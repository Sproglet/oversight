#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <sys/statvfs.h>

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

    int convert_double = 0;
    double dval=0.0;

    *free_result = 0;
    char *result=NULL;

    if (*vname == MACRO_SPECIAL_PREFIX ) {

#if 0
// deprecated
        if (util_starts_with(vname+1,"gaya")) {

            result = get_gaya_variable(vname+1,free_result);


        } else
#endif
            
            
        if (STRCMP(vname+1,"gaya") == 0) {

            convert_int=1;
            int_val = g_dimension->local_browser;

        } else if (STRCMP(vname+1,"nmt100") == 0) {
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

        } else if (STRCMP(vname+1,"selection_count") == 0) {
            convert_int=1;
            int_val = sorted_rows->num_rows;

        } else if (util_starts_with(vname+1,"sys_share_")) {

TRACE1;
            
            static int first_time = 1;
            static struct statvfs *s = NULL;
            if (first_time) {
                first_time = 0;
                s = MALLOC(sizeof(struct statvfs));
                if (s) {
                   if (statvfs("/share/.",s) != 0) {
                       HTML_LOG(0,"Error getting file system info");
                       FREE(s);
                       s = NULL;
                   }
                }
            }

            if (s != NULL) {
TRACE1;

                convert_double = 1;

                if (STRCMP(vname+1,"sys_share_used_gb") == 0) {
TRACE1;

                    dval = ( s->f_blocks - s->f_bfree );
                    dval *= s->f_bsize;
                    dval /= (1024*1024*1024);

                } else if (STRCMP(vname+1,"sys_share_used_percent") == 0) {
TRACE1;

                    dval = 100 - ( 100.0 * s->f_bfree ) /  s->f_blocks;

                } else if (STRCMP(vname+1,"sys_share_free_gb") == 0) {
TRACE1;

                    dval = s->f_bfree;
                    dval *= s->f_bsize;
                    dval /= (1024*1024*1024);

                } else if (STRCMP(vname+1,"sys_share_free_percent") == 0) {
TRACE1;

                    dval = ( 100.0 * s->f_bfree ) /  s->f_blocks;

                }
            }
#if 0
        } else if (STRCMP(vname+1,"item_count") == 0) {

            convert_int=1;
            int_val = sorted_rows->num_rows;

        } else if (STRCMP(vname+1,"group_count") == 0) {

            convert_int=1;
            int_val = sorted_rows->num_rows;
#endif

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


    } else if (util_starts_with(vname,VAR_PREFIX_SETTING_OVERSIGHT) ) {

        result = oversight_val(vname);

    } else if (util_starts_with(vname,VAR_PREFIX_SETTING_CATALOG)) {

        result = catalog_val(vname);

    } else if (util_starts_with(vname,VAR_PREFIX_SETTING_SKIN)) {

        result = skin_val(vname);

    } else if (util_starts_with(vname,VAR_PREFIX_SETTING_UNPAK)) {

        result = unpak_val(vname);

    } else if (util_starts_with(vname,VAR_PREFIX_TMP_SKIN)) {

        result = get_tmp_skin_variable(vname);
    }
    if (convert_int) {
        ovs_asprintf(&result,"%d",int_val);
        *free_result = 1;
    } else if (convert_double) {
        ovs_asprintf(&result,"%.1lf",dval);
        *free_result = 1;
    }

    return result;
}

/*
 * Hold values of temporary variables that are defined while processing the template.
 */
static struct hashtable *vars = NULL;
int set_tmp_skin_variable(char *name,char *value)
{
    int ret;
    if (vars == NULL) {
        vars = string_string_hashtable("tmp_vars",16);
    }
    ret = hashtable_insert(vars,STRDUP(name),STRDUP(value));
    HTML_LOG(0,"[%s=%s]",name,value);
    return ret;
}

void check_prefix(char *name,char *prefix)
{
    if (!util_starts_with(name,prefix)) {
        HTML_LOG(0,"[%s] doesn\'t begin with [%s]",name,prefix);
        assert(0);
    }
}

char *get_tmp_skin_variable(char *name)
{
    check_prefix(name,VAR_PREFIX_TMP_SKIN);

    if (vars == NULL) {
        return NULL;
    } else {
        return hashtable_search(vars,name);
    }
}
