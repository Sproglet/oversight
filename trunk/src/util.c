#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <regex.h>
#include <assert.h>

#include "util.h"
#include "hashtable.h"
#include "hashtable_itr.h"
#include "hashtable_utility.h"
#include "array.h"


/*
char *strdup(char *s) {

	char *s2 = NULL;
	if (s != NULL) {
		*s2 = malloc(strlen(s)+1);
		assert(s2);
		strcpy(s2,s);
	}
	return s2;
}

*/



// String hashfunction
// http://www.cse.yorku.ca/~oz/hash.html
unsigned int stringhash(void *vptr) {
    unsigned long hash = 5381;
    int c;
    unsigned char *str = vptr;

    while ((c = *str++)) {
        hash = ((hash << 5) + hash) + c; /* hash * 33 + c */
    }

    return hash;
}
int stringcmp(void *a,void *b) {
    return strcmp(a,b) ==0;
}

struct hashtable *string_string_hashtable() {

    return create_hashtable(16,stringhash,stringcmp);
}


/*
 * This function joins two strings with a separator and returns the result
 * in new memory.
 * The original strings are freed.
 * If the separator is nul then it is ignored.
 * This might be just enough to avoid using a proper string library
 */
char *join_str_fmt_free(char *fmt,char *s1,char *s2) {

    assert(fmt);
    char *s;
    int sz1=0;
    int sz2=0;
    char *s1cp = "";
    char *s2cp = "";

    if (s1) {
        sz1 = strlen(s1);
        s1cp = s1;
    }
    
    if (s2) {
        sz2 = strlen(s2);
        s2cp = s2;
    }
    
    s=malloc(sz1 + sz2 + strlen(fmt)+3);
    assert(s);
    sprintf(s,fmt,s1cp,s2cp);
    if (s1) free(s1);
    if (s2 && (s2 != s1)) free(s2);
    return s;
}
/*
 * Split a strin s_in into an array using regex pattern.
 * If pattern is one character long then a simple
 * character split is used.
 */
char *replace_all(char *s_in,char *pattern,char *replace) {

    assert(s_in);
    assert(pattern);
    assert(replace);

    int outlen = 0;
    int replace_len = strlen(replace);

    array *a = array_new();

    if (s_in == NULL) {
        return NULL;
    }


    regex_t re;
    char *s=s_in;
    char *s_end = s + strlen(s);

    regmatch_t pmatch[5];

    int status;


#define BUFSIZE 256
    char buf[BUFSIZE];

    if ((status = regcomp(&re,pattern,REG_EXTENDED)) != 0) {

        regerror(status,&re,buf,BUFSIZE);
        fprintf(stderr,"%s\n",buf);
        assert(1);

        return NULL;

    }


    int eflag = 0;
    // Repeatedly add the bit before each regex match
    while (s < s_end && regexec(&re,s,1,pmatch,eflag) == 0) {
        
        int match_start = pmatch[0].rm_so;
        int match_end = pmatch[0].rm_eo;
        

        // printf("split3 match found at [%*.s][%*.s]\n",match_start,s,(match_end-match_start),s+match_start);

        char *part = malloc(match_start+1);

        strncpy(part,s,match_start);
        part[match_start]='\0';

        array_add(a,part);
        outlen += strlen(part);

        array_add(a,strdup(replace));
        outlen += replace_len;

        //Move past the match
        if (match_start == 0 && match_end == 0) {
            match_end++;
        } 
        s += match_end;
        eflag = REG_NOTBOL;

    }
    // Add the last part
    array_add(a,strdup(s));
    outlen += strlen(s);


    regfree(&re);

    char *s_out = malloc(outlen+1);
    assert(s_out);
    s = s_out;

    int i;

    for(i = 0 ; i < a->size  ; i++ ) {
        strcpy(s,a->array[i]);
        s+=strlen(a->array[i]);
    }

    array_free(a,free,0);
    return s_out;
}

/*
 * Match a regular expression and return the submatch'ed braketed pair 0=the entire match
 */
char *regextract(char *s,char *pattern,int submatch) {
    assert(s);
    assert(pattern);
    int status;
    regmatch_t pmatch[5];
    char *result = NULL;


#define BUFSIZE 256
    char buf[BUFSIZE];
    regex_t re;

    if ((status = regcomp(&re,pattern,REG_EXTENDED)) != 0) {

        regerror(status,&re,buf,BUFSIZE);
        fprintf(stderr,"%s\n",buf);
        assert(1);
        return NULL;
    }

    if (regexec(&re,s,2,pmatch,0) == 0) {

        int match_start = pmatch[submatch].rm_so;
        int match_end = pmatch[submatch].rm_eo;
        if (match_start == -1 ) {
            result = NULL;
        } else {
            result = substring(s,match_start,match_end);
        }
    }

    regfree(&re);

    return result;

}

/*
 * Return a substring - must be freed by caller
 */
char *substring(char *s,int start_pos, int end_pos) {

    int len=end_pos-start_pos;
    char *p = malloc(len+1);
    strncpy(p,s+start_pos,len);
    p[len]='\0';
    return p;
}

/*
 * Merge one hash table into another.
 * if allocate then values are copied using strdup.
 * if copy==0 then hash table h2 will be destroyed as values have moved to h1
 */
void merge_hashtables(struct hashtable *h1,struct hashtable *h2,int copy) {
    if (hashtable_count(h2) > 0 ) {
        struct hashtable_itr *itr = hashtable_iterator(h2);
        do {
            void *k = hashtable_iterator_key(itr);
            void *v = hashtable_iterator_value(itr);
            if (copy) {
                v = strdup((char *)v);
                assert(v);
            }

            if ( !hashtable_change(h1,k,v) ) {
                hashtable_insert(h1,k,v);
            }
        }
    }

    // As h1 has h2 values we destroy h2 to avoid double memory frees.
    if (!copy) {
        hashtable_destroy(h2,0);
    }
}

void util_unittest() {
    char *hello = substring("XXhelloYY",2,7);
    printf("%s\n",hello);
    assert(strcmp(hello,"hello") == 0);

    char *there = regextract("over there!","([a-z]+)!",1);
    printf("%s\n",there);
    assert(strcmp(there,"there") == 0);

    hello=join_str_fmt_free("%s %s",hello,there);
    printf("%s\n",hello);
    assert(strcmp(hello,"hello there") == 0);

    char *x=replace_all(hello,"e","E");
    printf("%s\n",x);
    assert(strcmp(x,"hEllo thErE") == 0);

    struct hashtable *h = string_string_hashtable();

    printf("insert %s = %s\n",hello,x);
    assert(hashtable_insert(h,hello,x));

    assert(hashtable_search(h,hello) != NULL);
    assert(hashtable_search(h,x) == NULL);
    assert(hashtable_search(h,hello) != NULL);
    assert(hashtable_search(h,x) == NULL);

    printf("search = %s\n",(char *)hashtable_search(h,hello));
    assert(hashtable_search(h,hello) != NULL);

    printf("free x\n");
    free(x);

    printf("destroy\n");
    hashtable_destroy(h,0);
    //this may cause error
    // free(hello);

}

