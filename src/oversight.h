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
#include <string.h>
#include "config.h"
#include "hashtable.h"
#include "array.h"
#include "types.h"

#define NMT_PLAYLIST "/tmp/playlist.htm"
OVS_EXTERN(struct hashtable *g_query,NULL);
OVS_EXTERN(struct hashtable *g_oversight_config,NULL);
OVS_EXTERN(struct hashtable *g_unpack_config,NULL);
OVS_EXTERN(struct hashtable *g_catalog_config,NULL);
OVS_EXTERN(struct hashtable *g_skin_config,NULL);
OVS_EXTERN(struct hashtable *g_nmt_settings,NULL);
OVS_EXTERN(struct hashtable *g_genre_hash,NULL);
OVS_EXTERN(struct hashtable *g_first_two_letters,NULL);
OVS_EXTERN(struct hashtable *g_delete_queue,NULL);
OVS_EXTERN(int g_item_count,0);

OVS_EXTERN(Dimensions *g_dimension,NULL);
#define IN_POSTER_MODE (g_dimension->poster_mode != 0) 
#define IN_TEXT_MODE (g_dimension->poster_mode == 0) 
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

#define QUERY_PARAM_VIEW "view"
#define QUERY_PARAM_PERSON_ROLE "role"

// Used in the resize view when QUERY_PARAM_ACTION=QUERY_PARAM_ACTION_VALUE_SET
#define QUERY_PARAM_SET_NAME "set_name"
#define QUERY_PARAM_SET_VAL "set_val"
#define QUERY_PARAM_SET_MIN "set_min"
#define QUERY_PARAM_SET_MAX "set_max"



#define QUERY_ASSIGN_PREFIX "*"

#define QUERY_PARAM_SELECTED "i"
#define QUERY_PARAM_PAGE "p"
#define QUERY_PARAM_IDLIST "idlist"
#define QUERY_PARAM_EPISODE_TITLES "_et"
#define QUERY_PARAM_EPISODE_DATES "_ed"
#define QUERY_PARAM_TYPE_FILTER "_tf"
#define QUERY_PARAM_RATING "_r"

#define QUERY_PARAM_LOCKED_FILTER "_lf"
#define QUERY_PARAM_LOCKED_VALUE_NO "0"
#define QUERY_PARAM_LOCKED_VALUE_YES "1"
#define QUERY_PARAM_LOCKED_VALUE_ANY "2"

#define QUERY_PARAM_WATCHED_FILTER "_wf"
#define QUERY_PARAM_WATCHED_VALUE_NO "0"
#define QUERY_PARAM_WATCHED_VALUE_YES "1"
#define QUERY_PARAM_WATCHED_VALUE_ANY "2"

#define QUERY_PARAM_TITLE_FILTER "_Tf"
#define QUERY_PARAM_GENRE "G"
#define QUERY_PARAM_SORT "s"
#define QUERY_PARAM_SEASON "_sn"
#define QUERY_PARAM_SEARCH_MODE "_sm"
#define QUERY_PARAM_CHECKBOX_PREFIX "cb_"
#define QUERY_PARAM_RESIZE "resizeon"
#define QUERY_PARAM_PERSON "P"

#define QUERY_PARAM_ACTION "action"
#define QUERY_PARAM_SUBVIEW "view2"
#define QUERY_PARAM_ACTION_VALUE_SET "set"

#define QUERY_PARAM_QUERY "q"

#define QUERY_PARAM_CONFIG_FILE "cfgf"
#define QUERY_PARAM_CONFIG_HELP "cfgh"
#define QUERY_PARAM_CONFIG_TITLE "cfgt"

#define QUERY_PARAM_SELECT "select"
#define FORM_PARAM_SELECT_VALUE_DELETE "Delete"
#define FORM_PARAM_SELECT_VALUE_MARK "Mark"
#define FORM_PARAM_SELECT_VALUE_LOCK "Lock"


#define QUERY_PARAM_MEDIA_TYPE_VALUE_OTHER "O"
#define QUERY_PARAM_MEDIA_TYPE_VALUE_TV "T"
#define QUERY_PARAM_MEDIA_TYPE_VALUE_MOVIE "M"

#define NETWORK_SHARE "/opt/sybhttpd/localhost.drives/NETWORK_SHARE/"
#define NETWORK_SYMLINK "/opt/sybhttpd/default/.network"

#define NON_EMPTY_STR(str) ((str) && (*(str)))
#define EMPTY_STR(str) ((str) == NULL || (*(char *)(str)) == '\0')
#define IFEMPTY(s,alt) (EMPTY_STR(s)?(alt):(s))

#define NAME_FILTER_REGEX_FLAG "R"
#define NAME_FILTER_STRING_FLAG "S"
char *get_mounted_path(char *source,char *path,int *freeit);

#define STARTS_WITH_THE(a) ( ((a) != NULL) \
        && (a)[3] == ' ' \
        && ( (a)[0]=='T' || (a)[0]=='t' ) \
        && ( (a)[1]=='h' || (a)[1]=='H' ) \
        && ( (a)[2]=='e' || (a)[2]=='E' ))

// Instead of converting timestamps to epoc time use a rough representation (see time_ordinal)
#define FAST_TIME

#define USER_AGENT "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20040613 Firefox/0.8.0+"

#define COPY_STRING(len,from) ((from)?memcpy(CALLOC((len)+1,1),(from),(len)):NULL)

#define QUERY_RESIZE_DIM_ACTION "reset_dimensions"
#define QUERY_RESIZE_DIM_SET_NAME "dimension_set"
#define QUERY_RESIZE_DIM_SET_GRID "grid"
#define QUERY_RESIZE_DIM_SET_IMAGE "image"
#define QUERY_START_CELL "start_cell"
//
// Value to represent an inherited dimension. ie for tvboxsets use the main menu dimensions,
#define INHERIT_DIMENSION -1
#define INHERIT_DIMENSION_STR "-1"

OVS_EXTERN(ViewMode **g_view_modes,NULL);
OVS_EXTERN1(ViewMode *VIEW_ADMIN);
OVS_EXTERN1(ViewMode *VIEW_TV);
OVS_EXTERN1(ViewMode *VIEW_MOVIE);
OVS_EXTERN1(ViewMode *VIEW_OTHER);
OVS_EXTERN1(ViewMode *VIEW_PERSON);
OVS_EXTERN1(ViewMode *VIEW_TVBOXSET);
OVS_EXTERN1(ViewMode *VIEW_MOVIEBOXSET);
OVS_EXTERN1(ViewMode *VIEW_MENU);
OVS_EXTERN1(ViewMode *VIEW_MIXED);

OVS_EXTERN(long g_tvboxset_mode,-1);
OVS_EXTERN(MovieBoxsetMode g_moviebox_mode,MOVIE_BOXSETS_UNSET);

#endif

