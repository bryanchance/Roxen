/*
 * $Id: roxen.pike,v 1.341 1999/10/23 20:43:44 marcus Exp $
 *
 * The Roxen Challenger main program.
 *
 * Per Hedbor, Henrik Grubbström, Pontus Hagland, David Hedbor and others.
 */

// ABS and suicide systems contributed freely by Francesco Chemolli
constant cvs_version="$Id: roxen.pike,v 1.341 1999/10/23 20:43:44 marcus Exp $";

object backend_thread;
object argcache;

// Some headerfiles
#define IN_ROXEN
#include <roxen.h>
#include <config.h>
#include <module.h>
#include <variables.h>
#include <stat.h>

// Inherits
inherit "global_variables";
inherit "hosts";
inherit "disk_cache";
inherit "language";
inherit "supports";

// #define SSL3_DEBUG

/*
 * Version information
 */
constant __roxen_version__ = "1.4";
constant __roxen_build__ = "0";

#ifdef __NT__
string real_version= "Roxen Challenger/"+__roxen_version__+"."+__roxen_build__+" NT";
#else
string real_version= "Roxen Challenger/"+__roxen_version__+"."+__roxen_build__;
#endif

// Prototypes for other parts of roxen.
class RequestID 
{
  object conf; // Really Configuration, but that's sort of recursive.
  int time;
  string raw_url;
  int do_not_disconnect;
  mapping (string:string) variables;
  mapping (string:mixed) misc;
  mapping (string:string) cookies;
  mapping (string:string) request_headers;
  mapping (string:mixed) throttle;
  multiset(string) prestate;
  multiset(string) config;
  multiset(string) supports;
  multiset(string) pragma;
  array(string) client;
  array(string) referer;

  Stdio.File my_fd;
  string prot;
  string clientprot;
  string method;
  
  string realfile;
  string virtfile;
  string rest_query;
  string raw;
  string query;
  string not_query;
  string extra_extension;
  string data;
  string leftovers;
  array (int|string) auth;
  string rawauth;
  string realauth;
  string since;
  string remoteaddr;
  string host;

  void create(object|void master_request_id);
  void send(string|object what, int|void len);
  string scan_for_query( string in );
  void end(string|void s, int|void keepit);
  void ready_to_receive();
  void send_result(mapping|void result);
  RequestID clone_me();
};


string filename( object o )
{
  return search( master()->programs, object_program( o ) );
}

#ifdef THREADS
// This mutex is used by Privs
object euid_egid_lock = Thread.Mutex();
#endif /* THREADS */

/*
 * The privilege changer.
 *
 * Based on privs.pike,v 1.36.
 */
int privs_level;

static class Privs 
{
#if efun(seteuid)

  int saved_uid;
  int saved_gid;

  int new_uid;
  int new_gid;

#define LOGP (variables && variables->audit && GLOBVAR(audit))

#if constant(geteuid) && constant(getegid) && constant(seteuid) && constant(setegid)
#define HAVE_EFFECTIVE_USER
#endif

  static private string _getcwd()
  {
    if (catch{return(getcwd());}) {
      return("Unknown directory (no x-bit on current directory?)");
    }
  }

  static private string dbt(array t)
  {
    if(!arrayp(t) || (sizeof(t)<2)) return "";
    return (((t[0]||"Unknown program")-(_getcwd()+"/"))-"base_server/")+":"+t[1]+"\n";
  }

#ifdef THREADS
  static mixed mutex_key;	// Only one thread may modify the euid/egid at a time.
  static object threads_disabled;
#endif /* THREADS */

  int p_level;

  void create(string reason, int|string|void uid, int|string|void gid)
  {
#ifdef PRIVS_DEBUG
    werror(sprintf("Privs(%O, %O, %O)\n"
		   "privs_level: %O\n",
		   reason, uid, gid, privs_level));
#endif /* PRIVS_DEBUG */

#ifdef HAVE_EFFECTIVE_USER
    array u;

#ifdef THREADS
    if (euid_egid_lock) {
      catch { mutex_key = euid_egid_lock->lock(); };
    }
    threads_disabled = _disable_threads();
#endif /* THREADS */

    p_level = privs_level++;

    if(getuid()) return;

    /* Needs to be here since root-priviliges may be needed to
     * use getpw{uid,nam}.
     */
    saved_uid = geteuid();
    saved_gid = getegid();
    seteuid(0);

    /* A string of digits? */
    if(stringp(uid) && (replace(uid,"0123456789"/"",({""})*10)==""))
      uid = (int)uid;

    if(stringp(gid) && (replace(gid, "0123456789"/"", ({"" })*10 == "")))
      gid = (int)gid;

    if(!stringp(uid))
      u = getpwuid(uid);
    else 
    {
      u = getpwnam(uid);
      if(u) 
	uid = u[2];
    }

    if(u && !gid) 
      gid = u[3];
  
    if(!u) 
    {
      if (uid && (uid != "root")) 
      {
	if (intp(uid) && (uid >= 60000)) 
        {
	  report_warning(sprintf("Privs: User %d is not in the password database.\n"
				 "Assuming nobody.\n", uid));
	  // Nobody.
	  gid = gid || uid;	// Fake a gid also.
	  u = ({ "fake-nobody", "x", uid, gid, "A real nobody", "/", "/sbin/sh" });
	} else {
	  error("Unknown user: "+uid+"\n");
	}
      } else {
	u = ({ "root", "x", 0, gid, "The super-user", "/", "/sbin/sh" });
      }
    }

    if(LOGP)
      report_notice(sprintf("Change to %s(%d):%d privs wanted (%s), from %s",
			    (string)u[0], (int)uid, (int)gid,
			    (string)reason,
			    (string)dbt(backtrace()[-2])));

#if efun(cleargroups)
    catch { cleargroups(); };
#endif /* cleargroups */
#if efun(initgroups)
    catch { initgroups(u[0], u[3]); };
#endif
    gid = gid || getgid();
    int err = (int)setegid(new_gid = gid);
    if (err < 0) {
      report_debug(sprintf("Privs: WARNING: Failed to set the effective group id to %d!\n"
			   "Check that your password database is correct for user %s(%d),\n"
			   "and that your group database is correct.\n",
			   gid, (string)u[0], (int)uid));
      int gid2 = gid;
#ifdef HPUX_KLUDGE
      if (gid >= 60000) {
	/* HPUX has doesn't like groups higher than 60000,
	 * but has assigned nobody to group 60001 (which isn't even
	 * in /etc/group!).
	 *
	 * HPUX's libc also insists on filling numeric fields it doesn't like
	 * with the value 60001!
	 */
	perror("Privs: WARNING: Assuming nobody-group.\n"
	       "Trying some alternatives...\n");
	// Assume we want the nobody group, and try a couple of alternatives
	foreach(({ 60001, 65534, -2 }), gid2) {
	  perror("%d... ", gid2);
	  if (initgroups(u[0], gid2) >= 0) {
	    if ((err = setegid(new_gid = gid2)) >= 0) {
	      perror("Success!\n");
	      break;
	    }
	  }
	}
      }
#endif /* HPUX_KLUDGE */
      if (err < 0) {
	perror("Privs: Failed\n");
	throw(({ sprintf("Failed to set EGID to %d\n", gid), backtrace() }));
      }
      perror("Privs: WARNING: Set egid to %d instead of %d.\n",
	     gid2, gid);
      gid = gid2;
    }
    if(getgid()!=gid) setgid(gid||getgid());
    seteuid(new_uid = uid);
#endif /* HAVE_EFFECTIVE_USER */
  }

  void destroy()
  {
#ifdef PRIVS_DEBUG
    werror(sprintf("Privs->destroy()\n"
		   "privs_level: %O\n",
		   privs_level));
#endif /* PRIVS_DEBUG */

#ifdef HAVE_EFFECTIVE_USER
    /* Check that we don't increase the privs level */
    if (p_level >= privs_level) {
      report_error(sprintf("Change back to uid#%d gid#%d from uid#%d gid#%d\n"
			   "in wrong order! Saved level:%d Current level:%d\n"
			   "Occurs in:\n%s\n",
			   saved_uid, saved_gid, new_uid, new_gid,
			   p_level, privs_level,
			   describe_backtrace(backtrace())));
      return(0);
    }
    if (p_level != privs_level-1) {
      report_error(sprintf("Change back to uid#%d gid#%d from uid#%d gid#%d\n"
			   "Skips privs level. Saved level:%d Current level:%d\n"
			   "Occurs in:\n%s\n",
			   saved_uid, saved_gid, new_uid, new_gid,
			   p_level, privs_level,
			   describe_backtrace(backtrace())));
    }
    privs_level = p_level;

    if(LOGP) {
      catch {
	array bt = backtrace();
	if (sizeof(bt) >= 2) {
	  report_notice(sprintf("Change back to uid#%d gid#%d, from %s\n",
				saved_uid, saved_gid, dbt(bt[-2])));
	} else {
	  report_notice(sprintf("Change back to uid#%d gid#%d, from backend\n",
				saved_uid, saved_gid));
	}
      };
    }

    if(getuid()) return;

#ifdef DEBUG
    int uid = geteuid();
    if (uid != new_uid) {
      report_warning(sprintf("Privs: UID #%d differs from expected #%d\n"
			     "%s\n",
			     uid, new_uid, describe_backtrace(backtrace())));
    }
    int gid = getegid();
    if (gid != new_gid) {
      report_warning(sprintf("Privs: GID #%d differs from expected #%d\n"
			     "%s\n",
			     gid, new_gid, describe_backtrace(backtrace())));
    }
#endif /* DEBUG */

    seteuid(0);
    array u = getpwuid(saved_uid);
#if efun(cleargroups)
    catch { cleargroups(); };
#endif /* cleargroups */
    if(u && (sizeof(u) > 3)) {
      catch { initgroups(u[0], u[3]); };
    }
    setegid(saved_gid);
    seteuid(saved_uid);
#endif /* HAVE_EFFECTIVE_USER */
  }
#endif /* efun(seteuid) */
}

/* Used by read_config.pike, since there seems to be problems with
 * overloading otherwise.
 */
static object PRIVS(string r, int|string|void u, int|string|void g)
{
  return Privs(r, u, g);
}

#ifdef MODULE_DEBUG
#define MD_PERROR(X)	roxen_perror X;
#else
#define MD_PERROR(X)
#endif /* MODULE_DEBUG */

#ifndef THREADS
class container
{
  mixed value;
  mixed set(mixed to)
  {
    return value=to;
  }
  mixed get()
  {
    return value;
  }
}
#endif

// Locale support
Locale.Roxen.standard default_locale=Locale.Roxen.standard;
object fonts;
#if constant( thread_local )
object locale = thread_local();
#else
object locale = container(); 
#endif /* THREADS */

#define LOCALE	LOW_LOCALE->base_server

program Configuration;	/*set in create*/

array configurations = ({});

int die_die_die;

// Function that actually shuts down Roxen. (see low_shutdown).
private static void really_low_shutdown(int exit_code)
{
  // Die nicely.
#ifdef THREADS
  catch( stop_handler_threads() );
#endif /* THREADS */
  exit(exit_code);		// Now we die...
}

// Shutdown Roxen
//  exit_code = 0	True shutdown
//  exit_code = -1	Restart
private static void low_shutdown(int exit_code)
{
  catch 
  {
    configurations->stop();
    int pid;
    if (exit_code) {
      roxen_perror("Restarting Roxen.\n");
    } else {
      roxen_perror("Shutting down Roxen.\n");
      // exit(0);
    }
  };
  call_out(really_low_shutdown, 0.01, exit_code);
}

// Perhaps somewhat misnamed, really...  This function will close all
// listen ports and then quit.  The 'start' script should then start a
// new copy of roxen automatically.
void restart(float|void i)  
{ 
  call_out(low_shutdown, i, -1); 
} 
void shutdown(float|void i) 
{ 
  call_out(low_shutdown, i, 0); 
}

/*
 * handle() stuff
 */

#ifndef THREADS
// handle function used when THREADS is not enabled.
void unthreaded_handle(function f, mixed ... args)
{
  f(@args);
}

function handle = unthreaded_handle;
#else
function handle = threaded_handle;
#endif

/*
 * THREADS code starts here
 */
#ifdef THREADS
// #define THREAD_DEBUG

object do_thread_create(string id, function f, mixed ... args)
{
  object t = thread_create(f, @args);
  catch(t->set_name( id ));
#ifdef THREAD_DEBUG
  roxen_perror(id+" started\n");
#endif
  return t;
}

// Queue of things to handle.
// An entry consists of an array(function fp, array args)
static object (Thread.Queue) handle_queue = Thread.Queue();

// Number of handler threads that are alive.
static int thread_reap_cnt;

void handler_thread(int id)
{
  array (mixed) h, q;
  while(!die_die_die)
  {
    if(q=catch {
      do {
#ifdef THREAD_DEBUG
	werror("Handle thread ["+id+"] waiting for next event\n");
#endif /* THREAD_DEBUG */
	if((h=handle_queue->read()) && h[0]) {
#ifdef THREAD_DEBUG
	  werror(sprintf("Handle thread [%O] calling %O(@%O)...\n",
			 id, h[0], h[1..]));
#endif /* THREAD_DEBUG */
	  SET_LOCALE(default_locale);
	  h[0](@h[1]);
	  h=0;
	} else if(!h) {
	  // Roxen is shutting down.
	  werror("Handle thread ["+id+"] stopped\n");
	  thread_reap_cnt--;
	  return;
	}
      } while(1);
    }) {
      report_error(/* LOCALE->uncaught_error(*/describe_backtrace(q)/*)*/);
      if (q = catch {h = 0;}) {
	report_error(LOCALE->
		     uncaught_error(describe_backtrace(q)));
      }
    }
  }
}

void threaded_handle(function f, mixed ... args)
{
  handle_queue->write(({f, args }));
}

int number_of_threads;
void start_handler_threads()
{
  if (QUERY(numthreads) <= 1) {
    QUERY(numthreads) = 1;
    report_debug("Starting one thread to handle requests.\n");
  } else {
    report_debug("Starting "+
                 languages["en"]->number(  QUERY(numthreads) )
                 +" threads to handle requests.\n");
  }
  for(; number_of_threads < QUERY(numthreads); number_of_threads++)
    do_thread_create( "Handle thread ["+number_of_threads+"]",
		   handler_thread, number_of_threads );
}

void stop_handler_threads()
{
  int timeout=10;
  roxen_perror("Stopping all request handler threads.\n");
  while(number_of_threads>0) {
    number_of_threads--;
    handle_queue->write(0);
    thread_reap_cnt++;
  }
  while(thread_reap_cnt) {
    if(--timeout<=0) {
      roxen_perror("Giving up waiting on threads!\n");
      return;
    }
    sleep(0.1);
  }
}
#endif /* THREADS */

class fallback_redirect_request 
{
  string in = "";
  string out;
  string default_prefix;
  int port;
  object f;

  void die()
  {
#ifdef SSL3_DEBUG
    roxen_perror(sprintf("SSL3:fallback_redirect_request::die()\n"));
#endif /* SSL3_DEBUG */
#if 0
    /* Close the file, DAMMIT */
    object dummy = Stdio.File();
    if (dummy->open("/dev/null", "rw"))
      dummy->dup2(f);
#endif    
    f->close();
    destruct(f);
    destruct(this_object());
  }
  
  void write_callback(object id)
  {
#ifdef SSL3_DEBUG
    roxen_perror(sprintf("SSL3:fallback_redirect_request::write_callback()\n"));
#endif /* SSL3_DEBUG */
    int written = id->write(out);
    if (written <= 0)
      die();
    out = out[written..];
    if (!strlen(out))
      die();
  }

  void read_callback(object id, string s)
  {
#ifdef SSL3_DEBUG
    roxen_perror(sprintf("SSL3:fallback_redirect_request::read_callback(X, \"%s\")\n", s));
#endif /* SSL3_DEBUG */
    in += s;
    string name;
    string prefix;

    if (search(in, "\r\n\r\n") >= 0)
    {
//      werror(sprintf("request = '%s'\n", in));
      array(string) lines = in / "\r\n";
      array(string) req = replace(lines[0], "\t", " ") / " ";
      if (sizeof(req) < 2)
      {
	out = "HTTP/1.0 400 Bad Request\r\n\r\n";
      }
      else
      {
	if (sizeof(req) == 2)
	{
	  name = req[1];
	}
	else
	{
	  name = req[1..sizeof(req)-2] * " ";
	  foreach(Array.map(lines[1..], `/, ":"), array header)
	  {
	    if ( (sizeof(header) >= 2) &&
		 (lower_case(header[0]) == "host") )
	      prefix = "https://" + header[1] - " ";
	  }
	}
	if (prefix) {
	  if (prefix[-1] == '/')
	    prefix = prefix[..strlen(prefix)-2];
	  prefix = prefix + ":" + port;
	} else {
	  /* default_prefix (aka MyWorldLocation) already contains the
	   * portnumber.
	   */
	  if (!(prefix = default_prefix)) {
	    /* This case is most unlikely to occur,
	     * but better safe than sorry...
	     */
	    string ip = (f->query_address(1)/" ")[0];
	    prefix = "https://" + ip + ":" + port;
	  } else if (prefix[..4] == "http:") {
	    /* Broken MyWorldLocation -- fix. */
	    prefix = "https:" + prefix[5..];
	  }
	}
	out = sprintf("HTTP/1.0 301 Redirect to secure server\r\n"
		      "Location: %s%s\r\n\r\n", prefix, name);
      }
      f->set_read_callback(0);
      f->set_write_callback(write_callback);
    }
  }
  
  void create(object socket, string s, string l, int p)
  {
#ifdef SSL3_DEBUG
    roxen_perror(sprintf("SSL3:fallback_redirect_request(X, \"%s\", \"%s\", %d)\n", s, l||"CONFIG PORT", p));
#endif /* SSL3_DEBUG */
    f = socket;
    default_prefix = l;
    port = p;
    f->set_nonblocking(read_callback, 0, die);
    f->set_id(f);
    read_callback(f, s);
  }
}

class Protocol
{
  inherit Stdio.Port;

  constant name = "unknown";
  constant supports_ipless = 0;
  constant requesthandlerfile = "";
  constant default_port = 4711;

  int port;
  int refs;
  string ip;
  program requesthandler;
  array(string) sorted_urls = ({});
  mapping(string:mapping) urls = ([]);

  void ref(string name, mapping data)
  {
    if(urls[name])
      return;
    refs++;
    urls[name] = data;
    sorted_urls = Array.sort_array(indices(urls), lambda(string a, string b) {
						    return sizeof(a)<sizeof(b);
						  });
  }

  void unref(string name)
  {
    if(!urls[name])
      return;
    m_delete(urls, name);
    sorted_urls -= ({name});
    if( !--refs )
      destruct( ); // Close the port.
  }

  void got_connection()
  {
    object q = accept( );
    if( !q )
      ;// .. errno stuff here ..
    else {
      // FIXME: Add support for ANY => specific IP here.

      requesthandler( q, this_object() );
    }
  }

  object find_configuration_for_url( string url, RequestID id )
  {
//     werror("find configuration for '"+url+"'\n");
    foreach( sorted_urls, string in )
    {
      if( glob( in+"*", url ) )
      {
	if( urls[in]->path )
        {
	  id->not_query = id->not_query[strlen(urls[in]->path)..];
          id->misc->site_prefix_path = urls[in]->path;
        }
	return urls[ in ]->conf;
      }
    }
    // Ouch.
    return values( urls )[0]->conf;
  }

  void set_option_default(string option, mixed value)
  {
    mapping all_options = QUERY(port_options);
    all_options[""][option] = value;

    // FIXME: Mark as changed?
    // FIXME: Save?
  }

  mixed query_option(string option)
  {
    // FIXME: Cache?

    mapping(string:mapping(string:mixed)) all_options = QUERY(port_options);

    mixed res;

    mapping val;

    // Any protocol specific settiongs?
    if (val = all_options[name]) {
      mapping val2;
      // Any ip specific settings?
      if (val2 = val[ip]) {
	mapping val3;
	// Any port specific settings?
	if (val3 = val2[port]) {
	  if (!zero_type(res = val3[option])) {
	    return res;
	  }
	}
	if (!zero_type(res = val2[""][option])) {
	  return res;
	}
      }
      if (!zero_type(res = val[""][option])) {
	return res;
      }
    }
    if( all_options[""] )
      return all_options[""][option];
    return 0;
  }

  void create( int pn, string i )
  {
    if (query_option("do_not_bind")) {
      // This is useful if you run two Roxen processes,
      // that both handle an URL which has two IPs, and
      // use DNS round-robin.
      report_warning(sprintf("Binding to %s://%s:%d/ disabled\n",
			     name, ip, port));
      destruct();
    }
    if( !requesthandler )
      requesthandler = (program)requesthandlerfile;
    port = pn;
    ip = i;

    ::create();

    if(!bind( port, got_connection, ip )) {
      report_error(sprintf("Failed to bind %s://%s:%d/\n", name, ip, port));
      destruct();
    }
  }
}

class SSLProtocol
{
  inherit Protocol;

#if constant(SSL.sslfile)

  // SSL context
  object ctx;

  class destruct_protected_sslfile
  {
    object sslfile;

    mixed `[](string s)
    {
      return sslfile[s];
    }

    mixed `[]=(string s, mixed val)
    {
      return sslfile[s] = val;
    }

    mixed `->(string s)
    {
      return sslfile[s];
    }

    mixed `->=(string s, mixed val)
    {
      return sslfile[s] = val;
    }

    void destroy()
    {
      if (sslfile) {
	sslfile->close();
      }
    }

    void create(object q, object ctx)
    {
      sslfile = SSL.sslfile(q, ctx);
    }
  }

  object accept()
  {
    object q = ::accept();
    if (q) {
      return destruct_protected_sslfile(q, ctx);
    }
    return 0;
  }

  void create(int pn, string i)
  {
    ctx = SSL.context();

    object privs = Privs("Reading cert file");
    string f = Stdio.read_file(query_option("ssl_cert_file") ||
			       "demo_certificate.pem");
    string f2 = query_option("ssl_key_file") &&
      Stdio.read_file(query_option("ssl_key_file"));
    if (privs)
      destruct(privs);

    if (!f) {
      report_error("ssl3: Reading cert-file failed!\n");
      destruct();
      return;
    }
    object msg = Tools.PEM.pem_msg()->init(f);

    object part = msg->parts["CERTIFICATE"]
      ||msg->parts["X509 CERTIFICATE"];

    string cert;
  
    if (!part || !(cert = part->decoded_body())) {
      report_error("ssl3: No certificate found.\n");
      destruct();
      return;
    }
  
    if (query_option("ssl_key_file"))
    {
      if (!f2) {
	report_error("ssl3: Reading key-file failed!\n");
	destruct();
	return;
      }
      msg = Tools.PEM.pem_msg()->init(f2);
    }

    function r = Crypto.randomness.reasonably_random()->read;

#ifdef SSL3_DEBUG
    werror(sprintf("ssl3: key file contains: %O\n", indices(msg->parts)));
#endif

    if (part = msg->parts["RSA PRIVATE KEY"])
    {
      string key;

      if (!(key = part->decoded_body())) {
	report_error("ssl3: Private rsa key not valid (PEM).\n");
	destruct();
	return;
      }
      
      object rsa = Standards.PKCS.RSA.parse_private_key(key);
      if (!rsa) {
	report_error("ssl3: Private rsa key not valid (DER).\n");
	destruct();
	return;
      }

      ctx->rsa = rsa;
    
#ifdef SSL3_DEBUG
      report_debug(sprintf("ssl3: RSA key size: %d bits\n", rsa->rsa_size()));
#endif
    
      if (rsa->rsa_size() > 512)
      {
	/* Too large for export */
	ctx->short_rsa = Crypto.rsa()->generate_key(512, r);
      
	// ctx->long_rsa = Crypto.rsa()->generate_key(rsa->rsa_size(), r);
      }
      ctx->rsa_mode();

      object tbs = Tools.X509.decode_certificate (cert);
      if (!tbs) {
	report_error("ssl3: Certificate not valid (DER).\n");
	destruct();
	return;
      }
      if (!tbs->public_key->rsa->public_key_equal (rsa)) {
	report_error("ssl3: Certificate and private key do not match.\n");
	destruct();
	return;
      }
    }
    else if (part = msg->parts["DSA PRIVATE KEY"])
    {
      string key;

      if (!(key = part->decoded_body())) {
	report_error("ssl3: Private dsa key not valid (PEM).\n");
	destruct();
	return;
      }
      
      object dsa = Standards.PKCS.DSA.parse_private_key(key);
      if (!dsa) {
	report_error("ssl3: Private dsa key not valid (DER).\n");
	destruct();
	return;
      }

#ifdef SSL3_DEBUG
      report_debug(sprintf("ssl3: Using DSA key.\n"));
#endif
	
      dsa->use_random(r);
      ctx->dsa = dsa;
      /* Use default DH parameters */
      ctx->dh_params = SSL.cipher.dh_parameters();

      ctx->dhe_dss_mode();

      // FIXME: Add cert <-> private key check.
    }
    else {
      report_error("ssl3: No private key found.\n");
      destruct();
      return;
    }

    ctx->certificates = ({ cert });
    ctx->random = r;

#if EXPORT
    ctx->export_mode();
#endif

    ::create(pn, i);
  }
#else /* !constant(SSL.sslfile) */
  void create(int pn, string i) {
    report_error("No SSL support\n");
    destruct();
  }
#endif /* constant(SSL.sslfile) */
}

class HTTP
{
  inherit Protocol;
  constant supports_ipless = 1;
  constant name = "http";
  constant requesthandlerfile = "protocols/http.pike";
  constant default_port = 80;
}

class HTTPS
{
  inherit SSLProtocol;

  constant supports_ipless = 0;
  constant name = "https";
  constant requesthandlerfile = "protocols/http.pike";
  constant default_port = 443;

#if constant(SSL.sslfile)
  class http_fallback {
    object my_fd;

    void ssl_alert_callback(object alert, object|int n, string data)
    {
#ifdef SSL3_DEBUG
      roxen_perror(sprintf("SSL3:http_fallback(X, %O, \"%s\")\n", n, data));
#endif /* SSL3_DEBUG */
      //  trace(1);
#if 0
      werror(sprintf("ssl3->http_fallback: alert(%d, %d)\n"
		     "seq_num = %s\n"
		     "data = '%s'", alert->level, alert->description,
		     (string) n, data));
#endif
      if ( (my_fd->current_write_state->seq_num == 0)
	   && search(lower_case(data), "http"))
      {
	object raw_fd = my_fd->socket;
	my_fd->socket = 0;

	/* Redirect to a https-url */
	//    my_fd->set_close_callback(0);
	//    my_fd->leave_me_alone = 1;
	fallback_redirect_request(raw_fd, data,
				  my_fd->config && 
				  my_fd->config->query("MyWorldLocation"),
				  port);
	destruct(my_fd);
	destruct(this_object());
	//    my_fd = 0; /* Forget ssl-object */
      }
    }

    void ssl_accept_callback(object id)
    {
#ifdef SSL3_DEBUG
      roxen_perror(sprintf("SSL3:ssl_accept_callback(X)\n"));
#endif /* SSL3_DEBUG */
      id->set_alert_callback(0); /* Forget about http_fallback */
      my_fd = 0;          /* Not needed any more */
    }

    void create(object fd)
    {
      my_fd = fd;

      fd->set_alert_callback(ssl_alert_callback);
      fd->set_accept_callback(ssl_accept_callback);
    }
  }
    
  object accept()
  {
    object q = ::accept();

    if (q) {
      http_fallback(q);
    }
    return q;
  }
#endif /* constant(SSL.sslfile) */
}

class FTP
{
  inherit Protocol;
  constant supports_ipless = 0;
  constant name = "ftp";
  constant requesthandlerfile = "protocols/ftp.pike";
  constant default_port = 21;

  // Some statistics
  int sessions;
  int ftp_users;
  int ftp_users_now;
}

class FTPS
{
  inherit SSLProtocol;
  constant supports_ipless = 0;
  constant name = "ftps";
  constant requesthandlerfile = "protocols/ftp.pike";
  constant default_port = 21;	/*** ???? ***/

  // Some statistics
  int sessions;
  int ftp_users;
  int ftp_users_now;
}

class GOPHER
{
  inherit Protocol;
  constant supports_ipless = 0;
  constant name = "gopher";
  constant requesthandlerfile = "protocols/gopher.pike";
  constant default_port = 70;
}

class TETRIS
{
  inherit Protocol;
  constant supports_ipless = 0;
  constant name = "tetris";
  constant requesthandlerfile = "protocols/tetris.pike";
  constant default_port = 2050;
}

mapping protocols = ([
  "http":HTTP,
  "ftp":FTP,

  "https":HTTPS,
  "ftps":FTPS,

  "gopher":GOPHER,
  "tetris":TETRIS,
]);

mapping(string:mapping) open_ports = ([ ]);
mapping(string:object) urls = ([]);
array sorted_urls = ({});

array(string) find_ips_for( string what )
{
  if( what == "*" || lower_case(what) == "any" )
    return 0;

  if( is_ip( what ) )
    return ({ what });

  array res = gethostbyname( what );
  if( !res || !sizeof( res[1] ) )
    report_error( "I cannot possibly bind to "+what+
                  ", that host is unknown. "
                  "Substituting with ANY\n");
  else
    return Array.uniq(res[1]);
}

void unregister_url( string url ) 
{
  if( urls[ url ] && urls[ url ]->port )
  {
    urls[ url ]->port->unref(url);
    m_delete( urls, url );
    sort_urls();
  }
}

void sort_urls()
{
  sorted_urls = indices( urls );
  sort( map( map( sorted_urls, strlen ), `-), sorted_urls );
}

int register_url( string url, object conf )
{
  report_debug("Register "+url+" for "+conf->name+"\n");
  string protocol;
  string host;
  int port;
  string path;

  url = replace( url, "/ANY", "/*" );
  url = replace( url, "/any", "/*" );

  sscanf( url, "%[^:]://%[^/]%s", protocol, host, path );
  sscanf( host, "%[^:]:%d", host, port );

  if( strlen( path ) && ( path[-1] == '/' ) )
    path = path[..strlen(path)-2];
  if( !strlen( path ) )
    path = 0;

  if( urls[ url ] )
  {
    if( urls[ url ]->conf != conf )
    {
      report_error( "Cannot register URL "+url+
                    ", already registerd by " + 
                    urls[ url ]->conf->name + "!\n" );
      return 0;
    }
    urls[ url ]->port->ref(url, urls[url]);
    return 1;
  }

  Protocol prot;

  if( !( prot = protocols[ protocol ] ) )
  {
    report_error( "Cannot register URL "+url+
                  ", cannot find the protocol " + 
                  protocol + "!\n" );
    return 0;
  }

  if( !port )
    port = prot->default_port;

  array(string) required_hosts;

  /*  if( !prot->supports_ipless ) */
    required_hosts = find_ips_for( host );

  if (!required_hosts) {
    required_hosts = ({ 0 });	// ANY
  }

  mapping m;
  if( !( m = open_ports[ protocol ] ) )
    m = open_ports[ protocol ] = ([]);
    
  urls[ url ] = ([ "conf":conf, "path":path ]);
  sorted_urls += ({ url });

  int failures;

  foreach(required_hosts, string required_host) {
    if( m[ required_host ] && m[ required_host ][ port ] )
    {
      m[ required_host ][ port ]->ref(url, urls[url]);
      urls[ url ]->port = prot;
      continue;    /* No need to open a new port */
    }

    if( !m[ required_host ] )
      m[ required_host ] = ([ ]);

    m[ required_host ][ port ] = prot( port, required_host );
    if( !( m[ required_host ][ port ] ) )
    {
      m_delete( m[ required_host ], port );
      failures++;
      if (required_host) {
	report_warning("Binding the port on IP " + required_host +
		       " failed for URL " + url + "!\n");
      }
      continue;
    }
    urls[ url ]->port = m[ required_host ][ port ];
    m[ required_host ][ port ]->ref(url, urls[url]);
  }
  if (failures == sizeof(required_hosts)) {
    m_delete( urls, url );
    report_error( "Cannot register URL "+url+", cannot bind the port!\n" );
    sort_urls();
    return 0;
  }
  sort_urls();
  return 1;
}


object find_configuration( string name )
{
  name = replace( lower_case( replace(name,"-"," ") )-" ", "/", "-" );
  foreach( configurations, object o )
  {
    if( (lower_case( replace( o->name - " " , "/", "-" ) ) == name) ||
        (lower_case( replace( o->query_name() - " " , "/", "-" ) ) == name) )
      return o;
    werror(" is not '"+o->name+"'\n" );
  }
}

// Create a new configuration from scratch.
// 'type' is as in the form. 'none' for a empty configuration.
int add_new_configuration(string name, string type)
{
}

mapping(string:array(int)) error_log=([]);

// Write a string to the configuration interface error log and to stderr.
void nwrite(string s, int|void perr, int|void type)
{
  if (!error_log[type+","+s])
    error_log[type+","+s] = ({ time() });
  else
    error_log[type+","+s] += ({ time() });
  if(type >= 1) 
    roxen_perror(s);
}

// When was Roxen started?
int boot_time  =time();
int start_time =time();

string version()
{
  return QUERY(default_ident)?real_version:QUERY(ident);
}

public void log(mapping file, object request_id)
{
  if(!request_id->conf) return; 
  request_id->conf->log(file, request_id);
}

// Support for unique user id's 
private object current_user_id_file;
private int current_user_id_number, current_user_id_file_last_mod;

private void restore_current_user_id_number()
{
  if(!current_user_id_file)
    current_user_id_file = open(configuration_dir + "LASTUSER~", "rwc");
  if(!current_user_id_file)
  {
    call_out(restore_current_user_id_number, 2);
    return;
  } 
  current_user_id_number = (int)current_user_id_file->read(100);
  current_user_id_file_last_mod = current_user_id_file->stat()[2];
  perror("Restoring unique user ID information. (" + current_user_id_number 
	 + ")\n");
#ifdef FD_DEBUG
  mark_fd(current_user_id_file->query_fd(), LOCALE->unique_uid_logfile());
#endif
}


int increase_id()
{
  if(!current_user_id_file)
  {
    restore_current_user_id_number();
    return current_user_id_number+time();
  }
  if(current_user_id_file->stat()[2] != current_user_id_file_last_mod)
    restore_current_user_id_number();
  current_user_id_number++;
  //perror("New unique id: "+current_user_id_number+"\n");
  current_user_id_file->seek(0);
  current_user_id_file->write((string)current_user_id_number);
  current_user_id_file_last_mod = current_user_id_file->stat()[2];
  return current_user_id_number;
}

public string full_status()
{
  int tmp;
  string res="";
  array foo = ({0.0, 0.0, 0.0, 0.0, 0});
  if(!sizeof(configurations))
    return LOCALE->no_servers_enabled();
  
  foreach(configurations, object conf)
  {
    if(!conf->sent
       ||!conf->received
       ||!conf->hsent)
      continue;
    foo[0] += conf->sent->mb()/(float)(time(1)-start_time+1);
    foo[1] += conf->sent->mb();
    foo[2] += conf->hsent->mb();
    foo[3] += conf->received->mb();
    foo[4] += conf->requests;
  }

  for(tmp = 1; tmp < 4; tmp ++)
  {
    // FIXME: LOCALE?

    if(foo[tmp] < 1024.0)     
      foo[tmp] = sprintf("%.2f MB", foo[tmp]);
    else
      foo[tmp] = sprintf("%.2f GB", foo[tmp]/1024.0);
  }

  int uptime = time()-start_time;
  int days = uptime/(24*60*60);
  int hrs = uptime/(60*60);
  int min = uptime/60 - hrs*60;
  hrs -= days*24;

  tmp=(int)((foo[4]*600.0)/(uptime+1));

  return(LOCALE->full_status(real_version, boot_time, start_time-boot_time,
			     days, hrs, min, uptime%60,
			     foo[1], foo[0] * 8192.0, foo[2],
			     foo[4], (float)tmp/(float)10, foo[3]));
}


static int abs_started;

void restart_if_stuck (int force) 
{
  remove_call_out(restart_if_stuck);
  if (!(QUERY(abs_engage) || force))
    return;
  if(!abs_started) 
  {
    abs_started = 1;
    roxen_perror("Anti-Block System Enabled.\n");
  }
  call_out (restart_if_stuck,10);
  signal(signum("SIGALRM"),
	 lambda( int n ) {
	   werror(sprintf("**** %s: ABS engaged!\n"
			  "Trying to dump backlog: \n",
			  ctime(time()) - "\n"));
	   catch {
	     // Catch for paranoia reasons.
	     describe_all_threads();
	   };
	   werror(sprintf("**** %s: ABS exiting roxen!\n\n",
			  ctime(time())));
	   _exit(1); 	// It might now quit correctly otherwise, if it's
	   //  locked up
	 });
  alarm (60*QUERY(abs_timeout)+10);
}

void post_create () 
{
  if (QUERY(abs_engage))
    call_out (restart_if_stuck,10);
  if (QUERY(suicide_engage))
    call_out (restart,60*60*24*QUERY(suicide_timeout));
}


// Cache used by the various configuration interface modules etc.
// It should be OK to delete this cache at any time.
class ConfigIFCache
{
  string dir;
  void create( string name )
  {
    dir = "config_caches/"+replace(configuration_dir-".", "/", "-") + "/" + name + "/";
    mkdirhier( dir+"/foo" );
  }

  mixed set( string name, mixed to )
  {
    Stdio.File f = Stdio.File();
    if(!f->open(  dir + replace( name, "/", "-" ), "wct" ))
    {
      mkdirhier( dir+"/foo" );
      if(!f->open(  dir + replace( name, "/", "-" ), "wct" ))
      {
        report_error("Failed to create configuration interface cache file ("+
                     dir + replace( name, "/", "-" )+") "+
                     strerror( errno() )+"\n");
        return to;
      }
    }
    f->write( encode_value( to ) );
    return to;
  }
  
  mixed get( string name )
  {
    Stdio.File f = Stdio.File();
    if(!f->open(  dir + replace( name, "/", "-" ), "r" ))
      return 0;
    return decode_value( f->read() );
  }

  void delete( string name )
  {
    rm( dir + replace( name, "/", "-" ) );
  }
}


class ImageCache
{
  string name;
  string dir;
  function draw_function;
  mapping data_cache = ([]); // not normally used.
  mapping meta_cache = ([]);


  static mapping meta_cache_insert( string i, mapping what )
  {
    return meta_cache[i] = what;
  }
  
  static string data_cache_insert( string i, string what )
  {
    return data_cache[i] = what;
  }

  static mixed frommapp( mapping what )
  {
    if( what[""] ) return what[""];
    return what;
  }

  static void draw( string name, RequestID id )
  {
    mixed args = Array.map( Array.map( name/"$", argcache->lookup, id->client ), frommapp);
    mapping meta;
    string data;
    mixed reply = draw_function( @copy_value(args), id );

    if( arrayp( args ) )
      args = args[0];


    if( objectp( reply ) || (mappingp(reply) && reply->img) )
    {
      int quant = (int)args->quant;
      string format = lower_case(args->format || "gif");
      string dither = args->dither;
      Image.Colortable ct;
      object alpha;
      int true_alpha; 

      if( args->fs  || dither == "fs" )
	dither = "floyd_steinberg";

      if(  dither == "random" )
	dither = "random_dither";

      if( format == "jpg" ) 
        format = "jpeg";

      if(mappingp(reply))
      {
        alpha = reply->alpha;
        reply = reply->img;
      }
      
      if( args->gamma )
        reply = reply->gamma( (float)args->gamma );

      if( args["true-alpha"] )
        true_alpha = 1;

      if( args["opaque-value"] )
      {
        true_alpha = 1;
        int ov = (int)(((float)args["opaque-value"])*2.55);
        if( ov < 0 )
          ov = 0;
        else if( ov > 255 )
          ov = 255;
        if( alpha )
        {
          object i = Image.image( reply->xsize(), reply->ysize(), ov,ov,ov );
          i->paste_alpha( alpha, ov );
          alpha = i;
        }
        else
        {
          alpha = Image.image( reply->xsize(), reply->ysize(), ov,ov,ov );
        }
      }

      if( args->scale )
      {
        int x, y;
        if( sscanf( args->scale, "%d,%d", x, y ) == 2)
        {
          reply = reply->scale( x, y );
          if( alpha )
            alpha = alpha->scale( x, y );
        }
        else if( (float)args->scale < 3.0)
        {
          reply = reply->scale( ((float)args->scale) );
          if( alpha )
            alpha = alpha->scale( ((float)args->scale) );
        }
      }

      if( args->maxwidth || args->maxheight )
      {
        int x = (int)args->maxwidth, y = (int)args->maxheight;
        if( x && reply->xsize() > x )
        {
          reply = reply->scale( x, 0 );
          if( alpha )
            alpha = alpha->scale( x, 0 );
        }
        if( y && reply->ysize() > y )
        {
          reply = reply->scale( 0, y );
          if( alpha )
            alpha = alpha->scale( 0, y );
        }
      }

      if( quant || (format=="gif") )
      {
        int ncols = quant||id->misc->defquant||16;
        if( ncols > 250 )
          ncols = 250;
        ct = Image.Colortable( reply, ncols );
        if( dither )
          if( ct[ dither ] )
            ct[ dither ]();
          else
            ct->ordered();
      }

      if(!Image[upper_case( format )] 
         || !Image[upper_case( format )]->encode )
        error("Image format "+format+" unknown\n");

      mapping enc_args = ([]);
      if( ct )
        enc_args->colortable = ct;
      if( alpha )
        enc_args->alpha = alpha;

      foreach( glob( "*-*", indices(args)), string n )
        if(sscanf(n, "%*[^-]-%s", string opt ) == 2)
          enc_args[opt] = (int)args[n];

      switch(format)
      {
       case "gif":
         if( alpha && true_alpha )
         {
           object ct=Image.Colortable( ({ ({ 0,0,0 }), ({ 255,255,255 }) }) );
           ct->floyd_steinberg();
           alpha = ct->map( alpha );
         }
         if( catch {
           if( alpha )
             data = Image.GIF.encode_trans( reply, ct, alpha );
           else
             data = Image.GIF.encode( reply, ct );
         })
           data = Image.GIF.encode( reply );
         break;
       case "png":
         if( ct )
           enc_args->palette = ct;
         m_delete( enc_args, "colortable" );
       default:
        data = Image[upper_case( format )]->encode( reply, enc_args );
      }

      meta = ([ 
        "xsize":reply->xsize(),
        "ysize":reply->ysize(),
        "type":"image/"+format,
      ]);
    }
    else if( mappingp(reply) ) 
    {
      meta = reply->meta;
      data = reply->data;
      if( !meta || !data )
        error("Invalid reply mapping.\n"
              "Should be ([ \"meta\": ([metadata]), \"data\":\"data\" ])\n");
    }
    store_meta( name, meta );
    store_data( name, data );
  }


  static void store_meta( string id, mapping meta )
  {
    meta_cache_insert( id, meta );

    string data = encode_value( meta );
    Stdio.File f = Stdio.File(  );
    if(!f->open(dir+id+".i", "wct" ))
    {
      report_error( "Failed to open image cache persistant cache file "+
                    dir+id+".i: "+strerror( errno() )+ "\n" );
      return;
    }
    f->write( data );
  }

  static void store_data( string id, string data )
  {
    Stdio.File f = Stdio.File(  );
    if(!f->open(dir+id+".d", "wct" ))
    {
      data_cache_insert( id, data );
      report_error( "Failed to open image cache persistant cache file "+
                    dir+id+".d: "+strerror( errno() )+ "\n" );
      return;
    }
    f->write( data );
  }


  static mapping restore_meta( string id )
  {
    Stdio.File f;
    if( meta_cache[ id ] )
      return meta_cache[ id ];
    f = Stdio.File( );
    if( !f->open(dir+id+".i", "r" ) )
      return 0;
    return meta_cache_insert( id, decode_value( f->read() ) );
  }

  static mapping restore( string id )
  {
    string|object(Stdio.File) f;
    mapping m;
    if( data_cache[ id ] )
      f = data_cache[ id ];
    else 
      f = Stdio.File( );

    if(!f->open(dir+id+".d", "r" ))
      return 0;

    m = restore_meta( id );
    
    if(!m)
      return 0;

    if( stringp( f ) )
      return roxenp()->http_string_answer( f, m->type||("image/gif") );
    return roxenp()->http_file_answer( f, m->type||("image/gif") );
  }


  string data( string|mapping args, RequestID id, int|void nodraw )
  {
    string na = store( args, id );
    mixed res;

    if(!( res = restore( na )) )
    {
      if(nodraw)
        return 0;
      draw( na, id );
      res = restore( na );
    }
    if( res->file )
      return res->file->read();
    return res->data;
  }

  mapping http_file_answer( string|mapping data, 
                            RequestID id, 
                            int|void nodraw )
  {
    string na = store( data,id );
    mixed res;
    if(!( res = restore( na )) )
    {
      if(nodraw)
        return 0;
      draw( na, id );
      res = restore( na );
    }
    return res;
  }

  mapping metadata( string|mapping data, RequestID id, int|void nodraw )
  {
    string na = store( data,id );
    if(!restore_meta( na ))
    {
      if(nodraw)
        return 0;
      draw( na, id );
      return restore_meta( na );
    }
    return restore_meta( na );
  }

  mapping tomapp( mixed what )
  {
    if( mappingp( what ))
      return what;
    return ([ "":what ]);
  }

  string store( array|string|mapping data, RequestID id )
  {
    string ci;
    if( mappingp( data ) )
      ci = argcache->store( data );
    else if( arrayp( data ) )
      ci = Array.map( Array.map( data, tomapp ), argcache->store )*"$";
    else
      ci = data;
    return ci;
  }

  void set_draw_function( function to )
  {
    draw_function = to;
  }

  void create( string id, function draw_func, string|void d )
  {
    if(!d) d = roxenp()->QUERY(argument_cache_dir);
    if( d[-1] != '/' )
      d+="/";
    d += id+"/";

    mkdirhier( d+"foo");

    dir = d;
    name = id;
    draw_function = draw_func;
  }
}


class ArgCache
{
  static string name;
  static string path;
  static int is_db;
  static object db;

#define CACHE_VALUE 0
#define CACHE_SKEY  1
#define CACHE_SIZE  600
#define CLEAN_SIZE  100

#ifdef THREADS
  static Thread.Mutex mutex = Thread.Mutex();
# define LOCK() object __key = mutex->lock()
#else
# define LOCK() 
#endif

  static mapping (string:mixed) cache = ([ ]);

  static void setup_table()
  {
    if(catch(db->query("select id from "+name+" where id=-1")))
      if(catch(db->query("create table "+name+" ("
                         "id int auto_increment primary key, "
                         "lkey varchar(80) not null default '', "
                         "contents blob not null default '', "
                         "atime bigint not null default 0)")))
        throw("Failed to create table in database\n");
  }

  void create( string _name, 
               string _path, 
               int _is_db )
  {
    name = _name;
    path = _path;
    is_db = _is_db;

    if(is_db)
    {
      db = Sql.sql( path );
      if(!db)
        error("Failed to connect to database for argument cache\n");
      setup_table( );
    } else {
      if(path[-1] != '/' && path[-1] != '\\')
        path += "/";
      path += replace(name, "/", "_")+"/";
      mkdirhier( path + "/tmp" );
      object test = Stdio.File();
      if (!test->open (path + "/.testfile", "wc"))
	error ("Can't create files in the argument cache directory " + path + "\n");
      else {
	test->close();
	rm (path + "/.testfile");
      }
    }
  }

  static string read_args( string id )
  {
    if( is_db )
    {
      mapping res = db->query("select contents from "+name+" where id='"+id+"'");
      if( sizeof(res) )
      {
        db->query("update "+name+" set atime='"+
                  time()+"' where id='"+id+"'");
        return res[0]->contents;
      }
      return 0;
    } else {
      if( file_stat( path+id ) )
        return Stdio.read_bytes(path+"/"+id);
    }
    return 0;
  }

  static string create_key( string long_key )
  {
    if( is_db )
    {
      mapping data = db->query(sprintf("select id,contents from %s where lkey='%s'",
                                       name,long_key[..79]));
      foreach( data, mapping m )
        if( m->contents == long_key )
          return m->id;

      db->query( sprintf("insert into %s (contents,lkey,atime) values "
                         "('%s','%s','%d')", 
                         name, long_key, long_key[..79], time() ));
      return create_key( long_key );
    } else {
      string _key=MIME.encode_base64(Crypto.md5()->update(long_key)->digest(),1);
      _key = replace(_key-"=","/","=");
      string short_key = _key[0..1];

      while( file_stat( path+short_key ) )
      {
        if( Stdio.read_bytes( path+short_key ) == long_key )
          return short_key;
        short_key = _key[..strlen(short_key)];
        if( strlen(short_key) >= strlen(_key) )
          short_key += "."; // Not very likely...
      }
      object f = Stdio.File( path + short_key, "wct" );
      f->write( long_key );
      return short_key;
    }
  }


  int key_exists( string key )
  {
    LOCK();
    if( !is_db ) 
      return !!file_stat( path+key );
    return !!read_args( key );
  }

  string store( mapping args )
  {
    LOCK();
    array b = values(args), a = sort(indices(args),b);
    string data = MIME.encode_base64(encode_value(({a,b})),1);

    if( cache[ data ] )
      return cache[ data ][ CACHE_SKEY ];

    string id = create_key( data );
    cache[ data ] = ({ 0, 0 });
    cache[ data ][ CACHE_VALUE ] = copy_value( args );
    cache[ data ][ CACHE_SKEY ] = id;
    cache[ id ] = data;

    if( sizeof( cache ) > CACHE_SIZE )
    {
      array i = indices(cache);
      while( sizeof(cache) > CACHE_SIZE-CLEAN_SIZE )
        m_delete( cache, i[random(sizeof(i))] );
    }
    return id;
  }

  mapping lookup( string id, string|void client )
  {
    LOCK();
    if(cache[id] && cache[ cache[id] ] )
      return cache[cache[id]][CACHE_VALUE];

    string q = read_args( id );

    if(!q) error("Key does not exist! (Thinks "+ client +")\n");
    mixed data = decode_value(MIME.decode_base64( q ));
    data = mkmapping( data[0],data[1] );

    cache[ q ] = ({0,0});
    cache[ q ][ CACHE_VALUE ] = data;
    cache[ q ][ CACHE_SKEY ] = id;
    cache[ id ] = q;
    return data;
  }

  void delete( string id )
  {
    LOCK();
    if(cache[id])
    {
      m_delete( cache, cache[id] );
      m_delete( cache, id );
    }
    if( is_db )
      db->query( "delete from "+name+" where id='"+id+"'" );
    else
      rm( path+id );
  }
}

mapping cached_decoders = ([]);
string decode_charset( string charset, string data )
{
  // FIXME: This code is probably not thread-safe!
  if( charset == "iso-8859-1" ) return data;
  if( !cached_decoders[ charset ] )
    cached_decoders[ charset ] = Locale.Charset.decoder( charset );
  data = cached_decoders[ charset ]->feed( data )->drain();
  cached_decoders[ charset ]->flush();
  return data;
}

void create()
{
   SET_LOCALE(default_locale);
  // Dump some programs (for speed)
  dump( "base_server/newdecode.pike" );
  dump( "base_server/read_config.pike" );
  dump( "base_server/global_variables.pike" );
  dump( "base_server/module_support.pike" );
  dump( "base_server/http.pike" );
  dump( "base_server/socket.pike" );
  dump( "base_server/cache.pike" );
  dump( "base_server/supports.pike" );
  dump( "base_server/fonts.pike");
  dump( "base_server/hosts.pike");
  dump( "base_server/language.pike");

#ifndef __NT__
  if(!getuid()) {
    add_constant("Privs", Privs);
  } else
#endif /* !__NT__ */
    add_constant("Privs", class{});

  // for module encoding stuff
  
  add_constant( "Image", Image );
  add_constant( "Image.Image", Image.Image );
  add_constant( "Image.Font", Image.Font );
  add_constant( "Image.Colortable", Image.Colortable );
  add_constant( "Image.Color", Image.Color );
  add_constant( "Image.GIF.encode", Image.GIF.encode );
  add_constant( "Image.Color.Color", Image.Color.Color );
  add_constant( "roxen.argcache", argcache );
  add_constant( "ArgCache", ArgCache );
  add_constant( "Regexp", Regexp );
  add_constant( "Stdio.File", Stdio.File );
  add_constant( "Stdio.stdout", Stdio.stdout );
  add_constant( "Stdio.stderr", Stdio.stderr );
  add_constant( "Stdio.stdin", Stdio.stdin );
  add_constant( "Stdio.read_bytes", Stdio.read_bytes );
  add_constant( "Stdio.write_file", Stdio.write_file );
  add_constant( "Stdio.sendfile", Stdio.sendfile );
  add_constant( "Process.create_process", Process.create_process );
  add_constant( "roxen.load_image", load_image );
#if constant(Thread.Mutex)
  add_constant( "Thread.Mutex", Thread.Mutex );
  add_constant( "Thread.Queue", Thread.Queue );
#endif

  add_constant( "roxen", this_object());
  add_constant( "roxen.decode_charset", decode_charset);
  add_constant( "RequestID", RequestID);
  add_constant( "load",    load);
  add_constant( "Roxen.set_locale", set_locale );
  add_constant( "Roxen.locale", locale );
  add_constant( "Locale.Roxen", Locale.Roxen );
  add_constant( "Locale.Roxen.standard", Locale.Roxen.standard );
  add_constant( "Locale.Roxen.standard.register_module_doc", 
                 Locale.Roxen.standard.register_module_doc );
  add_constant( "roxen.ImageCache", ImageCache );
  // compatibility
  add_constant( "hsv_to_rgb",  Colors.hsv_to_rgb  );
  add_constant( "rgb_to_hsv",  Colors.rgb_to_hsv  );
  add_constant( "parse_color", Colors.parse_color );
  add_constant( "color_name",  Colors.color_name  );
  add_constant( "colors",      Colors             );
  add_constant( "roxen.fonts", (fonts = (object)"fonts.pike") );
  Configuration = (program)"configuration";
  if(!file_stat( "base_server/configuration.pike.o" ) ||
     file_stat("base_server/configuration.pike.o")[ST_MTIME] <
     file_stat("base_server/configuration.pike")[ST_MTIME])
  {
    Stdio.write_file( "base_server/configuration.pike.o", 
                      encode_value( Configuration, Codec( Configuration ) ) );
  }
  add_constant("Configuration", Configuration );

  call_out(post_create,1); //we just want to delay some things a little
}



// Set the uid and gid to the ones requested by the user. If the sete*
// functions are available, and the define SET_EFFECTIVE is enabled,
// the euid and egid is set. This might be a minor security hole, but
// it will enable roxen to start CGI scripts with the correct
// permissions (the ones the owner of that script have).

int set_u_and_gid()
{
#ifndef __NT__
  string u, g;
  int uid, gid;
  array pw;
  
  u=QUERY(User);
  sscanf(u, "%s:%s", u, g);
  if(strlen(u))
  {
    if(getuid())
    {
      report_error ("It is only possible to change uid and gid if the server "
		    "is running as root.\n");
    } else {
      if (g) {
#if constant(getgrnam)
	pw = getgrnam (g);
	if (!pw)
	  if (sscanf (g, "%d", gid)) pw = getgrgid (gid), g = (string) gid;
	  else report_error ("Couldn't resolve group " + g + ".\n"), g = 0;
	if (pw) g = pw[0], gid = pw[2];
#else
	if (!sscanf (g, "%d", gid))
	  report_warning ("Can't resolve " + g + " to gid on this system; "
			  "numeric gid required.\n");
#endif
      }

      pw = getpwnam (u);
      if (!pw)
	if (sscanf (u, "%d", uid)) pw = getpwuid (uid), u = (string) uid;
	else {
	  report_error ("Couldn't resolve user " + u + ".\n");
	  return 0;
	}
      if (pw) {
	u = pw[0], uid = pw[2];
	if (!g) gid = pw[3];
      }

#ifdef THREADS
      object mutex_key;
      catch { mutex_key = euid_egid_lock->lock(); };
      object threads_disabled = _disable_threads();
#endif

#if constant(seteuid)
      if (geteuid() != getuid()) seteuid (getuid());
#endif

#if constant(initgroups)
      catch {
	initgroups(pw[0], gid);
	// Doesn't always work - David.
      };
#endif

      if (QUERY(permanent_uid)) {
#if constant(setuid)
	if (g) {
#  if constant(setgid)
	  setgid(gid);
	  if (getgid() != gid) report_error ("Failed to set gid.\n"), g = 0;
#  else
	  report_warning ("Setting gid not supported on this system.\n");
	  g = 0;
#  endif
	}
	setuid(uid);
	if (getuid() != uid) report_error ("Failed to set uid.\n"), u = 0;
	if (u) report_notice(LOCALE->setting_uid_gid_permanently (uid, gid, u, g));
#else
	report_warning ("Setting uid not supported on this system.\n");
	u = g = 0;
#endif
      }
      else {
#if constant(seteuid)
	if (g) {
#  if constant(setegid)
	  setegid(gid);
	  if (getegid() != gid) report_error ("Failed to set effective gid.\n"), g = 0;
#  else
	  report_warning ("Setting effective gid not supported on this system.\n");
	  g = 0;
#  endif
	}
	seteuid(uid);
	if (geteuid() != uid) report_error ("Failed to set effective uid.\n"), u = 0;
	if (u) report_notice(LOCALE->setting_uid_gid (uid, gid, u, g));
#else
	report_warning ("Setting effective uid not supported on this system.\n");
	u = g = 0;
#endif
      }

      return !!u;
    }
  }
#endif
  return 0;
}

void reload_all_configurations()
{
  object conf;
  array (object) new_confs = ({});
  mapping config_cache = ([]);
  int modified;

  report_notice(LOCALE->reloading_config_interface());
  configs = ([]);
  setvars(retrieve("Variables", 0));

  foreach(list_all_configurations(), string config)
  {
    array err, st;
    foreach(configurations, conf)
    {
      if(lower_case(conf->name) == lower_case(config))
      {
	break;
      } else
	conf = 0;
    }
    if(!(st = config_is_modified(config))) {
      if(conf) {
	config_cache[config] = config_stat_cache[config];
	new_confs += ({ conf });
      }
      continue;
    }
    modified = 1;
    config_cache[config] = st;
    if(conf) {
      // Closing ports...
      if (conf->server_ports) {
	// Roxen 1.2.26 or later
	Array.map(values(conf->server_ports), destruct);
      } else {
	Array.map(indices(conf->open_ports), destruct);
      }
      conf->stop();
      conf->invalidate_cache();
      conf->modules = ([]);
      conf->create(conf->name);
    } else {
      if(err = catch
      {
	conf = enable_configuration(config);
      }) {
	report_error(LOCALE->
		     error_enabling_configuration(config,
						  describe_backtrace(err)));
	continue;
      }
    }
    if(err = catch
    {
      conf->start();
      conf->enable_all_modules();
    }) {
      report_error(LOCALE->
		   error_enabling_configuration(config,
						describe_backtrace(err)));
      continue;
    }
    new_confs += ({ conf });
  }
    
  foreach(configurations - new_confs, conf)
  {
    modified = 1;
    report_notice(LOCALE->disabling_configuration(conf->name));
    Array.map(values(conf->server_ports), destruct);
    conf->stop();
    destruct(conf);
  }
  if(modified) {
    configurations = new_confs;
    config_stat_cache = config_cache;
  }
}

object enable_configuration(string name)
{
  object cf = Configuration( name );
  configurations += ({ cf });
  report_notice( LOCALE->enabled_server(name) );
  return cf;
}

// Enable all configurations
void enable_configurations()
{
  array err;
  configurations = ({});

  foreach(list_all_configurations(), string config)
    if(err=catch( enable_configuration(config)->start() ))
      report_error("Error while loading configuration "+config+":\n"+
                   describe_backtrace(err)+"\n");
}


void enable_configurations_modules()
{
  mixed err;

  foreach(configurations, object config)
    if(err=catch( config->enable_all_modules() ))
      report_error("Error while loading modules in configuration "+
                   config->name+":\n"+describe_backtrace(err)+"\n");
}

array(int) invert_color(array color )
{
  return ({ 255-color[0], 255-color[1], 255-color[2] });
}


mapping low_decode_image(string data, void|array tocolor)
{
  Image.image i, a;
  string format;
  if(!data)
    return 0; 

#if constant(Image.GIF._decode)  
  // Use the low-level decode function to get the alpha channel.
  catch
  {
    array chunks = Image.GIF._decode( data );

    // If there is more than one render chunk, the image is probably
    // an animation. Handling animations is left as an exercise for
    // the reader. :-)
    foreach(chunks, mixed chunk)
      if(arrayp(chunk) && chunk[0] == Image.GIF.RENDER )
        [i,a] = chunk[3..4];
    format = "GIF";
  };

  if(!i) catch
  {
    i = Image.GIF.decode( data );
    format = "GIF";
  };
#endif

#if constant(Image.JPEG) && constant(Image.JPEG.decode)
  if(!i) catch
  {
    i = Image.JPEG.decode( data );
    format = "JPEG";
  };
#endif

#if constant(Image.XCF) && constant(Image.XCF._decode)
  if(!i) catch
  {
    mixed q = Image.XCF._decode( data,(["background":tocolor,]) );
    tocolor=0;
    format = "XCF Gimp file";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.PSD) && constant(Image.PSD._decode)
  if(!i) catch
  {
    mixed q = Image.PSD._decode( data, ([
      "background":tocolor,
      ]));
    tocolor=0;
    format = "PSD Photoshop file";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.PNG) && constant(Image.PNG._decode)
  if(!i) catch
  {
    mixed q = Image.PNG._decode( data );
    format = "PNG";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.BMP) && constant(Image.BMP._decode)
  if(!i) catch
  {
    mixed q = Image.BMP._decode( data );
    format = "Windows bitmap file";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.TGA) && constant(Image.TGA._decode)
  if(!i) catch
  {
    mixed q = Image.TGA._decode( data );
    format = "Targa";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.PCX) && constant(Image.PCX._decode)
  if(!i) catch
  {
    mixed q = Image.PCX._decode( data );
    format = "PCX";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.XBM) && constant(Image.XBM._decode)
  if(!i) catch
  {
    mixed q = Image.XBM._decode( data, (["bg":tocolor||({255,255,255}),
                                    "fg":invert_color(tocolor||({255,255,255})) ]));
    format = "XBM";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.XPM) && constant(Image.XPM._decode)
  if(!i) catch
  {
    mixed q = Image.XPM._decode( data );
    format = "XPM";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.TIFF) && constant(Image.TIFF._decode)
  if(!i) catch
  {
    mixed q = Image.TIFF._decode( data );
    format = "TIFF";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.ILBM) && constant(Image.ILBM._decode)
  if(!i) catch
  {
    mixed q = Image.ILBM._decode( data );
    format = "ILBM";
    i = q->image;
    a = q->alpha;
  };
#endif


#if constant(Image.PS) && constant(Image.PS._decode)
  if(!i) catch
  {
    mixed q = Image.PS._decode( data );
    format = "Postscript";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.XWD) && constant(Image.XWD.decode)
  if(!i) catch
  {
    i = Image.XWD.decode( data );
    format = "XWD";
  };
#endif

#if constant(Image.HRZ) && constant(Image.HRZ._decode)
  if(!i) catch
  {
    mixed q = Image.HRZ._decode( data );
    format = "HRZ";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.AVS) && constant(Image.AVS._decode)
  if(!i) catch
  {
    mixed q = Image.AVS._decode( data );
    format = "AVS X";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.PNM)
  if(!i)
    catch{
      i = Image.PNM.decode( data );
      format = "PNM";
    };
#endif

  if(!i) // No image could be decoded at all. 
    return 0;

  if( tocolor && i && a )
  {
    object o = Image.image( i->xsize(), i->ysize(), @tocolor );
    o->paste_mask( i,a );
    i = o;
  }

  return ([
    "format":format,
    "alpha":a,
    "img":i,
  ]);
}

mapping low_load_image(string f,object id)
{
  string data;
  object file, img;
  if(id->misc->_load_image_called < 5) 
  {
    // We were recursing very badly with the demo module here...
    id->misc->_load_image_called++;
    if(!(data=id->conf->try_get_file(f, id)))
    {
      file=Stdio.File();
      if(!file->open(f,"r") || !(data=file->read()))
	return 0;
    }
  }
  id->misc->_load_image_called = 0;
  if(!data)  return 0;
  return low_decode_image( data );
}



object load_image(string f,object id)
{
  mapping q = low_load_image( f, id );
  if( q ) return q->img;
  return 0;
}

// do the chroot() call. This is not currently recommended, since
// roxen dynamically loads modules, all module files must be
// available at the new location.

private void fix_root(string to)
{
#ifndef __NT__
  if(getuid())
  {
    perror("It is impossible to chroot() if the server is not run as root.\n");
    return;
  }

  if(!chroot(to))
  {
    perror("Roxen: Cannot chroot to "+to+": ");
#if efun(real_perror)
    real_perror();
#endif
    return;
  }
  perror("Root is now "+to+".\n");
#endif
}

void create_pid_file(string where)
{
#ifndef __NT__
  if(!where) return;
  where = replace(where, ({ "$pid", "$uid" }), 
		  ({ (string)getpid(), (string)getuid() }));

  rm(where);
  if(catch(Stdio.write_file(where, sprintf("%d\n%d", getpid(), getppid()))))
    perror("I cannot create the pid file ("+where+").\n");
#endif
}

program pipe;
object shuffle(object from, object to,
	       object|void to2, function(:void)|void callback)
{
#if efun(spider.shuffle)
  if(!to2)
  {
    if(!pipe)
      pipe = ((program)"smartpipe");
    object p = pipe( );
    p->input(from);
    p->set_done_callback(callback);
    p->output(to);
    return p;
  } else {
#endif
    // 'smartpipe' does not support multiple outputs.
    object p = Pipe.pipe();
    if (callback) p->set_done_callback(callback);
    p->output(to);
    if(to2) p->output(to2);
    p->input(from);
    return p;
#if efun(spider.shuffle)
  }
#endif
}


static private int _recurse;
// FIXME: Ought to use the shutdown code.
void exit_when_done()
{
  object o;
  int i;
  roxen_perror("Interrupt request received. Exiting,\n");
  die_die_die=1;

  if(++_recurse > 4)
  {
    roxen_perror("Exiting roxen (spurious signals received).\n");
    configurations->stop();
#ifdef THREADS
    stop_handler_threads();
#endif /* THREADS */
    exit(-1);	// Restart.
  }
  
  roxen_perror("Exiting roxen.\n");
  configurations->stop();
#ifdef THREADS
  stop_handler_threads();
#endif /* THREADS */
  exit(-1);	// Restart.
}

void exit_it()
{
  perror("Recursive signals.\n");
  exit(-1);	// Restart.
}

void set_locale( string to )
{
  if( to == "standard" )
    SET_LOCALE( default_locale );
  SET_LOCALE( Locale.Roxen[ to ] || default_locale );
}


// Dump all threads to the debug log.
void describe_all_threads()
{
  array(mixed) all_backtraces;
#if constant(all_threads)
  all_backtraces = all_threads()->backtrace();
#else /* !constant(all_threads) */
  all_backtraces = ({ backtrace() });
#endif /* constant(all_threads) */

  werror("Describing all threads:\n");
  int i;
  for(i=0; i < sizeof(all_backtraces); i++) {
    werror(sprintf("Thread %d:\n"
		   "%s\n",
		   i+1,
		   describe_backtrace(all_backtraces[i])));
  }
}


void dump( string file )
{
  program p = master()->programs[ replace(getcwd() +"/"+ file , "//", "/" ) ];
  array q;
  if(!p)
  {
#ifdef DUMP_DEBUG
    report_debug(file+" not loaded, and thus cannot be dumped.\n");
#endif
    return;
  }

  if(!file_stat( file+".o" ) ||
     (file_stat(file+".o")[ST_MTIME] < file_stat(file)[ST_MTIME]))
  {
    if(q=catch{
      Stdio.write_file(file+".o",encode_value(p,Codec(p)));
#ifdef DUMP_DEBUG
      report_debug( file+" dumped successfully to "+file+".o\n" );
#endif
    })
      report_debug("** Cannot encode "+file+": "+describe_backtrace(q)+"\n");
  }
#ifdef DUMP_DEBUG
  else
      report_debug(file+" already dumped (and up to date)\n");
#endif
}

int main(int argc, array argv)
{
//   dump( "base_server/disk_cache.pike");
// cannot encode this one yet...

  call_out( lambda() {
              ((program)"fastpipe"),
              ((program)"slowpipe"),

              dump( "protocols/http.pike");
              dump( "protocols/ftp.pike");
              dump( "protocols/https.pike");

              dump( "base_server/state.pike" );
              dump( "base_server/struct/node.pike" );
              dump( "base_server/persistent.pike");
              dump( "base_server/restorable.pike");
              dump( "base_server/highlight_pike.pike");
              dump( "base_server/dates.pike");
              dump( "base_server/wizard.pike" );
              dump( "base_server/proxyauth.pike" );
              dump( "base_server/html.pike" );
              dump( "base_server/module.pike" );
              dump( "base_server/throttler.pike" );
              dump( "base_server/smartpipe.pike" );
              dump( "base_server/slowpipe.pike" );
              dump( "base_server/fastpipe.pike" );
            }, 9);


  switch(getenv("LANG"))
  {
   case "sv":
     default_locale = Locale.Roxen["svenska"];
     break;
   case "jp":
     default_locale = Locale.Roxen["nihongo"];
     break;
  }
  SET_LOCALE(default_locale);
  initiate_languages();
  mixed tmp;
  
  mark_fd(0, "Stdin");
  mark_fd(1, "Stdout");
  mark_fd(2, "Stderr");

  configuration_dir =
    Getopt.find_option(argv, "d",({"config-dir","configuration-directory" }),
	     ({ "ROXEN_CONFIGDIR", "CONFIGURATIONS" }), "../configurations");

  if(configuration_dir[-1] != '/')
    configuration_dir += "/";

  // Dangerous...
  if(tmp = Getopt.find_option(argv, "r", "root")) fix_root(tmp);

  argv -= ({ 0 });
  argc = sizeof(argv);

  define_global_variables(argc, argv);

  object o;
  if(QUERY(locale) != "standard" && (o = Locale.Roxen[QUERY(locale)]))
  {
    default_locale = o;
    SET_LOCALE(default_locale);
  }
#if efun(syslog)
  init_logger();
#endif
  init_garber();
  initiate_supports();
  enable_configurations();

  set_u_and_gid(); // Running with the right [e]uid:[e]gid from this point on.

  create_pid_file(Getopt.find_option(argv, "p", "pid-file", "ROXEN_PID_FILE")
		  || QUERY(pidfile));

  roxen_perror("Initiating argument cache ... ");

  int id;
  string cp = QUERY(argument_cache_dir), na = "args";
  if( QUERY(argument_cache_in_db) )
  {
    id = 1;
    cp = QUERY(argument_cache_db_path);
    na = "argumentcache";
  }
  mixed e;
  e = catch( argcache = ArgCache(na,cp,id) );
  if( e )
  {
    report_error( "Failed to initialize the global argument cache:\n"
                  + (describe_backtrace( e )/"\n")[0]+"\n");
    werror( describe_backtrace( e ) );
  }
  roxen_perror( "\n" );

  enable_configurations_modules();
  
  call_out(update_supports_from_roxen_com,
	   QUERY(next_supports_update)-time());
  
#ifdef THREADS
  start_handler_threads();
  catch( this_thread()->set_name("Backend") );
  backend_thread = this_thread();
#endif /* THREADS */

  // Signals which cause a restart (exitcode != 0)
  foreach( ({ "SIGINT", "SIGTERM" }), string sig)
    catch( signal(signum(sig), exit_when_done) );

  catch( signal(signum("SIGHUP"), reload_all_configurations) );

  // Signals which cause Roxen to dump the thread state
  foreach( ({ "SIGUSR1", "SIGUSR2", "SIGTRAP" }), string sig)
    catch( signal(signum(sig), describe_all_threads) );

#ifdef __RUN_TRACE
  trace(1);
#endif
  start_time=time();		// Used by the "uptime" info later on.
  return -1;
}

string diagnose_error(array from)
{
}

// Called from the configuration interface.
string check_variable(string name, mixed value)
{
  switch(name)
  {
   case "ConfigurationURL":
   case "MyWorldLocation":
    if(strlen(value)<7 || value[-1] != '/' ||
       !(sscanf(value,"%*s://%*s/")==2))
      return(LOCALE->url_format());
    break;

   case "abs_engage":
    if (value)
      restart_if_stuck(1);
    else 
      remove_call_out(restart_if_stuck);
    break;

   case "suicide_engage":
    if (value) 
      call_out(restart,60*60*24*QUERY(suicide_timeout));
    else
      remove_call_out(restart);
    break;
   case "locale":
     object o;
     if(value != "standard" && (o = Locale.Roxen[value]))
     {
       default_locale = o;
       SET_LOCALE(default_locale);
     }
     break;
  }
}

mapping config_cache = ([ ]);
mapping host_accuracy_cache = ([]);
int is_ip(string s)
{
  return (replace(s,"0123456789."/"",({""})*11) == "");
}
