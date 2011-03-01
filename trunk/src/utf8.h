#ifndef __UTF8_OVERSIGHT__
#define __UTF8_OVERSIGHT__

#include "hashtable.h"
#include "util.h"
#include "vasprintf.h"

// Simple utf functions. If oversight requres more complete utf8 support look at a proper utf8 library eg utf8proc

#define IS_UTF8START(c) ( ( (c) & 0xc0 ) == 0xc0 )
#define IS_UTF8CONT(c) ( ( (c) & 0xc0 ) == 0x80 )
#define IS_UTF8(c) ( ( (c) & 0x80 )  )

int utf8len(char *str);
int utf8cmp_char(char *str1,char *str2);
char *utf8norm(char *s,int len);

#endif
