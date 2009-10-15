#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <assert.h>
#include <ctype.h>
#include <sys/statvfs.h>
#include <sys/types.h>

#include "hashtable.h"
#include "hashtable_loop.h"
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

#define MACRO_VARIABLE_PREFIX '$'
#define MACRO_QUERY_PREFIX '?'
#define MACRO_DBROW_PREFIX '%'

static struct hashtable *macros = NULL;
char *get_variable(char *vname);
char *image_path(char *template_name,char *name);

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

char *macro_fn_fanart_url(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    char *result = NULL;
    char *default_wallpaper=NULL;

    if (*oversight_val("ovs_display_fanart") == '0' ) {

        // do nothing

        
    } else if (args && args->size > 1 ) {

        ovs_asprintf(&result,"%s([default wallpaper])",call);

    } else {

        if (args && args->size == 1 ) {

            default_wallpaper = args->array[0];
        }

        char *fanart = get_picture_path(num_rows,sorted_rows,FANART_IMAGE);

        if (!fanart || !exists(fanart)) {

            if (default_wallpaper) {

                fanart = image_path(template_name,default_wallpaper);

            }
        }

        result  = file_to_url(fanart);
        FREE(fanart);
    }
    return result;
}

char *image_path(char *template_name,char *name)
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

char *macro_fn_poster(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result = NULL;

    DbRowId *rid=sorted_rows[0];

    if (num_rows == 0) {

       *free_result=0;
       result = "poster - no rows";

    } else if (args && args->size  == 1) {

        result = get_poster_image_tag(rid,args->array[0],POSTER_IMAGE);

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
            FREE(attr);
        } 


    } else {

        *free_result = 0;
        result = "POSTER([attributes])";
    }
    return result;
}

char *macro_fn_plot(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    *free_result=0;
    char *result = NULL;
    int max = g_dimension->max_plot_length;
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

    result = get_main_plot_static(sorted_rows[0]);
    if (result && max > 0 && max < strlen(result)) {
        if (max > 10) {
            strcpy(result+max-4,"...");
        }
        result[max] = '\0';
    }
    return result;
}

// TODO - Sort needs to default to Sort By Age. Add extra option to auto_option_list - default value.
char *macro_fn_sort_select(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char *result=NULL;

    if (!result) {
        struct hashtable *sort = string_string_hashtable(4);
        hashtable_insert(sort,DB_FLDID_TITLE,"Name");
        hashtable_insert(sort,DB_FLDID_INDEXTIME,"Age");
        hashtable_insert(sort,DB_FLDID_YEAR,"Year");
        result =  auto_option_list(QUERY_PARAM_TYPE_FILTER,"Age",sort);
        hashtable_destroy(sort,0,0);
    }
    *free_result = 0;
    return result;
}

char *macro_fn_media_select(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char *result=NULL;
    if (!result) {
        char *label;
        if (g_dimension->scanlines == 0) {
            label = "Tv+Mov";
        } else {
            label = "Tv+Movie";
        }
        struct hashtable *category = string_string_hashtable(4);
        hashtable_insert(category,"M","Movie");
        hashtable_insert(category,"T","Tv");
        result =  auto_option_list(QUERY_PARAM_TYPE_FILTER,label,category);
        hashtable_destroy(category,0,0);
    }
    *free_result = 0;
    return result;
}

char *macro_fn_watched_select(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char *result=NULL;
    if (!result) {
        struct hashtable *watched = string_string_hashtable(4);
        hashtable_insert(watched,"W","Watched");
        hashtable_insert(watched,"U","Unwatched");
        result =  auto_option_list(QUERY_PARAM_WATCHED_FILTER,"---",watched);
        hashtable_destroy(watched,0,0);
    }
    *free_result = 0;
    return result;
}

// Checkbox list of scan options
char *macro_fn_checkbox(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
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
            if (val && *val && strcmp(val,"\"\"") != 0 ) {
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
char *macro_fn_episode_total(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char result[10]="";
    *free_result=0;
    if (!*result) {
        sprintf(result,"%d",g_episode_total);
    }
    return result;
}

char *macro_fn_movie_total(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char result[10]="";
    *free_result=0;
    if (!*result) {
        sprintf(result,"%d",g_movie_total);
    }
    return result;
}
char *macro_fn_other_media_total(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char result[10]="";
    *free_result=0;
    if (!*result) {
        sprintf(result,"%d",g_other_media_total);
    }
    return result;
}

void add_letter_range(struct hashtable *title,unsigned char start,unsigned char end,int max_group_size) {
    unsigned char ch;
    int size=0;
    char group_title[50] = "";
    char group_range[3] = "";


    for(ch = start ; ch <= end ; ch ++ ) {

        int delta = g_title_letter_count[ch];
        if (size+delta > max_group_size) {
            // push current option group to option list and start a new one
            if (size) {

                HTML_LOG(0,"Adding range [%s][%s] at char %c/%d size %d",group_range,group_title,ch,ch,size);
                hashtable_insert(title,STRDUP(group_range),STRDUP(group_title));
                size=0;
            }
        }
        if (size == 0) {
            // Start range
            group_range[0]=ch;
            // Start title
            sprintf(group_title,"%c",ch);
        }
        size += delta;
        // update range
        group_range[1]=ch;
        group_range[2]='\0';
        // update title
        if (delta) {
            if (ch != *group_range) {
                sprintf(group_title+1,"-%c",ch);
            }
        }
    }
    if (size) {
        HTML_LOG(0,"Adding end range [%s][%s] at char %c/%d size %d",group_range,group_title,end,end,size);
        hashtable_insert(title,STRDUP(group_range),STRDUP(group_title));
    }
}

char *macro_fn_title_select(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char *result=NULL;
    if (!result) {

        struct hashtable *title = string_string_hashtable(30);

#if 1
        add_letter_range(title,' ','@',25);
        add_letter_range(title,'A','Z',25);
#else


        hashtable_insert(title,"A","A");
        hashtable_insert(title,"B","B");
        hashtable_insert(title,"C","C");
        hashtable_insert(title,"D","D");
        hashtable_insert(title,"EF","EF");
        hashtable_insert(title,"GH","GH");
        hashtable_insert(title,"IK","IJK");
        hashtable_insert(title,"L","L");
        hashtable_insert(title,"M","M");
        hashtable_insert(title,"NP","NOP");
        hashtable_insert(title,"QR","QR");
        hashtable_insert(title,"S","S");
        hashtable_insert(title,"T","T");
        hashtable_insert(title,"UZ","U-Z");
        hashtable_insert(title,"0","0-9");
#endif
        result =  auto_option_list(QUERY_PARAM_TITLE_FILTER,"All",title);
        hashtable_destroy(title,1,1);
    }
    *free_result = 0;
    return result;
}
char *macro_fn_title2_select(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char *result=NULL;
    if (!result) {
        result =  auto_option_list("t2","All",g_first_two_letters);
    }
    *free_result = 0;
    return result;
}

char *macro_fn_genre_select(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char *result = NULL;
    if (!result) {
        result = auto_option_list(DB_FLDID_GENRE,"All Genres",g_genre_hash);
    }
    *free_result = 0;
    return result;
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

    time_t c;
    char *year = NULL;
    DbRowId *rid = sorted_rows[0];
    int year_num = 0;
   
    if (rid->category == 'T' ) {

       c = rid->airdate;
        struct tm *t = localtime(&c);
        year_num = t->tm_year+1900;

    } else if (rid->category == 'M' ) {

        year_num = rid->year;

    } else {
        c = rid->date;
        struct tm *t = localtime(&c);
        year_num = t->tm_year+1900;
    }

    // TODO This is a logical bug - need to stop using uniz time functions to support dates before 1970
    if (year_num > 1970) {
        ovs_asprintf(&year,"%d",year_num);
    }
    return year;
}

char *macro_fn_cert_img(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *tmp=NULL;

    if (*oversight_val("ovs_display_certificate") == '1') {
        char *cert = util_tolower(sorted_rows[0]->certificate);


        tmp=replace_all(cert,"usa:","us:",0);
        FREE(cert);
        cert=tmp;


        tmp=replace_all(cert,":","/",0);
        FREE(cert);
        cert=tmp;

        ovs_asprintf(&tmp,"%s/templates/%s/images/cert/%s.%s",appDir(),skin_name(),cert,ovs_icon_type());
        FREE(cert);
        cert=tmp;

        char *attr;
        ovs_asprintf(&attr," width=%d height=%d ",g_dimension->certificate_size,g_dimension->certificate_size);

        tmp = get_local_image_link(cert,sorted_rows[0]->certificate,attr);
        FREE(attr);
    }

    return tmp;
}

char *macro_fn_tv_listing(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    int rows=0;
    int cols=0;
    HTML_LOG(1,"macro_fn_tv_listing");
    if (!get_rows_cols(call,args,&rows,&cols)) {
        rows = 16;
        cols = 2;
    }
    return tv_listing(num_rows,sorted_rows,rows,cols);
}


char *macro_fn_tv_paypal(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;

    return result;
}
char *macro_fn_tv_mode(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    static char *result = NULL;

    if (g_dimension->tv_mode == 0) {
        ovs_asprintf(&result,"<font class=error>%d Please change Video Output from AUTO in main av settings.</font>",
                g_dimension->tv_mode);
    } else {
        ovs_asprintf(&result,"%d",g_dimension->tv_mode);
    }

    return result;
}
char *macro_fn_sys_disk_used(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
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

char *macro_fn_paypal(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *p = NULL;
    if (!(g_dimension->local_browser) && *oversight_val("remove_donate_msg") != '1' ) {
        p = "<td width=25%><font size=2>Any contributions are gratefully received towards"
        "<font color=red>Oversight</font>,"
        "<font color=#FFFF00>FeedTime</font>,"
        "<font color=blue>Zebedee</font> and "
        "<font color=green>Unpak</font> scripts</font></td>"
        "<td><form action=\"https://www.paypal.com/cgi-bin/webscr\" method=\"post\">"
        "<input type=\"hidden\" name=\"cmd\" value=\"_s-xclick\">"
        "<input type=\"hidden\" name=\"hosted_button_id\" value=\"2496882\">"
        "<input width=50px type=\"image\" src=\"https://www.paypal.com/en_US/i/btn/btn_donateCC_LG.gif\" border=\"0\" name=\"submit\" alt=\"\">"
        "<img alt=\"\" border=\"0\" src=\"https://www.paypal.com/en_GB/i/scr/pixel.gif\" width=\"1\" height=\"1\">"
        "</form></td>";
        *free_result=0;
    }
    return p;
}

char *macro_fn_sys_load_avg(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    static char result[50] = "";
    *free_result = 0;
    if (!*result) {
        double av[3];
#if 0
        if (getloadavg(av,3) == 3) {
            sprintf(result,"1m:%.2lf/%.2lf/%.2lf",av[0],av[1],av[2]);
        }
#else
        FILE *fp = popen("uptime","r");
        if (fp) {
#define BLEN 99
            char buf[BLEN];
            while(fgets(buf,BLEN,fp) != NULL) {
                char *p = strstr(buf,"average:");
                if (p) {
                    p = strchr(p,' ');
                    if (p) {
                        sscanf(p," %lf, %lf, %lf",av,av+1,av+2);
                    }
                    sprintf(result,"%.2lf/%.2lf/%.2lf",av[0],av[1],av[2]);
                }
            }
            pclose(fp);
        }
#endif
    }
    return result;
}

char *macro_fn_sys_uptime(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

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

char *macro_fn_movie_listing(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
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

char *macro_fn_tvids(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return get_tvid_links(sorted_rows);
}

char *get_rating_stars(DbRowId *rid,int num_stars)
{

    double rating = rid->rating;
    static char *star_path=NULL;
    if (!star_path) {
        ovs_asprintf(&star_path,"/oversight/templates/%s/images/stars/star%%d.%s",
                skin_name(),ovs_icon_type());
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

char *macro_fn_rating_stars(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result = NULL;
    int num_stars=0;
    char *star_path=NULL;

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

char *macro_fn_source(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result = NULL;
    if (num_rows) {
        DbRowId *r=sorted_rows[0];
        if (r->db && r->db->source) {
            if (*(r->db->source) != '*') {
                result = add_network_icon(r->db->source,r->db->source);
            }
        }
    }
    return result;
}

char *macro_fn_rating(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result = NULL;

    if (*oversight_val("ovs_display_rating") != '0' && num_rows) {

        if (sorted_rows[0]->rating > 0.01) {
            ovs_asprintf(&result,"%.1lf",sorted_rows[0]->rating);
        }
    }

    return result;
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

    int free_url=0;
    char *url=NULL;

    if (strcasecmp(query_val("view"),"admin") == 0) {
        char *action = query_val("action");
        if (strcasecmp(action,"ask") == 0 || strcasecmp(action,"cancel") == 0) {
            return NULL;
        } else {
            url="?"; // clear URL
        } 
    } else {
        //we dont want it in the URL after the form is submitted.
        //keep query string eg when marking deleting. Select is passed as post variable
        url=self_url("select=");
        free_url=1;
    }
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
                FREE(params);
            }

            ovs_asprintf(&result,"Use keypad to search%s<font class=keypada>[%s]</font>%s",
                    start,current_regex,(left?left:""));
            FREE(start);
            if (left) FREE(left);

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

// Display a link back to this cgi file with paramters adjusted.
char *macro_fn_link(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
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

char *macro_fn_icon_link(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
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
char *macro_fn_image_url(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (args && args->size == 1) {
        char *tmp = image_path(template_name,args->array[0]);
        result = file_to_url(tmp);
        FREE(tmp);
    } else {
        ovs_asprintf(&result,"%s(image base name)",call);
    }
    return result;
}

// Display an icon
char *macro_fn_icon(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
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

char *macro_fn_admin_config_link(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

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


char *macro_fn_status(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return get_status();
}


char *macro_fn_help_button(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result = NULL;
    if (!g_dimension->local_browser) {
#define PROJECT_HOME "http://code.google.com/p/oversight/wiki/OversightIntro"
        char *tag=get_theme_image_tag("help",NULL);
        ovs_asprintf(&result,"<a href=\"" PROJECT_HOME"\" target=\"ovshelp\">%s</a>",tag);
        FREE(tag);
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

            HTML_LOG(2,"dbg params [%s] attr [%s] tvid [%s]",params,attrs,tvid_name);

            result = get_theme_image_link(params,attrs,image_base_name,"");
            FREE(params);
            FREE(attrs);
        } else if (! *view ) {
            //Only show disabled page controls in main menu view (not tv / movie subpage) - this may change
            char *image_off=NULL;
            ovs_asprintf(&image_off,"%s-off",image_base_name);
            result = get_theme_image_tag(image_off,NULL);
            FREE(image_off);
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
        FREE(tag);
    }

    return result;
}

char *macro_fn_exit_button(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;

    if(g_dimension->local_browser && !*query_val("select")) {
        char *tag=get_theme_image_tag("exit",NULL);
        ovs_asprintf(&result,"<a href=\"/start.cgi\" name=home >%s</a>",tag);
        FREE(tag);
    }
    return result;
}

char *macro_fn_mark_button(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (!*query_val("select") && allow_mark()) {
        if (g_dimension->local_browser) {
            char *tag=get_theme_image_tag("mark",NULL);
            ovs_asprintf(&result,
                    "<a href=\"javascript:alert('Select item then remote\n[9] to [w]atch,\n[8] to [u]nwatch')\">%s</a>",tag);
            FREE(tag);
        } else {
            result = get_theme_image_link("select=Mark","","mark","");
        }
    }
    return result;
}

char *macro_fn_delete_button(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *result=NULL;
    if (!*query_val("select") && (allow_delete() || allow_delist())) {
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
            FREE(image);
        }
    }
    return result;
}

// Parse val +2,-3,/4 
long numeric_constant_eval(long val,Array *args) {

    if (args) {
        //int i;
        //for(i = 0 ; i < args->size ; i++ ) {
            char *p=args->array[0];
            HTML_LOG(0,"start parsing [%s]",p);
            int error=0;

            char op='+';
            while (!error && *p && op) {

                long num2;
                char *numstr;
                char *nextp;
                //get the operator
                HTML_LOG(0,"parsing [%s]",p);

               
#if 0
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
                    
                    if (isdigit(*p)) {

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

                HTML_LOG(0,"val[%ld] op[%c] num [%ld]",val,op,num2);

                // do the calculation
                switch(op) {
                    case '+': val += num2; break;
                    case '-': val -= num2; break;
                    case '/': val /= num2; break;
                    case '*': val *= num2; break;
                    case '%': val %= num2; break;

                    default:
                        html_error("unexpected operator [%d]",*p);
                        error=1;
                        break;
                }
                if (*p == '\0') break;
                op=*p++;
            }
        //}
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
                char *replace=get_variable(v+1);

                char *tmp2;
                ovs_asprintf(&tmp2,"%s%s%s",NVL(newp),p,NVL(replace));
                if (free_result) {
                    FREE(replace);
                }
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

char *numeric_constant_macro(long val,Array *args) {
    char *result = NULL;
    long out = numeric_constant_eval(val,args);
    ovs_asprintf(&result,"%ld",out);
    return result;
}


char *macro_fn_if(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result)
{
    long l = numeric_constant_eval(0,args);
    if (l) {
        HTML_LOG(0,"val=%ld [%d] [%s]",l,args->size,args->array[1]);
        if (args->size >= 2) {
            return STRDUP(args->array[1]);
        }
    } else {
        HTML_LOG(0,"val=%ld [%d] [%s]",l,args->size,args->array[2]);
        if (args->size >= 3) {
            return STRDUP(args->array[2]);
        }
    }
    return NULL;
}
char *macro_fn_number(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result)
{
    return numeric_constant_macro(0,args);
}
char *macro_fn_font_size(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result)
{
    return numeric_constant_macro(g_dimension->font_size,args);
}
char *macro_fn_title_size(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return numeric_constant_macro(g_dimension->title_size,args);
}
char *macro_fn_scanlines(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    return numeric_constant_macro(g_dimension->scanlines,args);
}

// Write a html input table for a configuration file. The help file(arg2) decides which options to show.
char *macro_fn_edit_config(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {

    char *result = NULL;
    if (args && args->size == 2) {
        char *file=args->array[0];
        char *help_suffix=args->array[1];
        char *cmd;

        //Note this outputs directly to stdout so always returns null
        ovs_asprintf(&cmd,"cd \"%s\" && ./options.sh TABLE2 \"help/%s.%s\" \"conf/.%s.defaults\" \"conf/%s\" HIDE_VAR_PREFIX=1",
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

char *macro_fn_play_tvid(char *template_name,char *call,Array *args,int num_rows,DbRowId **sorted_rows,int *free_result) {
    char *text="";
    if (args && args->size > 0)  {
        text = args->array[0];
    }
    return get_play_tvid(text);
}

void macro_init() {

    if (macros == NULL) {
        //HTML_LOG(1,"begin macro init");
        macros = string_string_hashtable(64);

        hashtable_insert(macros,"PLOT",macro_fn_plot);
        hashtable_insert(macros,"POSTER",macro_fn_poster);
        hashtable_insert(macros,"FANART_URL",macro_fn_fanart_url);
        hashtable_insert(macros,"CERTIFICATE_IMAGE",macro_fn_cert_img);
        hashtable_insert(macros,"MOVIE_LISTING",macro_fn_movie_listing);
        hashtable_insert(macros,"TV_LISTING",macro_fn_tv_listing);
        hashtable_insert(macros,"EXTERNAL_URL",macro_fn_external_url);
        hashtable_insert(macros,"CONFIG_LINK",macro_fn_admin_config_link);
        hashtable_insert(macros,"TITLE",macro_fn_title);
        hashtable_insert(macros,"GENRE",macro_fn_genre);
        hashtable_insert(macros,"SEASON",macro_fn_season);
        hashtable_insert(macros,"YEAR",macro_fn_year);
        hashtable_insert(macros,"RATING",macro_fn_rating);
        hashtable_insert(macros,"RATING_STARS",macro_fn_rating_stars);
        hashtable_insert(macros,"SOURCE",macro_fn_source);
        hashtable_insert(macros,"GRID",macro_fn_grid);
        hashtable_insert(macros,"HEADER",macro_fn_header);
        hashtable_insert(macros,"FORM_START",macro_fn_form_start);
        hashtable_insert(macros,"MEDIA_TYPE",macro_fn_media_type);
        hashtable_insert(macros,"VERSION",macro_fn_version);
        hashtable_insert(macros,"HOSTNAME",macro_fn_hostname);
        hashtable_insert(macros,"MEDIA_TOGGLE",macro_fn_media_toggle);
        hashtable_insert(macros,"MEDIA_SELECT",macro_fn_media_select);
        hashtable_insert(macros,"SORT_SELECT",macro_fn_sort_select);
        hashtable_insert(macros,"WATCHED_TOGGLE",macro_fn_watched_toggle);
        hashtable_insert(macros,"WATCHED_SELECT",macro_fn_watched_select);
        hashtable_insert(macros,"SORT_TYPE_TOGGLE",macro_fn_sort_type_toggle);
        hashtable_insert(macros,"FILTER_BAR",macro_fn_filter_bar);
        hashtable_insert(macros,"STATUS",macro_fn_status);
        hashtable_insert(macros,"SETUP_BUTTON",macro_fn_setup_button);
        hashtable_insert(macros,"HELP_BUTTON",macro_fn_help_button);

        hashtable_insert(macros,"LINK",macro_fn_link);
        hashtable_insert(macros,"ICON",macro_fn_icon);
        hashtable_insert(macros,"ICON_LINK",macro_fn_icon_link);
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
        hashtable_insert(macros,"NUMBER",macro_fn_number);
        hashtable_insert(macros,"IF",macro_fn_if);
        hashtable_insert(macros,"FONT_SIZE",macro_fn_font_size);
        hashtable_insert(macros,"TITLE_SIZE",macro_fn_title_size);
        hashtable_insert(macros,"SCANLINES",macro_fn_scanlines);
        hashtable_insert(macros,"EDIT_CONFIG",macro_fn_edit_config);
        hashtable_insert(macros,"PLAY_TVID",macro_fn_play_tvid);
        hashtable_insert(macros,"TVIDS",macro_fn_tvids);
        hashtable_insert(macros,"TV_MODE",macro_fn_tv_mode);
        hashtable_insert(macros,"SYS_DISK_USED",macro_fn_sys_disk_used);
        hashtable_insert(macros,"SYS_UPTIME",macro_fn_sys_uptime);
        hashtable_insert(macros,"SYS_LOAD_AVG",macro_fn_sys_load_avg);
        hashtable_insert(macros,"PAYPAL",macro_fn_paypal);
        hashtable_insert(macros,"GENRE_SELECT",macro_fn_genre_select);
        hashtable_insert(macros,"TITLE_SELECT",macro_fn_title_select);
        hashtable_insert(macros,"TITLE2_SELECT",macro_fn_title2_select);
        hashtable_insert(macros,"OTHER_MEDIA_TOTAL",macro_fn_other_media_total);
        hashtable_insert(macros,"MOVIE_TOTAL",macro_fn_movie_total);
        hashtable_insert(macros,"EPISODE_TOTAL",macro_fn_episode_total);
        hashtable_insert(macros,"CHECKBOX",macro_fn_checkbox);
        hashtable_insert(macros,"MOUNT_STATUS",macro_fn_mount_status);
        hashtable_insert(macros,"IMAGE",macro_fn_image_url);
        //HTML_LOG(1,"end macro init");
    }
}

// ?xx = html query variable
// ovs_xxx = oversight config
// catalog_xxx = catalog config
// unpak_xxx = unpak config
//

char *get_variable(char *vname)
{

    char *result=NULL;

    if (*vname == MACRO_QUERY_PREFIX ) {

        // query variable
        result=query_val(vname+1);

    } else if (*vname == MACRO_DBROW_PREFIX ) {

        HTML_LOG(0,"DBROW LOOKUP [%s]",vname+1);
        char *fieldid = dbf_macro_to_fieldid(vname+1);
        if (fieldid) {
            HTML_LOG(0,"DBROW LOOKUP [%s]",fieldid);
            result=db_get_field(fieldid);
        }

    } else if (util_starts_with(vname,"ovs_") ) {

        result = oversight_val(vname);

    } else if (util_starts_with(vname,"catalog_")) {

        result = catalog_val(vname);

    } else if (util_starts_with(vname,"unpak_")) {

        result = unpak_val(vname);

    }

    return result;
}

char *macro_call(char *template_name,char *call,int num_rows,DbRowId **sorted_rows,int *free_result) {


    if (macros == NULL) macro_init();

    char *result = NULL;
    char *(*fn)(char *template_name,char *name,Array *args,int num_rows,DbRowId **,int *) = NULL;
    Array *args=NULL;

    if (*call == MACRO_VARIABLE_PREFIX) {

        free_result=0;

        result=get_variable(call+1);

        if (result == NULL) {

            printf("?%s?",call);

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
                replace_variables(args);
            }
        }
                

        if (fn) {
            //HTML_LOG(1,"begin macro [%s]",call);
            *free_result=1;
            result =  (*fn)(template_name,call,args,num_rows,sorted_rows,free_result);
            //HTML_LOG(1,"end macro [%s]",call);
        } else {
            printf("?%s?",call);
        }
        array_free(args);
    }
    return result;
}

