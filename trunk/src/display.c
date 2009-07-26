#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <errno.h>

#include "display.h"
#include "gaya_cgi.h"
#include "util.h"
#include "db.h"
#include "dboverview.h"
#include "oversight.h"
#include "hashtable.h"
#include "hashtable_loop.h"
    
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
                    for (p = strstr(new_params,param_name); p ; p=strstr(new_params,p+1) ) {

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

void display_self_link_multi(char *params,char *attr,char *title) {

    assert(params);
    assert(attr);
    assert(title);

    html_log(0," begin self link multi for params[%s] attr[%s] title[%s]",params,attr,title);

    char *url = self_url(params);
    html_log(0," end self link multi [%s]",url);

    printf("<a href=\"%s\" %s>%s</a>",url,attr,title);

    free(url);
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

    display_self_link_multi(params2,attr,text2);

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

void display_filter_bar() {
    printf("filterbar");
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

void display_theme_image_link(char *qlist,char *attr,char *image_name) {
    printf(image_name);
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
    version = replace_all(version,"BETA","b");


    printf("<br><font size=2>V2.%s %s</font>",version,util_hostname());
    td(NULL);

    //-- cell --------------------

    display_sort_cells();

    //- cell ---------------------
    td("");
    display_filter_bar();
    if (g_dimension->local_browser && hashtable_search(g_query,"select") == NULL) {
        build_tvid_list();
    }
    td(NULL);
    //
    //- cell ---------------------
    td("");
    display_status();
    td(NULL);
    //- cell ---------------------
    td("");
    display_theme_image_link("view=admin&action=ask","TVID=SETUP","configure");
    td(NULL);
    printf("</tr></table>");
}

void display_scroll_attributes(int left_scroll,int right_scroll,int centre_cell) {
    if (centre_cell) printf(" name=centreCell ");
    if (left_scroll) printf(" onkeyleftset=pgup1 ");
    if (right_scroll) printf(" onrightleftset=pgdp1 ");
}

void display_empty(char *width_attr,int grid_toggle,int left_scroll,int right_scroll,int centre_cell) {

    printf("\t\t<td %s class=empty%d>",width_attr,grid_toggle);

    printf("<a href=\"\" "); display_scroll_attributes(left_scroll,right_scroll,centre_cell); printf("></a>\n");

    printf("</td>\n");
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

void print_local_image_link(char *path,char *alt_text,char *attr) {

    assert(path);
    assert(alt_text);
    assert(attr);

    char *img_src = local_image_source(path);

    printf("<img alt=\"%s\" src=%s %s >",alt_text,img_src,attr);
    free(img_src);
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

void print_poster_image_tag(DbRowId *rowid,char *attr) {

    assert(rowid);
    assert(attr);
    
    char *newattr=attr;

    char *path = get_poster_path(rowid);

    if (rowid->watched) {
        ovs_asprintf(&newattr," %s %s ",attr,watched_style(rowid,0));
    }

    print_local_image_link(path,rowid->title,newattr);

    if (newattr != attr) {
        free(newattr);
    }
    free(path);
}


void display_item(DbRowId *row_id,char *width_attr,int grid_toggle,
        int left_scroll,int right_scroll,int centre_cell) {

    html_log(0,"TODO:Highlight matched bit");
    printf("\t\t<td %s class=%s>",width_attr,file_style(row_id,grid_toggle));

    if (g_dimension->poster_mode
            && ( row_id->category == 'T' || row_id->category == 'M' )
            && row_id->poster != NULL && row_id->poster[0] != '\0' ) {

        char *attr;
        ovs_asprintf(&attr," width=%d height=%d ",
                g_dimension->poster_menu_img_width,g_dimension->poster_menu_img_height);
        print_poster_image_tag(row_id,attr);
        free(attr);

    } else {

        printf("%s",row_id->title);
        if (row_id->season > 0) {
            printf(" %d",row_id->season);
        }
    }
    
    printf("</td>");
}


void display_template(char*template_name) {
    printf("<body>");
    printf("%s template here",template_name);
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

    if (end > numids) end = numids;

    printf("<table class=overview width=100%%>\n");
    int i = start;
    char *width_attr;

    ovs_asprintf(&width_attr," width=%d%% ",(int)(100/cols));
    for ( r = 0 ; r < rows ; r++ ) {
        printf("<tr>\n");
        for ( c = 0 ; c < cols ; c++ ) {
            i = start + c * rows + r ;

            int left_scroll = (page > 0 && c == 0);
            int right_scroll = (c == cols-1 && numids > start+rows*cols );
            int centre_cell = (r == centre_row && c == centre_col);

            if ( i < numids ) {

                display_item(row_ids[i],width_attr,(r+c) & 1,left_scroll,right_scroll,centre_cell);
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

void display_submit(char *name,char *value) {
    assert(name);
    assert(value);
    printf("<input type=submit name=\"%s\" value=\"%s\" />",name,value);
}

void display_confirm(char *name,char *val_ok,char *val_cancel) {
    printf("<table width=100%%><tr><td align=center>");
    display_submit(name,val_ok);
    printf("</td><td align=center>");
    display_submit(name,val_cancel);
    printf("</td></tr></table>");
}

char *default_button_attr() {
    static char *default_attr = NULL;
    if (default_attr == NULL) {
        ovs_asprintf(&default_attr,"width=%ld height=%ld",g_dimension->button_size,g_dimension->button_size);
        html_log(0,"default button attr = %s",default_attr);
    }
    return default_attr;
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

void display_theme_image_tag(char *image_name,char *attr) {

    char *isrc;
    assert(image_name);
    if (attr == NULL || ! *attr) {

        attr = default_button_attr();
    }
    isrc = icon_source(image_name);
    printf("<img alt=\"%s\" border=0 src=%s %s />",image_name,isrc,attr);
    free(isrc);
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

            display_theme_image_link(params,attrs,image_base_name);
            free(params);
            free(attrs);
        } else if (! *view ) {
            //Only show disabled page controls in main menu view (not tv / movie subpage) - this may change
            char *image_off=NULL;
            ovs_asprintf(&image_off,"%s-off",image_base_name);
            display_theme_image_tag(image_off,NULL);
            free(image_off);
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

    printf("<td width=10%%>");
    display_page_control(q_select,q_view,page,prev_page,-1,"pgup","left");
    printf("</td>");

    if (*q_view && *q_select) {
        printf("<td align=center>");
        display_theme_image_link("view=&idlist=","name=up","back");
        printf("</td>");
    }

    printf("<td align=center>");
    if (! *q_view) {
        if(hashtable_count(g_query) == 0 && g_dimension->local_browser) {
            printf("<a href=\"/start.cgi\" name=home >");
            display_theme_image_tag("exit",NULL);
            printf("</a>");
        } else {
            printf("<a href=\"%s?\" name=home TVID=HOME >",SELF_URL);
            display_theme_image_tag("home",NULL);
            printf("</a>");
        }
    }

    if (! *q_select) {
    } else {
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


    printf("<td width=10%%>");
    display_page_control(q_select,q_view,page,next_page,1,"pgdn","right");
    printf("</td>");



    printf("</tr></table>");
}

void display_menu() {

    char *start_cell;
    // Get filter options
    long crossview=0;

    if (config_check_str(g_query,QUERY_PARAM_REGEX,&start_cell)) {
        start_cell="filter5";
    } else {
        start_cell="centreCell";
    }


    printf("<body onloadset=%s focuscolor=yellow focustext=black class=local%ld >",
            start_cell,g_dimension->local_browser);

    config_check_long(g_oversight_config,"ovs_crossview",&crossview);
    html_log(0,"Crossview = %ld",crossview);

    //Tvid filter = this as the form 234
    html_log(0,"search query...");
    hashtable_dump("query",g_query);
    char *name_filter=hashtable_search(g_query,"_rt"); 
    html_log(0,"done search query");
    char *regex = NULL;
    if (name_filter) {
        html_log(2,"getting tvid..");
        regex = get_tvid(name_filter);
    } else {
        //Check regex entered via text box
        html_log(2,"getting regex..");
        regex=hashtable_search(g_query,"searcht");
        if (regex) {
            html_log(2,"lc regex..");
            regex=util_tolower(regex);
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


    if (regex) { free(regex); regex=NULL; }

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

    long page;
    if (!config_check_long(g_query,"p",&page)) {
        page = 0;
    }
    display_header(media_type);
    display_grid(page,hashtable_count(overview),sorted_row_ids);
    display_nav_buttons(page,
            page>0,
            (page+1)*g_dimension->rows*g_dimension->cols < hashtable_count(overview));

    printf("</body>");
    db_overview_hash_destroy(overview);

    free(sorted_row_ids);

    //finished now - so we could just let os free
    db_free_rowsets_and_dbs(rowsets);

}

void display_dynamic_styles() {

    long font_size = g_dimension->font_size;
    long small_font = font_size - 2;
    char *view;

    if (!config_check_str(g_query,"view",&view)) {
        view="";
    }
    assert(view);

    printf(".dummy {};"); //bug in gaya - ignores style after comment
    printf(".recent { font-size:%ld; }",font_size);
    printf("td { font-size:%ld; font-family:\"arial\";  }",font_size);

    if (strcmp(view,"movie")==0 || strcmp(view,"tv") ==0 ) {
        printf("font.plot { font-size:%ld ; font-weight:normal; }",small_font); 
        // watched/Unwatched tv
        printf("td.ep10 { background-color:#222222; font-weight:bold; font-size:%ld; }",small_font);
        printf("td.ep11 { background-color:#111111; font-weight:bold; font-size:%ld; }",small_font);
        printf("td.ep00 { background-color:#004400; font-weight:bold; font-size:%ld; }",small_font);
        printf("td.ep01 { background-color:#003300; font-weight:bold; font-size:%ld; }",small_font);
        printf(".eptitle { font-size:100%% ; font-weight:normal; font-size:%ld; }",small_font);

        printf("h1 { text-align:center; font-size:%ld; font-weight:bold; color:#FFFF00; }"
                ,g_dimension->title_size);

        printf(".label { color:red }");
    } else {
        printf(".scanlines%ld {color:#FFFF55; font-weight:bold; }",g_dimension->scanlines);
    }
}

