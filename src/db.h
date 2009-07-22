#ifndef __DB_ALORD__
#define __DB_ALORD__

#include "hashtable.h"
#include "util.h"
#include "vasprintf.h"

typedef struct Dbrowid_struct {

    long id;
    struct Db_struct *db;
    long offset;
    long date;
    int watched;
    char *title;
    char *poster;


} DbRowId;

#define DB_MEDIA_TYPE_TV 1
#define DB_MEDIA_TYPE_FILM 2
#define DB_MEDIA_TYPE_ANY 3

#define DB_WATCHED_FILTER_YES 1
#define DB_WATCHED_FILTER_NO 2
#define DB_WATCHED_FILTER_ANY 3

typedef struct Db_struct {

    char *path;
    char *source;

} Db;

typedef struct DbResults_struct {
    Db *db;
    long size;
    long memsize;
    DbRowId *rows;
} DbRowSet;




#endif
