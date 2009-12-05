/* (c) 2009 Andrew Lord - GPL V3 */

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <assert.h>

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
#include "admin.h"
#include "permissions.h"

void exec_old_cgi(int argc,char **argv);

// Load all config files excep unpak.cfg - that is loaded on-demand by unpak_val()
void load_configs () {
    html_comment("load ovs config");
    g_oversight_config =
        config_load_wth_defaults(appDir(),"conf/.oversight.cfg.defaults","conf/oversight.cfg");

    html_comment("load catalog config");
    g_catalog_config =
        config_load_wth_defaults(appDir(),"conf/.catalog.cfg.defaults","conf/catalog.cfg");

    html_comment("load nmt settings");
    g_nmt_settings = config_load("/tmp/setting.txt");
    html_comment("end load nmt settings");

}


#define PLAYLIST "/tmp/playlist.htm"
void clear_playlist() {
    truncate(PLAYLIST,0);
}

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

//Code to play a file. Only Gaya will understand this.
void gaya_auto_load(char *url_encoded_file) {

    char *file = url_decode(url_encoded_file);
    char *name = util_basename(file);

    printf("Content-Type: text/html\n\n");
    printf("<html><body onloadset=playme bgcolor=black text=white link=white >\n");
    printf("<html><body >\n");

    printf("<br><a href=\"/oversight/oversight.cgi\">Oversight</a>\n");

    //char *back=get_self_link("","",name);
    //printf("<br>%s\n",back);
    //FREE(back);

    printf("<br><a href=\"/start.cgi\">Home</a>\n");

    printf("<hr><a href=\"file://%s\" %s onfocusload name=playme>Play %s</a>\n", // file://
            url_encoded_file,vod_attr(file),name);

    printf("</body></html>\n");

    FREE(file);
    FREE(name);
}

int main(int argc,char **argv) {
    int result=0;

    g_start_clock = time(NULL);
    assert(sizeof(long long) >= 8);


    char *q=getenv("QUERY_STRING");

    if (q == NULL || strchr(q,'=') == NULL ) {
        if (argc > 1 ) {


            if (util_starts_with(argv[1],REMOTE_VOD_PREFIX2)) {

                gaya_auto_load(argv[1]+strlen(REMOTE_VOD_PREFIX2));
                exit(0);

            } else {
                char *img = url_decode(argv[1]);
                char *dot = strrchr(img,'.');

                if (dot) {


                    if (strcmp(dot,".png") == 0 ) {

                        cat("image/png",img);

                    } else if ( strcmp(dot,".jpg") == 0 ) {

                        cat("image/jpeg",img);

                    } else if ( strcmp(dot,".gif") == 0) {

                        cat("image/gif",img);

                    }
                }
                FREE(img);
            }
        }
    }



    printf("Content-Type: text/html\n\n");

    html_log_level_set(2);

    load_configs();

    long log_level;
    if (config_check_long(g_oversight_config,"ovs_log_level",&log_level)) {
        html_log_level_set(log_level);
    }

    html_comment("Appdir= [%s]",appDir());

    //array_unittest();
    //util_unittest();
    //config_unittest();

    g_query = string_string_hashtable(16);

    html_comment("default query ... ");
    add_default_html_parameters(g_query);
    html_hashtable_dump(0,"prequery",g_query);

    html_comment("read query ... ");
    g_query=parse_query_string(getenv("QUERY_STRING"),g_query);
    html_hashtable_dump(0,"query",g_query);

    html_comment("read post ... ");

    struct hashtable *post=read_post_data(getenv("TEMP_FILE"));
    html_hashtable_dump(0,"post",g_query);
    
    html_comment("merge query and post data");
    merge_hashtables(g_query,post,1); // post is destroyed

    html_hashtable_dump(0,"query final",g_query);

    // Run the old cgi script for admin functions
    // This will be phased out as the admin functions are brought in.
    char *view=query_val("view");  



    config_read_dimensions();

    html_comment("Begin Actions");
    do_actions();
    html_comment("End Actions view=%s select=%s ==",query_val("view"),query_val("select"));
   
    // After actions get view again. This is in case we have just deleted the last item in 
    // a tv or moview view. Then we want to go back to the main view.
    view=query_val("view");  


    DbRowSet **rowsets;
    DbRowId **sorted_rows;

    int num_rows = get_sorted_rows_from_params(&rowsets,&sorted_rows);
    HTML_LOG(0,"Got %d rows",num_rows);
    dump_all_rows("sorted",num_rows,sorted_rows);

TRACE;

    char *skin_name=oversight_val("ovs_skin_name");

TRACE;
    if (strchr(skin_name,'/') || *skin_name == '.' || !*skin_name ) {

        html_error("Invalid skin name[%s]",skin_name);

    } else {
TRACE;
        playlist_open();
TRACE;
        if (strcmp(view,VIEW_MOVIE) == 0 ||
                strcmp(view,VIEW_TV) == 0 ||
                strcmp(view,VIEW_TVBOXSET) == 0 
                ) {

            dump_all_rows("pre",num_rows,sorted_rows);

            display_template(skin_name,view,num_rows,sorted_rows);

            if (strcmp(view,VIEW_MOVIE) == 0 || strcmp(view,VIEW_TV) == 0 ) {
                build_playlist(num_rows,sorted_rows);
            } 

            dump_all_rows("post",num_rows,sorted_rows);


        } else if (strcmp(view,"admin") == 0) {

            setPermissions();
            display_admin();

        } else {

            //create_file_to_url_symlink();

            // main menu
            display_template(skin_name,"menu",num_rows,sorted_rows);
            build_playlist(num_rows,sorted_rows);
        }
    }

TRACE;

    // When troubleshooting we should clean up properly as this may reveal
    // malloc errors. 
    // But otherwise just let the OS reclaim everything.
    HTML_LOG(0,"deleting...");
    delete_queue_delete();
    TRACE;
    if(1) {
        html_comment("cleanup");

    TRACE;
        FREE(sorted_rows);
    TRACE;
        db_free_rowsets_and_dbs(rowsets);
    TRACE;

        /*
        html_comment("dump shit");
        html_hashtable_dump(3,"ovs cfg",oversight_config);
        html_hashtable_dump(3,"catalog cfg",catalog_config);
        html_hashtable_dump(3,"settings",nmt_settings);
        */
        hashtable_destroy(g_oversight_config,1,1);
    TRACE;

        hashtable_destroy(g_catalog_config,1,1);
    TRACE;

        hashtable_destroy(g_nmt_settings,1,1);
    TRACE;

        hashtable_destroy(g_query,1,0);
    TRACE;

        /*
        hashtable database_list= open_databases(g_query);

        display_page(g_query,database_list);
        */
    }

    HTML_LOG(0,"end=%d",result);


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


char *get_mounted_path(char *source,char *path,int *freeit)
{

    char *new = NULL;
    assert(source);
    assert(path);

    *freeit=0;
    if (*source == '*' ) {
        new = path;
    } else if (strchr(source,'/')) {
        //source contains /
        new = path;
    } else if (!util_starts_with(path,"/share/")) {
        // not in the /share/ folder
        new = path;
    } else {
        // Source = xxx 
        // [pop-nfs][/share/Apps/oversight/... becomes
        // /opt/sybhttpd/localhost.drives/NETWORK_SHARE/pop-nfs/Apps/oversight/...
        ovs_asprintf(&new,NETWORK_SHARE "%s/%s",source, path+7);
        HTML_LOG(1,"mounted path[%s]",new);
        *freeit=1;
TRACE;
    }
    return new;
}



