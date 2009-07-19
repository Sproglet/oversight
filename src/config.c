#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "util.h"
#include "config.h"
#include "assert.h"
#include "hashtable_loop.h"
#include "gaya_cgi.h"
#include "vasprintf.h"

void config_write(struct hashtable *cfg,char *filename) {

    assert(cfg);
    assert(filename);
    FILE *fp = fopen(filename,"w");
    if (fp == NULL) {
        fprintf(stderr,"Error opening [%s]\n",filename);
    } else {
        config_write_fp(cfg,fp);
        fclose(fp);
    }
}

void config_write_fp(struct hashtable *cfg,FILE *fp) {


    char *k,*v;
    struct hashtable_itr *itr = hashtable_loop_init(cfg) ;

    while (hashtable_loop_more(itr,&k,&v)) {

        if (v) {
            fprintf(fp,"%s:%s\n",k,v);
        }
    }
}

struct hashtable *config_load_wth_defaults(char *d,char *defaults_file,char *main_file) {

    char *f;
    struct hashtable *out = NULL;
    struct hashtable *new = NULL;
   
    // load the default settings
    f = malloc(strlen(d)+strlen(defaults_file)+3);
    sprintf(f,"%s/%s",d,defaults_file);
    if (is_file(f)) {
        fprintf(stderr,"loading [%s]\n",f);
        out = config_load(f);
    } else {
        out = string_string_hashtable();
    }
    free(f);

    // load the main settings
    f = malloc(strlen(d)+strlen(main_file)+3);
    sprintf(f,"%s/%s",d,main_file);

    if (is_file(f)) {
        fprintf(stderr,"loading [%s]\n",f);
        new = config_load(f);
    } else {
        new = string_string_hashtable();
    }
    free(f);

    merge_hashtables(out,new,1);

    return out;

}

struct hashtable *config_load(char *filename) {

    assert(filename);
    struct hashtable *result=NULL;
    FILE *f = fopen(filename,"r");

    if (f == NULL) {
        fprintf(stderr,"Unable to open config file [%s]\n",filename);
    } else {
        result = config_load_fp(f);
        fclose(f);
    }
    return result;
}

#define CFG_BUFSIZ 200
struct hashtable *config_load_fp(FILE *fp) {

    struct hashtable *result=string_string_hashtable();
    char line[CFG_BUFSIZ];

    while((fgets(line,CFG_BUFSIZ,fp))) {

        chomp(line);

        if (regpos(line,"^\\s*#") >= 0) {
            //skip comment
        } else {
            char *key = NULL;
            char *val = NULL;


            // key = value where value = X....X or just X (where X= ^space )
            // \x5b = [ \x5d = ]
            if ((key = regextract1(line,"^[[:space:]]*([][A-Za-z0-9_.]+)[=:]",1)) != NULL ) {


                if ((val = regextract1(line,"[=:][[:space:]]*([^[:space:]]?.*[^[:space:]])[[:space:]]*$",1)) != NULL) {
                    if (strlen(val)>=3 ) {
                        if (strchr("\"'",*val)) {
                            if (val[strlen(val)-1] == *val) {
                                //remove quotes
                                char *val2 = substring(val,1,strlen(val)-1);
                                free(val);
                                val = val2;
                            }
                        }
                    }
                }
            }

            if (key && val ) {
                //fprintf(stderr,"cfg add [ %s ] = [ %s ]\n",key,val);
                hashtable_insert(result,key,val);
            }

        }
    }
    return result;
}

void config_unittest() {
    struct hashtable *cfg = config_load("test.cfg");
    config_write(cfg,"delete.cfg");
    struct hashtable *cfg2 = config_load("delete.cfg");

    char *k,*v;
    struct hashtable_itr *itr = hashtable_loop_init(cfg) ;

    while(hashtable_loop_more(itr,&k,&v)) {

        char *v2 = hashtable_search(cfg2,k);
        assert(v2);
        assert(strcmp(v,v2) == 0);
        printf("%s:%s\n",k,v);

    }
}

//gets  string config value via out : returns 1 if found 0 if not
int config_get_str(struct hashtable *h,char *key,char **out) {
    *out =  hashtable_search(h,key);
    return (*out != NULL);
}

//gets  integer config value via out : returns 1 if found 0 if not
int config_get_int(struct hashtable *h,char *key,long *out) {
    char *s,*end;
    long val;
    if (config_get_str(h,key,&s) == 0) {
        return 0;
    }
    val=strtol(s,&end,10);
    if (*s != '\0' && *end == '\0') {
        html_comment("ERROR: Integer conversion error for [%s] = [%s]",s);
        return 0;
    }
    return 1;
}


/* read array variable from config - eg key[index]=value */
int config_get_str_indexed(struct hashtable *h,char *k,char *index,char **out) {
    char *s ;
    int result=0;
    if (ovs_asprintf(&s,"%s[%s]",k,index) >= 0 ) {
        result = config_get_str(h,s,out);
        free(s);
    }
    return result;
}

/* read array variable from config - eg key[index]=value */
int config_get_int_indexed(struct hashtable *h,char *k,char *index,long *out) {
    char *s ;
    int result=0;
    if (ovs_asprintf(&s,"%s[%s]",k,index) >= 0 ) {
        result = config_get_int(h,s,out);
        free(s);
    }
    return result;
}



