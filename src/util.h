#ifndef __UTIL_H_ALORD__
#define __UTIL_H_ALORD__

#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdio.h>
#include <regex.h>

#include "array.h"
#include "hashtable.h"

char *delimited_substring(char *buf,char prefix,char *substr,char suffix,int match_start,int match_end);
struct hashtable *string_string_hashtable(int size);
void merge_hashtables(struct hashtable *h1,struct hashtable *h2,int copy);
void hashtable_dump(char *label,struct hashtable *h);

char *join_str_fmt_free(char *fmt,char *s1,char *s2);
char *substring(char *s,int start_pos, int end_pos);

char *replace_all(char *s_in,char *pattern,char *replace,int reg_opts);

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
void *REALLOC(void *p,unsigned long bytes);
char *STRDUP(char *s);
char *util_tolower(char *s);
unsigned int stringhash(void *vptr);
char *util_hostname();
char *util_dirname(char *file);
char *query_val(char *name);
void query_remove(char *name);
char *util_basename(char *file);
int util_starts_with(char *a,char *b);
void util_regcomp(regex_t *re,char *pattern,int flags);
int util_rename(char *old,char *new);

#define FREE(x) do { free(x) ; x = NULL ;  } while(0)

#define DB_CHECK do {\
    html_log(0," DBCHECK %s %d",__FILE__,__LINE__);\
    FILE *fp=fopen("/share/Apps/oversight/index.db","r");\
    fclose(fp);\
} while(0)
void util_rmdir(char *path,char *name);

#define TRACE html_log(0,"%s %s %d",__FUNCTION__,__FILE__,__LINE__)

int exists_file_in_dir(char *dir,char *name);
#endif
