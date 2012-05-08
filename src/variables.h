
#ifndef __OVS_VARIABLES_H_
#define __OVS_VARIABLES_H_

#define MACRO_VARIABLE_PREFIX '$'
#define MACRO_SPECIAL_PREFIX '@'
#define MACRO_QUERY_PREFIX '?'
#define MACRO_DBROW_PREFIX '%'

#define VAR_PREFIX_SETTING_OVERSIGHT "ovs_"
#define VAR_PREFIX_SETTING_LOCALE "catalog_locale_"
#define VAR_PREFIX_SETTING_CATALOG "catalog_"
#define VAR_PREFIX_SETTING_SKIN "skin_"
#define VAR_PREFIX_SETTING_UNPAK "unpak_"
#define VAR_PREFIX_FIELD "field_"  // database field
#define VAR_PREFIX_TMP_SKIN "_"

#include "db.h"

char *get_variable(char *vname,int *free_result,DbSortedRows *sorted_rows);
int set_tmp_skin_variable(char *name,char *value);
char *get_tmp_skin_variable(char *name);
void check_prefix(char *name,char *prefix);
void variables_cleanup();

#endif
