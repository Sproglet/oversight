#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include "dbnames.h"
#include "util.h"
#include "gaya.h"
#include "gaya_cgi.h"

// Scan a names file. Format 
// key:name
// eg
// nm0000001:Fred Astaire
//
// The file must be sorted.


#define DB_PERSON_NAME_SIZE 110
#define PREFIX_LEN 3 // allow a bit more space to read start of next record when required \nnm0
static char name[DB_PERSON_NAME_SIZE+PREFIX_LEN+1];
// IMDB has some gems such as nm2770034 "11th Naval District United States Coast Guard Band"
// The longest name at the moment is 83 characters.
// nm2863306
// King Friedrich August the Third of Saxony, Johann Ludwig Karl Gustav Gregor Philipp

static inline int full_record(char *name) {
    return name[0] == 'n' && name[1] == 'm' && isdigit(name[2]);
}

// nm0001:aaaaaa
// nm0005:aaaaaa
// nm0010:aaaaaa
//
// nm0001:aaaaaa
// nm0005:aaaaaaaaa
// 

// Seek back from 'start' for the start of the previous record.
static inline long seek_back(FILE *fp,long start) {

    long result=-1;
    long prev;

    // goto start - DB_PERSON_NAME_SIZE
    //HTML_LOG(0,"seek back from [%ld]",start);
    prev= start - DB_PERSON_NAME_SIZE;
    if (prev< 0) {
        prev= 0;
    }
    if (fseek(fp,prev,SEEK_SET) != 0) {
        HTML_LOG(0,"seek start [%ld] failed. errno = %d",start,errno);
    } else {
        long bytes;
        // Read previous record (and also a bit more in case 'start' was pointing
        // at m0001 and we just needed to go back 1 byte.
        if ((bytes=fread(name,1,start-prev+PREFIX_LEN,fp)) >= 0) {
            //HTML_LOG(0,"bytes[%ld][%.*s]",bytes,bytes,name);
            char *p;
            for( p = name+bytes-PREFIX_LEN ; p >= name ; p--) {
                if (full_record(p)) {
                    fseek(fp,prev+(p-name),SEEK_SET);
                    //HTML_LOG(0,"seeked back to [%ld]",prev+(p-name));
                    result = prev+(p-name);
                    break;
                }
            }
        } else {
            HTML_LOG(0,"Failed to read bytes [%ld]. errno = %d",bytes,errno);
        }
    }

    return result;
}

char *dbnames_fetch_chop_static(char *key,FILE *f,long start,long end)
{
    char *state;
    char *result = NULL;
    int keylen = strlen(key);
    long mid;
    while(1) {
        mid = ( start + end ) / 2;
        //HTML_LOG(0,"chop[%ld][%ld][%ld]",start,mid,end);
        if (fseek(f,mid,SEEK_SET) == 0) {

            if ((state=fgets(name,DB_PERSON_NAME_SIZE,f)) != NULL) {
                //HTML_LOG(0,"mid[%ld][%s]",mid,name);
                if (!full_record(name)) {
                    // We have jumped into the middle of a record.
                    mid = seek_back(f,mid);
                    if (mid < 0) {
                        // Cant find start of record?
                        break;
                    } 

                    state = fgets(name,DB_PERSON_NAME_SIZE,f);
                    //HTML_LOG(0,"new mid[%ld][%s]",mid,name);

                    if (state && !full_record(name)) {
                        // Cant find start of record?
                        // This shouldnt happen because seek back checks this also.
                        break;
                    }
                    //HTML_LOG(0,"back[%ld][%s]",mid,name);
                }
            }
            if (state) {
                int cmp = strncmp(key,name,keylen);
                if (cmp == 0) {
                    result = name;
                    break;
                } else if (cmp < 0) {
                    end = mid;
                } else {
                    start = ftell(f);
                }
                if (end == start ) break;
            } else {
                // Nothing more
                break;
            }
        }
    }
    return result;
}

char *dbnames_fetch_static(char *key,char *file)
{
    char *result = NULL;
    struct stat st;

    if (stat(file,&st) == 0) {
        FILE *f = fopen(file,"rba");
        if (f) {
            result = dbnames_fetch_chop_static(key,f,0,st.st_size);

            // Remove trailing \n \r
            char *p = result+strlen(result);
            if (result) {
                if ((p=strchr(result,'\n')) != NULL) {
                    *p = '\0';
                }
            }

            fclose(f);
        }
    }
    HTML_LOG(1,"dbnames_fetch_chop_static[%s]=[%s]",key,result);

    return result;
}
