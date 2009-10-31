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

// If a paramter begins with this prefix then the remaining part 
// of the parameter name is passed as an option to the catalog.sh command
#define RESCAN_OPT_PREFIX "rescan_opt_"

// If a parameter begins with RESCAN_DIR_PREFIX then the remaining
// part of the name is passed as a scan folder to the catalog.sh command
#define RESCAN_DIR_PREFIX "rescan_dir_"

// If a parameter begins with RESCAN_OPT_GROUP_PREFIX then the VALUE
// is passed as an option to the catalog.sh command
// This is to allow for radio buttons.
#define RESCAN_OPT_GROUP_PREFIX "rescan_opt_@group"
struct hashtable *get_newly_selected_ids_by_source(int *totalp);
struct hashtable *get_newly_deselected_ids_by_source(int *totalp);
int count_unchecked();
// Add val=src1(id|..)src2(id|..) to hash table.
int idlist_to_idhash(struct hashtable *h,char *val);
int idcount(char *idlist);
void update_idlist(struct hashtable *source_id_hash_removed);

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


    query_remove("form");
    query_remove("select");
    query_remove("action");
    struct hashtable_itr *itr;
    Array *a = array_new(NULL);
    char *k,*v;
    for(itr=hashtable_loop_init(g_query) ; hashtable_loop_more(itr,&k,&v) ; ) {
        if (is_checkbox(k,v) || util_starts_with(k,RESCAN_OPT_PREFIX)) {
            array_add(a,k);
        }
    }

    int i;
    for(i=0 ; i<a->size ; i++) {
        HTML_LOG(1,"removing query[%s]",a->array[i]);
        query_remove(a->array[i]);
    }
    array_free(a);
}

void gaya_send_link(char *arg) {
    //send this link to gaya with a single argment.
//HTML_LOG(1,"dbg remove this arg=[%s]",arg);
    FILE *pip = fopen("/tmp/gaya_bc","w");
    if (!pip) {
        html_error("cant send [%s] to gaya");
    } else {
        char *link;
        char *file=url_encode(arg);
//HTML_LOG(1,"dbg remove this and this 1 file=[%s]",file);
        ovs_asprintf(&link,"http://localhost:8883%s?"REMOTE_VOD_PREFIX2"%s",getenv("SCRIPT_NAME"),file);
//HTML_LOG(1,"dbg remove this and this 2 link=[%s]",link);
        FREE(file);
//HTML_LOG(1,"dbg remove this and this 3");
        HTML_LOG(1,"sending link to gaya [%s]",link);
        fprintf(pip,"%s\n",link);
        fclose(pip);
        FREE(link);
    }
}


void delete_file(char *dir,char *name) {
    char *path;
    ovs_asprintf(&path,"%s/%s",dir,name);
    HTML_LOG(0,"delete [%s]",path);
    if (unlink(path) ) {
        html_error("failed to delete [%s] from [%s]",name,dir);
    }
    FREE(path);
}

void delete_media(DbRowId *rid,int delete_related) {

    char *f = strrchr(rid->file,'/');
    Array *names_to_delete=NULL;

    HTML_LOG(1,"%s %d begin delete_media",__FILE__,__LINE__);
    if (f[1] == '\0' ) {
        if (!exists_file_in_dir(rid->file,"video_ts") &&  !exists_file_in_dir(rid->file,"VIDEO_TS")) {
            HTML_LOG(0,"folder doesnt look like dvd floder");
            return;
        }
        util_rmdir(f,".");
        names_to_delete = array_new(free);
    } else {
        *f='/';
        HTML_LOG(1,"delete [%s]",rid->file);
        unlink(rid->file);
        *f='\0';
        names_to_delete = split(rid->parts,"/",0);

        if (delete_related) {

            struct dirent *dp;
            DIR *d = opendir(rid->file);
            if (d != NULL) {
                while((dp = readdir(d)) != NULL) {
                    if (util_starts_with(dp->d_name,"unpak.")) {

                        array_add(names_to_delete,STRDUP(dp->d_name));

                    } else if ( util_strreg(dp->d_name,"[^A-Za-z0-9](sample|samp)[^A-Za-z0-9]",REG_ICASE) != NULL ) {

                        array_add(names_to_delete,STRDUP(dp->d_name));

                    } 
                }
                closedir(d);
            }
        }
    }

    //Delete the following files at the end if not used.
    delete_queue_add(rid,rid->fanart);
    delete_queue_add(rid,rid->poster);
    delete_queue_add(rid,rid->nfo);

    if(names_to_delete && names_to_delete->size) {
       int i=0;
       for(i= 0 ; i<names_to_delete->size ; i++) {
           delete_file(rid->file,names_to_delete->array[i]);
       }
    }
    array_free(names_to_delete);
    HTML_LOG(1,"%s %d end delete_media",__FILE__,__LINE__);
    *f='/';
}


void delete_queue_add(DbRowId *rid,char *path) {

    if (path) {
        int freepath;
        char *real_path=get_path(rid,path,&freepath);

        if (g_delete_queue == NULL) {
            g_delete_queue = string_string_hashtable(16);
        }
        if (hashtable_search(g_delete_queue,real_path)) {
            if(freepath) {
                FREE(real_path);
            }
        } else {
            HTML_LOG(0,"delete_queue: pending delete [%s]",real_path);
            if(freepath) {
                hashtable_insert(g_delete_queue,real_path,"1");
            } else {
                hashtable_insert(g_delete_queue,STRDUP(real_path),"1");
            }
        }
    }
}


//Remove the filename from the delete queue
void delete_queue_unqueue(DbRowId *rid,char *path) {
    if (g_delete_queue != NULL && path != NULL ) {
        int freepath;
        char *real_path = get_path(rid,path,&freepath);
        if (hashtable_remove(g_delete_queue,real_path,1) ) {
            HTML_LOG(0,"delete_queue: unqueuing [%s] in use",real_path);
        }
        if (freepath) FREE(real_path);
    }
}

//physically delete files that have been queued for deletetion
void delete_queue_delete() {
    struct hashtable_itr *itr;
    char *k;

    if (g_delete_queue != NULL ) {
        
        for(itr=hashtable_loop_init(g_delete_queue) ; hashtable_loop_more(itr,&k,NULL) ; ) {
            HTML_LOG(1,"delete_queue: deleting [%s]",k);
            unlink(k);
        }
        hashtable_destroy(g_delete_queue,1,0);
        g_delete_queue=NULL;
    }
}

void send_command(char *source,char *remote_cmd) {
    char *cmd;
    int freepath;
    char *script = get_mounted_path(source,"/share/Apps/oversight/oversight.sh",&freepath);
    ovs_asprintf(&cmd,"\"%s\" SAY %s",script,remote_cmd);

    HTML_LOG(0,"send command:%s",cmd);

    system(cmd);

    if (freepath) {
        FREE(script);
    }
    FREE(cmd);
}

void do_actions() {

    char *view=query_val("view");
    char *action=query_val("action");
    //char *select=query_val("select");

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

        if (strcmp(action,"reinstall") == 0) {

            char *cmd;
            ovs_asprintf(&cmd,"%s/oversight-install.cgi install",appDir());
            util_system(cmd);
            FREE(cmd);

        } else if (strcmp(action,"rescan_request") == 0) {

            int parallel_scan = 0;
            char *cmd = STRDUP("catalog.sh NOWRITE_NFO ");
            char *k;
            char *v;
            
            // get all parameters with RESCAN_OPT_PREFIX
            // these are passed to the command line for both parallel and sequential scans
            struct hashtable_itr *itr = hashtable_loop_init(g_query);
            while (hashtable_loop_more(itr,&k,&v)) {

                if (util_starts_with(k,RESCAN_OPT_PREFIX)) {
                    char *tmp;
                    char *opt;
                    if (util_starts_with(k,RESCAN_OPT_GROUP_PREFIX)) {
                        opt = v;
                    } else {
                        opt = k+strlen(RESCAN_OPT_PREFIX);
                    }
                    ovs_asprintf(&tmp,"%s %s",cmd,opt);
                    FREE(cmd);
                    cmd = tmp;
                    if (strcmp(opt,"PARALLEL_SCAN" ) == 0 ) {
                        parallel_scan = 1;
                    }
                }
            }
            
            // get all parameters with RESCAN_DIR_PREFIX
            // If PARALLEL scan then the command is executed once for each folder.
            // otherwise all folders are passed together.
            itr = hashtable_loop_init(g_query);
            while (hashtable_loop_more(itr,&k,NULL)) {
                if (util_starts_with(k,RESCAN_DIR_PREFIX)) {
                    char *tmp;
                    ovs_asprintf(&tmp,"%s %s",cmd,k+strlen(RESCAN_DIR_PREFIX));
                    if (parallel_scan) {
                        send_command("*",tmp);
                        FREE(tmp);
                    } else {
                        FREE(cmd);
                        cmd = tmp;
                    }
                }
            }
            if (!parallel_scan) {
                send_command("*",cmd);
            }
            FREE(cmd);

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

                        HTML_LOG(1,"new name value [%s]=[%s]=[%s]",option_name,real_name,value);
                        HTML_LOG(1,"old name value [%s]=[%s]",old_name,old_value);

                        char *cmd;
                        ovs_asprintf(&cmd,"cd \"%s\" && ./options.sh SET \"conf/%s\" \"%s\" \"%s\"",
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

    } else if (*action) {

        int total_deleted = 0;
        struct hashtable *changed_source_id_hash = NULL;

        char *actionids = query_val("actionids");
        if (actionids && *actionids) {

            int total_changed = 0;

            // This is the direct delete method

            HTML_LOG(0,"actionids=[%s]",actionids);

            changed_source_id_hash = string_string_hashtable(16);

            total_changed = idlist_to_idhash(changed_source_id_hash,actionids);

            if (allow_mark() && strcmp(action,"watch") == 0) {

                db_set_fields(DB_FLDID_WATCHED,"1",changed_source_id_hash,DELETE_MODE_NONE);
                query_remove("action");

            } else if (allow_mark() && strcmp(action,"unwatch") == 0) {

                db_set_fields(DB_FLDID_WATCHED,"0",changed_source_id_hash,DELETE_MODE_NONE);
                query_remove("action");

            } else if (allow_delete() && strcmp(action,"delete") == 0) {

                db_set_fields(DB_FLDID_ACTION,NULL,changed_source_id_hash,DELETE_MODE_DELETE);
                total_deleted = total_changed;
                if (total_deleted > 0) {
                    update_idlist(changed_source_id_hash);
                }
                query_remove("action");

            } else if (allow_delist() && strcmp(action,"delist") == 0) {

                db_set_fields(DB_FLDID_ACTION,NULL,changed_source_id_hash,DELETE_MODE_REMOVE);
                total_deleted = total_changed;
                if (total_deleted > 0) {
                    update_idlist(changed_source_id_hash);
                }
                query_remove("action");

            }
            query_remove("actionids");
            hashtable_destroy(changed_source_id_hash,1,1);

        } else if (allow_mark() && strcmp(action,"Mark") == 0) {


            int total_changed = 0;
            
            changed_source_id_hash = get_newly_selected_ids_by_source(&total_changed);
            db_set_fields(DB_FLDID_WATCHED,"1",changed_source_id_hash,DELETE_MODE_NONE);
            hashtable_destroy(changed_source_id_hash,1,1);

            changed_source_id_hash = get_newly_deselected_ids_by_source(&total_changed);
            db_set_fields(DB_FLDID_WATCHED,"0",changed_source_id_hash,DELETE_MODE_NONE);
            hashtable_destroy(changed_source_id_hash,1,1);
            query_remove("action");


        } else if (allow_delete() && strcmp(action,"Delete") == 0) {

TRACE;
            changed_source_id_hash = get_newly_selected_ids_by_source(&total_deleted);
            db_set_fields(DB_FLDID_ACTION,NULL,changed_source_id_hash,DELETE_MODE_DELETE);
            if (total_deleted > 0) {
                update_idlist(changed_source_id_hash);
            }
            hashtable_destroy(changed_source_id_hash,1,1);
            query_remove("action");

        } else if (allow_delist() && strcmp(action,"Remove_From_List") == 0) {

TRACE;
            changed_source_id_hash = get_newly_selected_ids_by_source(&total_deleted);
            db_set_fields(DB_FLDID_ACTION,NULL,changed_source_id_hash,DELETE_MODE_REMOVE);
            if (total_deleted > 0) {
                update_idlist(changed_source_id_hash);
            }
            hashtable_destroy(changed_source_id_hash,1,1);
            query_remove("action");

        }

        // If in the tv  or movie view and all items have been deleted - go to the main view
        if (!*query_val("idlist")) {
            HTML_LOG(0,"Going back to main view");
            query_remove("view");
            query_remove("select");
        }

    }

    html_hashtable_dump(0,"post action query",g_query);


    if (*query_val("form") ) {

        clear_selection();

    }
}

// Collpase hash table with Key = source name value = "id1|id2|id3"
// to a string with format val=src1(id|..)src2(id|..)
// opposite function is idlist_to_idhash()
char *idhash_to_idlist(struct hashtable *source_id_hash) {
    char *out = NULL;
    struct hashtable_itr *itr;
    char *name,*ids;
    for(itr=hashtable_loop_init(source_id_hash) ; hashtable_loop_more(itr,&name,&ids) ; ) {
        char *tmp;
        ovs_asprintf(&tmp,"%s%s(%s)",
                NVL(out),
                name,
                ids);
        FREE(out);
        out = tmp;
    }
    HTML_LOG(0,"hash to list = [%s]",out);
    return out;
}

void update_idlist(struct hashtable *source_id_hash_removed)
{

    HTML_LOG(0,"pre update idlist = [%s]",query_val("idlist"));

    if (*query_val("idlist")) {

        struct hashtable *source_id_hash_current = string_string_hashtable(16);
        idlist_to_idhash(source_id_hash_current,query_val("idlist"));

        struct hashtable_itr *itr;
        char *source;
        char *removed_ids;

        for(itr=hashtable_loop_init(source_id_hash_removed) ; hashtable_loop_more(itr,&source,&removed_ids) ; ) {
            HTML_LOG(0,"Removing ids %s(%s)",source,removed_ids);
            char *oldids = hashtable_remove(source_id_hash_current,source,1);
            HTML_LOG(0,"Existing ids (%s)",oldids);

            if (oldids != NULL) {

                char *regex;
                ovs_asprintf(&regex,"\\<(%s)(\\||$)",removed_ids);

                char *keepids = replace_all(oldids,regex,"",0);
                HTML_LOG(0,"Remaining ids (%s)",keepids);

                // removing 1 from 1|2|3 will leave 2|3
                // removing 2 from 1|2|3 will leave 1|3
                // removing 3 from 1|2|3 will leave 1|2|
                if (*keepids) {
                    char *last = keepids+strlen(keepids)-1;
                    if (*last == '|') {
                        *last = '\0';
                        HTML_LOG(0,"Remaining ids (%s)",keepids);
                    }
                }
                FREE(regex);
                FREE(oldids);

                if (!EMPTY_STR(keepids)) {

                    hashtable_insert(source_id_hash_current,STRDUP(source),keepids);
                }
            }

        }
        //Update the html parameter
        query_update("idlist",idhash_to_idlist(source_id_hash_current));
        hashtable_destroy(source_id_hash_current,1,1);
    }
    HTML_LOG(0,"post update idlist = [%s]",query_val("idlist"));
}

// count the number if ids in an idlist format [source(id1|id2|..id3)][...][...]
// count = number of | + number of )
int idcount(char *idlist)
{
    int total=0;
    char *p;
    for(p=idlist; *p ; p++ ) {
        if (*p == '|' || *p == ')' ) {
            total++;
        }
    }
    return total;
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
// Key = source name value = "id1|id2|id3"
// opposite function is idhash_to_idlist()
int idlist_to_idhash(struct hashtable *h,char *val)
{

    Array *sources = split(val,")",0);
    int total=0;

    array_print("idlist_to_idhash",sources);

    if (sources) {
        int i;
        for(i = 0 ; i < sources->size ; i++ ) {

            char *source_idlist_str = sources->array[i]; 

            if (*source_idlist_str != '\0') {

                Array *source_ids = split(source_idlist_str,"(",0);

                array_print("idlist_to_idhash source ",source_ids);

                assert(source_ids && source_ids->size ==2);

                char *source = source_ids->array[0];
                char *idlist = source_ids->array[1];
                

                char *current_id_list = hashtable_search(h,source);

                char *new_idlist;


                if (current_id_list == NULL) {

                    hashtable_insert(h,STRDUP(source),STRDUP(idlist));
                    total++;

                } else {

                    ovs_asprintf(&new_idlist,"%s|%s",current_id_list,idlist);
                    hashtable_remove(h,source,1);
                    FREE(current_id_list);
                    hashtable_insert(h,STRDUP(source),new_idlist);
                    total++;

                }
                array_free(source_ids);
            }
        }
        array_free(sources);
    }
    return total;

HTML_LOG(1," end idlist_to_idhash");
}


int count_checked() {

    int total=0;
    char *name;
    char *val;
    struct hashtable_itr *itr;


    for(itr=hashtable_loop_init(g_query) ; hashtable_loop_more(itr,&name,&val) ; ) {

        if (util_starts_with(name,CHECKBOX_PREFIX) && strcmp(val,"on") != 0) {
            total++;
        }

    }
    HTML_LOG(1,"checked count [%d]",total);
    return total;
}


int count_unchecked() {

    int total=0;

    //First count the total number of ids passed in idlist
    char *p = query_val("idlist");
    if (*p) {
        total++;
        while (*p) {
            if (*p++ == '|' ) total++;
        }
    }

    //Now subtract total number of checked items.
    total -= count_checked();
    HTML_LOG(1,"unchecked count [%d]",total);
    return total;
}

struct hashtable *get_newly_selected_ids_by_source(int *totalp)
{

    struct hashtable *h = string_string_hashtable(16);

    char *name;
    char *val;
    struct hashtable_itr *itr;
    int total = 0;

    for(itr=hashtable_loop_init(g_query) ; hashtable_loop_more(itr,&name,&val) ; ) {

        if (is_checkbox(name,val) && checkbox_just_added(name) ) {

            HTML_LOG(1,"checkbox added [%s]",name);

            name += strlen(CHECKBOX_PREFIX);

            total += idlist_to_idhash(h,name);

        }
    }

    if (totalp) *totalp = total;
    return h;
}


struct hashtable *get_newly_deselected_ids_by_source(int *totalp)
{

    struct hashtable *h = string_string_hashtable(16);
    int total = 0;

    char *name;
    char *val;
    struct hashtable_itr *itr;

    for(itr=hashtable_loop_init(g_query) ; hashtable_loop_more(itr,&name,&val) ; ) {

        if (is_checkbox(name,val) && checkbox_just_removed(name) ) {

            HTML_LOG(1,"checkbox removed [%s]",name);
            name += strlen("orig_"CHECKBOX_PREFIX);

            total += idlist_to_idhash(h,name);

        }
    }
    if (totalp) *totalp = total;
HTML_LOG(1," end get_newly_deselected_ids_by_source");
    return h;
}


