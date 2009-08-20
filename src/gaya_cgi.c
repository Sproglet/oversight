#include <ctype.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <assert.h>
#include <time.h>

#include "gaya_cgi.h"
#include "util.h"
#include "array.h"
#include "hashtable_loop.h"
#include "vasprintf.h"

/*
* Parse the query string into a hashtable
* if hashtable is NULL a new one is created.
*/
struct hashtable *parse_query_string(char *q,struct hashtable *hashtable_in) {

    int i;
    Array *qarr = split(q,"&",0);

    if (hashtable_in == NULL) {
        hashtable_in = string_string_hashtable(16);
    }

    for(i = 0 ; i < qarr->size ; i++ ) {

        char *eq = strchr(qarr->array[i],'=');
        if (eq) {
            *eq = '\0';

            char *name=url_decode(qarr->array[i]);
            char *val=url_decode(eq+1);
            //printf("query [%s]=[%s]\n",name,val);

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

    struct hashtable *result = string_string_hashtable(16);

    if (post_filename == NULL) {
        html_log(2,"no post data");
        return result;
    }

    char *boundary = getenv("POST_BOUNDARY");
    char *method = getenv("HTTP_METHOD");
    char *post_type= getenv("POST_TYPE");

    html_log(1,"HTTP_METHOD=[%s]",method);
    html_log(1,"POST_TYPE=[%s]",post_type);
    html_log(1,"POST_BOUNDARY=[%s]",boundary);

    int url_encoded_in_post_data = 
        (method != NULL && strcmp(method,"POST") == 0 &&
         post_type != NULL && strcmp(post_type,"application/x-www-form-urlencoded") == 0);

    int cr_lf = 1;
    int unix_mode = 0;

    int in_header = 0;

    int format=cr_lf;

    //Used for file content
    char *upload_dir = getenv("UPLOAD_DIR");
    if (upload_dir == NULL) {
        upload_dir = "/tmp";
    }

    FILE *fileptr = NULL;

    char *name = NULL;
    char *value = NULL;


    html_log(3,"opening post file [%s]",post_filename);

    FILE *pfp = fopen(post_filename,"r");

    if (pfp == NULL) {
        html_error("Unable to open post data [%s]\n",post_filename);
        exit(1);
    }

    char post_line[POST_BUF];

    while(fgets(post_line,POST_BUF,pfp) != NULL ) {

//if ((p=strrchr(post_line,'\n')) != NULL) {
//*p='\0';
//}


        if (url_encoded_in_post_data) {

            // This is a one off rule that indicates the post file is just a single line
            // containing a query string
            html_log(1,"post line url: %s",post_line);

            char *q = replace_all(post_line,"[^:]:","",0); //why?
            parse_query_string(q,result);
            free(q);

        } else if (strstr(post_line,boundary) ) {

            html_log(1,"post line bdry: %s",post_line);
            if (fileptr != NULL ) {
                // Process item defined before boundary
                fclose(fileptr);
                // TODO may need to change ownership of files here.

            } else if (name != NULL && value != NULL ) {
                //New variable

                char *found;

                html_log(2,"post: name [%s] about to add val [%s] ...",name,value);

                if ((found=hashtable_remove(result,name)) != NULL) {

                    html_log(2,"post: name [%s] existing val [%s] new val [%s]",name,found,value);
                    char *tmp;
                    ovs_asprintf(&tmp,"%s\r%s",found,value);
                    hashtable_insert(result,name,tmp);
                    free(found);
                    free(value);

                } else {

                    html_log(2,"post: name [%s] new val [%s]..",name,value);
                    //Add the new value
                    hashtable_insert(result,name,value);
                }
            }
            name = value = NULL;
            fileptr=NULL;
            in_header = 1;

        } else if (in_header ) {
           
            html_log(1,"post line head: %s",post_line);
           if (strstr(post_line,"Content-Disposition: form-data; name=") == post_line) {

                name=regextract1(post_line,"name=\"([^\"]+)\"",1,0);
                html_log(2,"post: extracted name [%s]",name);
                value=NULL;
                format=cr_lf;

                if (strstr(post_line,"filename=\"")) {
                    //
                    //Start writing to a file
                    //
                    char *filename=regextract1(post_line,"filename=\"([^\"]+)\"",1,0);

                    if (filename != NULL) {
                        char *filepath = strdup(upload_dir);
                        char *tmp;


                        ovs_asprintf(&tmp,"%s/%s",filepath,filename);
                        FREE(filepath);
                        FREE(filename);

                        fileptr = fopen(tmp,"w");
                        FREE(tmp);
                    }
                }

            } else if (strstr(post_line,"Content-Type: application=") == post_line) {

                format = unix_mode;

            } else if (strchr("\r\n",post_line[0])) {

                // blank line - start reading data.
                in_header = 0;
                html_log(1,"Start data : inheader = %d",in_header);
                value = NULL;
            }

        } else {
            // not in_header - read data
            html_log(1,"post line data: %s",post_line);

            if (format == cr_lf) {
                //remove newline
                char *p = strrchr(post_line,'\r');
                if (p != NULL) *p = '\0';
            }

            if (fileptr != NULL) {
                fprintf(fileptr,"%s\n",post_line);
            } else if (value == NULL) {
                value=STRDUP(post_line);
            } else {
                char *tmp;
                ovs_asprintf(&tmp,"%s\n%s",value,post_line);
                free(value);
                value = tmp;
            }
        }
    }
    fclose(pfp);
    html_log(1,"post: end");

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
    assert(str);
  char *pstr = str, *buf = MALLOC(strlen(str) * 3 + 1), *pbuf = buf;
  while (*pstr) {
    if (isalnum(*pstr) || *pstr == '-' || *pstr == '_' || *pstr == '.' || *pstr == '~') 
      *pbuf++ = *pstr;
//    else if (*pstr == ' ') 
//      *pbuf++ = '+';
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
    assert(str);
  char *pstr = str, *buf = MALLOC(strlen(str) + 1), *pbuf = buf;
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

int is_local_browser() {
    char *addr;
    if ((addr=getenv("REMOTE_ADDR")) != NULL) {
        return (strcmp(addr,"127.0.0.1") == 0);
    } else {
        return 0;
    }
}

int is_pc_browser() {
    char *addr;
    if ((addr=getenv("REMOTE_ADDR")) != NULL) {
        return (strcmp(addr,"127.0.0.1") != 0);
    } else {
        return 0;
    }
}

char *html_encode(char *s) {
    assert(s);
    char *p,*q,*result;

    int size=0;

    for (p = s ; *p ; p++) {
        if (*p == '<' || *p == '>'  || *p == '&' ) {
            size += 5;
        } else if (*p <  0) { // changed to char * so from >127 to <0
            size += 7;
        } else {
            size ++;
        }
    }
    result = q = MALLOC(size+1);
    assert(q);
    for (p = s ; *p ; p++) {

        if (*p == '<' ) {
           strcpy(q,"&lt;"); q+= 4;
        } else if (*p == '>' ) {
           sprintf(q,"&gt;"); q+= 4;
        } else if (*p == '&' ) {
           sprintf(q,"&amp;"); q+= 5;
        } else if (*p < 0 ) { // changed to char * so from >127 to <0
            // -128 -> 128 -1 -> 255
           sprintf(q,"&#x%x;",256+(int)*p);
           q+= strlen(q);
        } else {
            *q = *p; q++;
        }
    }
    *q = '\0';
    return result;
}

/*
void html_comment(char *s) {
    s = html_encode(s);
    printf("<!-- %s -->\n",s);
    free(s);
}
*/
void html_comment(char *format,...) {
    va_list ap;

    assert((long)format > 10);
    va_start(ap,format);
    html_vacomment(format,ap);
    va_end(ap);
}

void html_vacomment(char *format,va_list ap) {
    int len;
    char *s1;

    if ((len=ovs_vasprintf(&s1,format,ap)) >= 0) {
        // char *s2;
        //s2=html_encode(s1);
        printf("<!-- %ld %s -->\n",clock()>>10,s1);
        fflush(stdout);
        //free(s2);
        free(s1);
    }
}

static int html_log_level = 0;

void html_log_level_set(int level) {
    html_log_level = level;
}

int html_log_level_get() {
    return html_log_level;
}


void html_log(int level,char *format,...) {
    va_list ap;

    assert(level < 10);
    if (level <= html_log_level ) {
        va_start(ap,format);
        html_vacomment(format,ap);
        va_end(ap);
    }
}
void html_error(char *format,...) {
    va_list ap;
    va_start(ap,format);
    printf("<!-- ERROR -->");
    vprintf(format,ap);
    fflush(stdout);
    //html_vacomment(format,ap);
    va_end(ap);
}


void html_hashtable_dump(int level,char *label,struct hashtable *h) {


    if (level <= html_log_level) {

        if (hashtable_count(h)) {

           char *k,*v;
           struct hashtable_itr *itr ;

           for(itr = hashtable_loop_init(h); hashtable_loop_more(itr,&k,&v) ; ) {

                html_comment("%s : [ %s ] = [ %s ]",label,k,v);
            }

        } else {
            html_comment("%s : EMPTY HASH",label);
        }
    }
}
