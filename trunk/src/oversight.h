#ifndef __OVS_OVERSIGHT_H__
#define __OVS_OVERSIGHT_H__

#ifdef OVS_MAIN
#define OVS_EXTERN(x,y) x = y
#else
#define OVS_EXTERN(x,y) extern x
#endif

#include "config.h"
#include "hashtable.h"

OVS_EXTERN(struct hashtable *g_query,NULL);
OVS_EXTERN(struct hashtable *g_oversight_config,NULL);
OVS_EXTERN(struct hashtable *g_unpack_config,NULL);
OVS_EXTERN(struct hashtable *g_catalog_config,NULL);
OVS_EXTERN(struct hashtable *g_nmt_settings,NULL);
OVS_EXTERN(Dimensions *g_dimension,NULL);
OVS_EXTERN(int g_local_browser,0);
/*
OVS_EXTERN struct hashtable *g_query;
OVS_EXTERN struct hashtable *g_oversight_config;
OVS_EXTERN struct hashtable *g_unpack_config;
OVS_EXTERN struct hashtable *g_catalog_config;
OVS_EXTERN struct hashtable *g_nmt_settings;
OVS_EXTERN Dimensions *g_dimension;
OVS_EXTERN int g_local_browser;
*/
#define OVS_VERSION "20090814-1BETA"

#define QUERY_PARAM_TYPE_FILTER "_tf"
#define QUERY_PARAM_WATCHED_FILTER "_wf"
#define QUERY_PARAM_SORT "s"
#define QUERY_PARAM_REGEX "_rf"
#define QUERY_PARAM_SEARCH_MODE "_sm"
#define QUERY_PARAM_CHECKBOX_PREFIX "cb_"

#define QUERY_PARAM_WATCHED_VALUE_NO "U"
#define QUERY_PARAM_WATCHED_VALUE_YES "W"

#define QUERY_PARAM_MEDIA_TYPE_VALUE_TV "T"
#define QUERY_PARAM_MEDIA_TYPE_VALUE_MOVIE "M"

#define SELF_URL ""
#define NETWORK_SHARE "/opt/sybhttpd/localhost.drives/NETWORK_SHARE/"

char *get_mounted_path(char *source,char *path);

#endif
