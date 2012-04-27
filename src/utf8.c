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

    diff = *s1 - *s2;
    if (!diff && IS_UTF8START(*s1 & *s2)) {
        diff = *s1++ - *s2++;
        while(!diff && IS_UTF8CONT(*s1 & *s2)) {
            diff = *s1++ - *s2++;
        }
    }
    return diff;
}

/*
 * Check if a byte sequence contains non-ascii characters.
 */
char is_ascii(char *s,int len)
{
    char *p = s;
    char *q = s+len;
    while( (p < q) && *p) {
        if (!isascii(*p++)) return 0;
    }
    return 1;
}
char *utf8norm(char *s,int len)
{
    char *out=NULL;
    if (is_ascii(s,len)) {
        out = COPY_STRING(len,s);
        //HTML_LOG(0,"ascii[%s]",NVL(out));
    } else {
        // Use COMPOSE rather than DECOMPOSE to preserve composed characters
        uint8_t *intptr;
        int uerr = utf8proc_map((uint8_t *)s,len,&intptr,UTF8PROC_COMPOSE|UTF8PROC_COMPAT|UTF8PROC_STABLE|UTF8PROC_IGNORE|UTF8PROC_STRIPCC);
        if (uerr < 0) {
            out = (char *)intptr;
            if (out == NULL) {
               // copy ascii bytes
                int i;
                char *p = out = COPY_STRING(len,s);
                for (i = 0 ; i < len ; i++ ) {
                    if (s[i] > 0) {
                        *p++ = s[i];
                    }
                } 
                *p = '\0';
            }
            HTML_LOG(0,"Error [%.*s] [%s] using [%s]",len,s,utf8proc_errmsg(uerr),out);
        } else {
            if (len && (out == NULL || !*out)) {
                // something went wrong?
                HTML_LOG(0,"Unknown error  - empty string  normalising [%.*s] ",len,s);
                out = COPY_STRING(len,s);
            } 
            //HTML_LOG(0,"utf8[%s]",NVL(out));
        }
    }
    return out;
}

int utf16(char *unterminated_char) 
{
    int out=0;

    unsigned char *p = (unsigned char *)unterminated_char;
    if (*p <= 0x7f ) {
        out += *p;

    } else if (*p < 0xE0 ) {
        out += (*p & 0x1f);

    } else if (*p < 0xF0 ) {
        out += (*p & 0x0f);

    } else if (*p < 0xF0 ) {
        out += (*p & 0x0f);

    } else if (*p < 0xF8 ) {
        out += (*p & 0x07);

    } else if (*p < 0xFC ) {
        out += (*p & 0x03);
    } else {
        out += (*p & 0x01);
    }
    if (*p > 0x7f ) {
        p++;
        while(IS_UTF8CONTP(p)) {
            out += (*p & 0x3f);
            p++;
        }
    }
    return out;
}

// Copy initial utf8 letter - return number of bytes copied. Null terminates the string.
int utf8_initial(char *in,char *out)
{
    char *p = out;

    if (IS_UTF8P(in)) {
        *p++ = *in++;
        while(IS_UTF8CONTP(in)) {
            *p++ = *in++;
        }
    } else if (*in) {
        // normal letter
        *p++ = *in++;
    }
    *p = '\0';
    return p-out;
}
