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

int starts_with(char *a,char *b) {
    return strncmp(a,b,strlen(b))==0;
}

int is_checkbox(char *name,char *val) {
    if (val && strcmp(val,"on") ==0) {
        if (starts_with(name,CHECKBOX_PREFIX)) {
            return 1;
        } else if (starts_with(name,"orig_"CHECKBOX_PREFIX)) {
            return 1;
        } else if (starts_with(name,"option_")) {
            return 1;
        } else if (starts_with(name,"orig_option_") ) {
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
void do_actions() {

    if (strcmp(query_val("searchb"),"Hide") == 0) {

        hashtable_remove(g_query,QUERY_PARAM_SEARCH_MODE);
        hashtable_remove(g_query,"searchb");
    }
    html_hashtable_dump(0,"post action query",g_query);

    if (has_post_data()) {

        clear_selection();

    }
}


