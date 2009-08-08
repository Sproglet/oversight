#ifndef __OVS_DISPLAY_H__
#define __OVS_DISPLAY_H__

#include "hashtable.h"
#include "config.h"
#include "db.h"

#define CHECKBOX_PREFIX "cb_"

#define REMOTE_VOD_PREFIX2 "vod.ovs." 
#define REMOTE_VOD_PREFIX1 "remote.vod.ovs."

void display_menu();

FILE *playlist_open();
void display_template(char*template_name,char *file_name,int num_rows,DbRowId **sorted_row_ids);
int get_sorted_rows_from_params(DbRowSet ***rowSetsPtr,DbRowId ***sortedRowsPtr);
void free_sorted_rows(DbRowSet **rowsets,DbRowId **sorted_row_ids);

void display_dynamic_styles();

char *add_hidden(char *names);
char *get_toggle(char *button_colour,char *param_name,char *v1,char *text1,char *v2,char *text2);
char *get_theme_image_link(char *qlist,char *href_attr,char *image_name,char *button_attr);
char * get_poster_image_tag(DbRowId *rowid,char *attr);
char *get_theme_image_tag(char *image_name,char *attr);
char *get_grid(long page,int rows, int cols, int numids, DbRowId **row_ids);
char *ovs_icon_type();
char * get_local_image_link(char *path,char *alt_text,char *attr);
char *get_tvid_links(DbRowId **rowids);
char *get_play_tvid(char *text);
char *movie_listing(DbRowId *rowid);
long use_boxsets();
char *tv_listing(int num_rows,DbRowId **sorted_rows,int rows,int cols);
char *get_status();
char *get_self_link(char *params,char *attr,char *title);
void display_confirm(char *name,char *val_ok,char *val_cancel);
#endif
