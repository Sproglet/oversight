#ifndef __GAYA_CGI_H__
#define __GAYA_CGI_H__
#include "hashtable.h"

struct hashtable *parse_query_string(char *q,struct hashtable *);
struct hashtable *read_post_data(char *post_filename);
char *url_decode(char *str);
char *url_encode(char *str);

#endif
