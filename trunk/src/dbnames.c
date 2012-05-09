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


#define NAME_SEP "\t"
#define DB_PERSON_NAME_SIZE 110
static char name_record[DB_PERSON_NAME_SIZE+1];
// IMDB has some gems such as nm2770034 "11th Naval District United States Coast Guard Band"
// The longest name at the moment is 83 characters.
// nm2863306
// King Friedrich August the Third of Saxony, Johann Ludwig Karl Gustav Gregor Philipp

// records have format ovsid\tname

// Seek back from 'start' for the start of the previous record.
static inline long seek_back(FILE *fp,long start) {

    long result=-1;
    long prev;

    // goto start - DB_PERSON_NAME_SIZE
    // HTML_LOG(0,"seek back from [%ld]",start);
    prev= start - DB_PERSON_NAME_SIZE;
    if (prev< 0) {
        prev= 0;
    }
    if (fseek(fp,prev,SEEK_SET) != 0) {
        HTML_LOG(0,"seek start [%ld] failed. errno = %d",start,errno);
    } else {
        long bytes;
        // HTML_LOG(1,"seek back checking range [%ld-%ld]",prev,start);
        // Read all bytes from prev to start.
        if ((bytes=fread(name_record,1,start-prev,fp)) >= 0) {
            //HTML_LOG(0,"bytes[%ld][%.*s]",bytes,bytes,name_record);

            // Now scan backwards until we hit cr or linefeed
            int i;
            for( i = bytes-1 ; i ; i-- ) {
                if (name_record[i] == '\n' || name_record[i] == '\r' || name_record[i] == '\0' ) {
                    //HTML_LOG(0,"seek back to [%.10s]",name_record+i+1);
                    prev += i+1;
                    break;
                }
            }
            if (fseek(fp,prev,SEEK_SET) != 0) {
                HTML_LOG(0,"seek start [%ld] failed - step 2 . errno = %d",start,errno);
            } else {
                //HTML_LOG(0,"seek back to [%ld]",prev);

                result = prev;
            }
        } else {
            HTML_LOG(0,"Failed to read bytes [%ld]. errno = %d",bytes,errno);
        }
    }

    return result;
}

/**
 * returns record in name file that matches the name id.
 * This has format 
 * id tab name 
 * eg
 * 1\tJohn Doe
 */
char *dbnames_fetch_chop_static(char *key,FILE *f,long start,long end)
{
    int count = 0;
    char *result = NULL;

    char full_key[20];
   
    sprintf(full_key,"%s\t",key);

    int keylen = strlen(full_key);
    long mid;
    HTML_LOG(1,"Looking for key [%s]",key);
    while(1) {
        if (++count > 20) {
            HTML_LOG(0,"Error in chop??");
            break;
        }
        mid = ( start + end ) / 2;
        HTML_LOG(1,"chop[%ld][%ld][%ld]",start,mid,end);
        if (fseek(f,mid,SEEK_SET) == 0) {
            // align with start of record.
            mid = seek_back(f,mid);
            if (mid < 0) {
                // Cant find start of record?
                break;
            } 
            if (fgets(name_record,DB_PERSON_NAME_SIZE,f) != NULL) {
                int cmp = strncmp(full_key,name_record,keylen);
                if (cmp == 0) {
                    result = name_record;
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
    HTML_LOG(1,"found [%s] = [%s]",key,result);
    return result;
}

/**
 * returns record in name file that matches the name id.
 * This has format 
 * id tab name 
 * eg
 * 1\tJohn Doe
 */
char *dbnames_fetch_static(char *key,char *file)
{
    char *result = NULL;
    struct STAT64 st;

    if (util_stat(file,&st) == 0) {
        FILE *f = util_open(file,"rba");
        if (f) {
            result = dbnames_fetch_chop_static(key,f,0,st.st_size);

            chomp(result);

            fclose(f);
        }
    }
    HTML_LOG(1,"dbnames_fetch_chop_static[%s]=[%s]",key,result);

    return result;
}

/**
 * Return actor information
 * [0]=id
 * [1]=name
 * [2]=image url
 */
Array *dbnames_fetch(char *key,char *file) 
{
    Array *result = NULL;
    char *record = dbnames_fetch_static(key,file);
    if (record) {

        // Find character after key and use as seperator
        char *p = strstr(record,key);
        if (p) {
            result = splitstr(record,NAME_SEP);
            if (result->size != 2 && result->size != 3) {
                HTML_LOG(0,"Bad actor info [%s]",record);
                array_free(result);
                result = NULL;
            }
        }
    }
    return result;
}
