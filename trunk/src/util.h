#ifndef __UTIL_H_ALORD__
#define __UTIL_H_ALORD__

#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdio.h>
#include <regex.h>

#include "array.h"
#include "hashtable.h"

int is_empty_dir(char *dname);
char *delimited_substring(char *buf,char *prefix,char *substr,char *suffix,int match_start,int match_end);
struct hashtable *string_string_hashtable(char *name,int size);
void merge_hashtables(struct hashtable *h1,struct hashtable *h2,int copy);
void hashtable_dump(char *label,struct hashtable *h);

char *join_str_fmt_free(char *fmt,char *s1,char *s2);
char *substring(char *s,int start_pos, int end_pos);

char *replace_all(char *s_in,char *pattern,char *replace,int reg_opts);
char *replace_all_str(char *s_in,...);
char *replace_url_params(char *s_in,...);
char *replace_str(char *s_in,char *match,char *replace);
char *translate_inplace(
        char *str, // input text
        char *a,  // ordered list to translate characters from
        char *b   // ordered list to translate characters to
        );

Array *regextract(char *s,char *pattern,int reg_opts);
char *regextract1(char *s,char *pattern,int submatch,int reg_opts);
void regextract_free(Array *submatches);
char *util_strreg(char *s,char *pattern,int reg_opts);

void util_unittest();
int chomp(char *line);

int exists(char *path);

int is_writeable(char *path);
int is_readable(char *path);
int is_executable(char *path);
int is_file(char *path);
int is_dir(char *path);

char *appDir();
char *tmpDir();

int nmt_mkdir(char *d);
char *nmt_subdir(char *root,char *name);

void nmt_chown(char *d);

int nmt_uid();
int nmt_gid();

void *MALLOC(unsigned long bytes);
void *CALLOC(size_t count,size_t bytes);
void *REALLOC(void *p,unsigned long bytes);
char *STRDUP(char *s);
char *util_tolower(char *s);

/*Berstein*/
//hash = ((hash << 5) + hash) + c; /* hash * 33 + c */
/*LUA*/
//hash ^= ((hash << 5) + (hash >> 2)) + c; 
#define HASH_ADD(h,c) h ^= ((h << 5) + (h >> 2)) + ((c) | 32) 

unsigned int stringhash(void *vptr);
char *util_hostname();
char *util_dirname(char *file);
char *util_basename(char *file);
char *util_basename_no_ext(char *file) ;
int util_starts_with(char *a,char *b);
int util_starts_with_ignore_case(char *a,char *b);
char *util_strcasestr(char *a,char *b);
void util_regcomp(regex_t *re,char *pattern,int flags);
int util_rename(char *old,char *new);
int util_system(char *cmd);

#define FREE(x) do { if (x) free(x) ; x = NULL ;  } while(0)

#define DB_CHECK do {\
    html_log(0," DBCHECK %s %d",__FILE__,__LINE__);\
    FILE *fp=fopen("/share/Apps/oversight/index.db","r");\
    fclose(fp);\
} while(0)
int util_rm(char *path);

#define HTML_LOG(level,format...) do {\
    if (level <= html_log_level ) {\
        html_log(level,format);\
    }\
}while(0);

#define TR HTML_LOG(0,"%s() %s:%d\n",__FUNCTION__,__FILE__,__LINE__)

#define TRACE1 do {\
    if (1) {\
        HTML_LOG(0,"@@TRACE@@ %s %s %d",__FUNCTION__,__FILE__,__LINE__);\
    }\
}while(0);

#define TRACE do {\
    if (0) {\
        HTML_LOG(0,"@@TRACE@@ %s %s %d",__FUNCTION__,__FILE__,__LINE__);\
    }\
}while(0);

#define PRINTSPAN(p,q) do { if (q>p) printf("%.*s",((q)-(p)),(p)); } while(0)
#define PRINTNSTR(n,p) do { if (n) printf("%.*s",(n),(p)); } while(0)
#define UNSET -2
#define UNSET_PTR ((void *)(-2))

/* reading a file using fgets will get out of sync if the line length is greater 
 * than the buffer. The following macros will log this.
 * fgets reads up to N-1 bytes and appends nul char so if a line is too long.
 * or only just fits. b[N] will be nul but b[N-1] will not be null.
 * So before fgets set b[N-1]=null - if it is not null after then we have hit
 * a long line. Not the line may actually just fit, but we still flag it as an 
 * error.
 */
#define PRE_CHECK_FGETS(b,sz) b[(sz)-2]='\0'
#define CHECK_FGETS(b,sz) assert(b[(sz)-2]=='\0')

int count_chr(char *str,char c);
int exists_in_dir(char *dir,char *name);
Array *util_hashtable_keys(struct hashtable *h,int take_ownership_of_keys);
char *util_day_static();
char *clean_js_string(char *in);

char *file_name(char *path);
int is_dvd(char *file);
int is_dvd_image(char *file);
int is_dvd_folder(char *file);
int file_age(char *path);

char *timestamp_static();
char *util_change_extension(char *file,char *new_ext);
int is_nmt200();
int is_nmt100();
struct hashtable *array_to_set(Array *args);
void set_free(struct hashtable *h);
int bchop(int id,int size,int *ids);
int index_STRCMP(char *a,char *b);
#endif
