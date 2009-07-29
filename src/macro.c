#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <assert.h>

#include "hashtable.h"
#include "util.h"
#include "oversight.h"
#include "db.h"
#include "dboverview.h"
#include "display.h"
#include "gaya_cgi.h"
#include "macro.h"

static struct hashtable *macros = NULL;

char *macro_fn_poster(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    return STRDUP("poster");
}

char *macro_fn_db(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    return STRDUP("db");
}

char *macro_fn_cert(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    return STRDUP("cert");
}

char *macro_fn_movie_listing(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    return STRDUP("movie_listing");
}

char *macro_fn_rating_stars(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    return STRDUP("rating_starts");
}

char *macro_fn_grid(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    return STRDUP("grid");
}

char *macro_fn_header(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    return STRDUP("header");
}

char *macro_fn_hostname(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    return STRDUP(util_hostname());
}

char *macro_fn_form_start(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {

    char *url=NULL;
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

char *macro_fn_tvids(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    return STRDUP("tvids");
}

char *macro_fn_is_gaya(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    if (g_dimension->local_browser) {
        return STRDUP("1");
    } else {
        return STRDUP("0");
    }
}

char *macro_fn_include(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    if (args && args->size == 2) {
        display_template(args->array[0],args->array[1],num_rows,sorted_rows);
    } else if (!args) {
        html_error("missing  args for include");
    } else {
        html_error("number of args for include = %d",args->size);
    }
    return NULL;
}

char *macro_fn_start_cell(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {

    if (*query_val(QUERY_PARAM_REGEX)) {
        return STRDUP("filter5");
    } else {
        return STRDUP("centreCell");
    }

}
char *macro_fn_media_type(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    char *mt="?";
    switch(*query_val(QUERY_PARAM_TYPE_FILTER)) {
        case 'T': mt="TV Shows"; break;
        case 'M': mt="Movies"; break;
        default: mt="All Video"; break;
    }

    return STRDUP(mt);
}
char *macro_fn_version(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {

    char *version=OVS_VERSION;
    version +=4;
    return replace_all(version,"BETA","b",0);

}

char *macro_fn_media_toggle(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {

    return get_toggle("red",QUERY_PARAM_TYPE_FILTER,
            QUERY_PARAM_MEDIA_TYPE_VALUE_TV,"Tv",
            QUERY_PARAM_MEDIA_TYPE_VALUE_MOVIE,"Film");

}
char *macro_fn_watched_toggle(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    return get_toggle("green",QUERY_PARAM_WATCHED_FILTER,
            QUERY_PARAM_WATCHED_VALUE_NO,"Unmarked",
            QUERY_PARAM_WATCHED_VALUE_YES,"Marked");
}
char *macro_fn_sort_type_toggle(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    return get_toggle("blue",QUERY_PARAM_SORT,
            DB_FLDID_TITLE,"Name",
            DB_FLDID_INDEXTIME,"Age");
}
char *macro_fn_filter_bar(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {

    char *result=NULL;

    if (*query_val(QUERY_PARAM_SEARCH_MODE) || *query_val(QUERY_PARAM_REGEX)) {

        if (g_dimension->local_browser) {
            char *current_regex =query_val(QUERY_PARAM_REGEX);
            char *left=NULL;
            char *start = get_theme_image_link("p=0&"QUERY_PARAM_SEARCH_MODE"=&"QUERY_PARAM_REGEX"=","","start-small","width=20 height=20");
            printf("<font class=keypada>[%s]</font>",current_regex);

            char *params;
            
            // Print icon to remove last digit from tvid search
            int regex_len=strlen(current_regex);
            if (regex_len >= 1 ) {
                regex_len --;

                ovs_asprintf(&params,"p=0&"QUERY_PARAM_SEARCH_MODE"=&"QUERY_PARAM_REGEX"=%.*s",
                        regex_len,current_regex);
                left = get_theme_image_link(params,"","left-small","width=20 height=20");
                free(params);
            }

            ovs_asprintf(&result,"Use keypad to search%s<font class=keypada>[%s]</font>%s",
                    start,current_regex,(left?left:""));
            free(start);
            if (left) free(left);

        } else {

            ovs_asprintf(&result,"<input type=text name=searcht value=\"%s\" >"
                    "<input type=submit name=searchb value=Search >"
                    "<input type=submit name=searchb value=Hide >"
                    "<input type=hidden name="QUERY_PARAM_SEARCH_MODE" value=\"%s\" >"
                    ,query_val("searcht"),query_val(QUERY_PARAM_SEARCH_MODE));

        }

    } else {
        result = get_theme_image_link("p=0&" QUERY_PARAM_SEARCH_MODE "=1","","find","");
    }
    return result;
}

char *macro_fn_status(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    char *result=NULL;
#define MSG_SIZE 20
    static char msg[MSG_SIZE+1];
    char *filename;
    ovs_asprintf(&filename,"%s/catalog.status",appDir());

    msg[0] = '\0';

    FILE *fp = fopen(filename,"r");
    if (fp) {
        fgets(msg,MSG_SIZE,fp);
        msg[MSG_SIZE] = '\0';
        chomp(msg);

        result = STRDUP(msg);

        fclose(fp);
    } else {
        html_error("Error %d opening [%s]",errno,filename);
    }
    free(filename);

    if (result == NULL) {

        if (exists_file_in_dir(tmpDir(),"cmd.pending")) {
            result = STRDUP("[ Catalog update pending ]");
        } else if (db_full_size() == 0 ) {
            result = STRDUP("[ Video index is empty. Select setup icon and scan the media drive ]");
        }
    }

    return result;
}


char *macro_fn_setup_button(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    return get_theme_image_link("view=admin&action=ask","TVID=SETUP","configure","");
}

long get_current_page() {
    long page;
    if (!config_check_long(g_query,"p",&page)) {
        page = 0;
    }
    return page;
}

char *get_page_control(int on,int offset,char *tvid_name,char *image_base_name) {

    char *select = query_val("select");
    char *view = query_val("view");
    int page = get_current_page();
    char *result = NULL;

    assert(view);
    assert(tvid_name);
    assert(image_base_name);

    if (! *select) {
        //only show page controls when NOT selecting
        if (on)  {
            char *params=NULL;
            char *attrs=NULL;
            ovs_asprintf(&params,"p=%d",page+offset);
            ovs_asprintf(&attrs,"tvid=%s name=%s1 onfocusload",tvid_name,tvid_name);

            html_log(1,"dbg params [%s] attr [%s] tvid [%s]",params,attrs,tvid_name);

            result = get_theme_image_link(params,attrs,image_base_name,"");
            free(params);
            free(attrs);
        } else if (! *view ) {
            //Only show disabled page controls in main menu view (not tv / movie subpage) - this may change
            char *image_off=NULL;
            ovs_asprintf(&image_off,"%s-off",image_base_name);
            result = get_theme_image_tag(image_off,NULL);
            free(image_off);
        }
    }
    return result;
}

char *macro_fn_left_button(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {

    int on = get_current_page() > g_dimension->rows*g_dimension->cols;

    return get_page_control(on,1,"pgup","left");
}




char *macro_fn_right_button(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {

    int on = ((get_current_page()+1)*g_dimension->rows*g_dimension->cols < num_rows);

    return get_page_control(on,1,"pgdn","right");
}



char *macro_fn_select_back_button(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    char *result=NULL;
    if (*query_val("view") && *query_val("select")) {
        result = get_theme_image_link("view=&idlist=","name=up","back","");
    }
    return result;
}

char *macro_fn_home_button(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    char *result=NULL;

    if (! *query_val("view")) {
        if(hashtable_count(g_query) == 0 && g_dimension->local_browser) {
            char *tag=get_theme_image_tag("exit",NULL);
            ovs_asprintf(&result,"<a href=\"/start.cgi\" name=home >%s</a>",tag);
            free(tag);
        } else {
            char *tag=get_theme_image_tag("home",NULL);
            ovs_asprintf(&result,"<a href=\"%s?\" name=home TVID=HOME >%s</a>",SELF_URL,tag);
            free(tag);
        }
    }

    return result;
}

char *macro_fn_mark_button(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    char *result=NULL;
    if (!*query_val("select") && allow_mark()) {
        result = get_theme_image_link("select=Mark","tvid=EJECT","mark","");
    }
    return result;
}

char *macro_fn_delete_button(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    char *result=NULL;
    if (!*query_val("select") && (allow_delete() || allow_delist())) {
        result = get_theme_image_link("select=Delete","tvid=CLEAR","delete","");
    }
    return result;
}
char *macro_fn_select_mark_submit(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    char *result=NULL;
    if (*query_val("select")) {
        ovs_asprintf(&result,"<input type=submit name=action value=Mark >");
    }
    return result;
}
char *macro_fn_select_delete_submit(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    char *result=NULL;
    if (*query_val("select")) {
        ovs_asprintf(&result,"<input type=submit name=action value=Delete >");
    }
    return result;
}
char *macro_fn_select_delist_submit(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    char *result=NULL;
    if (*query_val("select")) {
        ovs_asprintf(&result,"<input type=submit name=action value=Remove_From_List >");
    }
    return result;
}
char *macro_fn_select_cancel_submit(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    char *result=NULL;
    if (*query_val("select")) {
        ovs_asprintf(&result,"<input type=submit name=select value=Cancel >");
    }
    return result;
}
char *macro_fn_external_url(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    char *result;
    if (!g_dimension->local_browser){
        char *url=sorted_rows[0]->url;
        if (url != NULL) {
            char *image=get_theme_image_tag("upgrade"," alt=External ");
            ovs_asprintf(&result,"<a href=\"%s\">%s</a>",url,image);
            free(image);
        }
    }
    return result;
}

// Parse val +2,-3,/4 
char *numeric_constant_macro(long val,Array *args) {

    char *result = NULL;
    if (args) {
        int i;
        for(i = 0 ; i < args->size ; i++ ) {
            char *p=args->array[i];

            //get the operator
            char op='+';
            switch(*p) {
                case '+': case '-': case '/': case '*': case '%':
                    op=*p++; break;
            }

            // parse number
            char *end;
            long num2=strtol(p,&end,10);
            if (*p == '\0' || *end != '\0' ) {
                html_error("bad number [%s]",p);
            }

            // do the calculation
            switch(op) {
                case '+': val += num2; break;
                case '-': val -= num2; break;
                case '/': val /= num2; break;
                case '*': val *= num2; break;
                case '%': val %= num2; break;
            }
        }
    }
    ovs_asprintf(&result,"%ld",val);
    return result;
}

char *macro_fn_font_size(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    return numeric_constant_macro(g_dimension->font_size,args);
}
char *macro_fn_title_size(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    return numeric_constant_macro(g_dimension->title_size,args);
}
char *macro_fn_scanlines(char *call,Array *args,int num_rows,DbRowId **sorted_rows) {
    return numeric_constant_macro(g_dimension->scanlines,args);
}

void macro_init() {

    if (macros == NULL) {
        html_log(0,"begin macro init");
        macros = string_string_hashtable(32);

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
        hashtable_insert(macros,"FORM_START",macro_fn_form_start);
        hashtable_insert(macros,"MEDIA_TYPE",macro_fn_media_type);
        hashtable_insert(macros,"VERSION",macro_fn_version);
        hashtable_insert(macros,"HOSTNAME",macro_fn_hostname);
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
        hashtable_insert(macros,"INCLUDE_TEMPLATE",macro_fn_include);
        hashtable_insert(macros,"START_CELL",macro_fn_start_cell);
        hashtable_insert(macros,"FONT_SIZE",macro_fn_font_size);
        hashtable_insert(macros,"TITLE_SIZE",macro_fn_title_size);
        hashtable_insert(macros,"SCANLINES",macro_fn_scanlines);
        html_log(0,"end macro init");
    }
}

char *macro_call(char *call,int num_rows,DbRowId **sorted_rows) {

    if (macros == NULL) macro_init();

    char *result = NULL;
    char *(*fn)(char *name,Array *args,int num_rows,DbRowId **) = NULL;
    Array *args=NULL;

    char *p = strchr(call,'(');
    if (p == NULL) {
        fn = hashtable_search(macros,call);
    } else {
        char *q=strchr(p,')');
        if (q == NULL) {
            html_error("missing ) for [%s]",call);
        } else {
            // Get the arguments
            *q='\0';
            args = split(p+1,",",0);
            *q=')';
            // Get the function
            *p = '\0';
            fn = hashtable_search(macros,call);
            *p='(';
        }
    }
            

    if (fn) {
        html_log(0,"begin macro [%s]",call);
        result =  (*fn)(call,args,num_rows,sorted_rows);
        html_log(0,"end macro [%s]",call);
    } else {
        html_error("no macro [%s]",call);
    }
    array_free(args);
    return result;
}

