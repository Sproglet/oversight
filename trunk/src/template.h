// $Id:$
#ifndef __OVS_TEMPLATE_H_
#define __OVS_TEMPLATE_H_
#include "db.h"

int display_main_template(char*template_name,char *file_name,DbSortedRows *sorted_rows);
int display_template(int pass,FILE *in,char*skin_name,char *file_name,DbSortedRows *sorted_rows,FILE *out,int *request_reparse);
char *get_skin_name();
char *skin_path();
char *icon_source(char *image_name);
char *image_source(char *subfolder,char *image_name,char *ext);
char *file_source(char *subfolder,char *file_name,char *ext);

#endif
