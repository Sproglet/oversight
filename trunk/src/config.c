#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "oversight.h"
#include "util.h"
#include "config.h"
#include "assert.h"
#include "hashtable_loop.h"
#include "gaya_cgi.h"
#include "vasprintf.h"

int in_poster_mode() {
    return g_dimension->poster_mode != 0 ;
}

int in_text_mode() {
    return g_dimension->poster_mode  == 0;
}

int browsing_from_lan() {
    static int result = -1;
    if (result == -1) {
        result = 0;
        if (g_dimension->local_browser) {
            result = 1;
        } else {
            char *ip = getenv("REMOTE_ADDR");
            if (ip) {
                if (util_starts_with(ip,"192.168.") ||
                    util_starts_with(ip,"10.")  ||
                    ( util_starts_with(ip,"172.")  &&
                    util_strreg(ip,"172\\.([0-9]|[12][0-9]|3[01])\\.",0) != NULL ) ) {
                    result = 1;
                }
            }
        }
        HTML_LOG(0,"browsing from lan = %d",result);
    }
    return result;
}

static long allow_access(char *config_name) {
    static long result=-1;
    if (result == -1) {
        result=0;
        if (browsing_from_lan()) {
            result=1;
        } else if (!config_check_long(g_oversight_config,config_name,&result)) {
            result=0;
        }
        HTML_LOG(0,"allow %s = %d",config_name,result);
    }
    return result;
}
long allow_mark() {
    return allow_access("ovs_wan_mark");
}
long allow_delete() {
    return allow_access("ovs_wan_delete");
}
long allow_delist() {
    return allow_access("ovs_wan_delist");
}
long allow_admin() {
    return allow_access("ovs_wan_admin");
}

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
        out = config_load(f,0);
    } else {
        out = string_string_hashtable(16);
    }
    FREE(f);

    // load the main settings
    f = MALLOC(strlen(d)+strlen(main_file)+3);
    sprintf(f,"%s/%s",d,main_file);

    if (is_file(f)) {
        new = config_load(f,0);
    } else {
        new = string_string_hashtable(16);
    }
    FREE(f);

    merge_hashtables(out,new,1);

    return out;

}

struct hashtable *config_load(char *filename,int include_unquoted_space) {

    assert(filename);
    struct hashtable *result=NULL;

    HTML_LOG(0,"load config [%s]",filename);
    FILE *f = fopen(filename,"r");

    if (f == NULL) {
        fprintf(stderr,"Unable to open config file [%s]\n",filename);
    } else {
        result = config_load_fp(f,include_unquoted_space);
        fclose(f);
    }
    return result;
}

#define CFG_BUFSIZ 700
struct hashtable *config_load_fp(FILE *fp,int include_unquoted_space) {

    struct hashtable *result=string_string_hashtable(16);
    char line[CFG_BUFSIZ+1];

    PRE_CHECK_FGETS(line,CFG_BUFSIZ);

    while((fgets(line,CFG_BUFSIZ,fp))) {

        CHECK_FGETS(line,CFG_BUFSIZ);

        if ( (line[0] == ' ' || line[0] == '\t' || line[0] == '#' ) && util_strreg(line,"^\\s*#",0)) {
            //skip comment
        } else {
            char *key = NULL;
            char *val = NULL;


            // key = value where value = X....X or just X (where X= ^space )
            // \x5b = [ \x5d = ]
            //
            char *p = line;
            while (isspace(*p)) p++;
            key = p;
            while (isalnum(*p) || (*p && strchr("_.[]",*p))) {
                p++;
            }
            char *key_end = p;


            while(isspace(*p)) p++;
            if (*p == '=' || *p == ':' ) {

                char *val_end = NULL;

                p++;
                while(isspace(*p)) p++;
                val = p;
                if (*val && strchr("\"'",*val) ) {
                    //parse quoted value
                    p++;
                    while (*p && *p != *val) p++;
                    if (*p == *val) {
                        val++;
                        val_end=p;
                        p++;
                    }
                } else {
                    //parse unquoted value
                    while(*p && (!isspace(*p) || (include_unquoted_space && *p == ' ') )) {
                        p++;
                    }
                    val_end = p;
                }

                if (!include_unquoted_space) {
                    while(isspace(*p) || *p == ';') {
                        p++;
                    }
                }

                if (*p == '#') {
                    // skip trailing comment
                    while(*p >= ' ' || isspace(*p)) p++;
                }

                if (val_end && strchr("\n\r",*p)) {

                    if (key && val && key_end > key ) {
                        *key_end = *val_end = '\0';
                        //HTML_LOG(1,"setting [%s]=[%s]",key,val);
                        hashtable_insert(result,STRDUP(key),STRDUP(val));
                    }
                }
            }

        }
    }
    return result;
}

void config_unittest() {
    struct hashtable *cfg = config_load("test.cfg",0);
    config_write(cfg,"delete.cfg");
    struct hashtable *cfg2 = config_load("delete.cfg",0);

    char *k,*v;
    struct hashtable_itr *itr = hashtable_loop_init(cfg) ;

    while(hashtable_loop_more(itr,&k,&v)) {

        char *v2 = hashtable_search(cfg2,k);
        assert(v2);
        assert(STRCMP(v,v2) == 0);
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
    //HTML_LOG(4,"Checking string [%s]",key);
    *out =  hashtable_search(h,key);
    //HTML_LOG(4,"Checked string [%s] = [%s]",key,*out);
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
    //HTML_LOG(4,"Checking long [%s]",key);
    if (config_check_str(h,key,&s) == 0) {
        return 0;
    }
    val=strtol(s,&end,10);
    HTML_LOG(4,"Checked long [%s]=%ld",key,val);
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
        FREE(s);
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
    HTML_LOG(4,"%s[%s] = %ld result %d",k,index,*out,result);
    return result;
}

/* read optional array variable from config - eg key[index]=value */
int config_check_long_indexed(struct hashtable *h,char *k,char *index,long *out) {
    char *s ;
    int result=0;
    //HTML_LOG(4,"Checking long [%s[%s]]",k,index);
    if (ovs_asprintf(&s,"%s[%s]",k,index) >= 0 ) {
        result = config_check_long(h,s,out);
        FREE(s);
    }
    return result;
}

long get_scanlines(int *is_pal) {
    long scanlines = 0;
    int tv_mode_int = 0;

    if (g_dimension->local_browser) {
        //Localbrowser- get resolution
        char *tv_mode = hashtable_search(g_nmt_settings,"video_output");
        tv_mode_int = atoi(tv_mode);
        HTML_LOG(0,"tvmode = %d",tv_mode_int);
    }

    if (is_nmt100()) {
        if (!g_dimension->local_browser) {
            //Remote browser
            tv_mode_int = 6; 
            scanlines= 720;
        } else {
            if (tv_mode_int == 6 || tv_mode_int == 10 || tv_mode_int == 13 || tv_mode_int == 16 ) {
                scanlines = 720;
            } else if (tv_mode_int <= 5 || ( tv_mode_int == 9 )  || ( tv_mode_int >= 30 && tv_mode_int <= 31 )) {
                scanlines = 0;
            } else {
                // Note that NMT A series does not have a true 1080p but scales up 720
                scanlines = 720;
            }
        }
        if (is_pal) {
            *is_pal = g_dimension->local_browser && (tv_mode_int == 2 || tv_mode_int == 4 || tv_mode_int == 30);
        }
    } else {
        if (!g_dimension->local_browser) {
            //Remote browser
            tv_mode_int = 6; 
            scanlines= 720;
        } else {
            if (tv_mode_int <= 4 ) {
                scanlines = 0;
            } else if (tv_mode_int <= 6 ) {
                scanlines = 720;
            } else {
                scanlines = 1080;
            }
        }
        if (is_pal) {
            *is_pal = g_dimension->local_browser && (tv_mode_int == 2 || tv_mode_int == 4 );
        }
    }

    g_dimension->tv_mode = tv_mode_int;

    // NMT does not use correct aspect ratio for gaya on PAL. Video Playback is OK but gaya is squashed
     return scanlines;
}

void config_read_dimensions() {

    char scanlines_str[9];
    int ar_fixed = 0;

    
    html_comment("read dimensions");

    char *addr = getenv("REMOTE_ADDR");

    g_dimension = MALLOC(sizeof(Dimensions));

    g_dimension->local_browser = (addr == NULL || STRCMP(addr,"127.0.0.1") == 0);

    html_comment("local browser = %d",g_dimension->local_browser);
    //g_dimension->local_browser = 1;

    g_dimension->scanlines = get_scanlines(&(g_dimension->is_pal));

    html_comment("scanlines=[%ld] ispal = %d",g_dimension->scanlines,g_dimension->is_pal);

    sprintf(scanlines_str,"%ld",g_dimension->scanlines);


    html_comment("scanlines_str=[%]",scanlines_str);

    if (g_oversight_config == NULL) {
        HTML_LOG(0,"No oversight config read");
    } else {
        config_get_long_indexed(g_oversight_config,"ovs_font_size",scanlines_str,&(g_dimension->font_size));
        config_get_long_indexed(g_oversight_config,"ovs_title_size",scanlines_str,&(g_dimension->title_size));
        config_get_long_indexed(g_oversight_config,"ovs_movie_poster_height",scanlines_str,&(g_dimension->movie_img_height));
        config_get_long_indexed(g_oversight_config,"ovs_tv_poster_height",scanlines_str,&(g_dimension->tv_img_height));
        config_get_long_indexed(g_oversight_config,"ovs_max_plot_length",scanlines_str,&(g_dimension->max_plot_length));
        config_get_long_indexed(g_oversight_config,"ovs_button_size",scanlines_str,&(g_dimension->button_size));
        config_get_long_indexed(g_oversight_config,"ovs_certificate_size",scanlines_str,&(g_dimension->certificate_size));
        config_get_long_indexed(g_oversight_config,"ovs_poster_mode",scanlines_str,&(g_dimension->poster_mode));
        if (g_dimension->poster_mode) {
            config_get_long_indexed(g_oversight_config,"ovs_poster_mode_rows",scanlines_str,&(g_dimension->rows));
            config_get_long_indexed(g_oversight_config,"ovs_poster_mode_cols",scanlines_str,&(g_dimension->cols));
            config_get_long_indexed(g_oversight_config,"ovs_poster_mode_height",scanlines_str,&(g_dimension->poster_menu_img_height));
            config_get_long_indexed(g_oversight_config,"ovs_poster_mode_width",scanlines_str,&(g_dimension->poster_menu_img_width));
        } else {
            config_get_long_indexed(g_oversight_config,"ovs_rows",scanlines_str,&(g_dimension->rows));
            config_get_long_indexed(g_oversight_config,"ovs_cols",scanlines_str,&(g_dimension->cols));
        }

        double ntsc_fix = 8 / 7.0; // scale height by this amount
        double pal_fix = 576.0 / 480; // scale height by this amount

        if (g_dimension->poster_menu_img_height == 0) {
            //compute
            int lines=480;
            if (g_dimension->scanlines) lines=g_dimension->scanlines;

            html_comment("rows = %d\n",g_dimension->rows);

            double virtual_rows = g_dimension->rows + 1.1;

            int menu_height;
            if (g_dimension->scanlines == 0) {
                // Need adjustment for Gaya SD modes on NMT otherwise vertical is squashed
                ar_fixed = 1;
                menu_height = 100;
            } else {
                menu_height = 150;
            }
            g_dimension->poster_menu_img_height = ( lines - menu_height ) / virtual_rows ;

        }

        if (g_dimension->poster_menu_img_width == 0) {
            //compute from height
            g_dimension->poster_menu_img_width =  g_dimension->poster_menu_img_height / 1.5 ;
            if (ar_fixed) {
                // Gaya has SD NTSC distortion a square appears 54w 48h
                g_dimension->poster_menu_img_height *= ntsc_fix;

                if (g_dimension->is_pal) {
                    // Even worse PAL distortion.
                    // the height has been scaled to compensate for gaya bug. 
                    // Scale the width based on the original height!
                    g_dimension->poster_menu_img_height *= pal_fix;
                }
            }
        }

        g_dimension->movie_img_width = g_dimension->movie_img_height * 2 / 3;
        g_dimension->tv_img_width = g_dimension->tv_img_height * 2 / 3;
        if (g_dimension->is_pal) {
            g_dimension->movie_img_height *= ( 576.0 / 480 );
            g_dimension->tv_img_height *= ( 576.0 / 480 );
        }

        char *title_bar = oversight_val("ovs_title_bar");
        g_dimension->title_bar = 0;

        if (strcasecmp(title_bar,"poster_mode") == 0 || strcasecmp(title_bar,"always") == 0) {

            g_dimension->title_bar = g_dimension->poster_mode;
        }
    }
}


