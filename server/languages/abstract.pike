/*
 * name = "Abstract language class";
 * doc = "Handles the conversion of numbers and dates. You have to restart the server for updates to take effect.";
 */

// Array(string) with the months of the year, beginning with January
constant months = ({ "", "", "", "", "", "", "", "", "", "", "", "" });

// Array(string) with the days of the week, beginning with Sunday
constant days = ({ "", "", "", "", "", "", "" });

// Array(string) with all the language's identifiers
constant _aliases = ({});

// Array(string) with language code, the language in english
// and the native language description.
constant _id = ({ "??", "Unknown", "Unknown" });

constant languages = ([]);

array id()
{
  return _id;
}

string month(int num)
{
  return months[ num - 1 ];
}

string day(int num)
{
  return days[ num - 1 ];
}

array aliases()
{
  return _aliases;
}

string language(string code)
{
#if constant(Standards.ISO639_2)
  if(sizeof(code)==2)
    code=Standards.ISO639_2.map_639_1(code);
  if(sizeof(code)!=3) return 0;
  if(languages[code]) return languages[code];
  return Standards.ISO639_2.get_language(code);
#else
  if(sizeof(code)==2)
    code=RoxenLocale.ISO639_2.map_639_1(code);
  if(sizeof(code)!=3) return 0;
  if(languages[code]) return languages[code];
  return RoxenLocale.ISO639_2.get_language(code);
#endif
}

mapping list_languages()
{
#if constant(Standards.ISO639_2)
  mapping iso639_1=Standards.ISO639_2.list_639_1();
  return Standards.ISO639_2.list_languages()+
    mkmapping(indices(iso639_1), map(values(iso639_1), Standards.ISO639_2.get_language));
#else
  mapping iso639_1=RoxenLocale.ISO639_2.list_639_1();
  return RoxenLocale.ISO639_2.list_languages()+
    mkmapping(indices(iso639_1), map(values(iso639_1), RoxenLocale.ISO639_2.get_language));
#endif
}

string number(int i)
{
  return (string)i;
}

string ordered(int i)
{
  return (string)i;
}

string date(int i, mapping|void m)
{
  mapping lt=localtime(i);
  return sprintf("%4d-%02d-%02d", lt->year+1900, lt->mon+1, lt->mday);
}
