#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "display.h"
#include "gaya_cgi.h"
#include "util.h"
#include "db.h"
#include "dboverview.h"
#include "oversight.h"
    
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


void display_sort_cells() {
    td("");
    printf("Sort cells here");
    td(NULL);
}

void display_filter_bar() {
    printf("filterbar");
}

void display_status() {
    printf("status");
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

    sprintf(grid_class,"grid%cW%d_%d",
            row_id->category,
            row_id->watched!=0,
            grid_toggle & 1);

    return grid_class;
}
char *watched_style(DbRowId *rowid,int grid_toggle) {

    if (rowid->watched) {
        return "watched";
    } else { 
        long fresh_days;
        if (config_check_long(g_oversight_config,"ovs_new_days",&fresh_days)) {
            if (rowid->age + fresh_days*24*60*60 > time(NULL)) {
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
        ovs_asprintf(&newattr," %s border=2 class=fresh ",attr);
    }

    print_local_image_link(path,rowid->title,newattr);

    if (newattr != attr) {
        free(newattr);
    }
    free(path);
}


void display_item(DbRowId *row_id,char *width_attr,int grid_toggle,
        int left_scroll,int right_scroll,int centre_cell) {

    char grid_class[16];

    sprintf(grid_class,"grid%cW%d_%d",
            row_id->category,
            row_id->watched!=0,
            grid_toggle & 1);


    html_log(0,"TODO:Highlight matched bit");
    printf("\t\t<td %s class=%s>",width_attr,grid_class);

    if (g_dimension->poster_mode
            && ( row_id->category == 'T' || row_id->category == 'M' )
            && row_id->poster != NULL && row_id->poster[0] != '\0' ) {

        char *attr;
        ovs_asprintf(&attr," width=%d height=%d ",g_dimension->poster_menu_img_width,g_dimension->poster_menu_img_height);
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
    printf("%s template here",template_name);
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
void display_menu() {

    // Get filter options
    long crossview=0;

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
    long watched_param;
    int watched = DB_WATCHED_FILTER_ANY;

    if (config_check_long(g_query,"_wf",&watched_param)) {
        if (watched_param) {
            watched=DB_WATCHED_FILTER_YES;
        } else {
            watched=DB_WATCHED_FILTER_NO;
        }
    }
    html_log(0,"Watched filter = %ld",watched);

    // Tv/Film filter
    char *media_type_str=NULL;
    int media_type=DB_MEDIA_TYPE_ANY;

    if (config_check_str(g_query,"_tf",&media_type_str)) {
        switch(*media_type_str) {
            case 'T': media_type=DB_MEDIA_TYPE_TV; break ;
            case 'F': media_type=DB_MEDIA_TYPE_FILM; break ;
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
    display_footer();

    db_overview_hash_destroy(overview);

    free(sorted_row_ids);

    //finished now - so we could just let os free
    db_free_rowsets_and_dbs(rowsets);

}

