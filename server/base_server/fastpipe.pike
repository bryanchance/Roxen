// Pipe using sendfile, if possible.
// by Francesco Chemolli, based upon work by Per Hedbor and others.
// Copyright � 1999 - 2000, Roxen IS.

constant cvs_version="$Id: fastpipe.pike,v 1.7 2001/03/12 14:05:33 nilsson Exp $";

private array(string) headers=({});
private Stdio.File file;
private int flen=-1;
private int sent=0;
private function done_callback;
private array(mixed) callback_args;

//API functions
int bytes_sent() 
{
  return sent;
}

private void sendfile_done(int written, function callback, array(mixed) args) 
{
  sent=written;
  headers=({});
  file=0;
  flen=-1;
  if( done_callback ) done_callback(@callback_args);
  done_callback=0; callback_args=0;
}

void output (Stdio.File fd)
{
  // FIXME: timeout handling!
//   report_debug( "%O\n", ({strlen(headers[0]),file,-1,flen,0,fd,sendfile_done}) );
  Stdio.sendfile(headers,file,-1,flen,0,fd,sendfile_done);
}

void input (Stdio.File what, int len)
{
  if (file)
    error("HTTP-fastpipe: Multiple result files are not supported!\n");
  file=what;
  flen=len||-1;
}

void write(string what)
{
  headers+=({what});
}

void set_done_callback(function|void f, void|mixed ... args)
{
  done_callback=f;
  callback_args=args;
}

