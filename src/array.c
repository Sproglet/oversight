#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <regex.h>

#include "array.h"


array *array_new() {

    array *a = (array *)malloc(sizeof(array));
    a->array = NULL;
    a->size = 0;
    a->mem_size = 0;
    return a;
}

/*
 * a_ptr = pointer to address of array to be freed. it is set to NULL afterwards.
 * (*fr)=free function
 * free_by_address = if 1 then the address of the variable , rather then the memory is passed so that it can be set to NULL
 */
void array_FREE(array **a_ptr, void(*fr)(void *) , int free_by_address ) {
    array_free(*a_ptr,fr,free_by_address);
    *a_ptr=NULL;
}
void array_free(array *a, void(*fr)(void *) , int free_by_address ) {
    int i;

    if (fr != NULL) {
        for(i = 0 ; i < a->size ; i++ ) {
            if (a->array[i]) {
                if (free_by_address) {
                    (*fr)(a->array+i);
                } else {
                    (*fr)(a->array[i]);
                }
            }
        }
    }
    if (a->array) {
        free(a->array);
    }
}

/*
 * array[array->size++]=ptr
 * The array is NOT sparse. Use hastable for sparse arrays.
 */
void array_add(array *a,void *ptr) {
    array_set(a,a->size,ptr);
}

/*
 * array[idx]=ptr
 * The array is NOT sparse. Use hastable for sparse arrays.
 */
void array_set(array *a,int idx,void *ptr) {

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

void array_print(char *label,array *a) {

    int i;

    fprintf(stderr,"%s: size %d mem %d  \n",label,a->size,a->mem_size);

    if ( a->size) {

        for(i = 0 ; i < a->size ; i++ ) {

            fprintf(stderr,"%s: [%d]=<%s>\n",label,i,(char *)(a->array[i]));
        }
    }
}

void array_unittest() {

    array *a = array_new();

    array_add(a,"hello");
    array_add(a,"goodbye");

    array_print("hello-goodbye",a);

    array_set(a,1,"world");
    array_add(a,"!!!");
    array_print("hello-world",a);

    array_set(a,15,"fifteen of twenty");
    array_print("hello-world",a);

    array_FREE(&a,NULL,0);

    char *s="oneXXtwoXXthree\tfour";

    a = split(s,"XX");

    array_print(s,a);
    array_FREE(&a,NULL,0);

    a = split(s,"X");
    array_print(s,a);
    array_FREE(&a,NULL,0);

    a = split(s,"X+");
    array_print(s,a);
    array_FREE(&a,NULL,0);

    a = split(s,"X*");
    array_print(s,a);
    array_FREE(&a,NULL,0);


}


/*
 * Split a strin s_in into an array using character ch.
 */
array *splitch(char *s_in,char ch) {
    array *a = array_new();
    char *s = s_in;
    char *p;
    printf("split ch [%s] by [%c]\n",s,ch);

    if (s == NULL) {
        return a;
    }


    while ((p=strchr(s,ch)) != NULL ) {

        char *part = malloc(p-s+1);

        strncpy(part,s,p-s);

        part[p-s]='\0';

        printf("part=[%s]\n",part);

        array_add(a,part);

        s = p+1;
    }
    array_add(a,strdup(s));

    return a;

}

/*
 * Split a strin s_in into an array using regex pattern.
 * If pattern is one character long then a simple
 * character split is used.
 */
array *split(char *s_in,char *pattern) {

    array *a = array_new();

    if (s_in == NULL) {
        return a;
    }

    printf("split re [%s] by [%s]\n",s_in,pattern);

    if (strlen(pattern) == 1 ) {
        return splitch(s_in,pattern[0]);
    }

    regex_t re;
    char *s=s_in;
    char *s_end = s + strlen(s);

    regmatch_t pmatch[100];

    int status;


#define BUFSIZE 256
    char buf[BUFSIZE];

    if ((status = regcomp(&re,pattern,REG_EXTENDED)) != 0) {

        regerror(status,&re,buf,BUFSIZE);

        return NULL;

    }


    int eflag = 0;
    // Repeatedly add the bit before each regex match
    while (s < s_end && regexec(&re,s,1,pmatch,eflag) == 0) {
        
        int match_start = pmatch[0].rm_so;
        int match_end = pmatch[0].rm_eo;
        
        printf("start %d end %d\n",match_start,match_end);


        // printf("split3 match found at [%*.s][%*.s]\n",match_start,s,(match_end-match_start),s+match_start);

        char *part = malloc(match_start+1);

        strncpy(part,s,match_start);
        part[match_start]='\0';

        printf("part=[%s]\n",part);

        array_add(a,part);

        //Move past the match
        if (match_start == 0 && match_end == 0) {
            printf("inc\n");
            match_end++;
        } 
        s += match_end;
        eflag = REG_NOTBOL;

    }
    printf("split4 [%s]\n",s);
    // Add the last part
    array_add(a,strdup(s));

    regfree(&re);

    return a;
}

