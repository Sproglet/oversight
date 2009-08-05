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

long get_current_page() {
    long page;
    if (!config_check_long(g_query,"p",&page)) {
        page = 0;
    }
    return page;
}

int get_rows_cols(char *call,Array *args,int *rowsp,int *colsp) {

    int result = 0;
    if(args) {
        if (args->size != 2) {
            html_error("macro :%s or %s(rows,cols)",call,call);
        } else {
            char *end;

            *rowsp=strtol(args->array[0],&end,10);
            if (!*(char *)(args->array[0]) || *end) {
                html_error("macro :%s invalid number [%s]",call,args->array[0]);
            } else {

                *colsp=strtol(args->array[1],&end,10);
                if (!*(char *)(args->array[1]) || *end) {
                    html_error("macro :%s invalid number [%s]",call,args->array[1]);
                } else {
                    result = 1;
                }
            }

        }
    }
    return result;
}


char *macro_fn_poster(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    if (num_rows == 0) {
       *free_result=0;
       return "poster";
    } else if (args && args->size) {
        return get_poster_image_tag(sorted_rows[0],args->array[0]);
    } else {
        return get_poster_image_tag(sorted_rows[0],"");
    }
}

char *macro_fn_plot(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    *free_result=0;
    int max = 0;
    if (args && args->size > 0) {
        char *max_str=args->array[0];
        char *end;
        if (max_str && *max_str) {
            int tmp = strtol(max_str,&end,10);
            if (*end) {
                return "PLOT bad arg";
            } else {
                max = tmp;
            }
        }
    }

    if (max == 0 || max > strlen(sorted_rows[0]->plot) ) {

        return sorted_rows[0]->plot;

    } else {

        char *out = STRDUP(sorted_rows[0]->plot);
        out[max] = '\0';
        if (max > 10) {
            strcpy(out+max-4,"...");
        }
        *free_result=1;
        return out;
    }
}

char *macro_fn_genre(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    *free_result=0;
    return sorted_rows[0]->genre;
}

char *macro_fn_title(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    *free_result=0;
    return sorted_rows[0]->title;
}

char *macro_fn_season(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    char *season=NULL;;
    if (sorted_rows[0]->season >=0) {
        ovs_asprintf(&season,"%d",sorted_rows[0]->season);
    }
    return season;
}
char *macro_fn_year(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    time_t c = sorted_rows[0]->date;
    struct tm *t = localtime(&c);
    char *year;
    ovs_asprintf(&year,"%d",t->tm_year+1900);
    return year;
}

char *macro_fn_cert_img(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *cert = util_tolower(sorted_rows[0]->certificate);
    char *tmp;

    tmp=replace_all(cert,"usa:","us:",0);
    free(cert);
    cert=tmp;


    tmp=replace_all(cert,":","/",0);
    free(cert);
    cert=tmp;

    ovs_asprintf(&tmp,"%s/images/cert/%s.%s",appDir(),cert,ovs_icon_type());
    free(cert);
    cert=tmp;

    char *attr;
    ovs_asprintf(&attr," width=%d height=%d ",g_dimension->certificate_size,g_dimension->certificate_size);

    tmp = get_local_image_link(cert,sorted_rows[0]->certificate,attr);
    free(attr);

    return tmp;
}

char *macro_fn_tv_listing(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    int rows=0;
    int cols=0;
    html_log(0,"macro_fn_tv_listing");
    if (!get_rows_cols(call,args,&rows,&cols)) {
        rows = 10;
        cols = 2;
    }
    return tv_listing(num_rows,sorted_rows,rows,cols);
}



char *macro_fn_movie_listing(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return movie_listing(sorted_rows[0]);
}

char *macro_fn_tvids(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return get_tvid_links(sorted_rows);
}

char *macro_fn_rating_stars(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return STRDUP("rating_starts");
}

char *macro_fn_grid(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    int rows=0;
    int cols=0;
    if (!get_rows_cols(call,args,&rows,&cols)) {
        rows = g_dimension->rows;
        cols = g_dimension->cols;
    }
    return get_grid(get_current_page(),rows,cols,num_rows,sorted_rows);
}

char *macro_fn_header(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return STRDUP("header");
}

char *macro_fn_hostname(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    *free_result=0;
    return util_hostname();
}

char *macro_fn_form_start(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

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
    ovs_asprintf(&result,"<form action=\"%s\" enctype=\"multipart/form-data\" method=POST >\n%s",url,
            (hidden?hidden:"")
        );
    free(hidden);
    return result;
}

char *macro_fn_is_gaya(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    *free_result=0;
    if (g_dimension->local_browser) {
        return "1";
    } else {
        return "0";
    }
}

char *macro_fn_include(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    if (args && args->size == 1) {
        display_template(template_name,args->array[0],num_rows,sorted_rows);
    } else if (!args) {
        html_error("missing  args for include");
    } else {
        html_error("number of args for include = %d",args->size);
    }
    return NULL;
}

char *macro_fn_start_cell(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    *free_result=0;

    if (*query_val(QUERY_PARAM_REGEX)) {
        return "filter5";
    } else {
        return "centreCell";
    }

}
char *macro_fn_media_type(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    *free_result=0;
    char *mt="?";
    switch(*query_val(QUERY_PARAM_TYPE_FILTER)) {
        case 'T': mt="TV Shows"; break;
        case 'M': mt="Movies"; break;
        default: mt="All Video"; break;
    }

    return mt;
}
char *macro_fn_version(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    char *version=OVS_VERSION;
    version +=4;
    return replace_all(version,"BETA","b",0);

}

char *macro_fn_media_toggle(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    return get_toggle("red",QUERY_PARAM_TYPE_FILTER,
            QUERY_PARAM_MEDIA_TYPE_VALUE_TV,"Tv",
            QUERY_PARAM_MEDIA_TYPE_VALUE_MOVIE,"Film");

}
char *macro_fn_watched_toggle(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return get_toggle("green",QUERY_PARAM_WATCHED_FILTER,
            QUERY_PARAM_WATCHED_VALUE_NO,"Unmarked",
            QUERY_PARAM_WATCHED_VALUE_YES,"Marked");
}
char *macro_fn_sort_type_toggle(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return get_toggle("blue",QUERY_PARAM_SORT,
            DB_FLDID_TITLE,"Name",
            DB_FLDID_INDEXTIME,"Age");
}
char *macro_fn_filter_bar(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

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

char *macro_fn_status(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
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


char *macro_fn_setup_button(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return get_theme_image_link("view=admin&action=ask","TVID=SETUP","configure","");
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

char *macro_fn_left_button(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    int on = get_current_page() > 0;

    return get_page_control(on,-1,"pgup","left");
}




char *macro_fn_right_button(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    int on = ((get_current_page()+1)*g_dimension->rows*g_dimension->cols < num_rows);

    return get_page_control(on,1,"pgdn","right");
}



char *macro_fn_back_button(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (*query_val("view") && !*query_val("select")) {
        result = get_theme_image_link("view=&idlist=","name=up","back","");
    }
    return result;
}

char *macro_fn_home_button(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;

    if(!*query_val("select")) {
        char *tag=get_theme_image_tag("home",NULL);
        ovs_asprintf(&result,"<a href=\"%s?\" name=home TVID=HOME >%s</a>",SELF_URL,tag);
        free(tag);
    }

    return result;
}

char *macro_fn_exit_button(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;

    if(g_dimension->local_browser && !*query_val("select")) {
        char *tag=get_theme_image_tag("exit",NULL);
        ovs_asprintf(&result,"<a href=\"/start.cgi\" name=home >%s</a>",tag);
        free(tag);
    }
    return result;
}

char *macro_fn_mark_button(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (!*query_val("select") && allow_mark()) {
        result = get_theme_image_link("select=Mark","tvid=EJECT","mark","");
    }
    return result;
}

char *macro_fn_delete_button(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (!*query_val("select") && (allow_delete() || allow_delist())) {
        result = get_theme_image_link("select=Delete","tvid=CLEAR","delete","");
    }
    return result;
}
char *macro_fn_select_mark_submit(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (strcmp(query_val("select"),"Mark")==0) {
        ovs_asprintf(&result,"<input type=submit name=action value=Mark >");
    }
    return result;
}
char *macro_fn_select_delete_submit(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (strcmp(query_val("select"),"Delete")==0) {
        ovs_asprintf(&result,"<input type=submit name=action value=Delete >");
    }
    return result;
}
char *macro_fn_select_delist_submit(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (strcmp(query_val("select"),"Delete")==0) {
        ovs_asprintf(&result,"<input type=submit name=action value=Remove_From_List >");
    }
    return result;
}
char *macro_fn_select_cancel_submit(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (*query_val("select")) {
        ovs_asprintf(&result,"<input type=submit name=select value=Cancel >");
    }
    return result;
}
char *macro_fn_external_url(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
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

char *macro_fn_font_size(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return numeric_constant_macro(g_dimension->font_size,args);
}
char *macro_fn_title_size(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return numeric_constant_macro(g_dimension->title_size,args);
}
char *macro_fn_scanlines(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return numeric_constant_macro(g_dimension->scanlines,args);
}

char *macro_fn_play_tvid(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *text="";
    if (args && args->size > 0)  {
        text = args->array[0];
    }
    return get_play_tvid(text);
}

void macro_init() {

    if (macros == NULL) {
        //html_log(0,"begin macro init");
        macros = string_string_hashtable(32);

        hashtable_insert(macros,"PLOT",macro_fn_plot);
        hashtable_insert(macros,"POSTER",macro_fn_poster);
        hashtable_insert(macros,"CERTIFICATE_IMAGE",macro_fn_cert_img);
        hashtable_insert(macros,"MOVIE_LISTING",macro_fn_movie_listing);
        hashtable_insert(macros,"TV_LISTING",macro_fn_tv_listing);
        hashtable_insert(macros,"EXTERNAL_URL",macro_fn_external_url);
        hashtable_insert(macros,"TITLE",macro_fn_title);
        hashtable_insert(macros,"GENRE",macro_fn_genre);
        hashtable_insert(macros,"SEASON",macro_fn_season);
        hashtable_insert(macros,"YEAR",macro_fn_year);
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
        hashtable_insert(macros,"BACK_BUTTON",macro_fn_back_button);
        hashtable_insert(macros,"HOME_BUTTON",macro_fn_home_button);
        hashtable_insert(macros,"EXIT_BUTTON",macro_fn_exit_button);
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
        hashtable_insert(macros,"PLAY_TVID",macro_fn_play_tvid);
        hashtable_insert(macros,"TVIDS",macro_fn_tvids);
        //html_log(0,"end macro init");
    }
}

char *macro_call(char *template_name,char *call,int num_rows,DbRowId **sorted_rows,int *free_result) {


    if (macros == NULL) macro_init();

    char *result = NULL;
    char *(*fn)(char *template_name,char *name,Array *args,int num_rows,DbRowId **,int *) = NULL;
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
        //html_log(0,"begin macro [%s]",call);
        *free_result=1;
        result =  (*fn)(template_name,call,args,num_rows,sorted_rows,free_result);
        //html_log(0,"end macro [%s]",call);
    } else {
        html_error("no macro [%s]",call);
        printf("?%s?",call);
    }
    array_free(args);
    return result;
}

