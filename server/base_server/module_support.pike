// string cvs_version = "$Id: module_support.pike,v 1.25 1999/09/05 01:36:00 per Exp $";
#include <roxen.h>
#include <module.h>

/* Set later on to something better in roxen.pike::main() */
mapping (string:array) variables=([]); 

string get_doc_for( string region, string variable )
{
  if(variables[ variable ])
    return variables[variable][VAR_NAME]+
      "\n"+variables[ variable ][ VAR_DOC_STR ];
}

/* Variable support for the main Roxen "module". Normally this is
 * inherited from module.pike, but this is not possible, or wanted, in
 * this case.  Instead we define a few support functions.
 */

int setvars( mapping (string:mixed) vars )
{
  string v;
//  perror("Setvars: %O\n", vars);
  foreach( indices( vars ), v )
    if(variables[v])
      variables[v][ VAR_VALUE ] = vars[ v ];
  return 1;
}

static class ConfigurableWrapper
{
  int mode;
  function f;
  object roxen;

  int check()
  {
    if ((mode & VAR_EXPERT) &&
	(!roxen->configuration_interface()->expert_mode)) {
      return 1;
    }
    if ((mode & VAR_MORE) &&
	(!roxen->configuration_interface()->more_mode)) {
      return 1;
    }
    return(f());
  }
  void create(object roxen_, int mode_, function f_)
  {
    roxen = roxen_;
    mode = mode_;
    f = f_;
  }
};

function reg_s_loc;
int globvar(string var, mixed value, string name, int type,
	    string|void doc_str, mixed|void misc,
	    int|function|void not_in_config)
{
  variables[var]                     = allocate( VAR_SIZE );
  variables[var][ VAR_VALUE ]        = value;
  variables[var][ VAR_TYPE ]         = type & VAR_TYPE_MASK;
  variables[var][ VAR_DOC_STR ]      = doc_str;
  variables[var][ VAR_NAME ]         = name;
  variables[var][ VAR_MISC ]         = misc;
  
  type &= ~VAR_TYPE_MASK;		// Probably not needed, but...
  type &= (VAR_EXPERT | VAR_MORE);
  if (functionp(not_in_config)) {
    if (type) {
      variables[var][ VAR_CONFIGURABLE ] =
	ConfigurableWrapper(this_object(), type, not_in_config)->check;
    } else {
      variables[var][ VAR_CONFIGURABLE ] = not_in_config;
    }
  } else if (type) {
    variables[var][ VAR_CONFIGURABLE ] = type;
  } else if(intp(not_in_config)) {
    variables[var][ VAR_CONFIGURABLE ] = !not_in_config;
  }

  if(!reg_s_loc)
    reg_s_loc = master()->resolv("Locale")["Roxen"]["standard"]
              ->register_module_doc;
  reg_s_loc( this_object(), var, name, doc_str );
  variables[var][ VAR_SHORTNAME ] = var;
}

mapping locs = ([]);
void deflocaledoc( string locale, string variable, 
		   string name, string doc, mapping|void translate)
{
  if(!locs[locale] )
    locs[locale] = master()->resolv("Locale")["Roxen"][locale]
                 ->register_module_doc;
  if(!locs[locale])
    report_debug("Invalid locale: "+locale+". Ignoring.\n");
  else
    locs[locale]( this_object(), variable, name, doc, translate );
}


public mixed query(void|string var)
{
  if(var && variables[var])
    return variables[var][ VAR_VALUE ];
  if(this_object()->current_configuration)
    return this_object()->current_configuration->query(var);
  error("query("+var+"). Unknown variable.\n");
  return 0;
}

mixed set(string var, mixed val)
{
#if DEBUG_LEVEL > 30
  perror(sprintf("MAIN: set(\"%s\", %O)\n", var, val));
#endif
  if(variables[var])
  {
#if DEBUG_LEVEL > 28
    perror("MAIN:    Setting global variable.\n");
#endif
    return variables[var][VAR_VALUE] = val;
  }
  error("set("+var+"). Unknown variable.\n");
}

/* ================================================= */
/* ================================================= */

#if 0
#define SIMULATE(X)  mixed X( mixed ...a )				\
{									\
  if(roxenp()->current_configuration)					\
    return roxenp()->current_configuration->X(@a);	                \
  error("No current configuration\n");					\
}

SIMULATE(unload_module);
SIMULATE(disable_module);
SIMULATE(enable_module);
SIMULATE(load_module);
SIMULATE(find_module);
SIMULATE(register_module_load_hook);
#endif
