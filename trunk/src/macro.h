#ifndef __OVS_MACRO_H__
#define __OVS_MACRO_H__

#include "db.h"

typedef struct MacroCallInfo_struct {
    char *skin_name;
    char *orig_skin_name;
    char *call;
    Array *args;
    DbSortedRows *sorted_rows;
    int free_result;
} MacroCallInfo;

void macro_init();
char *macro_call(char *template_name,char *orig_skin,char *call,DbSortedRows *sorted_rows,int *free_result);
long output_state();

#endif
