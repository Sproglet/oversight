#ifndef UTIL_H_ALORD
#define UTIL_H_ALORD

struct hashtable *string_string_hashtable();

char *join_str_fmt_free(char *fmt,char *s1,char *s2);
char *replace_all(char *s_in,char *pattern,char *replace);
char *substring(char *s,int start_pos, int end_pos);
char *regextract(char *s,char *pattern,int submatch);

void util_unittest();
#endif
