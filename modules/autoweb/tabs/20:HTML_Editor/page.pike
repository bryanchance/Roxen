inherit "roxenlib";
inherit "wizard";

object wa;

array wanted_buttons = ({ });

array get_buttons(object id)
{
  return wanted_buttons;
}

void create (object webadm)
{
  wa = webadm;
}

string real_path(object id, string filename)
{
  return wa->query("sites_location")+id->misc->customer_id+
    (sizeof(filename)?(filename[0]=='/'?filename:"/"+filename):"/");
}

mapping dl(object id, string filename)
{
  object f = Stdio.File(real_path(id, filename), "r");
  if(f)
    return ([ "type" : "application/octet-stream",
	      "data" : f->read() ]);
  else
    return 0;
}

string|mapping navigate(object id, string f, string base_url)
{

  // werror("File: %O\n", f);
  // werror("Real file: %O\n", real_path(id, f));
  
  string res="";
  
  if(f[-1]!='/') // it's a file
  {
    array br = ({ });
    int t;
    object file = Stdio.File(real_path(id, f), "r");

    if(!objectp(file))
      return "File not found or permission denied.\n";

    mapping md = wa->get_md(id, f);
    br += ({ ({ "View",  f+" target=_autosite_show_real" }) });
    werror("%O\n", md);
    if(md->content_type=="text/html")
      br += ({ ({ "Edit File", (["filename":f ]) }) });
    br += ({ ({ "Edit Metadata", ([ "path":f ]) }),
	     ({ "Download File", ([ "path": base_url+"dl"+f ]) }),
	     ({ "Upload File", ([ "path":f ]) }),
	     ({ "Remove File", ([ "path":f ]) }) });
    wanted_buttons=br;

    // Show info about the file;
    res += "<img src='"+
	   wa->content_types[md->content_type||"autosite/unknown"]->img+
	   "'>&nbsp;&nbsp;";
    res += "<b>"+f+"</b><br>\n";

    mapping md = wa->get_md(id, f);
    array md_order = ({ "title", "content_type", "template",
			"keywords", "description" });
    mapping md_variables = ([ "title":"Title", "content_type":"Type",
			      "template":"Template", "keywords":"Keywords",
			      "description":"Description" ]);
    array rows = ({ });
    foreach(md_order, string variable) {
      if(md_variables[variable]&&md[variable])
	rows += ({ ({ "<b>"+md_variables[variable]+"</b>",
		      (variable=="content_type"?
		       wa->content_types[md[variable]]->name:
		       md[variable]) }) });
    }
    res += html_table( ({ "Metadata", "Value" }), rows);
  }
  else  // it's a directory
  {
    res += "<b>"+f+"</b><br>";
    wanted_buttons =
    ({ ({ "Create File", ([ "path": f ]) }),
       ({ "Upload File", ([ "path": f ]) }) });
    
    // Show the directory
    array files = ({ });
    array dirs = ({ });

    // Scan directory for files and directories.
    foreach(get_dir(real_path(id, f)), string file) {
      array f_stat = file_stat(real_path(id, f+file));
      if((sscanf(file, "%*s.md") == 0)&&(file!="templates")) {
	if(f_stat&&(sizeof(f_stat)>0)&&f_stat[1]==-2)
	  dirs += ({ file });
	else 
	  files += ({ file });
      }
    }

    // Display directories.
    foreach(sort(dirs), string item) {
      res += "<img src=\"internal-gopher-menu\">&nbsp;&nbsp;";
      res += "<a href=\""+base_url+"go"+f+item+"/\">"+item+"/</a><br>\n";
    }
    
    // Display files.
    foreach(sort(files), string item) {
      mapping md = wa->get_md(id, f+item);
      string img = "internal-gopher-unknown";
      if(md)
	img = wa->content_types[md->content_type||
			       "autosite/unknown"]->img;
      res += "<img src='"+img+"'>&nbsp;&nbsp;";
      res += "<a href=\""+base_url+"go"+f+item+"\">"+item+"</a><br>\n";
    }
  }
  
  if(sizeof(f)>1)
    res = "<a href=../>Up to parent directory</a><br>\n<br>\n"+res;
  
  return res;
}

string|mapping handle(string sub, object id)
{
  wanted_buttons=({ });
  if(!id->misc->state)
    id->misc->state=([]);
  string resource="/";
  string base_url = id->not_query[..sizeof(id->not_query)-sizeof(sub)-1];

  if(2==sscanf(sub, "%s/%s", sub, resource))
    resource = "/"+resource;
  switch(sub) {
  case "":
    break;
  case "go":
    break;
  case "dl":
    return dl(id, resource);
  default:
    return "What?";
  }
  return navigate(id, resource, base_url);
}
