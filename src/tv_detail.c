// $Id:$
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <errno.h>
#include <unistd.h>
#include <regex.h>
#include <time.h>
#include <ctype.h>

#include "types.h"
#include "display.h"
#include "gaya_cgi.h"
#include "util.h"
#include "array.h"
#include "db.h"
#include "dbplot.h"
#include "dboverview.h"

//#include "oversight.h"
//#include "hashtable.h"
//#include "hashtable_loop.h"
//#include "macro.h"
//#include "mount.h"
//#include "template.h"
//#include "exp.h"
//#include "filter.h"
//#include "abet.h"

#define JAVASCRIPT_EPINFO_FUNCTION_PREFIX "tvinf_"

char *ep_js_fn(long fn_id,...)
{

    char *result = NULL;

    va_list ap;
    va_start(ap,fn_id);
    result = js_function(JAVASCRIPT_EPINFO_FUNCTION_PREFIX ,"ovs_ep",fn_id,ap);
    va_end(ap);
    return result;
}

char *best_eptitle(DbItem *item,int *free_title)
{

    *free_title=0;
    char *title=item->eptitle;
    if (title == NULL || !*title) {
        title=item->eptitle_imdb;
    }
    if (title == NULL || !*title) {
        title=item->additional_nfo;
    }
    if (title == NULL || !*title) {
        title=util_basename(item->file);
        *free_title=1;
    }
    return title;
}

char *get_date_static(DbItem *item)
{
    static char *old_date_format=NULL;
    static char *recent_date_format=NULL;
    // Date format
    if (recent_date_format == NULL && !config_check_str(g_oversight_config,"ovs_date_format",&recent_date_format)) {
        recent_date_format="%d %b";
    }
    if (old_date_format == NULL && !config_check_str(g_oversight_config,"ovs_old_date_format",&old_date_format)) {
        old_date_format="%d %b %y";
    }

#define DATE_BUF_SIZ 40
    static char date_buf[DATE_BUF_SIZ];


    OVS_TIME date=item->airdate;
    if (date<=0) {
        date=item->airdate_imdb;
    }
    *date_buf='\0';
    if (date > 0) {

        char *date_format=NULL;
        if  (year(epoc2internal_time(time(NULL))) != year(date)) {  
            date_format = old_date_format;
        } else {
            date_format = recent_date_format;
        }

        strftime(date_buf,DATE_BUF_SIZ,date_format,internal_time2tm(date,NULL));
    }
    return date_buf;
}

/**
 * Create a number of javascript functions that each return the 
 * plot for a given row.
 * The funtions are named using the address location of the data  structure.
 * eg plot12234() { return 'He came, he saw , he conquered'; }
 */
char *create_episode_js_fn(int num_rows,DbItem **sorted_rows) {

    char *result = NULL;

    int i;
    char *tmp;
    Array *outa = array_new(free);

TRACE;
    // get titles from plot.db
    get_plot_offsets_and_text(num_rows,sorted_rows,1);

TRACE;

    // Find the first plot and genre
    char *main_plot=NULL;
    char *main_genre=NULL;

    for(i = 0 ; i < num_rows ; i++ ) {
        DbItem *item = sorted_rows[i];
        if (EMPTY_STR(main_plot) && !EMPTY_STR(item->plottext[PLOT_MAIN])) {
            main_plot = item->plottext[PLOT_MAIN];
        }
        if (EMPTY_STR(main_genre) && !EMPTY_STR(item->genre)) {
            main_genre = item->genre;
        }
    }

    if (EMPTY_STR(main_plot)) main_plot = "(no plot info)";
    if (main_genre == NULL) {
        main_genre = STRDUP("no genre");
    } else {
        main_genre = expand_genre(main_genre);
    }

TRACE;

    tmp = ep_js_fn(0,
            JS_ARG_STRING,"plot",NVL(main_plot),
            JS_ARG_STRING,"genre",NVL(main_genre),
            JS_ARG_STRING,"title",NVL(sorted_rows[0]->title),
            JS_ARG_END);
    array_add(outa,tmp);

    FREE(main_genre);

HTML_LOG(0,"num rows = %d",num_rows);
    // Episode Plots
    for(i = 0 ; i < num_rows ; i++ ) {
        DbItem *item = sorted_rows[i];
        int free_title=0;
        char *title = best_eptitle(item,&free_title);

        int freeshare=0;
        char *share = share_name(item,&freeshare);

        char *plot = item->plottext[PLOT_EPISODE];
        if (plot && plot[2] == ':') plot += 3;

        tmp = ep_js_fn(i+1,
                JS_ARG_STRING,"idlist",build_id_list(item),
                JS_ARG_STRING,"episode",NVL(item->episode),
                JS_ARG_STRING,"plot",NVL(plot),
                JS_ARG_STRING,"info",item->file,
                JS_ARG_STRING,"title",title,
                JS_ARG_STRING,"date",get_date_static(item),
                JS_ARG_STRING,"share",share,
                JS_ARG_INT,"watched",item->watched,
                JS_ARG_INT,"locked",is_locked(item),
                JS_ARG_STRING,"source",item->db->source,
                JS_ARG_STRING,"videosource",item->videosource,
                JS_ARG_STRING,"video",item->video,
                JS_ARG_STRING,"audio",item->audio,
                JS_ARG_END);

        array_add(outa,tmp);

        if (free_title) FREE(title);
        if (freeshare) FREE(share);

    }

    result = arraystr(outa);

    array_free(outa);

    ovs_asprintf(&tmp,"<script type=\"text/javascript\"><!--\n%s\n--></script>\n",NVL(result));
    FREE(result);
    result = tmp;

TRACE;

    return result;
}

char *pruned_tv_listing(int num_rows,DbItem **sorted_rows,int rows,int cols)
{
    int r,c;

    char *select=query_select_val();

    char *listing=NULL;

    int width_txt_and_date=100/cols; //text and date
    int width_epno=1; //episode width
    int width_icon=1; //episode width
    width_txt_and_date -= width_epno+width_icon;

TRACE;
    HTML_LOG(0,"pruned_tv_listing");


TRACE;
    char *script = create_episode_js_fn(num_rows,sorted_rows);
TRACE;

    int show_episode_titles = *query_val(QUERY_PARAM_EPISODE_TITLES) == '1';
    int show_episode_dates = *query_val(QUERY_PARAM_EPISODE_DATES) == '1';
    if  (!show_episode_dates && !show_episode_titles ) {
        width_txt_and_date = 1;
    }

    int show_repacks = *oversight_val("ovs_show_repack") != '0';
    

    printf("%s",script);

    HTML_LOG(0,"pruned_tv_listing num_rows=%d r%d x c%d",num_rows,rows,cols);
#if 0
    // Adjust rows to be squarish.
    if (num_rows/cols < rows ) {
        rows = (num_rows+cols-1) / cols;
    }

    HTML_LOG(0,"pruned_tv_listing num_rows=%d r%d x c%d",num_rows,rows,cols);
#endif

#define UNWATCHED_UNSET -1
    int i=0;
    for(r=0 ; r < rows ; r++ ) {
        HTML_LOG(1,"tvlisting row %d",r);
        char *row_text = NULL;
        int first_unwatched = UNWATCHED_UNSET;
        for(c = 0 ; c < cols ; c++ ) {
            HTML_LOG(1,"tvlisting col %d",c);

            //int i = c * rows + r;
            i = r * cols + c;
            if (i < num_rows) {

                int function_id = i+1;
                char *episode_col = NULL;

                DbItem *item = sorted_rows[i];

                if (*select) {
                    episode_col = select_checkbox(
                            item,
                            item->episode);
                } else {
                    char *ep = item->episode;
                    if (ep == NULL || !*ep ) {
                        ep = "play";
                    }

                    char *href_name = ep;
                    if (item->watched == 0 && first_unwatched == UNWATCHED_UNSET) {
                        href_name="[:START_CELL:]";
                        first_unwatched=i;
                    }

                    char *href_attr = href_focus_event_fn(JAVASCRIPT_EPINFO_FUNCTION_PREFIX,function_id);
                    episode_col = vod_link(
                            item,
                            ep,"",
                            item->db->source,
                            item->file,
                            href_name,
                            NVL(href_attr),
                            watched_style(item));
                    FREE(href_attr);
                }

                int free_eptitle=0;
                char *episode_title = "";
                if (show_episode_titles) {
                    episode_title = best_eptitle(item,&free_eptitle);
                }

                char *title_txt=NULL;

                int is_proper = show_repacks && (util_strcasestr(item->file,"proper"));

                int is_repack = show_repacks && (util_strcasestr(item->file,"repack"));

                char *icon_text = icon_link(item->file);

                ovs_asprintf(&title_txt,"%s%s%s",
                        episode_title,
                        (is_proper?"&nbsp;<font class=proper>[pr]</font>":""),
                        (is_repack?"&nbsp;<font class=repack>[rpk]</font>":"")
                        );
                if (free_eptitle) {
                    FREE(episode_title);
                }


                //Date
                char *date_buf=get_date_static(item);


                //network icon
                char *network_icon = add_network_icon(item,"");

                //Put Episode/Title/Date together in new cell.
                char td_class[10];
                sprintf(td_class,"ep%d%d",item->watched,i%2);
                char *tmp;

                char *td_plot_attr = td_mouse_event_fn(JAVASCRIPT_EPINFO_FUNCTION_PREFIX,function_id);

                ovs_asprintf(&tmp,
                        "%s<td class=%s width=%d%% %s align=right>%s</td>" 
                        "<td width=%d%% %s>%s</td>"
                        "<td class=%s width=%d%% %s>"
                        "<font %s>%s%s</font>"
                        "<font class=epdate>%s</font></td>\n",
                        (row_text?row_text:""),
                        td_class,width_epno, td_plot_attr, episode_col,

                        width_icon,NVL(td_plot_attr),NVL(icon_text),

                        td_class, width_txt_and_date, td_plot_attr,

                        watched_style(item), (network_icon?network_icon:""),
                        title_txt,
                        (show_episode_dates && *date_buf?date_buf:"")
                        );
                FREE(icon_text);

                if (!EMPTY_STR(td_plot_attr)) FREE(td_plot_attr);

                FREE(title_txt);
                FREE(episode_col);
                FREE(row_text);
                row_text=tmp;

            } else {
                char *tmp=NULL;
                ovs_asprintf(&tmp,"%s<td width=%d%%></td><td width=%d%%></td><td width=%d%%></td>\n",
                    (row_text?row_text:""),
                    width_epno,
                    width_icon,
                    width_txt_and_date);
                FREE(row_text);
                row_text=tmp;
            }
        }
        // Add the row
        if (row_text) {
            char *tmp;
            ovs_asprintf(&tmp,"%s<tr align=top>%s</tr>\n",(listing?listing:""),row_text);
            FREE(row_text);
            FREE(listing);
            listing=tmp;
        }
        if (i >= num_rows) break;
    }


    char *result=NULL;
    ovs_asprintf(&result,"<table width=100%% class=listing onblur=\"tv_inf0();\" >%s</table>",listing);
    FREE(listing);
    return result;
}

char *tv_listing(DbSortedRows *sorted_rows,int rows,int cols)
{
    int pruned_num_rows;
    DbItem **pruned_rows;


    html_log(-1,"tv_listing");
    pruned_rows = filter_page_items(0,sorted_rows->num_rows,sorted_rows->rows,sorted_rows->num_rows,&pruned_num_rows);
    char *result = pruned_tv_listing(pruned_num_rows,pruned_rows,rows,cols);
    FREE(pruned_rows);

    return result;
}

