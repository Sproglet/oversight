#ifndef __OVS_DISPLAY_H__
#define __OVS_DISPLAY_H__

#include "hashtable.h"
#include "config.h"
#include "db.h"

void display_menu();

void display_template(char*template_name,char *file_name,int num_rows,DbRowId **sorted_row_ids);
int get_sorted_rows_from_params(DbRowSet ***rowSetsPtr,DbRowId ***sortedRowsPtr);
void free_sorted_rows(DbRowSet **rowsets,DbRowId **sorted_row_ids);

void display_dynamic_styles();

char *add_hidden(char *names);
char *get_toggle(char *button_colour,char *param_name,char *v1,char *text1,char *v2,char *text2);
char *get_theme_image_link(char *qlist,char *href_attr,char *image_name,char *button_attr);
char * get_poster_image_tag(DbRowId *rowid,char *attr);
char *get_theme_image_tag(char *image_name,char *attr);
int exists_file_in_dir(char *dir,char *name);
char *get_grid(long page,int rows, int cols, int numids, DbRowId **row_ids);
char *ovs_icon_type();
char * get_local_image_link(char *path,char *alt_text,char *attr);
#endif
