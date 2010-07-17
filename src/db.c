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
#include "dbitem.h"
#include "dbnames.h"
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

Db *g_local_db = NULL;

char *copy_string(int len,char *s);
void get_genre_from_string(char *gstr,struct hashtable **h);

int local_db_size()
{
    if (g_local_db) {
        return g_local_db->db_size;
    } else {
        return -1;
    }
}

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
 * Load the database attributes.
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
    db->directors_file = replace_all(db->path,"index.db","db/directors.db",0);
    db->actors_file = replace_all(db->path,"index.db","db/actors.db",0);
    db->writers_file = replace_all(db->path,"index.db","db/writers.db",0);

TRACE;
    db->source= STRDUP(source);

TRACE;
    ovs_asprintf(&(db->backup),"%s.%s",db->path,util_day_static());

TRACE;
    db->lockfile = replace_all(db->path,"index.db","catalog.lck",0);

TRACE;
    db->locked_by_this_code=0;

    // Test code
#ifdef UNIT_TEST
    char *actor=query_val("actors");
    char *director=query_val("directors");
    char *writer=query_val("writers");
    if (!EMPTY_STR(actor)) {
        HTML_LOG(0,"actor [%s] = [%s]",actor,dbnames_fetch_static(actor,db->actors_file));
    }
    if (!EMPTY_STR(director)) {
        HTML_LOG(0,"director [%s] = [%s]",director,dbnames_fetch_static(director,db->directors_file));
    }
    if (!EMPTY_STR(writer)) {
        HTML_LOG(0,"director [%s] = [%s]",writer,dbnames_fetch_static(writer,db->writers_file));
    }
#endif

    if (STRCMP(db->source,"*") == 0) {
        g_local_db = db;
    }


    return db;
}







DbItemSet *db_rowset(Db *db) {
    assert(db);

    DbItemSet *dbrs = MALLOC(sizeof(DbItemSet));
    memset(dbrs,0,sizeof(DbItemSet));
    dbrs->db = db;
    return dbrs;
}


void db_rowset_add(DbItemSet *dbrs,DbItem *id) {

    assert(id);
    assert(dbrs);
    assert(id->db == dbrs->db);

    if (dbrs->size >= dbrs->memsize) {
        dbrs->memsize += 100;
        dbrs->rows = REALLOC(dbrs->rows,dbrs->memsize * sizeof(DbItem));
    }
    DbItem *insert = dbrs->rows + dbrs->size;
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

void db_scan_and_add_rowset(char *path,char *name,Exp *exp,
        int *rowset_count_ptr,DbItemSet ***row_set_ptr) {

    HTML_LOG(0,"begin db_scan_and_add_rowset [%s][%s]",path,name);
TRACE;
    if (db_to_be_scanned(name)) {
TRACE;

        Db *db = db_init(path,name);

        if (db) {
TRACE;

            DbItemSet *r = db_scan_titles(db,exp);

            if ( r != NULL ) {
TRACE;
                dump_all_rows2("rowset",r->size,r->rows);

                (*row_set_ptr) = REALLOC(*row_set_ptr,((*rowset_count_ptr)+2)*sizeof(DbItemSet*));
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
DbItemSet **db_crossview_scan_titles(
        int crossview,
        Exp *exp){
    int rowset_count=0;
    DbItemSet **rowsets = NULL;

TRACE;
    HTML_LOG(1,"begin db_crossview_scan_titles");
    // Add information from the local database
    db_scan_and_add_rowset( localDbPath(),"*", exp, &rowset_count,&rowsets);
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
                        db_scan_and_add_rowset( path,name, exp, &rowset_count,&rowsets);

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

    HTML_LOG(1,"end db_crossview_scan_titles");
    return rowsets;
}

void db_free_rowsets_and_dbs(DbItemSet **rowsets) {
    if (rowsets) {
        DbItemSet **r;
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

    HTML_LOG(1,"extract_idlist from [%s]",query);

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
        HTML_LOG(1,"idlist:db: name=%s searching all ids",db_name);
    } else {
        int i;
        HTML_LOG(1,"idlist:db: name=%s searching %d ids",db_name,*num_ids);
        for(i  = 0 ; i < *num_ids ; i++ ) {
            HTML_LOG(0,"idlist:db: name=%s id %d",db_name,result[i]);
        }
    }

    return result;
}

DbItemSet * db_scan_titles( Db *db, Exp *exp)
{

    DbItemSet *rowset = NULL;

    ViewMode *view=get_view_mode();

    int tv_or_movie_view = (view->view_class == VIEW_CLASS_DETAIL);

    int num_ids;
    int *ids = extract_idlist(db->source,&num_ids);

    HTML_LOG(3,"Creating db scan pattern..");

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
        DbItem rowid;
        db_rowid_init(&rowid,db);

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

                    if (keeprow) {
                        if (num_ids != ALL_IDS && idlist_index(rowid.id,num_ids,ids) == -1) {
                            keeprow = 0;
                        }
                    }
                    //if (keeprow) HTML_LOG(0,"xx id ok");
                    if (keeprow) {
                        if (exp && evaluate_num(exp,&rowid) == 0) {
                            keeprow = 0;
                        }
                    }
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
    FREE(db->directors_file);
    FREE(db->actors_file);
    FREE(db->writers_file);
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



void db_rowset_free(DbItemSet *dbrs) {
    int i;

    for(i = 0 ; i<dbrs->size ; i++ ) {
        DbItem *item = dbrs->rows + i;
        db_rowid_free(item,0);
    }

    FREE(dbrs->rows);
    FREE(dbrs);
}


void db_rowset_dump(int level,char *label,DbItemSet *dbrs) {
    int i;
    if (dbrs->size == 0) {
        HTML_LOG(level,"Rowset: %s : EMPTY",label);
    } else {
        for(i = 0 ; i<dbrs->size ; i++ ) {
            DbItem *item = dbrs->rows + i;
            HTML_LOG(level,"Rowset: %s [%s - %c - %d %s ]",label,item->title,item->category,item->season,item->poster);
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
                        DbItem item;
                        parse_row(ALL_IDS,NULL,0,buf,db,&item);
                        if (delete_mode == DELETE_MODE_DELETE || delete_mode == DELETE_MODE_REMOVE) {
                            add_internal_images_to_delete_queue(&item);
                            if (delete_mode == DELETE_MODE_DELETE ) {
                                delete_media(&item,1);
                            }
                        }
                        db_rowid_free(&item,0);
                        affected_total++;

                    } else if ( regexec(&regex_ptn,buf,2,pmatch,0) == 0) {
                        // Field is present - change it and write the modified field.
                        int spos=pmatch[1].rm_so;
                        int epos=pmatch[1].rm_eo;

                        HTML_LOG(0," got regexec %s %s from %d to %d ",id_regex_text,regex_text,spos,epos);

                        HTML_LOG(0,"%.*s[[%s]]%s",spos,buf,new_value,buf+epos);
                        fprintf(db_out,"%.*s%s%s",spos,buf,new_value,buf+epos);
                        affected_total++;

                    } else {
                        // field not present so just emit
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

void db_remove_row_helper(DbItem *item,int mode) {
    char idlist[20];
    sprintf(idlist,"%ld",item->id);
    db_set_fields_by_source(DB_FLDID_ID,NULL,item->db->source,idlist,mode);
}
// remove item from list, keep media, and keep images. initiated by Auto delist.
void db_auto_remove_row(DbItem *item) {
    db_remove_row_helper(item,DELETE_MODE_AUTO_REMOVE);
}
// remove item from list, keep media, delete images. user initiated delist
void db_remove_row(DbItem *item) {
    db_remove_row_helper(item,DELETE_MODE_REMOVE);
}
// remove item from list, delete everything. user initiated delete.
void db_delete_row_and_media(DbItem *item) {
    db_remove_row_helper(item,DELETE_MODE_DELETE);
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

void dump_row(char *prefix,DbItem *item)
{
    HTML_LOG(0,"xx %s  %d:T[%s]S[%d]E[%s]w[%d]",prefix,item->id,item->title,item->season,item->episode,item->watched);
}
void dump_all_rows(char *prefix,int num_rows,DbItem **sorted_rows)
{
#if 0
    int i;
    for(i = 0 ; i <  num_rows ; i ++ ) {
        DbItem *item = sorted_rows[i];
        dump_row(prefix,item);
        for( ; item ; item = item->linked ) {
            dump_row("linked:",item);
        }
    }
#endif
}
void dump_all_rows2(char *prefix,int num_rows,DbItem sorted_rows[])
{
#if 0
    int i;
    for(i = 0 ; i <  num_rows ; i ++ ) {
        DbItem *item = sorted_rows+i;
        dump_row(prefix,item);
        for( ; item ; item = item->linked ) {
            dump_row("linked:",item);
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
