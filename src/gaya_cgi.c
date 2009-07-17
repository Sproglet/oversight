#include <ctype.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include "gaya_cgi.h"
#include "util.h"
#include "array.h"

/*
* Parse the query string into a hashtable
* if hashtable is NULL a new one is created.
*/
struct hashtable *parse_query_string(char *q,struct hashtable *hashtable_in) {

    int i;
    array *qarr = split(q,"&");

    if (hashtable_in == NULL) {
        hashtable_in = string_string_hashtable();
    }

    for(i = 0 ; i < qarr->size ; i++ ) {

        char *eq = strchr(qarr->array[i],'=');
        if (eq) {
            *eq = '\0';

            char *name=url_decode(qarr->array[i]);
            char *val=url_decode(eq+1);
            printf("query [%s]=[%s]\n",name,val);

            if (hashtable_insert(hashtable_in,name,val) ==0) {
                fprintf(stderr," Error inserting [%s]=[%s]\n",name,val);
            }

            *eq = '=';
        }

    }

    array_free(qarr);

    return hashtable_in;
}

/*
 * Read the form post data
 */
#define POST_BUF 999
struct hashtable *read_post_data(char *post_filename) {

    struct hashtable *result = string_string_hashtable();

    if (post_filename == NULL) {
        return result;
    }

    char *boundary = getenv("POST_BOUNDARY");
    char *method = getenv("METHOD");
    char *post_type= getenv("POST_TYPE");

    int url_encoded_in_post_data = 
        (strcmp(method,"POST") == 0 && strcmp(post_type,"application/x-www-form-urlencoded") == 0);

    int cr_lf = 1;
    int unix_mode = 0;

    int in_data = -1;
    int start_data = -2;

    int format=cr_lf;

    //Used for file content
    char *upload_dir = getenv("UPLOAD_DIR");
    if (upload_dir == NULL) {
        upload_dir = "/tmp";
    }

    FILE *fileptr = NULL;

    char *name = NULL;
    char *value = NULL;

    // indicates which part of post data we are parsing
    int phase=0;

    FILE *pfp = fopen(post_filename,"r");

    if (pfp == NULL) {
        fprintf(stderr,"Unable to open post data [%s]\n",post_filename);
        exit(1);
    }

    char post_line[POST_BUF];

    while(fgets(post_line,POST_BUF,pfp) != NULL ) {
        if (phase >= 0) phase++;

//if ((p=strrchr(post_line,'\n')) != NULL) {
//*p='\0';
//}

        printf("<!-- %s -->",post_line);
        if (url_encoded_in_post_data) {
            char *q = replace_all(post_line,"[^:]:",""); //why?
            parse_query_string(q,result);
            free(q);
        } else if (strstr(post_line,boundary) ) {

            if (fileptr != NULL ) {
                // Process item defined before boundary
                fclose(fileptr);
                fileptr=NULL;
                // TODO may need to change ownership of files here.

            } else if (name != NULL && value != NULL ) {
                //New variable

                char *found;

                if ((found=hashtable_search(result,name)) != NULL) {

                    //Add the new value separated by \\r
                    hashtable_insert(result,name,join_str_fmt_free("%s\r%s",found,value));
                } else {

                    //Add the new value
                    hashtable_insert(result,name,value);
                }
                name = value = NULL;
            }
            phase = 0;

        } else if (phase > 0 && strstr(post_line,"Content-Disposition: form-data; name=") == post_line) {

            name=regextract1(post_line,"name=\"([^\"]+)\"",1);
            value=NULL;
            format=cr_lf;

            if (strstr(post_line,"filename=\"")) {
                //
                //Start writing to a file
                //
                char *filename=regextract1(post_line,"filename=\"([^\"]+)\"",1);

                if (filename != NULL) {
                    char *filepath = strdup(upload_dir);

                    filepath=join_str_fmt_free("%s/%s",filepath,filename);

                    fileptr = fopen(filepath,"w");
                    free(filepath);
                }
            }
        } else if (phase > 0 && strstr(post_line,"Content-Type: application=") == post_line) {

            format = unix_mode;

        } else if (phase > 0 && strcmp(post_line,"\r") ==0) {

            phase = start_data;

        } else if (phase < 0 ) { //start_date or in_data

            if (format == cr_lf) {
                //remove newline
                char *p = strrchr(post_line,'\r');
                if (p != NULL) *p = '\0';
            }

            if (fileptr != NULL) {
                fprintf(fileptr,"%s\n",post_line);
            } else if (phase == start_data) {
                value=strdup(post_line);
            } else {
                value=join_str_fmt_free("%s\n%s",value,strdup(post_line));
            }
            phase = in_data;
        }
    }
    fclose(pfp);

    return result;
}


/*==========================================================================
 * http://www.geekhideout.com/urlcode.shtml
 * ========================================================================*/
/* Converts a hex character to its integer value */
char from_hex(char ch) {
  return isdigit(ch) ? ch - '0' : tolower(ch) - 'a' + 10;
}

/*==========================================================================
 * http://www.geekhideout.com/urlcode.shtml
 * ========================================================================*/
/* Converts an integer value to its hex character*/
char to_hex(char code) {
  static char hex[] = "0123456789abcdef";
  return hex[code & 15];
}

/*==========================================================================
 * http://www.geekhideout.com/urlcode.shtml
 * ========================================================================*/
/* Returns a url-encoded version of str */
/* IMPORTANT: be sure to free() the returned string after use */
char *url_encode(char *str) {
  char *pstr = str, *buf = malloc(strlen(str) * 3 + 1), *pbuf = buf;
  while (*pstr) {
    if (isalnum(*pstr) || *pstr == '-' || *pstr == '_' || *pstr == '.' || *pstr == '~') 
      *pbuf++ = *pstr;
    else if (*pstr == ' ') 
      *pbuf++ = '+';
    else 
      *pbuf++ = '%', *pbuf++ = to_hex(*pstr >> 4), *pbuf++ = to_hex(*pstr & 15);
    pstr++;
  }
  *pbuf = '\0';
  return buf;
}

/*==========================================================================
 * http://www.geekhideout.com/urlcode.shtml
 * ========================================================================*/
/* Returns a url-decoded version of str */
/* IMPORTANT: be sure to free() the returned string after use */
char *url_decode(char *str) {
  char *pstr = str, *buf = malloc(strlen(str) + 1), *pbuf = buf;
  while (*pstr) {
    if (*pstr == '%') {
      if (pstr[1] && pstr[2]) {
        *pbuf++ = from_hex(pstr[1]) << 4 | from_hex(pstr[2]);
        pstr += 2;
      }
    } else if (*pstr == '+') { 
      *pbuf++ = ' ';
    } else {
      *pbuf++ = *pstr;
    }
    pstr++;
  }
  *pbuf = '\0';
  return buf;
}
