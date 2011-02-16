#include "utf8.h"
#include "gaya_cgi.h"
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

