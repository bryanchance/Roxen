import Simulate;

// This is a roxen module. (c) Informationsvävarna AB 1996.
//
// The main RXML parser. If this module is not added to a configuration,
// no RXML parsing will be done at all.  This module also maintains an
// accessed database, to be used by the <accessed> tag.
//
// It is in severe need of a cleanup in the code.
//
// This file *should* be split into multiple files, one with all
// 'USER' related tags, one with all CLIENT related tags, etc.
// 
// the only thing that should be in this file is the main parser.  


constant cvs_version = "$Id: htmlparse.pike,v 1.56 1997/12/15 01:52:13 per Exp $";
constant thread_safe=1;

#include <config.h>
#include <module.h>

inherit "module";
inherit "roxenlib";

import String;
import Array;
import Stdio;

#if !constant(Privs)
constant Privs=((program)"privs");
#endif /* !constant(Privs) */

constant language = roxen->language;

int cnum=0;
mapping fton=([]);
array (mapping) tag_callers, container_callers;
mapping (string:mapping(int:function)) real_tag_callers, real_container_callers;
int bytes;
array (object) parse_modules = ({ });

object database, names_file;
void build_callers();

// If the string 'w' match any of the patterns in 'a', return 1, else 0.
int _match(string w, array (string) a)
{
  string q;
  foreach(a, q)
    if(stringp(w) && stringp(q) && glob(q, w))
      return 1;
}

// Configuration interface fluff.
string comment()
{
  return query("toparse")*", ";
}

string status()
{
  return (bytes/1024 + " Kb parsed<br>"+
	  sizeof(fton)+" entries in the accessed database<br>");
}

private int ac_is_not_set()
{
  return !QUERY(ac);
}

private int ssi_is_not_set()
{
  return !QUERY(ssi);
}

void create()
{
  defvar("Accesslog", 
	 GLOBVAR(logdirprefix)+
	 short_name(roxen->current_configuration?
		    roxen->current_configuration->name:".")+"/Accessed", 
	 "Access log file", TYPE_FILE|VAR_MORE,
	 "In this file all accesses to files using the &lt;accessd&gt;"
	 " tag will be logged.", 0, ac_is_not_set);

  defvar("noparse", ({  }), "Extensions to accesscount",
          TYPE_STRING_LIST,
         "Always access-count all files ending with these extensions.");
 
  
  defvar("toparse", ({ "rxml","spml", "html", "htm" }), "Extensions to parse", 
	 TYPE_STRING_LIST, "Parse all files ending with these extensions.");

  defvar("parse_exec", 0, "Require exec bit on files for parsing",
	 TYPE_FLAG|VAR_MORE,
	 "If set, files has to have the execute bit (any of them) set "
	 "in order for them to be parsed by this module. The exec bit "
	 "is the one that is set by 'chmod +x filename'");
	 
  defvar("no_parse_exec", 0, "Don't Parse files with exec bit",
	 TYPE_FLAG|VAR_MORE,
	 "If set, no files with the exec bit set will be parsed. This is the "
	 "reverse of the 'Require exec bit on files for parsing' flag. "
	 "It is not very useful to set both variables.");
	 
  defvar("ac", 1, "Access log", TYPE_FLAG,
	 "If unset, the &lt;accessed&gt; tag will not work, and no access log "
	 "will be needed. This will save one file descriptors.");

  defvar("max_parse", 100, "Maximum file size", TYPE_INT|VAR_MORE,
	 "Maximum file size to parse, in Kilo Bytes.");

  defvar("ssi", 1, "SSI support: NSCA and Apache SSI support", 
	 TYPE_FLAG,
	 "If set, Roxen will parse NCSA / Apache server side includes.");

  defvar("exec", 0, "SSI support: execute command", 
	 TYPE_FLAG,
	 "If set and if server side include support is enabled, Roxen "
	 "will accept NCSA / Apache &lt;!--#exec cmd=\"XXX\"--&gt;.",
	 ssi_is_not_set);

  defvar("close_db", 1, "Close the database if it is not used",
	 TYPE_FLAG|VAR_MORE,
	 "If set, the accessed database will be closed if it is not used for "
	 "8 seconds");

  defvar("compat_if", 0, "Compatibility with old &lt;if&gt;",
	 TYPE_FLAG|VAR_MORE,
	 "If set the &lt;if&gt;-tag will work in compatibility mode.\n"
	 "This affects the behaviour when used together with the &lt;else&gt;-"
	 "tag.\n");
}

static string olf; // Used to avoid reparsing of the accessed index file...

static mixed names_file_callout_id;
inline void open_names_file()
{
  if(objectp(names_file)) return;
  remove_call_out(names_file_callout_id);
  object privs = Privs("Opening Access-log names file");
  names_file=open(QUERY(Accesslog)+".names", "wrca");
  names_file_callout_id = call_out(destruct, 1, names_file);
}

#ifdef THREADS
object db_lock = Thread.Mutex();
#endif /* THREADS */

static void close_db_file(object db)
{
#ifdef THREADS
  mixed key = db_lock->lock();
#endif /* THREADS */
  if (db) {
    destruct(db);
  }
}

static mixed db_file_callout_id;
inline mixed open_db_file()
{
  mixed key;
#ifdef THREADS
  catch { key = db_lock->lock(); };
#endif /* THREADS */
  if(objectp(database)) return key;
  if(!database)
  {
    if(db_file_callout_id) remove_call_out(db_file_callout_id);
    object privs = Privs("Opening Access-log database file");
    database=open(QUERY(Accesslog)+".db", "wrc");
    if (!database) {
      throw(({ sprintf("Failed to open \"%s.db\". Out of fd's?\n",
		       QUERY(Accesslog)), backtrace() }));
    }
    if (QUERY(close_db)) {
      db_file_callout_id = call_out(close_db_file, 9, database);
    }
  }
  return key;
}

void start()
{
  mixed tmp;

  build_callers();

  if(!QUERY(ac))
  {
    if(database)  destruct(database);
    if(names_file) destruct(names_file);
    return;
  }

  if(olf != QUERY(Accesslog))
  {
    olf = QUERY(Accesslog);

    object privs = Privs("Opening Access-log names file");
    mkdirhier(query("Accesslog"));
#if 0
    if(!QUERY(close_db))
      if(!(database=open(olf+".db", "wrc")))
      {
	perror("RXMLPARSE: Failed to open access database.\n");
	return;
      }
#endif /* 0 */

    if(names_file=open(olf+".names", "wrca"))
    {
      cnum=0;
      tmp=parse_accessed_database(names_file->read(0x7ffffff));
      fton=tmp[0];
      cnum=tmp[1];
      names_file = 0;
    }
  }
}

static int mdc;
int main_database_created()
{
  if(!QUERY(ac)) return -1;

  if(!mdc)
  {
    mixed key = open_db_file();
    database->seek(0);
    sscanf(database->read(4), "%4c", mdc);
    return mdc;
  }
  return mdc;
}

int database_set_created(string file, void|int t)
{
  int p;

  if(!QUERY(ac)) return -1;

  p=fton[file];
  if(!p) return 0;
  mixed key = open_db_file();
  database->seek((p*8)+4);
  return database->write(sprintf("%4c", t||time(1)));
}

int database_created(string file)
{
  int p,w;

  if(!QUERY(ac)) return -1;

  p=fton[file];
  if(!p) return main_database_created();
  mixed key = open_db_file();
  database->seek((p*8)+4);
  sscanf(database->read(4), "%4c", w);
  if(!w)
  {
    w=main_database_created();
    database_set_created(file, w);
  }
  return w;
}


int query_num(string file, int count)
{
  int p, n;
  string f;

  if(!QUERY(ac)) return -1;

  mixed key = open_db_file();

  // if(lock) lock->aquire();
  
  if(!(p=fton[file]))
  {
    if(!cnum)
    {
      database->seek(0);
      database->write(sprintf("%4c", time(1)));
    }
    fton[file]=++cnum;
    p=cnum;

//  perror(file + ": New entry.\n");
    open_names_file();
//  perror(file + ": Created new entry.\n");
    names_file->write(file+":"+cnum+"\n");

    database->seek(p*8);
    database->write(sprintf("%4c", 0));
    database_set_created(file);
  }
  if(database->seek(p*8) > -1)
  {
    sscanf(database->read(4), "%4c", n);
//  perror("Old count: " + n + "\n");
    if (count) 
    { 
//    perror("Adding "+count+" to it..\n");
      n+=count; 
      database->seek(p*8);
      database->write(sprintf("%4c", n)); 
    }
    //lock->free();
    return n;
  } 
//perror("Seek failed\n");
  //lock->free();
  return 0;
}

array register_module()
{
  return ({ MODULE_FILE_EXTENSION|MODULE_PARSER|MODULE_MAIN_PARSER, 
	    "Main RXML parser", 
	    ("This module makes it possible for other modules to add "
	     "new tags to the RXML parsing, in addition to the "
	     "default ones.  The default error message (no such resource) "
	     "use this parser, so if you do not want it, you will also "
	     "have to change the error message."), ({}), 1 });
}

string *query_file_extensions() 
{ 
  return query("toparse") + query("noparse"); 
}


#define _stat defines[" _stat"]
#define _error defines[" _error"]
#define _extra_heads defines[" _extra_heads"]
#define _rettext defines[" _rettext"]
#define _ok     defines[" _ok"]

string call_tag(string tag, mapping args, int i,
		object id, object file, mapping defines,
		object client)
{
  function rf = real_tag_callers[tag][i];
  if(!rf)
  {
    report_error("Call to non-registered tag from parse module.\n");
    return 0;
  }
  if(id->conf->check_security(rf, id, id->misc->seclevel))
    return 0;
  return rf(tag,args,id,file,defines,client);
}

string call_container(string tag, mapping args, string contents, int i,
		      object id, object file, mapping defines,
		      object client)
{
  function rf = real_container_callers[tag][i];
  if(!rf)
  {
    report_error("Call to non-registered container from parse module.\n");
    return 0;
  }
  if(id->conf->check_security(rf, id, id->misc->seclevel))
    return 0;
  return rf(tag,args,contents,id,file,defines,client);
}

string do_parse(string to_parse, object id, object file, mapping defines,
		object my_fd)
{  
  for(int i = 0; i<sizeof(tag_callers); i++)
  {
#ifdef PARSE_DEBUG
    werror("Parse pass "+i+"\n");
    werror(sprintf("Tags: %s\nContainers:%s\n",
		   indices(tag_callers[i])*", ",
		   indices(container_callers[i])*", "));
#endif
    to_parse=parse_html(to_parse, tag_callers[i], container_callers[i],
			i, id, file, defines, my_fd);
  }
  return to_parse;
}


mapping handle_file_extension( object file, string e, object id)
{
  mixed err;
  string to_parse;
  mapping defines = id->misc->defines || ([]);

  id->misc->defines = defines;
  if(search(QUERY(noparse),e)!=-1)
  {
    query_num(id->not_query, 1);
    if(!search(QUERY(toparse),e)==-1)  /* Parse anyway */
      return 0;
  }
  

  if(!defines->sizefmt)
  {
    // Already partially parsed.
#if efun(set_start_quote)
    set_start_quote(set_end_quote(0));
#endif
    defines->sizefmt = "abbrev"; 

    _error=200;
    _extra_heads=([ ]);
    if(id->misc->stat)
      _stat=id->misc->stat;
    else
      _stat=file->stat();
    if(_stat[1] > (QUERY(max_parse)*1024))
      return 0; // To large for me..
  }
  if(QUERY(parse_exec) &&   !(_stat[0] & 07111)) return 0;
  if(QUERY(no_parse_exec) && (_stat[0] & 07111)) return 0;

  to_parse = file->read(0x7fffffff);

  if(err = catch( to_parse = do_parse( to_parse,id,file,defines,id->my_fd ) ))
  {
    destruct(file);
    throw(err);
  }

  bytes += strlen(to_parse);

  file->close();
  destruct(file);

  return (["data":to_parse,
	   "type":"text/html",
	   "stat":_stat,
	   "error":_error,
	   "rettext":_rettext,
	   "extra_heads":_extra_heads,
//	   "expires": time(1) - 100,
	   ]);
}

/* parsing modules */
void insert_in_map_list(mapping to_insert, string map_in_object)
{
  function do_call = this_object()["call_"+map_in_object];

  array (mapping) in = this_object()[map_in_object+"_callers"];
  mapping (string:mapping) in2=this_object()["real_"+map_in_object+"_callers"];

  
  foreach(indices(to_insert), string s)
  {
    if(!in2[s]) in2[s] = ([]);
    for(int i=0; i<sizeof(in); i++)
      if(!in[i][s])
      {
	in[i][s] = do_call;
	in2[s][i] = to_insert[s];
	break;
      }
    if(i==sizeof(in))
    {
      in += ({ ([]) });
      if(map_in_object == "tag")
	container_callers += ({ ([]) });
      else
	tag_callers += ({ ([]) });
      in[i][s] = do_call;
      in2[s][i] = to_insert[s];
    }
  }
  this_object()[map_in_object+"_callers"]=in;
  this_object()["real_"+map_in_object+"_callers"]=in2;
}

void sort_lists()
{
  array ind, val, s;
  foreach(indices(real_tag_callers), string c)
  {
    ind = indices(real_tag_callers[c]);
    val = values(real_tag_callers[c]);
    sort(ind);
    s = map(val, lambda(function f) {
      return function_object(f)->query("_priority");
    });
    sort(s,val);
    real_tag_callers[c]=mkmapping(ind,val);
  }
  foreach(indices(real_container_callers), string c)
  {
    ind = indices(real_container_callers[c]);
    val = values(real_container_callers[c]);
    sort(ind);
    s = map(val, lambda(function f) {
      return function_object(f)->query("_priority");
    });
    sort(s,val);
    real_container_callers[c]=mkmapping(ind,val);
  }
}

void build_callers()
{
   object o;
   real_tag_callers=([]);
   real_container_callers=([]);

//   misc_cache = ([]);
   tag_callers=({ ([]) });
   container_callers=({ ([]) });

   parse_modules-=({0});

   foreach (parse_modules,o)
   {
     mapping foo;
     if(o->query_tag_callers)
       foo=o->query_tag_callers();

     if(mappingp(foo)) insert_in_map_list(foo, "tag");
     
     if(o->query_container_callers)
       foo=o->query_container_callers();

     if(mappingp(foo)) insert_in_map_list(foo, "container");
   }
   sort_lists();
}

void add_parse_module(object o)
{
  parse_modules |= ({o});
  remove_call_out(build_callers);
  call_out(build_callers,0);
}

void remove_parse_module(object o)
{
  parse_modules -= ({o});
  remove_call_out(build_callers);
  call_out(build_callers,0);
}

/* standard roxen tags */

string tagtime(int t,mapping m)
{
  string s;
  mixed eris;
  string res;

  if (m->part)
  {
    string sp;
    if(m->type == "ordered")
    {
      m->type="string";
      sp = "ordered";
    }

    switch (m->part)
    {
     case "year":
      return number2string((int)(localtime(t)->year+1900),m,
			   language(m->lang, sp||"number"));
     case "month":
      return number2string((int)(localtime(t)->mon+1),m,
			   language(m->lang, sp||"month"));
     case "day":
     case "wday":
      return number2string((int)(localtime(t)->wday+1),m,
			   language(m->lang, sp||"day"));
     case "date":
     case "mday":
      return number2string((int)(localtime(t)->mday),m,
			   language(m->lang, sp||"number"));
     case "hour":
      return number2string((int)(localtime(t)->hour),m,
			   language(m->lang, sp||"number"));
     case "min":
     case "minute":
      return number2string((int)(localtime(t)->min),m,
			   language(m->lang, sp||"number"));
     case "sec":
     case "second":
      return number2string((int)(localtime(t)->sec),m,
			   language(m->lang, sp||"number"));
     case "yday":
      return number2string((int)(localtime(t)->yday),m,
			   language(m->lang, sp||"number"));
     default: return "";
    }
  } else if(m->type) {
    switch(m->type)
    {
     case "iso":
      eris=localtime(t);
      return sprintf("%d-%02d-%02d", (eris->year+1900),
		     eris->mon+1, eris->mday);

     case "discordian":
     case "disc":
#if efun(discdate)
      eris=discdate(t);
      res=eris[0];
      if(m->year)
	res += " in the YOLD of "+eris[1];
      if(m->holiday && eris[2])
	res += ". Celebrate "+eris[2];
      return res;
#else
      return "Discordian date support disabled";
#endif
     case "stardate":
     case "star":
#if efun(stardate)
      return (string)stardate(t, (int)m->prec||1);
#else
      return "Stardate support disabled";
#endif
     default:
    }
  }
  s=language(m->lang, "date")(t,m);
  if (m->upper) s=upper_case(s);
  if (m->lower) s=lower_case(s);
  if (m->cap||m->capitalize) s=capitalize(s);
  return s;
}

string fix_relative(string file, object got)
{
  string other;
  if(file != "" && file[0] == '/')
    return file;
  other=got->not_query;
  if(file != "" && file[0] == '#')
    file = got->not_query + file;
  else
    file = dirname(got->not_query) + "/" +  file;
  // The below looks really buggy...
  // return simplify_path(replace(file, ({ "//", "..."}), ({"./..", "//"})));
  return simplify_path(file);
}

string tag_date(string q, mapping m)
{
  int t=(int)m->unix_time || time(1);
  if(m->day)    t += (int)m->day * 86400;
  if(m->hour)   t += (int)m->hour * 3600;
  if(m->minute) t += (int)m->minute * 60;
  if(m->min)    t += (int)m->min * 60;
  if(m->sec)    t += (int)m->sec;
  if(m->second) t += (int)m->second;

  if(!(m->brief || m->time || m->date))
    m->full=1;

  return tagtime(t,m);
}

inline string do_replace(string s, mapping (string:string) m)
{
  return replace(s, indices(m), values(m));
}

string tag_set(string tag, mapping m, object got)
{
  if (m->variable) {
    if (m->value) {
      // Set variable to value.
      got->variables[m->variable] = m->value;
    } else {
      // Unset variable.
      m_delete(got->variables, m->variable);
    }
    return("");
  } else {
    return("<!-- set: variable not specified -->");
  }
}

string tag_define(string tag,mapping m, string str, object got,object file,
		  mapping defines)
{ 
  if (m->name) defines[m->name]=str;
  else return "<!-- No name specified for the define! <define name=...> -->";
  return ""; 
}

string tag_insert(string tag,mapping m,object got,object file,mapping defines)
{
  string n;
  mapping fake_id=([]);

  if (n=m->name) 
  {
    m_delete(m, "name");
    return do_replace(defines[n]||"<!-- No such define: "+n+" -->", m);
  }

  if (n=m->variable) 
  {
    m_delete(m, "variable");
    return do_replace(got->variables[n]||"<!-- No such variable: "+n+" -->", m);
  }

  if (n=m->variables) 
  {
    if(n!="variables")
      return map(indices(got->variables), lambda(string s, mapping m) {
	return s+"="+sprintf("%O", m[s])+"\n";
      }, got->variables)*"\n";
    return implode_nicely(indices(got->variables));
  }

  if (n=m->cookies) 
  {
    if(n!="cookies")
      return map(indices(got->cookies), lambda(string s, mapping m) {
	return s+"="+sprintf("%O", m[s])+"\n";
      }, got->cookies)*"\n";
    return implode_nicely(indices(got->cookies));
  }

  if (n=m->cookie) 
  {
    m_delete(m, "cookie");
    return do_replace(got->cookies[n]||"<!-- No such variable: "+n+" -->", m);
  }

  if (m->file) 
  {
    string s;
    string f;
    f = fix_relative(m->file, got);

    if(m->nocache) got->pragma["no-cache"] = 1;

    s = roxen->try_get_file(f, got);

    if(!s) {
      if ((sizeof(f)>2) && (f[sizeof(f)-2..] == "--")) {
	// Might be a compat insert.
	s = roxen->try_get_file(f[..sizeof(f)-3], got);
      }
      if (!s) {
	return "<!-- No such file: "+f+"! -->";
      }
    }

    m_delete(m, "file");

    return do_replace(s, m);
  }
  return "";
}

string tag_modified(string tag, mapping m, object got, object file,
		    mapping defines);

string tag_compat_exec(string tag,mapping m,object got,object file,
		       mapping defines)
{
  if(!QUERY(ssi))
    return "SSI support disabled";

  if(m->cgi)
  {
    m->file = m->cgi;
    m_delete(m, "cgi");
    return tag_insert(tag, m, got, file, defines);
  }

  if(m->cmd)
  {
    if(QUERY(exec))
    {
      string tmp;
      tmp=got->conf->query("MyWorldLocation");
      sscanf(tmp, "%*s//%s", tmp);
      sscanf(tmp, "%s:", tmp);
      sscanf(tmp, "%s/", tmp);
      string user;
      user="Unknown";
      if(got->auth && got->auth[0])
	user=got->auth[1];
      string addr=got->remoteaddr || "Internal";
      object privs = Privs("Executing stuff..", "nobody");
      return popen(m->cmd,
		   getenv()
		   | build_roxen_env_vars(got)
		   | build_env_vars(got->not_query, got, 0));

    }
    else
      return " <b>execute command support disabled</b> ";
  }
  return "<!-- exec what? -->";
}

string tag_compat_config(string tag,mapping m,object got,object file,
			 mapping defines)
{
  if(QUERY(ssi)&& m->sizefmt == "abbrev" || m->sizefmt == "bytes")
    defines->sizefmt = m->sizefmt;
  else
    return "<!-- Config what? -->";
}

string tag_compat_include(string tag,mapping m,object got,object file,
			  mapping defines)
{
  if(!QUERY(ssi))
    return "SSI support disabled";

  if(m->virtual)
  {
    m->file = m->virtual;
    return tag_insert("insert", m, got, file, defines);
  }

  if(m->file)
  {
    mixed tmp;
    string fname1 = m->file;
    string fname2;
    if(m->file[0] != '/')
    {
      if(got->not_query[-1] == '/')
	m->file = got->not_query + m->file;
      else
	m->file = ((tmp = got->not_query / "/")[0..sizeof(tmp)-2] +
		   ({ m->file }))*"/";
      fname1 = got->conf->real_file(m->file, got);
      if ((sizeof(m->file) > 2) && (m->file[sizeof(m->file)-2..] == "--")) {
	fname2 = got->conf->real_file(m->file[..sizeof(m->file)-3], got);
      }
    } else if ((sizeof(fname1) > 2) && (fname1[sizeof(fname1)-2..] == "--")) {
      fname2 = fname1[..sizeof(fname1)-3];
    }
    return((fname1 && read_bytes(fname1)) ||
	   (fname2 && read_bytes(fname2)) ||
	   ("<!-- No such file: " +
	    (fname1 || fname2 || m->file) +
	    "! -->"));
  }
  return "<!-- What? -->";
}

string tag_compat_echo(string tag,mapping m,object got,object file,
			  mapping defines)
{
  if(!QUERY(ssi))
    return "SSI support disabled";
  if(m->var)
  {
    string addr=got->remoteaddr || "Internal";
    switch(m->var)
    {
     case "sizefmt":
      return defines->sizefmt;
      
     case "timefmt": case "errmsg":
      return "&lt;unimplemented&gt;";
      
     case "DOCUMENT_NAME": case "PATH_TRANSLATED":
      return roxen->real_file(got->not_query, got);

     case "DOCUMENT_URI":
      return got->not_query;

     case "DATE_LOCAL":
      return replace(ctime(time(1)), "\n", "");

     case "DATE_GMT":
      return replace(ctime(time(1) + localtime(time(1))->timezone), "\n", "");
      
     case "QUERY_STRING_UNESCAPED":
      return got->query || "";

     case "LAST_MODIFIED":
      return tag_modified(tag, m, got, file, defines);
      
     case "SERVER_SOFTWARE":
      return roxen->version();
      
     case "SERVER_NAME":
      string tmp;
      tmp=got->conf->query("MyWorldLocation");
      sscanf(tmp, "%*s//%s", tmp);
      sscanf(tmp, "%s:", tmp);
      sscanf(tmp, "%s/", tmp);
      return tmp;
      
     case "GATEWAY_INTERFACE":
      return "CGI/1.1";
      
     case "SERVER_PROTOCOL":
      return "HTTP/1.0";
      
     case "SERVER_PORT":
      tmp = objectp(got->my_fd) && got->my_fd->query_address(1);
      if(tmp)
	return (tmp/" ")[1];
      return "Internal";

     case "REQUEST_METHOD":
      return got->method;
      
     case "REMOTE_HOST":
      return roxen->quick_ip_to_host(addr);

     case "REMOTE_ADDR":
      return addr;

     case "AUTH_TYPE":
      return "Basic";
      
     case "REMOTE_USER":
      if(got->auth && got->auth[0])
	return got->auth[1];
      return "Unknown";
      
     case "HTTP_COOKIE": case "COOKIE":
      return (got->misc->cookies || "");

     case "HTTP_ACCEPT":
      return (got->misc->accept && sizeof(got->misc->accept)? 
	      got->misc->accept*", ": "None");
      
     case "HTTP_USER_AGENT":
      return got->client && sizeof(got->client)? 
	got->client*" " : "Unknown";
      
     case "HTTP_REFERER":
      return got->referer && sizeof(got->referer) ? 
	got->referer*", ": "Unknown";
      
     default:
      return "<i>Unknown variable</i>: '"+m->var+"'";
    }
  }
  return "<!-- Que? -->";
}

string tag_compat_fsize(string tag,mapping m,object got,object file,
			mapping defines)
{
  if(!QUERY(ssi))
    return "SSI support disabled";

  if(m->virtual)
  {
    m->file = roxen->real_file(m->virtual, got);
    m_delete(m, "virtual");
  }
  if(m->file)
  {
    array s;
    s = file_stat(m->file);
    if(s)
    {
      if(tag == "!--#fsize")
      {
	if(defines->sizefmt=="bytes")
	  return (string)s[1];
	else
	  return sizetostring(s[1]);
      } else {
	return ctime(s[3]);
      }
    }
    return "Error: Cannot stat file";
  }
  return "<!-- No file? -->";
}

string tag_accessed(string tag,mapping m,object got,object file,
		    mapping defines)
{
  int counts, n, prec, q, timep;
  string real, res;

  if(!QUERY(ac))
    return "Accessed support disabled.";

  if(m->file)
  {
    m->file = fix_relative(m->file, got);
    if(m->add) 
      counts = query_num(m->file, (int)m->add||1);
    else
      counts = query_num(m->file, 0);
  } else {
    if(_match(got->remoteaddr, got->conf->query("NoLog")))
      counts = query_num(got->not_query, 0);
    else if(defines->counted != "1") 
    {
      counts =query_num(got->not_query, 1);
      defines->counted = "1";
    } else {
      counts = query_num(got->not_query, 0);
    }
      
    m->file=got->not_query;
  }
  
  if(m->reset)
  {
    query_num(m->file, -counts);
    database_set_created(m->file, time(1));
    return "Number of counts for "+m->file+" is now 0.<br>";
  }

  if(m->silent)
    return "";

  if(m->since) 
  {
    if(m->database)
      return tagtime(database_created(0),m);
    return tagtime(database_created(m->file),m);
  }

  real="<!-- ("+counts+") -->";

  counts += (int)m->cheat;

  if(m->factor)
    counts = (counts * (int)m->factor) / 100;

  if(m->per)
  {
    timep=time(1) - database_created(m->file) + 1;
    
    switch(m->per)
    {
     case "second":
      counts /= timep;
      break;

     case "minute":
      counts = (int)((float)counts/((float)timep/60.0));
      break;

     case "hour":
      counts = (int)((float)counts/(((float)timep/60.0)/60.0));
      break;

     case "day":
      counts = (int)((float)counts/((((float)timep/60.0)/60.0)/24.0));
      break;

     case "week":
      counts = (int)((float)counts/(((((float)timep/60.0)/60.0)/24.0)/7.0));
      break;

     case "month":
      counts = (int)((float)counts/(((((float)timep/60.0)/60.0)/24.0)/30.42));
      break;

     case "year":
      counts=(int)((float)counts/(((((float)timep/60.0)/60.0)/24.0)/365.249));
      break;

    default:
      return "<!-- Per what? -->";
    }
  }

  if(prec=(int)m->precision || (int)m->prec)
  {
    n=ipow(10, prec);
    while(counts>n) { counts=(counts+5)/10; q++; }
    counts*=ipow(10, q);
  }

  switch(m->type)
  {
   case "mcdonalds":
    q=0;
    while(counts>10) { counts/=10; q++; }
    res="More than "+roxen->language("eng", "number")(counts*ipow(10, q))
        + " served.";
    break;
    
   case "linus":
    res=counts+" since "+ctime(database_created(0));
    break;

   case "ordered":
    m->type="string";
    res=number2string(counts,m,language(m->lang, "ordered"));
    break;

   default:
    res=number2string(counts,m,language(m->lang, "number"));
  }
  return res+(m->addreal?real:"");
}                  

string tag_user(string a, mapping b, object foo, object file,mapping defines);

string tag_modified(string tag, mapping m, object got, object file,
		    mapping defines)
{
  array (int) s;
  object f;
  
  if(m->by && !m->file && !m->realfile)
  {
    if(!got->conf->auth_module)
      return "<!-- modified by requires an user database! -->\n";
    m->name = roxen->last_modified_by(file, got);
    return tag_user(tag, m, got, file, defines);
  }

  if(m->file)
  {
    m->realfile = roxen->real_file(fix_relative(m->file,got), got);
    m_delete(m, "file");
  }

  if(m->by && m->realfile)
  {
    if(!got->conf->auth_module)
      return "<!-- modified by requires an user database! -->\n";

    if(f = open(m->realfile, "r"))
    {
      m->name = roxen->last_modified_by(f, got);
      destruct(f);
      return tag_user(tag, m, got, file,defines);
    }
    return "A. Nonymous.";
  }
  
  if(m->realfile)
    s = file_stat(m->realfile);

  if(!(_stat || s) && !m->realfile && got->realfile)
  {
    m->realfile = got->realfile;
    return tag_modified(tag, m, got, file, defines);
  }
  if(!s) s = _stat;
  return s ? tagtime(s[3], m) : "Error: Cannot stat file";
}

string tag_version() { return roxen->version(); }

string tag_clientname(string tag, mapping m, object got)
{
  if(m->full) 
    return got->client * " ";
  else 
    return got->client[0];
}

string tag_signature(string tag, mapping m, object got, object file,
		     mapping defines)
{
  string w;
  if(!(w=m->user || m->name))
    return "";
  return "<right><address>"+tag_user(tag, m, got, file,defines)
    +"</address></right>";
}

string tag_user(string tag, mapping m, object got, object file,mapping defines)
{
  string *u;
  string b, dom;

  if(!got->conf->auth_module)
    return "<!-- user requires an user database! -->\n";

  if (!(b=m->name)) {
    return(tag_modified("modified", m | ([ "by":"by" ]), got, file,defines));
  }

  b=m->name;

  dom=got->conf->query("Domain");
  if(dom[-1]=='.')
    dom=dom[0..strlen(dom)-2];
  if(!b) return "";
  u=roxen->userinfo(b, got);
  if(!u) return "";
  
  if(m->realname && !m->email)
  {
    if(m->link && !m->nolink)
      return "<a href=\"/~"+b+"/\">"+u[4]+"</a>";
    return u[4];
  }
  if(m->email && !m->realname)
  {
    if(m->link && !m->nolink)
      return "<a href=\"mailto:" + b + "@" + dom + "\">"
	+ b + "@" + dom + "</a>";
    return b + "@" + dom;
  }
  if(m->nolink && !m->link)
    return u[4] + " &lt;" + b + "@" + dom + "&gt;";
  return ("<a href=\"/~"+b+"/\">"+u[4]+"</a>"+
	  " <a href=\"mailto:" + b + "@" + dom + "\"> &lt;"+
	  b + "@" + dom + "&gt;</a>");
}

int match_passwd(string try, string org)
{
  if(!strlen(org))   return 1;
  if(crypt(try, org)) return 1;
}

string simple_parse_users_file(string file, string u)
{
 string line, user, pass;
 foreach(file/"\n", line)
 {
   if((sscanf(line, "%s:%s", user, pass) == 2) && (user==u))
     return pass;
 }
 return 0;
}

int match_user(array u, string user, string f, int wwwfile, object got)
{
  string s, pass;

  if(!wwwfile)
    s=read_bytes(f);
  else
    s=roxen->try_get_file(f, got);
  if(!s)
    return 0;
  if(u[1]!=user) return 0;
  pass=simple_parse_users_file(s, u[1]);
  if(!pass) return 0;
  if(u[0] == 1 && pass)
    return 1;
  return match_passwd(u[2], pass);
}

string tag_prestate(string tag, mapping m, string q, object got);
string tag_client(string tag,mapping m, string s,object got,object file);
string tag_deny(string a,  mapping b, string c, object d, object e, 
		mapping f, object g);


#define TEST(X)\
do { if(X) if(m->or) {if (QUERY(compat_if)) return "<true>"+s; else return s+"<true>";} else ok=1; else if(!m->or) return "<false>"; } while(0)

#define IS_TEST(X, Y) do                		\
{							\
  if(m->X)						\
  {							\
    string a, b;					\
    if(sscanf(m->X, "%s is %s", a, b)==2)		\
      TEST(_match(Y[a], b/","));			\
    else						\
      TEST(Y[m->X]);					\
  }							\
} while(0)


string tag_allow(string a, mapping (string:string) m, 
		 string s, object got, object file, 
		 mapping defines, object client)
{
  int ok;

  if(m->not)
  {
    m_delete(m, "not");
    return tag_deny("", m, s, got, file, defines, client);
  }

  if(m->eval) TEST((int)parse_rxml(m->eval, got));

  if(m->module)
    TEST(got->conf && got->conf->modules[m->module]);
  
  if(m->exists) TEST(roxen->try_get_file(fix_relative(m->exists,got),got,1));
  
  if(m->language)
    if(!got->misc["accept-language"])
    {
      if(!m->or)
	return "<false>";
    } else {
      TEST(_match(lower_case(got->misc["accept-language"]*" "),
		  lower_case(m->language)/","));
    }

  if(m->filename)
    TEST(_match(got->not_query, m->filename/","));

  IS_TEST(variable, got->variables);
  IS_TEST(cookie, got->cookies);
  IS_TEST(defined, defines);


  if(m->accept)
    if(!got->misc->accept)
    {
      if(!m->or)
	return "<false>";
    } else {
      TEST(glob("*"+m->accept+"*",got->misc->accept*" "));
    }

  if((m->referrer) || (m->referer))
  {
    if (!m->referrer) {
      m->referrer = m->referer;		// Backward compat
    }
    if(got && arrayp(got->referer) && sizeof(got->referer))
    {
      if(m->referrer-"r" == "efee")
      {
	if(m->or) {
	  if (QUERY(compat_if)) 
	    return "<true>" + s;
	  else
	    return s + "<true>";
	} else
	  ok=1;
      } else if (_match(got->referer*"", m->referrer/",")) {
	if(m->or) {
	  if (QUERY(compat_if))
	    return "<true>" + s;
	  else
	    return s + "<true>";
	} else
	  ok=1;
      } else if(!m->or) {
	return "<false>";
      }
    } else if(!m->or) {
      return "<false>";
    }
  }

  if(m->date)
  {
    int tok, a, b;
    mapping c;
    c=localtime(time(1));
    
    b=(int)sprintf("%02d%02d%02d", c->year, c->mon + 1, c->mday);
    a=(int)m->date;
    
    if(m->inclusive || !(m->before || m->after) && a==b)
      tok=1;

    if(m->before && a>b)
      tok=1;
    else if(m->after && a<b)
      tok=1;

    TEST(tok);
  }


  if(m->time)
  {
    int tok, a, b, d;
    mapping c;
    c=localtime(time(1));

    b=(int)sprintf("%02d%02d", c->hour, c->min);
    a=(int)m->time;

    if(m->until) {
      d = (int)m->until;
      if (d > a && (b > a && b < d) )
        tok = 1 ;
      if (d < a && (b > a || b < d) )
        tok = 1 ;
      if (m->inclusive && ( b==a || b==d ) )
        tok = 1 ;
    }
    else if(m->inclusive || !(m->before || m->after) && a==b)
      tok=1;
    if(m->before && a>b)
      tok=1;
    else if(m->after && a<b)
      tok=1;

    TEST(tok);
  }
 

  if(m->supports || m->name)
  {
    string q;
    q=tag_client("", m, s, got, file);
    TEST(q != "" && q);
  }

  if(m->wants) m->config = m->wants;
  if(m->configured) m->config = m->configured;

  if(m->config)
  {
    string c;
    foreach(m->config/",", c)
      TEST(got->config[c]);
  }

  if(m->prestate)
  {
    string q;
    q=tag_prestate("", mkmapping(m->prestate/",",m->prestate/","), s, got);
    TEST(q != "" && q);
  }

  if(m->host)
    TEST(_match(got->remoteaddr, m->host/","));

  if(m->domain)
    TEST(_match(roxen->quick_ip_to_host(got->remoteaddr), m->domain/","));
  
  if(m->user)
    if(m->user == "any")
      if(m->file)
	TEST(match_user(got->auth,got->auth[1],fix_relative(m->file,got),
			!!m->wwwfile, got));
      else
	TEST(got->auth && got->auth[0]);
    else
      if(m->file)
	TEST(match_user(got->auth,m->user,fix_relative(m->file,got),
			!!m->wwwfile, got));
      else
	TEST(got->auth && got->auth[0] && search(m->user/",", got->auth[1])
	     != -1);

  return ok?(QUERY(compat_if)?"<true>"+s:s+"<true>"):"<false>";
}

string tag_configurl()
{
  return roxen->config_url();
}

string tag_configimage(string f, mapping m)
{
  string args="";

  while(sizeof(m))
  {
    string q;
    switch(q=indices(m)[0])
    {
     case "src":
      args += " src=\"/internal-roxen-"+ (m->src-".gif") + "\"";
      break;
     default:
      args += " "+q+"=\""+m[q]+"\"";
    }
    m_delete(m, q);
  }
  return ("<img border=0 "+args+">");
}

string tag_aprestate(string tag, mapping m, string q, object got)
{
  string href, s, *foo;
  multiset prestate=(< >);

  if(!(href = m->href))
    href=strip_prestate(strip_config(got->raw_url));
  else 
  {
    if ((sizeof(foo = href / ":") > 1) && (sizeof(foo[0] / "/") == 1))
      return make_container("a",m,q);
    href=fix_relative(href, got);
    m_delete(m, "href");
  }
  
  if(!strlen(href))
    href="";

  prestate = (< @indices(got->prestate) >);

  foreach(indices(m), s) {
    if(m[s]==s) {
      m_delete(m,s);

      if(strlen(s) && s[0] == '-')
	prestate[s[1..]]=0;
      else
	prestate[s]=1;
    }
  }
  m->href = add_pre_state(href, prestate);
  return make_container("a",m,q);
}

string tag_aconfig(string tag, mapping m, string q, object got)
{
  string href;
  mapping(string:string) cookies = ([]);

  if(!m->href)
    href=strip_prestate(strip_config(got->raw_url));
  else 
  {
    href=m->href;
    if (search(href, ":") == search(href, "//")-1)
      return sprintf("<!-- Cannot add configs to absolute URLs -->\n"
		     "<a href=\"%s\">%s</a>", href, q);
    href=fix_relative(href, got);
    m_delete(m, "href");
  }

  foreach(indices(m), string opt) {
    if(m[opt]==opt) {
      if(strlen(opt)) {
	switch(opt[0]) {
	case '+':
	  m_delete(m, opt);
	  cookies[opt[1..]] = opt;
	  break;
	case '-':
	  m_delete(m, opt);
	  cookies[opt] = opt;
	  break;
	}
      }
    }
  }
  m->href = add_config(href, indices(cookies), got->prestate);
  return make_container("a", m, q);
}

string add_header(mapping to, string name, string value)
{
  if(to[name])
    if(arrayp(to[name]))
      to[name] += ({ value });
    else
      to[name] = ({ to[name], value });
  else
    to[name] = value;
}

string tag_add_cookie(string tag, mapping m, object got, object file,
		      mapping defines)
{
  string cookies;
  
  if(m->name)
    cookies = m->name+"="+http_encode_cookie(m->value||"")
      +(m->persistent?"; expires=Sun, 29-Dec-99 23:59:59 GMT; path=/":"");
  else
    return "<!-- set_cookie requires a `name' -->";

  add_header(_extra_heads, "Set-Cookie", cookies);

  return "";
}

string tag_remove_cookie(string tag, mapping m, object got, object file,
			 mapping defines)
{
  string cookies;
  if(m->name)
    cookies = m->name+"="+http_encode_cookie(m->value||"")+
      "; expires="+http_date(0)+"; path=/";
  else
    return "<!-- remove_cookie requires a `name' -->";

  add_header(_extra_heads, "Set-Cookie", cookies);
  return "";
}

string tag_prestate(string tag, mapping m, string q, object got)
{
  int ok, not=!!m->not, or=!!m->or;
  multiset pre=got->prestate;
  string s;

  foreach(indices(m), s)
    if(pre[s])
    {
      if(not) 
	if(!or)
	  return "";
	else
	  ok=0;
      else if(or)
	return q;
      else
	ok=1;
    } else {
      if(not)
	if(or)
	  return q;
	else
	  ok=1;
      else if(!or)
	return "";
    }
  return ok?q:"";
}

string tag_false(string tag, mapping m, object got, object file,
		 mapping defines, object client)
{
  _ok = 0;
  return "";
}

string tag_true(string tag, mapping m, object got, object file,
		mapping defines, object client)
{
  _ok = 1;
  return "";
}

string tag_if(string tag, mapping m, string s, object got, object file,
	      mapping defines, object client)
{
  string res, a, b;
  if(sscanf(s, "%s<otherwise>%s", a, b) == 2)
  {
    // compat_if mode?
    if (QUERY(compat_if)) {
      res=tag_allow(tag, m, a, got, file, defines, client);
      if (res == "<false>") {
	return b;
      }
    } else {
      res=tag_allow(tag, m, a, got, file, defines, client) +
	"<else>" + b + "</else>";
    }
  } else {
    res=tag_allow(tag, m, s, got, file, defines, client);
  }
  return res;
}

string tag_deny(string tag, mapping m, string s, object got, object file, 
		mapping defines, object client)
{
  if(m->not)
  {
    m->not = 0;
    return tag_if(tag, m, s, got, file, defines, client);
  }
  if(tag_if(tag,m,s,got,file,defines,client) == "<false>") {
    if (QUERY(compat_if)) {
      return "<true>"+s;
    } else {
      return s+"<true>";
    }
  }
  return "<false>";
}


string tag_else(string tag, mapping m, string s, object got, object file, 
		mapping defines) 
{ 
  return _ok?"":s; 
}

string tag_elseif(string tag, mapping m, string s, object got, object file, 
		  mapping defines, object client) 
{ 
  return _ok?"":tag_if(tag, m, s, got, file, defines, client); 
}

string tag_client(string tag,mapping m, string s,object got,object file)
{
  int isok, invert;

  if (m->not) invert=1; 

  if (m->supports)
    isok=!! got->supports[m->supports];

  if (m->support)
    isok=!!got->supports[m->support];

  if (!(isok && m->or) && m->name)
    isok=_match(got->client*" ",
		map(m->name/",", lambda(string s){return s+"*";}));
  return (isok^invert)?s:""; 
}

string tag_return(string tag, mapping m, object got, object file,
		  mapping defines)
{
  if(m->code)_error=(int)m->code || 200;
  if(m->text)_rettext=m->text;
  return "";
}

string tag_referer(string tag, mapping m, object got, object file,
		   mapping defines)
{
  if(got->referer)
    return sizeof(got->referer)?got->referer*"":m->alt?m->alt:"..";
  return m->alt?m->alt:"..";
}

string tag_header(string tag, mapping m, object got, object file,
		  mapping defines)
{
  if(m->name == "WWW-Authenticate")
  {
    string r;
    if(m->value)
    {
      if(!sscanf(m->value, "Realm=%s", r))
	r=m->value;
    } else {
      r="Users";
    }
    m->value="basic realm=\""+r+"\"";
  } else if(m->name=="URI") {
    m->value = "<" + m->value + ">";
  }
  
  if(!(m->value && m->name))
    return "<!-- Header requires booth a name and a value. -->";

  add_header(_extra_heads, m->name, m->value);
  return "";
}

string tag_expire_time(string tag, mapping m, object got, object file,
		       mapping defines)
{
  int t=time();
  if (m->hours) t+=((int)(m->hours))*3600;
  if (m->minutes) t+=((int)(m->hours))*60;
  if (m->seconds) t+=((int)(m->hours));
  if (m->days) t+=((int)(m->hours))*(24*3600);
  if (m->weeks) t+=((int)(m->hours))*(24*3600*7);
  if (m->months) t+=((int)(m->hours))*(24*3600*30+37800); /* 30.46d */
  if (m->years) t+=((int)(m->hours))*(3600*(24*365+6));   /* 365.25d */
  add_header(_extra_heads, "Expires", http_date(t));
  return "";
}

string tag_file(string tag, mapping m, object got)
{
  if(m->raw)
    return http_decode_string(got->raw_url);
  else
    return got->not_query;
}

string tag_realfile(string tag, mapping m, object got)
{
  return got->realfile || "unknown";
}

string tag_vfs(string tag, mapping m, object got)
{
  return got->virtfile || "unknown";
}

string tag_language(string tag, mapping m, object got)
{
  if(!got->misc["accept-language"])
    return "None";

  if(m->full)
    return got->misc["accept-language"]*"";
  else
    return (got->misc["accept-language"][0]/";")[0];
}

string tag_quote(string tagname, mapping m)
{
#if efun(set_start_quote)
  if(m->start && strlen(m->start))
    set_start_quote(m->start[0]);
  if(m->end && strlen(m->end))
    set_end_quote(m->end[0]);
#endif
  return "";
}

string tag_ximage(string tagname, mapping m, object id)
{
  string img = id->conf->real_file(fix_relative(m->src||"", id));
  if(img && search(img, ".gif")!=-1) {
    object fd = open(img, "r");
    if(fd) {
      int x, y;
      sscanf(gif_size(fd), "width=%d height=%d", x, y);
      m->width=x;
      m->height=y;
    }
  }
  return make_tag("img", m);
}

mapping pr_sizes = ([]);
string get_pr_size(string size, string color)
{
  if(pr_sizes[size+color]) return pr_sizes[size+color];
  object fd = open("roxen-images/power-"+size+"-"+color+".gif", "r");
  if(!fd) return "NONEXISTANT COMBINATION";
  return pr_sizes[size+color] = gif_size( fd );
}

string tag_pr(string tagname, mapping m)
{
  string size = m->size || "small";
  string color = m->color || "blue";
  if(m->help)
    return "Syntax: "
      "&lt;pr [size=large|small|medium] [color=blue|brown|green|purple]&gt;"
      "<br>All colors are not available in all sizes, available choices:<br>"
      "<pr list><br>The default size is small, the default color is blue\n";

  if(m->list)
  {
    string res = "<table><tr><td><b>size</b></td><td><b>color</b></td></tr>";
    foreach(sort(get_dir("roxen-images")), string f)
      if(sscanf(f, "power-%s", f))
	res += "<tr><td>"+replace(f-".gif","-","</td><td>")+"</tr>";
    return res + "</table>";
  }
  return ("<a href=http://www.roxen.com/><img border="+m->border+" "+
	  get_pr_size(size,color)+" "+
	  "src=/internal-roxen-power-"+size+"-"+color+"></a>");
}


mapping query_tag_callers()
{
   return (["accessed":tag_accessed,
	    "modified":tag_modified,
	    "pr":tag_pr,
	    "imgs":tag_ximage,
	    "version":tag_version,
	    "set":tag_set,
 	    "set_cookie":tag_add_cookie,
 	    "remove_cookie":tag_remove_cookie,
	    "clientname":tag_clientname,
	    "configurl":tag_configurl,
	    "configimage":tag_configimage,
	    "date":tag_date,
	    "referer":tag_referer,
	    "referrer":tag_referer,
	    "refferrer":tag_referer,
	    "referererer":tag_referer,
	    "refferrerr":tag_referer,
	    "accept-language":tag_language,
	    "insert":tag_insert,
	    "return":tag_return,
	    "file":tag_file,
	    "realfile":tag_realfile,
	    "vfs":tag_vfs,
	    "header":tag_header,
	    "expire_time":tag_expire_time,
	    "signature":tag_signature,
	    "user":tag_user,
 	    "quote":tag_quote,
	    "true":tag_true,	// Used internally
	    "false":tag_false,	// by <if> and <else>
	    "!--#echo":tag_compat_echo,           /* These commands are */
	    "!--#exec":tag_compat_exec,           /* NCSA/Apache Server */
	    "!--#flastmod":tag_compat_fsize,      /* Side includes.     */
	    "!--#fsize":tag_compat_fsize, 
	    "!--#include":tag_compat_include, 
	    "!--#config":tag_compat_config, 
	    ]);
}

string tag_source(string tag,mapping m, string s,object got,object file)
{
  string sep;
  sep=m["separator"]||"";
  if(!m->nohr)
    sep="<hr><h2>"+sep+"</h2><hr>";
  return ("<pre>"+replace(s, ({"<",">","&"}),({"&lt;","&gt;","&amp;"}))
	  +"</pre>"+sep+s);
}

string tag_source2(string tag,mapping m, string s,object got,object file)
{
  if(!m["magic"])
    if(m["pre"])
      return "\n<pre>"+
	replace(s, ({"{","}","&"}),({"&lt;","&gt;","&amp;"}))+"</pre>\n";
    else
      return replace(s, ({ "{", "}", "&" }), ({ "&lt;", "&gt;", "&amp;" }));
  else 
    if(m["pre"])
      return "\n<pre>"+
	replace(s, ({"<",">","&"}),({"&lt;","&gt;","&amp;"}))+"</pre>\n";
    else
      return replace(s, ({ "<", ">", "&" }), ({ "&lt;", "&gt;", "&amp;" }));
}

string tag_smallcaps(string t, mapping m, string s)
{
  string build="";
  int i,lc=1,j;
  string small=m->small;
  if (m->size)
  {
    build="<font size="+m->size+">";
    if (!small)
    {
      if (m->size[0]=='+') small="+"+(((int)m->size[1..10])-1);
      else if (m->size[0]=='-') small="-"+(((int)m->size[1..10])+1);
      else small=""+(((int)m->size)-1);
    }
  } else if (!small) small="-1";
  
  for (i=0; i<strlen(s); i++)
    if (s[i]=='<') 
    { 
      if (!lc) 
      { 
	build+="</font>";
	lc=1; 
      }
      for (j = i;j < strlen(s) && s[j] != '>'; j++);
      build += s[i..j];
      i = j;
    }
    else if (s[i]<=32) 
    { 
      if (!lc) build+="</font>"+s[i..i]; 
      else 
	build+=s[i..i]; 
      lc=1; 
    }
    else if (s[i]&64)
      if (s[i]&32) 
      { 
	if (lc) 
	  build+="<font size="+small+">"+sprintf("%c",s[i]-32)
	    +(m->space?"&nbsp;":""); 
	else 
	  build+=sprintf("%c",s[i]-32)+(m->space?"&nbsp;":""); lc=0; }
      else { 
	if (!lc) 
	  build+="</font>"+s[i..i]+(m->space?"&nbsp;":""); 
	else 
	  build+=s[i..i]+(m->space?"&nbsp;":""); 
	lc=1; 
      }
    else 
      build+=s[i..i]+(m->space?"&nbsp;":"");
  if (!lc) 
    build+="</font>"; 
  if (m->size) 
    build+="</font>";
  return build;
}

string tag_random(string tag, mapping m, string s)
{
  mixed q;
  if(!(q=m->separator || m->sep))
    return (q=s/"\n")[random(sizeof(q))];
  else
    return (q=s/q)[random(sizeof(q))];
}

string tag_right(string t, mapping m, string s, object got)
{
  if(got->supports->alignright)
    return "<p align=right>"+s+"</p>";
  
  return "<table width=100%><tr><td align=right>"+s+"</td></tr></table>";
}

string tag_formoutput(string tag_name, mapping args, string contents,
		      object request_id, mapping defines)
{
  string nullvalue = args->nullvalue || "";
  string quote = args->quote || "#";
  string multi_separator = args->multi_separator || ", ";
  array(string) content_array = contents/quote;
  int i;

  for (i=1; i < sizeof(content_array); i += 2) {
    mixed var_value = request_id->variables[content_array[i]];

    if (content_array[i] == "") {
      content_array[i] = quote;
    } else if (var_value) {
      if (arrayp(var_value)) {
	content_array[i] = var_value * multi_separator;
      } else if (search( var_value, "\000" ) != -1 ) {
        content_array[i] = (var_value / "\000") * multi_separator;
      } else {
	content_array[i] = var_value;
      }
    } else {
      content_array[i] = nullvalue;
    }
    content_array[i] = replace(content_array[i],
			       ({ "<", ">", "&", "\"", "\'" }),
			       ({ "&lt;", "&gt;", "&amp;", "&#34;", "&#39;" }));
  }
  return(content_array*"");
}

mapping query_container_callers()
{
  return (["comment":lambda(){ return ""; },
	   "source":tag_source,
	   "doc":tag_source2,
	   "random":tag_random,
	   "define":tag_define,
	   "right":tag_right,
	   "client":tag_client,
	   "if":tag_if,
	   "elif":tag_elseif,
	   "else if":tag_elseif,
	   "elseif":tag_elseif,
	   "else":tag_else,
	   "allow":tag_if,
	   "prestate":tag_prestate,
	   "apre":tag_aprestate,
	   "aconf":tag_aconfig,
	   "aconfig":tag_aconfig,
	   "deny":tag_deny,
	   "smallcaps":tag_smallcaps,
	   "formoutput":tag_formoutput,
	   ]);
}

int may_disable()  { return 0; }
