#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <dirent.h>
#include "util.h"
#include "actions.h"
#include "oversight.h"
#include "gaya_cgi.h"
#include "display.h"
#include "hashtable_loop.h"

struct hashtable *get_newly_selected_ids_by_source();
struct hashtable *get_newly_deselected_ids_by_source();
int count_unchecked();

//True if there was post data.
int has_post_data() {
    char *e = getenv("TEMP_FILE");
    return (e && *e );
}

int is_checkbox(char *name,char *val) {
    if (val && strcmp(val,"on") ==0) {
        if (util_starts_with(name,CHECKBOX_PREFIX)) {
            return 1;
        } else if (util_starts_with(name,"orig_"CHECKBOX_PREFIX)) {
            return 1;
        } else if (util_starts_with(name,"option_")) {
            return 1;
        } else if (util_starts_with(name,"orig_option_") ) {
            return 1;
        }
    }
    return 0;
}

void clear_selection() {


    // Clear the selection
    query_remove("select");
    if (strcmp(query_val("action"),"Cancel") !=0) {
        query_remove("action");
    }
    struct hashtable_itr *itr;
    Array *a = array_new(NULL);
    char *k,*v;
    for(itr=hashtable_loop_init(g_query) ; hashtable_loop_more(itr,&k,&v) ; ) {
        if (is_checkbox(k,v)) {
            array_add(a,k);
        }
    }

    int i;
    for(i=0 ; i<a->size ; i++) {
        html_log(0,"removing query[%s]",a->array[i]);
        query_remove(a->array[i]);
    }
    array_free(a);
}

void gaya_send_link(char *arg) {
    //send this link to gaya with a single argment.
//html_log(0,"dbg remove this arg=[%s]",arg);
    FILE *pip = fopen("/tmp/gaya_bc","w");
    if (!pip) {
        html_error("cant send [%s] to gaya");
    } else {
        char *link;
        char *file=url_encode(arg);
//html_log(0,"dbg remove this and this 1 file=[%s]",file);
        ovs_asprintf(&link,"http://localhost:8883%s?"REMOTE_VOD_PREFIX2"%s",getenv("SCRIPT_NAME"),file);
//html_log(0,"dbg remove this and this 2 link=[%s]",link);
        free(file);
//html_log(0,"dbg remove this and this 3");
        html_log(0,"sending link to gaya [%s]",link);
        fprintf(pip,"%s\n",link);
        fclose(pip);
        free(link);
    }
}


void delete_file(char *dir,char *name) {
    char *path;
    ovs_asprintf(&path,"%s/%s",dir,name);
    html_log(0,"delete [%s]",path);
    unlink(path);
    FREE(path);
}

void delete_media(DbRowId *rid,int delete_related) {

    char *f = strrchr(rid->file,'/');
    Array *names_to_delete=NULL;

    html_log(0,"%s %d begin delete_media",__FILE__,__LINE__);
    if (f[1] == '\0' ) {
        if (!exists_file_in_dir(rid->file,"video_ts") &&  !exists_file_in_dir(rid->file,"VIDEO_TS")) {
            html_log(0,"folder doesnt look like dvd floder");
            return;
        }
        util_rmdir(f,".");
        names_to_delete = array_new(free);
    } else {
        *f='/';
        html_log(0,"delete [%s]",rid->file);
        unlink(rid->file);
        *f='\0';
        names_to_delete = split(rid->parts,"/",0);

        if (delete_related) {

            struct dirent *dp;
            DIR *d = opendir(rid->file);
            if (d != NULL) {
                while((dp = readdir(d)) != NULL) {
                    if (util_starts_with(dp->d_name,"unpak.")) {

                        array_add(names_to_delete,dp->d_name);

                    } else if ( util_strreg(dp->d_name,"[^A-Za-z0-9](sample|samp)[^A-Za-z0-9]",REG_ICASE) != NULL ) {

                        array_add(names_to_delete,dp->d_name);

                    } 
                }
                closedir(d);
            }
        }
    }

    //Delete the following files if not used.
    delete_queue_add(rid->db->source,rid->poster);
    delete_queue_add(rid->db->source,rid->nfo);

    if(names_to_delete && names_to_delete->size) {
       int i=0;
       for(i= 0 ; i<names_to_delete->size ; i++) {
           delete_file(rid->file,names_to_delete->array[i]);
       }
    }
    array_free(names_to_delete);
    html_log(0,"%s %d end delete_media",__FILE__,__LINE__);
    *f='/';
}

static struct hashtable *g_delete_queue = NULL;

void delete_queue_add(char *source,char *path) {

    if (source && path && *source && *path ) {
        char *real_path = get_mounted_path(source,path);
        if (g_delete_queue == NULL) {
            g_delete_queue = string_string_hashtable(16);
        }
        if (hashtable_search(g_delete_queue,real_path)) {
            free(real_path);
        } else {
            html_log(0,"delete_queue: pending delete [%s]",real_path);
            hashtable_insert(g_delete_queue,real_path,"1");
        }
    }
}


//Remove the filename from the delete queue
void delete_queue_unqueue(char *source,char *path) {
    if (g_delete_queue != NULL && path != NULL ) {
        char *real_path = get_mounted_path(source,path);
        html_log(0,"delete_queue: unqueuing [%s] in use",real_path);
        hashtable_remove(g_delete_queue,real_path);
        FREE(real_path);
    }
}

//physically delete files that have been queued for deletetion
void delete_queue_delete() {
    struct hashtable_itr *itr;
    char *k;

    if (g_delete_queue != NULL ) {
        
        for(itr=hashtable_loop_init(g_delete_queue) ; hashtable_loop_more(itr,&k,NULL) ; ) {
            html_log(0,"delete_queue: deleting [%s]",k);
            unlink(k);
        }
        hashtable_destroy(g_delete_queue,1,0);
        g_delete_queue=NULL;
    }
}
void clean_params() {
    query_remove("idlist");
    query_remove("view");
    query_remove("action");
    query_remove("select");
}

void send_command(char *source,char *remote_cmd) {
    char *cmd;
    char *script = get_mounted_path(source,"/share/Apps/oversight/oversight.sh");
    ovs_asprintf(&cmd,"\"%s\" SAY %s",script,remote_cmd);

    html_log(0,"send command:%s",cmd);

    system(cmd);

    FREE(script);
    FREE(cmd);
}


void do_actions() {

    char *view=query_val("view");
    char *action=query_val("action");
    char *select=query_val("select");

    // If remote play then send to gaya
    char *file=query_val(REMOTE_VOD_PREFIX1);
    if (file && *file) {
        gaya_send_link(file); 
        query_remove(REMOTE_VOD_PREFIX1);
    }



    if (strcmp(query_val("searchb"),"Hide") == 0) {

        query_remove(QUERY_PARAM_SEARCH_MODE);
        query_remove("searchb");
    }

    if (allow_admin() && strcmp(view,"admin")==0 ) {

        if (strcmp(action,"rescan_request") == 0) {

            send_command("*","catalog.sh RESCAN UPDATE_POSTERS NOWRITE_NFO");

        } else if (strcmp(action,"Save Settings") == 0) {

            struct hashtable_itr *itr;
            char *option_name,*value;
            for(itr=hashtable_loop_init(g_query) ; hashtable_loop_more(itr,&option_name,&value) ; ) {
                if (util_starts_with(option_name,"option_")) {

                    char *real_name = strchr(option_name,'_')+1;

                    char *old_name,*old_value;
                    ovs_asprintf(&old_name,"orig_%s",option_name);

                    old_value=query_val(old_name);

                    if (strcmp(value,old_value) != 0) {

                        html_log(0,"new name value [%s]=[%s]=[%s]",option_name,real_name,value);
                        html_log(0,"old name value [%s]=[%s]",old_name,old_value);

                        char *cmd;
                        ovs_asprintf(&cmd,"cd \"%s\" && ./options.sh SET \"%s\" \"%s\" \"%s\"",
                                appDir(),
                                query_val("file"),
                                real_name,
                                value);
                        util_system(cmd);
                        FREE(cmd);

                        if (strcmp(real_name,"catalog_watch_frequency") == 0) {
                           char *cmd;
                           ovs_asprintf(&cmd,"cd \"%s\" && ./oversight.sh WATCH_FOLDERS %s",
                                   appDir(),value);
                           util_system(cmd);
                           FREE(cmd);
                        }

                    }
                    FREE(old_name);
                }
            }
        }

    } else if (*select) {

        if (allow_mark() && strcmp(action,"Mark") == 0) {

            struct hashtable *source_id_hash = NULL;
            
            source_id_hash = get_newly_selected_ids_by_source();
            db_set_fields(DB_FLDID_WATCHED,"1",source_id_hash,DELETE_MODE_NONE);
            hashtable_destroy(source_id_hash,1,1);

            source_id_hash = get_newly_deselected_ids_by_source();
            db_set_fields(DB_FLDID_WATCHED,"0",source_id_hash,DELETE_MODE_NONE);
            hashtable_destroy(source_id_hash,1,1);


        } else if (allow_mark() && strcmp(action,"Delete") == 0) {

            struct hashtable *source_id_hash = NULL;
            
            source_id_hash = get_newly_selected_ids_by_source();
            db_set_fields(DB_FLDID_ACTION,"D",source_id_hash,DELETE_MODE_DELETE);
            hashtable_destroy(source_id_hash,1,1);
            if (count_unchecked() == 0) {
                // No more remaining go back to main view
                clean_params();
            }

        } else if (allow_mark() && strcmp(action,"Remove_From_List") == 0) {

            struct hashtable *source_id_hash = NULL;
            
            source_id_hash = get_newly_selected_ids_by_source();
            db_set_fields(DB_FLDID_ID,NULL,source_id_hash,DELETE_MODE_REMOVE);
            hashtable_destroy(source_id_hash,1,1);
            if (count_unchecked() == 0) {
                clean_params();
                // No more remaining go back to main view
            }
        }

    }

    html_hashtable_dump(0,"post action query",g_query);

    if (has_post_data()) {

        clear_selection();

    }
}

int checkbox_just_added(char *name) {
    if (util_starts_with(name,CHECKBOX_PREFIX)) {
        //check orig_CHECKBOX_PREFIX.. is not in query string
        char *orig;
        ovs_asprintf(&orig,"orig_%s",name);
        if (!*query_val(orig)) {
            return 1;
        }
    }
    return 0;
}

int checkbox_just_removed(char *name) {
    if (util_starts_with(name,"orig_"CHECKBOX_PREFIX)) {
        //check CHECKBOX_PREFIX.. is not in query string
        if (!*query_val(name+strlen("orig_"))) {
            return 1;
        }
    }
    return 0;
}

// Add val=src1(id|..)src2(id|..) to hash table.
void merge_id_by_source(struct hashtable *h,char *val) {

    Array *sources = split(val,")",0);

    array_print("merge_id_by_source",sources);

    if (sources) {
        int i;
        for(i = 0 ; i < sources->size ; i++ ) {

            char *source_idlist_str = sources->array[i]; 

            if (*source_idlist_str != '\0') {

                Array *source_ids = split(source_idlist_str,"(",0);

                array_print("merge_id_by_source source ",source_ids);

                assert(source_ids && source_ids->size ==2);

                char *source = source_ids->array[0];
                char *idlist = source_ids->array[1];
                
html_log(0," merge_id_by_source [%s][%s]",source,idlist);

                char *current_id_list = hashtable_search(h,source);

html_log(0," merge_id_by_source  current [%s]",current_id_list);

                char *new_idlist;


                if (current_id_list == NULL) {

                    hashtable_insert(h,STRDUP(source),STRDUP(idlist));
html_log(0," merge_id_by_source added [%s]",idlist);

                } else {

                    ovs_asprintf(&new_idlist,"%s|%s",current_id_list,idlist);
                    hashtable_remove(h,source);
                    FREE(current_id_list);
                    hashtable_insert(h,STRDUP(source),new_idlist);

html_log(0," merge_id_by_source appended [%s]",new_idlist);

                }
                array_free(source_ids);
            }
        }
        array_free(sources);
    }
html_log(0," end merge_id_by_source");
}


int count_unchecked() {

    int total=0;

    char *name;
    char *val;
    struct hashtable_itr *itr;

    for(itr=hashtable_loop_init(g_query) ; hashtable_loop_more(itr,&name,&val) ; ) {

        if (util_starts_with(name,CHECKBOX_PREFIX) && strcmp(val,"on") != 0) {
            total++;
        }

    }
    html_log(0,"unchecked count [%d]",total);
    return total;
}

struct hashtable *get_newly_selected_ids_by_source() {

    struct hashtable *h = string_string_hashtable(16);

    char *name;
    char *val;
    struct hashtable_itr *itr;

    for(itr=hashtable_loop_init(g_query) ; hashtable_loop_more(itr,&name,&val) ; ) {

        if (is_checkbox(name,val) && checkbox_just_added(name) ) {

            html_log(0,"checkbox added [%s]",name);

            name += strlen(CHECKBOX_PREFIX);

            merge_id_by_source(h,name);

        }
    }
    return h;
}


struct hashtable *get_newly_deselected_ids_by_source() {

    struct hashtable *h = string_string_hashtable(16);

    char *name;
    char *val;
    struct hashtable_itr *itr;

    for(itr=hashtable_loop_init(g_query) ; hashtable_loop_more(itr,&name,&val) ; ) {

        if (is_checkbox(name,val) && checkbox_just_removed(name) ) {

            html_log(0,"checkbox removed [%s]",name);
            name += strlen("orig_"CHECKBOX_PREFIX);

            merge_id_by_source(h,name);

        }
    }
html_log(0," end get_newly_deselected_ids_by_source");
    return h;
}


