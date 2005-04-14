#!bin/pike -m lib/pike/master.pike

/* buildenv.pike -- build an environment setup file for ChiliMoon.
 *
 *    This script tries to build an environment setup file for
 *    ChiliMoon, making sure ChiliMoon has LD_LIBRARY_PATH and
 *    other essential variables set, to keep dynamic libraries
 *    and various other external stuff happy.
 */
 
string cvs_version = "$Id: buildenv.pike,v 1.11 2005/04/14 23:06:58 _cvs_dirix Exp $";

class Environment
{
  static string filename;
  static mapping(string:array(string)) env, oldenv;

  static void read()
  {
    string var, def;
    multiset(string) exports = (<>);
    Stdio.File f;
    env = ([]);
    oldenv = ([]);
    if (catch (f = Stdio.File(filename, "r")))
          return;

    foreach(f->read()/"\n", string line)
      if (sscanf(line-"\r", "%[A-Za-z0-9_]=%s", var, def)==2)
      {
	string pre, post;
	if(2==sscanf(def, "%s${"+var+"}%s", pre, post) ||
	   2==sscanf(def, "%s$"+var+"%s", pre, post))
	{
	  if (pre=="")
	    pre = 0;
	  else if (pre[-1]==':')
	    pre = pre[..sizeof(pre)-2];
	  else if (2==sscanf(reverse(pre), "}:+:%*[^{]{$%s", pre))
	    pre = reverse(pre);
	  if (post=="")
	    post = 0;
	  else if (post[0]==':')
	    post = post[1..];
	  else 
	    sscanf(post, "${%*[^:}]:+:}%s", post);
	  env[var] = ({ pre, 0, post });
	}
	else
	  env[var] = ({ 0, def, 0 });
      }
      else if (sscanf(line, "export %s", var))
	foreach((replace(var, ({"\t","\r"}),({" "," "}))/" ")-({""}), string v)
	  exports[v] = 1;
    foreach(indices(env), string e)
      if (!exports[e])
	m_delete(env, e);
    oldenv = copy_value(env);
  }

  static void write()
  {
    Stdio.File f = Stdio.File(filename, "cwt");
    if (!f)
    {
      error("Failed to write "+filename+"\n");
      return;
    }
    f->write("# This file is automatically generated by the buildenv.pike\n");
    f->write("# script. Generated on " + replace(ctime(time()),"\n","") + ".\n");
    f->write("#\n# Edit it at your own risk.  :-)\n");
    foreach(sort(indices(env)), string var)
    {
      array(string) v = env[var];
      if (v && (v[0]||v[1]||v[2]))
      {
	f->write(var+"=");
	if(v[1])
	  f->write((v[0]? v[0]+":":"")+v[1]+(v[2]? ":"+v[2]:""));
	else if (!v[0])
	  // Append only
	  f->write("${"+var+"}${"+var+":+:}"+v[2]);
	else if (!v[2])
	  // Prepend only
	  f->write(v[0]+"${"+var+":+:}${"+var+"}");
	else
	  // Prepend and append
	  f->write(v[0]+"${"+var+":+:}${"+var+"}:"+v[2]);
	f->write("\nexport "+var+"\n");
      }
    }
    f->close();
  }

  static int changed()
  {
    return !equal(env, oldenv);
  }

  void append(string var, string val)
  {
    array(string) v = env[var];
    if (!v)
      v = env[var] = ({ 0, 0, 0 });
    foreach(val/":", string comp)
      if ((!v[2]) || search(v[2]/":", comp)<0)
	v[2] = (v[2]? v[2]+":":"")+comp;
  }

  void prepend(string var, string val)
  {
    array(string) v = env[var];
    if (!v)
      v = env[var] = ({ 0, 0, 0 });
    foreach(val/":", string comp)
      if ((!v[0]) || search(v[0]/":", comp)<0)
	v[0] = comp+(v[0]? ":"+v[0]:"");
  }

  void set(string var, string val)
  {
    array(string) v = env[var];
    if (!v)
      v = env[var] = ({ 0, 0, 0 });
    v[1] = val;
  }

  void remove(string var)
  {
    m_delete(env, var);
  }

  string get(string var)
  {
    array(string) v = env[var];
    return v && (v-({0}))*":";
  }

  int finalize()
  {
    if (!changed())
      return 0;
    write();
    return 1;
  }

  void create(string fn)
  {
    filename = fn;
    read();
  }

}

void config_env(Environment env)
{
  string dir = "bin/env.d";
  program p;
  object eo;

  foreach(glob("*.pike", get_dir(dir)||({})), string e)
  { string name = (e/".")[0];
    if (!catch (p = compile_file(dir+"/"+e)))
    { if (eo = p())
        eo->run(env);
      else
        write("   Skipping %O.\n", name);
    }
    else
        write("   Test script %O failed to compile.\n", name);
  }
}

void main(int argc, array argv)
{
  write("   Setting up environment in %s.\n",
	combine_path(getcwd(), "../local"));

  if (Stdio.file_size("/etc/chilimoon") != -2)
  { if (Stdio.file_size("bin") != -2 || Stdio.file_size("modules") != -2)
    { write("   "+argv[0]+": "
	    "should be run in the ChiliMoon 'server' directory.\n");
      exit(1);
    }
    if (!mkdir("/etc/chilimoon", 0775))
    {
      write("   Failed to create /etc/chilimoon!\n");
      exit(1);
    }
  }

  Environment envobj = Environment("/usr/chilimoon/local/environment");

  config_env(envobj);
  if (envobj->finalize())
  {
    write("   Environment updated.\n\n");
  }
  else
  {
    write("   Environment didn't need updating.\n\n");
  }
}


