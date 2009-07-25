#ifndef __OVS_OVERSIGHT_H__
#define __OVS_OVERSIGHT_H__

#ifdef OVS_MAIN
#define OVS_EXTERN 
#else
#define OVS_EXTERN extern
#endif

#include "config.h"
#include "hashtable.h"

OVS_EXTERN struct hashtable *g_query;
OVS_EXTERN struct hashtable *g_oversight_config;
OVS_EXTERN struct hashtable *g_catalog_config;
OVS_EXTERN struct hashtable *g_nmt_settings;
OVS_EXTERN Dimensions *g_dimension;
OVS_EXTERN int g_local_browser;
#define OVS_VERSION "20090724-1BETA"

#define QUERY_PARAM_TYPE_FILTER "_tf"
#define QUERY_PARAM_WATCHED_FILTER "_wf"
#define QUERY_PARAM_SORT "s"
#define QUERY_PARAM_REGEX "_rf"
#define QUERY_PARAM_SEARCH_MODE "_sm"
#define QUERY_PARAM_CHECKBOX_PREFIX "cb_"

#define SELF_URL ""

#endif
