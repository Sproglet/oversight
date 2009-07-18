#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "util.h"
#include "config.h"
#include "assert.h"
#include "hashtable_itr.h"

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


    if (hashtable_count(cfg)) {
        struct hashtable_itr *itr = hashtable_iterator(cfg) ;
        do {

            char *key = hashtable_iterator_key(itr);
            char *val = hashtable_iterator_value(itr);

            if (val) {
                fprintf(fp,"%s:%s\n",key,val);
            }
        } while(hashtable_iterator_advance(itr));
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
        printf(stderr,"loading [%s]\n",f);
        out = config_load(f);
    } else {
        out = string_string_hashtable();
    }
    free(f);

    // load the main settings
    f = malloc(strlen(d)+strlen(main_file)+3);
    sprintf(f,"%s/%s",d,main_file);

    if (is_file(f)) {
        printf(stderr,"loading [%s]\n",f);
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
                fprintf(stderr,"cfg add [ %s ] = [ %s ]\n",key,val);
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
    if (hashtable_count(cfg)) {
        struct hashtable_itr *itr = hashtable_iterator(cfg);
        do {
            char *k = hashtable_iterator_key(itr);
            char *v = hashtable_iterator_value(itr);
            char *v2 = hashtable_search(cfg2,k);
            assert(v2);
            assert(strcmp(v,v2) == 0);
            printf("%s:%s\n",k,v);
        } while(hashtable_iterator_advance(itr));
    }
}




