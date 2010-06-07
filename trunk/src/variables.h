
#ifndef __OVS_VARIABLES_H_
#define __OVS_VARIABLES_H_

#define MACRO_VARIABLE_PREFIX '$'
#define MACRO_SPECIAL_PREFIX '@'
#define MACRO_QUERY_PREFIX '?'
#define MACRO_DBROW_PREFIX '%'

#include "db.h"

char *get_variable(char *vname,int *free_result,DbSortedRows *sorted_rows);
int set_skin_variable(char *name,char *value);
char *get_skin_variable(char *name);

#endif
