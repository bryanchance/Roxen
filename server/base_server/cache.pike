// This file is part of Roxen Webserver.
// Copyright � 1996 - 2000, Roxen IS.
// $Id: cache.pike,v 1.64 2001/03/11 18:48:39 nilsson Exp $

#pragma strict_types

#include <roxen.h>
#include <config.h>

// A cache entry is an array with four elements
#define ENTRY_SIZE 4
// The elements are as follows:
// A timestamp when the entry was last used
#define TIMESTAMP 0
// The actual data
#define DATA 1
// A timeout telling when the data is no longer valid.
#define TIMEOUT 2
// The size of the entry, in byts.
#define SIZE 3

#undef CACHE_WERR
#ifdef CACHE_DEBUG
# define CACHE_WERR(X) report_debug("CACHE: "+X+"\n");
#else
# define CACHE_WERR(X)
#endif

#undef MORE_CACHE_WERR
#ifdef MORE_CACHE_DEBUG
# define MORE_CACHE_WERR(X) report_debug("CACHE: "+X+"\n");
#else
# define MORE_CACHE_WERR(X)
#endif

// The actual cache along with some statistics mappings.
static mapping(string:mapping(string:array)) cache;
static mapping(string:int) hits=([]), all=([]);

void flush_memory_cache() {
  cache=([]);
  hits=([]);
  all=([]);
}

// Calculates the size of an entry, though it isn't very good at it.
constant svalsize = 4*4; // if pointers are 4 bytes..
int get_size(mixed x, void|int iter)
{
  if(iter++>20) {
    CACHE_WERR("Too deep recursion when examining entry size.\n");
    return 0;
  }
  if(mappingp(x))
    return svalsize + 64 + get_size(indices([mapping]x), iter) +
      get_size(values([mapping]x), iter);
  else if(stringp(x))
    return strlen([string]x)+svalsize;
  else if(arrayp(x))
  {
    int i;
    foreach([array]x, mixed f)
      i += get_size(f,iter);
    return svalsize + 4 + i;    // (base) + arraysize
  } else if(multisetp(x)) {
    int i;
    foreach(indices([multiset]x), mixed f)
      i += get_size(f,iter);
    return svalsize + i;    // (base) + arraysize
  } else if(objectp(x) || functionp(x)) {
    return svalsize + 128; // (base) + object struct + some extra.
    // _Should_ consider size of global variables / refcount
  }
  return svalsize; // base
}

// Expire a whole cache
void cache_expire(string in)
{
  CACHE_WERR(sprintf("cache_expire(\"%s\")", in));
  m_delete(cache, in);
}

// Lookup an entry in a cache
mixed cache_lookup(string in, string what)
{
  CACHE_WERR(sprintf("cache_lookup(\"%s\",\"%s\")  ->  ", in, what));
  all[in]++;
  int t=time(1);
  // Does the entry exist at all?
  if(array entry = (cache[in] && cache[in][what]) )
    // Is it time outed?
    if (entry[TIMEOUT] && entry[TIMEOUT] < t) {
      m_delete (cache[in], what);
      CACHE_WERR("Timed out");
    }
    else {
      // Update the timestamp and hits counter and return the value.
      cache[in][what][TIMESTAMP]=t;
      CACHE_WERR("Hit");
      hits[in]++;
      return entry[DATA];
    }
  else CACHE_WERR("Miss");
  return ([])[0];
}

// Return all indices used by a given cache or indices of available caches
array(string) cache_indices(string|void in)
{
  if (in)
    return (cache[in] && indices(cache[in])) || ({ });
  else
    return indices(cache);
}

// Return some fancy cache statistics.
mapping(string:array(int)) status()
{
  mapping(string:array(int)) ret = ([ ]);
  foreach(indices(cache), string name) {
    //  We only show names up to the first ":" if present. This lets us
    //  group entries together in the status table.
    string show_name = (name / ":")[0];
    array(int) entry = ({ sizeof(cache[name]),
			  hits[name],
			  all[name],
			  get_size(cache[name]) });
    if (!zero_type(ret[show_name]))
      for (int idx = 0; idx < 3; idx++)
	ret[show_name][idx] += entry[idx];
    else
      ret[show_name] = entry;
  }
  return ret;
}

// Remove an entry from the cache. Removes the entire cache if no
// entry key is given.
void cache_remove(string in, string what)
{
  CACHE_WERR(sprintf("cache_remove(\"%s\",\"%O\")", in, what));
  if(!what)
    m_delete(cache, in);
  else
    if(cache[in])
      m_delete(cache[in], what);
}

// Add an entry to a cache
mixed cache_set(string in, string what, mixed to, int|void tm)
{
#if MORE_CACHE_DEBUG
  CACHE_WERR(sprintf("cache_set(\"%s\", \"%s\", %O)\n",
		     in, what, to));
#else
  CACHE_WERR(sprintf("cache_set(\"%s\", \"%s\", %t)\n",
		     in, what, to));
#endif
  int t=time(1);
  if(!cache[in])
    cache[in]=([ ]);
  cache[in][what] = allocate(ENTRY_SIZE);
  cache[in][what][DATA] = to;
  if(tm) cache[in][what][TIMEOUT] = t + tm;
  cache[in][what][TIMESTAMP] = t;
  return to;
}

// Clean the cache.
void cache_clean()
{
  remove_call_out(cache_clean);
  int gc_time=[int](([function(string:mixed)]roxenp()->query)("mem_cache_gc"));
  string a, b;
  array c;
  int t=time(1);
  CACHE_WERR("cache_clean()");
  foreach(indices(cache), a)
  {
    MORE_CACHE_WERR("  Class  " + a);
    foreach(indices(cache[a]), b)
    {
      MORE_CACHE_WERR("     " + b + " ");
      c = cache[a][b];
#ifdef DEBUG
      if(!intp(c[TIMESTAMP]))
	error("     Illegal timestamp in cache ("+a+":"+b+")\n");
#endif
      if(c[TIMEOUT] && c[TIMEOUT] < t) {
	MORE_CACHE_WERR("     DELETED (explicit timeout)");
	m_delete(cache[a], b);
      }
      else {
	if(!c[SIZE]) {
	  c[SIZE]=(get_size(b) + get_size(c[DATA]) + 5*svalsize + 4)/100;
	  // (Entry size + cache overhead) / arbitrary factor
          MORE_CACHE_WERR("     Cache entry size percieved as " +
			  ([int]c[SIZE]*100) + " bytes\n");
	}
	if(c[TIMESTAMP]+1 < t && c[TIMESTAMP] + gc_time -
	   c[SIZE] < t)
	  {
	    MORE_CACHE_WERR("     DELETED");
	    m_delete(cache[a], b);
	  }
#ifdef MORE_CACHE_DEBUG
	else
	  CACHE_WERR("Ok");
#endif
      }
      if(!sizeof(cache[a]))
      {
	MORE_CACHE_WERR("  Class DELETED.");
	m_delete(cache, a);
      }
    }
  }
  call_out(cache_clean, gc_time);
}


// --- Session cache -----------------

#ifndef SESSION_BUCKETS
# define SESSION_BUCKETS 4
#endif
#ifndef SESSION_SHIFT_TIME
# define SESSION_SHIFT_TIME 30
#endif

// The minimum time until which the session should be stored.
private mapping(string:int) session_persistence;
// The sessions, divided into several buckets.
private array(mapping(string:mixed)) session_buckets;
// The database for storage of the sessions.
private Sql.Sql db;
// The biggest value in session_persistence
private int max_persistence;

// The low level call for storing a session in the database
private void store_session(string id, mixed data, int t) {
  data = encode_value(data);
  if(catch(db->query("INSERT INTO session_cache VALUES (%s," +
		     t + ",%s)", id, data)))
    db->query("UPDATE session_cache SET data=%s, persistence=" +
	      t + " WHERE id=%s", data, id);
}

// GC that, depending on the sessions session_persistence either
// throw the session away or store it in a database.
private void session_cache_handler() {
  remove_call_out(session_cache_handler);
  int t=time(1);
  if(max_persistence>t) {

  clean:
    foreach(indices(session_buckets[-1]), string id) {
      if(session_persistence[id]<t) {
	m_delete(session_buckets[-1], id);
	m_delete(session_persistence, id);
	continue;
      }
      for(int i; i<SESSION_BUCKETS-2; i++)
	if(session_buckets[i][id]) {
	  continue clean;
	}
      if(objectp(session_buckets[-1][id])) {
	m_delete(session_buckets[-1], id);
	m_delete(session_persistence, id);
	continue;
      }
      store_session(id, session_buckets[-1][id], session_persistence[id]);
      m_delete(session_buckets[-1], id);
      m_delete(session_persistence, id);
    }
  }

  session_buckets = ({ ([]) }) + session_buckets[..SESSION_BUCKETS-2];
  call_out(session_cache_handler, SESSION_SHIFT_TIME);
}

// Stores all sessions that should be persistent in the database.
// This function is called upon exit.
private void session_cache_destruct() {
  remove_call_out(session_cache_handler);
  int t=time(1);
  if(max_persistence>t) {
    report_notice("Synchronizing session cache");
    foreach(session_buckets, mapping(string:mixed) session_bucket)
      foreach(indices(session_bucket), string id)
	if(session_persistence[id]>t) {
	  store_session(id, session_bucket[id], session_persistence[id]);
	  m_delete(session_persistence, id);
	}
  }
  report_notice("Session cache synchronized\n");
}

//! Returns the data associated with the session @[id].
//! Returns a zero type upon failure.
mixed get_session_data(string id) {
  mixed data;
  foreach(session_buckets, mapping bucket)
    if(data=bucket[id]) {
      session_buckets[0][id] = data;
      return data;
    }
  data = db->query("SELECT data FROM session_cache WHERE id=%s", id);
  if(sizeof([array]data) &&
     !catch(data=decode_value( ([array(mapping(string:string))]data)[0]->data )))
    return data;
  return ([])[0];
}

//! Assiciates the session @[id] to the @[data]. If no @[id] is provided
//! a unique id will be generated. The session id is returned from the
//! function. The minimum guaranteed storage time may be set with the
//! @[persistence] argument. Note that this is not a time out.
//! If @[store] is set, the @[data] will be stored in a database directly,
//! and not when the garbage collect tries to delete the data. This
//! will ensure that the data is kept safe in case the server crashes
//! before the next GC.
string set_session_data(mixed data, void|string id, void|int persistence,
			void|int(0..1) store) {
  if(!id) id = ([function(void:string)]roxenp()->create_unique_id)();
  session_persistence[id] = persistence;
  session_buckets[0][id] = data;
  max_persistence = max(max_persistence, persistence);
  if(store && persistence) store_session(id, data, persistence);
  return id;
}

// Sets up the session database tables.
private void setup_tables() {
    if(catch(db->query("select id from session_cache where id=''"))) {
      db->query("CREATE TABLE session_cache ("
                "id CHAR(32) NOT NULL PRIMARY KEY, "
		"persistence INT UNSIGNED NOT NULL DEFAULT 0, "
                "data BLOB NOT NULL)");
    }
}

//! Initializes the session handler.
void init_session_cache() {
  db = ([function(string:object(Sql.Sql))]master()->resolv("DBManager.get"))("local");
  if( !db )
    report_fatal("No 'shared' database!\n");
  setup_tables();
}

void create()
{
  add_constant( "cache", this_object() );
  cache = ([ ]);
  call_out(cache_clean, 60);

  session_buckets = ({ ([]) }) * SESSION_BUCKETS;
  session_persistence = ([]);
  call_out(session_cache_handler, SESSION_SHIFT_TIME);

  CACHE_WERR("Now online.");
}

void destroy() {
  session_cache_destruct();
  return;
}
