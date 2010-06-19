#ifndef __OVS_DBROW_H__
#define __OVS_DBROW_H__

#include <stdio.h>

#include "time.h"
#include "dbread.h"
#include "array.h"

typedef enum ViewMode_enum {
    UNSET_VIEW_ID=0,
    MENU_VIEW_ID,
    TV_VIEW_ID,
    MOVIE_VIEW_ID,
    TVBOXSET_VIEW_ID,
    MOVIEBOXSET_VIEW_ID,
    ADMIN_VIEW_ID,
    MIXED_VIEW_ID
} ViewMode;

typedef struct Dbrowid_struct {

    long id;
    struct Db_struct *db;
    long offset;
    OVS_TIME date;
    int watched;
    char *title;
    char *orig_title;
    char *poster;
    char *genre;
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

    struct DbGroupIMDB_struct *comes_after;
    struct DbGroupIMDB_struct *comes_before;
    struct DbGroupIMDB_struct *remakes;

    struct DbGroupIMDB_struct *directors;
    struct DbGroupIMDB_struct *actors;

    // Set for first row in the list.
    // These fields will be moved to the ItemList structure once I create a list of Items
    // for each Grid position.
    char *drilldown_view_static;
    enum ViewMode_enum drilldown_mode;

} DbItem;

void db_rowid_dump(DbItem *item);
void fix_file_paths(int num_row,DbItem **rows);
void fix_file_path(DbItem *rowid);
int idlist_index(int id,int size,int *ids);
DbItem *db_rowid_new(struct Db_struct *db);
DbItem *db_rowid_init(DbItem *rowid,struct Db_struct *db);

// TODO: 3 functions below need consolidation read_and_parse_row() and
// parse_row() are usually called after some other time consuming action. eg
// deleting a file. but dbread_and_parse_row() is very
// performance critical , it scans the entire database at every page load, and
// it may not be simple to include this in consolidation and keep the
// performance.

DbItem *read_and_parse_row(
        DbItem *rowid,
        struct Db_struct *db,
        FILE *fp,
        int *eof,
        int tv_or_movie_view // true if looking at tv or moview view.
        );
DbItem *dbread_and_parse_row(
        DbItem *rowid,
        struct Db_struct *db,
        ReadBuf *fp,
        int *eof,
        int tv_or_movie_view // true if looking at tv or moview view.
        );
int parse_row(
        int num_ids, // number of ids passed in the idlist parameter of the query string. if ALL_IDS then id list is ignored.
        int *ids,    // sorted array of ids passed in query string idlist to use as a filter.
        int tv_or_movie_view, // true if looking at tv or moview view.
        char *buffer,  // The current buffer contaning a line of input from the database
        struct Db_struct *db,        // the database
        DbItem *rowid// current rowid structure to populate.
        );
#endif
