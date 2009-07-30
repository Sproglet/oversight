#ifndef __DB_ALORD__
#define __DB_ALORD__

#include "hashtable.h"
#include "util.h"
#include "vasprintf.h"
#include "dbfield.h"

typedef struct Dbrowid_struct {

    long id;
    struct Db_struct *db;
    long offset;
    long date;
    int watched;
    char *title;
    char *poster;
    char *genre;
    char category;
    int season;

    struct Dbrowid_struct *linked;

    // Add ext member etc but only populate if postermode=0 as the text mode has this extra detail
    char *file;
    char *ext;
    char *certificate;

    //only populate if view=tv or movie
    char *url;
    char *plot;
    char *parts;

} DbRowId;

void db_rowid_dump(DbRowId *rid);

#define DB_MEDIA_TYPE_TV 1
#define DB_MEDIA_TYPE_FILM 2
#define DB_MEDIA_TYPE_ANY 3

#define DB_WATCHED_FILTER_YES 1
#define DB_WATCHED_FILTER_NO 2
#define DB_WATCHED_FILTER_ANY 3

typedef struct Db_struct {

    char *path;
    char *source;
    int refcount; // # references to this db.

} Db;

typedef struct DbResults_struct {
    Db *db;
    long size;
    long memsize;
    DbRowId *rows;
} DbRowSet;


Db *db_init(char *filename, // path to the file
        char *source       // logical name or tag - local="*"
        );

DbRowSet * db_scan_titles(
        Db *db,
        char *name_filter,  // only load lines whose titles match the filter
        int media_type,     // 1=TV 2=MOVIE 3=BOTH 
        int watched,        // 1=watched 2=unwatched 3=any
        int *gross_size
        );

int db_lock(char *source);
int db_unlock(char *source);
void db_rowset_free(DbRowSet *dbrs);
void db_rowid_free(DbRowId *rid,int free_base);
void db_free(Db *db);

void db_rowset_dump(int level,char *label,DbRowSet *dbrs);

DbRowSet **db_crossview_scan_titles(
        int crossview,
        char *name_filter,  // only load lines whose titles match the filter
        int media_type,     // 1=TV 2=MOVIE 3=BOTH 
        int watched         // 1=watched 2=unwatched 3=any
        );
void db_free_rowsets_and_dbs(DbRowSet **rowsets);
int db_full_size();
#endif
