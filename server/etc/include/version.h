// Version information
// $Id: version.h,v 1.975 2008/06/24 06:22:26 dist Exp $
// 
// Note that version information (major and minor) is also
// present in module.h.
constant __roxen_version__ = "5.0";
constant __roxen_build__ = "4";

#if !constant(roxen_release)
constant roxen_release = "-cvs";
#endif /* !constant(roxen_release) */

#ifdef __NT__
constant real_version= "Roxen/"+__roxen_version__+"."+__roxen_build__+" NT"+roxen_release;
#else
constant real_version= "Roxen/"+__roxen_version__+"."+__roxen_build__+roxen_release;
#endif
