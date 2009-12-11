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

//void exec_old_cgi(int argc,char **argv);

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

int oversight_main(int argc,char **argv,int send_content_type_header) {
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



    if (send_content_type_header) {
        printf("Content-Type: text/html\n\n");

        printf("<!-- CGI -->\n");
    } else {
        printf("<!-- WGET -->\n");
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

// Changes stdout to be -O wget parameter.
// Returns index of output file argument or 0
int gaya_set_output(int argc,char **argv)
{
    int ret = 0;
    char *output = NULL;
    //Change stdout
    int i;
    for(i = 0 ; i < argc ; i++ ) {
        if (strcmp(argv[i],"-O") == 0 && i < argc-1) {
            ret = i+1;
            break;
        }
    }

    fprintf(stderr,"output=[%s]\n",output);
    fprintf(stderr,"query string=[%s]\n",getenv("QUERY_STRING"));

    if (argv[ret] != NULL) {
        // Change stdout and launch oversight
        freopen(argv[ret],"w",stdout);
    }
    freopen("/tmp/0err","w",stderr);
    return ret;
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
#define SCRIPT_PATH ":8883/oversight/oversight.cgi"
#define SCRIPT_NAME "http://127.0.0.1:8883/oversight/oversight.cgi"
int oversight_instead_of_wget(char *script_path,int argc, char **argv) 
{
    int ret = -1;

    gaya_set_output(argc,argv);

    int i;
    for (i = 0 ; i < argc ; i++ ) {
        printf("<!-- %d:[%s] -->\n",i,argv[i]);
    }

    // Get the arguments.
    if (*script_path == '?' ) {
        setenv("QUERY_STRING",script_path+1,1);
    }
    setenv("SCRIPT_NAME",SCRIPT_NAME,1);
    setenv("REMOTE_ADDR","127.0.0.1",1);

    printf("<!-- QUERY_STRING:[%s] -->\n",getenv("QUERY_STRING"));

       
    char *args[2] ;
    args[0]="oversight";
    args[1]=NULL;
    ret = oversight_main(1,args,0);
    return ret;

}

// 0=not browsing >0 browsing (index of url argument)
int gaya_file_browsing(int argc,char **argv) {
    static int ret = -1;
    if (ret == -1 ) {
        ret = 0;
        int i;
        for(i = 1 ; i < argc ; i++ ) {
            if (argv[i][0] == 'h'
                    && util_starts_with(argv[i],"http://localhost.drives:8883/")
                    && strstr(argv[i],"Tv")
                    && strstr(argv[i],"/?") ) {
                ret= i;
                break;
            }
        }
    }
    return ret;
}

// 0=no post data else = --post-data argument index 
int gaya_sent_post_data(int argc,char **argv) {

    static int ret= -1;

    if (ret == -1) {
        // can skip arg0 and use 0 as -ve result
        int i;
        ret = 0;
        for(i = 0 ; i < argc ; i++ ) {
            if (strcmp(argv[i],"--post-data") == 0) {
                ret = i;
                break;
            }
        }
        fprintf(stderr,"gaya_sent_post_data=[%d]\n",ret);
    }
    return ret;
}

// returns query string following oversight URL or NULL if nothing sent
char *gaya_sent_oversight_url(int argc,char **argv) {
    int i;
    char *p=NULL;
    // can skip arg0 and use 0 as -ve result
    for(i = 1 ; i < argc ; i++ ) {
        if (argv[i][0] == 'h' && (p=strstr(argv[i],SCRIPT_PATH)) != NULL) {
            p = p+strlen(SCRIPT_PATH);
            break;
        }
    }
    fprintf(stderr,"gaya_sent_oversight_url=[%s]",p);
    return p;
}

// return http argument to wget 
char *gaya_url(int argc,char **argv) {
    static char *result = NULL;
    int i;
    for (i = 1 ; i < argc ; i++) {
        if (argv[i][0] == 'h' && util_starts_with(argv[i],"http:") ) {
            result = argv[i];
            break;
        }
        
    }
    return result;
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
 

    if (strstr(argv[0],"wget") ) {

        char *query_string = NULL;
        if (argc == 2 && strcmp(argv[1],"-oversight") == 0 ) {

            // Special case to allow scripts to test if wget is really oversight.
            // wget -oversight will throw an error with the real wget.
            fprintf(stderr,"Oversight version %s\n",OVS_VERSION);
            ret = 0 ;

        } else if (!is_file(turbo_flag)) {

            run_wget(argc,argv);

        } else if ((query_string=gaya_sent_oversight_url(argc,argv)) != NULL 
            && !gaya_sent_post_data(argc,argv)) {
            // Oversight has been called as wget. 
            // The normal CGI call sequence from gaya is 
            // gaya -> wget -> sybhttpd -> cgi
            // By replacing oversight with wget we try to short circuit this.
            // gaya -> oversight
            ret = oversight_instead_of_wget(query_string,argc,argv);

        } else if ((gaya_file_browsing(argc,argv)) && !gaya_sent_post_data(argc,argv)) {

            // Gaya has invoked wget with argument eg.  http://localhost.drives:8883/HARD_DISK/?filter=3&page=1
            // Important bits are
            //          http://localhost.drives:8883/ 
            //          The folder /HARD_DISK/
            //          The directory browse "/?"
            gaya_set_output(argc,argv);
            gaya_list(gaya_url(argc,argv));

        } else {

            run_wget(argc,argv);
            // Passthru to wget.real

        }
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



