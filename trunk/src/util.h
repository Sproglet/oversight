#ifndef __UTIL_H_ALORD__
#define __UTIL_H_ALORD__
#include "array.h"

struct hashtable *string_string_hashtable();
void merge_hashtables(struct hashtable *h1,struct hashtable *h2,int copy);

char *join_str_fmt_free(char *fmt,char *s1,char *s2);
char *substring(char *s,int start_pos, int end_pos);

char *replace_all(char *s_in,char *pattern,char *replace);

array *regextract(char *s,char *pattern);
char *regextract1(char *s,char *pattern,int submatch);
void regextract_free(array *submatches);
int regpos(char *s,char *pattern);

void util_unittest();
void chomp(char *line);

int exists(char *path);

int is_writeable(char *path);
int is_readable(char *path);
int is_executable(char *path);
int is_file(char *path);
int is_dir(char *path);


#endif
