#include <stdio.h>
#include <string.h>
#include "variables.h"

#include "oversight.h"
#include "util.h"
#include "gaya.h"
#include "gaya_cgi.h"

// ?xx = html query variable
// ovs_xxx = oversight config
// catalog_xxx = catalog config
// unpak_xxx = unpak config
// skin_xxx = macro variable
//


#if 0
// deprecated
//
char *get_gaya_variable(char *vname,int *free_result)
{
    int int_val=0;

    *free_result = 0;
    char *result=NULL;
    if (STRCMP(vname+1,"gaya") == 0) {

        int_val = g_dimension->local_browser;

    } else if (STRCMP(vname+1,"gaya_page") == 0) {

        int_val = get_gaya_page();

    } else if (STRCMP(vname+1,"gaya_file_total") == 0) {

        int_val = gaya_file_total();

    } else if (STRCMP(vname+1,"gaya_prev_page") == 0) {

        int_val = gaya_prev_page();

    } else if (STRCMP(vname+1,"gaya_next_page") == 0) {

        int_val = gaya_next_page();

    } else if (STRCMP(vname+1,"gaya_first_file") == 0) {

        int_val = gaya_first_file();

    } else if (STRCMP(vname+1,"gaya_last_file") == 0) {

        int_val = gaya_last_file();

    } else if (STRCMP(vname+1,"gaya_prev_file") == 0) {

        int_val = gaya_prev_file();
    }

    ovs_asprintf(&result,"%d",int_val);
    *free_result = 1;

    return result;
}
#endif

/**
 * convert TITLE:n to the title of the N'th row of the sorted results.
 */

char *get_indexed_field(char *field_reference,DbSortedRows *sorted_rows)
{
    int row_num;
    char *result = NULL;

#define INDEX_SEP ':'
    char *sep_pos;
    char *fieldid = NULL;

    if ( (sep_pos = strchr(field_reference,INDEX_SEP)) != NULL) {
        char *name = COPY_STRING(sep_pos-field_reference,field_reference);
        fieldid = dbf_macro_to_fieldid(name);
        row_num = atoi(sep_pos+1);
        FREE(name);
    } else {
        fieldid = dbf_macro_to_fieldid(field_reference);
        row_num = 0;
    }

    if (fieldid) {
        // Get the value from the first row in the set
        result=db_get_field(sorted_rows,row_num,fieldid);
    } else {
        HTML_LOG(0,"Field [%s] not found",field_reference);
    }
    return result;
}

char *get_variable(char *vname,int *free_result,DbSortedRows *sorted_rows)
{

    int convert_int = 0;
    int int_val=0;

    *free_result = 0;
    char *result=NULL;

    if (*vname == MACRO_SPECIAL_PREFIX ) {

#if 0
// deprecated
        if (util_starts_with(vname+1,"gaya")) {

            result = get_gaya_variable(vname+1,free_result);


        } else
#endif
            
            
        if (STRCMP(vname+1,"nmt100") == 0) {
            convert_int=1;
            int_val = is_nmt100();

        } else if (STRCMP(vname+1,"nmt200") == 0) {

            convert_int=1;
            int_val = is_nmt200();

        } else if (STRCMP(vname+1,"hd") == 0) {

            convert_int=1;
            int_val = g_dimension->scanlines > 0;

        } else if (STRCMP(vname+1,"sd") == 0) {

            convert_int=1;
            int_val = g_dimension->scanlines == 0;

        } else if (STRCMP(vname+1,"poster_mode") == 0) {
            return ( g_dimension->poster_mode ? "1" : "0" ) ; // $@gaya

        } else if (STRCMP(vname+1,"poster_menu_img_width") == 0) {

            convert_int=1;
            int_val = g_dimension->current_grid->img_width;

        } else if (STRCMP(vname+1,"poster_menu_img_height") == 0) {

            convert_int=1;
            int_val = g_dimension->current_grid->img_height;

        }

    } else if (*vname == MACRO_QUERY_PREFIX ) {

        // html query variable ?name=val
        result=query_val(vname+1);

    } else if (*vname == MACRO_DBROW_PREFIX ) {

        char *f = vname+1;
        HTML_LOG(0,"DBROW LOOKUP [%s] - [%c%s] deprecated - use [field_%s]",f,MACRO_DBROW_PREFIX,f,f);
        *free_result=1;
        result = get_indexed_field(f,sorted_rows);


    } else if (util_starts_with(vname,"field_") ) {
        char *f = vname+6;
        HTML_LOG(0,"DBROW LOOKUP [%s]",f);
        *free_result=1;
        result = get_indexed_field(f,sorted_rows);


    } else if (util_starts_with(vname,"ovs_") ) {

        result = oversight_val(vname);

    } else if (util_starts_with(vname,"catalog_")) {

        result = catalog_val(vname);

    } else if (util_starts_with(vname,"unpak_")) {

        result = unpak_val(vname);

    } else if (util_starts_with(vname,"skin_")) {

        result = get_skin_variable(vname);
    }
    if (convert_int) {
        ovs_asprintf(&result,"%d",int_val);
        *free_result = 1;
    }

    return result;
}

static struct hashtable *vars = NULL;
int set_skin_variable(char *name,char *value)
{
    int ret;
    if (vars == NULL) {
        vars = string_string_hashtable("skin_vars",16);
    }
    ret = hashtable_insert(vars,STRDUP(name),STRDUP(value));
    HTML_LOG(0,"[%s=%s]",name,value);
    return ret;
}
char *get_skin_variable(char *name)
{
    if (vars == NULL) {
        return NULL;
    } else {
        return hashtable_search(vars,name);
    }
}
