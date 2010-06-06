// $Id:$
#ifndef __OVS_TEMPLATE_H_
#define __OVS_TEMPLATE_H_
#include "db.h"

int display_template(char*template_name,char *file_name,DbSortedRows *sorted_rows);
char *skin_name();
char *icon_source(char *image_name);
char *image_source(char *subfolder,char *image_name,char *ext);
char *file_source(char *subfolder,char *file_name,char *ext);

#endif
