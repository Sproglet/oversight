#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <errno.h>
#include <unistd.h>
#include <regex.h>
#include <time.h>

#include "display.h"
#include "gaya_cgi.h"
#include "util.h"
#include "array.h"
#include "db.h"
#include "dboverview.h"
#include "oversight.h"
#include "hashtable.h"
#include "hashtable_loop.h"
#include "macro.h"
    
char *get_theme_image_link(char *qlist,char *href_attr,char *image_name,char *button_attr);
char *get_theme_image_tag(char *image_name,char *attr);

char *get_play_tvid(char *text) {
    char *result;
    ovs_asprintf(&result,
        "<a href=\"file://tmp/playlist.htm?start_url=\" vod=playlist tvid=PLAY>%s</a>",text);
    return result;
}

// Return a full path 
char *get_path(char *path) {
    char *new=NULL;
    assert(path);
    if (path[0] == '/' ) {
        new = STRDUP(path);
    } else if (strncmp(path,"ovs:",4) == 0) {
        ovs_asprintf(&new,"%s/db/global/%s",appDir(),path+4);
    } else {
        // Other paths are relative to the media file
        /**
         * NO MORE PATHS TO MEDIA FILES
        char *f = strrchr(media_file,'/');
        if (f != NULL) {
            *f ='\0';
            ovs_asprintf(&new,"%s/%s",media_file,path);
            *f='/';
        } 
        */
        new = STRDUP(path);
    }
    return new;
}




char *get_poster_path(DbRowId *rowid) {
    assert(rowid->poster);
    char *url = get_path(rowid->poster); //conver ovs: to internal path
    char *url2 = get_mounted_path(rowid->db->source,url);
    FREE(url);
    return url2;
}


#define XHTML
void tag(char *label,char *attr,va_list ap) {

#ifdef XHTML
    static int count = 0;
    static char *stack[50];
#endif

    if (attr == NULL) {
        printf("</%s>\n",label);
#ifdef XHTML
        count --;
        if (count >= 0) {
            FREE(stack[count]);
        } else {
            html_error("empty html stack for </%s>",label);
        }
#endif
    } else {
        
#ifdef XHTML
        if (count && strcmp(label,stack[count]) == 0) {
            html_error("double nested <%s>",label); // div ok really
        }
#endif

        if (*attr == '\0') {
            printf("<%s>\n",label);
        } else {
            printf("<%s ",label);
            vprintf(attr,ap);
            printf(" >");
        }

#ifdef XHTML
        stack[count++] = STRDUP(label);
#endif
    }
}

void td(char *attr,...) {
    va_list ap;
    va_start(ap,attr);
    tag("td",attr,ap);
    va_end(ap);
}


// Merge the current query string with the parameters.
// Keep the parameters that are not in the new parameter list and are also not blank
// Also exclude "colour" because it represents a one off action and not at state.
char *self_url(char *new_params) {

    struct hashtable_itr *itr;
    char *param_name;
    char *param_value;

    int first=1;

    char *url = STRDUP(SELF_URL);

    for(itr=hashtable_loop_init(g_query) ; hashtable_loop_more(itr,&param_name,&param_value) ; ) {

        
        int param_name_len = strlen(param_name);
        char *p = NULL ;

        if ( param_value && *param_value ) {
            if (strcmp(param_name,"colour") != 0) {
                if (strstr(param_name,"option_") == NULL) {
                    //
                    // search for pram_name in new_params
                    int add_param=1;
                    for (p = strstr(new_params,param_name); p ; p=strstr(p+1,param_name) ) {

                        if ( ( p == new_params || p[-1] == '&' ) ) {
                            // start of string is beginning or after &
                           char *end = p + param_name_len;
                           if (strchr("&=",*end)) {
                              // end of string is = or & or nul
                              // param_name is in new_params - we dont want this
                              add_param=0;
                              break;
                           }
                        }
                    }
                    if (add_param) {
                        char *new;
                        ovs_asprintf(&new,"%s%c%s=%s",url,(first?'?':'&'),param_name,param_value);
                        FREE(url);
                        url = new;
                        first=0;
                    }
                }
            }
        }
    }
    // Now remove any blank params in the list
    char *tmp=replace_all(new_params,"([a-zA-Z0-9_]+=(&|$))","",0);

    char *new;
    ovs_asprintf(&new,"%s%c%s",url,(first?'?':'&'),tmp);
    FREE(url);
    FREE(tmp);
    
    return new;
}

char *get_self_link(char *params,char *attr,char *title) {

    assert(params);
    assert(attr);
    assert(title);
    char *result=NULL;

    html_log(0," begin self link multi for params[%s] attr[%s] title[%s]",params,attr,title);

    char *url = self_url(params);
    html_log(0," end self link multi [%s]",url);

    ovs_asprintf(&result,"<a href=\"%s\" %s>%s</a>",url,attr,title);

    FREE(url);
    return result;
}

#define NMT_PLAYLIST "/tmp/playlist.htm"

//void playlist_close() {
//    if (playlist_fp) {
//        fclose(playlist_fp);
//        playlist_fp=NULL;
//    }
//}

FILE *playlist_open() {
    static FILE *fp=NULL;
    static FILE *j=NULL;
    fflush(stdout);
    //html_log(0,"play list fp is %ld %ld %ld",k,fp,j);
    //exit(1);
    if (fp == NULL) {
        if (unlink(NMT_PLAYLIST) ) {
            html_log(0,"Failed to delete ["NMT_PLAYLIST"]");
        } else {
            html_log(0,"deleted ["NMT_PLAYLIST"]");
        }
        j = fp = fopen(NMT_PLAYLIST,"w");
    }
    assert(fp == j); //DONT ASK! ok catch corruption of static area - maybe...
    return fp;
}

char *add_network_icon(char *source,char *text) {

    assert(source);
    assert(text);
    char *icon;
    char *result=NULL;

    if (strcmp(source,"*") == 0) {

        icon =  get_theme_image_tag("harddisk"," width=20 height=15 ");

    } else {

        icon =  get_theme_image_tag("network"," width=20 height=15 ");

    }

    ovs_asprintf(&result,"%s %s",icon,text);

    FREE(icon);
    return result;

}

int has_category(DbRowId *rowid) {
    return (rowid->category == 'T' || rowid->category == 'M' );
}


//T2 just to avoid c string handling in calling functions!
char *vod_link(DbRowId *rowid,char *title ,char *t2,
        char *source,char *file,char *href_name,char *href_attr,char *font_class){

    assert(title);
    assert(t2);
    assert(source);
    assert(file);
    assert(href_name);
    assert(href_attr);
    assert(font_class);

    char *vod=NULL;
    int add_to_playlist= has_category(rowid);
    char *result=NULL;

    char *path = get_mounted_path(source,file);
    char *encoded_path = url_encode(path);


    if (!g_dimension->local_browser) {

        //If using a browser then VOD tags dont work. Make this script load the file into gaya
        //Note we send the view and idlist parameters so that we can render the original page 
        //in the brower after the infomation is sent to gaya.

        //This works by adding a parameter REMOTE_VOD_PREFIX1=filename
        //The script than captures this after clicking via do_actions,
        //this sends a url to gaya which points back to this script again but will just contain
        //small text to auto load a file using <a onfocusload> and <body onloadset>
        char *params =NULL;
        ovs_asprintf(&params,REMOTE_VOD_PREFIX1"=%s",encoded_path);
        //ovs_asprintf(&params,"idlist=&view=&"REMOTE_VOD_PREFIX1"=%s",encoded_path);
        result = get_self_link(params,"",title);
        FREE(params);

    } else {

        char *p = file + strlen(file);

        if (p[-1] == '/' ) {
            // VIDEO_TS
            ovs_asprintf(&vod," file=c ZCD=2 name=\"%s\" %s ",href_name,href_attr);
            add_to_playlist = 0;

        } else if (strcasecmp(p-4,".iso") == 0 || strcasecmp(p-4,".img") ==0) {

            // iso or img
            ovs_asprintf(&vod," file=c ZCD=2 name=\"%s\" %s ",href_name,href_attr);

        } else {
            // avi mkv etc
            ovs_asprintf(&vod," vod file=c name=\"%s\" %s ",href_name,href_attr);
        }

        if (add_to_playlist) {
            FILE *fp = playlist_open();
            fprintf(fp,"%s|0|0|file://%s|",util_basename(file),path);
            fflush(fp);
        }


        if (font_class != NULL && *font_class ) {

            ovs_asprintf(&result,"<a href=\"file://%s\" %s><font class=\"%s\">%s%s</font></a>",
                    encoded_path,vod,font_class,title,t2);
        } else {
            ovs_asprintf(&result,"<a href=\"file://%s\" %s>%s%s</a>",
                    encoded_path,vod,title,t2);
        }
    }

    FREE(encoded_path);
    FREE(path);
    FREE(vod);
    return result;
}

char *get_self_link_with_font(char *params,char *attr,char *title,char *font_class) {
    assert(params);
    assert(attr);
    assert(title);
    assert(font_class);
    char *title2=NULL;

    ovs_asprintf(&title2,"<font class=\"%s\">%s</font>",font_class,title);
    char *result = get_self_link(params,attr,title2);

    FREE(title2);
    return result;
}


void display_self_link(char *params,char *attr,char *title) {
    char *tmp;
    tmp=get_self_link(params,attr,title);
    printf("%s",tmp);
    FREE(tmp);
}


char *get_remote_button(char *button_colour,char *params,char *text) {

    assert(button_colour);
    assert(params);
    assert(text);

    char *params2;
    char *attr;
    char *text2;

    ovs_asprintf(&params2,"%s&colour=%s",params,button_colour);
    ovs_asprintf(&attr,"tvid=\"%s\"",button_colour);
    ovs_asprintf(&text2,"<font class=\"%sbutton\">%s</font>",button_colour,text);

    char *result = get_self_link(params2,attr,text2);

    FREE(params2);
    FREE(attr);
    FREE(text2);
    return result;
}


char *get_toggle(char *button_colour,char *param_name,char *v1,char *text1,char *v2,char *text2) {

    assert(button_colour);
    assert(param_name);
    assert(v1);
    assert(text1);
    assert(v2);
    assert(text2);

    char *param_value;
    char *params;
    char *text;
    char *next = v1;
    int v1current = 0;
    int v2current = 0;

    if (config_check_str(g_query,param_name,&param_value)) {
        if (strcmp(param_value,v1)==0) {
            v1current = 1;
            next = v2;
        }
        if (strcmp(param_value,v2)==0) {
            v2current = 1;
            next = v1;
        }
    }

    ovs_asprintf(&params,"p=0&%s=%s",param_name,next);

    html_log(0,"params = [%s]",params);

    ovs_asprintf(&text,"%s%s%s<br>%s%s%s",
            (v1current?"<u><b>":""),text1,(v1current?"</b></u>":""),
            (v2current?"<u><b>":""),text2,(v2current?"</b></u>":""));

    html_log(0,"toggle text = [%s]",text);

    char *result = get_remote_button(button_colour,params,text);

    FREE(params);
    FREE(text);
    return result;
}

//Add current named html parameter as a hidden value
char * add_hidden(char *name_list) {
    char *output="";
    Array *names = split(name_list,",",0);
    int i;
    for(i = 0 ; i < names->size ; i++ ) {

        char *name =names->array[i];
        char *val = query_val(name);

        if (*val) {

            char *tmp;
            ovs_asprintf(&tmp,"%s<input type=hidden name=\"%s\" value=\"%s\" >\n",output,name,val);
            if (*output) FREE(output);
            output = tmp;
        }
    }
    if (!*output) {
        return NULL;
    } else {
        return output;
    }
}

void display_submit(char *name,char *value) {
    assert(name);
    assert(value);
    printf("<input type=submit name=\"%s\" value=\"%s\">",name,value);
}

void display_confirm(char *name,char *val_ok,char *val_cancel) {
    printf("<table width=100%%><tr><td align=center>");
    display_submit(name,val_ok);
    printf("</td><td align=center>");
    display_submit(name,val_cancel);
    printf("</td></tr></table>");
}

int exists_file_in_dir(char *dir,char *name) {

    char *filename;
    int result = 0;

    ovs_asprintf(&filename,"%s/%s",dir,name);
    result = is_file(filename);
    FREE(filename);
    return result;
}


void display_footer(
        ) {
    printf("Footer here");
}

char *get_theme_image_link(char *qlist,char *href_attr,char *image_name,char *button_attr) {
    assert(qlist);
    assert(image_name);

    char  *tag=get_theme_image_tag(image_name,button_attr);
    char *result = get_self_link(qlist,href_attr,tag);
    FREE(tag);
    return result;
}
void display_theme_image_link(char *qlist,char *href_attr,char *image_name,char *button_attr) {

    assert(qlist);
    assert(image_name);

    char  *tag=get_theme_image_tag(image_name,button_attr);
    display_self_link(qlist,href_attr,tag);
    FREE(tag);
}

void build_tvid_list() {

    printf("tvid?");
}

char *get_scroll_attributes(int left_scroll,int right_scroll,int centre_cell,char *class) {
    char *attr;
    ovs_asprintf(&attr,
            " %s %s %s %s%s",
            (centre_cell? " name=centreCell ":""),
            (left_scroll? " onkeyleftset=pgup1 ":""),
            (right_scroll? " onkeyrightset=pgdn1 ":""),
            (class != NULL?" class=":""),
            (class != NULL?class:""));

    return attr;
}

char *get_empty(char *width_attr,int grid_toggle,int left_scroll,int right_scroll,int centre_cell) {

    char *attr;

    attr=get_scroll_attributes(left_scroll,right_scroll,centre_cell,NULL);

    char *result;

    ovs_asprintf(&result,"\t\t<td %s class=empty%d><a href=\"\" %s></a>\n",
            width_attr,grid_toggle,attr);

    FREE(attr);
    return result;
}


char *local_image_source(char *path) {
    char *new = NULL;
    assert(path);
    if (g_dimension->local_browser) {
        //If using gaya just go directly to the file system
        ovs_asprintf(&new,"\"file://%s\"",path);
    } else if (strstr(path,"/share/Apps/oversight") == path) {
        // if /share/Apps/oversight/file/path 
        // then use /oversight/file/path thanks to symlink 
        //  /opt/sybhttpd/default/oversight -> /share/Apps/oversight/
        ovs_asprintf(&new,"\"%s\"",path+11);
    } else if (strstr(path,"/opt/sybhttpd/default") == path) {
        // if in /opt/sybhttpd/default/file/path
        // then use /file/path
        ovs_asprintf(&new,"\"%s\"",path+21);
    } else {
        // otherwise pass as a paramter to this script. It will cat jpg etc it to stdout
        ovs_asprintf(&new,"\"?%s\"",path);
    }
    return new;

}

char * get_local_image_link(char *path,char *alt_text,char *attr) {

    assert(path);
    assert(alt_text);
    assert(attr);

    char *result;

    char *img_src = local_image_source(path);

    ovs_asprintf(&result,"<img alt=\"%s\" src=%s %s >",alt_text,img_src,attr);
    FREE(img_src);
    return result;
}


char *file_style(DbRowId *rowid,int grid_toggle) {

    static char grid_class[30];

    sprintf(grid_class," class=grid%cW%d_%d ",
            rowid->category,
            rowid->watched!=0,
            grid_toggle & 1);

    return grid_class;
}
char *watched_style(DbRowId *rowid,int grid_toggle) {

    if (rowid->watched) {
        return " class=watched ";
    } else { 
        long fresh_days;
        if (config_check_long(g_oversight_config,"ovs_new_days",&fresh_days)) {
            if (rowid->date + fresh_days*24*60*60 > time(NULL)) {
                return " border=2 class=fresh ";
            }
        }
    }
    return file_style(rowid,grid_toggle);
}

char * get_poster_image_tag(DbRowId *rowid,char *attr) {

    assert(rowid);
    assert(attr);
    char *result = NULL;
    
    char *newattr=attr;

    char *path = get_poster_path(rowid);

    if (rowid->watched) {
        ovs_asprintf(&newattr," %s %s ",attr,watched_style(rowid,0));
    }

    result = get_local_image_link(path,rowid->title,newattr);

    if (newattr != attr) {
        FREE(newattr);
    }
    FREE(path);
    return result;
}

char *ovs_icon_type() {
    static char *icon_type = NULL;
    static char *i=NULL;
    if (icon_type == NULL) {
        if (!config_check_str(g_oversight_config,"ovs_icon_type",&icon_type)) {
            icon_type="png";
        }
        html_log(0,"icon type = %s",icon_type);
        i = icon_type;
    }
    assert(icon_type == i );
    return icon_type;
}

char *container_icon(char *image_name,char *name) {
    char *path;
    char *attr;
    char *name_br;

    ovs_asprintf(&path,"%s/images/%s.%s",appDir(),image_name,ovs_icon_type());
    ovs_asprintf(&name_br,"(%s)",name);
    ovs_asprintf(&attr," width=30 alt=\"[%s]\" style=\"background-color:#AAAAAA\" ",name);

    char *result = get_local_image_link(path,name_br,attr);

    FREE(path);
    FREE(name_br);
    FREE(attr);
    return result;
}

//free result
char *icon_link(char *name) {

    char *result=NULL;

    if (name[strlen(name)-1] == '/') {
        result = container_icon("video_ts","vob");
    } else {
        char *ext = name + strlen(name) - 3;
        if (strcasecmp(ext,"iso")==0 || strcasecmp(ext,"img") == 0 || strcasecmp(ext,"mkv") == 0) {
            result = container_icon(ext,ext);
        } else if (strcasecmp(ext,"avi") != 0) {
            ovs_asprintf(&result,"<font size=\"-1\">[%s]</font>",ext);
        }
    }
    return result;
}



char *build_ext_list(DbRowId *row_id) {

    char *ext_icons = icon_link(row_id->ext);

    DbRowId *ri;
    for( ri = row_id->linked ; ri ; ri=ri->linked ) {
        if (strstr(ext_icons,ri->ext) == NULL) {
            char *new_ext;
            ovs_asprintf(&new_ext,"%s%s",ext_icons,icon_link(ri->ext));
            FREE(ext_icons);
            ext_icons = new_ext;
        }
    }
    return ext_icons;
}

char *build_id_list(DbRowId *row_id) {

    char *idlist=NULL;
    assert(row_id);
    assert(row_id->db);
    assert(row_id->db->source);

    ovs_asprintf(&idlist,"%s(%ld|",row_id->db->source,row_id->id);
    DbRowId *ri;
    for( ri = row_id->linked ; ri ; ri=ri->linked ) {
        char *tmp;
        ovs_asprintf(&tmp,"%s%ld|",idlist,ri->id);
        FREE(idlist);
        idlist = tmp;
    }

    idlist[strlen(idlist)-1] = ')';

    return idlist;
}

#define MAX_TITLE_LEN 50
char *trim_title(char *title) {
    char *out = STRDUP(title);
    if (strlen(out) > MAX_TITLE_LEN) {
        strcpy(out+MAX_TITLE_LEN-3,"..");
    }
    return out;
}


char *select_checkbox(DbRowId *rid,char *text) {
    char *result = NULL;
    char *select = query_val("select");

    if (*select) {

        char *id_list = build_id_list(rid);

        if (rid->watched && strcmp(select,"Mark")) {

            ovs_asprintf(&result,
                "<input type=checkbox name=\""CHECKBOX_PREFIX"%s\" CHECKED >"
                "<input type=hidden name=\"orig_"CHECKBOX_PREFIX"%s\" value=on>"
                "<font class=%s>%s</font>",
                    id_list,
                    id_list,
                    select,text);
        } else {

            ovs_asprintf(&result,
                "<input type=checkbox name=\""CHECKBOX_PREFIX"%s\" >"
                "<font class=%s>%s</font>",
                    id_list,
                    select,text);
        }
        FREE(id_list);
    } else {
        ovs_asprintf(&result,"<font class=Ignore>%s</font>",text);
    }
    return result;
}



char *movie_listing(DbRowId *rowid) {

    db_rowid_dump(rowid);

    char *select = query_val("select");
    char *style = watched_style(rowid,0);
    if (*select) {
        return select_checkbox(rowid,rowid->file);
    } else {
        char *result=NULL;
        char *button_attr=NULL;
        Array *parts = split(rowid->parts,"/",0);
        int button_size;
        html_log(0,"parts ptr = %ld",parts);
        if (parts && parts->size) {
            array_print("movie_listing",parts);
            // Multiple parts
            button_size = g_dimension->button_size * 2 / 3;
        } else {
            // Just one part
            button_size = g_dimension->button_size;
        }

        ovs_asprintf(&button_attr," width=%d height=%d ",button_size,button_size);
        char *movie_play = get_theme_image_tag("player_play",button_attr);
        FREE(button_attr);

        char *basename=util_basename(rowid->file);

        result=vod_link(rowid,basename,movie_play,rowid->db->source,rowid->file,"0","onkeyleftset=up",style);
        // Add vod links for all of the parts
        
        if (parts && parts->size) {
            char *dir_end = strrchr(rowid->file,'/');
            *dir_end = '\0';
            char *dir = rowid->file;

            int i;
            for(i = 0 ; i < parts->size ; i++ ) {

                char i_str[10];
                sprintf(i_str,"%d",i);

                char *part_path;
                ovs_asprintf(&part_path,"%s/%s",dir,parts->array[i]);

                char *tmp=vod_link(rowid,parts->array[i],movie_play,rowid->db->source,part_path,i_str,"",style);
                FREE(part_path);

                char *vod_list;
                ovs_asprintf(&vod_list,"%s\n<br>%s",result,tmp);
                FREE(tmp);
                FREE(result);
                result=vod_list;
            }
            *dir_end = '/';

            // Big play button
            {
                char *big_play = get_theme_image_tag("player_play","");
                char *play_tvid = get_play_tvid(big_play);
                FREE(big_play);

                char *vod_list;
                ovs_asprintf(&vod_list,"%s\n%s",play_tvid,result);
                FREE(result);
                result = vod_list;
            }
        }
        FREE(movie_play);
        return result;
    }
}



char *get_item(int cell_no,DbRowId *row_id,char *width_attr,int grid_toggle,
        int left_scroll,int right_scroll,int centre_cell) {

    html_log(0,"TODO:Highlight matched bit");

    char *title=NULL;
    char *font_class=NULL;
    char *grid_class=NULL;

    char *select = query_val("select");
    int tv_or_movie = has_category(row_id);


    if (in_poster_mode() ) {
        if (tv_or_movie && row_id->poster != NULL && row_id->poster[0] != '\0' ) {

            html_log(1,"dbg: tv or movie : set details as jpg");


            char *attr;
            ovs_asprintf(&attr," width=%d height=%d ",
                g_dimension->poster_menu_img_width,g_dimension->poster_menu_img_height);
            title = get_poster_image_tag(row_id,attr);
            FREE(attr);

            font_class = "fc";
            grid_class = "gc";
        } else {
            html_log(1,"dbg: unclassified : set details as title");
            // Unclassified
            title=STRDUP(row_id->title);
            font_class = watched_style(row_id,grid_toggle);
        }

    } else {

        // TEXT MODE
        html_log(1,"dbg: get text mode details ");

        font_class = watched_style(row_id,grid_toggle);
        grid_class = file_style(row_id,grid_toggle);
       
       char *tmp;
       title = row_id->title;

       char *cert = row_id->certificate;
       if ((tmp=strchr(cert,':')) != NULL) {
           ovs_asprintf(&cert,"(%s)",tmp+1);
       }


        char *title = trim_title(row_id->title);

        if (row_id->category == 'T' && row_id->season >= 1) {
            //Add season
            char *tmp;
            ovs_asprintf(&tmp,"%s S%s",title,row_id->season);
            FREE(title);
            title=tmp;
        }

        if (tv_or_movie) {
            html_log(1,"dbg: add certificate");
            //Add certificate and extension
            char *tmp;
            char *ext_icons=build_ext_list(row_id);
            html_log(1,"dbg: add extension [%s]",ext_icons);
            ovs_asprintf(&tmp,"%s %s %s",title,cert,ext_icons);
            FREE(title);
            title=tmp;
            if (cert != row_id->certificate) FREE(cert);
            FREE(ext_icons);
        }

        if (row_id->category == 'T') {
            html_log(1,"dbg: add episode count");
            //Add episode count
            int group_count=0;
            DbRowId *rid;

            for(rid=row_id ; rid ; rid=rid->linked) {
                group_count++;
            }
            char *tmp;
            ovs_asprintf(&tmp,"%s&nbsp;<font color=#AAFFFF size=-1>x%d</font>",title,group_count);
            FREE(title);
            title=tmp;
        }

        long crossview=0;
        config_check_long(g_oversight_config,"ovs_crossview",&crossview);
        if (crossview == 1) {
            html_log(1,"dbg: add network icon");
           char *tmp =add_network_icon(row_id->db->source,title);
           FREE(title);
           title = tmp;
        }

    }

    html_log(0,"dbg: details [%s]",title);


    char *cell_text=NULL;


    char *attr = get_scroll_attributes(left_scroll,right_scroll,centre_cell,grid_class);
    html_log(0,"dbg: scroll attributes [%s]",attr);

    char *idlist = build_id_list(row_id);

    if (tv_or_movie) {
        char *params;


        html_log(0,"dbg: id list... [%s]",idlist);

        ovs_asprintf(&params,"view=%s&idlist=%s",
                (row_id->category=='T'?"tv":"movie"),
                idlist);
        html_log(0,"dbg: params [%s]",params);

        cell_text = get_self_link_with_font(params,attr,title,font_class);
        html_log(0,"dbg: get_self_link_with_font [%s]",cell_text);

        FREE(params);

    } else {


        char cellId[9];

        sprintf(cellId,"%d",cell_no);
        char *cellName;
        if (centre_cell) {
            cellName="centreCell";
        } else {
            cellName=cellId;
        }


        cell_text = vod_link(row_id,title,"",row_id->db->source,row_id->file,cellName,attr,font_class);

    }
    FREE(attr);

    if (*select) {
        char *tmp = cell_text;
        tmp=select_checkbox(row_id,cell_text);
        FREE(cell_text);
        cell_text=tmp;
    }

    FREE(idlist);
    FREE(title);

    char *result;
    ovs_asprintf(&result,"\t\t<td %s class=%s>%s</td>",width_attr,grid_class,cell_text);
    FREE(cell_text);
    return result;
}


#define MACRO_CH_BEG '['
#define MACRO_CH_SEP ':'
#define MACRO_CH_END ']'
void template_replace(char *template_name,char *input,int num_rows,DbRowId **sorted_row_ids) {

    char *macro_start = NULL;


    char *p = input;
    macro_start = strchr(input,MACRO_CH_BEG);
    while (macro_start ) {

        char *macro_name_start = NULL;
        char *macro_name_end = NULL;
        char *macro_end = NULL;
        //print bit before macro
        *macro_start='\0';
        printf("%s",p);
        *macro_start=MACRO_CH_BEG;

        // Check we have MACRO_CH_BEG .. MACRO_CH_SEP MACRO_NAME MACRO_CH_SEP .. MACRO_CH_END
        // eg [text1:name:text2]
        // If the macro "name" is non-empty then "text1 macro-out text2" is printed.
        macro_name_start=strchr(macro_start,MACRO_CH_SEP);
        if (macro_name_start) {
            macro_name_start++;
            macro_name_end = strchr(macro_name_start,MACRO_CH_SEP);
            if (macro_name_end) {
                macro_end=strchr(macro_name_end,MACRO_CH_END);
            }
        }

        // Cant identify macro - advance to next character.
        if (macro_name_start == NULL || macro_name_end == NULL || macro_end == NULL ) {

            putc(MACRO_CH_BEG,stdout);
            macro_end = macro_start;

        } else {

            int free_result=0;
            macro_name_end[0] = '\0';
            char *macro_output = macro_call(template_name,macro_name_start,num_rows,sorted_row_ids,&free_result);
            macro_name_end[0] = MACRO_CH_SEP;
            if (macro_output && *macro_output) {

                // Print bit before macro call
                 macro_name_start[-1] = '\0'; 
                 printf("%s",macro_start+1);
                 macro_name_start[-1]=MACRO_CH_SEP;
                 fflush(stdout);

                 printf("%s",macro_output);
                 if (free_result) FREE(macro_output);
                 fflush(stdout);

                 // Print bit after macro call
                 macro_end[0] = '\0';
                 printf("%s",macro_name_end+1);
                 macro_end[0] = MACRO_CH_END;
                 fflush(stdout);
             }
        }

        p=macro_end+1;

        macro_start=strchr(p,MACRO_CH_BEG);

    }
    // Print the last bit
    printf("%s",p);
    fflush(stdout);
}

char *scanlines_to_text(long scanlines) {
    switch(scanlines) {
        case 1080: return "1080";
        case 720: return "720";
        default: return "sd";
    }
}

void display_template(char*template_name,char *file_name,int num_rows,DbRowId **sorted_row_ids) {

    html_log(0,"begin template");

    char *file;
    ovs_asprintf(&file,"%s/templates/%s/%s/%s.template",appDir(),
            template_name,
            scanlines_to_text(g_dimension->scanlines),
            file_name);
    html_log(1,"opening %s",file);

    FILE *fp=fopen(file,"r");
    if (fp == NULL) {
        if (errno == 2) {
            FREE(file);
            ovs_asprintf(&file,"%s/templates/%s/any/%s.template",appDir(),
                    template_name,
                    file_name);
            html_log(1,"opening %s",file);
            fp=fopen(file,"r");
        }
        if (fp == NULL) {
            html_error("Error %d opening %s",errno,file);
        }
    }

    if (fp) {
#define HTML_BUF_SIZE 999

        char buffer[HTML_BUF_SIZE+1];
        while(fgets(buffer,HTML_BUF_SIZE,fp) != NULL) {
            buffer[HTML_BUF_SIZE] = '\0';
//            if (strstr(buffer,"<!--") == NULL) {
//                html_log(1,"raw:%s",buffer);
//            }
            template_replace(template_name,buffer,num_rows,sorted_row_ids);
        }
        fflush(stdout);
        fclose(fp);
    }

    if (file) FREE(file);
    html_log(0,"end template");
}

char *get_grid(long page,int rows, int cols, int numids, DbRowId **row_ids) {
    
    int items_per_page = rows * cols;
    int start = page * items_per_page;
    int end = start + items_per_page;
    int centre_row = rows/2;
    int centre_col = cols/2;
    int r,c;

    int page_before = (page > 0);
    int page_after = (end < numids);

    if (end > numids) end = numids;

    html_log(0,"grid page %ld rows %d cols %d",page,rows,cols);

    char *result=NULL;
    int i = start;
    char *width_attr;
    char *tmp;

    ovs_asprintf(&width_attr," width=%d%% ",(int)(100/cols));
    for ( r = 0 ; r < rows ; r++ ) {


        html_log(0,"grid row %d",r);
        ovs_asprintf(&tmp,"%s<tr>\n",result);
        FREE(result);
        result=tmp;

        for ( c = 0 ; c < cols ; c++ ) {
            html_log(0,"grid col %d",c);
            i = start + c * rows + r ;

            int left_scroll = (page_before && c == 0);
            int right_scroll = (page_after && c == cols-1 );
            int centre_cell = (r == centre_row && c == centre_col);

            char *item=NULL;
            if ( i < numids ) {
                html_log(0,"grid item");
                item = get_item(i-start,row_ids[i],width_attr,(r+c) & 1,left_scroll,right_scroll,centre_cell);
            } else {
                html_log(0,"grid empty");
                item = get_empty(width_attr,(r+c) & 1,left_scroll,right_scroll,centre_cell);
            }
            ovs_asprintf(&tmp,"%s%s\n",result,item);
            FREE(result);
            FREE(item);
            result=tmp;
            html_log(0,"grid end col %d",c);
        }
        
        ovs_asprintf(&tmp,"%s</tr>\n",result);
        FREE(result);
        result=tmp;
        html_log(0,"grid end row %d",r);

    }
    ovs_asprintf(&tmp,"<table class=overview width=100%%>\n%s\n</table>\n",result);
    FREE(result);
    result=tmp;

    FREE(width_attr);
    return result;
}

/* Convert 234 to TVID/text message regex */
char *get_tvid( char *sequence ) {
    char *out = NULL;
    char *p,*q;
    if (sequence) {
        out = p = MALLOC(9*strlen(sequence)+1);
        *p = '\0';
        for(q = sequence ; *q ; q++ ) {
            switch(*q) {
                case '1' : strcpy(p,"1"); break;
                case '2' : strcpy(p,"[2abc]"); break;
                case '3' : strcpy(p,"[3def]"); break;
                case '4' : strcpy(p,"[4ghi]"); break;
                case '5' : strcpy(p,"[5jkl]"); break;
                case '6' : strcpy(p,"[6mno]"); break;
                case '7' : strcpy(p,"[7pqrs]"); break;
                case '8' : strcpy(p,"[8tuv]"); break;
                case '9' : strcpy(p,"[9wxyz]"); break;
            }
            p += strlen(p);
        }
    }
    html_log(1,"tvid %s = regex %s",sequence,out);
    return out;

}

char *default_button_attr() {
    static char *default_attr = NULL;
    if (default_attr == NULL) {
        ovs_asprintf(&default_attr,"width=%ld height=%ld",g_dimension->button_size,g_dimension->button_size);
        html_log(0,"default button attr = %s",default_attr);
    }
    return default_attr;
}

char *icon_source(image_name) {
    char *path;
    assert(image_name);

    char *app=appDir();
    char *ico=ovs_icon_type();

    ovs_asprintf(&path,"%s/images/nav/set1/%s.%s",
            app,
            image_name,
            ico);
    char *result = local_image_source(path);
    FREE(path);
    return result;
}

void href(char *url,char *attr,char *text) {
    printf("\n<a href=\"%s\" %s>%s</a>",url,attr,text);
}

char *get_theme_image_tag(char *image_name,char *attr) {

    char *isrc;
    char *result = NULL;
    assert(image_name);
    if (attr == NULL || ! *attr) {

        attr = default_button_attr();
    }
    isrc = icon_source(image_name);
    ovs_asprintf(&result,"<img alt=\"%s\" border=0 src=%s %s />",image_name,isrc,attr);
    FREE(isrc);
    return result;
}



int get_sorted_rows_from_params(DbRowSet ***rowSetsPtr,DbRowId ***sortedRowsPtr) {
    // Get filter options
    long crossview=0;

    config_check_long(g_oversight_config,"ovs_crossview",&crossview);
    html_log(0,"Crossview = %ld",crossview);

    //Tvid filter = this as the form 234
    html_log(0,"search query...");
    html_hashtable_dump(0,"query",g_query);
    char *name_filter=hashtable_search(g_query,"_rt"); 
    html_log(0,"done search query");
    char *regex = NULL;
    if (name_filter) {
        regex = get_tvid(name_filter);
    } else {
        //Check regex entered via text box

        if (*query_val("searcht") && *query_val(QUERY_PARAM_SEARCH_MODE)) {
            regex=util_tolower(query_val("searcht"));
        }
    }
    html_log(2,"Regex filter = %s",regex);

    // Watched filter
    char *watched_param;
    int watched = DB_WATCHED_FILTER_ANY;

    if (config_check_str(g_query,QUERY_PARAM_WATCHED_FILTER,&watched_param)) {

        if (strcmp(watched_param,QUERY_PARAM_WATCHED_VALUE_YES) == 0) {

            watched=DB_WATCHED_FILTER_YES;

        } else if (strcmp(watched_param,QUERY_PARAM_WATCHED_VALUE_NO) == 0) {

            watched=DB_WATCHED_FILTER_NO;
        }
    }
    html_log(0,"Watched filter = %ld",watched);

    // Tv/Film filter
    char *media_type_str=NULL;
    int media_type=DB_MEDIA_TYPE_ANY;

    if (config_check_str(g_query,QUERY_PARAM_TYPE_FILTER,&media_type_str)) {

        if(strcmp(media_type_str,QUERY_PARAM_MEDIA_TYPE_VALUE_TV) == 0) {

            media_type=DB_MEDIA_TYPE_TV; 

        } else if(strcmp(media_type_str,QUERY_PARAM_MEDIA_TYPE_VALUE_MOVIE) == 0) {

            media_type=DB_MEDIA_TYPE_FILM; 

        }
    }
    html_log(0,"Media type = %d",media_type);

    
    DbRowSet **rowsets = db_crossview_scan_titles( crossview, regex, media_type, watched);


    if (regex && *regex ) { FREE(regex); regex=NULL; }

    struct hashtable *overview = db_overview_hash_create(rowsets);

    DbRowId **sorted_row_ids = NULL;
    
    char *sort = DB_FLDID_TITLE;

    config_check_str(g_query,"s",&sort);


    if (strcmp(query_val("view"),"tv") == 0) {

        html_log(0,"sort by name / season / episode");
        sorted_row_ids = sort_overview(overview,db_overview_cmp_by_title);

    } else  if (sort && strcmp(sort,DB_FLDID_TITLE) == 0) {

        html_log(0,"sort by name [%s]",sort);
        sorted_row_ids = sort_overview(overview,db_overview_cmp_by_title);

    } else {

        html_log(0,"sort by age [%s]",sort);
        sorted_row_ids = sort_overview(overview,db_overview_cmp_by_age);
    }

    int numrows = hashtable_count(overview);
    //Free hash without freeing keys
    db_overview_hash_destroy(overview);

    if (sortedRowsPtr) *sortedRowsPtr = sorted_row_ids;
    if (rowSetsPtr) *rowSetsPtr = rowsets;

    return numrows;
}

void free_sorted_rows(DbRowSet **rowsets,DbRowId **sorted_row_ids) {

    FREE(sorted_row_ids);

    //finished now - so we could just let os free
    db_free_rowsets_and_dbs(rowsets);
}



void set_tvid_increments(int *tvid_val) {
    memset(tvid_val,0,256);
    tvid_val['1']=1;
    tvid_val['2']=tvid_val['a']=tvid_val['b']=tvid_val['c']=2;
    tvid_val['3']=tvid_val['d']=tvid_val['e']=tvid_val['f']=3;
    tvid_val['4']=tvid_val['g']=tvid_val['h']=tvid_val['i']=4;
    tvid_val['5']=tvid_val['j']=tvid_val['k']=tvid_val['l']=5;
    tvid_val['6']=tvid_val['m']=tvid_val['n']=tvid_val['o']=6;
    tvid_val['7']=tvid_val['p']=tvid_val['q']=tvid_val['r']=tvid_val['s']=7;
    tvid_val['8']=tvid_val['t']=tvid_val['u']=tvid_val['v']=8;
    tvid_val['9']=tvid_val['w']=tvid_val['x']=tvid_val['y']=tvid_val['z']=8;
}

char *get_tvid_links(DbRowId **rowids) {

    char *result = NULL;
    //if (g_dimension->local_browser && *query_val("select") == '\0')
    if (*query_val("select") == '\0')
    {

#define TVID_MAX_LEN 3 //
#define TVID_MAX 999   //must be 9 or 99 or 999

        int tvid_total=0;
        char *current_tvid = query_val(QUERY_PARAM_REGEX);

        // Tracks which tvid codes to output to html 0=dont output
        char tvid_output[TVID_MAX+1];
        memset(tvid_output,0,TVID_MAX+1); // initially no output

        // Map character to tvid digit.
        int tvid_val[256];
        set_tvid_increments(tvid_val);

        html_log(0,"tvid generation");

        int current_tvid_len = strlen(current_tvid);

        // Pre compute tvid link using @X@ as a placeholder
#define TVID_MARKER "@X@Y@"
        char *params;
        ovs_asprintf(&params,"p=0&"QUERY_PARAM_REGEX"=%s"TVID_MARKER,current_tvid);

        char *link_template = get_self_link(params,"tvid=\""TVID_MARKER"\"","");
        FREE(params);

        DbRowId **rowid_ptr;
        for(rowid_ptr = rowids ; *rowid_ptr ; rowid_ptr++ ) {

            DbRowId *rid = *rowid_ptr;

            char *lc_title = util_tolower(rid->title);

            Array *words = split(lc_title," ",0);

            if (words) {
                int w;
                for(w = 0 ; w < words->size ; w++ ) {

                    unsigned char *word = words->array[w];
                    unsigned char *remaining_word = word + current_tvid_len;

                    if (word+strlen((char *)word) > remaining_word) {
                        //
                        // no go through all remaining letters converting to tvid number
                        // and set that tvid to be output. eg.
                        // Say remaining word is "ost" of Lost. then we want tvids
                        // o =>6
                        // os => 67
                        // ost => 678

                        int i,tvid_index=0;
                        for(i = 0 ; i < TVID_MAX_LEN && *remaining_word ; i++,remaining_word++ ) {
                            tvid_index *= 10;
                            tvid_index += tvid_val[*remaining_word];

                            if (tvid_output[tvid_index] == 0) {
                                tvid_total++;
                                tvid_output[tvid_index] = 1;
                            }

                        }
                    }

                }
            }

            array_free(words);


            FREE(lc_title);
        }
        // Now output all of the selected tvids.
        result = malloc((strlen(link_template)+5)*tvid_total);

        int i;
        char i_str[TVID_MAX_LEN+1];
        char *p = result;
        for(i = 1 ; i <= TVID_MAX ; i++ ) {
            if (tvid_output[i]) {
                sprintf(i_str,"%d",i);
                char *link = replace_all(link_template,TVID_MARKER,i_str,0);
                strcpy(p,link);
                FREE(link);
                p=strchr(p,'\0');
                *p++ = '\n';
                *p = '\0';
            }
        }
        FREE(link_template);

    }
    return result;
}
long use_boxsets() {
    static long boxsets = -1;
    if(boxsets == -1) {
        if (!config_check_long(g_oversight_config,"ovs_boxsets",&boxsets)) {
            boxsets = 0;
        }
    }
    return boxsets;
}


int year(time_t t) {
    return localtime(&t)->tm_year + 1900;
}

char *tv_listing(int num_rows,DbRowId **sorted_rows,int rows,int cols) {
    int r,c;

    char *select=query_val("select");

    char *listing=NULL;
#define DATE_BUF_SIZ 40
    char date_buf[DATE_BUF_SIZ];
    char *old_date_format=NULL;
    char *new_date_format=NULL;

    int width2=100/cols; //text and date
    int width1=4; //episode width
    width2 -= width1;

    // Date format
    if (!config_check_str(g_oversight_config,"ovs_date_format",&new_date_format)) {
        new_date_format="- %d %b";
    }
    if (!config_check_str(g_oversight_config,"ovs_old_date_format",&old_date_format)) {
        old_date_format="-%d&nbsp;%b&nbsp;%y";
    }

    if (num_rows/cols < rows ) {
        rows = (num_rows+cols-1) / cols;
    }

    for(r=0 ; r < rows ; r++ ) {
        char *row_text = NULL;
        for(c = 0 ; c < cols ; c++ ) {

            int i = c * rows + r;
            if (i < num_rows) {

                char *title=NULL;
                char *episode_col = NULL;

                DbRowId *rid = sorted_rows[i];

                char episode[20];
                sprintf(episode,"%02d.",rid->episode);

                if (*select) {
                    episode_col = select_checkbox(
                            rid,
                            episode);
                } else {
                    episode_col = vod_link(
                            rid,
                            episode,"",
                            rid->db->source,
                            rid->file,
                            episode,
                            "",
                            watched_style(rid,i%2));
                }

                // Title
                title=rid->eptitle;
                if (title == NULL || !*title) {
                    title=rid->eptitle_imdb;
                }
                if (title == NULL || !*title) {
                    title=rid->additional_nfo;
                }
                if (title == NULL || !*title) {
                    title=util_basename(rid->file);
                }

                //TODO truncate episode length here - 37 chars?
                
                char *title_txt=NULL;
                int is_proper = util_strreg(rid->file,"proper",REG_ICASE) != NULL;
                int is_repack = util_strreg(rid->file,"repack",REG_ICASE) != NULL;
                char *icon_text = icon_link(rid->file);

                ovs_asprintf(&title_txt,"%s%s%s&nbsp;%s",
                        title,
                        (is_proper?"&nbsp;<font class=proper>[pr]</font>":""),
                        (is_repack?"&nbsp;<font class=repack>[rpk]</font>":""),
                        (icon_text?icon_text:""));
                FREE(icon_text);


                //Date
                long date=rid->airdate;
                if (date<=0) {
                    date=rid->airdate_imdb;
                }

                char *date_format=NULL;
                if  (year(time(NULL)) != year(date)) {  //if ( (year(time(NULL)-date) / 60 / 60 / 24 > 300 ) {
                    date_format = old_date_format;
                } else {
                    date_format = new_date_format;
                }

                *date_buf='\0';
                date=strftime(date_buf,DATE_BUF_SIZ,date_format,localtime((time_t *)(&date)));

                //Put Episode/Title/Date together in new cell.
                char *tmp;
                ovs_asprintf(&tmp,"%s<td class=ep%d%d width=%d%%>%s</td><td width=%d%%>%s<font class=epdate>%s</font></td>\n",
                        (row_text?row_text:""),
                        sorted_rows[0]->watched,i%2,
                        width1,
                        episode_col,
                        width2,
                        title_txt,
                        (*date_buf?date_buf:"")
                        );
                FREE(title_txt);
                FREE(episode_col);
                FREE(row_text);
                row_text=tmp;

            } else {
                char *tmp=NULL;
                ovs_asprintf(&tmp,"%s<td width=%d%%></td><td width=%d%%></td>\n",
                    (row_text?row_text:""),
                    width1,
                    width2);
                FREE(row_text);
                row_text=tmp;
            }
        }
        // Add the row
        if (row_text) {
            char *tmp;
            ovs_asprintf(&tmp,"%s<tr>%s</tr>\n",(listing?listing:""),row_text);
            FREE(row_text);
            FREE(listing);
            listing=tmp;
        }
    }

    char *result=NULL;
    ovs_asprintf(&result,"vdbg:<table width=100%% class=listing>%s</table>",listing);
    FREE(listing);
    return result;
}
