#ifndef GAYA_CGI_H
#define GAYA_CGI_H
#include "hashtable.h"

struct hashtable *parse_query_string(char *q,struct hashtable *);
char *url_decode(char *str);
char *url_encode(char *str);

#endif
