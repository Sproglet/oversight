#ifndef __OVS_DISPLAY_H__
#define __OVS_DISPLAY_H__

#include "hashtable.h"
#include "config.h"
#include "db.h"

#define CHECKBOX_PREFIX "cb_"

#define REMOTE_VOD_PREFIX2 "vod.ovs." 
#define REMOTE_VOD_PREFIX1 "remote.vod.ovs."

#define IMAGE_EXT_SD ".sd.jpg"
#define IMAGE_EXT_PAL ".pal.jpg"
#define IMAGE_EXT_HD ".hd.jpg"
#define IMAGE_EXT_THUMB ".thumb.jpg"
#define IMAGE_EXT_THUMB_BOXSET ".thumb.boxset.jpg"


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
char * get_poster_image_tag(DbItem *rowid,char *attr,ImageType image_type,ViewMode *newview);
char *get_theme_image_tag(char *image_name,char *attr);
char *ovs_icon_type();
char * get_local_image_link(char *path,char *alt_text,char *attr);
char * template_image_link(char *subfolder,char *name,char *ext,char *alt_text,char *attr);
char *get_tvid_links();
char *get_tvid_resize_links();
char *get_play_tvid(char *text);
long use_tv_boxsets();
long use_movie_boxsets();
char *get_status_static();
char *cgi_url(int full);
char *self_url(char *new_params);
char *get_self_link(char *params,char *attr,char *title);
char *get_self_link_with_font(char *params,char *attr,char *title,char *font_class);
void display_confirm(char *name,char *val_ok,char *val_cancel);
char *file_to_url(char *path);
char *get_path(DbItem *item,char *path,int *freepath);
char *vod_attr(char *file);
char *get_picture_path(int num_rows,DbItem **sorted_rows,ImageType image_type,ViewMode *newview);
void create_file_to_url_symlink();
char *auto_option_list(char *name,char *firstItem,struct hashtable *vals);
char *option_list(char *name,char *attr,char *firstItem,struct hashtable *vals);
char *add_network_icon(DbItem *r,char *text);
char *share_name(DbItem *r,int *freeme);
char *internal_image_path_static(DbItem *item,ImageType image_type);
void xx_dump_genre(char *file,int line,int num,DbItem **rows);
char *return_query_string();
void query_pop();
void set_selected_item();
char *get_selected_item();
int is_watched(DbItem *rowid);
int is_fresh(DbItem *rowid);
char *get_person_drilldown_link(ViewMode *view,char *dbfieldid,char *id,char *attr,char *name,char *font_class,char *cell_no_txt);
char *actor_image_path(DbItem *item,char *name_id);
int is_locked(DbItem *item);
char *drill_down_link(char *params,char *attr,char *title);
char *get_drilldown_name_static(char *root_name,int num_prefix);
char *get_drilldown_link_with_font(char *params,char *attr,char *title,char *font_attr);
char *js_function(char *function_prefix,char *called_function,long fn_id,va_list ap);
char *build_id_list(DbItem *row_id);
char *select_checkbox(DbItem *item,char *text);
char *href_focus_event_fn(char *function_name_prefix,long function_id);
char *vod_link(DbItem *rowid,char *title ,char *t2,char *source,char *file,char *href_name,char *href_attr,char *class);
char *watched_style(DbItem *rowid);
char *watched_style_small(DbItem *rowid);
char *file_style(DbItem *rowid);
char *file_style_small(DbItem *rowid);
int get_view_status(DbItem *rowid);
char *icon_link(char *name);
char *td_mouse_event_fn(char *function_name_prefix,long function_id);
DbItem **filter_page_items(int start,int num_rows,DbItem **row_ids,int max_new,int *new_num);
#endif
