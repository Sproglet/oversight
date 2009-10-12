#ifndef __DB_ALORD__
#define __DB_ALORD__

#include "hashtable.h"
#include "util.h"
#include "vasprintf.h"
#include "dbfield.h"
#include "time.h"

typedef struct Dbrowid_struct {

    long id;
    struct Db_struct *db;
    long offset;
    OVS_TIME date;
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
    int year;

    //only populate if view=tv or movie
    char *url;
    char *plot_key;
    char *episode_plot_key;
    char *fanart;
    char *parts;
    char *episode;
    char *director;

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

    long plot_offset;
    long episode_plot_offset;
    char *plot_text;
    char *episode_plot_text;

} DbRowId;

void db_rowid_dump(DbRowId *rid);

#define DB_MEDIA_TYPE_TV 1
#define DB_MEDIA_TYPE_FILM 2
#define DB_MEDIA_TYPE_ANY 3

#define DB_WATCHED_FILTER_YES 1
#define DB_WATCHED_FILTER_NO 2
#define DB_WATCHED_FILTER_ANY 3

typedef struct Db_struct {

    char *path;     // ..../index.db (auto computed from source)
    char *source;   // *=local otherwise use nmt share name
    char *lockfile; // ..../catalog.lck
    char *backup;   // backup path ....index.db.old
    int locked_by_this_code;
    char *plot_file; // ..../plot.db (auto computed from source)
    FILE *plot_fp;    // File pointer to plotfile

} Db;

typedef struct DbResults_struct {
    Db *db;
    long size;
    long memsize;
    DbRowId *rows;
    int movie_total;
    int series_total;
    int episode_total;
    int other_media_total;
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

int db_lock(Db *db);
int db_unlock(Db *db);
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
void db_set_fields(char *field_id,char *new_value,struct hashtable *ids_by_source,int delete_mode);
void db_remove_row(DbRowId *rid);
void db_delete_row_and_media(DbRowId *rid);
Array *get_genres();
char *db_get_field(char *fieldid);
#endif
