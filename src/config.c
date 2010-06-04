// $Id:$
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


int rename_cfg(char *old,char *new);
int set_option(char *file,char *name,char *new_value);

// Load all config files excep unpak.cfg - that is loaded on-demand by unpak_val()
void load_ovs_configs()
{
    g_oversight_config =
        config_load_wth_defaults(appDir(),"conf/.oversight.cfg.defaults","conf/oversight.cfg");

    g_catalog_config =
        config_load_wth_defaults(appDir(),"conf/.catalog.cfg.defaults","conf/catalog.cfg");

}

void load_configs()
{
    load_ovs_configs();

    g_nmt_settings = config_load("/tmp/setting.txt",1);

}

void reload_configs()
{
    HTML_LOG(0,"reload configs");
    // small leak here in not freeing the hashtable values.
    hashtable_destroy(g_oversight_config,0,0);
    hashtable_destroy(g_catalog_config,0,0); 

    load_ovs_configs();
    config_read_dimensions();
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

long allow_access(char *config_name) {
    long result;
    result=0;
    if (browsing_from_lan()) {
        result=1;
    } else if (!config_check_long(g_oversight_config,config_name,&result)) {
        result=0;
    }
    HTML_LOG(0,"allow %s = %d",config_name,result);
    return result;
}
long allow_mark() {
    static long result = -1;
    if (result == -1) result = allow_access("ovs_wan_mark");
    return result;
}

long allow_delete() {
    static long result = -1;
    if (result == -1) result = allow_access("ovs_wan_delete");
    return result;
}

long allow_delist() {
    static long result = -1;
    if (result == -1) result = allow_access("ovs_wan_delist");
    return result;
}

long allow_admin() {
    static long result = -1;
    if (result == -1) result = allow_access("ovs_wan_admin");
    return result;
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

// include_unquoted_space option is for /tmp/setting.txt other config files always quote space.
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

int is_comment(char *line) {
    while(*line && isspace(*line)) {
        line++;
    }
    return (*line == '#');
}

int parse_key_val(char *line,
        int include_unquoted_space,
        char **key_p,char **keyend_p,
        char **val_p,char **valend_p)
{

    int ret=0;
    char *key = NULL;
    char *val = NULL;

    if ( (*line == ' ' || *line == '\t' || *line == '#' ) && is_comment(line)) {

        // comment
        ret = 0;

    } else {

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
                    *key_p = key;
                    *val_p = val;
                    *keyend_p = key_end;
                    *valend_p = val_end;
                    ret = 1;
                }
            }
        }
    }
    return ret;
}


#define CFG_BUFSIZ 700
// include_unquoted_space option is for /tmp/setting.txt other config files always quote space.
struct hashtable *config_load_fp(FILE *fp,int include_unquoted_space) {

    struct hashtable *result=string_string_hashtable(16);
    char line[CFG_BUFSIZ+1];

    PRE_CHECK_FGETS(line,CFG_BUFSIZ);

    while((fgets(line,CFG_BUFSIZ,fp))) {

        CHECK_FGETS(line,CFG_BUFSIZ);

        char *key,*val,*keyend,*valend;

        if (parse_key_val(line,include_unquoted_space,&key,&keyend,&val,&valend) ) {

            *keyend = *valend = '\0';

            hashtable_insert(result,STRDUP(key),STRDUP(val));
        }

    }
    return result;
}

// Add delta to a dimension value. 0=success
int ovs_config_increment(char *name,char *delta_str,int min,int max) 
{
    int ret = 1;
    char *file;

HTML_LOG(0,"ovs_config_increment(%s,%s)",name,delta_str);

    ovs_asprintf(&file,"%s/conf/oversight.cfg",appDir());


    char *old_val;
    old_val=oversight_val(name);
HTML_LOG(0,"ovs_config_increment old val %s = (%s)",name,old_val);
    if (old_val != NULL) {

        int v;
        int delta;
        if (util_starts_with(delta_str,QUERY_ASSIGN_PREFIX)) {
            v = atoi(delta_str+strlen(QUERY_ASSIGN_PREFIX));
        } else {
            delta = atoi(delta_str);
            v = atoi(old_val) + delta;
        }

        if (v < min) {
            v = min;
        } else if (v > max) {
             v = max;
        }

        char *new_val;
        ovs_asprintf(&new_val,"%d",v);
        ret = set_option(file,name,new_val);
        FREE(new_val);
    } else {
        html_error("Unable to find [%s] setting",name);
    }
    FREE(file);
    return ret;
}

int ovs_config_dimension_inherit(char *keyword_prefix) 
{
    return ovs_config_dimension_increment(keyword_prefix,"="INHERIT_DIMENSION_STR,INHERIT_DIMENSION,INHERIT_DIMENSION);
}

int ovs_config_dimension_increment(char *keyword_prefix,char* delta_str,int min,int max) 
{
    char *name;
HTML_LOG(0,"ovs_config_dimension_increment(%s,%s)",keyword_prefix,delta_str);
    ovs_asprintf(&name,"%s[%s]",keyword_prefix,g_dimension->set_name);
    int ret=ovs_config_increment(name,delta_str,min,max);
    FREE(name);
    return ret;
}

// 0 = success
int set_option(char *file,char *name,char *new_value)
{
    HTML_LOG(0,"set_option(%s,%s,%s)",file,name,new_value);

    int set_err = 1;
    char *tmp_file;
    char *old_file;
    int pid = getpid();
    int namelen = strlen(name);

    ovs_asprintf(&tmp_file,"%s.%d.tmp",file,pid);
    ovs_asprintf(&old_file,"%s.old",file);

    FILE *tmp_fp = NULL;
    FILE *fp = fopen(file,"r");

    if (fp == NULL) {

        html_error("Failed to open(r)[%s]",file);

    } else {

        tmp_fp = fopen(tmp_file,"w");
        if (tmp_fp == NULL) {

            html_error("Failed to open(w) [%s]",tmp_file);

        } else {

            char line[CFG_BUFSIZ+1];
            PRE_CHECK_FGETS(line,CFG_BUFSIZ);
            while((fgets(line,CFG_BUFSIZ,fp))) {

                int keep=1;
                CHECK_FGETS(line,CFG_BUFSIZ);

                char *key,*val,*keyend,*valend;

                if (parse_key_val(line,0,&key,&keyend,&val,&valend) ) {

                    if (keyend-key == namelen && util_starts_with(key,name)) {
                        keep=0;
                        fprintf(tmp_fp,"%s=\"%s\"\n",name,new_value);
                        set_err = 0;
                    }
                }
                if (keep) {
                    // preserve line
                    fprintf(tmp_fp,"%s",line);
                }

            }
            if (set_err) {
                // not found. Write it at the end.
                fprintf(tmp_fp,"%s=\"%s\"\n",name,new_value);
                set_err = 0;
            }
        }
    }

    if (fp) fclose(fp);
    if (tmp_fp) fclose(tmp_fp);

    if (!set_err) {
        if (rename_cfg(file,old_file) != 0) {
            set_err = 2;
        } else if (rename(tmp_file,file) != 0) {
            set_err = 3;
            rename_cfg(old_file,file); // try to undo
        }
    }
    return set_err;
}

// 0 = success
int rename_cfg(char *old,char *new)
{
    int ret;
    if ((ret = rename(old,new)) != 0) {
        html_error("Error renaming [%s] to [%s]",old,new);
    }
    return ret;
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

/* read mandatory array variable from config - eg key[index]=value 1=good else halt
 * If the value is -1 then set it to the inherit value */
int config_get_long_indexed_inherit(struct hashtable *h,char *k,char *key_suffix,char *index,long inherit_value,long *out) {
/* read mandatory array variable from config - eg key[index]=value */
    char *full_key;
    ovs_asprintf(&full_key,"%s%s",NVL(k),NVL(key_suffix));

    int ret = config_get_long_indexed(h,full_key,index,out);
    if (*out == INHERIT_DIMENSION) {
        *out = inherit_value;
    }
    FREE(full_key);
    return ret;
}

/* read optional array variable from config - eg key[index]=value 1=good  else halt */
int config_get_long_indexed(struct hashtable *h,char *k,char *index,long *out) {

    int result = config_check_long_indexed(h,k,index,out);
    if (!result) {
        html_error("ERROR: missing config int entry {%s[%s]}",k,index);
        exit(1);
    }
    HTML_LOG(4,"%s[%s] = %ld result %d",k,index,*out,result);
    return result;
}

/* read optional array variable from config - eg key[index]=value 1=good 0=bad */
int config_check_long_indexed(struct hashtable *h,char *k,char *index,long *out) {
    char *s ;
    int result=0;
    //HTML_LOG(4,"Checking long [%s[%s]]",k,index);
    if (ovs_asprintf(&s,"%s[%s]",k,index) >= 0 ) {
        result = config_check_long(h,s,out);
//        if (result == 0 ) {
//            // If looking for some_name_movieboxet[index] then try some_name[index]
//           if ((p = strstr(k,"_tvboxset")) != NULL || (p = strstr(k,"_movieboxset")) != NULL ) {
//               char *short_key
//           }
//       }
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
                // 720 modes.
                scanlines = 720;
            } else {
                // tv is 1080 but browser is still 720
                scanlines = 720;
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
//
//  
void config_get_grid_dimensions(
        struct hashtable *config_hash,
        char *key_suffix, // eg "" _tvboxset _movieboxset
        int grid_index // GRID_MAIN, GRID_MOVIEBOXSET etc.
        ) {

    config_get_long_indexed_inherit(config_hash,"ovs_poster_mode_rows",
            key_suffix,  
            g_dimension->set_name, // eg sd , hd, pc
            g_dimension->grids[GRID_MAIN].rows,&(g_dimension->grids[grid_index].rows));

    config_get_long_indexed_inherit(config_hash,"ovs_poster_mode_cols",
            key_suffix, 
            g_dimension->set_name, // eg sd , hd, pc
            g_dimension->grids[GRID_MAIN].cols,&(g_dimension->grids[grid_index].cols));

    config_get_long_indexed_inherit(config_hash,"ovs_poster_mode_height",
            key_suffix,
            g_dimension->set_name, // eg sd , hd, pc
            g_dimension->grids[GRID_MAIN].img_height,&(g_dimension->grids[grid_index].img_height));

    config_get_long_indexed_inherit(config_hash,"ovs_poster_mode_width",
            key_suffix,
            g_dimension->set_name, // eg sd , hd, pc
            g_dimension->grids[GRID_MAIN].img_width,&(g_dimension->grids[grid_index].img_width));
}


void config_read_dimensions() {

    int ar_fixed = 0;

    
    html_comment("read dimensions");

    char *addr = getenv("REMOTE_ADDR");

    g_dimension = MALLOC(sizeof(Dimensions));

    g_dimension->local_browser = (addr == NULL || STRCMP(addr,"127.0.0.1") == 0);

    html_comment("local browser = %d",g_dimension->local_browser);
    //g_dimension->local_browser = 1;

    g_dimension->scanlines = get_scanlines(&(g_dimension->is_pal));

    html_comment("scanlines=[%ld] ispal = %d",g_dimension->scanlines,g_dimension->is_pal);


    if (!g_dimension->local_browser) {
        g_dimension->set_name = STRDUP("pc");
    } else {
        ovs_asprintf(&(g_dimension->set_name),"%ld",g_dimension->scanlines);
    }


    html_comment("g_dimension->set_name=[%s]",g_dimension->set_name);

    if (g_oversight_config == NULL) {
        HTML_LOG(0,"No oversight config read");
    } else {
        config_get_long_indexed(g_oversight_config,"ovs_font_size",g_dimension->set_name,&(g_dimension->font_size));
        config_get_long_indexed(g_oversight_config,"ovs_title_size",g_dimension->set_name,&(g_dimension->title_size));
        config_get_long_indexed(g_oversight_config,"ovs_movie_poster_height",g_dimension->set_name,&(g_dimension->movie_img_height));
        config_get_long_indexed(g_oversight_config,"ovs_tv_poster_height",g_dimension->set_name,&(g_dimension->tv_img_height));
        config_get_long_indexed(g_oversight_config,"ovs_max_plot_length",g_dimension->set_name,&(g_dimension->max_plot_length));
        config_get_long_indexed(g_oversight_config,"ovs_button_size",g_dimension->set_name,&(g_dimension->button_size));
        config_get_long_indexed(g_oversight_config,"ovs_certificate_size",g_dimension->set_name,&(g_dimension->certificate_size));
        config_get_long_indexed(g_oversight_config,"ovs_poster_mode",g_dimension->set_name,&(g_dimension->poster_mode));

        g_dimension->current_grid = &(g_dimension->grids[GRID_MAIN]);


        if (!g_dimension->poster_mode) {

            config_get_long_indexed(g_oversight_config,"ovs_rows",g_dimension->set_name,&(g_dimension->text_rows));
            config_get_long_indexed(g_oversight_config,"ovs_cols",g_dimension->set_name,&(g_dimension->text_cols));
            // Force all boxset views to use main menu dimensions. Otherwise we'd have to maintain another set of dimensions
            // for text mode tvboxsets and text mode movie boxsets which I think is not necessary. Text mode is really
            // obsoleted by now.
            g_dimension->current_grid->rows = g_dimension->text_rows;
            g_dimension->current_grid->cols = g_dimension->text_cols;

        } else {

            // set the current grid dimensions
            char *view = query_val(QUERY_PARAM_VIEW);
            if (STRCMP(view,VIEW_TVBOXSET) == 0) {
                g_dimension->current_grid = &(g_dimension->grids[GRID_TVBOXSET]);
            } else if (STRCMP(view,VIEW_MOVIEBOXSET) == 0) {
                g_dimension->current_grid = &(g_dimension->grids[GRID_MOVIEBOXSET]);
            }

            config_get_grid_dimensions(g_oversight_config,"",GRID_MAIN);

            config_get_grid_dimensions(g_oversight_config,"_tvboxset",GRID_TVBOXSET);
            config_get_grid_dimensions(g_oversight_config,"_movieboxset",GRID_MOVIEBOXSET);

        }

        // compute_auto_image_dimensions
        //
        double ntsc_fix = 8 / 7.0; // scale height by this amount
        double pal_fix = 576.0 / 480; // scale height by this amount

        if (g_dimension->poster_mode) {
            if (g_dimension->current_grid->img_height == 0) {
                //compute
                int lines=480;
                if (g_dimension->scanlines) lines=g_dimension->scanlines;

                html_comment("rows = %d\n",g_dimension->current_grid->rows);

                // Compute row height by first allowing for menu height.
                double virtual_rows;
                if (g_dimension->scanlines > 600 ) {
                    virtual_rows = g_dimension->current_grid->rows + 0.8 ;
                } else {
                    virtual_rows = g_dimension->current_grid->rows + 1.1 ;
                }

                int menu_height;
                if (g_dimension->scanlines == 0) {
                    // Need adjustment for Gaya SD modes on NMT otherwise vertical is squashed
                    ar_fixed = 1;
                    menu_height = 100;
                } else {
                    menu_height = 150;
                }
                g_dimension->current_grid->img_height = ( lines - menu_height ) / virtual_rows ;

            }

            if (g_dimension->current_grid->img_width == 0) {
                //compute from height
                g_dimension->current_grid->img_width =  g_dimension->current_grid->img_height / 1.5 ;
                if (ar_fixed) {
                    // Gaya has SD NTSC distortion a square appears 54w 48h
                    g_dimension->current_grid->img_height *= ntsc_fix;

                    if (g_dimension->is_pal) {
                        // Even worse PAL distortion.
                        // the height has been scaled to compensate for gaya bug. 
                        // Scale the width based on the original height!
                        g_dimension->current_grid->img_height *= pal_fix;
                    }
                }

            }
        }

        // For Tv and Movie detail view 
        g_dimension->movie_img_width = g_dimension->movie_img_height * 2 / 3;
        g_dimension->tv_img_width = g_dimension->tv_img_height * 2 / 3;
        if (g_dimension->is_pal) {
            g_dimension->movie_img_height *= pal_fix;
            g_dimension->tv_img_height *= pal_fix;
        }

        char *title_bar = oversight_val("ovs_title_bar");
        g_dimension->title_bar = 0;

        if (strcasecmp(title_bar,"poster_mode") == 0 || strcasecmp(title_bar,"always") == 0) {

            g_dimension->title_bar = g_dimension->poster_mode;
        }
    }
}


// vi:sw=4:et:ts=4