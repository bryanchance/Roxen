inherit "wizard";
constant action = "debug_info";

constant name = "Pike module list";
constant name_svenska = "Pikemodullista";

constant doc =
"show information about which features and modules are "
"available in the pike this roxen is using";
constant doc_svenska =
"Visa information om vilka features och moduler som �r tillg�ngliga "
"i den pike som den h�r roxenservern anv�nder";

mapping(string:int) modules = ([]);

void find_modules()
{
  object m = master();

  modules = ([]);

  if(!_static_modules["Regexp"])
    modules["dynamic_modules"] = 1;
  else
    modules["dynamic_modules"] = -1;

#if efun(thread_create)
  modules["threads"] = 1;
#else
  modules["threads"] = -1;
#endif /* thread_create */

  foreach(m->pike_module_path, string p)
  {
    array files;
    catch { files = get_dir(p); };
    if (files) {
      foreach(glob("*.so", files), string f) {
	string s = (f/".so")[0];

	catch {
	  mixed val = m->resolv(s);
	  if (objectp(val)) {
	    if (sizeof(indices(val))) {
	      modules[s] = 1;
	    } else {
	      modules[s] = -1;
	    }
	  } else if (val) {
	    modules[s] = 1;
	  }
	};
      }
      foreach(glob("*.pmod", files), string f) {
	string s = (f/".pmod")[0];

	if (!modules[s]) {
	  catch {
	    mixed val = m->resolv(s);
	    if (objectp(val)) {
	      if (sizeof(indices(val))) {
		modules[s] = 1;
	      } else {
		modules[s] = -1;
	      }
	    } else if (val) {
	      modules[s] = 1;
	    }
	  };
	}
      }
    }
  }
  // These modules only add efuns.
  foreach(({ "call_out", "math", "sprintf", "system" }), string s)
    if (modules[s])
      modules[s] = 1;
}

mixed page_0(object id, object mc)
{
  if (!sizeof(modules)) {
    find_modules();
  }
  string res = "<font size=+1>&locale.features;</font>"+
         "<ul>\n";
  foreach(({ "dynamic_modules", "threads",
             "_Crypto",
             "CommonLog",
	     "Gmp", "Gz",
             "MIME",
             "_Image_TTF", "_Image_JPEG",
	     "Msql", "Mysql", "Odbc", "Oracle", "Postgres",
             "Yp" }), string s) {
    if (modules[s] == 1) {
      res += " "+fix_module_name(s);
    }
  }
  res += "</ul><br>\n";
  array disabled = sort(filter(indices(modules),
			       lambda(string s, mapping m) {
				 return(m[s] != 1);
			       }, modules));
  if (sizeof(disabled)) {
    res += "<font size=+1>&locale.module_disabled;</font>"+
        "<ul>\n";
    res += disabled * " ";
    res += "</ul><br>\n";
  }
  return(res);
}

string fix_module_name( string what )
{
  switch( what )
  {
   case "Gmp":
     return "bignums";
   case "_Charset":
     return "Locale.Charset";
  }

  if( sscanf( what, "_Image_%s", what ) )
    return "Image."+what;
  return what;
}

mapping has;
int no_double_(string what )
{
  if(what == "") return 0;
  has[what]++;
  if( what[0] == '_' && has[what[1..]] )
    return 0;
  return (what[0] != what[1]) || what[0] != '_';
}

mixed page_1(object id, object mc)
{
  if (!sizeof(modules))
    find_modules();
  has = ([]);
  mapping trans = mkmapping(map(indices(modules),fix_module_name),
                            indices(modules));

  return("<font size=+1>&locale.all_modules;</font><ul>\n"
         "<table cellpadding=2 cellspacing=0 border=0>"
         "<tr><td><b>&locale.name;</b></td>"
         "<td><b>&locale.state;</b></td>"
         +map(filter(sort(indices(trans)),no_double_),
             lambda(string s, mapping r) {
               return
                 "<tr><td>"+s+"</td><td>"+
                 ({"&locale.disabled;",
                   "&locale.na;",
                   "&locale.enabled;" })[ r[trans[s]] + 1]+
                 "</td></tr>\n";
             }, modules)*"")+"</table>";
}

mixed parse(object id)
{
  return page_0(id,0)+page_1(id,0);
}
