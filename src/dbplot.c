// $Id:$
#include <stdlib.h>
// #include <sys/types.h>
// #include <unistd.h>
#include <stdio.h>
// #include <regex.h>
#include <assert.h>
#include <string.h>
#include <errno.h>
// #include <dirent.h>
// #include <time.h>
// #include <ctype.h>

#include "db.h"
#include "dbplot.h"
#include "gaya_cgi.h"
#include "oversight.h"
#include "array.h"



static void set_plot_positions_by_db(Db *db,int num_rows,DbItem **rows,int start_row,int copy_plot_text);
char *truncate_plot(char *plot,int *free_result);

#define MAX_PLOT_LENGTH 10000
static char* plot_buf = NULL;

FILE *plot_open(Db*db)
{
    char *path = db->plot_file;
    // If it is a remote oversight then read from local copy
    if (util_starts_with(db->plot_file,NETWORK_SHARE)) {
        path = get_crossview_local_copy(db->plot_file,db->source);
    }

    if (db->plot_fp == NULL) {
        db->plot_fp = fopen(path,"r");
        if (db->plot_fp == NULL) {
            html_error("Unable to open plotfile [%s]",path);
        }
    }
    if (path != db->plot_file) FREE(path);

    return db->plot_fp;
}

/**
 * for now we will do a full file scan.
 * If this becomes an issue we will need to build a hashtable 
 * of plotid to filepos. but we only need to pass the file once.
 * if oversight becomes a client-server app then there is more
 * value in creating a plot lookup table.
 */

#define PLOT_KEY_PREFIX "_@"
#define LOG_LVL 1

#define MAX_PLOT_KEY_IDLEN 20
void set_plot_keys(DbItem *item) {

    char id[MAX_PLOT_KEY_IDLEN+1];

    id[0]='\0';

    if(!EMPTY_STR(item->url)) {
        char *tmp = item->url;
        if (util_starts_with(item->url,"http:")) {
            char  *tmp2 = strstr(item->url,"/tt" );
            if (tmp2) tmp = tmp2+1;
        }
        if (util_starts_with(tmp,"tt")) {
            //  If its imdb just copy the identifier
            sprintf(id,"%.9s",tmp);
        } else {
            // it is some value set by catalog.sh - use it
            sprintf(id,"%.*s",MAX_PLOT_KEY_IDLEN,tmp);
        }
    }
    if (id[0]) {

        if (item->category == 'T' ) {

            ovs_asprintf(&(item->plotkey[PLOT_MAIN]),"_@%s@%d@@_",id,item->season);

            if(!EMPTY_STR(item->episode)) {
                ovs_asprintf(&(item->plotkey[PLOT_EPISODE]),"_@%s@%d@%s@_",id,item->season,NVL(item->episode));
            }

        } else {
            ovs_asprintf(&(item->plotkey[PLOT_MAIN]),"_@%s@@@_",id);
        }
    }
    HTML_LOG(1,"plot for %d/%s/%s/%d/%s=[%s][%s]",item->id,item->url,item->title,item->season,item->episode,
            item->plotkey[PLOT_MAIN],item->plotkey[PLOT_EPISODE]);
}

static char *get_plot_by_key_static(DbItem *item,PlotType ptype)
{
    int count=0;

    char *type = (ptype == PLOT_MAIN ? "main" : "episode" );

    char *key = item->plotkey[ptype];

    if (key == NULL) {
        HTML_LOG(1,"No plot for [%s]",item->file);
        return NULL;
    }

    if (!util_starts_with(key,PLOT_KEY_PREFIX)) {
        // If the plot does not start with the PLOT_KEY_PREFIX then assume
        // it is the old format where the plot was embedded in the main index.db file
        HTML_LOG(LOG_LVL,"Using legacy format plot-key = plot for %s=[%s]",item->file,key);
        return key;
    }

    HTML_LOG(LOG_LVL,"Getting %s plot [%s] for [%s]",type,key[ptype],key,item->file);
    char *result = NULL;
    FILE *fp = plot_open(item->db);

    if (fp) {
        if (!plot_buf) plot_buf = MALLOC(MAX_PLOT_LENGTH+1);
        PRE_CHECK_FGETS(plot_buf,MAX_PLOT_LENGTH);
        if (!EMPTY_STR(key)) {
            if (item->plotoffset[ptype] == PLOT_POSITION_UNSET) {

                rewind(fp);
                fseek(fp,0L,SEEK_SET);
                if (fseek(fp,0L,SEEK_SET) != 0) {
                    html_error("Error %d resetting plot file",errno);
                } else {
                    long fpos=0;
                    while(fgets(plot_buf,MAX_PLOT_LENGTH,fp) ) {
                        CHECK_FGETS(plot_buf,MAX_PLOT_LENGTH);

                        count++;

                        chomp(plot_buf);

                        if (util_starts_with(plot_buf,key)) {
                            item->plotoffset[ptype] = fpos + strlen(key);
                            result = plot_buf+strlen(key);
                            break;
                        }
                        fpos = ftell(fp);
                    }
                }
            } else {
                count++;
                HTML_LOG(LOG_LVL,"Direct seek to %ld",item->plotoffset[ptype]);
                fseek(fp,item->plotoffset[ptype],SEEK_SET);
                fgets(plot_buf,MAX_PLOT_LENGTH,fp);
                CHECK_FGETS(plot_buf,MAX_PLOT_LENGTH);
                plot_buf[MAX_PLOT_LENGTH] = '\0';
                chomp(plot_buf);
                result = plot_buf;
            }
        }
    }
    if (result == NULL) {
        HTML_LOG(0,"no plot (%s) for [%s] in %d records",key,item->file,count);
    } else {
        HTML_LOG(LOG_LVL,"got plot (%s) =  [%s] in %d records",key,result,count);
    }
    return result;
}

char *get_plot(DbItem *item,PlotType ptype)
{
    
    if (item->plottext[ptype] == NULL) {
        int free_short_plot;
        set_plot_keys(item);
        char *plot = NVL(get_plot_by_key_static(item,PLOT_MAIN));
        char *short_plot = truncate_plot(plot,&free_short_plot);

        if (free_short_plot) {
            item->plottext[ptype] =  short_plot;
        } else {
            item->plottext[ptype] =  STRDUP(short_plot);
        }
    }
    HTML_LOG(1,"plot=[%s]",item->plottext[ptype]);
    return item->plottext[ptype];
}

char *truncate_plot(char *plot,int *free_result)
{
    char *short_plot = plot;
    *free_result = 0;
    int max = g_dimension->max_plot_length;

    if (!EMPTY_STR(plot) || strlen(plot) > max) {

        char *p = plot + max;
        // search back to a full stop.
        while (p > plot && strchr(".!?",*p) == NULL ) {
            p--;
        }
        *free_result = 1;
        if (p == plot ) {
            // oops gone too far. Just truncate with ellipse
            ovs_asprintf(&short_plot,"%.*s...",max-3,plot);
        } else {
            ovs_asprintf(&short_plot,"%.*s",p-plot+1 ,plot);
        }
    }
    return short_plot;
}

/**
 * Update the plot offset fields for the given rows.
 * Rows may be in different databases so to parse the plot file in one scan
 * we have to scan all the rows in the same database at the same time.
 *
 * so we have two loops on the row id list but resulting on only one sweep
 * of each plot.db file.
 */
#define NEEDS_PLOT(item,ptype) (!EMPTY_STR((item)->url) && !EMPTY_STR((item)->plotkey[ptype]) && (item)->plotoffset[ptype] == PLOT_POSITION_UNSET)

void get_plot_offsets_and_text(int num_rows,DbItem **rows,int copy_plot_text)
{
    int i;
    if (rows != NULL &&  num_rows > 0 ) {
           
TRACE;
        for(i = 0 ; i < num_rows ; i ++ ) {
            DbItem *item = rows[i];
            set_plot_keys(item);
        }
TRACE;
        for(i = 0 ; i < num_rows ; i ++ ) {

            DbItem *item = rows[i];

            if (NEEDS_PLOT(item,PLOT_MAIN) || NEEDS_PLOT(item,PLOT_EPISODE)) {

                Db *db = item->db;

TRACE;
                // Open the database plot file
                set_plot_positions_by_db(db,num_rows,rows,i,copy_plot_text);
TRACE;

            }
            int ptype;
            for (ptype = 0 ; ptype < PLOT_TYPE_COUNT ; ptype++ ) {
                HTML_LOG(LOG_LVL,"plot %d : key[%s] offset[%d] text[%s]",i,
                    item->plotkey[ptype],item->plotoffset[ptype],item->plottext[ptype]);
            }

        }
    }
TRACE;
}

void check_and_copy_plot(int copy_plot_text,DbItem *item,PlotType ptype,long fpos,char *buf) {

    char *key = item->plotkey[ptype];

    if (key && util_starts_with(buf,key)) {

        item->plotoffset[ptype] = fpos + strlen(key);

        if (copy_plot_text) {
            char *in = buf+strlen(key);
            int free_plot;
            char *plot = truncate_plot(in,&free_plot);
            if (!free_plot) {
                plot = STRDUP(plot);
            }
            item->plottext[ptype] = plot;
        }

    }
}

static void set_plot_positions_by_db(Db *db,int num_rows,DbItem **rows,int start_row,int copy_plot_text)
{

    int i;
    FILE *fp = plot_open(db);

    if (fp) {

        fseek(fp,0,SEEK_SET);
        long fpos=0;

        if (!plot_buf) plot_buf = MALLOC(MAX_PLOT_LENGTH+1);
        PRE_CHECK_FGETS(plot_buf,MAX_PLOT_LENGTH);

        while( fgets(plot_buf,MAX_PLOT_LENGTH,fp) != NULL ) {

            CHECK_FGETS(plot_buf,MAX_PLOT_LENGTH);
            chomp(plot_buf);

            if (!util_starts_with(plot_buf,PLOT_KEY_PREFIX)) {
                html_error("Plot too long? %.20s",plot_buf);
                continue;
            }

            for(i = start_row ; i < num_rows ; i ++ ) {

                DbItem *item = rows[i];

                if (item->db == db ) {


                    int ptype;
                    for (ptype = 0 ; ptype < PLOT_TYPE_COUNT ; ptype++ ) {
                        if (NEEDS_PLOT(item,ptype)  && util_starts_with(plot_buf,item->plotkey[ptype])) {

                            check_and_copy_plot(copy_plot_text,item,ptype,fpos,plot_buf);

                            HTML_LOG(1,"Got plot [%s] for [%s]",item->plotkey[ptype],item->file);
                        }
                    }
                }
            }
            fpos=ftell(fp);
        }
    }
TRACE;
}


// vi:sw=4:et:ts=4
