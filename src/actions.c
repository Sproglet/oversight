#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "util.h"
#include "oversight.h"
#include "gaya_cgi.h"
#include "display.h"
#include "hashtable_loop.h"

struct hashtable *get_newly_selected_ids_by_source();
struct hashtable *get_newly_deselected_ids_by_source();

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
    hashtable_remove(g_query,"select");
    if (strcmp(query_val("action"),"Cancel") ==0) {
        hashtable_remove(g_query,"action");
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
        hashtable_remove(g_query,a->array[i]);
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

void do_actions() {

    char *view=query_val("view");
    char *action=query_val("action");
    char *select=query_val("select");

    // If remote play then send to gaya
    char *file=query_val(REMOTE_VOD_PREFIX1);
    if (file && *file) {
        gaya_send_link(file); 
        hashtable_remove(g_query,REMOTE_VOD_PREFIX1);
    }



    if (strcmp(query_val("searchb"),"Hide") == 0) {

        hashtable_remove(g_query,QUERY_PARAM_SEARCH_MODE);
        hashtable_remove(g_query,"searchb");
    }

    if (allow_admin() && strcmp(view,"admin")==0 ) {

        //do_admin_actions();

    } else if (*select) {

        if (allow_mark() && strcmp(action,"Mark") == 0) {

            struct hashtable *source_id_hash = NULL;
            
            source_id_hash = get_newly_selected_ids_by_source();
            db_set_fields(DB_FLDID_WATCHED,"1",source_id_hash);
            hashtable_destroy(source_id_hash,1,1);

            source_id_hash = get_newly_deselected_ids_by_source();
            db_set_fields(DB_FLDID_WATCHED,"0",source_id_hash);
            hashtable_destroy(source_id_hash,1,1);


        } else if (allow_mark() && strcmp(action,"Delete") == 0) {

            struct hashtable *source_id_hash = NULL;
            
            source_id_hash = get_newly_selected_ids_by_source();
            db_set_fields(DB_FLDID_ACTION,"D",source_id_hash);
            hashtable_destroy(source_id_hash,1,1);

        } else if (allow_mark() && strcmp(action,"Remove_From_List") == 0) {

            struct hashtable *source_id_hash = NULL;
            
            source_id_hash = get_newly_selected_ids_by_source();
            db_set_fields(DB_FLDID_ID,NULL,source_id_hash);
            hashtable_destroy(source_id_hash,1,1);
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

                    hashtable_insert_log(h,STRDUP(source),STRDUP(idlist));
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


