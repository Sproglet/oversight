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

#define JS_MOVIE_INFO_FN_PREFIX "set_info"
void add_movie_info_text(Array *js,long fn_id,char *info)
{
    char *text = clean_js_string(info);
    char *tmp;
    ovs_asprintf(&tmp,"\nfunction " JS_MOVIE_INFO_FN_PREFIX "%x() { set_info('%s'); }\n",fn_id,text);
    array_add(js,tmp);
    if (text != info) FREE(text);
}
void add_movie_part_row(Array *output,long fn_id,char *cell)
{
    char *tmp;
    char *focus=td_mouse_event_fn(JS_MOVIE_INFO_FN_PREFIX,fn_id);
    ovs_asprintf(&tmp,"\n<tr><td %s>%s</td></tr>\n",NVL(focus),cell);
    FREE(focus);
    array_add(output,tmp);
}


char *movie_listing(DbItem *rowid)
{
    int show_names;
   
    show_names = *oversight_val("ovs_movie_filename") == '1';


    db_rowid_dump(rowid);

    char *js_title = clean_js_string(rowid->title);

    printf("<script type=\"text/javascript\"><!--\ng_title='%s';\ng_idlist='%s';\n--></script>\n",
            js_title,build_id_list(rowid));

    if (js_title != rowid->title) FREE(js_title);


    char *select = query_select_val();
    char *style = watched_style(rowid);
    if (*select) {
        return select_checkbox(rowid,rowid->file);
    } else {
        Array *js = array_new(free);
        Array *output = array_new(free);

        Array *parts = splitstr(rowid->parts,"/");
        HTML_LOG(1,"parts ptr = %ld",parts);

        char *label;

        if (show_names) {
            label = file_name(rowid->file);
        } else {
            if (parts && parts->size) {
                label = STRDUP("part 1");
            } else {
                label = STRDUP("movie");
            }
        }

        char *mouse=href_focus_event_fn(JS_MOVIE_INFO_FN_PREFIX,0);
        char *href_attr;
        ovs_asprintf(&href_attr,"onkeyleftset=up %s",NVL(mouse));
        add_movie_info_text(js,0,rowid->file);
//      char *vod = vod_link(rowid,label,"",rowid->db->source,rowid->file,"[:START_CELL:]",href_attr,style); // As with tv_detail this is not exporting out properly ab because guya does not like to
        char *vod = vod_link(rowid,label,"",rowid->db->source,rowid->file,"",href_attr,style); //  select a link that goes over two links the selected name is now on the play button.
        add_movie_part_row(output,0,vod);

        FREE(label);
        FREE(mouse);
        FREE(href_attr);

        // Add vod links for all of the parts
        
        if (parts && parts->size) {

            int i;
            for(i = 0 ; i < parts->size ; i++ ) {

                char i_str[10];
                sprintf(i_str,"%d",i);

                char *mouse=href_focus_event_fn(JS_MOVIE_INFO_FN_PREFIX,i+1);

HTML_LOG(0,"mouse[%s]",mouse);
                char *label;


                if (show_names) {
                    ovs_asprintf(&label,parts->array[i]);
                } else {
                    ovs_asprintf(&label,"part %d",i+2);
                }
                char *vod = vod_link(rowid,label,"",rowid->db->source,parts->array[i],i_str,NVL(mouse),style);
                FREE(label);

                add_movie_part_row(output,i+1,vod);
                add_movie_info_text(js,i+1,parts->array[i]);

                FREE(mouse);

            }
        }


        // Big play button
        char *play_button = get_theme_image_tag("player_play","");
        char *play_tvid;
        if (is_dvd(rowid->file)) {
            // DVDs are not added to the play list. So the play button just plays the dvd directly
            play_tvid = vod_link(rowid,play_button,"",rowid->db->source,rowid->file,"selectedCell","",style); // selectedCell for onloadSet
        } else {
            play_tvid = get_play_tvid(play_button); // selectedCell has been hard coded into this function.
        }

        char *vod_list;
        char *js_script = arraystr(js);
        char *result = arraystr(output);

        ovs_asprintf(&vod_list,
            "<script type=\"text/javascript\"><!--\n\n%s\n\n--></script>\n"
            "<table><tr><td>%s</td>"
            "<td><table>%s</table></td></table>",
            js_script,play_tvid,result);

        FREE(result);
        result = vod_list;
        FREE(js_script);
        FREE(play_button);
        FREE(play_tvid);

        array_free(output);
        array_free(js);

        return result;
    }
}


