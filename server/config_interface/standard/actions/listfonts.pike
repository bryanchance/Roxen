/*
 * $Id: listfonts.pike,v 1.11 2000/08/16 14:48:27 lange Exp $
 */

#include <roxen.h>
//<locale-token project="admin_tasks"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("admin_tasks",X,Y)

constant action = "maintenance";

string name= LOCALE(10, "List fonts");
string doc = LOCALE(11, "List all available fonts");


string versions(string font)
{
  array res=({ });
  array b = available_font_versions(font,32);
  if (!b || !sizeof(b)) 
    return "<b>"+LOCALE("dH","Not available.")+"</b>"; 
  array a = map(b,describe_font_type);
  mapping m = mkmapping(b,a);
  foreach(sort(indices(m)), string t)
    res += ({ "<input type='hidden' name='"+(font+"/"+t)+"'/>"+
	      Roxen.html_encode_string(m[t]) });
  return String.implode_nicely(res);
}

string list_font(string font)
{
  return (Roxen.html_encode_string(map(replace(font,"_"," ")/" ",capitalize)*" ")+
          " <font size='-1'>"+versions(font)+"</font><br />");
}

string page_0(RequestID id)
{
  string res=("<input type='hidden' name='action' value='listfonts.pike'/>"
              "<input type='hidden' name='doit' value='indeed'/>\n"
	      "<font size='+1'>" +
	      LOCALE("dI","All available fonts") + "</font><p>");
  foreach(roxen->fonts->available_fonts(1), string font)
    res+=list_font(font);
  res += ("</p><p>" + LOCALE(236,"Example text") +
	  "<font size=-1><input name=text size=46 value='" +
	  LOCALE(237,"Jackdaws love my big sphinx of quartz.") +
	  "'></p><p><table width='70%'><tr><td align='left'>"
          "<cf-cancel href='?class=maintenance'/></td><td align='right'>"
	  "<cf-next/></td></tr></table></p>");
  return res;
}

string page_1(RequestID id)
{
  string res="";
  mapping v = id->variables;
  foreach(roxen->fonts->available_fonts(), string fn)
    res += Roxen.html_encode_string (fn)+":<br />\n"
      "<gtext align='top' font='"+fn+"'>"+
      Roxen.html_encode_string (v->text)+"</gtext><p>";
  return res+"<br /></p><p>\n<cf-ok/></p>";
}

mixed parse( RequestID id )
{
  if( id->variables->doit )
    return page_1( id );
  return page_0( id );
}
