#include <roxen.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)


string module_global_page( RequestID id, Configuration conf )
{
  return "";
}

string module_page( RequestID id, string conf, string module )
{
  return 
#"<emit source='module-variables-sections'
  configuration='"+conf+#"'
  module='"+module+#"'>
   <tab ::='&_.first; &_.last; &_.selected;'
        href='?section=&_.section:http;'>&_.sectionname;</tab>
</emit>";
}


mixed parse( RequestID id )
{
  array path = ((id->misc->path_info||"")/"/")-({""});

  if( id->real_variables->section )
    id->variables->section=id->real_variables->section[0];

  if( !sizeof( path )  )
    return "Hm?";

  Configuration conf = roxen->find_configuration( path[0] );
  if( !conf->inited )
    conf->enable_all_modules();
  id->misc->current_configuration = conf;
  switch( sizeof(path)<3?"settings":path[ 1 ] )
  {
   case "settings":
     return
       Roxen.http_string_answer(
	 "<emit source='config-variables-sections' add-status='1'"
	 "configuration='"+path[0]+"'>\n"
	 "  <tab ::='&_.first; &_.last; &_.selected;'\n"
	 "       href='?section=&_.section:http;'>&_.sectionname;</tab>"
	 "</emit>");
     break;

   default:
     return Roxen.http_string_answer( module_page( id, path[0], path[2] ));
  }
}
