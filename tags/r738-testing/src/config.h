#ifndef __CONFIG_H_ALORD__
#define __CONFIG_H_ALORD__

#include <stdio.h>
#include "hashtable.h"

typedef struct dimension_str {
    int tv_mode;
    int is_pal;
    long scanlines;
    long poster_mode;
    long title_bar; //dynamic title bar.
    long local_browser;
    long rows;
    long cols;
    long font_size;
    long title_size;
    long movie_img_height;
    long movie_img_width;
    long tv_img_height;
    long tv_img_width;
    long max_plot_length;
    long button_size;
    long certificate_size;
    long poster_menu_img_width;
    long poster_menu_img_height;

} Dimensions ;

struct hashtable *config_load(char *filename);
struct hashtable *config_load_fp(FILE *fp);
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

void config_read_dimensions();

long allow_admin();
long allow_delist();
long allow_delete();
long allow_mark();
int in_poster_mode();
int in_text_mode();
int browsing_from_lan();
#endif
