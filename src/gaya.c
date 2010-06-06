// $Id:$
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
#include "template.h"

#define PORT_STR ":8883"

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

// 0=no post data else = --post-data argument index 
int gaya_sent_post_data(int argc,char **argv)
{

    static int ret= -1;

    if (ret == -1) {
        // can skip arg0 and use 0 as -ve result
        int i;
        ret = 0;
        for(i = 0 ; i < argc ; i++ ) {
            if (STRCMP(argv[i],"--post-data") == 0) {
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
    //fprintf(stderr,"gaya_sent_oversight_url=[%s]\n",p);
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
        if (STRCMP(argv[i],"-O") == 0 && i < argc-1) {
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
// vi:sw=4:et:ts=4
