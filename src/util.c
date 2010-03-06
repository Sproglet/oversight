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

        if (STARTS_WITH_THE(str)) str+=4;

        hash = 5381;
        
        while ((c = *str++)) {
            /*Berstein*/
            //hash = ((hash << 5) + hash) + c; /* hash * 33 + c */
            /*LUA*/
            //hash ^= ((hash << 5) + (hash >> 2)) + c; 
            
            /* Case insensitive LUA */
            hash ^= ((hash << 5) + (hash >> 2)) + (c | 32); 
        }
    }

    return hash;
}
int stringcmp(void *a,void *b) {
    return STRCMP(a,b) ==0;
}

struct hashtable *string_string_hashtable(int size)
{

    return create_hashtable(size,stringhash,stringcmp);
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
char *replace_str(char *s_in,char *match,char *replace)
{
    char *tmp;
    char *p=NULL;
    char *out = s_in;
    int matchlen = strlen(match);
    int replen = strlen(replace);
    int offset=0;
    while((p = strstr(out+offset,match)) != NULL) {
        ovs_asprintf(&tmp,"%.*s%s%s",p-out,out,NVL(replace),p+matchlen);
        offset  = p-out + replen;
        if (out != s_in) FREE(out);
        out = tmp;
    }
    if (out == s_in) {
        out = STRDUP(s_in);
    }
    return out;
}
/*
 * Split a strin s_in into an array using regex pattern.
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
        assert(1);
    }
}
/* return position of regex in a string. NULL if no match  */
char *util_strreg(char *s,char *pattern,int reg_opts)
{
    assert(s);
    assert(pattern);

    regmatch_t pmatch[1];
    regex_t re;

    util_regcomp(&re,pattern,0);

    char *pos = NULL;

    if (regexec(&re,s,1,pmatch,0) == 0) {
        pos = s+pmatch[0].rm_so;
    }

    regfree(&re);
    return pos;
}

/*
 * Extract a single regex submatch
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
 * Match a regular expression and return the submatch'ed braketed pair 0=the entire match
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
                v = strdup((char *)v);
                assert(v);
            }

            if ( hashtable_change(h1,k,v) ) {
                HTML_LOG(3,"Changed [ %s ] = [ %s ]",k,v);
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
    struct hashtable *h = string_string_hashtable(16);

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
            *q++ = tolower(*s++);
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
void query_remove(char *name) {
    HTML_LOG(0,"Removing query item [%s]",name);
    if (hashtable_remove(g_query,name,1) == NULL) {
        HTML_LOG(5,"query item not present [%s]",name);
    }
}
void query_update(char *name,char *new)
{
    HTML_LOG(0,"Changing query item [%s] to [%s]",name,new);
    hashtable_remove(g_query,name,1);
    hashtable_insert(g_query,name,new);
}
     
char *query_val(char *name)
{
    char *val;
    if (config_check_str(g_query,name,&val)) {
        return val;
    } else {
        return "";
    }
}
char *catalog_val(char *name)
{
    char *val;
    if (config_check_str(g_catalog_config,name,&val)) {
        return val;
    } else {
        return "";
    }
}
char *oversight_val(char *name)
{
    char *val;
    if (config_check_str(g_oversight_config,name,&val)) {
        return val;
    } else {
        return "";
    }
}
char *setting_val(char *name)
{
    char *val;
    if (config_check_str(g_nmt_settings,name,&val)) {
        return val;
    } else {
        return "";
    }
}
char *unpak_val(char *name)
{
    char *val;

    if (g_unpack_config == NULL) {
        g_unpack_config = config_load_wth_defaults(appDir(),"conf/unpak.cfg.example","conf/unpak.cfg");
    }

    if (config_check_str(g_unpack_config,name,&val)) {
        return val;
    } else {
        return "";
    }
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

int is_nmt200()
{
    static int check=1;
    static int result;
    if (check) {
        check = 0;
        char *cpu_model = getenv("CPU_MODEL");
        result = (cpu_model != NULL && STRCMP(cpu_model,"74K") == 0);
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

void util_rmdir(char *path,char *name)
{
    char *full_path;
    ovs_asprintf(&full_path,"%s/%s",path,name);
    if (is_dir(full_path)) {
        DIR *d = opendir(full_path);
        if (d) {
            struct dirent *dp;
            while((dp = readdir(d)) != NULL) {
                if(STRCMP(dp->d_name,".") != 0 && STRCMP(dp->d_name,"..") != 0) {
                    util_rmdir(full_path,dp->d_name);
                }
            }
            closedir(d);
            HTML_LOG(1,"rmdir [%s]",full_path);
            rmdir(full_path);
        }
    } else {
        HTML_LOG(1,"unlink [%s]",full_path);
        unlink(full_path);
    }
    FREE(full_path);
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

int exists_file_in_dir(char *dir,char *name)
{

    char *filename;
    int result = 0;

    ovs_asprintf(&filename,"%s/%s",dir,name);
    result = is_file(filename);
    FREE(filename);
    return result;
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

char *clean_js_string(char *in)
{
    char *out = in;

    if (in != NULL) {
        if (strchr(out,'\'')) {
            char *tmp = replace_all(out,"'","\\'",0);
            if (out != in) FREE(out);
            out = tmp;
        }
        if (strstr(out,"&quot;")) {
            char *tmp = replace_all(out,"&quot;","\\'",0);
            if (out != in) FREE(out);
            out = tmp;
        }
        replace_char(out,'\r',' ');
        replace_char(out,'\n',' ');

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
    ovs_asprintf(&result,"%.*s%s",dot-file,file,new_ext);

    return result;

}
