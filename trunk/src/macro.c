// $Id:$
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <assert.h>
#include <ctype.h>
#include <sys/statvfs.h>
#include <sys/types.h>

#include "types.h"
#include "grid.h"
#include "template.h"
#include "template_condition.h"
#include "hashtable.h"
#include "hashtable_loop.h"
#include "array.h"
#include "util.h"
#include "oversight.h"
#include "db.h"
#include "dbnames.h"
#include "dbplot.h"
#include "display.h"
#include "tv_detail.h"
#include "movie_detail.h"
#include "grid_display.h"
#include "dboverview.h"
#include "display.h"
#include "gaya_cgi.h"
#include "macro.h"
#include "dbfield.h"
#include "mount.h"
#include "gaya.h"
#include "actions.h"
#include "vasprintf.h"
#include "variables.h"
#include "mount.h"

#define NO_ARGS(x) (!(x)->args || (x)->args->size == 0)
#define HAS_ARGS(x,n) ((x)->args && (x)->args->size == (n) )

typedef enum { FILE_PATH , FILE_ENC , FILE_VOD } FileAspect;


static struct hashtable *macros = NULL;
char *image_path_by_resolution(char *skin_name,char *name);
char *get_named_arg(struct hashtable *h,char *name);
struct hashtable *args_to_hash(MacroCallInfo *call,char *required_list,char *optional_list);
void free_named_args(struct hashtable *h);
char *macro_fn_background_url(MacroCallInfo *call_info);
char *macro_fn_file_general(MacroCallInfo *call_info,FileAspect aspect);
Array *js_array(DbSortedRows *rows,int max,Array *fields);
void loop_expand(char *loop_name,Array *loop_body,char *loop_value,Array *out,int max);
char *image_url(MacroCallInfo *call_info,ImageType type);
int get_page_max(int *maxptr,MacroCallInfo *call_info);
int get_page_size(int *size,MacroCallInfo *call_info);
long numeric_constant_eval_str(long val,char *expression);
int check_index(MacroCallInfo *call_info,int index);
char *drilldown_url_by_item(DbItem *item,int position);
char *menu_page_url(MacroCallInfo *call_info,int offset_in);

// This value is added to indexed lookups for FILE_VOD BANNER_URL etc.
// By default it refers to first selected data item.
// IT can be changed using PAGE(align_data) macro.
static int aligned_data_offset = 0;

int has_rows(MacroCallInfo *call_info,int report)
{
    int ret = 1;
    if (!call_info->sorted_rows || !call_info->sorted_rows->num_rows) {
        if (report) html_error("no rows");
        ret = 0;
    }
    return ret;
}

Db *firstdb(MacroCallInfo *call_info)
{
    Db *result = NULL;
    DbSortedRows *sorted_rows = call_info->sorted_rows;

    if (has_rows(call_info,1)) {
        DbItem *item = sorted_rows->rows[0];
        result = item->db;
    }
    return result;
}

/*
 * Return path to a person domain file for a given database.
 * eg. /blah/blah/actor.imdb.db
 * eg. /blah/blah/director.allocine.db
 *
 * must be freed.
 */
char *get_person_domain_filename(Db *db,char *role,char *domain)
{
    char *file = NULL;
    char *domain_file = NULL;

    assert(db);
    assert(role);
    assert(domain);

    file = db->people_file;
    if (file) {
        char *ext = strrchr(file,'.');
        if (ext) {
            ovs_asprintf(&domain_file,"%.*s.%s%s",ext-file,file,domain,ext);
        }
    }
    return domain_file;
}

/**
 * This is where we may start feeling the pain for not using a proper database.
 * Scan the *entire* file for field2 and then return field1.
 */
char *person_reverse_lookup(char *file,char *field2)
{
    int field2len;
    char *result = NULL;
    FILE *fp = util_open(file,"r");
    if (fp) {
        field2len = strlen(field2);
#define PERSON_BUFSIZE 99
        char buf[PERSON_BUFSIZE+1] = "";

        while(fgets(buf,PERSON_BUFSIZE,fp)) {
            char *tab = strchr(buf,'\t');
            if (tab) {
                if (util_starts_with(tab+1,field2) && strchr("\n\r",tab[1+field2len])) {
                    ovs_asprintf(&result,"%.*s",tab-buf,buf);
                    break;
                }
            }
        }
        fclose(fp);
    }
    HTML_LOG(0,"%s:%s=[%s]",file,field2,result);
    return result;
}

char *person_id(Db *db,char *ovs_id,char *role,char *domain) {
    char *domain_file=get_person_domain_filename(db,role,domain);
    char *result = person_reverse_lookup(domain_file,ovs_id);
    FREE(domain_file);
    return result;
}

/*
 * User current QUERY_PARAM_PERSON and QUERY_PARAM_PERSON_ROLE parameters to find 
 * a persons domain specific id.
 */
char *current_person_id(Db *db,char *domain) {
    return person_id(db,query_val(QUERY_PARAM_PERSON),query_val(QUERY_PARAM_PERSON_ROLE),domain);
}

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

/*
 * =begin wiki
 * ==DETAILS_URL==
 *
 * Generate a URL to drill down to this item.
 * [:DETAILS_URL(index=>item_no):]
 *
 * If position is supplied this is preserved as query value i=
 * This allows a back button to return the the selected item on the grid.
 * [:DETAILS_URL(index=>item_no,position=>pos):]
 *
 * =end wiki
 */
char *macro_fn_details(MacroCallInfo *call_info)
{
    int index=0;
    int pos=0;
    char *result=NULL;
    if (!has_rows(call_info,1)) {

        call_info->free_result=0;
        return "?";

    } else {

        struct hashtable *h = args_to_hash(call_info,"%index","%position");

        if (h) {

            util_parse_int(get_named_arg(h,"index"),&index,0);
            util_parse_int(get_named_arg(h,"position"),&pos,0);

            index += aligned_data_offset;
            if(check_index(call_info,index)) {
                result = drilldown_url_by_item(call_info->sorted_rows->rows[index-1],pos);
            }
            free_named_args(h);
        }
    }

    return result;
}

/**
 * =begin wiki
 * ==FANART_URL==
 *
 * FANART_URL(default_image)
 * FANART_URL(default=>image,index=>nn)
 * Display image  by looking for fanart for the first db item. If not present then look in the fanart db, otherwise
 * use the named image from skin/720 or skin/sd folder. Also see BACKGROUND_URL BANNER_URL POSTER_URL THUMB_URL
 *
 * =end wiki
**/  
char *macro_fn_fanart_url(MacroCallInfo *call_info)
{
    if (*oversight_val("ovs_display_fanart") == '0' ) {

        return macro_fn_background_url(call_info);
    } else {
        return image_url(call_info,FANART_IMAGE);
    }
}

/**
 * =begin wiki
 * ==POSTER_URL==
 *
 * POSTER_URL(default_image)
 * POSTER_URL(default=>image,index=>nn)
 * Display image  by looking for fanart for the first db item. If not present then look in the Oversight db, otherwise
 * use the named image from skin/720 or skin/sd folder. Also see BACKGROUND_URL FANART_URL BANNER_URL THUMB_URL
 *
 * =end wiki
**/  
char *macro_fn_poster_url(MacroCallInfo *call_info)
{
    return image_url(call_info,POSTER_IMAGE);
}
/**
 * =begin wiki
 * ==THUMB_URL==
 *
 * THUMB_URL(default_image)
 * THUMB_URL(default=>image,index=>nn)
 * Display small poster image  of db item. If not present then look in the Oversight db, otherwise
 * use the named image from skin/720 or skin/sd folder. Also see BACKGROUND_URL FANART_URL POSTER_URL BANNER_URL
 *
 * =end wiki
**/  
char *macro_fn_thumb_url(MacroCallInfo *call_info)
{
    return image_url(call_info,THUMB_IMAGE);
}
/**
 * =begin wiki
 * ==BANNER_URL==
 *
 * THUMB_URL(default_image)
 * THUMB_URL(default=>image,index=>nn)
 * Display  banner image for db item. If not present then look in the Oversight db, otherwise
 * use the named image from skin/720 or skin/sd folder. Also see BACKGROUND_URL FANART_URL POSTER_URL THUMB_URL
 *
 * =end wiki
**/  
char *macro_fn_banner_url(MacroCallInfo *call_info)
{
    return image_url(call_info,BANNER_IMAGE);
}
char *image_url(MacroCallInfo *call_info,ImageType type)
{

    char *result = NULL;
    char *default_image=NULL;
    int index=1;
    struct hashtable *h=NULL;

    if (!has_rows(call_info,1)) {

        call_info->free_result=0;
        return "?";

    } else {

        h = args_to_hash(call_info,NULL,"default,%index");

        if (h) {

            default_image = get_named_arg(h,"default");

            util_parse_int(get_named_arg(h,"index"),&index,0);

        } else  if (HAS_ARGS(call_info,1)) {

            if (call_info->args && call_info->args->size == 1 ) {

                default_image = call_info->args->array[0];
            }
        } else {
            ovs_asprintf(&result,"%s([default image]) OR (default=>image,index=>nn)",call_info->call);
        }
    }
    index += aligned_data_offset;

    if (index > call_info->sorted_rows->num_rows) {
        html_error("index [%d] too big",index);
        index = 1;
    }
    index--;
    char *path = get_picture_path(1,call_info->sorted_rows->rows+index,type,NULL);

    if (!path || !exists(path)) {

        if (default_image) {

            path = image_path_by_resolution(call_info->skin_name,default_image);

        }
    }

    result  = file_to_url(path);
    FREE(path);
    free_named_args(h);
    return result;
}

// used to find resolution dependent images - normally for wallpapers.
char *image_path_by_resolution(char *skin_name,char *name)
{
    char *result = NULL;
    // Use default wallpaper

    if (g_dimension->scanlines == 0 ) {
        ovs_asprintf(&result,"%s/templates/%s/sd/%s",appDir(),skin_name,name);
    } else {
        ovs_asprintf(&result,"%s/templates/%s/%d/%s",appDir(),skin_name,g_dimension->scanlines,name);
    }
    return result;
}

char *macro_fn_web_status(MacroCallInfo *call_info) {
    char *result = NULL;

    if (call_info->args == NULL || call_info->args->size == 0  || call_info->args->size > 2 ) {
        call_info->free_result=0;
        result = "WEB_STATUS(url[,expected text])";
    } else {
        // If expected text is present prepare grep command to check wget output
        char *expected_text = NULL;
        if (call_info->args->size == 2 ) {
            // wget | grep -q causes broken pipe unless wget has -q also.
            ovs_asprintf(&expected_text," -O - | grep  -q \"%s\"",call_info->args->array[1]);
        } else {
            // otherwise silence wget.
            expected_text = STRDUP(" -O /dev/null");
        }

        char *cmd;

        ovs_asprintf(&cmd,"wget -U \"%s\" -q -t 1 --dns-timeout 3 --connect-timeout 3 --read-timeout 20 --ignore-length \"%s%s\" %s",
                USER_AGENT,
                (util_starts_with(call_info->args->array[0],"http")?"":"http://"),
                call_info->args->array[0],
                expected_text);

        //HTML_LOG(0,"web status cmd [%s]",cmd);
        int ok = system(cmd) == 0;
        HTML_LOG(0,"web status result (1=good) %d",ok);
        FREE(cmd);
        char *good = get_theme_image_tag("ok"," class=webstatus ");
        char *bad = get_theme_image_tag("cancel"," class=webstatus ");
        result = STRDUP((ok?good:bad));
        FREE(good);
        FREE(bad);
        FREE(expected_text);
    }

    return result;
}

char *macro_fn_mount_status(MacroCallInfo *call_info) {
    struct hashtable *mounts = mount_points_hash();
    struct hashtable_itr *itr;
    char *tmp;
    char *k,*v;
    char *result = NULL;
    if (mounts) {
        char *good = get_theme_image_tag("ok"," class=nasstatus ");
        char *bad = get_theme_image_tag("cancel"," class=nasstatus ");
        itr = hashtable_loop_init(mounts) ;
        while(hashtable_loop_more(itr,&k,&v)) {
            if (v) {
                if (util_starts_with(k,NETWORK_SHARE)) {
                    k += strlen(NETWORK_SHARE);
                }
                char *image = NULL;

                if (strcmp(v,MOUNT_STATUS_IN_MTAB) == 0 ||  strcmp(v,MOUNT_STATUS_NOT_IN_MTAB) == 0) {
                    image = NULL;
                } else if (strcmp(v,MOUNT_STATUS_OK) == 0) {
                    image = good;
                } else if (strcmp(v,MOUNT_STATUS_BAD) == 0) {
                    image = bad;
                }

                if (image) {
                    ovs_asprintf(&tmp,"%s<tr><td class=mount%s>%s %s</td></tr>",
                        NVL(result),v,image,k);
                    FREE(result);
                    result = tmp;
                }
            }
        }
        FREE(good);
        FREE(bad);
    }
    ovs_asprintf(&tmp,"<table><tr><th>NAS Status</th></tr>%s</table>",NVL(result));
    FREE(result);
    result = tmp;

    return result;
}

/**
 * Return Actor Image tag. additional tag attributes can be passed as argument.
 * [:PERSON_IMAGE:]
 * [:PERSON_IMAGE(attributes):]
 *
 * Example:
 * [:PERSON_IMAGE(height="100px"):]
 *
 */
char *macro_fn_person_image(MacroCallInfo *call_info)
{
    char *attr = "";
    char *result = NULL;
    char *name_id = query_val(QUERY_PARAM_PERSON);
    if (!EMPTY_STR(name_id)) {

        // We need one DbItem to get Db information if we need to mount crossview etc.
        DbItem *item = NULL;
        if (has_rows(call_info,1)) {
            item = call_info->sorted_rows->rows[0];

            //Get class info from parameter
            
            if (call_info->args && call_info->args->size ) {
                attr=(char *)call_info->args->array[0];
            }
            char *path = actor_image_path(item,name_id);

            Array *name_info = dbnames_fetch(name_id,item->db->people_file);

            result = get_local_image_link(path,"",attr);

            FREE(path);
            array_free(name_info);
        } else {
            HTML_LOG(0,"no db row to get actor info");
        }
    }
    return result;
}

/**
 * =begin wiki
 * ==POSTER==
 *
 * Display poster for current item.
 *
 * [:POSTER:]
 * [:POSTER(attributes):]
 *
 * =end wiki
 */
char *macro_fn_poster(MacroCallInfo *call_info)
{
    char *result = NULL;

    if (!has_rows(call_info,1)) {
        call_info->free_result=0;
        return "?";
    }

    DbItem *item=call_info->sorted_rows->rows[0];

    if (call_info->sorted_rows->num_rows == 0) {

       call_info->free_result=0;
       result = "poster - no rows";

    } else if (call_info->args && call_info->args->size  == 1) {

        result = get_poster_image_tag(item,call_info->args->array[0],POSTER_IMAGE,NULL);


    } else if (!call_info->args || call_info->args->size == 0 ) {

        char *attr;
        long height;
        long width;


        if (item) {

            if (item->category == 'T') {
                height=g_dimension->tv_img_height;
                width=g_dimension->tv_img_width;
            } else {
                height=g_dimension->movie_img_height;
                width=g_dimension->movie_img_width;
            }
            ovs_asprintf(&attr," height=%d width=%d  ",height,width);

            result =  get_poster_image_tag(item,attr,POSTER_IMAGE,NULL);

            FREE(attr);

        } 


    } else {

        call_info->free_result = 0;
        result = "POSTER([attributes])";
    }
    return result;
}

/**
 * Return the current menu page number.
 */
char *macro_fn_page(MacroCallInfo *call_info)
{
    call_info->free_result=1;
    char *result = NULL;

    char *p = query_val(QUERY_PARAM_PAGE);
    int page = 1;
    if (p && *p) {
        page = atoi(p)+1;
    }
    ovs_asprintf(&result,"%d",page);

    return result;
}

#define PAGE_SIZE_VAR "_page_size"
/**
 * =begin wiki
 * ==PAGE_MAX==
 * Return the last page number by dividing number of items by the page size (aka grid size).
 * This does not take delisting into account, which may reduce the number of items.
 *
 * the page size is determined from the following items:
 * - the _page_size skin variable can be used (see [:SET_PAGE(size=>):] also [:SET(...}:]
 * - If the variable is not set then it is computed from current rows*cols. (this will force another parse of the template)
 *
 * Example:
 * [:PAGE_MAX:]
 * =end wiki
 */
char *macro_fn_page_max(MacroCallInfo *call_info)
{
    char *result = NULL;
    int max;

    if (get_page_max(&max,call_info)) {
        ovs_asprintf(&result,"%d",max);
    } else {
        result = CALL_UNCHANGED;
    }

    return result;
}

/**
 * =begin wiki
 * ==SET_PAGE==
 *
 * [:SET_PAGE(size=>n,[align_data=>1]):]
 *
 * This will tell the template the number of elements in a page. 
 * If not present then other macros (eg PAGE_MAX)  may force a reparse of the template if the page size is not know during the current parse..
 * This will set temprary variable - _page_size that will be used to calculate PAGE_MAX and wrap around behaviour of MENU_PAGE_NEXT/PREV_URL
 *
 * If align_data is set then the correct offset will be added to the fields
 * FILE_VOD FILE_ENC FILE_PATH FANART_IMAGE BANNER_IMAGE THUMB_IMAGE etc.
 *
 * =end wiki
 */
char *macro_fn_set_page(MacroCallInfo *call_info)
{

    static int set=0;
    char *result = NULL;
    if (set) {
        html_error("page size already set - ignoring");
    } else {
        struct hashtable *h = args_to_hash(call_info,"%size","%align_data");

        char *size_str = get_named_arg(h,"size");
        int size;
        set_tmp_skin_variable(PAGE_SIZE_VAR,size_str);

        char *align=get_named_arg(h,"align_data");
        if (!EMPTY_STR(align) && *align == '1') {

            int page=0;
            char *page_str = query_val("p");
            if (!EMPTY_STR(page_str)) util_parse_int(page_str,&page,1);

            if (util_parse_int(size_str,&size,1)) {
                aligned_data_offset = size * page;
                HTML_LOG(0,"Setting data offset %d page=%d page_size=%d ",aligned_data_offset,page,size);
            }
        }
        free_named_args(h);
        set = 1;
    }
    return result;
}


// Clean up static allocated data - we dont really have to do this as process is ending.
void macro_cleanup()
{
}

char *macro_fn_plot(MacroCallInfo *call_info)
{
    call_info->free_result=1;
    char *result = NULL;

    if (!has_rows(call_info,1)) {
        call_info->free_result=0;
        return "?";
    }


    int season = -1;
    int i;
    for ( i = 0 ; EMPTY_STR(result) && i < call_info->sorted_rows->num_rows ; i++ ) {
        DbItem *item = call_info->sorted_rows->rows[i];
        if (season == -1 || item->season != season ) {
            season = item->season;
            result = get_plot(item,PLOT_MAIN);
            HTML_LOG(1,"plot for %s %d %s = %s",item->title,item->season,item->episode,result);
        }
    }
    if (result) {
        // TODO plot should be freed???
        if (result[2] == ':') result += 3; // skip language qualifier
        result = STRDUP(result);
    }

    HTML_LOG(1,"plot[%s]",result);

    //char *clean = clean_js_string(result);

    return result;
}

char *macro_fn_sort_select(MacroCallInfo *call_info) {
    static char *result=NULL;

    if (!result) {
        struct hashtable *sort = string_string_hashtable("sort",4);
        hashtable_insert(sort,DB_FLDID_TITLE,"Name");
        hashtable_insert(sort,DB_FLDID_INDEXTIME,"Age");
        hashtable_insert(sort,DB_FLDID_YEAR,"Year");
        result =  auto_option_list(QUERY_PARAM_TYPE_FILTER,DB_FLDID_INDEXTIME,sort);
        hashtable_destroy(sort,0,NULL);
    }
    call_info->free_result = 0;
    return result;
}

/**
 * Takes a parameter list of form
 *
 *  Label/Range   where Range=num1-num2 or Empty (all)
 * eg.
 *
 * [:RATING_SELECT(All/,Low/0-6,Good/6.1-7.6,Classic/7.7-10):]
 *
 */
char *macro_fn_rating_select(MacroCallInfo *call_info)
{
    static char *result=NULL;
    if (!result) {
        struct hashtable *rating = string_string_hashtable("rating",4);

        char *first = NULL;
        Array *args = call_info->args;
        if (args) {
            int i;
            for(i = 0 ; i < args->size ; i++ ) { 

                char *arg = args->array[i];

                char *range = strchr(arg,'/');
                if (range == NULL ){
                    html_error("bad arg [%s] expect format label/num1-num2 or label/",arg);
                } else {
                    range++;
                    if (first == NULL) first = range;
                    hashtable_insert(rating,range,COPY_STRING(range-arg-1,arg));
                }
            }
        }
        result =  auto_option_list(QUERY_PARAM_RATING,first,rating);
        hashtable_destroy(rating,0,free);
    }
    call_info->free_result = 0;
    return result;
}

char *macro_fn_media_select(MacroCallInfo *call_info)
{
    static char *result=NULL;
    if (!result) {
    //    char *label;
    //    if (g_dimension->scanlines == 0) {
    //        label = "Tv+Mov";
    //    } else {
    //        label = "Tv+Movie";
    //    }
        struct hashtable *category = string_string_hashtable("category",4);

        char *both=QUERY_PARAM_MEDIA_TYPE_VALUE_MOVIE QUERY_PARAM_MEDIA_TYPE_VALUE_TV;
        hashtable_insert(category,both,"All");

        hashtable_insert(category,QUERY_PARAM_MEDIA_TYPE_VALUE_MOVIE,"Movie");
        hashtable_insert(category,QUERY_PARAM_MEDIA_TYPE_VALUE_TV,"Tv");
		hashtable_insert(category,QUERY_PARAM_MEDIA_TYPE_VALUE_OTHER,"Other");

        result =  auto_option_list(QUERY_PARAM_TYPE_FILTER,both,category);
        hashtable_destroy(category,0,NULL);
    }
    call_info->free_result = 0;
    return result;
}

/*
 * =begin wiki
 * ==WATCHED_SELECT==
 * Display Watched/Unwatched selection.
 *
 * [:WATCHED_SELECT:]
 * =end wiki
 */
char *macro_fn_watched_select(MacroCallInfo *call_info) {
    static char *result=NULL;
    if (!result) {
        struct hashtable *watched = string_string_hashtable("watched_menu",4);
        hashtable_insert(watched,QUERY_PARAM_WATCHED_VALUE_ANY,"---");
        hashtable_insert(watched,QUERY_PARAM_WATCHED_VALUE_YES,"Watched");
        hashtable_insert(watched,QUERY_PARAM_WATCHED_VALUE_NO,"Unwatched");
        result =  auto_option_list(QUERY_PARAM_WATCHED_FILTER,QUERY_PARAM_WATCHED_VALUE_ANY,watched);
        hashtable_destroy(watched,0,NULL);
    }
    call_info->free_result = 0;
    return result;
}

/*
 * =begin wiki
 * ==LOCKED_SELECT==
 * Display Locked/Unlocked selection.
 *
 * [:LOCKED_SELECT:]
 * =end wiki
 */
char *macro_fn_locked_select(MacroCallInfo *call_info) {
    static char *result=NULL;
    if (!result) {
        struct hashtable *locked = string_string_hashtable("locked_menu",4);
        hashtable_insert(locked,QUERY_PARAM_LOCKED_VALUE_ANY,"---");
        hashtable_insert(locked,QUERY_PARAM_LOCKED_VALUE_YES,"Locked");
        hashtable_insert(locked,QUERY_PARAM_LOCKED_VALUE_NO,"Unlocked");
        result =  auto_option_list(QUERY_PARAM_LOCKED_FILTER,QUERY_PARAM_LOCKED_VALUE_ANY,locked);
        hashtable_destroy(locked,0,NULL);
    }
    call_info->free_result = 0;
    return result;
}

// Checkbox list of scan options
char *macro_fn_checkbox(MacroCallInfo *call_info) {
    static char *result=NULL;
    if (!call_info->args || call_info->args->size < 3 ) {
        result = "CHECKBOX(htmlname_prefix,checked,htmlsep,values,..,..,)";
        call_info->free_result = 0;
    } else {

        int i;
        char *htmlname=call_info->args->array[0];
        char *checked=call_info->args->array[1];
        char *sep=call_info->args->array[2];
        int first = 1;

        for(i = 3 ; i < call_info->args->size ; i++ ) {
            char *tmp;
            char *val = call_info->args->array[i];
            if (val && *val && STRCMP(val,"\"\"") != 0 ) {
                ovs_asprintf(&tmp,"%s%s<input type=checkbox name=\"%s%s\" %s>%s",
                    NVL(result),(first==1?"":sep),htmlname,val,checked,val);
                first = 0;
                FREE(result);
                result = tmp;
            }
        }
    }
    return result;
}
char *macro_fn_episode_total(MacroCallInfo *call_info) {
    static char result[10]="";
    call_info->free_result=0;
    if (!*result) {
        sprintf(result,"%d",g_episode_total);
    }
    return result;
}
/*
 * =begin wiki
 * ==EPISODE_COUNT
 * Number of episodes on this detail page
 * =end wiki
 */
char *macro_fn_episode_count(MacroCallInfo *call_info) {
    static char result[10]="";
    call_info->free_result=0;
    if (!*result) {
        if (call_info->sorted_rows) {
            sprintf(result,"%d",call_info->sorted_rows->num_rows);
        }
    }
    return result;
}

char *macro_fn_movie_total(MacroCallInfo *call_info)
{
    static char result[10]="";
    call_info->free_result=0;
    if (!*result) {
        sprintf(result,"%d",g_movie_total);
    }
    return result;
}
char *macro_fn_other_media_total(MacroCallInfo *call_info)
{
    static char result[10]="";
    call_info->free_result=0;
    if (!*result) {
        sprintf(result,"%d",g_other_media_total);
    }
    return result;
}


/*
 * Return index selection list with item selected.
 */
char *title_index(AbetIndex *ai,char *query_param_name)
{
    char *result = NULL;

    if (ai) {
        struct hashtable *title = string_string_hashtable("index",30);

        char *k;
        AbetLetterCount *v;
        struct hashtable_itr *itr ;
        hashtable_insert(title,"","-");
        for(itr = hashtable_loop_init(ai->index); hashtable_loop_more(itr,&k,&v) ; ) {
            if (v->count) {
                hashtable_insert(title,k,k);
            }
        }

        result = auto_option_list(query_param_name,"",title);
        hashtable_destroy(title,0,NULL);
    }
    return result;
}

char *macro_fn_title_select(MacroCallInfo *call_info)
{
    static char *result=NULL;
    if (!result) {

        HTML_LOG(1,"macro_fn_title_select");
        result = title_index(g_abet_title,QUERY_PARAM_TITLE_FILTER);
    }
    call_info->free_result = 0;
    return result;
}

char *macro_fn_genre_select(MacroCallInfo *call_info)
{
    static char *result = NULL;
    if (g_genre_hash != NULL) {

        // Expand the genre hash table
        struct hashtable *expanded_genres = string_string_hashtable("genre_menu",16);
        char *k,*v;
        struct hashtable_itr *itr;
        for(itr = hashtable_loop_init(g_genre_hash) ; hashtable_loop_more(itr,&k,&v) ; ) {
            char *val = expand_genre(v);

            if (!hashtable_search(expanded_genres,val)) {
                hashtable_insert(expanded_genres,STRDUP(val),val);
            }
        }

        if (!hashtable_search(expanded_genres,"")) {
            hashtable_insert(expanded_genres,STRDUP(""),STRDUP("All Genres"));
        }
        result = auto_option_list(DB_FLDID_GENRE,"",expanded_genres);
        call_info->free_result = 0; // TODO : this should be freed but we'll leave until next release.
        hashtable_destroy(expanded_genres,1,free);
    }
    return result;
}

/*
 * =begin wiki
 * ==FLUSH==
 *
 * Flush macro output. For debugging. [:FLUSH:]
 * =end wiki
 */
char *macro_fn_flush(MacroCallInfo *call_info)
{
    html_flush();
    return NULL;
}
char *macro_fn_genre(MacroCallInfo *call_info)
{

    char *genre = "";
    call_info->free_result=0;

    if (has_rows(call_info,1) && call_info->sorted_rows->rows[0]->genre ) {
        call_info->free_result=1;
        genre =expand_genre(call_info->sorted_rows->rows[0]->genre);
    }

    return genre;
}

/**
 * =begin wiki
 * ==ORIG_TITLE==
 * Can Also use $field_ORIG_TITLE
 * =end wiki
 **/
char *macro_fn_orig_title(MacroCallInfo *call_info) {

    char *result = "?";
    call_info->free_result=0;

    if (has_rows(call_info,1) && call_info->sorted_rows->rows[0]->orig_title ) {
        result = call_info->sorted_rows->rows[0]->orig_title;
    } 
    return result;
}

/**
 * =begin wiki
 * ==TITLE==
 * Can Also use $field_TITLE
 * =end wiki
 **/
char *macro_fn_title(MacroCallInfo *call_info) {

    char *result = "?";
    call_info->free_result=0;

    if (has_rows(call_info,1) && call_info->sorted_rows->rows[0]->title ) {
        result = call_info->sorted_rows->rows[0]->title;
    } 
    return result;
}

char *macro_fn_set(MacroCallInfo *call_info)
{
    if (call_info->args == NULL || call_info->args->size != 2 ) {
        html_error("invalid arguments [:%s(name,val):]",call_info->call);
    } else {
        set_tmp_skin_variable(call_info->args->array[0],call_info->args->array[1]);
    }
    return NULL;
}

char *macro_fn_season(MacroCallInfo *call_info) {

    char *season="?";
    call_info->free_result=0;

    if (has_rows(call_info,1) && call_info->sorted_rows->rows[0]->season >=0) {
        ovs_asprintf(&season,"%d",call_info->sorted_rows->rows[0]->season);
        call_info->free_result=1;
    }
    return season;
}
int chartotal(char *s,char *c) {
    int total =0;
    while (*s) {
        if (strchr(c,*s++)) total++;
    }
    return total;
}

char *macro_fn_runtime(MacroCallInfo *call_info) {

    int runtime = 0;
    int i;
    if (has_rows(call_info,1)) {
        for(i = 0 ; i < call_info->sorted_rows->num_rows ; i++ ) {
            DbItem *item = call_info->sorted_rows->rows[i];
            if (item->runtime > 0 ) {
                runtime = item->runtime;
                break;
            }
        }
    }

    HTML_LOG(0,"runtime=[%d]",runtime);

    if (runtime == 0) {
        call_info->free_result=0;
        return NULL;
    }

#define MAX_RUNTIME 30
    static char runtime_str[MAX_RUNTIME+1];
    char *hm_format = oversight_val("ovs_hm_runtime_format");
    char *m_format = oversight_val("ovs_m_runtime_format");

    HTML_LOG(0,"ovs_hm_runtime_format[%s]",hm_format);
    HTML_LOG(0,"ovs_m_runtime_format[%s]",m_format);

    runtime_str[MAX_RUNTIME]='\0';
    if (runtime >= 60 ) {

        if (chartotal(hm_format,"%") > 1 ) {
            sprintf(runtime_str,hm_format,runtime/60,runtime%60);
        } else {
            sprintf(runtime_str,hm_format,runtime);
        }

    } else {

        if (chartotal(m_format,"%") > 1 ) {
            sprintf(runtime_str,m_format,runtime/60,runtime%60);
        } else {
            sprintf(runtime_str,m_format,runtime);
        }
    }
    assert(runtime_str[MAX_RUNTIME] == '\0');
    HTML_LOG(0,"runtime[%d]m = [%s]",runtime,runtime_str);

    call_info->free_result = 0;
    return runtime_str;
}
char *macro_fn_year(MacroCallInfo *call_info) {

    int i;
    if (!has_rows(call_info,1) ) {
        call_info->free_result=0;
        return "?";
    }
    char *year = NULL;
    int year_num = 0;
   
    // look for item with year set - sometimes tv Pilot does not have airdate 
    for(i = 0 ; i < call_info->sorted_rows->num_rows && year_num <= 1900 ; i++ ) {
        DbItem *item = call_info->sorted_rows->rows[i];

        if (item->category == 'T' ) {

            struct tm *t = internal_time2tm(item->airdate,NULL);
            year_num = t->tm_year+1900;

        } else if (item->category != 'M' ) {

            struct tm *t = internal_time2tm(item->date,NULL);
            year_num = t->tm_year+1900;
        }
        if (item->category == 'M' || year_num == 1900) {
            year_num = item->year;
        }
    }
    if (year_num && year_num != 1900) {
        ovs_asprintf(&year,"%d",year_num);
    }
    return year;
}

char *macro_fn_cert_img(MacroCallInfo *call_info) {
    char *cert,*tmp;
    cert = tmp = NULL;

    if (!has_rows(call_info,1) ) {
        call_info->free_result=0;
        return "?";
    }

    if (*oversight_val("ovs_display_certificate") == '1') {

        cert = util_tolower(call_info->sorted_rows->rows[0]->certificate);

        if (!EMPTY_STR(cert)) {

            tmp=replace_str(cert,"usa:","us:");
            FREE(cert);
            cert=tmp;


            translate_inplace(cert,":_","/-");

            char *attr;
            ovs_asprintf(&attr," height=%d ",g_dimension->certificate_size);

            tmp = template_image_link("/cert",cert,NULL,call_info->sorted_rows->rows[0]->certificate,attr);
            if (tmp == NULL) {
                // Try to find the image without country prefix
                char *no_country = strchr(cert,'/');
                if (no_country) {
                    no_country++;
                    tmp = template_image_link("/cert",no_country,NULL,call_info->sorted_rows->rows[0]->certificate,attr);
                }
            }
            if (tmp) {
                // relace text with image.
                FREE(cert);
                FREE(attr);
                cert=tmp;
            }
        }
    }

    HTML_LOG(0,"xx cert[%s]",cert);
    return cert;
}

char *macro_fn_tv_listing(MacroCallInfo *call_info) {
    int rows=0;
    int cols=0;
    HTML_LOG(1,"macro_fn_tv_listing");

    if (!get_rows_cols(call_info->call,call_info->args,&rows,&cols)) {
        char sl[20];
        long rl=0,cl=0;
        sprintf(sl,"%ld",g_dimension->scanlines);
        config_check_long_indexed(g_oversight_config,"ovs_tv_rows",sl,&rl);
        config_check_long_indexed(g_oversight_config,"ovs_tv_cols",sl,&cl);
        //rows = atoi(oversight_val("ovs_tv_rows"));
        //cols = atoi(oversight_val("ovs_tv_cols"));
        if (rl) rows = rl ; else rows = 10;
        if (cl) cols = cl ; else cols = 4 + 2 * (g_dimension->scanlines > 600 );
    }
    return tv_listing(call_info->sorted_rows,rows,cols);
}


char *macro_fn_tv_paypal(MacroCallInfo *call_info) {
    char *result=NULL;

    return result;
}
char *macro_fn_tv_mode(MacroCallInfo *call_info) {

    static char *result = NULL;

    if (g_dimension->tv_mode == 0) {
        ovs_asprintf(&result,"<font class=error>Image size may be wrong in AUTO mode. Please change Video Output to best TV resolution.</font>");
    } else {
        ovs_asprintf(&result,"%d",g_dimension->tv_mode);
    }

    return result;
}

char *macro_fn_paypal(MacroCallInfo *call_info) {
    char *p = NULL;
    if (!(g_dimension->local_browser) && *oversight_val("remove_donate_msg") != '1' ) {
        p =
        "<form action=\"https://www.paypal.com/cgi-bin/webscr\" method=\"post\">"
        "<input type=\"hidden\" name=\"cmd\" value=\"_s-xclick\">"
        //"<input type=\"hidden\" name=\"hosted_button_id\" value=\"2496882\">"
        //"<input width=50px type=\"image\" src=\"https://www.paypal.com/en_US/i/btn/btn_donateCC_LG.gif\" border=\"0\" name=\"submit\" alt=\"\">"
        "<input type=\"hidden\" name=\"hosted_button_id\" value=\"9700071\">"
        "<input class=paypal type=\"image\" src=\"https://www.paypal.com/en_US/GB/i/btn/btn_donateCC_LG.gif\" border=\"0\" name=\"submit\" alt=\"PayPal - The safer, easier way to pay online.\">"
        "<img  alt=\"\" border=\"0\" src=\"https://www.paypal.com/en_GB/i/scr/pixel.gif\" width=\"1\" height=\"1\">"
        "</form> ";
        call_info->free_result=0;
    }

    return p;
}

char *macro_fn_sys_load_avg(MacroCallInfo *call_info) {

    char *result=NULL;
    double av[3];
#if 0
    if (getloadavg(av,3) == 3) {
        ovs_asprintf(&result,"1m:%.2lf/%.2lf/%.2lf",av[0],av[1],av[2]);
    }
#else
    FILE *fp = util_open("/proc/loadavg","r");
    if (fp) {
#define BLEN 99
        char buf[BLEN];
        while(fgets(buf,BLEN,fp) != NULL) {
            if (sscanf(buf,"%lf %lf %lf",av,av+1,av+2) == 3) {
                ovs_asprintf(&result,"%.2lf/%.2lf/%.2lf",av[0],av[1],av[2]);
                break;
            }
        }
        fclose(fp);
    }
#endif
    return result;
}

char *macro_fn_sys_uptime(MacroCallInfo *call_info) {

    static char result[50] = "";

    call_info->free_result = 0;
    if (!*result) {
        FILE *fp = util_open("/proc/uptime","r");
        if (fp != NULL) {
#define BUFSIZE 50
            char buf[BUFSIZE+1] = "";
            if (fgets(buf,BUFSIZE,fp)) {

                long upsecs;

                if (sscanf(buf,"%ld",&upsecs) == 1) {
                    int secs = upsecs % 60; upsecs -= secs ; upsecs /= 60;
                    int mins = upsecs % 60; upsecs -= mins ; upsecs /= 60;
                    int hrs = upsecs % 24; upsecs -= hrs ; upsecs /= 24;
                    int days = upsecs;
                    char *p = result;
                    if (days) p += sprintf(p,"%dday%s ",days,(days>1?"s":""));
                    if (hrs) p += sprintf(p,"%dhr%s ",hrs,(hrs>1?"s":""));
                    if (mins) p += sprintf(p,"%dm ",mins);
                }
            }
        }

    }
    return result;
}

char *macro_fn_movie_listing(MacroCallInfo *call_info) {
    return movie_listing(call_info->sorted_rows->rows[0]);
}

// add code for a star image to a buffer and return pointer to end of buffer.
char *add_star(int star_no) {

    char name[10];

    sprintf(name,"star%d",star_no);

    char *p;
    ovs_asprintf(&p,"<img src=\"%s\" \\>",image_source("stars",name,NULL));

    return p;
}

char *macro_fn_resize_controls(MacroCallInfo *call_info)
{

    char *result = NULL;
    if (get_view_mode(0) != VIEW_ADMIN) {
        result = get_tvid_resize_links();
    }
    return result;
    
}
char *macro_fn_tvids(MacroCallInfo *call_info)
{

    char *result = NULL;
    if (! *query_view_val()) {
        result = get_tvid_links();
    }
    return result;
    
}

char *get_rating_stars(DbItem *item,int num_stars)
{

    double rating = item->rating;

    Array *a = array_new(free);

    if (rating > 10) rating=10;

    rating = rating * num_stars / 10.0 ;

    int i;

    for(i = 1 ; i <= (int)(rating+0.0001) ; i++) {

        array_add(a,add_star(10));
        num_stars --;
    }

    int tenths = (int)(0.001+10*(rating - (int)(rating+0.001)));
    if (tenths) {
        array_add(a,add_star(tenths));
        num_stars --;
    }

    while(num_stars > 0 ) {

        array_add(a,add_star(0));
        num_stars--;
    }
    char *result = arraystr(a);
    array_free(a);

    return result;
}

/*
 * =begin wiki
 * ==RATING_STARS==
 *
 * RATING_STARS(numstars)
 *
 * This will make a rating bar based on the number of stars supplied.
 * You should have the following stars defined...
 *
 * eg  Consider a rating of 7.9/10 on a 5 star bar 
 *
 * 7.9/10 =~ 3.9/5
 * So 3 whole stars then a 0.9 star then an empty star.
 *
 * stat0.png this is an empty star.
 * star1.png = 0.1 star etc.
 * star10.png - this is a whole star.
 *
 * =end wiki
 */
char *macro_fn_rating_stars(MacroCallInfo *call_info) {
    char *result = NULL;
    int num_stars=0;
    char *star_path=NULL;

    if (!has_rows(call_info,1) ) {
        call_info->free_result=0;
        return "?";
    }
    if (*oversight_val("ovs_display_rating") != '0') {

        if (call_info->args && call_info->args->size == 1 && sscanf(call_info->args->array[0],"%d",&num_stars) == 1 ) {

            star_path=call_info->args->array[1];

            result = get_rating_stars(call_info->sorted_rows->rows[0],num_stars);

        } else {

            ovs_asprintf(&result,"%s(num_stars) %%d is replaced with 10ths of the rating, eg 7.9rating becomes star10.png*7,star9.png,star0.png*2)",call_info->call);
        }
    }
        
    return result;
}

char *macro_fn_source(MacroCallInfo *call_info) {
    char *result = NULL;
    if (!has_rows(call_info,1) ) {
        call_info->free_result=0;
        return "?";
    }
    if (call_info->sorted_rows->num_rows) {
        DbItem *r=call_info->sorted_rows->rows[0];
        int freeit;
        char *share = share_name(r,&freeit);
        result = add_network_icon(r,share);
        if (freeit) FREE(share);
    }
    return result;
}

/*
 * =begin wiki
 * ==RATING([scale=>scale,precision=>0|1])
 * Multiply rating by scale and round 
 * Oversight Ratings are from 0 to 10
 *
 * Default scale = 1
 * Default precision = 1
 *
 * =end wiki
 */
char *macro_fn_rating(MacroCallInfo *call_info) {
    char *result = NULL;
    int scale=1;
    int precision=1;
    char *tmp;

    if (!has_rows(call_info,1) ) {
        call_info->free_result=0;
        return "?";
    }
    if (*oversight_val("ovs_display_rating") != '0' && call_info->sorted_rows->num_rows) {
        struct hashtable *h = args_to_hash(call_info,NULL,"%scale,%precision");
        if ((tmp = get_named_arg(h,"scale")) != NULL) {
            scale = atoi(tmp);
        }
        if ((tmp = get_named_arg(h,"precision")) != NULL) {
            precision = atoi(tmp);
        }


        if (call_info->sorted_rows->rows[0]->rating > 0.01) {

            double n = scale*call_info->sorted_rows->rows[0]->rating;

#if 0
            switch(precision) {
                case 0: n+= 0.5; break;
                case 1: n+= 0.05; break;
            }
#endif

            ovs_asprintf(&result,"%.*lf",precision,n);
        }
        free_named_args(h);
    }

    return result;
}

struct hashtable *args_to_set(Array *args,struct hashtable **numbers)
{
    int i;
    struct hashtable *h = NULL;
    if (args) {
        for(i= 0 ; i < args->size ; i++ ) {
            if (h == NULL) {
                h = string_string_hashtable("set",16);
            }
            char *name = args->array[i];
            if (*name == '%') { // integer prefix
                if (*numbers == NULL) {
                    *numbers = string_string_hashtable("numbers",16);

                }
                name++;
                hashtable_insert(*numbers,STRDUP(name),"1");
            }
            hashtable_insert(h,STRDUP(name),"1");
        }
    }
    return h;
}

// If a macro has arguments like, 1,cols=>3,rows=>4,5  then create a hashtable cols=>3,rows=>4
#define HASH_ASSIGN "=>"
struct hashtable *args_to_hash(MacroCallInfo *call_info,char *required_list,char *optional_list)
{
    int ok=1;
    int i;

    Array *args = call_info->args;

    struct hashtable *required_set = NULL;
    struct hashtable *optional_set = NULL;
    struct hashtable *int_type = NULL; // all names prefixed % will be integer type

    // Get list of required variables.
    if (required_list != NULL) {
        Array *a = split1ch(required_list,",");
        required_set = args_to_set(a,&int_type);
        array_free(a);
    }

    // Get list of optional variables.
    if (optional_list != NULL) {
        Array *a = split1ch(optional_list,",");
        optional_set = args_to_set(a,&int_type);
        array_free(a);
    }

    struct hashtable *h = NULL;
    if (args) {
        for(i= 0 ; i < args->size ; i++ ) {
            char *hashop;
            char *a = args->array[i];
            if ((hashop = strstr(a,HASH_ASSIGN)) != NULL) {
                char *name,*val;
                ovs_asprintf(&name,"%.*s",hashop-a,a);

                if ((required_set && hashtable_search(required_set,name))
                  || (optional_set && hashtable_search(optional_set,name) ) ) {
                    val = STRDUP(hashop+strlen(HASH_ASSIGN));
                    if (h == NULL) {
                        h = string_string_hashtable("macro_args",16);
                    }
                    if (hashtable_search(h,name)) {
                        html_error("ignore duplicate arg[%s]",name);
                    } else {
                        if (int_type && hashtable_search(int_type,name)) {
                            int tmp;
                            if (!util_parse_int(val,&tmp,0)) {
                                // Try to evalute it
                                html_error("bad number [%s] for argument [%s]",val,name);
                                long num2 = numeric_constant_eval_str(0,val);
                                char *tmp;
                                ovs_asprintf(&tmp,"%ld",num2);
                                FREE(val);
                                val=tmp;
                                html_error("final number=[%s] ",val);
                                //ok=0;
                            } else {
                                //HTML_LOG(0,"parsed [%s:%s] as [%d]",name,val,tmp);
                            }
                        }
                        hashtable_insert(h,name,val);
                    }
                } else {
                    ok = 0;
                }
            }
        }
    }
    // Now check all required arguments are present
    if (required_set) {
        char *name,*value;
        struct hashtable_itr *itr;
        for(itr=hashtable_loop_init(required_set) ; hashtable_loop_more(itr,&name,&value) ; ) {
            if (!get_named_arg(h,name)) {
                html_error("required arg[%s] missing",name);
                ok = 0;
            }
        }
    }


    set_free(int_type);
    set_free(required_set);
    set_free(optional_set);
    if (!ok) {
        html_error("usage %s(%s %s[%s])",
                call_info->call,
                NVL(required_list),
                (EMPTY_STR(required_list)?"":","),
                NVL(optional_list) ) ;

        free_named_args(h);
        h = NULL;
    }
    return h;
}

/*
 *
 * =begin wiki
 * ==GRID==
 * Grid Macro has format
 * [:GRID(rows=>r,cols=>c,img_height=>300,img_width=>200,offset=>0):]
 *
 * All parameters are optional.
 * rows,cols            = row and columns of thumb images in the grid (defaults to config file settings for that view)
 * img_height,img_width = thumb image dimensions ( defaults to config file settings for that view)
 * offset               = This setting is to allow multiple grids on the same page. eg. 
 * for a layout where X represents a thumb you may have:
 *
 * {{{
 * XXXX
 * XX
 * }}}
 *
 * This could be two grids
 * [:GRID(rows=>1,cols=>4,offset=>0):]
 * [:GRID(rows=>2,cols=>2,offset=>4):]
 *
 * In this secnario oversight also needs to know which is the last grid on the page, so it can add the page navigation to 
 * the correct grid. As the elements may occur in
 * any order in the template, this would either require two passes of the template, or the user to indicate the 
 * last grid. I took the easy option , so the user must spacify the total thumbs on the page.
 *
 * [:GRID(rows=>1,cols=>4,offset=>0):]
 * [:GRID(rows=>2,cols=>2,offset=>4,last=>1):]
 * =end wiki
 */
char *get_named_arg(struct hashtable *h,char *name)
{
    char *ret = NULL;
    if (h) {
        ret = hashtable_search(h,name);
    }
    return ret;
}

void free_named_args(struct hashtable *h)
{
    if (h) {
        hashtable_destroy(h,1,free);
    }
}

/**
 * =begin wiki
 * ==GRID==
 *
 * Display poster for current item.
 *
 * [:GRID:]
 * [:GRID(rows,cols,img_height,img_width,offset,order):]
 *
 * offset = number of first item in this grid segment. ITem numbering starts from 0.
 * if no offset supplied then it is computed from the size of the previous GRID.
 * This works as long as the grids appear in order within the HTML
 *
 * orientation=horizontal, vertical :  determines sort order within the grid.
 *
 * Example:
 *
 * [:SET(_grid_size,7):]
 * [:GRID(rows=>1,cols=>4,offset=>0,order=Horizontal):]
 * [:GRID(rows=>3,cols=>1,offset=>4,order=Vertical):]
 *
 * At present GRID cannot be inside a loop as they must be parsed during first pass.
 * =end wiki
 */
char *macro_fn_grid(MacroCallInfo *call_info) {

    struct hashtable *h = args_to_hash(call_info,NULL,"%rows,%cols,%img_height,%img_width,%offset,%order");
    
    GridSegment *gs ;
    char *result = NULL;
   
    if (call_info->pass == 1 ) {
       
        gs = grid_info_add_segment(get_grid_info());

        // Copy default grid size and dimensions
        gs->dimensions = *(g_dimension->current_grid);

        char *tmp;

        if ((tmp = get_named_arg(h,"rows")) != NULL) {
            gs->dimensions.rows = atoi(tmp);
        }
        if ((tmp = get_named_arg(h,"cols")) != NULL) {
            gs->dimensions.cols = atoi(tmp);
        }

        if ((tmp = get_named_arg(h,"img_height")) != NULL) {
            gs->dimensions.img_height = atoi(tmp);
        }
        if ((tmp = get_named_arg(h,"img_width")) != NULL) {
            gs->dimensions.img_width = atoi(tmp);
        }
        if ((tmp = get_named_arg(h,"offset")) != NULL) {
            gs->offset = atoi(tmp);
        }
        if ((tmp = get_named_arg(h,"grid_order")) != NULL) {
            gs->grid_direction = str2grid_direction(tmp);
        }

        // leave text for next pass
        result = CALL_UNCHANGED;
        call_info->request_reparse=1;

    } else if (call_info->pass == 2 ) {

        static int grid_no = 0;

        gs = get_grid_info()->segments->array[grid_no++];
        result = get_grid(get_current_page(),gs,call_info->sorted_rows);

    } else {
        assert(0);
    }

    free_named_args(h);

    return result;
}



char *macro_fn_header(MacroCallInfo *call_info) {
    return STRDUP("header");
}

char *macro_fn_hostname(MacroCallInfo *call_info) {
    call_info->free_result=0;
    return util_hostname();
}

char *macro_fn_form_start(MacroCallInfo *call_info) {

    int free_url=0;
    char *url=NULL;

    if (get_view_mode(0) == VIEW_ADMIN) {
        char *action = query_val(QUERY_PARAM_ACTION);
        if (strcasecmp(action,"ask") == 0 || strcasecmp(action,"cancel") == 0) {
            return NULL;
        } else {
            url=cgi_url(1);// clear URL
        } 
    } else {
        //we dont want it in the URL after the form is submitted.
        //keep query string eg when marking deleting. Select is passed as post variable
        url=self_url("select=");
        free_url=1;
    }

    char *hidden = add_hidden("idlist,view,page,sort,select,"
            QUERY_PARAM_TYPE_FILTER","QUERY_PARAM_WATCHED_FILTER);
    char *result;
    ovs_asprintf(&result,
            "<form action=\"%s\" enctype=\"multipart/form-data\" method=POST >"
            "<input type=hidden name=form value=\"1\">\n%s",
            url,
            (hidden?hidden:"")
        );
    FREE(hidden);
    if  (free_url) { FREE(url); }
    return result;
}

char *macro_fn_form_end(MacroCallInfo *call_info) {
    char *result=NULL;
    ovs_asprintf(&result,"<input type=hidden item_count=\"%d\" /></form>",g_item_count);
    return result;
}

char *macro_fn_is_gaya(MacroCallInfo *call_info) {
    call_info->free_result=0;
    if (g_dimension->local_browser) {
        return "1";
    } else {
        return "0";
    }
}

char *macro_fn_include(MacroCallInfo *call_info) {
    if (call_info->args && call_info->args->size == 1) {

        display_template(
                call_info->pass,
                NULL,
                call_info->orig_skin_name,
                call_info->args->array[0],
                call_info->sorted_rows,
                call_info->outfp,
                &(call_info->request_reparse));

    } else if (!call_info->args) {
        html_error("missing  args for include");
    } else {
        html_error("number of args for include = %d",call_info->args->size);
    }
    return NULL;
}

char *macro_fn_start_cell(MacroCallInfo *call_info) {
    call_info->free_result=0;
    char *result=NULL;

    char *start_cell = get_start_cell();
    if (start_cell && *start_cell) {

        result = start_cell;

    } else {
        result= "selectedCell";
    }

    return result;

}
char *macro_fn_media_type(MacroCallInfo *call_info) {
    call_info->free_result=0;
    char *mt="?";
    switch(*query_val(QUERY_PARAM_TYPE_FILTER)) {
		case 'O': mt="Other"; break;
        case 'T': mt="TV Shows"; break;
        case 'M': mt="Movies"; break;
        default: mt="All Video"; break;
    }

    return mt;
}
char *macro_fn_version(MacroCallInfo *call_info) {

    char *version=OVS_VERSION;
    char *tmp = replace_str(version,"beta","β"); 
    char *result =  replace_str(tmp,"alpha","α");

    FREE(tmp);
    return result;

}

char *macro_fn_media_toggle(MacroCallInfo *call_info) {

    return get_toggle("red",QUERY_PARAM_TYPE_FILTER,
            QUERY_PARAM_MEDIA_TYPE_VALUE_TV,"Tv",
            QUERY_PARAM_MEDIA_TYPE_VALUE_MOVIE,"Film");

}
char *macro_fn_watched_toggle(MacroCallInfo *call_info) {
    return get_toggle("yellow",QUERY_PARAM_WATCHED_FILTER,
            QUERY_PARAM_WATCHED_VALUE_NO,"Unwatched",
            QUERY_PARAM_WATCHED_VALUE_YES,"Watched");
}
char *macro_fn_sort_type_toggle(MacroCallInfo *call_info) {
    return get_toggle("blue",QUERY_PARAM_SORT,
            DB_FLDID_TITLE,"Name",
            DB_FLDID_INDEXTIME,"Age");
}

// Display a link back to this cgi file with paramters adjusted.
char *macro_fn_link(MacroCallInfo *call_info) {
    char *result=NULL;

    if (call_info->args && call_info->args->size == 2) {

        result = drill_down_link(call_info->args->array[0],"",call_info->args->array[1]);

    } else if (call_info->args && call_info->args->size == 3) {

        result= drill_down_link(call_info->args->array[0],call_info->args->array[2],call_info->args->array[1]);

    } else {

        printf("%s(params,title[,attr])",call_info->call);
    }
    return result;
}

char *macro_fn_icon_link(MacroCallInfo *call_info) {
    char *result=NULL;
    if (call_info->args && call_info->args->size == 2) {

        result = get_theme_image_link(call_info->args->array[0],"",call_info->args->array[1],"");

    } else if (call_info->args && call_info->args->size == 3) {

        result= get_theme_image_link(call_info->args->array[0],call_info->args->array[2],call_info->args->array[1],"");

    } else if (call_info->args && call_info->args->size == 3) {

        result= get_theme_image_link(call_info->args->array[0],call_info->args->array[2],call_info->args->array[1],call_info->args->array[3]);

    } else {

        printf("%s(params,icon[,href_attr[,image_attr]])",call_info->call);
    }
    return result;
}

/**
  =begin wiki
  ==BACKGROUND_URL==
  BACKGROUND_URL(image name)
  Display image from skin/720 or skin/sd folder. Also see FANART_URL

  ==BACKGROUND_IMAGE==
  BACKGROUND_IMAGE(image name) - deprecated - use BACKGROUND_URL() 
  Display image from skin/720 or skin/sd folder. Also see BACKGROUND_URL,FANART_URL
  =end wiki
**/  
char *macro_fn_background_url(MacroCallInfo *call_info)
{
    char *result=NULL;
    if (call_info->args && call_info->args->size == 1) {
        char *tmp = image_path_by_resolution(call_info->skin_name,call_info->args->array[0]);
        if (!exists(tmp)) {
            FREE(tmp);
            tmp = image_path_by_resolution("default",call_info->args->array[0]);
        }
        result = file_to_url(tmp);
        FREE(tmp);
    } else {
        ovs_asprintf(&result,"%s(image base name)",call_info->call);
    }
    return result;
}

/**
  =begin wiki
  ==FAVICON==

  Display favicon html link.
  [:FAVICON:]
  =end wiki
**/  
char *macro_fn_favicon(MacroCallInfo *call_info)
{
    char *result="";
    call_info->free_result = 0;
    if (is_pc_browser()) {
        result = "<link rel=\"shortcut icon\" href=\"/oversight/templates/ovsicon.ico\" />";
    }
    return  result;
}


/**
 * =begin wiki
 * ==FILE_PATH(n)==
 * Return name of n'th file part. See also FILEPARTS, FILE_ENCODED FILE_VOD_ATTRIBUTES
 * =endwiki
 */
char *macro_fn_file_path(MacroCallInfo *call_info)
{
    return macro_fn_file_general(call_info,FILE_PATH);
}
/**
 * =begin wiki
 * ==FILE_ENCODED(n)==
 * Return url encoded name of n'th file part. See also FILEPARTS, FILE_PATH FILE_VOD_ATTRIBUTES
 * =endwiki
 */
char *macro_fn_file_enc(MacroCallInfo *call_info)
{
    return macro_fn_file_general(call_info,FILE_ENC);
}
/**
 * =begin wiki
 * ==FILE_VOD_ATTRIBUTES(n)==
 * Return VOD attributes for n'th file part. See also FILEPARTS, FILE_ENCODED FILE_PATH
 * =endwiki
 */
char *macro_fn_file_vod(MacroCallInfo *call_info)
{
    return macro_fn_file_general(call_info,FILE_VOD);
}
/**
 * =begin wiki
 * ==FILE_NUM_PARTS==
 * Return number of parts  for a movie 
 *
 * IT should only be called on a movie detail page
 * =end wiki
 */
char *macro_fn_file_num_parts(MacroCallInfo *call_info)
{
    char *result=NULL;
    if (call_info->args==NULL || call_info->args->size == 0) {
        if (has_rows(call_info,1)) {
            DbItem *item = call_info->sorted_rows->rows[0];
            if (item) {
                int count = 0;
                if (item->file) {
                    count = 1 + num_parts(item);
                }
                ovs_asprintf(&result,"%d",count);
            }
        }

    } else {
        ovs_asprintf(&result,"%s( no args expected)",call_info->call);
    }
    return result;
}

// Check a user specified index - starting from 1. 
int check_index(MacroCallInfo *call_info,int index) 
{
    int ret = 0;
    DbItem *item = call_info->sorted_rows->rows[0];
    if (index < 1 ) {
        html_error("invalid index %d",index);
    } else if (!call_info->sorted_rows ) {
       html_error("no rows for index %d",index);
    } else if (item->category == 'M' && call_info->sorted_rows->num_rows == 1)  {
        // A movie on its own - the index refers to the PARTS
        if (index == 1) {
            if (!(item->file)) {
                html_error("item has no file?");
            } else {
                ret = 1;
            }
        } else {
            if (index-1 > num_parts(item)) {
                html_error("item has %d parts",num_parts(item)+1);
            } else {
                ret=1;
            }
        }
    } else if (index > call_info->sorted_rows->num_rows ) {
       html_error("index %d out of range [%d]",index,call_info->sorted_rows->num_rows);
    } else {
        ret = 1;
    }
    return ret;
}

char *macro_fn_file_general(MacroCallInfo *call_info,FileAspect aspect)
{
    char *result=NULL;
    int part_no = 1;
    int freeit = 0;
    int freeit2 = 0;

    if ((call_info->args==NULL || call_info->args->size <= 1) && has_rows(call_info,1)){

        if (call_info->args && call_info->args->size == 1) {
            if (!util_parse_int(call_info->args->array[0],&part_no,1)) {
                return NULL;
            }
        }
        DbItem *item = call_info->sorted_rows->rows[0];
        char *path;

        if (item->category == 'M' && call_info->sorted_rows->num_rows == 1)  {
            // A movie on its own - the index refers to the PARTS
            path = get_path_no(item,part_no-1,&freeit);
        } else {
            // Anything else the index refers to the n'th item
            part_no += aligned_data_offset;
            if (!check_index(call_info,part_no)) {
                return NULL;
            }
            item = call_info->sorted_rows->rows[part_no-1];
            path = get_path_no(item,1,&freeit);
        }

        if (path) {
            switch(aspect) {
                case FILE_PATH:
                    result = path;
                    call_info->free_result = freeit;
                    break;
                case FILE_ENC:

                    result = url_encode_static(path,&freeit2);
                    if (freeit2) {
                        if (freeit) FREE(path);
                        call_info->free_result = 1;
                    } else if (freeit) {
                        call_info->free_result = 1;
                    } else {
                        call_info->free_result = 0;
                    }
                    break;
                case FILE_VOD:
                    result = vod_attr(path);
                    if (freeit) FREE(path);
                    call_info->free_result = 0;
                    break;
            }
        }

    } else {
        ovs_asprintf(&result,"%s(partno)",call_info->call);
    }
    return  result;
}

/**
  =begin wiki
  ==SKIN_NAME==

  Replace with name of the currently selected skin.
  =end wiki
**/  
char *macro_fn_skin_name(MacroCallInfo *call_info)
{
    call_info->free_result = 0;
    return get_skin_name();
}

/**
  =begin wiki
 * ==TEMPLATE_URL==
 * TEMPLATE_URL(file path)
 * Return URL to a file within the current skin/template. Fall back to default skin if not found in current skin.
 * eg.
 * [:TEMPLATE_URL(css/default.css):]
  =end wiki
 */
char *macro_fn_template_url(MacroCallInfo *call_info)
{
    char *result=NULL;
    if (call_info->args && call_info->args->size >= 1) {

        char *name = arraystr(call_info->args);
        result = file_source("",name,""); 
        FREE(name);

    } else {

        printf("%s(TEMPLATE_URL[name])",call_info->call);
    }
    return result;
}

/**
 * =begin wiki
 * ==IMAGE_URL==
 *   Description:
 *   Generate a url for a template image from current skins images folder - if not present look in defaults.
 *   This is just the url - no html tag is included.
 * Syntax:
 * [:IMAGE_URL(image name):]
 * Example:
 * [:IMAGE_URL(stop):]
 * =end wiki
 */  
char *macro_fn_image_url(MacroCallInfo *call_info)
{
    char *result=NULL;
    if (call_info->args && call_info->args->size >= 1) {

        char *name = arraystr(call_info->args);
        HTML_LOG(1,"IMAGE_URL(%s)",name);
        result = image_source("",name,""); 
        FREE(name);

    } else {

        printf("%s(IMAGE_URL[name])",call_info->call);
    }
    return result;
}
/**
 * =begin wiki
 * ==IMAGE_URL==
 *   Description:
 *   Generate html <img> tag to display an icon  - if not present look in defaults.
 * Syntax:
 * [:ICON(name,[attribute]):]
 * Example:
 * [:ICON(stop,width=20):]
 * =end wiki
 */  
char *macro_fn_icon(MacroCallInfo *call_info) {
    char *result=NULL;
    if (call_info->args && call_info->args->size == 1) {

        result= get_theme_image_tag(call_info->args->array[0],"");

    } else if (call_info->args && call_info->args->size == 2) {

        result= get_theme_image_tag(call_info->args->array[0],call_info->args->array[1]);

    } else {

        printf("%s(icon_name[,attr])",call_info->call);
    }
    return result;
}


/**
  =begin wiki
  ==CONFIG_LINK==
    Description:
    Generate text to link to a settings configuration form for a config file.
  Syntax:
  [:CONFIG_LINK(conf=>,help=>,text=>link text,attr=>html_attributes,skin=1):]
  Example:
  =end wiki
**/  
char *macro_fn_admin_config_link(MacroCallInfo *call_info)
{

    char *result=NULL;
    struct hashtable *h = args_to_hash(call_info,"conf_file,help_suffix,text","attr");

    if (h) {
        char *conf = get_named_arg(h,"conf_file");
        char *help = get_named_arg(h,"help_suffix");
        char *text = get_named_arg(h,"text");
        char *attr = NVL(get_named_arg(h,"attr"));

        char *c = config_path(conf);
        char *d = config_defaults_path(conf);
        if (exists(d) || exists(d)) {

            char *params;
            char *text2 = text;
            if (text == NULL || *text != '{' ) {
                ovs_asprintf(&text2,"{%s}",NVL(text));
            }
            ovs_asprintf(&params,"%s=%s&action=settings&%s=%s&%s=%s&%s=%s",
                    QUERY_PARAM_VIEW,"admin",
                    QUERY_PARAM_CONFIG_FILE,conf,
                    QUERY_PARAM_CONFIG_HELP,help,
                    QUERY_PARAM_CONFIG_TITLE, text2
                    );

            result = drill_down_link(params,attr,text2);

            FREE(params);
            if (text2 != text) {
                FREE(text2);
            }
        } else {
            HTML_LOG(0,"missing conf file [%s] or [%s]",c,d);
        }
        free_named_args(h);
    }
    return result;
}

/**
  =begin wiki
  ==STATUS==
    Description:
    Replace with current status passed from the scanner.
  Syntax:
  [:STATUS:]
  Example:
  [:STATUS:]
  =end wiki
**/  
char *macro_fn_status(MacroCallInfo *call_info)
{
    call_info->free_result = 0;
    char *result = get_status_static();
    if (result == NULL  && local_db_size() == 0) {
        result = "Database empty. Goto [Setup]&gt;media sources and rescan.";
    }

    return result;
}


/**
  =begin wiki
  ==HELP_BUTTON==
    Description:
    Display a template image from current skins images folder - if not present look in defaults.
  Syntax:
  [:HELP_BUTTON:]
  Example:
  [:HELP_BUTTON:]
  =end wiki
**/  
char *macro_fn_help_button(MacroCallInfo *call_info)
{
    char *result = NULL;
    char *tag=get_theme_image_tag("help",NULL);
    if (!g_dimension->local_browser) {
#define PROJECT_HOME "http://code.google.com/p/oversight/wiki/OversightIntro"
        ovs_asprintf(&result,"<a href=\"" PROJECT_HOME"\" target=\"ovshelp\">%s</a>",tag);
    } else {
        ovs_asprintf(&result,"<a href=\"javascript:alert('[%s] mark\n[%s] lock\n[%s] delist\n[%s] delete');\" >%s</a>",
                oversight_val("ovs_tvid_mark"),
                oversight_val("ovs_tvid_lock"),
                oversight_val("ovs_tvid_delist"),
                oversight_val("ovs_tvid_delete"),
                tag);
    }
    FREE(tag);
    return result;
}

char *macro_fn_setup_button(MacroCallInfo *call_info) {
    return get_theme_image_link(QUERY_PARAM_VIEW"=admin&action=ask","TVID=SETUP","configure","");
}

char *get_page_control(int next_page,char *tvid_name,char *image_base_name) {

    char *select = query_select_val();
    char *view = query_view_val();
    char *result = NULL;

    assert(view);
    assert(tvid_name);
    assert(image_base_name);

//    char *button_attr=" width=10px height=10px ";
    char *button_attr="";

    if (! *select) {
        //only show page controls when NOT selecting
        char *params=NULL;
        char *attrs=NULL;
        ovs_asprintf(&params,"p=%d",next_page);
        ovs_asprintf(&attrs,"tvid=%s name=%s1 onfocusload",tvid_name,tvid_name);

        if (g_dimension->local_browser) {
            // draw invisible page controls
            char *url=self_url(params);
            ovs_asprintf(&result,"<a href=\"%s\" %s></a>",url,attrs);
        } else {
            // visible page controls in browser
            result = get_theme_image_link(params,attrs,image_base_name,button_attr);
        }
        FREE(params);
        FREE(attrs);
    }
    return result;
}

char *macro_fn_left_button(MacroCallInfo *call_info) {

    char *result=NULL;

    int page_max=0;

    if (get_page_max(&page_max,call_info)) {

        HTML_LOG(0,"LEFT page_max %d ",page_max);
        int page = get_current_page();
        HTML_LOG(0,"LEFT page %d ",page);

        // 0->9 1->0
        int next_page = (page+page_max-1)%page_max;

        HTML_LOG(0,"LEFT next %d",next_page);
        result = get_page_control(next_page,"pgup","left");

    } else {

        result = CALL_UNCHANGED;

    }

    return result;
}

/*
 * Get highest page number.
 * This is computed from page size and number of items (see SET_PAGE )
 */
int get_page_max(int *maxptr,MacroCallInfo *call_info)
{
    int ret=0;
    if(maxptr) {
        int page_size;
        if (get_page_size(&page_size,call_info)) {
            if (page_size) {
                *maxptr = 1 + (call_info->sorted_rows->num_rows -1) / page_size  ;
                ret=1;
            } else {
                html_error("zero page size");
            }
        }
    }
    return ret;
}

// returns 1-ok 0-failed
int get_page_size(int *size,MacroCallInfo *call_info)
{
    int ret = 0;
    if (size) {
        int page_size;
        char *tmp;

        if ((tmp=get_tmp_skin_variable(PAGE_SIZE_VAR))!= NULL) {

            // page size set by SET_PAGE
            util_parse_int(tmp,size,1);
            ret = 1;

        } else if ( call_info->pass > 1 ) {
           
            page_size = get_grid_info()->page_size;
            
            HTML_LOG(0,"page size from grid=%d",page_size);
            
            if (page_size > 0) {

                *size = page_size;
                ret = 1;

            } else {
                html_error("unable to compute page size on pass %d",call_info->pass);
                call_info->request_reparse = 1;
            }
        } else {
            // Always request reparse if pass1 as grid may not be finished.
            call_info->request_reparse = 1;
        }
    }
    return ret;
}


char *menu_page(int page_num,MacroCallInfo *call_info)
{
    char *result = NULL;
    int page_max;

    if (get_page_max(&page_max,call_info)) {

        int next_page = (page_num+2*page_max)%page_max;  // avoid -ve modulo

        char *params;
        ovs_asprintf(&params,"p=%d",next_page);
        result = self_url(params);
        FREE(params);
    } else {
        result = CALL_UNCHANGED;
    }
    return result;
}

/*
 * =begin wiki
 * ==MENU_PAGE_PREV_URL==
 *
 * Link to previous page URL
 * Shorthand for MENU_PAGE_URL(offset=>-1):]
 * =end wiki
 */
char *macro_fn_menu_page_prev_url(MacroCallInfo *call_info)
{
    return menu_page_url(call_info,-1);
}
/*
 * =begin wiki
 * ==MENU_PAGE_NEXT_URL==
 *
 * Link to previous page URL
 * Shorthand for MENU_PAGE_URL(offset=>-1):]
 * =end wiki
 */
char *macro_fn_menu_page_next_url(MacroCallInfo *call_info)
{
    return menu_page_url(call_info,1);
}
/*
 * =begin wiki
 * ==MENU_PAGE_URL==
 *
 * Generate url to jump to the given menu page. Offset is relative from current page.
 * [:MENU_PAGE_URL(offset=>1):]
 * This should be called from another menu page. To get to menu from details page use the BACK urls.
 * =end wiki
 */
char *macro_fn_menu_page_url(MacroCallInfo *call_info,int offset_in)
{
    return menu_page_url(call_info,0);
}

char *menu_page_url(MacroCallInfo *call_info,int offset_in)
{

    char *result=NULL;

    int offset;

    if(offset_in) {
        // Simple case for MENU_PAGE_PREV_URL / MENU_PAGE_NEXT_URL
        if (NO_ARGS(call_info)) {
            result = menu_page(get_current_page() + offset_in,call_info); 
        } else {
            html_error("no arguments expected [%s]",call_info->call);
        }
    } else {
        // MENU_PAGE_URL(offset=>n)
        struct hashtable *h=args_to_hash(call_info,"offset",NULL);
        if (h) {
            if (util_parse_int(get_named_arg(h,"offset"),&offset,1)) {

                result = menu_page(get_current_page() + offset,call_info); 
            }
        }
        free_named_args(h);
    }

    return result;
}
char *macro_fn_right_button(MacroCallInfo *call_info) {

    char *result=NULL;

    int page_max;

    if (get_page_max(&page_max,call_info)) {

        int page = get_current_page();

        int next_page = (page+1)%page_max; // 0->1 9->0

        HTML_LOG(0,"RIGHT page %d page_max %d next %d",page,page_max,next_page);
        result = get_page_control(next_page,"pgdn","right");

    } else {

        result = CALL_UNCHANGED;

    }

    return result;
}

char *macro_fn_back_button(MacroCallInfo *call_info) {
    char *result=NULL;
    if (*query_view_val() && !*query_select_val()) {
        char *attr = "";
        if (call_info->args && call_info->args->size == 1) {
            attr=call_info->args->array[0];
        }
        result = get_theme_image_return_link("name=up","back",attr);
    }
    return result;
}

char *macro_fn_menu_tvid(MacroCallInfo *call_info) {
    char *result=NULL;
    char *url = self_url(QUERY_PARAM_VIEW"=&idlist=");
    ovs_asprintf(&result,"<a href=\"%s\" TVID=TAB ></a>",url);
    FREE(url);
    return result;
}
char *macro_fn_home_button(MacroCallInfo *call_info) {
    char *result=NULL;

    if(!*query_select_val()) {
        char *icon = "home";
        if (get_status_static() ) {
            icon = "gear";
        }
        char *tag=get_theme_image_tag(icon,NULL);
        ovs_asprintf(&result,"<a href=\"%s?\" name=home TVID=HOME >%s</a>",cgi_url(0),tag);
        FREE(tag);
    }

    return result;
}

char *macro_fn_exit_button(MacroCallInfo *call_info) {
    char *result=NULL;

    if(g_dimension->local_browser && !*query_select_val()) {
        char *tag=get_theme_image_tag("exit",NULL);
        ovs_asprintf(&result,"<a href=\"/start.cgi\" name=home >%s</a>",tag);
        FREE(tag);
    }
    return result;
}

char *macro_fn_mark_button(MacroCallInfo *call_info) {
    char *result=NULL;
    if (!*query_select_val() && allow_mark()) {
        if (g_dimension->local_browser) {
            char *tag=get_theme_image_tag("mark",NULL);
            ovs_asprintf(&result,
                    "<a href=\"javascript:alert('Select item then remote\n[%s] button')\">%s</a>",
                oversight_val("ovs_tvid_mark"),
                tag);
            FREE(tag);
        } else {
            result = get_theme_image_link("select="FORM_PARAM_SELECT_VALUE_MARK,"","mark","");
        }
    }
    return result;
}

char *macro_fn_delete_button(MacroCallInfo *call_info) {
    char *result=NULL;
    if (!*query_select_val() && (allow_delete() || allow_delist())) {
        if (g_dimension->local_browser) {
            char *tag=get_theme_image_tag("delete",NULL);
            ovs_asprintf(&result,
                "<a href=\"javascript:alert('Select item then remote\ndelist=[%s]\ndelete=[%s]')\">%s</a>",
                oversight_val("ovs_tvid_delist"),
                oversight_val("ovs_tvid_delete"),
                    tag);
            FREE(tag);
        } else {
            result = get_theme_image_link("select="FORM_PARAM_SELECT_VALUE_DELETE,"","delete","");
        }
    }
    return result;
}

/*
 * =begin wiki
 * ==LOOP_START==
 *
 * [:LOOP_START(name):] - following lines are stored as the named loop body up to the [:LOOP_END:]
 *
 * ==LOOP_END==
 * [:LOOP_END:] - End of names loop body
 *
 * ==LOOP_EXPAND==
 *
 * [:LOOP_EXPAND(name=>name,num=>n):]
 * [:LOOP_EXPAND(name=>name,end=>n[,start=>n,inc=>n]):]
 * [:LOOP_EXPAND(name=>name,values=>val1|val2|...|val3):]
 *
 * Expand the named loop body replace aoccurences of $loop_name with the numeric value
 *
 * =end wiki
 */
char *macro_fn_loop_expand(MacroCallInfo *call_info)
{
    char *result = NULL;
    struct hashtable *h = args_to_hash(call_info,"name","start,inc,num,end,values");
    int start=1;
    int inc=1;
    int end=1;
    Array *values = NULL;
    char *name;
    int i;

    if (call_info->sorted_rows ) {
        end = call_info->sorted_rows->num_rows;
    }

    if (h) {
        char *tmp;
        name = get_named_arg(h,"name");
        Array *loop = loop_lookup(name);
        if (loop) {

            if ((tmp = get_named_arg(h,"num")) != NULL) {
                end = atoi(tmp);
            }
            if ((tmp = get_named_arg(h,"end")) != NULL) {
                end = atoi(tmp);
            }
            if ((tmp = get_named_arg(h,"inc")) != NULL) {
                inc = atoi(tmp);
            }
            if ((tmp = get_named_arg(h,"start")) != NULL) {
                start = atoi(tmp);
            }
            if ((tmp = get_named_arg(h,"values")) != NULL) {
                values = splitstr(tmp,"|");
            }

            Array *out = array_new(free);

            if (values) {
                for(i = 0 ; i < values->size ; i++ ) {
                    loop_expand(name,loop,values->array[i],out,values->size);
                }
            } else {
                char num[10];
                for(i = start ; i<= end ; i+=inc) {
                    sprintf(num,"%d",i);
                    loop_expand(name,loop,num,out,end);
                }
            }

            result = arraystr(out);

            // Do another pass if it looks like a macro is present
            if (result) {
               char *p = strchr(result,'[');
               if (p && strchr(p,':')) {
                    call_info->request_reparse=1;
               }
            }

            array_free(out);
        }

        free_named_args(h);

    }
    return result;
}

void loop_expand(char *loop_name,Array *loop_body,char *loop_value,Array *out,int max)
{
    int i;
    if (loop_name && loop_body && loop_body->size) {
        if (!loop_value) loop_value="";

        char *replace;
        ovs_asprintf(&replace,"\\$%s\\>",loop_name);

        for(i = 0 ; i<loop_body->size ; i++ ) {
            char *in = loop_body->array[i];
            if (in) {
                char *new;
                char *new2;
                if (strstr(in,loop_name)) {
                    new = replace_all(in,replace,loop_value,0);
                } else {
                    new = STRDUP(in);
                }
                if (strstr(new,"_max")) {
                    char *replace_max;
                    ovs_asprintf(&replace_max,"\\$%s_max\\>",loop_name);
                    char max_value[10];
                    sprintf(max_value,"%d",max);
                    new2 = replace_all(new,replace_max,max_value,0);
                    FREE(new);
                    new = new2;
                }
                array_add(out,new);
            }
        }
        FREE(replace);
    }
}


char *macro_fn_lock_button(MacroCallInfo *call_info)
{
    char *result=NULL;
    if (!*query_select_val() && allow_locking() ) {
        if (g_dimension->local_browser) {
            char *tag=get_theme_image_tag("security",NULL);
            ovs_asprintf(&result,
                "<a href=\"javascript:alert('Select item then remote\n[%s] button')\">%s</a>",
                oversight_val("ovs_tvid_lock"),
                tag);
            FREE(tag);
        } else {
            result = get_theme_image_link("select="FORM_PARAM_SELECT_VALUE_LOCK,"","security","");
        }
    }
    return result;
}

char *macro_fn_select_mark_submit(MacroCallInfo *call_info) {
    char *result=NULL;
    if (STRCMP(query_select_val(),FORM_PARAM_SELECT_VALUE_MARK)==0) {
        ovs_asprintf(&result,"<input type=submit name=action value=Mark >");
    }
    return result;
}

char *macro_fn_select_delete_submit(MacroCallInfo *call_info) {
    char *result=NULL;
    if (STRCMP(query_select_val(),FORM_PARAM_SELECT_VALUE_DELETE)==0) {
        ovs_asprintf(&result,"<input type=submit name=action value=Delete onclick=\"return confirm('Delete Files?');\" >");
    }
    return result;
}
char *macro_fn_select_delist_submit(MacroCallInfo *call_info)
{
    char *result=NULL;
    if (STRCMP(query_select_val(),FORM_PARAM_SELECT_VALUE_DELETE)==0) {
        ovs_asprintf(&result,"<input type=submit name=action value=Remove_From_List >");
    }
    return result;
}
char *macro_fn_select_cancel_submit(MacroCallInfo *call_info)
{
    char *result=NULL;
    if (*query_select_val()) {
        ovs_asprintf(&result,"<input type=submit name=select value=Cancel >");
    }
    return result;
}
char *macro_fn_select_lock_submit(MacroCallInfo *call_info)
{
    char *result=NULL;
    if (STRCMP(query_select_val(),FORM_PARAM_SELECT_VALUE_LOCK)==0) {
        ovs_asprintf(&result,"<input type=submit name=action value=Lock >");
    }
    return result;
}
char *macro_fn_select_unlock_submit(MacroCallInfo *call_info)
{
    char *result=NULL;
    if (STRCMP(query_select_val(),FORM_PARAM_SELECT_VALUE_LOCK)==0) {
        ovs_asprintf(&result,"<input type=submit name=select value=Unlock >");
    }
    return result;
}

/*
 * =begin wiki
 * ==PERSON_URL==
 *
 * Display a link to required domain - default is IMDB
 *
 * [:PERSON_URL:]
 * =end wiki
 */
char *macro_fn_person_url(MacroCallInfo *call_info) {
    char *result=NULL;
    if (!has_rows(call_info,1) ) {
        call_info->free_result=0;
        return "?";
    }

    char *image=get_theme_image_tag("upgrade"," alt=External ");
    char *person=query_val(QUERY_PARAM_PERSON);

    char *person_id = NULL;
    
    if (!EMPTY_STR(person)) {
        person_id = current_person_id(firstdb(call_info),"imdb");

        ovs_asprintf(&result,"<a href=\"http://%s.imdb.com/name/%s%s\">%s</a>",
            (g_dimension->local_browser?"m":"www"),
            (util_starts_with(person_id,"nm")?"":"nm"),
            person_id,image);
    }
    FREE(image);
    FREE(person_id);
    return result;
}

/*
 * =begin wiki
 * ==EXTERNAL_URL==
 *
 * Display a link to movie or tv website (default website IMDB)
 *
 * [:EXTERNAL_URL:]
 * [:EXTERNAL_URL:(domain=>domain_name):] 
 *
 * Example:
 * [:EXTERNAL_URL:(domain=>imdb):] 
 * [:EXTERNAL_URL:(domain=>themoviedb):] 
 *
 * =end wiki
 */
char *macro_fn_external_url(MacroCallInfo *call_info) {

    char *result=NULL;

    if (!has_rows(call_info,1) ) {
        call_info->free_result=0;
        return "?";
    }

    char *domain;
    struct hashtable *h = args_to_hash(call_info,NULL,"domain");
    if ((domain = get_named_arg(h,"domain")) == NULL) {
        domain = "imdb";
    }

    struct hashtable *domain_hash = config_load_domain(domain);
    //HTML_LOG(0,"domain....");
    hashtable_dump("domain",domain_hash);

    char *idlist=call_info->sorted_rows->rows[0]->url;

    if (idlist != NULL) {

        //HTML_LOG(0,"idlist=[%s]",idlist);

        char *website=NULL;
        char *website_template=NULL;

        char *id = get_id_from_idlist(idlist,domain,0);
        //HTML_LOG(0,"id=[%s]",id);
    
        if (id) {
            if (config_check_str(domain_hash,"catalog_domain_movie_url",&website_template)) {
                //HTML_LOG(0,"website_template=[%s]",website_template);
                website = replace_str(website_template,"{ID}",id);
                if (website) {
                    //HTML_LOG(0,"website=[%s]",website);

                    char *image=get_theme_image_tag("upgrade"," alt=External ");
                    ovs_asprintf(&result,"<a href=\"%s\">%s</a>",website, image);

                    FREE(image);
                    FREE(website);
                }
            }
            FREE(id);
        }
    }

    hashtable_destroy(domain_hash,1,free);
    free_named_args(h);
    return result;
}

// Very simple expression evaluator - no precedence, no brackets.
// should be possible to use the url evaluator instead. see exp_test.
// This would require the url operators (~a~ for AND etc) to be replaced
// with more standard characters. 
// Or simple enhance the OpDetails to have standard_text and url_text fields.
long numeric_constant_eval_str(long val,char *expression)
{

    char *p=expression;
    HTML_LOG(1,"start parsing [%s]",p);
    int error=0;

    char op='+';
    while (!error && *p && op) {

        long num2;
        char *numstr;
        char *nextp;
        //get the operator
        HTML_LOG(1,"parsing [%s]",p);

       
#if 0
        // commented out as variables are already substituted by the template calling code.
        // parse number
        if (*p == MACRO_VARIABLE_PREFIX) {
            char *end;
            p++;
            nextp=p;
            if (*nextp == MACRO_QUERY_PREFIX) {
                nextp++;
            }
            while(*nextp && ( isalnum(*nextp) || strchr("_[]",*nextp) ) ) {
                nextp++;
            }
            char tmp = *nextp;
            *nextp='\0';
            numstr=get_variable(p);
            HTML_LOG(0,"var [%s]=[%s]",p,numstr);
            *nextp=tmp;
            if (numstr && *numstr) {
                num2 = strtol(numstr,&end,10);

            } else {
                html_error("bad setting [%s]",p);
                break;
            }
            if (*end != '\0') {
                html_error("bad number [%s]",numstr);
                break;
            }
            p = nextp;

        } else
#endif
            
            if (*p == '-' || isdigit(*(unsigned char *)p)) {

            num2=strtol(p,&nextp,10);
            numstr=p;
            p = nextp;

        } else {
            html_error("unexpected character [%c]",*p);
            error=1;
            break;
        }

        if (*numstr == '\0' ) {
            html_error("bad number [%s]",numstr);
            break;
        }

        HTML_LOG(1,"val[%ld] op[%c] num [%ld]",val,op,num2);

        // do the calculation
        switch(op) {
            case '+': val += num2; break;
            case '-': val -= num2; break;
            case '/': val /= num2; break;
            case '*': val *= num2; break;
            case '%': val %= num2; break;
            case '=': val = (val == num2 ); break;

            default:
                html_error("unexpected operator [%d]",*p);
                error=1;
                break;
        }
        if (*p == '\0') break;
        op=*p++;
    }
    return val;
}

void replace_variables(Array *args,DbSortedRows *sorted_rows)
{
    if (args) {
        int i;
        for(i = 0 ; i < args->size ; i++ ) {
            HTML_LOG(2,"Begin replace_variables [%s]",args->array[i]);
            char *p=args->array[i];
            char *newp=NULL;
            char *v;
            while((v=strchr(p,MACRO_VARIABLE_PREFIX)) != NULL) {
                int free_result = 0;
                char *endv = v+1;
                if (*endv == MACRO_QUERY_PREFIX ) {
                    endv++;
                } else if (*endv == MACRO_SPECIAL_PREFIX ) {
                    endv++;
                } else if (*endv == MACRO_DBROW_PREFIX ) {
                    free_result = 1;
                    endv++;
                }
                while (*endv && (isalnum(*(unsigned char *)endv) || strchr("_[]",*endv))) {
                    endv++;
                }
                char tmp = *endv;
                *endv = '\0'; //replace char following variable name
                *v='\0'; //replace $ with null

                int free2;
                char *replace=get_variable(v+1,&free2,sorted_rows);

                char *tmp2;
                ovs_asprintf(&tmp2,"%s%s%s",NVL(newp),p,NVL(replace));

                if (free2) FREE(replace);

                FREE(newp);
                newp = tmp2;

                //restore end of strings
                *p=MACRO_VARIABLE_PREFIX;
                *endv = tmp;
                //advance
                p = endv;
            }
            // Last bit
            if (*p) {
                char *tmp2;
                ovs_asprintf(&tmp2,"%s%s",NVL(newp),p);
                FREE(newp);
                newp = tmp2;
            }
            //Now replace the array variable
            if (newp) {
                FREE(args->array[i]); //TODO : can we free this?
                args->array[i] = newp;
            }
            HTML_LOG(2,"End replace_variables [%s]",args->array[i]);
        }
    }
}

// Parse val eg. +2-3/4 
long numeric_constant_eval_first_arg(long val,Array *args) {

    if (args) {
        val = numeric_constant_eval_str(val,args->array[0]);
    }
    return val;
}


char *numeric_constant_arg_to_str(long val,Array *args) {
    char *result = NULL;
    long out = numeric_constant_eval_first_arg(val,args);
    ovs_asprintf(&result,"%ld",out);
    return result;
}


/**
 * =begin wiki
 * ==IF==
 * Multi line form:
 *
 * [:IF(exp):]
 * [:ELSE:]
 * [:ENDIF:]
 *
 * Single line form
 *
 * [:IF(exp,text):]
 * [:IF(exp,text,alternative_text):]
 *
 * =end wiki
 *
 */
char *macro_fn_if(MacroCallInfo *call_info)
{
    long l = numeric_constant_eval_first_arg(0,call_info->args);
    if (call_info->args == NULL || call_info->args->size == 1 ) {
        // Single form [:IF:] - supresses all line output until [:ENDIF:] or [:ELSE:]
        // Also returns NULL to remove itself from output.
        output_state_push(l);
        
    } else if (l) {
        // [:IF(exp,replace):] - if exp is true - result is 'replace'
        HTML_LOG(0,"val=%ld [%d] [%s]",l,call_info->args->size,call_info->args->array[1]);
        if (call_info->args->size >= 2) {
            return STRDUP(call_info->args->array[1]);
        }
    } else {
        // [:IF(exp,replace,replace2):] - if exp is false - result is 'replace2'
        HTML_LOG(0,"val=%ld [%d] [%s]",l,call_info->args->size,call_info->args->array[2]);
        if (call_info->args->size >= 3) {
            return STRDUP(call_info->args->array[2]);
        }
    }
    return NULL;
}
/*
 * =begin wiki
 * ==ELSEIF==
 * see multiline [IF]
 * =end wiki
 */
char *macro_fn_elseif(MacroCallInfo *call_info)
{
    char *result = NULL;

    if (call_info->args == NULL ||  call_info->args->size != 1 ) {
        call_info->free_result=0;
        result="ELSEIF";
    } else {
        long l = numeric_constant_eval_first_arg(0,call_info->args);
        output_state_eval(l);
    }
    return result;
}

/*
 * =begin wiki
 * ==ELSE==
 * see multiline [IF]
 * =end wiki
 */
char *macro_fn_else(MacroCallInfo *call_info) {

    char *result = NULL;
    if (call_info->args && call_info->args->size ) {
        call_info->free_result=0;
        result="ENDIF";
    } else {
        output_state_invert();
    }

    return result;
}
/*
 * =begin wiki
 * ==ENDIF==
 * see multiline [IF]
 * =end wiki
 */
char *macro_fn_endif(MacroCallInfo *call_info) {
    char *result = NULL;
    if (call_info->args && call_info->args->size ) {
        call_info->free_result=0;
        result="ENDIF";
    } else {
        output_state_pop();
    }
    return result;
}

/*
 * =begin wiki
 * ==EVAL==
 * Compute a value and insert into html output
 * Example:
   td { width:[:EVAL($@poster_menu_img_width-2):]px; }
 * =end wiki
 */
char *macro_fn_eval(MacroCallInfo *call_info)
{
    call_info->free_result = 1;
    return numeric_constant_arg_to_str(0,call_info->args);
}

/*
 * =begin wiki
 *
 * ==FONT_SIZE==
 * Compute font_size relative to user configured font size.
 * Examples:
     {{{
    .eptitle { font-size:100% ; font-weight:normal; font-size:[:FONT_SIZE(-2):]; }
    td { font-size:[:FONT_SIZE:]; font-family:"arial"; color:white; }
    }}}
 * =end wiki
 */

char *macro_fn_font_size(MacroCallInfo *call_info)
{
    return numeric_constant_arg_to_str(g_dimension->font_size,call_info->args);
}
char *macro_fn_title_size(MacroCallInfo *call_info) {
    return numeric_constant_arg_to_str(g_dimension->title_size,call_info->args);
}
char *macro_fn_body_width(MacroCallInfo *call_info) {
    long value = g_dimension->scanlines ;
    switch(value) {
        case 0:
        if (g_dimension->is_pal) {
            value = 700;
        } else {
            value = 685;
        }
        break;
        case 720:
            value = 1096;
            break;

    }

    return numeric_constant_arg_to_str(value,call_info->args);
}

/*
 * =begin wiki
 * ==URL_BASE==
 * Return link to /oversight path that will work on browser or tv.
 * Example:
 * {{{
 * img src="[:BASE_URL:]/templates/[:SKIN_NAME:]/images/detail/rating_[:RATING(precision=>0):]0.png"/>
 * }}}
 *
 * =end wiki
 */
char *macro_fn_url_base(MacroCallInfo *call_info)
{
    static char *base = NULL;
    call_info->free_result = 0;
    if (base == NULL) {
        if (g_dimension->local_browser) {
            ovs_asprintf(&base,"file://%s",appDir());
        } else {
            base = "/oversight";
        }
    }
    return base;
}

char *macro_fn_body_height(MacroCallInfo *call_info) {
    char* value = "100%";

    if (g_dimension->local_browser) {

        switch(g_dimension->scanlines) {
            case 0:
                if (g_dimension->is_pal) {
                    value = "490px";
                } else {
                    value = "400px";
                }
            break;
            case 720:
                value = "644px";
                break;
        }

    } else {
        value="100%";
    }
    call_info->free_result = 0;
    return value;

    //return numeric_constant_arg_to_str(value,args);
}

char *macro_fn_display_type(MacroCallInfo *call_info) {
    call_info->free_result = 0;
    return g_dimension->set_name;
}

char *macro_fn_scanlines(MacroCallInfo *call_info) {
    return numeric_constant_arg_to_str(g_dimension->scanlines,call_info->args);
}

/**
 * =begin wiki
 * ==EDIT_CONFIG==
 *
 * Write a html input table for a configuration file.
 * The config file is expected to have format 
 * name=value
 *
 * The help file has format
 * name:help text
 * OR
 * name:help text|val1|val2|...|valn
 *
 * At present it calls an external file "options.sh" to generate the HTML table. 
 * This script was kept from the original awk version of oversight as performance is not an issue 
 * It may get ported to native code one day.
 *
 * [:EDIT_CONFIG:]
 * [:EDIT_CONFIG(conf=>name of config file,help=>help file suffix):]
 *
 * Default path for conf and help files is oversight/{conf,help}
 * if file = skin.cfg folder is the oversight/templates/skin/{conf,help}
 *
 * =end wiki
 */
char *macro_fn_edit_config(MacroCallInfo *call_info) {

    char *result = NULL;
    struct hashtable *h = args_to_hash(call_info,"conf_file,help_suffix",NULL);
    if (h) {
        char *file=get_named_arg(h,"conf_file");
        char *help_suffix=get_named_arg(h,"help_suffix");
        char *cmd;

        HTML_LOG(0,"file[%s]",file);
        HTML_LOG(0,"help[%s]",help_suffix);
        HTML_LOG(0,"call[%s]",call_info->call);

        char *help_path = config_help_path(file,help_suffix);
        char *conf_path = config_path(file);
        char *def_path = config_defaults_path(file);

        //Note this outputs directly to stdout so always returns null
        ovs_asprintf(&cmd,"cd \"%s\" && ./bin/options.sh TABLE \"%s\" \"%s\" \"%s\" HIDE_VAR_PREFIX=1",
                appDir(),help_path,def_path,conf_path);

        FREE(help_path);
        FREE(def_path);
        FREE(conf_path);

        util_system_htmlout(cmd);
        FREE(cmd);

        call_info->free_result = 0;
        result="";

        free_named_args(h);

    }
    return result;
}

char *macro_fn_play_tvid(MacroCallInfo *call_info) {

    char *result = NULL;
    char *text="";
    if (call_info->args && call_info->args->size > 0)  {
        text = call_info->args->array[0];
    }
    if (playlist_size(call_info->sorted_rows)) {
        result = get_play_tvid(text);
    }
    return result;
}

char *name_list_macro(char *name_file,char *dbfieldid,DbGroupIMDB *group,char *class,int rows,int cols)
{
    char *result = NULL;
    if (group) {
        EVALUATE_GROUP(group);
        if (group->dbgi_size) {
            HTML_LOG(0,"%d rows %d cols",rows,cols);

            Array *out = array_new(free);
            char *tmp;
            ovs_asprintf(&tmp,"<table class=\"%s\">\n",class);
            array_add(out,tmp);
            
            int r,c;
            int i;

            for (r = 0 ; r < rows ; r++ ) {
                array_add(out,STRDUP("\n<tr>"));
                for (c = 0 ; c < cols ; c++ ) {
                    array_add(out,STRDUP("\n<td>"));

                    i = r * cols + c;
                    if (  i < group->dbgi_size ) {

                        char id[20];
                       
                        sprintf(id,"%d",group->dbgi_ids[i]);

                        Array *name_info=dbnames_fetch(id,name_file);


                        if (name_info) {

                            char *link = get_person_drilldown_link(VIEW_PERSON,dbfieldid,id,"",name_info->array[1],"","");

                            //At present name is "nm0000000:First Last" but this may 
                            //change.
                            array_add(out,link);

                            array_free(name_info);
                        } else {
                            array_add(out,STRDUP(id));
                        }

                    }

                    array_add(out,STRDUP("</td>\n"));
                }
                array_add(out,STRDUP("</tr>\n"));
            }

            array_add(out,STRDUP("</table>\n"));
            result = arraystr(out);
            array_free(out);
        }
    }
    return result;
}

char *macro_fn_person_name(MacroCallInfo *call_info)
{
    char *result = NULL;

    call_info->free_result = 0;

    char *id=query_val(QUERY_PARAM_PERSON);
    if (!EMPTY_STR(id)) {
        Db *db = firstdb(call_info);
        Array *actor_info = dbnames_fetch(id,db->people_file);
        if (actor_info) {
            result = actor_info->array[1];
        } else {
            result = id;
        }
    }
    return result;
}

/**
 * =begin wiki
 * ==PERSON_ID==
 * Return the imdb id of the current actor. This is just the person parameter.(QUERY_PARAM_PERSON)
 *
 * The domain should be passed as a parameter - eg "imdb" or "allocine"
 *
 * [:PERSON_ID(domain=>imdb):]
 * =end wiki
 */
char *macro_fn_person_id(MacroCallInfo *call_info)
{
    call_info->free_result = 0;

    char *result=NULL;
    struct hashtable *h = args_to_hash(call_info,"domain",NULL);
    if (h) {
        char *domain = get_named_arg(h,"domain");
        if (!EMPTY_STR(domain)) {

            Db *db = firstdb(call_info);
            result = current_person_id(db,domain);
        }

    }
    free_named_args(h);

    return result;
}

/*
 * =begin wiki
 * ==PERSON_ROLE==
 *
 * Return the current role of the person Actor, Director or Writer.
 * The roles are kept seperate to reduce possibility of namesake clashes.
 * The imdb ids are not used because scraping should not be tied to any
 * particular site. So the best identifier is name.
 *
 *
 * =end wiki
 */
char *macro_fn_person_role(MacroCallInfo *call_info)
{
    call_info->free_result = 0;
    char *result = NULL;
    char *role = query_val(QUERY_PARAM_PERSON_ROLE);
    if (strcmp(role,DB_FLDID_ACTOR_LIST) == 0) {
        result = NULL; // Dont display anything for Actor - avoids Actor/Actress issue.
    } else if (strcmp(role,DB_FLDID_WRITER_LIST) == 0) {
        result = "Writer";
    } else if (strcmp(role,DB_FLDID_DIRECTOR_LIST) == 0) {
        result = "Director";
    }
    return result;
}

char *people_table(MacroCallInfo *call_info,char *people_file,char *fieldid,char *class,DbGroupIMDB *people_field,
        int default_rows,int default_cols)
{

    char *result = NULL;
    if (has_rows(call_info,1)) {
        char *tmp;
        int rows=default_rows;
        int cols=default_cols;
        struct hashtable *h = args_to_hash(call_info,NULL,"rows,cols");
        if ((tmp = get_named_arg(h,"rows")) != NULL) {
            rows = atoi(tmp);
        }
        if ((tmp = get_named_arg(h,"cols")) != NULL) {
            cols = atoi(tmp);
        }

        result = name_list_macro(people_file,fieldid,people_field,class,rows,cols);
        free_named_args(h);
    }
    return result;
}

char *macro_fn_actors(MacroCallInfo *call_info)
{
    char *result = NULL;
    if (has_rows(call_info,1)) {
        DbItem *item = call_info->sorted_rows->rows[0];
        result = people_table(call_info,item->db->people_file,DB_FLDID_ACTOR_LIST,"actors",item->actors,2,6);
    }
    return result;
}

char *macro_fn_directors(MacroCallInfo *call_info)
{
    char *result = NULL;
    if (has_rows(call_info,1)) {
        DbItem *item = call_info->sorted_rows->rows[0];
        result = people_table(call_info,item->db->people_file,DB_FLDID_DIRECTOR_LIST,"directors",item->directors,1,2);
    }
    return result;
}
/*
 * =begin wiki
 * ==DUMP_VARS==
 *
 * Dump all variables with the given prefix
 * =end wiki
 */

char *macro_fn_dump_vars(MacroCallInfo *call_info)
{
    char *result = NULL;
    hashtable_dump("tmp",tmp_var_hash());
    hashtable_dump("ovs",g_oversight_config);
    hashtable_dump("catalog",g_catalog_config);
    hashtable_dump("skin",g_skin_config);
    hashtable_dump("locale",g_locale_config);
    hashtable_dump("setting",g_nmt_settings);

    return result;
}

char *macro_fn_writers(MacroCallInfo *call_info) {
    char *result = NULL;
    if (has_rows(call_info,1)) {
        DbItem *item = call_info->sorted_rows->rows[0];
        result = people_table(call_info,item->db->people_file,DB_FLDID_WRITER_LIST,"writers",item->writers,1,2);
    }
    return result;
}

char *macro_fn_sizegb(MacroCallInfo *call_info)
{
    char *result = NULL;
    DbItem *item = call_info->sorted_rows->rows[0];
    if (item) {
        ovs_asprintf(&result,"%.1fGb",dbrow_total_size(item) / 1024.0);
    }

    return result;
}

/*
 * Calc qualith from width (not heigth because of letterboxing)
 */
char *macro_fn_videoquality(MacroCallInfo *call_info)
{
    char *result = NULL;
    DbItem *item = call_info->sorted_rows->rows[0];
    if (item && item->video) {
        call_info->free_result=0;
        char *width_str = regextract1(item->video,"w0=([0-9]+)",1,0);

        char *interlaced = strstr(item->video,"i0=1");

        if (width_str) {
            int width = atol(width_str);
            FREE(width_str);
            if (width >= 1920 ) {
                if (interlaced) {
                    result="1080i";
                } else {
                    result="1080p";
                }
            } else if (width >= 1280 ) {
                if (interlaced) {
                    result="720i";
                } else {
                    result="720p";
                }
            } else {
                result="sd";
            }
        }
    }
    return result;
}

/*
 * =begin wiki
 * ==JS_DETAILS==
 *
 * JS_DETAILS([max=>n,fields=>field1|field2|field3...fieldx])
 *
 * Output all details for current items in a javascript/json array
 * if max not provided - all selected rows will be used.
 *
 * Example [:JS_DETAILS(max=>4,fields=>TITLE|FILE|EPISODE|PLOT):]
 *
 * For list of fields see [http://code.google.com/p/oversight/source/browse/trunk/src/dbfield.c dbfield.c]
 *
 * =end wiki
 */
char *macro_fn_jsdetails(MacroCallInfo *call_info)
{
    char *result = NULL;
    struct hashtable *h = args_to_hash(call_info,"fields","max");
    if (h) {
        char *tmp;
        char *fieldlist=get_named_arg(h,"fields");
        int max = 0;
        if ((tmp = get_named_arg(h,"max")) != NULL) {
            max = atoi(tmp);
        }

        Array*fields = splitstr(fieldlist,"|");
        Array*js = js_array(call_info->sorted_rows,max,fields);

        if (js) {
            result=arraystr(js);
        }
        array_free(fields);

        free_named_args(h);
    }
    return result;
}

Array *js_array(DbSortedRows *sorted_rows,int max,Array *fields) 
{
    int i=0,j=0;
    Array *out = NULL;
    if (sorted_rows == NULL || sorted_rows->num_rows == 0 || fields==NULL || fields->size == 0) return NULL;

    if (max > sorted_rows->num_rows || max == 0 ) max = sorted_rows->num_rows;

    // Convert field names to field ids.
    Array *field_ids = array_new(NULL);
    for(j = 0 ; j < fields->size ; j++ ) {

        char *name =fields->array[j];
        HTML_LOG(1,"name=[%s]",name);
        char *id = dbf_macro_to_fieldid(name);
        HTML_LOG(1,"id=[%s]",id);
        if (id == NULL) {
            html_error("unknown field id [%s]",name);
            id="";
        }
        array_add(field_ids,id);
    }
    
    if (sorted_rows && max) {
        out = array_new(free);
        for(i = 0 ; i < max ; i++ ) {
            DbItem *item = sorted_rows->rows[i];

            array_add(out,STRDUP((i==0?"[":",")));

            int j = 0;
            for(j = 0 ; j < field_ids->size ; j++ ) {
                char *js;
                char *field_id = field_ids->array[j];
                char *name = fields->array[j];

                if (EMPTY_STR(field_id)) {

                    ovs_asprintf(&js,"%c%s:\"???\"\n", (j==0?'{':','),fields->array[j]);
                    array_add(out,js);

                } else {
                    char *value = db_rowid_get_field(item,field_id);
                    if (value) {

                        // Write file paths as Url encoded
                        if (strcmp(name,"FILE") == 0) {
                            char *tmp = url_encode_static(value,NULL);
                            if (tmp != value) {
                                FREE(value);
                                value = tmp;
                            }
                        }


                        char *value2 = clean_js_string(value);
                        if (value2) {
                            ovs_asprintf(&js,"%c%s:\"%s\"\n", (j==0?'{':','),fields->array[j],value2);
                            array_add(out,js);
                            if (value2 != value) FREE(value2);
                        }
                        FREE(value);
                    }
                }
            }
            array_add(out,STRDUP("}\n"));

        }
        array_add(out,STRDUP("]"));
    }
    array_free(field_ids);
    return out;
}

/**
 * position = cell number on current page. This will be preserved to aid user navigation when returning to page.
 */
char *drilldown_url_by_item(DbItem *item,int position) 
{
    char *params=NULL;
    int free_name2=0;
    char *name2=NULL;
    ViewMode *view = get_drilldown_view(item);

    // The current cell number is pushed into the parent page query values
    char *cell_no_param = get_drilldown_name_static(QUERY_PARAM_SELECTED,1);

    if (view == VIEW_TVBOXSET) {

        name2 = url_encode_static(item->title,&free_name2);
        ovs_asprintf(&params,"%s=%d&"QUERY_PARAM_VIEW"=%s&p=&"QUERY_PARAM_TITLE_FILTER"="QPARAM_FILTER_EQUALS QPARAM_FILTER_STRING "%s",
                cell_no_param,position,
                view->name,name2);

    } else if (view == VIEW_TV) {
        name2 = url_encode_static(item->title,&free_name2);
        ovs_asprintf(&params,"%s=%d&"QUERY_PARAM_VIEW"=%s&p=&"QUERY_PARAM_TITLE_FILTER"="QPARAM_FILTER_EQUALS QPARAM_FILTER_STRING "%s&"QUERY_PARAM_SEASON"=%d",
                cell_no_param,position,
                view->name,name2,item->season);

    } else {
        ovs_asprintf(&params,"%s=%d&"QUERY_PARAM_VIEW"=%s&p=&idlist=%s",
                cell_no_param,position,
                view->name,build_id_list(item));
    }
    if (free_name2) FREE(name2);

    char *url = drill_down_url(params);
    FREE(params);

    return url;
}



void macro_init() {

    if (macros == NULL) {
        //HTML_LOG(1,"begin macro init");
        macros = string_string_hashtable("macro_names",64);

        hashtable_insert(macros,"ACTORS",macro_fn_actors);
        hashtable_insert(macros,"BACKGROUND_URL",macro_fn_background_url); // referes to images in sd / 720 folders.
        hashtable_insert(macros,"BACKGROUND_IMAGE",macro_fn_background_url); // Old name - deprecated.
        hashtable_insert(macros,"BACK_BUTTON",macro_fn_back_button);
        hashtable_insert(macros,"BANNER_URL",macro_fn_banner_url);
        hashtable_insert(macros,"BODY_HEIGHT",macro_fn_body_height);
        hashtable_insert(macros,"BODY_WIDTH",macro_fn_body_width);
        hashtable_insert(macros,"CERTIFICATE_IMAGE",macro_fn_cert_img);
        hashtable_insert(macros,"CHECKBOX",macro_fn_checkbox);
        hashtable_insert(macros,"DIRECTORS",macro_fn_directors);
        hashtable_insert(macros,"DETAIL_URL",macro_fn_details);
        hashtable_insert(macros,"DUMP_VARS",macro_fn_dump_vars);
        hashtable_insert(macros,"CONFIG_LINK",macro_fn_admin_config_link);
        hashtable_insert(macros,"DELETE_BUTTON",macro_fn_delete_button);
        hashtable_insert(macros,"EDIT_CONFIG",macro_fn_edit_config);
        hashtable_insert(macros,"ELSE",macro_fn_else);
        hashtable_insert(macros,"ELSEIF",macro_fn_elseif);
        hashtable_insert(macros,"ENDIF",macro_fn_endif);
        hashtable_insert(macros,"EPISODE_TOTAL",macro_fn_episode_total);
        hashtable_insert(macros,"EPISODE_COUNT",macro_fn_episode_count);
        hashtable_insert(macros,"EVAL",macro_fn_eval);
        hashtable_insert(macros,"EXIT_BUTTON",macro_fn_exit_button);
        hashtable_insert(macros,"EXTERNAL_URL",macro_fn_external_url);
        hashtable_insert(macros,"FANART_URL",macro_fn_fanart_url);
        hashtable_insert(macros,"FAVICON",macro_fn_favicon);
        hashtable_insert(macros,"FILE_PATH",macro_fn_file_path);
        hashtable_insert(macros,"FILE_ENCODED",macro_fn_file_enc);
        hashtable_insert(macros,"FILE_VOD_ATTRIBUTES",macro_fn_file_vod);
        hashtable_insert(macros,"FILE_NUM_PARTS",macro_fn_file_num_parts);
        hashtable_insert(macros,"FONT_SIZE",macro_fn_font_size);
        hashtable_insert(macros,"FORM_END",macro_fn_form_end);
        hashtable_insert(macros,"FORM_START",macro_fn_form_start);
        hashtable_insert(macros,"FLUSH",macro_fn_flush);
        hashtable_insert(macros,"GENRE",macro_fn_genre);
        hashtable_insert(macros,"GENRE_SELECT",macro_fn_genre_select);
        hashtable_insert(macros,"GRID",macro_fn_grid);
        hashtable_insert(macros,"HEADER",macro_fn_header);
        hashtable_insert(macros,"HELP_BUTTON",macro_fn_help_button);
        hashtable_insert(macros,"HOME_BUTTON",macro_fn_home_button);
        hashtable_insert(macros,"HOSTNAME",macro_fn_hostname);
        hashtable_insert(macros,"ICON",macro_fn_icon);
        hashtable_insert(macros,"ICON_LINK",macro_fn_icon_link);
        hashtable_insert(macros,"IF",macro_fn_if);
        hashtable_insert(macros,"IMAGE_URL",macro_fn_image_url);
        hashtable_insert(macros,"INCLUDE_TEMPLATE",macro_fn_include);
        hashtable_insert(macros,"IS_GAYA",macro_fn_is_gaya);
        hashtable_insert(macros,"JS_DETAILS",macro_fn_jsdetails);
        hashtable_insert(macros,"LEFT_BUTTON",macro_fn_left_button);
        hashtable_insert(macros,"LINK",macro_fn_link);
        hashtable_insert(macros,"LOOP_EXPAND",macro_fn_loop_expand);
        hashtable_insert(macros,"LOCK_BUTTON",macro_fn_lock_button);
        hashtable_insert(macros,"LOCKED_SELECT",macro_fn_locked_select);
        hashtable_insert(macros,"MARK_BUTTON",macro_fn_mark_button);
        hashtable_insert(macros,"MEDIA_SELECT",macro_fn_media_select);
        hashtable_insert(macros,"MEDIA_TOGGLE",macro_fn_media_toggle);
        hashtable_insert(macros,"MEDIA_TYPE",macro_fn_media_type);
        hashtable_insert(macros,"MENU_TVID",macro_fn_menu_tvid);
        hashtable_insert(macros,"MENU_PAGE_URL",macro_fn_menu_page_url);
        hashtable_insert(macros,"MENU_PAGE_NEXT_URL",macro_fn_menu_page_next_url);
        hashtable_insert(macros,"MENU_PAGE_PREV_URL",macro_fn_menu_page_prev_url);
        hashtable_insert(macros,"MOUNT_STATUS",macro_fn_mount_status);
        hashtable_insert(macros,"MOVIE_LISTING",macro_fn_movie_listing);
        hashtable_insert(macros,"MOVIE_TOTAL",macro_fn_movie_total);
        hashtable_insert(macros,"OTHER_MEDIA_TOTAL",macro_fn_other_media_total);
        hashtable_insert(macros,"ORIGINAL_TITLE",macro_fn_orig_title);
        hashtable_insert(macros,"ORIG_TITLE",macro_fn_orig_title);
        hashtable_insert(macros,"PAYPAL",macro_fn_paypal);
        hashtable_insert(macros,"PLAY_TVID",macro_fn_play_tvid);
        hashtable_insert(macros,"PAGE",macro_fn_page);
        hashtable_insert(macros,"PAGE_MAX",macro_fn_page_max);
        hashtable_insert(macros,"SET_PAGE",macro_fn_set_page);
        hashtable_insert(macros,"PERSON_ID",macro_fn_person_id);
        hashtable_insert(macros,"PERSON_IMAGE",macro_fn_person_image);
        hashtable_insert(macros,"PERSON_NAME",macro_fn_person_name);
        hashtable_insert(macros,"PERSON_ROLE",macro_fn_person_role);
        hashtable_insert(macros,"PERSON_URL",macro_fn_person_url);
        hashtable_insert(macros,"PLOT",macro_fn_plot);
        hashtable_insert(macros,"POSTER",macro_fn_poster);
        hashtable_insert(macros,"POSTER_URL",macro_fn_poster_url);
        hashtable_insert(macros,"RATING_SELECT",macro_fn_rating_select);
        hashtable_insert(macros,"RATING",macro_fn_rating);
        hashtable_insert(macros,"RATING_STARS",macro_fn_rating_stars);
        hashtable_insert(macros,"RESIZE_CONTROLS",macro_fn_resize_controls);
        hashtable_insert(macros,"RIGHT_BUTTON",macro_fn_right_button);
        hashtable_insert(macros,"RUNTIME",macro_fn_runtime);
        hashtable_insert(macros,"SCANLINES",macro_fn_scanlines);
        hashtable_insert(macros,"DISPLAY_TYPE",macro_fn_display_type);
        hashtable_insert(macros,"SEASON",macro_fn_season);
        hashtable_insert(macros,"SET",macro_fn_set);
        hashtable_insert(macros,"SELECT_CANCEL_SUBMIT",macro_fn_select_cancel_submit);
        hashtable_insert(macros,"SELECT_DELETE_SUBMIT",macro_fn_select_delete_submit);
        hashtable_insert(macros,"SELECT_DELIST_SUBMIT",macro_fn_select_delist_submit);
        hashtable_insert(macros,"SELECT_LOCK_SUBMIT",macro_fn_select_lock_submit);
        hashtable_insert(macros,"SELECT_MARK_SUBMIT",macro_fn_select_mark_submit);
        hashtable_insert(macros,"SELECT_UNLOCK_SUBMIT",macro_fn_select_unlock_submit);
        hashtable_insert(macros,"SETUP_BUTTON",macro_fn_setup_button);
        hashtable_insert(macros,"SKIN_NAME",macro_fn_skin_name);
        hashtable_insert(macros,"SIZEGB",macro_fn_sizegb);
        hashtable_insert(macros,"SORT_SELECT",macro_fn_sort_select);
        hashtable_insert(macros,"SORT_TYPE_TOGGLE",macro_fn_sort_type_toggle);
        hashtable_insert(macros,"SOURCE",macro_fn_source);
        hashtable_insert(macros,"START_CELL",macro_fn_start_cell);
        hashtable_insert(macros,"STATUS",macro_fn_status);
        hashtable_insert(macros,"SYS_LOAD_AVG",macro_fn_sys_load_avg);
        hashtable_insert(macros,"SYS_UPTIME",macro_fn_sys_uptime);
        hashtable_insert(macros,"TAB_TVID",macro_fn_menu_tvid);
        hashtable_insert(macros,"TEMPLATE_URL",macro_fn_template_url);
        hashtable_insert(macros,"TITLE",macro_fn_title);
        hashtable_insert(macros,"TITLE_SELECT",macro_fn_title_select);
        hashtable_insert(macros,"TITLE_SIZE",macro_fn_title_size);
        hashtable_insert(macros,"THUMB_URL",macro_fn_thumb_url);
        hashtable_insert(macros,"TVIDS",macro_fn_tvids);
        hashtable_insert(macros,"TV_LISTING",macro_fn_tv_listing);
        hashtable_insert(macros,"TV_MODE",macro_fn_tv_mode);
        hashtable_insert(macros,"URL_BASE",macro_fn_url_base);
        hashtable_insert(macros,"VERSION",macro_fn_version);
        hashtable_insert(macros,"VIDEOQUALITY",macro_fn_videoquality);
        hashtable_insert(macros,"WATCHED_SELECT",macro_fn_watched_select);
        hashtable_insert(macros,"WATCHED_TOGGLE",macro_fn_watched_toggle);
        hashtable_insert(macros,"WEB_STATUS",macro_fn_web_status);
        hashtable_insert(macros,"WRITERS",macro_fn_writers);
        hashtable_insert(macros,"YEAR",macro_fn_year);
        //HTML_LOG(1,"end macro init");
    }
}


char *macro_call(int pass,char *skin_name,char *orig_skin,char *call,DbSortedRows *sorted_rows,int *free_result,FILE *out,int *request_reparse)
{
    if (macros == NULL) macro_init();

    char *result = NULL;
    char *(*fn)(MacroCallInfo *) = NULL;
    Array *args=NULL;

    if (*call == MACRO_VARIABLE_PREFIX) {



        result=get_variable(call+1,free_result,sorted_rows);

        if (result == NULL) {

            printf("??%s?",call);

        }

    } else {

        //Macro call


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
                // Replace any variables in the function
                replace_variables(args,sorted_rows);
            }
        }
                

        MacroCallInfo call_info;
        memset(&call_info,0,sizeof(MacroCallInfo));

        call_info.skin_name = skin_name;
        call_info.orig_skin_name = orig_skin;
        call_info.call = call;
        call_info.args = args;
        call_info.sorted_rows = sorted_rows;
        call_info.free_result = 1;
        call_info.pass = pass;
        call_info.outfp = out;

        if (fn) {

            //HTML_LOG(1,"begin macro [%s]",call);
            result =  (*fn)(&call_info);
            *free_result=call_info.free_result;
            if (call_info.request_reparse) {
                (*request_reparse) ++;
                //HTML_LOG(0,"reparse requested by [%s]",call);
            }

            //HTML_LOG(1,"end macro [%s]",call);
        } else {
            html_error("unknown macro [%s]",call);
        }
        array_free(args);
    }
    return result;
}

// Store any loop bodies
static struct hashtable *loops=NULL;
Array *loop_register(char *loop_name)
{
    if (loops == NULL) {
        loops=string_string_hashtable("loops",10);
    }
    Array *lines = array_new(free);
    hashtable_insert(loops,STRDUP(loop_name),lines);
    HTML_LOG(0,"registered loop body [%s]",loop_name);
    return lines;
}
Array *loop_lookup(char *loop_name)
{
    Array *result = NULL;
    if (loops) {
        result = hashtable_search(loops,loop_name);
        if (!result) {
            html_error("cannot find loop [%s] ",loop_name);
        } else {
            HTML_LOG(0,"found loop [%s] ",loop_name);
        }
    }
    return result;
}

void loop_deregister_all() 
{
    if (loops) {
        HTML_LOG(0,"removing all loop bodies");
        hashtable_destroy(loops,1,(void *)array_free);
        loops = NULL;
    }
}

// vi:sw=4:et:ts=4
