#ifndef __OVS_DBROW_H__
#define __OVS_DBROW_H__

#include <stdio.h>
#include "db.h"
#include "dbread.h"

void fix_file_paths(int num_row,DbRowId **rows);
void fix_file_path(DbRowId *rowid);
int in_idlist(int id,int size,int *ids);
DbRowId *db_rowid_new(Db *db);
DbRowId *db_rowid_init(DbRowId *rowid,Db *db);

// TODO: 3 functions below need consolidation read_and_parse_row() and
// parse_row() are usually called after some other time consuming action. eg
// deleting a file. but dbread_and_parse_row() is very
// performance critical , it scans the entire database at every page load, and
// it may not be simple to include this in consolidation and keep the
// performance.

DbRowId *read_and_parse_row(
        DbRowId *rowid,
        Db *db,
        FILE *fp,
        int *eof,
        int tv_or_movie_view // true if looking at tv or moview view.
        );
DbRowId *dbread_and_parse_row(
        DbRowId *rowid,
        Db *db,
        ReadBuf *fp,
        int *eof,
        int tv_or_movie_view // true if looking at tv or moview view.
        );
int parse_row(
        int num_ids, // number of ids passed in the idlist parameter of the query string. if ALL_IDS then id list is ignored.
        int *ids,    // sorted array of ids passed in query string idlist to use as a filter.
        int tv_or_movie_view, // true if looking at tv or moview view.
        char *buffer,  // The current buffer contaning a line of input from the database
        Db *db,        // the database
        DbRowId *rowid// current rowid structure to populate.
        );
#endif
