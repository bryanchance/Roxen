// This is a roxen module.
// Modified by Francesco Chemolli to add throttling capabilities.
// Copyright � 1996 - 1998, Idonex AB.
// $Id: http.pike,v 1.165 1999/10/12 13:19:18 per Exp $

#define MAGIC_ERROR

#ifdef MAGIC_ERROR
inherit "highlight_pike";
#endif
constant cvs_version = "$Id: http.pike,v 1.165 1999/10/12 13:19:18 per Exp $";
// HTTP protocol module.
#include <config.h>
private inherit "roxenlib";



#ifdef PROFILE
#define HRTIME() gethrtime()
#define HRSEC(X) ((int)((X)*1000000))
#define SECHR(X) ((X)/(float)1000000)
int req_time = HRTIME();
#endif

#ifdef REQUEST_DEBUG
int footime, bartime;
#define DPERROR(X)	bartime = gethrtime()-footime; werror("%s (%d)\n", (X), bartime);footime=gethrtime()
#else
#define DPERROR(X)
#endif

#ifdef FD_DEBUG
#define MARK_FD(X) catch{DPERROR(X); mark_fd(my_fd->query_fd(), (X)+" "+remoteaddr);}
#else
#define MARK_FD(X) DPERROR(X)
#endif

constant decode        = MIME.decode_base64;
constant find_supports = roxen.find_supports;
constant version       = roxen.version;
constant _query        = roxen.query;
constant _time         = predef::time;

private static array(string) cache;
private static int wanted_data, have_data;

object conf;
object port_obj;

#include <roxen.h>
#include <module.h>

#undef QUERY
#if constant(cpp)
#define QUERY(X)	_query( #X )
#else /* !constant(cpp) */
#define QUERY(X) 	_query("X")
#endif /* constant(cpp) */

int time;
string raw_url;
int do_not_disconnect;
mapping (string:string) variables       = ([ ]);
mapping (string:mixed)  misc            = ([ ]);
mapping (string:string) cookies         = ([ ]);
mapping (string:string) request_headers = ([ ]);

multiset (string) prestate  = (< >);
multiset (string) config    = (< >);
multiset (string) supports  = (< >);
multiset (string) pragma    = (< >);

string remoteaddr, host;

array  (string) client;
array  (string) referer;

mapping file;

object my_fd; /* The client. */

string prot;
string clientprot;
string method;

string realfile, virtfile;
string rest_query="";
string raw;
string query;
string not_query;
string extra_extension = ""; // special hack for the language module
string data, leftovers;
array (int|string) auth;
string rawauth, realauth;
string since;

// Parse a HTTP/1.1 HTTP/1.0 or 0.9 request, including form data and
// state variables.  Return 0 if more is expected, 1 if done, and -1
// if fatal error.

void end(string|void a,int|void b);

object pipe;

//used values: throttle->doit=0|1 to enable it
//             throttle->rate the rate
//             throttle->fixed if it's not to be touched again
mapping throttle=([]);

object throttler;//the inter-request throttling object.

/* Pipe-using send functions */

// FIXME:
//I'm choosing the pipe type upon setup. Thus I'm assuming that all headers
//have been defined before then. This is actually not true in case
//of throttling and keep-alive. We'll take care of that later.
private void setup_pipe()
{
  if(!my_fd) {
    end();
    return;
  }
  if (!conf || !conf->query("req_throttle"))
    throttle->doit=0;
  if(!pipe) {
    if (throttle->doit || (conf && conf->throttler)) {
      pipe=((program)"slowpipe")();
    } else {
      pipe=((program)"fastpipe")();
    }
  }
  if (throttle->doit) {
    throttle->rate=max(throttle->rate,
             conf->query("req_throttle_min")); //if conf=0 => throttle=0
    pipe->throttle(throttle->rate,
                   (int)(throttle->rate*conf->query("req_throttle_depth_mult")),
                   0);
  }
  if (conf && conf->throttler) { 
    pipe->assign_throttler(conf->throttler);
  }
}


void send (string|object what, int|void len)
{
#ifdef REQUEST_DEBUG
  roxen_perror(sprintf("send(%O, %O)\n", what, len));
#endif /* REQUEST_DEBUG */

  if(!what) return;
  if(!pipe) setup_pipe();
  if(!pipe) return;
  if(stringp(what))  pipe->write(what);
  else               pipe->input(what,len);
}

void start_sender (function callback, mixed ... args)
{
  if (pipe) {
    MARK_FD("HTTP really handled, piping "+not_query);
#ifdef FD_DEBUG
    call_out(timer, 30, _time(1)); // Update FD with time...
#endif
    // FIXME: What about args?
    pipe->set_done_callback( callback );
    pipe->output(my_fd);
  } else {
    MARK_FD("HTTP really handled, pipe done");
    callback(@args);
  }
}

string scan_for_query( string f )
{
  if(sscanf(f,"%s?%s", f, query) == 2)
  {
    string v, a, b;

    foreach(query / "&", v)
      if(sscanf(v, "%s=%s", a, b) == 2)
      {
	a = http_decode_string(replace(a, "+", " "));
	b = http_decode_string(replace(b, "+", " "));
	
	if(variables[ a ])
	  variables[ a ] +=  "\0" + b;
	else
	  variables[ a ] = b;
      } else
	if(strlen( rest_query ))
	  rest_query += "&" + http_decode_string( v );
	else
	  rest_query = http_decode_string( v );
    rest_query=replace(rest_query, "+", "\000"); /* IDIOTIC STUPID STANDARD */
  }
  return f;
}


private int really_set_config(array mod_config)
{
  string url, m;
  string base;
  base = conf->query("MyWorldLocation")||"/";
  if(supports->cookies)
  {
#ifdef REQUEST_DEBUG
    perror("Setting cookie..\n");
#endif
    if(mod_config)
      foreach(mod_config, m)
	if(m[-1]=='-')
	  config[m[1..]]=0;
	else
	  config[m]=1;
      
    if(sscanf(replace(raw_url,({"%3c","%3e","%3C","%3E" }),
		      ({"<",">","<",">"})),"/<%*s>/%s",url)!=2)
      url = "/";

    if ((base[-1] == '/') && (strlen(url) && url[0] == '/')) {
      url = base + url[1..];
    } else {
      url = base + url;
    }

    my_fd->write(prot + " 302 Config in cookie!\r\n"
		 "Set-Cookie: "
		  + http_roxen_config_cookie(indices(config) * ",") + "\r\n"
		 "Location: " + url + "\r\n"
		 "Content-Type: text/html\r\n"
		 "Content-Length: 0\r\n\r\n");
  } else {
#ifdef REQUEST_DEBUG
    perror("Setting {config} for user without Cookie support..\n");
#endif
    if(mod_config)
      foreach(mod_config, m)
	if(m[-1]=='-')
	  prestate[m[1..]]=0;
	else
	  prestate[m]=1;
      
    if (sscanf(replace(raw_url, ({ "%3c", "%3e", "%3C", "%3E" }), 
		       ({ "<", ">", "<", ">" })),   "/<%*s>/%s", url) == 2) {
      url = "/" + url;
    }
    if (sscanf(replace(url, ({ "%28", "%29" }), ({ "(", ")" })),
	       "/(%*s)/%s", url) == 2) {
      url = "/" + url;
    }

    url = add_pre_state(url, prestate);

    if (base[-1] == '/') {
      url = base + url[1..];
    } else {
      url = base + url;
    }

    my_fd->write(prot + " 302 Config In Prestate!\r\n"
		 "\r\nLocation: " + url + "\r\n"
		 "Content-Type: text/html\r\n"
		 "Content-Length: 0\r\n\r\n");
  }
  return 2;
}

private static mixed f, line;
private static int hstart;

private int parse_got()
{
  multiset (string) sup;
  array mod_config;
  string a, b, s="", linename, contents;
  int config_in_url;

  DPERROR(sprintf("HTTP: parse_got(%O)", raw));
  if (!method) {  // Haven't parsed the first line yet.  
    // We check for \n only if \r\n fails, since Netscape 4.5 sends
    // just a \n when doing a proxy-request. 
    // example line:
    //   "CONNECT mikabran:443 HTTP/1.0\n"
    //   "User-Agent: Mozilla/4.5 [en] (X11; U; Linux 2.0.35 i586)"
    // Die Netscape, die! *grumble*
    // Luckily the solution below shouldn't ever cause any slowdowns
    
    if (!sscanf(raw, "%s\r\n%s", line, s) &&
	!sscanf(raw, "%s\n%s", line, s)) {
      // Not enough data. Unless the client writes one byte at a time,
      // this should never happen, really.
      
      DPERROR(sprintf("HTTP: parse_got(%O): Not enough data.", raw));
      return 0;
    }
    if(strlen(line) < 4)
    {
      // Incorrect request actually - min possible (HTTP/0.9) is "GET /"
      // but need to support PING of course!
      
      DPERROR(sprintf("HTTP: parse_got(%O): Malformed request.", raw));
      return 1;
    }

    string trailer, trailer_trailer;
    switch(sscanf(line+" ", "%s %s %s %s %s",
		  method, f, clientprot, trailer, trailer_trailer))
    {
    case 5:
      // Stupid sscanf!
      if (trailer_trailer != "") {
	// Get rid of the extra space from the sscanf above.
	trailer += " " + trailer_trailer[..sizeof(trailer_trailer)-2];
      }
      /* FALL_THROUGH */
    case 4:
      // Got extra spaces in the URI.
      // All the extra stuff is now in the trailer.

      // Get rid of the extra space from the sscanf above.
      trailer = trailer[..sizeof(trailer) - 2];
      f += " " + clientprot;

      // Find the last space delimiter.
      int end;
      if (!(end = (search(reverse(trailer), " ") + 1))) {
        // Just one space in the URI.
        clientprot = trailer;
      } else {
        f += " " + trailer[..sizeof(trailer) - (end + 1)];
        clientprot = trailer[sizeof(trailer) - end ..];
      }
      /* FALL_THROUGH */
    case 3:
      // >= HTTP/1.0

      prot = clientprot;
      // method = upper_case(p1);
      if(!(< "HTTP/1.0", "HTTP/1.1" >)[prot]) {
	// We're nice here and assume HTTP even if the protocol
	// is something very weird.
	prot = "HTTP/1.1";
      }

      // Do we have all the headers?
      if (!sscanf(raw, "%s\r\n\r\n%s", s, data)) {
	// No, we need more data.
	DPERROR("HTTP: parse_got(): Request is not complete.");
	return 0;
      }
      // Remove the first line (ie the command).
      // Note: This works since both \r\n and \n end with \n..
      if (!sscanf(s, "%*s\n%s", s)) {
	s = "";
      }
      // s now contains the unparsed headers.
      break;

    case 2:
      // HTTP/0.9
      clientprot = prot = "HTTP/0.9";
      if(method != "PING")
	method = "GET"; // 0.9 only supports get.
      s = data = ""; // no headers or extra data...
      break;

    case 1:
      // PING...
      if(method == "PING") 
	break;
      // only PING is valid here.
      return 1;
      
    default:
      // Too many or too few entries ->  Hum.
      return 1;
    }
  } else {
    // HTTP/1.0 or later
    // Check that the request is complete
    if (!sscanf(raw, "%s\r\n\r\n%s", s, data)) {
      // No, we need more data.
      DPERROR("HTTP: parse_got(): Request is still not complete.");
      return 0;
    }
  }
  if(method == "PING") {
    my_fd->write("PONG\r\n"); 
    return 2;
  }
  
  raw_url    = f;
  time       = _time(1);
  // if(!data) data = "";
  DPERROR(sprintf("RAW_URL:%O", raw_url));

  if(!remoteaddr)
  {
    if(my_fd) {
      remoteaddr = my_fd->query_address();
      if(remoteaddr) 
      	sscanf(remoteaddr, "%s %*s", remoteaddr);
    }
    if(!remoteaddr) {
      DPERROR("HTTP: parse_request(): No remote address.");
      end();
      return 2;
    }
  }

  DPERROR(sprintf("After Remote Addr:%O", f));
  
  f = scan_for_query( f );

  DPERROR(sprintf("After query scan:%O", f));

  f = http_decode_string( f );
  string prf = f[1..1];
  if (prf == "<" && sscanf(f, "/<%s>/%s", a, f)==2)
  {
    config_in_url = 1;
    mod_config = (a/",");
    f = "/"+f;
  }

  DPERROR(sprintf("After cookie scan:%O", f));
  
  if (prf == "(" && (sscanf(f, "/(%s)/%s", a, f)==2) && strlen(a))
  {
    prestate = aggregate_multiset(@(a/","-({""})));
    f = "/"+f;
  }

  DPERROR(sprintf("After prestate scan:%O", f));
  
  not_query = simplify_path(f);

  DPERROR(sprintf("After simplify_path == not_query:%O", not_query));

  request_headers = ([]);	// FIXME: KEEP-ALIVE?

  if(sizeof(s)) {
    //    sscanf(s, "%s\r\n\r\n%s", s, data);
    //     s = replace(s, "\n\t", ", ") - "\r"; 
    //     Handle rfc822 continuation lines and strip \r
    foreach(s/"\r\n" - ({""}), line)
    {
      //      DPERROR(sprintf("Header :%s", line));
      //      linename=contents=0;
      
      if(sscanf(line, "%s:%*[ \t]%s", linename, contents) == 3)
      {
      	DPERROR(sprintf("Header-sscanf :%s", linename));
      	linename=lower_case(linename);
      	DPERROR(sprintf("lower-case :%s", linename));

	// FIXME: Multiple headers?
      	request_headers[linename] = contents;
	if(strlen(contents))
	{
	  switch (linename) {
	  case "content-length":
	    misc->len = (int)contents;
	    if(!misc->len) continue;
	    if(method == "POST")
	    {
	      if(!data) data="";
	      int l = misc->len;
	      wanted_data=l;
	      have_data=strlen(data);

	      if(strlen(data) < l) 
              {
		DPERROR("HTTP: parse_request(): More data needed in POST.");
		return 0;
	      }
	      leftovers = data[l+2..];
	      data = data[..l+1];

	      switch(lower_case((((misc["content-type"]||"")+";")/";")[0]-" "))
	      {
	      default: // Normal form data.
		string v;
		if(l < 200000)
		{
		  foreach(replace(data,
				  ({ "\n", "\r", "+" }),
				  ({ "", "", " "}))/"&", v)
		    if(sscanf(v, "%s=%s", a, b) == 2)
		    {
		      a = http_decode_string( a );
		      b = http_decode_string( b );
		     
		      if(variables[ a ])
			variables[ a ] +=  "\0" + b;
		      else
			variables[ a ] = b;
		    }
		}
		break;

	      case "multipart/form-data":
		//		perror("Multipart/form-data post detected\n");
		object messg = MIME.Message(data, misc);
		foreach(messg->body_parts, object part) {
		  if(part->disp_params->filename) {
		    variables[part->disp_params->name]=part->getdata();
		    variables[part->disp_params->name+".filename"]=
		      part->disp_params->filename;
		    if(!misc->files)
		      misc->files = ({ part->disp_params->name });
		    else
		      misc->files += ({ part->disp_params->name });
		  } else {
		    if(variables[part->disp_params->name])
		      variables[part->disp_params->name] += "\0" + part->getdata();
		    else
		      variables[part->disp_params->name] = part->getdata();
		  }
		}
		break;
	      }
	    }
	    break;
	  
	  case "authorization":
	    rawauth = contents;
	    break;
	  
	  case "proxy-authorization":
	    array y;
	    y = contents / " ";
	    if(sizeof(y) < 2)
	      break;
	    y[1] = decode(y[1]);
	    misc->proxyauth=y;
	    break;
	  
	  case "pragma":
	    pragma|=aggregate_multiset(@replace(contents, " ", "")/ ",");
	    break;

	  case "user-agent":
	    if(!client)
	    {
	      sscanf(contents, "%s via", contents);
	      client = contents/" " - ({ "" });
	    }
	    break;

	    /* Some of M$'s non-standard user-agent info */
	  case "ua-pixels":	/* Screen resolution */
	  case "ua-color":	/* Color scheme */
	  case "ua-os":	/* OS-name */
	  case "ua-cpu":	/* CPU-type */
	    misc[linename - "ua-"] = contents ;
	    break;

	  case "referer":
	    referer = contents/" ";
	    break;
	    
	  case "extension":
#ifdef DEBUG
          perror("Client extension: "+contents+"\n");
#endif
	  case "request-range":
	    contents = lower_case(contents-" ");
	    if(!search(contents, "bytes")) 
	      // Only care about "byte" ranges.
	      misc->range = contents[6..];
	    break;
	    
	  case "range":
	    contents = lower_case(contents-" ");
	    if(!misc->range && !search(contents, "bytes"))
	      // Only care about "byte" ranges. Also the Request-Range header
	      // has precedence since Stupid Netscape (TM) sends both but can't
	      // handle multipart/byteranges but only multipart/x-byteranges.
	      // Duh!!!
	      misc->range = contents[6..];
	    break;
	      
	  case "connection":
	  case "content-type":
	    misc[linename] = lower_case(contents);
	    break;

	  case "accept-encoding":
	    foreach((contents-" ")/",", string e) {
	      if (lower_case(e) == "gzip") {
		supports["autogunzip"] = 1;
	      }
	    }
	  case "accept":
	  case "accept-charset":
	  case "accept-language":
	  case "session-id":
	  case "message-id":
	  case "from":
	    if(misc[linename])
	      misc[linename] += (contents-" ") / ",";
	    else
	      misc[linename] = (contents-" ") / ",";
	    break;

	  case "cookie": /* This header is quite heavily parsed */
	    string c;
	    misc->cookies = contents;
	    if (!sizeof(contents)) {
	      // Needed for the new Pike 0.6
	      break;
	    }
	    foreach(((contents/";") - ({""})), c)
	    {
	      string name, value;
	      while(sizeof(c) && c[0]==' ') c=c[1..];
	      if(sscanf(c, "%s=%s", name, value) == 2)
	      {
		value=http_decode_string(value);
		name=http_decode_string(name);
		cookies[ name ]=value;
		if(name == "RoxenConfig" && strlen(value))
		{
		  array tmpconfig = value/"," + ({ });
		  string m;

		  if(mod_config && sizeof(mod_config))
		    foreach(mod_config, m)
		      if(!strlen(m))
		      { continue; } /* Bug in parser force { and } */
		      else if(m[0]=='-')
			tmpconfig -= ({ m[1..] });
		      else
			tmpconfig |= ({ m });
		  mod_config = 0;
		  config = aggregate_multiset(@tmpconfig);
		}
	      }
	    }
	    break;

	  case "host":
	  case "proxy-connection":
	  case "security-scheme":
	  case "via":
	  case "cache-control":
	  case "negotiate":
	  case "forwarded":
	  case "new-uri":
	    misc[linename]=contents;
	    break;	    

	  case "proxy-by":
	  case "proxy-maintainer":
	  case "proxy-software":
	  case "mime-version":
	    break;
	    
	  case "if-modified-since":
	    since=contents;
	    break;
	  }
	}
      }
    }
  }

  DPERROR("HTTP: parse_got(): after header scan");
#ifndef DISABLE_SUPPORTS    
  if(!client) {
    client = ({ "unknown" });
    supports = find_supports("", supports); // This makes it somewhat faster.
  } else 
    supports = find_supports(lower_case(client*" "), supports);
#else
  supports = (< "images", "gifinline", "forms", "mailto">);
#endif
  DPERROR("HTTP: parse_got(): supports");
  if(!referer) referer = ({ });
  if(misc->proxyauth) {
    // The Proxy-authorization header should be removed... So there.
    mixed tmp1,tmp2;
    
    foreach(tmp2 = (raw / "\n"), tmp1) {
      if(!search(lower_case(tmp1), "proxy-authorization:"))
	tmp2 -= ({tmp1});
    }
    raw = tmp2 * "\n"; 
  }
  if(config_in_url) {
    DPERROR("HTTP: parse_got(): config_in_url");
    return really_set_config( mod_config );
  }
  if(!supports->cookies)
    config = prestate;
  else
    if(conf
       && QUERY(set_cookie)
       && !cookies->RoxenUserID && strlen(not_query)
       && not_query[0]=='/' && method!="PUT")
    {
      if (!(QUERY(set_cookie_only_once) &&
	    cache_lookup("hosts_for_cookie",remoteaddr))) {
	misc->moreheads = ([ "Set-Cookie":http_roxen_id_cookie(), ]);
      }
      if (QUERY(set_cookie_only_once))
	cache_set("hosts_for_cookie",remoteaddr,1);
    }
  return 3;	// Done.
}

void disconnect()
{
  file = 0;
#ifdef REQUEST_DEBUG
  if (my_fd) MARK_FD("my_fd in HTTP disconnected?");
#endif
  if(do_not_disconnect)return;
  destruct();
}

void end(string|void s, int|void keepit)
{
  pipe = 0;
#ifdef PROFILE
  if(conf)
  {
    float elapsed = SECHR(HRTIME()-req_time);
    string nid =
#ifdef FILE_PROFILE
      not_query
#else
      dirname(not_query)
#endif
      ;
    array p;
    if(!(p=conf->profile_map[nid]))
      p = conf->profile_map[nid] = ({0,0.0,0.0});
    p[0]++;
    p[1] += elapsed;
    if(elapsed > p[2]) p[2]=elapsed;
  }
#endif

#ifdef KEEP_ALIVE
  if(keepit &&
     (!(file->raw || file->len <= 0))
     && (misc->connection == "keep-alive" ||
	 (prot == "HTTP/1.1" && misc->connection != "close"))
     && my_fd)
  {
    // Now.. Transfer control to a new http-object. Reset all variables etc..
    object o = object_program(this_object())();
    o->remoteaddr = remoteaddr;
    o->supports = supports;
    o->host = host;
    o->client = client;
    MARK_FD("HTTP kept alive");
    object fd = my_fd;
    my_fd=0;
    if(s) leftovers += s;
    o->chain(fd,port_obj,leftovers);
    disconnect();
    return;
  }
#endif

  if(objectp(my_fd))
  {
    MARK_FD("HTTP closed");
    catch {
      my_fd->set_close_callback(0);
      my_fd->set_read_callback(0);
      my_fd->set_blocking();
      if(s) my_fd->write(s);
      my_fd->close();
      destruct(my_fd);
    };
    my_fd = 0;
  }
  disconnect();  
}

static void do_timeout()
{
  // werror("do_timeout() called, time="+time+"; time()="+_time()+"\n");
  int elapsed = _time()-time;
  if(time && elapsed >= 30)
  {
    MARK_FD("HTTP timeout");
    // Do not under any circumstances send any data as a reply here.
    // This is an easy reason why: It breaks keep-alive totaly.
    // It is not a very good idea to do that, since it might be enabled
    // per deafult any century now..
    end("");
  } else {
    // premature call_out... *�#!"
    call_out(do_timeout, 10);
    MARK_FD("HTTP premature timeout");
  }
}

static string last_id, last_from;
string get_id(string from)
{
  if(last_from == from) return last_id;
  last_from=from;
  catch {
    object f = open(from,"r");
    string id;
    id = f->read(200);
    if(sscanf(id, "%*s$"+"Id: %*s,v %s ", id) == 3)
      return last_id=" (version "+id+")";
  };
  last_id = "";
  return "";
}

void add_id(array to)
{
  foreach(to[1], array q)
    if(stringp(q[0]))
      q[0]+=get_id(q[0]);
}

string link_to(string what, int eid, int qq)
{
  int line;
  string file, fun;
  sscanf(what, "%s(%*s in line %d in %s", fun, line, file);
  if(file && fun && line)
  {
    sscanf(file, "%s (", file);
    if(file[0]!='/') file = combine_path(getcwd(), file);
//     werror("link to the function "+fun+" in the file "+
// 	   file+" line "+line+"\n");
    return ("<a href=\"/(old_error,find_file)/error?"+
	    "file="+http_encode_string(file)+"&"
	    "fun="+http_encode_string(fun)+"&"
	    "off="+qq+"&"
	    "error="+eid+"&"
	    "line="+line+"#here\">");
  }
  return "<a>";
}


string format_backtrace(array bt, int eid)
{
  // first entry is always the error, 
  // second is the actual function, 
  // rest is backtrace.
  //   bt = map( bt, html_encode_string );
  bt = map( bt, lambda( string q ){ 
                  return highlight_pike("foo", ([ "nopre":1 ]), q);
                } );
  string reason = roxen.diagnose_error( bt );
  if(sizeof(bt) == 1) // No backtrace?!
    bt += ({ "Unknown error, no backtrace."});
  string res = ("<title>Internal Server Error</title>"
		"<body bgcolor=white text=black link=darkblue vlink=darkblue>"
		"<table width=\"100%\" border=0 cellpadding=0 cellspacing=0>"
		"<tr><td valign=bottom align=left><img border=0 "
		"src=\""+(conf?"/internal-roxen-":"/img/")+
		"roxen-icon-gray.gif\" alt=\"\"></td>"
		"<td>&nbsp;</td><td width=100% height=39>"
		"<table cellpadding=0 cellspacing=0 width=100% border=0>"
		"<td width=\"100%\" align=right valigh=center height=28>"
		"<b><font size=+1>Failed to complete your request</font>"
		"</b></td></tr><tr width=\"100%\"><td bgcolor=\"#003366\" "
		"align=right height=12 width=\"100%\"><font color=white "
		"size=-2>Internal Server Error&nbsp;&nbsp;</font></td>"
		"</tr></table></td></tr></table>"
		"<p>\n\n"
		"<font size=+2 color=darkred>"
		"<img alt=\"\" hspace=10 align=left src="+
		(conf?"/internal-roxen-":"/img/") +"manual-warning.gif>"
		+bt[0]+"</font><br>\n"
		"The error occured while calling <b>"+
                bt[1]+"</b><p>\n"
		+(reason?reason+"<p>":"")
		+"<br><h3><br>Complete Backtrace:</h3>\n\n<ol>");

  int q = sizeof(bt)-1;
  foreach(bt[1..], string line)
  {
    string fun, args, where, fo;
    if((sscanf(html_encode_string(line), "%s(%s) in %s",
	       fun, args, where) == 3) &&
       (sscanf(where, "%*s in %s", fo) && fo)) {
      line += get_id( fo );
      res += ("<li value="+(q--)+"> "+
	      (replace(line, fo, link_to(line,eid,sizeof(bt)-q-1)+fo+"</a>")
	       -(getcwd()+"/"))+"<p>\n");
    } else {
      res += "<li value="+(q--)+"> <b><font color=darkgreen>"+
	line+"</font></b><p>\n";
    }
  }
  res += ("</ul><p><b><a href=\"/(old_error,plain)/error?error="+eid+"\">"
	  "Generate text-only version of this error message, for bug reports"+
	  "</a></b>");
  return res+"</body>";
}

string generate_bugreport(array from, string u, string rd)
{
  add_id(from);
  return ("<pre>"+html_encode_string("Roxen version: "+version()+
	  (roxen.real_version != version()?
	   " ("+roxen.real_version+")":"")+
	  "\nRequested URL: "+u+"\n"
	  "\nError: "+
	  describe_backtrace(from)-(getcwd()+"/")+
	  "\n\nRequest data:\n"+rd));
}

string censor(string what)
{
  string a, b, c;
  if(!what)
    return "No backtrace";
  if(sscanf(what, "%shorization:%s\n%s", a, b, c)==3)
    return a+" ################ (censored)\n"+c;
  return what;
}

int store_error(array err)
{
  mapping e = roxen.query_var("errors");
  if(!e) roxen.set_var("errors", ([]));
  e = roxen.query_var("errors"); /* threads... */
  
  int id = ++e[0];
  if(id>1024) id = 1;
  e[id] = ({err,raw_url,censor(raw)});
  return id;
}

array get_error(string eid)
{
  mapping e = roxen.query_var("errors");
  if(e) return e[(int)eid];
  return 0;
}


void internal_error(array err)
{
  array err2;
  if(QUERY(show_internals)) 
  {
    err2 = catch { 
      array(string) bt = (describe_backtrace(err)/"\n") - ({""});
      file = http_low_answer(500, format_backtrace(bt, store_error(err)));
    };	
    if(err2) {
      werror("Internal server error in internal_error():\n" +
	     describe_backtrace(err2)+"\n while processing \n"+
	     describe_backtrace(err));
      file = http_low_answer(500, "<h1>Error: The server failed to "
			     "fulfill your query, due to an "
			     "internal error in the internal error routine.</h1>");
    }
  } else {
    file = http_low_answer(500, "<h1>Error: The server failed to "
			   "fulfill your query, due to an internal error.</h1>");
  }
  report_error("Internal server error: " +
	       describe_backtrace(err) + "\n");
}

int wants_more()
{
  return !!cache;
}

constant errors =
([
  200:"200 OK",
  201:"201 URI follows",
  202:"202 Accepted",
  203:"203 Provisional Information",
  204:"204 No Content",
  206:"206 Partial Content", // Byte ranges
  
  300:"300 Moved",
  301:"301 Permanent Relocation",
  302:"302 Temporary Relocation",
  303:"303 Temporary Relocation method and URI",
  304:"304 Not Modified",

  400:"400 Bad Request",
  401:"401 Access denied",
  402:"402 Payment Required",
  403:"403 Forbidden",
  404:"404 No such file or directory.",
  405:"405 Method not allowed",
  407:"407 Proxy authorization needed",
  408:"408 Request timeout",
  409:"409 Conflict",
  410:"410 This document is no more. It has gone to meet it's creator. It is gone. It will not be coming back. Give up. I promise. There is no such file or directory.",
  416:"416 Requested range not satisfiable",

  500:"500 Internal Server Error.",
  501:"501 Not Implemented",
  502:"502 Gateway Timeout",
  503:"503 Service unavailable",
  
  ]);


void do_log()
{
  MARK_FD("HTTP logging"); // fd can be closed here
  if(conf)
  {
    int len;
    if(pipe) file->len = pipe->bytes_sent();
    if(conf)
    {
      if(file->len > 0) conf->sent+=file->len;
      file->len += misc->_log_cheat_addition;
      conf->log(file, this_object());
    }
  }
  end(0,1);
  return;
}

#ifdef FD_DEBUG
void timer(int start)
{
  if(pipe) {
    // FIXME: Disconnect if no data has been sent for a long while
    //   (30min?)
    MARK_FD(sprintf("HTTP_piping_%d_%d_%d_%d_(%s)",
		    pipe->sent,
		    stringp(pipe->current_input) ?
		    strlen(pipe->current_input) : -1,
		    pipe->last_called,
		    _time(1) - start, 
		    not_query));
  } else {
    MARK_FD("HTTP piping, but no pipe for "+not_query);
  }
  call_out(timer, 30, start);
}
#endif

string handle_error_file_request(array err, int eid)
{
//   return "file request for "+variables->file+"; line="+variables->line;
  string data = Stdio.read_bytes(variables->file);
  array(string) bt = (describe_backtrace(err)/"\n") - ({""});
  string down;

  if((int)variables->off-1 >= 1)
    down = link_to( bt[(int)variables->off-1],eid, (int)variables->off-1);
  else
    down = "<a>";
  if(data)
  {
    int off = 49;
    array (string) lines = data/"\n";
    int start = (int)variables->line-50;
    if(start < 0)
    {
      off += start;
      start = 0;
    }
    int end = (int)variables->line+50;
    lines=highlight_pike("foo", ([ "nopre":1 ]), lines[start..end]*"\n")/"\n";

//     foreach(bt, string b)
//     {
//       int line;
//       string file, fun;
//       sscanf(what, "%s(%*s in line %d in %s", fun, line, file);
//       if(file && fun && line) sscanf(file, "%s (", file);
//       if((file == variables->file) && 
// 	 (fun == variables->fun) && 
// 	 (line == variables->line))
//     }

    if(sizeof(lines)>off)
      lines[off]=("<font size=+2><b>"+down+lines[off]+"</a></b></font></a>");
    lines[max(off-20,0)] = "<a name=here>"+lines[max(off-20,0)]+"</a>";
    data = lines*"\n";
  }
  
  return format_backtrace(bt,eid)+"<hr noshade><pre>"+data+"</pre>";
}

// The wrapper for multiple ranges (send a multipart/byteranges reply).
#define BOUND "Byte_Me_Now_Roxen"

class MultiRangeWrapper
{
  object file;
  function rcb;
  int current_pos, len, separator;
  array ranges;
  array range_info = ({});
  string type;
  string stored_data = "";
  void create(mapping _file, mapping heads, array _ranges, object id)
  {
    file = _file->file;
    len = _file->len;
    foreach(indices(heads), string h)
    {
      if(lower_case(h) == "content-type") {
	type = heads[h];
	m_delete(heads, h);
      }
    }
    if(id->request_headers["request-range"])
      heads["Content-Type"] = "multipart/x-byteranges; boundary=" BOUND;
    else
      heads["Content-Type"] = "multipart/byteranges; boundary=" BOUND;
    ranges = _ranges;
    int clen;
    foreach(ranges, array range)
    {
      int rlen = 1+ range[1] - range[0];
      string sep =  sprintf("\r\n--" BOUND "\r\nContent-Type: %s\r\n"
			    "Content-Range: bytes %d-%d/%d\r\n\r\n",
			    type||"application/octet-stream",
			    @range, len);
      clen += rlen + strlen(sep);
      range_info += ({ ({ rlen, sep }) });
    }
    clen += strlen(BOUND) + 8; // End boundary length.
    _file->len = clen;
  }

  string read(int num_bytes)
  {
    string out = stored_data;
    int rlen, total = num_bytes;
    num_bytes -= strlen(out);
    stored_data = "";
    foreach(ranges, array range)
    {
      rlen = range_info[0][0] - current_pos;
      if(separator != 1) {
	// New range, write new separator.
	//	write("Initiating new range %d -> %d.\n", @range);
	out += range_info[0][1];
	num_bytes -= strlen(range_info[0][1]);
	file->seek(range[0]);
	separator = 1;
      }
      if(num_bytes > 0) {
	if(rlen <= num_bytes)
	  // Entire range fits.
	{
	  out += file->read(rlen);
	  num_bytes -= rlen;
	  current_pos = separator = 0;
	  ranges = ranges[1..]; // One range done.
	  range_info = range_info[1..];
	} else {
	  out += file->read(num_bytes);
	  current_pos += num_bytes;
	  num_bytes = 0;
	}
      }
      if(num_bytes <= 0)
	break; // Return data
    }
    if(!sizeof(ranges) && separator != 2) {
      // End boundary. Only write once and only when
      // no more ranges remain.
      separator = 2;
      out += "\r\n--" BOUND "--\r\n";
    }  
    if(strlen(out) > total)
    {
      // Oops. too much data again. Write and store. Write and store.
      stored_data = out[total..];
      return out[..total-1];
    }
    return out ; // We are finally done.
  }
  
  mixed `->(string what)
  {
    switch(what) {
     case "read":
      return read;

     case "set_nonblocking":
      return 0;

     case "query_fd":
      return lambda() { return -1; };
      
     default:
      return file[what];
    }
  }
}


// Parse the range header itno multiple ranges.
array parse_range_header(int len)
{
  array ranges = ({});
  foreach(misc->range / ",", string range)
  {
    int r1, r2;
    if(range[0] == '-' ) {
      // End of file request
      r1 = (len - (int)range[1..]);
      if(r1 < 0) {
	// Entire file requested here. 
	r1 = 0;
      }
      ranges += ({ ({ len - (int)range[1..], len-1 }) }); 
    } else if(range[-1] == '-') {
      // Rest of file request
      r1 = (int)range;
      if(r1 >= len)
	// Range beginning is after EOF.
	continue; 
      ranges += ({ ({ r1, len-1 }) });
    } else if(sscanf(range, "%d-%d", r1, r2)==2) {
      // Standard range
      if(r1 <= r2) {
	if(r1 >= len)
	  // Range beginning is after EOF.
	  continue;
	ranges += ({ ({ r1, r2 < len ? r2 : len -1  }) });
      }
      else 
	// A syntatically incorrect range should make the server
	// ignore the header. Really.
	return 0;
    } else
      // Invalid syntax again...
      return 0; 
  }
  return ranges;
}

// Tell the client that it can start sending some more data
void ready_to_receive()
{
  if (clientprot == "HTTP/1.1") {
    my_fd->write("HTTP/1.1 100 Continue\r\n");
  }
}

// Send the result.
void send_result(mapping|void result)
{
  array err;
  int tmp;
  mapping heads;
  string head_string;
  if (result) {
    file = result;
  }

  DPERROR(sprintf("HTTP: send_result(%O)", file));
  
  if(!mappingp(file))
  {
    if(misc->error_code)
      file = http_low_answer(misc->error_code, errors[misc->error]);
    else if(err = catch {
      file=http_low_answer(404,
			   replace(parse_rxml(conf->query("ZNoSuchFile"),
                                              this_object()),
				   ({"$File", "$Me"}), 
				   ({not_query,
				     conf->query("MyWorldLocation")})));
    }) {
      internal_error(err);
    }
  } else {
    if((file->file == -1) || file->leave_me) 
    {
      if(do_not_disconnect) {
	file = 0;
	pipe = 0;
	return;
      }
      my_fd = 0;
      file = 0;
      return;
    }

    if(file->type == "raw")  file->raw = 1;
    else if(!file->type)     file->type="text/plain";
  }
  
  if(!file->raw)
  {
    heads = ([]);
    if(!file->len)
    {
      if(objectp(file->file))
	if(!file->stat && !(file->stat=misc->stat))
	  file->stat = (int *)file->file->stat();
      array fstat;
      if(arrayp(fstat = file->stat))
      {
	if(file->file && !file->len)
	  file->len = fstat[1];
    
	if(prot != "HTTP/0.9") {
	  heads["Last-Modified"] = http_date(fstat[3]);
	  
	  if(since)
	  {
	    if(is_modified(since, fstat[3], fstat[1]))
	    {
	      file->error = 304;
	      file->file = 0;
	      file->data="";
	      // 	    method="";
	    }
	  }
	}
      }
      if(stringp(file->data)) 
	file->len += strlen(file->data);
    }
    if(prot != "HTTP/0.9") {
      string h;
      heads += ([
	"MIME-Version" 	: (file["mime-version"] || "1.0"),
	"Content-type" 	: file["type"],
	"Accept-Ranges" 	: "bytes",
	"Server" 		: replace(version(), " ", "�"),
#ifdef KEEP_ALIVE
	"Connection": (misc->connection == "close" ? "close": "Keep-Alive"),
#else
	"Connection"	: "close",
#endif
	"Date"		: http_date(time)
      ]);


      if(file->encoding)
	heads["Content-Encoding"] = file->encoding;
    
      if(!file->error) 
	file->error=200;
    
      if(file->expires)
	heads->Expires = http_date(file->expires);

      if(mappingp(file->extra_heads)) {
	heads |= file->extra_heads;
      }

      if(mappingp(misc->moreheads)) {
	heads |= misc->moreheads;
      }

      if(misc->range && file->len && objectp(file->file) && !file->data &&
	 file->error == 200 && (method == "GET" || method == "HEAD"))
	// Plain and simple file and a Range header. Let's play.
	// Also we only bother with 200-requests. Anything else should be
	// nicely and completely ignored. Also this is only used for GET and
	// HEAD requests.
      {
	// split the range header. If no valid ranges are found, ignore it.
	// If one is found, send that range. If many are found we need to
	// use a wrapper and send a multi-part message. 
	array ranges = parse_range_header(file->len);
	if(ranges) // No incorrect syntax...
	{ 
	  if(sizeof(ranges)) // And we have valid ranges as well.
	  {
	    file->error = 206; // 206 Partial Content
	    if(sizeof(ranges) == 1)
	    {
	      heads["Content-Range"] = sprintf("bytes %d-%d/%d",
					       @ranges[0], file->len);
	      file->file->seek(ranges[0][0]);
	      if(ranges[0][1] == (file->len - 1) &&
		 GLOBVAR(RestoreConnLogFull))
		// Log continuations (ie REST in FTP), 'range XXX-'
		// using the entire length of the file, not just the
		// "sent" part. Ie add the "start" byte location when logging
		misc->_log_cheat_addition = ranges[0][0];
	      file->len = ranges[0][1] - ranges[0][0]+1;
	    } else {
	      // Multiple ranges. Multipart reply and stuff needed.
	      // We do this by replacing the file object with a wrapper.
	      // Nice and handy.
	      file->file = MultiRangeWrapper(file, heads, ranges, this_object());
	    }
	  } else {
	    // Got the header, but the specified ranges was out of bounds.
	    // Reply with a 416 Requested Range not satisfiable.
	    file->error = 416;
	    heads["Content-Range"] = "*/"+file->len;
	    if(method == "GET") {
	      file->data = "The requested byte range is out-of-bounds. Sorry.";
	      file->len = strlen(file->data);
	      file->file = 0;
	    }
	  }
	}
      }
    
      head_string = prot+" "+(file->rettext||errors[file->error])+"\r\n";
      array tmp_head = ({});
      foreach(indices(heads), h)
	if(arrayp(heads[h]))
	  foreach(heads[h], tmp)
	    tmp_head += ({ `+(h, ": ", tmp) });
	else
	  tmp_head += ({ `+(h, ": ", heads[h]) });
      head_string += tmp_head * "\r\n";
    
      if(file->len > -1) 
	head_string += "\r\nContent-Length: "+ file->len +"\r\n";
      head_string += "\r\n";
    
      if(conf) conf->hsent += strlen(head_string);
    }
  }
#ifdef REQUEST_DEBUG
  roxen_perror(sprintf("Sending result for prot:%O, method:%O file:%O\n",
		       prot, method, file));
#endif /* REQUEST_DEBUG */

  MARK_FD("HTTP handled");

#ifdef KEEP_ALIVE
  if(!leftovers) leftovers = data||"";
#endif

  if(my_fd->query_fd && my_fd->query_fd() >= 0 &&
     file->len > 0 && file->len < 2000)
  {
    // Ordinary connection, and a short file.
    // Just do a blocking write().
    my_fd->write((head_string || "") +
		 (file->file?file->file->read(file->len):
		  (file->data[..file->len-1])));
    do_log();
    return;
  }

  if(head_string) send(head_string);

  if(method != "HEAD" && file->error != 304)
    // No data for these two...
  {
    if(file->data && strlen(file->data))
      send(file->data, file->len);
    if(file->file)  
      send(file->file, file->len);
  } else
    file->len = 1; // Keep those alive, please...

  start_sender(do_log);
}


// Execute the request
void handle_request( )
{
  DPERROR("HTTP: handle_request()");

#ifdef MAGIC_ERROR
  if(prestate->old_error)
  {
    array err = get_error(variables->error);
    if(err)
    {
      if(prestate->plain)
      {
	file = ([
	  "type":"text/html",
	  "data":generate_bugreport( @err ),
	]);
        send_result();
        return;
      } else {
	if(prestate->find_file)
        {
	  if(!realauth)
	    file = http_auth_required("admin");
	  else
	  {
	    array auth = (realauth+":")/":";
	    if((auth[0] != roxen.query("ConfigurationUser"))
	       || !crypt(auth[1], roxen.query("ConfigurationPassword")))
	      file = http_auth_required("admin");
	    else
	      file = ([
		"type":"text/html",
		"data":handle_error_file_request( err[0], 
						  (int)variables->error ),
	      ]);
	  }
          send_result();
          return;
	}
      }
    }
  }
#endif /* MAGIC_ERROR */

  remove_call_out(do_timeout);
  MARK_FD("HTTP handling request");

  array e;
  if(e= catch(file = conf->handle_request( this_object() )))
    internal_error( e );
  send_result();
}

/* We got some data on a socket.
 * ================================================= 
 */
int processed;
void got_data(mixed fooid, string s)
{
  int tmp;
  
  MARK_FD("HTTP got data");
  remove_call_out(do_timeout);
  call_out(do_timeout, 30); // Close down if we don't get more data 
                         // within 30 seconds. Should be more than enough.
  time = _time(1); // Check is made towards this to make sure the object
  		  // is not killed prematurely.
  if(!raw)
    raw = s;
  else 
    raw += s;
  if(wanted_data)
  {
    if(strlen(s) + have_data < wanted_data)
    {
      //      cache += ({ s });
      have_data += strlen(s);

      DPERROR("HTTP: We want more data.");
      return;
    }
  }
  
  
  // If the request starts with newlines, it's a broken request. Really!
  //  sscanf(s, "%*[\n\r]%s", s);
  if(strlen(raw)) tmp = parse_got();
  switch(tmp)
  { 
   case 0:
    //    if(this_object()) 
    //      cache = ({ s });		// More on the way.
    DPERROR("HTTP: Request needs more data.");
    return;
    
   case 1:
    DPERROR("HTTP: Stupid Client Error");
    end((prot||"HTTP/1.0")+" 500 Stupid Client Error\r\nContent-Length: 0\r\n\r\n");
    return;			// Stupid request.
    
   case 2:
    DPERROR("HTTP: Done");
    end();
    return;
  }

  // FIXME: port_obj->name & port_obj->default_port are constant
  // consider caching them?
  conf =
    port_obj->find_configuration_for_url(port_obj->name + "://" +
					 misc->host +
					 (search(misc->host, ":")<0?
					  (":"+port_obj->default_port):"") +
					 not_query,
					 this_object());

  if (rawauth) 
  {
    /* Need to authenticate with the configuration */
    array(string) y = rawauth / " ";
    realauth = 0;
    auth = 0;
    if (sizeof(y) >= 2) 
    {
      y[1] = MIME.decode_base64(y[1]);
      realauth = y[1];
      if (conf->auth_module) 
        y = conf->auth_module->auth(y, this_object());
      auth = y;
    }
  }


  if( misc->proxyauth ) 
  {
    /* Need to authenticate with the configuration */
    if (sizeof(misc->proxyauth) >= 2) 
    {
      //    misc->proxyauth[1] = MIME.decode_base64(misc->proxyauth[1]);
      if (conf->auth_module) 
        misc->proxyauth
          = conf->auth_module->auth(misc->proxyauth,this_object() );
    }
  }

  conf->received += strlen(s);
  conf->requests++;

  DPERROR("HTTP: Calling roxen.handle().");

  my_fd->set_close_callback(0); 
  my_fd->set_read_callback(0); 
  processed=1;
  roxen.handle(this_object()->handle_request);
}

/* Get a somewhat identical copy of this object, used when doing 
 * 'simulated' requests. */

object clone_me()
{
  object c,t;
  c=object_program(t=this_object())();

// c->first = first;
  c->port_obj = port_obj;
  c->conf = conf;
  c->time = time;
  c->raw_url = raw_url;
  c->variables = copy_value(variables);
  c->misc = copy_value(misc);
  c->misc->orig = t;

  c->prestate = prestate;
  c->supports = supports;
  c->config = config;

  c->remoteaddr = remoteaddr;
  c->host = host;

  c->client = client;
  c->referer = referer;
  c->pragma = pragma;

  c->cookies = cookies;
  c->my_fd = 0;
  c->prot = prot;
  c->clientprot = clientprot;
  c->method = method;
  
// realfile virtfile   // Should not be copied.  
  c->rest_query = rest_query;
  c->raw = raw;
  c->query = query;
  c->not_query = not_query;
  c->data = data;
  c->extra_extension = extra_extension;

  c->auth = auth;
  c->realauth = realauth;
  c->rawauth = rawauth;
  c->since = since;
  return c;
}

void clean()
{
  if(!(my_fd && objectp(my_fd)))
    end();
  else if((_time(1) - time) > 4800) 
    end();
}

void create(object f, object c)
{
  if(f)
  {
    MARK_FD("HTTP connection");
    f->set_nonblocking(got_data, 0, end);
    my_fd = f;
    if( c )
      port_obj = c;
    call_out(do_timeout, 30);
    time = _time(1);
  }
}

void chain(object f, object c, string le)
{
  my_fd = f;
  port_obj = c;
  do_not_disconnect=-1;
  MARK_FD("Kept alive");
  if(strlen(le))
    // More to handle already.
    got_data(0,le);
  else {
    // If no pipelined data is available, call out...
    call_out(do_timeout, 150);
    time = _time(1);
  }

  if(!my_fd)
  {
    if(do_not_disconnect == -1)
    {
      do_not_disconnect=0;
      disconnect();
    }
  } else {
    if(do_not_disconnect == -1) 
      do_not_disconnect = 0;
    if(!processed) {
      f->set_close_callback(end);
      f->set_read_callback(got_data);
    }
  }
}
