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
    int pass;  // first or second pass??
    FILE *outfp;
    int request_reparse; // set if another pass is needed.
} MacroCallInfo;

void macro_init();
char *macro_call(int pass,char *template_name,char *orig_skin,char *call,DbSortedRows *sorted_rows,int *free_result,FILE *out,int *request_reparse);
long output_state();
void loop_deregister_all() ;
Array *loop_lookup(char *loop_name);
Array *loop_register(char *loop_name);
void macro_cleanup();

#define CALL_UNCHANGED ((char *)-2)

#endif
