// This is a roxen module. Copyright � 2000 - 2001, Roxen IS.
//

#include <module.h>
inherit "module";

constant cvs_version = "$Id: additional_rxml.pike,v 1.26 2003/01/26 02:25:01 mani Exp $";
constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Tags: Additional RXML tags";
constant module_doc  = "This module provides some more complex and not as widely used RXML tags.";

void create() {
  defvar("insert_href",0,"Allow <insert href>",
	 TYPE_FLAG|VAR_MORE,
         "If set, it will be possible to use <tt>&lt;insert href&gt;</tt> to "
	 "insert pages from another web server. Note that the thread will be "
	 "blocked while it fetches the web page.");
}

class TagInsertHref {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "href";

  string get_data(string var, mapping args, RequestID id) {
    if(!query("insert_href")) RXML.run_error("Insert href is not allowed.");

    if(args->nocache)
      NOCACHE();
    else
      CACHE(60);
    Protocols.HTTP q=Protocols.HTTP.get_url(args->href);
    if(q && q->status>0 && q->status<400)
      return q->data();

    RXML.run_error(q ? q->status_desc + "\n": "No server response\n");
  }
}

string container_recursive_output (string tagname, mapping args,
                                  string contents, RequestID id)
{
  int limit;
  array(string) inside, outside;
  if (id->misc->recout_limit)
  {
    limit = id->misc->recout_limit - 1;
    inside = id->misc->recout_outside, outside = id->misc->recout_inside;
  }
  else
  {
    limit = (int) args->limit || 100;
    inside = args->inside ? args->inside / (args->separator || ",") : ({});
    outside = args->outside ? args->outside / (args->separator || ",") : ({});
    if (sizeof (inside) != sizeof (outside))
      RXML.parse_error("'inside' and 'outside' replacement sequences "
		       "aren't of same length.\n");
  }

  if (limit <= 0) return contents;

  int save_limit = id->misc->recout_limit;
  string save_inside = id->misc->recout_inside, save_outside = id->misc->recout_outside;

  id->misc->recout_limit = limit;
  id->misc->recout_inside = inside;
  id->misc->recout_outside = outside;

  string res = Roxen.parse_rxml (
    parse_html (
      contents,
      (["recurse": lambda (string t, mapping a, string c) {return c;}]),
      ([]),
      "<" + tagname + ">" + replace (contents, inside, outside) +
      "</" + tagname + ">"),
    id);

  id->misc->recout_limit = save_limit;
  id->misc->recout_inside = save_inside;
  id->misc->recout_outside = save_outside;

  return res;
}

class TagSprintf {
  inherit RXML.Tag;
  constant name = "sprintf";

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      array(string|int|float) in;
      if(args->split)
	in=content/args->split;
      else
	in=({content});

      array f=((args->format-"%%")/"%")[1..];
      if(sizeof(in)!=sizeof(f))
	RXML.run_error("Indata hasn't the same size as format data (%d, %d).\n", sizeof(in), sizeof(f));

      // Do some casting
      for(int i; i<sizeof(in); i++) {
	int quit;
	foreach(f[i]/1, string char) {
	  if(quit) break;
	  switch(char) {
	  case "d":
	  case "u":
	  case "o":
	  case "x":
	  case "X":
	  case "c":
	  case "b":
	    in[i]=(int)in[i];
	    quit=1;
	    break;
	  case "f":
	  case "g":
	  case "e":
	  case "G":
	  case "E":
	  case "F":
	    in[i]=(float)in[i];
	    quit=1;
	    break;
	  case "s":
	  case "O":
	  case "n":
	  case "t":
	    quit=1;
	    break;
	  }
	}
      }

      result=sprintf(args->format, @in);
      return 0;
    }
  }
}

class TagSscanf {
  inherit RXML.Tag;
  constant name = "sscanf";

  class Frame {
    inherit RXML.Frame;

    string do_return(RequestID id) {
      array(string) vars=args->variables/",";
      array(string) vals=array_sscanf(content, args->format);
      if(sizeof(vars)<sizeof(vals))
	RXML.run_error("Too few variables.\n");

      int var=0;
      foreach(vals, string val)
	RXML.user_set_var(vars[var++], val, args->scope);

      if(args->return)
	RXML.user_set_var(args->return, sizeof(vals), args->scope);
      return 0;
    }
  }
}

class TagDice {
  inherit RXML.Tag;
  constant name = "dice";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    string do_return(RequestID id) {
      NOCACHE();
      if(!args->type) args->type="D6";
      args->type = replace( args->type, "T", "D" );
      int value;
      args->type=replace(args->type, "-", "+-");
      foreach(args->type/"+", string dice) {
	if(has_value(dice, "D")) {
	  if(dice[0]=='D')
	    value+=random((int)dice[1..])+1;
	  else {
	    array(int) x=(array(int))(dice/"D");
	    if(sizeof(x)!=2)
	      RXML.parse_error("Malformed dice type.\n");
	    value+=x[0]*(random(x[1])+1);
	  }
	}
	else
	  value+=(int)dice;
      }

      if(args->variable)
	RXML.user_set_var(args->variable, value, args->scope);
      else
	result=(string)value;

      return 0;
    }
  }
}

class TagEmitKnownLangs
{
  inherit RXML.Tag;
  constant name = "emit", plugin_name = "known-langs";
  array get_dataset(mapping m, RequestID id)
  {
    return map(get_core()->list_languages(),
	       lambda(string id)
	       {
		 object language = roxenp()->language_low(id);
		 string eng_name = language->id()[1];
		 if(eng_name == "standard")
		   eng_name = "english";
		 return ([ "id" : id,
			 "name" : language->id()[2],
		  "englishname" : eng_name ]);
	       });
  }
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
  "dice":#"<desc type='cont'><p><short>
 Simulates a D&amp;D style dice algorithm.</short></p></desc>

<attr name='type' value='string' default='D6'><p>
 Describes the dices. A six sided dice is called 'D6' or '1D6', while
 two eight sided dices is called '2D8' or 'D8+D8'. Constants may also
 be used, so that a random number between 10 and 20 could be written
 as 'D9+10' (excluding 10 and 20, including 10 and 20 would be 'D11+9').
 The character 'T' may be used instead of 'D'.</p>
</attr>",

  "insert#href":#"<desc type='plugin'><p><short>
 Inserts the contents at that URL.</short> This function has to be
 enabled in the <module>Additional RXML tags</module> module in the
 ChiliMoon administration interface. The page download will block
 the current thread, and if running unthreaded, the whole server.
 There is no timeout in the download, so if the server connected to
 hangs during transaction, so will the current thread in this server.</p></desc>

<attr name='href' value='string'><p>
 The URL to the page that should be inserted.</p>
</attr>

<attr name='nocache' value='string'><p>
 If provided the resulting page will get a zero cache time in the RAM cache.
 The default time is up to 60 seconds depending on the cache limit imposed by
 other RXML tags on the same page.</p>
</attr>",

"sscanf":#"<desc type='cont'><p><short>
 Extract parts of a string and put them in other variables.</short> Refer to
 the sscanf function in the Pike reference manual for a complete
 description.</p>
</desc>

<attr name='variables' value='list' required='required'><p>
 A comma separated list with the name of the variables that should be set.</p>
<ex>
<sscanf variables='form.year,var.month,var.day'
format='%4d%2d%2d'>19771003</sscanf>
&form.year;-&var.month;-&var.day;
</ex>
</attr>

<attr name='scope' value='name' required='required'><p>
 The name of the fallback scope to be used when no scope is given.</p>
<ex>
<sscanf variables='year,month,day' scope='var'
 format='%4d%2d%2d'>19801228</sscanf>
&var.year;-&var.month;-&var.day;<br />
<sscanf variables='form.year,var.month,var.day'
 format='%4d%2d%2d'>19801228</sscanf>
&form.year;-&var.month;-&var.day;
</ex>
</attr>

<attr name='return' value='name'><p>
 If used, the number of successfull variable 'extractions' will be
 available in the given variable.</p>
</attr>",

  "sprintf":#"<desc type='cont'><p><short>
 Prints out variables with the formating functions availble in the
 Pike function sprintf.</short> Refer to the Pike reference manual for
 a complete description.</p></desc>

<attr name='format' value='string'><p>
  The formatting string.</p>
</attr>

<attr name='split' value='charater'><p>
  If used, the tag content will be splitted with the given string.</p>
<ex>
<sprintf format='#%02x%02x%02x' split=','>250,0,33</sprintf>
</ex>
</attr>",


"emit#known-langs":({ #"<desc type='plugin'><p><short>
 Outputs all languages partially supported by roxen for writing
 numbers, weekdays et c.</short>
 Outputs all languages partially supported by roxen for writing
 numbers, weekdays et c (for example for the number and date tags).
 </p>
</desc>

 <ex><emit source='known-langs' sort='englishname'>
  4711 in &_.englishname;: <number lang='&_.id;' num='4711'/><br />
</emit></ex>",
			([
			  "&_.id;":#"<desc type='entity'>
 <p>Prints the three-character ISO 639-2 id of the language, for
 example \"eng\" for english and \"deu\" for german.</p>
</desc>",
			  "&_.name;":#"<desc type='entity'>
 <p>The name of the language in the language itself, for example
 \"fran�ais\" for french.</p>
</desc>",
			  "&_.englishname;":#"<desc type='entity'>
 <p>The name of the language in English.</p>
</desc>",
			]) }),

#if 0
  // This applies to the old rxml 1.x parser. The doc for this tag is
  // here only for historical interest, to serve as a monument over
  // the quoting horrors that do_output_tag and its likes incurred.
  "recursive-output": #"\
<desc type='cont'>
  <p>This container provides a way to implement recursive output,
  which is mainly useful when you want to create arbitrarily nested
  trees from some external data, e.g. an SQL database. Put simply, the
  <tag>recurse</tag> tag is replaced by everything inside and
  including the <tag>recursive-output</tag> container. Although simple
  in theory, it tends to get a little bit messy in practice.</p>

  <p>To make it work you have to pay some attention to the parsing
  order of the involved tags. After the <tag>recursive-output</tag>
  container have replaced every <tag>recurse</tag> with itself, the
  whole thing is parsed again. Therefore, to make it terminate, you
  must always put the <tag>recurse</tag> inside a conditional
  container (typically an <tag>if</tag>) that does not preparse its
  contents.</p>

  <p>So far so good, but you'll almost always want to use some sort of
  output container, e.g. <tag>formoutput</tag> or
  <tag>sqloutput</tag>, together with this tag, which makes it
  slightly more complex due to the necessary treatment of the quote
  characters. Since the contents of <tag>recursive-output</tag> is
  expanded two levels at any time, each level needs its own set of
  quotes. To accomplish this, <tag>recursive-output</tag> can rotate
  two quote sets which are specified by the `inside' and `outside'
  arguments. Each time a <tag>recurse</tag> is replaced, every string
  in the `inside' set is replaced by the string in the corresponding
  position in the `outside' set, then the two sets trade places. Thus,
  you should put all quote characters you use inside
  <tag>recursive-output</tag> in the `inside' set and some other
  characters that doesn't clash with anything in the `outside' set.
  You might also have to quote the quote characters when writing these
  sets, which is done by doubling them.</p>
</desc>

<attr name='inside' value='string,...'><p>
  The list of quotes `inside' the container, to be replaced in with the
  `outside' set in every other round of recursion.</p>
</attr>

<attr name='outside' value='string,...'><p>
  The list of quotes `outside' the container, to be replaced in with
  the `inside' set in every other round of recursion.</p>
</attr>

<attr name='multisep' value='separator'><p>
  The given value is used as the separator between the strings in the
  two sets. It defaults to ','.</p>
</attr>

<attr name='limit' value='number'><p>
  Specifies the maximum nesting depth. As a safeguard it defaults to
  100.</p>
</attr>",
#endif

]);
#endif
