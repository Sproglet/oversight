/* (c) 2009 Andrew Lord - GPL V3 */

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>

#define OVS_MAIN 1
#include "oversight.h"
#include "hashtable.h"
#include "util.h"
#include "gaya_cgi.h"
#include "config.h"
#include "db.h"
#include "dboverview.h"
#include "display.h"
#include "actions.h"

void exec_old_cgi(int argc,char **argv);
void load_configs () {
    html_comment("load ovs config");
    g_oversight_config =
        config_load_wth_defaults(appDir(),"oversight.cfg.example","oversight.cfg");

    html_comment("load catalog config");
    g_catalog_config =
        config_load_wth_defaults(appDir(),"catalog.cfg.example","catalog.cfg");

    html_comment("load nmt settings");
    g_nmt_settings = config_load("/tmp/setting.txt");

}

#define PLAYLIST "/tmp/playlist.htm"
void clear_playlist() {
    truncate(PLAYLIST,0);
}

void exec_old_cgi(int argc,char **argv);

void cat(char *content,char *file) {
    printf("Content-Type: %s\n\n",content);
    FILE *fp = fopen (file,"r");
#define CATBUFLEN 1000
    char catbuf[CATBUFLEN+1];
    size_t bytes;
    if (fp) {
        while((bytes=fread(catbuf,1,CATBUFLEN,fp)) > 0)  {
            fwrite(catbuf,1,bytes,stdout);
        }
        fclose(fp);
        exit(0);
    } else {
        fprintf(stderr,"Error %d opening [%s|%s]\n",errno,content,file);
        exit(1);
    }
}

int main(int argc,char **argv) {
    int result=0;

    char *q=getenv("QUERY_STRING");

    if (q == NULL || strchr(q,'=') == NULL ) {
        if (argc > 1 ) {
            char *dot = strrchr(argv[1],'.');

            if (dot) {
                if (strcmp(dot,".png") == 0 ) {

                    cat("image/png",argv[1]);

                } else if ( strcmp(dot,".jpg") == 0 ) {

                    cat("image/jpeg",argv[1]);

                } else if ( strcmp(dot,".gif") == 0) {

                    cat("image/gif",argv[1]);

                }
            }
        }
    }



    printf("Content-Type: text/html\n\n");
    html_log_level_set(2);

    html_comment("Appdir= [%s]",appDir());

    //array_unittest();
    //util_unittest();
    //config_unittest();

    html_comment("read query ... ");
    g_query=parse_query_string(getenv("QUERY_STRING"),NULL);

    html_comment("read post ... ");

    struct hashtable *post=read_post_data(getenv("TEMP_FILE"));
    
    html_comment("merge query and post data");
    merge_hashtables(g_query,post,0); // post is destroyed

    html_hashtable_dump(0,"query final",g_query);

    // Run the old cgi script for admin functions
    // This will be phased out as the admin functions are brought in.
    char *view=query_val("view");  

    /*
     * For functions that are not yet ported - run the old script.
     */
    if (strcmp(view,"admin") == 0) {        //TODO Delete when code finished
        exec_old_cgi(argc,argv);                    //TODO Delete when code finished
    }


    load_configs();

    config_read_dimensions();

    do_actions();



    DbRowSet **rowsets;
    DbRowId **sorted_rows;

    int num_rows = get_sorted_rows_from_params(&rowsets,&sorted_rows);


    if (strcmp(view,"tv") == 0) {

        display_template("default","tv",num_rows,sorted_rows);

    } else if (strcmp(view,"movie") == 0) {

        display_template("default","movie",num_rows,sorted_rows);

    } else {

        display_template("default","menu",num_rows,sorted_rows);
    }

    free_sorted_rows(rowsets,sorted_rows);

    /*
    html_comment("dump shit");
    html_hashtable_dump(3,"ovs cfg",oversight_config);
    html_hashtable_dump(3,"catalog cfg",catalog_config);
    html_hashtable_dump(3,"settings",nmt_settings);
    */
    hashtable_destroy(g_oversight_config,1,1);
    hashtable_destroy(g_catalog_config,1,1);
    hashtable_destroy(g_nmt_settings,1,1);
    hashtable_destroy(g_query,1,0);

    /*
    hashtable database_list= open_databases(g_query);

    display_page(g_query,database_list);
    */

    return result;
    
}

void exec_old_cgi(int argc,char **argv) {
    char *old_cgi;
    char **args = MALLOC((argc+1) * sizeof(char *));
    int i,j=0;

    for(i = 0 ; i < argc ; i++ ) {
        args[j++] = argv[i];
    }
    args[j]=NULL;

    ovs_asprintf(&old_cgi,"%s/%s",appDir(),"oversight_old.cgi");
    if (execv(old_cgi,args) != 0) {
        int e = errno;
        html_error("Failed to launch [%s] error %d",old_cgi,e);
        exit(e);
    }
}




