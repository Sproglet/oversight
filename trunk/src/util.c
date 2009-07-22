#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <regex.h>
#include <assert.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <pwd.h>
#include <unistd.h>
#include <errno.h>
#include <ctype.h>

#include "util.h"
#include "hashtable.h"
#include "hashtable_loop.h"
#include "hashtable_utility.h"
#include "gaya_cgi.h"
#include "vasprintf.h"



// String hashfunction - used by string_string_hashtable()
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

    char *s;
    ovs_asprintf(&s,fmt,s1,s2);
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

    Array *a = array_new(free);

    int eflag = 0;
    // Repeatedly add the bit before each regex match
    while (s < s_end && regexec(&re,s,1,pmatch,eflag) == 0) {
        
        int match_start = pmatch[0].rm_so;
        int match_end = pmatch[0].rm_eo;
        

        // printf("split3 match found at [%*.s][%*.s]\n",match_start,s,(match_end-match_start),s+match_start);

        char *part = MALLOC(match_start+1);

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

    char *s_out = MALLOC(outlen+1);
    assert(s_out);
    s = s_out;

    int i;

    for(i = 0 ; i < a->size  ; i++ ) {
        strcpy(s,a->array[i]);
        s+=strlen(a->array[i]);
    }

    array_free(a);
    return s_out;
}

#define BUFSIZE 256
/* return position of regex in a string. -1 if no match  */
int regpos(char *s,char *pattern) {
    assert(s);
    assert(pattern);

    int status;
    regmatch_t pmatch[1];
    regex_t re;

    if ((status = regcomp(&re,pattern,REG_EXTENDED)) != 0) {

        char buf[BUFSIZE];
        regerror(status,&re,buf,BUFSIZE);
        fprintf(stderr,"%s\n",buf);
        assert(1);
        return -1;
    }

    int pos = -1;

    if (regexec(&re,s,1,pmatch,0) == 0) {
        pos = pmatch[0].rm_so;
    }

    regfree(&re);
    return pos;
}

/*
 * Extract a single regex submatch
 */
char *regextract1(char *s,char *pattern,int submatch) {

    Array *a = regextract(s,pattern);
    char *segment = NULL;

    if (a == NULL) {
        return NULL;
    } else {
        segment = a->array[submatch];
        a->array[submatch] = NULL;
        array_free(a);
    }
    return segment;
}

/*
 * Match a regular expression and return the submatch'ed braketed pair 0=the entire match
 */
Array *regextract(char *s,char *pattern) {

    int submatch = 1;
    // count number of submatch brackets
    char *br;
    for(br=pattern ; *br ; br ++ ) {
        if (*br == '(') {
            submatch++;
        }
    }

    assert(s);
    assert(pattern);
    int status;
    Array *result = NULL;


    regex_t re;

    if ((status = regcomp(&re,pattern,REG_EXTENDED)) != 0) {

        char buf[BUFSIZE];
        regerror(status,&re,buf,BUFSIZE);
        fprintf(stderr,"%s\n",buf);
        assert(1);
        return NULL;
    }

    regmatch_t *pmatch = calloc(submatch+1,sizeof(regmatch_t));

    if (regexec(&re,s,submatch,pmatch,0) == 0) {

        result = array_new(free);
        int i;
        for(i = 0 ; i < submatch ; i++ ) {

            int match_start = pmatch[i].rm_so;
            int match_end = pmatch[i].rm_eo;

            if (match_start == -1 ) {

                array_add(result,NULL);

            } else {

                array_add(result,substring(s,match_start,match_end));
            }
        }
    }
    free(pmatch);

    regfree(&re);

    return result;

}

// Free results of regextract
void regextract_free(Array *submatches) {
    array_free(submatches);
}

/*
 * Return a substring - must be freed by caller
 */
char *substring(char *s,int start_pos, int end_pos) {

    int len=end_pos-start_pos;
    char *p = MALLOC(len+1);
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

       char *k,*v;
       struct hashtable_itr *itr ;

       for(itr = hashtable_loop_init(h2); hashtable_loop_more(itr,&k,&v) ; ) {

            if (copy) {
                v = strdup((char *)v);
                assert(v);
            }

            if ( hashtable_change(h1,k,v) ) {
                html_log(1,"Changed [ %s ] = [ %s ]\n",k,v);
            } else {
                hashtable_insert(h1,k,v);
                html_log(4,"Added [ %s ] = [ %s ]\n",k,v);
            }
        }
    }

    // As h1 has h2 values we destroy h2 to avoid double memory frees.
    if (!copy) {
        hashtable_destroy(h2,1,0);
    }
}

void util_unittest() {

    printf("strings...\n");
    // string functions
    char *hello = substring("XXhelloYY",2,7);
    //printf("%s\n",hello);
    assert(strcmp(hello,"hello") == 0);

    //regex functions
    //
    printf("regextract...\n");
    Array *a = regextract("over there!","([a-z]+)!");
    char *there = strdup(a->array[1]);
    array_free(a);

    assert(strcmp(there,"there") == 0);


    hello=join_str_fmt_free("%s %s",hello,there);

    printf("replaceall...\n");
    char *x=replace_all(hello,"e","E");
    printf("%s\n",x);
    assert(strcmp(x,"hEllo thErE") == 0);

    printf("regpos...\n");
    assert(regpos("hello","e") == 1);

    printf("regmatch...\n");
    Array *matches=regextract(" a=b helllo d:efg ","(.)=(.).*(.):(..)");
    assert(matches);
    assert(matches->size == 5);
    assert(strcmp(matches->array[0],"a=b helllo d:ef") ==0);
    assert(strcmp(matches->array[1],"a") ==0);
    assert(strcmp(matches->array[2],"b") ==0);
    assert(strcmp(matches->array[3],"d") ==0);
    assert(strcmp(matches->array[4],"ef") ==0);
    printf("regmatch4...\n");
    array_free(matches);
    printf("regmatch5...\n");

    //printf("%s\n",hello);
    assert(strcmp(hello,"hello there") == 0);

    // hashtables
    //
    struct hashtable *h = string_string_hashtable();

    assert(hashtable_insert(h,hello,x));

    assert(hashtable_search(h,hello) == x);
    assert(hashtable_search(h,x) == NULL);

    printf("free x\n");
    free(x);

    printf("destroy\n");
    hashtable_destroy(h,1,0);
    //this may cause error after a destroy?
    // free(hello);
}

int chomp(char *str) {
    int i=0;
    if (str) {
        char *p = str + strlen(str) -1 ; 
        while ( p > str  && strchr("\n\r",*p )) {
            *p = '\0';
            p--;
            i++;
        }
    }
    return i;
}

int exists(char *path) {
       return access(path,F_OK);
}

int is_writeable(char *path) {
       return access(path,W_OK);
}

int is_readable(char *path) {
       return access(path,R_OK);
}
int is_executable(char *path) {
       return access(path,X_OK);
}

int is_file(char *path) {
    struct stat s;
    if (stat(path,&s) == 0) {
        return S_ISREG(s.st_mode);
    } else {
        return 0;
    }
}

int is_dir(char *path) {
    struct stat s;
    if (stat(path,&s) == 0) {
        return S_ISDIR(s.st_mode);
    } else {
        return 0;
    }
}


char *appDir() {
    char *d="/share/Apps/oversight";
    if (!is_dir(d)) {
        d=".";
    }
    return d;
}

char *tmpDir() {
    static char *d=NULL;
    
    if (d == NULL ) {

        d = nmt_subdir(appDir(),"tmp");
    }
    return d;
}
        
//return new directory - name must be freed
char *nmt_subdir(char *root,char *name) {

    char *d;
    ovs_asprintf(&d,"%s/%s",root,name);

    if (!is_dir(d)) {
        nmt_mkdir(d);
    }
    return d;
}

void nmt_chown(char *d) {
    if (nmt_uid() >= 0 && nmt_gid() >= 0) {
        chown(d,nmt_uid(),nmt_gid());
    }
}

int nmt_mkdir(char *d) {

    int err;

    if ((err=mkdir(d,0775)) != 0) {
        fprintf(stderr,"unable to create [%s] : %d\n",d,errno);
    } else {
        nmt_chown(d);
    }
    return err;
}

static struct passwd *nmt_passwd = NULL;

int nmt_uid() {

    if (nmt_passwd == NULL ) {
        nmt_passwd = getpwnam("nmt");
    }
    if (nmt_passwd != NULL ) {
        return nmt_passwd->pw_uid;
    } else {
        return getuid();
    }
}

int nmt_gid() {

    if (nmt_passwd == NULL ) {
        nmt_passwd = getpwnam("nmt");
    }
    if (nmt_passwd != NULL ) {
        return nmt_passwd->pw_gid;
    } else {
        return getgid();
    }
}

void hashtable_dump(char *label,struct hashtable *h) {


    if (hashtable_count(h)) {

       char *k,*v;
       struct hashtable_itr *itr ;

       for(itr = hashtable_loop_init(h); hashtable_loop_more(itr,&k,&v) ; ) {

            fprintf(stderr,"<!-- %s : [ %s ] = [ %s ] -->\n",label,k,v);
        }

    } else {
        fprintf(stderr,"<!-- %s : EMPTY HASH -->\n",label);
    }
}

void *REALLOC(void *ptr,unsigned long bytes) {
    void *p = NULL;

    if (bytes) {
    
        p = realloc(ptr,bytes);
        if (p == NULL && bytes) {
            fprintf(stderr,"Memory exhausted on malloc\n");
            printf("Memory exhausted on malloc\n");
            exit(1);
        }

    }
    return p;
}

void *MALLOC(unsigned long bytes) {
    void *p = NULL;

    if (bytes) {
    
        p = malloc(bytes);
        if (p == NULL && bytes) {
            fprintf(stderr,"Memory exhausted on malloc\n");
            printf("Memory exhausted on malloc\n");
            exit(1);
        }

    }
    return p;
}

char *util_tolower(char *s) {
    char *p = NULL;
    if(s) {
        p = MALLOC(strlen(p)+1);
        char *q = p ;
        while (*s) {
            *q = tolower(*s);
        }
        *q='\0';
    }
    return p;
}

char *STRDUP(char *s) {
    char *p = NULL;

    if (s) {
    
        p = strdup(s);
        if (p == NULL) {
            fprintf(stderr,"Memory exhausted on strdup\n");
            printf("Memory exhausted on strdup\n");
            exit(1);
        }

    }
    return p;
}
