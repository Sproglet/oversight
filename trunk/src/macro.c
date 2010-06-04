// $Id:$
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <assert.h>
#include <ctype.h>
#include <sys/statvfs.h>
#include <sys/types.h>

#include "template.h"
#include "hashtable.h"
#include "hashtable_loop.h"
#include "array.h"
#include "util.h"
#include "oversight.h"
#include "db.h"
#include "dbplot.h"
#include "display.h"
#include "dboverview.h"
#include "display.h"
#include "gaya_cgi.h"
#include "macro.h"
#include "dbfield.h"
#include "mount.h"
#include "gaya.h"
#include "actions.h"
#include "vasprintf.h"


#define MACRO_VARIABLE_PREFIX '$'
#define MACRO_SPECIAL_PREFIX '@'
#define MACRO_QUERY_PREFIX '?'
#define MACRO_DBROW_PREFIX '%'

static struct hashtable *macros = NULL;
char *get_variable(char *vname,int *free_result);
char *image_path_by_resolution(char *template_name,char *name);
char *get_named_arg(struct hashtable *h,char *name);

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


char *macro_fn_fanart_url(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    char *result = NULL;
    char *default_wallpaper=NULL;

    if (num_rows == 0 || sorted_rows == NULL ) {
        *free_result=0;
        return "?";
    }
    if (*oversight_val("ovs_display_fanart") == '0' ) {

        // do nothing
        
    } else if (args && args->size > 1 ) {

        ovs_asprintf(&result,"%s([default wallpaper])",call);

    } else {

        if (args && args->size == 1 ) {

            default_wallpaper = args->array[0];
        }

        char *fanart = get_picture_path(num_rows,sorted_rows,FANART_IMAGE);
TRACE;

        if (!fanart || !exists(fanart)) {

            if (default_wallpaper) {

                fanart = image_path_by_resolution(template_name,default_wallpaper);

            }
        }

        result  = file_to_url(fanart);
        FREE(fanart);
    }
    return result;
}

// used to find resolution dependent images - normally for wallpapers.
char *image_path_by_resolution(char *template_name,char *name)
{
    char *result = NULL;
    // Use default wallpaper

    if (g_dimension->scanlines == 0 ) {
        ovs_asprintf(&result,"%s/templates/%s/sd/%s",appDir(),template_name,name);
    } else {
        ovs_asprintf(&result,"%s/templates/%s/%d/%s",appDir(),template_name,g_dimension->scanlines,name);
    }
    return result;
}

char *macro_fn_web_status(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result = NULL;

    if (args == NULL || args->size == 0  || args->size > 2 ) {
        *free_result=0;
        result = "WEB_STATUS(url[,expected text])";
    } else {
        // If expected text is present prepare grep command to check wget output
        char *expected_text = NULL;
        if (args->size == 2 ) {
            // wget | grep -q causes broken pipe unless wget has -q also.
            ovs_asprintf(&expected_text," -O - | grep  -q \"%s\"",args->array[1]);
        } else {
            // otherwise silence wget.
            expected_text = STRDUP(" -O /dev/null");
        }

        char *cmd;

        ovs_asprintf(&cmd,"/bin/wget -U \"%s\" -q -t 1 --dns-timeout 2 --connect-timeout 5 --read-timeout 10 --ignore-length \"%s%s\" %s",
                USER_AGENT,
                (util_starts_with(args->array[0],"http")?"":"http://"),
                args->array[0],
                expected_text);

        HTML_LOG(0,"web status cmd [%s]",cmd);
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

char *macro_fn_mount_status(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
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
                // We also show - unknown mount status as good - keep things simple
                ovs_asprintf(&tmp,"%s<tr><td class=mount%s>%s %s</td></tr>",
                        NVL(result),v,(*v=='0'?bad:good),k);
                //ovs_asprintf(&tmp,"%s<tr><td>%s</td><td class=mount%s>%s</td></tr>",
                        //NVL(result),k,v,(*v=='1'?good:bad));
                FREE(result);
                result = tmp;
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

char *macro_fn_poster(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result = NULL;

    if (num_rows == 0 || sorted_rows == NULL ) {
        *free_result=0;
        return "?";
    }

    DbRowId *rid=sorted_rows[0];

    if (num_rows == 0) {

       *free_result=0;
       result = "poster - no rows";

    } else if (args && args->size  == 1) {

        result = get_poster_image_tag(rid,args->array[0],POSTER_IMAGE);
TRACE;

    } else if (!args || args->size == 0 ) {

        char *attr;
        long height;
        long width;


        if (rid) {

            if (rid->category == 'T') {
                height=g_dimension->tv_img_height;
                width=g_dimension->tv_img_width;
            } else {
                height=g_dimension->movie_img_height;
                width=g_dimension->movie_img_width;
            }
            ovs_asprintf(&attr," height=%d width=%d  ",height,width);

            result =  get_poster_image_tag(rid,attr,POSTER_IMAGE);
TRACE;
            FREE(attr);
TRACE;
        } 


    } else {

        *free_result = 0;
        result = "POSTER([attributes])";
    }
    return result;
}

char *macro_fn_plot(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    *free_result=1;
    char *result = NULL;

    if (num_rows == 0 || sorted_rows == NULL ) {
        *free_result=0;
        return "?";
    }

TRACE;
    int season = -1;
    int i;
    for ( i = 0 ; EMPTY_STR(result) && i < num_rows ; i++ ) {
        DbRowId *rid = sorted_rows[i];
        if (season == -1 || rid->season != season ) {
            season = rid->season;
            result = get_plot(rid,PLOT_MAIN);
            HTML_LOG(0,"plot for %s %d %s = [%s]",rid->title,rid->season,rid->episode,result);
        }
    }
    if (result) {
        result = STRDUP(result);
    }
TRACE;
    HTML_LOG(1,"plot[%s]",result);

    //char *clean = clean_js_string(result);
TRACE;
    return result;
}

char *macro_fn_sort_select(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char *result=NULL;

    if (!result) {
        struct hashtable *sort = string_string_hashtable(4);
        hashtable_insert(sort,DB_FLDID_TITLE,"Name");
        hashtable_insert(sort,DB_FLDID_INDEXTIME,"Age");
        hashtable_insert(sort,DB_FLDID_YEAR,"Year");
        result =  auto_option_list(QUERY_PARAM_TYPE_FILTER,DB_FLDID_INDEXTIME,sort);
        hashtable_destroy(sort,0,0);
    }
    *free_result = 0;
    return result;
}

char *macro_fn_media_select(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char *result=NULL;
    if (!result) {
    //    char *label;
    //    if (g_dimension->scanlines == 0) {
    //        label = "Tv+Mov";
    //    } else {
    //        label = "Tv+Movie";
    //    }
        struct hashtable *category = string_string_hashtable(4);

        char *both=QUERY_PARAM_MEDIA_TYPE_VALUE_MOVIE QUERY_PARAM_MEDIA_TYPE_VALUE_TV;
        hashtable_insert(category,both,"All");

        hashtable_insert(category,QUERY_PARAM_MEDIA_TYPE_VALUE_MOVIE,"Movie");
        hashtable_insert(category,QUERY_PARAM_MEDIA_TYPE_VALUE_TV,"Tv");
		hashtable_insert(category,QUERY_PARAM_MEDIA_TYPE_VALUE_OTHER,"Other");

        result =  auto_option_list(QUERY_PARAM_TYPE_FILTER,both,category);
        hashtable_destroy(category,0,0);
    }
    *free_result = 0;
    return result;
}

char *macro_fn_watched_select(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char *result=NULL;
    if (!result) {
        struct hashtable *watched = string_string_hashtable(4);
        hashtable_insert(watched,"","---");
        hashtable_insert(watched,QUERY_PARAM_WATCHED_VALUE_YES,"Watched");
        hashtable_insert(watched,QUERY_PARAM_WATCHED_VALUE_NO,"Unwatched");
        result =  auto_option_list(QUERY_PARAM_WATCHED_FILTER,"",watched);
        hashtable_destroy(watched,0,0);
    }
    *free_result = 0;
    return result;
}

// Checkbox list of scan options
char *macro_fn_checkbox(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char *result=NULL;
    if (!args || args->size < 3 ) {
        result = "CHECKBOX(htmlname_prefix,checked,htmlsep,values,..,..,)";
        *free_result = 0;
    } else {

        int i;
        char *htmlname=args->array[0];
        char *checked=args->array[1];
        char *sep=args->array[2];
        int first = 1;

        for(i = 3 ; i < args->size ; i++ ) {
            char *tmp;
            char *val = args->array[i];
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
char *macro_fn_episode_total(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char result[10]="";
    *free_result=0;
    if (!*result) {
        sprintf(result,"%d",g_episode_total);
    }
    return result;
}

char *macro_fn_movie_total(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char result[10]="";
    *free_result=0;
    if (!*result) {
        sprintf(result,"%d",g_movie_total);
    }
    return result;
}
char *macro_fn_other_media_total(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char result[10]="";
    *free_result=0;
    if (!*result) {
        sprintf(result,"%d",g_other_media_total);
    }
    return result;
}

char *macro_fn_title_select(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char *result=NULL;
    if (!result) {

        HTML_LOG(0,"macro_fn_title_select");
        struct hashtable *title = string_string_hashtable(30);

        char *letters[]= 
          { "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z","1",NULL};

        int i;
        for (i = 0 ; letters[i] ; i++ ) {
            hashtable_insert(title,letters[i],letters[i]);
        }
        hashtable_insert(title,"","*");
        result =  auto_option_list(QUERY_PARAM_TITLE_FILTER,"",title);
        hashtable_destroy(title,0,0);
    }
    *free_result = 0;
    return result;
}

char *macro_fn_genre_select(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char *result = NULL;
    if (g_genre_hash != NULL) {

        // Expand the genre hash table
        struct hashtable *expanded_genres = string_string_hashtable(16);
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
        *free_result = 0; // TODO : this should be freed but we'll leave until next release.
        hashtable_destroy(expanded_genres,1,1);
    }
    return result;
}

char *macro_fn_genre(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    char *genre = "";
    *free_result=0;

    if (num_rows && sorted_rows && sorted_rows[0]->genre ) {
        *free_result=1;
        genre =expand_genre(sorted_rows[0]->genre);
    }

    return genre;
}

char *macro_fn_title(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    char *result = "?";
    *free_result=0;

    if ( num_rows && sorted_rows && sorted_rows[0]->title ) {
        result = sorted_rows[0]->title;
    } 
    return result;
}

char *macro_fn_season(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    char *season="?";
    *free_result=0;

    if (num_rows && sorted_rows && sorted_rows[0]->season >=0) {
        ovs_asprintf(&season,"%d",sorted_rows[0]->season);
        *free_result=1;
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

char *macro_fn_runtime(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    int runtime = 0;
    int i;
    for(i = 0 ; i < num_rows ; i++ ) {
        DbRowId *rid = sorted_rows[i];
        if (rid->runtime > 0 ) {
            runtime = rid->runtime;
            break;
        }
    }

    HTML_LOG(0,"runtime=[%d]",runtime);

    if (runtime == 0) {
        *free_result=0;
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

    *free_result = 0;
    return runtime_str;
}
char *macro_fn_year(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    int i;
    if (num_rows == 0 || sorted_rows == NULL ) {
        *free_result=0;
        return "?";
    }
    char *year = NULL;
    int year_num = 0;
   
    // look for item with year set - sometimes tv Pilot does not have airdate 
    for(i = 0 ; i < num_rows && year_num <= 1900 ; i++ ) {
        DbRowId *rid = sorted_rows[i];

        if (rid->category == 'T' ) {

            HTML_LOG(0,"airdate[%s]=[%x]",rid->file,rid->airdate);
            struct tm *t = internal_time2tm(rid->airdate,NULL);
            year_num = t->tm_year+1900;

        } else if (rid->category == 'M' ) {

            year_num = rid->year;

        } else {
            struct tm *t = internal_time2tm(rid->date,NULL);
            year_num = t->tm_year+1900;
        }
    }


    ovs_asprintf(&year,"%d",year_num);
    return year;
}

char *macro_fn_cert_img(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *cert,*tmp;
    cert = tmp = NULL;

    if (num_rows == 0 || sorted_rows == NULL ) {
        *free_result=0;
        return "?";
    }

    if (*oversight_val("ovs_display_certificate") == '1') {

        cert = util_tolower(sorted_rows[0]->certificate);

        tmp=replace_str(cert,"usa:","us:");
        FREE(cert);
        cert=tmp;


        translate_inplace(cert,":_","/-");

        char *attr;
        ovs_asprintf(&attr," height=%d ",g_dimension->certificate_size);

        tmp = template_image_link("/cert",cert,NULL,sorted_rows[0]->certificate,attr);
        FREE(cert);
        FREE(attr);
        cert=tmp;
    }

    HTML_LOG(0,"xx cert[%s]",cert);
    return cert;
}

char *macro_fn_tv_listing(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    int rows=0;
    int cols=0;
    HTML_LOG(1,"macro_fn_tv_listing");
TRACE;
    if (!get_rows_cols(call,args,&rows,&cols)) {
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
    return tv_listing(num_rows,sorted_rows,rows,cols);
}


char *macro_fn_tv_paypal(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;

    return result;
}
char *macro_fn_tv_mode(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    static char *result = NULL;

    if (g_dimension->tv_mode == 0) {
        ovs_asprintf(&result,"<font class=error>%d Please change Video Output from AUTO in main av settings.</font>",
                g_dimension->tv_mode);
    } else {
        ovs_asprintf(&result,"%d",g_dimension->tv_mode);
    }

    return result;
}
char *macro_fn_sys_disk_used(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    *free_result=0;
    static char result[50] = "";

    if (!*result) {

        struct statvfs s;

        if (statvfs("/share/.",&s) == 0) {

            //use doubles to avoid overflow
            double free = s.f_bfree;

            free *= s.f_bsize;  //bytes

            free /= (1024*1024*1024) ; //Gigs

            double free_percent = 100.0 * s.f_bfree / s.f_blocks;

            sprintf(result,"%.1lfG free (%.1lf%%)",free,free_percent);
        
        }
    }

    return result;
}

char *macro_fn_paypal(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *p = NULL;
    if (!(g_dimension->local_browser) && *oversight_val("remove_donate_msg") != '1' ) {
        p = "<td width=25%><font size=2>Any contributions are gratefully received towards"
        "<font color=red>Oversight</font>,"
        "<font color=#FFFF00>FeedTime</font>,"
        "<font color=blue>Zebedee</font> and "
        "<font color=green>Unpak</font> scripts</font></td>"
        "<td><form action=\"https://www.paypal.com/cgi-bin/webscr\" method=\"post\">"
        "<input type=\"hidden\" name=\"cmd\" value=\"_s-xclick\">"
        //"<input type=\"hidden\" name=\"hosted_button_id\" value=\"2496882\">"
        //"<input width=50px type=\"image\" src=\"https://www.paypal.com/en_US/i/btn/btn_donateCC_LG.gif\" border=\"0\" name=\"submit\" alt=\"\">"
        "<input type=\"hidden\" name=\"hosted_button_id\" value=\"9700071\">"
        "<input width=50px type=\"image\" src=\"https://www.paypal.com/en_US/GB/i/btn/btn_donateCC_LG.gif\" border=\"0\" name=\"submit\" alt=\"PayPal - The safer, easier way to pay online.\">"
        "<img alt=\"\" border=\"0\" src=\"https://www.paypal.com/en_GB/i/scr/pixel.gif\" width=\"1\" height=\"1\">"
        "</form></td>";
        *free_result=0;
    }

    return p;
}

char *macro_fn_sys_load_avg(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    char *result=NULL;
    double av[3];
#if 0
    if (getloadavg(av,3) == 3) {
        ovs_asprintf(&result,"1m:%.2lf/%.2lf/%.2lf",av[0],av[1],av[2]);
    }
#else
    FILE *fp = fopen("/proc/loadavg","r");
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

char *macro_fn_sys_uptime(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    static char result[50] = "";

    *free_result = 0;
    if (!*result) {
        FILE *fp = fopen("/proc/uptime","r");
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

char *macro_fn_movie_listing(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return movie_listing(sorted_rows[0]);
}

// add code for a star image to a buffer and return pointer to end of buffer.
char *add_star(char *buf,char *star_path,int star_no) {
    char *p = buf;
    p += sprintf(p,"<img src=\"");
    p += sprintf(p,star_path,star_no);
    p += sprintf(p,"\">");
    return p;
}

char *macro_fn_resize_controls(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result)
{

    char *result = NULL;
    if (STRCMP(query_val(QUERY_PARAM_VIEW),VIEW_ADMIN) != 0) {
        result = get_tvid_resize_links();
    }
    return result;
    
}
char *macro_fn_tvids(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result)
{

    char *result = NULL;
    if (! *query_val(QUERY_PARAM_VIEW)) {
        result = get_tvid_links();
    }
    return result;
    
}

char *get_rating_stars(DbRowId *rid,int num_stars)
{

    double rating = rid->rating;
    static char *star_path=NULL;
    if (!star_path) {
        if (g_dimension->local_browser) {
            ovs_asprintf(&star_path,"file://%s/templates/%s/images/stars/star%%d.%s",
                    appDir(),
                    skin_name(),ovs_icon_type());
        } else {
            ovs_asprintf(&star_path,"/oversight/templates/%s/images/stars/star%%d.%s",
                    skin_name(),ovs_icon_type());
        }
    }

    if (rating > 10) rating=10;

    rating = rating * num_stars / 10.0 ;

    char *result = malloc((num_stars+1) * (strlen(star_path)+strlen("<img src=..>")+10));
    int i;

    char *p = result;

    for(i = 1 ; i <= (int)(rating+0.0001) ; i++) {

        p = add_star(p,star_path,10);
        num_stars --;

    }

    int tenths = (int)(0.001+10*(rating - (int)(rating+0.001)));
    if (tenths) {
        p = add_star(p,star_path,tenths);
        num_stars --;
    }

    while(num_stars > 0 ) {

        p = add_star(p,star_path,0);
        num_stars--;
    }

    return result;
}

char *macro_fn_rating_stars(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result = NULL;
    int num_stars=0;
    char *star_path=NULL;

    if (num_rows == 0 || sorted_rows == NULL ) {
        *free_result=0;
        return "?";
    }
    if (*oversight_val("ovs_display_rating") != '0') {

        if (args && args->size == 1 && sscanf(args->array[0],"%d",&num_stars) == 1 ) {

            star_path=args->array[1];

            result = get_rating_stars(sorted_rows[0],num_stars);

        } else {

            ovs_asprintf(&result,"%s(num_stars) %%d is replaced with 10ths of the rating, eg 7.9rating becomes star10.png*7,star9.png,star0.png*2)",call);
        }
    }
        
    return result;
}

char *macro_fn_source(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result = NULL;
    if (num_rows == 0 || sorted_rows == NULL ) {
        *free_result=0;
        return "?";
    }
    if (num_rows) {
        DbRowId *r=sorted_rows[0];
        int freeit;
        char *share = share_name(r,&freeit);
        result = add_network_icon(r,share);
        if (freeit) FREE(share);
    }
    return result;
}

char *macro_fn_rating(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result = NULL;

    if (num_rows == 0 || sorted_rows == NULL ) {
        *free_result=0;
        return "?";
    }
    if (*oversight_val("ovs_display_rating") != '0' && num_rows) {

        if (sorted_rows[0]->rating > 0.01) {
            ovs_asprintf(&result,"%.1lf",sorted_rows[0]->rating);
        }
    }

    return result;
}


// If a macro has arguments like, 1,cols=>3,rows=>4,5  then create a hashtable cols=>3,rows=>4
#define HASH_ASSIGN "=>"
struct hashtable *args_to_hash(Array *args,char *required_list,char *optional_list) {
    int i;

    struct hashtable *required_set = NULL;
    struct hashtable *optional_set = NULL;

    // Get list of required variables.
    if (required_list != NULL) {
        Array *a = split1ch(required_list,",");
        required_set = array_to_set(a);
        array_free(a);
    }

    // Get list of optional variables.
    if (optional_list != NULL) {
        Array *a = split1ch(optional_list,",");
        optional_set = array_to_set(a);
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
                        h = string_string_hashtable(16);
                    }
                    if (hashtable_search(h,name)) {
                        html_error("ignore duplicate arg[%s]",name);
                    } else {
                        hashtable_insert(h,name,val);
                    }
                } else {
                    html_error("ignore arg[%s] not in [%s][%s]",name,NVL(required_list),NVL(optional_list));
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
            }
        }
    }


    set_free(required_set);
    set_free(optional_set);
    return h;
}

/*
 * Grid Macro has format
 * GRID(rows=>r,cols=>c,img_height=300,img_width=200,offset=0,page_size=50);
 *
 * All parameters are optional.
 * rows,cols            = row and columns of thumb images in the grid (defaults to config file settings for that view)
 * img_height,img_width = thumb image dimensions ( defaults to config file settings for that view)
 * offset               = This setting is to allow multiple grids on the same page. eg. 
 * for a layout where X represents a thumb you mak have:
 *
 * XXXX
 * XX
 * XX
 *
 * This could be two grids
 * GRID(rows=>1,cols=>4,offset=0);
 * GRID(rows=>2,cols=>2,offset=4);
 *
 * In this secnario oversight also needs to know which is the last grid on the page, so it can add the page navigation to 
 * the correct grid. As the elements may occur in
 * any order in the template, this would either require two passes of the template, or the user to indicate the 
 * last grid. I took the easy option , so the user must spacify the total thumbs on the page.
 *
 * GRID(rows=>1,cols=>4,offset=0);
 * GRID(rows=>2,cols=>2,offset=4,last=1);
 */
static GridInfo *grid_info=NULL; // At the moment only one Grid(multi segments) per page.

char *get_named_arg(struct hashtable *h,char *name)
{
    char *ret = NULL;
    if (h) {
        ret = hashtable_search(h,name);
    }
    return ret;
}
void free_named_args(struct hashtable *h) {
    if (h) {
        hashtable_destroy(h,1,1);
    }
}

char *macro_fn_grid(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    struct hashtable *h = args_to_hash(args,NULL,"rows,cols,img_height,img_width,offset,page_size");
    
    if (grid_info == NULL) {
        grid_info = grid_info_init();
    }

    GridSegment *gs = grid_info_add_segment(grid_info);

    // Copy default grid size and dimensions
    gs->dimensions = *(g_dimension->current_grid);
    gs->offset = 0;
    
    char *tmp;
    if ((tmp = get_named_arg(h,"page_size")) != NULL) {
        if (grid_info->page_size != DEFAULT_PAGE_SIZE) {
            html_error("duplicate page size");
        } else {
            grid_info->page_size = atoi(tmp);
        }
    }

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
        if (grid_info->page_size == DEFAULT_PAGE_SIZE) {
            html_error("GRID: page_size must be given with offset");
        }
    }

    char *result = get_grid(get_current_page(),gs,num_rows,sorted_rows);

    free_named_args(h);

HTML_LOG(0,"macro length = %d",NVL(result));

    return result;
}

char *macro_fn_header(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return STRDUP("header");
}

char *macro_fn_hostname(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    *free_result=0;
    return util_hostname();
}

char *macro_fn_form_start(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    int free_url=0;
    char *url=NULL;

TRACE;
    if (strcasecmp(query_val(QUERY_PARAM_VIEW),VIEW_ADMIN) == 0) {
        char *action = query_val(QUERY_PARAM_ACTION);
        if (strcasecmp(action,"ask") == 0 || strcasecmp(action,"cancel") == 0) {
            return NULL;
        } else {
            url=cgi_url(1);// clear URL
        } 
    } else {
TRACE;
        //we dont want it in the URL after the form is submitted.
        //keep query string eg when marking deleting. Select is passed as post variable
        url=self_url("select=");
        free_url=1;
    }
TRACE;
    char *hidden = add_hidden("idlist,view,page,sort,select,"
            QUERY_PARAM_TYPE_FILTER","QUERY_PARAM_REGEX","QUERY_PARAM_WATCHED_FILTER);
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

char *macro_fn_form_end(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    ovs_asprintf(&result,"<input type=hidden item_count=\"%d\" /></form>",g_item_count);
    return result;
}

char *macro_fn_is_gaya(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    *free_result=0;
    if (g_dimension->local_browser) {
        return "1";
    } else {
        return "0";
    }
}

char *macro_fn_include(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    if (args && args->size == 1) {
        display_template(orig_skin,args->array[0],num_rows,sorted_rows);
    } else if (!args) {
        html_error("missing  args for include");
    } else {
        html_error("number of args for include = %d",args->size);
    }
    return NULL;
}

char *macro_fn_start_cell(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    *free_result=0;
    char *result=NULL;

    char *start_cell = get_start_cell();
    if (start_cell && *start_cell) {

        result = start_cell;

    } else if (*query_val(QUERY_PARAM_REGEX)) {
        result="filter5";

    } else {
        result= "selectedCell";
    }

    return result;

}
char *macro_fn_media_type(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    *free_result=0;
    char *mt="?";
    switch(*query_val(QUERY_PARAM_TYPE_FILTER)) {
		case 'O': mt="Other"; break;
        case 'T': mt="TV Shows"; break;
        case 'M': mt="Movies"; break;
        default: mt="All Video"; break;
    }

    return mt;
}
char *macro_fn_version(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    char *version=OVS_VERSION;
    if (strstr(version,"2009")) {
        version +=4;
    }
    return replace_all(version,"BETA","b",0);

}

char *macro_fn_media_toggle(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    return get_toggle("red",QUERY_PARAM_TYPE_FILTER,
            QUERY_PARAM_MEDIA_TYPE_VALUE_TV,"Tv",
            QUERY_PARAM_MEDIA_TYPE_VALUE_MOVIE,"Film");

}
char *macro_fn_watched_toggle(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return get_toggle("yellow",QUERY_PARAM_WATCHED_FILTER,
            QUERY_PARAM_WATCHED_VALUE_NO,"Unwatched",
            QUERY_PARAM_WATCHED_VALUE_YES,"Watched");
}
char *macro_fn_sort_type_toggle(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return get_toggle("blue",QUERY_PARAM_SORT,
            DB_FLDID_TITLE,"Name",
            DB_FLDID_INDEXTIME,"Age");
}
char *macro_fn_filter_bar(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

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
                FREE(params);
            }

            ovs_asprintf(&result,"Use keypad to search%s<font class=keypada>[%s]</font>%s",
                    start,current_regex,(left?left:""));
            FREE(start);
            if (left) FREE(left);

        } else {

            ovs_asprintf(&result,"<input type=text name="QUERY_PARAM_SEARCH_TEXT" value=\"%s\" >"
                    "<input type=submit name=searchb value=Search >"
                    "<input type=submit name=searchb value=Hide >"
                    "<input type=hidden name="QUERY_PARAM_SEARCH_MODE" value=\"%s\" >"
                    ,query_val(QUERY_PARAM_SEARCH_TEXT),query_val(QUERY_PARAM_SEARCH_MODE));

        }

    } else {
        result = get_theme_image_link("p=0&" QUERY_PARAM_SEARCH_MODE "=1","","find","");
    }
    return result;
}

// Display a link back to this cgi file with paramters adjusted.
char *macro_fn_link(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;

    if (args && args->size == 2) {

        result = get_self_link(args->array[0],"",args->array[1]);

    } else if (args && args->size == 3) {

        result= get_self_link(args->array[0],args->array[2],args->array[1]);

    } else {

        printf("%s(params,title[,attr])",call);
    }
    return result;
}

char *macro_fn_icon_link(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (args && args->size == 2) {

        result = get_theme_image_link(args->array[0],"",args->array[1],"");

    } else if (args && args->size == 3) {

        result= get_theme_image_link(args->array[0],args->array[2],args->array[1],"");

    } else if (args && args->size == 3) {

        result= get_theme_image_link(args->array[0],args->array[2],args->array[1],args->array[3]);

    } else {

        printf("%s(params,icon[,href_attr[,image_attr]])",call);
    }
    return result;
}

// write an image url
char *macro_fn_background_image(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (args && args->size == 1) {
        char *tmp = image_path_by_resolution(template_name,args->array[0]);
        result = file_to_url(tmp);
        FREE(tmp);
    } else {
        ovs_asprintf(&result,"%s(image base name)",call);
    }
    return result;
}

char *macro_fn_favicon(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result="";
    *free_result = 0;
    if (is_pc_browser()) {
        result = "<link rel=\"shortcut icon\" href=\"/oversight/templates/ovsicon.ico\" />";
    }
    return  result;
}

char *macro_fn_skin_name(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    *free_result = 0;
    return skin_name();
}

char *macro_fn_template_url(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result)
{
    char *result=NULL;
    if (args && args->size >= 1) {

        char *name = arraystr(args);
        result = file_source("",name,""); 
        FREE(name);

    } else {

        printf("%s(TEMPLATE_URL[name])",call);
    }
    return result;
}

// Display a template image from images folder - if not present look in defaults.
char *macro_fn_image_url(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result)
{
    char *result=NULL;
    if (args && args->size >= 1) {

        char *name = arraystr(args);
        result = image_source("",name,""); 
        FREE(name);

    } else {

        printf("%s(IMAGE_URL[name])",call);
    }
    return result;
}
// Display an icon ICON(name,[attribute]) - if not present look in defaults.
char *macro_fn_icon(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (args && args->size == 1) {

        result= get_theme_image_tag(args->array[0],"");

    } else if (args && args->size == 2) {

        result= get_theme_image_tag(args->array[0],args->array[1]);

    } else {

        printf("%s(icon_name[,attr])",call);
    }
    return result;
}

char *config_link(char *config_file,char *help_suffix,char *html_attributes,char *text) {
    char *params,*link;
    ovs_asprintf(&params,"action=settings&file=%s&help=%s&title=%s",config_file,help_suffix,text);
    link = get_self_link(params,html_attributes,text);
    FREE(params);
    return link;
}

char *macro_fn_admin_config_link(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    char *result=NULL;

    if (args && args->size == 3) {

        result= config_link(args->array[0],args->array[1],"",args->array[2]);

    } else if (args && args->size == 4) {

        result= config_link(args->array[0],args->array[1],args->array[3],args->array[2]);

    } else {

        printf("%s(config_file,help_suffix,text[,html_attributes])",call);
    }
    return result;
}


char *macro_fn_status(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return get_status();
}


char *macro_fn_help_button(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result = NULL;
    char *tag=get_theme_image_tag("help",NULL);
    if (!g_dimension->local_browser) {
#define PROJECT_HOME "http://code.google.com/p/oversight/wiki/OversightIntro"
        ovs_asprintf(&result,"<a href=\"" PROJECT_HOME"\" target=\"ovshelp\">%s</a>",tag);
    } else {
        ovs_asprintf(&result,"<a href=\"javascript:alert('[RED] mark\n[GREEN] unmark\n[DELETE] delist/delete');\" >%s</a>",tag);
    }
    FREE(tag);
    return result;
}

char *macro_fn_setup_button(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return get_theme_image_link(QUERY_PARAM_VIEW"=admin&action=ask","TVID=SETUP","configure","");
}

char *get_page_control(int on,int offset,char *tvid_name,char *image_base_name) {

    char *select = query_val(QUERY_PARAM_SELECT);
    char *view = query_val(QUERY_PARAM_VIEW);
    int page = get_current_page();
    char *result = NULL;

    assert(view);
    assert(tvid_name);
    assert(image_base_name);

//    char *button_attr=" width=10px height=10px ";
    char *button_attr="";

    if (! *select) {
        //only show page controls when NOT selecting
        if (on)  {
            char *params=NULL;
            char *attrs=NULL;
            ovs_asprintf(&params,"p=%d",page+offset);
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
        } else if (! *view ) {
            if (!g_dimension->local_browser) {
                //show disabled page controls in browser
                char *image_off=NULL;
                ovs_asprintf(&image_off,"%s-off",image_base_name);
                result = get_theme_image_tag(image_off,button_attr);
                FREE(image_off);
            }
        }
    }
    return result;
}

char *macro_fn_left_button(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    int on = get_current_page() > 0;

    return get_page_control(on,-1,"pgup","left");
}




char *macro_fn_right_button(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    int on = ((get_current_page()+1)*g_dimension->current_grid->rows*g_dimension->current_grid->cols < num_rows);

    return get_page_control(on,1,"pgdn","right");
}



char *macro_fn_back_button(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (*query_val(QUERY_PARAM_VIEW) && !*query_val(QUERY_PARAM_SELECT)) {
        char *attr = "";
        if (args && args->size == 1) {
            attr=args->array[0];
        }
        result = get_theme_image_return_link("name=up","back",attr);
    }
    return result;
}

char *macro_fn_menu_tvid(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    char *url = self_url(QUERY_PARAM_VIEW"=&idlist=");
    ovs_asprintf(&result,"<a href=\"%s\" TVID=TAB ></a>",url);
    FREE(url);
    return result;
}
char *macro_fn_home_button(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;

    if(!*query_val(QUERY_PARAM_SELECT)) {
        char *tag=get_theme_image_tag("home",NULL);
        ovs_asprintf(&result,"<a href=\"%s?\" name=home TVID=HOME >%s</a>",cgi_url(0),tag);
        FREE(tag);
    }

    return result;
}

char *macro_fn_exit_button(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;

    if(g_dimension->local_browser && !*query_val(QUERY_PARAM_SELECT)) {
        char *tag=get_theme_image_tag("exit",NULL);
        ovs_asprintf(&result,"<a href=\"/start.cgi\" name=home >%s</a>",tag);
        FREE(tag);
    }
    return result;
}

char *macro_fn_mark_button(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (!*query_val(QUERY_PARAM_SELECT) && allow_mark()) {
        if (g_dimension->local_browser) {
            char *tag=get_theme_image_tag("mark",NULL);
            ovs_asprintf(&result,
                    "<a href=\"javascript:alert('Select item then remote\n[RED] to mark watched,\nGREEN for not watched')\">%s</a>",tag);
            FREE(tag);
        } else {
            result = get_theme_image_link("select=Mark","","mark","");
        }
    }
    return result;
}

char *macro_fn_delete_button(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (!*query_val(QUERY_PARAM_SELECT) && (allow_delete() || allow_delist())) {
        if (g_dimension->local_browser) {
            char *tag=get_theme_image_tag("delete",NULL);
            ovs_asprintf(&result,
                "<a href=\"javascript:alert('Select item then remote\n[DELETE/CLEAR] button')\">%s</a>",tag);
            FREE(tag);
        } else {
            result = get_theme_image_link("select=Delete","","delete","");
        }
    }
    return result;
}
char *macro_fn_select_mark_submit(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (STRCMP(query_val(QUERY_PARAM_SELECT),FORM_PARAM_SELECT_VALUE_MARK)==0) {
        ovs_asprintf(&result,"<input type=submit name=action value=Mark >");
    }
    return result;
}
char *macro_fn_select_delete_submit(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (STRCMP(query_val(QUERY_PARAM_SELECT),FORM_PARAM_SELECT_VALUE_DELETE)==0) {
        ovs_asprintf(&result,"<input type=submit name=action value=Delete onclick=\"return confirm('STOP! REALLY DELETE FILES?');\" >");
    }
    return result;
}
char *macro_fn_select_delist_submit(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (STRCMP(query_val(QUERY_PARAM_SELECT),FORM_PARAM_SELECT_VALUE_DELETE)==0) {
        ovs_asprintf(&result,"<input type=submit name=action value=Remove_From_List >");
    }
    return result;
}
char *macro_fn_select_cancel_submit(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (*query_val(QUERY_PARAM_SELECT)) {
        ovs_asprintf(&result,"<input type=submit name=select value=Cancel >");
    }
    return result;
}
char *macro_fn_external_url(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (num_rows == 0 || sorted_rows == NULL ) {
        *free_result=0;
        return "?";
    }
    if (!g_dimension->local_browser){
        char *url=sorted_rows[0]->url;
        if (url != NULL) {
            char *image=get_theme_image_tag("upgrade"," alt=External ");
            char *website="";
            if (util_starts_with(url,"tt")) {
                website = "http://www.imdb.com/title/";
            }
            ovs_asprintf(&result,"<a href=\"%s%s\">%s</a>",website,url,image);
            FREE(image);
        }
    }
    return result;
}

// Very simple expression evaluator - no precedence, no brackets.
long numeric_constant_eval_str(long val,char *expression) {

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
            
            if (*p == '-' || isdigit(*p)) {

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

void replace_variables(Array *args)
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
                while (*endv && (isalnum(*endv) || strchr("_[]",*endv))) {
                    endv++;
                }
                char tmp = *endv;
                *endv = '\0'; //replace char following variable name
                *v='\0'; //replace $ with null

                int free2;
                char *replace=get_variable(v+1,&free2);

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


/*
 * Stack to manage output state.
 * IF , and elseif push the expression value to TOS
 * else negates TOS.
 * There is also a value below TOS that indicates if a clause has fired for this 
 * if-elseif-else-endif
 */
#define IF_CLAUSE_FIRED output_state_stack[output_state_tos]
#define IF_CLAUSE_VALUE output_state_stack[output_state_tos-1]
static long output_state_stack[100];
static int output_state_tos=-1;
long output_state() {
    
    //HTML_LOG(0,"[%d]if(%d) && fired=%d",output_state_tos,IF_CLAUSE_VALUE,IF_CLAUSE_FIRED);

    if (output_state_tos >= 1 ) {
        return (IF_CLAUSE_VALUE!=0 && IF_CLAUSE_FIRED == 1);
    } else {
        return 1;
    }
}
void output_state_push(long val) {
    output_state_stack[++output_state_tos] = val;
}
long output_state_pop() {
    if (output_state_tos >= 0 ) { 
        return output_state_stack[output_state_tos--];
    } else {
        return -1;
    }
}

char *macro_fn_if(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result)
{
    long l = numeric_constant_eval_first_arg(0,args);
    if (args == NULL || args->size == 1 ) {
        // Single form [:IF:] - supresses all line output until [:ENDIF:] or [:ELSE:]
        // Also returns NULL to remove itself from output.

        int current_state = output_state();
        //reserve two spaces on the stack
        output_state_push(0);
        output_state_push(0); 
        if (current_state) {
            IF_CLAUSE_VALUE = l;
            if (l) { IF_CLAUSE_FIRED++; }
        } else {
            IF_CLAUSE_FIRED=2;
        }
        
    } else if (l) {
        // [:IF(exp,replace):] - if exp is true - result is 'replace'
        HTML_LOG(0,"val=%ld [%d] [%s]",l,args->size,args->array[1]);
        if (args->size >= 2) {
            return STRDUP(args->array[1]);
        }
    } else {
        // [:IF(exp,replace,replace2):] - if exp is false - result is 'replace2'
        HTML_LOG(0,"val=%ld [%d] [%s]",l,args->size,args->array[2]);
        if (args->size >= 3) {
            return STRDUP(args->array[2]);
        }
    }
    return NULL;
}
char *macro_fn_elseif(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result)
{
    char *result = NULL;

    if (args == NULL ||  args->size != 1 ) {
        *free_result=0;
        result="ELSEIF";
    } else {
        if (IF_CLAUSE_FIRED <= 1) {
            long l = numeric_constant_eval_first_arg(0,args);
            IF_CLAUSE_VALUE = l;
            if (l) { IF_CLAUSE_FIRED++; }
        }
    }
    return result;
}

char *macro_fn_else(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    if (IF_CLAUSE_FIRED <= 1) {
        IF_CLAUSE_VALUE = !IF_CLAUSE_VALUE;
        if (IF_CLAUSE_VALUE) { IF_CLAUSE_FIRED++; }
    }

    return NULL;
}
char *macro_fn_endif(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result = NULL;
    if (args && args->size ) {
        *free_result=0;
        result="ENDIF";
    } else {
        output_state_pop();
        output_state_pop(); // This is the value that tracks if a clause fired
    }
    return result;
}

char *macro_fn_eval(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result)
{
    *free_result = 1;
    return numeric_constant_arg_to_str(0,args);
}

char *macro_fn_number(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result)
{
    return numeric_constant_arg_to_str(0,args);
}
char *macro_fn_font_size(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result)
{
    return numeric_constant_arg_to_str(g_dimension->font_size,args);
}
char *macro_fn_title_size(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return numeric_constant_arg_to_str(g_dimension->title_size,args);
}
char *macro_fn_body_width(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
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

    return numeric_constant_arg_to_str(value,args);
}
char *macro_fn_url_base(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result)
{
    static char *base = NULL;
    *free_result = 0;
    if (base == NULL) {
        if (g_dimension->local_browser) {
            ovs_asprintf(&base,"file://%s",appDir());
        } else {
            base = "/oversight";
        }
    }
    return base;
}

char *macro_fn_body_height(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
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
    *free_result = 0;
    return value;

    //return numeric_constant_arg_to_str(value,args);
}

char *macro_fn_scanlines(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return numeric_constant_arg_to_str(g_dimension->scanlines,args);
}

// Write a html input table for a configuration file. The help file(arg2) decides which options to show.
char *macro_fn_edit_config(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    char *result = NULL;
    if (args && args->size == 2) {
        char *file=args->array[0];
        char *help_suffix=args->array[1];
        char *cmd;

        //Note this outputs directly to stdout so always returns null
        ovs_asprintf(&cmd,"cd \"%s\" && ./options.sh TABLE \"help/%s.%s\" \"conf/.%s.defaults\" \"conf/%s\" HIDE_VAR_PREFIX=1",
                appDir(),file,help_suffix,file,file);

        system(cmd);
        FREE(cmd);

        *free_result = 0;

        result="";

    } else {
        ovs_asprintf(&result,"%s(config_file,help_suffix)",call);
    }
    return result;
}

char *macro_fn_play_tvid(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    char *result = NULL;
    char *text="";
    if (args && args->size > 0)  {
        text = args->array[0];
    }
    if (playlist_size(num_rows,sorted_rows)) {
        result = get_play_tvid(text);
    }
    return result;
}


/*
 <tr>
    <td>
        <table border="0" cellspacing="0" cellpadding="0" background="file:///opt/sybhttpd/localhost.images/sd/list_bar.
png">
            <tr>
                <td width="40" height="35" align="right"><font size="2" color=user1><b>28</b></font></td>
                <td width="40" align="right">
                    <img src="file:///opt/sybhttpd/localhost.images/sd/list_folder.png" width="35" height="25">
                </td>
                <td width="290"><a href="http://localhost.drives:8883/HARD_DISK/Complete/house.s06e08.720p.hdtv.x264.imm
erse.extra.par.s.nzb/?filter=3" name="28" onkeyleftset="media" onkeyrightset="FILE_INDEX" tvid="28" alt="house.s06e08.72
0p.hdtv....text/plain                4 KB" file=c   fip="house.s06e08.720p.hdtv.x264.immerse.extra.par.s.nzb"><font size
="2" color=user1><b><marquee behavior=focus width=290>&nbsp;&nbsp;house.s06e08.720p.hdtv.x264.immerse.extra.par.s.nzb</m
arquee></b></font></a></td>
                <td width="10"></td>
            </tr>
        </table>
    </td>
</tr>
<tr><td height="2"></td></tr>
*/

char *get_gaya_row(int pos,Array *files,
        int number_cell_width,int number_cell_height,int icon_cell_width,
        int image_width,int image_height,
        int name_width,
        int space_width) {
    char *tmp;

    char *link;
    char *name = files->array[pos];

    char *link_content;
    char *image;

    char *encoded_name = url_encode(name+1);

    ovs_asprintf(&link_content,
        "<font size=\"2\" color=user1><b><marquee behavior=focus width=%d>&nbsp;&nbsp;%s</marquee></b></font>",
        name_width,name+1);

    if (*name == 'd' )  {
        ovs_asprintf(&link,
            "<a href=\"http://localhost.drives:8883%s%s/?filter=%s\" name=\"%d\" tvid=\"%d\" "
            "onkeyleftset=\"media\" onkeyrightset=\"FILE_INDEX\" alt=\"%s\" file=c "
            "fip=\"%s\">%s</a>",
            get_gaya_short_folder(),encoded_name,get_gaya_filter(),pos,pos,name+1,name+1,link_content);
        image=gaya_image("list_folder.png");

    } else {
        image=gaya_get_file_image(name+1);
        ovs_asprintf(&link,"%s",link_content);
    }
    FREE(link_content);

    ovs_asprintf(&tmp,
    "<tr><td>\n"
        "<table border=\"0\" cellspacing=\"0\" cellpadding=\"0\" background=\"%s\"><tr>\n"
        "<td width=\"%d\" height=\"%d\" align=\"right\"><font size=\"2\" color=user1><b>%d</b></font></td>\n"
        "<td width=\"%d\" align=\"right\"><img src=\"%s\" width=\"%d\" height=\"%d\"></td>\n"
        "<td width=\"%d\">%s</td>\n"
        "<td width=\"10\"></td>\n"
        "</tr></table>\n"
    "</td></tr>\n\n"
    "<tr><td height=\"2\"></td></tr>\n\n",
         gaya_image("list_bar.png"),
         number_cell_width,number_cell_height,pos,
         icon_cell_width,image,image_width,image_height,
         name_width,link);

    FREE(encoded_name);
    FREE(image);
    FREE(link);

    return tmp;
        
}

char *macro_fn_gaya_list_rows(
        char *template_name,
        char *call,
        Array *args,
        int num_rows,
        DbRowId **sorted_rows,
        int *free_result)
{
    *free_result = 1;
    char *result = NULL;

    //args = row height, col1 width, col2width , col3 width , col4width

    Array *files = gaya_get_files();

    int arg=0;

    if (args == NULL || args->size != 7 ) {
        *free_result = 0;
        return "GAYA_LIST_ROWS(number_cell_w,number_cell_h,icon_cell_w,image_w,image_h,name_w,space_w)";
    }
    int number_cell_width = atol(args->array[arg++]);
    int number_cell_height = atol(args->array[arg++]);
    int icon_cell_width=atol(args->array[arg++]);
    int image_width=atol(args->array[arg++]);
    int image_height=atol(args->array[arg++]);
    int name_width=atol(args->array[arg++]);
    int space_width=atol(args->array[arg++]);

    int i = 0;
    int start_file = gaya_first_file();
    int end_file = gaya_last_file();

    HTML_LOG(0,"Files from %d to %d",start_file,end_file);
    for(i = start_file ; i<= end_file ; i++ ) {
        char *tmp;
        char *new_row = 
            get_gaya_row(i-1,files,
                    number_cell_width,number_cell_height,icon_cell_width,
                    image_width,image_height,
                    name_width,space_width);

        //HTML_LOG(0,"ROW[%s]",new_row);

        ovs_asprintf(&tmp,"%s%s",NVL(result),new_row);
        FREE(result);
        FREE(new_row);
        result = tmp;
    }

    //HTML_LOG(0,"RESULT[%s]",result);
    return result;
}

char *macro_fn_gaya_folder(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    *free_result = 0;
    return get_gaya_short_folder();
}

char *macro_fn_gaya_root_folder_name(char *template_name,char *orig_skin,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    *free_result = 1;
    char *result = NULL;

    char *f = get_gaya_short_folder();
    f++; 

    char *end = strchr(f,'/');
    if (end == NULL) {
        end = f + strlen(f);
    }
    ovs_asprintf(&result,"%.*s",end-f,f);
    return result;
}

void macro_init() {

    if (macros == NULL) {
        //HTML_LOG(1,"begin macro init");
        macros = string_string_hashtable(64);

        hashtable_insert(macros,"BACKGROUND_IMAGE",macro_fn_background_image); // referes to images in sd / 720 folders.
        hashtable_insert(macros,"BACK_BUTTON",macro_fn_back_button);
        hashtable_insert(macros,"BODY_HEIGHT",macro_fn_body_height);
        hashtable_insert(macros,"BODY_WIDTH",macro_fn_body_width);
        hashtable_insert(macros,"CERTIFICATE_IMAGE",macro_fn_cert_img);
        hashtable_insert(macros,"CHECKBOX",macro_fn_checkbox);
        hashtable_insert(macros,"CONFIG_LINK",macro_fn_admin_config_link);
        hashtable_insert(macros,"DELETE_BUTTON",macro_fn_delete_button);
        hashtable_insert(macros,"EDIT_CONFIG",macro_fn_edit_config);
        hashtable_insert(macros,"ELSE",macro_fn_else);
        hashtable_insert(macros,"ELSEIF",macro_fn_elseif);
        hashtable_insert(macros,"ENDIF",macro_fn_endif);
        hashtable_insert(macros,"EPISODE_TOTAL",macro_fn_episode_total);
        hashtable_insert(macros,"EVAL",macro_fn_eval);
        hashtable_insert(macros,"EXIT_BUTTON",macro_fn_exit_button);
        hashtable_insert(macros,"EXTERNAL_URL",macro_fn_external_url);
        hashtable_insert(macros,"FANART_URL",macro_fn_fanart_url);
        hashtable_insert(macros,"FAVICON",macro_fn_favicon);
        hashtable_insert(macros,"FILTER_BAR",macro_fn_filter_bar);
        hashtable_insert(macros,"FONT_SIZE",macro_fn_font_size);
        hashtable_insert(macros,"FORM_END",macro_fn_form_end);
        hashtable_insert(macros,"FORM_START",macro_fn_form_start);
        hashtable_insert(macros,"GAYA_FOLDER",macro_fn_gaya_folder);
        hashtable_insert(macros,"GAYA_LIST_ROWS",macro_fn_gaya_list_rows);
        hashtable_insert(macros,"GAYA_ROOT_FOLDER_NAME",macro_fn_gaya_root_folder_name);
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
        hashtable_insert(macros,"LEFT_BUTTON",macro_fn_left_button);
        hashtable_insert(macros,"LINK",macro_fn_link);
        hashtable_insert(macros,"MARK_BUTTON",macro_fn_mark_button);
        hashtable_insert(macros,"MEDIA_SELECT",macro_fn_media_select);
        hashtable_insert(macros,"MEDIA_TOGGLE",macro_fn_media_toggle);
        hashtable_insert(macros,"MEDIA_TYPE",macro_fn_media_type);
        hashtable_insert(macros,"MENU_TVID",macro_fn_menu_tvid);
        hashtable_insert(macros,"MOUNT_STATUS",macro_fn_mount_status);
        hashtable_insert(macros,"MOVIE_LISTING",macro_fn_movie_listing);
        hashtable_insert(macros,"MOVIE_TOTAL",macro_fn_movie_total);
        hashtable_insert(macros,"NUMBER",macro_fn_number);
        hashtable_insert(macros,"OTHER_MEDIA_TOTAL",macro_fn_other_media_total);
        hashtable_insert(macros,"PAYPAL",macro_fn_paypal);
        hashtable_insert(macros,"PLAY_TVID",macro_fn_play_tvid);
        hashtable_insert(macros,"PLOT",macro_fn_plot);
        hashtable_insert(macros,"POSTER",macro_fn_poster);
        hashtable_insert(macros,"RATING",macro_fn_rating);
        hashtable_insert(macros,"RATING_STARS",macro_fn_rating_stars);
        hashtable_insert(macros,"RESIZE_CONTROLS",macro_fn_resize_controls);
        hashtable_insert(macros,"RIGHT_BUTTON",macro_fn_right_button);
        hashtable_insert(macros,"RUNTIME",macro_fn_runtime);
        hashtable_insert(macros,"SCANLINES",macro_fn_scanlines);
        hashtable_insert(macros,"SEASON",macro_fn_season);
        hashtable_insert(macros,"SELECT_CANCEL_SUBMIT",macro_fn_select_cancel_submit);
        hashtable_insert(macros,"SELECT_DELETE_SUBMIT",macro_fn_select_delete_submit);
        hashtable_insert(macros,"SELECT_DELIST_SUBMIT",macro_fn_select_delist_submit);
        hashtable_insert(macros,"SELECT_MARK_SUBMIT",macro_fn_select_mark_submit);
        hashtable_insert(macros,"SETUP_BUTTON",macro_fn_setup_button);
        hashtable_insert(macros,"SKIN_NAME",macro_fn_skin_name);
        hashtable_insert(macros,"SORT_SELECT",macro_fn_sort_select);
        hashtable_insert(macros,"SORT_TYPE_TOGGLE",macro_fn_sort_type_toggle);
        hashtable_insert(macros,"SOURCE",macro_fn_source);
        hashtable_insert(macros,"START_CELL",macro_fn_start_cell);
        hashtable_insert(macros,"STATUS",macro_fn_status);
        hashtable_insert(macros,"SYS_DISK_USED",macro_fn_sys_disk_used);
        hashtable_insert(macros,"SYS_LOAD_AVG",macro_fn_sys_load_avg);
        hashtable_insert(macros,"SYS_UPTIME",macro_fn_sys_uptime);
        hashtable_insert(macros,"TAB_TVID",macro_fn_menu_tvid);
        hashtable_insert(macros,"TEMPLATE_URL",macro_fn_template_url);
        hashtable_insert(macros,"TITLE",macro_fn_title);
        hashtable_insert(macros,"TITLE_SELECT",macro_fn_title_select);
        hashtable_insert(macros,"TITLE_SIZE",macro_fn_title_size);
        hashtable_insert(macros,"TVIDS",macro_fn_tvids);
        hashtable_insert(macros,"TV_LISTING",macro_fn_tv_listing);
        hashtable_insert(macros,"TV_MODE",macro_fn_tv_mode);
        hashtable_insert(macros,"URL_BASE",macro_fn_url_base);
        hashtable_insert(macros,"VERSION",macro_fn_version);
        hashtable_insert(macros,"WATCHED_SELECT",macro_fn_watched_select);
        hashtable_insert(macros,"WATCHED_TOGGLE",macro_fn_watched_toggle);
        hashtable_insert(macros,"WEB_STATUS",macro_fn_web_status);
        hashtable_insert(macros,"YEAR",macro_fn_year);

        //HTML_LOG(1,"end macro init");
    }
}

// ?xx = html query variable
// ovs_xxx = oversight config
// catalog_xxx = catalog config
// unpak_xxx = unpak config
//

char *get_variable(char *vname,int *free_result)
{

    int convert_int = 0;
    int int_val=0;

    *free_result = 0;
    char *result=NULL;

    if (*vname == MACRO_SPECIAL_PREFIX ) {

        if (util_starts_with(vname+1,"gaya")) {

            if (STRCMP(vname+1,"gaya") == 0) {

                convert_int=1;
                int_val = g_dimension->local_browser;

            } else if (STRCMP(vname+1,"gaya_page") == 0) {

                convert_int=1;
                int_val = get_gaya_page();

            } else if (STRCMP(vname+1,"gaya_file_total") == 0) {

                convert_int=1;
                int_val = gaya_file_total();

            } else if (STRCMP(vname+1,"gaya_prev_page") == 0) {

                convert_int=1;
                int_val = gaya_prev_page();

            } else if (STRCMP(vname+1,"gaya_next_page") == 0) {

                convert_int=1;
                int_val = gaya_next_page();

            } else if (STRCMP(vname+1,"gaya_first_file") == 0) {

                convert_int=1;
                int_val = gaya_first_file();

            } else if (STRCMP(vname+1,"gaya_last_file") == 0) {

                convert_int=1;
                int_val = gaya_last_file();

            } else if (STRCMP(vname+1,"gaya_prev_file") == 0) {

                convert_int=1;
                int_val = gaya_prev_file();
            }

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

        }

    } else if (*vname == MACRO_QUERY_PREFIX ) {

        // html query variable ?name=val
        result=query_val(vname+1);

    } else if (*vname == MACRO_DBROW_PREFIX ) {

        HTML_LOG(0,"DBROW LOOKUP [%s]",vname+1);
        char *fieldid = dbf_macro_to_fieldid(vname+1);
        if (fieldid) {
            HTML_LOG(0,"DBROW LOOKUP [%s]",fieldid);
            // Get the value from the first row in the set
            result=db_get_field(fieldid);
        }

    } else if (util_starts_with(vname,"ovs_") ) {

        result = oversight_val(vname);

    } else if (util_starts_with(vname,"catalog_")) {

        result = catalog_val(vname);

    } else if (util_starts_with(vname,"unpak_")) {

        result = unpak_val(vname);

    }
    if (convert_int) {
        ovs_asprintf(&result,"%d",int_val);
        *free_result = 1;
    }

    return result;
}

char *macro_call(char *template_name,char *orig_skin,char *call,int num_rows,DbRowId **sorted_rows,int *free_result)
{


TRACE;
    if (macros == NULL) macro_init();

    char *result = NULL;
    char *(*fn)(char *template_name,char *orig_skin,char *name,Array *args,int num_rows,DbRowId **,int *) = NULL;
    Array *args=NULL;

    if (*call == MACRO_VARIABLE_PREFIX) {


TRACE;
        result=get_variable(call+1,free_result);

        if (result == NULL) {

            printf("?%s?",call);

        }

    } else {

        //Macro call
TRACE;

        char *p = strchr(call,'(');
        if (p == NULL) {
            fn = hashtable_search(macros,call);
        } else {
            char *q=strchr(p,')');
            if (q == NULL) {
                html_error("missing ) for [%s]",call);
            } else {
TRACE;
                // Get the arguments
                *q='\0';
                args = split(p+1,",",0);
                *q=')';
                // Get the function
                *p = '\0';
                fn = hashtable_search(macros,call);
                *p='(';
                // Replace any variables in the function
                replace_variables(args);
            }
        }
                

        if (fn) {
TRACE;
            //HTML_LOG(1,"begin macro [%s]",call);
            *free_result=1;
            result =  (*fn)(template_name,orig_skin,call,args,num_rows,sorted_rows,free_result);
TRACE;
            //HTML_LOG(1,"end macro [%s]",call);
        } else {
            printf("?%s?",call);
        }
        array_free(args);
    }
    return result;
}

// vi:sw=4:et:ts=4
