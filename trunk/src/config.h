#ifndef __CONFIG_H_ALORD__
#define __CONFIG_H_ALORD__

#include <stdio.h>
#include "hashtable.h"
#include "grid.h"
#include "types.h"


#define GRID_MAIN 0
#define GRID_TVBOXSET 1
#define GRID_MOVIEBOXSET 2


#define CONFIG_LABEL_TEXT "=>"


typedef struct dimension_str {
    int tv_mode;
    int is_pal;
    long scanlines;
    long poster_mode;
    long title_bar; //dynamic title bar.
    long local_browser;
    long text_rows;
    long text_cols;
    long font_size;
    long title_size;
    long movie_img_height;
    long movie_img_width;
    long tv_img_height;
    long tv_img_width;
    long max_plot_length;
    long button_size;
    long certificate_size;
    char *set_name; // eg 0=SD , 720=HD , pc=browser
    GridDimensions grids[3]; // main , tvboxset , movie boxset
    GridDimensions *current_grid;
    GridDirection grid_direction;
} Dimensions ;

struct hashtable *config_load(char *filename,int include_unquoted_space,int verbose);
struct hashtable *config_load_domain(char *domain);
void config_write(struct hashtable *cfg,char *filename);
void config_write_fp(struct hashtable *cfg,FILE *fp);
void config_unittest();
struct hashtable *config_load_wth_defaults(char *d,char *defaults_file,char *main_file);

int config_get_str(struct hashtable *h,char *key,char **out);
int config_check_str(struct hashtable *h,char *key,char **out);
int config_get_long(struct hashtable *h,char *key,long *out);
int config_check_long(struct hashtable *h,char *key,long *out);

int config_get_long_indexed(struct hashtable *h,char *k,char *index,long *out);
int config_check_long_indexed(struct hashtable *h,char *k,char *index,long *out);
int config_get_str_indexed(struct hashtable *h,char *k,char *index,char **out);
int config_check_str_indexed(struct hashtable *h,char *k,char *index,char **out);

void load_configs();
void reload_configs();
void config_read_dimensions();

long allow_admin();
long allow_delist();
long allow_delete();
long allow_mark();
long allow_locking();
int in_poster_mode();
int in_text_mode();
int browsing_from_lan();
int ovs_config_dimension_increment(char *keyword_prefix,char* delta_str,int min,int max);
int ovs_config_dimension_inherit(char *keyword_prefix);
char *query_val(char *name);
char *catalog_val(char *name);
char *locale_val(char *name);
char *setting_val(char *name);
char *oversight_val(char *name);
char *skin_val(char *name);
char *unpak_val(char *name);
void query_update(char *name,char *new);
void query_remove(char *name);
char *query_view_val();
ViewMode *get_view_mode(int reset);
char *query_select_val();
char *view_mode_to_str(ViewMode *m);
GridDirection str2grid_direction(char *name);
char *config_path(char *conf_file) ;
char *config_defaults_path(char *conf_file) ;
char *config_help_path(char *conf_file,char *help_suffix) ;
#endif
