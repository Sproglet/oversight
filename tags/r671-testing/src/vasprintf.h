#ifndef __OVS_VASPRINTF__GNU__
#define __OVS_VASPRINTF__GNU__
#include "stdarg.h"
int ovs_asprintf (char **result, char *format, ...);
int ovs_vasprintf ( char **result, char *format, va_list args);
#endif
