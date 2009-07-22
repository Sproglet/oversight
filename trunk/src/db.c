#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdio.h>
#include <regex.h>
#include <assert.h>
#include <string.h>

#include "db.h"
#include "dbfield.h"
#include "gaya_cgi.h"

char *db_get_lock_file_name() {
    char *s;
    ovs_asprintf(&s,"%s/catalog.lck",getenv("APPDIR"));
    return s;
}

int db_is_locked(char *lockfile) {
    int lockpid;
    if (is_file(lockfile)) {
        FILE *fp = fopen(lockfile,"r");
        int count = fscanf(fp,"%d\n",&lockpid);
        fclose(fp);
        if (count == 1) {
            if (lockpid != getpid()) {
                html_log(0,"Database locked by pid=%d current pid=%d",lockpid,getpid());
                return 1;
            }
        }
    }
    return 0;
}

int db_lock(char *source) {

    int backoff[] = { 10,10,10,10,10,10,20,30, 0 };
    char *lockfile = db_get_lock_file_name(source);

    int attempt;

    for(attempt = 0 ; backoff[attempt] ; attempt++ ) {

        if (!db_is_locked(lockfile)) {
            sleep(backoff[attempt]);
            html_log(0,"Sleeping for %d\n",backoff[attempt]);

            FILE *fp = fopen(lockfile,"w");
            fprintf(fp,"%d\n",getpid());
            fclose(fp);
            free(lockfile);
            return 1;
        }
    }
    html_error("Failed to get lock [%s]\n",lockfile);
    free(lockfile);
    return 0;
}

int db_unlock(char *source) {
    char *lockfile = db_get_lock_file_name(source);
    return unlink(lockfile) ==0;
}

/*
 * Load the database. Each database entry will just be an ID and a pointer to the DB file position
 * (see DbRow)
 */
Db *db_init(char *filename, // path to the file
        char *source       // logical name or tag - local="*"
        ) {

    Db *db = MALLOC(sizeof(Db));

    db->path =  STRDUP(filename);
    db->source= STRDUP(source);
    return db;
}

#define DB_SEP '\t'

// Search for <tab>field_id<tab>field<tab>
int field_pos(char *field_id,char *buffer,char **start,int *length) {
    char *p;
    assert(field_id);
    assert(buffer);
    assert(start);
    assert(strlen(field_id) < 5);

    int fid_len = strlen(field_id);

    for (p = strstr(buffer,field_id) ; p != NULL ; p = strstr(p+1,field_id) ) {
        if (p[-1] == DB_SEP && p[fid_len] == DB_SEP ) {
            *start=p+fid_len+1;
            p=strchr(*start,DB_SEP);
            assert(p);
            *length = p - *start;
            return 1;
        }
    }
    html_error("Failed to find field [%s]",field_id);
    return 0;
}

int extract_field_str(char *field_id,char *buffer,char **str) {
    char *s;
    int fld_len;
    assert(str);
    assert(field_id);
    assert(buffer);
    if (field_pos(field_id,buffer,&s,&fld_len)) {
        *str = MALLOC(fld_len+1);
        strncpy(*str,s,fld_len);
        *((*str)+fld_len) = '\0';
        return 1;
    }
    html_error("Failed to extract string field [%s]",field_id);
    return 0;
}

int extract_field_long(char *field_id,char *buffer,long *val_ptr) {
    char *s;
    int fld_len;
    assert(val_ptr);
    assert(field_id);
    assert(buffer);
    if (field_pos(field_id,buffer,&s,&fld_len)) {
        long val;
        char term;
        if (sscanf(s,"%ld%c",&val,&term) != 2) {
            html_error("failed to extract long field %s",field_id);
        } else if (term != '\t') {
            html_error("bad terminator [%c] after long field %s = %ld",term,field_id,val);
        } else {
            *val_ptr = val;
            return 1;
        }
    }
    return 0;
}
int extract_field_int(char *field_id,char *buffer,int *val_ptr) {
    char *s;
    int fld_len;
    assert(val_ptr);
    assert(field_id);
    assert(buffer);
    if (field_pos(field_id,buffer,&s,&fld_len)) {
        int val;
        char term;
        if (sscanf(s,"%d%c",&val,&term) != 2) {
            html_error("failed to extract int field %s",field_id);
        } else if (term != '\t') {
            html_error("bad terminator [%c] after int field %s = %d",term,field_id,val);
        } else {
            *val_ptr = val;
            return 1;
        }
    }
    return 0;
}


int parse_row(long fpos,char *buffer,Db *db,DbRowId *rowid) {

    assert(db);
    assert(rowid);

    rowid->db = db;
    rowid->offset = fpos;

    if (extract_field_long(DB_FLDID_ID,buffer,&(rowid->id))) {
        if (extract_field_long(DB_FLDID_INDEXTIME,buffer,&(rowid->date))) {
            if (extract_field_int(DB_FLDID_ID,buffer,&(rowid->watched))) {
                if (extract_field_str(DB_FLDID_TITLE,buffer,&(rowid->title))) {
                    if (extract_field_str(DB_FLDID_POSTER,buffer,&(rowid->poster))) {
                        return 1;
                    }
                }
            }
        }
    }
    html_error("Failed to parse row {%s}",buffer);
    return 0;
}

DbRowSet *db_rowset(Db *db) {
    assert(db);

    DbRowSet *dbrs = MALLOC(sizeof(DbRowSet));
    dbrs->db = db;
    dbrs->size=0;
    dbrs->memsize=0;
    dbrs->rows=NULL;
    return dbrs;
}

int db_rowset_add(DbRowSet *dbrs,DbRowId *id) {

    assert(id);
    assert(dbrs);
    assert(id->db == dbrs->db);

    if (dbrs->size >= dbrs->memsize) {
        dbrs->memsize += 10;
        dbrs->rows = REALLOC(dbrs->rows,dbrs->memsize * sizeof(DbRowId));
    }
    DbRowId *insert = dbrs->rows + dbrs->size;
    *insert = *id;
    return dbrs->size;
}

DbRowSet * db_scan_titles(
        Db *db,
        char *name_filter,  // only load lines whose titles match the filter
        int media_type,     // 1=TV 2=MOVIE 3=BOTH 
        int watched         // 1=watched 2=unwatched 3=any
        ){

    regex_t pattern;
    DbRowSet *rowset = NULL;

    html_log(3,"Creating db scan pattern..");

    if (name_filter) {
        // Take the pattern and turn it into <TAB>_ID<TAB>pattern<TAB>
        char *full_regex_text;
        int status;

        ovs_asprintf(&full_regex_text,"\t%s\t%s\t",DB_FLDID_ID,name_filter);

        if ((status = regcomp(&pattern,full_regex_text,REG_EXTENDED)) != 0) {

#define BUFSIZE 256
            char buf[BUFSIZE];
            regerror(status,&pattern,buf,BUFSIZE);
            fprintf(stderr,"%s\n",buf);
            assert(1);
            return NULL;
        }
        free(full_regex_text);
    }

    char *watched_substring=NULL;
    switch(watched) {
        case DB_WATCHED_FILTER_NO : watched_substring = "\t" DB_FLDID_WATCHED "\t0\t"; break;
        case DB_WATCHED_FILTER_YES : watched_substring = "\t" DB_FLDID_WATCHED "\t1\t"; break;
        case DB_WATCHED_FILTER_ANY : watched_substring = NULL ; break;
        default: assert(watched == DB_WATCHED_FILTER_NO); break;
    }

    char *media_substring=NULL;
    switch(media_type) {
        case DB_MEDIA_TYPE_TV : media_substring = "\t" DB_FLDID_CATEGORY "\tT\t"; break;
        case DB_MEDIA_TYPE_FILM : media_substring = "\t" DB_FLDID_CATEGORY "\tM\t"; break;
        case DB_MEDIA_TYPE_ANY : media_substring = NULL ; break;
        default: assert(watched == DB_MEDIA_TYPE_TV); break;
    }

    html_log(3,"db scanning...");

    int row_count,total_rows;
    FILE *fp = fopen(db->path,"r");
    if (fp) {
        unsigned long pos;
        rowset=db_rowset(db);
        DbRowId rowid;
#define DB_ROW_BUF_SIZE 900
        char buffer[DB_ROW_BUF_SIZE+1];
        while (1) {
            pos = ftell(fp);
            if (fgets(buffer,DB_ROW_BUF_SIZE,fp) == NULL) break;

            total_rows++;

            if (chomp(buffer) == 0 ) {
                html_error("Long db line alert");
                exit(1);
            }

            if (name_filter) {
                if (regexec(&pattern,buffer,0,NULL,0) != 0 ) {
                    continue;
                }
            }
            if (media_substring) {
                if (strstr(buffer,media_substring) == NULL) {
                    continue;
                }
            }

            if (watched_substring) {
                if (strstr(buffer,watched_substring) == NULL) {
                    continue;
                }
            }

            if (parse_row(pos,buffer,db,&rowid)) {
                row_count = db_rowset_add(rowset,&rowid);
            }
        }
    }
    fclose(fp);
    if (rowset) {
        html_log(0,"filtered %d of %d rows",row_count,total_rows);
    } else {
        html_error("No rows loaded");
    }
    return rowset;
}




