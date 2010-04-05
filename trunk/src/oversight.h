#ifndef __OVS_OVERSIGHT_H__
#define __OVS_OVERSIGHT_H__

#ifdef OVS_MAIN
#define OVS_EXTERN(x,y) x = y
#define OVS_EXTERN1(x) x 
#else
#define OVS_EXTERN(x,y) extern x
#define OVS_EXTERN1(x) extern x
#endif

#include <time.h>
#include "config.h"
#include "hashtable.h"
#include "array.h"

#define NMT_PLAYLIST "/tmp/playlist.htm"
OVS_EXTERN(struct hashtable *g_query,NULL);
OVS_EXTERN(struct hashtable *g_oversight_config,NULL);
OVS_EXTERN(struct hashtable *g_unpack_config,NULL);
OVS_EXTERN(struct hashtable *g_catalog_config,NULL);
OVS_EXTERN(struct hashtable *g_nmt_settings,NULL);
OVS_EXTERN(struct hashtable *g_genre_hash,NULL);
OVS_EXTERN(struct hashtable *g_first_two_letters,NULL);
OVS_EXTERN(struct hashtable *g_delete_queue,NULL);

OVS_EXTERN(Dimensions *g_dimension,NULL);
OVS_EXTERN(int g_local_browser,0);
OVS_EXTERN(Array *g_genre,NULL);
OVS_EXTERN(int html_log_level,0);
OVS_EXTERN(int g_playlist_count,0);
OVS_EXTERN(int g_movie_total,0);
OVS_EXTERN(int g_episode_total,0);
OVS_EXTERN(int g_other_media_total,0);
OVS_EXTERN(time_t g_start_clock,0);

#define NUM_TITLE_LETTERS 256
OVS_EXTERN1(unsigned char g_title_letter_count[NUM_TITLE_LETTERS]);

#define NVL(s) ((s)?(s):"")
#define STRCMP(a,b) strcmp(NVL(a),NVL(b))
#define STRCASECMP(a,b) strcasecmp(NVL(a),NVL(b))

/*
#define OVS_VERSION "20091123-5BETA"
*/
#define VIEW_TV "tv"
#define VIEW_MOVIE "movie"
#define VIEW_TVBOXSET "tvboxset"
#define VIEW_MOVIEBOXSET "movieboxset"
#define VIEW_MIXED "mixed"
#define MENU_VIEW=1
#define TV_VIEW=2
#define MOVIE_VIEW=3
#define TVBOXSET_VIEW=10
#define MOVIEBOXSET_VIEW=11

#define QUERY_PARAM_VIEW "view"
#define QUERY_PARAM_SELECTED "i"
#define QUERY_PARAM_PAGE "p"
#define QUERY_PARAM_IDLIST "idlist"
#define QUERY_PARAM_EPISODE_TITLES "_et"
#define QUERY_PARAM_EPISODE_DATES "_ed"
#define QUERY_PARAM_TYPE_FILTER "_tf"
#define QUERY_PARAM_WATCHED_FILTER "_wf"
#define QUERY_PARAM_TITLE_FILTER "_Tf"
#define QUERY_PARAM_GENRE "G"
#define QUERY_PARAM_SORT "s"
#define QUERY_PARAM_SEASON "_sn"
#define QUERY_PARAM_REGEX "_rf"
#define QUERY_PARAM_SEARCH_MODE "_sm"
#define QUERY_PARAM_CHECKBOX_PREFIX "cb_"

#define QUERY_PARAM_WATCHED_VALUE_NO "U"
#define QUERY_PARAM_WATCHED_VALUE_YES "W"

#define QUERY_PARAM_MEDIA_TYPE_VALUE_TV "T"
#define QUERY_PARAM_MEDIA_TYPE_VALUE_MOVIE "M"

#define NETWORK_SHARE "/opt/sybhttpd/localhost.drives/NETWORK_SHARE/"
#define NETWORK_SYMLINK "/opt/sybhttpd/default/.network"

#define NON_EMPTY_STR(str) ((str) && (*(str)))
#define EMPTY_STR(str) ((str) == NULL || (*(str)) == '\0')
#define IFEMPTY(s,alt) (EMPTY_STR(s)?(alt):(s))

#define NAME_FILTER_REGEX_FLAG "R"
#define NAME_FILTER_STRING_FLAG "S"
char *get_mounted_path(char *source,char *path,int *freeit);

#define STARTS_WITH_THE(a) ( ((a) != NULL) \
        && ( (a)[0]=='T' || (a)[0]=='t' ) \
        && ( (a)[1]=='h' || (a)[1]=='H' ) \
        && ( (a)[2]=='e' || (a)[2]=='E' ) \
        && (a)[3] == ' ' )

// Instead of converting timestamps to epoc time use a rough representation (see time_ordinal)
#define FAST_TIME

#define USER_AGENT "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20040613 Firefox/0.8.0+"

#endif
