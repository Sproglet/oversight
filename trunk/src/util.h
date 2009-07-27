#ifndef __UTIL_H_ALORD__
#define __UTIL_H_ALORD__
#include "array.h"
#include "hashtable.h"

struct hashtable *string_string_hashtable();
void merge_hashtables(struct hashtable *h1,struct hashtable *h2,int copy);
void hashtable_dump(char *label,struct hashtable *h);

char *join_str_fmt_free(char *fmt,char *s1,char *s2);
char *substring(char *s,int start_pos, int end_pos);

char *replace_all(char *s_in,char *pattern,char *replace,int reg_opts);

Array *regextract(char *s,char *pattern,int reg_opts);
char *regextract1(char *s,char *pattern,int submatch,int reg_opts);
void regextract_free(Array *submatches);
int regpos(char *s,char *pattern,int reg_opts);

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

#endif
