#ifndef __OVS_TYPES_H__
#define __OVS_TYPES_H__

// Types will be migrated here over time.

typedef struct EnumString_struct {
    int id ;
    const char *str;
} EnumString;

typedef enum GridDirection_enum {
    GRID_ORDER_DEFAULT,
    GRID_ORDER_HORIZONTAL ,
    GRID_ORDER_VERTICAL
} GridDirection;

#define DB_MEDIA_TYPE_TV 1
#define DB_MEDIA_TYPE_FILM 2
#define DB_MEDIA_TYPE_ANY 3
#define DB_MEDIA_TYPE_OTHER 4



typedef struct ViewMode_struct {
    char *name;
    int view_class;
    int row_select; // How to select rows TV=by title_season tvboxset=by title  anything else by id;
    int has_playlist;
    char *dimension_cell_suffix; // get image dimensions from config file
    int media_type;
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


typedef enum MovieBoxsetMode_enum {
    MOVIE_BOXSETS_UNSET , 
    MOVIE_BOXSETS_NONE ,
    MOVIE_BOXSETS_FIRST , // Box sets are related by first movie connection
    MOVIE_BOXSETS_LAST , // Box sets are related by last movie connection 
    MOVIE_BOXSETS_ANY    // Box sets are related by any movie connection
} MovieBoxsetMode;

#endif
