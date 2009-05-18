// Symbolic DB handling. 
//
// $Id: DBManager.pmod,v 1.72 2009/05/18 13:47:47 grubba Exp $

//! Manages database aliases and permissions

#include <roxen.h>
#include <config.h>


#define CN(X) string_to_utf8( X )
#define NC(X) utf8_to_string( X )


constant NONE  = 0;
//! No permissions. Used in @[set_permission] and @[get_permission_map]

constant READ  = 1;
//! Read permission. Used in @[set_permission] and @[get_permission_map]

constant WRITE = 2;
//! Write permission. Used in @[set_permission] and @[get_permission_map]


private
{
  mixed query( mixed ... args )
  {
    return connect_to_my_mysql( 0, "roxen" )->query( @args );
  }

  string short( string n )
  {
    return lower_case(sprintf("%s%4x", CN(n)[..6],(hash( n )&65535) ));
  }

  void clear_sql_caches()
  {
#if DBMANAGER_DEBUG
    werror("DBManager: clear_sql_caches():\n"
	   "  dead_sql_cache: %O\n"
	   "  sql_cache: %O\n"
	   "  connection_cache: %O\n",
	   dead_sql_cache,
	   sql_cache,
	   connection_cache);
#endif /* DMBMANAGER_DEBUG */
    /* Rotate the sql_caches.
     *
     * Perform the rotation first, to avoid thread-races.
     */
    sql_url_cache = ([]);
    connection_user_cache = ([]);
    clear_connect_to_my_mysql_cache();
  }
  
  array changed_callbacks = ({});
  void changed()
  {
    changed_callbacks-=({0});
    clear_sql_caches();
    
    foreach( changed_callbacks, function cb )
      catch( cb() );
  }

  static void low_ensure_has_users( Sql.Sql db, Configuration c, string host,
				    string|void password )
  {
    array q = db->query( "SELECT User FROM user WHERE User=%s AND Host=%s",
			 short(c->name)+"_rw", host );
    
    if( sizeof( q ) )
    {
      db->query("DELETE FROM user WHERE User=%s AND Host=%s",
		short(c->name)+"_rw", host );
      db->query("DELETE FROM user WHERE User=%s AND Host=%s",
		short(c->name)+"_ro", host );
    }
    
    if( password )
    {
      db->query( "INSERT INTO user (Host,User,Password) "
		 "VALUES (%s, %s, PASSWORD(%s))",
		 host, short(c->name)+"_rw", password ); 
      db->query( "INSERT INTO user (Host,User,Password) "
		 "VALUES (%s, %s, PASSWORD(%s))",
		 host, short(c->name)+"_ro", password );
    }
    else
    {
      db->query( "INSERT INTO user (Host,User,Password) "
		 "VALUES (%s, %s, '')",
		 host, short(c->name)+"_rw" ); 
      db->query( "INSERT INTO user (Host,User,Password) "
		 "VALUES (%s, %s, '')",
		 host, short(c->name)+"_ro" );
    }
  }
  
  void ensure_has_users( Sql.Sql db, Configuration c )
  {
    low_ensure_has_users( db, c, "localhost" );
  }

  void ensure_has_external_users( Sql.Sql db, Configuration c,
				  string password )
  {
    low_ensure_has_users( db, c, "127.0.0.1", password );
  }

  static void execute_sql_script(Sql.Sql db, string script,
				 int|void quiet)
  {
    // Split on semi-colon, but not inside strings...
    array(string) queries =
      map(Parser.C.split(script)/({";"}), `*, "");
    foreach(queries[..sizeof(queries)-2], string q) {
      mixed err = catch {db->query(q);};
      if (err && !quiet) {
	// Complain about failures only if they're not expected.
	master()->handle_error(err);
      }
    }
  }

  static void low_set_user_permissions( Configuration c, string name,
					int level, string host,
					string|void password )
  {
    Sql.Sql db = connect_to_my_mysql( 0, "mysql" );

    low_ensure_has_users( db, c, host, password );

    db->query("DELETE FROM db "
	      "  WHERE User LIKE '"+short(c->name)+"%%' "
	      "    AND Db=%s"
	      "    AND Host=%s", name, host);

    if( level > 0 )
    {
      db->query("INSERT INTO db (Host,Db,User,Select_priv) "
                "VALUES (%s, %s, %s, 'Y')",
                host, name, short(c->name)+"_ro");
      if( level > 1 ) {
	// FIXME: Is this correct for Mysql 4.0.18?
        db->query("INSERT INTO db (Host,Db,User,Select_priv,Insert_priv,"
		  "Update_priv,Delete_priv,Create_priv,Drop_priv,Grant_priv,"
		  "References_priv,Index_priv,Alter_priv) VALUES (%s, %s, %s,"
                  "'Y','Y','Y','Y','Y','Y','N','Y','Y','Y')",
                  host, name, short(c->name)+"_rw");
      } else {
        db->query("INSERT INTO db (Host,Db,User,Select_priv) "
                  "VALUES (%s, %s, %s, 'Y')",
                  host, name, short(c->name)+"_rw");
      }
    }
    db->query( "FLUSH PRIVILEGES" );
  }
  
  void set_user_permissions( Configuration c, string name, int level )
  {
    low_set_user_permissions( c, name, level, "localhost" );
  }
  
  void set_external_user_permissions( Configuration c, string name, int level,
				      string password )
  {
    low_set_user_permissions( c, name, level, "127.0.0.1", password );
  }

  
  class ROWrapper( static Sql.Sql sql )
  {
    static int pe;
    static array(mapping(string:mixed)) query( string query, mixed ... args )
    {
      // Get rid of any initial whitespace.
      query = String.trim_all_whites(query);
      if( has_prefix( lower_case(query), "select" ) ||
          has_prefix( lower_case(query), "show" ) ||
          has_prefix( lower_case(query), "describe" ))
        return sql->query( query, @args );
      pe = 1;
      throw( ({ "Permission denied\n", backtrace()}) );
    }
    static object big_query( string query, mixed ... args )
    {
      // Get rid of any initial whitespace.
      query = String.trim_all_whites(query);
      if( has_prefix( lower_case(query), "select" ) ||
          has_prefix( lower_case(query), "show" ) ||
          has_prefix( lower_case(query), "describe" ))
        return sql->big_query( query, @args );
      pe = 1;
      throw( ({ "Permission denied\n", backtrace()}) );
    }
    static string error()
    {
      if( pe )
      {
        pe = 0;
        return "Permission denied";
      }
      return sql->error();
    }

    static string host_info()
    {
      return sql->host_info()+" (read only)";
    }

    static mixed `[]( string i )
    {
      switch( i )
      {
       case "query": return query;
       case "big_query": return big_query;
       case "host_info": return host_info;
       case "error": return error;
       default:
         return sql[i];
      }
    }
    static mixed `->( string i )
    {
      return `[](i);
    }
  }

  mapping(string:mapping(string:string)) sql_url_cache = ([]);

  mapping(string:mixed) get_db_url_info(string db)
  {
    mapping(string:mixed) d = sql_url_cache[ db ];
    if( !d )
    {
      array(mapping(string:string)) res;
      res = query("SELECT path,local FROM dbs WHERE name=%s", db );
      if( !sizeof( res ) )
	return 0;
      sql_url_cache[db] = d = res[0];
    }
    return d;
  }

  Sql.Sql low_get( string user, string db, void|int reuse_in_thread,
		   void|string charset)
  {
    if( !user )
      return 0;
    mixed res;
    mapping(string:mixed) d = get_db_url_info(db);
    if( !d ) return 0;

    if( (int)d->local )
      return connect_to_my_mysql( user, db, reuse_in_thread, charset );

    // Otherwise it's a tad more complex...  
    if( user[strlen(user)-2..] == "ro" )
      // The ROWrapper object really has all member functions Sql.Sql
      // has, but they are hidden behind an overloaded index operator.
      // Thus, we have to fool the typechecker.
      return [object(Sql.Sql)](object)
	ROWrapper( sql_cache_get( d->path, reuse_in_thread, charset) );
    return sql_cache_get( d->path, reuse_in_thread, charset);
  }
};

Sql.Sql get_sql_handler(string db_url)
{
#ifdef USE_EXTSQL_ORACLE
  if(has_prefix(db_url, "oracle:"))
    return ExtSQL.sql(db_url);
#endif
  return Sql.Sql(db_url);
}

Sql.Sql sql_cache_get(string what, void|int reuse_in_thread,
		      void|string charset)
{
  Thread.MutexKey key = roxenloader.sq_cache_lock();
  string i = replace(what,":",";")+":-";
  Sql.Sql res = roxenloader.sq_cache_get(i, reuse_in_thread, charset);
  if (res) return res;
  // Release the lock during the call to get_sql_handler(),
  // since it may take quite a bit of time...
  destruct(key);
  if (res = get_sql_handler(what)) {
    // Now we need the lock again...
    key = roxenloader.sq_cache_lock();
    res = roxenloader.sq_cache_set(i, res, reuse_in_thread, charset);
    // Fool the optimizer so that key is not released prematurely
    if( res )
      return res; 
  }
}

void add_dblist_changed_callback( function(void:void) callback )
//! Add a function to be called when the database list has been
//! changed. This function will be called after all @[create_db] and
//! @[drop_db] calls.
{
  changed_callbacks |= ({ callback });
}

int remove_dblist_changed_callback( function(void:void) callback )
//! Remove a function previously added with @[add_dblist_changed_callback].
//! Returns non-zero if the function was in the callback list.
{
  int s = sizeof( changed_callbacks );
  changed_callbacks -= ({ callback });
  return s-sizeof( changed_callbacks );
}

array(string) list( void|Configuration c )
//! List all database aliases.
//!
//! If @[c] is specified, only databases that the given configuration can
//! access will be visible.
{
  array(mapping(string:string)) res;
  if( c )
    return  query( "SELECT "
                   " dbs.name AS name "
                   "FROM "
                   " dbs,db_permissions "
                   "WHERE"
                   " dbs.name=db_permissions.db"
                   " AND db_permissions.config=%s"
                   " AND db_permissions.permission!='none'",
                   CN(c->name))->name
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
      -({"roxen","mysql"})
#endif
      ;
  return query( "SELECT name from dbs" )->name
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
      -({"roxen","mysql"})
#endif
    ;
}

mapping(string:mapping(string:int)) get_permission_map( )
//! Get a list of all permissions for all databases.
//!
//! @returns
//!   Return format:
//!   	@mapping
//!   	  @member mapping(string:int) dbname
//!   	    @mapping
//!   	      @member int configname
//!   		Access level same as for @[set_permission()] et al.
//!   	    @endmapping
//!   	@endmapping
{
  mapping(string:mapping(string:int)) res = ([]);

  foreach( list(), string n )
  {
    mixed m = query( "SELECT * FROM db_permissions WHERE db=%s", n );
    if( sizeof( m ) )
      foreach( m, m )
      {
        if( !res[m->db] )res[m->db] = ([]);
        switch( m->permission )
        {
         case "none":    res[m->db][NC(m->config)] = NONE; break;
         case "read":    res[m->db][NC(m->config)] = READ; break;
         case "write":   res[m->db][NC(m->config)] = WRITE; break;
        }
      }
    else
      res[n] = ([]);
  }
  foreach( indices(res), string q )
    foreach( roxenp()->configurations, Configuration c )
      if( zero_type( res[q][c->name] ) )
        res[q][c->name] = 0;
  return res;
}

string db_driver( string db )
//! Returns the name of the protocol used to connect to the database 'db'.
//! This is the part before :// in the database URL.  
{
  if( !(db = db_url( db )) ) return "mysql";
  sscanf( db, "%[^:]:", db );
  return db;
}

int is_mysql( string db )
//! Returns true if the specified database is a MySQL database.
{
  return !(db = db_url( db )) || has_prefix( db, "mysql://" );
}

array(mapping(string:mixed)) db_table_fields( string name, string table )
//! Returns a mapping of fields in the database, if it's supported by
//! the protocol handler. Otherwise returns 0.
{
  Sql.Sql db = cached_get( name );
  catch {
    if( db->list_fields )
    {
      mixed res = db->list_fields( table );
      if( res ) return res;
    }
  };
  // Now, this is slow, but very generic. :-)
  mixed err = catch {
    array res = ({});
    foreach( db->big_query( "SELECT * FROM "+table )->fetch_fields(),
	     object q )
    {
      res += ({
	([
	  "name":q->name,
	  "type":q->type,
	])
      });
    }
    return res;
  };
  // No dice.
  return 0;
}

array(string) db_tables( string name )
//! Attempt to list all tables in the specified DB, and then return
//! the list.
{
  object db = get(name);
  if (!db) return ({});
  array(string) res;
  if( db->list_tables )
  {
    catch {
      if( res =  db->list_tables() )
	return res;
    };
  }

  // Well, let's try some specific solutions then. The main problem if
  // we reach this stage is probably that we are using a ODBC driver
  // which does not support the table enumeration interface, this
  // causing list_tables to throw an error.

  switch( db_driver( name ) )
  {
    case "mysql":
      return ({});

    case "odbc":
      // Oracle.
      catch {
	res = db->query( "select TNAME from tab")->TNAME;
	return res;
      };
      // fallthrough.

      // Microsoft SQL (7.0 or newer)
      catch {
	res = ({});
	foreach( db->query("SELECT * FROM information_schema.tables"),
		 mapping row )
	  if( has_prefix( lower_case(row->TABLE_TYPE), "base" ) )
	    res += ({ row->TABLE_NAME });
	return res;
      };

      
    case "postgres":
      // Postgres
      catch {
	res = db->query("SELECT a.relname AS name FROM pg_class a, "
			"pg_user b WHERE ( relkind = 'r') and "
			"relname !~ '^pg_' "
			"AND relname !~ '^xin[vx][0-9]+' AND "
			"b.usesysid = a.relowner AND "
			"NOT (EXISTS (SELECT viewname FROM pg_views "
			"WHERE viewname=a.relname)) ")->name;
	return res;
      };
  }

  return ({});
}

mapping db_table_information( string db, string table )
//! Return a mapping with at least the indices rows, data_length
//! and index_length, if possible. Otherwise returns 0.
{
  switch( db_driver( db ) )
  {
    case "mysql":
    {
      foreach( get(db)->query( "SHOW TABLE STATUS" ), mapping r )
      {
	if( r->Name == table )
	  return ([ "rows":(int)r->Rows,
		    "data_length":(int)r->Data_length,
		    "index_length":(int)r->Index_length ]);
      }
    }
    default:
#if 0
      mixed err = catch{
	return ([
	  "rows":
	  (int)(get(db)->query( "SELECT COUNT(*) AS C FROM "+table )[0]->C),
	]);
      };
#endif
  }
  return 0;
}


mapping db_stats( string name )
//! Return statistics for the specified database (such as the number
//! of tables and their total size). If the database is not an
//! internal database, or the database does not exist, 0 is returned
{
  mapping res = ([]);
  Sql.Sql db = cached_get( name );
  array d;

  switch( db_driver( name ) )
  {
    case "mysql":
      if( !catch( d = db->query( "SHOW TABLE STATUS" ) ) )
      {
	foreach( d, mapping r )
	{
	  res->size += (int)r->Data_length+(int)r->Index_length;
	  res->tables++;
	  res->rows += (int)r->Rows;
	}
	return res;
      }

      // fallthrough to generic interface.
    default:
      catch
      {
	foreach( db_tables( name ), string n )
	{
	  mapping i  = db_table_information( name, n );
	  res->tables++;
	  if( i )
	  {
	    res->rows += i->rows;
	    res->size += i->data_length+i->index_length;
	  }
	}
	return res;
      };
  }
  return 0;
}


int is_internal( string name )
//! Return true if the DB @[name] is an internal database
{
  array(mapping(string:mixed)) d =
           query("SELECT path,local FROM dbs WHERE name=%s", name );
  if( !sizeof( d ) ) return 0;
  return (int)d[0]["local"];
}

string db_url( string name,
	       int|void force )
//! Returns the URL of the db, or 0 if the DB @[name] is an internal
//! database and @[force] is not specified. If @[force] is specified,
//! a URL is always returned unless the database does not exist.
{
  array(mapping(string:mixed)) d =
           query("SELECT path,local FROM dbs WHERE name=%s", name );

  if( !sizeof( d ) )
    return 0;

  if( (int)d[0]["local"] )
  {
    if( force )
      return replace( roxenloader->my_mysql_path,
		      ([
			"%user%":"rw",
			"%db%":name
		      ]) );
    return 0;
  }
  return d[0]->path;
}

static mapping connection_user_cache  = ([]);

string get_db_user( string name, Configuration c, int ro )
{
  string key = name+"|"+(c&&c->name)+"|"+ro;
  if( !zero_type( connection_user_cache[ key ] ) )
    return connection_user_cache[ key ];

  array(mapping(string:mixed)) res;
  if( c )
  {
    res = query( "SELECT permission FROM db_permissions "
                 "WHERE db=%s AND config=%s",  name, CN(c->name));
    if( sizeof( res ) && res[0]->permission != "none" )
      return connection_user_cache[ key ]=short(c->name) +
	((ro || res[0]->permission!="write")?"_ro":"_rw");
    return connection_user_cache[ key ] = 0;
  }
  return connection_user_cache[ key ] = ro?"ro":"rw";
}

Sql.Sql get( string name, void|Configuration conf,
	     int|void read_only, void|int reuse_in_thread,
	     void|string charset)
//! Returns an SQL connection object for a database named under the
//! "DB" tab in the administration interface.
//!
//! @param name
//!   The name of the database.
//!
//! @param conf
//!   If this isn't zero, only return the database if this
//!   configuration has at least read access.
//!
//! @param read_only
//!   Return a read-only connection if this is set. A read-only
//!   connection is also returned if @[conf] is specified and only has
//!   read access (regardless of @[read_only]).
//!
//! @param reuse_in_thread
//!   If this is nonzero then the SQL connection is reused within the
//!   current thread. I.e. other calls to this function from this
//!   thread with the same @[name] and @[read_only] and a nonzero
//!   @[reuse_in_thread] will return the same object. However, the
//!   connection won't be reused while a result object from
//!   @[Sql.Sql.big_query] or similar exists.
//!
//!   Using this flag is a good way to cut down on the amount of
//!   simultaneous connections, and to avoid deadlocks when
//!   transactions or locked tables are used (other problems can occur
//!   instead though, if transactions or table locking is done
//!   recursively). However, the caller has to ensure that the
//!   connection never becomes in use by another thread. The safest
//!   way to ensure that is to always keep it on the stack, i.e. only
//!   assign it to variables declared inside functions or pass it in
//!   arguments to functions.
//!
//! @param charset
//!   If this is nonzero then the returned connection is configured to
//!   use the specified charset for queries and returned text strings.
//!
//!   The valid values and their meanings depend on the type of
//!   database connection. However, the special value
//!   @expr{"unicode"@} configures the connection to accept and return
//!   unencoded (possibly wide) unicode strings (provided the
//!   connection supports this).
//!
//!   An error is thrown if the database connection doesn't support
//!   the given charset or has no charset support at all.
//!
//!   See @[Sql.Sql.set_charset] for more information.
//!
//! @note
//! A charset being set through the @[charset] argument or
//! @[Sql.Sql.set_charset] is tracked and reset properly when a
//! connection is reused. If the charset (or any other context info,
//! for that matter) is changed some other way then it must be
//! restored before the connection is released.
{
#ifdef MODULE_DEBUG
  if (!reuse_in_thread)
    if (mapping(string:TableLockInfo) dbs = table_locks->get())
      if (TableLockInfo lock_info = dbs[name])
	werror ("Warning: Another connection was requested to %O "
		"in a thread that has locked tables %s.\n"
		"It's likely that this will result in a deadlock - "
		"consider using the reuse_in_thread flag.\n",
		name,
		String.implode_nicely (indices (lock_info->locked_for_read &
						lock_info->locked_for_write)));
#endif
  return low_get( get_db_user( name, conf, read_only), name, reuse_in_thread,
		  charset);
}

Sql.Sql cached_get( string name, void|Configuration c, void|int ro,
		    void|string charset)
{
  return get (name, c, ro, 0, charset);
}

static Thread.Local table_locks = Thread.Local();
static class TableLockInfo (
  Sql.Sql db,
  int count,
  multiset(string) locked_for_read,
  multiset(string) locked_for_write,
) {}

class MySQLTablesLock
//! This class is a helper to do MySQL style LOCK TABLES in a safer
//! way:
//!
//! o  It avoids nested LOCK TABLES which would implicitly release the
//!    previous lock. Instead it checks that the outermost lock
//!    encompasses all tables.
//! o  It ensures UNLOCK TABLES always gets executed on exit through
//!    the refcount garb strategy (i.e. put it in a local variable
//!    just like a @[Thread.MutexKey]).
//! o  It checks that the @[reuse_in_thread] flag was used to
//!    @[DBManager.get] to ensure that a thread doesn't outlock itself
//!    by using different connections.
//!
//! Note that atomic queries and updates don't require
//! @[MySQLTablesLock] stuff even when it's used in other places at
//! the same time. They should however use a connection retrieved with
//! @[reuse_in_thread] set to avoid deadlocks.
{
  static TableLockInfo lock_info;

  static void create (Sql.Sql db,
		      array(string) read_tables,
		      array(string) write_tables)
  //! @[read_tables] and @[write_tables] contain the tables to lock
  //! for reading and writing, respectively. A table string may be
  //! written as @expr{"foo AS bar"@} to specify an alias.
  {
    if (!db->db_name)
      error ("db was not retrieved with DBManager.get().\n");
    if (!db->reuse_in_thread)
      error ("db was not retrieved with DBManager.get(x,y,z,1).\n");

    multiset(string) read_tbl = (<>);
    foreach (read_tables || ({}), string tbl) {
      sscanf (tbl, "%[^ \t]", tbl);
      read_tbl[tbl] = 1;
    }

    multiset(string) write_tbl = (<>);
    foreach (write_tables || ({}), string tbl) {
      sscanf (tbl, "%[^ \t]", tbl);
      write_tbl[tbl] = 1;
    }

    mapping(string:TableLockInfo) dbs = table_locks->get();
    if (!dbs) table_locks->set (dbs = ([]));

    if ((lock_info = dbs[db->db_name])) {
      if (lock_info->db != db)
	error ("Tables %s are already locked by this thread through "
	       "a different connection.\nResult objects from "
	       "db->big_query or similar might be floating around, "
	       "or normal and read-only access might be mixed.\n",
	       indices (lock_info->locked_for_read &
			lock_info->locked_for_write) * ", ");
      if (sizeof (read_tbl - lock_info->locked_for_read -
		  lock_info->locked_for_write))
	error ("Cannot read lock more tables %s "
	       "due to already held locks on %s.\n",
	       indices (read_tbl - lock_info->locked_for_read -
			lock_info->locked_for_write) * ", ",
	       indices (lock_info->locked_for_read &
			lock_info->locked_for_write) * ", ");
      if (sizeof (write_tbl - lock_info->locked_for_write))
	error ("Cannot write lock more tables %s "
	       "due to already held locks on %s.\n",
	       indices (write_tbl - lock_info->locked_for_write) * ", ",
	       indices (lock_info->locked_for_read &
			lock_info->locked_for_write) * ", ");
#ifdef TABLE_LOCK_DEBUG
      werror ("[%O, %O] MySQLTablesLock.create(): Tables already locked: "
	      "read: [%{%O, %}], write: [%{%O, %}]\n",
	      this_thread(), db,
	      indices (lock_info->locked_for_read),
	      indices (lock_info->locked_for_write));
#endif
      lock_info->count++;
    }

    else {
      string query = "LOCK TABLES " +
	({
	  sizeof (read_tbl) && (read_tables * " READ, " + " READ"),
	  sizeof (write_tbl) && (write_tables * " WRITE, " + " WRITE")
	}) * ", ";
#ifdef TABLE_LOCK_DEBUG
      werror ("[%O, %O] MySQLTablesLock.create(): %s\n",
	      this_thread(), db, query);
#endif
      db->query (query);
      dbs[db->db_name] = lock_info =
	TableLockInfo (db, 1, read_tbl, write_tbl);
    }
  }

  int topmost_lock()
  {
    return lock_info->count == 1;
  }

  Sql.Sql get_db()
  {
    return lock_info->db;
  }

  static void destroy()
  {
    if (!--lock_info->count) {
#ifdef TABLE_LOCK_DEBUG
      werror ("[%O, %O] MySQLTablesLock.destroy(): UNLOCK TABLES\n",
	      this_thread(), lock_info->db);
#endif
      lock_info->db->query ("UNLOCK TABLES");
      m_delete (table_locks->get(), lock_info->db->db_name);
    }
#ifdef TABLE_LOCK_DEBUG
    else
      werror ("[%O, %O] MySQLTablesLock.destroy(): %d locks left\n",
	      this_thread(), lock_info->db, lock_info->count);
#endif
  }
}

void drop_db( string name )
//! Drop the database @[name]. If the database is internal, the actual
//! tables will be deleted as well.
{
  if( (< "local", "mysql", "roxen"  >)[ name ] )
    error( "Cannot drop the 'local' database\n" );

  array q = query( "SELECT name,local FROM dbs WHERE name=%s", name );
  if(!sizeof( q ) )
    error( "The database "+name+" does not exist\n" );
  if( sizeof( q ) && (int)q[0]["local"] )
    query( "DROP DATABASE `"+name+"`" );
  query( "DELETE FROM dbs WHERE name=%s", name );
  query( "DELETE FROM db_groups WHERE db=%s", name );
  query( "DELETE FROM db_permissions WHERE db=%s", name );
  changed();
}

void set_url( string db, string url, int is_internal )
//! Set the URL for the specified database.
//! No data is copied.
//! This function call only works for external databases. 
{
  query( "UPDATE dbs SET path=%s, local=%d WHERE name=%s",
	 url, is_internal, db );
  changed();
}

void copy_db_md( string oname, string nname )
//! Copy the metadata from oname to nname. Both databases must exist
//! prior to this call.
{
  mapping m = get_permission_map( )[oname];
  foreach( indices( m ), string s )
    if( Configuration c = roxenp()->find_configuration( s ) )
      set_permission( nname, c, m[s] );
  changed();
}

array(mapping) backups( string dbname )
{
  if( dbname )
    return query( "SELECT * FROM db_backups WHERE db=%s", dbname );
  return query("SELECT * FROM db_backups"); 
}

array(mapping) restore( string dbname, string directory, string|void todb,
			array|void tables )
//! Restore the contents of the database dbname from the backup
//! directory. New tables will not be deleted.
//!
//! This function supports restoring both backups generated with @[backup()]
//! and with @[dump()].
//!
//! The format of the result is as for the second element in the
//! return array from @[backup]. If todb is specified, the backup will
//! be restored in todb, not in dbname.
//!
//! @note
//!   When restoring backups generated with @[dump()] the @[tables]
//!   parameter is ignored.
{
  Sql.Sql db = cached_get( todb || dbname );

  if( !directory )
    error("Illegal directory\n");

  if( !db )
    error("Illegal database\n");

  directory = combine_path( getcwd(), directory );

  string fname;

  if (Stdio.is_file(fname = directory + "/dump.sql") ||
      Stdio.is_file(fname = directory + "/dump.sql.bz2") ||
      Stdio.is_file(fname = directory + "/dump.sql.gz")) {
    // mysqldump-style backup.

    Stdio.File raw = Stdio.File(fname, "r");
    Stdio.File cooked = raw;
    if (has_suffix(fname, ".bz2")) {
      cooked = Stdio.File();
      Process.create_process(({ "bzip2", "-cd" }),
			     ([ "stdout":cooked->pipe(Stdio.PROP_IPC),
				"stdin":raw,
			     ]));
      raw->close();
    } else if (has_suffix(fname, ".gz")) {
      cooked = Stdio.File();
      Process.create_process(({ "gzip", "-cd" }),
			     ([ "stdout":cooked->pipe(Stdio.PROP_IPC),
				"stdin":raw,
			     ]));
      raw->close();
    }
    report_notice("Restoring backup file %s to database %s...\n",
		  fname, todb || dbname);
    execute_sql_script(db, cooked->read());
    // FIXME: Return a proper result.
    return ({});
  }

  array q =
    tables ||
    query( "SELECT tbl FROM db_backups WHERE db=%s AND directory=%s",
	   dbname, directory )->tbl;

  array res = ({});
  foreach( q, string table )
  {
    db->query( "DROP TABLE IF EXISTS "+table);
    directory = combine_path( getcwd(), directory );
    res += db->query( "RESTORE TABLE "+table+" FROM %s", directory );
  }
  return res;
}

void delete_backup( string dbname, string directory )
//! Delete a backup previously done with @[backup()] or @[dump()].
{
  // 1: Delete all backup files.
  array(string) tables =
    query( "SELECT tbl FROM db_backups WHERE db=%s AND directory=%s",
	   dbname, directory )->tbl;
  if (!sizeof(tables)) {
    // Backward compat...
    directory = combine_path( getcwd(), directory );
    tables =
      query( "SELECT tbl FROM db_backups WHERE db=%s AND directory=%s",
	     dbname, directory )->tbl;
  }
  foreach( tables, string table )
  {
    rm( directory+"/"+table+".frm" );
    rm( directory+"/"+table+".MYD" );
  }
  rm( directory+"/dump.sql" );
  rm( directory+"/dump.sql.bz2" );
  rm( directory+"/dump.sql.gz" );
  rm( directory );

  // 2: Delete the information about this backup.
  query( "DELETE FROM db_backups WHERE db=%s AND directory=%s",
	 dbname, directory );
}

#ifdef ENABLE_DB_BACKUPS
array(string|array(mapping)) dump(string dbname, string|void directory,
				  string|void tag)
//! Make a backup using @tt{mysqldump@} of all data in the specified database.
//! If a directory is not specified, one will be created in $VARDIR.
//!
//! @param dbname
//!   Database to backup.
//! @param directory
//!   Directory to store the backup in.
//!   Defaults to a directory under @tt{$VARDIR@}.
//! @param tag
//!   Flag indicating the subsystem that requested the backup
//!   (eg @[timed_backup()] sets it to @expr{"timed_backup"@}.
//!   This flag is used to let the backup generation cleanup
//!   differentiate between its backups and others.
//!
//! This function is similar to @[backup()], but uses a different
//! storage format, and supports backing up external (MySQL) databases.
//!
//! @returns
//!   Returns an array with the following structure:
//!   @array
//!   	@elem string directory
//!   	  Name of the directory.
//!   	@elem array(mapping(string:string)) db_info
//!   	@array
//!   	  @elem mapping(string:string) table_info
//!   	    @mapping
//!   	      @member string "Table"
//!   		Table name.
//!   	      @member string "Msg_type"
//!   		one of:
//!   		@string
//!   		  @value "status"
//!   		  @value "error"
//!   		  @value "info"
//!   		  @value "warning"
//!   		@endstring
//!   	      @member string "Msg_text"
//!   		The message.
//!   	    @endmapping
//!   	@endarray
//!   @endarray
//!
//! @note
//!   This function currently only works for MySQL databases.
//!
//! @seealso
//!   @[backup()]
{
  mapping(string:mixed) db_url_info = get_db_url_info(dbname);
  if (!db_url_info)
    error("Illegal database.\n");

  string mysqldump;
  foreach(({ "libexec", "bin", "sbin" }), string dir) {
    foreach(({ "mysqldump.exe", "mysqldump" }), string bin) {
      string path = combine_path(getcwd(), "mysql", dir, bin);
      if (Stdio.is_file(path)) {
	mysqldump = path;
	break;
      }
    }
    if (mysqldump) break;
  }
  if (!mysqldump) {
    error("Mysqldump backup method not supported "
	  "without a mysqldump binary.\n");
  }

  if( !directory )
    directory = roxen_path( "$VARDIR/"+dbname+"-"+isodate(time(1)) );
  directory = combine_path( getcwd(), directory );

  string db_url = db_url_info->path;

  if (db_url_info->local) {
    db_url = replace(roxenloader->my_mysql_path, ({ "%user%", "%db%" }),
		     ({ "ro", dbname || "mysql" }));
  }
  if (!has_prefix(db_url, "mysql://"))
    error("Currently only supports MySQL databases.\n");
  string host = (db_url/"://")[1..]*"://";
  string port;
  string user;
  string password;
  string db;
  array(string) arr = host/"@";
  if (sizeof(arr) > 1) {
    // User and/or password specified
    host = arr[-1];
    arr = (arr[..sizeof(arr)-2]*"@")/":";
    if (!user && sizeof(arr[0])) {
      user = arr[0];
    }
    if (!password && (sizeof(arr) > 1)) {
      password = arr[1..]*":";
      if (password == "") {
	password = 0;
      }
    }
  }
  arr = host/"/";
  if (sizeof(arr) > 1) {
    host = arr[..sizeof(arr)-2]*"/";
    db = arr[-1];
  } else {
    error("No database specified in DB-URL for DB alias %s.\n", dbname);
  }
  arr = host/":";
  if (sizeof(arr) > 1) {
    port = arr[1..]*":";
    host = arr[0];
  }

  // Time to build the command line...
  array(string) cmd = ({ mysqldump, "--add-drop-table", "--all",
			 "--complete-insert", "--compress",
			 "--extended-insert", "--hex-blob",
			 "--quick", "--quote-names" });
  if ((host == "") || (host == "localhost")) {
    // Socket.
    if (port) {
      cmd += ({ "--socket=" + port });
    }
  } else {
    // Hostname.
    cmd += ({ "--host=" + host });
    if (port) {
      cmd += ({ "--port=" + port });
    }
  }
  if (user) {
    cmd += ({ "--user=" + user });
  }
  if (password) {
    cmd += ({ "--password=" + password });
  }

  mkdirhier( directory+"/" );

  cmd += ({
    "--result-file=" + directory + "/dump.sql",
    db,
  });

  werror("Backing up database %s to %s/dump.sql...\n", dbname, directory);
  // werror("Starting mysqldump command: %O...\n", cmd);

  if (Process.create_process(cmd)->wait()) {
    error("Mysql dump command failed for DB %s.\n", dbname);
  }

  foreach( db_tables( dbname ), string table )
  {
    query( "DELETE FROM db_backups WHERE "
	   "db=%s AND directory=%s AND tbl=%s",
	   dbname, directory, table );
    query( "INSERT INTO db_backups (db,tbl,directory,whn,tag) "
	   "VALUES (%s,%s,%s,%d,%s)",
	   dbname, table, directory, time(), tag );
  }

  if (Process.create_process(({ "bzip2", "-f9", directory + "/dump.sql" }))->
      wait() &&
      Process.create_process(({ "gzip", "-f9", directory + "/dump.sql" }))->
      wait()) {
    werror("Failed to compress the database dump.\n");
  }

  // FIXME: Fix the returned table_info!
  return ({ directory,
	    map(db_tables(dbname),
		lambda(string table) {
		  return ([ "Table":table,
			    "Msg_type":"status",
			    "Msg_text":"Backup ok",
		  ]);
		}),
  });
}
#endif

array(string|array(mapping)) backup( string dbname, string|void directory,
				     string|void tag)
//! Make a backup of all data in the specified database.
//! If a directory is not specified, one will be created in $VARDIR.
//!
//! @param dbname
//!   (Internal) database to backup.
//! @param directory
//!   Directory to store the backup in.
//!   Defaults to a directory under @tt{$VARDIR@}.
//! @param tag
//!   Flag indicating the subsystem that requested the backup
//!   (eg @[timed_backup()] sets it to @expr{"timed_backup"@}.
//!   This flag is used to let the backup generation cleanup
//!   differentiate between its backups and others.
//!
//! @returns
//!   Returns an array with the following structure:
//!   @array
//!   	@elem string directory
//!   	  Name of the directory.
//!   	@array
//!   	  @elem mapping(string:string) table_info
//!   	    @mapping
//!   	      @member string "Table"
//!   		Table name.
//!   	      @member string "Msg_type"
//!   		one of:
//!   		@string
//!   		  @value "status"
//!   		  @value "error"
//!   		  @value "info"
//!   		  @value "warning"
//!   		@endstring
//!   	      @member string "Msg_text"
//!   		The message.
//!   	    @endmapping
//!   	@endarray
//!   @endarray
//!
//! @note
//!   Currently this function only works for internal databases.
//!
//! @seealso
//!   @[dump()]
{
  Sql.Sql db = cached_get( dbname );

  if( !db )
    error("Illegal database\n");

  if( !directory )
    directory = roxen_path( "$VARDIR/"+dbname+"-"+isodate(time(1)) );
  directory = combine_path( getcwd(), directory );

  if( is_internal( dbname ) )
  {
    mkdirhier( directory+"/" );
    array tables = db_tables( dbname );
    array res = ({});
    foreach( tables, string table )
    {
      res += db->query( "BACKUP TABLE "+table+" TO %s",directory);
      query( "DELETE FROM db_backups WHERE "
	     "db=%s AND directory=%s AND tbl=%s",
	     dbname, directory, table );
      if (tag) {
	query( "INSERT INTO db_backups (db,tbl,directory,whn,tag) "
	       "VALUES (%s,%s,%s,%d,%s)",
	       dbname, table, directory, time(), tag );
      } else {
	query( "INSERT INTO db_backups (db,tbl,directory,whn,tag) "
	       "VALUES (%s,%s,%s,%d,NULL)",
	       dbname, table, directory, time() );
      }
    }

    return ({ directory,res });
  }
  else
  {
    error("Currently only handles internal databases\n");
    // Harder. :-)
  }
}

#ifdef ENABLE_DB_BACKUPS
//! Call-out id's for backup schedules.
protected mapping(int:mixed) backup_cos = ([]);

//! Perform a scheduled database backup.
//!
//! @param schedule_id
//!   Database to backup.
//!
//! This function is called by the database backup scheduler
//! to perform the scheduled backup.
//!
//! @seealso
//!   @[set_backup_timer()]
void timed_backup(int schedule_id)
{
  mixed co = m_delete(backup_cos, schedule_id);
  if (co) remove_call_out(co);

  array(mapping(string:string))
    backup_info = query("SELECT schedule, period, offset, dir, "
			"       generations, method "
			"  FROM db_schedules "
			" WHERE id = %d "
			"   AND period > 0 ",
			schedule_id);
  if (!sizeof(backup_info)) return;	// Timed backups disabled.
  string base_dir = backup_info[0]->dir || "";
  if (!has_prefix(base_dir, "/")) {
    base_dir = "$VARDIR/" + base_dir;
  }

  report_notice("Performing database backup according to schedule %s...\n",
		backup_info[0]->schedule);

  foreach(query("SELECT name "
		"  FROM dbs "
		" WHERE schedule_id = %d",
		schedule_id)->name, string db) {
    mixed err = catch {
	mapping lt = localtime(time(1));
	string dir = roxen_path(base_dir + "/" + db + "-" + isodate(time(1)) +
				sprintf("T%02d-%02d", lt->hour, lt->min));

	switch(backup_info[0]->method) {
	default:
	  report_error("Unsupported database backup method: %O for DB %O\n"
		       "Falling back to the default \"mysqldump\" method.\n",
		       backup_info[0]->method, db);
	  // FALL_THROUGH
	case "mysqldump":
	  dump(db, dir, "timed_backup");
	  break;
	case "backup":
	  backup(db, dir, "timed_backup");
	  break;
	}
	int generations = (int)backup_info[0]->generations;
	if (generations) {
	  foreach(query("SELECT directory FROM db_backups "
			" WHERE db = %s "
			"   AND tag = %s "
			" GROUP BY directory "
			" ORDER BY whn DESC "
			" LIMIT %d, 65536",
			db, "timed_backup", generations)->directory,
		  string dir) {
	    report_notice("Removing old backup %O of DB %O...\n",
			  dir, db);
	    delete_backup(db, dir);
	  }
	}
      };
    if (err) {
      master()->handle_error(err);
      err = catch {
	  if (has_prefix(err[0], "Unsupported ")) {
	    report_error("Disabling timed backup of database %s.\n", db);
	    query("UPDATE dbs "
		  "   SET schedule_id = NULL "
		  " WHERE name = %s ",
		  db);
	  }
	};
      if (err) {
	master()->handle_error(err);
      }
    }
  }

  report_notice("Database backup according to schedule %s completed.\n",
		backup_info[0]->schedule);

  start_backup_timer(schedule_id, (int)backup_info[0]->period,
		     (int)backup_info[0]->offset);
}

//! Set (and restart) a backup schedule.
//!
//! @param schedule_id
//!   Backup schedule to configure.
//! @param period
//!   Backup interval. @expr{0@} (zero) to disable automatic backups.
//! @param offset
//!   Backup interval offset.
//!
//! See @[start_backup_timer()] for details about @[period] and @[offset].
//!
//! @seealso
//!   @[start_backup_timer()]
void low_set_backup_timer(int schedule_id, int period, int offset)
{
  query("UPDATE db_schedules "
	"   SET period = %d, "
	"       offset = %d "
	" WHERE id = %d",
	period, offset, schedule_id);

  start_backup_timer(schedule_id, period, offset);
}

//! Set (and restart) a backup schedule.
//!
//! @param schedule_id
//!   Backup schedule to configure.
//! @param period
//!   Backup interval in seconds.
//!   Typically @expr{604800@} (weekly) or @expr{86400@} (dayly),
//!   or @expr{0@} (zero - disabled).
//! @param weekday
//!   Day of week to perform backups on (if weekly backups).
//!   @expr{0@} (zero) or @expr{7@} for Sunday.
//! @param tod
//!   Time of day in seconds to perform the backup.
//!
//! @seealso
//!   @[low_set_backup_timer()]
void set_backup_timer(int schedule_id, int period, int weekday, int tod)
{
  low_set_backup_timer(schedule_id, period, tod + ((weekday + 3)%7)*86400);
}

//! (Re-)start the timer for a backup schedule.
//!
//! @param schedule_id
//!   Backup schedule to (re-)start.
//! @param period
//!   Backup interval in seconds (example: @expr{604800@} for weekly).
//!   Specifying a period of @expr{0@} (zero) disables the backup timer
//!   for the database temporarily (until the next call or server restart).
//! @param offset
//!   Offset in seconds from Thursday 1970-01-01 00:00:00 local time
//!   for the backup period (example: @expr{266400@} (@expr{3*86400 + 2*3600@})
//!   for Sundays at 02:00).
//!
//! @seealso
//!   @[timed_backup()], @[start_backup_timers()]
void start_backup_timer(int schedule_id, int period, int offset)
{
  mixed co = m_delete(backup_cos, schedule_id);
  if (co) remove_call_out(co);

  if (!period) return;

  int t = -time(1);
  mapping(string:int) lt = localtime(-t);
  t += offset + lt->timezone;
  t %= period;

  if (!t) t += period;

  backup_cos[schedule_id] =
    roxenp()->background_run(t, timed_backup, schedule_id);
}

//! (Re-)start backup timers for all databases.
//!
//! This function calls @[start_backup_timer()] for
//! all configured databases.
//!
//! @seealso
//!   @[start_backup_timer()]
void start_backup_timers()
{
  foreach(query("SELECT id, schedule, period, offset "
		"  FROM db_schedules "
		" WHERE period > 0 "
		" ORDER BY id ASC"),
	  mapping(string:string) backup_info) {
    report_notice("Starting the backup timer for the %s backup schedule.\n",
		  backup_info->schedule);
    start_backup_timer((int)backup_info->id, (int)backup_info->period,
		       (int)backup_info->offset);
  }
}
#endif

void rename_db( string oname, string nname )
//! Rename a database. Please note that the actual data (in the case of
//! internal database) is not copied. The old database is deleted,
//! however. For external databases, only the metadata is modified, no
//! attempt is made to alter the external database.
{
  query( "UPDATE dbs SET name=%s WHERE name=%s", oname, nname );
  query( "UPDATE db_permissions SET db=%s WHERE db=%s", oname, nname );
  if( is_internal( oname ) )
  {
    Sql.Sql db = connect_to_my_mysql( 0, "mysql" );
    db->query("CREATE DATABASE IF NOT EXISTS %s",nname);
    db->query("UPDATE db SET Db=%s WHERE Db=%s",oname, nname );
    db->query("DROP DATABASE IF EXISTS %s",oname);
    query( "FLUSH PRIVILEGES" );
  }
  changed();
}

mapping get_group( string name )
{
  array r= query( "SELECT * FROM groups WHERE name=%s", name );
  if( sizeof( r ) )
    return r[0];
}

array(string) list_groups()
{
  return query( "SELECT name FROM groups" )->name;
}

int create_group( string name,    string lname,
		     string comment, string pattern )
{
  if( get_group( name ) )
  {
    query( "UPDATE groups SET comment=%s, pattern=%s, lname=%s "
	   "WHERE name=%s",  comment, pattern, lname, name );
  }
  else
  {
    query("INSERT INTO groups (comment,pattern,lname,name) "
	  "VALUES (%s,%s,%s,%s)", comment, pattern, lname, name );
  }
}

int delete_group( string name )
{
  if( !get_group( name ) )
    return 0;
  if( sizeof(group_dbs( name )) )
    return 0;
  query( "DELETE FROM groups WHERE name=%s", name );
  return 1;
}

array(string) group_dbs( string group )
{
  return query( "SELECT db FROM db_groups WHERE groupn=%s", group )
    ->db
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
      -({"roxen","mysql"})
#endif
    ;
}

string db_group( string db )
{
  array q =query( "SELECT groupn FROM db_groups WHERE db=%s", db );
  if( sizeof( q )  )
    return q[0]->groupn;
  return "internal";
}

string get_group_path( string db, string group )
{
  mapping m = get_group( group );
  if( !m )
    error("The group %O does not exist.", group );
  if( strlen( m->pattern ) )
  {
    catch
    {
      Sql.Sql sq = Sql.Sql( m->pattern+"mysql" );
      sq->query( "CREATE DATABASE "+db );
    };
    return m->pattern+db;
  }
  return 0;
}

void set_db_group( string db, string group )
{
  query("DELETE FROM db_groups WHERE db=%s", db);
  query("INSERT INTO db_groups (db,groupn) VALUES (%s,%s)",
	db, group );
}

void create_db( string name, string path, int is_internal,
		string|void group )
//! Create a new symbolic database alias.
//!
//! If @[is_internal] is specified, the database will be automatically
//! created if it does not exist, and the @[path] argument is ignored.
//!
//! If the database @[name] already exists, an error will be thrown
//!
//! If group is specified, the @[path] will be generated
//! automatically using the groups defined by @[create_group]
{
  if( get( name ) )
    error("The database "+name+" already exists\n");
  if( sizeof((array)name & ({ '@', ' ', '-', '&', '%', '\t',
			      '\n', '\r', '\\', '/', '\'', '"',
			      '(', ')', '*', '+', }) ) )
    error("Please do not use any of the characters @, -, &, /, \\ "
	  "or %% in database names.\nAlso avoid whitespace characters\n");
  if( has_value( name, "-" ) )
    name = replace( name, "-", "_" );
  if( group )
  {
    set_db_group( name, group );
    if( is_internal )
    {
    path = get_group_path( name, group );
    if( path )
      is_internal = 0;
    }
  }
  else
    query("INSERT INTO db_groups (db,groupn) VALUES (%s,%s)",
	  name, "internal" );

  query( "INSERT INTO dbs (name,path,local) VALUES (%s,%s,%s)", name,
	 (is_internal?name:path), (is_internal?"1":"0") );
#ifdef ENABLE_DB_BACKUPS
  if (!is_internal && !has_prefix(path, "mysql://")) {
    query("UPDATE dbs SET schedule_id = NULL WHERE name = %s", name);
  }
#endif
  if( is_internal )
    catch(query( "CREATE DATABASE `"+name+"`"));
  changed();
}

int set_external_permission( string name, Configuration c, int level,
			     string password )
//! Set the permission for the configuration @[c] on the database
//! @[name] to @[level] for an external tcp connection from 127.0.0.1
//! authenticated via password @[password].
//!
//! Levels:
//!  @int
//!    @value DBManager.NONE
//!      No access
//!    @value DBManager.READ
//!      Read access
//!    @value DBManager.WRITE
//!      Write access
//!  @endint
//!
//! @returns
//!  This function returns 0 if it fails. The only reason for it to
//!  fail is if there is no database with the specified @[name].
//!
//! @note
//!  This function is only valid for local databases.
//!
//! @seealso
//!  @[set_permission()], @[get_db_user()]
{
  array(mapping(string:mixed)) d =
           query("SELECT path,local FROM dbs WHERE name=%s", name );

  if( !sizeof( d ) )
      return 0;

  if( (int)d[0]["local"] )
    set_external_user_permissions( c, name, level, password );
  
  return 1;
}

int set_permission( string name, Configuration c, int level )
//! Set the permission for the configuration @[c] on the database
//! @[name] to @[level].
//!
//! Levels:
//!  @int
//!    @value DBManager.NONE
//!      No access
//!    @value DBManager.READ
//!      Read access
//!    @value DBManager.WRITE
//!      Write access
//!  @endint
//!
//!  Please note that for non-local databases, it's not really
//!  possible to differentiate between read and write permissions,
//!  roxen does try to do that anyway by checking the requests and
//!  disallowing anything but 'select' and 'show' from read only
//!  databases. Please note that this is not really all that secure.
//!
//!  From local (in the mysql used by Roxen) databases, the
//!  permissions are enforced by using different users, and should be
//!  secure as long as the permission system in mysql is not modified
//!  directly by the administrator.
//!
//! @returns
//!  This function returns 0 if it fails. The only reason for it to
//!  fail is if there is no database with the specified @[name].
{
  array(mapping(string:mixed)) d =
           query("SELECT path,local FROM dbs WHERE name=%s", name );

  if( !sizeof( d ) )
      return 0;

  query( "DELETE FROM db_permissions WHERE db=%s AND config=%s",
         name,CN(c->name) );

  query( "INSERT INTO db_permissions (db,config,permission) "
	 "VALUES (%s,%s,%s)", name,CN(c->name),
	 (level?level==2?"write":"read":"none") );
  
  if( (int)d[0]["local"] )
    set_user_permissions( c, name, level );

  clear_sql_caches();

  return 1;
}

mapping module_table_info( string db, string table )
{
  array td;
  if( sizeof(td=query("SELECT * FROM module_tables WHERE db=%s AND tbl=%s",
		      db, table ) ) )
    return td[0];
  return ([]);
}

string insert_statement( string db, string table, mapping row )
//! Convenience function.
{
  function q = cached_get( db )->quote;
  string res = "INSERT INTO "+table+" ";
  array(string) vi = ({});
  array(string) vv = ({});
  foreach( indices( row ), string r )
    if( !has_value( r, "." ) )
    {
      vi += ({r});
      vv += ({"'"+q(row[r])+"'"});
    }
  return res + "("+vi*","+") VALUES ("+vv*","+")";
}

void is_module_table( RoxenModule module, string db, string table,
		   string|void comment )
//! Tell the system that the table 'table' in the database 'db'
//! belongs to the module 'module'. The comment is optional, and will
//! be shown in the configuration interface if present.
{
  string mn = module ? module->sname(): "";
  string cn = module ? module->my_configuration()->name : "";
  catch(query("DELETE FROM module_tables WHERE "
	      "module=%s AND conf=%s AND tbl=%s AND db=%s",
	      mn,cn,table,db ));

  query("INSERT INTO module_tables (conf,module,db,tbl,comment) VALUES "
	"(%s,%s,%s,%s,%s)",
	cn,mn,db,table,comment||"" );
}

void is_module_db( RoxenModule module, string db, string|void comment )
//! Tell the system that the databse 'db' belongs to the module 'module'.
//! The comment is optional, and will be shown in the configuration
//! interface if present.
{
  is_module_table( module, db, "", comment );
}
  

static void create()
{
  mixed err = 
  catch {
    query("CREATE TABLE IF NOT EXISTS db_backups ("
	  " db varchar(80) not null, "
	  " tbl varchar(80) not null, "
	  " directory varchar(255) not null, "
	  " whn int unsigned not null, "
	  " tag varchar(20) null, "
	  " INDEX place (db,directory))");

    if (catch { query("SELECT tag FROM db_backups LIMIT 1"); }) {
      // The tag field is missing.
      // Upgraded Roxen?
      query("ALTER TABLE db_backups "
	    "  ADD tag varchar(20) null");
    }
       
  query("CREATE TABLE IF NOT EXISTS db_groups ("
	" db varchar(80) not null, "
	" groupn varchar(80) not null)");

  query("CREATE TABLE IF NOT EXISTS groups ( "
	"  name varchar(80) not null primary key, "
	"  lname varchar(80) not null, "
	"  comment blob not null, "
	"  pattern varchar(255) not null default '')");

  catch(query("INSERT INTO groups (name,lname,comment,pattern) VALUES "
      " ('internal','Uncategorized','Databases without any group','')"));

  query("CREATE TABLE IF NOT EXISTS module_tables ("
	"  conf varchar(80) not null, "
	"  module varchar(80) not null, "
	"  db   varchar(80) not null, "
	"  tbl varchar(80) not null, "
	"  comment blob not null, "
	"  INDEX place (db,tbl), "
	"  INDEX own (conf,module) "
	")");

#ifdef ENABLE_DB_BACKUPS
  query("CREATE TABLE IF NOT EXISTS db_schedules ("
	"id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, "
	"schedule VARCHAR(255) NOT NULL, "
	"dir VARCHAR(255) NULL, "
	"period INT UNSIGNED NOT NULL DEFAULT 604800, "
	"offset INT UNSIGNED NOT NULL DEFAULT 266400, "
	"generations INT UNSIGNED NOT NULL DEFAULT 1, "
	"method VARCHAR(20) NOT NULL DEFAULT 'mysqldump')");

  if (!sizeof(query("SELECT schedule "
		    "  FROM db_schedules "
		    " WHERE id = 1"))) {
    query("INSERT INTO db_schedules "
	  "       (id, schedule) "
	  "VALUES (1, 'Default')");
  }
#endif
    
  multiset q = (multiset)query( "SHOW TABLES" )->Tables_in_roxen;
  if( !q->dbs )
  {
    query( #"
CREATE TABLE dbs (
 name VARCHAR(64) NOT NULL PRIMARY KEY,
 path VARCHAR(100) NOT NULL, 
 local INT UNSIGNED NOT NULL"
#ifdef ENABLE_DB_BACKUPS
 #",
 schedule_id INT DEFAULT 1,
 INDEX schedule_id (schedule_id)"
#endif
 #")
 " );
    create_db( "local",  0, 1 );
    create_db( "roxen",  0, 1 );
    create_db( "mysql",  0, 1 );

    is_module_db( 0, "local",
		  "The local database contains data that "
		  "should not be shared between multiple-frontend servers" );
    is_module_db( 0, "roxen",
		  "The roxen database contains data about the other databases "
		  "in the server." );    
    is_module_db( 0, "mysql",
		  "The mysql database contains data about access "
		  "rights for the internal MySQL database." );
#ifdef ENABLE_DB_BACKUPS
  } else {
    if (catch { query("SELECT schedule_id FROM dbs LIMIT 1"); }) {
      // The schedule_id field is missing.
      // Upgraded Roxen?
      query("ALTER TABLE dbs "
	    "  ADD schedule_id INT DEFAULT 1, "
	    "  ADD INDEX schedule_id (schedule_id)");
      // Don't attempt to backup non-mysql databases.
      query("UPDATE dbs "
	    "   SET schedule_id = NULL "
	    " WHERE local = 0 "
	    "   AND path NOT LIKE 'mysql://%'");
    }
#endif
  }
  
  if( !q->db_permissions )
  {
    query(#"
CREATE TABLE db_permissions (
 db VARCHAR(64) NOT NULL, 
 config VARCHAR(80) NOT NULL, 
 permission ENUM ('none','read','write') NOT NULL,
 INDEX db_conf (db,config))
" );
    // Must be done from a call_out -- the configurations does not
    // exist yet (this code is called before 'main' is called in
    // roxen)
    call_out(
      lambda(){
	foreach( roxenp()->configurations, object c )
	{
	  set_permission( "local", c, WRITE );
	}
      }, 0 );
  }

	
  if( file_stat( "etc/docs.frm" ) )
  {
    if( !sizeof(query( "SELECT tbl FROM db_backups WHERE "
		       "db=%s AND directory=%s",
		       "docs", getcwd()+"/etc" ) ) )
      query("INSERT INTO db_backups (db,tbl,directory,whn) "
	    "VALUES ('docs','docs','"+getcwd()+"/etc','"+time()+"')");
  }

#ifdef ENABLE_DB_BACKUPS
  // Start the backup timers when we have finished booting.
  call_out(start_backup_timers, 0);
#endif
  
  return;
  };

  werror( describe_backtrace( err ) );
}
