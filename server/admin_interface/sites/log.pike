inherit "../logutil.pike";
#include <config.h>

string parse(RequestID id)
{
  mapping log = roxen->error_log;
  array report = indices(log), r2;

  last_time=0;
  r2 = map(values(log),lambda(array a){
     return id->variables->reversed?-a[-1]:a[0];
  });
  sort(r2,report);
  for(int i=0;i<min(sizeof(report),1000);i++) 
     report[i] = describe_error(report[i], log[report[i]],
				id->misc->cf_locale, 2);
  if( sizeof( report ) >= 1000 )
    report[1000] =
      sprintf("%d entries skipped. Present in log on disk",
	      sizeof( report )-999 );
  return "</dl>"+(sizeof(report)?(report[..1000]*""):"Empty<dl>";
}
