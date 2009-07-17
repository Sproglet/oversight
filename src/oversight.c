/* (c) 2009 Andrew Lord - GPL V3 */

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "hashtable.h"
#include "util.h"
#include "gaya_cgi.h"

int main(int argc,char **argv) {

    int result=0;

    printf("Content-Type: text/html\n\n");

    //array_unittest();
    util_unittest();
    config_unittest();

    struct hashtable *query=parse_query_string(getenv("QUERY_STRING"),NULL);

    struct hashtable *post=read_post_data(getenv("TEMP_FILE"));

    merge_hashtables(query,post,0); // post is destroyed

/*
    doActions(query);

    hashtable database_list= open_databases(query);

    display_page(query,database_list);
*/
    hashtable_destroy(query,0);
    return result;
    
}



