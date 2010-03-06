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
#include "gaya.h"
#include "subtitles.h"


//void exec_old_cgi(int argc,char **argv);

// Load all config files excep unpak.cfg - that is loaded on-demand by unpak_val()
void load_configs () {
    g_oversight_config =
        config_load_wth_defaults(appDir(),"conf/.oversight.cfg.defaults","conf/oversight.cfg");

    g_catalog_config =
        config_load_wth_defaults(appDir(),"conf/.catalog.cfg.defaults","conf/catalog.cfg");

    g_nmt_settings = config_load("/tmp/setting.txt");

}

void clear_playlist() {
    truncate(NMT_PLAYLIST,0);
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

void adjust_path()
{
    char *new_path;
    char *binDir;

    if (is_nmt100()) {
        binDir="nmt100";
    } else {
        binDir="nmt200";
    }

    ovs_asprintf(&new_path,"%s:%s/bin/%s",getenv("PATH"),appDir(),binDir);
    setenv("PATH",new_path,1);
}

int oversight_main(int argc,char **argv,int send_content_type_header) {
    int result=0;

    g_start_clock = time(NULL);
    assert(sizeof(long long) >= 8);

    adjust_path();

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


                    if (STRCMP(dot,".png") == 0 ) {

                        cat("image/png",img);

                    } else if ( STRCMP(dot,".jpg") == 0 ) {

                        cat("image/jpeg",img);

                    } else if ( STRCMP(dot,".gif") == 0) {

                        cat("image/gif",img);

                    }
                }
                FREE(img);
            }
        }
    }



    if (send_content_type_header) {
        printf("Content-Type: text/html\n\n");

        printf("<!-- CGI:%s -->\n",OVS_VERSION);
    } else {
        printf("<!-- WGET:%s -->\n",OVS_VERSION);
    }

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
    char *view=query_val(QUERY_PARAM_VIEW);  



    config_read_dimensions();

    HTML_LOG(0,"Begin Actions");
    do_actions();
   


    DbRowSet **rowsets;
    DbRowId **sorted_rows;

    int num_rows = get_sorted_rows_from_params(&rowsets,&sorted_rows);
    HTML_LOG(0,"Got %d rows",num_rows);
    dump_all_rows("sorted",num_rows,sorted_rows);

    if (num_rows == 0 && (util_starts_with(view,"tv") || util_starts_with(view,"movie"))) {
        // If in the tv  or movie view and all items have been deleted - go to the main view
        char *back = return_query_string();
        HTML_LOG(0,"Going back to main view using [%s]",back);
        html_hashtable_dump(0,"preback",g_query);
        parse_query_string(back,g_query);
        html_hashtable_dump(0,"postback",g_query);
        FREE(back);
        // Now refetch all data again with new parameters.
        FREE(sorted_rows);
        db_free_rowsets_and_dbs(rowsets);
        num_rows = get_sorted_rows_from_params(&rowsets,&sorted_rows);
        HTML_LOG(0,"refetched %d rows",num_rows);
        view=query_val(QUERY_PARAM_VIEW);  
    }

    // Remove and store the last navigation cell. eg if user clicked on cell 12 this is passed in 
    // the URL as @i=12. The url that returns to this page then has i=12. If we have returned to this
    // page we must remove i=12 from the query so that it is not passed to the new urls created for this 
    // page.
    set_selected_item();

TRACE;

    char *skin_name=oversight_val("ovs_skin_name");

TRACE;
    if (strchr(skin_name,'/') || *skin_name == '.' || !*skin_name ) {

        html_error("Invalid skin name[%s]",skin_name);

    } else {
TRACE;
        playlist_open();
TRACE;
        if (STRCMP(view,VIEW_MOVIE) == 0 ||
                STRCMP(view,VIEW_TV) == 0 ||
                STRCMP(view,VIEW_TVBOXSET) == 0 
                ) {

            dump_all_rows("pre",num_rows,sorted_rows);

            display_template(skin_name,view,num_rows,sorted_rows);

            if (STRCMP(view,VIEW_MOVIE) == 0 || STRCMP(view,VIEW_TV) == 0 ) {
                build_playlist(num_rows,sorted_rows);
            } 

            dump_all_rows("post",num_rows,sorted_rows);


        } else if (STRCMP(view,"admin") == 0) {

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


/*
 * If gaya has invoked oversight as wget then the parameter list looks like 
 *
 * -q -H --convert-links --header=Accept-Charset:iso-8859-1,utf-8;q=0.7,*;q=0.7
 * -U Syabas/50-17-090204-15-HDD-403-000/15-HDD Firefox/0.8.0+ (gaya1 TV Res720x576;   Browser Res624x496-32bits;   Res720x576;   mac_addr=00:06:dc:43:c9:53)
 *  -P /mnt/.cache/s
 *  --tries=3s
 *  --timeout=60s
 *  -ncs
 *  --keep-session-cookies
 *  --save-cookies /mnt/.cache/coos
 *  --load-cookies /mnt/.cache/coo
 *  -x
 *  -O /tmp/0
 *  http://127.0.0.1:8883/oversight/oversight.cgi?_et=1&view=tv&idlist=*(643%7C649%7C647%7C645)
 *
 * We just want the argument to oversight  and the output file.
 * eg.
 *     _et=1&view=tv&idlist=*(643%7C649%7C647%7C645)
 * and
 *    /tmp/0
 */
#define SCRIPT_NAMEX "http://127.0.0.1:8883/oversight/oversight.cgi"
#define SCRIPT_NAME "/oversight/oversight.cgi"
int oversight_instead_of_wget(int argc, char **argv) 
{
    int ret = -1;

    gaya_set_output(argc,argv);
    gaya_set_env(argc,argv);
    setenv("SCRIPT_NAME",SCRIPT_NAME,1);
       
    char *args[2] ;
    args[0]="oversight";
    args[1]=NULL;
    ret = oversight_main(1,args,0);
    return ret;

}


int run_wget(int argc,char **argv) {

   char **args = CALLOC(argc+1,sizeof(char *));

   int i;
   for(i = 0 ; i < argc ; i++) {
       args[i] = argv[i];
   }
   args[argc] = NULL;
   return execv("/bin/wget.real",args);
}

int main(int argc,char **argv)
{
    int ret = -1;

    char *turbo_flag;
    ovs_asprintf(&turbo_flag,"%s/conf/use.wget.wrapper",appDir());
 
    char *turbo_flag2;
    ovs_asprintf(&turbo_flag2,"%s/conf/replace.file.browser",appDir());
 

    if (strstr(argv[0],"wget") ) {

        if (argc == 2 && STRCMP(argv[1],"-oversight") == 0 ) {

            // Special case to allow scripts to test if wget is really oversight.
            // wget -oversight will throw an error with the real wget.
            fprintf(stderr,"Oversight version %s\n",OVS_VERSION);
            ret = 0 ;

        } else if (!is_file(turbo_flag)) {

            run_wget(argc,argv);

        } else if (gaya_sent_oversight_url(argc,argv) && !gaya_sent_post_data(argc,argv)) {
            // Oversight has been called as wget. 
            // The normal CGI call sequence from gaya is 
            // gaya -> wget -> sybhttpd -> cgi
            // By replacing oversight with wget we try to short circuit this.
            // gaya -> oversight
            ret = oversight_instead_of_wget(argc,argv);

#if 0
        } else if (is_file(turbo_flag2) && (gaya_file_browsing(argc,argv)) && !gaya_sent_post_data(argc,argv)) {

            // Gaya has invoked wget with argument eg.  http://localhost.drives:8883/HARD_DISK/?filter=3&page=1
            // Important bits are
            //          http://localhost.drives:8883/ 
            //          The folder /HARD_DISK/
            //          The directory browse "/?"
            g_nmt_settings = config_load("/tmp/setting.txt");
            config_read_dimensions();
            gaya_set_output(argc,argv);
            gaya_set_env(argc,argv);
            ret = gaya_list(gaya_url(argc,argv));
#endif

        } else {

            run_wget(argc,argv);
            // Passthru to wget.real

        }
    } else if ( argc > 1 && strcmp(argv[1],"-subtitle") == 0 ) {

        ret = subtitle_main(argc,argv);

    } else {
        // start oversight normally (original cgi entry point)
        ret = oversight_main(argc,argv,1);
    }
    return ret;
}

#if 0
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
#endif


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


