#include <module.h>

int zonk;
#define link(d) ("<a href=\""+node->path(1)+"?"+(zonk++)+"\">\n"+(d)+"\n</a>\n")

inherit "config/low_describers";

string describe_configuration_global_variables(object node)
{
  return link("<font size=+1><b>Server variables</b></font>");
}

string describe_holder(object node)
{
  object o, foo;
  int num;

  o=node->down;
  while(o)
  {
    if(!((functionp(o->data[VAR_CONFIGURABLE])&&o->data[VAR_CONFIGURABLE]())
	 ||((o->data[VAR_CONFIGURABLE]==VAR_EXPERT)
	    &&!this_object()->expert_mode)))
    {
      num++;
      foo=o;
    }
    o=o->next;
  }
  if(num==1)
  {
    foo->folded = 0;
    return link(node->data);
  }
  if(num)
    return link(node->data + "...");
}

string describe_builtin_variables(object node)
{
  return link("<b>Builtin variables (security, comments etc.)</b>");
}

string describe_errors(object node)
{
  string err;
  array report = ({ });

  foreach(indices(node->data), err)
    report += ({ (node->data[err]>1?(node->data[err] + " times:<br>"):"") 
		   + err + "<hr noshade size=1>" });

  if(node->folded)
    return (link("<font size=+2>Error and debug log</font>"));
  return (link("<font size=+2>Error and debug log")
	  + "</font><dd><pre>"+
	  (sizeof(report)?(report*""):"Empty")+"</pre>");
}

array|string describe_module_variable(object node)
{
  string res, err;

  if((node->data[VAR_CONFIGURABLE] == VAR_EXPERT)&&!this_object()->expert_mode)
    return 0;
  if(functionp(node->data[VAR_CONFIGURABLE]) && node->data[VAR_CONFIGURABLE]())
    return 0;
    
  if(node->folded)
    if(node->error)
      return "<b>Error in:</b> "+link("<b>"+node->data[VAR_NAME]+"</b>");
    else
      return link(node->data[VAR_NAME])
	+ ": <i>" + describe_variable_as_text(node->data) + "</i>";

  if(node->error)
    err = "<font size=+1><b>"+node->error+"</b></font><br>";

  res = describe_variable_low(node->data, node->path(1));

  if(res)
    return ({ "<form action=/(set)"+node->path(1)+">" 
		, (err?err:"")+res+"</form>" });

}

string describe_open_files(object node)
{
  string res = link("<font size=+1>Open files</font><dd>");
  if(node->folded)
    return res;
#if 0
#ifndef DEBUG
  res += "<br><i>Define DEBUG in config/config.h for more accurate debug</i><p>";
#endif
#endif
  res += roxen->checkfd();
  return res;
}

string describe_module_copy_status(object node)
{
  string q;

  roxen->current_configuration = node->config();

  if(node->data)
    q=node->data();

  if(!q || !strlen(q)) return 0;

  if(!node->folded)
    return link("<b>Status and debug info</b>")+"<dd>" + q+"<br>";
  return link("<b>Status and debug info</b><br>");
}

string describe_module_copy_variables(object node)
{
  return link("Variables");
}  

string describe_module_copy(object node)
{
  string name, com;
  object o;

  if(!node->data)
  {
    node->dest();
    return "";
  }


  if((name=node->data->query("_name")) && strlen(name))
    ;
  else if(node->data->query_name) 
    name = node->data->query_name();
  else if(node->data->comment) 
    name = node->data->comment();

  if(!name || !strlen(name)) 
    name=node->_path[sizeof(node->_path)-2..sizeof(node->_path)-1]*" copy ";

  if(node->folded)
    return  ("<font size=+1>" + link( name ) + "</font>");

  com = (node->data->file_name_and_stuff()+
	 (node->data->query("_comment")||""));

  return ("<font size=+1>" + link( name ) + "</font><dd>" 
	  + (roxen->QUERY(DOC)?node->data->info():"")
	  + (strlen(com)?"<p><i>"+com+"</i></p>":"")
	  +"<dd>");
}

string describe_module(object node)
{
  string name, com;
  if(!(node->data->enabled 
       && (name=node->data->enabled->query("_name")) 
       && strlen(name)))
    name = node->data->name;

  if(node->data->enabled)
    com = (node->data->master->file_name_and_stuff()+
	   (node->data->master->query("_comment")||""));

  if(node->data->copies)
    return ("<font size=+1>" + link(name) + "</font>");
  if(node->folded)
    return ("<font size=+1>" + link(name) + "</font>");

  return ("<font size=+1>" + link(name) +  "</font><dd>"
	  +  "<font size=+0>"  + node->data->master->info() 
	  + (strlen(com)?"<p><i>"+com+"</i></p>":"")
	  + "</font>");

}

string describe_global_variables( object node )
{
  return "";
}

string describe_root(object root)
{
  return "";
}

string describe_configurations(object node)
{
  return "";
}

string describe_configuration(object node)
{
  if(!node->data)  
  {
    node->dest();
    return 0;
  }
  return ("<font size=+2>" + link(node->data->query_name()) + "</font>"+
         (node->folded?"":"<dd>"+node->data->desc()+node->data->comment()));
}


#if efun(_memory_usage)
mapping last_usage = ([]);
#endif
string describe_global_debug(object node)
{
  string res;
  mixed foo;
  if(node->folded)
    return link("<font size=+1>Debug information for developers</font>");
  else
    res = link("<font size=+1>Debug information for developers</font><ul>");
#if efun(_memory_usage)
  foo = _memory_usage();
  int total;
  string f;
  res+="<table border=0 cellspacing=0 cellpadding=2 width=50%>"
    "<tr align=left bgcolor=#000060><th colspan=3>Memory Usage:</th></tr>"
    "<tr bgcolor=darkblue><th align=left>Entry<th align=right>"
    "Current (KB)<th align=right>Change (KB)</tr>";
  foreach(sort(indices(foo)), f)
    if(search(f, "num_")) {
      foo->total_usage += foo[f]/1024;
      res += "<tr bgcolor=black><td><b>"+f+"</b></td><td align=right><b>"+(foo[f]/1024)+
	"</b></td><td align=right><b>"+((foo[f]-last_usage[f])/1024)+"</b><br></td>";
    }
  res += "<tr bgcolor=black><td><b><font color=yellow>Total Usage"
    "</font></b></td><td align=right><b><font color=yellow>"+
    foo->total_usage+"</font></b></td><td align=right><b><font color=yellow>"+
    (foo->total_usage-last_usage->total_usage)+"</font></b><br></td>";

  res+="</table>";
  res+="<table border=0 cellspacing=0 cellpadding=2 width=50%><tr bgcolor=darkblue><th align=left>Entry<th align=right>Current<th align=right>Change</tr>";
  foreach(sort(indices(foo)), f)
    if(!search(f, "num_"))
      res += "<tr bgcolor=black><td><b>"+f[4..]+"</b></td><td align=right><b>"+(foo[f])+"</b>"
	"</td><td align=right><b>"+((foo[f]-last_usage[f]))+"</b><br></td>";
  last_usage=foo;
  res+="</table>";
#endif
#if efun(_dump_obj_table)
  res += ("<table  border=0 cellspacing=0 cellpadding=2 width=50%>"
	  "<tr align=left bgcolor=#000060><th  colspan=2>List of all "
	  "programs:</th></tr>"
	  "<tr align=left bgcolor=darkblue>"
	  "<th>Program name</th><th align=right>Clones</th></tr>");
  foo = _dump_obj_table();
  mapping allobj = ([]);
  string a = getcwd(), s;
  if(a[-1] != '/')
    a += "/";
  int i;
  for(i = 0; i < sizeof(foo); i++) {
    allobj[foo[i][0]]++;
  }
  foreach(sort_array(indices(allobj), 
		     lambda(string a, string b, mapping allobj) {
    return allobj[a] < allobj[b];
  }, allobj), s) {
    if(search(s, "Destructed?") == -1)
      res += sprintf("<tr bgcolor=black><td><b>%s</b></td>"
		     "<td align=right><b>%d</b></td></tr>\n",
		     s - a, allobj[s]);
  }
  res += "</table>";
#endif
#if efun(_num_objects)
  res += ("Number of destructed objects: " + _num_dest_objects() +"<br>\n");
#endif  
  return res +"</ul>";
}

#define MB (1024*1024)

string describe_string_status(object node)
{
#ifndef DEBUG
  return 0;
#endif
#if efun(_string_debug)
  if(node->folded)
    return link("<font size=+1>Shared string status</font>");
  return (link("<font size=+1>Shared string status</font><dd>")
	  + "<font size=+0><pre>"
	  + _string_debug(1)
	  + "</pre></font>\n");
#endif
}

string describe_request_status(object node)
{
  if(node->folded)
    return link("<font size=+1>Access / request status</font>");
  return link("<font size=+1>Access / request status</font>") + "<dd>"+
    roxen->full_status();
}

string describe_pipe_status(object node)
{
  int *ru;
#if efun(_pipe_debug)
  ru=_pipe_debug();
 if(node->folded)
    return link("<font size=+1>Pipe system status</font>");
 if(!ru[0])
   return (link("<font size=+1>Pipe system status</font>")+"<dd>Idle");
 
 return (link("<font size=+1>Pipe system status</font>")+"<dd>"
	 "<table border=0 cellspacing=0 cellpadding=-1>"
	 "<tr align=right><td colspan=2>Number of open outputs:</td><td>"
          +ru[0] + "</td></tr>"
	  "<tr align=right><td colspan=2>Number of open inputs:</td><td>"
	  +ru[1] + "</td></tr>"
	  "<tr align=right><td></td><td>strings:</td><td>"+ru[2]+"</td></tr>"
	  "<tr align=right><td></td><td>objects:</td><td>"+ru[3]+"</td></tr>"
	  "<tr align=right><td></td><td>mmapped:</td><td>"+(ru[1]-ru[2]-ru[3])
	  +"<td> ("+(ru[4]/1024)+"."+(((ru[4]*10)/1024)%10)+" Kb)</td></tr>"
	  "<tr align=right><td colspan=2>Buffers used in pipe:</td><td>"+ru[5]
          + "<td> (" + ru[6]/1024 + ".0 Kb)</td></tr>"
	  "</table>\n");
#endif
}

string describe_process_status(object node)
{
  string res;
  int *ru, tmp, use_ru;

  if(catch(ru=rusage())) return 0;

  if(ru[0])
    tmp=ru[0]/(time(1) - roxen->start_time+1);

  if(node->folded)
    return link("<font size=+1>Process status</font>");

  return (link("<font size=+1>Process status</font>")+"<dd><pre>"
	  "CPU-Time used             : "+roxen->msectos(ru[0]+ru[1])+
	  " ("+tmp/10+"."+tmp%10+"%)\n"
	  +(ru[-2]?(sprintf("Resident set size (RSS)   : %.3f Mb\n",
			    (float)ru[-2]/(float)MB)):"")
	  +(ru[-1]?(sprintf("Stack size                : %.3f Mb\n",
			    (float)ru[-1]/(float)MB)):"")
	  +(ru[6]?"Page faults (non I/O)     : " + ru[6] + "\n":"")
	  +(ru[7]?"Page faults (I/O)         : " + ru[7] + "\n":"")
	  +(ru[8]?"Full swaps (should be 0)  : " + ru[8] + "\n":"")
	  +(ru[9]?"Block input operations    : " + ru[9] + "\n":"")
	  +(ru[10]?"Block output operations   : " + ru[10] + "\n":"")
	  +(ru[11]?"Messages sent             : " + ru[11] + "\n":"")
	  +(ru[12]?"Messages received         : " + ru[12] + "\n":"")
	  +(ru[13]?"Number of signals received: " + ru[13] + "\n":"")
	  +"</pre>");
}

string describe_hostnames_status(object node)
{

  if(node->folded)
    return link("<font size=+1>Host names</font>");
  if(!sizeof(roxen->out))
    return link("<font size=+1>Host names</font><dd>No processes running");
  return (link("<font size=+1>Host names</font><dd>") +
	  "Number of host name lookup processes : "+sizeof(roxen->out)+"<br>"
	  "Host name lookup queue size          : "  
	  + (sizeof(roxen->do_when_found)?sizeof(roxen->do_when_found)
	     + " (" + roxen->get_size(roxen->do_when_found)+
	     sprintf(" bytes, %2.1f per process)<br>",
		     (float)sizeof(roxen->do_when_found)
		     / (float)sizeof(roxen->out))
	     :"empty"));
}

string describe_cache_system_status(object node)
{
  if(node->folded)
    return link("<font size=+1>Memory cache system</font>");
  return (link("<font size=+1>Memory cache system</font><dd>") 
	  + cache->status());
}


string describe_disk_cache_system_status(object node)
{
  if(!(roxen->QUERY(cache)))
    return 0;

  if(node->folded)
    return link("<font size=+1>Persistent disk cache system</font>");
  return (link("<font size=+1>Persistent disk cache system</font><dd>") 
	  + roxen->get_garb_info());
}

array describe_global_status(object node)
{
  string res;
  int *ru, tmp, use_ru;

  if(node->folded)
    return ({"", ""});
  
  res =  "<h2>Server uptime: " 
    + roxen->msectos((time(1) - roxen->start_time)*1000)
    + "</h2>";

  return ({ "<p>", res });
}
