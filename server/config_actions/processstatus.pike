/*
 * $Id: processstatus.pike,v 1.1 1997/08/24 02:20:47 peter Exp $
 */

inherit "wizard";
constant name= "Status//Process status";

constant doc = ("Shows the vaious information about the pike process.");

constant more=1;

#define MB (1024*1024)

mixed page_0(object id, object mc)
{
  string res;
  int *ru, tmp, use_ru;

  if(catch(ru=rusage())) return 0;

  if(ru[0])
    tmp=ru[0]/(time(1) - roxen->start_time+1);

  return (/* "<font size=\"+1\"><a href=\""+ roxen->config_url()+
	     "Actions/?action=processstatus.pike&foo="+ time(1)+
	     "\">Process status</a></font>"+ */
	  "<pre>"
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

mixed handle(object id) { return wizard_for(id,0); }
