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
    ovs_asprintf(&f,"%s/%s",d,defaults_file);

    if (is_file(f)) {
        fprintf(stderr,"loading [%s]\n",f);
        out = config_load(f);
    } else {
        out = string_string_hashtable();
    }
    free(f);

    // load the main settings
    f = MALLOC(strlen(d)+strlen(main_file)+3);
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

//gets mandatory string config value via out : returns 1 aborts if not found
int config_get_str(struct hashtable *h,char *key,char **out) {
    int result = config_check_str(h,key,out);
    if (!result) {
        html_error("ERROR: missing config string entry {%s}",key);
        exit(1);
    }
    return result;
}
//gets optional string config value via out : returns 1 if found 0 if not
int config_check_str(struct hashtable *h,char *key,char **out) {
    html_log(3,"Checking string [%s]",key);
    *out =  hashtable_search(h,key);
    html_log(3,"Checked string [%s] = [%s]",key,*out);
    return (*out != NULL);
}

//gets mandatory integer config value via out : returns 1 if found 0 if not
int config_get_long(struct hashtable *h,char *key,long *out) {
    int result = config_check_long(h,key,out);
    if (!result) {
        html_error("ERROR: missing config long entry {%s}",key);
        exit(1);
    }
    return result;
}

//gets optional integer config value via out : returns 1 if found 0 if not
int config_check_long(struct hashtable *h,char *key,long *out) {
    char *s,*end;
    long val;
    html_log(3,"Checking long [%s]",key);
    if (config_check_str(h,key,&s) == 0) {
        return 0;
    }
    val=strtol(s,&end,10);
    html_log(3,"Checked long [%s]=%ld",key,val);
    if (*s != '\0' && *end != '\0') {
        html_error("ERROR: Integer conversion error for [%s] = [%s]",key,s);
        exit(1);
    }
    *out = val;
    return 1;
}

/* read mandatory array variable from config - eg key[index]=value */
int config_get_str_indexed(struct hashtable *h,char *k,char *index,char **out) {
    int result = config_check_str_indexed(h,k,index,out);
    if (!result) {
        html_error("ERROR: missing config string entry {%s[%s]}",k,index);
        exit(1);
    }
    return result;
}
/* read optional array variable from config - eg key[index]=value */
int config_check_str_indexed(struct hashtable *h,char *k,char *index,char **out) {
    char *s ;
    int result=0;
    if (ovs_asprintf(&s,"%s[%s]",k,index) >= 0 ) {
        result = config_check_str(h,s,out);
        free(s);
    }
    return result;
}

/* read mandatory array variable from config - eg key[index]=value */
int config_get_long_indexed(struct hashtable *h,char *k,char *index,long *out) {

    int result = config_check_long_indexed(h,k,index,out);
    if (!result) {
        html_error("ERROR: missing config int entry {%s[%s]}",k,index);
        exit(1);
    }
    html_log(3,"%s[%s] = %ld result %d",k,index,*out,result);
    return result;
}

/* read optional array variable from config - eg key[index]=value */
int config_check_long_indexed(struct hashtable *h,char *k,char *index,long *out) {
    char *s ;
    int result=0;
    html_log(3,"Checking long [%s[%s]]",k,index);
    if (ovs_asprintf(&s,"%s[%s]",k,index) >= 0 ) {
        result = config_check_long(h,s,out);
        free(s);
    }
    return result;
}

long get_scanlines(struct hashtable *nmt_settings,int *is_pal) {
    long scanlines = 0;
    char *tv_mode = hashtable_search(nmt_settings,"video_output");
    int tv_mode_int = atoi(tv_mode);

    if (tv_mode_int == 6 || tv_mode_int == 10 || tv_mode_int == 13 ) {
        scanlines = 720;
    } else if (tv_mode_int <= 5 || ( tv_mode_int >= 7 && tv_mode_int <= 9 )  || ( tv_mode_int >= 30 && tv_mode_int <= 31 )) {
        scanlines = 0;
    } else {
        scanlines = 1080;
    }
    // NMT does not use correct aspect ratio for gaya on PAL. Video Playback is OK but gaya is squashed
    if (is_pal) {
        *is_pal = (tv_mode_int == 2 || tv_mode_int == 4 || tv_mode_int == 30);
    }
     return scanlines;
}

void config_read_dimensions(struct hashtable *ovs_cfg,struct hashtable *nmt_cfg,Dimensions *dim) {

    char scanlines_str[9];
    long scanlines;
    int is_pal;
    int pal_fixed = 0;

    html_comment("read dimensions");
    dim->scanlines = scanlines = get_scanlines(nmt_cfg,&is_pal);

    html_comment("scanlines=[%ld] ispal = %d",scanlines,is_pal);

    sprintf(scanlines_str,"%ld",scanlines);
    html_comment("scanlinesstr=[%]",scanlines_str);

    config_get_long_indexed(ovs_cfg,"ovs_font_size",scanlines_str,&(dim->font_size));
    config_get_long_indexed(ovs_cfg,"ovs_title_size",scanlines_str,&(dim->title_size));
    config_get_long_indexed(ovs_cfg,"ovs_movie_poster_width",scanlines_str,&(dim->movie_img_width));
    config_get_long_indexed(ovs_cfg,"ovs_tv_poster_width",scanlines_str,&(dim->tv_img_width));
    config_get_long_indexed(ovs_cfg,"ovs_max_plot_length",scanlines_str,&(dim->max_plot_length));
    config_get_long_indexed(ovs_cfg,"ovs_button_size",scanlines_str,&(dim->button_size));
    config_get_long_indexed(ovs_cfg,"ovs_certificate_size",scanlines_str,&(dim->certificate_size));
    config_get_long_indexed(ovs_cfg,"ovs_poster_mode",scanlines_str,&(dim->poster_mode));
    if (dim->poster_mode) {
        config_get_long_indexed(ovs_cfg,"ovs_poster_mode_rows",scanlines_str,&(dim->rows));
        config_get_long_indexed(ovs_cfg,"ovs_poster_mode_cols",scanlines_str,&(dim->cols));
        config_get_long_indexed(ovs_cfg,"ovs_poster_mode_height",scanlines_str,&(dim->poster_menu_img_height));
        config_get_long_indexed(ovs_cfg,"ovs_poster_mode_width",scanlines_str,&(dim->poster_menu_img_width));
    } else {
        config_get_long_indexed(ovs_cfg,"ovs_rows",scanlines_str,&(dim->rows));
        config_get_long_indexed(ovs_cfg,"ovs_cols",scanlines_str,&(dim->cols));
    }

    if (dim->poster_menu_img_height == 0) {
        //compute
        int lines=500;
        if (scanlines) lines=scanlines;

        html_comment("rows = %d\n",dim->rows);
        dim->poster_menu_img_height = lines/ dim->rows + 1.6 ;

        if (is_pal) {
            // Need adjustment for Gaya PAL mode on NMT otherwise vertical is squashed
            dim->poster_menu_img_height *= ( 576 / 480 );
            pal_fixed = 1;
        }
    }

    if (dim->poster_menu_img_width == 0) {
        //compute from height
        dim->poster_menu_img_width =  dim->poster_menu_img_height / 1.5 ;
        if (pal_fixed) {
            // the height has been scaled to compensate for gaya bug. 
            // Scale the width based on the original height!
            dim->poster_menu_img_width *= ( 480 / 576 );
        }
    }


}


