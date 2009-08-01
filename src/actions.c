#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "util.h"
#include "oversight.h"
#include "gaya_cgi.h"
#include "display.h"
#include "hashtable_loop.h"


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
        hashtable_remove(g_query,k);
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
    html_hashtable_dump(0,"post action query",g_query);

    if (has_post_data()) {

        clear_selection();

    }
}


