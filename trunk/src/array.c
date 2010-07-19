// $Id:$
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <regex.h>

#include "array.h"
#include "assert.h"
#include "util.h"
#include "gaya_cgi.h"

int array_strlen(Array *a);

Array *array_new(void(*free_fn)(void *)) {

    Array *a = (Array *)MALLOC(sizeof(Array));
    a->array = NULL;
    a->size = 0;
    a->mem_size = 0;
    a->free_fn = free_fn;
    return a;
}

/*
 * a_ptr = pointer to address of array to be freed. it is set to NULL afterwards.
 * (*fr)=free function
 * free_by_address = if 1 then the address of the variable , rather then the memory is passed so that it can be set to NULL
 */
void array_free(Array *a) {
    int i;

    void(*free_fn)(void *);

    if (a) {
        free_fn = a->free_fn;

        if (free_fn != NULL) {
            for(i = 0 ; i < a->size ; i++ ) {
                if (a->array[i]) {
                    (*free_fn)(a->array[i]);
                    if (free_fn == free ) { 
                        a->array[i] = NULL;
                    }
                }
            }
        }
        if (a->array) {
            FREE(a->array);
        }
        a->size = 0;
    }
}

/*
 * array[array->size++]=ptr
 * The array is NOT sparse. Use hastable for sparse arrays.
 */
void array_add(Array *a,void *ptr) {
    array_set(a,a->size,ptr);
}

/*
 * array[idx]=ptr
 * The array is NOT sparse. Use hastable for sparse arrays.
 */
void array_set(Array *a,int idx,void *ptr) {

#define ARRAY_EXPAND 10
    //extend memory
    if (idx >=  a->mem_size) {
        int new_size = idx + ARRAY_EXPAND;
        int i;
        a->array = realloc(a->array , new_size * sizeof(void *));

        for(i = a->mem_size ; i< new_size ; i++ ) {
            a->array[i] = NULL;
        }
        a->mem_size = new_size;
    }

    //extend application size
    if (idx >=  a->size) {
        a->size = idx+1;
    }

    //set the value
    if (idx < a->size) {
        a->array[idx] = ptr;
    }
}

// strcmp function for qsort.
int array_strcasecmp(const void *a,const void *b) {
    return strcasecmp(*(char **)a,*(char **)b);
}

// Sort an array. If 2nd arg is null then use default sort array_strcasecmp
void array_sort(Array *a,int (*fn)(const void *,const void *)) {
    if (a && a->size) {
        if (fn == NULL) {
            fn = array_strcasecmp;
        }
        qsort(a->array,a->size,sizeof(void *),fn);
    }
}

void array_dump(int level,char *label,Array *a)
{

    int i;

    if (a) {

        HTML_LOG(level,"%s: size %d mem %d",label,a->size,a->mem_size);

        if ( a->size) {

            for(i = 0 ; i < a->size ; i++ ) {

                HTML_LOG(level,"%s: [%d]=<%s>",label,i,(char *)(a->array[i]));
            }
        }
    } else {
        HTML_LOG(level,"%s: null array",label);
    }
}
void array_print(char *label,Array *a) {

    array_dump(1,label,a);
}

void array_unittest() {

    Array *a = array_new(free);

    array_add(a,"hello");
    array_add(a,"goodbye");

    array_print("hello-goodbye",a);

    array_set(a,1,"world");
    array_add(a,"!!!");
    array_print("hello-world",a);

    array_set(a,15,"fifteen of twenty");
    array_print("hello-world",a);

    array_free(a);

    char *s="oneXXtwoXXthree\tfour";

    a = split(s,"XX",0);

    assert(a->size == 3);
    assert(STRCMP(a->array[0],"one") == 0);
    assert(STRCMP(a->array[1],"two") == 0);
    assert(STRCMP(a->array[2],"three\tfour") == 0);
    array_free(a);

    a = split(s,"X",0);
    assert(a->size == 5);
    assert(STRCMP(a->array[0],"one") == 0);
    assert(STRCMP(a->array[1],"") == 0);
    assert(STRCMP(a->array[2],"two") == 0);
    assert(STRCMP(a->array[3],"") == 0);
    assert(STRCMP(a->array[4],"three\tfour") == 0);
    array_free(a);

    a = split(s,"X+",0);
    assert(a->size == 3);
    assert(STRCMP(a->array[0],"one") == 0);
    assert(STRCMP(a->array[1],"two") == 0);
    assert(STRCMP(a->array[2],"three\tfour") == 0);
    array_free(a);

    a = split(s,"X*",0);
    array_print(s,a);
    array_free(a);


}


/*
 * Split a strin s_in into an array using any character in sep.
 */
Array *split1ch(char *s_in,char *sep)
{
    Array *a = array_new(free);
    char *s = s_in;
    char *p;

    // printf("split ch [%s] by [%c]\n",s,ch);

    if (s_in == NULL || *s_in == '\0' ) {
        return a;
    }


    p = s;
    while (*p ) { 
        if (strchr(sep,*p)) {

            char *part;
            part = COPY_STRING(p-s,s);
            part[p-s] = '\0';

            array_add(a,part);

            s = p =  p+1;
        } else {
            p++;
        }
    }
    array_add(a,STRDUP(s));

    return a;

}
/*
 * Split a strin s_in into an array using character ch.
 */
Array *splitstr(char *s_in,char *sep)
{
    return splitstr_max(s_in,sep,-1);
}

/*
 * Split a strin s_in into an array using character ch.
 * Max n parts. 0 = all parts.
 */
Array *splitstr_max(char *s_in,char *sep,int n)
{
    Array *a = array_new(free);
    char *s = s_in;
    char *p;

    int seplen = strlen(sep);
    // printf("split ch [%s] by [%c]\n",s,ch);

    if (s_in == NULL || *s_in == '\0' ) {
        return a;
    }


    while ((p=strstr(s,sep)) != NULL && n != 0 ) {

        char *part;

        part = COPY_STRING(p-s,s);
        part[p-s] = '\0';

        //HTML_LOG(0,"part[%s]",part);

        array_add(a,part);

        s = p+seplen;

        if (n>0) n--;
    }
    array_add(a,STRDUP(s));

    return a;

}

char *join(Array *a,char *sep) {
    char *result=NULL;
    int len=0;
    int slen = 0;
    if (sep) {
        slen = strlen(sep);
    }

    if (a && a->size) {

        len = array_strlen(a) + slen * (a->size-1);
        result = MALLOC(len+1);
        char *q;
        char *p = result;
        int i;

        for(i = 0 ; i< a->size ; i++ ) {
            if (i) {
                if(slen) {
                    // copy the separator
                    memcpy(p,sep,slen);
                    p+=slen;
                }
            }
            if ((q = a->array[i]) != NULL ) {
                while ((*p++ = *q++ ) != '\0' ) {
                        ; //do nothing
                }
                p--;
            }
        }
        *p = '\0';

    }
    return result;
}

/*
 * Split a strin s_in into an array using regex pattern.
 * If pattern is one character long then a simple
 * character split is used.
 */
Array *split(char *s_in,char *pattern,int reg_opts) {

    Array *a = array_new(free);

    if (s_in == NULL || *s_in == '\0' ) {
        return a;
    }

    //printf("split re [%s] by [%s]\n",s_in,pattern);

    if ( pattern[0] && !pattern[1] && reg_opts == 0 ) {
        return splitstr(s_in,pattern);
    }

    regex_t re;
    char *s=s_in;
    char *s_end = s + strlen(s);

    regmatch_t pmatch[100];

    int status;


#define BUFSIZE 256
    char buf[BUFSIZE];

    if ((status = regcomp(&re,pattern,REG_EXTENDED|reg_opts)) != 0) {

        regerror(status,&re,buf,BUFSIZE);

        return NULL;

    }


    int eflag = 0;
    // Repeatedly add the bit before each regex match
    while (s < s_end && regexec(&re,s,1,pmatch,eflag) == 0) {
        
        int match_start = pmatch[0].rm_so;
        int match_end = pmatch[0].rm_eo;
        
        // printf("split3 match found at [%*.s][%*.s]\n",match_start,s,(match_end-match_start),s+match_start);

        char *part = MALLOC(match_start+1);

        strncpy(part,s,match_start);
        part[match_start]='\0';

    //    printf("part=[%s]\n",part);

        array_add(a,part);

        //Move past the match
        if (match_start == 0 && match_end == 0) {
     //       printf("inc\n");
            match_end++;
        } 
        s += match_end;
        eflag = REG_NOTBOL;

    }
    // printf("split4 [%s]\n",s);
    array_add(a,strdup(s));

    regfree(&re);

    return a;
}

/**
 * Get combined length of all char * in an array.
 */
int array_strlen(Array *a)
{
    int len  = 0;
    int i;
    if (a) {
        for (i = 0 ; i < a->size ; i++ ) {
            if (a->array[i]) {
                len += strlen(a->array[i]);
            }
        }
    }
    return len;
}

/**
 * Convert Array of Char * to a single char *
 */
char *arraystr(Array *a)
{
    return join(a,NULL);
}

/**
 * Convert Array of Array of Char * to a single char *
 */
char *array2dstr(Array *a)
{
    int i,j;
    int len  = 0;
    char *str = NULL;
    if (a) {
        for (i = 0 ; i < a->size ; i++ ) {
            Array *b = a->array[i];
            len += array_strlen(b);
        }
    }

    if (len) {
        str = MALLOC(len+1);
        char *q,*p = str;
        for (i = 0 ; i < a->size ; i++ ) {
            Array *b = a->array[i];
            if (b) {
                for (j = 0 ; j < b->size ; j++ ) {
                    if ((q = b->array[j]) != NULL ) {
                        while ((*p++ = *q++ ) != '\0' ) {
                            ; //do nothing
                        }
                        p--;
                    }
                }
            }
        }
        *p = '\0';
    }
    return str;
}
// vi:sw=4:et:ts=4
