/*
 * $Id: listfonts.pike,v 1.9 2000/05/03 08:50:34 mast Exp $
 */

constant action = "maintenance";
constant name= "List Available Fonts";
constant doc = "List all available fonts";

string versions(string font)
{
  array res=({ });
  array b = available_font_versions(font,32);
  if (!b || !sizeof(b)) return "<b>Not available.</b>"; // FIXME: locale?
  array a = map(b,describe_font_type);
  mapping m = mkmapping(b,a);
  foreach(sort(indices(m)), string t)
    res += ({ "<input type=hidden name='"+(font+"/"+t)+"'>"+
	      Roxen.html_encode_string(m[t]) });
  return String.implode_nicely(res);
}

string list_font(string font)
{
  return (Roxen.html_encode_string(map(replace(font,"_"," ")/" ",capitalize)*" ")+
          " <font size='-1'>"+versions(font)+"</font><br />");
}

string page_0(object id)
{
  string res=("<input type=hidden name=action value=listfonts.pike>"
              "<input type=hidden name=doit value=indeed>"
              "<font size=+1>All available fonts</font><p>");
  foreach(roxen->fonts->available_fonts(1), string font)
    res+=list_font(font);
  // FIXME: locale?
  res += ("<p>Example text: <font size=-1><input name=text size=46 value='"
          "&locale.font_test_string;'><p>"
	  "<table width='70%'><tr><td align=left>"
          "<cf-cancel href='?class=maintenance'></td><td align=right>"
	  "<cf-next></td></tr></table>");
  return res;
}

string page_1(object id)
{
  string res="";
  mapping v = id->variables;
  foreach(roxen->fonts->available_fonts(), string fn)
    res += Roxen.html_encode_string (fn)+":<br />\n"
      "<gtext align='top' font='"+fn+"'>"+
      Roxen.html_encode_string (v->text)+"</gtext><p>";
  return res+"<br /></p><p>\n<cf-ok></p>";
}

mixed parse(object id)
{
  if( id->variables->doit )
    return page_1( id );
  return page_0( id );
}
