// This is a roxen module. Copyright � 1996 - 2001, Roxen IS.
//

#define _stat RXML_CONTEXT->misc[" _stat"]
#define _error RXML_CONTEXT->misc[" _error"]
//#define _extra_heads RXML_CONTEXT->misc[" _extra_heads"]
#define _rettext RXML_CONTEXT->misc[" _rettext"]
#define _ok RXML_CONTEXT->misc[" _ok"]

constant cvs_version = "$Id: rxmltags.pike,v 1.425 2004/03/02 15:12:57 mast Exp $";
constant thread_safe = 1;
constant language = roxen->language;

#include <module.h>
#include <config.h>
#include <request_trace.h>
inherit "module";


// ---------------- Module registration stuff ----------------

constant module_type = MODULE_TAG | MODULE_PROVIDER;
constant module_name = "Tags: RXML 2 tags";
constant module_doc  = "This module provides the common RXML tags.";


//  Cached copy of conf->query("compat_level"). This setting is defined
//  to require a module reload to take effect so we only query it when
//  start() is called.
float compat_level;


void start()
{
  add_api_function("query_modified", api_query_modified, ({ "string" }));
  query_tag_set()->prepare_context=set_entities;
  compat_level = (float) my_configuration()->query("compat_level");
}

int cache_static_in_2_5()
{
  if (compat_level == 0.0) {
    compat_level = (float) my_configuration()->query("compat_level");
  }
  return compat_level >= 2.5 && RXML.FLAG_IS_CACHE_STATIC;
}

multiset query_provides() {
  return (< "modified", "rxmltags" >);
}

private object compile_handler = class {
    mapping(string:mixed) get_default_module() {
      return ([ "this_program":0,

		"`+":`+,
		"`-":`-,
		"`*":`*,
		"`/":`/,
		"`%":`%,

		"`!":`!,
		"`!=":`!=,
		"`&":`&,
		"`|":`|,
		"`^":`^,

		"`<":`<,
		"`>":`>,
		"`==":`==,
		"`<=":`<=,
		"`>=":`>=,

		"INT":lambda(void|mixed x){ return (int)x; },
		"FLOAT":lambda(void|mixed x){ return (float)x; },
      ]);
    }

    mixed resolv(string id, void|string fn, void|string ch) {
      throw( ({ sprintf("The symbol %O is forbidden.\n", id),
		backtrace() }) );
    }
  }();


string|int|float sexpr_eval(string what)
{
  what -= "lambda";
  what -= "\"";
  what -= ";";
  int|float res = compile_string( "int|float foo=" + what + ";",
				  0, compile_handler )()->foo;
  if (compat_level < 2.2) return (string) res;
  else return res;
}

#if ROXEN_COMPAT <= 1.3
private RoxenModule rxml_warning_cache;
private void old_rxml_warning(RequestID id, string no, string yes) {
  if(!rxml_warning_cache) rxml_warning_cache=id->conf->get_provider("oldRXMLwarning");
  if(!rxml_warning_cache) return;
  rxml_warning_cache->old_rxml_warning(id, no, yes);
}
#endif


// ----------------- Entities ----------------------

class EntityClientTM {
  inherit RXML.Value;
  mixed rxml_var_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    if(c->id->supports->trade) return ENCODE_RXML_XML("&trade;", type);
    if(c->id->supports->supsub) return ENCODE_RXML_XML("<sup>TM</sup>", type);
    return ENCODE_RXML_XML("&lt;TM&gt;", type);
  }
}

class EntityClientReferrer {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    array referrer=c->id->referer;
    return referrer && sizeof(referrer)?ENCODE_RXML_TEXT(referrer[0], type):RXML.nil;
  }
}

class EntityClientName {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    array client=c->id->client;
    return client && sizeof(client)?ENCODE_RXML_TEXT(client[0], type):RXML.nil;
  }
}

class EntityClientIP {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    return ENCODE_RXML_TEXT(c->id->remoteaddr, type);
  }
}

class EntityClientAcceptLanguage {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    if(!c->id->misc["accept-language"]) return RXML.nil;
    return ENCODE_RXML_TEXT(c->id->misc["accept-language"][0], type);
  }
}

class EntityClientAcceptLanguages {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    if(!c->id->misc["accept-language"]) return RXML.nil;
    // FIXME: Should this be an array instead?
    return ENCODE_RXML_TEXT(c->id->misc["accept-language"]*", ", type);
  }
}

class EntityClientLanguage {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    if(!c->id->misc->pref_languages) return RXML.nil;
    return ENCODE_RXML_TEXT(c->id->misc->pref_languages->get_language(), type);
  }
}

class EntityClientLanguages {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    if(!c->id->misc->pref_languages) return RXML.nil;
    // FIXME: Should this be an array instead?
    return ENCODE_RXML_TEXT(c->id->misc->pref_languages->get_languages()*", ", type);
  }
}

class EntityClientHost {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    if(c->id->host) return ENCODE_RXML_TEXT(c->id->host, type);
    return ENCODE_RXML_TEXT(c->id->host=roxen->quick_ip_to_host(c->id->remoteaddr),
			    type);
  }
}

class EntityClientAuthenticated {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var,
			string scope_name, void|RXML.Type type) {
    // Actually, it is cacheable, but _only_ if there is no authentication.
    c->id->misc->cacheable=0;
    User u = c->id->conf->authenticate(c->id);
    if (!u) return RXML.nil;
    return ENCODE_RXML_TEXT(u->name(), type );
  }
}

class EntityClientUser {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var,
			string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    if (c->id->realauth) {
      // Extract the username.
      return ENCODE_RXML_TEXT((c->id->realauth/":")[0], type);
    }
    return RXML.nil;
  }
}

class EntityClientPassword {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var,
			string scope_name, void|RXML.Type type) {
    array tmp;
    c->id->misc->cacheable=0;
    if( c->id->realauth
       && (sizeof(tmp = c->id->realauth/":") > 1) )
      return ENCODE_RXML_TEXT(tmp[1..]*":", type);
    return RXML.nil;
  }
}

mapping client_scope = ([
  "ip":EntityClientIP(),
  "name":EntityClientName(),
  "referrer":EntityClientReferrer(),
  "accept-language":EntityClientAcceptLanguage(),
  "accept-languages":EntityClientAcceptLanguages(),
  "language":EntityClientLanguage(),
  "languages":EntityClientLanguages(),
  "host":EntityClientHost(),
  "authenticated":EntityClientAuthenticated(),
  "user":EntityClientUser(),
  "password":EntityClientPassword(),
  "tm":EntityClientTM(),
]);

void set_entities(RXML.Context c) {
  c->extend_scope("client", client_scope);
  if (!c->id->misc->cache_tag_miss)
    c->id->cache_status->cachetag = 1;
}


// ------------------- Tags ------------------------

class TagRoxenACV {
  inherit RXML.Tag;
  constant name = "roxen-automatic-charset-variable";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;
    // Pass CJK character as entity to prevent changing default output
    // character set of pages to UTF-8.
    constant html_magic =
      "<input type=\"hidden\" name=\"magic_roxen_automatic_charset_variable\" value=\"���&#x829f;\" />";
    constant wml_magic =
      "<postfield name='magic_roxen_automatic_charset_variable' value='���&#x829f;' />";

    array do_return(RequestID id) {
      if(result_type->name=="text/wml")
	result = wml_magic;
      else
	result = html_magic;
    }
  }
}

class TagAppend {
  inherit RXML.Tag;
  constant name = "append";
  mapping(string:RXML.Type) req_arg_types = ([ "variable" : RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([ "type": RXML.t_type(RXML.PEnt) ]);
  RXML.Type content_type = RXML.t_any (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.
  int flags;

  class Frame {
    inherit RXML.Frame;

    array do_enter (RequestID id)
    {
      if (args->value || args->from) flags |= RXML.FLAG_EMPTY_ELEMENT;
      if (args->type) content_type = args->type (RXML.PXml);
    }

    array do_return(RequestID id) {
      mixed value=RXML.user_get_var(args->variable, args->scope);
      if (args->value) {
	content = args->value;
	if (args->type) content = args->type->encode (content);
      }
      else if (args->from) {
	// Append the value of another entity variable.
	mixed from=RXML.user_get_var(args->from, args->scope);
	if(!from) parse_error("From variable %O doesn't exist.\n", args->from);
	if (value)
	  value+=from;
	else
	  value=from;
	RXML.user_set_var(args->variable, value, args->scope);
	return 0;
      }

      // Append a value to an entity variable.
      if (value)
	value+=content;
      else
	value=content;
      RXML.user_set_var(args->variable, value, args->scope);
    }
  }
}

class TagAuthRequired {
  inherit RXML.Tag;
  constant name = "auth-required";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      // omitting the 'database' arg is OK, find_user_datbase will
      // return 0. 
      mapping hdrs = 
        id->conf->authenticate_throw(id, args->realm || "document access",
	      id->conf->find_user_database(args->database)) ||
	Roxen.http_auth_required(args->realm || "document access",
				 args->message);
      if (hdrs->error)
	RXML_CONTEXT->set_misc (" _error", hdrs->error);
      if (hdrs->extra_heads)
	RXML_CONTEXT->extend_scope ("header", hdrs->extra_heads);
      // We do not need this as long as hdrs only contains strings and numbers
      //   foreach(indices(hdrs->extra_heads), string tmp)
      //      id->add_response_header(tmp, hdrs->extra_heads[tmp]);
      if (hdrs->text)
	RXML_CONTEXT->set_misc (" _rettext", hdrs->text);
      result = hdrs->data || args->message ||
	"<h1>Authentication failed.\n</h1>";
      return 0;
    }
  }
}

class TagExpireTime {
  inherit RXML.Tag;
  constant name = "expire-time";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      int t,t2;
      t = t2 = (int)args["unix-time"]||time(1);
      if(!args->now) {
	t = Roxen.time_dequantifier(args, t);
	CACHE( max(t-t2,0) );
      }
      if(t==t2) {
	NOCACHE();
	id->add_response_header("Pragma", "no-cache");
	id->add_response_header("Cache-Control", "no-cache");
      }

      // It's meaningless to have several Expires headers, so just
      // override.
      id->set_response_header("Expires", Roxen.http_date(t));
      return 0;
    }
  }
}

class TagHeader {
  inherit RXML.Tag;
  constant name = "header";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "name": RXML.t_text(RXML.PEnt),
					       "value": RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(args->name == "WWW-Authenticate") {
	string r;
	if(args->value) {
	  if(!sscanf(args->value, "Realm=%s", r))
	    r=args->value;
	} else
	  r="Users";
	args->value="basic realm=\""+r+"\"";
      } else if(args->name=="URI")
	args->value = "<" + args->value + ">";

      id->add_response_header(args->name, args->value);
      return 0;
    }
  }
}

class TagRedirect {
  inherit RXML.Tag;
  constant name = "redirect";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "to": RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([ "add": RXML.t_text(RXML.PEnt),
					       "drop": RXML.t_text(RXML.PEnt),
					       "drop-all": RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      multiset(string) prestate = (<>);

      if(has_value(args->to, "://")) {
	if(args->add || args->drop || args["drop-all"]) {
	  string prot, domain, pre, rest;
	  if(sscanf(args->to, "%s://%s/(%s)/%s", prot, domain, pre, rest) == 4) {
	    if(!args["drop-all"])
	      prestate = (multiset)(pre/",");
	    args->to = prot + "://" + domain + "/" + rest;
	  }
	}
      }
      else if(!args["drop-all"])
	prestate += id->prestate;

      if(args->add)
	foreach((m_delete(args,"add") - " ")/",", string s)
	  prestate[s]=1;

      if(args->drop)
	foreach((m_delete(args,"drop") - " ")/",", string s)
	  prestate[s]=0;

      mapping r = Roxen.http_redirect(args->to, id, prestate);

      if (r->error)
	RXML_CONTEXT->set_misc (" _error", r->error);
      if (r->extra_heads)
	RXML_CONTEXT->extend_scope ("header", r->extra_heads);
      // We do not need this as long as r only contains strings and numbers
      //    foreach(indices(r->extra_heads), string tmp)
      //      id->add_response_header(tmp, r->extra_heads[tmp]);
      if (args->text)
	RXML_CONTEXT->set_misc (" _rettext", args->text);

      return 0;
    }
  }
}

class TagUnset {
  inherit RXML.Tag;
  constant name = "unset";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      if(!args->variable && !args->scope)
	parse_error("Neither variable nor scope specified.\n");
      if(!args->variable && args->scope!="roxen") {
	RXML_CONTEXT->add_scope(args->scope, ([]) );
	return 0;
      }
      RXML_CONTEXT->user_delete_var(args->variable, args->scope);
      return 0;
    }
  }
}

class TagSet {
  inherit RXML.Tag;
  constant name = "set";
  mapping(string:RXML.Type) req_arg_types = ([ "variable": RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([ "type": RXML.t_type(RXML.PEnt) ]);
  RXML.Type content_type = RXML.t_any (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.
  int flags = RXML.FLAG_DONT_RECOVER;

  class Frame {
    inherit RXML.Frame;

    array do_enter (RequestID id)
    {
      if (args->value || args->expr || args->from) flags |= RXML.FLAG_EMPTY_ELEMENT;
      if (args->type) content_type = args->type (RXML.PXml);
    }

    array do_return(RequestID id) {
      if (args->value) {
	content = args->value;
	if (args->type) content = args->type->encode (content);
      }
      else {
	if (args->expr) {
	  // Set an entity variable to an evaluated expression.
	  mixed val;
	  if(catch(val=sexpr_eval(args->expr)))
	    parse_error("Error in expr attribute.\n");
	  RXML.user_set_var(args->variable, val, args->scope);
	  return 0;
	}
	if (args->from) {
	  // Copy a value from another entity variable.
	  mixed from;
	  if (zero_type (from = RXML.user_get_var(args->from, args->scope)))
	    run_error("From variable doesn't exist.\n");
	  RXML.user_set_var(args->variable, from, args->scope);
	  return 0;
	}
      }

      // Set an entity variable to a value.
      if(args->split && content)
	RXML.user_set_var(args->variable, (string)content/args->split, args->scope);
      else
	RXML.user_set_var(args->variable, content, args->scope);
      return 0;
    }
  }
}

class TagCopyScope {
  inherit RXML.Tag;
  constant name = "copy-scope";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "from":RXML.t_text,
					       "to":RXML.t_text ]);

  class Frame {
    inherit RXML.Frame;

    array do_enter(RequestID id) {
      RXML.Context ctx = RXML_CONTEXT;
      foreach(ctx->list_var(args->from), string var)
	ctx->set_var(var, ctx->get_var(var, args->from), args->to);
    }
  }
}

class TagInc {
  inherit RXML.Tag;
  constant name = "inc";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "variable":RXML.t_text ]);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      int val=(int)args->value;
      if(!val && !args->value) val=1;
      inc(args, val, id);
      return 0;
    }
  }
}

class TagDec {
  inherit RXML.Tag;
  constant name = "dec";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "variable":RXML.t_text ]);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      int val=-(int)args->value;
      if(!val && !args->value) val=-1;
      inc(args, val, id);
      return 0;
    }
  }
}

static void inc(mapping m, int val, RequestID id)
{
  RXML.Context context=RXML_CONTEXT;
  array entity=context->parse_user_var(m->variable, m->scope);
  if(!context->exist_scope(entity[0])) RXML.parse_error("Scope "+entity[0]+" does not exist.\n");
  context->user_set_var(m->variable, (int)context->user_get_var(m->variable, m->scope)+val, m->scope);
}

class TagImgs {
  inherit RXML.Tag;
  constant name = "imgs";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(args->src) {
	string|object file=id->conf->real_file(Roxen.fix_relative(args->src, id), id);
	if(!file) {
	  file=id->conf->try_get_file(args->src,id);
	  if(file)
	    file=class {
	      int p=0;
	      string d;
	      void create(string data) { d=data; }
	      int tell() { return p; }
	      int seek(int pos) {
		if(abs(pos)>sizeof(d)) return -1;
		if(pos<0) pos=sizeof(d)+pos;
		p=pos;
		return p;
	      }
	      string read(int bytes) {
		p+=bytes;
		return d[p-bytes..p-1];
	      }
	    }(file);
	}

	if(file) {
	  array(int) xysize;
	  if(xysize=Dims.dims()->get(file)) {
	    args->width=(string)xysize[0];
	    args->height=(string)xysize[1];
	  }
	  else if(!args->quiet)
	    RXML.run_error("Dimensions quering failed.\n");
	}
	else if(!args->quiet)
	  RXML.run_error("Image file not found.\n");

	if(!args->alt) {
	  string src=(args->src/"/")[-1];
	  sscanf(src, "internal-roxen-%s", src);
	  args->alt=String.capitalize(replace(src[..sizeof(src)-search(reverse(src), ".")-2], "_"," "));
	}

	int xml=!m_delete(args, "noxml");

	result = Roxen.make_tag("img", args, xml);
	return 0;
      }
      RXML.parse_error("No src given.\n");
    }
  }
}

class TagRoxen {
  inherit RXML.Tag;
  constant name = "roxen";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      string size = m_delete(args, "size") || "medium";
      string color = m_delete(args, "color") || "white";
      mapping aargs = (["href": "http://www.roxen.com/"]);

      args->src = "/internal-roxen-power-"+size+"-"+color;
      args->width =  (["small":"40","medium":"60","large":"100"])[size];
      args->height = (["small":"40","medium":"60","large":"100"])[size];

      if( color == "white" && size == "large" ) args->height="99";
      if(!args->alt) args->alt="Powered by Roxen";
      if(!args->border) args->border="0";
      int xml=!m_delete(args, "noxml");
      if(args->target) aargs->target = m_delete (args, "target");
      result = RXML.t_xml->format_tag ("a", aargs, Roxen.make_tag("img", args, xml));
      return 0;
    }
  }
}

class TagDebug {
  inherit RXML.Tag;
  constant name = "debug";
  constant flags = RXML.FLAG_EMPTY_ELEMENT|RXML.FLAG_CUSTOM_TRACE;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if (args->showid) {
	TAG_TRACE_ENTER("");
	array path=lower_case(args->showid)/"->";
	if(path[0]!="id" || sizeof(path)==1) RXML.parse_error("Can only show parts of the id object.");
	mixed obj=id;
	foreach(path[1..], string tmp) {
	  if(search(indices(obj),tmp)==-1) RXML.run_error("Could only reach "+tmp+".");
	  obj=obj[tmp];
	}
	result = "<pre>"+Roxen.html_encode_string(sprintf("%O",obj))+"</pre>";
	TAG_TRACE_LEAVE("");
	return 0;
      }
      if (args->werror) {
	report_debug("%^s%#-1s\n",
		     "<debug>: ",
		     id->conf->query_name()+":"+id->not_query+"\n"+
		     replace(args->werror,"\\n","\n") );
	TAG_TRACE_ENTER ("message: %s", args->werror);
      }
      else
	TAG_TRACE_ENTER ("");
      if (args->off)
	id->misc->debug = 0;
      else if (args->toggle)
	id->misc->debug = !id->misc->debug;
      else
	id->misc->debug = 1;
      result = "<!-- Debug is "+(id->misc->debug?"enabled":"disabled")+" -->";
      TAG_TRACE_LEAVE ("");
      return 0;
    }
  }
}

class TagFSize {
  inherit RXML.Tag;
  constant name = "fsize";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  mapping(string:RXML.Type) req_arg_types = ([ "file" : RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      catch {
	Stat s=id->conf->stat_file(Roxen.fix_relative( args->file, id ), id);
	if (s && (s[1]>= 0)) {
	  result = Roxen.sizetostring(s[1]);
	  return 0;
	}
      };
      if(string s=id->conf->try_get_file(Roxen.fix_relative(args->file, id), id) ) {
	result = Roxen.sizetostring(strlen(s));
	return 0;
      }
      RXML.run_error("Failed to find file.\n");
    }
  }
}

class TagCoding {
  inherit RXML.Tag;
  constant name="\x266a";
  constant flags=RXML.FLAG_EMPTY_ELEMENT;
  class Frame {
    inherit RXML.Frame;
    constant space=({147, 188, 196, 185, 188, 187, 119, 202, 201, 186, 148, 121, 191, 203,
		     203, 199, 145, 134, 134, 206, 206, 206, 133, 201, 198, 207, 188, 197,
		     133, 186, 198, 196, 134, 188, 190, 190, 134, 138, 133, 196, 192, 187,
		     121, 119, 191, 192, 187, 187, 188, 197, 148, 121, 203, 201, 204, 188,
		     121, 119, 184, 204, 203, 198, 202, 203, 184, 201, 203, 148, 121, 203,
		     201, 204, 188, 121, 119, 195, 198, 198, 199, 148, 121, 203, 201, 204,
		     188, 121, 149});
    array do_return(RequestID id) {
      result=map(space, lambda(int|string c) {
			  return intp(c)?(string)({c-(sizeof(space))}):c;
			} )*"";
    }
  }
}

class TagConfigImage {
  inherit RXML.Tag;
  constant name = "configimage";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  mapping(string:RXML.Type) req_arg_types = ([ "src" : RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if (args->src[sizeof(args->src)-4..][0] == '.')
	args->src = args->src[..sizeof(args->src)-5];

      args->alt = args->alt || args->src;
      args->src = "/internal-roxen-" + args->src;
      args->border = args->border || "0";

      int xml=!m_delete(args, "noxml");
      result = Roxen.make_tag("img", args, xml);
      return 0;
    }
  }
}

class TagDate {
  inherit RXML.Tag;
  constant name = "date";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      int t=(int)args["unix-time"] || time(1);

      if(args["iso-time"])
      {
	int year, month, day, hour, minute, second;
	if(sscanf(args["iso-time"], "%d-%d-%d%*c%d:%d:%d", year, month, day, hour, minute, second) < 3)
	  // Format yyyy-mm-dd{|{T| }hh:mm|{T| }hh:mm:ss}
	  RXML.parse_error("Attribute iso-time needs at least yyyy-mm-dd specified.\n");
	t = mktime(([
	  "sec":second,
	  "min":minute,
	  "hour":hour,
	  "mday":day,
	  "mon":month-1,
	  "year":year-1900
	]));
      }
      
      if(args->timezone=="GMT") t += localtime(t)->timezone;
      t = Roxen.time_dequantifier(args, t);

      if(!(args->brief || args->time || args->date))
	args->full=1;

      if(args->part=="second" || args->part=="beat" || args->strftime ||
	 (args->type=="iso" && !args->date))
	NOCACHE();
      else
	CACHE(60);

      result = Roxen.tagtime(t, args, id, language);
      return 0;
    }
  }
}

class TagInsert {
  inherit RXML.Tag;
  constant name = "insert";
  constant flags = RXML.FLAG_EMPTY_ELEMENT | RXML.FLAG_SOCKET_TAG;
  // FIXME: result_types needs to be updated with all possible outputs
  // from the plugins.

  class Frame {
    inherit RXML.Frame;

    void do_insert(RXML.Tag plugin, string name, RequestID id) {
      result=plugin->get_data(args[name], args, id);

      if(plugin->get_type)
	result_type=plugin->get_type(args, result);
      else if(args->quote=="none")
	result_type=RXML.t_xml;
      else if(args->quote=="html")
	result_type=RXML.t_text;
      else
	result_type=RXML.t_text;
    }

    array do_return(RequestID id) {

      if(args->source) {
	RXML.Tag plugin=get_plugins()[args->source];
	if(!plugin) RXML.parse_error("Source "+args->source+" not present.\n");
	do_insert(plugin, args->source, id);
	return 0;
      }
      foreach((array)get_plugins(), [string name, RXML.Tag plugin]) {
	if(args[name]) {
	  do_insert(plugin, name, id);
	  return 0;
	}
      }

      parse_error("No correct insert attribute given.\n");
    }
  }
}

class TagInsertVariable {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "variable";

  string get_data(string var, mapping args, RequestID id) {
    if(zero_type(RXML.user_get_var(var, args->scope)))
      RXML.run_error("No such variable ("+var+").\n", id);
    if(args->index) {
      mixed data = RXML.user_get_var(var, args->scope);
      if(intp(data) || floatp(data))
	RXML.run_error("Can not index numbers.\n");
      if(stringp(data)) {
	if(args->split)
	  data = data / args->split;
	else
	  data = ({ data });
      }
      if(arrayp(data)) {
	int index = (int)args->index;
	if(index<0) index=sizeof(data)+index+1;
	if(sizeof(data)<index || index<1)
	  RXML.run_error("Index out of range.\n");
	else
	  return data[index-1];
      }
      if(data[args->index]) return data[args->index];
      RXML.run_error("Could not index variable data\n");
    }
    return (string)RXML.user_get_var(var, args->scope);
  }
}

class TagInsertVariables {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "variables";

  string get_data(string var, mapping args) {
    RXML.Context context=RXML_CONTEXT;
    if(var=="full")
      return map(sort(context->list_var(args->scope)),
		 lambda(string s) {
		   return sprintf("%s=%O", s, context->get_var(s, args->scope) );
		 } ) * "\n";
    return String.implode_nicely(sort(context->list_var(args->scope)));
  }
}

class TagInsertScopes {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "scopes";

  string get_data(string var, mapping args) {
    RXML.Context context=RXML_CONTEXT;
    if(var=="full") {
      string result = "";
      foreach(sort(context->list_scopes()), string scope) {
	result += scope+"\n";
	result += Roxen.html_encode_string(map(sort(context->list_var(args->scope)),
					       lambda(string s) {
						 return sprintf("%s.%s=%O", scope, s,
								context->get_var(s, args->scope) );
					       } ) * "\n");
	result += "\n";
      }
      return result;
    }
    return String.implode_nicely(sort(context->list_scopes()));
  }
}

class TagInsertLocate {
  inherit RXML.Tag;
  constant name= "insert";
  constant plugin_name = "locate";

  RXML.Type get_type( mapping args )
  {
    if (args->quote=="html")
      return RXML.t_text;
    return RXML.t_xml;
  }

  string get_data(string var, mapping args, RequestID id)
  {
    array(string) result;
    
    result = VFS.find_above_read( id->not_query, var, id );

    if( !result )
      RXML.run_error("Cannot locate any file named "+var+".\n");

    return result[1];
  }  
}

class TagInsertFile {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "file";

  RXML.Type get_type(mapping args) {
    if (args->quote=="html")
      return RXML.t_text;
    return RXML.t_xml;
  }

  string get_data(string var, mapping args, RequestID id)
  {
    string result;
    if(args->nocache) // try_get_file never uses the cache any more.
      CACHE(0);      // Should we really enforce CACHE(0) here?
    
    result=id->conf->try_get_file(var, id);

    if( !result )
      RXML.run_error("No such file ("+Roxen.fix_relative( var, id )+").\n");

#if ROXEN_COMPAT <= 1.3
    if(id->conf->old_rxml_compat)
      return Roxen.parse_rxml(result, id);
#endif
    return result;
  }
}

class TagInsertRealfile {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "realfile";

  string get_data(string var, mapping args, RequestID id) {
    string filename=id->conf->real_file(Roxen.fix_relative(var, id), id);
    if(!filename)
      RXML.run_error("Could not find the file %s.\n", Roxen.fix_relative(var, id));
    Stdio.File file=Stdio.File(filename, "r");
    if(file)
      return file->read();
    RXML.run_error("Could not open the file %s.\n", Roxen.fix_relative(var, id));
  }
}

class TagReturn {
  inherit RXML.Tag;
  constant name = "return";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      if(args->code)
	RXML_CONTEXT->set_misc (" _error", (int)args->code);
      if(args->text)
	RXML_CONTEXT->set_misc (" _rettext", replace(args->text, "\n\r"/1, "%0A%0D"/3));
      return 0;
    }
  }
}

class TagSetCookie {
  inherit RXML.Tag;
  constant name = "set-cookie";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  mapping(string:RXML.Type) req_arg_types = ([ "name" : RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      int t;
      if(args->persistent) t=-1; else t=Roxen.time_dequantifier(args);
      Roxen.set_cookie( id,  args->name, (args->value||""), t, 
                        args->domain, args->path );
      return 0;
    }
  }
}

class TagRemoveCookie {
  inherit RXML.Tag;
  constant name = "remove-cookie";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  mapping(string:RXML.Type) req_arg_types = ([ "name" : RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([
    "value" : RXML.t_text(RXML.PEnt),
    "domain" : RXML.t_text(RXML.PEnt),
    "path" : RXML.t_text(RXML.PEnt),
  ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
//    really... is this error a good idea?  I don't think so, it makes
//    it harder to make pages that use cookies. But I'll let it be for now.
//       /Per

      if(!id->cookies[args->name])
        RXML.run_error("That cookie does not exist.\n");
      Roxen.remove_cookie( id, args->name, 
                           (args->value||id->cookies[args->name]||""), 
                           args->domain, args->path );
      return 0;
    }
  }
}

string tag_modified(string tag, mapping m, RequestID id, Stdio.File file)
{

  if(m->by && !m->file && !m->realfile)
    m->file = id->virtfile;
  
  if(m->file)
    m->realfile = id->conf->real_file(Roxen.fix_relative( m_delete(m, "file"), id), id);

  if(m->by && m->realfile)
  {
    if(!sizeof(id->conf->user_databases()))
      RXML.run_error("Modified by requires a user database.\n");

    Stdio.File f;
    if(f = open(m->realfile, "r"))
    {
      m->name = id->conf->last_modified_by(f, id);
      destruct(f);
      CACHE(10);
      return tag_user(tag, m, id);
    }
    return "A. Nonymous.";
  }

  Stat s;
  if(m->realfile)
    s = file_stat(m->realfile);
  else if (_stat)
    s = _stat;
  else
    s =  id->conf->stat_file(id->not_query, id);

  if(s) {
    CACHE(10);
    if(m->ssi)
      return Roxen.strftime(id->misc->ssi_timefmt || "%c", s[3]);
    return Roxen.tagtime(s[3], m, id, language);
  }

  if(m->ssi) return id->misc->ssi_errmsg||"";
  RXML.run_error("Couldn't stat file.\n");
}


string|array(string) tag_user(string tag, mapping m, RequestID id)
{
  if (!m->name)
    return "";
  
  User uid, tmp;
  foreach( id->conf->user_databases(), UserDB udb ){
    if( tmp = udb->find_user( m->name ) )
      uid = tmp;
  }
 
  if(!uid)
    return "";
  
  string dom = id->conf->query("Domain");
  if(sizeof(dom) && (dom[-1]=='.'))
    dom = dom[0..strlen(dom)-2];
  
  if(m->realname && !m->email)
  {
    if(m->link && !m->nolink)
      return ({ 
	sprintf("<a href=%s>%s</a>", 
		Roxen.html_encode_tag_value( "/~"+uid->name() ),
		Roxen.html_encode_string( uid->gecos() ))
      });
    
    return ({ Roxen.html_encode_string( uid->gecos() ) });
  }
  
  if(m->email && !m->realname)
  {
    if(m->link && !m->nolink)
      return ({ 
	sprintf("<a href=%s>%s</a>",
		Roxen.html_encode_tag_value(sprintf("mailto:%s@%s",
					      uid->name(), dom)), 
		Roxen.html_encode_string(sprintf("%s@%s", uid->name(), dom)))
      });
    return ({ Roxen.html_encode_string(uid->name()+ "@" + dom) });
  } 

  if(m->nolink && !m->link)
    return ({ Roxen.html_encode_string(sprintf("%s <%s@%s>",
					 uid->gecos(), uid->name(), dom))
    });

  return 
    ({ sprintf( (m->nohomepage?"":
		 sprintf("<a href=%s>%s</a>",
			 Roxen.html_encode_tag_value( "/~"+uid->name() ),
			 Roxen.html_encode_string( uid->gecos() ))+
		 sprintf(" <a href=%s>%s</a>",
			 Roxen.html_encode_tag_value(sprintf("mailto:%s@%s", 
						       uid->name(), dom)),
			 Roxen.html_encode_string(sprintf("<%s@%s>", 
						    uid->name(), dom)))))
    });
}


class TagSetMaxCache {
  inherit RXML.Tag;
  constant name = "set-max-cache";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      id->misc->cacheable = Roxen.time_dequantifier(args);
    }
  }
}


// ------------------- Containers ----------------
class TagCharset
{
  inherit RXML.Tag;
  constant name="charset";
  RXML.Type content_type = RXML.t_same;

  class Frame
  {
    inherit RXML.Frame;
    array do_return( RequestID id )
    {
      if( args->in && catch {
	content=Locale.Charset.decoder( args->in )->feed( content )->drain();
      })
	RXML.run_error("Illegal charset, or unable to decode data: %s\n",
		       args->in );
      if( args->out && id->set_output_charset)
	id->set_output_charset( args->out );
      result_type = result_type (RXML.PXml);
      result="";
      return ({content});
    }
  }
}

class TagScope {
  inherit RXML.Tag;

  constant name = "scope";
  mapping(string:RXML.Type) opt_arg_types = ([ "extend" : RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;

    string scope_name;
    mapping|object vars;
    mapping oldvar;

    array do_enter(RequestID id) {
      scope_name = args->scope || args->extend || "form";
      // FIXME: Should probably work like this, but it's anything but
      // simple to do that now, since variables is a class that simply
      // fakes the old variable structure using real_variables
// #if ROXEN_COMPAT <= 1.3
//       if(scope_name=="form") oldvar=id->variables;
// #endif
      if(args->extend)
	vars=copy_value(RXML_CONTEXT->get_scope (scope_name));
      else
	vars=([]);
// #if ROXEN_COMPAT <= 1.3
//       if(oldvar) id->variables=vars;
// #endif
      return 0;
    }

    array do_return(RequestID id) {
// #if ROXEN_COMPAT <= 1.3
//       if(oldvar) id->variables=oldvar;
// #endif
      result=content;
      return 0;
    }
  }
}

array(string) container_catch( string tag, mapping m, string c, RequestID id )
{
  string r;
  mixed e = catch(r=Roxen.parse_rxml(c, id));
  if(e && objectp(e) && e->tag_throw) return ({ e->tag_throw });
  if(e) throw(e);
  return ({r});
}

class TagCache {
  inherit RXML.Tag;
  constant name = "cache";
  constant flags = (RXML.FLAG_GET_RAW_CONTENT |
		    RXML.FLAG_GET_EVALED_CONTENT |
		    RXML.FLAG_DONT_CACHE_RESULT |
		    RXML.FLAG_CUSTOM_TRACE);
  constant cache_tag_location = "tag_cache";

  static class TimeOutEntry (
    TimeOutEntry next,
    // timeout_cache is a wrapper array to get a weak ref to the
    // timeout_cache mapping for the frame. This way the mapping will
    // be garbed when the frame disappears, in addition to the
    // timeout.
    array(mapping(string:array(int|RXML.PCode))) timeout_cache)
    {}

  static TimeOutEntry timeout_list;

  static void do_timeouts()
  {
    int now = time (1);
    for (TimeOutEntry t = timeout_list, prev; t; t = t->next) {
      mapping(string:array(int|RXML.PCode)) cachemap = t->timeout_cache[0];
      if (cachemap) {
	foreach (indices (cachemap), string key)
	  if (cachemap[key][0] < now) m_delete (cachemap, key);
	prev = t;
      }
      else
	if (prev) prev->next = t->next;
	else timeout_list = t->next;
    }
    roxen.background_run (roxen.query("mem_cache_gc"), do_timeouts);
  }

  static void add_timeout_cache (mapping(string:array(int|RXML.PCode)) timeout_cache)
  {
    if (!timeout_list)
      roxen.background_run (roxen.query("mem_cache_gc"), do_timeouts);
    else
      for (TimeOutEntry t = timeout_list; t; t = t->next)
	if (t->timeout_cache[0] == timeout_cache) return;
    timeout_list =
      TimeOutEntry (timeout_list,
		    set_weak_flag (({timeout_cache}), 1));
  }

  class Frame {
    inherit RXML.Frame;

    int do_iterate;
    mapping(string|int:mixed) keymap, overridden_keymap;
    string key;
    RXML.PCode evaled_content;
    int timeout, persistent_cache = 0;

    // The following are retained for frame reuse.
    string content_hash;
    array(string|int) subvariables;
    mapping(string:RXML.PCode|array(int|RXML.PCode)) alternatives;

    static void add_subvariables_to_keymap()
    {
      RXML.Context ctx = RXML_CONTEXT;
      foreach (subvariables, string var) {
	array splitted = ctx->parse_user_var (var, 1);
	if (intp (splitted[0])) { // Depend on the whole scope.
	  mapping|RXML.Scope scope = ctx->get_scope (var);
	  if (mappingp (scope))
	    keymap[var] = scope + ([]);
	  else if (var == "form")
	    // Special case to optimize this scope.
	    keymap->form = ctx->id->real_variables + ([]);
	  else {
	    array indices = scope->_indices (ctx, var);
	    keymap[var] = mkmapping (indices, rows (scope, indices));
	  }
	}
	else
	  keymap[var] = ctx->get_var (splitted[1..], splitted[0]);
      }
    }

    static void make_key_from_keymap(RequestID id)
    {
      // Cacheing is not allowed if there are keys except '1' and
      // none of them are page.path.
      array(string|int) keys = indices(keymap) - ({1});
      if (sizeof(keys) && !has_value(keys, "page.path")) {
	if (!args["enable-client-cache"])
	  NOCACHE();
	else if(!args["enable-protocol-cache"])
	  NO_PROTO_CACHE();
      }

      key = encode_value_canonic (keymap);
      if (!args["disable-key-hash"])
	// Initialize with a 32 char string to make sure MD5 goes
	// through all the rounds even if the key is very short.
	// Otherwise the risk for coincidental equal keys gets much
	// bigger.
	key = Crypto.md5()->update ("................................")
			  ->update (key)
			  ->digest();
    }

    array do_enter (RequestID id)
    {
      if( args->nocache || args["not-post-method"] && id->method == "POST" ) {
	do_iterate = 1;
	key = 0;
	TAG_TRACE_ENTER ("no cache due to %s",
			 args->nocache ? "nocache argument" : "POST method");
	id->cache_status->cachetag = 0;
	id->misc->cache_tag_miss = 1;
	return 0;
      }

      RXML.Context ctx = RXML_CONTEXT;
      int default_key = compat_level < 2.2;

      overridden_keymap = 0;
      if (!args->propagate ||
	  (!(keymap = ctx->misc->cache_key) &&
	   (m_delete (args, "propagate"), 1))) {
	overridden_keymap = ctx->misc->cache_key;
	keymap = ctx->misc->cache_key = ([]);
      }

      if (args->variable) {
	if (args->variable != "")
	  foreach (args->variable / ",", string var) {
	    var = String.trim_all_whites (var);
	    array splitted = ctx->parse_user_var (var, 1);
	    if (intp (splitted[0])) { // Depend on the whole scope.
	      mapping|RXML.Scope scope = ctx->get_scope (var);
	      if (mappingp (scope))
		keymap[var] = scope + ([]);
	      else if (var == "form")
		// Special case to optimize this scope.
		keymap->form = id->real_variables + ([]);
	      else if (scope) {
		array indices = scope->_indices (ctx, var);
		keymap[var] = mkmapping (indices, rows (scope, indices));
	      }
	      else
		parse_error ("Unknown scope %O.\n", var);
	    }
	    else
	      keymap[var] = ctx->get_var (splitted[1..], splitted[0]);
	  }
	default_key = 0;
      }

      if (args->profile) {
	if (mapping avail_profiles = id->misc->rxml_cache_cur_profile)
	  foreach (args->profile / ",", string profile) {
	    profile = String.trim_all_whites (profile);
	    mixed profile_val = avail_profiles[profile];
	    if (zero_type (profile_val))
	      parse_error ("Unknown cache profile %O.\n", profile);
	    keymap[" " + profile] = profile_val;
	  }
	else
      	  parse_error ("There are no cache profiles.\n");
	default_key = 0;
      }

      if (args->propagate) {
	if (args->key)
	  parse_error ("Argument \"key\" cannot be used together with \"propagate\".");
	// Updated the key, so we're done. The surrounding cache tag
	// should do the caching.
	do_iterate = 1;
	TAG_TRACE_ENTER ("propagating key, is now %s",
			 RXML.utils.format_short (keymap, 200));
	key = keymap = 0;
	flags &= ~RXML.FLAG_DONT_CACHE_RESULT;
	return 0;
      }

      if(args->key) keymap[0] += ({args->key});

      if (default_key) {
	// Include the form variables and the page path by default.
	keymap->form = id->real_variables + ([]);
	keymap["page.path"] = id->not_query;
      }

      if (subvariables) add_subvariables_to_keymap();

      if (args->shared) {
	if(args->nohash)
	  // Always use the configuration in the key; noone really
	  // wants cache tainting between servers.
	  keymap[1] = id->conf->name;
	else {
	  if (!content_hash) {
	    // Include the content type in the hash since we cache the
	    // p-code which has static type inference.
	    if (!content) content = "";
	    if (String.width (content) != 8) content = encode_value_canonic (content);
	    content_hash = Crypto.md5()->update ("................................")
				       ->update (content)
				       ->update (content_type->name)
				       ->digest();
	  }
	  keymap[1] = ({id->conf->name, content_hash});
	}
      }

      make_key_from_keymap(id);

      timeout = Roxen.time_dequantifier (args);

      // Now we have the cache key.

      object(RXML.PCode)|array(int|RXML.PCode) entry = args->shared ?
	cache_lookup (cache_tag_location, key) :
	alternatives && alternatives[key];

      int removed = 0; // 0: not removed, 1: stale, 2: timeout, 3: pragma no-cache

      if (entry) {
      check_entry_valid: {
	  if (arrayp (entry)) {
	    if (entry[0] < time (1)) {
	      removed = 2;
	      break check_entry_valid;
	    }
	    else evaled_content = entry[1];
	  }
	  else evaled_content = entry;
	  if (evaled_content->is_stale())
	    removed = 1;
	  else if (id->pragma["no-cache"] && args["flush-on-no-cache"])
	    removed = 3;
	}

	if (removed) {
	  if (args->shared)
	    cache_remove (cache_tag_location, key);
	  else
	    if (alternatives) m_delete (alternatives, key);
	}

	else {
	  do_iterate = -1;
	  TAG_TRACE_ENTER ("cache hit%s for key %s",
			   args->shared ?
			   (timeout ? " (shared timeout cache)" : " (shared cache)") :
			   (timeout ? " (timeout cache)" : ""),
			   RXML.utils.format_short (keymap, 200));
	  key = keymap = 0;
	  return ({evaled_content});
	}
      }

      keymap += ([]);
      do_iterate = 1;
      TAG_TRACE_ENTER ("cache miss%s, %s",
		       args->shared ?
		       (timeout ? " (shared timeout cache)" : " (shared cache)") :
		       (timeout ? " (timeout cache)" : ""),
		       removed == 1 ? "entry p-code is stale" :
		       removed == 2 ? "entry had timed out" :
		       removed == 3 ? "a pragma no-cache request removed the entry" :
		       "no entry");
      id->cache_status->cachetag = 0;
      id->misc->cache_tag_miss = 1;
      return 0;
    }

    array do_return (RequestID id)
    {
      if (key) {
	mapping(string|int:mixed) subkeymap = RXML_CONTEXT->misc->cache_key;
	if (sizeof (subkeymap) > sizeof (keymap)) {
	  // The test above assumes that no subtag removes entries in
	  // RXML_CONTEXT->misc->cache_key.
	  subvariables = filter (indices (subkeymap - keymap), stringp);
	  // subvariables is part of the persistent state, but we'll
	  // come to state_update later anyway if it should be called.
	  add_subvariables_to_keymap();
	  make_key_from_keymap(id);
	}

	if (args->shared) {
	  cache_set(cache_tag_location, key, evaled_content, timeout);
	  TAG_TRACE_LEAVE ("added shared%s cache entry with key %s",
			   timeout ? " timeout" : "",
			   RXML.utils.format_short (keymap, 200));
	}
	else
	  if (timeout) {
	    if (!alternatives) add_timeout_cache (alternatives = ([]));
	    alternatives[key] = ({time() + timeout, evaled_content});
	    if (args["persistent-cache"] == "yes") {
	      persistent_cache = 1;
	      RXML_CONTEXT->state_update();
	    }
	    TAG_TRACE_LEAVE ("added%s timeout cache entry with key %s",
			     persistent_cache ? " (possibly persistent)" : "",
			     RXML.utils.format_short (keymap, 200));
	  }
	  else {
	    if (!alternatives) alternatives = ([]);
	    alternatives[key] = evaled_content;
	    if (args["persistent-cache"] != "no") {
	      persistent_cache = 1;
	      RXML_CONTEXT->state_update();
	    }
	    TAG_TRACE_LEAVE ("added%s cache entry with key %s",
			     persistent_cache ? " (possibly persistent)" : "",
			     RXML.utils.format_short (keymap, 200));
	  }
      }
      else
	TAG_TRACE_LEAVE ("");

      if (overridden_keymap) {
	RXML_CONTEXT->misc->cache_key = overridden_keymap;
	overridden_keymap = 0;
      }

      result += content;
      return 0;
    }

    array save()
    {
      return ({content_hash, subvariables, persistent_cache,
	       persistent_cache && alternatives});
    }

    void restore (array saved)
    {
      [content_hash, subvariables, persistent_cache, alternatives] = saved;
    }
  }
}

class TagNocache
{
  inherit RXML.Tag;
  constant name = "nocache";
  constant flags = RXML.FLAG_DONT_CACHE_RESULT;
  class Frame
  {
    inherit RXML.Frame;
  }
}

class TagCrypt {
  inherit RXML.Tag;
  constant name = "crypt";

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(args->compare) {
	_ok=crypt(content,args->compare);
	return 0;
      }
      result=crypt(content);
      return 0;
    }
  }
}

class TagFor {
  inherit RXML.Tag;
  constant name = "for";
  int flags = cache_static_in_2_5();

  class Frame {
    inherit RXML.Frame;

    private int from,to,step,count;

    array do_enter(RequestID id) {
      from = (int)args->from;
      to = (int)args->to;
      step = (int)args->step!=0?(int)args->step:(to<from?-1:1);
      if((to<from && step>0)||(to>from && step<0))
	run_error("Step has the wrong sign.\n");
      from-=step;
      count=from;
      return 0;
    }

    int do_iterate() {
      if(!args->variable) {
	int diff=abs(to-from);
	to=from;
	return diff;
      }
      count+=step;
      RXML.user_set_var(args->variable, count, args->scope);
      if(to<from) return count>=to;
      return count<=to;
    }

    array do_return(RequestID id) {
      if(args->variable) RXML.user_set_var(args->variable, count-step, args->scope);
      result=content;
      return 0;
    }
  }
}

string simpletag_apre(string tag, mapping m, string q, RequestID id)
{
  string href;

  if(m->href) {
    href=m_delete(m, "href");
    array(string) split = href/":";
    if ((sizeof(split) > 1) && (sizeof(split[0]/"/") == 1))
      return RXML.t_xml->format_tag("a", m, q);
    href=Roxen.strip_prestate(Roxen.fix_relative(href, id));
  }
  else
    href=Roxen.strip_prestate(Roxen.strip_config(id->raw_url));

  if(!strlen(href))
    href="";

  multiset prestate = (< @indices(id->prestate) >);

  // FIXME: add and drop should handle t_array
  if(m->add)
    foreach((m_delete(m, "add") - " ")/",", string s)
      prestate[s]=1;

  if(m->drop)
    foreach((m_delete(m,"drop") - " ")/",", string s)
      prestate[s]=0;

  m->href = Roxen.add_pre_state(href, prestate);
  return RXML.t_xml->format_tag("a", m, q);
}

string simpletag_aconf(string tag, mapping m,
		       string q, RequestID id)
{
  string href;

  if(m->href) {
    href=m_delete(m, "href");
    if (search(href, ":") == search(href, "//")-1)
      RXML.parse_error("It is not possible to add configs to absolute URLs.\n");
    href=Roxen.fix_relative(href, id);    
  }
  else
    href=Roxen.strip_prestate(Roxen.strip_config(id->raw_url));

  array cookies = ({});
  // FIXME: add and drop should handle t_array
  if(m->add)
    foreach((m_delete(m,"add") - " ")/",", string s)
      cookies+=({s});

  if(m->drop)
    foreach((m_delete(m,"drop") - " ")/",", string s)
      cookies+=({"-"+s});

  m->href = Roxen.add_config(href, cookies, id->prestate);
  return RXML.t_xml->format_tag("a", m, q);
}

class TagMaketag {
  inherit RXML.Tag;
  constant name = "maketag";
  mapping(string:RXML.Type) req_arg_types = ([ "type" : RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([ "noxml" : RXML.t_text(RXML.PEnt),
					       "name" : RXML.t_text(RXML.PEnt) ]);

  class TagAttrib {
    inherit RXML.Tag;
    constant name = "attrib";
    mapping(string:RXML.Type) req_arg_types = ([ "name" : RXML.t_text(RXML.PEnt) ]);

    class Frame {
      inherit RXML.Frame;

      array do_return(RequestID id) {
	id->misc->makeargs[args->name] = content || "";
	return 0;
      }
    }
  }

  RXML.TagSet internal =
    RXML.shared_tag_set (0, "/rxmltags/maketag", ({ TagAttrib() }) );

  class Frame {
    inherit RXML.Frame;
    mixed old_args;
    RXML.TagSet additional_tags = internal;

    array do_enter(RequestID id) {
      old_args = id->misc->makeargs;
      id->misc->makeargs = ([]);
      return 0;
    }

    array do_return(RequestID id) {
      switch(args->type) {
      case "pi":
	if(!args->name) parse_error("Type 'pi' requires a name attribute.\n");
	result = RXML.t_xml->format_tag(args->name, 0, content, RXML.FLAG_PROC_INSTR);
	break;
      case "container":
	if(!args->name) parse_error("Type 'container' requires a name attribute.\n");
	result = RXML.t_xml->format_tag(args->name, id->misc->makeargs, content, RXML.FLAG_RAW_ARGS);
	break;
      case "tag":
	if(!args->name) parse_error("Type 'tag' requires a name attribute.\n");
	result = RXML.t_xml->format_tag(args->name, id->misc->makeargs, 0,
					(args->noxml?RXML.FLAG_COMPAT_PARSE:0)|
					RXML.FLAG_EMPTY_ELEMENT|RXML.FLAG_RAW_ARGS);
	break;
      case "comment":
	result = "<!--" + content + "-->";
	break;
      case "cdata":
	result = "<![CDATA[" + content/"]]>"*"]]]]><![CDATA[>" + "]]>";
	break;
      }
      id->misc->makeargs = old_args;
      return 0;
    }
  }
}

class TagDoc {
  inherit RXML.Tag;
  constant name="doc";
  RXML.Type content_type = RXML.t_same;

  class Frame {
    inherit RXML.Frame;

    array do_enter(RequestID id) {
      if(args->preparse) content_type = result_type(RXML.PXml);
      return 0;
    }

    array do_return(RequestID id) {
      array from;
      if(args->quote) {
	m_delete(args, "quote");
	from=({ "<", ">", "&" });
      }
      else
	from=({ "{", "}", "&" });

      result=replace(content, from, ({ "&lt;", "&gt;", "&amp;"}) );

      if(args->pre) {
	m_delete(args, "pre");
	result="\n"+RXML.t_xml->format_tag("pre", args, result)+"\n";
      }

      return 0;
    }
  }
}

string simpletag_autoformat(string tag, mapping m, string s, RequestID id)
{
  s-="\r";

  string p=(m["class"]?"<p class=\""+m["class"]+"\">":"<p>");

  if(!m->nonbsp)
  {
    s = replace(s, "\n ", "\n&nbsp;"); // "|\n |"      => "|\n&nbsp;|"
    s = replace(s, "  ", "&nbsp; ");  //  "|   |"      => "|&nbsp;  |"
    s = replace(s, "  ", " &nbsp;"); //   "|&nbsp;  |" => "|&nbsp; &nbsp;|"
  }

  if(!m->nobr) {
    s = replace(s, "\n", "<br />\n");
    if(m->p) {
      if(search(s, "<br />\n<br />\n")!=-1) s=p+s;
      s = replace(s, "<br />\n<br />\n", "\n</p>"+p+"\n");
      if(sizeof(s)>3 && s[0..2]!="<p>" && s[0..2]!="<p ")
        s=p+s;
      if(s[..sizeof(s)-4]==p)
        return s[..sizeof(s)-4];
      else
        return s+"</p>";
    }
    return s;
  }

  if(m->p) {
    if(search(s, "\n\n")!=-1) s=p+s;
      s = replace(s, "\n\n", "\n</p>"+p+"\n");
      if(sizeof(s)>3 && s[0..2]!="<p>" && s[0..2]!="<p ")
        s=p+s;
      if(s[..sizeof(s)-4]==p)
        return s[..sizeof(s)-4];
      else
        return s+"</p>";
    }

  return s;
}

class Smallcapsstr (string bigtag, string smalltag, mapping bigarg, mapping smallarg)
{
  constant UNDEF=0, BIG=1, SMALL=2;
  static string text="",part="";
  static int last=UNDEF;

  string _sprintf() {
    return "Smallcapsstr("+bigtag+","+smalltag+")";
  }

  void add(string char) {
    part+=char;
  }

  void add_big(string char) {
    if(last!=BIG) flush_part();
    part+=char;
    last=BIG;
  }

  void add_small(string char) {
    if(last!=SMALL) flush_part();
    part+=char;
    last=SMALL;
  }

  void write(string txt) {
    if(last!=UNDEF) flush_part();
    part+=txt;
  }

  void flush_part() {
    switch(last){
    case UNDEF:
    default:
      text+=part;
      break;
    case BIG:
      text+=RXML.t_xml->format_tag(bigtag, bigarg, part);
      break;
    case SMALL:
      text+=RXML.t_xml->format_tag(smalltag, smallarg, part);
      break;
    }
    part="";
    last=UNDEF;
  }

  string value() {
    if(last!=UNDEF) flush_part();
    return text;
  }
}

string simpletag_smallcaps(string t, mapping m, string s)
{
  Smallcapsstr ret;
  string spc=m->space?"&nbsp;":"";
  m_delete(m, "space");
  mapping bm=([]), sm=([]);
  if(m["class"] || m->bigclass) {
    bm=(["class":(m->bigclass||m["class"])]);
    m_delete(m, "bigclass");
  }
  if(m["class"] || m->smallclass) {
    sm=(["class":(m->smallclass||m["class"])]);
    m_delete(m, "smallclass");
  }

  if(m->size) {
    bm+=(["size":m->size]);
    if(m->size[0]=='+' && (int)m->size>1)
      sm+=(["size":m->small||"+"+((int)m->size-1)]);
    else
      sm+=(["size":m->small||(string)((int)m->size-1)]);
    m_delete(m, "small");
    ret=Smallcapsstr("font","font", m+bm, m+sm);
  }
  else
    ret=Smallcapsstr("big","small", m+bm, m+sm);

  for(int i=0; i<strlen(s); i++)
    if(s[i]=='<') {
      int j;
      for(j=i; j<strlen(s) && s[j]!='>'; j++);
      ret->write(s[i..j]);
      i+=j-1;
    }
    else if(s[i]<=32)
      ret->add_small(s[i..i]);
    else if(lower_case(s[i..i])==s[i..i])
      ret->add_small(upper_case(s[i..i])+spc);
    else if(upper_case(s[i..i])==s[i..i])
      ret->add_big(s[i..i]+spc);
    else
      ret->add(s[i..i]+spc);

  return ret->value();
}

string simpletag_random(string tag, mapping m, string s, RequestID id)
{
  NOCACHE();
  array q = s/(m->separator || m->sep || "\n");
  int index;
  if(m->seed)
    index = array_sscanf(Crypto.md5()->update(m->seed)->digest(),
			 "%4c")[0]%sizeof(q);
  else
    index = random(sizeof(q));

  return q[index];
}

class TagGauge {
  inherit RXML.Tag;
  constant name = "gauge";

  class Frame {
    inherit RXML.Frame;
    int t;

    array do_enter(RequestID id) {
      NOCACHE();
      t=gethrtime();
    }

    array do_return(RequestID id) {
      t=gethrtime()-t;
      if(args->variable) RXML.user_set_var(args->variable, t/1000000.0, args->scope);
      if(args->silent) return ({ "" });
      if(args->timeonly) return ({ sprintf("%3.6f", t/1000000.0) });
      if(args->resultonly) return ({content});
      return ({ "<br /><font size=\"-1\"><b>Time: "+
		sprintf("%3.6f", t/1000000.0)+
		" seconds</b></font><br />"+content });
    }
  }
}

// Removes empty lines
string simpletag_trimlines( string tag_name, mapping args,
                           string contents, RequestID id )
{
  contents = replace(contents, ({"\r\n","\r" }), ({"\n","\n"}));
  return (contents / "\n" - ({ "" })) * "\n";
}

void container_throw( string t, mapping m, string c, RequestID id)
{
  if(c[-1]!='\n') c+="\n";
  throw( class(string tag_throw) {}( c ) );
}

// Internal methods for the default tag
private int|array internal_tag_input(string t, mapping m, string name, multiset(string) value)
{
  if (name && m->name!=name) return 0;
  if (m->type!="checkbox" && m->type!="radio") return 0;
  if (value[m->value||"on"]) {
    if (m->checked) return 0;
    m->checked = "checked";
  }
  else {
    if (!m->checked) return 0;
    m_delete(m, "checked" );
  }

  int xml=!m_delete(m, "noxml");

  return ({ Roxen.make_tag(t, m, xml) });
}
array split_on_option( string what, Regexp r )
{
  array a = r->split( what );
  if( !a )
     return ({ what });
  return split_on_option( a[0], r ) + a[1..];
}
private int|array internal_tag_select(string t, mapping m, string c, string name, multiset(string) value)
{
  if(name && m->name!=name) return ({ RXML.t_xml->format_tag(t, m, c) });

  // Split indata into an array with the layout
  // ({ "option", option_args, stuff_before_next_option })*n
  // e.g. "fox<OPtioN foo='bar'>gazink</option>" will yield
  // tmp=({ "OPtioN", " foo='bar'", "gazink</option>" }) and
  // ret="fox"
  Regexp r = Regexp( "(.*)<([Oo][Pp][Tt][Ii][Oo][Nn])([^>]*)>(.*)" );
  array(string) tmp=split_on_option(c,r);
  string ret=tmp[0],nvalue;
  int selected,stop;
  tmp=tmp[1..];

  while(sizeof(tmp)>2) {
    stop=search(tmp[2],"<");
    if(sscanf(tmp[1],"%*svalue=%s",nvalue)!=2 &&
       sscanf(tmp[1],"%*sVALUE=%s",nvalue)!=2)
      nvalue=tmp[2][..stop==-1?sizeof(tmp[2]):stop];
    else if(!sscanf(nvalue, "\"%s\"", nvalue) && !sscanf(nvalue, "'%s'", nvalue))
      sscanf(nvalue, "%s%*[ >]", nvalue);
    selected=Regexp(".*[Ss][Ee][Ll][Ee][Cc][Tt][Ee][Dd].*")->match(tmp[1]);
    ret+="<"+tmp[0]+tmp[1];
    if(value[nvalue] && !selected) ret+=" selected=\"selected\"";
    ret+=">"+tmp[2];
    if(!Regexp(".*</[Oo][Pp][Tt][Ii][Oo][Nn]")->match(tmp[2])) ret+="</"+tmp[0]+">";
    tmp=tmp[3..];
  }
  return ({ RXML.t_xml->format_tag(t, m, ret) });
}

string simpletag_default( string t, mapping m, string c, RequestID id)
{
  multiset value=(<>);
  if(m->value) value=mkmultiset((m->value||"")/(m->separator||","));
  if(m->variable) value+=(<RXML.user_get_var(m->variable, m->scope)>);
  if(value==(<>)) return c;

  return parse_html(c, (["input":internal_tag_input]),
		    (["select":internal_tag_select]),
		    m->name, value);
}

string simpletag_sort(string t, mapping m, string c, RequestID id)
{
  if(!m->separator)
    m->separator = "\n";

  string pre="", post="";
  array lines = c/m->separator;

  while(lines[0] == "")
  {
    pre += m->separator;
    lines = lines[1..];
  }

  while(lines[-1] == "")
  {
    post += m->separator;
    lines = lines[..sizeof(lines)-2];
  }

  lines=sort(lines);

  return pre + (m->reverse?reverse(lines):lines)*m->separator + post;
}

string simpletag_replace( string tag, mapping m, string cont, RequestID id)
{
  switch(m->type)
  {
  case "word":
  default:
    if(!m->from) return cont;
   return replace(cont,m->from,(m->to?m->to:""));

  case "words":
    if(!m->from) return cont;
    string s=m->separator?m->separator:",";
    array from=(array)(m->from/s);
    array to=(array)(m->to/s);

    int balance=sizeof(from)-sizeof(to);
    if(balance>0) to+=allocate(balance,"");

    return replace(cont,from,to);
  }
}

class TagCSet {
  inherit RXML.Tag;
  constant name = "cset";
  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      if( !args->variable ) parse_error("Variable not specified.\n");
      if(!content) content="";
      if( args->quote != "none" )
	content = Roxen.html_decode_string( content );

      RXML.user_set_var(args->variable, content, args->scope);
      return ({ "" });
    }
  }
}

class TagColorScope {
  inherit RXML.Tag;
  constant name = "colorscope";

  class Frame {
    inherit RXML.Frame;
    string link, alink, vlink;

#define LOCAL_PUSH(X) if(args->X) { X=RXML_CONTEXT->misc->X; RXML_CONTEXT->misc->X=args->X; }
    array do_enter(RequestID id) {
      Roxen.push_color("colorscope",args,id);
      LOCAL_PUSH(link);
      LOCAL_PUSH(alink);
      LOCAL_PUSH(vlink);
      return 0;
    }

#define LOCAL_POP(X) if(X) RXML_CONTEXT->misc->X=X
    array do_return(RequestID id) {
      Roxen.pop_color("colorscope",id);
      LOCAL_POP(link);
      LOCAL_POP(alink);
      LOCAL_POP(vlink);
      result=content;
      return 0;
    }
  }
}


// ------------------------- RXML Core tags --------------------------

class TagHelp {
  inherit RXML.Tag;
  constant name = "help";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit "rxmlhelp";
    inherit RXML.Frame;

    array do_return(RequestID id) {
      string help_for = args->for || id->variables->_r_t_h;
      string ret="<h2>Roxen Interactive RXML Help</h2>";

      if(!help_for) {
	NOCACHE();
	array tags=map(indices(RXML_CONTEXT->tag_set->get_tag_names()),
		       lambda(string tag) {
			 if (!has_prefix (tag, "_"))
			   if(tag[..3]=="!--#" || !has_value(tag, "#"))
			     return tag;
			 return "";
		       } ) - ({ "" });
	tags += map(indices(RXML_CONTEXT->tag_set->get_proc_instr_names()),
		    lambda(string tag) { return "&lt;?"+tag+"?&gt;"; } );
	tags = Array.sort_array(tags,
				lambda(string a, string b) {
				  if(has_prefix (a, "&lt;?")) a=a[5..];
				  if(has_prefix (b, "&lt;?")) b=b[5..];
				  if(lower_case(a)==lower_case(b)) return a > b;
				  return lower_case (a) > lower_case (b);
				})-({"\x266a"});

	string char;
	ret += "<b>Here is a list of all defined tags. Click on the name to "
	  "receive more detailed information. All these tags are also availabe "
	  "in the \""+RXML_NAMESPACE+"\" namespace.</b><p>\n";
	array tag_links;

	foreach(tags, string tag) {
	  string tag_char =
	    lower_case (has_prefix (tag, "&lt;?") ? tag[5..5] : tag[0..0]);
	  if (tag_char != char) {
	    if(tag_links && char!="/") ret+="<h3>"+upper_case(char)+"</h3>\n<p>"+
					 String.implode_nicely(tag_links)+"</p>";
	    char = tag_char;
	    tag_links=({});
	  }
	  if(tag[0..sizeof(RXML_NAMESPACE)]!=RXML_NAMESPACE+":") {
	    string enc=tag;
	    if(enc[0..4]=="&lt;?") enc=enc[4..sizeof(enc)-6];
	    if(undocumented_tags && undocumented_tags[tag])
	      tag_links += ({ tag });
	    else
	      tag_links += ({ sprintf("<a href=\"%s?_r_t_h=%s\">%s</a>\n",
				      id->url_base() + id->not_query[1..],
				      Roxen.http_encode_url(enc), tag) });

	  }
	}

	ret+="<h3>"+upper_case(char)+"</h3>\n<p>"+String.implode_nicely(tag_links)+"</p>";
	/*
	ret+="<p><b>This is a list of all currently defined RXML scopes and their entities</b></p>";

	RXML.Context context=RXML_CONTEXT;
	foreach(sort(context->list_scopes()), string scope) {
	  ret+=sprintf("<h3><a href=\"%s?_r_t_h=%s\">%s</a></h3>\n",
		       id->not_query, Roxen.http_encode_url("&"+scope+";"), scope);
	  ret+="<p>"+String.implode_nicely(Array.map(sort(context->list_var(scope)),
						       lambda(string ent) { return ent; }) )+"</p>";
	}
	*/
	return ({ ret });
      }

      result=ret+find_tag_doc(help_for, id);
    }
  }
}

class TagNumber {
  inherit RXML.Tag;
  constant name = "number";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      if(args->type=="roman") return ({ Roxen.int2roman((int)args->num) });
      if(args->type=="memory") return ({ Roxen.sizetostring((int)args->num) });
      result=roxen.language(args->lang||args->language||
                            RXML_CONTEXT->misc->theme_language,
			    args->type||"number",id)( (int)args->num );
    }
  }
}


class TagUse {
  inherit RXML.Tag;
  constant name = "use";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  private array(string) list_packages() { 
    return filter(((get_dir("../local/rxml_packages")||({}))
		   |(get_dir("rxml_packages")||({}))),
		  lambda( string s ) {
		    return s!=".cvsignore" &&
		      (Stdio.file_size("../local/rxml_packages/"+s)+
		       Stdio.file_size( "rxml_packages/"+s )) > 0;
		  });
  }

  private string read_package( string p ) {
    string data;
    p = combine_path("/", p);
    if(file_stat( "../local/rxml_packages/"+p ))
      catch(data=Stdio.File( "../local/rxml_packages/"+p, "r" )->read());
    if(!data && file_stat( "rxml_packages/"+p ))
      catch(data=Stdio.File( "rxml_packages/"+p, "r" )->read());
    return data;
  }

  private string use_file_doc(string f, string data) {
    string res, doc;
    int help; // If true, all tags support the 'help' argument.
    sscanf(data, "%*sdoc=\"%s\"", doc);
    sscanf(data, "%*shelp=%d", help);
    res = "<dt><b>"+f+"</b></dt><dd>"+(doc?doc+"<br />":"")+"</dd>";

    array defs = parse_use_package(data, RXML_CONTEXT);
    cache_set("macrofiles", "|"+f, defs, 300);

    array(string) ifs = ({}), tags = ({});

    foreach (indices (defs[0]), string defname)
      if (has_prefix (defname, "if\0"))
	ifs += ({defname[sizeof ("if\0")..]});
      else if (has_prefix (defname, "tag\0"))
	tags += ({defname[sizeof ("tag\0")..]});

    constant types = ({ "if plugin", "tag", "form variable", "\"var\" scope variable" });

    array pack = ({ifs, tags, indices(defs[1]), indices(defs[2])});

    for(int i; i<3; i++)
      if(sizeof(pack[i])) {
	res += "Defines the following " + types[i] + (sizeof(pack[i])!=1?"s":"") +
	  ": " + String.implode_nicely( sort(pack[i]) ) + ".<br />";
      }

    if(help) res+="<br /><br />All tags accept the <i>help</i> attribute.";
    return res;
  }

  private array parse_use_package(string data, RXML.Context ctx) {
    RequestID id = ctx->id;

    RXML.Parser parser = Roxen.get_rxml_parser (ctx->id);
    parser->write_end (data);
    parser->eval();

    return ({
      parser->context->misc - ([" _extra_heads": 1, " _error": 1, " _stat": 1]),
      parser->context->get_scope ("form"),
      parser->context->get_scope ("var")
    });
  }

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(args->packageinfo) {
	NOCACHE();
	string res ="<dl>";
	foreach(list_packages(), string f)
	  res += use_file_doc(f, read_package( f ));
	return ({ res+"</dl>" });
      }

      if(!args->file && !args->package)
	parse_error("No file or package selected.\n");

      array res;
      string name, filename;
      if(args->file)
      {
	filename = Roxen.fix_relative(args->file, id);
	name = id->conf->get_config_id() + "|" + filename;
      }
      else if( args->locate )
      {
	filename = VFS.find_above( id->not_query, args->locate, id, "locate" );
	name = id->conf->get_config_id() + "|" + filename;
      }
      else
      {
	name = "|" + args->package;
      }
      RXML.Context ctx = RXML_CONTEXT;

      if(args->info || id->pragma["no-cache"] ||
	 !(res=cache_lookup("macrofiles",name)) ) {

	string file;
	if(filename)
	  file = id->conf->try_get_file( filename, id );
	else
	  file = read_package( args->package );

	if(!file)
	  run_error("Failed to fetch "+(args->file||args->package)+".\n");

	if( args->info )
	  return ({"<dl>"+use_file_doc( args->file || args->package, file )+"</dl>"});

	res = parse_use_package(file, ctx);
	cache_set("macrofiles", name, res);
      }

      [mapping(string:mixed) newdefs,
       mapping(string:mixed)|RXML.Scope formvars,
       mapping(string:mixed)|RXML.Scope varvars] = res;
      foreach (indices (newdefs), string defname) {
	mixed def = ctx->misc[defname] = newdefs[defname];
	if (has_prefix (defname, "tag\0")) ctx->add_runtime_tag (def[3]);
      }
      ctx->extend_scope ("form", formvars);
      ctx->extend_scope ("var", varvars);

      return 0;
    }
  }
}

class UserTagContents
{
  inherit RXML.Tag;
  constant name = "contents";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  array(RXML.Type) result_types = ({RXML.t_any (RXML.PXml)});

  class IdentityVar (string self)
  {
    mixed rxml_var_eval (RXML.Context ctx, string var, string scope_name,
			 void|RXML.Type type)
    {
      return ENCODE_RXML_XML (self, type);
    }
  }

  // Got two frame types in this tag: First the normal frame which is
  // created when <contents/> is parsed. Second the ExpansionFrame
  // which is made by the normal frame with the actual content the
  // UserTag frame got.

  class Frame
  {
    inherit RXML.Frame;
    constant is_user_tag_contents_tag = 1;

    string scope;

    local RXML.Frame get_upframe()
    {
      RXML.Frame upframe = up;
      int nest = 1;
      for (; upframe; upframe = upframe->up)
	if (upframe->is_contents_nest_tag) {
	  if ((!scope || upframe->scope_name == scope) && !--nest)
	    return upframe;
	}
	else
	  if (upframe->is_user_tag_contents_tag &&
	      (!scope || upframe->scope == scope)) nest++;
      parse_error ("No associated defined tag to get contents from.\n");
    }

    // Note: The ExpansionFrame instances aren't saved and restored
    // here for p-code use, since they can't be shared between
    // evaluations (due to e.g. orig_ctx_scopes).

    array do_return()
    {
      if (args["copy-of"] && args["value-of"])
	parse_error ("Attributes copy-of and value-of are mutually exclusive.\n");

      scope = args->scope;
      RXML.Frame upframe = get_upframe();

      if (compat_level < 2.4 && !args["copy-of"] && !args["value-of"])
	// Must reevaluate the contents each time it's inserted to be
	// compatible in old <contents/> tags without copy-of or
	// value-of arguments.
	args->eval = "";

      // Note that args will be parsed again in the ExpansionFrame.

      if (upframe->is_define_tag) {
	// If upframe is a <define> tag and not the user tag then
	// we're being preparsed. Output an entity on the form
	// &_internal_.4711; so that we can find it again after the
	// preparse.
	if (mapping(string:ExpansionFrame) ctag = upframe->preparsed_contents_tags) {
	  RXML.Context ctx = RXML_CONTEXT;
	  string var = ctx->alloc_internal_var();
	  ctag[var] = ExpansionFrame (
	    0,
	    args["copy-of"] || args["value-of"] ?
	    RXML.t_xml (content_type->parser_prog) : content_type,
	    args);
	  // Install a value for &_internal_.4711; that expands to
	  // itself, in case something evaluates it during preparse.
	  // Don't use the proper ctx->set_var since these assigments
	  // doesn't need to be registered if p-code is created;
	  // they're only used temporarily during the preparse.
	  ctx->scopes->_internal_[var] = IdentityVar ("&_internal_." + var + ";");
	  result_type = result_type (RXML.PNone);
	  return ({"&_internal_." + var + ";"});
	}
	else
	  parse_error ("This tag is currently only supported in "
		       "<define tag='...'> and <define container='...'>.\n");
      }

      else {
	ExpansionFrame exp_frame =
	  ExpansionFrame (upframe,
			  args["copy-of"] || args["value-of"] ?
			  RXML.t_xml (content_type->parser_prog) : content_type,
			  args);
#ifdef DEBUG
	if (flags & RXML.FLAG_DEBUG) exp_frame->flags |= RXML.FLAG_DEBUG;
#endif
	return ({exp_frame});
      }
    }
  }

  static function(:mapping) get_arg_function (mapping args)
  {
    return lambda () {return args;};
  }

  class ExpansionFrame
  {
    inherit RXML.Frame;
    int do_iterate;

    RXML.Frame upframe;

    static void create (void|RXML.Frame upframe_,
			void|RXML.Type type, void|mapping contents_args)
    {
      if (type) {		// Might be created from decode or _clone_empty.
	content_type = type, result_type = type (RXML.PNone);
	args = contents_args;
	if (args["copy-of"] || args["value-of"])
	  // If there's an error it'll typically be completely lost if
	  // we use copy-of or value-of, so propagate it instead.
	  flags |= RXML.FLAG_DONT_RECOVER;
	if ((upframe = upframe_)) {
	  // upframe is zero if we're called during preparse.
	  RXML.PCode compiled_content = upframe->compiled_content;
	  if (compiled_content && !compiled_content->is_stale()) {
	    content = compiled_content;
	    // The internal way to flag a compiled but unevaluated
	    // flag is to set args to a function returning the
	    // argument mapping. It'd be prettier with a flag for
	    // this.
	    args = (mixed) get_arg_function (args);
	  }
	  else {
	    content = upframe->content_text;
	    flags |= RXML.FLAG_UNPARSED;
	  }
	  if (upframe->compile) flags |= RXML.FLAG_COMPILE_INPUT;
	}
      }
    }

    local mixed get_content (RXML.Frame upframe, mixed content)
    {
      if (string expr = args["copy-of"] || args["value-of"]) {
	string insert_type = args["copy-of"] ? "copy-of" : "value-of";

	string value;
	if (sscanf (expr, "%*[ \t\n\r]@%*[ \t\n\r]%s", expr) == 3) {
	  // Special treatment to select attributes at the top level.
	  sscanf (expr, "%[^][ \t\n\r/@(){}:.,]%*[ \t\n\r]%s", expr, string rest);
	  if (!sizeof (expr))
	    parse_error ("Error in %s attribute: No attribute name after @.\n",
			 insert_type);
	  if (sizeof (rest))
	    parse_error ("Error in %s attribute: "
			 "Unexpected subpath %O after attribute %s.\n",
			 insert_type, rest, expr);
	  if (expr == "*") {
	    if (insert_type == "copy-of")
	      value = upframe->vars->args;
	    else
	      foreach (indices (upframe->vars), string var)
		if (!(<"args", "rest-args", "contents">)[var] &&
		    !has_prefix (var, "__contents__")) {
		  value = upframe->vars[var];
		  break;
		}
	  }
	  else if (!(<"args", "rest-args", "contents">)[expr] &&
		   !has_prefix (expr, "__contents__"))
	    if (string val = upframe->vars[expr])
	      if (insert_type == "copy-of")
		value = Roxen.make_tag_attributes (([expr: val]));
	      else
		value = val;
	}

	else {
	  if (!objectp (content) || content->node_type != SloppyDOM.Node.DOCUMENT_NODE)
	    content = upframe->content_result = SloppyDOM.parse ((string) content, 1);

	  mixed res = 0;
	  if (mixed err = catch (
		res = content->simple_path (expr, insert_type == "copy-of")))
	    // We're sloppy and assume that the error is some parse
	    // error regarding the expression.
	    parse_error ("Error in %s attribute: %s", insert_type,
			 describe_error (err));

	  if (insert_type == "copy-of")
	    value = res;
	  else {
	    if (arrayp (res)) res = sizeof (res) && res[0];
	    if (objectp (res))
	      value = res->get_text_content();
	    else if (mappingp (res) && sizeof (res))
	      value = values (res)[0];
	    else
	      value = "";
	  }
	}

#ifdef DEBUG
	if (TAG_DEBUG_TEST (flags & RXML.FLAG_DEBUG))
	  tag_debug ("%O:   Did %s %O in %s: %s\n", this_object(),
		     insert_type, expr,
		     RXML.utils.format_short (
		       objectp (content) ? content->xml_format() : content),
		     RXML.utils.format_short (value));
#endif
	return value;
      }

      else
	if (objectp (content) &&
	    content->node_type == SloppyDOM.Node.DOCUMENT_NODE &&
	    result_type->empty_value == "")
	  // The content has been parsed into a SloppyDOM.Document by
	  // the code above in an earlier <contents/>. Format it again
	  // if the result type is string-like.
	  return content->xml_format();
	else
	  return content;
    }

    mapping(string:mixed) orig_ctx_scopes;
    mapping(RXML.Frame:array) orig_ctx_hidden;

    array do_enter()
    {
      if (!upframe->got_content_result || args->eval) {
	do_iterate = 1;
	// Switch to the set of scopes that were defined at entry of
	// the UserTag frame, to get static variable binding in the
	// content. This is poking in the internals; there ought to be
	// some sort of interface here.
	RXML.Context ctx = RXML_CONTEXT;
	orig_ctx_scopes = ctx->scopes, ctx->scopes = upframe->saved_scopes;
	orig_ctx_hidden = ctx->hidden, ctx->hidden = upframe->saved_hidden;
      }
      else
	// Already have the result of the content evaluation.
	do_iterate = -1;
      return 0;
    }

    array do_return()
    {
      if (do_iterate >= 0) {
	// Switch back the set of scopes. This is poking in the
	// internals; there ought to be some sort of interface here.
	RXML.Context ctx = RXML_CONTEXT;
	ctx->scopes = orig_ctx_scopes, orig_ctx_scopes = 0;
	ctx->hidden = orig_ctx_hidden, orig_ctx_hidden = 0;
	upframe->content_result = content;
	upframe->got_content_result = 1;
      }
      else
	content = upframe->content_result;

      result = get_content (upframe, content);
      return 0;
    }

    // The frame might be used as a variable value if preparsing is in
    // use (see the is_define_tag stuff in Frame.do_return). Note: The
    // frame is not thread local in this case.
    mixed rxml_var_eval (RXML.Context ctx, string var, string scope_name,
			 void|RXML.Type type)
    {
      RXML.Frame upframe = ctx->frame;
#ifdef DEBUG
      if (!upframe || !upframe->is_user_tag)
	error ("Expected current frame to be UserTag, but it's %O.\n", upframe);
#endif

      mixed content;

      // Do the work in _eval, do_enter and do_return. Can't use the
      // do_* functions since the frame isn't thread local here.

      if (!upframe->got_content_result || args->eval) {
	// Switch to the set of scopes that were defined at entry of
	// the UserTag frame, to get static variable binding in the
	// content. This is poking in the internals; there ought to be
	// some sort of interface here.
	RXML.Context ctx = RXML_CONTEXT;
	mapping(string:mixed) orig_ctx_scopes = ctx->scopes;
	ctx->scopes = upframe->saved_scopes;
	mapping(RXML.Frame:array) orig_ctx_hidden = ctx->hidden;
	ctx->hidden = upframe->saved_hidden;

	RXML.PCode compiled_content = upframe->compiled_content;
	if (compiled_content && !compiled_content->is_stale())
	  content = compiled_content->eval (ctx);
	else if (upframe->compile)
	  [content, upframe->compiled_content] =
	    ctx->eval_and_compile (content_type, upframe->content_text);
	else
	  content = content_type->eval (upframe->content_text);

	// Switch back the set of scopes. This is poking in the
	// internals; there ought to be some sort of interface here.
	ctx->scopes = orig_ctx_scopes;
	ctx->hidden = orig_ctx_hidden;
	upframe->content_result = content;
	upframe->got_content_result = 1;
      }
      else
	content = upframe->content_result;

#if constant (_disable_threads)
      // If content is a SloppyDOM object, it's not thread safe when
      // it extends itself lazily, so a lock is necessary. We use the
      // interpreter lock since it's the cheapest one and since
      // get_content doesn't block anyway.
      Thread._Disabled threads_disabled = _disable_threads();
#endif
      mixed result = get_content (upframe, content);
#if constant (_disable_threads)
      threads_disabled = 0;
#endif

      // Note: result_type == content_type (except for the parser).
      return type && type != result_type ?
	type->encode (result, result_type) : result;
    }

    array _encode() {return ({content_type, upframe, args});}
    void _decode (array data) {create (@data);}

    string format_rxml_backtrace_frame (void|RXML.Context ctx)
    {
      if (ctx)
	// Used as an RXML.Value.
	return "<contents" + Roxen.make_tag_attributes (args) + ">";
      else
	// Used as a frame. The real contents frame is just above, so
	// suppress this one.
	return "";
    }
  }
}

// This tag set can't be shared since we look at compat_level in
// UserTagContents.
RXML.TagSet user_tag_contents_tag_set =
  RXML.TagSet (this_module(), "_user_tag", ({UserTagContents()}));

class UserTag {
  inherit RXML.Tag;
  string name, lookup_name;
  int flags = RXML.FLAG_COMPILE_RESULT;
  RXML.Type content_type = RXML.t_xml;
  array(RXML.Type) result_types = ({ RXML.t_any(RXML.PXml) });

  // Note: We can't store the actual user tag definition directly in
  // this object; it won't work correctly in p-code since we don't
  // reparse the source and thus don't create a frame with the current
  // runtime tag definition. By looking up the definition in
  // RXML.Context.misc we can get the current definition even if it
  // changes in loops etc.

  void create(string _name, int moreflags) {
    if (_name) {
      name=_name;
      lookup_name = "tag\0" + name;
      flags |= moreflags;
    }
  }

  mixed _encode()
  {
    return ({ name, flags });
  }

  void _decode(mixed v)
  {
    [name, flags] = v;
    lookup_name = "tag\0" + name;
  }

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags;
    RXML.TagSet local_tags;
    string scope_name;
    mapping vars;
    string raw_tag_text;
    int do_iterate;
#ifdef MODULE_LEVEL_SECURITY
    object check_security_object = this_module();
#endif

    constant is_user_tag = 1;
    constant is_contents_nest_tag = 1;
    string content_text;
    RXML.PCode compiled_content;
    mixed content_result;
    int got_content_result;
    mapping(string:mixed) saved_scopes;
    mapping(RXML.Frame:array) saved_hidden;
    int compile;

    array tagdef;

    array do_enter (RequestID id)
    {
      vars = 0;
      do_iterate = content_text ? -1 : 1;
      if ((tagdef = RXML_CONTEXT->misc[lookup_name]))
	if (tagdef[4]) {
	  local_tags = RXML.empty_tag_set;
	  additional_tags = 0;
	}
	else {
	  additional_tags = user_tag_contents_tag_set;
	  local_tags = 0;
	}
      return 0;
    }

    array do_return(RequestID id) {
      if (!tagdef) return ({propagate_tag()});
      RXML.Context ctx = RXML_CONTEXT;

      [array(string|RXML.PCode) def, mapping defaults,
       string def_scope_name, UserTag ignored,
       mapping(string:UserTagContents.ExpansionFrame) preparsed_contents_tags] = tagdef;
      vars = defaults+args;
      scope_name = def_scope_name || name;

      if (content_text)
	// A previously evaluated tag was restored.
	content = content_text;
      else {
	if(content && args->trimwhites)
	  content = String.trim_all_whites(content);

	if (stringp (def[0])) {
#if ROXEN_COMPAT <= 1.3
	  if(id->conf->old_rxml_compat) {
	    array replace_from, replace_to;
	    if (flags & RXML.FLAG_EMPTY_ELEMENT) {
	      replace_from = map(indices(vars),Roxen.make_entity)+
		({"#args#"});
	      replace_to = values(vars)+
		({ Roxen.make_tag_attributes(vars)[1..] });
	    }
	    else {
	      replace_from = map(indices(vars),Roxen.make_entity)+
		({"#args#", "<contents>"});
	      replace_to = values(vars)+
		({ Roxen.make_tag_attributes(vars)[1..], content });
	    }
	    string c2;
	    c2 = replace(def[0], replace_from, replace_to);
	    if(c2!=def[0]) {
	      vars=([]);
	      return ({c2});
	    }
	  }
#endif
	}

	content_text = content || "";
	compile = ctx->make_p_code;
      }

      vars->args = Roxen.make_tag_attributes(vars)[1..];
      vars["rest-args"] = Roxen.make_tag_attributes(args - defaults)[1..];
      vars->contents = content;
      if (preparsed_contents_tags) vars += preparsed_contents_tags;
      id->misc->last_tag_args = vars;
      got_content_result = 0;

      if (compat_level > 2.1) {
	// Save the scope state so that we can switch back in
	// <contents/>, thereby achieving static variable binding in
	// the content. This is poking in the internals; there ought
	// to be some sort of interface here.
	saved_scopes = ctx->scopes + ([]);
	saved_hidden = ctx->hidden + ([]);
      }
      else {
	saved_scopes = ctx->scopes;
	saved_hidden = ctx->hidden;
      }

      return def;
    }

    array save() {return ({content_text, compiled_content});}
    void restore (array saved) {[content_text, compiled_content] = saved;}
  }
}

// A helper Scope class used when preparsing in TagDefine: Every
// variable in it has its own entity string as value, so that e.g.
// &_.contents; goes through the preparse step.
class IdentityVars
{
  inherit RXML.Scope;
  mixed `[] (string var, void|RXML.Context ctx,
	     void|string scope_name, void|RXML.Type type)
  {
    // Note: The fallback for scope_name here is not necessarily
    // correct, but this is typically only called from the rxml
    // parser, which always sets it.
    return ENCODE_RXML_XML ("&" + (scope_name || "_") + "." + var + ";", type);
  }
};
IdentityVars identity_vars = IdentityVars();

class TagDefine {
  inherit RXML.Tag;
  constant name = "define";
  constant flags = RXML.FLAG_DONT_RECOVER;
  RXML.Type content_type = RXML.t_xml (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags;

    constant is_define_tag = 1;
    constant is_contents_nest_tag = 1;
    array(string|RXML.PCode) def;
    mapping defaults;
    int do_iterate;

    // Used when we preparse.
    RXML.Scope|mapping vars;
    string scope_name;
    mapping(string:UserTagContents.ExpansionFrame) preparsed_contents_tags;

    array do_enter(RequestID id) {
      if (def)
	// A previously evaluated tag was restored.
	do_iterate = -1;
      else {
	preparsed_contents_tags = 0;
	do_iterate = 1;
	if(args->preparse) {
	  m_delete(args, "preparse");
	  if (compat_level >= 2.4) {
	    // Older rxml code might use the _ scope and don't expect
	    // it to be overridden in this situation.
	    if (args->tag || args->container) {
	      vars = identity_vars;
	      preparsed_contents_tags = ([]);
	    }
	    else
	      // Even though there won't be any postparse fill-in of
	      // &_.foo; etc we define a local scope for consistency.
	      // This way we can provide special values in the future,
	      // or perhaps fix postparse fill-in even for variables,
	      // if plugins, etc.
	      vars = ([]);
	    additional_tags = user_tag_contents_tag_set;
	    scope_name = args->scope;
	  }
	}
	else
	  content_type = RXML.t_xml;
      }
      return 0;
    }

    // Callbacks used by the <attrib> parser. These are intentionally
    // defined outside the scope of do_return to avoid getting dynamic
    // frames with cyclic references. This is only necessary for Pike
    // 7.2.

    private string add_default(Parser.HTML p, mapping m, string c,
			       mapping defaults, RequestID id)
    {
      if(m->name) defaults[m->name]=Roxen.parse_rxml(c, id);
      return "";
    };

    private array no_more_attrib (Parser.HTML p, void|string ignored)
    {
      p->add_container ("attrib", 0);
      p->_set_tag_callback (0);
      p->_set_data_callback (0);
      p->add_quote_tag ("?", 0, "?");
      p->add_quote_tag ("![CDATA[", 0, "]]");
      return 0;
    };

    private array data_between_attribs (Parser.HTML p, string d)
    {
      sscanf (d, "%[ \t\n\r]", string ws);
      if (d != ws) no_more_attrib (p);
      return 0;
    }

    private array quote_other_entities (Parser.HTML p, string s, void|string scope_name)
    {
      // We know that s ends with ";", so it must be
      // longer than the following prefixes if they match.
      if (sscanf (s, "&_.%c", int c) && c != '.' ||
	  (scope_name &&
	   sscanf (s, "&" + replace (scope_name, "%", "%%") + ".%c", c) &&
	   c != '.'))
	return 0;
      return ({"&:", s[1..]});
    }

    array do_return(RequestID id) {
      string n;
      RXML.Context ctx = RXML_CONTEXT;

      if(n=args->variable) {
	if(args->trimwhites) content=String.trim_all_whites((string)content);
	RXML.user_set_var(n, content, args->scope);
	return 0;
      }

      if (n=args->tag||args->container) {
#if ROXEN_COMPAT <= 1.3
	n = id->conf->old_rxml_compat?lower_case(n):n;
#endif
	int moreflags=0;
	if(args->tag) {
	  moreflags = RXML.FLAG_EMPTY_ELEMENT;
	  m_delete(args, "tag");
	} else
	  m_delete(args, "container");

	if (!def) {
	  defaults=([]);

#if ROXEN_COMPAT <= 1.3
	  if(id->conf->old_rxml_compat)
	    foreach( indices(args), string arg )
	      if( arg[..7] == "default_" )
	      {
		defaults[arg[8..]] = args[arg];
		old_rxml_warning(id, "define attribute "+arg,"attrib container");
		m_delete( args, arg );
	      }
#endif

	  if(!content) content = "";

	  Parser.HTML p;
	  if( compat_level > 2.1 ) {
	    p = Roxen.get_xml_parser();
	    p->add_container ("attrib", ({add_default, defaults, id}));
	    // Stop parsing for attrib tags when we reach something else
	    // than whitespace and comments.
	    p->_set_tag_callback (no_more_attrib);
	    p->_set_data_callback (data_between_attribs);
	    p->add_quote_tag ("?", no_more_attrib, "?");
	    p->add_quote_tag ("![CDATA[", no_more_attrib, "]]");
	  }
	  else
	    p = Parser.HTML()->add_container("attrib", ({add_default, defaults, id}));

	  if (preparsed_contents_tags) {
	    // Translate the &_internal_.4711; references to
	    // &_.__contents__17;. This is necessary since the numbers
	    // in the _internal_ scope is only unique within the
	    // current parse context. Otoh it isn't safe to use
	    // &_.__contents__17; during preparse since the current
	    // scope varies.
	    int id = 0;
	    foreach (indices (preparsed_contents_tags), string var) {
	      preparsed_contents_tags["__contents__" + ++id] =
		preparsed_contents_tags[var];
	      m_delete (preparsed_contents_tags, var);
	      p->add_entity ("_internal_." + var, "&_.__contents__" + id + ";");
	      m_delete (ctx->scopes->_internal_, var);
	    }

	    // Quote all entities except those handled above and those
	    // in the current scope, to avoid repeated evaluation of
	    // them in the expansion phase in UserTag. We use the rxml
	    // special "&:foo;" quoting syntax.
	    p->_set_entity_callback (quote_other_entities);
	    if (args->scope) p->set_extra (args->scope);
	  }

	  content = p->finish (content)->read();

	  if(args->trimwhites) {
	    content=String.trim_all_whites(content);
	    m_delete (args, "trimwhites");
	  }

#ifdef DEBUG
	  if (defaults->_debug_) {
	    moreflags |= RXML.FLAG_DEBUG;
	    m_delete (defaults, "_debug_");
	  }
#endif

#if ROXEN_COMPAT <= 1.3
	  if(id->conf->old_rxml_compat)
	    content = replace( content, indices(args), values(args) );
#endif
	  def = ({content});
	}

	string lookup_name = "tag\0" + n;
	array oldtagdef;
	UserTag user_tag;
	if ((oldtagdef = ctx->misc[lookup_name]) &&
	    !((user_tag = oldtagdef[3])->flags & RXML.FLAG_EMPTY_ELEMENT) ==
	    !(moreflags & RXML.FLAG_EMPTY_ELEMENT)) // Redefine.
	  ctx->set_misc (lookup_name, ({def, defaults, args->scope, user_tag,
					preparsed_contents_tags}));
	else {
	  user_tag = UserTag (n, moreflags);
	  ctx->set_misc (lookup_name, ({def, defaults, args->scope, user_tag,
					preparsed_contents_tags}));
	  ctx->add_runtime_tag(user_tag);
	}
	return 0;
      }

      if (n=args->if) {
	ctx->set_misc ("if\0" + n, UserIf (n, content));
	return 0;
      }

      if (n=args->name) {
	ctx->set_misc (n, content);
	old_rxml_warning(id, "attempt to define name ","variable");
	return 0;
      }

      parse_error("No tag, variable, if or container specified.\n");
    }

    array save() {return ({def, defaults, preparsed_contents_tags});}
    void restore (array saved) {[def, defaults, preparsed_contents_tags] = saved;}
  }
}

class TagUndefine {
  inherit RXML.Tag;
  int flags = RXML.FLAG_EMPTY_ELEMENT;
  constant name = "undefine";
  class Frame {
    inherit RXML.Frame;
    array do_enter(RequestID id) {
      string n;

      if(n=args->variable) {
	RXML_CONTEXT->user_delete_var(n, args->scope);
	return 0;
      }

      if (n=args->tag||args->container) {
	m_delete (RXML_CONTEXT->misc, "tag\0" + n);
	RXML_CONTEXT->remove_runtime_tag(n);
	return 0;
      }

      if (n=args->if) {
	m_delete(RXML_CONTEXT->misc, "if\0" + n);
	return 0;
      }

      if (n=args->name) {
	m_delete(RXML_CONTEXT->misc, args->name);
	return 0;
      }

      parse_error("No tag, variable, if or container specified.\n");
    }
  }
}

class Tracer (Configuration conf)
{
  // Note: \n is used sparingly in output to make it look nice even
  // inside <pre>.
  string resolv="<ol>";
  int level;

  string _sprintf()
  {
    return "Tracer()";
  }

#if constant (gethrtime)
  mapping et = ([]);
#endif
#if constant (gethrvtime)
  mapping et2 = ([]);
#endif

  local void start_clock()
  {
#if constant (gethrvtime)
    et2[level] = gethrvtime();
#endif
#if constant (gethrtime)
    et[level] = gethrtime();
#endif
  }

  local string stop_clock()
  {
    string res;
#if constant (gethrtime)
    res = sprintf("%.5f", (gethrtime() - et[level])/1000000.0);
#else
    res = "";
#endif
#if constant (gethrvtime)
    res += sprintf(" (CPU = %.2f)", (gethrvtime() - et2[level])/1000000.0);
#endif
    return res;
  }

  void trace_enter_ol(string type, function|object thing)
  {
    level++;

    if (thing) {
      string name = Roxen.get_modfullname (Roxen.get_owning_module (thing));
      if (name)
	name = "module " + name;
      else if (this_program conf = Roxen.get_owning_config (thing))
	name = "configuration " + Roxen.html_encode_string (conf->query_name());
      else
	name = Roxen.html_encode_string (sprintf ("object %O", thing));
      type += " in " + name;
    }

    string efont="", font="";
    if(level>2) {efont="</font>";font="<font size=-1>";}

    resolv += font + "<li><b>�</b> " + type + "<ol>" + efont;
    start_clock();
  }

  void trace_leave_ol(string desc)
  {
    level--;

    string efont="", font="";
    if(level>1) {efont="</font>";font="<font size=-1>";}

    resolv += "</ol>" + font;
    if (sizeof (desc))
      resolv += "<b>�</b> " + Roxen.html_encode_string(desc);
    string time = stop_clock();
    if (sizeof (time)) {
      if (sizeof (desc)) resolv += "<br />";
      resolv += "<i>Time: " + time + "</i>";
    }
    resolv += efont + "</li>\n";
  }

  string res()
  {
    while(level>0) trace_leave_ol("");
    return resolv + "</ol>";
  }
}

class TagTrace {
  inherit RXML.Tag;
  constant name = "trace";

  class Frame {
    inherit RXML.Frame;
    function a,b;
    Tracer t;

    array do_enter(RequestID id) {
      NOCACHE();
      t = Tracer(id->conf);
      a = id->misc->trace_enter;
      b = id->misc->trace_leave;
      id->misc->trace_enter = t->trace_enter_ol;
      id->misc->trace_leave = t->trace_leave_ol;
      t->start_clock();
      return 0;
    }

    array do_return(RequestID id) {
      id->misc->trace_enter = a;
      id->misc->trace_leave = b;
      result = "<h3>Tracing</h3>" + content +
	"<h3>Trace report</h3>" + t->res();
      string time = t->stop_clock();
      if (sizeof (time))
	result += "<h3>Total time: " + time + "</h3>";
      return 0;
    }
  }
}

class TagNoParse {
  inherit RXML.Tag;
  constant name = "noparse";
  RXML.Type content_type = RXML.t_same;
  class Frame {
    inherit RXML.Frame;
  }
}

class TagPINoParse {
  inherit TagNoParse;
  constant flags = RXML.FLAG_PROC_INSTR;
  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      result = content[1..];
      return 0;
    }
  }
}

class TagPICData
{
  inherit RXML.Tag;
  constant name = "cdata";
  constant flags = RXML.FLAG_PROC_INSTR;
  RXML.Type content_type = RXML.t_text;
  class Frame
  {
    inherit RXML.Frame;
    array do_return (RequestID id)
    {
      result_type = RXML.t_text;
      result = content[1..];
      return 0;
    }
  }
}

class TagEval {
  inherit RXML.Tag;
  constant name = "eval";
  array(RXML.Type) result_types = ({ RXML.t_any(RXML.PXml) });

  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      return ({ content });
    }
  }
}

class TagNoOutput {
  inherit RXML.Tag;
  constant name = "nooutput";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;

  class Frame {
    inherit RXML.Frame;
    array do_process() {
      return ({""});
    }
  }
}

class TagStrLen {
  inherit RXML.Tag;
  constant name = "strlen";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;

  class Frame {
    inherit RXML.Frame;
    array do_return() {
      if(!stringp(content)) {
	result="0";
	return 0;
      }
      result = (string)strlen(content);
    }
  }
}

class TagElements
{
  inherit RXML.Tag;
  constant name = "elements";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = (["variable": RXML.t_text (RXML.PEnt)]);
  array(RXML.Type) result_types = ({RXML.t_int}) + ::result_types;

  class Frame
  {
    inherit RXML.Frame;
    array do_enter()
    {
      mixed var;
      if (zero_type (var = RXML.user_get_var (args->variable, args->scope)))
	parse_error ("Variable %O doesn't exist.\n", args->variable);
      if (objectp (var) && var->_sizeof)
	result = var->_sizeof();
      else if (arrayp (var) || mappingp (var))
	result = sizeof (var);
      else
	result = 1;
      if (result_type != RXML.t_int)
	result = result_type->encode (result, RXML.t_int);
      return 0;
    }
  }
}

class TagCase {
  inherit RXML.Tag;
  constant name = "case";

  class Frame {
    inherit RXML.Frame;
    int cap;
    array do_enter() {cap = 0; return 0;}
    array do_process(RequestID id) {
      if(args->case) {
	string op;
	switch(lower_case(args->case)) {
	  case "lower":
	    if (content_type->lower_case)
	      return ({content_type->lower_case (content)});
	    op = "lowercased";
	    break;
	  case "upper":
	    if (content_type->upper_case)
	      return ({content_type->upper_case (content)});
	    op = "uppercased";
	    break;
	  case "capitalize":
	    if (content_type->capitalize) {
	      if(cap) return ({content});
	      if (sizeof (content)) cap=1;
	      return ({content_type->capitalize (content)});
	    }
	    op = "capitalized";
	    break;
	  default:
	    if (compat_level > 2.1)
	      parse_error ("Invalid value %O to the case argument.\n", args->case);
	}
	if (compat_level > 2.1)
	  parse_error ("Content of type %s doesn't handle being %s.\n",
		       content_type->name, op);
      }
      else
	if (compat_level > 2.1)
	  parse_error ("Argument \"case\" is required.\n");

#if ROXEN_COMPAT <= 1.3
      if(args->lower) {
	content = lower_case(content);
	old_rxml_warning(id, "attribute lower","case=lower");
      }
      if(args->upper) {
	content = upper_case(content);
	old_rxml_warning(id, "attribute upper","case=upper");
      }
      if(args->capitalize){
	content = capitalize(content);
	old_rxml_warning(id, "attribute capitalize","case=capitalize");
      }
#endif
      return ({ content });
    }
  }
}

class FrameIf {
  inherit RXML.Frame;
  int do_iterate;

  array do_enter(RequestID id) {
    int and = 1;
    do_iterate = -1;

    if(args->not) {
      m_delete(args, "not");
      do_enter(id);
      do_iterate=do_iterate==1?-1:1;
      return 0;
    }

    if(args->or)  { and = 0; m_delete( args, "or" ); }
    if(args->and) { and = 1; m_delete( args, "and" ); }
    mapping plugins=get_plugins();
    mapping(string:mixed) defs = RXML_CONTEXT->misc;

    int ifval=0;
    foreach(indices (args), string s)
      if (object(RXML.Tag)|object(UserIf) plugin =
	  plugins[s] || defs["if\0" + s]) {
	ifval = plugin->eval( args[s], id, args, and, s );
	if(ifval) {
	  if(!and) {
	    do_iterate = 1;
	    return 0;
	  }
	}
	else
	  if(and)
	    return 0;
      }
    if(ifval) {
      do_iterate = 1;
      return 0;
    }
    return 0;
  }

  array do_return(RequestID id) {
    if(do_iterate==1) {
      _ok = 1;
      result = content;
    }
    else
      _ok = 0;
    return 0;
  }
}

class TagIf {
  inherit RXML.Tag;
  constant name = "if";
  int flags = RXML.FLAG_SOCKET_TAG | cache_static_in_2_5();
  array(RXML.Type) result_types = ({RXML.t_any});
  program Frame = FrameIf;
}

class TagElse {
  inherit RXML.Tag;
  constant name = "else";
  int flags = cache_static_in_2_5();
  array(RXML.Type) result_types = ({RXML.t_any});
  class Frame {
    inherit RXML.Frame;
    int do_iterate;
    array do_enter(RequestID id) {
      do_iterate= _ok ? -1 : 1;
      return 0;
    }
  }
}

class TagThen {
  inherit RXML.Tag;
  constant name = "then";
  int flags = cache_static_in_2_5();
  array(RXML.Type) result_types = ({RXML.t_any});
  class Frame {
    inherit FrameIf;
    array do_enter(RequestID id) {
      do_iterate= _ok ? 1 : -1;
      return 0;
    }
  }
}

class TagElseif {
  inherit RXML.Tag;
  constant name = "elseif";
  int flags = cache_static_in_2_5();
  array(RXML.Type) result_types = ({RXML.t_any});

  class Frame {
    inherit FrameIf;
    int last;

    array do_enter(RequestID id) {
      last=_ok;
      do_iterate = -1;
      if(last) return 0;
      return ::do_enter(id);
    }

    array do_return(RequestID id) {
      if(last) return 0;
      return ::do_return(id);
    }

    mapping(string:RXML.Tag) get_plugins() {
      return RXML_CONTEXT->tag_set->get_plugins ("if");
    }
  }
}

class TagTrue {
  inherit RXML.Tag;
  constant name = "true";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;
    array do_enter(RequestID id) {
      _ok = 1;
    }
  }
}

class TagFalse {
  inherit RXML.Tag;
  constant name = "false";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.
  class Frame {
    inherit RXML.Frame;
    array do_enter(RequestID id) {
      _ok = 0;
    }
  }
}

class TagCond
{
  inherit RXML.Tag;
  constant name = "cond";
  RXML.Type content_type = RXML.t_nil (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_any});

  class TagCase
  {
    inherit RXML.Tag;
    constant name = "case";
    array(RXML.Type) result_types = ({RXML.t_nil});

    class Frame
    {
      inherit FrameIf;

      array do_enter (RequestID id)
      {
	do_iterate = -1;
	if (up->matched) return 0;
	content_type = up->result_type (RXML.PXml);
	return ::do_enter (id);
      }

      array do_return (RequestID id)
      {
	::do_return (id);
	if (up->matched) return 0; // Does this ever happen?
	up->result = result;
	if(_ok) up->matched = 1;
	result = RXML.Void;
	return 0;
      }

      // Must override this since it's used by FrameIf.
      mapping(string:RXML.Tag) get_plugins()
	{return RXML_CONTEXT->tag_set->get_plugins ("if");}
    }
  }

  class TagDefault
  {
    inherit RXML.Tag;
    constant name = "default";
    array(RXML.Type) result_types = ({RXML.t_nil});

    class Frame
    {
      inherit RXML.Frame;
      int do_iterate;

      array do_enter()
      {
	if (up->matched) {
	  do_iterate = -1;
	  return 0;
	}
	do_iterate = 1;
	content_type = up->result_type (RXML.PNone);
	return 0;
      }

      array do_return()
      {
	up->default_data = content;
	return 0;
      }
    }
  }

  RXML.TagSet cond_tags =
    RXML.shared_tag_set (0, "/rxmltags/cond", ({TagCase(), TagDefault()}));

  class Frame
  {
    inherit RXML.Frame;
    RXML.TagSet local_tags = cond_tags;
    string default_data;
    int(0..1) matched;

    array do_enter (RequestID id) {
      matched = 0;
      return 0;
    }

    array do_return (RequestID id)
    {
      if(matched)
	_ok = 1;
      else if (default_data) {
	_ok = 0;
	return ({RXML.parse_frame (result_type (RXML.PXml), default_data)});
      }
      return 0;
    }
  }
}

class TagEmit {
  inherit RXML.Tag;
  constant name = "emit";
  int flags = RXML.FLAG_SOCKET_TAG | cache_static_in_2_5();
  mapping(string:RXML.Type) req_arg_types = ([ "source":RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([ "scope":RXML.t_text(RXML.PEnt),
					       "maxrows":RXML.t_int(RXML.PEnt),
					       "skiprows":RXML.t_int(RXML.PEnt),
					       "rowinfo":RXML.t_text(RXML.PEnt), // t_var
					       "do-once":RXML.t_text(RXML.PEnt), // t_bool
					       "filter":RXML.t_text(RXML.PEnt),  // t_list
					       "sort":RXML.t_text(RXML.PEnt),    // t_list
					       "remainderinfo":RXML.t_text(RXML.PEnt), // t_var
  ]);
  array(string) emit_args = indices( req_arg_types+opt_arg_types );
  RXML.Type def_arg_type = RXML.t_text(RXML.PNone);
  array(RXML.Type) result_types = ({RXML.t_any});

  int(0..1) should_filter(mapping vs, mapping filter) {
    RXML.Context ctx = RXML_CONTEXT;
    foreach(indices(filter), string v) {
      string|object val = vs[v];
      if(objectp(val))
	val = val->rxml_const_eval ? val->rxml_const_eval(ctx, v, "", RXML.t_text) :
	  val->rxml_var_eval(ctx, v, "", RXML.t_text);
      if(!val)
	return 1;
      if(!glob(filter[v], val))
	return 1;
    }
    return 0;
  }

  class TagDelimiter {
    inherit RXML.Tag;
    constant name = "delimiter";

    static int(0..1) more_rows(array|object res, mapping filter) {
      if(objectp(res)) {
	while(res->peek() && should_filter(res->peek(), filter))
	  res->skip_row();
	return !!res->peek();
      }
      if(!sizeof(res)) return 0;
      foreach(res[RXML.get_var("real-counter")..], mapping v) {
	if(!should_filter(v, filter))
	  return 1;
      }
      return 0;
    }

    class Frame {
      inherit RXML.Frame;

      array do_return(RequestID id) {
	object|array res = id->misc->emit_rows;
	if(!id->misc->emit_filter) {
	  if( objectp(res) ? res->peek() :
	      RXML.get_var("counter") < sizeof(res) )
	    result = content;
	  return 0;
	}
	if(id->misc->emit_args->maxrows &&
	   id->misc->emit_args->maxrows == RXML.get_var("counter"))
	  return 0;
	if(more_rows(res, id->misc->emit_filter))
	  result = content;
	return 0;
      }
    }
  }

  RXML.TagSet internal =
    RXML.shared_tag_set (0, "/rxmltags/emit", ({ TagDelimiter() }) );

  // A slightly modified Array.dwim_sort_func
  // used as emits sort function.
  static int dwim_compare(mixed a0, mixed b0, string v) {
    RXML.Context ctx;

    if(objectp(a0) && a0->rxml_var_eval) {
      if(!ctx) ctx = RXML_CONTEXT;
      a0 = a0->rxml_const_eval ? a0->rxml_const_eval(ctx, v, "", RXML.t_text) :
	a0->rxml_var_eval(ctx, v, "", RXML.t_text);
    }
    else
      a0 = (string)a0;

    if(objectp(b0) && b0->rxml_var_eval) {
      if(!ctx) ctx = RXML_CONTEXT;
      b0 = b0->rxml_const_eval ? b0->rxml_const_eval(ctx, v, "", RXML.t_text) :
	b0->rxml_var_eval(ctx, v, "", RXML.t_text);
    }
    else
      b0 = (string)b0;

    return dwim_compare_iter(a0, b0);
  }

  static int dwim_compare_iter(string a0,string b0) {
    if (!a0) {
      if (b0)
	return -1;
      return 0;
    }

    if (!b0)
      return 1;

    string a2="",b2="";
    int a1,b1;
    sscanf(a0,"%s%d%s",a0,a1,a2);
    sscanf(b0,"%s%d%s",b0,b1,b2);
    if (a0>b0) return 1;
    if (a0<b0) return -1;
    if (a1>b1) return 1;
    if (a1<b1) return -1;
    if (a2==b2) return 0;
    return dwim_compare_iter(a2,b2);
  }

  static int strict_compare (mixed a0, mixed b0, string v)
  // This one does a more strict compare than dwim_compare. It only
  // tries to convert values from strings to floats or ints if they
  // are formatted exactly as floats or ints. That since there still
  // are places where floats and ints are represented as strings (e.g.
  // in sql query results). Then it compares the values with `<.
  //
  // This more closely resembles how 2.1 and earlier compared values.
  {
    RXML.Context ctx;

    if(objectp(a0) && a0->rxml_var_eval) {
      if(!ctx) ctx = RXML_CONTEXT;
      a0 = a0->rxml_const_eval ? a0->rxml_const_eval(ctx, v, "", RXML.t_text) :
	a0->rxml_var_eval(ctx, v, "", RXML.t_text);
    }

    if(objectp(b0) && b0->rxml_var_eval) {
      if(!ctx) ctx = RXML_CONTEXT;
      b0 = b0->rxml_const_eval ? b0->rxml_const_eval(ctx, v, "", RXML.t_text) :
	b0->rxml_var_eval(ctx, v, "", RXML.t_text);
    }

    if (stringp (a0)) {
      if (sscanf (a0, "%d%*[ \t]%*c", int i) == 2) a0 = i;
      else if (sscanf (a0, "%f%*[ \t]%*c", float f) == 2) a0 = f;
    }
    if (stringp (b0)) {
      if (sscanf (b0, "%d%*[ \t]%*c", int i) == 2) b0 = i;
      else if (sscanf (b0, "%f%*[ \t]%*c", float f) == 2) b0 = f;
    }

    int res;
    if (mixed err = catch (res = b0 < a0)) {
      // Assume we got a "cannot compare different types" error.
      // Compare the types instead.
      a0 = sprintf ("%t", a0);
      b0 = sprintf ("%t", b0);
      res = b0 < a0;
    }
    if (res)
      return 1;
    else if (a0 < b0)
      return -1;
    else
      return 0;
  }

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = internal;
    string scope_name;
    mapping vars;

    // These variables are used to store id->misc-variables
    // that otherwise would be overwritten when emits are
    // nested.
    array(mapping(string:mixed))|object outer_rows;
    mapping outer_filter;
    mapping outer_args;

    object plugin;
    array(mapping(string:mixed))|object res;
    mapping filter;

    array expand(object res) {
      array ret = ({});
      do {
	ret += ({ res->get_row() });
      } while(ret[-1]!=0);
      return ret[..sizeof(ret)-2];
    }

    array do_enter(RequestID id) {
      if(!(plugin=get_plugins()[args->source]))
	parse_error("The emit source %O doesn't exist.\n", args->source);
      scope_name=args->scope||args->source;
      vars = (["counter":0]);

#if 0
#ifdef DEBUG
      tag_debug ("Got emit plugin %O for source %O\n", plugin, args->source);
#endif
#endif
      TRACE_ENTER("Fetch emit dataset for source "+args->source, 0);
      PROF_ENTER( args->source, "emit" );
      plugin->eval_args( args, 0, 0, emit_args );
      res = plugin->get_dataset(args, id);
      PROF_LEAVE( args->source, "emit" );
      TRACE_LEAVE("");
#if 0
#ifdef DEBUG
      if (objectp (res))
	tag_debug ("Emit plugin %O returned data set object %O\n",
		   plugin, res);
      else if (arrayp (res))
	tag_debug ("Emit plugin %O returned data set with %d items\n",
		   plugin, sizeof (res));
#endif
#endif

      if(args->skiprows && plugin->skiprows)
	m_delete(args, "skiprows");

      if(args->maxrows && plugin->maxrows)
	  m_delete(args, "maxrows");

      // Parse the filter argument
      if(args->filter) {
	array pairs = args->filter / ",";
	filter = ([]);
	foreach( pairs, string pair) {
	  string v,g;
	  if( sscanf(pair, "%s=%s", v,g) != 2)
	    continue;
	  v = String.trim_whites(v);
	  if(g != "*"*sizeof(g))
	    filter[v] = g;
	}
	if(!sizeof(filter)) filter = 0;
      }

      outer_args = id->misc->emit_args;
      outer_rows = id->misc->emit_rows;
      outer_filter = id->misc->emit_filter;
      id->misc->emit_args = args;
      id->misc->emit_filter = filter;

      if(objectp(res))
	if(args->sort ||
	   (args->skiprows && args->skiprows<0) ||
	   args->rowinfo )
	  // Expand the object into an array of mappings if sort,
	  // negative skiprows or rowinfo is used. These arguments
	  // should be intercepted, dealt with and removed by the
	  // plugin, should it have a more clever solution. Note that
	  // it would be possible to use a expand_on_demand-solution
	  // where a value object is stored as the rowinfo value and,
	  // if used inside the loop, triggers an expansion. That
	  // would however force us to jump to another iterator function.
	  // Let's save that complexity enhancement until later.
	  res = expand(res);
	else if(filter) {
	  do_iterate = object_filter_iterate;
	  id->misc->emit_rows = res;
	  return 0;
	}
	else {
	  do_iterate = object_iterate;
	  id->misc->emit_rows = res;

	  if(args->skiprows) {
	    int loop = args->skiprows;
	    while(loop--)
	      res->skip_row();
	  }

	  return 0;
	}

      if(arrayp(res)) {
	if(args->sort && !plugin->sort)
	{
	  array(string) raw_fields = (args->sort - " ")/"," - ({ "" });

	  class FieldData {
	    string name;
	    int order;
	    function compare;
	  };

	  array(FieldData) fields = allocate (sizeof (raw_fields));

	  for (int idx = 0; idx < sizeof (raw_fields); idx++) {
	    string raw_field = raw_fields[idx];
	    FieldData field = fields[idx] = FieldData();
	    int i;

	  field_flag_scan:
	    for (i = 0; i < sizeof (raw_field); i++)
	      switch (raw_field[i]) {
		case '-':
		  if (field->order) break field_flag_scan;
		  field->order = '-';
		  break;
		case '+':
		  if (field->order) break field_flag_scan;
		  field->order = '+';
		  break;
		case '*':
		  if (compat_level > 2.2) {
		    if (field->compare) break field_flag_scan;
		    field->compare = strict_compare;
		    break;
		  }
		  // Fall through.
		default:
		  break field_flag_scan;
	      }
	    field->name = raw_field[i..];

	    if (!field->compare) {
	      if (compat_level > 2.1)
		field->compare = dwim_compare;
	      else
		field->compare = strict_compare;
	    }
	  }

	  res = Array.sort_array(
	    res,
	    lambda (mapping(string:mixed) m1,
		    mapping(string:mixed) m2,
		    array(FieldData) fields)
	    {
	      foreach (fields, FieldData field)
	      {
		int tmp;
		switch (field->order) {
		  case '-':
		    tmp = field->compare (m2[field->name], m1[field->name],
					  field->name);
		    break;
		  default:
		  case '+':
		    tmp = field->compare (m1[field->name], m2[field->name],
					  field->name);
		}

		if (tmp == 1)
		  return 1;
		else if (tmp == -1)
		  return 0;
	      }
	      return 0;
	    },
	    fields);
	}

	if(filter) {

	  // If rowinfo or negative skiprows are used we have
	  // to do filtering in a loop of its own, instead of
	  // doing it during the emit loop.
	  if(args->rowinfo || (args->skiprows && args->skiprows<0)) {
	    for(int i; i<sizeof(res); i++)
	      if(should_filter(res[i], filter)) {
		res = res[..i-1] + res[i+1..];
		i--;
	      }
	    filter = 0;
	  }
	  else {

	    // If skiprows is to be used we must only count
	    // the rows that wouldn't be filtered in the
	    // emit loop.
	    if(args->skiprows) {
	      int skiprows = args->skiprows;
	      if(skiprows > sizeof(res))
		res = ({});
	      else {
		int i;
		for(; i<sizeof(res) && skiprows; i++)
		  if(!should_filter(res[i], filter))
		    skiprows--;
		res = res[i..];
	      }
	    }

	    vars["real-counter"] = 0;
	    do_iterate = array_filter_iterate;
	  }
	}

	// We have to check the filter again, since it
	// could have been zeroed in the last if statement.
	if(!filter) {

	  if(args->skiprows) {
	    if(args->skiprows<0) args->skiprows = sizeof(res) + args->skiprows;
	    res=res[args->skiprows..];
	  }

 	  if(args->remainderinfo)
	    RXML.user_set_var(args->remainderinfo, args->maxrows?
			      max(sizeof(res)-args->maxrows, 0): 0);

	  if(args->maxrows) res=res[..args->maxrows-1];
	  if(args->rowinfo)
	    RXML.user_set_var(m_delete(args, "rowinfo"), sizeof(res));
	  if(args["do-once"] && sizeof(res)==0) res=({ ([]) });

	  do_iterate = array_iterate;
	}

	id->misc->emit_rows = res;

	return 0;
      }

      parse_error("Wrong return type from emit source plugin.\n");
    }

    int(0..1) do_once_more() {
      if(vars->counter || !args["do-once"]) return 0;
      vars = (["counter":1]);
      return 1;
    }

    function do_iterate;

    int(0..1) object_iterate(RequestID id) {
      int counter = vars->counter;

      if(args->maxrows && counter == args->maxrows)
	return do_once_more();

      if(mappingp(vars=res->get_row())) {
	vars->counter = ++counter;
	return 1;
      }

      vars = (["counter":counter]);
      return do_once_more();
    }

    int(0..1) object_filter_iterate(RequestID id) {
      int counter = vars->counter;

      if(args->maxrows && counter == args->maxrows)
	return do_once_more();

      if(args->skiprows && args->skiprows>0)
	while(args->skiprows-->-1)
	  while((vars=res->get_row()) &&
		should_filter(vars, filter));
      else
	while((vars=res->get_row()) &&
	      should_filter(vars, filter));

      if(mappingp(vars)) {
	vars->counter = ++counter;
	return 1;
      }

      vars = (["counter":counter]);
      return do_once_more();
    }

    int(0..1) array_iterate(RequestID id) {
      int counter=vars->counter;
      if(counter>=sizeof(res)) return 0;
      vars=res[counter++];
      vars->counter=counter;
      return 1;
    }

    int(0..1) array_filter_iterate(RequestID id) {
      int real_counter = vars["real-counter"];
      int counter = vars->counter;

      if(real_counter>=sizeof(res)) return do_once_more();

      if(args->maxrows && counter == args->maxrows)
	return do_once_more();

      while(should_filter(res[real_counter++], filter))
	if(real_counter>=sizeof(res)) return do_once_more();

      vars=res[real_counter-1];

      vars["real-counter"] = real_counter;
      vars->counter = counter+1;
      return 1;
    }

    array do_return(RequestID id) {
      result = content;

      id->misc->emit_rows = outer_rows;
      id->misc->emit_filter = outer_filter;
      id->misc->emit_args = outer_args;

      int rounds = vars->counter - !!args["do-once"];
      _ok = !!rounds;

      if(args->remainderinfo) {
	if(args->filter) {
	  int rem;
	  if(arrayp(res)) {
	    foreach(res[vars["real-counter"]+1..], mapping v)
	      if(!should_filter(v, filter))
		rem++;
	  } else {
	    mapping v;
	    while( v=res->get_row() )
	      if(!should_filter(v, filter))
		rem++;
	  }
	  RXML.user_set_var(args->remainderinfo, rem);
	}
	else if( do_iterate == object_iterate )
	  RXML.user_set_var(args->remainderinfo, res->num_rows_left());
      }

      res = 0;
      return 0;
    }

  }
}

class TagComment {
  inherit RXML.Tag;
  constant name = "comment";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;
  RXML.Type content_type = RXML.t_any (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.
  class Frame {
    inherit RXML.Frame;
    int do_iterate;
    array do_enter() {
      if (args && args->preparse)
	do_iterate = 1;
      else {
	do_iterate = -1;
	// Argument existence can be assumed static, so we can set
	// FLAG_MAY_CACHE_RESULT here.
	flags |= RXML.FLAG_MAY_CACHE_RESULT;
      }
      return 0;
    }
    array do_return = ({});
  }
}

class TagPIComment {
  inherit TagComment;
  constant flags = RXML.FLAG_PROC_INSTR|RXML.FLAG_MAY_CACHE_RESULT;
  RXML.Type content_type = RXML.t_any (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.
}


// ---------------------- If plugins -------------------

class UserIf
{
  constant name = "if";
  string plugin_name;
  string|RXML.RenewablePCode rxml_code;

  void create(string pname, string code) {
    plugin_name = pname;
    rxml_code = code;
  }

  int eval(string ind, RequestID id) {
    int otruth, res;
    string tmp;

    TRACE_ENTER("user defined if argument "+plugin_name, UserIf);
    otruth = _ok;
    _ok = -2;
    if (objectp (rxml_code))
      tmp = rxml_code->eval (RXML_CONTEXT);
    else
      [tmp, rxml_code] =
	RXML_CONTEXT->eval_and_compile (RXML.t_html (RXML.PXml), rxml_code, 1);
    res = _ok;
    _ok = otruth;

    TRACE_LEAVE("");

    if(ind==plugin_name && res!=-2)
      return res;

    return (ind==tmp);
  }

  // These objects end up in RXML_CONTEXT->misc and might therefore be
  // cached persistently.
  constant is_RXML_encodable = 1;
  array _encode() {return ({plugin_name, rxml_code});}
  void _decode (array data) {[plugin_name, rxml_code] = data;}
}

class IfIs
{
  inherit RXML.Tag;
  constant name = "if";

  constant cache = 0;
  constant case_sensitive = 0;
  string|array source (RequestID id, string s);

  int(0..1) eval( string value, RequestID id, mapping args )
  {
    if (args["expr-cache"]) {
      CACHE((int) args["expr-cache"]);
    } else {
      if(cache != -1)
	CACHE(cache);
    }
    array arr=value/" ";
    string|array var=source(id, arr[0]);
    if(!arrayp(var)) return do_check(var, arr, id);

    int(0..1) recurse_check(array var, array arr, RequestID id) {
      foreach(var, mixed val) {
	if(arrayp(val)) {
	  if(recurse_check(val, arr, id)) return 1;
	  continue;
	}
	if(do_check(RXML.t_text->encode(val), arr, id))
	  return 1;
      }
      return 0;
    };

    return recurse_check(var, arr, id);
  }

  int(0..1) do_check( string var, array arr, RequestID id) {
    if(sizeof(arr)<2) return !!var;

    if(!var)
      if (compat_level == 2.2)
	// This makes unset variables be compared as if they had the
	// empty string as value. I can't understand the logic behind
	// it, but it makes the test <if variable="form.foo is "> be
	// true if form.foo is unset, a state very different from
	// having the empty string as a value. To be on the safe side
	// we're still bug compatible in 2.2 compatibility mode (but
	// both earlier and later releases does the correct thing
	// here). /mast
	var = "";
      else
	// If var is zero then it had no value. Thus it's always
	// different from any value it might be compared with.
	return arr[1] == "!=";

    string is;

    // FIXME: This code should be adapted to compare arbitrary values.

    if(case_sensitive) {
      is=arr[2..]*" ";
    }
    else {
      var = lower_case( var );
      is=lower_case(arr[2..]*" ");
    }

    if(arr[1]=="==" || arr[1]=="=" || arr[1]=="is")
      return ((is==var)||glob(is,var)||
            sizeof(filter( is/",", glob, var )));
    if(arr[1]=="!=") return is!=var;

    string trash;
    if(sscanf(var,"%f%s",float f_var,trash)==2 && trash=="" &&
       sscanf(is ,"%f%s",float f_is ,trash)==2 && trash=="") {
      if(arr[1]=="<") return f_var<f_is;
      if(arr[1]==">") return f_var>f_is;
    }
    else {
      if(arr[1]=="<") return (var<is);
      if(arr[1]==">") return (var>is);
    }

    return !!source(id, arr*" ");
  }
}

class IfMatch
{
  inherit RXML.Tag;
  constant name = "if";

  constant cache = 0;
  function source;

  int eval( string is, RequestID id, mapping args ) {
    array|string value=source(id);
    if (args["expr-cache"]) {
      CACHE((int) args["expr-cache"]);
    } else {
      if(cache != -1)
	CACHE(cache);
    }
    if(!value) return 0;
    if(arrayp(value)) value=value*" ";
    value = lower_case( value );
    is = lower_case( "*"+is+"*" );
    return glob(is,value) || sizeof(filter( is/",", glob, value ));
  }
}

class TagIfDebug {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "debug";

  int eval( string dbg, RequestID id, mapping m ) {
#ifdef DEBUG
    return 1;
#else
    return 0;
#endif
  }
}

class TagIfModuleDebug {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "module-debug";

  int eval( string dbg, RequestID id, mapping m ) {
#ifdef MODULE_DEBUG
    return 1;
#else
    return 0;
#endif
  }
}

class TagIfDate {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "date";

  int eval(string date, RequestID id, mapping m) {
    CACHE(60); // One minute accuracy is probably good enough...
    int a, b;
    mapping t = ([]);

    date = replace(date, "-", "");
    if(sizeof(date)!=8 && sizeof(date)!=6)
      RXML.run_error("If date attribute doesn't conform to YYYYMMDD syntax.");
    if(sscanf(date, "%04d%02d%02d", t->year, t->mon, t->mday)==3)
      t->year-=1900;
    else if(sscanf(date, "%02d%02d%02d", t->year, t->mon, t->mday)!=3)
      RXML.run_error("If date attribute doesn't conform to YYYYMMDD syntax.");

    if(t->year>70) {
      t->mon--;
      a = mktime(t);
    }

    t = localtime(time(1));
    b = mktime(t - (["hour": 1, "min": 1, "sec": 1, "isdst": 1, "timezone": 1]));

    // Catch funny guys
    if(m->before && m->after) {
      if(!m->inclusive)
	return 0;
      m_delete(m, "before");
      m_delete(m, "after");
    }

    if( (m->inclusive || !(m->before || m->after)) && a==b)
      return 1;

    if(m->before && a>b)
      return 1;

    if(m->after && a<b)
      return 1;

    return 0;
  }
}

class TagIfTime {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "time";

  int eval(string ti, RequestID id, mapping m) {
    CACHE(time(1)%60); // minute resolution...

    int|object a, b, d;
    
    if(sizeof(ti) <= 5 /* Format is hhmm or hh:mm. */)
    {
	    mapping c = localtime(time(1));
	    
	    b=(int)sprintf("%02d%02d", c->hour, c->min);
	    a=(int)replace(ti,":","");

	    if(m->until)
		    d = (int)m->until;
		    
    }
    else /* Format is ISO8601 yyyy-mm-dd or yyyy-mm-ddThh:mm etc. */
    {
	    if(has_value(ti, "T"))
	    {
		    /* The Calendar module can for some reason not
		     * handle the ISO8601 standard "T" extension. */
		    a = Calendar.ISO.dwim_time(replace(ti, "T", " "))->minute();
		    b = Calendar.ISO.Minute();
	    }
	    else
	    {
		    a = Calendar.ISO.dwim_day(ti);
		    b = Calendar.ISO.Day();
	    }

	    if(m->until)
		    if(has_value(m->until, "T"))
			    /* The Calendar module can for some reason not
			     * handle the ISO8601 standard "T" extension. */
			    d = Calendar.ISO.dwim_time(replace(m->until, "T", " "))->minute();
		    else
			    d = Calendar.ISO.dwim_day(m->until);
    }
    
    if(d)
    {
      if (d > a && (b > a && b < d) )
	return 1;
      if (d < a && (b > a || b < d) )
	return 1;
      if (m->inclusive && ( b==a || b==d ) )
	return 1;
      return 0;
    }
    else if( (m->inclusive || !(m->before || m->after)) && a==b )
      return 1;
    if(m->before && a>b)
      return 1;
    else if(m->after && a<b)
      return 1;
  }
}

class TagIfUser {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "user";

  int eval(string u, RequestID id, mapping m)
  {
    object db;
    if( m->database )
      db = id->conf->find_user_database( m->database );
    User uid = id->conf->authenticate( id, db );

    if( !uid && !id->auth )
      return 0;

    NOCACHE();

    if( u == "any" )
      if( m->file )
	// Note: This uses the compatibility interface. Should probably
	// be fixed.
	return match_user( id->auth, id->auth[1], m->file, !!m->wwwfile, id);
      else
	return !!u;
    else
      if(m->file)
	// Note: This uses the compatibility interface. Should probably
	// be fixed.
	return match_user(id->auth,u,m->file,!!m->wwwfile,id);
      else
	return has_value(u/",", uid->name());
  }

  private int match_user(array u, string user, string f, int wwwfile, RequestID id) {
    string s, pass;
    if(u[1]!=user)
      return 0;
    if(!wwwfile)
      s=Stdio.read_bytes(f);
    else
      s=id->conf->try_get_file(Roxen.fix_relative(f,id), id);
    return ((pass=simple_parse_users_file(s, u[1])) &&
	    (u[0] || match_passwd(u[2], pass)));
  }

  private int match_passwd(string try, string org) {
    if(!strlen(org)) return 1;
    if(crypt(try, org)) return 1;
  }

  private string simple_parse_users_file(string file, string u) {
    if(!file) return 0;
    foreach(file/"\n", string line)
      {
	array(string) arr = line/":";
	if (arr[0] == u && sizeof(arr) > 1)
	  return(arr[1]);
      }
  }
}

class TagIfGroup {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "group";

  int eval(string u, RequestID id, mapping m) {
    object db;
    if( m->database )
      db = id->conf->find_user_database( m->database );
    User uid = id->conf->authenticate( id, db );

    if( !uid && !id->auth )
      return 0;

    NOCACHE();
    if( m->groupfile )
      return ((m->groupfile && sizeof(m->groupfile))
	      && group_member(id->auth, u, m->groupfile, id));
    return sizeof( uid->groups() & (u/"," )) > 0;
  }

  private int group_member(array auth, string group, string groupfile, RequestID id) {
    if(!auth)
      return 0; // No auth sent

    string s;
    catch { s = Stdio.read_bytes(groupfile); };

    if (!s)
      s = id->conf->try_get_file( Roxen.fix_relative( groupfile, id), id );

    if (!s) return 0;

    s = replace(s,({" ","\t","\r" }), ({"","","" }));

    multiset(string) members = simple_parse_group_file(s, group);
    return members[auth[1]];
  }

  private multiset simple_parse_group_file(string file, string g) {
    multiset res = (<>);
    array(string) arr ;
    foreach(file/"\n", string line)
      if(sizeof(arr = line/":")>1 && (arr[0] == g))
	res += (< @arr[-1]/"," >);
    return res;
  }
}

class TagIfExists {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "exists";

  int eval(string u, RequestID id) {
    CACHE(5);
    return id->conf->is_file(Roxen.fix_relative(u, id), id);
  }
}

class TagIfInternalExists {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "internal-exists";

  int eval(string u, RequestID id) {
    CACHE(5);
    return id->conf->is_file(Roxen.fix_relative(u, id), id, 1);
  }
}

class TagIfNserious {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "nserious";

  int eval() {
#ifdef NSERIOUS
    return 1;
#else
    return 0;
#endif
  }
}

class TagIfModule {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "module";

  int eval(string u, RequestID id) {
    if (!sizeof(u)) return 0;
    return sizeof(glob(u+"#*", indices(id->conf->enabled_modules)));
  }
}

class TagIfTrue {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "true";

  int eval(string u, RequestID id) {
    return _ok;
  }
}

class TagIfFalse {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "false";

  int eval(string u, RequestID id) {
    return !_ok;
  }
}

class TagIfAccept {
  inherit IfMatch;
  constant plugin_name = "accept";
  array source(RequestID id) {
    if( !id->request_headers->accept ) // .. there might be no header
      return ({});
    if( arrayp(id->request_headers->accept) ) // .. there might be multiple
      id->request_headers->accept = id->request_headers->accept*",";
    // .. or there might be one.
    array data = id->request_headers->accept/",";
    array res = ({});
    foreach( data, string d )
    {
      sscanf( d, "%s;", d ); // Ignores the quality parameters etc.
      res += ({d});
    }
    return res;
  }
}

class TagIfConfig {
  inherit IfIs;
  constant plugin_name = "config";
  string source(RequestID id, string s) {
    if(id->config[s]) return "";
    return 0;
  }
}

class TagIfCookie {
  inherit IfIs;
  constant plugin_name = "cookie";
  string source(RequestID id, string s) {
    return id->cookies[s];
  }
}

class TagIfClient {
  inherit IfMatch;
  constant plugin_name = "client";
  array source(RequestID id) {
    return id->client;
  }
}

#if ROXEN_COMPAT <= 1.3
class TagIfName {
  inherit TagIfClient;
  constant plugin_name = "name";
}
#endif

class TagIfDefined {
  inherit IfIs;
  constant plugin_name = "defined";
  string source(RequestID id, string s) {
    mixed val;
    if(zero_type(val=RXML_CONTEXT->misc[s])) return 0;
    if(stringp(val) || intp(val) || floatp(val)) return (string)val;
    return "";
  }
}

class TagIfDomain {
  inherit IfMatch;
  constant plugin_name = "domain";
  string source(RequestID id) {
    return id->host;
  }
}

class TagIfIP {
  inherit IfMatch;
  constant plugin_name = "ip";
  string source(RequestID id) {
    return id->remoteaddr;
  }
}

#if ROXEN_COMPAT <= 1.3
class TagIfHost {
  inherit TagIfIP;
  constant plugin_name = "host";
}
#endif

class TagIfLanguage {
  inherit IfMatch;
  constant plugin_name = "language";
  array source(RequestID id) {
    return id->misc->pref_languages->get_languages();
  }
}

class TagIfMatch {
  inherit IfIs;
  constant plugin_name = "match";
  string source(RequestID id, string s) {
    return s;
  }
}

class TagIfMaTcH {
  inherit TagIfMatch;
  constant plugin_name = "Match";
  constant case_sensitive = 1;
}

class TagIfPragma {
  inherit IfIs;
  constant plugin_name = "pragma";
  string source(RequestID id, string s) {
    if(id->pragma[s]) return "";
    return 0;
  }
}

class TagIfPrestate {
  inherit IfIs;
  constant plugin_name = "prestate";
  constant cache = -1;
  string source(RequestID id, string s) {
    if(id->prestate[s]) return "";
    return 0;
  }
}

class TagIfReferrer {
  inherit IfMatch;
  constant plugin_name = "referrer";
  array source(RequestID id) {
    return id->referer;
  }
}

class TagIfSupports {
  inherit IfIs;
  constant plugin_name = "supports";
  string source(RequestID id, string s) {
    if(id->supports[s]) return "";
    return 0;
  }
}

class TagIfVariable {
  inherit IfIs;
  constant plugin_name = "variable";
  constant cache = 1;
  string source(RequestID id, string s) {
    mixed var;
    if (compat_level == 2.2) {
      // The check below makes it impossible to tell the value 0 from
      // an unset variable. It's clearly a bug, but we still keep it
      // in 2.2 compatibility mode since fixing it would introduce an
      // incompatibility in (at least) this case:
      //
      //    <set variable="var.foo" expr="0"/>
      //    <if variable="var.foo"> <!-- This is expected to be false. -->
      if (!(var=RXML.user_get_var(s))) return 0;
    }
    else
      if (zero_type (var=RXML.user_get_var(s))) return 0;
    if(arrayp(var)) return var;
    return RXML.t_text->encode (var);
  }
}

class TagIfVaRiAbLe {
  inherit TagIfVariable;
  constant plugin_name = "Variable";
  constant case_sensitive = 1;
}

class TagIfSizeof {
  inherit IfIs;
  constant plugin_name = "sizeof";
  constant cache = -1;
  string source(RequestID id, string s) {
    mixed var;
    if (compat_level == 2.2) {
      // See note in TagIfVariable.source.
      if (!(var=RXML.user_get_var(s))) return 0;
    }
    else
      if (zero_type (var=RXML.user_get_var(s))) return 0;
    if(stringp(var) || arrayp(var) ||
       multisetp(var) || mappingp(var)) return (string)sizeof(var);
    if(objectp(var) && var->_sizeof) return (string)sizeof(var);
    return (string)sizeof((string)var);
  }
  int(0..1) do_check(string var, array arr, RequestID id) {
    if(sizeof(arr)>2 && !var) var = "0";
    return ::do_check(var, arr, id);
  }
}

class TagIfClientvar {
  inherit IfIs;
  constant plugin_name = "clientvar";
  string source(RequestID id, string s) {
    return id->client_var[s];
  }
}

class TagIfExpr {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "expr";
  int eval(string u) {
    return (int)sexpr_eval(u);
  }
}


class TagIfTestLicense {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "test-license";
  int eval(string u, RequestID id, mapping args)
  {
    License.Key key = id->conf->getvar("license")->get_key();
    if(!key)
      RXML.run_error("No license key defined for this configuration.");
    
    //  Expects a string on the form "module#feature"
    if(sscanf(u, "%s#%s", string module, string feature) == 2) {
      return !!key->get_module_feature(module, feature);
    }
    RXML.parse_error("Wrong syntax!");
  }
}


// --------------------- Emit plugins -------------------

class TagEmitSources {
  inherit RXML.Tag;
  constant name="emit";
  constant plugin_name="sources";

  array(mapping(string:string)) get_dataset(mapping m, RequestID id) {
    return Array.map( indices(RXML_CONTEXT->tag_set->get_plugins("emit")),
		      lambda(string source) { return (["source":source]); } );
  }
}

class TagPathplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "path";

  array get_dataset(mapping m, RequestID id)
  {
    string fp = "";
    array res = ({});
    string p = m->path || id->not_query;
    if( m->trim )
      sscanf( p, "%s"+m->trim, p );
    if( has_suffix(p, "/") )
      p = p[..strlen(p)-2];
    array q = p / "/";
    if( m->skip )
      q = q[(int)m->skip..];
    if( m["skip-end"] )
      q = q[..sizeof(q)-((int)m["skip-end"]+1)];
    foreach( q, string elem )
    {
      fp += "/" + elem;
      fp = replace( fp, "//", "/" );
      res += ({
        ([
          "name":elem,
          "path":fp
        ])
      });
    }
    return res;
  }
}

class TagEmitValues {
  inherit RXML.Tag;
  constant name="emit";
  constant plugin_name="values";

  array(mapping(string:string)) get_dataset(mapping m, RequestID id) {
    if(m["from-scope"]) {
      m->values=([]);
      RXML.Context context=RXML_CONTEXT;
      map(context->list_var(m["from-scope"]),
	  lambda(string var){ m->values[var]=context->get_var(var, m["from-scope"]);
	  return ""; });
    }

    if( m->variable )
      m->values = RXML_CONTEXT->user_get_var( m->variable );

    if(!m->values)
      return ({});

    if(stringp(m->values)) {
      if(m->advanced) {
	switch(m->advanced) {
	case "chars":
	  m->split="";
	  break;
	case "lines":
	  m->values = replace(m->values, ({ "\n\r", "\r\n", "\r" }),
			      ({ "\n", "\n", "\n" }));
	  m->split = "\n";
	  break;
	case "words":
	  m->values = replace(m->values, ({ "\n\r", "\r\n", "\r" }),
			      ({ "\n", "\n", "\n" }));
	  m->values = replace(m->values, ({ "-\n", "\n", "\t" }),
			      ({ "", " ", " " }));
	  m->values = map(m->values/" " - ({""}),
			  lambda(string word) {
			    if(word[-1]=='.' || word[-1]==',' || word[-1]==';' ||
			       word[-1]==':' || word[-1]=='!' || word[-1]=='?')
			      return word[..sizeof(word)-2];
			    return word;
			  });
	  break;
	}
      }
      if(stringp(m->values))
	m->values=m->values / (m->split || "\000");
    }

    if(mappingp(m->values))
      return map( indices(m->values),
		  lambda(mixed ind) {
		    mixed val = m->values[ind];
		    if(m->trimwhites) val=String.trim_all_whites((string)val);
		    if(m->case=="upper") val=upper_case(val);
		    else if(m->case=="lower") val=lower_case(val);
		    return (["index":ind,"value":val]);
		  });

    if(arrayp(m->values))
      return map( m->values,
		  lambda(mixed val) {
		    if(m->trimwhites) val=String.trim_all_whites((string)val);
		    if(m->case=="upper") val=upper_case(val);
		    else if(m->case=="lower") val=lower_case(val);
		    return (["value":val]);
		  } );

    RXML.run_error("Values variable has wrong type %t.\n", m->values);
  }
}

class TagEmitFonts
{
  inherit RXML.Tag;
  constant name = "emit", plugin_name = "fonts";
  array get_dataset(mapping args, RequestID id)
  {
    return roxen->fonts->get_font_information(args->ttf_only);
  }
}


class TagEmitLicenseWarnings {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "license-warnings";
  array get_dataset(mapping args, RequestID id)
  {
    // This emit plugin can be used to list warnings in the loaded
    // license for a configuration. It can also be used within
    // <license> or emit#licenses.
    License.Key key = (( RXML.get_context()->current_scope() &&
			 RXML.get_context()->get_var("key") )||
		       id->conf->getvar("license")->get_key());
    if(!key) {
      RXML.parse_error("No license key defined in the configuration\n");
      return ({});
    }
    return key->get_warnings();
  }
}

// ---------------- API registration stuff ---------------

string api_query_modified(RequestID id, string f, int|void by)
{
  mapping m = ([ "by":by, "file":f ]);
  return tag_modified("modified", m, id, id);
}


// --------------------- Documentation -----------------------

mapping tagdocumentation() {
  Stdio.File file=Stdio.File();
  if(!file->open(__FILE__,"r")) return 0;
  mapping doc=compile_string("#define manual\n"+file->read())->tagdoc;
  file->close();
  if(!file->open("etc/supports","r")) return doc;

  Parser.HTML()->
    add_container("flags", format_support)->
    add_container("vars", format_support)->
    set_extra(doc)->
    finish(file->read())->read();

  return doc;
}

static int format_support(Parser.HTML p, mapping m, string c, mapping doc) {
  string key = ([ "flags":"if#supports",
		  "vars":"if#clientvar" ])[p->tag_name()];
  c=Roxen.html_encode_string(c)-"#! ";
  c=(Array.map(c/"\n", lambda(string row) {
			 if(sscanf(row, "%*s - %*s")!=2) return "";
			 return "<li>"+row+"</li>";
		       }) - ({""})) * "\n";
  doc[key]+="<ul>\n"+c+"</ul>\n";
  return 0;
}


//  FIXME: Move this to intrawise.pike if possible
class TagIWCache {
  inherit TagCache;
  constant name = "__iwcache";

  //  Place all cache data in a specific cache which we can clear when
  //  the layout files are updated.
  constant cache_tag_location = "iwcache";
  
  class Frame {
    inherit TagCache::Frame;
    
    array do_enter(RequestID id) {
      //  Compute a cache key which depends on the state of the user's
      //  Platform cookie. Get user ID from id->misc->sbobj which in
      //  turn gets initialized in find_file(). This ID will be 0 for
      //  all users (even when authenticated in IW) as long as they
      //  haven't logged in into Platform.
      //  Enable protocol caching since our key is shared and thus
      //  in essence only dependent on &page.path;. Aside from that the
      //  user ID is part of the key, but all authenticated users will
      //  fall through the protocol cache anyway.
      object sbobj = id->misc->sbobj;
      int userid = sbobj && sbobj->get_userid();
      args = ([ "shared" : "yes-please",
		"key"    : ("userid:" + userid +
			    "|tmpl:" + (id->misc->iw_template_set || "")),
		"enable-client-cache"   : "yes-please",
		"enable-protocol-cache" : "yes-please",
      ]);
      if(id->supports->robot||id->variables->__print)
	args += ([ "nocache" : "yes" ]);
      
      return ::do_enter(id);
    }
  }
}



#ifdef manual
constant tagdoc=([
"&roxen;":#"<desc type='scope'><p><short>
 This scope contains information specific to this Roxen
 WebServer.</short> It is not possible to write any information to
 this scope.
</p></desc>",

"&roxen.domain;":#"<desc type='entity'><p>
 The domain name of this site. The information is taken from the
 client request, so a request to \"http://community.roxen.com/\" would
 give this entity the value \"community.roxen.com\", while a request
 for \"http://community/\" would give the entity value \"community\".
</p></desc>",

"&roxen.hits;":#"<desc type='entity'><p>
 The number of hits, i.e. requests the webserver has accumulated since
 it was last started.
</p></desc>",

"&roxen.hits-per-minute;":#"<desc type='entity'><p>
 The average number of requests per minute since the webserver last
 started.
</p></desc>",

"&roxen.pike-version;":#"<desc type='entity'><p>
 The version of Pike the webserver is using, e.g. \"Pike v7.2 release 140\".
</p></desc>",

"&roxen.sent;":#"<desc type='entity'><p>
 The total amount of data the webserver has sent since it last started.
</p></desc>",

"&roxen.sent-kbit-per-second;":#"<desc type='entity'><p>
 The average amount of data the webserver has sent, in Kibibits.
</p></desc>",

"&roxen.sent-mb;":#"<desc type='entity'><p>
 The total amount of data the webserver has sent, in Mebibits.
</p></desc>",

"&roxen.sent-per-minute;":#"<desc type='entity'><p>
 The average number of bytes that the webserver sends during a
 minute. Based on the sent amount of data and uptime since last server start.
</p></desc>",

"&roxen.server;":#"<desc type='entity'><p>
 The URL of the webserver. The information is taken from the client request,
 so a request to \"http://community.roxen.com/index.html\" would give this
 entity the value \"http://community.roxen.com/\", while a request for
 \"http://community/index.html\" would give the entity the value
 \"http://community/\".
</p></desc>",

"&roxen.ssl-strength;":#"<desc type='entity'><p>
 Contains the maximum number of bits encryption strength that the SSL is capable of.
 Note that this is the server side capability, not the client capability.
 Possible values are 0, 40, 128 or 168.
</p></desc>",

"&roxen.time;":#"<desc type='entity'><p>
 The current posix time. An example output: \"244742740\".
</p></desc>",

"&roxen.unique-id;":#"<desc type='entity'><p>
 Returns a unique id that can be used for e.g. session
 identification. An example output: \"7fcda35e1f9c3f7092db331780db9392\".
 Note that a new id will be generated every time this entity is used,
 so you need to store the value in another variable if you are going
 to use it more than once.
</p></desc>",

"&roxen.uptime;":#"<desc type='entity'><p>
 The total uptime of the webserver since last start, in seconds.
</p></desc>",

"&roxen.uptime-days;":#"<desc type='entity'><p>
 The total uptime of the webserver since last start, in days.
</p></desc>",

"&roxen.uptime-hours;":#"<desc type='entity'><p>
 The total uptime of the webserver since last start, in hours.
</p></desc>",

"&roxen.uptime-minutes;":#"<desc type='entity'><p>
 The total uptime of the webserver since last start, in minutes.
</p></desc>",

//----------------------------------------------------------------------

"&client;":#"<desc type='scope'><p><short>
 This scope contains information specific to the client/browser that
 is accessing the page. All support variables defined in the support
 file is added to this scope.</short>
</p></desc>",

"&client.ip;":#"<desc type='entity'><p>
 The client is located on this IP-address. An example output: \"194.52.182.15\".
</p></desc>",

"&client.host;":#"<desc type='entity'><p>
 The host name of the client, if possible to resolve.
 An example output: \"www.roxen.com\".
</p></desc>",

"&client.name;":#"<desc type='entity'><p>
 The name of the client, i.e. the sent user agent string up until the
 first space character. An example output: \"Mozilla/4.7\".
</p></desc>",

"&client.Fullname;":#"<desc type='entity'><p>
 The full user agent string, i.e. name of the client and additional
 info like; operating system, type of computer, etc. An example output:
 \"Mozilla/4.7 [en] (X11; I; SunOS 5.7 i86pc)\".
</p></desc>",

"&client.fullname;":#"<desc type='entity'><p>
 The full user agent string, i.e. name of the client and additional
 info like; operating system, type of computer, etc. Unlike <ent>client.fullname</ent>
 this value is lowercased. An example output:
 \"mozilla/4.7 [en] (x11; i; sunos 5.7 i86pc)\".
</p></desc>",

"&client.referrer;":#"<desc type='entity'><p>
 Prints the URL of the page on which the user followed a link that
 brought her to this page. The information comes from the referrer
 header sent by the browser. An example output: \"http://www.roxen.com/index.xml\".
</p></desc>",

"&client.accept-language;":#"<desc type='entity'><p>
 The client prefers to have the page contents presented in this
 language, according to the accept-language header. An example output: \"en\".
</p></desc>",

"&client.accept-languages;":#"<desc type='entity'><p>
 The client prefers to have the page contents presented in these
 languages, according to the accept-language header. An example output: \"en, sv\".
</p></desc>",

"&client.language;":#"<desc type='entity'><p>
 The clients most preferred language. Usually the same value as
 <ent>client.accept-language</ent>, but is possibly altered by
 a customization module like the Preferred language analyzer.
 It is recommended that this entity is used over the <ent>client.accept-language</ent>
 when selecting languages. An example output: \"en\".
</p></desc>",

"&client.languages;":#"<desc type='entity'><p>
 An ordered list of the clients most preferred languages. Usually the
 same value as <ent>client.accept-language</ent>, but is possibly altered
 by a customization module like the Preferred language analyzer, or
 reorganized according to quality identifiers according to the HTTP
 specification. An example output: \"en, sv\".
</p></desc>",

"&client.authenticated;":#"<desc type='entity'><p>
 Returns the name of the user logged on to the site, i.e. the login
 name, if any exists.
</p></desc>",

"&client.user;":#"<desc type='entity'><p>
 Returns the name the user used when he/she tried to log on the site,
 i.e. the login name, if any exists.
</p></desc>",

"&client.password;":#"<desc type='entity'><p>
 Returns the password the user used when he/she tried to log on the site.
</p></desc>",

"&client.height;":#"<desc type='entity'><p>
 The presentation area height in pixels. For WAP-phones.
</p></desc>",

"&client.width;":#"<desc type='entity'><p>
 The presentation area width in pixels. For WAP-phones.
</p></desc>",

"&client.robot;":#"<desc type='entity'><p>

 Returns the name of the webrobot. Useful if the robot requesting
 pages is to be served other contents than most visitors. Use
 <ent>client.robot</ent> together with <xref href='../if/if.tag'
 />.</p>

 <p>Possible webrobots are: ms-url-control, architex, backrub,
 checkbot, fast, freecrawl, passagen, gcreep, getright, googlebot,
 harvest, alexa, infoseek, intraseek, lycos, webinfo, roxen,
 altavista, scout, slurp, url-minder, webcrawler, wget, xenu and
 yahoo.</p>
</desc>",

"&client.javascript;":#"<desc type='entity'><p>
 Returns the highest version of javascript supported.
</p></desc>",

"&client.tm;":#"<desc type='entity'><p><short>
 Generates a trademark sign in a way that the client can
 render.</short> Possible outcomes are \"&amp;trade;\",
 \"&lt;sup&gt;TM&lt;/sup&gt;\", and \"&amp;gt;TM&amp;lt;\".</p>
</desc>",

//----------------------------------------------------------------------

"&page;":#"<desc type='scope'><p><short>
 This scope contains information specific to this page.</short></p>
</desc>",

"&page.realfile;":#"<desc type='entity'><p>
 Path to this file in the file system. An example output:
 \"/home/joe/html/index.html\".
</p></desc>",

"&page.virtroot;":#"<desc type='entity'><p>
 The root of the present virtual filesystem, usually \"/\".
</p></desc>",

"&page.mountpoint;":#"<desc type='entity'><p>
 The root of the present virtual filesystem without the ending slash,
 usually \"\".
</p></desc>",

//  &page.virtfile; is same as &page.path; but deprecated since we want to
//  harmonize with SiteBuilder entities.
"&page.path;":#"<desc type='entity'><p>
 Absolute path to this file in the virtual filesystem. E.g. with the
 URL \"http://www.roxen.com/partners/../products/index.xml\", as well
 as \"http://www.roxen.com/products/index.xml\", the value will be
 \"/products/index.xml\", given that the virtual filsystem was mounted
 on \"/\".
</p></desc>",

"&page.pathinfo;":#"<desc type='entity'><p>
 The \"path info\" part of the URL, if any. Can only get set if the
 \"Path info support\" module is installed. For details see the
 documentation for that module.
</p></desc>",

"&page.query;":#"<desc type='entity'><p>
 The query part of the page URL. If the page URL is
 \"http://www.server.com/index.html?a=1&amp;b=2\"
 the value of this entity is \"a=1&amp;b=2\".
</p></desc>",

"&page.url;":#"<desc type='entity'><p>
 The absolute path for this file from the web server's root
 view including query variables.
</p></desc>",

"&page.last-true;":#"<desc type='entity'><p>
 Is \"1\" if the last <tag>if</tag>-statement succeeded, otherwise 0.
 (<xref href='../if/true.tag' /> and <xref href='../if/false.tag' />
 is considered as <tag>if</tag>-statements here) See also: <xref
 href='../if/' />.</p>
</desc>",

"&page.language;":#"<desc type='entity'><p>
 What language the contents of this file is written in. The language
 must be given as metadata to be found.
</p></desc>",

"&page.scope;":#"<desc type='entity'><p>
 The name of the current scope, i.e. the scope accessible through the
 name \"_\".
</p></desc>",

"&page.filesize;":#"<desc type='entity'><p>
 This file's size, in bytes.
</p></desc>",

"&page.ssl-strength;":#"<desc type='entity'><p>
 The number of bits used in the key of the current SSL connection.
</p></desc>",

"&page.self;":#"<desc type='entity'><p>
 The name of this file, derived from the URL. If the URL is
 \"http://community.roxen.com/articles/index.html\", then the
 value of this entity is \"index.html\".
</p></desc>",

"&page.dir;":#"<desc type='entity'><p>
 The name of the directory in the virtual filesystem where the file resides,
 as derived from the URL. If the URL is
 \"http://community.roxen.com/articles/index.html\", then the
 value of this entity is \"/articles/\".
</p></desc>",

//----------------------------------------------------------------------

"&form;":#"<desc type='scope'><p><short hide='hide'>
 This scope contains form variables.</short> This scope contains the
 form variables, i.e. the answers to HTML forms sent by the client.
 Both variables resulting from POST operations and GET operations gets
 into this scope. There are no predefined entities for this scope.
</p></desc>",

//----------------------------------------------------------------------

"&cookie;":#"<desc type='scope'><p><short>
 This scope contains the cookies sent by the client.</short> Adding,
 deleting or changing in this scope updates the clients cookies. There
 are no predefined entities for this scope. When adding cookies to
 this scope they are automatically set to expire after two years.
</p></desc>",

//----------------------------------------------------------------------

"&var;":#"<desc type='scope'><p><short>
 General variable scope.</short> This scope is always empty when the
 page parsing begins and is therefore suitable to use as storage for
 all variables used during parsing.
</p></desc>",

//----------------------------------------------------------------------

"roxen-automatic-charset-variable":#"<desc type='tag'><p>
 If put inside a form, the right character encoding of the submitted
 form can be guessed by Roxen WebServer. The tag will insert another
 tag that forces the client to submit the string \"���&#x829f;\". Since the
 WebServer knows the name and the content of the form variable it can
 select the proper character decoder for the requests variables.
</p>

<ex-box><form>
  <roxen-automatic-charset-variable/>
  Name: <input name='name'/><br />
  Mail: <input name='mail'/><br />
  <input type='submit'/>
</form></ex-box>
</desc>",

//----------------------------------------------------------------------

"colorscope":#"<desc type='cont'><p><short>
 Makes it possible to change the autodetected colors within the tag.</short>
 Useful when out-of-order parsing occurs, e.g.</p>

<ex-box><define tag=\"hello\">
  <colorscope bgcolor=\"red\">
    <gtext>Hello</gtext>
  </colorscope>
</define>

<table><tr>
  <td bgcolor=\"red\">
    <hello/>
  </td>
</tr></table></ex-box>

 <p>It can also successfully be used when the wiretap module is turned off
 for e.g. performance reasons.</p>
</desc>

<attr name='text' value='color'><p>
 Set the text color to this value within the scope.</p>
</attr>

<attr name='bgcolor' value='color'><p>
 Set the background color to this value within the scope.</p>
</attr>

<attr name='link' value='color'><p>
 Set the link color to this value within the scope.</p>
</attr>

<attr name='alink' value='color'><p>
 Set the active link color to this value within the scope.</p>
</attr>

<attr name='vlink' value='color'><p>
 Set the visited link color to this value within the scope.</p>
</attr>",

//----------------------------------------------------------------------

"aconf":#"<desc type='cont'><p><short>
 Creates a link that can modify the config states in the cookie
 RoxenConfig.</short> In practice it will add &lt;keyword&gt;/ right
 after the server in the URL. E.g. if you want to remove the config
 state bacon and add config state egg the
 first \"directory\" in the path will be &lt;-bacon,egg&gt;. If the
 user follows this link the WebServer will understand how the
 RoxenConfig cookie should be modified and will send a new cookie
 along with a redirect to the given url, but with the first
 \"directory\" removed. The presence of a certain config state can be
 detected by the <xref href='../if/if_config.tag'/> tag.</p>
</desc>

<attr name='href' value='uri'>
 <p>Indicates which page should be linked to, if any other than the
 present one.</p>
</attr>

<attr name='add' value='string'>
 <p>The config state, or config states that should be added, in a comma
 separated list.</p>
</attr>

<attr name='drop' value='string'>
 <p>The config state, or config states that should be dropped, in a comma
 separated list.</p>
</attr>

<attr name='class' value='string'>
 <p>This cascading style sheet (CSS) class definition will apply to
 the a-element.</p>

 <p>All other attributes will be inherited by the generated <tag>a</tag> tag.</p>
</attr>",

//----------------------------------------------------------------------

"append":#"<desc type='both'><p><short>
 Appends a value to a variable. The variable attribute and one more is
 required.</short>
</p></desc>

<attr name='variable' value='string' required='required'>
 <p>The name of the variable.</p>
</attr>

<attr name='value' value='string'>
 <p>The value the variable should have appended.</p>

 <ex>
 <set variable='var.ris' value='Roxen'/>
 <append variable='var.ris' value=' Internet Software'/>
 &var.ris;
 </ex>
</attr>

<attr name='from' value='string'>
 <p>The name of another variable that the value should be copied
 from.</p>
</attr>",

//----------------------------------------------------------------------

"apre":#"<desc type='cont'><p><short>

 Creates a link that can modify prestates.</short> Prestates can be
 seen as valueless cookies or toggles that are easily modified by the
 user. The prestates are added to the URL. If you set the prestate
 \"no-images\" on \"http://www.demolabs.com/index.html\" the URL would
 be \"http://www.demolabs.com/(no-images)/\". Use <xref
 href='../if/if_prestate.tag' /> to test for the presence of a
 prestate. <tag>apre</tag> works just like the <tag>a href='...'</tag>
 container, but if no \"href\" attribute is specified, the current
 page is used. </p>

</desc>

<attr name='href' value='uri'>
 <p>Indicates which page should be linked to, if any other than the
 present one.</p>
</attr>

<attr name='add' value='string'>
 <p>The prestate or prestates that should be added, in a comma
 separated list.</p>
</attr>

<attr name='drop' value='string'>
 <p>The prestate or prestates that should be dropped, in a comma separated
 list.</p>
</attr>

<attr name='class' value='string'>
 <p>This cascading style sheet (CSS) class definition will apply to
 the a-element.</p>
</attr>",

//----------------------------------------------------------------------

"auth-required":#"<desc type='tag'><p><short>
 Adds an HTTP auth required header and return code (401), that will
 force the user to supply a login name and password.</short> This tag
 is needed when using access control in RXML in order for the user to
 be prompted to login.
</p></desc>

<attr name='realm' value='string' default='document access'>
 <p>The realm you are logging on to, i.e \"Demolabs Intranet\".</p>
</attr>

<attr name='message' value='string'>
 <p>Returns a message if a login failed or cancelled.</p>
</attr>",

//----------------------------------------------------------------------

"autoformat":#"<desc type='cont'><p><short hide='hide'>
 Replaces newlines with <tag>br/</tag>:s'.</short>Replaces newlines with
 <tag>br /</tag>:s'.</p>

<ex><autoformat>
It is almost like
using the pre tag.
</autoformat></ex>
</desc>

<attr name='p'>
 <p>Replace empty lines with <tag>p</tag>:s.</p>
<ex><autoformat p=''>
It is almost like

using the pre tag.
</autoformat></ex>
</attr>

<attr name='nobr'>
 <p>Do not replace newlines with <tag>br /</tag>:s.</p>
</attr>

<attr name='nonbsp'><p>
 Do not turn consecutive spaces into interleaved
 breakable/nonbreakable spaces. When this attribute is not given, the
 tag will behave more or less like HTML:s <tag>pre</tag> tag, making
 whitespace indention work, without the usually unwanted effect of
 really long lines extending the browser window width.</p>
</attr>

<attr name='class' value='string'>
 <p>This cascading style sheet (CSS) definition will be applied on the
 p elements.</p>
</attr>",

//----------------------------------------------------------------------

"cache":#"<desc type='cont'><p><short>
 This tag caches the evaluated result of its contents.</short> When
 the tag is encountered again in a later request, it can thus look up
 and return that result without evaluating the content again.</p>

 <p>Nested <tag>cache</tag> tags are normally cached separately, and
 they are also recognized so that the surrounding tags don't cache
 their contents too. It's thus possible to change the cache parameters
 or completely disable caching of a certain part of the content inside
 a <tag>cache</tag> tag.</p>
 
 <note><p>This implies that many RXML tags that surrounds the inner
 <tag>cache</tag> tag(s) won't be cached. The reason is that those
 surrounding tags use the result of the inner <tag>cache</tag> tag(s),
 which can only be established when the actual context in each request
 is compared to the cache parameters. See the section below about
 cache static tags, though.</p></note>

 <p>Besides the value produced by the content, all assignments to RXML
 variables in any scope are cached. I.e. an RXML code block which
 produces a value in a variable may be cached, and the same value will
 be assigned again to that variable when the cached entry is used.</p>

 <p>When the content is evaluated, the produced result is associated
 with a key that is specified by the optional attributes \"variable\",
 \"key\" and \"profile\". This key is what the the cached data depends
 on. If none of the attributes are used, the tag will have a single
 cache entry that always matches.</p>

 <note><p>It is easy to create huge amounts of cached values if the
 cache parameters are chosen badly. E.g. to depend on the contents of
 the form scope is typically only acceptable when combined with a
 fairly short cache time, since it's otherwise easy to fill up the
 memory on the server simply by making many requests with random
 variables.</p></note>

 <h1>Shared caches</h1>

 <p>The cache can be shared between all <tag>cache</tag> tags with
 identical content, which is typically useful in <tag>cache</tag> tags
 used in templates included into many pages. The drawback is that
 cache entries stick around when the <tag>cache</tag> tags change in
 the RXML source, and that the cache cannot be persistent (see below).
 Only shared caches have any effect if the RXML pages aren't compiled
 and cached as p-code.</p>

 <p>If the cache isn't shared, and the page is compiled to p-code
 which is saved persistently then the produced cache entries can also
 be saved persistently. See the \"persistent-cache\" attribute for
 more details.</p>

 <note><p>For non-shared caches, this tag depends on the caching in
 the RXML parser to work properly, since the cache is associated with
 the specific tag instance in the compiled RXML code. I.e. there must
 be some sort of cache on the top level that can associate the RXML
 source to an old p-code entry before the cache in this tag can have
 any effect. E.g. if the RXML parser module in WebServer is used, you
 have to make sure page caching is turned on in it. So if you don't
 get cache hits when you think there should be, the cache miss might
 not be in this tag but instead in the top level cache that maps the
 RXML source to p-code.</p>

 <p>Also note that non-shared timeout caches are only effective if the
 p-code is cached in RAM. If it should work for p-code that is cached
 on disk but not in RAM, you need to add the attribute
 \"persistent-cache=yes\".</p>

 <p>Note to Roxen CMS (a.k.a. SiteBuilder) users: The RXML parser
 module in WebServer is <i>not</i> used by Roxen CMS. See the CMS
 documentation for details about how to control RXML p-code
 caching.</p></note>

 <h1>Cache static tags</h1>

 <note><p>Note that this is only applicable if the compatibility level
 is set to 2.5 or higher.</p></note>

 <p>Some common tags, e.g. <tag>if</tag> and <tag>emit</tag>, are
 \"cache static\". That means that they are cached even though there
 are nested <tag>cache</tag> tag(s). That can be done since they
 simply let their content pass through (repeated zero or more
 times).</p>

 <p>Cache static tags are always evaluated when the surrounding
 <tag>cache</tag> generates a new entry. Other tags are evaluated when
 the entry is used, providing they contain or might contain nested
 <tag>cache</tag> or <tag>nocache</tag>. This can give side effects;
 consider this example:</p>

<ex-box>
<cache>
  <registered-user>
    <nocache>Your name is &registered-user.name;</nocache>
  </registered-user>
</cache>
</ex-box>

 <p>Assume the tag <tag>registered-user</tag> is a custom tag that
 ignores its content whenever the user isn't registered. If it isn't
 cache static, the nested <tag>nocache</tag> tag causes it to stay
 unevaluated in the surrounding cache, and the test of the user is
 therefore kept dynamic. If it on the other hand is cache static, that
 test is cached and the cache entry will either contain the
 <tag>nocache</tag> block and a cached assignment to
 <ent>registered-user.name</ent>, or none of the content inside
 <tag>registered-user</tag>. The dependencies of the outer cache must
 then include the user for it to work correctly.</p>

 <p>Because of this, it's important to know whether a tag is cache
 static or not, and it's noted in the doc for all such tags.</p>

 <h1>Compatibility</h1>

 <p>If the compatibility level of the site is lower than 2.2 and there
 is no \"variable\" or \"profile\" attribute, the cache depends on the
 contents of the form scope and the path of the current page (i.e.
 <ent>page.path</ent>). This is often a bad policy since it's easy for
 a client to generate many cache entries.</p>

 <p>None of the standard RXML tags are cache static if the
 compatibility level is 2.4 or lower.</p>
</desc>

<attr name='variable' value='string'>
 <p>This is a comma-separated list of variables and scopes that the
 cache should depend on. The value can be an empty string, which is
 useful to only disable the default dependencies in compatibility
 mode.</p>

 <p>Since it's important to keep down the size of the cache, this
 should typically be kept to only a few variables with a limited set
 of possible values, or else the cache should have a timeout.</p>
</attr>

<attr name='key' value='string'>
 <p>Use the value of this attribute directly in the key. This
 attribute mainly exist for compatibility; it's better to use the
 \"variable\" attribute instead.</p>

 <p>It is an error to use \"key\" together with \"propagate\", since
 it wouldn't do what you'd expect: The value for \"key\" would not be
 reevaluated when an entry is chosen from the cache, since the nested,
 propagating <tag>cache</tag> isn't reached at all then.</p>
</attr>

<attr name='profile' value='string'>
 <p>A comma-separated list to choose one or more profiles from a set
 of preconfigured cache profiles. Which cache profiles are available
 depends on the RXML parser module in use; the standard RXML parser
 currently has none.</p>
</attr>

<attr name='shared'>
 <p>Share the cache between different instances of the
 <tag>cache</tag> with identical content, wherever they may appear on
 this page or some other in the same server. See the tag description
 for details about shared caches.</p>
</attr>

<attr name='persistent-cache' value='yes|no'>
  <p>If the value is \"yes\" then the cache entries are saved
  persistently, providing the RXML p-code is saved. If it's \"no\"
  then the cache entries are not saved. If it's left out then the
  default is to save if there's no timeout on the cache, otherwise
  not. This attribute has no effect if the \"shared\" attribute is
  used; shared caches can not be saved persistently.</p>
</attr>

<attr name='nocache'>
 <p>Do not cache the content in any way. Typically useful to disable
 caching of a section inside another cache tag.</p>
</attr>

<attr name='propagate'>
 <p>Propagate the cache dependencies to the surrounding
 <tag>cache</tag> tag, if there is any. Useful to locally add
 dependencies to a cache without introducing a new cache level. If
 there is no surrounding <tag>cache</tag> tag, this attribute is
 ignored.</p>

 <p>Note that only the dependencies are propagated, i.e. the settings
 in the \"variable\", \"key\" and \"profile\" attributes. The other
 attributes are used only if there's no surrounding <tag>cache</tag>
 tag.</p>
</attr>

<attr name='nohash'>
 <p>If the cache is shared, then the content won't be made part of the
 cache key. Thus the cache entries can be mixed up with other
 <tag>cache</tag> tags.</p>
</attr>

<attr name='not-post-method'>
 <p>By adding this attribute all HTTP requests using the POST method will
 be unaffected by the caching. The result will be calculated every time,
 and the result will not be stored in the cache. The contents of the cache
 will however remain unaffected by the POST request.</p>
</attr>

<attr name='flush-on-no-cache'>
 <p>If this attribute is used the cache will be flushed every time a client
 sends a pragma no-cache header to the server. These are e.g. sent when
 shift+reload is pressed in Netscape Navigator.</p>
</attr>

<attr name='enable-client-cache'>
</attr>

<attr name='enable-protocol-cache'>
</attr>


<attr name='years' value='number'>
 <p>Add this number of years to the time this entry is valid.</p>
</attr>
<attr name='months' value='number'>
 <p>Add this number of months to the time this entry is valid.</p>
</attr>
<attr name='weeks' value='number'>
 <p>Add this number of weeks to the time this entry is valid.</p>
</attr>
<attr name='days' value='number'>
 <p>Add this number of days to the time this entry is valid.</p>
</attr>
<attr name='hours' value='number'>
 <p>Add this number of hours to the time this entry is valid.</p>
</attr>
<attr name='beats' value='number'>
 <p>Add this number of beats to the time this entry is valid.</p>
</attr>
<attr name='minutes' value='number'>
 <p>Add this number of minutes to the time this entry is valid.</p>
</attr>
<attr name='seconds' value='number'>
 <p>Add this number of seconds to the time this entry is valid.</p>
</attr>",

// Intentionally left undocumented:
//
// <attr name='disable-key-hash'>
//  Do not hash the key used in the cache entry. Normally the
//  produced key is hashed to reduce memory usage and improve speed,
//  but since that makes it theoretically possible that two cache
//  entries clash, this attribute may be used to avoid it.
// </attr>

//----------------------------------------------------------------------

"nocache": #"<desc type='cont'><p><short>
 Avoid caching of a part inside a <tag>cache</tag> tag.</short> This
 is the same as using the <tag>cache</tag> tag with the nocache
 attribute.</p>

 <p>Note that when a part inside a <tag>cache</tag> tag isn't cached,
 it implies that any RXML tags that surround the <tag>nocache</tag>
 tag inside the <tag>cache</tag> tag also aren't cached.</p>
</desc>",

//----------------------------------------------------------------------

"catch":#"<desc type='cont'><p><short>
 Evaluates the RXML code, and, if nothing goes wrong, returns the
 parsed contents.</short> If something does go wrong, the error
 message is returned instead. See also <xref
 href='throw.tag' />.
</p>
</desc>",

//----------------------------------------------------------------------

"charset":#"<desc type='both'><p>
 <short>Converts between character sets.</short> The tag can be used both
 to decode texts encoded in strange character encoding schemas, but also
 to decide upon the final encoding of the resulting page. All character
 sets listed in <a href='http://rfc.roxen.com/1345'>RFC 1345</a> are
 supported.
</p>
</desc>

<attr name='in' value='Character set'><p>
 Converts the contents of the charset tag from the character set indicated
 by this attribute to the internal text representation.</p>
</attr>

<attr name='out' value='Character set'><p>
 Sets the output conversion character set of the current request. The page
 will be sent encoded with the indicated character set.</p>
</attr>
",

//----------------------------------------------------------------------

"configimage":#"<desc type='tag'><p><short>
 Returns one of the internal Roxen configuration images.</short> The
 src attribute is required.
</p></desc>

<attr name='src' value='string'>
 <p>The name of the picture to show.</p>
</attr>

<attr name='border' value='number' default='0'>
 <p>The image border when used as a link.</p>
</attr>

<attr name='alt' value='string' default='The src string'>
 <p>The picture description.</p>
</attr>

<attr name='class' value='string'>
 <p>This cascading style sheet (CSS) class definition will be applied to
 the image.</p>

 <p>All other attributes will be inherited by the generated img tag.</p>
</attr>",

//----------------------------------------------------------------------

"configurl":#"<desc type='tag'><p><short>
 Returns a URL to the administration interface.</short>
</p></desc>",

//----------------------------------------------------------------------

"cset":#"<desc type='cont'><p>
 Sets a variable with its content. This is deprecated in favor of
 using the &lt;set&gt;&lt;/set&gt; construction.</p>
</desc>

<attr name='variable' value='name'>
 <p>The variable to be set.</p>
</attr>

<attr name='quote' value='html|none'>
 <p>How the content should be quoted before assigned to the variable.
 Default is html.</p>
</attr>",

//----------------------------------------------------------------------

"crypt":#"<desc type='cont'><p><short>
 Encrypts the contents as a Unix style password.</short> Useful when
 combined with services that use such passwords.</p>

 <p>Unix style passwords are one-way encrypted, to prevent the actual
 clear-text password from being stored anywhere. When a login attempt
 is made, the password supplied is also encrypted and then compared to
 the stored encrypted password.</p>
</desc>

<attr name='compare' value='string'>
 <p>Compares the encrypted string with the contents of the tag. The tag
 will behave very much like an <xref href='../if/if.tag' /> tag.</p>
<ex><crypt compare=\"LAF2kkMr6BjXw\">Roxen</crypt>
<then>Yepp!</then>
<else>Nope!</else>
</ex>
</attr>",

//----------------------------------------------------------------------

"date":#"<desc type='tag'><p><short>
 Inserts the time and date.</short> Does not require attributes.
</p>

<ex><date/></ex>
</desc>

<attr name='unix-time' value='number of seconds'>
 <p>Display this time instead of the current. This attribute uses the
 specified Unix 'time_t' time as the starting time (which is
 <i>01:00, January the 1st, 1970</i>), instead of the current time.
 This is mostly useful when the <tag>date</tag> tag is used from a
 Pike-script or Roxen module.</p>

<ex><date unix-time='120'/></ex>
</attr>

<attr name='iso-time' value='{yyyy-mm-dd, yyyy-mm-dd hh:mm, yyyy-mm-dd hh:mm:ss}'>
 <p>Display this time instead of the current. This attribute uses the specified
ISO 8601 time as the starting time, instead of the current time. The character
between the date and the time can be either \" \" (space) or \"T\" (the letter T).</p>

<ex><date iso-time='2002-09-03 16:06'/></ex>
</attr>

<attr name='timezone' value='local|GMT' default='local'>
 <p>Display the time from another timezone.</p>
</attr>

<attr name='years' value='number'>
 <p>Add this number of years to the result.</p>
 <ex><date date='' years='2'/></ex>
</attr>

<attr name='months' value='number'>
 <p>Add this number of months to the result.</p>
 <ex><date date='' months='2'/></ex>
</attr>

<attr name='weeks' value='number'>
 <p>Add this number of weeks to the result.</p>
 <ex><date date='' weeks='2'/></ex>
</attr>

<attr name='days' value='number'>
 <p>Add this number of days to the result.</p>
</attr>

<attr name='hours' value='number'>
 <p>Add this number of hours to the result.</p>
 <ex><date time='' hours='2' type='iso'/></ex>
</attr>

<attr name='beats' value='number'>
 <p>Add this number of beats to the result.</p>
 <ex><date time='' beats='10' type='iso'/></ex>
</attr>

<attr name='minutes' value='number'>
 <p>Add this number of minutes to the result.</p>
</attr>

<attr name='seconds' value='number'>
 <p>Add this number of seconds to the result.</p>
</attr>

<attr name='adjust' value='number'>
 <p>Add this number of seconds to the result.</p>
</attr>

<attr name='brief'>
 <p>Show in brief format.</p>
<ex><date brief=''/></ex>
</attr>

<attr name='time'>
 <p>Show only time.</p>
<ex><date time=''/></ex>
</attr>

<attr name='date'>
 <p>Show only date.</p>
<ex><date date=''/></ex>
</attr>

<attr name='type' value='string|ordered|iso|discordian|stardate|number|unix'>
 <p>Defines in which format the date should be displayed in. Discordian
 and stardate only make a difference when not using part. Note that
 type='stardate' has a separate companion attribute, prec, which sets
 the precision.</p>

<xtable>
<row><c><p><i>type=discordian</i></p></c><c><ex><date date='' type='discordian'/> </ex></c></row>
<row><c><p><i>type=iso</i></p></c><c><ex><date date='' type='iso'/></ex></c></row>
<row><c><p><i>type=number</i></p></c><c><ex><date date='' type='number'/></ex></c></row>
<row><c><p><i>type=ordered</i></p></c><c><ex><date date='' type='ordered'/></ex></c></row>
<row><c><p><i>type=stardate</i></p></c><c><ex><date date='' type='stardate'/></ex></c></row>
<row><c><p><i>type=string</i></p></c><c><ex><date date='' type='string'/></ex></c></row>
<row><c><p><i>type=unix</i></p></c><c><ex><date date='' type='unix'/></ex></c></row>
</xtable>
</attr>

<attr name='part' value='year|month|day|wday|date|mday|hour|minute|second|yday|beat|week|seconds'>
 <p>Defines which part of the date should be displayed. Day and wday is
 the same. Date and mday is the same. Yday is the day number of the
 year. Seconds is unix time type. Only the types string, number and
 ordered applies when the part attribute is used.</p>

<xtable><row><h>Part</h><h>Meaning</h></row>
<row><c><p>year</p></c>
  <c><p>Display the year.</p>
     <ex><date part='year' type='number'/></ex></c></row>
<row><c><p>month</p></c>
  <c><p>Display the month.</p>
     <ex><date part='month' type='ordered'/></ex></c></row>
<row><c><p>day</p></c>
  <c><p>Display the weekday, starting with Sunday.</p>
     <ex><date part='day' type='ordered'/></ex></c></row>
<row><c><p>wday</p></c>
  <c><p>Display the weekday. Same as 'day'.</p>
     <ex><date part='wday' type='string'/></ex></c></row>
<row><c><p>date</p></c>
  <c><p>Display the day of this month.</p>
     <ex><date part='date' type='ordered'/></ex></c></row>
<row><c><p>mday</p></c>
  <c><p>Display the number of days since the last full month.</p>
     <ex><date part='mday' type='number'/></ex></c></row>
<row><c><p>hour</p></c>
  <c><p>Display the numbers of hours since midnight.</p>
     <ex><date part='hour' type='ordered'/></ex></c></row>
<row><c><p>minute</p></c>
  <c><p>Display the numbers of minutes since the last full hour.</p>
     <ex><date part='minute' type='number'/></ex></c></row>
<row><c><p>second</p></c>
  <c><p>Display the numbers of seconds since the last full minute.</p>
     <ex><date part='second' type='string'/></ex></c></row>
<row><c><p>yday</p></c>
  <c><p>Display the number of days since the first of January.</p>
     <ex><date part='yday' type='ordered'/></ex></c></row>
<row><c><p>beat</p></c>
  <c><p>Display the number of beats since midnight Central European
  Time(CET). There is a total of 1000 beats per day. The beats system
  was designed by <a href='http://www.swatch.com'>Swatch</a> as a
  means for a universal time, without time zones and day/night
  changes.</p>
     <ex><date part='beat' type='number'/></ex></c></row>
<row><c><p>week</p></c>
  <c><p>Display the number of the current week.</p>
     <ex><date part='week' type='number'/></ex></c></row>
<row><c><p>seconds</p></c>
  <c><p>Display the total number of seconds this year.</p>
     <ex><date part='seconds' type='number'/></ex></c></row>
</xtable></attr>

<attr name='strftime' value='string'>
 <p>If this attribute is given to date, it will format the result
 according to the argument string.</p>

<xtable>
 <row><h>Format</h><h>Meaning</h></row>
 <row><c><p>%%</p></c><c><p>Percent character</p></c></row>
 <row><c><p>%a</p></c><c><p>Abbreviated weekday name, e.g. \"Mon\"</p></c></row>
 <row><c><p>%A</p></c><c><p>Weekday name</p></c></row>
 <row><c><p>%b</p></c><c><p>Abbreviated month name, e.g. \"Jan\"</p></c></row>
 <row><c><p>%B</p></c><c><p>Month name</p></c></row>
 <row><c><p>%c</p></c><c><p>Date and time, e.g. \"%a %b %d  %H:%M:%S %Y\"</p></c></row>
 <row><c><p>%C</p></c><c><p>Century number, zero padded to two charachters.</p></c></row>
 <row><c><p>%d</p></c><c><p>Day of month (1-31), zero padded to two characters.</p></c></row>
 <row><c><p>%D</p></c><c><p>Date as \"%m/%d/%y\"</p></c></row>
 <row><c><p>%e</p></c><c><p>Day of month (1-31), space padded to two characters.</p></c></row>
 <row><c><p>%H</p></c><c><p>Hour (24 hour clock, 0-23), zero padded to two characters.</p></c></row>
 <row><c><p>%h</p></c><c><p>See %b</p></c></row>
 <row><c><p>%I</p></c><c><p>Hour (12 hour clock, 1-12), zero padded to two charcters.</p></c></row>
 <row><c><p>%j</p></c><c><p>Day numer of year (1-366), zero padded to three characters.</p></c></row>
 <row><c><p>%k</p></c><c><p>Hour (24 hour clock, 0-23), space padded to two characters.</p></c></row>
 <row><c><p>%l</p></c><c><p>Hour (12 hour clock, 1-12), space padded to two characters.</p></c></row>
 <row><c><p>%m</p></c><c><p>Month number (1-12), zero padded to two characters.</p></c></row>
 <row><c><p>%M</p></c><c><p>Minute (0-59), zero padded to two characters.</p></c></row>
 <row><c><p>%n</p></c><c><p>Newline</p></c></row>
 <row><c><p>%p</p></c><c><p>\"a.m.\" or \"p.m.\"</p></c></row>
 <row><c><p>%r</p></c><c><p>Time in 12 hour clock format with %p</p></c></row>
 <row><c><p>%R</p></c><c><p>Time as \"%H:%M\"</p></c></row>
 <row><c><p>%S</p></c><c><p>Seconds (0-61), zero padded to two characters.</p></c></row>
 <row><c><p>%t</p></c><c><p>Tab</p></c></row>
 <row><c><p>%T</p></c><c><p>Time as \"%H:%M:%S\"</p></c></row>
 <row><c><p>%u</p></c><c><p>Weekday as a decimal number (1-7), 1 is Sunday.</p></c></row>
 <row><c><p>%U</p></c><c><p>Week number of year as a decimal number (0-53), with sunday as the first day of week 1,
    zero padded to two characters.</p></c></row>
 <row><c><p>%V</p></c><c><p>ISO week number of the year as a decimal number (1-53), zero padded to two characters.</p></c></row>
 <row><c><p>%w</p></c><c><p>Weekday as a decimal number (0-6), 0 is Sunday.</p></c></row>
 <row><c><p>%W</p></c><c><p>Week number of year as a decimal number (0-53), with sunday as the first day of week 1,
    zero padded to two characters.</p></c></row>
 <row><c><p>%x</p></c><c><p>Date as \"%a %b %d %Y\"</p></c></row>
 <row><c><p>%X</p></c><c><p>See %T</p></c></row>
 <row><c><p>%y</p></c><c><p>Year (0-99), zero padded to two characters.</p></c></row>
 <row><c><p>%Y</p></c><c><p>Year (0-9999), zero padded to four characters.</p></c></row>
</xtable>

<ex><date strftime=\"%B %e %Y, %A %T\"/></ex>
</attr>

<attr name='lang' value='langcode'>
 <p>Defines in what language a string will be presented in. Used together
 with <att>type=string</att> and the <att>part</att> attribute to get
 written dates in the specified language.</p>

<ex><date part='day' type='string' lang='de'/></ex>
</attr>

<attr name='case' value='upper|lower|capitalize'>
 <p>Changes the case of the output to upper, lower or capitalize.</p>
 <ex><date date='' lang='&client.language;' case='upper'/></ex>
</attr>

<attr name='prec' value='number'>
 <p>The number of decimals in the stardate.</p>
</attr>",

//----------------------------------------------------------------------

"debug":#"<desc type='tag'><p><short>
 Helps debugging RXML-pages as well as modules.</short> When debugging mode is
 turned on, all error messages will be displayed in the HTML code.
</p></desc>

<attr name='on'>
 <p>Turns debug mode on.</p>
</attr>

<attr name='off'>
 <p>Turns debug mode off.</p>
</attr>

<attr name='toggle'>
 <p>Toggles debug mode.</p>
</attr>

<attr name='showid' value='string'>
 <p>Shows a part of the id object. E.g. showid=\"id->request_headers\".</p>
</attr>

<attr name='werror' value='string'>
  <p>When you have access to the server debug log and want your RXML
     page to write some kind of diagnostics message or similar, the
     werror attribute is helpful.</p>

  <p>This can be used on the error page, for instance, if you'd want
     such errors to end up in the debug log:</p>

  <ex-box><debug werror='File &page.url; not found!
(linked from &client.referrer;)'/></ex-box>

  <p>The message is also shown the request trace, e.g. when
  \"Tasks\"/\"Debug information\"/\"Resolve path...\" is used in the
  configuration interface.</p>
</attr>",

//----------------------------------------------------------------------

"dec":#"<desc type='tag'><p><short>
 Subtracts 1 from a variable.</short>
</p></desc>

<attr name='variable' value='string' required='required'>
 <p>The variable to be decremented.</p>
</attr>

<attr name='value' value='number' default='1'>
 <p>The value to be subtracted.</p>
</attr>",

//----------------------------------------------------------------------

"default":#"<desc type='cont'><p><short hide='hide'>
 Used to set default values for form elements.</short> This tag makes it easier
 to give default values to \"<tag>select</tag>\" and \"<tag>input</tag>\" form elements.
 Simply put the <tag>default</tag> tag around the form elements to which it should give
 default values.</p>

 <p>This tag is particularly useful in combination with generated forms or forms with
 generated default values, e.g. by database tags.</p>
</desc>

<attr name='value' value='string'>
 <p>The value or values to set. If several values are given, they are separated with the
 separator string.</p>
</attr>

<attr name='separator' value='string' default=','>
 <p>If several values are to be selected, this is the string that
 separates them.</p>
</attr>

<attr name='name' value='string'>
 <p>If used, the default tag will only affect form element with this name.</p>
</attr>

<ex-box><default name='my-select' value='&form.preset;'>
  <select name='my-select'>
    <option value='1'>First</option>
    <option value='2'>Second</option>
    <option value='3'>Third</option>
  </select>
</default></ex-box>

<ex-box><form>
<default value=\"&form.opt1;,&form.opt2;,&form.opt3;\">
  <input name=\"opt1\" value=\"yes1\" type=\"checkbox\" /> Option #1
  <input name=\"opt2\" value=\"yes2\" type=\"checkbox\" /> Option #2
  <input name=\"opt3\" value=\"yes3\" type=\"checkbox\" /> Option #3
  <input type=\"submit\" />
</default>
</form></ex-box>",

"doc":#"<desc type='cont'><p><short hide='hide'>
 Eases code documentation by reformatting it.</short>Eases
 documentation by replacing \"{\", \"}\" and \"&amp;\" with
 \"&amp;lt;\", \"&amp;gt;\" and \"&amp;amp;\". No attributes required.
</p></desc>

<attr name='quote'>
 <p>Instead of replacing with \"{\" and \"}\", \"&lt;\" and \"&gt;\"
 is replaced with \"&amp;lt;\" and \"&amp;gt;\".</p>

<ex><doc quote=''>
<table>
 <tr>
    <td> First cell </td>
    <td> Second cell </td>
 </tr>
</table>
</doc></ex>
</attr>

<attr name='pre'><p>
 The result is encapsulated within a <tag>pre</tag> container.</p>

<ex><doc pre=''>
{table}
 {tr}
    {td} First cell {/td}
    {td} Second cell {/td}
 {/tr}
{/table}
</doc></ex>
</attr>

<attr name='class' value='string'>
 <p>This cascading style sheet (CSS) definition will be applied on the pre element.</p>
</attr>",

//----------------------------------------------------------------------

"expire-time":#"<desc type='tag'><p><short hide='hide'>
 Sets client cache expire time for the document.</short>
 Sets client cache expire time for the document by sending the HTTP header
 \"Expires\". Note that on most systems the time can only be set to dates
 before 2038 due to operating software limitations.
</p></desc>

<attr name='now'>
 <p>Notify the client that the document expires now. The headers
 \"Pragma: no-cache\" and \"Cache-Control: no-cache\"
 will also be sent, besides the \"Expires\" header.</p>
</attr>

<attr name='unix-time' value='number'>
 <p>The exact time of expiration, expressed as a posix time integer.</p>
</attr>

<attr name='years' value='number'>
 <p>Add this number of years to the result.</p>
</attr>

<attr name='months' value='number'>
  <p>Add this number of months to the result.</p>
</attr>

<attr name='weeks' value='number'>
  <p>Add this number of weeks to the result.</p>
</attr>

<attr name='days' value='number'>
  <p>Add this number of days to the result.</p>
</attr>

<attr name='hours' value='number'>
  <p>Add this number of hours to the result.</p>
</attr>

<attr name='beats' value='number'>
  <p>Add this number of beats to the result.</p>
</attr>

<attr name='minutes' value='number'>
  <p>Add this number of minutes to the result.</p>
</attr>

<attr name='seconds' value='number'>
   <p>Add this number of seconds to the result.</p>

</attr>",

//----------------------------------------------------------------------

"for":#"<desc type='cont'><p><short>
 Makes it possible to create loops in RXML.</short>

 <note><p>This tag is cache static (see the <tag>cache</tag> tag)
 if the compatibility level is set to 2.5 or higher.</p></note>
</p></desc>

<attr name='from' value='number'>
 <p>Initial value of the loop variable.</p>
</attr>

<attr name='step' value='number'>
 <p>How much to increment the variable per loop iteration. By default one.</p>
</attr>

<attr name='to' value='number'>
 <p>How much the loop variable should be incremented to.</p>
</attr>

<attr name='variable' value='name'>
 <p>Name of the loop variable.</p>
</attr>",

//----------------------------------------------------------------------

"fsize":#"<desc type='tag'><p><short>
 Prints the size of the specified file.</short>
</p></desc>

<attr name='file' value='string'>
 <p>Show size for this file.</p>
</attr>",

//----------------------------------------------------------------------

"gauge":#"<desc type='cont'><p><short>
 Measures how much CPU time it takes to run its contents through the
 RXML parser.</short> Returns the number of seconds it took to parse
 the contents.
</p></desc>

<attr name='variable' value='string'>
 <p>The result will be put into a variable. E.g. variable=\"var.gauge\" will
 put the result in a variable that can be reached with <ent>var.gauge</ent>.</p>
</attr>

<attr name='silent'>
 <p>Don't print anything.</p>
</attr>

<attr name='timeonly'>
 <p>Only print the time.</p>
</attr>

<attr name='resultonly'>
 <p>Only print the result of the parsing. Useful if you want to put the time in
 a database or such.</p>
</attr>",

//----------------------------------------------------------------------

"header":#"<desc type='tag'><p><short>
 Adds a HTTP header to the page sent back to the client.</short> For
 more information about HTTP headers please steer your browser to
 chapter 14, 'Header field definitions' in <a href='http://community.roxen.com/developers/idocs/rfc/rfc2616.html'>RFC 2616</a>, available at Roxen Community.
</p></desc>

<attr name='name' value='string'>
 <p>The name of the header.</p>
</attr>

<attr name='value' value='string'>
 <p>The value of the header.</p>
</attr>",

//----------------------------------------------------------------------

"imgs":#"<desc type='tag'><p><short>
 Generates a image tag with the correct dimensions in the width and height
 attributes. These dimensions are read from the image itself, so the image
 must exist when the tag is generated. The image must also be in GIF, JPEG/JFIF
 or PNG format.</short>
</p></desc>

<attr name='src' value='string' required='required'>
 <p>The path to the file that should be shown.</p>
</attr>

<attr name='alt' value='string'>
 <p>Description of the image. If no description is provided, the filename
 (capitalized, without extension and with some characters replaced) will
 be used.</p>
 </attr>

 <p>All other attributes will be inherited by the generated img tag.</p>",

//----------------------------------------------------------------------

"inc":#"<desc type='tag'><p><short>
 Adds 1 to a variable.</short>
</p></desc>

<attr name='variable' value='string' required='required'>
 <p>The variable to be incremented.</p>
</attr>

<attr name='value' value='number' default='1'>
 <p>The value to be added.</p>
</attr>",

//----------------------------------------------------------------------

"insert":#"<desc type='tag'><p><short>
 Inserts a file, variable or other object into a webpage.</short>
</p></desc>

<attr name='quote' value='html|none'>
 <p>How the inserted data should be quoted. Default is \"html\", except for
 the file plugin where it's \"none\".</p>
</attr>",

//----------------------------------------------------------------------

"insert#variable":#"<desc type='plugin'><p><short>
 Inserts the value of a variable.</short>
</p></desc>

<attr name='variable' value='string'>
 <p>The name of the variable.</p>
</attr>

<attr name='scope' value='string'>
 <p>The name of the scope, unless given in the variable attribute.</p>
</attr>

<attr name='index' value='number'>
 <p>If the value of the variable is an array, the element with this
 index number will be inserted. 1 is the first element. -1 is the last
 element.</p>
</attr>

<attr name='split' value='string'>
 <p>A string with which the variable value should be splitted into an
 array, so that the index attribute may be used.</p>
</attr>",

//----------------------------------------------------------------------

"insert#variables":#"<desc type='plugin'><p><short>
 Inserts a listing of all variables in a scope.</short></p><note><p>It is
 possible to create a scope with an infinite number of variables set.
 In this case the programmer of that scope decides which variables that
 should be listable, i.e. this will not cause any problem except that
 all variables will not be listed. It is also possible to hide
 variables so that they are not listed with this tag.
</p></note></desc>

<attr name='variables' value='full|plain'>
 <p>Sets how the output should be formatted.</p>

 <ex><pre>
<insert variables='full' scope='roxen'/>
</pre></ex>
</attr>

<attr name='scope'>
 <p>The name of the scope that should be listed, if not the present scope.</p>
</attr>",

//----------------------------------------------------------------------

"insert#scopes":#"<desc type='plugin'><p><short>
 Inserts a listing of all present variable scopes.</short>
</p></desc>

<attr name='scopes' value='full|plain'>
 <p>Sets how the output should be formatted.</p>

 <ex><insert scopes='plain'/></ex>
</attr>",

//----------------------------------------------------------------------

"insert#file":#"<desc type='plugin'><p><short>
 Inserts the contents of a file.</short> It reads files in a way
 similar to if you fetched the file with a browser, so the file may be
 parsed before it is inserted, depending on settings in the RXML
 parser. Most notably which kinds of files (extensions) that should be
 parsed. Since it reads files like a normal request, e.g. generated
 pages from location modules can be inserted. Put the tag
 <xref href='../programming/eval.tag' /> around <tag>insert</tag> if the file should be
 parsed after it is inserted in the page. This enables RXML defines
 and scope variables to be set in the including file (as opposed to
 the included file). You can also configure the file system module so
 that files with a certain extension can not be downloaded, but still
 inserted into other documents.
</p></desc>

<attr name='file' value='string'>
 <p>The virtual path to the file to be inserted.</p>

 <ex-box><eval><insert file='html_header.inc'/></eval></ex-box>
</attr>",

//----------------------------------------------------------------------

"insert#realfile":#"<desc type='plugin'><p><short>
 Inserts a raw, unparsed file.</short> The disadvantage with the
 realfile plugin compared to the file plugin is that the realfile
 plugin needs the inserted file to exist, and can't fetch files from e.g.
 an arbitrary location module. Note that the realfile insert plugin
 can not fetch files from outside the virtual file system.
</p></desc>

<attr name='realfile' value='string'>
 <p>The virtual path to the file to be inserted.</p>
</attr>",

//----------------------------------------------------------------------

"maketag":({ #"<desc type='cont'><p><short hide='hide'>
 Makes it possible to create tags.</short>This tag creates tags.
 The contents of the container will be put into the contents of the produced container.
</p></desc>

<attr name='name' value='string'>
 <p>The name of the tag that should be produced. This attribute is required for tags,
 containers and processing instructions, i.e. for the types 'tag', 'container' and 'pi'.</p>
<ex-src><maketag name='one' type='tag'></maketag>
<maketag name='one' type='tag' noxml='noxml'></maketag></ex-src>
</attr>

<attr name='noxml'>
 <p>Tags should not be terminated with a trailing slash. Only makes a difference for
 the type 'tag'.</p>
</attr>

<attr name='type' value='tag|container|pi|comment|cdata'>
 <p>What kind of tag should be produced. The argument 'Pi' will produce a processing instruction tag.</p>
<ex-src><maketag type='pi' name='PICS'>l gen true r (n 0 s 0 v 0 l 2)</maketag></ex-src>
<ex-src><maketag type='comment'>Menu starts here</maketag></ex-src>
<ex-box><maketag type='comment'>Debug: &form.res; &var.sql;</maketag></ex-box>
<ex-src><maketag type='cdata'>Exact   words</maketag></ex-src>
</attr>",

 ([
   "attrib":#"<desc type='cont'><p>
   Inside the maketag container the container
   <tag>attrib</tag> is defined. It is used to add attributes to the produced
   tag. The contents of the attribute container will be the
   attribute value. E.g.</p>
   </desc>

<ex><eval>
<maketag name=\"replace\" type=\"container\">
 <attrib name=\"from\">A</attrib>
 <attrib name=\"to\">U</attrib>
 MAD
</maketag>
</eval>
</ex>

   <attr name='name' value='string' required='required'>
   <p>The name of the attribute.</p>
   </attr>"
 ])
   }),

//----------------------------------------------------------------------

"modified":#"<desc type='tag'><p><short hide='hide'>
 Prints when or by whom a page was last modified.</short> Prints when
 or by whom a page was last modified, by default the current page.
</p></desc>

<attr name='by'>
 <p>Print by whom the page was modified. Takes the same attributes as
 <xref href='user.tag' />. This attribute requires a user database.
 </p>

 <ex-box>This page was last modified by <modified by='1'
 realname='1'/>.</ex-box>
</attr>

<attr name='file' value='path'>
 <p>Get information about this file rather than the current page.</p>
</attr>

<attr name='realfile' value='path'>
 <p>Get information from this file in the computer's filesystem rather
 than Roxen Webserver's virtual filesystem.</p>
</attr>",

//----------------------------------------------------------------------

"random":#"<desc type='cont'><p><short>
 Randomly chooses a message from its contents.</short>
</p></desc>

<attr name='separator' value='string'>
 <p>The separator used to separate the messages, by default newline.</p>

<ex><random separator='#'>Foo#Bar#Baz</random></ex>
</attr>

<attr name='seed' value='string'>
 <p>Enables you to use a seed that determines which message to choose.</p>

<ex-box>Tip of the day:
<set variable='var.day'><date type='iso' date=''/></set>
<random seed='var.day'><insert file='tips.txt'/></random></ex-box>
</attr>",

//----------------------------------------------------------------------

"redirect":#"<desc type='tag'><p><short hide='hide'>
 Redirects the user to another page.</short> Redirects the user to
 another page by sending a HTTP redirect header to the client. If the
 redirect is local, i.e. within the server, all prestates are preserved.
 E.g. \"/index.html\" and \"index.html\" preserves the prestates, while
 \"http://server.com/index.html\" does not.
</p></desc>

<attr name='to' value='URL' required='required'>
 <p>The location to where the client should be sent.</p>
</attr>

<attr name='add' value='string'>
 <p>The prestate or prestates that should be added, in a comma separated
 list.</p>
</attr>

<attr name='drop' value='string'>
 <p>The prestate or prestates that should be dropped, in a comma separated
 list.</p>
</attr>

<attr name='drop-all'>
 <p>Removes all prestates from the redirect target.</p>
</attr>

<attr name='text' value='string'>
 <p>Sends a text string to the browser, that hints from where and why the
 page was redirected. Not all browsers will show this string. Only
 special clients like Telnet uses it.</p>

<p>Arguments prefixed with \"add\" or \"drop\" are treated as prestate
 toggles, which are added or removed, respectively, from the current
 set of prestates in the URL in the redirect header (see also <xref href='apre.tag' />). Note that this only works when the
 to=... URL is absolute, i.e. begins with a \"/\", otherwise these
 state toggles have no effect.</p>
</attr>",

//----------------------------------------------------------------------

"remove-cookie":#"<desc type='tag'><p><short>
 Sets the expire-time of a cookie to a date that has already occured.
 This forces the browser to remove it.</short>
 This tag won't remove the cookie, only set it to the empty string, or
 what is specified in the value attribute and change
 it's expire-time to a date that already has occured. This is
 unfortunutaly the only way as there is no command in HTTP for
 removing cookies. We have to give a hint to the browser and let it
 remove the cookie.
</p></desc>

<attr name='name' required='required'>
 <p>Name of the cookie the browser should remove.</p>
</attr>

<attr name='value' value='text'>
 <p>Even though the cookie has been marked as expired some browsers
 will not remove the cookie until it is shut down. The text provided
 with this attribute will be the cookies intermediate value.</p>

 <p>Note that removing a cookie won't take effect until the next page
 load.</p>
</attr>

<attr name='domain'>
 <p>Domain of the cookie the browser should remove.</p>
</attr>

<attr name='path' value='string' default=\"\">
  <p>Path of the cookie the browser should remove</p>
</attr>",

//----------------------------------------------------------------------

"replace":#"<desc type='cont'><p><short>
 Replaces strings in the contents with other strings.</short>
</p></desc>

<attr name='from' value='string' required='required'>
 <p>String or list of strings that should be replaced.</p>
</attr>

<attr name='to' value='string'>
 <p>String or list of strings with the replacement strings. Default is the
 empty string.</p>
</attr>

<attr name='separator' value='string' default=','>
 <p>Defines what string should separate the strings in the from and to
 attributes.</p>
</attr>

<attr name='type' value='word|words' default='word'>
 <p>Word means that a single string should be replaced. Words that from
 and to are lists.</p>
</attr>",

//----------------------------------------------------------------------

"return":#"<desc type='tag'><p><short>
 Changes the HTTP return code for this page. </short>
 <!-- See the Appendix for a list of HTTP return codes. (We have no appendix) -->
</p></desc>

<attr name='code' value='integer'>
 <p>The HTTP status code to return.</p>
</attr>

<attr name='text'>
 <p>The HTTP status message to set. If you don't provide one, a default
 message is provided for known HTTP status codes, e g \"No such file
 or directory.\" for code 404.</p>
</attr>",

//----------------------------------------------------------------------

"roxen":#"<desc type='tag'><p><short>
 Returns a nice Roxen logo.</short>
</p></desc>

<attr name='size' value='small|medium|large' default='medium'>
 <p>Defines the size of the image.</p>
<ex><roxen size='small'/>
<roxen/>
<roxen size='large'/></ex>
</attr>

<attr name='color' value='black|white' default='white'>
 <p>Defines the color of the image.</p>
<ex><roxen color='black'/></ex>
</attr>

<attr name='alt' value='string' default='\"Powered by Roxen\"'>
 <p>The image description.</p>
</attr>

<attr name='border' value='number' default='0'>
 <p>The image border.</p>
</attr>

<attr name='class' value='string'>
 <p>This cascading style sheet (CSS) definition will be applied on the img element.</p>
</attr>

<attr name='target' value='string'>
 <p>Names a target frame for the link around the image.</p>

 <p>All other attributes will be inherited by the generated img tag.</p>
</attr> ",

//----------------------------------------------------------------------

"scope":#"<desc type='cont'><p><short>
 Creates a new variable scope.</short> Variable changes inside the scope
 container will not affect variables in the rest of the page.
</p></desc>

<attr name='extend' value='name' default='form'>
 <p>If set, all variables in the selected scope will be copied into
 the new scope. NOTE: if the source scope is \"magic\", as e.g. the
 roxen scope, the scope will not be copied, but rather linked and will
 behave as the original scope. It can be useful to create an alias or
 just for the convinience of refering to the scope as \"_\".</p>
</attr>

<attr name='scope' value='name' default='form'>
 <p>The name of the new scope, besides \"_\".</p>
</attr>",

//----------------------------------------------------------------------

"set":#"<desc type='both'><p><short>
 Sets a variable in any scope that isn't read-only.</short>
</p>
<ex-box><set variable='var.language'>Pike</set></ex-box>
</desc>

<attr name='variable' value='string' required='required'>
 <p>The name of the variable.</p>
<ex-box><set variable='var.foo' value='bar'/></ex-box>
</attr>

<attr name='value' value='string'>
 <p>The value the variable should have.</p>
</attr>

<attr name='expr' value='string'>
 <p>An expression whose evaluated value the variable should have.</p>
</attr>

<attr name='from' value='string'>
 <p>The name of another variable that the value should be copied from.</p>
</attr>

<attr name='split' value='string'>
 <p>The value will be splitted by this string into an array.</p>

 <p>If none of the above attributes are specified, the variable is unset.
 If debug is currently on, more specific debug information is provided
 if the operation failed. See also: <xref href='append.tag' /> and <xref href='../programming/debug.tag' />.</p>
</attr> ",

//----------------------------------------------------------------------

"copy-scope":#"<desc type='tag'><p><short>
 Copies the content of one scope into another scope</short></p></desc>

<attr name='from' value='scope name' required='1'>
 <p>The name of the scope the variables are copied from.</p>
</attr>

<attr name='to' value='scope name' required='1'>
 <p>The name of the scope the variables are copied to.</p>
</attr>",

//----------------------------------------------------------------------

"set-cookie":#"<desc type='tag'><p><short>
 Sets a cookie that will be stored by the user's browser.</short> This
 is a simple and effective way of storing data that is local to the
 user. If no arguments specifying the time the cookie should survive
 is given to the tag, it will live until the end of the current browser
 session. Otherwise, the cookie will be persistent, and the next time
 the user visits  the site, she will bring the cookie with her.
</p>

<p>Note that the change of a cookie will not take effect until the
 next page load.</p></desc>

<attr name='name' value='string' required='required'>
 <p>The name of the cookie.</p>
</attr>

<attr name='seconds' value='number'>
 <p>Add this number of seconds to the time the cookie is kept.</p>
</attr>

<attr name='minutes' value='number'>
 <p>Add this number of minutes to the time the cookie is kept.</p>
</attr>

<attr name='hours' value='number'>
 <p>Add this number of hours to the time the cookie is kept.</p>
</attr>

<attr name='days' value='number'>
 <p>Add this number of days to the time the cookie is kept.</p>
</attr>

<attr name='weeks' value='number'>
 <p>Add this number of weeks to the time the cookie is kept.</p>
</attr>

<attr name='months' value='number'>
 <p>Add this number of months to the time the cookie is kept.</p>
</attr>

<attr name='years' value='number'>
 <p>Add this number of years to the time the cookie is kept.</p>
</attr>

<attr name='persistent'>
 <p>Keep the cookie for five years.</p>
</attr>

<attr name='domain'>
 <p>The domain for which the cookie is valid.</p>
</attr>

<attr name='value' value='string'>
 <p>The value the cookie will be set to.</p>
</attr>

<attr name='path' value='string' default=\"\"><p>
 The path in which the cookie should be available.</p>
</attr>
",

//----------------------------------------------------------------------

"set-max-cache":#"<desc type='tag'><p><short>
 Sets the maximum time this document can be cached in any ram
 caches.</short></p>

 <p>Default is to get this time from the other tags in the document
 (as an example, <xref href='../if/if_supports.tag' /> sets the time to
 0 seconds since the result of the test depends on the client used.</p>

 <p>You must do this at the end of the document, since many of the
 normal tags will override this value.</p>
</desc>

<attr name='years' value='number'>
 <p>Add this number of years to the time this page was last loaded.</p>
</attr>
<attr name='months' value='number'>
 <p>Add this number of months to the time this page was last loaded.</p>
</attr>
<attr name='weeks' value='number'>
 <p>Add this number of weeks to the time this page was last loaded.</p>
</attr>
<attr name='days' value='number'>
 <p>Add this number of days to the time this page was last loaded.</p>
</attr>
<attr name='hours' value='number'>
 <p>Add this number of hours to the time this page was last loaded.</p>
</attr>
<attr name='beats' value='number'>
 <p>Add this number of beats to the time this page was last loaded.</p>
</attr>
<attr name='minutes' value='number'>
 <p>Add this number of minutes to the time this page was last loaded.</p>
</attr>
<attr name='seconds' value='number'>
 <p>Add this number of seconds to the time this page was last loaded.</p>
</attr>",

//----------------------------------------------------------------------

"smallcaps":#"<desc type='cont'><p><short>
 Prints the contents in smallcaps.</short> If the size attribute is
 given, font tags will be used, otherwise big and small tags will be
 used.</p>

<ex><smallcaps>Roxen WebServer</smallcaps></ex>
</desc>

<attr name='space'>
 <p>Put a space between every character.</p>
<ex><smallcaps space=''>Roxen WebServer</smallcaps></ex>
</attr>

<attr name='class' value='string'>
 <p>Apply this cascading style sheet (CSS) style on all elements.</p>
</attr>

<attr name='smallclass' value='string'>
 <p>Apply this cascading style sheet (CSS) style on all small elements.</p>
</attr>

<attr name='bigclass' value='string'>
 <p>Apply this cascading style sheet (CSS) style on all big elements.</p>
</attr>

<attr name='size' value='number'>
 <p>Use font tags, and this number as big size.</p>
</attr>

<attr name='small' value='number' default='size-1'>
 <p>Size of the small tags. Only applies when size is specified.</p>

 <ex><smallcaps size='6' small='2'>Roxen WebServer</smallcaps></ex>
</attr>",

//----------------------------------------------------------------------

"sort":#"<desc type='cont'><p><short>
 Sorts the contents.</short></p>

 <ex><sort>Understand!
I
Wee!
Ah,</sort></ex>
</desc>

<attr name='separator' value='string'>
 <p>Defines what the strings to be sorted are separated with. The sorted
 string will be separated by the string.</p>

 <ex><sort separator='#'>way?#perhaps#this</sort></ex>
</attr>

<attr name='reverse'>
 <p>Reversed order sort.</p>

 <ex><sort reverse=''>backwards?
or
:-)
maybe</sort></ex>
</attr>",

//----------------------------------------------------------------------

"throw":#"<desc type='cont'><p><short>
 Throws a text to be caught by <xref href='catch.tag' />.</short>
 Throws an exception, with the enclosed text as the error message.
 This tag has a close relation to <xref href='catch.tag' />. The
 RXML parsing will stop at the <tag>throw</tag> tag.
 </p></desc>",

//----------------------------------------------------------------------

"trimlines":#"<desc type='cont'><p><short>
 Removes all empty lines from the contents.</short></p>

  <ex><pre><trimlines>
See how all this junk


just got zapped?

</trimlines></pre></ex>
</desc>",

//----------------------------------------------------------------------

"unset":#"<desc type='tag'><p><short>
 Unsets a variable, i.e. removes it.</short>
</p></desc>

<attr name='variable' value='string' required='required'>
 <p>The name of the variable.</p>

 <ex><set variable='var.jump' value='do it'/>
&var.jump;
<unset variable='var.jump'/>
&var.jump;</ex>
</attr>",

//----------------------------------------------------------------------

"user":#"<desc type='tag'><p><short>
 Prints information about the specified user.</short> By default, the
 full name of the user and her e-mail address will be printed, with a
 mailto link and link to the home page of that user.</p>

 <p>The <tag>user</tag> tag requires an authentication module to work.</p>
</desc>

<attr name='email'>
 <p>Only print the e-mail address of the user, with no link.</p>
 <ex-box>Email: <user name='foo' email='1'/></ex-box>
</attr>

<attr name='link'>
 <p>Include links. Only meaningful together with the realname or email attribute.</p>
</attr>

<attr name='name'>
 <p>The login name of the user. If no other attributes are specified, the
 user's realname and email including links will be inserted.</p>
<ex-box><user name='foo'/></ex-box>
</attr>

<attr name='nolink'>
 <p>Don't include the links.</p>
</attr>

<attr name='nohomepage'>
 <p>Don't include homepage links.</p>
</attr>

<attr name='realname'>
 <p>Only print the full name of the user, with no link.</p>
<ex-box><user name='foo' realname='1'/></ex-box>
</attr>",

//----------------------------------------------------------------------

"if#expr":#"<desc type='plugin'><p><short>
 This plugin evaluates a string as a pike expression.</short>
 Available arithmetic operators are +, -, *, / and % (modulo).
 Available relational operators are &lt;, &gt;, ==, !=, &lt;= and
 &gt;=. Available bitwise operators are &amp;, | and ^, representing
 AND, OR and XOR. Available boolean operators are &amp;&amp; and ||,
 working as the pike AND and OR.</p>

 <p>Numbers can be represented as decimal integers when numbers
 are written out as normal, e.g. \"42\". Numbers can also be written
 as hexadecimal numbers when precedeed with \"0x\", as octal numbers
 when precedeed with \"0\" and as binary number when precedeed with
 \"0b\". Numbers can also be represented as floating point numbers,
 e.g. \"1.45\" or \"1.6E5\". Numbers can be converted between floats
 and integers by using the cast operators \"(float)\" and \"(int)\".</p>

 <ex-box>(int)3.14</ex-box>

 <p>A common problem when dealing with variables from forms is that
 a variable might be a number or be empty. To ensure that a value is
 produced the special functions INT and FLOAT may be used. In the
 expression \"INT(&form.num;)+1\" the INT-function will produce 0 if
 the form variable is empty, hence preventing the incorrect expression
 \"+1\" to be produced.</p>
</desc>

<attr name='expr' value='expression'>
 <p>Choose what expression to test.</p>
</attr>",

//----------------------------------------------------------------------

"emit#fonts":({ #"<desc type='plugin'><p><short>
 Prints available fonts.</short> This plugin makes it easy to list all
 available fonts in Roxen WebServer.
</p></desc>

<attr name='type' value='ttf|all'>
 <p>Which font types to list. ttf means all true type fonts, whereas all
 means all available fonts.</p>
</attr>",
		([
"&_.name;":#"<desc type='entity'><p>
 Returns a font identification name.</p>

<p>This example will print all available ttf fonts in gtext-style.</p>
<ex-box><emit source='fonts' type='ttf'>
  <gtext font='&_.name;'>&_.expose;</gtext><br />
</emit></ex-box>
</desc>",
"&_.copyright;":#"<desc type='entity'><p>
 Font copyright notice. Only available for true type fonts.
</p></desc>",
"&_.expose;":#"<desc type='entity'><p>
 The preferred list name. Only available for true type fonts.
</p></desc>",
"&_.family;":#"<desc type='entity'><p>
 The font family name. Only available for true type fonts.
</p></desc>",
"&_.full;":#"<desc type='entity'><p>
 The full name of the font. Only available for true type fonts.
</p></desc>",
"&_.path;":#"<desc type='entity'><p>
 The location of the font file.
</p></desc>",
"&_.postscript;":#"<desc type='entity'><p>
 The fonts postscript identification. Only available for true type fonts.
</p></desc>",
"&_.style;":#"<desc type='entity'><p>
 Font style type. Only available for true type fonts.
</p></desc>",
"&_.format;":#"<desc type='entity'><p>
 The format of the font file, e.g. ttf.
</p></desc>",
"&_.version;":#"<desc type='entity'><p>
 The version of the font. Only available for true type fonts.
</p></desc>",
"&_.trademark;":#"<desc type='entity'><p>
 Font trademark notice. Only available for true type fonts.
</p></desc>",
		])
	     }),

//----------------------------------------------------------------------

"case":#"<desc type='cont'><p><short>
 Alters the case of the contents.</short>
</p></desc>

<attr name='case' value='upper|lower|capitalize' required='required'><p>
 Changes all characters to upper or lower case letters, or
 capitalizes the first letter in the content.</p>

<ex><case case='upper'>upper</case></ex>
<ex><case case='lower'>lower</case></ex>
<ex><case case='capitalize'>capitalize</case></ex>
</attr>",

//----------------------------------------------------------------------

"cond":({ #"<desc type='cont'><p><short>
 This tag makes a boolean test on a specified list of cases.</short>
 This tag is almost eqvivalent to the <xref href='../if/if.tag'
 />/<xref href='../if/else.tag' /> combination. The main difference is
 that the <tag>default</tag> tag may be put whereever you want it
 within the <tag>cond</tag> tag. This will of course affect the order
 the content is parsed. The <tag>case</tag> tag is required.</p>
</desc>",

	  (["case":#"<desc type='cont'><p>
 This tag takes the argument that is to be tested and if it's true,
 it's content is executed before exiting the <tag>cond</tag>. If the
 argument is false the content is skipped and the next <tag>case</tag>
 tag is parsed.</p></desc>

<ex-box><cond>
 <case variable='form.action = edit'>
  some database edit code
 </case>
 <case variable='form.action = delete'>
  some database delete code
 </case>
 <default>
  view something from the database
 </default>
</cond></ex-box>",

	    "default":#"<desc type='cont'><p>
 The <tag>default</tag> tag is eqvivalent to the <tag>else</tag> tag
 in an <tag>if</tag> statement. The difference between the two is that
 the <tag>default</tag> may be put anywhere in the <tag>cond</tag>
 statement. This affects the parseorder of the statement. If the
 <tag>default</tag> tag is put first in the statement it will allways
 be executed, then the next <tag>case</tag> tag will be executed and
 perhaps add to the result the <tag>default</tag> performed.</p></desc>"
	    ])
	  }),

//----------------------------------------------------------------------

"comment":#"<desc type='cont'><p><short>
 The enclosed text will be removed from the document.</short> The
 difference from a normal SGML (HTML/XML) comment is that the text is
 removed from the document, and can not be seen even with <i>view
 source</i> in the browser.</p>

 <p>Note that since this is a normal tag, it requires that the content
 is properly formatted. Therefore it's often better to use the
 &lt;?comment&nbsp;...&nbsp;?&gt; processing instruction tag to
 comment out arbitrary text (which doesn't contain '?&gt;').</p>

 <p>Just like any normal tag, the <tag>comment</tag> tag nests inside
 other <tag>comment</tag> tags. E.g:</p>

 <ex-box><comment> a <comment> b </comment> c </comment></ex-box>

 <p>Here 'c' is not output since the comment starter before 'a'
 matches the ender after 'c' and not the one before it.</p>
</desc>

<attr name='preparse'>
 <p>Parse and execute any RXML inside the comment tag. This can be used
 to do stuff without producing any output in the response. This is a
 compatibility argument; the recommended way is to use
 <tag>nooutput</tag> instead.</p>
</attr>",

//----------------------------------------------------------------------

"?comment":#"<desc type='pi'><p><short>
 Processing instruction tag for comments.</short> This tag is similar
 to the RXML <tag>comment</tag> tag but should be used
 when commenting arbitrary text that doesn't contain '?&gt;'.</p>

<ex-box><?comment
  This comment will not ever be shown.
?></ex-box>
</desc>",

//----------------------------------------------------------------------

"define":({ #"<desc type='cont'><p><short>
 Defines variables, tags, containers and if-callers.</short></p>
<p>The values of the attributes given to the defined tag are
 available in the scope created within the define tag.</p></desc>

<attr name='variable' value='name'><p>
 Sets the value of the variable to the contents of the container.</p>
</attr>

<attr name='tag' value='name'><p>
 Defines a tag that outputs the contents of the container.</p>

<ex><define tag=\"hi\">Hello &_.name;!</define>
<hi name=\"Martin\"/></ex>
</attr>

<attr name='container' value='name'><p>
 Defines a container that outputs the contents of the container.</p>
</attr>

<attr name='if' value='name'><p>
 Defines an if-caller that compares something with the contents of the
 container.</p>
</attr>

<attr name='trimwhites'><p>
 Trim all white space characters from the beginning and the end of the
 contents.</p>
</attr>

<attr name='preparse'><p>
 Sends the definition through the RXML parser when the
 <tag>define</tag> is executed instead of when the defined tag is
 used.</p>

 <p>Compatibility notes: If the compatibility level is 2.2 or earlier,
 the result from the RXML parse is parsed again when the defined tag
 is used, which can be a potential security problem. Also, if the
 compatibility level is 2.2 or earlier, the <tag>define</tag> tag does
 not set up a local scope during the preparse pass, which means that
 the enclosed code will still use the closest surrounding \'_\'
 scope.</p>
</attr>",

	    ([
"attrib":#"<desc type='cont'><p>
 When defining a tag or a container the tag <tag>attrib</tag>
 can be used to define default values of the attributes that the
 tag/container can have. The attrib tag must be the first tag(s)
 in the define tag.</p>
</desc>

 <attr name='name' value='name'><p>
  The name of the attribute which default value is to be set.</p>
 </attr>",

"&_.args;":#"<desc type='entity'><p>
 The full list of the attributes, and their arguments, given to the
 tag.
</p></desc>",

"&_.rest-args;":#"<desc type='entity'><p>
 A list of the attributes, and their arguments, given to the tag,
 excluding attributes with default values defined.
</p></desc>",

"&_.contents;":#"<desc type='entity'><p>
 The unevaluated contents of the container.
</p></desc>",

"contents":#"<desc type='tag'><p>
 Inserts the whole or some part of the arguments or the contents
 passed to the defined tag or container.</p>

 <p>The passed contents are RXML evaluated in the first encountered
 <tag>contents</tag>; the later ones reuses the result of that.
 (However, if it should be compatible with 2.2 or earlier then it\'s
 reevaluated each time unless there\'s a \'copy-of\' or \'value-of\'
 attribute.)</p>

 <p>Note that when the preparse attribute is used, this tag is
 converted to a special variable reference on the form
 \'<ent>_.__contents__<i>n</i></ent>\', which is then substituted with
 the real value when the defined tag is used. It\'s that way to make
 the expansion work when the preparsed code puts it in an attribute
 value. (This is mostly an internal implementation detail, but it can
 be good to know since the variable name might show up.)
</p></desc>

<attr name='scope' value='scope'><p>
 Associate this <tag>contents</tag> tag with the innermost
 <tag>define</tag> container with the given scope. The default is to
 associate it with the innermost <tag>define</tag>.</p>
</attr>

<attr name='eval'><p>
 When this attribute exists, the passed content is (re)evaluated
 unconditionally before being inserted. Normally the evaluated content
 from the preceding <tag>contents</tag> tag is reused, and it\'s only
 evaluated if this is the first encountered <tag>contents</tag>.</p>
</attr>

<attr name='copy-of' value='expression'><p>
 Selects a part of the content node tree to copy. As opposed to the
 value-of attribute, all the selected nodes are copied, with all
 markup.</p>

 <p>The expression is a simplified variant of an XPath location path:
 It consists of one or more steps delimited by \'<tt>/</tt>\'.
 Each step selects some part(s) of the current node. The first step
 operates on the defined tag or container itself, and each following
 one operates on the part(s) selected by the previous step.</p>

 <p>A step may be any of the following:</p>

 <list type=\"ul\">
   <item><p>\'<i>name</i>\' selects all elements (i.e. tags or
   containers) with the given name in the content. The name can be
   \'<tt>*</tt>\' to select all.</p></item>

   <item><p>\'<tt>@</tt><i>name</i>\' selects the element attribute
   with the given name. The name can be \'<tt>*</tt>\' to select
   all.</p></item>

   <item><p>\'<tt>comment()</tt>\' selects all comments in the
   content.</p></item>

   <item><p>\'<tt>text()</tt>\' selects all text pieces in the
   content.</p></item>

   <item><p>\'<tt>processing-instruction(<i>name</i>)</tt>\' selects
   all processing instructions with the given name in the content. The
   name may be left out to select all.</p></item>

   <item><p>\'<tt>node()</tt>\' selects all the different sorts of
   nodes in the content, i.e. the whole content.</p></item>
 </list>

 <p>A step may be followed by \'<tt>[<i>n</i>]</tt>\' to choose
 the nth item in the selected set. The index n may be negative to
 select an element in reverse order, i.e. -1 selects the last element,
 -2 the second-to-last, etc.</p>

 <p>An example: The expression \'<tt>p/*[2]/@href</tt>\' first
 selects all <tag>p</tag> elements in the content. In the content of
 each of these, the second element with any name is selected. It\'s
 not an error if some of the <tag>p</tag> elements have less than two
 child elements; those who haven\'t are simply ignored. Lastly, all
 \'href\' attributes of all those elements are selected. Again it\'s
 not an error if some of the elements lack \'href\' attributes.</p>

 <p>Note that an attribute node is both the name and the value, so in
 the example above the result might be
 \'<tt>href=\"index.html\"</tt>\' and not
 \'<tt>index.html</tt>\'. If you only want the value, use the
 value-of attribute instead.</p>
</attr>

<attr name='value-of' value='expression'><p>
 Selects a part of the content node tree and inserts its text value.
 As opposed to the copy-of attribute, only the value of the first
 selected node is inserted. The expression is the same as for the
 copy-of attribute.</p>

 <p>The text value of an element node is all the text in it and all
 its subelements, without the elements themselves or any processing
 instructions.</p>
</attr>"
	    ])

}),

//----------------------------------------------------------------------

"else":#"<desc type='cont'><p><short>

 Execute the contents if the previous <xref href='if.tag'/> tag didn't,
 or if there was a <xref href='false.tag'/> tag above.</short> This
 tag also detects if the page's truth value has been set to false, which
 occurrs whenever a runtime error is encountered. The <xref
 href='../output/emit.tag'/> tag, for one, signals this way when it did
 not loop a single time.</p>

 <p>The result is undefined if there has been no <xref href='if.tag'/>,
 <xref href='true.tag'/>, <xref href='false.tag' /> or other tag that
 touches the page's truth value earlier in the page.</p>

 <note><p>This tag is cache static (see the <tag>cache</tag> tag)
 if the compatibility level is set to 2.5 or higher.</p></note>
</desc>",

//----------------------------------------------------------------------

"elseif":#"<desc type='cont'><p><short>
 Same as the <xref href='if.tag' />, but it will only evaluate if the
 previous <tag>if</tag> returned false.</short></p>

 <note><p>This tag is cache static (see the <tag>cache</tag> tag)
 if the compatibility level is set to 2.5 or higher.</p></note>
</desc>",

//----------------------------------------------------------------------

"false":#"<desc type='tag'><p><short>
 Internal tag used to set the return value of <xref href='../if/'
 />.</short> It will ensure that the next <xref href='else.tag' /> tag
 will show its contents. It can be useful if you are writing your own
 <xref href='if.tag' /> lookalike tag. </p>
</desc>",

//----------------------------------------------------------------------

"help":#"<desc type='tag'><p><short>
 Gives help texts for tags.</short> If given no arguments, it will
 list all available tags. By inserting <tag>help/</tag> in a page, a
 full index of the tags available in that particular Roxen WebServer
 will be presented. If a particular tag is missing from that index, it
 is not available at that moment. Since all tags are available through
 modules, that particular tag's module hasn't been added to the
 Roxen WebServer yet. Ask an administrator to add the module.
</p>
</desc>

<attr name='for' value='tag'><p>
 Gives the help text for that tag.</p>
<ex><help for='roxen'/></ex>
</attr>",

//----------------------------------------------------------------------

"if":#"<desc type='cont'><p><short>
 The <tag>if</tag> tag is used to conditionally include its
 contents.</short> <xref href='else.tag'/> or <xref
 href='elseif.tag'/> can be used afterwards to include alternative
 content if the test is false.</p>

 <p>The tag itself is useless without its plugins. Its main
 functionality is to provide a framework for the plugins. It is
 mandatory to add a plugin as one attribute. The other attributes
 provided are and, or and not, used for combining different plugins
 with logical operations.</p>

 <p>Note: Since XML mandates that tag attributes must be unique, it's
 not possible to use the same plugin more than once with a logical
 operator. E.g. this will not work:</p>

 <ex-box><if variable='var.x' and='' variable='var.y'>
   This does not work.
 </if></ex-box>

 <p>You have to use more than one tag in such cases. The example above
 can be rewritten like this to work:</p>

 <ex-box><if variable='var.x'>
   <if variable='var.y'>
     This works.
   </if>
 </if></ex-box>

 <p>The If plugins are sorted according to their function into five
 categories: Eval, Match, State, Utils and SiteBuilder.</p>

 <h1>Eval plugins</h1>

 <p>The Eval category is the one corresponding to the regular tests made
 in programming languages, and perhaps the most used. They evaluate
 expressions containing variables, entities, strings etc and are a sort
 of multi-use plugins.</p>

 <ex-box><if variable='var.foo > 0' and='' match='var.bar is No'>
    ...
  </if></ex-box>

 <ex-box><if variable='var.foo > 0' not=''>
  &var.foo; is less than 0
</if><else>
  &var.foo; is greater than 0
</else></ex-box>

 <p>The tests are made up either of a single operand or two operands
 separated by an operator surrounded by single spaces. The value of
 the single or left hand operand is determined by the If plugin.</p>

 <p>If there is only a single operand then the test is successful if
 it has a value different from the integer 0. I.e. all string values,
 including the empty string \"\" and the string \"0\", make the test
 succeed.</p>

 <p>If there is an operator then the right hand is treated as a
 literal value (with some exceptions described below). Valid operators
 are \"=\", \"==\", \"is\", \"!=\", \"&lt;\" and \"&gt;\".</p>

 <ex><set variable='var.x' value='6'/>
<if variable='var.x > 5'>More than one hand</if></ex>

 <p>The three operators \"=\", \"==\" and \"is\" all test for
 equality. They can furthermore do pattern matching with the right
 operand. If it doesn't match the left one directly then it's
 interpreted as a glob pattern with \"*\" and \"?\". If it still
 doesn't match then it's splitted on \",\" and each part is tried as a
 glob pattern to see if any one matches.</p>

 <p>In a glob pattern, \"*\" means match zero or more arbitrary
 characters, and \"?\" means match exactly one arbitrary character.
 Thus \"t*f??\" will match \"trainfoo\" as well as \"tfoo\" but not
 \"trainfork\" or \"tfo\". It is not possible to use regexps together
 with any of the if-plugins.</p>

 <ex><set variable='var.name' value='Sesame'/>
<if variable='var.name is e*,*e'>\"&var.name;\" begins or ends with an 'e'.</if></ex>

 <h1>Match plugins</h1>

 <p>The Match category contains plugins that match contents of
 something, e.g. an IP package header, with arguments given to the
 plugin as a string or a list of strings.</p>

 <ex>Your domain <if ip='130.236.*'> is </if>
<else> isn't </else> liu.se.</ex>

 <h1>State plugins</h1>

 <p>State plugins check which of the possible states something is in,
 e.g. if a flag is set or not, if something is supported or not, if
 something is defined or not etc.</p>

 <ex>
   Your browser
  <if supports='javascript'>
   supports Javascript version &client.javascript;
  </if>
  <else>doesn't support Javascript</else>.
 </ex>

 <h1>Utils plugins</h1>

 <p>Utils are additonal plugins specialized for certain tests, e.g.
 date and time tests.</p>

 <ex-box>
  <if time='1700' after=''>
    Are you still at work?
  </if>
  <elseif time='0900' before=''>
     Wow, you work early!
  </elseif>
  <else>
   Somewhere between 9 to 5.
  </else>
 </ex-box>

 <h1>SiteBuilder plugins</h1>

 <p>SiteBuilder plugins requires a Roxen Platform SiteBuilder
 installed to work. They are adding test capabilities to web pages
 contained in a SiteBuilder administrated site.</p>

 <note><p>This tag is cache static (see the <tag>cache</tag> tag)
 if the compatibility level is set to 2.5 or higher.</p></note>
</desc>

<attr name='not'><p>
 Inverts the result (true-&gt;false, false-&gt;true).</p>
</attr>

<attr name='or'><p>
 If any criterion is met the result is true.</p>
</attr>

<attr name='and'><p>
 If all criterions are met the result is true. And is default.</p>
</attr>",

//----------------------------------------------------------------------

"if#true":#"<desc type='plugin'><p><short>
 This will always be true if the truth value is set to be
 true.</short> Equivalent with <xref href='then.tag' />.
 This is a <i>State</i> plugin.
</p></desc>

<attr name='true' required='required'><p>
 Show contents if truth value is false.</p>
</attr>",

//----------------------------------------------------------------------

"if#false":#"<desc type='plugin'><p><short>
 This will always be true if the truth value is set to be
 false.</short> Equivalent with <xref href='else.tag' />.
 This is a <i>State</i> plugin.</p>
</desc>

<attr name='false' required='required'><p>
 Show contents if truth value is true.</p>
</attr>",

//----------------------------------------------------------------------

"if#module":#"<desc type='plugin'><p><short>
 Returns true if the selected module is enabled in the current
 server.</short> This is useful when you are developing RXML applications
 that you plan to move to other servers, to ensure that all required
 modules are added. This is a <i>State</i> plugin.</p>
</desc>

<attr name='module' value='name'><p>
 The \"real\" name of the module to look for, i.e. its filename
 without extension and without directory path.</p>
</attr>",

//----------------------------------------------------------------------

"if#accept":#"<desc type='plugin'><p><short>
 Returns true if the browser accepts certain content types as specified
 by it's Accept-header, for example image/jpeg or text/html.</short> If
 browser states that it accepts */* that is not taken in to account as
 this is always untrue. This is a <i>Match</i> plugin.
</p></desc>

<attr name='accept' value='type1[,type2,...]' required='required'>
</attr>",

//----------------------------------------------------------------------

"if#config":#"<desc type='plugin'><p><short>
 Has the config been set by use of the <xref href='../protocol/aconf.tag'
 /> tag?</short> This is a <i>State</i> plugin.</p>
</desc>

<attr name='config' value='name' required='required'>
</attr>",

//----------------------------------------------------------------------

"if#cookie":#"<desc type='plugin'><p><short>
 Does the cookie exist and if a value is given, does it contain that
 value?</short> This is an <i>Eval</i> plugin.
</p></desc>
<attr name='cookie' value='name[ is value]' required='required'>
</attr>",

//----------------------------------------------------------------------

"if#client":#"<desc type='plugin'><p><short>
 Compares the user agent string with a pattern.</short> This is a
 <i>Match</i> plugin.
</p></desc>
<attr name='client' value='' required='required'>
</attr>",

//----------------------------------------------------------------------

"if#date":#"<desc type='plugin'><p><short>
 Is the date yyyymmdd?</short> The attributes before, after and
 inclusive modifies the behavior. This is a <i>Utils</i> plugin.
</p></desc>
<attr name='date' value='yyyymmdd | yyyy-mm-dd' required='required'><p>
 Choose what date to test.</p>
</attr>

<attr name='after'><p>
 The date after todays date.</p>
</attr>

<attr name='before'><p>
 The date before todays date.</p>
</attr>

<attr name='inclusive'><p>
 Adds todays date to after and before.</p>

 <ex>
  <if date='19991231' before='' inclusive=''>
     - 19991231
  </if>
  <else>
    20000101 -
  </else>
 </ex>
</attr>",

//----------------------------------------------------------------------

"if#defined":#"<desc type='plugin'><p><short>
 Tests if a certain RXML define is defined by use of the <xref
 href='../variable/define.tag' /> tag, and in that case tests its
 value.</short> This is an <i>Eval</i> plugin. </p>
</desc>

<attr name='defined' value='define' required='required'><p>
 Choose what define to test.</p>
</attr>",

//----------------------------------------------------------------------

"if#domain":#"<desc type='plugin'><p><short>
 Does the user's computer's DNS name match any of the
 patterns?</short> Note that domain names are resolved asynchronously,
 and that the first time someone accesses a page, the domain name will
 probably not have been resolved. This is a <i>Match</i> plugin.
</p></desc>

<attr name='domain' value='pattern1[,pattern2,...]' required='required'><p>
 Choose what pattern to test.</p>
</attr>
",

//----------------------------------------------------------------------

// If eval is deprecated. This information is to be put in a special
// 'deprecated' chapter in the manual, due to many persons asking
// about its whereabouts.

"if#eval":#"<desc type='plugin'><p><short>
 Deprecated due to non-XML compliancy.</short> The XML standard says
 that attribute-values are not allowed to contain any markup. The
 <tag>if eval</tag> tag was deprecated in Roxen 2.0.</p>

<ex-box><!-- If eval statement -->
<if eval=\"<foo>\">x</if>

<!-- Compatible statement -->
<define variable=\"var.foo\" preparse=\"preparse\"><foo/></define>
<if sizeof=\"var.foo\">x</if></ex-box>

 <p>A similar but more XML compliant construct is a combination of
 <tag>set variable</tag> and an apropriate <tag>if</tag> plugin.
</p></desc>",

"if#exists":#"<desc type='plugin'><p><short>
 Returns true if the named page is viewable.</short> A nonviewable page
 is e.g. a file that matches the internal files patterns in the filesystem module.
 If the path does not begin with /, it is assumed to be a URL relative to the directory
 containing the page with the <tag>if</tag>-statement. 'Magic' files like /internal-roxen-unit
 will evaluate as true. This is a <i>State</i> plugin.</p>
</desc>

<attr name='exists' value='path' required='1'>
 <p>Choose what path in the virtual filesystem to test.</p>
</attr>
",

"if#internal-exists":#"<desc type='plugin'><p><short>
 Returns true if the named page exists.</short> If the page at the given path
 is nonviewable, e.g. matches the internal files patterns in the filesystem module,
 it will still be detected by this if plugin. If the path does not begin with /, it
 is assumed to be a URL relative to the directory containing the page with the if statement.
 'Magic' files like /internal-roxen-unit will evaluate as true.
 This is a <i>State</i> plugin.</p></desc>

<attr name='internal-exists' value='path' required='1'>
 <p>Choose what path in the virtual filesystem to test.</p>
</attr>",

//----------------------------------------------------------------------

"if#group":#"<desc type='plugin'><p><short>
 Checks if the current user is a member of the group according
 the groupfile.</short> This is a <i>Utils</i> plugin.
</p></desc>
<attr name='group' value='name' required='required'><p>
 Choose what group to test.</p>
</attr>

<attr name='groupfile' value='path' required='required'><p>
 Specify where the groupfile is located.</p>
</attr>",

//----------------------------------------------------------------------

"if#ip":#"<desc type='plugin'><p><short>
 Does the users computers IP address match any of the
 patterns?</short> This plugin replaces the Host plugin of earlier
 RXML versions. This is a <i>Match</i> plugin.
</p></desc>
<attr name='ip' value='pattern1[,pattern2,...]' required='required'><p>
 Choose what IP-adress pattern to test.</p>
</attr>
",

//----------------------------------------------------------------------

"if#language":#"<desc type='plugin'><p><short>
 Does the client prefer one of the languages listed, as specified by the
 Accept-Language header?</short> This is a <i>Match</i> plugin.
</p></desc>

<attr name='language' value='language1[,language2,...]' required='required'><p>
 Choose what language to test.</p>
</attr>
",

//----------------------------------------------------------------------

"if#match":#"<desc type='plugin'><p><short>
 Evaluates patterns.</short> More information can be found in the
 <xref href='../../tutorial/if_tags/plugins.xml'>If tags
 tutorial</xref>. Match is an <i>Eval</i> plugin.</p></desc>

<attr name='match' value='pattern' required='required'><p>
 Choose what pattern to test. The pattern could be any expression.
 Note!: The pattern content is treated as strings:</p>

<ex>
 <set variable='var.hepp' value='10' />

 <if match='var.hepp is 10'>
  true
 </if>
 <else>
  false
 </else>
</ex>

 <p>This example shows how the plugin treats \"var.hepp\" and \"10\"
 as strings. Hence when evaluating a variable as part of the pattern,
 the entity associated with the variable should be used, i.e.
 <ent>var.hepp</ent> instead of var.hepp. A correct example would be:</p>

<ex>
<set variable='var.hepp' value='10' />

 <if match='&var.hepp; is 10'>
  true
 </if>
 <else>
  false
 </else>
</ex>

 <p>Here, &var.hepp; is treated as an entity and parsed
 correctly, letting the plugin test the contents of the entity.</p>
</attr>
",

//----------------------------------------------------------------------

"if#Match":#"<desc type='plugin'><p><short>
 Case sensitive version of the <tag>if match</tag> plugin.</short></p>
</desc>",

//----------------------------------------------------------------------

"if#pragma":#"<desc type='plugin'><p><short>
 Compares the HTTP header pragma with a string.</short> This is a
 <i>State</i> plugin.
</p></desc>

<attr name='pragma' value='string' required='required'><p>
 Choose what pragma to test.</p>

<ex>
 <if pragma='no-cache'>The page has been reloaded!</if>
 <else>Reload this page!</else>
</ex>
</attr>
",

//----------------------------------------------------------------------

"if#prestate":#"<desc type='plugin'><p><short>
 Are all of the specified prestate options present in the URL?</short>
 This is a <i>State</i> plugin.
</p></desc>
<attr name='prestate' value='option1[,option2,...]' required='required'><p>
 Choose what prestate to test.</p>
</attr>
",

//----------------------------------------------------------------------

"if#referrer":#"<desc type='plugin'><p><short>
 Does the referrer header match any of the patterns?</short> This
 is a <i>Match</i> plugin.
</p></desc>
<attr name='referrer' value='pattern1[,pattern2,...]' required='required'><p>
 Choose what pattern to test.</p>
</attr>
",

//----------------------------------------------------------------------

// The list of support flags is extracted from the supports database and
// concatenated to this entry.
"if#supports":#"<desc type='plugin'><p><short>
 Does the browser support this feature?</short> This is a
 <i>State</i> plugin.
</p></desc>

<attr name='supports' value='feature' required='required'>
 <p>Choose what supports feature to test.</p>
</attr>

<p>The following features are supported:</p> <supports-flags-list/>",

//----------------------------------------------------------------------

"if#time":#"<desc type='plugin'><p><short>
 Is the time hhmm, hh:mm, yyyy-mm-dd or yyyy-mm-ddThh:mm?</short> The attributes before, after,
 inclusive and until modifies the behavior. This is a <i>Utils</i> plugin.
</p></desc>
<attr name='time' value='hhmm|yyyy-mm-dd|yyyy-mm-ddThh:mm' required='required'><p>
 Choose what time to test.</p>
</attr>

<attr name='after'><p>
 The time after present time.</p>
</attr>

<attr name='before'><p>
 The time before present time.</p>
</attr>

<attr name='until' value='hhmm|yyyy-mm-dd|yyyy-mm-ddThh:mm'><p>
 Gives true for the time range between present time and the time value of 'until'.</p>
</attr>

<attr name='inclusive'><p>
 Adds present time to after and before.</p>

<ex-box>
  <if time='1200' before='' inclusive=''>
    ante meridiem
  </if>
  <else>
    post meridiem
  </else>
</ex-box>
</attr>",

//----------------------------------------------------------------------

"if#user":#"<desc type='plugin'><p><short>
 Has the user been authenticated as one of these users?</short> If any
 is given as argument, any authenticated user will do. This is a
 <i>Utils</i> plugin.
</p></desc>

<attr name='user' value='name1[,name2,...]|any' required='required'><p>
 Specify which users to test.</p>
</attr>
",

//----------------------------------------------------------------------

"if#variable":#"<desc type='plugin'><p><short>
 Does the variable exist and, optionally, does its content match the
 pattern?</short> This is an <i>Eval</i> plugin.
</p></desc>

<attr name='variable' value='name[ operator pattern]' required='required'><p>
 Choose variable to test. Valid operators are '=', '==', 'is', '!=',
 '&lt;' and '&gt;'.</p>
</attr>",

//----------------------------------------------------------------------

"if#Variable":#"<desc type='plugin'><p><short>
 Case sensitive version of the <tag>if variable</tag> plugin.</short></p>
</desc>",

//----------------------------------------------------------------------

// The list of support flags is extracted from the supports database and
// concatenated to this entry.
"if#clientvar":#"<desc type='plugin'><p><short>
 Evaluates expressions with client specific values.</short> This
 is an <i>Eval</i> plugin.
</p></desc>

<attr name='clientvar' value='variable [is value]' required='required'><p>
 Choose which variable to evaluate against. Valid operators are '=',
 '==', 'is', '!=', '&lt;' and '&gt;'.</p>
</attr>",
// <p>Available variables are:</p>

//----------------------------------------------------------------------

"if#sizeof":#"<desc type='plugin'><p><short>
 Compares the size of a variable with a number.</short>
 This is an <i>Eval</i> plugin.</p>

<ex>
<set variable=\"var.x\" value=\"hello\"/>
<set variable=\"var.y\" value=\"\"/>
<if sizeof=\"var.x == 5\">Five</if>
<if sizeof=\"var.y > 0\">Nonempty</if>
</ex>
</desc>",

//----------------------------------------------------------------------

"nooutput":#"<desc type='cont'><p><short>
 The contents will not be sent through to the page.</short> Side
 effects, for example sending queries to databases, will take effect.
</p></desc>",

//----------------------------------------------------------------------

"noparse":#"<desc type='cont'><p><short>
 The contents of this container tag won't be RXML parsed.</short>
</p></desc>",

//----------------------------------------------------------------------

"?noparse": #"<desc type='pi'><p><short>
 The content is inserted as-is, without any parsing or
 quoting.</short> The first whitespace character (i.e. the one
 directly after the \"noparse\" name) is discarded.</p>
</desc>",

//----------------------------------------------------------------------

"?cdata": #"<desc type='pi'><p><short>
 The content is inserted as a literal.</short> I.e. any XML markup
 characters are encoded with character references. The first
 whitespace character (i.e. the one directly after the \"cdata\" name)
 is discarded.</p>

 <p>This processing instruction is just like the &lt;![CDATA[ ]]&gt;
 directive but parsed by the RXML parser, which can be useful to
 satisfy browsers that does not handle &lt;![CDATA[ ]]&gt; correctly.</p>
</desc>",

//----------------------------------------------------------------------

"number":#"<desc type='tag'><p><short>
 Prints a number as a word.</short>
</p></desc>

<attr name='num' value='number' required='required'><p>
 Print this number.</p>
<ex><number num='4711'/></ex>
</attr>

<attr name='language' value='langcodes'><p>
 The language to use.</p>
 <p><lang/></p>
 <ex>Mitt favoritnummer �r <number num='11' language='sv'/>.</ex>
 <ex>Il mio numero preferito � <number num='15' language='it'/>.</ex>
</attr>

<attr name='type' value='number|ordered|roman|memory' default='number'><p>
 Sets output format.</p>

 <ex>It was his <number num='15' type='ordered'/> birthday yesterday.</ex>
 <ex>Only <number num='274589226' type='memory'/> left on the Internet.</ex>
 <ex>Spock Garfield <number num='17' type='roman'/> rests here.</ex>
</attr>",

//----------------------------------------------------------------------

"strlen":#"<desc type='cont'><p><short>
 Returns the length of the contents.</short></p>

 <ex>There are <strlen>foo bar gazonk</strlen> characters
 inside the tag.</ex>
</desc>",

//----------------------------------------------------------------------

"elements": #"<desc type='tag'><p><short>
 Returns the number of elements in a variable.</short> If the variable
 isn't of a type which contains several elements (includes strings), 1
 is returned. That makes it consistent with variable indexing, e.g.
 var.foo.1 takes the first element in var.foo if it's an array, and if
 it isn't then it's the same as var.foo.</p></desc>

<attr name='variable' value='string'>
 <p>The name of the variable.</p>
</attr>

<attr name='scope' value='string'>
 <p>The name of the scope, unless given in the variable attribute.</p>
</attr>",

//----------------------------------------------------------------------

"then":#"<desc type='cont'><p><short>
 Shows its content if the truth value is true.</short> This is useful in
 conjunction with tags that leave status data there, such as the <xref
 href='../output/emit.tag'/> or <xref href='../programming/crypt.tag'/>
 tags.</p>

 <note><p>This tag is cache static (see the <tag>cache</tag> tag)
 if the compatibility level is set to 2.5 or higher.</p></note>
</desc>",

//----------------------------------------------------------------------

"trace":#"<desc type='cont'><p><short>
 Executes the contained RXML code and makes a trace report about how
 the contents are parsed by the RXML parser.</short>
</p></desc>",

//----------------------------------------------------------------------

"true":#"<desc type='tag'><p><short>
 An internal tag used to set the return value of <xref href='../if/'
 />.</short> It will ensure that the next <xref href='else.tag'
 /> tag will not show its contents. It can be useful if you are
 writing your own <xref href='if.tag' /> lookalike tag.</p>
</desc>",

//----------------------------------------------------------------------

"undefine":#"<desc type='tag'><p><short>
 Removes a definition made by the define container.</short> One
 attribute is required.
</p></desc>

<attr name='variable' value='name'><p>
 Undefines this variable.</p>

 <ex>
  <define variable='var.hepp'>hopp</define>
  &var.hepp;
  <undefine variable='var.hepp'/>
  &var.hepp;
 </ex>
</attr>

<attr name='tag' value='name'><p>
 Undefines this tag.</p>
</attr>

<attr name='container' value='name'><p>
 Undefines this container.</p>
</attr>

<attr name='if' value='name'><p>
 Undefines this if-plugin.</p>
</attr>",

//----------------------------------------------------------------------

"use":#"<desc type='cont'><p><short>
 Reads <i>tag definitions</i>, user defined <i>if plugins</i> and 
 <i>variables</i> from a file or package and includes into the 
 current page.</short></p>
 <note>The file itself is not inserted into the page. This only 
 affects the environment in which the page is parsed. The benefit is 
 that the package file needs only be parsed once, and the compiled 
 versions of the user defined tags can then be used, thus saving time. 
 It is also a fairly good way of creating templates for your website. 
 Just define your own tags for constructions that appears frequently 
 and save both space and time. Since the tag definitions are cached 
 in memory, make sure that the file is not dependent on anything dynamic, 
 such as form variables or client settings, at the compile time. Also 
 note that the use tag only lets you define variables in the form 
 and var scope in advance. Variables with the same name will be 
 overwritten when the use tag is parsed.</note>
</desc>

<attr name='packageinfo'><p>
 Show a list of all available packages.</p>
</attr>

<attr name='package' value='name'><p>
 Reads all tags, container tags and defines from the given package.
 Packages are files located by default in <i>../rxml_packages/</i>.</p>
</attr>

<attr name='file' value='path'><p>
 Reads all tags and container tags and defines from the file.</p>

 <p>This file will be fetched just as if someone had tried to fetch it
 with an HTTP request. This makes it possible to use Pike script
 results and other dynamic documents. Note, however, that the results
 of the parsing are heavily cached for performance reasons. If you do
 not want this cache, use <tag>insert file='...'
 nocache='1'</tag> instead.</p>
</attr>

<attr name='info'><p>
 Show a list of all defined tags/containers and if arguments in the
 file.</p>
</attr>",

//----------------------------------------------------------------------

"eval":#"<desc type='cont'><p><short>
 Postparses its content.</short> Useful when an entity contains
 RXML-code. <tag>eval</tag> is then placed around the entity to get
 its content parsed.</p>
</desc>",

//----------------------------------------------------------------------

"emit#path":({ #"<desc type='plugin'><p><short>
 Prints paths.</short> This plugin traverses over all directories in
 the path from the root up to the current one.</p>
</desc>

<attr name='path' value='string'><p>
   Use this path instead of the document path</p>
</attr>

<attr name='trim' value='string'><p>
 Removes all of the remaining path after and including the specified
 string.</p>
</attr>

<attr name='skip' value='number'><p>
 Skips the 'number' of slashes ('/') specified, with beginning from
 the root.</p>
</attr>

<attr name='skip-end' value='number'><p>
 Skips the 'number' of slashes ('/') specified, with beginning from
 the end.</p>
</attr>",
	       ([
"&_.name;":#"<desc type='entity'><p>
 Returns the name of the most recently traversed directory.</p>
</desc>",

"&_.path;":#"<desc type='entity'><p>
 Returns the path to the most recently traversed directory.</p>
</desc>"
	       ])
}),

//----------------------------------------------------------------------

"emit#sources":({ #"<desc type='plugin'><p><short>
 Provides a list of all available emit sources.</short>
</p></desc>",
  ([ "&_.source;":#"<desc type='entity'><p>
  The name of the source.</p></desc>" ]) }),

//----------------------------------------------------------------------

"emit#values":({ #"<desc type='plugin'><p><short>
 Splits the string provided in the values attribute and outputs the
 parts in a loop.</short> The value in the values attribute may also
 be an array or mapping.
</p></desc>

<attr name='values' value='string, mapping or array'><p>
 An array, mapping or a string to be splitted into an array. This
 attribute is required unless the variable attribute is used.</p>
</attr>

<attr name='variable' value='name'><p>Name of a variable from which the
 values are taken.</p>
</attr>

<attr name='split' value='string' default='NULL'><p>
 The string the values string is splitted with. Supplying an empty string
 results in the string being split between every single character.</p>
</attr>

<attr name='advanced' value='lines|words|chars'><p>
 If the input is a string it can be splitted into separate lines, words
 or characters by using this attribute.</p>
</attr>

<attr name='case' value='upper|lower'><p>
 Changes the case of the value.</p>
</attr>

<attr name='trimwhites'><p>
 Trims away all leading and trailing white space charachters from the
 values.</p>
</attr>

<attr name='from-scope' value='name'>
 <p>Create a mapping out of a scope and give it as indata to the emit.</p>
</attr>
",

([
"&_.value;":#"<desc type='entity'><p>
 The value of one part of the splitted string</p>
</desc>",

"&_.index;":#"<desc type='entity'><p>
 The index of this mapping entry, if input was a mapping</p>
</desc>"
])
	      }),

//----------------------------------------------------------------------

"emit":({ #"<desc type='cont'><p><short hide='hide'>

 Provides data, fetched from different sources, as entities. </short>

 <tag>emit</tag> is a generic tag used to fetch data from a
 provided source, loop over it and assign it to RXML variables
 accessible through entities.</p>

 <p>Occasionally an <tag>emit</tag> operation fails to produce output.
 This might happen when <tag>emit</tag> can't find any matches or if
 the developer has made an error. When this happens the truth value of
 that page is set to <i>false</i>. By using <xref
 href='../if/else.tag' /> afterwards it's possible to detect when an
 <tag>emit</tag> operation fails.</p>

 <note><p>This tag is cache static (see the <tag>cache</tag> tag)
 if the compatibility level is set to 2.5 or higher.</p></note>
</desc>

<attr name='source' value='plugin' required='required'><p>
 The source from which the data should be fetched.</p>
</attr>

<attr name='scope' value='name' default='The emit source'><p>
 The name of the scope within the emit tag.</p>
</attr>

<attr name='maxrows' value='number'><p>
 Limits the number of rows to this maximum. Note that it is
 often better to restrict the number of rows emitted by
 modifying the arguments to the emit plugin, if possible.
 E.g. when quering a MySQL database the data can be restricted
 to the first 100 entries by adding \"LIMIT 100\".</p>
</attr>

<attr name='skiprows' value='number'><p>
 Makes it possible to skip the first rows of the result. Negative
 numbers means to skip everything execept the last n rows. Note
 that it is often better to make the plugin skip initial rows,
 if possible.</p>
</attr>

<attr name='rowinfo' value='variable'><p>
 The number of rows in the result, after it has been filtered and
 limited by maxrows and skiprows, will be put in this variable,
 if given. Note that this may not be the same value as the number
 of emit iterations that the emit tag will perform, since it will
 always make one iteration when the attribute do-once is set.</p>
</attr>

<attr name='remainderinfo' value='variable'><p>
 The number of rows left to output, when the emit is restricted
 by the maxrows attribute. Rows excluded by other means such as
 skiprows or filter are not included in hte remainderinfo value.
 The rows counted in the remainderinfo are also filtered if the
 filter attribute is used, so the value represents the actual
 number of rows that should have been outputed, had emit not
 been restriced.</p>
</attr>

<attr name='do-once'><p>
 Indicate that at least one loop should be made. All variables in the
 emit scope will be empty, except for the counter variable.</p>
</attr>

<attr name='filter' value='list'><p>
 The filter attribute is used to block certain 'rows' from the
 source from being emitted. The filter attribute should be set
 to a list with variable names in the emitted scope and glob patterns
 the variable value must match in order to not get filtered.
 A list might look like <tt>name=a*,id=??3?45</tt>. Note that
 it is often better to perform the filtering in the plugin, by
 modifying its arguments, if possible. E.g. when querying an SQL
 database the use of where statements is recommended, e.g.
 \"WHERE name LIKE 'a%' AND id LIKE '__3_45'\" will perform the
 same filtering as above.</p>

<ex><emit source='values' values='foo,bar,baz' split=',' filter='value=b*'>
&_.value;
</emit></ex>
</attr>

<attr name='sort' value='list'><p>
  The emit result can be sorted by the emit tag before being output.
  Just list the variable names in the scope that the result should
  be sorted on, in prioritized order, e.g. \"lastname,firstname\".
  By adding a \"-\" sign in front of a name, that entry will be
  sorted in the reversed order.</p>

  <p>The sort algorithm will treat numbers as complete numbers and not
  digits in a string, hence \"foo8bar\" will be sorted before
  \"foo11bar\". If a variable name is prefixed by \"*\", then a
  stricter sort algorithm is used which will compare fields containing
  floats and integers numerically and all other values as strings,
  without trying to detecting numbers etc inside them.</p>

  <p>Compatibility notes: In 2.1 compatibility mode the default sort
  algorithm is the stricter one. In 2.2 compatibility mode the \"*\"
  flag is disabled.</p>
</attr>",

	  ([

"&_.counter;":#"<desc type='entity'><p>
 Gives the current number of loops inside the <tag>emit</tag> tag.
</p>
</desc>"

	  ])
       }),

//----------------------------------------------------------------------

    ]);
#endif
