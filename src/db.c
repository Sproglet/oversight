// $Id:$
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <utime.h>
#include <errno.h>
#include <stdio.h>
#include <regex.h>
#include <assert.h>
#include <string.h>
#include <dirent.h>
#include <time.h>
#include <ctype.h>

#include "db.h"
#include "dbread.h"
#include "dboverview.h"
#include "dbplot.h"
#include "actions.h"
#include "dbfield.h"
#include "gaya_cgi.h"
#include "oversight.h"
#include "hashtable_loop.h"
#include "network.h"
#include "mount.h"

#define DB_ROW_BUF_SIZE 6000
#define QUICKPARSE

#define HEX_YEAR_OFFSET 1900
#define EOL(c)  ((c) == '\n'  ||  (c) == '\r' || (c) == '\0' )
#define SEP(c)  ((c) == '\t' ) 
#define TERM(c)  ( ( (c) == '\n' ) || ( (c) == '\r' ) || ( (c) == '\0' ) || (c) == EOF )

/*
static long read_and_parse_row_ticks=0;
static long assign_ticks=0;
static long inner_date_ticks=0;
static long date_ticks=0;
static long filter_ticks=0;
static long discard_ticks=0;
static long keep_ticks=0;
*/
#define START_CLOCK(x) 
#define STOP_CLOCK(x) 

char *copy_string(int len,char *s);
DbRowId *db_rowid_new(Db *db);
DbRowId *db_rowid_init(DbRowId *rowid,Db *db);
DbRowId *read_and_parse_row(
        DbRowId *rowid,
        Db *db,
        FILE *fp,
        int *eof,
        int tv_or_movie_view // true if looking at tv or moview view.
        );
int in_idlist(int id,int size,int *ids);
void get_genre_from_string(char *gstr,struct hashtable **h);
void fix_file_path(DbRowId *rowid);

#define UNSET -2
static int use_folder_titles = UNSET;

char *copy_string(int len,char *s)
{
    char *p=NULL;
    if (s) {
        p = MALLOC(len+1);
        memcpy(p,s,len+1);
    }
    return p;
}

int db_lock_pid(Db *db)
{

    int lockpid=0;

    if (is_file(db->lockfile)) {

        FILE *fp = fopen(db->lockfile,"r");

        fscanf(fp,"%d\n",&lockpid);
        fclose(fp);
    }
    return lockpid;
}

int db_is_locked_by_another_process(Db *db)
{

    int result=0;
    int lockpid =  db_lock_pid(db) ;

    if ( lockpid != 0 && lockpid != getpid() ) {
        char *dir;
        ovs_asprintf(&dir,"/proc/%d",lockpid);
        if (is_dir(dir)) {
            HTML_LOG(1,"Database locked by pid=%d current pid=%d",lockpid,getpid());
            result=1;
        } else {
            HTML_LOG(1,"Database was locked by pid=%d current pid=%d : releasing lock",lockpid,getpid());
        }
        FREE(dir);
    }
    return result;
}

int db_lock(Db *db)
{

    int backoff[] = { 10,10,10,10,10,10,20,30, 0 };

    int attempt;

    db->locked_by_this_code=0;
    for(attempt = 0 ; backoff[attempt] && db->locked_by_this_code ==0 ; attempt++ ) {

        if (db_is_locked_by_another_process(db)) {

            sleep(backoff[attempt]);
            HTML_LOG(1,"Sleeping for %d\n",backoff[attempt]);

        } else {
            db->locked_by_this_code=1;
        }
    }
    if (db->locked_by_this_code) {
        FILE *fp = fopen(db->lockfile,"w");
        fprintf(fp,"%d\n",getpid());
        fclose(fp);
        HTML_LOG(1,"Aquired lock [%s]\n",db->lockfile);
    } else {
        html_error("Failed to get lock [%s]\n",db->lockfile);
    }
    return db->locked_by_this_code;
}

int db_unlock(Db *db)
{

    db->locked_by_this_code=0;
    HTML_LOG(1,"Released lock [%s]\n",db->lockfile);
    return unlink(db->lockfile) ==0;
}

/*
 * Load the database. Each database entry will just be an ID and a pointer to the DB file position
 * (see DbRow)
 */
Db *db_init(char *filename, // path to the file - if NULL compute from source
        char *source       // logical name or tag - local="*"
        )
{
    int freepath;

TRACE;
    Db *db = CALLOC(1,sizeof(Db));

TRACE;
    if (filename == NULL) {
        db->path = get_mounted_path(source,"/share/Apps/oversight/index.db",&freepath);
        if (!freepath) {
            db->path = STRDUP(db->path);
        }
    } else {
        db->path =  STRDUP(filename);
    }
TRACE;
    db->plot_file = replace_all(db->path,"index.db","plot.db",0);

TRACE;
    db->source= STRDUP(source);

TRACE;
    ovs_asprintf(&(db->backup),"%s.%s",db->path,util_day_static());

TRACE;
    db->lockfile = replace_all(db->path,"index.db","catalog.lck",0);

TRACE;
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
    if (!quiet) HTML_LOG(1,"ERROR: Failed to find field [%s]",field_id);
    return 0;
}

int parse_date(char *field_id,char *buffer,OVS_TIME *val_ptr,int quiet)
{

    char term='\0';
    int y,m,d;

    if (!*buffer) {
        // blank is OK
        return 1;
    } else if (sscanf(buffer,"%4d-%d-%d%c",&y,&m,&d,&term) < 3) {
        if (!quiet) html_error("ERROR: failed to extract date field %s",field_id);
    } else if (term != '\t' && term != '\0') {
        if (!quiet) html_error("ERROR: bad terminator [%c=%d] after date field %s = %d %d",term,term,field_id,y,m,d);
    } else {
        struct tm t;
        t.tm_year = y - 1900;
        t.tm_mon = m - 1;
        t.tm_mday = d;
        t.tm_hour = 0;
        t.tm_min = 0;
        t.tm_sec = 0;
        *val_ptr = time_ordinal(&t);
        if (*val_ptr < 0 ) {
            HTML_LOG(1,"bad date %d/%02d/%02d = %s",y,m,d,asctime(&t));
        }
        return 1;
    }
    return 0;
}

#define FIELD_TYPE_NONE '-'
#define FIELD_TYPE_STR 's'
#define FIELD_TYPE_DOUBLE 'f'
#define FIELD_TYPE_CHAR 'c'
#define FIELD_TYPE_LONG 'l'
#define FIELD_TYPE_YEAR 'y'
#define FIELD_TYPE_INT 'i'
#define FIELD_TYPE_DATE 'd'
#define FIELD_TYPE_TIMESTAMP 't'
#define FIELD_TYPE_IMDB_LIST 'I'

// Most field ids have the form _a or _ab. This function looks at th first few letters of the 
// id and returns its type (FIELD_TYPE_STR,FIELD_TYPE_INT etc) and its offset within the DbRowId structure.
static inline int db_rowid_get_field_offset_type(DbRowId *rowid,char *name,void **offset,char *type,int *overview) {

    register char *p = name;
    *offset=NULL;
    *type = FIELD_TYPE_NONE;
    *overview = 0;



    if  (*p++ == '_' ) {

        switch(*p++) {
            case 'a':
                if (*p == 'i' ) { // _ai
                    *offset=&(rowid->additional_nfo);
                    *type = FIELD_TYPE_STR;

                } else if (*p == 'd' ) { // _ad...

                    if (p[1] == '\0') { // _ad

                        *offset=&(rowid->airdate);
                        *type = FIELD_TYPE_DATE;

                    } else if (p[1] == 'i') { // _adi

                        *offset=&(rowid->airdate_imdb);
                        *type = FIELD_TYPE_DATE;

                    }
                } else if (*p == '\0' ) { // _a
                    *offset=&(rowid->comes_after);
                    *type = FIELD_TYPE_IMDB_LIST;
                    *overview = 1;
                }
                break;
            case 'b':
                if (*p == '\0' ) { // _b
                    *offset=&(rowid->comes_before);
                    *type = FIELD_TYPE_IMDB_LIST;
                    *overview = 1;
                }
                break;
            case 'C':
                if (*p == '\0') { // _C
                    *offset=&(rowid->category);
                    *type = FIELD_TYPE_CHAR;
                    *overview = 1;
                }
                break;
            case 'd':
                if (*p == '\0') { // _d
                    *offset=&(rowid->director);
                    *type = FIELD_TYPE_STR;
                }
                break;
            case 'D':
                if (*p == 'T' ) {
                    *offset=&(rowid->downloadtime);
                    *type = FIELD_TYPE_TIMESTAMP;
                    *overview = 1;
                }
                break;
            case 'e':
                if (*p == '\0') { // _e
                    *offset=&(rowid->episode);
                    *type = FIELD_TYPE_STR;
                }else if (*p == 't') {
                    if (p[1] == '\0') { // _et
                        *offset=&(rowid->eptitle);
                        *type = FIELD_TYPE_STR;
                    } else if (p[1] == 'i') { // _eti
                        *offset=&(rowid->eptitle_imdb);
                        *type = FIELD_TYPE_STR;
                    }
    //            }else if (name[2] == 'p') { // _ep
    //                *offset=&(rowid->episode_plot_key);
    //                *type = FIELD_TYPE_STR;
                }
                break;
            case 'f':
                    if (*p == 'a') {
                        *offset=&(rowid->fanart);
                        *type = FIELD_TYPE_STR;
                    }
                break;
            case 'F':
                if (*p == '\0') {
                    *offset=&(rowid->file);
                    *type = FIELD_TYPE_STR;
                    *overview = 1;
                } else if (*p == 'T' ) {
                    *offset=&(rowid->filetime);
                    *type = FIELD_TYPE_TIMESTAMP;
                    *overview = 1;
                }
                break;

            case 'G':
                if (*p == '\0') {
                    *offset=&(rowid->genre);
                    *type = FIELD_TYPE_STR;
                    *overview = 1;
                }
                break;
            case 'J':
                if (*p == '\0') {
                    *offset=&(rowid->poster);
                    *type = FIELD_TYPE_STR;
                }
                break;
            case 'i':
                if (*p == 'd') {
                    *offset=&(rowid->id);
                    *type = FIELD_TYPE_LONG;
                    *overview = 1;
                }
                break;
            case 'I':
                if (*p == 'T') {
                    *offset=&(rowid->date);
                    *type = FIELD_TYPE_TIMESTAMP;
                    *overview = 1;
                }
                break;
            case 'k':
                if (*p == '\0' ) { // _k
                    *offset=&(rowid->remakes);
                    *type = FIELD_TYPE_IMDB_LIST;
                    *overview = 1;
                }
                break;
            case 'n':
                    if (*p == 'f') {
                        *offset=&(rowid->nfo);
                        *type = FIELD_TYPE_STR;
                    }
                break;
            case 'o':
                if (*p == 't') {
                    *offset=&(rowid->orig_title);
                    *type = FIELD_TYPE_STR;
                }
                break;
            case 'p':
                    if (*p == 't') {
                        *offset=&(rowid->parts);
                        *type = FIELD_TYPE_STR;
                    }
                break;
    //        case 'P':
    //                if (name[2] == '\0') {
    //                *offset=&(rowid->plot_key);
    //                *type = FIELD_TYPE_STR;
    //                }
    //            break;
            case 'r':
                if (*p == '\0') {
                    *offset=&(rowid->rating);
                    *type = FIELD_TYPE_DOUBLE;
                    *overview = 1;
                } else if (*p == 't') {
                    *offset=&(rowid->runtime);
                    *type = FIELD_TYPE_INT;
                }
                break;
            case 'R':
                if (*p == '\0') {
                    *offset=&(rowid->certificate);
                    *type = FIELD_TYPE_STR;
                    *overview = 1;
                }
                break;
            case 's':
                if (*p == '\0') {
                    *offset=&(rowid->season);
                    *type = FIELD_TYPE_INT;
                    *overview = 1;
                }
                break;
            case 't':
                //do nothing - TVCOM
                break;
            case 'T':
                if (*p == '\0') {
                    *offset=&(rowid->title);
                    *type = FIELD_TYPE_STR;
                    *overview = 1;
                }
                break;
            case 'U':
                if (*p == '\0') {
                    *offset=&(rowid->url);
                    *type = FIELD_TYPE_STR;
                    *overview = 1;
                }
                break;
            case 'w':
                if (*p == '\0') {
                    *offset=&(rowid->watched);
                    *type = FIELD_TYPE_INT;
                    *overview = 1;
                }
                break;
            case 'Y':
                if (*p == '\0') {
                    *offset=&(rowid->year) ;
                    *type = FIELD_TYPE_YEAR;
                    *overview = 1;
                }
                break;
        }
    }
    if (*type == FIELD_TYPE_NONE) {
        HTML_LOG(-1,"Unknown field [%s]",name);
        return 0;
    }
    return 1;

}
// Return string representation of a field the way a user would like to see it.
// TODO: Need to add expand for genre codes.
char * db_rowid_get_field(DbRowId *rowid,char *name)
{

    char *result=NULL;
    void *offset;
    char type;
    int overview;

    if (!db_rowid_get_field_offset_type(rowid,name,&offset,&type,&overview)) {
        return NULL;
    }

    //HTML_LOG(0,"db_rowid_get_field of [%s] %d=%d?",rowid->title,I//);

    switch(type) {
        case FIELD_TYPE_STR:
            ovs_asprintf(&result,"%s",NVL(*(char **)offset));
            break;
        case FIELD_TYPE_CHAR:
            ovs_asprintf(&result,"%c",*(char *)(offset));
            break;
        case FIELD_TYPE_DOUBLE:
            ovs_asprintf(&result,"%.1lf",*(double *)offset);
            break;
        case FIELD_TYPE_YEAR:
            ovs_asprintf(&result,"%d",*(int *)offset);
            break;
        case FIELD_TYPE_INT:
            ovs_asprintf(&result,"%d",*(int *)offset);
            break;
        case FIELD_TYPE_LONG:
            ovs_asprintf(&result,"%ld",*(long *)offset);
            break;
        case FIELD_TYPE_DATE:
            ovs_asprintf(&result,"%s",fmt_date_static(*(OVS_TIME *)offset));
            break;
        case FIELD_TYPE_TIMESTAMP:
            ovs_asprintf(&result,"%s",fmt_timestamp_static(*(OVS_TIME *)offset));
            break;
        default:
            HTML_LOG(0,"Bad field type [%c]",type);
            assert(0);
    }
    return result;
}

static inline void db_rowid_set_field(DbRowId *rowid,char *name,char *val,int val_len,int tv_or_movie_view) {

    void *offset;
    char type;
    int overview;

    if (!db_rowid_get_field_offset_type(rowid,name,&offset,&type,&overview)) {
        return;
    }
    //Dont get the field if this is the menu view and it is not an overview field 
    if (tv_or_movie_view || overview) {

        // Used to checl for trailing chars.
        char *tmps=NULL;


        switch(type) {
            case FIELD_TYPE_STR:

                *(char **)offset = COPY_STRING(val_len,val);
                if (offset == &(rowid->file)) {

                    fix_file_path(rowid);
                }
                break;
            case FIELD_TYPE_CHAR:
                *(char *)offset = *val;
                break;
            case FIELD_TYPE_YEAR:
                if (strlen(val) > 3) {
                    *(int *)offset=strtol(val,&tmps,10) ;
                } else {
                    *(int *)offset=strtol(val,&tmps,16)+HEX_YEAR_OFFSET ;
                    //HTML_LOG(0,"year %s = %d",val,*(int *)offset);
                }
                break;
            case FIELD_TYPE_INT:
                *(int *)offset=strtol(val,&tmps,10) ;
                break;
            case FIELD_TYPE_LONG:
                *(long *)offset=strtol(val,&tmps,10) ;
                break;
            case FIELD_TYPE_DOUBLE:
                sscanf(val,"%lf",(double *)offset);
                break;
            case FIELD_TYPE_DATE:
                parse_date(name,val,offset,0);
                break;
            case FIELD_TYPE_TIMESTAMP:
                *(long *)offset=strtol(val,&tmps,16) ;
                break;
            case FIELD_TYPE_IMDB_LIST:
                *(DbGroupIMDB **)offset = parse_imdb_list(val,val_len);
                break;
            default:
                HTML_LOG(0,"Bad field type [%c]",type);
                assert(0);
        }
    }
}



OVS_TIME *timestamp_ptr(DbRowId *rowid)
{
    static int age_field_scantime = -1;
    if (age_field_scantime== -1) {
       age_field_scantime = (STRCMP(oversight_val("ovs_age_field"),"scantime") == 0);
    }
    if (age_field_scantime) {
        return &(rowid->date);
    } else {
        return &(rowid->filetime);
    }
}



void fix_file_path(DbRowId *rowid)
{
    // Append Network share path
    if (rowid->file[0] != '/') {
        char *tmp;
        ovs_asprintf(&tmp,"%s%s" , NETWORK_SHARE, rowid->file );
        FREE(rowid->file);
        rowid->file = tmp;
    }
    // set extension
    char *p = strrchr(rowid->file,'.');
    if (p) {
        rowid->ext = p+1;
    }
}

void fix_file_paths(int num_row,DbRowId **rows)
{
    int i;
    for(i = 0 ; i < num_row ; i++ ) {
        DbRowId *rid;
        for(rid = rows[i] ; rid ; rid = rid->linked ) {
            // Append Network share path
            fix_file_path(rid);
        }
    }
}

void set_title_as_folder(DbRowId *rowid)
{

    char *e=strrchr(rowid->file,'\0');
    char *s = NULL;
    int is_vob=0;

    if (e && e > rowid->file) {

        e--;
        s = e;

        if (e > rowid->file && *e == '/') {
            *e = '\0';
            s--;
            is_vob=1;
        }
        while(s > rowid->file && *s != '/') {
            s--;
        }
        if ( s >= rowid->file ) {
            HTML_LOG(1,"Title changed from [%s] to [%s]",rowid->title,s);
            FREE(rowid->title);
            rowid->title = STRDUP(s);
            if (is_vob) {
                *e='/';
            }
        }
    }
}

#define DB_NAME_BUF_SIZE 10
#define DB_VAL_BUF_SIZE 4000
#define ROW_SIZE 10000

//changes here should be reflected in catalog.sh.full:createIndexRow()
void write_row(FILE *fp,DbRowId *rid) {
    fprintf(fp,"\t%s\t%ld",DB_FLDID_ID,rid->id);
    fprintf(fp,"\t%s\t%c",DB_FLDID_CATEGORY,rid->category);
    fprintf(fp,"\t%s\t%s",DB_FLDID_INDEXTIME,fmt_timestamp_static(rid->date));
    fprintf(fp,"\t%s\t%d",DB_FLDID_WATCHED,rid->watched);
    fprintf(fp,"\t%s\t%s",DB_FLDID_TITLE,rid->title);
    fprintf(fp,"\t%s\t%d",DB_FLDID_SEASON,rid->season);
    fprintf(fp,"\t%s\t%.1lf",DB_FLDID_RATING,rid->rating);
    fprintf(fp,"\t%s\t%s",DB_FLDID_EPISODE,rid->episode);
    //fprintf(fp,"\t%s\t%s",DB_FLDID_POSTER,rid->poster);
    fprintf(fp,"\t%s\t%s",DB_FLDID_GENRE,rid->genre);
    fprintf(fp,"\t%s\t%d",DB_FLDID_RUNTIME,rid->runtime);
    fprintf(fp,"\t%s\t%s",DB_FLDID_PARTS,rid->parts);
    fprintf(fp,"\t%s\t%x",DB_FLDID_YEAR,rid->year-HEX_YEAR_OFFSET);

    // Remove Network share path
    if (util_starts_with(rid->file,NETWORK_SHARE)) {
        fprintf(fp,"\t%s\t%s",DB_FLDID_FILE,rid->file+strlen(NETWORK_SHARE));
    } else {
        fprintf(fp,"\t%s\t%s",DB_FLDID_FILE,rid->file);
    }

    fprintf(fp,"\t%s\t%s",DB_FLDID_ADDITIONAL_INFO,rid->additional_nfo);
    fprintf(fp,"\t%s\t%s",DB_FLDID_URL,rid->url);
    fprintf(fp,"\t%s\t%s",DB_FLDID_CERT,rid->certificate);
    if (rid->director) {
        fprintf(fp,"\t%s\t%s",DB_FLDID_DIRECTOR,NVL(rid->director));
    }
    fprintf(fp,"\t%s\t%s",DB_FLDID_FILETIME,fmt_timestamp_static(rid->filetime));
    fprintf(fp,"\t%s\t%s",DB_FLDID_DOWNLOADTIME,fmt_timestamp_static(rid->downloadtime));
    //fprintf(fp,"\t%s\t%s",DB_FLDID_PROD,rid->prod);
    fprintf(fp,"\t%s\t%s",DB_FLDID_AIRDATE,fmt_date_static(rid->airdate));

    // TODO: Deprecate
    fprintf(fp,"\t%s\t%s",DB_FLDID_EPTITLEIMDB,rid->eptitle_imdb);
    // TODO: Deprecate
    fprintf(fp,"\t%s\t%s",DB_FLDID_AIRDATEIMDB,fmt_date_static(rid->airdate_imdb));

    fprintf(fp,"\t%s\t%s",DB_FLDID_EPTITLE,rid->eptitle);
    fprintf(fp,"\t%s\t%s",DB_FLDID_NFO,rid->nfo);
    if (rid->comes_after) {
        fprintf(fp,"\t%s\t%s",DB_FLDID_COMES_AFTER,db_group_imdb_compressed_string_static(rid->comes_after));
    }
    if (rid->comes_before) {
        fprintf(fp,"\t%s\t%s",DB_FLDID_COMES_BEFORE,db_group_imdb_compressed_string_static(rid->comes_before));
    }
    if (rid->remakes) {
        fprintf(fp,"\t%s\t%s",DB_FLDID_REMAKE,db_group_imdb_compressed_string_static(rid->remakes));
    }
    //fprintf(fp,"\t%s\t%s",DB_FLDID_FANART,rid->fanart);
    //fprintf(fp,"\t%s\t%s",DB_FLDID_PLOT,rid->plot_key);
    //fprintf(fp,"\t%s\t%s",DB_FLDID_EPPLOT,rid->episode_plot_key);
    fprintf(fp,"\t\n");
    fflush(fp);
}


// There are two functions to read the db - this one and parse_row()
// They should be consolidated.
// This one does a full table scan.
//
// Some ways to speed this up:
// increase buffer for file descriptor setvbuf()
// use fread()
// use read()
//
DbRowId *dbread_and_parse_row(
        DbRowId *rowid,
        Db *db,
        ReadBuf *fp,
        int *eof,
        int tv_or_movie_view // true if looking at tv or moview view.
        )
{

    db_rowid_init(rowid,db);


    register char * next;

    char *name,*name_end;
    char *value,*value_end;


    *eof = 0;

    next = fp->data_start;

    //HTML_LOG(0,"dbline start[%.20s]",next);
    
    // Skip comment lines
    while(next && *next == '#') {
        next = dbreader_advance_line(fp,next);
    }
    //HTML_LOG(0,"dbline starting[%.20s]",next);

    if (next == NULL) {
        *eof = 1;
        rowid = NULL;
    } else {

        // Here we assume the buffer will hold a complete line so it MUST have \r\n or \0
        // search for first tab
        while(*next && !SEP(*next)) next++;


        //HTML_LOG(0,"dbline start/cur/end = %u / (%d,%u) / %u",fp->data_start,*next,next,fp->data_end);
        if (*next == '\t' ) {

            //HTML_LOG(0,"dbline start/cur/end = %u / (%d,%u) / %u",fp->data_start,*next,next,fp->data_end);
            next++;

            if ( *next == '_' ) {

            // Loop starts at first character after _
                do {
                    //HTML_LOG(0,"dbline name loop start/cur/end = %u / (%d,%u) / %u",fp->data_start,*next,next,fp->data_end);

                    name = name_end =  next;
                    while(*next && !SEP(*next)) {
                        next ++;
                    }
                    name_end = next;

                    //HTML_LOG(0,"parse name=[%.*s]",name_end-name,name);
                    //HTML_LOG(0,"dbline val? start/cur/end = %u / (%d,%u) / %u",fp->data_start,*next,next,fp->data_end);

                    if (*next == '\t') {
                        // "<tab> Name <tab>" expect value
                        value = value_end = ++next;

                        // Read until we hit a SEP - unless it not followed by underscore - which is expected.
                        while ( *next &&  (  !SEP(*next) || ( !EOL(next[1]) && next[1] != '_' ))) {
                            next++;
                        }

                        value_end = next;
                        //HTML_LOG(0,"parse value=[%.*s]",value_end-value,value);


                        if (*name && *value) {

                            char ntmp,vtmp;
                            ntmp = *name_end;
                            vtmp = *value_end;

                            *value_end = *name_end = '\0';

                            db_rowid_set_field(rowid,name,value,value_end-value,tv_or_movie_view);

                            *name_end = ntmp;
                            *value_end = vtmp;

                        }
                    }
                    // Seek to next name
                    while (*next == '\t' ) { 
                        next++;
                    } 

                } while (*next == '_');
            }
        }
        //HTML_LOG(0,"dbline ending %d[%.20s]",*next,next);

        // Skip EOL characters,
        dbreader_advance_line(fp,next);
        //HTML_LOG(0,"dbline finished at [%.20s]",fp->data_start);

    //    if (rowid->genre == NULL) {
    //        HTML_LOG(0,"no genre [%s][%s]",rowid->file,rowid->title);
    //    }
        if (use_folder_titles) {

            set_title_as_folder(rowid);
        }
    }

    return rowid;
}

DbRowId *db_rowid_init(DbRowId *rowid,Db *db) {
    int i;
    memset(rowid,0,sizeof(DbRowId));
    rowid->rating=0;

    rowid->db = db;
    rowid->season = 1;
    rowid->category='?';
    for(i = 0 ; i < PLOT_TYPE_COUNT ; i++ ) {
        rowid->plotoffset[i] = PLOT_POSITION_UNSET;
    }
    return rowid;
}
DbRowId *db_rowid_new(Db *db) {

    DbRowId *rowid = MALLOC(sizeof(*rowid));
    db_rowid_init(rowid,db);
    return rowid;
}

void db_rowid_dump(DbRowId *rid) {
    
    time_t t;
    HTML_LOG(1,"ROWID: id = %d",rid->id);
    HTML_LOG(1,"ROWID: watched = %d",rid->watched);
    HTML_LOG(1,"ROWID: title(%s)",rid->title);
    HTML_LOG(1,"ROWID: file(%s)",rid->file);
    HTML_LOG(1,"ROWID: ext(%s)",rid->ext);
    HTML_LOG(1,"ROWID: season(%d)",rid->season);
    HTML_LOG(1,"ROWID: episode(%s)",rid->episode);
    HTML_LOG(1,"ROWID: genre(%s)",rid->genre);
    HTML_LOG(1,"ROWID: ext(%c)",rid->category);
    HTML_LOG(1,"ROWID: parts(%s)",rid->parts);
    t = rid->date;
    HTML_LOG(1,"ROWID: date(%s)",asctime(localtime(&t)));
    HTML_LOG(1,"ROWID: eptitle(%s)",rid->eptitle);
    HTML_LOG(1,"ROWID: eptitle_imdb(%s)",rid->eptitle_imdb);
    HTML_LOG(1,"ROWID: additional_nfo(%s)",rid->additional_nfo);
    t = rid->airdate;
    HTML_LOG(1,"ROWID: airdate(%s)",asctime(localtime(&t)));
    t = rid->airdate_imdb;
    HTML_LOG(1,"ROWID: airdate_imdb(%s)",asctime(localtime(&t)));
    HTML_LOG(1,"ROWID: follows(%s)",db_group_imdb_string_static(rid->comes_after));
    HTML_LOG(1,"ROWID: followed by(%s)",db_group_imdb_string_static(rid->comes_before));
    HTML_LOG(1,"ROWID: remakes(%s)",db_group_imdb_string_static(rid->remakes));
    HTML_LOG(1,"----");
}


#define ALL_IDS -1
// There are two functions to parse a row. This one and read_and_parse_row().
// The should be brought together at some point!
// This function only reads the listed ids.
int parse_row(
        int num_ids, // number of ids passed in the idlist parameter of the query string. if ALL_IDS then id list is ignored.
        int *ids,    // sorted array of ids passed in query string idlist to use as a filter.
        int tv_or_movie_view, // true if looking at tv or moview view.
        char *buffer,  // The current buffer contaning a line of input from the database
        Db *db,        // the database
        DbRowId *rowid// current rowid structure to populate.
        ) {

    assert(db);
    assert(rowid);

    db_rowid_init(rowid,db);

    int result = 0;
    
    char *name_start = buffer;

    while(1) {

        char *name_end,*value_start,*value_end = NULL;

        //find start of name
        if (*name_start != '\t') {
            html_error("rowid %d: Tab expected before next field name",rowid->id);
            break;
        }

        name_start++;
        if (!*name_start || *name_start == 10 || *name_start == 13 ) {
            result = 1;
            break;
        }

        //find end of name00527SC 
        name_end=name_start;
        while(*name_end && *name_end != '\t') {
            name_end++;
        }
        if (*name_end != '\t') {
            HTML_LOG(-1,"rowid %d: Tab expected after next field name - got %c(%d) %c=%d",rowid->id,*name_start,*name_start,*name_end,*name_end);
            break;
        }
        *name_end = '\0';
        //HTML_LOG(-1,"fname[%s]",name_start);


        //find start of value
        value_end=value_start=name_end+1;
        while(*value_end) {
            if (*value_end == '\t') {
                // if the tab is followed by a field name or EOL then break.
                // This is added because some XML API return tabs. 
                // Really we should change separator to something else.
                switch(value_end[1]) {
                    case '_' : case '\n': case '\r' : case '\0' : 
                        goto got_value_end; //Yes it really is a goto
                }
            }
            value_end++;
        }
got_value_end:

        if (*value_end != '\t') {
            HTML_LOG(-1,"rowid %d: Tab expected after field value",rowid->id);
            break;
        }


        *value_end = '\0';

        int val_len=value_end-value_start;

        //HTML_LOG(-1,"fval[%s]",value_start);
        //
        //char *value_copy = MALLOC(val_len+1);
        //memcpy(value_copy,value_start,val_len+1);


        db_rowid_set_field(rowid,name_start,value_start,val_len,1);


        *name_end = *value_end = '\t';
        name_start = value_end;
    }
    // The folowing files are removed from the delete queue whenever they are parsed.
    delete_queue_unqueue(rowid,rowid->nfo);
    delete_queue_unqueue(rowid,rowid->poster);
    delete_queue_unqueue(rowid,rowid->fanart);

    result =   (result && (num_ids == ALL_IDS || in_idlist(rowid->id,num_ids,ids)) );
    if (!result) {
        db_rowid_free(rowid,0);
    }
    return result;
}

DbRowSet *db_rowset(Db *db) {
    assert(db);

    DbRowSet *dbrs = MALLOC(sizeof(DbRowSet));
    memset(dbrs,0,sizeof(DbRowSet));
    dbrs->db = db;
    return dbrs;
}


void db_rowset_add(DbRowSet *dbrs,DbRowId *id) {

    assert(id);
    assert(dbrs);
    assert(id->db == dbrs->db);

    if (dbrs->size >= dbrs->memsize) {
        dbrs->memsize += 100;
        dbrs->rows = REALLOC(dbrs->rows,dbrs->memsize * sizeof(DbRowId));
    }
    DbRowId *insert = dbrs->rows + dbrs->size;
    *insert = *id;
    (dbrs->size)++;

    switch(id->category) {
        case 'T': dbrs->episode_total++; break;
        case 'M': dbrs->movie_total++; break;
        default: dbrs->other_media_total++; break;
    }
}

char *db_get_field(DbSortedRows *sorted_rows,int idx,char *fieldid)
{
    char *result = NULL;
    if (idx <= sorted_rows->num_rows ) {
        result =  db_rowid_get_field(sorted_rows->rows[idx],fieldid);
    }
    return result; 
}


char *localDbPath() {
    static char *a=NULL;
    if (a == NULL) {
        ovs_asprintf(&a,"%s/index.db",appDir());
    }
    return a;
}

// Return 1 if db should be scanned according to html get parameters.
int db_to_be_scanned(char *name) {
    char *idlist = query_val(QUERY_PARAM_IDLIST);
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

    HTML_LOG(0,"begin db_scan_and_add_rowset [%s][%s]",path,name);
TRACE;
    if (db_to_be_scanned(name)) {
TRACE;

        Db *db = db_init(path,name);

        if (db) {
TRACE;

            DbRowSet *r = db_scan_titles(db,name_filter,media_type,watched);

            if ( r != NULL ) {
TRACE;
                dump_all_rows2("rowset",r->size,r->rows);

                (*row_set_ptr) = REALLOC(*row_set_ptr,((*rowset_count_ptr)+2)*sizeof(DbRowSet*));
                (*row_set_ptr)[(*rowset_count_ptr)++] = r;
                (*row_set_ptr)[(*rowset_count_ptr)]=NULL;

            }
        }
    }
    HTML_LOG(0,"end db_scan_and_add_rowset[%s][%s]=%d",path,name,*rowset_count_ptr);
}

char *next_space(char *p) {
    char *space=p;

    while(*space) {
        if (*space == ' ') return space;
        if (*space == '\\' ) space++;
        space++;
    }
    return NULL;
}

char *is_nmt_network_share(char *mtab_line) {


    char *space=next_space(mtab_line);

    HTML_LOG(3,"mtab looking at[%s]",space);
    if (space) {
        if (util_starts_with(space+1,NETWORK_SHARE)) {
            HTML_LOG(0,"mtab nmt share[%s]",mtab_line);
           return space+1;
        }
    }
    HTML_LOG(2,"mtab ignore[%s]",mtab_line);
    return NULL;
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

    if (use_folder_titles == UNSET ) {
        use_folder_titles = *oversight_val("ovs_use_folders_as_title") == '1';
    }

TRACE;
    HTML_LOG(1,"begin db_crossview_scan_titles");
    // Add information from the local database
    db_scan_and_add_rowset(
        localDbPath(),"*",
        name_filter,media_type,watched,
        &rowset_count,&rowsets);
TRACE;

    if (crossview) {
        //get iformation from any remote databases
        // Get crossview mounts by looking at pflash settings servnameN=name
        char *settingname,*name;
        struct hashtable_itr *itr;
        for (itr=hashtable_loop_init(g_nmt_settings) ; hashtable_loop_more(itr,&settingname,&name) ; ) {

            if (util_starts_with(settingname,"servname") && name && *name ) {

                char *path=NULL;
                HTML_LOG(0,"crossview looking at %s=[%s]",settingname,name);
                ovs_asprintf(&path,NETWORK_SHARE "%s/Apps/oversight/index.db",name);

                if (nmt_mount(path)) {
                    if (is_file(path)) {

                        HTML_LOG(0,"crossview [%s]",path);
                        db_scan_and_add_rowset(
                            path,name,
                            name_filter,media_type,watched,
                            &rowset_count,&rowsets);

                    } else {
                        HTML_LOG(0,"crossview search [%s] doesnt exist",path);
                    }
                } else {
                    HTML_LOG(0,"crossview search - could not mount [%s] ",path);
                }
                FREE(path);
            }
        }
    }

    HTML_LOG(0,"end db_crossview_scan_titles");
    return rowsets;
}

void db_free_rowsets_and_dbs(DbRowSet **rowsets) {
    if (rowsets) {
        DbRowSet **r;
TRACE;
        for(r = rowsets ; *r ; r++ ) {
TRACE;
            Db *db = (*r)->db;
            db_rowset_free(*r);
TRACE;
            db_free(db);
TRACE;
        }
TRACE;
        FREE(rowsets);
TRACE;
    }
}

//integer compare function for sort.
int id_cmp_fn(const void *i,const void *j) {
    return (*(const int *)i) - (*(const int *)j);
}

// For a given db name - extract and sort the list of ids in the idlist query param
// eg idlist=dbname(id1|id2|id3)name2(id4|id5)...
// if there is no idlist then ALL ids are OK. to indicate this num_ids = -1
int *extract_idlist(char *db_name,int *num_ids) {

    char *query = query_val(QUERY_PARAM_IDLIST);
    int *result = NULL;

    HTML_LOG(0,"extract_idlist from [%s]",query);

    if (*query) {
        *num_ids = 0;
        char *p = delimited_substring(query,")",db_name,"(",1,0);
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
        HTML_LOG(0,"idlist:db: name=%s searching all ids",db_name);
    } else {
        int i;
        HTML_LOG(0,"idlist:db: name=%s searching %d ids",db_name,*num_ids);
        for(i  = 0 ; i < *num_ids ; i++ ) {
            HTML_LOG(0,"idlist:db: name=%s id %d",db_name,result[i]);
        }
    }

    return result;
}

// quick binary chop to search list.
int in_idlist(int id,int size,int *ids) {

    if (size == 0) return 0;
    if (size == ALL_IDS) return 1;

    // The range is usually much smaller than the number of possible ids.
    // So do boundary comparison first.
    if (id < ids[0] ) return 0;
    if (id > ids[size-1] ) return 0;

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

            HTML_LOG(1,"found %d",ids[mid]);
            return 1;
        }
    } while (min < max);

    //HTML_LOG("not found %d",id);
    return 0;
}

#define FIRST_TITLE_LETTER(title) \
        (!title?\
            '\0'\
        :\
            (*(title) == 'T' && (title)[1]=='h' && (title)[2] == 'e' && (title)[3]==' ' ?\
                (title)[4]\
             :\
             *title)\
        )

#define ANY_SEASON -10
DbRowSet * db_scan_titles(
        Db *db,
        char *name_filter,  // only load lines whose titles match the filter
        int media_type,     // 1=TV 2=MOVIE 3=BOTH 
        int watched        // 1=watched 2=unwatched 3=any
        ){

    regex_t pattern;

    DbRowSet *rowset = NULL;

    char *view=query_view_val();
    int tv_or_movie_view = (STRCMP(view,VIEW_TV)==0 || STRCMP(view,VIEW_MOVIE) == 0);

    int num_ids;
    int *ids = extract_idlist(db->source,&num_ids);

    char *title_filter = query_val(QUERY_PARAM_TITLE_FILTER);

    int season = ANY_SEASON;
    if (*query_val(QUERY_PARAM_SEASON) ) {
        season = atol(query_val(QUERY_PARAM_SEASON));
    }

    HTML_LOG(3,"Creating db scan pattern..");

    // Special case if the name_filter starts with P then it is a regex. If it starts with S then a string
    if (name_filter && *name_filter && *name_filter == NAME_FILTER_REGEX_FLAG[0] ) {
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
        HTML_LOG(0,"filtering by regex [%s]",name_filter);
    }

    // For back compatability (and custom genre support) we serach for both compressed genres or normal.
    char *genre_filter = query_val(DB_FLDID_GENRE);
    char *compressed_genre_filter = NULL;
    if (!EMPTY_STR(genre_filter) ) {
        compressed_genre_filter = compress_genre(genre_filter);

        // If its a custom genre, then compressed will be the same.
        if (STRCMP(compressed_genre_filter,genre_filter) == 0) {
            compressed_genre_filter = NULL;
        }
        HTML_LOG(0,"genre filter [%s][%s]",genre_filter,compressed_genre_filter);
    }


    db->db_size=0;


    char  *path = db->path;

    // If it is a remote oversight then read from local copy
    if (util_starts_with(db->path,NETWORK_SHARE)) {
        path = get_crossview_local_copy(db->path,db->source);
    }
    HTML_LOG(0,"db scanning %s",path);

    ReadBuf *fp = dbreader_open(path);

    if (fp) {

        rowset=db_rowset(db);

        int eof=0;
        DbRowId rowid;
        db_rowid_init(&rowid,db);

        unsigned char title_filter_start='\0';
        unsigned char title_filter_end=255;
        if (title_filter && *title_filter && *title_filter != '*') {
            title_filter_start=*(unsigned char *)title_filter;
            title_filter_end=*(unsigned char *)(title_filter+strlen(title_filter)-1);
            HTML_LOG(0,"Title Filter [%c-%c]",title_filter_start,title_filter_end);
        }


        while (eof == 0) {
            db->db_size++;
            dbread_and_parse_row(&rowid,db,fp,&eof,tv_or_movie_view);

            if (rowid.file) {

                //HTML_LOG(0,"xx read1 [%d][%s][%s]",rowid.id,rowid.title,rowid.genre);

                int keeprow=1;

                // If there were any  deletes queued for shared resources, revoke them
                // as they are in use by this item.
                if (g_delete_queue != NULL) {

TRACE;
                    delete_queue_unqueue(&rowid,rowid.nfo);
TRACE;
                    remove_internal_images_from_delete_queue(&rowid);
TRACE;
                }

                // Check the device is mounted - if not skip it.
                if (!nmt_mount_quick(rowid.file)){

                    HTML_LOG(1,"Path not mounted [%s]",rowid.file);
                    keeprow=0;

                } else {

                    switch(rowid.category) {
                        case 'T': g_episode_total++; break;
                        case 'M': g_movie_total++; break;
                        default: g_other_media_total++; break;
                    }


                    if (rowid.genre) {
                        get_genre_from_string(rowid.genre,&g_genre_hash);
                    }

                    if (season != ANY_SEASON && rowid.season != season ) {
                        keeprow = 0;
                    }

                    if (title_filter_start && keeprow) {

                        unsigned char first_letter = FIRST_TITLE_LETTER(rowid.title);

                        if (first_letter) {
                            if (title_filter_start < 'A' ) {
                                // Non alpahbetic
                                if (first_letter >= 'A' && first_letter <= 'Z') {
                                    keeprow = 0;
                                }
                            } else if (first_letter < title_filter_start || first_letter > title_filter_end) {
                                keeprow = 0;
                            }
                        }
                    }

                    if (genre_filter && *genre_filter && keeprow) {
                        //HTML_LOG(0,"genre [%.*s]",10,rowid.genre);
                        if (EMPTY_STR(rowid.genre))  {
                            keeprow=0;
                        } else if (delimited_substring(rowid.genre," |",genre_filter," |",1,1)) {
                            keeprow= 1;
                        } else if (compressed_genre_filter != NULL &&
                                 delimited_substring(rowid.genre," |",compressed_genre_filter," |",1,1)) {
                            keeprow=1;
                        } else {
                            keeprow = 0;
                        }
                    }

                    //if (keeprow) HTML_LOG(0,"xx genre ok");

                    if (name_filter && *name_filter && keeprow) {
                        int match=-1;
                        if (*name_filter == NAME_FILTER_REGEX_FLAG[0]) {
                            match= regexec(&pattern,rowid.title,0,NULL,0);
                        } else if ( *name_filter == NAME_FILTER_STRING_FLAG[0] ) {
                            match = STRCASECMP(rowid.title,name_filter+1);
                        }
                        if (match != 0 ) {
                            HTML_LOG(5,"skipped %s!=%s",rowid.title,name_filter);
                            keeprow=0;
                        } else {
                            HTML_LOG(1,"matched [%s]",rowid.title);
                        }
                    }
                    if (keeprow) {
                        int is_tv = (rowid.category == *QUERY_PARAM_MEDIA_TYPE_VALUE_TV);
                        int is_movie = (rowid.category == *QUERY_PARAM_MEDIA_TYPE_VALUE_MOVIE);

                        switch(media_type) {
                            case DB_MEDIA_TYPE_TV:
                                if (!is_tv) {
                                    keeprow=0;
                                }
                                break;
                            case DB_MEDIA_TYPE_FILM:
                                if (!is_movie) {
                                    keeprow=0;
                                }
                                break;
                            case DB_MEDIA_TYPE_OTHER:
                                if (is_tv || is_movie) {
                                    keeprow=0;
                                }
                                break;
                        }
                    }
                    //if (keeprow) HTML_LOG(0,"xx type ok");

                    if (keeprow) {
                        switch(watched) {
                            case DB_WATCHED_FILTER_NO : if (rowid.watched != 0 ) keeprow=0 ; break;
                            case DB_WATCHED_FILTER_YES : if (rowid.watched != 1 ) keeprow=0 ; break;
                        }
                    }
                    //if (keeprow) HTML_LOG(0,"xx watched ok");
                    if (keeprow) {
                        if (num_ids != ALL_IDS && !in_idlist(rowid.id,num_ids,ids)) {
                            keeprow = 0;
                        }
                    }
                    //if (keeprow) HTML_LOG(0,"xx id ok");
                }

                if (keeprow) {
                    db_rowset_add(rowset,&rowid);
                    //HTML_LOG(0,"xx keep [%d][%s][%s]",rowid.id,rowid.title,rowid.genre);
                } else {
                    db_rowid_free(&rowid,0);
                }
            }
        }

        /*
        HTML_LOG(0,"read_and_parse_row_ticks %d",read_and_parse_row_ticks/1000);
        HTML_LOG(0,"inner_date_ticks %d",inner_date_ticks/1000);
        HTML_LOG(0,"date_ticks %d",date_ticks/1000);
        HTML_LOG(0,"assign_ticks %d",assign_ticks/1000);
        HTML_LOG(0,"filter_ticks %d",filter_ticks/1000);
        HTML_LOG(0,"keep_ticks %d",keep_ticks/1000);
        HTML_LOG(0,"discard_ticks %d",discard_ticks/1000);
        */

        dbreader_close(fp);
    }
    if (path != db->path) FREE(path);
    HTML_LOG(0,"db[%s] filtered %d of %d rows",db->source,(rowset?rowset->size:0),db->db_size);
    FREE(ids);
    if (!EMPTY_STR(compressed_genre_filter)) FREE(compressed_genre_filter);
    HTML_LOG(1,"return rowset");
    return rowset;
}

void db_free(Db *db) {


    if (db->locked_by_this_code) {
        db_unlock(db);
    }
    if (db->plot_fp) {
        fclose(db->plot_fp);
        db->plot_fp = NULL;
    }

    FREE(db->source);
    FREE(db->path);
    FREE(db->plot_file);
    FREE(db->lockfile);
    FREE(db->backup);
    FREE(db);

}

/*
 * Expand list of genre keys. eg. 
 * r = Romance
 * a | c = Action | Comedy
 */
char *translate_genre(char *genre_keys,int expand)
{
    static Array *genres = NULL;
    if (genres == NULL) {
        char *list = catalog_val("catalog_genre");
        //HTML_LOG(0,"catalog_genre = [%s] ",list);
        //html_hashtable_dump(0,"catalog",g_catalog_config);
        if (!EMPTY_STR(list)) {
            genres=splitstr(list,",");
        }
        //array_dump(0,"genres",genres);
    }

    char *out = genre_keys;
    if (out == NULL) {
        out = STRDUP("");
    } else if (genres) {
        int i;
        for(i = 0 ; i < genres->size ; i += 2 ) {

            char *key = genres->array[i+1];
            char *val = genres->array[i];

            char *from,*to;

            if (expand) {
                from = key;
                to = val;
            } else {
                from = val;
                to = key;
            }

            // If key is a letter on its own replace with val.
            // could use regex replace \<key\> , val but this is slow platform
            char *p;
            if ((p=delimited_substring(out," |",from," |",1,1)) != NULL) {

                char *new;
                ovs_asprintf(&new,"%.*s%s%s",p-out,out,to,p+strlen(from));
                if (out != genre_keys) FREE(out);
                out = new;
            }

        }
    }
    if (out == genre_keys) out = STRDUP(out);

    //HTML_LOG(0,"genre[%s] is [%s]",genre_keys,out);
    return out;
}
// * a | c = Action | Comedy
char *expand_genre(char *genre_keys)
{
    char *tmp = translate_genre(genre_keys,1);
    char *tmp2 = replace_all(tmp," *\\| *"," | ",0);
    FREE(tmp);
    return tmp2;
}
// * Action | Comedy = a|c
char *compress_genre(char *genre_names)
{
    return translate_genre(genre_names,0);
}


void db_rowid_free(DbRowId *rid,int free_base) {

    int i;
    assert(rid);

//    HTML_LOG(0,"%s %lu %lu",rid->title,rid,rid->file);
//    HTML_LOG(0,"%s",rid->file);
    FREE(rid->title);
    FREE(rid->poster);
    FREE(rid->genre);
    FREE(rid->file);
    FREE(rid->episode);
    //Dont free ext as it points to file.


    // Following are only set in tv/movie view
    FREE(rid->url);
    FREE(rid->parts);
    FREE(rid->fanart);
    for(i = 0 ; i < PLOT_TYPE_COUNT ; i++ ) {
        FREE(rid->plotkey[i]);
        FREE(rid->plottext[i]);
    }
    FREE(rid->eptitle);
    FREE(rid->eptitle_imdb);
    FREE(rid->additional_nfo);

    ARRAY_FREE(rid->playlist_paths);
    ARRAY_FREE(rid->playlist_names);

    //Only populated if deleting
    FREE(rid->nfo);

    FREE(rid->certificate);
    if (free_base) {
        FREE(rid);
    }
}

void db_rowset_free(DbRowSet *dbrs) {
    int i;

    for(i = 0 ; i<dbrs->size ; i++ ) {
        DbRowId *rid = dbrs->rows + i;
        db_rowid_free(rid,0);
    }

    FREE(dbrs->rows);
    FREE(dbrs);
}


void db_rowset_dump(int level,char *label,DbRowSet *dbrs) {
    int i;
    if (dbrs->size == 0) {
        HTML_LOG(level,"Rowset: %s : EMPTY",label);
    } else {
        for(i = 0 ; i<dbrs->size ; i++ ) {
            DbRowId *rid = dbrs->rows + i;
            HTML_LOG(level,"Rowset: %s [%s - %c - %d %s ]",label,rid->title,rid->category,rid->season,rid->poster);
        }
    }
}

void db_set_fields_by_source(
        char *field_id, // field to be set ie         -- SET FIELD_ID
        char *new_value, // value to set the field to -- = new_value
        char *source,    // which db to update        -- UPDATE source
        char *idlist,    // List of ids ie.           --  WHERE ID in idlist
        int delete_mode // DELETE_MODE_DELETE DELETE_MODE_REMOVE DELETE_MODE_NONE (update)
        ) {

    HTML_LOG(0," begin db_set_fields_by_source [%s][%s] [%s] -> [%s] delete mode = %d",
        source,idlist,field_id,new_value,delete_mode);

    int affected_total=0;
    int dbsize=0;

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
    PRE_CHECK_FGETS(buf,DB_ROW_BUF_SIZE);

    regmatch_t pmatch[5];

    ovs_asprintf(&regex_text,"\t%s\t([^\t]+)\t",field_id);
    util_regcomp(&regex_ptn,regex_text,0);
    HTML_LOG(1,"regex filter [%s]",regex_text);

    ovs_asprintf(&id_regex_text,"\t%s\t(%s)\t",DB_FLDID_ID,idlist);
    util_regcomp(&id_regex_ptn,id_regex_text,0);
    HTML_LOG(1,"regex extract [%s]",id_regex_text);



    if (db && db_lock(db)) {
HTML_LOG(1," begin open db");
        int free_inpath;
        char *inpath = get_mounted_path(db->source,db->path,&free_inpath);

        FILE *db_in = fopen(inpath,"r");

        if (db_in) {
            char *tmpdb;
            ovs_asprintf(&tmpdb,"%s.tmp.%d",inpath,getpid());
            int rename=0;

            FILE *db_out = fopen(tmpdb,"w");

            if (db_out) {
                while(1) {
                    

                    if (fgets(buf,DB_ROW_BUF_SIZE,db_in) == NULL) {
                        break;
                    }

                    CHECK_FGETS(buf,DB_ROW_BUF_SIZE);

                    dbsize++;

                    if (regexec(&id_regex_ptn,buf,0,NULL,0) != 0 ) {

                        // No match - emit
                        fprintf(db_out,"%s",buf);

                    } else if (
                            delete_mode == DELETE_MODE_AUTO_REMOVE ||
                            delete_mode == DELETE_MODE_REMOVE ||
                            delete_mode == DELETE_MODE_DELETE) {

                        // if delisting then keep the resources. Only remove them if there is a 
                        // user initiated deletion or delist. Autodelist do not delete images.
                        // Otherwise we have to do a third pass of the db to identify autodelited 
                        // resources that are still in use.
                        // pass 1 = user delete/delist action
                        // pass 2 = render / auto delist.
                        DbRowId rid;
                        parse_row(ALL_IDS,NULL,0,buf,db,&rid);
                        if (delete_mode == DELETE_MODE_DELETE || delete_mode == DELETE_MODE_REMOVE) {
                            add_internal_images_to_delete_queue(&rid);
                            if (delete_mode == DELETE_MODE_DELETE ) {
                                delete_media(&rid,1);
                            }
                        }
                        db_rowid_free(&rid,0);
                        affected_total++;

                    } else if ( regexec(&regex_ptn,buf,2,pmatch,0) == 0) {
                        // Field is present - change it
                        int spos=pmatch[1].rm_so;
                        int epos=pmatch[1].rm_eo;

                        HTML_LOG(0," got regexec %s %s from %d to %d ",id_regex_text,regex_text,spos,epos);

                        HTML_LOG(0,"%.*s[[%s]]%s",spos,buf,new_value,buf+epos);
                        fprintf(db_out,"%.*s%s%s",spos,buf,new_value,buf+epos);
                        affected_total++;

                    } else {
                        // field not present - we could append the field at this stage.
                        // but there is not calling function that adds fields on the fly!
                        // so just emit
                        fprintf(db_out,"%s",buf);

                    }

                }
                fclose(db_out);
                rename=1;
            }

            fclose(db_in);
            if (rename) {
                int free_backup;
                char *backup=get_mounted_path(db->source,db->backup,&free_backup);

                util_rename(inpath,backup);
                util_rename(tmpdb,inpath);

                if (free_backup) FREE(backup);

            }
            FREE(tmpdb);
        }
        if (free_inpath) FREE(inpath);
        db_unlock(db);
        db_free(db);
    }
    HTML_LOG(0," end db_set_fields_by_source - %d of %d records changed",affected_total,dbsize);
    regfree(&regex_ptn);
    regfree(&id_regex_ptn);
    FREE(regex_text);
    FREE(id_regex_text);

}

void db_remove_row_helper(DbRowId *rid,int mode) {
    char idlist[20];
    sprintf(idlist,"%ld",rid->id);
    db_set_fields_by_source(DB_FLDID_ID,NULL,rid->db->source,idlist,mode);
}
// remove item from list, keep media, and keep images. initiated by Auto delist.
void db_auto_remove_row(DbRowId *rid) {
    db_remove_row_helper(rid,DELETE_MODE_AUTO_REMOVE);
}
// remove item from list, keep media, delete images. user initiated delist
void db_remove_row(DbRowId *rid) {
    db_remove_row_helper(rid,DELETE_MODE_REMOVE);
}
// remove item from list, delete everything. user initiated delete.
void db_delete_row_and_media(DbRowId *rid) {
    db_remove_row_helper(rid,DELETE_MODE_DELETE);
}

void db_set_fields(char *field_id,char *new_value,struct hashtable *ids_by_source,int delete_mode) {
    struct hashtable_itr *itr;
    char *source;
    char *idlist;

    HTML_LOG(0," begin db_set_fields [%s] -> [%s]",field_id,new_value);
    for(itr=hashtable_loop_init(ids_by_source) ; hashtable_loop_more(itr,&source,&idlist) ; ) {
        db_set_fields_by_source(field_id,new_value,source,idlist,delete_mode);
    }
    HTML_LOG(1," end db_set_fields");
}

#define GENRE_SEP(c) ((c) == '|' || (c) == ' ' || (c) == ',')

void get_genre_from_string(char *gstr,struct hashtable **h) {

    char *p;

    if (*h == NULL) {
        *h = string_string_hashtable("genre_hash",16);
    }

    for(;;) {

        while (GENRE_SEP(*gstr)) { gstr++; } // eat sep

        if (!*gstr) {
            break;
        }

        p = gstr;
        while ( *p && !GENRE_SEP(*p)) { p++; } // find end sep

        //while ( p > gstr && p[-1] == ' ' ) p--; // rtrim

        if (*gstr && p > gstr) {
            char save_c = *p;
            *p = '\0';

            // Exclude 'and' and 'Show' from genres
            if (STRCMP(gstr,"and") != 0 && STRCMP(gstr,"Show") != 0 ) {

                //HTML_LOG(1,"Genre[%s]",gstr);
                if (gstr && *gstr) {
                    char *g = hashtable_search(*h,gstr);
                    if (g==NULL) {
                        HTML_LOG(1,"added Genre[%s]",gstr);
                        char *g=STRDUP(gstr);
                        hashtable_insert(*h,g,g);
                    }
                }
            }

            *p = save_c;

            gstr = p;
        }
    }
}

void dump_row(char *prefix,DbRowId *rid)
{
    HTML_LOG(0,"xx %s  %d:T[%s]S[%d]E[%s]w[%d]",prefix,rid->id,rid->title,rid->season,rid->episode,rid->watched);
}
void dump_all_rows(char *prefix,int num_rows,DbRowId **sorted_rows)
{
#if 0
    int i;
    for(i = 0 ; i <  num_rows ; i ++ ) {
        DbRowId *rid = sorted_rows[i];
        dump_row(prefix,rid);
        for( ; rid ; rid = rid->linked ) {
            dump_row("linked:",rid);
        }
    }
#endif
}
void dump_all_rows2(char *prefix,int num_rows,DbRowId sorted_rows[])
{
#if 0
    int i;
    for(i = 0 ; i <  num_rows ; i ++ ) {
        DbRowId *rid = sorted_rows+i;
        dump_row(prefix,rid);
        for( ; rid ; rid = rid->linked ) {
            dump_row("linked:",rid);
        }
    }
#endif
}

/*
 * Todo this should use fread/fwrite 
 */
#define COPY_BUF_SIZE 2000
int copy_file(char *from, char *to)
{
    HTML_LOG(0,"copying [%s] to [%s]",from,to);
    char buf[COPY_BUF_SIZE+1];
    int result = -1;
    FILE *fromfp,*tofp;

    if ((fromfp = fopen(from,"r") ) != NULL) {
        if ((tofp = fopen(to,"w") ) != NULL) {
            while (fgets(buf,COPY_BUF_SIZE,fromfp) ) {

                fputs(buf,tofp);
            }
            result = errno;
            fclose(tofp);
        }
        fclose(fromfp);
    }
    return result;
}

char *get_crossview_local_copy(char *path,char *label)
{

    char *local_path = path;

    if (util_starts_with(path,NETWORK_SHARE) ) {

        struct stat remote_s;
        if (stat(path,&remote_s) == 0) {
            char *tmp;
            ovs_asprintf(&tmp,"%s/tmp/%s.%s",appDir(),util_basename(path),label);
            struct stat local_s;
            if (stat(tmp,&local_s) != 0 || remote_s.st_mtime > local_s.st_mtime ) {
                // copy remote file
                if (copy_file(path,tmp) == 0) {
                    local_path = tmp;

                    //Set modification and access time of new file to be the same as the old one
                    //compensates for clock sync issues.
                    struct utimbuf ut;
                    ut.actime = ut.modtime = remote_s.st_mtime;

                    if (utime(local_path,&ut) ) {
                        HTML_LOG(0,"Error setting modification time of [%s]",local_path);
                    }
                }
            } else if (remote_s.st_mtime < local_s.st_mtime) {
                // Use local file
                local_path = tmp;
            }
        }
    }
    
    return local_path;
}

// vi:sw=4:et:ts=4
