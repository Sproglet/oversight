#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdio.h>
#include <regex.h>
#include <assert.h>
#include <string.h>
#include <dirent.h>
#include <time.h>

#include "db.h"
#include "dbfield.h"
#include "gaya_cgi.h"

struct hashtable *read_and_parse_row(FILE *fp);

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
    db->refcount =0;
    return db;
}

#define DB_SEP '\t'

// Search for <tab>field_id<tab>field<tab>
int field_pos(char *field_id,char *buffer,char **start,int *length,int quiet) {
    char *p;
    assert(field_id);
    assert(buffer);
    assert(start);

    int fid_len = strlen(field_id);

    //We can increment search by fid_len as the field names cant overlap due to tabs(DB_SEP).
    for (p = strstr(buffer,field_id) ; p != NULL ; p = strstr(p+fid_len,field_id) ) {
        if (p[-1] == DB_SEP && p[fid_len] == DB_SEP ) {
            *start=p+fid_len+1;
            p=strchr(*start,DB_SEP);
            assert(p);
            *length = p - *start;
            return 1;
        }
    }
    if (!quiet) html_error("Failed to find field [%s]",field_id);
    return 0;
}

int extract_field_str(char *field_id,char *buffer,char **str,int quiet) {
    char *s;
    int fld_len;
    assert(str);
    assert(field_id);
    assert(buffer);
    if (field_pos(field_id,buffer,&s,&fld_len,quiet)) {
        *str = MALLOC(fld_len+1);
        strncpy(*str,s,fld_len);
        *((*str)+fld_len) = '\0';
        return 1;
    }
    if (!quiet) html_error("Failed to extract string field [%s]",field_id);
    return 0;
}

int extract_field_long(char *field_id,char *buffer,long *val_ptr,int quiet) {
    char *s;
    int fld_len;
    assert(val_ptr);
    assert(field_id);
    assert(buffer);
    if (field_pos(field_id,buffer,&s,&fld_len,quiet)) {
        long val;
        char term;
        if (sscanf(s,"%ld%c",&val,&term) != 2) {
            if (!quiet) html_error("failed to extract long field %s",field_id);
        } else if (term != '\t') {
            if (!quiet) html_error("bad terminator [%c] after long field %s = %ld",term,field_id,val);
        } else {
            *val_ptr = val;
            return 1;
        }
    }
    return 0;
}
int extract_field_timestamp(char *field_id,char *buffer,long *val_ptr,int quiet) {
    char *s;
    int fld_len;
    assert(val_ptr);
    assert(field_id);
    assert(buffer);
    int y,m,d,H,M,S;

    if (field_pos(field_id,buffer,&s,&fld_len,quiet)) {
        char term;
        if (sscanf(s,"%4d%2d%2d%2d%2d%2d%c",&y,&m,&d,&H,&M,&S,&term) != 7) {
            if (!quiet) html_error("failed to extract long field %s",field_id);
        } else if (term != '\t') {
            if (!quiet) html_error("bad terminator [%c] after long field %s = %d %d %d %d %d %d",term,field_id,y,m,d,H,M,S);
        } else {
            struct tm t;
            t.tm_year = y - 1900;
            t.tm_mon = m - 1;
            t.tm_mday = d;
            t.tm_hour = H;
            t.tm_min = M;
            t.tm_sec = S;
            *val_ptr = mktime(&t);
            if (*val_ptr < 0 ) {
                html_log(0,"bad timstamp %d/%02d/%02d %02d:%02d:%02d = %s",y,m,d,H,M,S,asctime(&t));
            }
            //*val_ptr = S+60*(M+60*(H+24*(d+32*(m+12*(y-1970)))));
            return 1;
        }
    }
    return 0;
}
int extract_field_int(char *field_id,char *buffer,int *val_ptr,int quiet) {
    char *s;
    int fld_len;
    assert(val_ptr);
    assert(field_id);
    assert(buffer);
    if (field_pos(field_id,buffer,&s,&fld_len,quiet)) {
        int val;
        char term;
        if (sscanf(s,"%d%c",&val,&term) != 2) {
            if (!quiet) html_error("failed to extract int field [%s]",field_id);
        } else if (term != '\t') {
            if (!quiet) html_error("bad terminator [%c] after int field %s = %d",term,field_id,val);
        } else {
            *val_ptr = val;
            return 1;
        }
    }
    return 0;
}
int extract_field_char(char *field_id,char *buffer,char *val_ptr,int quiet) {
    char *s;
    int fld_len;
    assert(val_ptr);
    assert(field_id);
    assert(buffer);
    if (field_pos(field_id,buffer,&s,&fld_len,quiet)) {
        char val;
        char term;
        if (sscanf(s,"%c%c",&val,&term) != 2) {
            if (!quiet) html_error("failed to extract character field %s",field_id);
        } else if (term != '\t') {
            if (!quiet) html_error("bad terminator [%c] after character field %s = %c",term,field_id,val);
        } else {
            *val_ptr = val;
            return 1;
        }
    }
    return 0;
}

#ifdef FAST_PARSE
struct hashtable *read_and_parse_row(FILE *fp) {
    char value[DB_ROW_BUF_SIZE];
#define DB_NAME_BUF_SIZE 10
    char name[DB_NAME_BUF_SIZE];
    char next;

    char *buf[2] = { name , value };
    char buflen[2] = { DB_ROW_BUF_SIZE,DB_NAME_BUF_SIZE};

    struct hashtable *row_hash = string_string_hashtable();

    int buf_pick=1;
    do {
        next = getc(fp);

        switch(next) {
        case '\t':
            while(next == '\t') {
                //read next field
                
                buf_pick = 1-buf_pick;
                char *p = buf[buf_pick];
                char *end = p + buflen[buf_pick];

                next = getc(fp);
                while (next != '\r' && next != '\n' && next != '\t') {

                    assert(p < end);

                    *p++ = next;

                    next = getc(fp);
                }
                if (next == '\t') {
                    *p = '\0';
                    if (buf_pick == 1) {
                        // just finished value - add to hash.
                        html_log(0,"parsed field %s=%s",name,value);
                        hashtable_insert(row_hash,STRDUP(name),STRDUP(value));
                    }
                } else {
                    //end of row
                    return row_hash;
                }
            }
            break;
        case '\n' : case '\r' :  // EOL terminators
            break;
        case '#': //comment
            fgets(buffer,DB_ROW_BUF_SIZE,fp);
            break;

            
        default: // Anything else
            html_error("unexpected character [%c] at start of line",next);
        }
    }
    return NULL;
}
#endif

int parse_row(long fpos,char *buffer,Db *db,DbRowId *rowid) {

    assert(db);
    assert(rowid);

    memset(rowid,0,sizeof(*rowid));

    rowid->db = db;
    rowid->offset = fpos;
    rowid->season = -1;
    rowid->category='?';

    switch(buffer[0]) {
        case '\t':
            if (extract_field_long(DB_FLDID_ID,buffer,&(rowid->id),0)) {
                if (extract_field_timestamp(DB_FLDID_INDEXTIME,buffer,&(rowid->date),0)) {
                    if (extract_field_int(DB_FLDID_ID,buffer,&(rowid->watched),0)) {
                        if (extract_field_str(DB_FLDID_TITLE,buffer,&(rowid->title),0)) {
                            if (extract_field_str(DB_FLDID_POSTER,buffer,&(rowid->poster),0)) {
                                extract_field_int(DB_FLDID_SEASON,buffer,&(rowid->season),1);
                                extract_field_char(DB_FLDID_CATEGORY,buffer,&(rowid->category),1);

                                //if (in_text_mode() || (rowid->category != 'M' && rowid->category != 'T' ) ) {

            //html_log(0,"db getting file..");
                                    extract_field_str(DB_FLDID_FILE,buffer,&(rowid->file),0);
            //html_log(0,"db file = [%s]",rowid->file);
                                    rowid->ext = strrchr(rowid->file,'.');
            //html_log(0,"db ext = [%s]",rowid->ext);
                                    if (rowid->ext) rowid->ext++;
            //html_log(0,"db ext = [%s]",rowid->ext);

                                    extract_field_str(DB_FLDID_CERT,buffer,&(rowid->certificate),0);
            //html_log(0,"db cert = [%s]",rowid->certificate);

                                //}

                                return 1;
                            }
                        }
                    }
                }
            }
            html_error("Failed to parse row {%s}",buffer);
            break;
        case '#' : // do nothing
            break;
        default:
            html_error("Unknown line in db {%s}",buffer);
    }
    return 0;
}

DbRowSet *db_rowset(Db *db) {
    assert(db);

    DbRowSet *dbrs = MALLOC(sizeof(DbRowSet));
    dbrs->db = db;
    db->refcount++;
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
    (dbrs->size)++;

    insert->db->refcount++;

    return dbrs->size;
}

char *localDbPath() {
    static char *a=NULL;
    if (a == NULL) {
        ovs_asprintf(&a,"%s/index.db",appDir());
    }
    return a;
}

static int g_db_size = 0;

int db_full_size() {
    return g_db_size;
}

//
// Returns null terminated array of rowsets
DbRowSet **db_crossview_scan_titles(
        int crossview,
        char *name_filter,  // only load lines whose titles match the filter
        int media_type,     // 1=TV 2=MOVIE 3=BOTH 
        int watched         // 1=watched 2=unwatched 3=any
        ){
    int rowset_count=1;
    DbRowSet **rowsets = MALLOC((rowset_count+1)*sizeof(DbRowSet*));
    Db *db;

    int this_db_size;


    db = db_init(localDbPath(),"*");

    rowsets[0] = db_scan_titles(db,name_filter,media_type,watched,&this_db_size);
    rowsets[1]=NULL;

    g_db_size += this_db_size;


    if (crossview) {
        char *root="/opt/sybhttpd/localhost.drives/NETWORK_SHARE";
        DIR *d = opendir(root);
        if (d) {
            struct dirent dent,*p;
            while((readdir_r(d,&dent,&p)) == 0) {

                char *path=NULL;
                char *name=dent.d_name;

                ovs_asprintf(&path,"%s/%s/Apps/oversight/index.db",root,name);
                if (is_file(path)) {
                    Db *db = db_init(path,name);

                    if (db) {

                        DbRowSet *r = db_scan_titles(db,name_filter,media_type,watched,&this_db_size);
                        g_db_size += this_db_size;

                        if (r != NULL) {
                            rowset_count++;
                            rowsets = REALLOC(rowsets,(rowset_count+1)*sizeof(DbRowSet*));
                            rowsets[rowset_count-1] = r;
                            rowsets[rowset_count]=NULL;
                        }
                    }
                } else {
                    html_log(0,"crossview search %s doesnt exist",path);
                }
                free(path);
            }
            closedir(d);
        }
    }
    return rowsets;
}

void db_free_rowsets_and_dbs(DbRowSet **rowsets) {
    DbRowSet **r;
    for(r = rowsets ; *r ; r++ ) {
        Db *db = (*r)->db;
        db_rowset_free(*r);
        db_free(db);
    }
    free(rowsets);
}

DbRowSet * db_scan_titles(
        Db *db,
        char *name_filter,  // only load lines whose titles match the filter
        int media_type,     // 1=TV 2=MOVIE 3=BOTH 
        int watched,        // 1=watched 2=unwatched 3=any
        int *gross_size     // Full unfiltered size of database.
        ){

    regex_t pattern;
    DbRowSet *rowset = NULL;

    html_log(2,"Creating db scan pattern..");

    if (name_filter && *name_filter) {
        // Take the pattern and turn it into <TAB>_ID<TAB>pattern<TAB>
        int status;

        if ((status = regcomp(&pattern,name_filter,REG_EXTENDED|REG_ICASE)) != 0) {

#define BUFSIZE 256
            char buf[BUFSIZE];
            regerror(status,&pattern,buf,BUFSIZE);
            fprintf(stderr,"%s\n",buf);
            assert(1);
            return NULL;
        }
        html_log(0,"filering by regex [%s]",name_filter);
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

    html_log(2,"db scanning...");

    int row_count=0;
    int total_rows=0;
    FILE *fp = fopen(db->path,"r");
    if (fp) {
        unsigned long pos;
        rowset=db_rowset(db);
        DbRowId rowid;
#define DB_ROW_BUF_SIZE 4000
        char buffer[DB_ROW_BUF_SIZE+1];

#ifdef FAST_PARSE
        while (1) {
            hashtable *row_hash = read_and_parse_row(fp,&pos);
            if (row_hash) {
                total_rows++;

                if (buffer[0] == '\t' && gross_size != NULL) {
                    (*gross_size)++;
            }
        }
#endif

        while (1) {
            pos = ftell(fp);
            /*
             * TODO: Further optimisation - replace fgets with function that parses 
             * input using fgetc directly into hashtable name value pairs.
             */
            if (fgets(buffer,DB_ROW_BUF_SIZE,fp) == NULL) break;

            total_rows++;

            if (buffer[0] == '\t' && gross_size != NULL) {
                (*gross_size)++;
            }



            if (name_filter && *name_filter) {
                char *title_start=NULL;
                int title_len=0;
                int match;

                // Modify buffer in place and try to match. This allows use of ^ $
                // And prevents the regex matching against the rest of the buffer.
                if (field_pos(DB_FLDID_TITLE,buffer,&title_start,&title_len,0)) {
                    title_start[title_len] = '\0';
                    match = regexec(&pattern,title_start,0,NULL,0);
                    if (match != 0 ) {
                        html_log(4,"skipped %s!=%s",title_start,name_filter);
                        title_start[title_len] = DB_SEP;
                        continue;
                    }
                    title_start[title_len] = DB_SEP;
                }
            }
            if (media_substring) {
                if (strstr(buffer,media_substring) == NULL) {
                    html_log(4,"skipped %s",media_substring);
                    continue;
                }
            }

            if (watched_substring) {
                if (strstr(buffer,watched_substring) == NULL) {
                    html_log(4,"skipped %s",watched_substring);
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
        html_log(0,"db[%s] filtered %d of %d rows",db->source,row_count,total_rows);
    } else {
        html_error("db[%s] No rows loaded",db->source);
    }
    return rowset;
}

void db_free(Db *db) {

    assert(db->refcount == 0);

    free(db->source);
    free(db->path);
    free(db);

}


void db_rowid_free(DbRowId *rid,int free_base) {

    assert(rid);

    free(rid->title);
    free(rid->poster);
    free(rid->file);
    //Dont free ext as it points to file.

    free(rid->certificate);
    rid->db->refcount--;
    if (free_base) {
        free(rid);
    }
}

void db_rowset_free(DbRowSet *dbrs) {
    int i;

    for(i = 0 ; i<dbrs->size ; i++ ) {
        DbRowId *rid = dbrs->rows + i;
        db_rowid_free(rid,0);
    }

    free(dbrs->rows);
    dbrs->db->refcount--;
    free(dbrs);
}


void db_rowset_dump(int level,char *label,DbRowSet *dbrs) {
    int i;
    if (dbrs->size == 0) {
        html_log(level,"Rowset: %s : EMPTY",label);
    } else {
        for(i = 0 ; i<dbrs->size ; i++ ) {
            DbRowId *rid = dbrs->rows + i;
            html_log(level,"Rowset: %s [%s - %c - %d %s ]",label,rid->title,rid->category,rid->season,rid->poster);
        }
    }
}

