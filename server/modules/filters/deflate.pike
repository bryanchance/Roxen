// This is a ChiliMoon module which provides auto-deflate compression support.
// Copyright (c) 2004-2005, Stephen R. van den Berg, The Netherlands.
//                     <srb@cuci.nl>
//
// This module is open source software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation; either version 2, or (at your option) any
// later version.
//

constant cvs_version =
 "$Id: deflate.pike,v 1.1 2004/05/22 17:45:30 _cvs_stephen Exp $";
constant thread_safe = 1;

#include <module.h>

inherit "module";

constant module_type = MODULE_FILTER;
LocaleString module_name = "Filters: Auto deflate";
LocaleString module_doc =  
 "This module provides the auto deflate filter.<br />"
 "<p>Copyright &copy; 2004-2005, by "
 "<a href='mailto:srb@cuci.nl'>Stephen R. van den Berg</a>, "
 "The Netherlands.</p>"
 "<p>This module is open source software; you can redistribute it and/or "
 "modify it under the terms of the GNU General Public License as published "
 "by the Free Software Foundation; either version 2, or (at your option) any "
 "later version.</p>";

void create() {
  set_module_creator("Stephen R. van den Berg <srb@cuci.nl>");
  defvar ("compressionlevel", 1,
        "Compressionlevel", TYPE_INT,
        "Use 1 for fast compression, use 9 for slow compression."
          );
  defvar ("minfilesize", 1024,
        "Minimum file size", TYPE_INT,
        "Any data below this size limit will be sent uncompressed."
          );
}

int before, after, nosupport, success, nowant;
float time_spent;
int timestart;

void start()
{ timestart=time(1);
}

string status()
{ return sprintf("Transferred: %.3fMiB ~ %.3fKiB/request<br />\n"
                 "Compression ratio: %.1f%%<br />\n"
                 "CPU time: %.3fs ~ %.3f%%<br />\n"
                 "Successful requests: %d<br />\n"
                 "Unsupported requests: %d<br />\n"
                 "Unwanted requests: %d<br />\n",
		 (float)after/(1024*1024), (float)after/(success||1)/1024,
		 (before-after)*100.0/(before||1),
		 time_spent, time_spent*100/(time(1)-timestart||1),
		 success,nosupport,nowant);
}

mapping filter( mapping result, RequestID id )
{
   int len;
   if( id->misc->internal_get
    || !result
    || !stringp(result->data)
    || id->misc->deflated
    || (len=sizeof(result->data))<query("minfilesize")
    || result->encoding                   // FIXME Does this catch CGI output?
     && (result->encoding=="deflate" || result->encoding=="gzip")
    || result->type
     && !has_prefix(result->type, "text/")
     && !has_prefix(result->type, "application/x-javascript"))
      return 0;

    id->misc->deflated = 1;
// FIXME This should be handled more delicately
// This module should probably be a new kind of breed LAST_FILTER:
// - It should adapt an existing Vary field, and it should
// - Not need to compress if a 304 response is about to be returned
// Send the Vary field even if not compressing, downstream proxies should
// know that we are looking at it
    result->extra_heads+=(["Vary":"Etag,Accept-Encoding"]);

    ;{ mixed accpt;
       if(!(accpt=id->request_headers["accept-encoding"])
        ||!has_value(accpt,"deflate"))
        { nosupport++;
          return 0;
        }
     }
    if(id->cookies->deflate=="0")
     { nowant++;
       return 0;
     }
    success++;
    before+=len;
    time_spent+=gauge {
     result->data =
      Gz.deflate(-query("compressionlevel"))->deflate(result->data);
    };
    after+=sizeof(result->data);
    result->encoding="deflate";
}
