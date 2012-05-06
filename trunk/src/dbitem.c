#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>

#include "dbfield.h"
#include "utf8.h"
#include "dbitem.h"
#include "dboverview.h"
#include "dbplot.h"
#include "config.h"
#include "util.h"
#include "gaya_cgi.h"
#include "actions.h"
#include "initials.h"

#define HEX_YEAR_OFFSET 1900
#define EOL(c)  ((c) == '\n'  ||  (c) == '\r' || (c) == '\0' )
#define SEP(c)  ((c) == '\t' ) 
#define TERM(c)  ( ( (c) == '\n' ) || ( (c) == '\r' ) || ( (c) == '\0' ) || (c) == EOF )

static inline void db_rowid_set_field(DbItem *rowid,char *name,char *val,int val_len,int tv_or_movie_view);

void db_rowid_free(DbItem *item,int free_base)
{

    int i;
    if(item) {

        FREE(item->sets);
        ARRAY_FREE(item->set_array);

    //    HTML_LOG(0,"%s %lu %lu",item->title,item,item->file);
    //    HTML_LOG(0,"%s",item->file);
        FREE(item->title);
        FREE(item->poster);
        FREE(item->genre);
        FREE(item->expanded_genre);
        FREE(item->file);
        FREE(item->episode);
        //Dont free ext as it points to file.


        // Following are only set in tv/movie view
        FREE(item->url);
        FREE(item->parts);
        FREE(item->fanart);
        for(i = 0 ; i < PLOT_TYPE_COUNT ; i++ ) {
            FREE(item->plotkey[i]);
            FREE(item->plottext[i]);
        }
        FREE(item->eptitle);
        FREE(item->eptitle_imdb);
        FREE(item->additional_nfo);

        ARRAY_FREE(item->playlist_paths);
        ARRAY_FREE(item->playlist_names);

        //Only populated if deleting
        FREE(item->nfo);

        FREE(item->certificate);

        FREE(item->idlist);

        FREE(item->video);
        FREE(item->audio);
        FREE(item->videosource);
        FREE(item->subtitles);

        FREE(item->yamj_member_of);

        if (free_base) {
            FREE(item);
        }
    }
}
void set_title_as_folder(DbItem *rowid)
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
// There are two functions to read the db - this one and parse_row()
// They should be consolidated.
// This one does a full table scan.
//
// Some ways to speed this up:
// increase buffer for file descriptor setvbuf()
// use fread()
// use read()
//
DbItem *dbread_and_parse_row(
        DbItem *rowid,
        Db *db,
        ReadBuf *fp,
        int *eof,
        int tv_or_movie_view // true if looking at tv or moview view.
        )
{
#define UNSET -2
    static int use_folder_titles = UNSET;
    if (use_folder_titles == UNSET ) {
        use_folder_titles = *oversight_val("ovs_use_folders_as_title") == '1';
    }


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
        //HTML_LOG(0,"dbline ending %d[%.20s] ",*next,next);

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

    if (rowid) {
#if 0
            HTML_LOG(0,"TITLE [%s] ",rowid->title);
            HTML_LOG(0,"FILE [%s] ",rowid->file);
        if (rowid->directors) {
            HTML_LOG(0,"[%s/%d] directors [%s]",rowid->title,rowid->external_id,
                    db_group_imdb_string_static(rowid->directors,"nm"));
        }
        if (rowid->actors) {
            HTML_LOG(0,"[%s/%d] actors [%s]",rowid->title,rowid->external_id,
                    db_group_imdb_string_static(rowid->actors,"nm"));
        }
#endif
    }
    return rowid;
}

DbItem *db_rowid_init(DbItem *rowid,Db *db) {
    int i;
    memset(rowid,0,sizeof(DbItem));
    rowid->rating=0;

    rowid->db = db;
    rowid->season = -1;
    rowid->category='?';
    for(i = 0 ; i < PLOT_TYPE_COUNT ; i++ ) {
        rowid->plotoffset[i] = PLOT_POSITION_UNSET;
    }
    return rowid;
}
DbItem *db_rowid_new(Db *db) {

    DbItem *rowid = MALLOC(sizeof(*rowid));
    db_rowid_init(rowid,db);
    return rowid;
}

void db_rowid_dump(DbItem *item)
{
    
    time_t t;
    HTML_LOG(1,"ROWID: id = %d",item->id);
    HTML_LOG(1,"ROWID: watched = %d",item->watched);
    HTML_LOG(1,"ROWID: title(%s)",item->title);
    HTML_LOG(1,"ROWID: file(%s)",item->file);
    HTML_LOG(1,"ROWID: ext(%s)",item->ext);
    HTML_LOG(1,"ROWID: season(%d)",item->season);
    HTML_LOG(1,"ROWID: episode(%s)",item->episode);
    HTML_LOG(1,"ROWID: genre(%s)",item->genre);
    HTML_LOG(1,"ROWID: ext(%c)",item->category);
    HTML_LOG(1,"ROWID: parts(%s)",item->parts);
    HTML_LOG(1,"ROWID: videosource(%s)",item->videosource);
    HTML_LOG(1,"ROWID: video(%s)",item->video);
    HTML_LOG(1,"ROWID: audio(%s)",item->audio);
    HTML_LOG(1,"ROWID: size(%d)mb",item->sizemb);
    HTML_LOG(1,"ROWID: subtitles(%s)",item->subtitles);
    t = item->date;
    HTML_LOG(1,"ROWID: date(%s)",asctime(localtime(&t)));
    HTML_LOG(1,"ROWID: eptitle(%s)",item->eptitle);
    HTML_LOG(1,"ROWID: eptitle_imdb(%s)",item->eptitle_imdb);
    HTML_LOG(1,"ROWID: additional_nfo(%s)",item->additional_nfo);
    t = item->airdate;
    HTML_LOG(1,"ROWID: airdate(%s)",asctime(localtime(&t)));
    t = item->airdate_imdb;
    HTML_LOG(1,"ROWID: airdate_imdb(%s)",asctime(localtime(&t)));
    HTML_LOG(1,"ROWID: set(%s)",item->sets);
    HTML_LOG(1,"ROWID: directors(%s)",db_group_imdb_string_static(item->directors));
    HTML_LOG(1,"ROWID: actors(%s)",db_group_imdb_string_static(item->actors));
    HTML_LOG(1,"----");
}


// There are two functions to parse a row. This one and dbread_and_parse_row().
// The should be brought together at some point!
// This function only reads the listed ids.
int parse_row(
        int num_ids, // number of ids passed in the idlist parameter of the query string. if ALL_IDS then id list is ignored.
        int *ids,    // sorted array of ids passed in query string idlist to use as a filter.
        int tv_or_movie_view, // true if looking at tv or moview view.
        char *buffer,  // The current buffer contaning a line of input from the database
        Db *db,        // the database
        DbItem *rowid// current rowid structure to populate.
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

    result =   (result && (num_ids == ALL_IDS || idlist_index(rowid->id,num_ids,ids) >= 0) );
    if (!result) {
        db_rowid_free(rowid,0);
    }
    return result;
}
// Returns index of item.
// -1 = not found.
int idlist_index(int id,int size,int *ids)
{
    return bchop(id,size,ids);
}

#define DB_NAME_BUF_SIZE 10
#define DB_VAL_BUF_SIZE 4000
#define ROW_SIZE 10000

// Not used at the moment, the code modifies the index.db using sed like behaviour
// so no need to write a row ...yet.. but this may change once the db editor is implemented.
#if 0
//changes here should be reflected in catalog.sh.full:createIndexRow()
void write_row(FILE *fp,DbItem *item) {
    fprintf(fp,"\t%s\t%ld",DB_FLDID_ID,item->id);
    fprintf(fp,"\t%s\t%c",DB_FLDID_CATEGORY,item->category);
    fprintf(fp,"\t%s\t%s",DB_FLDID_INDEXTIME,fmt_timestamp_static(item->date));
    fprintf(fp,"\t%s\t%d",DB_FLDID_WATCHED,item->watched);
    fprintf(fp,"\t%s\t%d",DB_FLDID_LOCKED,item->locked);
    fprintf(fp,"\t%s\t%s",DB_FLDID_TITLE,item->title);
    fprintf(fp,"\t%s\t%d",DB_FLDID_SEASON,item->season);
    fprintf(fp,"\t%s\t%.1lf",DB_FLDID_RATING,item->rating);
    fprintf(fp,"\t%s\t%s",DB_FLDID_EPISODE,item->episode);
    //fprintf(fp,"\t%s\t%s",DB_FLDID_POSTER,item->poster);
    fprintf(fp,"\t%s\t%s",DB_FLDID_GENRE,item->genre);
    fprintf(fp,"\t%s\t%d",DB_FLDID_RUNTIME,item->runtime);
    fprintf(fp,"\t%s\t%s",DB_FLDID_PARTS,item->parts);
    fprintf(fp,"\t%s\t%x",DB_FLDID_YEAR,item->year-HEX_YEAR_OFFSET);

    // Remove Network share path
    if (util_starts_with(item->file,NETWORK_SHARE)) {
        fprintf(fp,"\t%s\t%s",DB_FLDID_FILE,item->file+strlen(NETWORK_SHARE));
    } else {
        fprintf(fp,"\t%s\t%s",DB_FLDID_FILE,item->file);
    }

    fprintf(fp,"\t%s\t%s",DB_FLDID_ADDITIONAL_INFO,item->additional_nfo);
    fprintf(fp,"\t%s\t%s",DB_FLDID_URL,item->url);
    fprintf(fp,"\t%s\t%s",DB_FLDID_CERT,item->certificate);
    if (item->directors) {
        fprintf(fp,"\t%s\t%s",DB_FLDID_DIRECTOR_LIST,db_group_imdb_compressed_string_static(item->directors));
    if (item->actors) {
        fprintf(fp,"\t%s\t%s",DB_FLDID_ACTOR_LIST,db_group_imdb_compressed_string_static(item->actors));
    }
    fprintf(fp,"\t%s\t%s",DB_FLDID_FILETIME,fmt_timestamp_static(item->filetime));
    fprintf(fp,"\t%s\t%s",DB_FLDID_DOWNLOADTIME,fmt_timestamp_static(item->downloadtime));
    //fprintf(fp,"\t%s\t%s",DB_FLDID_PROD,item->prod);
    fprintf(fp,"\t%s\t%s",DB_FLDID_AIRDATE,fmt_date_static(item->airdate));

    // TODO: Deprecate
    fprintf(fp,"\t%s\t%s",DB_FLDID_EPTITLEIMDB,item->eptitle_imdb);
    // TODO: Deprecate
    fprintf(fp,"\t%s\t%s",DB_FLDID_AIRDATEIMDB,fmt_date_static(item->airdate_imdb));

    fprintf(fp,"\t%s\t%s",DB_FLDID_EPTITLE,item->eptitle);
    fprintf(fp,"\t%s\t%s",DB_FLDID_NFO,item->nfo);
    if (item->remakes) {
        fprintf(fp,"\t%s\t%s",DB_FLDID_REMAKE,db_group_imdb_compressed_string_static(item->remakes));
    }
    //fprintf(fp,"\t%s\t%s",DB_FLDID_FANART,item->fanart);
    //fprintf(fp,"\t%s\t%s",DB_FLDID_PLOT,item->plot_key);
    //fprintf(fp,"\t%s\t%s",DB_FLDID_EPPLOT,item->episode_plot_key);
    fprintf(fp,"\t%s\t%s",DB_FLDID_VIDEO,item->video);
    fprintf(fp,"\t%s\t%s",DB_FLDID_VIDEOSOURCE,item->videosource);
    fprintf(fp,"\t%s\t%s",DB_FLDID_AUDIO,item->audio);
    fprintf(fp,"\t%s\t%d",DB_FLDID_SIZEMB,item->sizemb);
    fprintf(fp,"\t%s\t%s",DB_FLDID_SUBTITLES,item->subtitles);
    fprintf(fp,"\t\n");
    fflush(fp);
}
#endif

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


// Most field ids have the form _a or _ab. This function looks at th first few letters of the 
// id and returns its type (FIELD_TYPE_STR,FIELD_TYPE_INT etc) and its offset within the DbItem structure.
static inline int db_rowid_get_field_offset_type_inline(
        DbItem *rowid,
        char *name,
        void **offset,
        char *type,
        int *overview,
        char **imdb_prefix_ptr)
{

    register char *p = name;
    *offset=NULL;
    *type = FIELD_TYPE_NONE;
    *overview = 0;

    char *imdb_prefix="";



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
                    *offset=&(rowid->sets);
                    *type = FIELD_TYPE_STR;
                    *overview = 1;
                }
                break;
            case 'A':
                if (*p == '\0') { // _A
                    *offset=&(rowid->actors);
                    *type = FIELD_TYPE_IMDB_LIST_NOEVAL;
                    *overview = 1;
                    imdb_prefix = "nm";
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
                    *offset=&(rowid->directors);
                    *type = FIELD_TYPE_IMDB_LIST_NOEVAL;
                    *overview = 1;
                    imdb_prefix = "nm";
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
                }else if (name[2] == 'p') { // _ep
                    *offset=&(rowid->plottext[PLOT_EPISODE]);
                    *type = FIELD_TYPE_STR;
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
            case 'l':
                if (*p == '\0') {
                    *offset=&(rowid->locked);
                    *type = FIELD_TYPE_INT;
                    *overview = 1;
                }
            case 'L':
                break;
                    if (*p == '\0') {
                        *offset=&(rowid->subtitles);
                        *type = FIELD_TYPE_STR;
                    }
                break;
            case 'm':
                if (*p == '\0') {
                    *offset=&(rowid->sizemb);
                    *type = FIELD_TYPE_INT;
                    *overview = 1;
                }
            case 'n':
                    if (*p == 'f') {
                        *offset=&(rowid->nfo);
                        *type = FIELD_TYPE_STR;
                    }
                break;
            case 'o':
                if (*p == 't') {
                    *offset=&(rowid->orig_title);
                    *type = FIELD_TYPE_UTF8_STR;
                    *overview = 1;
                }
                break;
            case 'p':
                    if (*p == 't') {
                        *offset=&(rowid->parts);
                        *type = FIELD_TYPE_STR;
                    }
                break;
            case 'P':
                    if (name[2] == '\0') {
                    *offset=&(rowid->plottext[PLOT_MAIN]);
                    *type = FIELD_TYPE_STR;
                    }
                break;
            case 'r':
                if (*p == '\0') {
                    *offset=&(rowid->rating);
                    *type = FIELD_TYPE_DOUBLE;
                    *overview = 1;
                } else if (*p == 't') {
                    *offset=&(rowid->runtime);
                    *type = FIELD_TYPE_INT;
                    *overview = 1;
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
            case 'S':
                    if (*p == '\0') {
                        *offset=&(rowid->audio);
                        *type = FIELD_TYPE_STR;
                        *overview = 1;
                    }
                break;
            case 't':
                if (*p == '\0') {
                    *offset=&(rowid->top250);
                    *type = FIELD_TYPE_INT;
                    *overview = 1;
                }
                break;
            case 'T':
                if (*p == '\0') {
                    *offset=&(rowid->title);
                    *type = FIELD_TYPE_UTF8_STR;
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
            case 'v':
                    if (*p == '\0') {
                        *offset=&(rowid->video);
                        *type = FIELD_TYPE_STR;
                        *overview = 1;
                    }
                break;
            case 'V':
                    if (*p == '\0') {
                        *offset=&(rowid->videosource);
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
            case 'W':
                if (*p == '\0') { // _d
                    *offset=&(rowid->writers);
                    *type = FIELD_TYPE_IMDB_LIST_NOEVAL;
                    *overview = 1;
                    imdb_prefix = "nm";
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
    if (imdb_prefix_ptr) {
        *imdb_prefix_ptr = imdb_prefix;
    }
    if (*type == FIELD_TYPE_NONE) {
        HTML_LOG(-1,"Unknown field [%s]",name);
        return 0;
    }
    return 1;

}

int db_rowid_get_field_offset_type(DbItem *rowid,char *name,void **offset,char *type,int *overview,char **imdb_prefix_ptr)
{
    return db_rowid_get_field_offset_type_inline(rowid,name,offset,type,overview,imdb_prefix_ptr);
}

// Return string representation of a field the way a user would like to see it.
// TODO: Need to add expand for genre codes.
char * db_rowid_get_field(DbItem *rowid,char *name)
{

    char *result=NULL;
    void *offset;
    char type;
    int overview;

    if (strcmp(name,DB_FLDID_PLOT) == 0) {
        get_plot(rowid,PLOT_MAIN);
    } else if (strcmp(name,DB_FLDID_EPPLOT) == 0) {
        get_plot(rowid,PLOT_EPISODE);
    }
    if (!db_rowid_get_field_offset_type_inline(rowid,name,&offset,&type,&overview,NULL)) {
        return NULL;
    }

    //HTML_LOG(0,"db_rowid_get_field of [%s] %d=%d?",rowid->title,I//);

    switch(type) {
        case FIELD_TYPE_UTF8_STR:
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

static inline void db_rowid_set_field(DbItem *rowid,char *name,char *val,int val_len,int tv_or_movie_view) {

    void *offset;
    char type;
    int overview;
    char *prefix;

    if (!db_rowid_get_field_offset_type_inline(rowid,name,&offset,&type,&overview,&prefix)) {
        return;
    }
    //Dont get the field if this is the menu view and it is not an overview field 
    if (tv_or_movie_view || overview) {

        // Used to check for trailing chars.
        char *tmps=NULL;


        switch(type) {
            case FIELD_TYPE_UTF8_STR:

                *(char **)offset = utf8norm(val,val_len);
                break;

            case FIELD_TYPE_STR:

                *(char **)offset = COPY_STRING(val_len,val);
                if (offset == &(rowid->file)) {

                    fix_file_path(rowid);
                }
                else if (offset == &(rowid->url)) {
                    char *imdb_id = get_item_id(rowid,"imdb",0);
                    if (imdb_id) {
                        rowid->external_id = atol(imdb_id+2);
                        FREE(imdb_id);
                    }
                }
                break;
            case FIELD_TYPE_CHAR:
                *(char *)offset = *val;
                break;
            case FIELD_TYPE_YEAR:
                if (strlen(val) > 3) {
                    *(int *)offset=strtol(val,&tmps,10) ;
                } else {
                    int y = strtol(val,&tmps,16);
                    if (y) y += HEX_YEAR_OFFSET;
                    *(int *)offset = y;
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
                *(DbGroupIMDB **)offset = parse_imdb_list(prefix,val,val_len,NULL);
                break;
            case FIELD_TYPE_IMDB_LIST_NOEVAL:
                *(DbGroupIMDB **)offset = get_raw_imdb_list(val,val_len,prefix);
                break;
            default:
                HTML_LOG(0,"Bad field type [%c]",type);
                //assert(0);
        }
    }
}



OVS_TIME *timestamp_ptr(DbItem *rowid)
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

void fix_file_path(DbItem *rowid)
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

void fix_file_paths(int num_row,DbItem **rows)
{
    int i;
    for(i = 0 ; i < num_row ; i++ ) {
        DbItem *item;
        for(item = rows[i] ; item ; item = item->linked ) {
            // Append Network share path
            fix_file_path(item);
        }
    }
}

int is_on_internal_hdd(DbItem *item)
{
    return (is_on_local_oversight(item) && util_starts_with(item->file,"/share/"));
}
// true if internal hdd or USB
int is_on_local_storage(DbItem *item)
{
    return (is_on_local_oversight(item) && !util_starts_with(item->file,NETWORK_SHARE));
}
int is_on_local_oversight(DbItem *item)
{
    return (*(item->db->source) == '*' );
}
int is_on_remote_oversight(DbItem *item)
{
    return (*(item->db->source) != '*' );
}

char *get_item_id(DbItem *item,char *domain,int add_domain)
{
    return get_id_from_idlist(item->url,domain,add_domain);
}

//
// Extract id from idlist where idlist format = domain:id eg.
// imdb:tt12345 thetvdb:12234
// result must be freed.
//
char *get_id_from_idlist(char *idlist,char *domain,int add_domain)
{

    char *idend;
    char *result = NULL;

    if (idlist) {
        char *id = delimited_substring(idlist," ",domain,":",1,0);
        if (id) {
            if (!add_domain) {
                id += strlen(domain)+1; // skip over domain:
            }
            idend = strchr(id,' ');

            if (idend == NULL) idend = id + strlen(id);

            ovs_asprintf(&result,"%.*s",idend-id,id);
        }
    }
    HTML_LOG(1,"get_id_from_idlist(%s,%s)=[%s]",idlist,domain,result);
    return result;
}

int dbrow_total_size(DbItem *rowid)
{
    int sz=0;
    DbItem *ri;
    for( ri = rowid ; ri ; ri=ri->linked ) {
        sz += ri->sizemb;
    }
    return sz;
}

