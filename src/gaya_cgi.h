#ifndef __GAYA_CGI_H__
#define __GAYA_CGI_H__
#include "hashtable.h"
#include "array.h"
#include "stdarg.h"
#include "oversight.h"
#include "display.h"

// for gaya_cgi.c
void add_default_html_parameters(struct hashtable *query_hash);
struct hashtable *parse_query_string(char *q,struct hashtable *);
struct hashtable *read_post_data(char *post_filename);
char *url_decode(char *str);
char *url_encode(char *str);
char *url_encode_static(char *str,int *free_result);
int is_pc_browser();
int is_local_browser();

char *html_encode(char *s);

void html_comment(char *format,...);
void html_vacomment(char *format,va_list ap);

void html_error(char *format,...);
void html_log_level_set(int lvl);
int html_log_level_get();
void html_log(int level,char *format,...);
void html_hashtable_dump(int level,char *label,struct hashtable *h);
void html_set_output(FILE *fp);

#endif
