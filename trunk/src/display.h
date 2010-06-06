#ifndef __OVS_DISPLAY_H__
#define __OVS_DISPLAY_H__

#include "hashtable.h"
#include "config.h"
#include "db.h"

#define CHECKBOX_PREFIX "cb_"

#define REMOTE_VOD_PREFIX2 "vod.ovs." 
#define REMOTE_VOD_PREFIX1 "remote.vod.ovs."

typedef enum { FANART_IMAGE , POSTER_IMAGE , THUMB_IMAGE } ImageType;

void display_menu();

FILE *playlist_open();
DbSortedRows *get_sorted_rows_from_params();
void sorted_rows_free_all(DbSortedRows *sortedRows);
int playlist_size(DbSortedRows *sorted_rows);
void build_playlist(DbSortedRows *sorted_rows);

void display_dynamic_styles();

char *add_hidden(char *names);
char *get_toggle(char *button_colour,char *param_name,char *v1,char *text1,char *v2,char *text2);
char *get_theme_image_return_link(char *href_attr,char *image_name,char *button_attr);
char *get_theme_image_link(char *qlist,char *href_attr,char *image_name,char *button_attr);
char * get_poster_image_tag(DbRowId *rowid,char *attr,ImageType image_type);
char *get_theme_image_tag(char *image_name,char *attr);
char *get_grid(long page,GridSegment *gs,DbSortedRows *sorted_rows);
char *ovs_icon_type();
char * get_local_image_link(char *path,char *alt_text,char *attr);
char * template_image_link(char *subfolder,char *name,char *ext,char *alt_text,char *attr);
char *get_tvid_links();
char *get_tvid_resize_links();
char *get_play_tvid(char *text);
char *movie_listing(DbRowId *rowid);
long use_tv_boxsets();
long use_movie_boxsets();
char *tv_listing(DbSortedRows *sorted_rows,int rows,int cols);
char *get_status();
char *cgi_url(int full);
char *self_url(char *new_params);
char *get_self_link(char *params,char *attr,char *title);
char *get_self_link_with_font(char *params,char *attr,char *title,char *font_class);
void display_confirm(char *name,char *val_ok,char *val_cancel);
char *file_to_url(char *path);
char *get_path(DbRowId *rid,char *path,int *freepath);
char *vod_attr(char *file);
char *get_picture_path(int num_rows,DbRowId **sorted_rows,ImageType image_type);
void create_file_to_url_symlink();
char *auto_option_list(char *name,char *firstItem,struct hashtable *vals);
char *option_list(char *name,char *attr,char *firstItem,struct hashtable *vals);
char *add_network_icon(DbRowId *r,char *text);
char *share_name(DbRowId *r,int *freeme);
char *internal_image_path_static(DbRowId *rid,ImageType image_type);
void xx_dump_genre(char *file,int line,int num,DbRowId **rows);
char *return_query_string();
void query_pop();
void set_selected_item();
char *get_selected_item();
#endif
