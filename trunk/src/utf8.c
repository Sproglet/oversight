#include "utf8.h"
// Simple utf functions. If oversight requres more complete utf8 support look at a proper utf8 library eg utf8proc

int utf8len(char *str)
{
    int len = 0;
    char *p = str;
    while(1) {
        if (*p > 0) {
            len++;
        } else if (*p) {
            if (*p & 0x40 ) {
                len ++;
            }
        } else {
            break;
        }
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
    if (IS_UTF8START(*str1 & *str2)) {
        diff = *str1++ - *str2++;
        while(!diff && IS_UTF8CONT(*str1 & *str2)) {
            diff = *str1++ - *str2++;
        }
    } else {
        diff = *str1 - *str2;
    }
    return diff;
}

