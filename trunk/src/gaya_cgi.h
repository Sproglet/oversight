#ifndef __GAYA_CGI_H__
#define __GAYA_CGI_H__
#include "hashtable.h"
#include "stdarg.h"

// for gaya_cgi.c
struct hashtable *parse_query_string(char *q,struct hashtable *);
struct hashtable *read_post_data(char *post_filename);
char *url_decode(char *str);
char *url_encode(char *str);
int is_pc_browser();
int is_local_browser();

char *html_encode(char *s);

void html_comment(char *format,...);
void html_vacomment(char *format,va_list ap);

void html_error(char *format,...);
void html_log_level_set(int lvl);
void html_log(int level,char *format,...);
void html_hashtable_dump(int level,char *label,struct hashtable *h);

#endif
