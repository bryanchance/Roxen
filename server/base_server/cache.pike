string cvs_version = "$Id: cache.pike,v 1.3 1996/12/10 04:13:32 per Exp $";
#include <config.h>

inherit "roxenlib";

#define TIMESTAMP 0
#define DATA 1

#define ENTRY_SIZE 2

#define CACHE_TIME_OUT 2000

#if DEBUG_LEVEL > 8
#ifndef CACHE_DEBUG
#define CACHE_DEBUG
#endif
#endif

mapping cache;
mapping hits=([]), all=([]);

mixed cache_lookup(string in, string what)
{
#ifdef CACHE_DEBUG
  perror(sprintf("CACHE: cache_lookup(\"%s\",\"%s\")  ->  ", in, what));
#endif
  all[in]++;
  if(cache[in] && cache[in][what])
  {
#ifdef CACHE_DEBUG
    perror("Hit\n");
#endif
    hits[in]++;
    cache[in][what][TIMESTAMP]=time(0);
    return cache[in][what][DATA];
  }
#ifdef CACHE_DEBUG
  perror("Miss\n");
#endif
  return 0;
}

string status()
{
  string res, a;
  res = "<table border=0 cellspacing=0 cellpadding=2><tr bgcolor=darkblue>"
    "<th align=left>Class</th><th align=left>Entries</th><th align=left>Memory used (KB)</th><th align=left>Hitrate</th></tr>";
  array c, b;
  b=indices(cache);
  c=map_array(values(cache), get_size);
  sort(c,b);
  int n, totale, totalm, totalh, mem, totalr;
  foreach(reverse(b), a)
  {
    res += "<tr align=right bgcolor="+(n/3%2?"black":"#000033")+"><td align=left>"+a+"</td><td>"+sizeof(cache[a])+"</td><td>"
      + ((mem=get_size(cache[a]))/1024) + "</td>";
    if(all[a])
      res += "<td>"+(hits[a]*100)/all[a]+"%</td>";
    else
      res += "<td>0%</td>";
    res += "</tr>";
    totale += sizeof(cache[a]);
    totalm += mem;
    totalh += hits[a];
    totalr += all[a];
  }
  res += "<tr align=right bgcolor=darkblue><td align=left>Total</td><td>"+totale+"</td><td>" + (totalm/1024) + "</td>";
    if(totalr)
      res += "<td>"+(totalh*100)/totalr+"%</td>";
    else
      res += "<td>0%</td>";
    res += "</tr>";
  return res + "</table>";
}

void cache_remove(string in, string what)
{
#ifdef CACHE_DEBUG
  perror(sprintf("CACHE: cache_remove(\"%s\",\"%O\")\n", in, what));
#endif
  if(!what)
    m_delete(cache, in);
  else
    if(cache[in]) 
      m_delete(cache[in], what);
}

void cache_set(string in, string what, mixed to)
{
#ifdef CACHE_DEBUG
  perror(sprintf("CACHE: cache_set(\"%s\", \"%s\", %O)\n",
		 in, what, to));
#endif
  if(!cache[in])
    cache[in]=([ ]);
  cache[in][what] = allocate(ENTRY_SIZE);
  cache[in][what][DATA] = to;
  cache[in][what][TIMESTAMP] = time(0);
}

void cache_clean()
{
  string a, b;
  int cache_time_out=CACHE_TIME_OUT;
#ifdef CACHE_DEBUG
  perror("CACHE: cache_clean()\n");
#endif
#ifdef CACHE_DEBUG
  perror("CACHE: Before cleaning\n");
  perror("CACHE: "+status()/"\n"*"\nCACHE: "+"\n");
#endif
  foreach(indices(cache), a)
  {
#ifdef CACHE_DEBUG
#if DEBUG_LEVEL > 40
    perror("CACHE:   Class  " + a + "\n");
#endif
#endif
    foreach(indices(cache[a]), b)
    {
#ifdef CACHE_DEBUG
#if DEBUG_LEVEL > 40
      perror("CACHE:      " + b + " ");
#endif
#endif
      if(!intp(cache[a][b][TIMESTAMP]))
	error("Illegal timestamp in cache ("+a+":"+b+")\n");
#endif
      if(cache[a][b][TIMESTAMP] < (time(0) - cache_time_out))
      {
#ifdef CACHE_DEBUG
#if DEBUG_LEVEL > 40
	perror("DELETED\n");
#endif
#endif	
	m_delete(cache[a], b);
      }
#ifdef CACHE_DEBUG
#if DEBUG_LEVEL > 40
      else
	perror("Ok\n");
#endif
#endif	
      if(!sizeof(cache[a]))
      {
#ifdef CACHE_DEBUG
#if DEBUG_LEVEL > 40
	perror("CACHE:    Class DELETED.\n");
#endif
#endif
	m_delete(cache, a);
      }
    }
  }
#ifdef CACHE_DEBUG
  perror("CACHE: After cleaning\n");
  perror("CACHE: "+status()/"\n"*"\nCACHE: "+"\n");
#endif
  call_out(cache_clean, 1000);
}

void create()
{
#ifdef CACHE_DEBUG
  perror("CACHE: Now online.\n");
#endif
  cache=([  ]);
  add_efun("cache_lookup", cache_lookup);
  add_efun("cache_set", cache_set);
  add_efun("cache_remove", cache_remove);
  call_out(cache_clean, 10);
}

 

