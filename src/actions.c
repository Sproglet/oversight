#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "util.h"
#include "oversight.h"

void do_actions() {

    if (strcmp(query_val("searchb"),"Hide") == 0) {

        hashtable_remove(g_query,QUERY_PARAM_SEARCH_MODE);
        hashtable_remove(g_query,"searchb");
    }
    html_hashtable_dump(0,"post action query",g_query);
}
