#ifndef __OVS_OVERSIGHT_H__
#define __OVS_OVERSIGHT_H__

#ifdef OVS_MAIN
#define OVS_EXTERN(x,y) x = y
#else
#define OVS_EXTERN(x,y) extern x
#endif

#include "config.h"
#include "hashtable.h"
#include "array.h"

OVS_EXTERN(struct hashtable *g_query,NULL);
OVS_EXTERN(struct hashtable *g_oversight_config,NULL);
OVS_EXTERN(struct hashtable *g_unpack_config,NULL);
OVS_EXTERN(struct hashtable *g_catalog_config,NULL);
OVS_EXTERN(struct hashtable *g_nmt_settings,NULL);
OVS_EXTERN(struct hashtable *g_genre_hash,NULL);
OVS_EXTERN(Dimensions *g_dimension,NULL);
OVS_EXTERN(int g_local_browser,0);
OVS_EXTERN(Array *g_genre,NULL);
OVS_EXTERN(int html_log_level,0);
OVS_EXTERN(int g_playlist_count,0);
OVS_EXTERN(int g_movie_total,0);
OVS_EXTERN(int g_episode_total,0);
OVS_EXTERN(int g_other_media_total,0);

#define NVL(s) ((s)?(s):"")

#define OVS_VERSION "20090904-4BETA"

#define QUERY_PARAM_TYPE_FILTER "_tf"
#define QUERY_PARAM_WATCHED_FILTER "_wf"
#define QUERY_PARAM_TITLE_FILTER "_Tf"
#define QUERY_PARAM_GENRE "G"
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
#define NETWORK_SYMLINK "/opt/sybhttpd/default/.network"

char *get_mounted_path(char *source,char *path);

// Instead of converting timestamps to epoc time use a rough representation (see time_ordinal)
#define FAST_TIME

#endif
