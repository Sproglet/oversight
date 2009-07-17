/* (c) 2009 Andrew Lord - GPL V3 */

#include <string.h>
#include <stdlib.h>
#include "hashtable.h"
#include "util.h"
#include "gaya_cgi.h"

int main(int argc,char **argv) {

    int result=0;

    //array_unittest();
    util_unittest();

    struct hashtable *query=parse_query_string(getenv("QUERY_STRING"),NULL);
/*

    struct hashtable *post=get_post_data();

    merge_hash(query,post);

    hashtable_destroy(post,1);

    doActions(query);

    hashtable database_list= open_databases(query);

    display_page(query,database_list);
*/
    hashtable_destroy(query,0);
    return result;
    
}

