#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)	_STR_LOCALE("roxen_config",X,Y)

string c_name( string c, RequestID id )
{
  if( c == _(0,"automatic") )
    return Roxen.short_name( id->variables->lname );
  return c;
}

void really_do_create( RequestID id  )
{
  
  DBManager.create_group( c_name(id->variables->name,id),
			     id->variables->lname,
			     id->variables->comment,
			     (strlen(id->variables->url)?
			     "mysql://"+id->variables->url+"/" : 
			     ""));
}


mapping|string parse( RequestID id )
{
  RXML.user_set_var( "var.go-on",  "<cf-ok/>" );

  if( !id->variables->name )
    id->variables->name = _(0,"automatic");
  
  string error="",form =
#"
<gtext scale=0.6>"+_(0,"Create a new database group")+#"</gtext><br />
"+_(0,"The groups are used mainly to group the databases in the\n"
"Administration interface, but also to indicate the default MySQL server\n"
"internal databases will be created in.\n"
"\n"
"<p> If a group has a URL set, it will be used to select the database\n"
"server in which the database will be created, please note that this\n"
    "server must be a MySQL server, nothing else will work.\n")+#"<br /><p>
<font size=+1><b>ERROR</b></font>
<table>
  <tr>
    <td><b>"+_(0,"ID")+#":</b></td> <td><input name='name' value='&form.name;' size=20/></td>
    <td><b>"+_(0,"Name")+#":</b></td> <td><input name='lname' value='&form.lname;' size=30/></td>
  </tr>
  <tr>
  <td valign=top colspan='2'>
    <i>"+_(0,"The identifier of the group. This is used internally in Roxen,"
	   " and must be unique. "
	   "If you leave it as automatic, a ID will be selected "
	   "automatically.")+#"
     </i>
   </td>
   <td valign=top colspan='2' width='100%'>

        <i>"+_(0,"The name of the database group. This is what is"
	       " shown in the configuration interface")+#"</i>
   </td>
 </tr>
  <tr>
     <td><nbsp><b>"+_(0,"URL")+#":</b></nbsp></td>
      <td colspan=3>mysql://<input name='url' size=30 value='&form.url;'/></td>
      </tr>
      <tr><td valign=top colspan='4'><i>
      "+_(0,"This URL is only used when </i>Internal<i> databases is "
	  "created in this group, and it specified which MySQL server "
	  "the datbase should be created in. As an example, if you want all "
	  "databases created in the group to end up in the MySQL running "
	  "on the host </i>wyrm<i>, using the account with the username </i>foo<i> and "
	  "password </i>bar<i>, set this URL to </i>foo:bar@wyrm<i>")+
    "</td></tr>"
#"<tr><td valign=top><nbsp><b>"+_(0,"Comment")+#":</b></nbsp></td>
      <td colspan=3><textarea name='comment' cols=50 rows=10>&form.comment;</textarea></td></tr>"

    "</table>";

  if( id->variables["ok.x"]  )
  {
    if( strlen(id->variables->url) )
    {
      if(catch(Sql.Sql( "mysql://"+id->variables->url+"/mysql" ) ))
	error = sprintf( "<font color='&usr.warncolor;'>"+
			 _(0,"Cannot connect to %s")+
			 "</font>", "mysql://"+id->variables->url );
    }
    if(!strlen(error))
      if( DBManager.get_group( c_name(id->variables->name,id) ) )
	error=sprintf("<font color='&usr.warncolor;'>"+
		      _(0,"A database group named %s already exists")+
		      "</font>");
    if( !strlen( error ) )
      if( Roxen.is_mysql_keyword( id->variables->name ) )
	error = sprintf("<font color='&usr.warncolor;'>"+
			_(0,"%s is a MySQL keyword, used by MySQL."
			  "Please select another name")+
			"</font>", id->variables->name );
      else
      {
	really_do_create( id );
	RXML.user_set_var( "var.go-on", "<redirect to=''/>" );
	return "";
      }
  }
  return replace( form, "ERROR", error );
}
