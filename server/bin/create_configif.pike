/*
 * $Id: create_configif.pike,v 1.22 2000/05/30 14:31:18 marcus Exp $
 *
 * Create an initial administration interface server.
 */

int mkdirhier(string from)
{
  string a, b;
  array f;

  f=(from/"/");
  b="";

  foreach(f[0..sizeof(f)-2], a)
  {
    mkdir(b+a);
    b+=a+"/";
  }
}

string read_string(Stdio.Readline rl, string prompt, string|void def,
		   string|void batch)
{
  string res = batch || rl->read( prompt+(def? " ["+def+"]":"")+": " );
  if( def && !strlen(res-" ") )
    res = def;
  return res;
}

int main(int argc, array argv)
{
  Stdio.Readline rl = Stdio.Readline();
  string name, user, password, configdir, port;
  string passwd2;
  mapping(string:string) batch = ([]);

  rl->redisplay( 1 );

#if constant( SSL3 )
  string def_port = "https://*:"+(random(20000)+10000)+"/";
#else
  string def_port = "http://*:"+(random(20000)+10000)+"/";
#endif

  write( "Roxen 2.0 administration interface installation script\n");

  configdir =
   Getopt.find_option(argv, "d",({"config-dir","configuration-directory" }),
  	              ({ "ROXEN_CONFIGDIR", "CONFIGURATIONS" }),
                      "../configurations");
  int admin = has_value(argv, "-a");

  int batch_args = search(argv, "--batch");
  if(batch_args>=0)
    batch = mkmapping(@Array.transpose(argv[batch_args+1..]/2));

  foreach( get_dir( configdir )||({}), string cf )
    catch 
    {
      if( cf[-1]!='~' &&
	  search( Stdio.read_file( configdir+"/"+cf ), 
                  "'config_filesystem#0'" ) != -1 )
      {
        werror("There is already an administration interface present in "
               "this server.\nNo new will be created\n");
        exit( 0 );
      }
    };
  if(configdir[-1] != '/')
    configdir+="/";
  if(admin)
    write( "Creating an administrator user.\n" );
  else
    write( "Creating an administration interface server in "+configdir+"\n");

  do
  {
    if(!admin) 
    {
      name = read_string(rl, "Server name", "Administration Interface",
			 batch->server_name);

      int port_ok;
      while( !port_ok )
      {
        string protocol, host, path;

        port = read_string(rl, "Port URL", def_port, batch->server_url);
	m_delete(batch, "server_url");
        if( port == def_port )
          ;
        else if( (int)port )
        {
          int ok;
          while( !ok )
          {
            switch( protocol = lower_case(read_string(rl, "Protocol", "http")))
            {
             case "":
               protocol = "http";
             case "http":
             case "https":
               port = protocol+"://*:"+port+"/";
               ok=1;
               break;
             default:
               write("Only http and https are supported for the "
                     "configuration interface\n");
               break;
            }
          }
        }

        if( sscanf( port, "%[^:]://%[^/]%s", protocol, host, path ) == 3)
        {
          if( path == "" )
            path = "/";
          switch( lower_case(protocol) )
          {
           case "http":
           case "https":
             // Verify hostname here...
             port = lower_case( protocol )+"://"+host+path;
             port_ok = 1;
             break;
           default:
             write("Only http and https are supported for the "
                   "configuration interface\n");
             break;
          }
        }
      }
    }

    do 
    {
      user = read_string(rl, "Administrator user name", "administrator",
			 batch->user);
      m_delete(batch, "user");
    } while(((search(user, "/") != -1) || (search(user, "\\") != -1)) &&
            write("User name may not contain slashes.\n"));

    do
    {
      rl->get_input_controller()->dumb=1;
      password = read_string(rl, "Administrator Password", 0, batch->password);
      passwd2 = read_string(rl, "Administrator Password (again)", 0, batch->password);
      rl->get_input_controller()->dumb=0;
      if(batch->password)
	m_delete(batch, "password");
      else
	write("\n");
    } while(!strlen(password) || (password != passwd2));
  } while( strlen( passwd2 = read_string(rl, "Ok?", "y", batch->ok ) ) && passwd2[0]=='n' );


  if( !admin )
  {
    string community_user, community_password, proxy_host="", proxy_port="80";
    string community_userpassword="";
    int use_update_system=0;
  
    if(!batch->update) {
      write("Roxen 2.0 has a built-in update system. If enabled it will periodically\n");
      write("contact update servers at Roxen Internet Software over the Internet.\n");
      write("Do you want to enable this?\n");
    }
    if(!(strlen( passwd2 = read_string(rl, "Ok?", "y", batch->update ) ) && passwd2[0]=='n' ))
    {
      use_update_system=1;
      if(!batch->community_user) {
	write("If you have a registered user identity at Roxen Community\n");
	write("(http://community.roxen.com), you may be able to access\n");
	write("additional material through the update system.\n");
	write("Press enter to skip this.\n");
      }
      community_user=read_string(rl, "Roxen Community Identity (your e-mail)",
				 0, batch->community_user);
      if(sizeof(community_user))
      {
        do
        {
          rl->get_input_controller()->dumb=1;
          community_password = read_string(rl, "Roxen Community Password", 0,
					   batch->community_password);
          passwd2 = read_string(rl, "Roxen Community Password (again)", 0,
				batch->community_password);
          rl->get_input_controller()->dumb=0;
	  if(batch->community_password)
	    m_delete(batch, "community_password");
	  else
	    write("\n");
          community_userpassword=community_user+":"+community_password;
        } while(!strlen(community_password) || (community_password != passwd2));
      }
      
      if((strlen( passwd2 = read_string(rl, "Do you want to access the update "
					"server through an HTTP proxy?",
					"n", batch->community_proxy))
	  && passwd2[0]!='n' ))
      {
	proxy_host=read_string(rl, "Proxy host", 0, batch->proxy_host);
	if(sizeof(proxy_host))
	  proxy_port=read_string(rl, "Proxy port", "80", batch->proxy_port);
	if(!sizeof(proxy_port))
	  proxy_port="80";
      }
    }
    mkdirhier( configdir );
    Stdio.write_file( configdir+replace( name, " ", "_" ),
                      replace(
#"
<!-- -*- html -*- -->
<?XML version=\"1.0\"?>

<region name='EnabledModules'>
  <var name='config_filesystem#0'> <int>1</int>  </var> <!-- Configration Filesystem -->
</region>

<region name='pikescript#0'>
  <var name='trusted'><int>1</int></var>
</region>

<region name='update#0'>
  <var name='do_external_updates'> <int>$USE_UPDATE_SYSTEM$</int> </var>
  <var name='proxyport'>         <int>$PROXY_PORT$</int> </var>
  <var name='proxyserver'>       <str>$PROXY_HOST</str> </var>
  <var name='userpassword'>      <str>$COMMUNITY_USERPASSWORD$</str> </var>
</region>

<region name='contenttypes#0'>
  <var name='_priority'>         <int>0</int> </var>
  <var name='default'>           <str>application/octet-stream</str> </var>
  <var name='exts'><str># This will include the defaults from a file.
# Feel free to add to this, but do it after the #include line if
# you want to override any defaults

#include %3cetc/extensions%3e
tag text/html
xml text/html
rad text/html
ent text/html

</str></var>
</region>

<region name='spider#0'>
  <var name='Domain'> <str></str> </var>
  <var name='MyWorldLocation'><str></str></var>
  <var name='URLs'> <a> <str>$URL$</str></a> </var>

  <var name='comment'>
    <str>Automatically created by create_configuration</str>
  </var>

  <var name='name'>
    <str>$NAME$</str>
  </var>
</region>",
 ({ "$NAME$", "$URL$", "$USE_UPDATE_SYSTEM$","$PROXY_PORT$",
    "$PROXY_HOST", "$COMMUNITY_USERPASSWORD$" }),
 ({ name, port, (string)use_update_system, proxy_port,
    proxy_host, community_userpassword }) ));
    write("Administration interface created\n");
  }

  string ufile=(configdir+"_configinterface/settings/" + user + "_uid");
  mkdirhier( ufile );
  Stdio.write_file(ufile,
string_to_utf8(#"<?XML version=\"1.0\"  encoding=\"UTF-8\"?>
<map>
  <str>permissions</str> : <a> <str>Everything</str> </a>
  <str>real_name</str>   : <str>Administration Interface Default User</str>
  <str>password</str>    : <str>" + crypt(password) + #"</str>
  <str>name</str>        : <str>" + user + "</str>\n</map>" ));

  write("Administrator user \"" + user + "\" created.\n");
}
