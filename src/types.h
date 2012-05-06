#ifndef __OVS_TYPES_H__
#define __OVS_TYPES_H__

#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdio.h>
#include <regex.h>
//
// Types will be migrated here over time.


#define OVS_TIME unsigned long


typedef struct EnumString_struct {
    int id ;
    const char *str;
} EnumString;

typedef enum GridDirection_enum {
    GRID_ORDER_DEFAULT,
    GRID_ORDER_HORIZONTAL ,
    GRID_ORDER_VERTICAL
} GridDirection;

typedef struct array_str {
    void **array;
    int size;
    int mem_size;
    void (*free_fn)(void *);
} Array;

#define DB_MEDIA_TYPE_TV "T"
#define DB_MEDIA_TYPE_FILM "M"
#define DB_MEDIA_TYPE_ANY NULL
#define DB_MEDIA_TYPE_OTHER "O"



typedef struct ViewMode_struct {
    char *name;
    int view_class;
    int row_select; // How to select rows TV=by title_season tvboxset=by title  anything else by id;
    int has_playlist;
    char *dimension_cell_suffix; // get image dimensions from config file
    char *media_types;
    int (*default_sort)(); // how to sort elements of this view
    //int (*default_sort)(DbItem **item1,DbItem **item2); // how to sort elements of this view
    int (*item_eq_fn)(void *,void *); // used to build hashtable of items
    unsigned int (*item_hash_fn)(void *); // used to build hashtable of items
} ViewMode;

#define ROW_BY_ID 0
#define ROW_BY_TITLE 1
#define ROW_BY_SEASON 2

#define VIEW_CLASS_MENU 0
#define VIEW_CLASS_ADMIN 1
#define VIEW_CLASS_BOXSET 2
#define VIEW_CLASS_DETAIL 3


typedef struct Dbrowid_struct {

    long id;
    struct Db_struct *db;
    long offset;
    OVS_TIME date;
    int top250;
    int watched;
    int locked;
    char *title;
    char *orig_title;
    char *poster;
    char *genre;
    char *expanded_genre;
    char category;
    int season;

    // Add ext member etc but only populate if postermode=0 as the text mode has this extra detail
    char *file;
    char *ext;
    char *certificate;
    int year;
    int runtime;

    char *url;
    int external_id;

    /*
     * plot_key is derived from URL tt0000000
     * movie plot_key[MAIN]=_@tt0000000@@@_
     * tv plot_key[MAIN]=_@tt0000000@season@@_
     * tv plot_key[EPPLOT]=_@tt0000000@season@episode@_
     */
    char *plotkey[2];
    char *fanart;
    char *parts;
    char *episode;

    //only populate if deleting
    char *nfo;

    OVS_TIME airdate;
    OVS_TIME airdate_imdb;

    char *eptitle;
    char *eptitle_imdb;
    char *additional_nfo;
    double rating;

    OVS_TIME filetime;
    OVS_TIME downloadtime;

    //Only set if a row has a vodlink displayed and is added the the playlist
    Array *playlist_paths;
    Array *playlist_names;

    long plotoffset[2];
    char *plottext[2];

    // Set to 1 if item checked on HDD
    int delist_checked;

    // General flag
    int visited;

// warning TODO remove this link once lists are implemented
    struct Dbrowid_struct *linked;
    int link_count;

    // Space separated list of set ids - imdb sets are imdb:ttnnnnn = id of first movie , tmdb sets use collection id
    char *sets;
    Array *set_array; // sets split into array.

    struct DbGroupIMDB_struct *directors;
    struct DbGroupIMDB_struct *actors;
    struct DbGroupIMDB_struct *writers;

    // Set for first row in the list.
    // These fields will be moved to the ItemList structure once I create a list of Items
    // for each Grid position.
   // char *drilldown_view_static;
    ViewMode *drilldown_view;

    // Holds hash value 
    unsigned int tmp_hash;
    // Holds idlist text string for items in the grid
    char *idlist;

    int num_seasons; // If this item represents a boxset - this is total number of seasons.

    char *videosource; // DVDRIP, R5 , BluRay etc. Set via catalog script
    // Video info in a csv list - cN=codec,wN=width,hN=heigth,fN=fps for stream N
    char *video;

    // Audio info in a csv list - cN=codec,lN=language,chN=channels stream N
    char *audio;
    // Subtitle info in a csv list - lN=language
    char *subtitles;

    int sizemb;


    // For YAMJ emulation - XML outputs sub indexes for each item - presumable for mavigation between categories.
    Array * yamj_member_of;
} DbItem;

// GROUPS AND IMDB LISTS =========================================================================
//
// A Group of related rows. This may be :
// a movie boxset (a list of related imdb numbers)
// a tv box set. ( a Title and a Season. )
// a tv box series. ( a Title . )
// a custom group (A tag which will be stored against the item)
typedef enum DbGroupType_enum {
    DB_GROUP_BY_IMDB_LIST ,
    DB_GROUP_BY_NAME_TYPE_SEASON ,
    DB_GROUP_BY_CUSTOM_TAG
} DbGroupType;

typedef struct DbGroupIMDB_struct {
    int evaluated; // To improve page load performance groups are only evaluated when needed.
    char *raw; // Raw string for this group. This should be freed when the ids are evaluated.
    int raw_len;

    char *prefix; // tt or nm - do not free
    int dbgi_max_size;
    int dbgi_size;
    int *dbgi_ids;
    int dbgi_sorted;
} DbGroupIMDB;

typedef struct DbGroupNameSeason_struct {
    char *name;
    int type;
    int season;
} DbGroupNameSeason;

typedef struct DbGroupCustom_struct {
    char *dbgc_tag;
} DbGroupCustom;

typedef struct DbGroupDef_struct {
    DbGroupType dbg_type;
    union {
        DbGroupIMDB dbgi;
        DbGroupNameSeason dbgns;
        DbGroupCustom dbgc;
    } u;

} DbGroupDef;

// Expression  =============================================================================
//
typedef enum Op_enum {
    OP_CONSTANT=0,
    OP_ADD='+',
    OP_SUBTRACT='-',
    OP_MULTIPLY='*',
    OP_DIVIDE='/',
    OP_AND='&',
    OP_OR='O',
    OP_NOT='!',
    OP_EQ='=',
    OP_NE='~',
    OP_LE='{',
    OP_LT='<',
    OP_GT='>',
    OP_GE='}',
    OP_STARTS_WITH='^',
    OP_CONTAINS='#',
    OP_DBFIELD='_',
    OP_SPLIT='|',
    OP_LEFT='[',
    OP_THE='T',
    OP_PERIOD='p',

    OP_REGEX_CONTAINS='r',
    OP_REGEX_MATCH='R',
    OP_REGEX_STARTS_WITH='s'
} Op;

typedef enum ValType_enum {
    VAL_TYPE_NONE=0,
    VAL_TYPE_IMDB_LIST=1,
    VAL_TYPE_NUM=2,
    VAL_TYPE_STR=4,
    VAL_TYPE_CHAR=8,
    VAL_TYPE_LIST=16
} ValType;

typedef struct Value_struct {
    ValType type;
    double num_val;
    char *str_val;
    Array *list_val;
    // True if string or list values must be freed.
    int free_str;
    DbGroupIMDB *imdb_list_val;

} Value;

#define TOKEN_URL 0
#define TOKEN_PLAIN 1
typedef struct {
    Op op;
    char* token[2];
    int num_args;
    int precedence;
    int argtypes[2]; // Based on or'ed ValType argtype[0] is for first child eg  = VAL_TYPE_STR|VAL_TYPE_CHAR
} OpDetails;

typedef struct Exp_struct {

    OpDetails *op_details;
    struct Exp_struct *subexp[2]; // Child expressions for operators
    Value val; // Used for atomic values and working values when calculating

    // If op is a Regex function the regex details are held in the following fields.
    regex_t *regex;
    char *regex_str; // Holds string used to define regex

    // If op is OP_DBFIELD then field offset info is held here
    char fld_type;
    int fld_offset;
    int fld_overview;
    char *fld_imdb_prefix;
    int original_token_type; // used for error messages - type of tokens used to create the expression
} Exp;

// YAMJ Compatibility types
//
typedef struct {
    char *name;

    // URL representation of expression that must evaluate to true for items to be included . see parse_url_expression()
    char *filter_expr_url;
    Exp *filter_expr;

    // Sort order - if null use owning YAMJCat sort order.
    char *sort_order;
    int page; // page requested

    // temporary array for items before sorting
    Array *items;

    // For the current category this will be populated with rows from the database.
    DbItem **sorted_items;

    int item_total;
    int evaluated;

    struct YAMJCat_str *owner_cat;

} YAMJSubCat;

typedef struct YAMJCat_str {

    // Name is defined directly from config file OR is derived from parent category auto_subcat_expr
    char *name;
    // URL representation of query used to auto build sub categoroes. see parse_url_expression()
    char *auto_subcat_expr_url;
    Exp *auto_subcat_expr;
    // Sort order - if null use Title.
    char *sort_order;
    int evaluated;
    Array *subcats;
    int page_size;

    // Used to mak computed values to Subcats.
    struct Hashtable *value_to_auto_subcat;
} YAMJCat;
/**
 * String filter parameters may begin with the following codes to indicate the type of comparison
 */
#define QPARAM_FILTER_REGEX "r"
#define QPARAM_FILTER_STRING "s"

#define QPARAM_FILTER_STARTS_WITH "s"
#define QPARAM_FILTER_CONTAINS "c"
#define QPARAM_FILTER_EQUALS "e"

typedef enum JavascriptArgType_enum { JS_ARG_END , JS_ARG_STRING , JS_ARG_INT } JavascriptArgType;

typedef enum { WATCHED , NORMAL , FRESH } ViewStatus;
#endif
