/*
 * Locale stuff.
 * <locale-token project="roxen_config"> _ </locale-token>
 */
#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

constant box      = "large";
constant box_initial = 1;

constant box_position = -1;

String box_name = _(0,"Welcome message");
String box_doc  = _(0,"Roxen welcome message and news");

string parse( RequestID id )
{
  return "<eval><insert file=\"welcome.txt\" /></eval>";
}
