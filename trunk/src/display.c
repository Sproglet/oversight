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
#include "mount.h"
    
char *get_theme_image_link(char *qlist,char *href_attr,char *image_name,char *button_attr);
char *get_theme_image_tag(char *image_name,char *attr);

char *get_play_tvid(char *text) {
    char *result;
    ovs_asprintf(&result,
        "<a href=\"file:///tmp/playlist.htm?start_url=\" vod=playlist tvid=\"_PLAY\">%s</a>",text);
    return result;
}

// Return a full path 
char *get_path(DbRowId *rid,char *path) {

    char *mounted_path=NULL;

    char *path_relative_to_host_nmt=NULL;
    assert(path);
    if (path[0] == '/' ) {
        path_relative_to_host_nmt = STRDUP(path);
    } else if (strncmp(path,"ovs:",4) == 0) {
        ovs_asprintf(&path_relative_to_host_nmt,"%s/db/global/%s",appDir(),path+4);
    } else {
        char *d=util_dirname(rid->file);
       ovs_asprintf(&path_relative_to_host_nmt,"%s/%s",d,path);
       FREE(d);
    }

    mounted_path=get_mounted_path(rid->db->source,path_relative_to_host_nmt);

    FREE(path_relative_to_host_nmt);

    return mounted_path;
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
                    if (new_params && *new_params) {
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

    html_log(1," begin self link multi for params[%s] attr[%s] title[%s]",params,attr,title);

    char *url = self_url(params);
    html_log(1," end self link multi [%s]",url);

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
    //html_log(1,"play list fp is %ld %ld %ld",k,fp,j);
    //exit(1);
    if (fp == NULL) {
        if (unlink(NMT_PLAYLIST) ) {
            html_log(1,"Failed to delete ["NMT_PLAYLIST"]");
        } else {
            html_log(1,"deleted ["NMT_PLAYLIST"]");
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

char *vod_attr(char *file) {

    char *p = file + strlen(file);

    if (p[-1] == '/' || strcasecmp(p-4,".iso")==0 || strcasecmp(p-4,".img") == 0) {

        return "file=c ZCD=2";

    } else {
        return "vod file=c";

    }
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

    char *path = get_path(rowid,file);

    nmt_mount(path);

    char *encoded_path = url_encode(path);
    int show_link = 1;

    if (!exists(path) ) {


        char *parent_dir = util_dirname(path);
        char *grandparent_dir = util_dirname(parent_dir);

        char *name = util_basename(path);

        html_log(3,"path[%s]",path);
        html_log(3,"parent_dir[%s]",parent_dir);
        html_log(3,"grandparent_dir[%s]",grandparent_dir);
        html_log(3,"name[%s]",name);

        show_link=0;
        if (!exists(grandparent_dir)) {

            //media gone
            //ovs_asprintf(&result,"<font class=error>%s</font>",name);
            font_class="class=error";

        } else {

            //media present - file gone!
            db_remove_row(rowid);
            ovs_asprintf(&result,"removed %s",name);
        }
        FREE(name);
        FREE(parent_dir);
        FREE(grandparent_dir);
    }

    if (show_link) {


        if (!g_dimension->local_browser && browsing_from_lan()) {

            if (*oversight_val("ovs_tv_play_via_pc") == '1') {
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
                result = get_self_link_with_font(params,font_class,title,font_class);
                FREE(params);

            } else {
                ovs_asprintf(&result,"<font class=%s>%s</font>",font_class,title);
            }

        } else {

            ovs_asprintf(&vod," %s name=\"%s\" %s ",vod_attr(file),href_name,href_attr);

            if (add_to_playlist) {
                FILE *fp = playlist_open();
                char *name=util_basename(file);
                fprintf(fp,"%s|0|0|file://%s|",name,path);
                FREE(name);
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
    }

    FREE(encoded_path);
    FREE(path);
    FREE(vod);
    return result;
}

char *get_self_link_with_font(char *params,char *attr,char *title,char *font_attr) {
    assert(params);
    assert(attr);
    assert(title);
    assert(font_attr);
    char *title2=NULL;

    ovs_asprintf(&title2,"<font %s>%s</font>",font_attr,title);
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

    param_value = query_val(param_name);

    if (!*param_value) {

        next = v1;
        v1current = v2current = 0;

    } else if (strcmp(param_value,v1)==0) {

        v1current = 1;
        next = v2;

    } else if (strcmp(param_value,v2)==0) {
            
        v2current = 1;
        next = "";
    }

    ovs_asprintf(&params,"p=0&%s=%s",param_name,next);

    html_log(1,"params = [%s]",params);

    ovs_asprintf(&text,"%s%s%s<br>%s%s%s",
            (v1current?"<u><b>":""),text1,(v1current?"</b></u>":""),
            (v2current?"<u><b>":""),text2,(v2current?"</b></u>":""));

    html_log(1,"toggle text = [%s]",text);

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

char *add_scroll_attributes(int left_scroll,int right_scroll,int centre_cell,char *attrin) {
    char *attr;
    ovs_asprintf(&attr,
            " %s%s%s %s ",
            (centre_cell? "name=centreCell ":""),
            (left_scroll? "onkeyleftset=pgup1 ":""),
            (right_scroll? "onkeyrightset=pgdn1 ":""),

            (attrin != NULL?attrin:""));

    return attr;
}

char *get_empty(char *width_attr,int grid_toggle,int left_scroll,int right_scroll,int centre_cell) {

    char *attr;

    attr=add_scroll_attributes(left_scroll,right_scroll,centre_cell,NULL);

    char *result;

    ovs_asprintf(&result,"\t\t<td %s class=empty%d><a href=\"\" %s></a>\n",
            width_attr,grid_toggle,attr);

    FREE(attr);
    return result;
}


static int use_file_to_url_symlink=0;
void create_file_to_url_symlink() {
    // Create a symlink that gives a remote browse simple access to all
    // files via http://ip:8883/...
    // By default remote browsers can only see /opt/httpd/default and
    // only gaya can see the other media mount points eg /opt/sybhttpd/localhost.drives
    // (becuase sybhttpd checks the headers sent back by the browser (see mini-installer)
    // This link allows /NETWORK_SHARE/path/to/file to be accessed as
    // http://:8883/.network/path/to/file
    //
    // This is a potential security risk so well make it optional
    // Without it - remote browsers  access mounted images by passing them as an argument
    // to oversight.cgi which then 'cats' them to stdout - see main()
    if (!exists(NETWORK_SYMLINK)) {
        symlink(NETWORK_SHARE,NETWORK_SYMLINK);
    }
    use_file_to_url_symlink=1;
}

char *file_to_url(char *path) {
    char *new = NULL;
    assert(path);
    if (g_dimension->local_browser) {
        //If using gaya just go directly to the file system
        ovs_asprintf(&new,"\"file://%s\"",path);

    } else if (util_starts_with(path,"/share/Apps/oversight")) {
        // if /share/Apps/oversight/file/path 
        // then use /oversight/file/path thanks to symlink 
        //  /opt/sybhttpd/default/oversight -> /share/Apps/oversight/
        ovs_asprintf(&new,"\"%s\"",path+11);

    } else if (util_starts_with(path,"/opt/sybhttpd/default")) {
        // if in /opt/sybhttpd/default/file/path
        // then use /file/path
        ovs_asprintf(&new,"\"%s\"",path+21);

    } else if (use_file_to_url_symlink && util_starts_with(path,NETWORK_SHARE)) {
        ovs_asprintf(&new,"\"/.network/%s\"",path+strlen(NETWORK_SHARE));
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


    if (!exists(path) ) {
        result = STRDUP(alt_text);
        html_log(0,"%s doesnt exist",path);
    } else {
        char *img_src = file_to_url(path);
        ovs_asprintf(&result,"<img alt=\"%s\" src=%s %s >",alt_text,img_src,attr);
        FREE(img_src);
    }
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
char *file_style_small(DbRowId *rowid,int grid_toggle) {

    static char grid_class[30];

    sprintf(grid_class," class=grid%cW%d_%d_small ",
            rowid->category,
            rowid->watched!=0,
            grid_toggle & 1);

    return grid_class;
}
int is_fresh(DbRowId *rowid) {
    int result=0;
    long fresh_days;
    if (config_check_long(g_oversight_config,"ovs_new_days",&fresh_days)) {
        if (rowid->date + fresh_days*24*60*60 > time(NULL)) {
            result=1;
        }
    }
    return result;
}

char *watched_style(DbRowId *rowid,int grid_toggle) {

    if (rowid->watched) {
        return " class=watched ";
    } else if (is_fresh(rowid) ) {
        return " class=fresh ";
    } else { 
        return file_style(rowid,grid_toggle);
    }
}
char *watched_style_small(DbRowId *rowid,int grid_toggle) {

    if (rowid->watched) {
        return " class=watched_small ";
    } else if (is_fresh(rowid) ) {
        return " class=fresh_small ";
    } else { 
        return file_style_small(rowid,grid_toggle);
    }
}

char *check_path(char *a,char *b,char *c,char *d) {
    char *p;

    ovs_asprintf(&p,"%s%s%s%s",a,b,c,d);
    if (!exists(p)) {
        html_log(1,"%s doesnt exist",p);
        FREE(p);
        p = NULL;
    } else {
        html_log(1,"%s exist",p);
    }
    return p;
}

char *get_picture_path(int num_rows,DbRowId **sorted_rows,int is_fanart) {

    char *path = NULL;
    DbRowId *rid = sorted_rows[0];
    char *modifier="";

    if (is_fanart) {
        modifier="fanart";
    }

if (1) {
    // First check the filesystem. We do this via the mounted path.
    // This requires that the remote file is already mounted.
    char *file = get_path(rid,rid->file);
    char *dir = util_dirname(file);

    // Find position of file extension.
    char *dot = NULL;
    char saved='\0';;

    // First look for file.modifier.jpg file.modifier.png
    if (rid->ext != NULL) { 
        dot = strrchr(file,'.');
        if (dot) {

            dot++;
            saved=*dot;
            *dot = '\0';
        }
    }


    path=check_path(file,modifier,"jpg","");

    if (path == NULL) path=check_path(file,modifier,"png","");

    if (is_fanart) {
        if (path == NULL) path=check_path(dir,"/",modifier,".jpg");
        if (path == NULL) path=check_path(dir,"/",modifier,".png");
    }
    FREE(file);
    FREE(dir);
}


    if (path == NULL) {
        // No pictures on filesystem - look in db
        int i;
        if (is_fanart) {
            for (i = 0 ;  i < num_rows ; i++ ) {
                path = sorted_rows[i]->fanart;
                if (path) break;
            }
        } else {
            for (i = 0 ;  i < num_rows ; i++ ) {
                path = sorted_rows[i]->poster;
                if (path) break;
            }
        }
        if (path) {
            char *mounted_path = get_path(sorted_rows[i],path);
            FREE(path);
            path = mounted_path;

            if (is_fanart ) {
                char *file;
                if (g_dimension->scanlines == 0 ) {
                    file = replace_all(path,"\\.jpg$",".sd.jpg",0);
                } else {
                    file = replace_all(path,"\\.jpg$",".hd.jpg",0);
                }
                FREE(path);
                path = file;
            }
        }
    }

    return path;

}

char * get_poster_image_tag(DbRowId *rowid,char *attr) {

    assert(rowid);
    assert(attr);
    char *result = NULL;
    
    char *newattr=attr;

    char *path = get_picture_path(1,&rowid,0);

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
        html_log(1,"icon type = %s",icon_type);
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

    if (name) {
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
    }
    return result;
}



char *build_ext_list(DbRowId *row_id) {

    html_log(3,"ext=%s",row_id->ext);
    char *ext_icons = icon_link(row_id->ext);
    html_log(3,"ext_icons=%s",ext_icons);

    DbRowId *ri;
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

        if (rid->watched && strcmp(select,"Mark") == 0) {

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
        html_log(1,"parts ptr = %ld",parts);
        if (parts && parts->size) {
            array_print("movie_listing",parts);
            // Multiple parts
            button_size = g_dimension->button_size * 2 / 3;
        } else {
            // Just one part
            button_size = g_dimension->button_size;
        }

        ovs_asprintf(&button_attr," width=%d height=%d ",button_size,button_size);
        //char *movie_play = get_theme_image_tag("player_play",button_attr);
        FREE(button_attr);

        char *basename=util_basename(rowid->file);

        result=vod_link(rowid,basename,"",rowid->db->source,rowid->file,"0","onkeyleftset=up",style);
        FREE(basename);
        // Add vod links for all of the parts
        
        if (parts && parts->size) {

            int i;
            for(i = 0 ; i < parts->size ; i++ ) {

                char i_str[10];
                sprintf(i_str,"%d",i);

                char *tmp=vod_link(rowid,parts->array[i],"",rowid->db->source,parts->array[i],i_str,"",style);

                char *vod_list;
                ovs_asprintf(&vod_list,"%s<br>\n%s",result,tmp);
                FREE(tmp);
                FREE(result);
                result=vod_list;
            }
        }

        // Big play button
        {
            char *big_play = get_theme_image_tag("player_play","");
            char *play_tvid = get_play_tvid(big_play);
            FREE(big_play);

            char *vod_list;
            ovs_asprintf(&vod_list,"<table><tr><td>%s</td><td>%s</td></table>",play_tvid,result);
            FREE(result);
            result = vod_list;
        }
        //FREE(movie_play);
        return result;
    }
}


int group_count(DbRowId *rid) {
    int i=0;
    for(  ; rid ; rid=rid->linked) {
        i++;
    }
    return i;
}

int unwatched_count(DbRowId *rid) {
    int i=0;
    for(  ; rid ; rid=rid->linked) {
        if (rid->watched == 0) {
            i++;
        }
    }
    return i;
}

char *mouse_or_focus_event(char *title,char *on_event,char *off_event) {
    char *result = NULL;
    ovs_asprintf(&result," %s=\"show('%s');\" %s=\"show('.');\"",on_event,title,off_event);
    return result;
}

char *focus_event(char *title) {
    return mouse_or_focus_event(title,"onfocus","onblur");
}

char *mouse_event(char *title) {
    return mouse_or_focus_event(title,"onmouseover","onmouseout");
}

char *get_poster_mode_item(DbRowId *row_id,int grid_toggle,char **font_class,char **grid_class) {

    char *title = NULL;
    html_log(2,"dbg: tv or movie : set details as jpg");


    char *attr;

    ovs_asprintf(&attr," width=%d height=%d %s ",
        g_dimension->poster_menu_img_width,
        g_dimension->poster_menu_img_height,
        watched_style(row_id,grid_toggle)
        );

    title = get_poster_image_tag(row_id,attr);
    FREE(attr);

    *font_class = "class=fc";
    if (is_fresh(row_id)) {
        *grid_class = "class=gc_fresh";
    } else {
        *grid_class = "class=gc";
    }
    return title;
}

char *get_poster_mode_item_unknown(DbRowId *row_id,int grid_toggle,char **font_class,char **grid_class) {
    html_log(2,"dbg: unclassified : set details as title");
    // Unclassified
    char *title=STRDUP(row_id->title);
    if (strlen(title) > 20) {
        strcpy(title+18,"..");
    }
    if (is_fresh(row_id)) {
        *grid_class = "class=gc_fresh_small";
    } else {
        *grid_class = "class=gc_small";
    }
    *font_class = watched_style(row_id,grid_toggle);
    *grid_class = file_style(row_id,grid_toggle);

    *font_class = watched_style_small(row_id,grid_toggle);
    return title;
}

char *get_text_mode_item(DbRowId *row_id,int grid_toggle,char **font_class,char **grid_class) {
    int tv_or_movie = has_category(row_id);
    // TEXT MODE
    html_log(2,"dbg: get text mode details ");

    *font_class = watched_style(row_id,grid_toggle);
    *grid_class = file_style(row_id,grid_toggle);
   
   char *tmp;
   char *title = trim_title(row_id->title);

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

    if (tv_or_movie) {
        html_log(2,"dbg: add certificate");
        //Add certificate and extension
        char *tmp;
        char *ext_icons=build_ext_list(row_id);
        html_log(2,"dbg: add extension [%s]",ext_icons);

        ovs_asprintf(&tmp,"%s %s %s",
                title,
                (cert?cert:""),
                (ext_icons?ext_icons:""));

        FREE(title);
        title=tmp;
        if (cert != row_id->certificate) FREE(cert);
        FREE(ext_icons);
    }


    if (row_id->category == 'T') {
        html_log(2,"dbg: add episode count");
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
    if (crossview == 1) {
        html_log(2,"dbg: add network icon");
       char *tmp =add_network_icon(row_id->db->source,title);
       FREE(title);
       title = tmp;
    }

    return title;
}


char *get_item(int cell_no,DbRowId *row_id,char *width_attr,int grid_toggle,
        int left_scroll,int right_scroll,int centre_cell) {

    html_log(1,"TODO:Highlight matched bit");

    char *title=NULL;
    char *font_class="";
    char *grid_class="";

    char *select = query_val("select");
    int tv_or_movie = has_category(row_id);

    //Gaya has a navigation bug in which highlighting sometimes misbehaves on links 
    //with multi-lines of text. This was not a problem until the roaming title display
    //was introduced. When the bug triggers all elements become unfocussed causing
    //navigation position to be lost. 
    //To circumvent bug - only the first word of the link is highlighted.
    char *first_space=NULL;

    if (in_poster_mode() ) {
        if (tv_or_movie && row_id->poster != NULL && row_id->poster[0] != '\0' ) {

            title = get_poster_mode_item(row_id,grid_toggle,&font_class,&grid_class);

        } else {
            title = get_poster_mode_item_unknown(row_id,grid_toggle,&font_class,&grid_class);
            first_space = strchr(title,' ');
        }

    } else {

        title = get_text_mode_item(row_id,grid_toggle,&font_class,&grid_class);
        first_space = strchr(title,' ');
    }
    if (first_space) {
        // Truncate even more if the first space does not occur early enough in the title.
        if (first_space - title > 11 ) {
            first_space = title+11;
        }
        *first_space='\0';
    }

    html_log(1,"dbg: details [%s]",title);


    char *cell_text=NULL;
    char *focus_ev = "";
    char *mouse_ev = "";

    if (g_dimension->title_bar) {

        char *simple_title;
        if (row_id->category=='T') {
            ovs_asprintf(&simple_title,"%s S%d",row_id->title,row_id->season);
        } else if (row_id->year) {
            ovs_asprintf(&simple_title,"%s (%d)",row_id->title,row_id->year);
        } else {
            ovs_asprintf(&simple_title,"%s",row_id->title);
        }

        focus_ev = focus_event(simple_title);
        if (!g_dimension->local_browser) {
            mouse_ev = mouse_event(simple_title);
        }
        FREE(simple_title);
    }

    char *title_change_attr;
    ovs_asprintf(&title_change_attr," %s %s" ,(grid_class?grid_class:""), focus_ev);


    char *attr = add_scroll_attributes(left_scroll,right_scroll,centre_cell,title_change_attr);
    FREE(title_change_attr);

    html_log(1,"dbg: scroll attributes [%s]",attr);

    char *idlist = build_id_list(row_id);

//    if (g_dimension->local_browser && g_dimension->title_bar) {
//        first_space=strchr(title,' ');
//        if (first_space) *first_space='\0';
//    }

    if (tv_or_movie) {
        char *params;


        html_log(1,"dbg: id list... [%s]",idlist);

        ovs_asprintf(&params,"view=%s&idlist=%s",
                (row_id->category=='T'?"tv":"movie"),
                idlist);
        html_log(1,"dbg: params [%s]",params);

        

        cell_text = get_self_link_with_font(params,attr,title,font_class);
        html_log(1,"dbg: get_self_link_with_font [%s]",cell_text);

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
        // Convert <a hrefd....><x><y><q>..</q>... ..<z>..</z></y></x></a>
        // To      <a hrefd....><x><y><q>..</q>...</y></x></a><x><y>..<z>..</z></y></x>
    //if (first_space) *first_space=' ';
    FREE(attr);

    if (*select) {
        char *tmp = cell_text;
        tmp=select_checkbox(row_id,cell_text);
        FREE(cell_text);
        cell_text=tmp;
    }


    char *result;

//    if (first_space) {
//        // Adjust first space to show the rest of the title
//        *first_space=' ';
//    } else {
//        //Title has already been shown in full
//        first_space="";
//    }
//
//    if (*first_space) {
//        ovs_asprintf(&result,"\t<td %s %s %s>%s<font class=%s>%s</font></td>",
//                width_attr,grid_class,mouse_ev,
//                cell_text,font_class,first_space);
//    } else {
        ovs_asprintf(&result,"\t<td %s %s %s >%s%s%s</td>",
                width_attr,grid_class,mouse_ev,cell_text,
                (first_space?" ":""),
                (first_space?first_space+1:""));
//    }
    if (mouse_ev && *mouse_ev) FREE(mouse_ev);
    if (focus_ev && *focus_ev) FREE(focus_ev);

    FREE(cell_text);
    FREE(idlist);
    FREE(title); // first_space points inside of title
    return result;
}

char *template_replace_only(char *template_name,char *input,int num_rows,DbRowId **sorted_row_ids);
int template_replace_and_emit(char *template_name,char *input,int num_rows,DbRowId **sorted_row_ids);

#define MACRO_STR_START "["
#define MACRO_STR_END "]"
#define MACRO_STR_START_INNER ":"
#define MACRO_STR_END_INNER ":"
/*
 * if mode=0 only replace simple variables in the buffer.
 * if mode=1 replace complex variables and push to stdout. this is for more complex multi-line macros
 * */
int template_replace(char *template_name,char *input,int num_rows,DbRowId **sorted_row_ids) {

    char *newline=template_replace_only(template_name,input,num_rows,sorted_row_ids);
    if (newline != input) {
        html_log(0,"old line [%s]",input);
        html_log(0,"new line [%s]",newline);
    }
    int count = template_replace_and_emit(template_name,newline,num_rows,sorted_row_ids);
    if (newline !=input) FREE(newline);
    return count;
}

char *template_replace_only(char *template_name,char *input,int num_rows,DbRowId **sorted_row_ids) {

    char *newline = input;
    char *macro_start = NULL;
    int count = 0;


    macro_start = strstr(input,MACRO_STR_START);
    while (macro_start ) {

        char *macro_name_start = NULL;
        char *macro_name_end = NULL;
        char *macro_end = NULL;

        // Check we have MACRO_STR_START .. MACRO_STR_START_INNER MACRO_NAME MACRO_STR_END_INNER .. MACRO_STR_END
        // eg [text1:name:text2]
        // If the macro "name" is non-empty then "text1 macro-out text2" is printed.
        macro_name_start=strstr(macro_start,MACRO_STR_START_INNER);
        if (macro_name_start) {
            macro_name_start++;
            macro_name_end = strstr(macro_name_start,MACRO_STR_END_INNER);
            if (macro_name_end) {
                macro_end=strstr(macro_name_end,MACRO_STR_END);
            }
        }

        // Cant identify macro - advance to next character.
        if (macro_name_start == NULL || macro_name_end == NULL || macro_end == NULL || *macro_name_start != '$'  ) {

            macro_end = macro_start;

        } else {

            int free_result=0;
            *macro_name_end = '\0';
            char *macro_output = macro_call(template_name,macro_name_start,num_rows,sorted_row_ids,&free_result);
            count++;
            *macro_name_end = *MACRO_STR_START_INNER;
            if (macro_output && *macro_output) {


                //convert AA[BB:$CC:DD]EE to AABBnewDDEE

                *macro_start = '\0';   //terminate AA
                 macro_name_start[-1] = '\0';  // terminate BB
                 *macro_end = '\0'; // terminate DD

                 char *tmp;

                 ovs_asprintf(&tmp,"%s%s%s%s%s",newline,macro_start+1,macro_output,macro_name_end+1,macro_end+1);

                 // Adjust the end pointer so it is relative to the new buffer.
                 char *new_macro_end = tmp + strlen(newline)+strlen(macro_start+1)+strlen(macro_output)+strlen(macro_name_end+1);
                 
                 // put back the characters we just nulled.
                 *macro_start = *MACRO_STR_START;
                 macro_name_start[-1] = *MACRO_STR_START_INNER;
                 *macro_end = *MACRO_STR_END;

                 if (free_result) FREE(macro_output);
                 if (newline != input) FREE(newline);
                 newline = tmp;

                 macro_end = new_macro_end;
            } else {
                //convert AA[BB:$CC:DD]EE to AAEE
                char *p=macro_end+1;
                int i = strlen(p)+1;
                memmove(macro_start+1,p,i);
                macro_end = macro_start;

             }
        }

        macro_start=strstr(++macro_end,MACRO_STR_START);

    }
    return newline;
}
int template_replace_and_emit(char *template_name,char *input,int num_rows,DbRowId **sorted_row_ids) {

    char *macro_start = NULL;
    int count = 0;


    char *p = input;
    macro_start = strstr(input,MACRO_STR_START);
    while (macro_start ) {

        char *macro_name_start = NULL;
        char *macro_name_end = NULL;
        char *macro_end = NULL;
        //print bit before macro
        *macro_start='\0';
        printf("%s",p);
        *macro_start=*MACRO_STR_START;

        // Check we have MACRO_STR_START .. MACRO_STR_START_INNER MACRO_NAME MACRO_STR_END_INNER .. MACRO_STR_END
        // eg [text1:name:text2]
        // If the macro "name" is non-empty then "text1 macro-out text2" is printed.
        macro_name_start=strstr(macro_start,MACRO_STR_START_INNER);
        if (macro_name_start) {
            macro_name_start++;
            macro_name_end = strstr(macro_name_start,MACRO_STR_END_INNER);
            if (macro_name_end) {
                macro_end=strstr(macro_name_end,MACRO_STR_END);
            }
        }

        // Cant identify macro - advance to next character.
        if (macro_name_start == NULL || macro_name_end == NULL || macro_end == NULL  ) {

            putc(*MACRO_STR_START,stdout);
            macro_end = macro_start;

        } else {

            int free_result=0;
            *macro_name_end = '\0';
            char *macro_output = macro_call(template_name,macro_name_start,num_rows,sorted_row_ids,&free_result);
            count++;
            *macro_name_end = *MACRO_STR_START_INNER;
            if (macro_output && *macro_output) {

                // Print bit before macro call
                 macro_name_start[-1] = '\0'; 
                 printf("%s",macro_start+1);
                 macro_name_start[-1]=*MACRO_STR_START_INNER;
                 fflush(stdout);

                 printf("%s",macro_output);
                 if (free_result) FREE(macro_output);
                 fflush(stdout);

                 // Print bit after macro call
                 macro_end[0] = '\0';
                 printf("%s",macro_name_end+1);
                 macro_end[0] = *MACRO_STR_END;
                 fflush(stdout);
             }
        }

        p=macro_end+1;

        macro_start=strstr(p,MACRO_STR_START);

    }
    // Print the last bit
    printf("%s",p);
    fflush(stdout);
    return count;
}

char *scanlines_to_text(long scanlines) {
    switch(scanlines) {
        case 1080: return "1080";
        case 720: return "720";
        default: return "sd";
    }
}

void display_template(char*template_name,char *file_name,int num_rows,DbRowId **sorted_row_ids) {

    html_log(1,"begin template");

    char *file;
    ovs_asprintf(&file,"%s/templates/%s/%s.template",appDir(),
            template_name,
            scanlines_to_text(g_dimension->scanlines),
            file_name);
    html_log(2,"opening %s",file);

    FILE *fp=fopen(file,"r");
    if (fp == NULL) {
        if (errno == 2 || errno == 22) {
            FREE(file);
            ovs_asprintf(&file,"%s/templates/%s/any/%s.template",appDir(),
                    template_name,
                    file_name);
            html_log(2,"opening %s",file);
            fp=fopen(file,"r");
        }
        if (fp == NULL) {
            html_error("Error %d opening %s",errno,file);
        }
    }

    if (fp) {
#define HTML_BUF_SIZE 999

        char buffer[HTML_BUF_SIZE+1];

        int is_css = strncmp(file_name,"css.",4) == 0 ;
        int fix_css_bug = is_css && is_local_browser();


        while(fgets(buffer,HTML_BUF_SIZE,fp) != NULL) {
            int count = 0; 
            buffer[HTML_BUF_SIZE] = '\0';
            char *p=buffer;
            while(*p == ' ') {
                p++;
            }
            if ((count=template_replace(template_name,p,num_rows,sorted_row_ids)) != 0 ) {
                html_log(4,"macro count %d",count);
            }

            if (fix_css_bug && strstr(p,"*/") ) {
                printf(".dummy { color:red; }");
            }

        }
        fflush(stdout);
        fclose(fp);
    }

    if (file) FREE(file);
    html_log(1,"end template");
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
        ovs_asprintf(&tmp,"%s<tr>\n",(result?result:""));
        FREE(result);
        result=tmp;

        for ( c = 0 ; c < cols ; c++ ) {
            i = start + c * rows + r ;

            int left_scroll = (page_before && c == 0);
            int right_scroll = (page_after && c == cols-1 );
            int centre_cell = (r == centre_row && c == centre_col);

            char *item=NULL;
            if ( i < numids ) {
                item = get_item(i-start,row_ids[i],width_attr,(r+c) & 1,left_scroll,right_scroll,centre_cell);
            } else {
                item = get_empty(width_attr,(r+c) & 1,left_scroll,right_scroll,centre_cell);
            }
            ovs_asprintf(&tmp,"%s%s\n",result,item);
            FREE(result);
            FREE(item);
            result=tmp;
            html_log(1,"grid end col %d",c);
        }
        
        ovs_asprintf(&tmp,"%s</tr>\n",result);
        FREE(result);
        result=tmp;
        html_log(1,"grid end row %d",r);

    }
    ovs_asprintf(&tmp,"<center><table class=overview_poster%d>\n%s\n</table></center>\n",
            g_dimension->poster_mode,
            result);
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
    html_log(2,"tvid %s = regex %s",sequence,out);
    return out;

}

char *default_button_attr() {
    static char *default_attr = NULL;
    if (default_attr == NULL) {
        ovs_asprintf(&default_attr,"width=%ld height=%ld",g_dimension->button_size,g_dimension->button_size);
        html_log(1,"default button attr = %s",default_attr);
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
    char *result = file_to_url(path);
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
    html_log(1,"Crossview = %ld",crossview);

    //Tvid filter = this as the form 234
    html_hashtable_dump(0,"query",g_query);

    char *regex = get_tvid(query_val(QUERY_PARAM_REGEX));

    if (regex == NULL || !*regex) {
        //Check regex entered via text box

        if (*query_val("searcht") && *query_val(QUERY_PARAM_SEARCH_MODE)) {
            regex=util_tolower(query_val("searcht"));
        }
    }
    html_log(3,"Regex filter = %s",regex);

    // Watched filter
    // ==============
    int watched = DB_WATCHED_FILTER_ANY;
    char *watched_param=query_val(QUERY_PARAM_WATCHED_FILTER);

    if (strcmp(watched_param,QUERY_PARAM_WATCHED_VALUE_YES) == 0) {

        watched=DB_WATCHED_FILTER_YES;

    } else if (strcmp(watched_param,QUERY_PARAM_WATCHED_VALUE_NO) == 0) {

        watched=DB_WATCHED_FILTER_NO;
    }

    html_log(1,"Watched filter = %ld",watched);

    // Tv/Film filter
    // ==============
    char *media_type_str=query_val(QUERY_PARAM_TYPE_FILTER);
    int media_type=DB_MEDIA_TYPE_ANY;

    if(strcmp(media_type_str,QUERY_PARAM_MEDIA_TYPE_VALUE_TV) == 0) {

        media_type=DB_MEDIA_TYPE_TV; 

    } else if(strcmp(media_type_str,QUERY_PARAM_MEDIA_TYPE_VALUE_MOVIE) == 0) {

        media_type=DB_MEDIA_TYPE_FILM; 

    }
    html_log(1,"Media type = %d",media_type);

    
    DbRowSet **rowsets = db_crossview_scan_titles( crossview, regex, media_type, watched);

TRACE;

    if (regex && *regex ) { FREE(regex); regex=NULL; }

    struct hashtable *overview = db_overview_hash_create(rowsets);
TRACE;

    DbRowId **sorted_row_ids = NULL;
    
    char *sort = DB_FLDID_TITLE;

    config_check_str(g_query,"s",&sort);
TRACE;

    if (strcmp(query_val("view"),"tv") == 0) {
TRACE;

        sorted_row_ids = sort_overview(overview,db_overview_cmp_by_title);

    } else  if (sort && strcmp(sort,DB_FLDID_TITLE) == 0) {
TRACE;

        html_log(1,"sort by name [%s]",sort);
        sorted_row_ids = sort_overview(overview,db_overview_cmp_by_title);

    } else {
TRACE;

        html_log(1,"sort by age [%s]",sort);
        sorted_row_ids = sort_overview(overview,db_overview_cmp_by_age);
    }
TRACE;

    int numrows = hashtable_count(overview);
    //Free hash without freeing keys
    db_overview_hash_destroy(overview);

    if (sortedRowsPtr) *sortedRowsPtr = sorted_row_ids;
    if (rowSetsPtr) *rowSetsPtr = rowsets;

    return numrows;
}

void free_sorted_rows(DbRowSet **rowsets,DbRowId **sorted_row_ids) {

TRACE;
    FREE(sorted_row_ids);

    //finished now - so we could just let os free
TRACE;
    db_free_rowsets_and_dbs(rowsets);
TRACE;
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
    tvid_val['9']=tvid_val['w']=tvid_val['x']=tvid_val['y']=tvid_val['z']=9;
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
        char tvid_output[TVID_MAX+2];
        memset(tvid_output,0,TVID_MAX+2); // initially no output

        // Map character to tvid digit.
        int tvid_val[256];
        set_tvid_increments(tvid_val);

        html_log(1,"tvid generation");

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
        *result = '\0';

        int i;
        //char i_str[TVID_MAX_LEN+1];
        char *p = result;

        Array *link_parts=split(link_template,TVID_MARKER,0);
        html_log(-1,"link [%s]",link_template);
        // Split the link_template into two strings - before and after the TVID_MARKER

        for(i = 1 ; i <= TVID_MAX ; i++ ) {
            if (tvid_output[i]) {
                int j;
                p += sprintf(p,"%s",(char *)link_parts->array[0]);
                for(j = 1 ; j <  link_parts->size ;  j++ ) {
                    p += sprintf(p,"%d%s",i,(char *)link_parts->array[j]);
                }
                *p++ = '\n';
                *p = '\0';

                /*
                sprintf(i_str,"%d",i);
                char *link = replace_all(link_template,TVID_MARKER,i_str,0);
                strcpy(p,link);
                FREE(link);
                p=strchr(p,'\0');
                *p++ = '\n';
                *p = '\0';
                */
            }
        }
        array_free(link_parts);
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
        html_log(1,"tvlisting row %d",r);
        char *row_text = NULL;
        for(c = 0 ; c < cols ; c++ ) {
            html_log(1,"tvlisting col %d",c);

            int i = c * rows + r;
            if (i < num_rows) {

                char *title=NULL;
                char *episode_col = NULL;

                DbRowId *rid = sorted_rows[i];

                if (*select) {
                    episode_col = select_checkbox(
                            rid,
                            rid->episode);
                } else {
                    episode_col = vod_link(
                            rid,
                            rid->episode,"",
                            rid->db->source,
                            rid->file,
                            rid->episode,
                            "",
                            watched_style(rid,i%2));
                }

                // Title
                int free_title=0;
                title=rid->eptitle;
                if (title == NULL || !*title) {
                    title=rid->eptitle_imdb;
                }
                if (title == NULL || !*title) {
                    title=rid->additional_nfo;
                }
                if (title == NULL || !*title) {
                    title=util_basename(rid->file);
                    free_title=1;
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
                if (free_title) FREE(title);
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
                char td_class[10];
                sprintf(td_class,"ep%d%d",rid->watched,i%2);
                char *tmp;
                ovs_asprintf(&tmp,"%s<td class=%s width=%d%%>%s</td><td class=%s width=%d%%><font %s>%s</font><font class=epdate>%s</font></td>\n",
                        (row_text?row_text:""),
                        td_class,
                        width1,
                        episode_col,
                        td_class,
                        width2,
                        watched_style(rid,i%2),
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
    ovs_asprintf(&result,"<table width=100%% class=listing>%s</table>",listing);
    FREE(listing);
    return result;
}
char *get_status() {
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
        html_log(1,"Error %d opening [%s]",errno,filename);
    }
    FREE(filename);

    if (result == NULL) {

        if (exists_file_in_dir(tmpDir(),"cmd.pending")) {
            result = STRDUP("[ Catalog update pending ]");
        } else if (db_full_size() == 0 ) {
            result = STRDUP("[ Video index is empty. Select setup icon and scan the media drive ]");
        }
    }

    return result;
}
char *auto_option_list(char *name,char *firstItem,struct hashtable *vals) {

    char *attr;
    if (g_dimension->local_browser) {
        attr="onchange=\"location.assign(this.childNodes[this.selectedIndex].value)\"";
    } else {
        attr="onchange=\"location.assign(this.options[this.selectedIndex].value)\"";
    }
    return option_list(name,attr,firstItem,vals);
}


#define PLACEHOLDER "X@X@X"
char *option_list(char *name,char *attr,char *firstItem,struct hashtable *vals) {
    char *result=NULL;
    char *selected=query_val(name);
    char *params;

    // Do not take ownership of the keys - thay belong to the hashtable.
    Array *keys = util_hashtable_keys(vals,0);
    array_sort(keys,array_strcasecmp);

    ovs_asprintf(&params,"p=&%s=" PLACEHOLDER,name);
    char *link=self_url(params);
    FREE(params);
    Array *link_parts = split(link,PLACEHOLDER,0);
    FREE(link);

    //GAYA does seem to like passing just the options to the link
    //eg just "?a=b"
    //we have to pass a more substantial path. eg. .?a=b
    char *link_prefix;
    if (g_dimension->local_browser) {
        link_prefix = "/oversight/oversight.cgi";
    } else {
        link_prefix = "/oversight/oversight.cgi";
    }

    if (keys && keys->size) {
        int i;


        for(i = 0 ; i < keys->size ; i++ ) {
            char *tmp;
            char *k=keys->array[i];
            char *link=join(link_parts,k);
            //char *link=STRDUP("/oversight/oversig");
            ovs_asprintf(&tmp,
                    "%s<option value=\"%s%s\" %s >%s</option>\n",
                    (result?result:""),
                    link_prefix,
                    link,
                    (strcmp(selected,k)==0?"selected":""),
                k);
            FREE(link);
            FREE(result);
            result=tmp;
        }
    }
    array_free(link_parts);
    if (result) {
        char *tmp;
        ovs_asprintf(&tmp,"<select name=\"%s\" %s>\n<option value=\"./oversight.cgi?\">%s</option>%s</select>",
                name,attr,firstItem,result);
        FREE(result);
        result = tmp;
    }
    array_free(keys);
    return result;
}
