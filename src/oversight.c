/* (c) 2009 Andrew Lord - GPL V3 */

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "hashtable.h"
#include "util.h"
#include "gaya_cgi.h"
#include "config.h"

struct hashtable *oversight_config = NULL;
struct hashtable *catalog_config = NULL;
struct hashtable *nmt_settings = NULL;

int main(int argc,char **argv) {

    int result=0;

    html_log_level_set(3);

    printf("Content-Type: text/html\n\n");

    html_comment("Appdir= [%s]",appDir());

    //array_unittest();
    //util_unittest();
    //config_unittest();

    struct hashtable *query=parse_query_string(getenv("QUERY_STRING"),NULL);

    struct hashtable *post=read_post_data(getenv("TEMP_FILE"));

    html_comment("merge query and post data");
    merge_hashtables(query,post,0); // post is destroyed

    html_comment("load ovs config");
    oversight_config =
        config_load_wth_defaults(appDir(),"oversight.cfg.example","oversight.cfg");

    html_comment("load catalog config");
    catalog_config =
        config_load_wth_defaults(appDir(),"catalog.cfg.example","catalog.cfg");

    html_comment("load nmt settings");
    nmt_settings = config_load("/tmp/setting.txt");

    Dimensions dimensions;
    html_comment("read dimensions");
    config_read_dimensions(oversight_config,nmt_settings,&dimensions);

    html_comment("dump shit");
    html_hashtable_dump(3,"ovs cfg",oversight_config);
    html_hashtable_dump(3,"catalog cfg",catalog_config);
    html_hashtable_dump(3,"settings",nmt_settings);

    html_comment("done config");



/*
    doActions(query);

    hashtable database_list= open_databases(query);

    display_page(query,database_list);
*/
    html_log(2,"Shutdown 2");
    html_log(0,"Shutdown 0");
    hashtable_destroy(oversight_config,1);
    hashtable_destroy(catalog_config,1);
    hashtable_destroy(query,0);
    return result;
    
}





