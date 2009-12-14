// mini replacement for gaya
#include <sys/types.h>
#include <dirent.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include "util.h"
#include "gaya.h"
#include "hashtable.h"
#include "oversight.h"
#include "gaya_cgi.h"

#define PORT_STR ":8883"

#define GAYA_VIDEO_FILTER  '3'
#define GAYA_AUDIO_FILTER  '1'
#define GAYA_IMAGE_FILTER  '2'
#define GAYA_OTHER_FILTER  '4'

static int last_file(int page);
static int first_file(int page);

void show_page(char *folder,char * filter,int page);
void set_gaya_filter(char *filter);


int gaya_list(char *arg)
{

    //arg = http://localhost.drives:8883/HARD_DISK/Complete/?filter=3&page=3


    g_query = string_string_hashtable(16);

    // Get query string
    char *qpos = strchr(arg,'?');
    fprintf(stderr,"qpos = [%s]\n",qpos);
    if (qpos != NULL ) {
        fprintf(stderr,"begin parse\n");
        parse_query_string(qpos+1,g_query);
        fprintf(stderr,"end parse\n");
    } else {
        qpos = arg+ strlen(arg);
    }
TR;
    // Get Folder
    char *folder;
    char *folder_start = strstr(arg,PORT_STR);
    if (folder_start) {
TR;
        folder_start += strlen(PORT_STR);
    
TR;
        ovs_asprintf(&folder,"%.*s",qpos - folder_start, folder_start );
        set_gaya_folder(folder);
        FREE(folder);
TR;

        // get page
        if (*query_val("page")) {
            set_gaya_page(atol(query_val("page")));
        }
TR;

        set_gaya_filter(query_val("filter"));
TR;
        // Get the file list
        gaya_get_files();

        show_page(get_gaya_folder(),get_gaya_filter(),get_gaya_page());
TR;
        return 0;

    }
TR;
}

static char *gaya_folder=NULL;

char *get_gaya_short_folder()
{
    return gaya_folder;
}
char *get_gaya_folder()
{
    static char *f=NULL;
    if (f == NULL) {
        ovs_asprintf(&f,"/opt/sybhttpd/localhost.drives%s",get_gaya_short_folder());
    }
    return f;
}

void set_gaya_folder(char *folder)
{
    gaya_folder = STRDUP(folder);
    fprintf(stderr,"set_gaya_folder[%s]\n",gaya_folder);
}

static int gaya_page_size = 9;
void set_gaya_page_size(int s)
{
    gaya_page_size = s;
    fprintf(stderr,"set_gaya_page_size[%d]\n",gaya_page_size);
}

int get_gaya_page_size()
{
    return gaya_page_size;
}


static int gaya_page = 1;

int get_gaya_page()
{
    return gaya_page;
}

void set_gaya_page(int page)
{
    gaya_page = page;
    HTML_LOG(0,"set_gaya_page[%d]\n",gaya_page);
}

static char *gaya_filter=NULL;

char *get_gaya_filter()
{
    return gaya_filter;
}

void set_gaya_filter(char *filter)
{
    gaya_filter = STRDUP(filter);
    fprintf(stderr,"set_gaya_filter[%s]\n",gaya_filter);
}

static Array *gaya_files= NULL;

Array *gaya_get_files()
{   

    if (gaya_files == NULL ) {
        gaya_files = array_new(free);

        HTML_LOG(0,"reading [%s]",get_gaya_folder());
        if (chdir(get_gaya_folder())) {
            HTML_LOG(0,"Error : cant cd to [%s]",get_gaya_folder());

        } else {

            DIR *d = opendir(get_gaya_folder());
            if(d) {
                struct dirent *file;
                while( (file=readdir(d)) != NULL) {
                    
                    //HTML_LOG(0,"file [%s]",file->d_name);
                    char *tmp;

                    if (is_dir(file->d_name)) {
                        
                        if (file->d_name[0] != '.') {
                            //HTML_LOG(0,"add dir [%s]",file->d_name);
                            ovs_asprintf(&tmp,"d%s",file->d_name);
                            array_add(gaya_files,tmp);
                        }

                    } else if (is_visible(*gaya_filter,file->d_name)) {

                        //HTML_LOG(0,"add file [%s]",file->d_name);
                        ovs_asprintf(&tmp,"f%s",file->d_name);
                        array_add(gaya_files,tmp);
                    }
                }
                closedir(d);
            }
            array_sort(gaya_files,NULL);
        }
        array_dump(0,"files",gaya_files);
    }
    return gaya_files;
}

void show_page(char *folder,char *filter,int page)
{
    display_template("gaya","sd100",0,NULL);
}

char *gaya_image(char *image)
{

    char *res;
    if (g_dimension->scanlines == 0 ) {
        res="sd";
    } else {
        res="hd";
    }

    char *tmp;
    ovs_asprintf(&tmp,"file:///opt/sybhttpd/localhost.images/%s/%s",res,image);
    return tmp;
}

int gaya_file_total()
{
    int ret = 0;
    if (gaya_files ) {
        ret = gaya_files->size;
    }
    return ret;
}

static int last_file(int page)
{
    int ret = first_file(page) + (gaya_page_size - 1);
    if (ret > gaya_file_total() ) {
        ret = gaya_file_total();
    }
    return ret;
}

static int first_file(int page)
{
    return page * gaya_page_size - (gaya_page_size -1) ;
}


int gaya_first_file()
{
    return first_file(get_gaya_page());
}

int gaya_last_file()
{
    return last_file(get_gaya_page());
}
int gaya_prev_file()
{
    return last_file(gaya_prev_page());
}

int gaya_next_page()
{
    int ret = gaya_page +1;
    if ( (ret * gaya_page_size - (gaya_page_size-1) ) > gaya_file_total() ) {
        ret = 1;
    }
    return ret;
}
int gaya_prev_page()
{
    int ret = gaya_page -1;
    if (ret == 0 ) {
        ret = ( gaya_file_total() + (gaya_page_size-1) ) / gaya_page_size;
    }
    return ret;
}

char *gaya_filter_name(char filter_char)
{
    switch(filter_char) {
        case '1': return "music" ;;
        case '2': return "photo" ;;
        case '3': return "video" ;;
        case '4':
        default : return "other" ;;

    }
}

int is_video(char *name)
{
    int ret = 0;
    char  *dot = strrchr(name,'.');
    if (dot) {
        char *ext=util_tolower(dot+1);
        ret = delimited_substring("iso|avi|divx|mkv|mp4|ts|m2ts|xmv|mpe|movie|asf|vob|m2v|m2p|mpg|mpeg|mov|m4v|wmv","|",ext,"|",1,1) != NULL;
    }
    return ret;
}

int is_audio(char *name)
{
    int ret = 0;
    char  *dot = strrchr(name,'.');
    if (dot) {
        char *ext=util_tolower(dot+1);
        ret = delimited_substring("wav|m4a|mpga|mp2|mp3|pcm|ogg|wma|mp1|ac3|aac|mpa|pls|dts|flac","|",ext,"|",1,1) != NULL;
    }
    return ret;
}

int is_image(char *name)
{
    int ret = 0;
    char  *dot = strrchr(name,'.');
    if (dot) {
        char *ext=util_tolower(dot+1);
        ret = delimited_substring("gif|jpg|jpeg|jpe|png|bmp","|",ext,"|",1,1) != NULL;
    }
    return ret;
}

int is_other(char *name)
{
    return !(is_video(name) || is_audio(name) || is_image(name));
}

int is_visible(char filter,char *name)
{
    switch(filter) {
        case GAYA_VIDEO_FILTER: return is_video(name);
        case GAYA_AUDIO_FILTER: return is_audio(name);
        case GAYA_IMAGE_FILTER: return is_image(name);
        case GAYA_OTHER_FILTER: return is_other(name);
        default: return 0;
    }
}

char gaya_get_file_type(char *name) {
    if (is_video(name) ) return GAYA_VIDEO_FILTER;
    else if (is_audio(name) ) return GAYA_AUDIO_FILTER;
    else if (is_image(name) ) return GAYA_IMAGE_FILTER;
    else return GAYA_OTHER_FILTER;
}

char *gaya_get_file_image(char *name)
{
    char *iname;
    ovs_asprintf(&iname,"list_%s.png",gaya_filter_name(gaya_get_file_type(name)));

    char *tmp = gaya_image(iname);
    FREE(iname);
    return tmp;
}
//
// 0=not browsing >0 browsing (index of url argument)
int gaya_file_browsing(int argc,char **argv)
{
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
    fprintf(stderr,"gaya_file_browsing[%d]\n",ret);
    return ret;
}

// 0=no post data else = --post-data argument index 
int gaya_sent_post_data(int argc,char **argv)
{

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

#define SCRIPT_PATH ":8883/oversight/oversight.cgi"
// returns query string following oversight URL or NULL if nothing sent
char *gaya_sent_oversight_url(int argc,char **argv)
{
    int i;
    char *p=NULL;
    // can skip arg0 and use 0 as -ve result
    for(i = 1 ; i < argc ; i++ ) {
        if (argv[i][0] == 'h' && (p=strstr(argv[i],SCRIPT_PATH)) != NULL) {
            p = p+strlen(SCRIPT_PATH);
            break;
        }
    }
    fprintf(stderr,"gaya_sent_oversight_url=[%s]\n",p);
    return p;
}

// return http argument to wget 
char *gaya_url(int argc,char **argv)
{
    static char *result = NULL;
    int i;
    for (i = 1 ; i < argc ; i++) {
        if (argv[i][0] == 'h' && util_starts_with(argv[i],"http:") ) {
            result = argv[i];
            break;
        }
        
    }
    fprintf(stderr,"gaya_url:[%s]\n",result);
    return result;
}
// Changes stdout to be -O wget parameter.
// Returns index of output file argument or 0
int gaya_set_output(int argc,char **argv)
{
    int ret = 0;
    //Change stdout
    int i;
    for(i = 0 ; i < argc ; i++ ) {
        printf("gaya_set_output : arg %d[%s]\n",i,argv[i]);
        if (strcmp(argv[i],"-O") == 0 && i < argc-1) {
            ret = i+1;
            break;
        }
    }

    fprintf(stderr,"output= %d[%s]\n",ret,argv[ret]);

    if (ret > 0 && argv[ret] != NULL) {
        // Change stdout and launch oversight
        freopen(argv[ret],"w",stdout);
    }
    fprintf(stderr,"<!-- begin -->\n");
    return ret;
}

void gaya_set_env(int argc,char **argv)
{

    char *url = gaya_url(argc,argv);

    char *query;

    int i;
    for (i = 0 ; i < argc ; i++ ) {
        printf("<!-- %d:[%s] -->\n",i,argv[i]);
    }

    // Get the arguments.
    query = strchr(url,'?');
    if ( query ) {
        setenv("QUERY_STRING",query+1,1);
    }
    setenv("REMOTE_ADDR","127.0.0.1",1);
}
