#ifndef __OVS_DBNAMES_H__
#define __OVS_DBNAMES_H__

#include "types.h"

Array *dbnames_fetch(char *key,char *file);
char *dbnames_fetch_static(char *key,char *file);

#endif
