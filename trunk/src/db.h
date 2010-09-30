#ifndef __DB_ALORD__
#define __DB_ALORD__

#include "hashtable.h"
#include "util.h"
#include "vasprintf.h"
#include "dbitem.h"
#include "dbfield.h"
#include "time.h"
#include "exp.h"

typedef enum { PLOT_MAIN=0 , PLOT_EPISODE=1 } PlotType;

#define PLOT_TYPE_COUNT 2

OVS_TIME *timestamp_ptr(DbItem *rowid);

#define ALL_IDS -1

/**
 * Details for a particualr index.db/plot.db
 **/
typedef struct Db_struct {

    char *path;     // ..../index.db (auto computed from source)
    char *source;   // *=local otherwise use nmt share name
    char *lockfile; // ..../catalog.lck
    char *backup;   // backup path ....index.db.old
    int locked_by_this_code;
    char *plot_file; // ..../plot.db (auto computed from source)
    FILE *plot_fp;    // File pointer to plotfile
    int db_size;
    char *actors_file; // ..../db/actors.db (auto computed from source)
    char *directors_file; // ..../db/actors.db (auto computed from source)
    char *writers_file; // ..../db/actors.db (auto computed from source)

#if 0
    char *directors_file; // ..../db/directors.db (auto computed from source)
    char *writers_file; // ..../db/writers.db (auto computed from source)
#endif

} Db;

/**
 * A subset of entries from a particular Db
 * The subset is usually determined by the query string. eg Only Movies beginning with A etc.
 */
typedef struct DbResults_struct {
    Db *db;
    long size;
    long memsize;
    DbItem *rows; // Array of actual entries.
    int movie_total;
    int series_total;
    int episode_total;
    int other_media_total;
} DbItemSet;

/**
 * All DbItemSets merged and sorted.
 */
typedef struct DBSortedRows_struct {

    int num_rows;
    DbItemSet **rowsets;
    DbItem **rows;

} DbSortedRows;

Db *db_init(char *filename, // path to the file
        char *source       // logical name or tag - local="*"
        );

DbItemSet * db_scan_titles( Db *db, Exp *exp,int num_ids,int *ids,void (*action)(DbItem *,void *),void *action_data);
int db_lock(Db *db);
int db_unlock(Db *db);
void db_rowset_free(DbItemSet *dbrs);
void db_rowid_free(DbItem *item,int free_base);
void db_free(Db *db);

void db_rowset_dump(int level,char *label,DbItemSet *dbrs);

DbItemSet **db_crossview_scan_titles(
        int crossview,
        Exp *exp);
void db_free_rowsets_and_dbs(DbItemSet **rowsets);
int db_full_size();
void db_set_fields(char *field_id,char *new_value,struct hashtable *ids_by_source,int delete_mode);
void db_auto_remove_row(DbItem *item);
void db_remove_row(DbItem *item);
void db_delete_row_and_media(DbItem *item);
Array *get_genres();
char *db_get_field(DbSortedRows *sorted_rows,int idx,char *fieldid);
void dump_row(char *prefix,DbItem *item);
void dump_all_rows(char *prefix,int num_rows,DbItem **sorted_rows);
void dump_all_rows2(char *prefix,int num_rows,DbItem sorted_rows[]);
OVS_TIME get_newest_linked_timestamp(DbItem *rowid);
void fix_file_paths(int num_row,DbItem **rows);
char *get_crossview_local_copy(char *path,char *label);
char *expand_genre(char *genre_keys);
char *compress_genre(char *genre_names);
char * db_rowid_get_field(DbItem *rowid,char *name);
int local_db_size();
int *extract_ids_by_source(char *query,char *dbsource,int *num_ids);
int *extract_ids(char *s,int *num_ids);
char *person_file_static(Db *db,char *fieldid);
#endif
