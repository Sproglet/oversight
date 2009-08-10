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
#include "actions.h"
#include "dbfield.h"
#include "gaya_cgi.h"
#include "oversight.h"
#include "hashtable_loop.h"

#define DB_ROW_BUF_SIZE 4000

struct hashtable *read_and_parse_row(FILE *fp);
int in_idlist(int id,int size,int *ids);

int db_lock_pid(Db *db) {

    int lockpid=0;

    if (is_file(db->lockfile)) {

        FILE *fp = fopen(db->lockfile,"r");

        fscanf(fp,"%d\n",&lockpid);
        fclose(fp);
    }
    return lockpid;
}

int db_is_locked_by_another_process(Db *db) {

    int result=0;
    int lockpid =  db_lock_pid(db) ;

    if ( lockpid != 0 && lockpid != getpid() ) {
        char *dir;
        ovs_asprintf(&dir,"/proc/%d",lockpid);
        if (is_dir(dir)) {
            html_log(0,"Database locked by pid=%d current pid=%d",lockpid,getpid());
            result=1;
        } else {
            html_log(0,"Database was locked by pid=%d current pid=%d : releasing lock",lockpid,getpid());
        }
        FREE(dir);
    }
    return result;
}

int db_lock(Db *db) {

    int backoff[] = { 10,10,10,10,10,10,20,30, 0 };

    int attempt;

    db->locked_by_this_code=0;
    for(attempt = 0 ; backoff[attempt] && db->locked_by_this_code ==0 ; attempt++ ) {

        if (db_is_locked_by_another_process(db)) {

            sleep(backoff[attempt]);
            html_log(0,"Sleeping for %d\n",backoff[attempt]);

        } else {
            db->locked_by_this_code=1;
        }
    }
    if (db->locked_by_this_code) {
        FILE *fp = fopen(db->lockfile,"w");
        fprintf(fp,"%d\n",getpid());
        fclose(fp);
        html_log(0,"Aquired lock [%s]\n",db->lockfile);
    } else {
        html_error("Failed to get lock [%s]\n",db->lockfile);
    }
    return db->locked_by_this_code;
}

int db_unlock(Db *db) {

    db->locked_by_this_code=0;
    html_log(0,"Released lock [%s]\n",db->lockfile);
    return unlink(db->lockfile) ==0;
}

/*
 * Load the database. Each database entry will just be an ID and a pointer to the DB file position
 * (see DbRow)
 */
Db *db_init(char *filename, // path to the file - if NULL compute from source
        char *source       // logical name or tag - local="*"
        ) {

    Db *db = MALLOC(sizeof(Db));

    if (filename == NULL) {
        db->path = get_mounted_path(source,"/share/Apps/oversight/index.db");
    } else {
        db->path =  STRDUP(filename);
    }
    db->source= STRDUP(source);

    ovs_asprintf(&(db->backup),"%s.old",db->path);

    db->lockfile = replace_all(db->path,"index.db","catalog.lck",0);

    db->locked_by_this_code=0;
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
    if (!quiet) html_log(0,"ERROR: Failed to find field [%s]",field_id);
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
    if (!quiet) html_log(0,"ERROR: Failed to extract string field [%s]",field_id);
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
            if (!quiet) html_log(0,"ERROR: failed to extract long field %s",field_id);
        } else if (term != '\t') {
            if (!quiet) html_log(0,"ERROR: bad terminator [%c] after long field %s = %ld",term,field_id,val);
        } else {
            *val_ptr = val;
            return 1;
        }
    }
    return 0;
}
int extract_field_date(char *field_id,char *buffer,long *val_ptr,int quiet) {
    char *s;
    int fld_len;
    assert(val_ptr);
    assert(field_id);
    assert(buffer);
    int y,m,d;

    if (field_pos(field_id,buffer,&s,&fld_len,quiet)) {
        char term;
        if (sscanf(s,"%4d-%d-%d%c",&y,&m,&d,&term) != 4) {
            if (!quiet) html_log(0,"ERROR: failed to extract date field %s",field_id);
        } else if (term != '\t') {
            if (!quiet) html_log(0,"ERROR: bad terminator [%c] after date field %s = %d %d",term,field_id,y,m,d);
        } else {
            struct tm t;
            t.tm_year = y - 1900;
            t.tm_mon = m - 1;
            t.tm_mday = d;
            t.tm_hour = 0;
            t.tm_min = 0;
            t.tm_sec = 0;
            *val_ptr = mktime(&t);
            if (*val_ptr < 0 ) {
                html_log(0,"bad date %d/%02d/%02d = %s",y,m,d,asctime(&t));
            }
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
            if (!quiet) html_error("failed to extract timestamp field %s",field_id);
        } else if (term != '\t') {
            if (!quiet) html_log(0,"ERROR: bad terminator [%c] after timestamp field %s = %d %d %d %d %d %d",term,field_id,y,m,d,H,M,S);
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
                html_log(0,"ERROR: bad timstamp %d/%02d/%02d %02d:%02d:%02d = %s",y,m,d,H,M,S,asctime(&t));
            }
            //*val_ptr = S+60*(M+60*(H+24*(d+32*(m+12*(y-1970)))));
            return 1;
        }
    }
    return 0;
}
int extract_field_double(char *field_id,char *buffer,double *val_ptr,int quiet) {
    char *s;
    int fld_len;
    assert(val_ptr);
    assert(field_id);
    assert(buffer);
    if (field_pos(field_id,buffer,&s,&fld_len,quiet)) {
        double val;
        char term;
        if (sscanf(s,"%lf%c",&val,&term) != 2) {
            if (!quiet) html_log(0,"ERROR: failed to extract double field [%s]",field_id);
        } else if (term != '\t') {
            if (!quiet) html_log(0,"ERROR: bad terminator [%c] after double field %s = %d",term,field_id,val);
        } else {
            *val_ptr = val;
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
            if (!quiet) html_log(0,"ERROR: failed to extract int field [%s]",field_id);
        } else if (term != '\t') {
            if (!quiet) html_log(0,"ERROR: bad terminator [%c] after int field %s = %d",term,field_id,val);
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
            if (!quiet) html_log(0,"ERROR: failed to extract character field %s",field_id);
        } else if (term != '\t') {
            if (!quiet) html_log(0,"ERROR: bad terminator [%c] after character field %s = %c",term,field_id,val);
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

void db_rowid_dump(DbRowId *rid) {
    
    html_log(0,"ROWID: id = %d",rid->id);
    html_log(0,"ROWID: watched = %d",rid->watched);
    html_log(0,"ROWID: title(%s)",rid->title);
    html_log(0,"ROWID: file(%s)",rid->file);
    html_log(0,"ROWID: ext(%s)",rid->ext);
    html_log(0,"ROWID: season(%d)",rid->season);
    html_log(0,"ROWID: episode(%d)",rid->episode);
    html_log(0,"ROWID: genre(%s)",rid->genre);
    html_log(0,"ROWID: ext(%c)",rid->category);
    html_log(0,"ROWID: parts(%s)",rid->parts);
    html_log(0,"ROWID: date(%s)",asctime(localtime((time_t *)&(rid->date))));
    html_log(0,"ROWID: eptitle(%s)",rid->eptitle);
    html_log(0,"ROWID: eptitle_imdb(%s)",rid->eptitle_imdb);
    html_log(0,"ROWID: additional_nfo(%s)",rid->additional_nfo);
    html_log(0,"ROWID: airdate(%s)",asctime(localtime((time_t *)&(rid->airdate))));
    html_log(0,"ROWID: airdate_imdb(%s)",asctime(localtime((time_t *)&(rid->airdate_imdb))));
    html_log(0,"----");
}

#define ALL_IDS -1
int parse_row(
        int num_ids, // number of ids passed in the idlist parameter of the query string
        int *ids,    // sorted array of ids passed in query string idlist.
        int tv_or_movie_view, // true if looking at tv or moview view.
        char *buffer,  // The current buffer contaning a line of input from the database
        Db *db,        // the database
        DbRowId *rowid// current rowid structure to populate.
        ) {

    assert(db);
    assert(rowid);

    memset(rowid,0,sizeof(*rowid));
    rowid->rating=0;
    rowid->watched=0;

    rowid->db = db;
    rowid->season = -1;
    rowid->category='?';

    int report_error=1;

    switch(buffer[0]) {
        case '\t':
            if (extract_field_long(DB_FLDID_ID,buffer,&(rowid->id),0)) {

                // Filter on id if necessary
                //html_log(0,"dbg row id = %ld",rowid->id);
                if (num_ids == ALL_IDS || in_idlist(rowid->id,num_ids,ids)) {

                    if (extract_field_timestamp(DB_FLDID_INDEXTIME,buffer,&(rowid->date),0)) {

                        if (extract_field_str(DB_FLDID_TITLE,buffer,&(rowid->title),0)) {
                            if (extract_field_str(DB_FLDID_POSTER,buffer,&(rowid->poster),0)) {

                                extract_field_int(DB_FLDID_WATCHED,buffer,&(rowid->watched),1);
                                assert(rowid->watched == 0 || rowid->watched == 1);

                                extract_field_int(DB_FLDID_SEASON,buffer,&(rowid->season),1);
                                extract_field_char(DB_FLDID_CATEGORY,buffer,&(rowid->category),1);
                                extract_field_str(DB_FLDID_GENRE,buffer,&(rowid->genre),0);

                                //if (in_text_mode() || (rowid->category != 'M' && rowid->category != 'T' ) ) {

            //html_log(0,"db getting file..");
                                    extract_field_str(DB_FLDID_FILE,buffer,&(rowid->file),0);
            //html_log(0,"db file = [%s]",rowid->file);
                                    rowid->ext = strrchr(rowid->file,'.');
            //html_log(0,"db ext = [%s]",rowid->ext);
                                    if (rowid->ext) rowid->ext++;
            //html_log(0,"db ext = [%s]",rowid->ext);

                                    extract_field_str(DB_FLDID_CERT,buffer,&(rowid->certificate),0);
                                    extract_field_str(DB_FLDID_CERT,buffer,&(rowid->certificate),0);
            //html_log(0,"db cert = [%s]",rowid->certificate);

                                //}
                                if (tv_or_movie_view) {
                                    extract_field_str(DB_FLDID_FANART,buffer,&(rowid->fanart),0);
                                    extract_field_str(DB_FLDID_URL,buffer,&(rowid->url),0);
                                    extract_field_str(DB_FLDID_PARTS,buffer,&(rowid->parts),0);
                                    //the big one!
                                    extract_field_str(DB_FLDID_PLOT,buffer,&(rowid->plot),0);
                                    if (strlen(rowid->plot) > g_dimension->max_plot_length) {
                                        strcpy(rowid->plot + g_dimension->max_plot_length -4 , "...");
                                    }

                                    extract_field_double(DB_FLDID_RATING,buffer,&(rowid->rating),0);
                                    extract_field_int(DB_FLDID_EPISODE,buffer,&(rowid->episode),0);

                                    extract_field_str(DB_FLDID_EPTITLE,buffer,&(rowid->eptitle),0);
                                    extract_field_str(DB_FLDID_EPTITLEIMDB,buffer,&(rowid->eptitle_imdb),0);

                                    extract_field_str(DB_FLDID_ADDITIONAL_INFO,buffer,&(rowid->additional_nfo),0);

                                    extract_field_date(DB_FLDID_AIRDATE,buffer,&(rowid->airdate),0);
                                    extract_field_date(DB_FLDID_AIRDATEIMDB,buffer,&(rowid->airdate_imdb),0);

                                }
                                // If doing actions we need to get the nfo file. 
                                // Also get it during normal load if there are files queued to delete.
                                // in the latter case remove the file from the queue is it is still in use.
                                extract_field_str(DB_FLDID_NFO,buffer,&(rowid->nfo),0);
                                /*
                                if (deleting == PRE_DELETE || g_delete_queue != NULL) {
                                    extract_field_str(DB_FLDID_NFO,buffer,&(rowid->nfo),0);
                                    if (deleting != PRE_DELETE) {
                                        delete_queue_remove(rowid->nfo);
                                        free(rowid->nfo);
                                        rowid->nfo = NULL;
                                    }
                                }
                                */

                                // The folowing files are removed from the delete queue whenever they are parsed.
                                delete_queue_unqueue(rowid->db->source,rowid->nfo);
                                delete_queue_unqueue(rowid->db->source,rowid->poster);

                                return 1;
                            }
                        }
                    }
                } else {
                    report_error=0;
                }
            }
            if (report_error) {
                html_error("Failed to parse row {%s}",buffer);
            }
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

// Return 1 if db should be scanned accoring to html get parameters.
int db_to_be_scanned(char *name) {
    static char *idlist = NULL;
    if (idlist == NULL) {
        idlist = query_val("idlist");
    }
    if (*idlist) {
        //Look for "name(" in idlist
        char *p = idlist;
        char *q;
        int name_len = strlen(name);

        while((q=strstr(p,name)) != NULL) {
            if (q[name_len] == '(') {
                return 1;
            }
            p = q+name_len;
        }
        return 0;
    } else {
        // Empty idlist parameter - always scan
        return 1;
    }
}

void db_scan_and_add_rowset(char *path,char *name,char *name_filter,int media_type,int watched,
        int *rowset_count_ptr,DbRowSet ***row_set_ptr) {

    if (db_to_be_scanned(name)) {

        Db *db = db_init(path,name);

        if (db) {

            int this_db_size=0;
            DbRowSet *r = db_scan_titles(db,name_filter,media_type,watched,&this_db_size);

            if ( r != NULL ) {

                (*row_set_ptr) = REALLOC(*row_set_ptr,((*rowset_count_ptr)+2)*sizeof(DbRowSet*));
                (*row_set_ptr)[(*rowset_count_ptr)++] = r;
                (*row_set_ptr)[(*rowset_count_ptr)]=NULL;

                g_db_size += this_db_size;

            }
        }
    }
}


//
// Returns null terminated array of rowsets
DbRowSet **db_crossview_scan_titles(
        int crossview,
        char *name_filter,  // only load lines whose titles match the filter
        int media_type,     // 1=TV 2=MOVIE 3=BOTH 
        int watched         // 1=watched 2=unwatched 3=any
        ){
    int rowset_count=0;
    DbRowSet **rowsets = NULL;

    // Add information from the local database
    db_scan_and_add_rowset(
        localDbPath(),"*",
        name_filter,media_type,watched,
        &rowset_count,&rowsets);

    if (crossview) {
        //get iformation from any remote databases
        DIR *d = opendir(NETWORK_SHARE);
        if (d) {
            struct dirent dent,*p;
            while((readdir_r(d,&dent,&p)) == 0) {

                char *path=NULL;
                char *name=dent.d_name;

                ovs_asprintf(&path,NETWORK_SHARE"%s/Apps/oversight/index.db",name);
                if (is_file(path)) {

                    db_scan_and_add_rowset(
                        path,name,
                        name_filter,media_type,watched,
                        &rowset_count,&rowsets);

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

//integer compare function for sort.
int id_cmp_fn(const void *i,const void *j) {
    return (*(const int *)i) - (*(const int *)j);
}

// For a given db name - extract and sort the list of ids in the idlist query param
// eg idlist=dbname(id1|id2|id3)name2(id4|id5)...
// if there is no idlist then ALL ids are OK. to indicate this num_ids = -1
int *extract_idlist(char *db_name,int *num_ids) {

    char *query = query_val("idlist");
    int *result = NULL;

    html_log(0,"extract_idlist from [%s]",query);

    if (*query) {
        *num_ids = 0;
        char *p = delimited_substring(query,')',db_name,'(',1,0);
        if (p) {
            p += strlen(db_name)+1;
            char *q = strchr(p,')');
            if (q) {
                *q = '\0';
                Array *idstrings = split(p,"|",0);
                *q = ')';
                if (idstrings) {
                    result = malloc(idstrings->size * sizeof(int));
                    int i;
                    for(i = 0 ; i < idstrings->size ; i++ ) {
                        char ch;
                        result[i]=0;
                        sscanf(idstrings->array[i],"%d%c",result+i,&ch);
                    }
                    // Sort the ids.
                    qsort(result,idstrings->size,sizeof(int),id_cmp_fn);
                    *num_ids = idstrings->size;

                    array_free(idstrings);
                }
            }
        }

    } else {
        *num_ids = ALL_IDS;
    }

    if (*num_ids == ALL_IDS) {
        html_log(0,"db: name=%s searching all ids",db_name);
    } else {
        int i;
        for(i  = 0 ; i < *num_ids ; i++ ) {
            html_log(0,"db: name=%s id %d",db_name,result[i]);
        }
    }

    return result;
}

// quick binary chop to search list.
int in_idlist(int id,int size,int *ids) {

    if (size == 0) return 0;
    if (size == ALL_IDS) return 1;

    int min=0;
    int max=size;
    int mid;
    do {
        mid = (min+max) / 2;

        if (id < ids[mid] ) {

            max = mid;

        } else if (id > ids[mid] ) {

            min = mid + 1 ;

        } else {

            html_log(0,"found %d",ids[mid]);
            return 1;
        }
    } while (min < max);

    //html_log("not found %d",id);
    return 0;
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

    char *view=query_val("view");
    int tv_or_movie_view = (strcmp(view,"tv")==0 || strcmp(view,"movie") == 0);

    int num_ids;
    int *ids = extract_idlist(db->source,&num_ids);

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


    int row_count=0;
    int total_rows=0;

    html_log(2,"db scanning %s",db->path);

    FILE *fp = fopen(db->path,"r");
    html_log(2,"db scanning %s",db->path);
    assert(fp);
html_log(2,"db fp.%ld..",(long)fp);
    if (fp) {
        rowset=db_rowset(db);
        DbRowId rowid;
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
html_log(2,"db start loop...");

        while (1) {
            /*
             * TODO: Further optimisation - replace fgets with function that parses 
             * input using fgetc directly into hashtable name value pairs.
             */
            buffer[DB_ROW_BUF_SIZE]='\0';
            if (fgets(buffer,DB_ROW_BUF_SIZE,fp) == NULL) break;
            assert( buffer[DB_ROW_BUF_SIZE] == '\0');

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


            if (parse_row(num_ids,ids,tv_or_movie_view,buffer,db,&rowid)) {
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
    free(ids);
    return rowset;
}

void db_free(Db *db) {


    if (db->locked_by_this_code) {
        db_unlock(db);
    }

    free(db->source);
    free(db->path);
    free(db->lockfile);
    free(db->backup);
    free(db);

}


void db_rowid_free(DbRowId *rid,int free_base) {

    assert(rid);

    free(rid->title);
    free(rid->poster);
    free(rid->genre);
    free(rid->file);
    //Dont free ext as it points to file.


    // Following are only set in tv/movie view
    free(rid->url);
    free(rid->parts);
    free(rid->fanart);
    free(rid->plot);
    free(rid->eptitle);
    free(rid->eptitle_imdb);
    free(rid->additional_nfo);

    //Only populated if deleting
    free(rid->nfo);

    free(rid->certificate);
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

void db_set_fields_by_source(
        char *field_id,char *new_value,char *source,char *idlist,int delete_mode) {

html_log(0," begin db init");

    Db *db = db_init(NULL,source);

    int new_len = 0;
    
    if (new_value != NULL) {
        new_len = strlen(new_value);
    }

    char *id_regex_text;
    regex_t id_regex_ptn;

    char *regex_text;
    regex_t regex_ptn;

    char buf[DB_ROW_BUF_SIZE+1];

    regmatch_t pmatch[5];

    ovs_asprintf(&regex_text,"\t%s\t([^\t]+)\t",field_id);
    util_regcomp(&regex_ptn,regex_text,0);

    ovs_asprintf(&id_regex_text,"\t%s\t(%s)\t",DB_FLDID_ID,idlist);
    util_regcomp(&id_regex_ptn,id_regex_text,0);


html_log(0," begin db_set_fields_by_source ids %s(%s) %s=%s ",source,idlist,field_id,new_value);

    if (db && db_lock(db)) {
html_log(0," begin open db");
        FILE *db_in = fopen(db->path,"r");

        if (db_in) {
            char *tmpdb="/share/Apps/oversight/index.db.tmp";

            FILE *db_out = fopen(tmpdb,"w");

            if (db_out) {
                while(1) {
                    
                    buf[DB_ROW_BUF_SIZE]='\0';

                    if (fgets(buf,DB_ROW_BUF_SIZE,db_in) == NULL) {
                        break;
                    }

                    assert( buf[DB_ROW_BUF_SIZE] == '\0' );



                    if (regexec(&id_regex_ptn,buf,0,NULL,0) == 0 && regexec(&regex_ptn,buf,2,pmatch,0) == 0) {

                        if (delete_mode == DELETE_MODE_REMOVE) {
                            // do nothing. line is not written 
                        } else if (delete_mode == DELETE_MODE_DELETE) {
                            DbRowId rid;
                            parse_row(ALL_IDS,NULL,0,buf,db,&rid);
                            delete_media(&rid,1);
                            db_rowid_free(&rid,0);
                        } else {
                            int spos=pmatch[1].rm_so;
                            int epos=pmatch[1].rm_eo;

html_log(0," got regexec %s %s from %d to %d ",id_regex_text,regex_text,spos,epos);

                            buf[spos]='\0';

                            fprintf(db_out,"%s%s%s",buf,new_value,buf+epos);
                        }

                    } else {

                        fprintf(db_out,"%s",buf);

                    }

                }
                fclose(db_out);
            }

            fclose(db_in);
            util_rename(db->path,db->backup);
            util_rename(tmpdb,db->path);
        }
        db_unlock(db);
        db_free(db);
    }
html_log(0," end db_set_fields_by_source");
    regfree(&regex_ptn);
    regfree(&id_regex_ptn);
    FREE(regex_text);
    FREE(id_regex_text);

}

void db_set_fields(char *field_id,char *new_value,struct hashtable *ids_by_source,int delete_mode) {
    struct hashtable_itr *itr;
    char *source;
    char *idlist;

html_log(0," begin db_set_fields");
    for(itr=hashtable_loop_init(ids_by_source) ; hashtable_loop_more(itr,&source,&idlist) ; ) {
        db_set_fields_by_source(field_id,new_value,source,idlist,delete_mode);
    }
html_log(0," end db_set_fields");
}


