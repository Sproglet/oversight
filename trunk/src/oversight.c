// $Id:$
/* (c) 2009 Andrew Lord - GPL V3 */

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <assert.h>
#include <dirent.h>
#include <libgen.h>

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
#include "template.h"
#include "exp.h"
#include "utf8.h"
#include "abet.h"
#include "yamj.h"


//void exec_old_cgi(int argc,char **argv);

void daemonize();

void clear_playlist() {
    truncate(NMT_PLAYLIST,0);
}

int ls(char *path) {
    int result = 0;
    printf("Content-Type: text/html; charset=utf-8\n\n<html><head><title>%s</title><style type=\"text/css\">"
            " .K { color:green; }"
            " .M { color:orange; }"
            " .G { color:red; }"
            " td.size { text-align:right; }"
            "</style></head><body>%s<br>",path,path);
    DIR *d = opendir(path);
    if (d) {
        Array *dirs = array_new(free);
        Array *files = array_new(free);
        struct dirent *f ;
        while((f = readdir(d)) != NULL) {
            
            char *p,*u;
            double size=0;
            char *unit="b";
            int precision=0;
            char *size_str=NULL;
            struct STAT64 st;

            ovs_asprintf(&p,"%s/%s",path,f->d_name);
            //printf("<br>checking %s\n",p);
            //u = file_to_url(p);

            ovs_asprintf(&u,"?%s",p);

            util_stat(p,&st);

            size = st.st_size;
            if (f->d_type == 0) {
                // more nmt100 oddness - dirent type not set?
                if (S_ISREG(st.st_mode)) f->d_type = DT_REG;
                else if (S_ISDIR(st.st_mode)) f->d_type = DT_DIR;
            }
            if (size > 1024 ) { size /= 1024 ; unit="<span class=\"K\">K</span>" ; precision=1; }
            if (size > 1024 ) { size /= 1024 ; unit="<font class=\"M\">M</span>" ; }
            if (size > 1024 ) { size /= 1024 ; unit="<span class=\"G\">G</span>" ; }

            char *display = f->d_name;
            if (strcmp(f->d_name,"..") == 0) {
                // find parent folder name
                char *tmp = STRDUP(path);
                ovs_asprintf(&u,"?%s",dirname(tmp));
                FREE(tmp);
                display="up↑";  ; // UP
            }

            if (strcmp(f->d_name,".") != 0) {
                char *tmp;
                switch(f->d_type) {
                    case DT_REG:
                        if(strstr(f->d_name,"log.gz")) {
                            // Display inline link
                            ovs_asprintf(&tmp,"<tr><td><a href=\"%s.txt\">%s</a> <a href=\"%s\">*</a></td><td class=\"size\"> - %.*f%s</td></tr>",
                                    u,display,u, precision,size,unit);
                        } else {
                            //ovs_asprintf(&tmp,"<tr><td>%.1f%s</td><td><a href=\"%s\">%s</a></td></tr>",size,unit,u,f->d_name);
                            ovs_asprintf(&tmp,"<tr><td><a href=\"%s\">%s</a></td><td class=\"size\"> - %.*f%s</td></tr>",
                                    u,display, precision,size,unit);
                        }
                        array_add(files,tmp);
                        break;
                    case DT_DIR:
                        ovs_asprintf(&tmp,"<a href=\"%s\">%s</a>&nbsp;&nbsp;&nbsp;&nbsp; ",u,display);
                        array_add(dirs,tmp);
                        break;
                    default:
                        ovs_asprintf(&tmp,"<tr><td><a href=\"%s\">%s</a></td><td>%d?</td></tr>",u,f->d_name,f->d_type);
                        array_add(files,tmp);
                        break;
                }
            }
            FREE(size_str);
            FREE(u);
            FREE(p);
        }

        closedir(d);

        char *out;
        array_sort(dirs,NULL);
        out = arraystr(dirs);
        if (out) {
            printf("%s",out);
        }
        FREE(out);

        printf("<hr><table border=\"0\">");
        array_sort(files,NULL);
        out = arraystr(files);
        if (out) {
            printf("%s",out);
        }
        FREE(out);
        printf("</table>");

        array_free(dirs);
        array_free(files);
    } else {
        fprintf(stderr,"Error %d opening [%s]\n",errno,path);
        result = errno;
    }
    printf("</body></html>");
    return result;
}


int cat(char *headers,char *file)
{
    if (headers) {
        printf("%s\n\n",headers);
    }
    FILE *fp = fopen (file,"r");
    if (fp) {
        append_content(fp,stdout);
        fflush(stdout);
        fclose(fp);
        return 0;
    } else {
        fprintf(stderr,"Error %d opening [%s|%s]\n",errno,headers,file);
        return errno;
    }
}

//Code to play a file. Only Gaya will understand this.
void gaya_auto_load(char *url_encoded_file) {

    char *file = url_decode(url_encoded_file);
    char *name = util_basename(file);

    printf("Content-Type: text/html\n\n");
    printf("<html><body onloadset=playme bgcolor=black text=white link=white >\n");
    //printf("<html><body >\n");

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

static void start_page(char *callmode) {
    printf("<html>\n<head>\n<meta http-equiv=content-type content=\"text/html; charset=utf-8\">\n");
    printf("<!-- %s:%s -->\n",callmode,OVS_VERSION);
}

#define YAMJ_PREFIX "yamj/"
#define YAMJ_PREFIX2 "yamj="
int oversight_main(int argc,char **argv,int send_content_type_header)
{
    int result=0;
    int done=0;

    g_start_clock = time(NULL);
    assert(sizeof(long long) >= 8);

    init_view();
    adjust_path();

    char *q=getenv("QUERY_STRING");

    char *p;
    if (q && (p = delimited_substring(q,"&",REMOTE_VOD_PREFIX2,"=",1,0)) != NULL) {

        gaya_auto_load(p+strlen(REMOTE_VOD_PREFIX2)+1);
        done=1;

    } else if (util_starts_with(q,YAMJ_PREFIX2)) {

        yamj_xml(q+strlen(YAMJ_PREFIX2));
        done=1;

    } else if (q == NULL || strchr(q,'=') == NULL ) {

        if (argc > 1 ) {

            if ( argv[1] && *argv[1] && argv[2] == NULL && util_starts_with(argv[1],YAMJ_PREFIX) ) {
                char *req = url_decode(argv[1]);
                yamj_xml(req+strlen(YAMJ_PREFIX));
                FREE(req);
                done=1;

            } else if ( argv[1] && *argv[1] && argv[2] == NULL && strchr(argv[1],'=') == NULL) {
                // Single argument passed.
                //
                char *path = url_decode(argv[1]);
                char *dot = strrchr(path,'.');
                if (dot < path) dot = strchr(path,'\0');
                int result = 0;

                fprintf(stderr,"path=[%s]",path);

                // should really use file command or magic number to determine file type

                if (dot && STRCMP(dot,".png") == 0 ) {

                    result = cat(CONTENT_TYPE"image/png",path);

                } else if (dot &&  STRCMP(dot,".jpg") == 0 ) {

                    result = cat(CONTENT_TYPE"image/jpeg",path);

                } else if (dot &&  STRCMP(dot,".gif") == 0) {

                    result = cat(CONTENT_TYPE"image/gif",path);

                } else if (dot &&  (STRCMP(dot,".swf") == 0 || STRCMP(dot,".phf" ) == 0) ) {

                    result = cat(CONTENT_TYPE"application/x-shockwave-flash",path);

                } else if (browsing_from_lan() ) {

                    if (is_dir(path)) {

                        // load_configs(); // load configs so we can use file_to_url() functions 
                        result = ls(path);
                    } else {
                        int exists = is_file(path);

                        char *all_headers = NULL;
                        char *content_headers = NULL;

                        if (exists) {
                            if (strstr(path,".tar.gz") || strcmp(dot,".tgz") == 0) {

                                ovs_asprintf(&content_headers,"%s%s\n%s%s",
                                        CONTENT_TYPE,"application/x-tar",CONTENT_ENC,"gzip");

                            } else if (strcmp(dot,".gz") == 0 ) {

                                ovs_asprintf(&content_headers,"%s%s\n%s%s",
                                        CONTENT_TYPE,"application/x-gzip",CONTENT_ENC,"identity");

                            } else if (strcmp(dot,".html") == 0 ) {

                                ovs_asprintf(&content_headers,"%s%s",
                                        CONTENT_TYPE,"text/html;charset=utf-8");

                            } else {
                                ovs_asprintf(&content_headers,"%s%s",
                                        CONTENT_TYPE,"text/plain;charset=utf-8");
                            }
                        } else {
                            // .gz.txt is a fake extension added by the ls command to view log.gz inline without browser downloading.
                            if (strstr(path,".gz.txt")) {
                                ovs_asprintf(&content_headers,"%s%s\n%s%s",
                                        CONTENT_TYPE,"text/plain;charset=utf-8", CONTENT_ENC,"gzip");
                                // remove .txt to get real zip file.
                                // .txt is needed so a certain browser displays inline. (might be other ways)
                                *dot = '\0';
                            } else {
                                // 404 error would be here
                            }
                        }
                        ovs_asprintf(&all_headers,"%s\n%s%ld",content_headers,CONTENT_LENGTH,file_size(path));
                        FREE(content_headers);
                        result = cat(all_headers,path);
                        FREE(all_headers);

                    }
                }
                FREE(path);
                fflush(stdout);
                done=1;
            }
        }
    }



    if (!done) {
        if (send_content_type_header) {
            printf("Content-Type: text/html; charset=utf-8\n\n");

            start_page("CGI");
        } else {
            start_page("WGET");
        }

        html_log_level_set(2);

        load_configs();
        //html_hashtable_dump(0,"settings",g_nmt_settings);

        long log_level;
        if (config_check_long(g_oversight_config,"ovs_log_level",&log_level)) {
            html_log_level_set(log_level);
        }

        html_comment("Appdir= [%s]",appDir());

        //array_unittest();
        //util_unittest();
        //config_unittest();

        g_query = string_string_hashtable("g_query2",16);

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


#if 0
        html_comment("utf8len expect 2 = %d",utf8len("Àa"));
        html_comment("utf8len expect 2 = %d",utf8len("àa"));
        html_comment("utf8len expect 2 = %d",utf8len("üa"));
        html_comment("utf8cmp_char 0 = %d",utf8cmp_char("üa","üb"));
        html_comment("utf8cmp_char !0 = %d",utf8cmp_char("üa","üa"));
        html_comment("utf8cmp_char 0 = %d",utf8cmp_char("a","a"));
        html_comment("utf8cmp_char !0 = %d",utf8cmp_char("a","b"));
        html_comment("utf8cmp_char !0 = %d",utf8cmp_char("üa","Ã¼a"));
        html_comment("utf8cmp_char !0 = %d",utf8cmp_char("a","üa"));
        Abet *a = abet_create("abcdefghijklmnopqrstuvwxyz");
        html_comment("inc a %d",abet_letter_inc_or_add(a,"a",1));
        html_comment("inc a %d",abet_letter_inc_or_add(a,"a",1));
        html_comment("inc z %d",abet_letter_inc_or_add(a,"z",1));
        html_comment("inc 4 %d",abet_letter_inc_or_add(a,"4",1));
        html_comment("inc 5 %d",abet_letter_inc_or_add(a,"5",1));
        html_comment("inc 5 %d",abet_letter_inc_or_add(a,"5",1));
        html_comment("inc 6* %d",abet_letter_inc_or_add(a,"6",0));
        html_comment("inc 7* %d",abet_letter_inc_or_add(a,"7",0));
        html_comment("inc a %d",abet_letter_inc_or_add(a,"a",1));
        abet_free(a);
#endif


        config_read_dimensions(1);

        HTML_LOG(0,"Begin Actions");
        do_actions();
       
        ViewMode *view;

        DbSortedRows *sortedRows = NULL;


        while(1) {
            view=get_view_mode(1);  
            HTML_LOG(0,"view mode = [%s]",view->name);

            // If movie view but all ids have been removed , then move up
            if (view == VIEW_MOVIE && !*query_val(QUERY_PARAM_IDLIST)) {
                query_pop();
                view=get_view_mode(1);  
            }

            sortedRows = get_sorted_rows_from_params();
            dump_all_rows("sorted",sortedRows->num_rows,sortedRows->rows);

            // Found some data - continue to render page.
            if (sortedRows->num_rows) {
                break;
            }

            // If it's not a tv/movie detail or boxset view then break
            if (view == VIEW_MENU ||  view == VIEW_ADMIN ) {
                break;
            }

            // No data found in this view - try to return to the previous view.
            query_pop();
            // Adjust config - 
            // TODO Change the config structure to reload more efficiently.
            //reload_configs();

            config_read_dimensions(1);

            // Now refetch all data again with new parameters.
            sorted_rows_free_all(sortedRows);
            HTML_LOG(0,"reparsing database");
        }

        // Remove and store the last navigation cell. eg if user clicked on cell 12 this is passed in 
        // the URL as @i=12. The url that returns to this page then has i=12. If we have returned to this
        // page we must remove i=12 from the query so that it is not passed to the new urls created for this 
        // page.
        set_selected_item();

        char *skin_name=oversight_val("ovs_skin_name");

        if (strchr(skin_name,'/') || *skin_name == '.' || !*skin_name ) {

            html_error("Invalid skin name[%s]",skin_name);

        } else {

            playlist_open();
            //exp_test();

            if (view->view_class == VIEW_CLASS_ADMIN) {

                setPermissions();
                display_admin(sortedRows);

            } else {

                display_main_template(skin_name,view->name,sortedRows);
                if (view->has_playlist) {
                    build_playlist(sortedRows);
                } 
            } 
        }


        // When troubleshooting we should clean up properly as this may reveal
        // malloc errors. 
        // But otherwise just let the OS reclaim everything.
        HTML_LOG(0,"deleting...");
        delete_queue_delete();
        TRACE;

#if 0
        // Cleanup properly
            html_comment("cleanup");

            sorted_rows_free_all(sortedRows);
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

            hashtable_destroy(g_query,1,0);
        TRACE;
            hashtable_destroy(g_nmt_settings,1,1);
        TRACE;


            /*
            hashtable database_list= open_databases(g_query);

            display_page(g_query,database_list);
            */
#endif

        HTML_LOG1(0,"end=%d",result);


        fflush(stdout);
    }
    return result;
    
}

#define ABORT_FILE_NAME "wget.wrapper.error"
// Create a file which should be deleted when oversight is deleted.
// if other supporting scripts detect this file thry know oversight
// is misbehaving, and should not install it inplace of wget.
// So a user should only have to reboot to stop any issues with 
// oversight messing with wget.
static char *abort_file_path;
void create_abort_file() {
    ovs_asprintf(&abort_file_path,"%s/conf/%s",appDir(),ABORT_FILE_NAME);
    FILE *fp = fopen(abort_file_path,"w");
    fclose(fp);
}

// Delete the abort file. see create_abort_file()
void delete_abort_file() {
    unlink(abort_file_path);
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

#ifdef OVS_ABORT_FILE
    create_abort_file();
#endif

    gaya_set_output(argc,argv);
    gaya_set_env(argc,argv);
    setenv("SCRIPT_NAME",SCRIPT_NAME,1);
       
    char *args[2] ;
    args[0]="oversight";
    args[1]=NULL;


    ret = oversight_main(1,args,0);

#ifdef OVS_ABORT_FILE
    delete_abort_file();
#endif

    return ret;

}

#define SLEEP_USECS 1000
 // from http://www.steve.org.uk/Reference/Unix/faq_2.html#SEC16
void daemonize()
{

#if 0
    int pid = fork();

    //  these exits() changed to _exit() as we have already forked from sybhttpd
    switch(pid) {

        case 0:
            break;
        case -1:
            fprintf(stderr,"Unable to fork - error %d",errno);
            _exit(-1);
            break;
        default:
            {
                //int status;
                //waitpid(pid,&status,0);
                _exit(0);
            }
    }

    // child 1 ---------------------------------------------
    
    // Give parent time to die.
    usleep(SLEEP_USECS);

    if (setpgrp() == -1) {
        fprintf(stderr,"Unable to setpgrp - error %d",errno);
    }
    if (setsid() == -1) {
        // fprintf(stderr,"Unable to setsid - error %d",errno);
    }

    pid = fork();
    switch(pid) {

        case 0:
            break;
        case -1:
            fprintf(stderr,"Unable to fork child - error %d",errno);
            _exit(-1);
            break;
        default:
            _exit(0);
    }

    // child 2 ---------------------------------------------

    // Give parent time to die.
    usleep(SLEEP_USECS);


    // chdir("/");
    umask(0);
#endif
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

        } else {

            run_wget(argc,argv);
            // Passthru to wget.real

        }
#if 0
    } else if ( argc > 1 && strcmp(argv[1],"-subtitle") == 0 ) {

        ret = subtitle_main(argc,argv);
#endif

    } else {

#if 0
        int i;
        FILE *fp = fopen("/share/Apps/oversight/logs/request.log","a");
        for(i = 0 ; i < argc ; i++ ) fprintf(fp,"[%s]",argv[i]);
        fprintf(fp,"\n");
        fclose(fp);
#endif
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
    }
    return new;
}


// vi:sw=4:et:ts=4
