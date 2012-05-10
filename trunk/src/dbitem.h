#ifndef __OVS_DBROW_H__
#define __OVS_DBROW_H__

#include <stdio.h>

#include "time.h"
#include "dbread.h"
#include "array.h"
#include "types.h"


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
int db_rowid_get_field_offset_type(DbItem *rowid,char *name,void **offset,char *type,int *overview,char **imdb_prefix_ptr);
int is_on_local_storage(DbItem *item);
int is_on_internal_hdd(DbItem *item);
int is_on_remote_oversight(DbItem *item);
int is_on_local_oversight(DbItem *item);
char *get_item_id(DbItem *item,char *domain,int add_domain);
char *get_id_from_idlist(char *idlist,char *domain,int add_domain);
int dbrow_total_size(DbItem *rowid);
int num_parts(DbItem *item);
#endif
