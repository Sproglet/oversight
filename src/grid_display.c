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
#include "template.h"

//#include "oversight.h"
//#include "hashtable.h"
//#include "hashtable_loop.h"
//#include "macro.h"
//#include "mount.h"
//#include "exp.h"
//#include "filter.h"
//#include "abet.h"

#define JAVASCRIPT_MENU_FUNCTION_PREFIX "t_"

char *get_tv_drilldown_link(ViewMode *view,char *name,int season,char *attr,char *title,char *font_class,char *cell_no_txt);
char *get_tvboxset_drilldown_link(ViewMode *view,char *name,char *attr,char *title,char *font_class,char *cell_no_txt);
char *get_movie_drilldown_link(ViewMode *view,char *idlist,char *attr,char *title,char *font_class,char *cell_no_txt);

void get_watched_counts(DbItem *item,int *watchedp,int *unwatchedp) 
{
    int watched=0;
    int unwatched=0;
    for(  ; item ; item=item->linked) {
        if (item->watched ) {
            watched++;
        } else {
            unwatched++;
        }
    }
    if (watchedp) *watchedp = watched;
    if (unwatchedp) *unwatchedp = unwatched;
}
    
int unwatched_count(DbItem *item)
{
    int i=0;
    get_watched_counts(item,NULL,&i);
    return i;
}

int watched_count(DbItem *item)
{
    int i=0;
    get_watched_counts(item,&i,NULL);
    return i;
}

char *get_poster_mode_item(DbItem *row_id,char **font_class,char **grid_class,ViewMode *newview)
{

    char *title = NULL;
    HTML_LOG(2,"dbg: tv or movie : set details as jpg");
    ViewStatus status = get_view_status(row_id);



    // *font_class and *grid_class are returned to the caller to set the <a><font> class and the <td>
    switch(status) {
        case NORMAL:  *grid_class = "class=poster"; break;
        case FRESH:   *grid_class = "class=poster_fresh"; break;
        case WATCHED: *grid_class = "class=poster_watched"; break;
        default:
             assert(0);
    }
    *font_class = *grid_class;


#if 0
    char *attr;
    // The class is reused here to set the image tag
    // They just happen to have the same name - maybe there is a more css friendly way to do this!
    ovs_asprintf(&attr," width=%d height=%d %s ",
        g_dimension->current_grid->img_width,
        g_dimension->current_grid->img_height,
        *font_class);

    title = get_poster_image_tag(row_id,attr,THUMB_IMAGE);
    FREE(attr);
#else
    title = get_poster_image_tag(row_id,*font_class,THUMB_IMAGE,newview);
#endif

TRACE;
    return title;
}

char *get_poster_mode_item_unknown(DbItem *row_id,char **font_class,char **grid_class)
{
    HTML_LOG(2,"dbg: unclassified : set details as title");
    // Unclassified

    char *title;
    title = row_id->title;
    if (title != NULL) {
        title = STRDUP(title);
    } else {
        title = util_basename(row_id->file);
    }

    if (strlen(title) > 20) {
        strcpy(title+18,"..");
    }
    if (is_watched(row_id)) {
        *grid_class = "class=poster_watched_unknown";
    } else if (is_fresh(row_id)) {
        *grid_class = "class=poster_fresh_unknown";
    } else {
        *grid_class = "class=poster_unknown";
    }
    *font_class = watched_style_small(row_id);
    return title;
}

char *build_ext_list(DbItem *row_id)
{

    HTML_LOG(3,"ext=%s",row_id->ext);
    char *ext_icons = icon_link(row_id->ext);
    HTML_LOG(3,"ext_icons=%s",ext_icons);

    DbItem *ri;
    for( ri = row_id->linked ; ri ; ri=ri->linked ) {
        if (ri->ext && (ext_icons==NULL || strstr(ext_icons,ri->ext) == NULL)) {
            char *new_ext;
            char *linked_icon = icon_link(ri->ext);
            if (linked_icon) {
                ovs_asprintf(&new_ext,"%s%s",
                        (ext_icons?ext_icons:""),
                        (linked_icon?linked_icon:""));
                FREE(linked_icon);
                FREE(ext_icons);
                ext_icons = new_ext;
            }
        }
    }
    return ext_icons;
}

int group_count(DbItem *item) {
    int i=0;
    for(  ; item ; item=item->linked) {
        i++;
    }
    return i;
}

#define MAX_TITLE_LEN 50
char *trim_title(char *title)
{
    char *out = STRDUP(title);
    if (strlen(out) > MAX_TITLE_LEN) {
        strcpy(out+MAX_TITLE_LEN-3,"..");
    }
    return out;
}
//
// Count number of unique seasons in the list.
int season_count(DbItem *item)
{

#define MAX_SEASON 200
#define WORDBITS 16
#define WORDS ((MAX_SEASON/WORDBITS)+1)

    if (item->num_seasons == 0) {
        // First push seasons into a set (bits)
        unsigned int i=0;
        unsigned int j=0;
        unsigned long bitmask[WORDS+1];
        memset(bitmask,0,WORDS * sizeof(long));

        DbItem *item2;
        for( item2 = item  ; item2 ; item2=item2->linked) {
            if (item2->category == 'T') {
                i=item2->season / WORDBITS;
                j=item2->season % WORDBITS;
                bitmask[i] |= (1 << (j-1) ); // allow for season 0 - prequels - pilots.
            }
        }


        // Now count total bits set.
        int total=0;
        for(i=0 ; i < WORDS ; i++ ) {
            for(j=1<<(WORDBITS-1) ; j ; j = j >> 1 ) {
               if (bitmask[i] & j ) total++;
            }
        }
    
        item->num_seasons = total;
    }
    return item->num_seasons;
}

char *get_text_mode_item(DbItem *row_id,char **font_class,char **grid_class,ViewMode *newview)
{

    // TEXT MODE
    HTML_LOG(2,"dbg: get text mode details ");

    *font_class = watched_style(row_id);
    *grid_class = file_style(row_id);

    char *title = trim_title(row_id->title);
   
    char *tmp;
    if (newview->view_class == VIEW_CLASS_BOXSET) {
        if (strcmp(newview->name,"tvboxset") == 0) {

            ovs_asprintf(&tmp,"%s [%d Seasons]",title,season_count(row_id));
            FREE(title);
            title = tmp;

        } else {

            ovs_asprintf(&tmp,"[%s Boxset]",title);
            FREE(title);
            title = tmp;
        }

    } else {

       char *cert = row_id->certificate;
       if ((tmp=strchr(cert,':')) != NULL) {
           if (tmp[1] != '\0') {
               ovs_asprintf(&cert,"(%s)",tmp+1);
           } else {
               cert = NULL;
           }
       }

        if (row_id->category == 'T' && row_id->season >= 1) {
            //Add season
            char *tmp;
            ovs_asprintf(&tmp,"%s S%d",title,row_id->season);
            FREE(title);
            title=tmp;
        }

        HTML_LOG(2,"dbg: add certificate");
        //Add certificate and extension
        char *tmp;
        char *ext_icons=build_ext_list(row_id);
        HTML_LOG(2,"dbg: add extension [%s]",ext_icons);

        ovs_asprintf(&tmp,"%s %s %s",
                title,
                (cert?cert:""),
                (ext_icons?ext_icons:""));

        FREE(title);
        title=tmp;
        if (cert != row_id->certificate) FREE(cert);
        FREE(ext_icons);


        if (row_id->category == 'T') {
            HTML_LOG(2,"dbg: add episode count");
            //Add episode count

            int unwatched = unwatched_count(row_id);

            if (unwatched) {
                char *tmp;
                int total = group_count(row_id);
                ovs_asprintf(&tmp,"%s&nbsp;<font color=#AAFFFF size=-1>x%d of %d</font>",title,unwatched,total);
                FREE(title);
                title=tmp;
            }
        }

        long crossview=0;
        config_check_long(g_oversight_config,"ovs_crossview",&crossview);
        if (crossview == 1 && is_on_remote_oversight(row_id)) {
            HTML_LOG(2,"dbg: add network icon");
           char *tmp =add_network_icon(row_id,title);
           FREE(title);
           title = tmp;
        }
    }
    HTML_LOG(0,"title[%s] newview[%s] final title[%s]",row_id->title,newview,title);

    return title;
}

char *add_scroll_attributes(int left_scroll,int right_scroll,int selected_cell,char *attrin)
{
    char *attr;
    ovs_asprintf(&attr,
            " %s%s%s %s ",
            (selected_cell? "name=selectedCell ":""),
            (left_scroll? "onkeyleftset=pgup1 ":""),
            (right_scroll? "onkeyrightset=pgdn1 ":""),

            (attrin != NULL?attrin:""));

    return attr;
}




char *get_item(int cell_no,DbItem *row_id,int grid_toggle,char *width_attr,char *height_attr,
        int left_scroll,int right_scroll,int selected_cell,int select_mode)
{

    //TODO:Highlight matched bit
    HTML_LOG(2,"Item %d = %s %s %s",cell_no,row_id->db->source,row_id->title,row_id->file);

    char cell_no_txt[9];
    sprintf(cell_no_txt,"%d",cell_no);

    char *title=NULL;
    char *font_class="";
    char *grid_class="";

    char *cell_background_image=NULL;
    int displaying_text;

    //Gaya has a navigation bug in which highlighting sometimes misbehaves on links 
    //with multi-lines of text. This was not a problem until the javascript title display
    //was introduced. When the bug triggers all elements become unfocussed causing
    //navigation position to be lost. 
    //To circumvent bug - only the first word of the link is highlighted.
    char *first_space=NULL;
    int link_first_word_only = g_dimension->local_browser && g_dimension->title_bar;

    get_drilldown_view(row_id);
    ViewMode *newview = row_id->drilldown_view;

    if (IN_POSTER_MODE) {

        displaying_text=0;

        if ((title = get_poster_mode_item(row_id,&font_class,&grid_class,newview)) != NULL) {

            if (*title != '<' && !util_starts_with(title,"<img")) {
                displaying_text=1;
                first_space = strchr(title,' ');
            }

        } else {
            title = get_poster_mode_item_unknown(row_id,&font_class,&grid_class);
            displaying_text=1;
        }
        if (displaying_text) {

            if (link_first_word_only) {
                //
                //Reduce amount of text in link - to fix gaya navigation
                first_space = strchr(title,' ');
            }

            // Display alternate image - this has to be a cell background image
            // so ewe can overlay text on it. as NTM does not have relative positioning
            // the alternative is to render the page and then use javascript to inspect
            // the cell coordinates and then overlay the text. yuk
            switch (row_id->category) {
                case 'T':
                    cell_background_image=icon_source("tv"); break;
                case 'M':
                case 'F':
                    cell_background_image=icon_source("video"); break;
                default:
                    cell_background_image=icon_source("video"); break;
            }
        }

    } else {
        displaying_text=1;

        title = get_text_mode_item(row_id,&font_class,&grid_class,newview);
    }
    if (first_space) {
        // Truncate even more if the first space does not occur early enough in the title.
        if (first_space - title > 11 ) {
            first_space = title+11;
        }
        *first_space='\0';
    }
    char *cell_text=NULL;
    char *focus_ev = NULL;
    char *mouse_ev = NULL;

    if (g_dimension->title_bar && !select_mode) {

        focus_ev = href_focus_event_fn(JAVASCRIPT_MENU_FUNCTION_PREFIX,cell_no+1);
        mouse_ev = td_mouse_event_fn(JAVASCRIPT_MENU_FUNCTION_PREFIX,cell_no+1);
    }



    if (select_mode) {

        cell_text = select_checkbox(row_id,NVL(title));

    } else {

        char *title_change_attr;
        ovs_asprintf(&title_change_attr," %s %s" ,(grid_class?grid_class:""), NVL(focus_ev));


        char *attr = add_scroll_attributes(left_scroll,right_scroll,selected_cell,title_change_attr);
        FREE(title_change_attr);
        HTML_LOG(1,"dbg: scroll attributes [%s]",attr);


        switch(row_id->drilldown_view->row_select) {
            case ROW_BY_SEASON:
                cell_text = get_tv_drilldown_link(newview,row_id->title,row_id->season,attr,title,font_class,cell_no_txt);
                break;
            case ROW_BY_TITLE:
                cell_text = get_tvboxset_drilldown_link(newview,row_id->title,attr,title,font_class,cell_no_txt);
                break;
            default:
                cell_text = get_movie_drilldown_link(newview,build_id_list(row_id),attr,title,font_class,cell_no_txt);
        }
        FREE(attr);
    }

    // Add a horizontal image to stop cell shrinkage.
    char *add_spacer = "";
    if (IN_POSTER_MODE && displaying_text) {
        // NMT browser seems to collapse width of table cells that do no contain poster images.
        // It seems to ignore most common CSS to fix the width.
        // This problem occurs if an entire column has no posters. (set rows=1 to make this happen more often).
        // There may be a nice way to fix with css but in the mean time I'll use an image.
        //
        // I does work if the image doesnt exists but this slows the NMT browser down.
        char *img = get_theme_image_tag("1000x1",width_attr);
        ovs_asprintf(&add_spacer,"<br>%s",img);
        FREE(img);
    }

    char *result;

    char *background_prefix = "";
    char *background_suffix = "";
    if (cell_background_image) {
        background_prefix = "background=\"";
        background_suffix = "\"";
    }

    ovs_asprintf(&result,"\t<td %s%s%s class=grid%d %s >%s%s%s%s</td>\n",
            background_prefix,NVL(cell_background_image),background_suffix,
            //NVL(width_attr),
            //NVL(height_attr),
            grid_toggle,
            NVL(mouse_ev),
            
            cell_text,
            (first_space?" ":""),
            (first_space?first_space+1:""),
            add_spacer);

    if (!EMPTY_STR(add_spacer)) FREE(add_spacer);
    FREE(mouse_ev);
    FREE(focus_ev);
    if (!EMPTY_STR(cell_background_image)) FREE(cell_background_image);

    FREE(cell_text);
    FREE(title); // first_space points inside of title
    return result;
}

char *menu_js_fn(long fn_id,...)
{

    char *result = NULL;

    va_list ap;
    va_start(ap,fn_id);
    result = js_function(JAVASCRIPT_MENU_FUNCTION_PREFIX ,"ovs_menu",fn_id,ap);
    va_end(ap);
    return result;
}



char * write_titlechanger(int offset,int rows, int cols, int numids, DbItem **row_ids)
{
    int i,r,c;
    Array *script = array_new(free);


    
    static int first_time=1;
    if (first_time) {
        first_time = 0;
        array_add(script,STRDUP("function t_0() { ovs_menu_clear(); }\n"));
    }

    for ( r = 0 ; r < rows ; r++ ) {
        for ( c = 0 ; c < cols ; c++ ) {
            i = c * rows + r ;
            if ( i < numids ) {

                DbItem *item = row_ids[i];

                int watched,unwatched;
                get_watched_counts(item,&watched,&unwatched);

                char *js_fn_call=NULL;

                int season = -1;
                ViewMode *view_mode = get_drilldown_view(item);
                if (view_mode == VIEW_TV) {
                    season = item->season;
                }

                if (item->category == 'T' ) {
                    // Write the call to the show function and also tract the idlist;
                    if (view_mode == VIEW_TVBOXSET) {
                        js_fn_call = menu_js_fn(i+1+offset,
                                JS_ARG_STRING,"title",item->title,
                                JS_ARG_STRING,"orig_title",item->orig_title,
                                JS_ARG_STRING,"cert",item->certificate,
                                JS_ARG_STRING,"idlist",build_id_list(item),
                                JS_ARG_INT,"year",item->year,
                                JS_ARG_STRING,"view",view_mode->name,
                                JS_ARG_INT,"unwatched",unwatched,
                                JS_ARG_INT,"watched",watched,
                                JS_ARG_INT,"num_seasons",season_count(item),
                                JS_ARG_INT,"count",item->link_count+1,
                                JS_ARG_INT,"mb",dbrow_total_size(item),
                                JS_ARG_END);
                    } else {
                        js_fn_call = menu_js_fn(i+1+offset,
                                JS_ARG_STRING,"title",item->title,
                                JS_ARG_STRING,"orig_title",item->orig_title,
                                JS_ARG_STRING,"cert",item->certificate,
                                JS_ARG_STRING,"idlist",build_id_list(item),
                                JS_ARG_INT,"year",item->year,
                                JS_ARG_STRING,"view",view_mode->name,
                                JS_ARG_INT,"unwatched",unwatched,
                                JS_ARG_INT,"watched",watched,
                                JS_ARG_INT,"season",season,
                                JS_ARG_INT,"count",item->link_count+1,
                                JS_ARG_STRING,"videosource",item->videosource,
                                JS_ARG_STRING,"video",item->video,
                                JS_ARG_STRING,"audio",item->audio,
                                JS_ARG_INT,"mb",dbrow_total_size(item),
                                JS_ARG_END);
                    }

                } else {
                    int freeshare=0;
                    char *share = share_name(item,&freeshare);
                    // char *cert_country = NULL;
                    char *cert_rating = strchr(NVL(item->certificate),':');

                    if (cert_rating) {
                        // cert_country = COPY_STRING(cert_rating - item->certificate,item->certificate);
                        cert_rating++;
                    }

                    // Dont show watched/unwatched for movies
                    js_fn_call = menu_js_fn(i+1+offset,
                            JS_ARG_STRING,"title",item->title,
                            JS_ARG_STRING,"orig_title",item->orig_title,
                            JS_ARG_STRING,"cert",cert_rating,
                            JS_ARG_STRING,"idlist",build_id_list(item),
                            JS_ARG_INT,"runtime",item->runtime,
                            JS_ARG_INT,"year",item->year,
                            JS_ARG_STRING,"view",view_mode->name,
                            JS_ARG_INT,"unwatched",unwatched,
                            JS_ARG_INT,"watched",watched,
                            JS_ARG_STRING,"source",item->db->source,
                            JS_ARG_STRING,"share",share,
                            JS_ARG_INT,"count",item->link_count+1,
                            JS_ARG_STRING,"videosource",item->videosource,
                            JS_ARG_STRING,"video",item->video,
                            JS_ARG_STRING,"audio",item->audio,
                            JS_ARG_INT,"mb",dbrow_total_size(item),
                            JS_ARG_END);
                    if (freeshare) FREE(share);
                    // if (cert_country) FREE(cert_country);
                }
                if (js_fn_call) {
                    array_add(script,js_fn_call);
                }
            }
        }
    }
    char *result = arraystr(script);
    array_free(script);
    HTML_LOG(0,"write_titlechanger end");
    return result;
}

char *get_empty(char *width_attr,int grid_toggle,char *height_attr,int left_scroll,int right_scroll,int selected_cell)
{

    char *attr;

    attr=add_scroll_attributes(left_scroll,right_scroll,selected_cell,NULL);

    char *result;

    ovs_asprintf(&result,"\t\t<td %s %s class=empty%d><a href=\"\" %s></a>\n",
            width_attr,height_attr,grid_toggle,attr);

    FREE(attr);
    return result;
}

// Generate the HTML for the grid. 
// Note that the row_ids have already been pruned to only contain the items
// for the current page.
char *render_grid(long page,GridSegment *gs, int numids, DbItem **row_ids,int page_before,int page_after)
{

    int rows = gs->dimensions.rows;

    int cols = gs->dimensions.cols;

    // Points past last item
    int end_item = rows * cols;
    if (end_item > numids ) {
        end_item = numids;
    }
    
    int centre_row = rows/2;
    int centre_col = cols/2;
    int r,c;

    int cell_margin=2;

    HTML_LOG(0,"render page %ld rows %d cols %d",page,rows,cols);

#if 0
    // Diagnostic code. Enable to see all rows dumped.
    HTML_LOG(0,"input size = %d",numids);
    for(r=0 ; r<numids ; r++) {
        HTML_LOG(0,"get_grid row %d %s %s %s",r,row_ids[r]->db->source,row_ids[r]->title,row_ids[r]->file);
        DbItem *l =row_ids[r]->linked;
        while (l) {
            HTML_LOG(0,"get_grid linked %d %s %s %s",r,l->db->source,l->title,l->file);
           l = l->linked;
        }
    }
#endif

    char *result=NULL;
    int i;
    char *width_attr;
    char *height_attr;
    char *tmp;
    int select_mode=!EMPTY_STR(query_select_val());

    char *grid_css;

    if (numids < rows * cols ) {
        //re-arrange layout to have as many columns as possible.
        rows = (numids + (cols-1)) / cols;
    }

    if (g_dimension->poster_mode) {
        ovs_asprintf(&width_attr," width=%dpx ", gs->dimensions.img_width+cell_margin);

        ovs_asprintf(&height_attr," height=%dpx ", gs->dimensions.img_height+cell_margin);
    } else {
        ovs_asprintf(&width_attr," width=%d%% ",(int)(100/cols));
        height_attr=STRDUP("");
    }

    ovs_asprintf(&grid_css,"<style type=\"text/css\">\n"
            "div.grid%d table tr td a font img {\n"
            "\twidth:%dpx;\n"
            "\theight:%dpx;\n}\n"
            "</style>\n",
            gs->offset,
            gs->dimensions.img_width,
            gs->dimensions.img_height);

    char *title_change_script = write_titlechanger(gs->offset,rows,cols,numids,row_ids);

TRACE;
    Array *rowArray = array_new(free);

    int selected_cell = -1;
    if (*get_selected_item()) {
        selected_cell = atol(get_selected_item());
    } else {
        selected_cell = centre_col * rows + centre_row;
    }
    HTML_LOG(0,"rows = %d",rows);
    

    // Now build the table and return the text.
    for ( r = 0 ; r < rows ; r++ ) {

        HTML_LOG(1,"grid row %d",r);

        ovs_asprintf(&tmp,"<tr class=\"grid_row%d\" >\n",(r&1));

        array_add(rowArray,tmp);

        for ( c = 0 ; c < cols ; c++ ) {

            switch(gs->grid_direction) {
                case GRID_ORDER_VERTICAL:
                    i = c * rows + r ; break;
                case GRID_ORDER_HORIZONTAL:
                case GRID_ORDER_DEFAULT:
                    i = r * cols + c ; break;

                default:
                    assert("bad grid order"==NULL);
                    i = r * cols + c ; break;
            }

            HTML_LOG(1,"grid col %d",c);

            int left_scroll = (page_before && c == 0);
            int right_scroll = (page_after && c == cols-1 );
            int is_selected = (i == selected_cell);

            char *item_text=NULL;
            if ( i < numids ) {
                item_text = get_item(gs->offset+i,row_ids[i],(c+r)&1,width_attr,height_attr,left_scroll,right_scroll,is_selected,select_mode);
            } else {
                // only draw empty cells if there are two or more rows
                if (rows > 1) {
                    item_text = get_empty(width_attr,(c+r)&1,height_attr,left_scroll,right_scroll,is_selected);
                } else {
                    item_text = NULL;
                }

            }

            if (item_text) array_add(rowArray,item_text);
            HTML_LOG(1,"grid end col %d",c);
        }

        array_add(rowArray,STRDUP("</tr>\n"));
        HTML_LOG(1,"grid end row %d",r);

    }

    char *w;
    if (!g_dimension->poster_mode) {
        w="width=100%";
    } else {
        w="";
    }

    result = arraystr(rowArray);
    array_free(rowArray);

    ovs_asprintf(&tmp,
            "<script type=\"text/javascript\"><!--\n%s\n--></script>\n%s\n"
            "<center><div class=grid%d><table class=overview_poster %s>\n%s\n</table></div></center>\n",
            title_change_script,
            grid_css,
            gs->offset,
            (g_dimension->poster_mode?"":" width=100%"),
            (result?result:"<tr><td>&nbsp;</td><tr>")
    );

    FREE(grid_css);

    FREE(title_change_script);

    FREE(result);
    result=tmp;

    FREE(width_attr);
    HTML_LOG(0,"render_grid length = %d",strlen(NVL(result)));

    return result;
}




char *get_grid(long page,GridSegment *gs,DbSortedRows *sorted_rows) 
{
    int numids = sorted_rows->num_rows;
    DbItem **row_ids = sorted_rows->rows;
    // first loop through the selected rowids that we expect to draw.
    // If there are any that need pruning - remove them from the database and get another one.
    // This will possibly cause a temporary inconsistency in page numbering but
    // as we have just updated the database it will be correct on the next page draw.
    //
    // Note the db load routing should already filter out items that cant be mounted,
    // otherwise this can cause timeouts.
    if (gs->parent->page_size == DEFAULT_PAGE_SIZE) {
        gs->parent->page_size = gs->dimensions.rows * gs->dimensions.cols;
    }

    int start = page * gs->parent->page_size; 

    int total=0;
    // Create space for pruned rows
TRACE1;
    DbItem **prunedRows = filter_page_items(start,numids,row_ids,gs->parent->page_size,&total);
TRACE1;

    
    DbItem **segmentRows = prunedRows + gs->offset;

    int segment_total = total - gs->offset;

    if (segment_total < 0 ) {

        segment_total = 0;

    } else if (segment_total > gs->dimensions.rows * gs->dimensions.cols ) {

        segment_total = gs->dimensions.rows * gs->dimensions.cols ;
    }


    int page_before = (gs->offset == 0) && (page > 0);
    int page_after = gs->offset + segment_total >= total;


TRACE1;
    char  *ret =  render_grid(page,gs,segment_total,segmentRows,page_before,page_after);
TRACE1;
    FREE(prunedRows);
    return ret;
}

char *get_tv_drilldown_link(ViewMode *view,char *name,int season,char *attr,char *title,char *font_class,char *cell_no_txt)
{
    char *result = NULL;
    static char *link_template = NULL;
    if (link_template == NULL ) {

        // Note the Selected parameter is added with a preceding @. This ensures that it is present in the 
        // return link. 
        link_template = get_drilldown_link_with_font(
            QUERY_PARAM_VIEW "=@VIEW@&p=&"QUERY_PARAM_TITLE_FILTER"="QPARAM_FILTER_EQUALS QPARAM_FILTER_STRING "@NAME@&"QUERY_PARAM_SEASON"=@SEASON@&@CELLNO_PARAM@=@CELLNO@",
            "@ATTR@","@TITLE@","@FONT_CLASS@");
    }
    char season_txt[9];
    sprintf(season_txt,"%d",season);

    int free_name2;
    char *name2 = url_encode_static(name,&free_name2);

    result = replace_all_str(link_template,
            "@VIEW@",view->name,
            "@NAME@",name2,
            "@SEASON@",season_txt,
            "@ATTR@",attr,
            "@TITLE@",title,
            "@CELLNO_PARAM@",get_drilldown_name_static(QUERY_PARAM_SELECTED,1),
            "@CELLNO@",cell_no_txt,
            "@FONT_CLASS@",font_class,
            NULL);

    if (free_name2) FREE(name2);
    return result;
}

char *get_tvboxset_drilldown_link(ViewMode *view,char *name,char *attr,char *title,char *font_class,char *cell_no_txt)
{
    char *result = NULL;
    static char *link_template = NULL;
    if (link_template == NULL ) {

        // Note the Selected parameter is added with a preceding @. This ensures that it is present in the 
        // return link. 
        link_template = get_drilldown_link_with_font(
                QUERY_PARAM_VIEW "=@VIEW@&p=&"QUERY_PARAM_TITLE_FILTER"="QPARAM_FILTER_EQUALS QPARAM_FILTER_STRING "@NAME@&@CELLNO_PARAM@=@CELLNO@","@ATTR@","@TITLE@","@FONT_CLASS@");
    }

    int free_name2;
    char *name2 = url_encode_static(name,&free_name2);

    result = replace_all_str(link_template,
            "@VIEW@",view->name,
            "@NAME@",name2,
            "@ATTR@",attr,
            "@TITLE@",title,
            "@FONT_CLASS@",font_class,
            "@CELLNO_PARAM@",get_drilldown_name_static(QUERY_PARAM_SELECTED,1),
            "@CELLNO@",cell_no_txt,
            NULL);

    if (free_name2) FREE(name2);
    return result;
}

char *get_movie_drilldown_link(ViewMode *view,char *idlist,char *attr,char *title,char *font_class,char *cell_no_txt)
{
    char *result = NULL;
    static char *link_template = NULL;
    if (link_template == NULL ) {

        // Note the Selected parameter is added with a preceding @. This ensures that it is present in the 
        // return link. 
        link_template = get_drilldown_link_with_font(
               QUERY_PARAM_VIEW "=@VIEW@&p=&idlist=@IDLIST@&@CELLNO_PARAM@=@CELLNO@","@ATTR@","@TITLE@","@FONT_CLASS@");
    }

    result = replace_all_str(link_template,
            "@VIEW@",view->name,
            "@IDLIST@",idlist,
            "@ATTR@",attr,
            "@TITLE@",title,
            "@FONT_CLASS@",font_class,
            "@CELLNO_PARAM@",get_drilldown_name_static(QUERY_PARAM_SELECTED,1),
            "@CELLNO@",cell_no_txt,
            NULL);

    return result;
}
