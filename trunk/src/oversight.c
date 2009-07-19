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

char *g_scanlines="0";
char *get_scanlines(struct hashtable *nmt_settings) {
    char *tv_mode = hashtable_search(nmt_settings,"video_output");
    int tv_mode_int = atoi(tv_mode);

    if (tv_mode_int == 6 || tv_mode_int == 10 || tv_mode_int == 13 ) {
        return "720";
    } else if (tv_mode_int <= 5 || ( tv_mode_int >= 7 && tv_mode_int <= 9 )  || ( tv_mode_int >= 30 && tv_mode_int <= 31 )) {
        return "0";
    } else {
        return "1080";
    }
}

int main(int argc,char **argv) {

    int result=0;

    printf("Content-Type: text/html\n\n");

    html_comment("Appdir= [%s]",appDir());

    //array_unittest();
    //util_unittest();
    //config_unittest();

    struct hashtable *query=parse_query_string(getenv("QUERY_STRING"),NULL);

    struct hashtable *post=read_post_data(getenv("TEMP_FILE"));

    merge_hashtables(query,post,0); // post is destroyed

    oversight_config =
        config_load_wth_defaults(appDir(),"oversight.cfg.example","oversight.cfg");

    catalog_config =
        config_load_wth_defaults(appDir(),"catalog.cfg.example","catalog.cfg");

    nmt_settings = config_load("/tmp/setting.txt");

    html_log_level_set(3);
    html_hashtable_dump(3,"ovs cfg",oversight_config);
    html_hashtable_dump(3,"catalog cfg",catalog_config);
    html_hashtable_dump(3,"settings",nmt_settings);

    html_comment("done config");


     g_scanlines = get_scanlines(nmt_settings);
     html_comment("scanlines=[%s]",g_scanlines);

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





