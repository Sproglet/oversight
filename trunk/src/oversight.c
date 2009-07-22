/* (c) 2009 Andrew Lord - GPL V3 */

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>

#include "hashtable.h"
#include "util.h"
#include "gaya_cgi.h"
#include "config.h"
#include "db.h"
#include "dboverview.h"

void embed_stylesheet();
void exec_old_cgi(int argc,char **argv);
char *get_tvid( char *sequence );

void load_configs (struct hashtable **oversight_config,struct hashtable **catalog_config,struct hashtable **nmt_settings) {
    html_comment("load ovs config");
    *oversight_config =
        config_load_wth_defaults(appDir(),"oversight.cfg.example","oversight.cfg");

    html_comment("load catalog config");
    *catalog_config =
        config_load_wth_defaults(appDir(),"catalog.cfg.example","catalog.cfg");

    html_comment("load nmt settings");
    *nmt_settings = config_load("/tmp/setting.txt");

}


void tv_submenu(struct hashtable *query,
        struct hashtable *oversight_config,
        struct hashtable *catalog_config,
        struct hashtable *nmt_settings,
        Dimensions *dimensions,
        int argc,char **argv) {




}

void movie_submenu(struct hashtable *query,
        struct hashtable *oversight_config,
        struct hashtable *catalog_config,
        struct hashtable *nmt_settings,
        Dimensions *dimensions,
        int argc,char **argv) {








}

void menu(struct hashtable *query,
        struct hashtable *oversight_config,
        struct hashtable *catalog_config,
        struct hashtable *nmt_settings,
        Dimensions *dimensions,
        int argc,char **argv) {

    // Get filter options
    long crossview=0;

    config_check_long(oversight_config,"ovs_crossview",&crossview);
    html_log(0,"Crossview = %ld",crossview);

    //Tvid filter = this as the form 234
    char *name_filter=hashtable_search(query,"_rt"); 
    char *regex = NULL;
    if (name_filter) {
        html_log(2,"getting tvid..");
        regex = get_tvid(name_filter);
    } else {
        //Check regex entered via text box
        html_log(2,"getting regex..");
        regex=hashtable_search(query,"searcht");
        if (regex) {
            html_log(2,"lc regex..");
            regex=util_tolower(regex);
        }
    }
    html_log(0,"Regex filter = %s",regex);

    // Watched filter
    long watched_param;
    int watched = DB_WATCHED_FILTER_ANY;

    if (config_check_long(query,"_wf",&watched_param)) {
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

    if (config_check_str(query,"_tf",&media_type_str)) {
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

    config_check_str(query,"s",&sort);

    html_log(0,"sort by [%s]",sort);

    if (strcmp(sort,DB_FLDID_TITLE) == 0) {
        sorted_row_ids = sort_overview(overview,db_overview_cmp_by_title);
    } else {
        sorted_row_ids = sort_overview(overview,db_overview_cmp_by_age);
    }

    int i;
    for(i = 0 ; i < hashtable_count(overview) ; i++ ) {

        DbRowId *rid = sorted_row_ids[i];
        html_log(0,"sorted [%s]",rid->title);
    }

    db_overview_hash_destroy(overview);

    free(sorted_row_ids);

    //finished now - so we could just let os free
    db_free_rowsets_and_dbs(rowsets);


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

// nmt css links dont work properly - so embed the stylesheet.
#define CSS_BUFSIZ 200
void embed_stylesheet() {
    char *css;
    FILE *fp;
    ovs_asprintf(&css,"%s/oversight.css",appDir());
    if ((fp=fopen(css,"r")) != NULL) {
        char buffer[CSS_BUFSIZ];
        while(fgets(buffer,CSS_BUFSIZ,fp)) {
            printf("%s",buffer);
        }
    }
    free(css);
}

#define PLAYLIST "/tmp/playlist.htm"
void clear_playlist() {
    truncate(PLAYLIST,0);
}

void exec_old_cgi(int argc,char **argv);

int main(int argc,char **argv) {

    int result=0;

    html_log_level_set(3);

    printf("Content-Type: text/html\n\n");

    html_comment("Appdir= [%s]",appDir());

    //array_unittest();
    //util_unittest();
    //config_unittest();

    struct hashtable *query=parse_query_string(getenv("QUERY_STRING"),NULL);

    struct hashtable *post=read_post_data(getenv("TEMP_FILE"));

    html_comment("merge query and post data");
    merge_hashtables(query,post,0); // post is destroyed

    // Run the old cgi script for admin functions
    // This will be phased out as the admin functions are brought in.
    char *view=hashtable_search(query,"view");  

    /*
     * For functions that are not yet ported - run the old script.
     */
    if (view && strcmp(view,"admin") == 0) {        //TODO Delete when code finished
        exec_old_cgi(argc,argv);                    //TODO Delete when code finished
    } else if (view && strcmp(view,"tv") == 0) {    //TODO Delete when code finished
        exec_old_cgi(argc,argv);                    //TODO Delete when code finished
    } else if (view && strcmp(view,"movie") == 0) { //TODO Delete when code finished
        exec_old_cgi(argc,argv);                    //TODO Delete when code finished
    }


    struct hashtable *oversight_config;
    struct hashtable *catalog_config;
    struct hashtable *nmt_settings;
    Dimensions dimensions;

    load_configs(&oversight_config,&catalog_config,&nmt_settings);

    config_read_dimensions(oversight_config,nmt_settings,&dimensions);

    embed_stylesheet();
/*
    doActions(query);
*/

    if (view && strcmp(view,"tv") == 0) {

        tv_submenu(query,oversight_config,catalog_config,nmt_settings,&dimensions,argc,argv);

    } else if (view && strcmp(view,"movie") == 0) {

        movie_submenu(query,oversight_config,catalog_config,nmt_settings,&dimensions,argc,argv);

    } else {

        menu(query,oversight_config,catalog_config,nmt_settings,&dimensions,argc,argv);
    }

    /*
    html_comment("dump shit");
    html_hashtable_dump(3,"ovs cfg",oversight_config);
    html_hashtable_dump(3,"catalog cfg",catalog_config);
    html_hashtable_dump(3,"settings",nmt_settings);
    */
    hashtable_destroy(oversight_config,1,1);
    hashtable_destroy(catalog_config,1,1);
    hashtable_destroy(nmt_settings,1,1);
    hashtable_destroy(query,1,0);

    /*
    hashtable database_list= open_databases(query);

    display_page(query,database_list);
    */

    return result;
    
}

void exec_old_cgi(int argc,char **argv) {
    char *old_cgi;
    char **args = MALLOC((argc+1) * sizeof(char *));
    int i,j=0;

    for(i = 0 ; i < argc ; i++ ) {
        args[j++] = argv[i];
    }
    args[j]=NULL;

    ovs_asprintf(&old_cgi,"%s/%s",appDir(),"oversight_old.cgi");
    if (execv(old_cgi,args) != 0) {
        int e = errno;
        html_error("Failed to launch [%s] error %d",old_cgi,e);
        exit(e);
    }
}




