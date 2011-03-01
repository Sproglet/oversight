#include <ctype.h>

#include "utf8.h"
#include "gaya_cgi.h"
#include "utf8proc.h"
// Simple utf functions. If oversight requres more complete utf8 support look at a proper utf8 library eg utf8proc

int utf8len(char *str)
{
    int len = 0;
    unsigned char *p = (unsigned char *)str;
    while(*p) {
        if (*p < 128) {
            len++;
        } else if (*p & 0x40 ) {
                len ++;
        }
        html_comment("[%c] [%d] [%x] len=%d",*p,(int)(*p),(int)(*p),len);
        p++;
    }
    return len;
}

/*
 * Compare 2 utf8 characters 
 */
int utf8cmp_char(char *str1,char *str2)
{
    int diff;
    unsigned char *s1 = (unsigned char *)str1;
    unsigned char *s2 = (unsigned char *)str2;

    if (IS_UTF8START(*s1 & *s2)) {
        diff = *s1++ - *s2++;
        while(!diff && IS_UTF8CONT(*s1 & *s2)) {
            diff = *s1++ - *s2++;
        }
    } else {
        diff = *s1 - *s2;
    }
    return diff;
}

/*
 * Check if a byte sequence contains non-ascii characters.
 */
char is_utf8(char *s,int len)
{
    char *p = s;
    char *q = s+len;
    while(p < q && *p) {
        if (!isascii(*p++)) return 0;
    }
    return 1;
}
char *utf8norm(char *s,int len)
{
    char *out;
    if (is_utf8(s,len)) {
        int uerr = utf8proc_map((uint8_t *)s,len,(uint8_t**)&out,UTF8PROC_DECOMPOSE|UTF8PROC_COMPAT|UTF8PROC_STABLE|UTF8PROC_IGNORE|UTF8PROC_STRIPCC);
        if (uerr < 0) {
            HTML_LOG(0,"Error [%.*s] [%s]",len,s,utf8proc_errmsg(uerr));
        }
    } else {
        out = COPY_STRING(len,s);
    }
    return out;
}
