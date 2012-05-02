// $Id:$
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <regex.h>
#include <assert.h>
#include <utime.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <pwd.h>
#include <unistd.h>
#include <errno.h>
#include <ctype.h>
#include <dirent.h>
#include <time.h>

#include "util.h"
#include "hashtable.h"
#include "hashtable_loop.h"
#include "hashtable_utility.h"
#include "gaya_cgi.h"
#include "vasprintf.h"
#include "config.h"
#include "oversight.h"
#include "permissions.h"
#include "abet.h"


// All folders have . and ..
int is_empty_dir(char *dname)
{
    int result = 0;
    int i=0;
    DIR *d = opendir(dname);
    if (d) {
        while(readdir(d)) {
            i++;
            if (i == 3) break;
        }
        closedir(d);
    }
    result =  i <= 2;
    HTML_LOG(0,"is_empty_dir[%s]=%d",dname,result);
    return result;
}


// String hashfunction - used by string_string_hashtable()
// http://www.cse.yorku.ca/~oz/hash.html
unsigned int stringhash(void *vptr) {

    register unsigned long hash = 0;
    int c;
    unsigned char *str = vptr;

    if (str) {

        //if (STARTS_WITH_THE(str)) str+=4;

        hash = 5381;
        
        while ((c = *str++)) {
            
            /* Case insensitive LUA */
            // HASH_ADD(hash,c);
            /* For oversight this is good enough. Dont worry about overflow */
            hash += c;
        }
    }

    return hash;
}
int stringcmp(void *a,void *b) {
    return STRCMP(a,b) ==0;
}

struct hashtable *string_long_hashtable(char *name,int size)
{
    return create_hashtable(name,size,stringhash,stringcmp);
}
struct hashtable *string_string_hashtable(char *name,int size)
{
    return create_hashtable(name,size,stringhash,stringcmp);
}

// Replace all pairs  string,match1,replace1,match2,replace2,NULL
char *replace_all_str(char *s_in,...)
{
    char *result;
    va_list args;
    char *match,*replace;

    char *tmp;

    va_start(args,s_in);

    result = s_in;

    while ((match = va_arg(args,char *)) != NULL ) {
        replace = va_arg(args,char *);

        tmp = replace_str(result,match,replace);

        if (result != s_in) FREE(result);
        result = tmp;
    }
    va_end(args);
    if (result == s_in) {
        result = STRDUP(result);
    }
    return result;

}


char *translate_inplace(
        char *str, // input text
        char *a,   // ordered list to translate characters from
        char *b    // ordered list to translate characters to
        )
{
    char *p = str;
    if (p) {
        while(*p) {
            char *ch;
            if ((ch=strchr(a,*p)) != NULL) {
                *p = b[ch-a];
            }
            p++;
        }
    }
    return str;
}

/*
 * replace match with relace. num=-1 = all occurences.
 */
char *replace_str_num(char *s_in,char *match,char *replace,int num)
{
    char *out=NULL,*p;
    char *m,*s,*s1;
   
    if (s_in && match && replace) {
        int matchlen = strlen(NVL(match));
        int replen = strlen(replace);

        assert(matchlen);

        int old_size = strlen(s_in);

        int new_size; 
        // Estimate max length of new string
        if (replen < matchlen ) {
            new_size = old_size + 1;
        } else {
            new_size = replen * ( old_size / matchlen ) + old_size % matchlen + 1;
        }

        // Now look for 'match' in 's_in'
        s = s_in;
        p = out = MALLOC(new_size);
        while (*s) {
            s1 = s;
            m = match;
            // Try to match against current s1 position
            while(*s1 && *m && *s1 == *m ) {
                s1++;
                m++;
            }
            if (*m || num == 0) {
                // NO MATCH - copy all matching (from s to s1) AND the additional character that broke the match
                // Hence s <= s1 rather than s<s1
                while(s <= s1) {
                    *p++ = *s++;
                }
            } else {
                // MATCH
                strcpy(p,replace);
                p += replen;
                s = s1;
                if (num > 0 ) {
                    num--;
                }
            }
        }
        *p = '\0';
    } else {
        html_error("empty args");
    }
    return out;
}
char *replace_str(char *s_in,char *match,char *replace)
{
    return replace_str_num(s_in,match,replace,-1);
}

/*
 * Split a string s_in into an array using regex pattern.
 * If pattern is one character long then a simple
 * character split is used.
 */
char *replace_all(char *s_in,char *pattern,char *replace,int reg_opts)
{

    assert(s_in);
    assert(pattern);
    replace = NVL(replace);

    int outlen = 0;
    int replace_len = strlen(replace);


    if (s_in == NULL) {
        return NULL;
    }


    regex_t re;
    char *s=s_in;
    char *s_end = s + strlen(s);

    regmatch_t pmatch[5];

    util_regcomp(&re,pattern,REG_EXTENDED|reg_opts);

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
void util_regcomp(regex_t *re,char *pattern,int flags)
{

    int status;

    if ((status = regcomp(re,pattern,REG_EXTENDED|flags)) != 0) {

        char buf[BUFSIZE];
        regerror(status,re,buf,BUFSIZE);
        fprintf(stderr,"%s\n",buf);
        assert(0);
    }
}
/* return position of regex in a string. NULL if no match  */
char *util_strreg(char *s,char *pattern,int reg_opts)
{
    assert(s);
    assert(pattern);

    regmatch_t pmatch[1];
    regex_t re;

    util_regcomp(&re,pattern,reg_opts);

    char *pos = NULL;

    if (regexec(&re,s,1,pmatch,0) == 0) {
        pos = s+pmatch[0].rm_so;
    }

    regfree(&re);
    return pos;
}

/*
 * Match a regular expression and return the submatch'ed braketed pair 0=the entire match
 */
char *regextract1(char *s,char *pattern,int submatch,int reg_opts) {

    Array *a = regextract(s,pattern,reg_opts);
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
 * Match a regular expression and return array of submatches
 */
Array *regextract(char *s,char *pattern,int reg_opts)
{

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
    Array *result = NULL;

    regex_t re;

    util_regcomp(&re,pattern,REG_EXTENDED|reg_opts);

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
    FREE(pmatch);

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
                v = STRDUP((char *)v);
            }

            if ( hashtable_change(h1,k,v) ) {
                HTML_LOG(3,"Changed [ %s ] = [ %s ]",k,v);
            } else if (copy) {
                hashtable_insert(h1,STRDUP(k),v);
                HTML_LOG(5,"Added [ %s ] = [ %s ]",k,v);
            } else {
                hashtable_insert(h1,k,v);
                HTML_LOG(5,"Added [ %s ] = [ %s ]",k,v);
            }
        }
    }

    // As h1 has h2 values we destroy h2 to avoid double memory frees.
    if (!copy) {
        hashtable_destroy(h2,0,0);
    }
}

void util_unittest() {

    printf("strings...\n");
    // string functions
    char *hello = substring("XXhelloYY",2,7);
    //printf("%s\n",hello);
    assert(STRCMP(hello,"hello") == 0);

    //regex functions
    //
    printf("regextract...\n");
    Array *a = regextract("over there!","([a-z]+)!",0);
    char *there = strdup(a->array[1]);
    array_free(a);

    assert(STRCMP(there,"there") == 0);


    printf("replaceall...\n");
    char *x=replace_all(hello,"e","E",0);
    printf("%s\n",x);
    assert(STRCMP(x,"hEllo thErE") == 0);

    printf("strreg...\n");
    char *hstr="hello";
    assert(util_strreg(hstr,"e",0) == hstr);

    printf("regmatch...\n");
    Array *matches=regextract(" a=b helllo d:efg ","(.)=(.).*(.):(..)",0);
    assert(matches);
    assert(matches->size == 5);
    assert(STRCMP(matches->array[0],"a=b helllo d:ef") ==0);
    assert(STRCMP(matches->array[1],"a") ==0);
    assert(STRCMP(matches->array[2],"b") ==0);
    assert(STRCMP(matches->array[3],"d") ==0);
    assert(STRCMP(matches->array[4],"ef") ==0);
    printf("regmatch4...\n");
    array_free(matches);
    printf("regmatch5...\n");

    //printf("%s\n",hello);
    assert(STRCMP(hello,"hello there") == 0);

    // hashtables
    //
    struct hashtable *h = string_string_hashtable("test",16);

    assert(hashtable_insert(h,hello,x));

    assert(hashtable_search(h,hello) == x);
    assert(hashtable_search(h,x) == NULL);

    printf("free x\n");
    FREE(x);

    printf("destroy\n");
    hashtable_destroy(h,1,0);
    //this may cause error after a destroy?
    // FREE(hello);
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


// Return substr within buf if it is preceeded by prefix and followed by suffix.
// if match_start is true the prefix is not required at the start.
// if match_end is true the suffix is not required at the end.
char *delimited_substring(char *buf,char *prefix,char *substr,char *suffix,int match_start,int match_end)
{

    assert(buf);
    char *p;
    int len = strlen(substr);

    p=buf;

    while ((p=strstr(p,substr))!= NULL ) {

        if (( p > buf && strchr(prefix,p[-1]) ) || (p == buf && match_start ) ) {

            if ( ( p[len] && strchr(suffix,p[len]) ) || (p[len] == '\0' && match_end ) ) {

                return p;

            }
        }
        p++;
    }
    return NULL;
}

int exists(char *path) {
       return access(path,F_OK) == 0;
}

int is_writeable(char *path) {
       return access(path,W_OK) == 0;
}

int is_readable(char *path) {
       return access(path,R_OK) == 0;
}
int is_executable(char *path) {
       return access(path,X_OK) == 0;
}

int is_file(char *path) {
    struct STAT64 s;
    if (STAT64(path,&s) == 0) {
        return S_ISREG(s.st_mode);
    } else {
        return 0;
    }
}
long file_size(char *path) {
    struct STAT64 s;
    if (STAT64(path,&s) == 0) {
        return s.st_size;
    } else {
        return 0;
    }
}

int is_dir(char *path) {
    struct STAT64 s;
    if (STAT64(path,&s) == 0) {
        return S_ISDIR(s.st_mode);
    } else {
        return 0;
    }
}


char *appDir() {
    static char *d=NULL;
    if (d == NULL) {
        d = "/share/Apps/oversight";
        if (!is_dir(d)) {
            d=".";
        }
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

int util_rename(char *old,char *new) {
    if (rename(old,new)) {
        nmt_chown(new);
        return 1;
    }
    return 0;
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

#define NMT_USER "nmt"
int nmt_uid() {

    if (nmt_passwd == NULL ) {
        nmt_passwd = getpwnam(NMT_USER);
    }
    if (nmt_passwd != NULL ) {
        return nmt_passwd->pw_uid;
    } else {
        return getuid();
    }
}

int nmt_gid() {

    if (nmt_passwd == NULL ) {
        nmt_passwd = getpwnam(NMT_USER);
    }
    if (nmt_passwd != NULL ) {
        return nmt_passwd->pw_gid;
    } else {
        return getgid();
    }
}

void hashtable_dump(char *label,struct hashtable *h) {
    hashtable_dumpf(stderr,label,h);
}

void hashtable_dumpf(FILE *fp,char *label,struct hashtable *h) {

    FILE *out = html_get_output();

    if (hashtable_count(h)) {

       char *k,*v;
       struct hashtable_itr *itr ;

       for(itr = hashtable_loop_init(h); hashtable_loop_more(itr,&k,&v) ; ) {

            fprintf(out,"<!-- %s : [ %s ] = [ %s ] -->\n",label,k,v);
        }

    } else {
        fprintf(out,"<!-- %s : EMPTY HASH -->\n",label);
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

void *CALLOC(size_t count,size_t bytes)
{
    void *p = NULL;

    if (count * bytes) {
        if ((p = calloc(count,bytes)) == NULL) {
            fprintf(stderr,"Memory exhausted on calloc(%d,%d)\n",count,bytes);
            printf("Memory exhausted on calloc(%d,%d)\n",count,bytes);
            exit(1);
        }
    }

    return p;
}

void *MALLOC(unsigned long bytes)
{
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
        p = MALLOC(strlen(s)+1);
        char *q = p ;
        while (*s) {
            *q++ = tolower(*(unsigned char *)s++);
        }
        *q='\0';
    }
    return p;
}

char *STRDUP(char *s) {
    char *p = NULL;

    p = strdup(NVL(s));
    if (p == NULL) {
        fprintf(stderr,"Memory exhausted on strdup\n");
        printf("Memory exhausted on strdup\n");
        exit(1);
    }

    return p;
}
char *util_hostname() {
#define HOSTBUFSIZ 30
    static char hostname[HOSTBUFSIZ];
    gethostname(hostname,HOSTBUFSIZ);
    hostname[HOSTBUFSIZ-1]='\0';
    return hostname;
}
// return parent dir of media file. ptr must be freed.
char *util_dirname(char *file)
{

    char *result=NULL;

    char *p = strrchr(file,'/');
    if (!p) {
        result = STRDUP(".");
    } else {

        char *q;

        if (!p[1]) {
            // VOB Folder
            *p='\0';
            q=strrchr(file,'/');
            *p='/';
        } else {
            // Normal file
            q=p;
        }
        *q='\0';
        result=STRDUP(file);
        *q='/';
    }
    return result;
}

char *util_endswith(char *s,char *r)
{
    char *ret = NULL;
    if (s) {
        int slen = strlen(s);
        if (!r) {
            ret = s+slen;
        } else {
            int rlen = strlen(r);
            if (rlen < slen) {
                char *p = s + slen - rlen;
                if (strcmp(p,r) == 0) {
                    ret = p;
                }
            }
        }
    }
    return ret;
}

// return basename of media file. ptr must be freed.
char *util_basename(char *file)
{
//For a normal file return the file name, for a DVD VOB folder return parent folder.
    char *p,*s;

    s = p = strrchr(file,'/');

    if (s == NULL) {

        s = STRDUP(file);

    } else {

        if (s && s[1] == '\0' ) {  
            //If it ends with / go back to penultimate / - for VOBSUB
            *p='\0';
            s=strrchr(file,'/');
        }

        // Copy string after /
        if (s) {
            s=STRDUP(s+1);
        } else {
            s= STRDUP(file);
        }

        //If vobsub restore final /
        if (p && *p=='\0') *p='/';
    }

    return s;
}

// result must be freed
char *util_basename_no_ext(char *file) 
{
    char *b = util_basename(file);
    char *e = strrchr(b,'.');
    if (e != NULL) {
        *e = '\0';
    }
    return b;
}

int is_nmt200()
{
    static int check=1;
    static int result;
    if (check) {
        check = 0;
        char *path = getenv("PATH");
        result = (path != NULL && strstr(path,"/opt/syb/sigma/bdj") != NULL);
    }
    return result;
}
int is_nmt100()
{
    return !is_nmt200();
}

int util_starts_with(char *a,char *b)
{
    if (!a) a = "";
    if (!b) b = "";
    while(*a == *b) {
        if (*b == '\0') return 1;
        a++;
        b++;
    }
    return *b == '\0';
}
char *util_strcasestr(char *a,char *b)
{
    if (!a) a = "";
    if (!b) b = "";

    char *aa;
    for ( aa = a ; *aa ; aa++ ) {

        char *p;
        p = aa;
        char *q = b;
        while(*p && tolower(*(unsigned char *)p) == tolower(*(unsigned char *)q) ) {
            p++;
            q++;
        }
        if (*q == '\0') return aa;
    }
    return NULL;
}

int util_starts_with_ignore_case(char *a,char *b)
{
    if (!a) a = "";
    if (!b) b = "";
    while(tolower(*(unsigned char *)a) == tolower(*(unsigned char *)b) ) {
        if (*b == '\0') return 1;
        a++;
        b++;
    }
    return *b == '\0';
}

int util_stat(char *path,struct STAT64 *st)
{
    int result = STAT64(path,st);
    if (result) {
        HTML_LOG(0,"stat error %d for [%s]",errno,path);
        HTML_LOG(0,"uid %d gid %d ",st->st_uid,st->st_gid);

    }
    return result;
}

char *expand_paths(Array *paths)
{
    char *result=NULL;
    if (paths) {
        int i;
        for(i = 0 ; i < paths->size ; i++ ) {
            char *tmp;
            char *f = replace_str(paths->array[i],"'","'\\''");

            ovs_asprintf(&tmp,"%s '%s'",NVL(result),f);
            FREE(f);
            FREE(result);
            result = tmp;
        }
    }
    return result;
}

void util_file_list_command(char *command_and_args,Array *paths)
{
    char *cmd;
    if (paths) {
        char *p = expand_paths(paths);
        ovs_asprintf(&cmd,"%s %s",command_and_args,p);
        FREE(p);
        util_system(cmd);
        FREE(cmd);
    }
}


// Delete a file using seperate process
void util_file_command(char *command_and_args,char *path)
{
    char *f = replace_str(path,"'","'\\''");
    char *cmd;
    ovs_asprintf(&cmd,"%s '%s'", command_and_args,f);
    util_system(cmd);
    FREE(cmd);
    FREE(f);
}

// recursive delete
int util_rm(char *path)
{

    int result=-1;
    struct STAT64 st;
    if (util_stat(path,&st) ) {
        

    } else if (S_ISREG(st.st_mode)) {

        result = unlink(path);
        HTML_LOG(1,"unlink [%s] = %d",path,result);

    } else if (S_ISDIR(st.st_mode)) {

        result = 0;
        DIR *d = opendir(path);
        if (d == NULL) {

            result = errno;

        } else {

            struct dirent *sub ;

            while(result == 0 && (sub = readdir(d)) != NULL) {

                if (sub->d_type == DT_REG ||
                    (sub->d_type == DT_DIR && strcmp(sub->d_name,".") && strcmp(sub->d_name,".."))) {
                    char *tmp;
                    ovs_asprintf(&tmp,"%s/%s",path,sub->d_name);
                    result = util_rm(tmp);
                    FREE(tmp);
                }
            }
            closedir(d);

            if (result == 0) {
                result = rmdir(path);
            }
        }
        HTML_LOG(1,"rmdir [%s] = %d",path,result);
    }
    return result;
}

int count_chr(char *str,char c)
{
    int count = 0;

    str = NVL(str);

    while((str=strchr(str,c)) != NULL) {
        count++;
        str++;
    }
    return count;
}

int exists_in_dir(char *dir,char *name)
{

    char *filename;
    int result = 0;

    ovs_asprintf(&filename,"%s/%s",dir,name);
    result = exists(filename);
    FREE(filename);
    return result;
}

// Append content is usually called when Oversight is not doing much itself, just handing off to another file.
// So use a big buffer. 100K
int append_content(FILE *from_fp,FILE *to_fp)
{
    int ret = 0;
#define CATBUFLEN 1000000
    char catbuf[CATBUFLEN+1];
    size_t bytes;
    if (from_fp && to_fp) {
        ret = 0;
        while((bytes=fread(catbuf,1,CATBUFLEN,from_fp)) > 0)  {
            if (fwrite(catbuf,1,bytes,to_fp) != bytes) {
                ret = errno;
                break;
            }
        }
        if (ret == 0) {
            ret = ferror(from_fp);
        }
    }
    return ret;
}

int util_system_htmlout(char *cmd)
{
    int ret = -1;
    char *t = "/tmp/ovs.XXXXXX";
    char *n = STRDUP(t);
    int fd;
    if ((fd = mkstemp(n)) == -1) {

        ret = errno;

    } else {

        close(fd);

        HTML_LOG(0,"filename[%s]",n);

        char *cmd2;
        ovs_asprintf(&cmd2,"%s > '%s'",cmd,n);
        ret = util_system(cmd2);
        FILE *in_fp = fopen(n,"r");
        if (in_fp) {
            append_content(in_fp,html_get_output());
            fclose(in_fp);
        }
        unlink(n);
        FREE(cmd2);
    }
    HTML_LOG(0,"util_system_htmlout=%d",ret);
    return ret;
}
int util_system(char *cmd)
{
    int result;
    HTML_LOG(1,"system %s",cmd);
    result = system(cmd);
    HTML_LOG(0,"exec[%s]=%d",cmd,result);
    return result;
}

Array *util_hashtable_keys(struct hashtable *h,int take_ownership_of_keys)
{
    if (h == NULL) return NULL;
    Array *a;
   
    if (take_ownership_of_keys) {
       a = array_new(free);
    } else {
       a = array_new(NULL);
    }
    struct hashtable_itr *itr;
    char *k,*v;
    for (itr = hashtable_loop_init(h) ; hashtable_loop_more(itr,&k,&v) ; ) {
        array_add(a,k);
    }
    return a;
}


char *util_day_static()
{
#define DAY_SIZE 20
    static char day[DAY_SIZE+1];
    time_t t;
    time(&t);
    strftime(day,DAY_SIZE,"%a.%P",localtime(&t));
    return day;
}

void replace_char(char *string,char in,char out)
{
    if (string) {
        char *p = string;
        while ((p = strchr(p,in)) != NULL) {
            *p = out;
        }
    }
}

// Escape all meta characters in input string.
// If no change the SAME string is returned.
char *escape(char *in,char esc,char *meta)
{
    char *out,*inp,*outp=NULL;
   
    out =  inp = in;

    if (in) {
        while(*inp) {
            if (strchr(meta,*inp) || *inp == esc ) {
                outp = out = MALLOC(2*strlen(in)+1);
                break;
            }
            inp++;
        }
        if (out != in) {

            // copy string up to first meta char
            memcpy(outp,in,inp-in);
            outp += (inp-in);

            // copy rest of string  - escaping meta chars 
            while (*inp) {

                if ( *inp == esc ) {

                    *outp++ = *inp++;

                } else if(strchr(meta,*inp)) {

                    *outp++ = esc;
                }
                *outp++ = *inp++;

            }
            *outp = '\0';
        }
    }
    return out;
}
/**
 * Remove escape characters from a string.
 * If no change the SAME string is returned.
 */
char *unescape(char *in,char esc)
{
    char *out,*inp,*outp=NULL;
   
    out =  inp = in;

    if (in) {

        while(*inp) {
            if (*inp == esc ) {
                outp = out = MALLOC(strlen(in)+1);
                break;
            }
            inp++;
        }
        if (out != in) {


            // copy string up to first esc char
            memcpy(outp,in,inp-in);
            outp += (inp-in);

            // copy rest of string  - removing escapes
            while (*inp) {

                if ( *inp == esc ) {

                    inp++;
                }
                *outp++ = *inp++;
            }
            *outp = '\0';
        }
    }
    return out;
}

// If no change the SAME string is returned.
char *clean_js_string(char *in)
{
    char *tmp;
    char *out = in;

    if (in == NULL) {
        return STRDUP("");
    } else {
        if (strstr(out,"&quot;")) {
            tmp = replace_str(out,"&quot;","\\'");
            if (out != in) FREE(out);
            out = tmp;
        }
        if (strstr(out,"&amp;")) {
            tmp = replace_str(out,"&amp;","&");
            if (out != in) FREE(out);
            out = tmp;
        }
        replace_char(out,'\r',' ');
        replace_char(out,'\n',' ');

        // Escape any quotes that are not already escaped
        // this allows multiple calls for clean_js_string
        tmp = escape(out,'\\',"'");
        if (tmp != out) {
            if (out != in) FREE(out);
            out = tmp;
        }
    }
    return out;
}
int is_dvd_image(char *file)
{
    char *p = file + strlen(file);

    return (strcasecmp(p-4,".iso")==0 || strcasecmp(p-4,".img") == 0);
}

int is_dvd_folder(char *file)
{
    char *p = file + strlen(file);

    return (p[-1] == '/' );
}

int is_dvd(char *file)
{
    return (is_dvd_image(file) || is_dvd_folder(file)) ;
}

char *file_name(char *path)
{
    char *result;
    if (path == NULL) {
        result = STRDUP("");
    } else {
        char *p,*end;
        end = p = path + strlen(path);
        if (p > path) {
            if (p[-1] == '/') {
                end --;
                p -= 2;
            }
            while(p >= path && *p != '/') {
                p--;
            }
            p++;
        }
        result = COPY_STRING(end-p,p);
        result[end-p]='\0';
    }
    return result;
}


// Return age of file in seconds. -1 = doesnt exist or error
int file_age(char *path)
{
    struct STAT64 s;
    if (util_stat(path,&s) == 0) {
        return time(NULL) - s.st_mtime;
    } else {
        return -1;
    }
}


char *timestamp_static()
{
#define DATE_BUF_SIZ 40
    static char date[DATE_BUF_SIZ];
    time_t t;
    struct tm *timep;
    timep = localtime(&t);
    strftime(date,DATE_BUF_SIZ,"%Y%m%d-%H%M%S",timep);
    return date;
}

char *util_change_extension(char *file,char *new_ext) 
{
    char *dot = strrchr(file,'.');
    char *result;
    if (dot) {
        ovs_asprintf(&result,"%.*s%s",dot-file,file,new_ext);
    } else {
        ovs_asprintf(&result,"%s%s",file,new_ext);
    }

    return result;

}
// When freeing the set use set_free(h);
void set_free(struct hashtable *h)
{
    if (h) {
        hashtable_destroy(h,1,0);
    }
}

struct hashtable *array_to_set(Array *args)
{
    int i;
    struct hashtable *h = NULL;
    if (args) {
        for(i= 0 ; i < args->size ; i++ ) {
            if (h == NULL) {
                h = string_string_hashtable("set",16);
            }
            hashtable_insert(h,STRDUP(args->array[i]),"1");
        }
    }
    return h;
}
// quick binary chop to search list.
// Returns index of item.
// -1 = not found.
//
#define BCHOP_NOT_FOUND -1
int bchop(int id,int size,int *ids)
{

    if (size == 0) return BCHOP_NOT_FOUND;

    // The range is usually much smaller than the number of possible ids.
    // So do boundary comparison first.
    if (id < ids[0] || id > ids[size-1] ) {
        return BCHOP_NOT_FOUND;
    }

    int min=0;
    int max=size;
    int mid;
    do {
        mid = (min+max) / 2;

        if (id < ids[mid] ) {

            max = mid;

        } else if (id > ids[mid] ) {

            min = mid + 1 ;

        } else {

            HTML_LOG(1,"found %d",ids[mid]);
            return mid;
        }
    } while (min < max);

    //HTML_LOG("not found %d",id);
    return BCHOP_NOT_FOUND;
}
int index_STRCMP(char *a,char *b)
{
    if (STARTS_WITH_THE(a)) a+= 4;
    if (STARTS_WITH_THE(b)) b+= 4;
    //if (strncasecmp(a,"the ",4)==0) a+= 4;
    //if (strncasecmp(b,"the ",4)==0) b+= 4;
    //return strcasecmp(a,b);
    return abet_strcmp(a,b,g_abet_title->abet);
}
char *donated_file()
{
    static char *file = NULL;
    if (file == NULL) {
        ovs_asprintf(&file,"%s/db/.donate",appDir());
    }
    return file;
}

int util_touch(char *path,time_t t)
{
    int ret = 0;
    FILE *f = fopen(path,"a");
    if (f) {
        fclose(f);
        permissions(nmt_uid(),nmt_gid(),0775,0,path);

        struct utimbuf ut;
        ut.actime = ut.modtime = t;

        if (utime(path,&ut) != 0) {
            ret = errno;
        }
    } else {
        ret = errno;
    }
    return ret;
}
// Return offset to n'th utf8 character. 
// If not present return pointer to end
// utf8pos("ab",0) = "ab"
// utf8pos("ab",2) = ""
char *utf8pos(char *p,int n)
{

    if (p) {
        while (n>0) {

            if (*p > 0 ) {
                p++;
            } else if (!*p) {
                break;
            } else {
                // high bit character - assume first one is the chracter ans skip the continuation ones
                p++;
                while (( *p & 0xC0 ) == 0x80 ) {
                    p++;
                }
            }
            n--;
        }
    }
    return p;
}

/*
 * contents are overwritten must not be freed
 * Supports 3 different static strings.
 *
 */
char *xmlstr_static(char *text,int idx)
{
    static char *out[3]={NULL,NULL,NULL};
    static int free_last[3] = {0,0,0};

    static char *x[4]= { "&" ,     "<" ,    ">" ,   NULL};
    static char *y[4]= { "&amp;" , "&lt;" , "&gt" , NULL};

    if (out[idx] && free_last[idx]) {
        FREE(out[idx]);
        free_last[idx]=0;
    }
    text = NVL(text);
    out[idx] = text;
    int i;
    for(i = 0 ; x[i] ; i++ ) {
        if (strchr(out[idx],x[i][0])) {
            char *tmp = replace_str(out[idx],x[i],y[i]);
            if (out[idx] != text) FREE(out[idx]);
            out[idx] = tmp;
        }
    }
    free_last[idx] =  (out[idx] != text);

    return out[idx];
}

int current_year()
{
    static int y=0;
    if (y == 0) {
        time_t t = time(NULL);
        struct tm *now = localtime(&t);
        y = now->tm_year+1900;
    }
    return y;
}

time_t file_time(char *path)
{
    struct STAT64 s;
    if (STAT64(path,&s) == 0) {
        return s.st_mtime;
    } else {
        return 0;
    }
}
// vi:sw=4:et:ts=4
