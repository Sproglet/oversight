#include <string.h>
#include <stdlib.h>

#include "hashtable.h"
#include "util.h"
#include "oversight.h"
#include "db.h"
#include "dboverview.h"
#include "gaya_cgi.h"
#include "macro.h"

static struct hashtable *macros = NULL;

char *macro_fn_poster(char *call,char **args,DbRowId **sorted_rows) {
    return STRDUP("poster");
}

char *macro_fn_db(char *call,char **args,DbRowId **sorted_rows) {
    return STRDUP("db");
}

char *macro_fn_cert(char *call,char **args,DbRowId **sorted_rows) {
    return STRDUP("cert");
}

char *macro_fn_movie_listing(char *call,char **args,DbRowId **sorted_rows) {
    return STRDUP("movie_listing");
}

char *macro_fn_rating_stars(char *call,char **args,DbRowId **sorted_rows) {
    return STRDUP("rating_starts");
}

char *macro_fn_grid(char *call,char **args,DbRowId **sorted_rows) {
    return STRDUP("grid");
}

char *macro_fn_header(char *call,char **args,DbRowId **sorted_rows) {
    return STRDUP("header");
}

char *macro_fn_hostname(char *call,char **args,DbRowId **sorted_rows) {
    return STRDUP(util_hostname());
}

char *macro_fn_form_start(char *call,char **args,DbRowId **sorted_rows) {

    if (strcasecmp(query_val("view"),"admin") == 0) {
        char *action = query_val("action");
        if (strcasecmp(action,"ask") == 0 || strcasecmp(action,"cancel") == 0) {
            return NULL;
        } else {
            url="?"; // clear URL
        } 
    } else {
        url=""; //keep query string eg when marking deleting
    }
    char *hidden = add_hidden("cache,idlist,view,page,sort,"
            QUERY_PARAM_TYPE_FILTER","QUERY_PARAM_REGEX","QUERY_PARAM_WATCHED_FILTER);
    char *result;
    ovs_asprintf(&result,"<form action=\"%s\" enctype=\"multipart/form-data\" method=POST >\n%s",url,hidden);
    free(hidden);
    return result;
}

char *macro_fn_tvids(char *call,char **args,DbRowId **sorted_rows) {
    return STRDUP("tvids");
}

char *macro_fn_is_gaya(char *call,char **args,DbRowId **sorted_rows) {
    if (g_dimension->local_browser) {
        return STRDUP("1");
    } else {
        return STRDUP("0");
    }
}

char *macro_fn_include(char *call,char **args,DbRowId **sorted_rows) {
    return STRDUP("include");
}

char *macro_fn_start_cell(char *call,char **args,DbRowId **sorted_rows) {

    if (*query_val(QUERY_PARAM_REGEX)) {
        return STRDUP("filter5");
    } else {
        return STRDUP("centreCell");
    }

}

char *macro_fn_media_toggle(char *call,char **args,DbRowId **sorted_rows) {
    char *result=NULL;

    return result;
}
char *macro_fn_watched_toggle(char *call,char **args,DbRowId **sorted_rows) {
    char *result=NULL;
    return result;
}
char *macro_fn_sort_type_toggle(char *call,char **args,DbRowId **sorted_rows) {
    char *result=NULL;
    return result;
}
char *macro_fn_filter_bar(char *call,char **args,DbRowId **sorted_rows) {
    char *result=NULL;
    return result;
}
char *macro_fn_status(char *call,char **args,DbRowId **sorted_rows) {
    char *result=NULL;
    return result;
}
char *macro_fn_setup_button(char *call,char **args,DbRowId **sorted_rows) {
    char *result=NULL;
    return result;
}
char *macro_fn_left_button(char *call,char **args,DbRowId **sorted_rows) {
    char *result=NULL;
    return result;
}
char *macro_fn_right_button(char *call,char **args,DbRowId **sorted_rows) {
    char *result=NULL;
    return result;
}
char *macro_fn_select_back_button(char *call,char **args,DbRowId **sorted_rows) {
    char *result=NULL;
    return result;
}
char *macro_fn_home_button(char *call,char **args,DbRowId **sorted_rows) {
    char *result=NULL;
    return result;
}
char *macro_fn_mark_button(char *call,char **args,DbRowId **sorted_rows) {
    char *result=NULL;
    return result;
}
char *macro_fn_delete_button(char *call,char **args,DbRowId **sorted_rows) {
    char *result=NULL;
    return result;
}
char *macro_fn_select_mark_submit(char *call,char **args,DbRowId **sorted_rows) {
    char *result=NULL;
    return result;
}
char *macro_fn_select_delete_submit(char *call,char **args,DbRowId **sorted_rows) {
    char *result=NULL;
    return result;
}
char *macro_fn_select_delist_submit(char *call,char **args,DbRowId **sorted_rows) {
    char *result=NULL;
    return result;
}
char *macro_fn_select_cancel_submit(char *call,char **args,DbRowId **sorted_rows) {
    char *result=NULL;
    return result;
}


void macro_init() {
macros = string_string_hashtable();

    hashtable_insert(macros,"POSTER_IMAGE",macro_fn_poster);
    hashtable_insert(macros,"CERTIFICATE_IMAGE",macro_fn_cert);
    hashtable_insert(macros,"MOVIE_LISTING",macro_fn_movie_listing);
    hashtable_insert(macros,"EXTERNAL_URL",macro_fn_external_url);
    hashtable_insert(macros,"TITLE",macro_fn_db);
    hashtable_insert(macros,"GENRE",macro_fn_db);
    hashtable_insert(macros,"SEASON",macro_fn_db);
    hashtable_insert(macros,"YEAR",macro_fn_db);
    hashtable_insert(macros,"RATING_STARS",macro_fn_rating_stars);
    hashtable_insert(macros,"GRID",macro_fn_grid);
    hashtable_insert(macros,"HEADER",macro_fn_header);
    hashtable_insert(macros,"HOSTNAME",macro_fn_hostname);
    hashtable_insert(macros,"FORM_START",macro_fn_form_start);
    hashtable_insert(macros,"MEDIA_TOGGLE",macro_fn_media_toggle);
    hashtable_insert(macros,"WATCHED_TOGGLE",macro_fn_watched_toggle);
    hashtable_insert(macros,"SORT_TYPE_TOGGLE",macro_fn_sort_type_toggle);
    hashtable_insert(macros,"FILTER_BAR",macro_fn_filter_bar);
    hashtable_insert(macros,"STATUS",macro_fn_status);
    hashtable_insert(macros,"SETUP_BUTTON",macro_fn_setup_button);

    hashtable_insert(macros,"LEFT_BUTTON",macro_fn_left_button);
    hashtable_insert(macros,"RIGHT_BUTTON",macro_fn_right_button);
    hashtable_insert(macros,"SELECT_BACK_BUTTON",macro_fn_select_back_button);
    hashtable_insert(macros,"HOME_BUTTON",macro_fn_home_button);
    hashtable_insert(macros,"MARK_BUTTON",macro_fn_mark_button);
    hashtable_insert(macros,"DELETE_BUTTON",macro_fn_delete_button);
    hashtable_insert(macros,"SELECT_MARK_SUBMIT",macro_fn_select_mark_submit);
    hashtable_insert(macros,"SELECT_DELETE_SUBMIT",macro_fn_select_delete_submit);
    hashtable_insert(macros,"SELECT_DELIST_SUBMIT",macro_fn_select_delist_submit);
    hashtable_insert(macros,"SELECT_CANCEL_SUBMIT",macro_fn_select_cancel_submit);

    hashtable_insert(macros,"IS_GAYA",macro_fn_is_gaya);
    hashtable_insert(macros,"INCLUDE",macro_fn_include);
    hashtable_insert(macros,"START_CELL",macro_fn_start_cell);
}

char *macro_call(char *call,DbRowId **sorted_rows) {

    if (macros == NULL) macro_init();

    char (*fn)(char *name,char **args,DbRowId **);

    fn = hashtable_search(macros,call);

    return (*fn)(call,NULL,sorted_rows);
}

