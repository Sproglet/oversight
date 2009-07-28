#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <errno.h>

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
    
void display_theme_image_link(char *qlist,char *href_attr,char *image_name,char *button_attr);
char *get_theme_image_tag(char *image_name,char *attr);
void display_tvids(DbRowId **rowids);

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


#define NETWORK_SHARE "/opt/sybhttpd/localhost.drives/NETWORK_SHARE/"
char *get_mounted_path(char *source,char *path) {

    char *new = NULL;
    assert(source);
    assert(path);

    if (*source == '*' ) {
        new = STRDUP(path);
    } else if (strchr(source,'/')) {
        new = STRDUP(path);
    } else if (strncmp(path,"/share/",7) != 0) {
        new = STRDUP(path);
    } else {
        // Source = xxx 
        // [pop-nfs][/share/Apps/oversight/... becomes
        // /opt/sybhttpd/localhost.drives/NETWORK_SHARE/pop-nfs/Apps/oversight/...
        ovs_asprintf(&new,NETWORK_SHARE "%s/%s",source, path+7);
    }
    return new;
}



char *get_poster_path(DbRowId *rowid) {
    assert(rowid->poster);
    char *url = get_path(rowid->poster); //conver ovs: to internal path
    char *url2 = get_mounted_path(rowid->db->source,url);
    free(url);
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
            free(stack[count]);
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
                        free(url);
                        url = new;
                        first=0;
                    }
                }
            }
        }
    }
    char *new;
    ovs_asprintf(&new,"%s%c%s",url,(first?'?':'&'),new_params);
    free(url);
    
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

    free(url);
    return result;
}

#define NMT_PLAYLIST "/tmp/playlist.htm"
static FILE *playlist_fp=NULL;

void playlist_close() {
    if (playlist_fp) {
        fclose(playlist_fp);
        playlist_fp=NULL;
    }
}

FILE *playlist_open() {
    if (playlist_fp == NULL) {
        playlist_fp = fopen(NMT_PLAYLIST,"w");
    }
    return playlist_fp;
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

    free(icon);
    return result;

}


char *vod_link(char *title,char *source,char *file,char *href_name,char *href_attr,char *font_class){

    assert(title);
    assert(source);
    assert(file);
    assert(href_name);
    assert(href_attr);
    assert(font_class);

    char *vod;
    int add_to_playlist=1;
    char *result=NULL;

    if (file[strlen(file)-1] == '/' ) {
        // VIDEO_TS
        ovs_asprintf(&vod," file=c ZCD=2 name=\"%s\" %s ",href_name,href_attr);
        add_to_playlist = 0;

    } else if (regpos(file,"\\.(iso|ISO|img|IMG)$",0) ) {

        // iso or img
        ovs_asprintf(&vod," file=c ZCD=2 name=\"%s\" %s ",href_name,href_attr);

    } else {
        // avi mkv etc
        ovs_asprintf(&vod," vod file=c name=\"%s\" %s ",href_name,href_attr);
    }

    char *path = get_mounted_path(source,file);

    if (add_to_playlist) {
        FILE *fp = playlist_open();
        fprintf(fp,"%s|0|0|file://%s|",file,path);
    }

    char *encoded_path = url_encode(path);

    if (font_class != NULL && *font_class ) {

        ovs_asprintf(&result,"<a href=\"%s\" %s><font class=\"%s\">%s</font></a>",
                encoded_path,vod,font_class,title);
    } else {
        ovs_asprintf(&result,"<a href=\"%s\" %s>%s</a>",
                encoded_path,vod,title);
    }

    free(encoded_path);
    free(path);
    free(vod);
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

    free(title2);
    return result;
}


void display_self_link(char *params,char *attr,char *title) {
    char *tmp;
    tmp=get_self_link(params,attr,title);
    printf("%s",tmp);
    free(tmp);
}


void display_remote_button(char *button_colour,char *params,char *text) {

    assert(button_colour);
    assert(params);
    assert(text);

    char *params2;
    char *attr;
    char *text2;

    ovs_asprintf(&params2,"%s&colour=%s",params,button_colour);
    ovs_asprintf(&attr,"tvid=\"%s\"",button_colour);
    ovs_asprintf(&text2,"<font class=\"%sbutton\">%s</font>",button_colour,text);

    display_self_link(params2,attr,text2);

    free(params2);
    free(attr);
    free(text2);
}


void display_toggle(char *button_colour,char *param_name,char *v1,char *text1,char *v2,char *text2) {

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

    display_remote_button(button_colour,params,text);

    free(params);
    free(text);
}

void display_sort_cells() {

    printf("<td>");

    display_toggle("red",QUERY_PARAM_TYPE_FILTER,
            QUERY_PARAM_MEDIA_TYPE_VALUE_TV,"Tv",
            QUERY_PARAM_MEDIA_TYPE_VALUE_MOVIE,"Film");

    printf("</td><td>");

    display_toggle("green",QUERY_PARAM_WATCHED_FILTER,
            QUERY_PARAM_WATCHED_VALUE_NO,"Unmarked",
            QUERY_PARAM_WATCHED_VALUE_YES,"Marked");

    printf("</td><td>");

    display_toggle("blue",QUERY_PARAM_SORT,
            DB_FLDID_TITLE,"Name",
            DB_FLDID_INDEXTIME,"Age");

    printf("</td>");
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
            if (*output) free(output);
            output = tmp;
        }
    }
    return output;
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


void display_filter_bar() {
    if (*query_val(QUERY_PARAM_SEARCH_MODE) || *query_val(QUERY_PARAM_REGEX)) {

        if (g_dimension->local_browser) {
            char *current_regex =query_val(QUERY_PARAM_REGEX);
            printf("Use the numbers to search");
            display_theme_image_link("p=0&"QUERY_PARAM_SEARCH_MODE"=&"QUERY_PARAM_REGEX"=","","start-small","width=20 height=20");
            printf("<font class=keypada>[%s]</font>",current_regex);

            char *params;
            
            // Print icon to remove last digit from tvid search
            int regex_len=strlen(current_regex);
            if (regex_len >= 1 ) {
                regex_len --;

                ovs_asprintf(&params,"p=0&"QUERY_PARAM_SEARCH_MODE"=&"QUERY_PARAM_REGEX"=%.*s",
                        regex_len,current_regex);
                display_theme_image_link(params,"","left-small","width=20 height=20");
            }

        } else {

            printf("<input type=text name=searcht value=\"%s\" >",query_val("searcht"));
            add_hidden(QUERY_PARAM_SEARCH_MODE);
            display_submit("searchb","Search");
            display_submit("searchb","Hide");

        }

    } else {
        display_theme_image_link("p=0&" QUERY_PARAM_SEARCH_MODE "=1","","find","");
    }
}

void form_start() {
    char *url;

}

char *get_catalog_message() {
#define MSG_SIZE 20
    char *result = NULL;
    static char msg[MSG_SIZE+1];
    char *filename;
    ovs_asprintf(&filename,"%s/catalog.status",appDir());

    msg[0] = '\0';

    FILE *fp = fopen(filename,"r");
    if (fp) {
        fgets(msg,MSG_SIZE,fp);
        msg[MSG_SIZE] = '\0';
        chomp(msg);

        result = msg;

        fclose(fp);
    } else {
        html_error("Error %d opening [%s]",errno,filename);
    }
    free(filename);

    return result;
}

int exists_file_in_dir(char *dir,char *name) {

    char *filename;
    int result = 0;

    ovs_asprintf(&filename,"%s/%s",dir,name);
    result = is_file(filename);
    free(filename);
    return result;
}

void display_status() {
    char *msg = get_catalog_message();
    if (msg == NULL) {

        if (exists_file_in_dir(tmpDir(),"cmd.pending")) {
            msg = "[ Catalog update pending ]";
        } else if (db_full_size() == 0 ) {
            msg = "[ Video index is empty. Select setup icon and scan the media drive ]";
        }
    }

    printf("%s",(msg == NULL ? "" : msg));
}


void display_footer(
        ) {
    printf("Footer here");
}

void display_theme_image_link(char *qlist,char *href_attr,char *image_name,char *button_attr) {
    assert(qlist);
    assert(image_name);

    char  *tag=get_theme_image_tag(image_name,button_attr);
    display_self_link(qlist,href_attr,tag);
    free(tag);
}

void build_tvid_list() {

    printf("tvid?");
}

void display_header(int media_type) {

    printf("<table class=header width=100%%><tr>\n");
    td("align=left width=20%");
    char *mt="?";
    switch(media_type) {
        case DB_MEDIA_TYPE_ANY: mt="All Video"; break;
        case DB_MEDIA_TYPE_TV: mt="TV Shows"; break;
        case DB_MEDIA_TYPE_FILM: mt="Movies"; break;
    }
    printf("<font size=6>%s</font>\n",mt);

    char *version=OVS_VERSION;
    version +=4;
    version = replace_all(version,"BETA","b",0);


    printf("<br><font size=2>V2.%s %s</font>",version,util_hostname());
    td(NULL);

    //-- cell --------------------

    display_sort_cells();

    //- cell ---------------------
    td("");
    display_filter_bar();
    td(NULL);
    //
    //- cell ---------------------
    td("");
    display_status();
    td(NULL);
    //- cell ---------------------
    td("");
    display_theme_image_link("view=admin&action=ask","TVID=SETUP","configure","");
    td(NULL);
    printf("</tr></table>");
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

void display_empty(char *width_attr,int grid_toggle,int left_scroll,int right_scroll,int centre_cell) {

    char *attr;
    printf("\t\t<td %s class=empty%d>",width_attr,grid_toggle);

    attr=get_scroll_attributes(left_scroll,right_scroll,centre_cell,NULL);
    printf("<a href=\"\" %s></a>\n",attr);

    printf("</td>\n");
    free(attr);
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
    free(img_src);
    return result;
}


char *file_style(DbRowId *rowid,int grid_toggle) {

    static char grid_class[16];

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
        free(newattr);
    }
    free(path);
    return result;
}

char *ovs_icon_type() {
    static char *icon_type = NULL;
    if (icon_type == NULL) {
        if (!config_check_str(g_oversight_config,"ovs_icon_type",&icon_type)) {
            icon_type="png";
        }
        html_log(0,"icon type = %s",icon_type);
    }
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

    free(path);
    free(name_br);
    free(attr);
    return result;
}
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
            free(ext_icons);
            ext_icons = new_ext;
        }
    }
    return ext_icons;
}

char *build_id_list(DbRowId *row_id) {

    char *idlist=NULL;

    ovs_asprintf(&idlist,"%s(%ld|",row_id->db->source,row_id->id);
    DbRowId *ri;
    for( ri = row_id->linked ; ri ; ri=ri->linked ) {
        char *tmp;
        ovs_asprintf(&tmp,"%s%ld|",idlist,ri->id);
        free(idlist);
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



void display_item(int cell_no,DbRowId *row_id,char *width_attr,int grid_toggle,
        int left_scroll,int right_scroll,int centre_cell) {

    html_log(0,"TODO:Highlight matched bit");

    char *title=NULL;
    char *font_class=NULL;
    char *grid_class=NULL;

    char *select = query_val("select");
    int tv_or_movie = (row_id->category == 'T' || row_id->category == 'M' );


    if (in_poster_mode() ) {
        if (tv_or_movie && row_id->poster != NULL && row_id->poster[0] != '\0' ) {

            html_log(1,"dbg: tv or movie : set details as jpg");


            char *attr;
            ovs_asprintf(&attr," width=%d height=%d ",
                g_dimension->poster_menu_img_width,g_dimension->poster_menu_img_height);
            title = get_poster_image_tag(row_id,attr);
            free(attr);

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
            free(title);
            title=tmp;
        }

        if (tv_or_movie) {
            html_log(1,"dbg: add certificate");
            //Add certificate and extension
            char *tmp;
            char *ext_icons=build_ext_list(row_id);
            html_log(1,"dbg: add extension [%s]",ext_icons);
            ovs_asprintf(&tmp,"%s %s %s",title,cert,ext_icons);
            free(title);
            title=tmp;
            if (cert != row_id->certificate) free(cert);
            free(ext_icons);
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
            free(title);
            title=tmp;
        }

        long crossview=0;
        config_check_long(g_oversight_config,"ovs_crossview",&crossview);
        if (crossview == 1) {
            html_log(1,"dbg: add network icon");
           char *tmp =add_network_icon(row_id->db->source,title);
           free(title);
           title = tmp;
        }

    }

    html_log(0,"dbg: details [%s]",title);


    char *cell_text=NULL;
    if (*select) {

        //cell_text = select_checkbox(row_id,title);

    } else {


        char *attr = get_scroll_attributes(left_scroll,right_scroll,centre_cell,grid_class);
        html_log(0,"dbg: scroll attributes [%s]",attr);

        if (tv_or_movie) {
            char *params;

            char *idlist = build_id_list(row_id);

            html_log(0,"dbg: id list... [%s]",idlist);

            ovs_asprintf(&params,"view=%s&idlist=%s",
                    (row_id->category=='T'?"tv":"movie"),
                    idlist);
            html_log(0,"dbg: params [%s]",params);

            cell_text = get_self_link_with_font(params,attr,title,font_class);
            html_log(0,"dbg: get_self_link_with_font [%s]",cell_text);

            free(idlist);
            free(params);

        } else {

            char cellId[9];

            sprintf(cellId,"%d",cell_no);
            char *cellName;
            if (centre_cell) {
                cellName="centreCell";
            } else {
                cellName=cellId;
            }


            cell_text = vod_link(title,row_id->db->source,row_id->file,cellName,attr,font_class);

        }
        free(attr);
    }

    free(title);

    printf("\t\t<td %s class=%s>",width_attr,grid_class);
    printf("%s",cell_text);
    printf("</td>");
    free(cell_text);
}


void template_replace(char *input,DbRowId **sorted_row_ids) {
    char *p,*q;

    for (p=input,q=strchr(p,'{')  ; q  ;  q=strchr(p,'{') ) {

        char *macro_start = q;
        char *macro_name_start = NULL;
        char *macro_name_end = NULL;
        char *macro_end = NULL;
        //print bit before macro
        *q='\0';
        printf("%s",p);
        *q='{';

        macro_name_start=strchr(macro_start,':');
        if (macro_name_start) {
            macro_name_start++;
            macro_name_end = strchr(macro_name_start,':');
            if (macro_name_end) {
                macro_end=strchr(macro_name_end,'}');
            }
        }

        // Cant identify macro - advance to next character.
        if (macro_name_start == NULL || macro_name_end == NULL || macro_end == NULL ) {

            putc('{',stdout);
            p=macro_start+1;

        } else {

            macro_name_end[0] = '\0';
            char *macro_output = macro_call(macro_name_start,sorted_row_ids);
            macro_name_end[0] = ':';
            if (macro_output && *macro_output) {

                // Print bit before macro call
                 macro_name_start[-1] = '\0'; 
                 printf("%s",macro_start+1);
                 macro_name_start[-1]=':';

                 printf("%s",macro_output);

                 // Print bit after macro call
                 macro_end[0] = '\0';
                 printf("%s",macro_name_end+1);
                 macro_end[0] = '}';
             }
            p = macro_end + 1;
        }
    }
    printf("%s",p);
}

void display_play_button(char *text1,char *text2) {
    printf("<a href=\"file://tmp/playlist.htm?start_url=\" vod=playlist tvid=PLAY>%s%s</a>",text1,text2);
}

char *scanlines_to_text(long scanlines) {
    switch(scanlines) {
        case 1080: return "1080";
        case 720: return "720";
        default: return "sd";
    }
}

void display_template(char*template_name,char *file_name,DbRowId **sorted_row_ids) {

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
            free(file);
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
            if (strstr(buffer,"<!--") == NULL) {
                html_log(1,"raw:%s",buffer);
            }
            template_replace(buffer,sorted_row_ids);
        }
        fflush(stdout);
        fclose(fp);
    }

    if (file) free(file);
    printf("</form>");
    display_play_button("","");
    printf("</body>");
}

void display_grid(long page, int numids, DbRowId **row_ids) {
    
    int rows = g_dimension->rows;
    int cols = g_dimension->cols;
    int items_per_page = rows * cols;
    int start = page * items_per_page;
    int end = start + items_per_page;
    int centre_row = rows/2;
    int centre_col = cols/2;
    int r,c;

    int page_before = (page > 0);
    int page_after = (end < numids);

    if (end > numids) end = numids;

    printf("<table class=overview width=100%%>\n");
    int i = start;
    char *width_attr;

    ovs_asprintf(&width_attr," width=%d%% ",(int)(100/cols));
    for ( r = 0 ; r < rows ; r++ ) {
        printf("<tr>\n");
        for ( c = 0 ; c < cols ; c++ ) {
            i = start + c * rows + r ;

            int left_scroll = (page_before && c == 0);
            int right_scroll = (page_after && c == cols-1 );
            int centre_cell = (r == centre_row && c == centre_col);

            if ( i < numids ) {

                display_item(i-start,row_ids[i],width_attr,(r+c) & 1,left_scroll,right_scroll,centre_cell);
            } else {
                display_empty(width_attr,(r+c) & 1,left_scroll,right_scroll,centre_cell);
            }
        }
        printf("</tr>\n");
    }
    printf("</table>\n");
    free(width_attr);
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
    ovs_asprintf(&path,"%s/images/nav/set1/%s.%s",
            appDir(),
            image_name,
            ovs_icon_type());
    char *result = local_image_source(path);
    free(path);
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
    free(isrc);
    return result;
}

void display_page_control(char *select,char *view,int page,int on,int offset,char *tvid_name,char *image_base_name) {
    assert(select);
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

            display_theme_image_link(params,attrs,image_base_name,"");
            free(params);
            free(attrs);
        } else if (! *view ) {
            //Only show disabled page controls in main menu view (not tv / movie subpage) - this may change
            char *image_off=NULL;
            ovs_asprintf(&image_off,"%s-off",image_base_name);
            char *tag = get_theme_image_tag(image_off,NULL);
            printf("%s",tag);
            free(image_off);
            free(tag);
        }
    }
}

void display_nav_buttons(int page,int prev_page,int next_page) {
    
    char *q_view=NULL;
    char *q_select=NULL;

    if (!config_check_str(g_query,"view",&q_view)) {
        q_view = "";
    }

    if (!config_check_str(g_query,"select",&q_select)) {
        q_select = "";
    }

    printf("<table class=footer width=100%%><tr valign=top>");

    printf("\n<td width=10%%>");
    display_page_control(q_select,q_view,page,prev_page,-1,"pgup","left");
    printf("</td>");

    if (*q_view && *q_select) {
        printf("\n<td align=center>");
        display_theme_image_link("view=&idlist=","name=up","back","");
        printf("</td>");
    }

    printf("\n<td align=center>");
    if (! *q_view) {
        if(hashtable_count(g_query) == 0 && g_dimension->local_browser) {
            char *tag=get_theme_image_tag("exit",NULL);
            printf("<a href=\"/start.cgi\" name=home >%s</a>",tag);
            free(tag);
        } else {
            char *tag=get_theme_image_tag("home",NULL);
            printf("<a href=\"%s?\" name=home TVID=HOME >%s</a>",SELF_URL,tag);
            free(tag);
        }
    }

    if (! *q_select) {
        // user is viewing
        if (allow_mark()) {
            printf("<td>"); display_theme_image_link("select=Mark","tvid=EJECT","mark",""); printf("</td>");
        }
        if (allow_delete() || allow_delist()) {
            printf("<td>"); display_theme_image_link("select=Delete","tvid=CLEAR","delete",""); printf("</td>");
        }

    } else {
        // user is selecting
        if (strcmp(q_select,"Mark") == 0 ) {

            printf("<td>"); display_submit("action","Mark"); printf("</td>");

        } else if (strcmp(q_select,"Delete") == 0 ) {

            if (allow_delete()) {
                printf("<td>"); display_submit("action","Delete"); printf("</td>");
            }

            if (allow_delist()) {
                printf("<td>"); display_submit("action","Remove_From_List"); printf("</td>");
            }
            printf("<td>"); display_submit("select","Cancel"); printf("</td>");
        }
    }

    printf("</td>");


    printf("\n<td width=10%%>");
    display_page_control(q_select,q_view,page,next_page,1,"pgdn","right");
    printf("</td>");



    printf("</tr></table>");
}

void get_sorted_rows_from_params(DbRowSet ***rowSetsPtr,DbRowId ***sortedRowsPtr) {
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
        html_log(2,"getting tvid..");
        regex = get_tvid(name_filter);
    } else {
        //Check regex entered via text box
        html_log(2,"getting regex..");


        if (*query_val("searcht") && *query_val(QUERY_PARAM_SEARCH_MODE)) {
            html_log(2,"lc regex..");
            regex=util_tolower(query_val("searcht"));
        }
    }
    html_log(0,"Regex filter = %s",regex);

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


    if (regex && *regex ) { free(regex); regex=NULL; }

    struct hashtable *overview = db_overview_hash_create(rowsets);

    DbRowId **sorted_row_ids = NULL;
    
    char *sort = DB_FLDID_TITLE;

    config_check_str(g_query,"s",&sort);


    if (sort && strcmp(sort,DB_FLDID_TITLE) == 0) {
        html_log(0,"sort by name [%s]",sort);
        sorted_row_ids = sort_overview(overview,db_overview_cmp_by_title);
    } else {
        html_log(0,"sort by age [%s]",sort);
        sorted_row_ids = sort_overview(overview,db_overview_cmp_by_age);
    }

    //Free hash without freeing keys
    db_overview_hash_destroy(overview);

    if (sortedRowsPtr) *sortedRowsPtr = sorted_row_ids;
    if (rowSetsPtr) *rowSetsPtr = rowsets;

}

void free_sorted_rows(DbRowSet **rowsets,DbRowId **sorted_row_ids) {

    free(sorted_row_ids);

    //finished now - so we could just let os free
    db_free_rowsets_and_dbs(rowsets);
}



void display_menu() {

    char *start_cell;

    long page;
    if (!config_check_long(g_query,"p",&page)) {
        page = 0;
    }

    display_template("default","menu",sorted_row_ids);

    form_start();
    display_header(media_type);
    display_tvids(sorted_row_ids);
    display_grid(page,hashtable_count(overview),sorted_row_ids);
    display_nav_buttons(page,
            page>0,
            (page+1)*g_dimension->rows*g_dimension->cols < hashtable_count(overview));

    printf("</form></body>");

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

void display_tvids(DbRowId **rowids) {

    //if (g_dimension->local_browser && *query_val("select") == '\0')
    if (*query_val("select") == '\0')
    {

#define TVID_MAX_LEN 3 //
#define TVID_MAX 999   //must be 9 or 99 or 999

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
#define TVID_MARKER "@X@"
        char *params;
        ovs_asprintf(&params,"p=0&"QUERY_PARAM_REGEX"=%s"TVID_MARKER,current_tvid);

        char *link_template = get_self_link(params,"tvid=\""TVID_MARKER"\"","");
        free(params);

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

                            tvid_output[tvid_index] = 1;
                        }
                    }

                }
            }

            array_free(words);


            free(lc_title);
        }
        // Now output all of the selected tvids.
        int i;
        char i_str[TVID_MAX_LEN+1];
        for(i = 1 ; i <= TVID_MAX ; i++ ) {
            if (tvid_output[i]) {
                sprintf(i_str,"%d",i);
                char *link = replace_all(link_template,TVID_MARKER,i_str,0);
                printf("%s\n",link);
                free(link);
            }
        }

        free(link_template);
    }
}

void display_dynamic_styles() {

    long font_size = g_dimension->font_size;
    long small_font = font_size - 2;
    char *view = query_val("view");


    printf(".dummy {};\n"); //bug in gaya - ignores style after comment
    printf(".recent { font-size:%ld; }\n",font_size);
    printf("td { font-size:%ld; font-family:\"arial\";  }\n",font_size);

    if (strcmp(view,"movie")==0 || strcmp(view,"tv") ==0 ) {
        printf("font.plot { font-size:%ld ; font-weight:normal; }\n",small_font); 
        // watched/Unwatched tv
        printf("td.ep10 { background-color:#222222; font-weight:bold; font-size:%ld; }\n",small_font);
        printf("td.ep11 { background-color:#111111; font-weight:bold; font-size:%ld; }\n",small_font);
        printf("td.ep00 { background-color:#004400; font-weight:bold; font-size:%ld; }\n",small_font);
        printf("td.ep01 { background-color:#003300; font-weight:bold; font-size:%ld; }\n",small_font);
        printf(".eptitle { font-size:100%% ; font-weight:normal; font-size:%ld; }\n",small_font);

        printf("h1 { text-align:center; font-size:%ld; font-weight:bold; color:#FFFF00; }\n"
                ,g_dimension->title_size);

        printf(".label { color:red }\n");
    } else {
        printf(".scanlines%ld {color:#FFFF55; font-weight:bold; }\n",g_dimension->scanlines);
    }
    fflush(stdout);
}

