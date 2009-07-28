#ifndef __OVS_DISPLAY_H__
#define __OVS_DISPLAY_H__

#include "hashtable.h"
#include "config.h"
#include "db.h"

void display_menu();

void display_template(char*template_name,char *file_name,DbRowId **sorted_row_ids);

void display_dynamic_styles();

char *add_hidden(char *names);
#endif
