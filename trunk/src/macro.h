#ifndef __OVS_MACRO_H__
#define __OVS_MACRO_H__

#include "db.h"

void macro_init();
char *macro_call(char *template_name,char *orig_skin,char *call,int num_rows,DbRowId **sorted_rows,int *free_result);
long output_state();

#endif
