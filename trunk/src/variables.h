
#ifndef __OVS_VARIABLES_H_
#define __OVS_VARIABLES_H_

#define MACRO_VARIABLE_PREFIX '$'
#define MACRO_SPECIAL_PREFIX '@'
#define MACRO_QUERY_PREFIX '?'
#define MACRO_DBROW_PREFIX '%'
char *get_variable(char *vname,int *free_result);
int set_skin_variable(char *name,char *value);
char *get_skin_variable(char *name);

#endif
