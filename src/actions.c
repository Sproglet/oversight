// $Id:$
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
#include "mount.h"
#include "permissions.h"
#include "template.h"

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


typedef enum { LOCK_STATUS_UNKNOWN , LOCK_STATUS_LOCK , LOCK_STATUS_UNLOCK } LockMode;
typedef enum { MARKED_STATUS_UNKNOWN , MARKED_STATUS_MARKED , MARKED_STATUS_UNMARKED } MarkedStatus;


struct hashtable *get_newly_selected_ids_by_source(int *totalp);
struct hashtable *get_newly_deselected_ids_by_source(int *totalp);
int count_unchecked();
void do_action_by_id(struct hashtable *ids_by_source,void (*action)(DbItem *,void *),void *action_data);
// Add val=src1(id|..)src2(id|..) to hash table.
int idlist_to_idhash(struct hashtable *h,char *val);
int idcount(char *idlist);
void update_idlist(struct hashtable *source_id_hash_removed);

void lock_item_cb(DbItem *item,void *action_data);
void unlock_item_cb(DbItem *item,void *action_data);
void lock_toggle_item_cb(DbItem *item,void *action_data);
void get_marked_status_cb(DbItem *item,void *data);
void get_locked_status_cb(DbItem *item,void *data);

//True if there was post data.
int has_post_data() {
    char *e = getenv("TEMP_FILE");
    return (e && *e );
}

static int is_checkbox(char *name,char *val) {
    if (val && STRCMP(val,"on") ==0) {
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

static void clear_selection() {


    query_remove(QUERY_PARAM_CONFIG_HELP);
    query_remove(QUERY_PARAM_CONFIG_FILE);
    query_remove(QUERY_PARAM_CONFIG_TITLE);
    query_remove("form");
    query_remove(QUERY_PARAM_SELECT);
    query_remove(QUERY_PARAM_ACTION);

    query_remove(QUERY_PARAM_SET_NAME);
    query_remove(QUERY_PARAM_SET_VAL);

    query_remove("old_action");
    struct hashtable_itr *itr;
    Array *a = array_new(NULL);
    char *k,*v;
    for(itr=hashtable_loop_init(g_query) ; hashtable_loop_more(itr,&k,&v) ; ) {
        if (is_checkbox(k,v) || util_starts_with(k,RESCAN_OPT_PREFIX) || util_starts_with(k,RESCAN_DIR_PREFIX)) {
            array_add(a,k);
        }
    }

    int i;
    for(i=0 ; i<a->size ; i++) {
        query_remove(a->array[i]);
    }
    array_free(a);
}

static void gaya_send_link(char *arg) {
    //send this link to gaya with a single argment.
HTML_LOG(0,"dbg remove this arg=[%s]",arg);
    FILE *pip = fopen("/tmp/gaya_bc","w");
    if (!pip) {
        html_error("cant send [%s] to gaya");
    } else {
        char *link;
        char *file=url_encode(arg);
HTML_LOG(0,"dbg remove this and this 1 file=[%s]",file);
        ovs_asprintf(&link,"http://localhost:8883%s?"REMOTE_VOD_PREFIX2"=%s",getenv("SCRIPT_NAME"),file);
HTML_LOG(0,"dbg remove this and this 2 link=[%s]",link);
        FREE(file);
HTML_LOG(0,"dbg remove this and this 3");
        HTML_LOG(0,"sending link to gaya [%s]",link);
        fprintf(pip,"%s\n",link);
        fclose(pip);
        FREE(link);
    }
}


void delete_media(DbItem *item,int delete_related) {


    Array *names_to_delete=NULL;
    char *dir = util_dirname(item->file);

    if(is_dvd_folder(item->file)) {
        // VIDEO_TS
        if (!exists_in_dir(item->file,"video_ts") &&  !exists_in_dir(item->file,"VIDEO_TS") && 
             !exists_in_dir(item->file,"bdmv") &&  !exists_in_dir(item->file,"BDMV") ) {
            HTML_LOG(0,"folder [%s] doesnt look like dvd folder");
            return;
        }
        delete_queue_add(item,1,item->file);
    } else {

        int i;

        delete_queue_add(item,1,item->file);
        names_to_delete = split(item->parts,"/",0);
        for(i = 0 ; i < names_to_delete->size ; i++ ) {
            delete_queue_add(item,1,names_to_delete->array[i]);
        }

        if (delete_related) {

            struct dirent *dp;
            DIR *d = opendir(dir);
            if (d != NULL) {
                while((dp = readdir(d)) != NULL) {
                    if (util_starts_with(dp->d_name,"unpak.")) {

                        delete_queue_add(item,1,dp->d_name);

                    } else if ( util_strreg(dp->d_name,"[^A-Za-z0-9](sample|samp)[^A-Za-z0-9]",REG_ICASE) != NULL ) {

                        delete_queue_add(item,1,dp->d_name);

                    } 
                }
                closedir(d);
            }
        }
    }

    //Delete the following files at the end if not used.
    delete_queue_add(item,0,item->nfo);

    // Delete all files with the same prefix.
    struct dirent *dp;
    char *prefix = util_basename_no_ext(item->file);
    DIR *d = opendir(dir);
    if (d != NULL) {
        while((dp = readdir(d)) != NULL) {
            if (util_starts_with(dp->d_name,prefix)) {

                // regex also allows for language tags before the extension
                if ( util_strreg(dp->d_name+strlen(prefix),"^\\.(|[a-z]+\\.)(srt|nfo|sub|idx|sub|png|jpg|sfv|srr)$",REG_ICASE) != NULL ) {
                    delete_queue_add(item,1,dp->d_name);

                }
            }
        }
        closedir(d);
    }
    FREE(prefix);

    // Delete the folder only if it's empty.
    delete_queue_add(item,0,dir);

    array_free(names_to_delete);
    FREE(dir);
    HTML_LOG(1,"%s %d end delete_media",__FILE__,__LINE__);
}

/*
 * Return list of images for this item - list will NOT free itself
 * The images will be passed to the delete queue.
 */
static void insert_image_list(DbItem *item,Array *a) {

TRACE;
    char *poster = internal_image_path_static(item,POSTER_IMAGE,0);
    //HTML_LOG(0,"poster[%s]",poster);
    if (poster) {
        array_add(a,STRDUP(poster));
        array_add(a,replace_all(poster,"\\.jpg$",IMAGE_EXT_THUMB,0));
        array_add(a,replace_all(poster,"\\.jpg$",IMAGE_EXT_THUMB_BOXSET,0));
    }

    char *fanart = internal_image_path_static(item,FANART_IMAGE,0);
    //HTML_LOG(0,"fanart[%s]",fanart);
    if (fanart) {
        array_add(a,STRDUP(fanart));
        array_add(a,replace_all(fanart,"\\.jpg$",IMAGE_EXT_HD,0));
        array_add(a,replace_all(fanart,"\\.jpg$",IMAGE_EXT_SD,0));
        array_add(a,replace_all(fanart,"\\.jpg$",IMAGE_EXT_PAL,0));
    }
    char *banner = internal_image_path_static(item,BANNER_IMAGE,0);
    //HTML_LOG(0,"banner[%s]",banner);
    if (banner) {
        array_add(a,STRDUP(banner));
    }
}

void remove_internal_images_from_delete_queue(DbItem *item)
{
    int i;
TRACE;
    if (g_delete_queue != NULL ) {
        Array *a = array_new(free);
        insert_image_list(item,a);
        for(i=0 ; i < a->size ; i++ ) {
            delete_queue_unqueue(item,(char *)(a->array[i]));
        }
        array_free(a);
    }
}

void add_internal_images_to_delete_queue(DbItem *item)
{
    int i;
    Array *a = array_new(NULL); // memory is taken over by delete queue
    insert_image_list(item,a);
    for(i=0 ; i < a->size ; i++ ) {
        delete_queue_add(item,1,(char *)(a->array[i]));
    }
    array_free(a);
}



void delete_queue_add(DbItem *item,int force,char *path) {

    if (path) {
        int freepath;


        char *real_path=get_path(item,path,&freepath);

        struct STAT64 st;

        if (util_stat(real_path,&st) == 0) {

            if (0 && strcmp(item->db->source,"*") == 0 && st.st_uid != nmt_uid()) {

                HTML_LOG(0,"Error: no permission to delete [%s]",item->file);

            } else {

                if (g_delete_queue == NULL) {
                    g_delete_queue = string_string_hashtable("delete queue",16);
                }
                if (hashtable_search(g_delete_queue,real_path)) {
                    if(freepath) {
                        FREE(real_path);
                    }
                } else {
                    HTML_LOG(0,"delete_queue: pending delete item: [%s] of [%d:%s]",real_path,item->id,item->title);
                    if(!freepath) {
                        real_path = STRDUP(real_path);
                    }
                    hashtable_insert(g_delete_queue,real_path,(force?"1":"0"));
                }
            }
        }
    }
}


//Remove the filename from the delete queue
void delete_queue_unqueue(DbItem *item,char *path) {
    if (g_delete_queue != NULL && path != NULL ) {
        int freepath;
        char *real_path = get_path(item,path,&freepath);
        if (hashtable_remove(g_delete_queue,real_path,1) ) {
            HTML_LOG(0,"delete_queue: unqueuing [%s] in use by [%d:%s]",real_path,item->id,item->title);
        }
        if (freepath) FREE(real_path);
    }
}

//physically delete files that have been queued for deletetion
void delete_queue_delete() {
    struct hashtable_itr *itr;
    char *k,*v;

    HTML_LOG(0,"delete queue %x",g_delete_queue);

    char *cmd=NULL;

    Array *files = array_new(NULL);
    Array *empty_folders = array_new(NULL);
    Array *nonempty_folders = array_new(NULL);

    if (g_delete_queue != NULL ) {
        
        // delete all files first
        for(itr=hashtable_loop_init(g_delete_queue) ; hashtable_loop_more(itr,&k,&v) ; ) {
           if (is_file(k)) {
               HTML_LOG(0,"delete_queue_delete: file [%s]",k);
               array_add(files,k);
           } else if (is_dir(k)) {
               if (count_chr(k,'/') > 2) {
                   HTML_LOG(0,"delete_queue_delete: folder [%s]",k);

                   if (v && *v == '1' ) {
                       array_add(nonempty_folders,k);
                   } else {
                       array_add(empty_folders,k);
                   }
               } else {
                   HTML_LOG(0,"delete_queue_delete: skipping folder [%s]",k);
               }
           }
        }

        char *f=expand_paths(files);
        char *d1=expand_paths(nonempty_folders);
        char *d2=expand_paths(empty_folders);
        ovs_asprintf(&cmd,"daemon sh %s/bin/delete.sh --rm %s --rmfr %s --rmdir %s",appDir(),NVL(f),NVL(d1),NVL(d2));
        util_system(cmd);
        FREE(cmd);
        FREE(f);
        FREE(d1);
        FREE(d2);

        array_free(files);
        array_free(empty_folders);
        array_free(nonempty_folders);

        hashtable_destroy(g_delete_queue,1,NULL);
        g_delete_queue=NULL;
    }
}

static void delete_config(char *name) {
    char *timestamp = timestamp_static();
    char *tmp,*tmp2;
    ovs_asprintf(&tmp,"%s/conf/%s",appDir(),name);
    ovs_asprintf(&tmp2,"%s/conf/%s.%s",appDir(),name,timestamp);
    if (rename(tmp,tmp2) != 0) {
        HTML_LOG(0,"Error renaming [%s] to [%s]",tmp,tmp2);
    } else {
        HTML_LOG(0,"Renamed [%s] to [%s]",tmp,tmp2);
    }
    FREE(tmp);
    FREE(tmp2);
}

static char *g_start_cell = NULL;

void set_start_cell()
{
    g_start_cell = STRDUP(query_val(QUERY_START_CELL));
    query_remove(QUERY_START_CELL);
}
char *get_start_cell()
{
    return g_start_cell;
}

void do_actions() {

    set_start_cell();

    ViewMode *view=get_view_mode(1);
    char *action=query_val(QUERY_PARAM_ACTION);
    char *set_name=query_val(QUERY_PARAM_SET_NAME);
    char *set_val=query_val(QUERY_PARAM_SET_VAL);

    // If remote play then send to gaya
    char *file=query_val(REMOTE_VOD_PREFIX1);
    if (!EMPTY_STR(file)) {
        gaya_send_link(file); 
        query_remove(REMOTE_VOD_PREFIX1);
    }



    if (STRCMP(query_val("searchb"),"Hide") == 0) {

        query_remove(QUERY_PARAM_SEARCH_MODE);
        query_remove("searchb");
    }

    if (allow_admin() && view == VIEW_ADMIN) {

        if (util_starts_with(action,"donate_")) {

#define DAY (24*60*60)
            if (STRCMP(action,"donate_remind") == 0) {
                // touch file one week in the future
                util_touch(donated_file(),time(NULL) + 7 * DAY );
            } else if ((STRCMP(action,"donate_no") == 0) || (STRCMP(action,"donate_done") == 0)) {
                // touch file 2 years in future.
                util_touch(donated_file(),time(NULL)+ 2 * 365 * DAY);
            } else  {
                // disable for one day
                util_touch(donated_file(),time(NULL) + 1 * DAY );
            }

        } else if (STRCMP(action,"kill_scans") == 0) {

            char *cmd;
            ovs_asprintf(&cmd,"daemon sh %s/bin/killscans.sh",appDir());
            util_system(cmd);

        } else if (STRCMP(action,"reinstall") == 0) {

            char *cmd;
            ovs_asprintf(&cmd,"%s/oversight-install.cgi install > %s/logs/reinstall.log 2>&1",appDir(),appDir());
            util_system(cmd);
            FREE(cmd);

        } else if (STRCMP(action,"reset_defaults") == 0) {

            delete_config("oversight.cfg");
            delete_config("catalog.cfg");
            delete_config("unpak.cfg");

        } else if (STRCMP(action,"reset_dns_cache") == 0) {

            char *cmd;
            ovs_asprintf(&cmd,"daemon sh %s/bin/dns.sh",appDir());
            util_system(cmd);

        } else if (STRCMP(action,"clear_cache") == 0) {

            util_rm("/mnt/.cache");

        } else if (STRCMP(action,"rescan_request") == 0) {

            int parallel_scan = 0;
            char *cmd ;

            ovs_asprintf(&cmd,"DAEMON_DIR='%s' daemon %s/bin/catalog.sh NOWRITE_NFO ",appDir(),appDir());

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
                    ovs_asprintf(&tmp,"%s \"%s\"",cmd,opt);
                    FREE(cmd);
                    cmd = tmp;
                    if (STRCMP(opt,"PARALLEL_SCAN" ) == 0 ) {
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
                    ovs_asprintf(&tmp,"%s \"%s\"",cmd,k+strlen(RESCAN_DIR_PREFIX));
                    if (parallel_scan) {
                        util_system(tmp);
                        FREE(tmp);
                    } else {
                        FREE(cmd);
                        cmd = tmp;
                    }
                }
            }
            if (!parallel_scan) {
                util_system(cmd);
            }
            FREE(cmd);

        } else if (STRCMP(action,"Save Settings") == 0) {

            struct hashtable_itr *itr;
            char *option_name,*value;
            for(itr=hashtable_loop_init(g_query) ; hashtable_loop_more(itr,&option_name,&value) ; ) {
                if (util_starts_with(option_name,"option_")) {

                    char *real_name = strchr(option_name,'_')+1;

                    char *old_name,*old_value;
                    ovs_asprintf(&old_name,"orig_%s",option_name);

                    old_value=query_val(old_name);

                    if (STRCMP(value,old_value) != 0) {

                        HTML_LOG(1,"new name value [%s]=[%s]=[%s]",option_name,real_name,value);
                        HTML_LOG(1,"old name value [%s]=[%s]",old_name,old_value);

                        char *file = query_val(QUERY_PARAM_CONFIG_FILE);
                        char *cmd;
                        ovs_asprintf(&cmd,"cd \"%s\" && ./bin/options.sh SET \"%s/conf/%s\" \"%s\" \"%s\"",
                            appDir(),
                            (strcmp(file,"skin.cfg")==0  ? skin_path() : appDir()),
                            file,
                            real_name,
                            value);
                        util_system(cmd);
                        FREE(cmd);

                        if (STRCMP(real_name,"catalog_watch_frequency") == 0) {
                           char *cmd;
                           ovs_asprintf(&cmd,"cd \"%s\" && ./bin/oversight.sh WATCH_FOLDERS %s",
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

            // The following actions are invoked when deleting and marking via gaya.
            // In this case the url was ...action=delete&actionsids=*(1|2|3)nas(4|5|6) etc.

            HTML_LOG(0,"actionids=[%s]",actionids);

            changed_source_id_hash = string_string_hashtable("changed_ids",16);

            total_changed = idlist_to_idhash(changed_source_id_hash,actionids);

            if (allow_mark() && STRCMP(action,"watch") == 0) {

                MarkedStatus m = MARKED_STATUS_UNKNOWN;
                do_action_by_id(changed_source_id_hash,get_marked_status_cb,&m);
                char *val=NULL;
                switch(m) {
                    case MARKED_STATUS_MARKED: val = "0" ; break;
                    case MARKED_STATUS_UNMARKED: val = "1" ; break;
                    default: assert(0);
                }
                db_set_fields(DB_FLDID_WATCHED,val,changed_source_id_hash,DELETE_MODE_NONE);

            } else if (allow_delete() && STRCMP(action,"delete") == 0) {

                db_set_fields(DB_FLDID_ACTION,NULL,changed_source_id_hash,DELETE_MODE_DELETE);
                total_deleted = total_changed;
                if (total_deleted > 0) {
                    update_idlist(changed_source_id_hash);
                }

            } else if (allow_delist() && STRCMP(action,"delist") == 0) {

                db_set_fields(DB_FLDID_ACTION,NULL,changed_source_id_hash,DELETE_MODE_REMOVE);
                total_deleted = total_changed;
                if (total_deleted > 0) {
                    update_idlist(changed_source_id_hash);
                }

            } else if (allow_locking() && STRCMP(action,"lock") == 0) {

                LockMode m = LOCK_STATUS_UNKNOWN;
                do_action_by_id(changed_source_id_hash,get_locked_status_cb,&m);
                char *val=NULL;
                void (*fn)(DbItem *,void *) = NULL;

                switch(m) {
                    case LOCK_STATUS_LOCK: val = "0" ; fn = unlock_item_cb ; break;
                    case LOCK_STATUS_UNLOCK: val = "1" ; fn = lock_item_cb ;  break;
                    default: assert(0);
                }
                do_action_by_id(changed_source_id_hash,fn,NULL);
                db_set_fields(DB_FLDID_LOCKED,val,changed_source_id_hash,DELETE_MODE_NONE);

                //LockMode mode = LOCK_STATUS_UNKNOWN;
                //do_action_by_id(changed_source_id_hash,lock_toggle_item_cb,&mode);

            }
            query_remove(QUERY_PARAM_ACTION);
            query_remove("actionids");
            hashtable_destroy(changed_source_id_hash,1,free);

        } else if (allow_mark() && STRCMP(action,FORM_PARAM_SELECT_VALUE_MARK) == 0) {

                // The following actions are invoked when marking via PC browser and form.
                // In this case the post data has a select box variable for each item

                int total_changed = 0;
                
                changed_source_id_hash = get_newly_selected_ids_by_source(&total_changed);
                db_set_fields(DB_FLDID_WATCHED,"1",changed_source_id_hash,DELETE_MODE_NONE);
                hashtable_destroy(changed_source_id_hash,1,free);

                changed_source_id_hash = get_newly_deselected_ids_by_source(&total_changed);
                db_set_fields(DB_FLDID_WATCHED,"0",changed_source_id_hash,DELETE_MODE_NONE);
                hashtable_destroy(changed_source_id_hash,1,free);
                query_remove(QUERY_PARAM_ACTION);


        } else if (allow_delete() && STRCMP(action,FORM_PARAM_SELECT_VALUE_DELETE) == 0) {

TRACE;
                // The following actions are invoked when deleting via PC browser and form.
                // In this case the post data has a select box variable for each item
                changed_source_id_hash = get_newly_selected_ids_by_source(&total_deleted);
                db_set_fields(DB_FLDID_ACTION,NULL,changed_source_id_hash,DELETE_MODE_DELETE);
                if (total_deleted > 0) {
                    update_idlist(changed_source_id_hash);
                }
                hashtable_destroy(changed_source_id_hash,1,free);
                query_remove(QUERY_PARAM_ACTION);

        } else if (allow_delist() && STRCMP(action,"Remove_From_List") == 0) {

TRACE;
                // The following actions are invoked when delisting via PC browser and form.
                // In this case the post data has a select box variable for each item
                changed_source_id_hash = get_newly_selected_ids_by_source(&total_deleted);
                db_set_fields(DB_FLDID_ACTION,NULL,changed_source_id_hash,DELETE_MODE_REMOVE);
                if (total_deleted > 0) {
                    update_idlist(changed_source_id_hash);
                }
                hashtable_destroy(changed_source_id_hash,1,free);
                query_remove(QUERY_PARAM_ACTION);

        } else if (allow_locking() && STRCMP(action,FORM_PARAM_SELECT_VALUE_LOCK) == 0) {

                // The following actions are invoked when delisting via PC browser and form.
                // In this case the post data has a select box variable for each item
                changed_source_id_hash = get_newly_selected_ids_by_source(&total_deleted);
                do_action_by_id(changed_source_id_hash,lock_item_cb,NULL);
                db_set_fields(DB_FLDID_LOCKED,"1",changed_source_id_hash,DELETE_MODE_NONE);
                hashtable_destroy(changed_source_id_hash,1,free);

                changed_source_id_hash = get_newly_deselected_ids_by_source(&total_deleted);
                do_action_by_id(changed_source_id_hash,unlock_item_cb,NULL);
                db_set_fields(DB_FLDID_LOCKED,"0",changed_source_id_hash,DELETE_MODE_NONE);
                hashtable_destroy(changed_source_id_hash,1,free);

                query_remove(QUERY_PARAM_ACTION);

        } else if (allow_admin() && STRCMP(action,QUERY_PARAM_ACTION_VALUE_SET)==0 && util_starts_with(set_name,"ovs_poster_mode_")) {

            int min = atoi(query_val(QUERY_PARAM_SET_MIN));
            int max = atoi(query_val(QUERY_PARAM_SET_MAX));

            if (ovs_config_dimension_increment(set_name,set_val,min,max) == 0) {
                reload_configs();
            }
            query_remove(QUERY_PARAM_SET_MIN);
            query_remove(QUERY_PARAM_SET_MAX);
            query_remove(QUERY_PARAM_ACTION);
            query_remove(QUERY_PARAM_SET_NAME);
            query_remove(QUERY_PARAM_SET_VAL);

        } else if (allow_admin() && STRCMP(action,QUERY_RESIZE_DIM_ACTION)==0 ) {

            char *dimension_set=query_val(QUERY_RESIZE_DIM_SET_NAME); // image or grid ie reset image height/width or grid rows/cols
            if (view == VIEW_TVBOXSET) {

                if (STRCMP(dimension_set,QUERY_RESIZE_DIM_SET_GRID)==0) {
 
                    ovs_config_dimension_increment("ovs_poster_mode_rows_tvboxset","=-1",-1,-1);
                    ovs_config_dimension_increment("ovs_poster_mode_cols_tvboxset","=-1",-1,-1);
                    reload_configs();


                } else if (STRCMP(dimension_set,QUERY_RESIZE_DIM_SET_IMAGE)==0) {

                    ovs_config_dimension_increment("ovs_poster_mode_height_tvboxset","=-1",-1,-1);
                    ovs_config_dimension_increment("ovs_poster_mode_width_tvboxset","=-1",-1,-1);
                    reload_configs();

                } else {
                   html_error("unable to reset tvboxset dimensions");
                }
            } else if (view == VIEW_MOVIEBOXSET) {

                if (STRCMP(dimension_set,"grid")==0) {

                   ovs_config_dimension_default("ovs_poster_mode_rows_movieboxset");
                   ovs_config_dimension_default("ovs_poster_mode_cols_movieboxset");
                    reload_configs();

                } else if (STRCMP(dimension_set,"poster")==0) {

                    ovs_config_dimension_default("ovs_poster_mode_height_movieboxset");
                    ovs_config_dimension_default("ovs_poster_mode_width_movieboxset");
                    reload_configs();

                } else {
                   html_error("unable to reset movieboxset dimensions");
                }
            }
            query_remove(QUERY_PARAM_ACTION);

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
static char *idhash_to_idlist(struct hashtable *source_id_hash) {
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
//    if (out == NULL) {
//        out = STRDUP("");
//    }
    HTML_LOG(0,"hash to list = [%s]",out);
    return out;
}

void update_idlist(struct hashtable *source_id_hash_removed)
{

    HTML_LOG(0,"pre update idlist = [%s]",query_val(QUERY_PARAM_IDLIST));

    if (*query_val(QUERY_PARAM_IDLIST)) {

        struct hashtable *source_id_hash_current = string_string_hashtable("source_id_hash_current",16);
        idlist_to_idhash(source_id_hash_current,query_val(QUERY_PARAM_IDLIST));

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
        query_update(STRDUP(QUERY_PARAM_IDLIST),idhash_to_idlist(source_id_hash_current));
        hashtable_destroy(source_id_hash_current,1,free);

    }

    HTML_LOG(0,"post update idlist = [%s]",query_val(QUERY_PARAM_IDLIST));
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

        if (util_starts_with(name,CHECKBOX_PREFIX) && STRCMP(val,"on") != 0) {
            total++;
        }

    }
    HTML_LOG(1,"checked count [%d]",total);
    return total;
}


int count_unchecked() {

    int total=0;

    //First count the total number of ids passed in idlist
    char *p = query_val(QUERY_PARAM_IDLIST);
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

// Get all ids that were selected on the form. This method is valid via the PC view.
struct hashtable *get_newly_selected_ids_by_source(int *totalp)
{

    struct hashtable *h = string_string_hashtable("idhash",16);

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

    struct hashtable *h = string_string_hashtable("deselected_ids_by_source",16);
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

void do_action_by_id(struct hashtable *ids_by_source,void (*action)(DbItem *,void *),void *action_data)
{
    struct hashtable_itr *itr;
    char *source;
    char *idlist;

    for(itr=hashtable_loop_init(ids_by_source) ; hashtable_loop_more(itr,&source,&idlist) ; ) {

        int num_ids;
        int *ids = extract_ids(idlist,&num_ids);

        Db *db = db_init(NULL,source);

        DbItemSet *is = db_scan_titles(db,NULL,num_ids,ids,action,action_data,NULL,NULL);

        db_rowset_free(is);

        db_free(db);
        FREE(ids);
    }
}

// Lock the file on the file system if it is a local file
void lock_item_cb(DbItem *item,void *action_data)
{
    if (is_on_internal_hdd(item)) {
        HTML_LOG(0,"lock_item_cb[%d][%s]",item->id,item->file);
        if (is_file(item->file)) {
            permissions(0,0,0755,1,item->file);
        }
    }
}

// Un Lock the file on the file system if it is a local file
void unlock_item_cb(DbItem *item,void *action_data)
{
    if (is_on_internal_hdd(item)) {
        HTML_LOG(0,"unlock_item_cb[%d][%s]",item->id,item->file);
        // should call chattr +i but need to call via

        if (is_file(item->file)) {
            permissions(nmt_uid(),nmt_gid(),0755,1,item->file);
        }
    }
}

void lock_toggle_item_cb(DbItem *item,void *action_data)
{
    // Get the locking mode
    LockMode mode = *(LockMode *)action_data;

    // If lock mode not set then make it opposite of current items lock status
    if (mode == LOCK_STATUS_UNKNOWN) {
        if (is_locked(item)) {
            mode = LOCK_STATUS_UNLOCK;
        } else {
            mode = LOCK_STATUS_LOCK;
        }
        *(LockMode *)action_data = mode;
    }
    switch(mode) {
        case LOCK_STATUS_LOCK:
            lock_item_cb(item,NULL); break;
        case LOCK_STATUS_UNLOCK:
            unlock_item_cb(item,NULL); break;
        case LOCK_STATUS_UNKNOWN:
            assert(0);
    }
}


void get_locked_status_cb(DbItem *item,void *data)
{
    LockMode status = *(int *)data;
    if (status == LOCK_STATUS_UNKNOWN) {
        if (item->locked) {
            HTML_LOG(0,"Got locked status");
            status = LOCK_STATUS_LOCK;
        } else {
            HTML_LOG(0,"Got unlocked status");
            status = LOCK_STATUS_UNLOCK;
        }
        *(LockMode *)data = status;
    }
}

void get_marked_status_cb(DbItem *item,void *data)
{
    MarkedStatus status = *(int *)data;
    if (status == MARKED_STATUS_UNKNOWN) {
        if (item->watched) {
            HTML_LOG(0,"Got marked status");
            status = MARKED_STATUS_MARKED;
        } else {
            HTML_LOG(0,"Got unmarked status");
            status = MARKED_STATUS_UNMARKED;
        }
        *(MarkedStatus *)data = status;
    }
}


// vi:sw=4:et:ts=4
