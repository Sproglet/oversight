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
void show_page(char *folder,char * filter,int page);
void set_gaya_filter(char *filter);

void gaya_list(char *arg)
{

    //arg = http://localhost.drives:8883/HARD_DISK/Complete/?filter=3&page=3

    g_query = string_string_hashtable(16);

    // Get query string
    char *qpos = strchr(arg,'?');
    if (qpos != NULL ) {
        parse_query_string(qpos+1,g_query);
    } else {
        qpos = arg+ strlen(arg);
    }

    // Get Folder
    char *folder;
    char *folder_start = strstr(arg,PORT_STR);
    if (folder_start) {
        folder_start += strlen(PORT_STR);
    
        ovs_asprintf(&folder,"%.*s",qpos - folder_start, folder_start );
        set_gaya_folder(folder);
        FREE(folder);

        // get page
        int page=atol(query_val("page"));
        set_gaya_page(page);

        set_gaya_filter(query_val("filter"));
        show_page(get_gaya_folder(),get_gaya_filter(),get_gaya_page());

    }
}

static char *gaya_folder=NULL;

char *get_gaya_folder()
{
    return gaya_folder;
}

void set_gaya_folder(char *folder)
{
    gaya_folder = STRDUP(folder);
}


static int gaya_page = 1;

int get_gaya_page()
{
    return gaya_page;
}

void set_gaya_page(int page)
{
    gaya_page = page;
}

static char *gaya_filter=NULL;

char *get_gaya_filter()
{
    return gaya_filter;
}

void set_gaya_filter(char *filter)
{
    gaya_filter = STRDUP(filter);
}

static Array *gaya_files= NULL;

Array *gaya_get_files()
{   

    if (gaya_files == NULL ) {
        Array *gaya_files = array_new(free);

        chdir(get_gaya_folder());

        DIR *d = opendir(get_gaya_folder());
        if(d) {
            struct dirent *file;
            while( (file=readdir(d)) != NULL) {
                
                char *tmp;

                if (is_dir(file->d_name)) {
                    
                    ovs_asprintf(&tmp,"d%s",file->d_name);
                    array_add(gaya_files,tmp);

                } else if (is_file(file->d_name)) {

                    ovs_asprintf(&tmp,"-%s",file->d_name);
                    array_add(gaya_files,tmp);
                }
            }
            closedir(d);
        }
        array_sort(gaya_files,NULL);
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
