#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>

#include "db.h"
#include "util.h"
#include "gaya_cgi.h"
#include "hashtable.h"
#include "display.h"
#include "hashtable_loop.h"

//Compare a string - numeric compare of numeric parts.
int numstrcmp(char *a,char *b) {
    int anum,bnum;
    char *anext,*bnext;

    HTML_LOG(3,"numstrcmp begin %s=%s",a,b);

    if (a == NULL ) {
        return -(b == NULL);
    } else if (b == NULL) {
        return 1;
    }

    while (*a && *b ) {
        if (isdigit(*a) && isdigit(*b)) {
            anum=strtol(a,&anext,10);
            bnum=strtol(b,&bnext,10);
            if (anum != bnum) {
                return anum-bnum;
            }
            a=anext;
            b=bnext;
        } else if (*a != *b ) {
            return *a - *b;
        }
        a++;
        b++;
    }
    return *a - *b;
}

// This function is inverted to usual sense as we wnat the oldest first.
// This function is just used for sorting the overview AFTER it has been created.
int db_overview_cmp_by_age(DbRowId **rid1,DbRowId **rid2) {
    return (*rid2)->date - (*rid1)->date;
}

#define THE(a) ( ( (a)[0]=='T' || (a)[0]=='t' ) \
        && ( (a)[1]=='h' || (a)[1]=='H' ) \
        && ( (a)[2]=='e' || (a)[2]=='E' ) \
        && (a)[3] == ' ' )

int index_strcmp(char *a,char *b) {
    if (THE(a)) a+= 4;
    if (THE(b)) b+= 4;
    //if (strncasecmp(a,"the ",4)==0) a+= 4;
    //if (strncasecmp(b,"the ",4)==0) b+= 4;
    return strcasecmp(a,b);
}
// This function is just used for sorting the overview AFTER it has been created.
int db_overview_cmp_by_title(DbRowId **rid1,DbRowId **rid2) {

    int c;

    // If titles are different - return comparison
    if ((c=index_strcmp((*rid1)->title,(*rid2)->title)) != 0) {
        return c;
    }

    if ((*rid1)->category == 'T' && (*rid2)->category=='T') {
        // Compare by season

        int d = (*rid1)->season-(*rid2)->season;
        if (d == 0) {
            d = numstrcmp((*rid1)->episode,(*rid2)->episode);
        }
        return d;
    } else {
        // Same title - arbitrary comparison
        return (*rid1) - (*rid2);
    }
}

// overview equality function based on titles only. This is used in boxset mode.
int db_overview_name_eqf(DbRowId *rid1,DbRowId *rid2) {

    if (rid1->category != rid2->category) {
        return 0;
    } else {
        return strcmp(rid1->title,rid2->title) ==0;
    }
}
// overview hash function based on titles only. This is used in boxset mode.
unsigned int db_overview_name_hashf(void *rid) {

    unsigned int h;
    h  = stringhash(((DbRowId *)rid)->title);
    return h;
}


// overview equality function based on titles and season only. This is used in non-boxset mode.
int db_overview_name_season_eqf(DbRowId *rid1,DbRowId *rid2) {

    if (rid1->category != rid2->category) {
        return 0;
    } else if (rid1->category == 'T' ) {
       if (strcmp(rid1->title,rid2->title) != 0) {
          return 0;
       } else {
          return (rid1->season == rid2->season);
       }
    } else {
        //films are equal only if source and file are equal
        return strcmp(rid1->file,rid2->file)==0 && strcmp(rid1->db->source,rid2->db->source) ==0 ;
    }
}
// overview hash function based on titles and season only. This is used in non-boxset mode.
unsigned int db_overview_name_season_hashf(void *rid) {
    unsigned int h;
    h  = stringhash(((DbRowId *)rid)->title);
    if (((DbRowId *)rid)->category == 'T') {
        // tv shows Unique per title/season/category
        h = ( h << 5 ) + h + ((DbRowId *)rid)->season;
    }
    return h;
}
// overview equality function based on titles and season only. This is used in non-boxset mode.
int db_overview_name_season_episode_eqf(DbRowId *rid1,DbRowId *rid2) {

    if (rid1->category != rid2->category) {
        return 0;
    } else if (rid1->category == 'T' ) {
       if (strcmp(rid1->title,rid2->title) != 0) {
          return 0;
       } else if ( rid1->season != rid2->season ) {
           return 0 ;
       } else {
          return strcmp(rid1->episode,rid2->episode) ==0;
       }
    } else {
        return strcmp(rid1->title,rid2->title) ==0;
    }
}
// overview hash function based on titles and season only. This is used in non-boxset mode.
unsigned int db_overview_name_season_episode_hashf(void *rid) {
    unsigned int h;
    h  = stringhash(((DbRowId *)rid)->title);
    if (((DbRowId *)rid)->category == 'T') {
        // tv shows Unique per title/season/category
        h = ( h << 5 ) + h + ((DbRowId *)rid)->season;
        h = ( h << 5 ) + h + stringhash(((DbRowId *)rid)->episode);
    }
    return h;
}
// overview equality function based on file path only. This is used in non-boxset mode.
int db_overview_file_path_eqf(DbRowId *rid1,DbRowId *rid2) {

    return strcmp(rid1->file,rid2->file) ==0 && strcmp(rid1->db->source,rid2->db->source) == 0;
}
// overview hash function based on file path . This is used in non-boxset mode.
unsigned int db_overview_file_path_hashf(void *rid) {
    unsigned int h;
    h  = stringhash(((DbRowId *)rid)->file);
    return h;
}

void overview_dump(int level,char *label,struct hashtable *overview) {
    struct hashtable_itr *itr;
    DbRowId *k;

    if (level <= html_log_level_get()) {
        if (hashtable_count(overview) ) {
            for (itr=hashtable_loop_init(overview) ; hashtable_loop_more(itr,&k,NULL) ; ) {

                HTML_LOG(0,"%s key=[%s][%c %s s%02d]",label,k->db->source,k->category,k->title,k->season);
            }
        } else {
            HTML_LOG(0,"%s EMPTY",label);
        }
    }
}

void overview_array_dump(int level,char *label,DbRowId **arr) {
    if (level <= html_log_level_get()) {
        if (*arr) {
            while (*arr) {
                HTML_LOG(level,"%s key=[%s %c\t%s s%02de%s date:%ll]",label,(*arr)->db->source,(*arr)->category,(*arr)->title,(*arr)->season,(*arr)->episode,(*arr)->date);
                arr++;
            }
        } else {
            HTML_LOG(level,"%s EMPTY",label);
        }
    }
}


struct hashtable *db_overview_hash_create(DbRowSet **rowsets) {
    
    int total=0;
    struct hashtable *overview = NULL;

    char *view=query_val("view");

TRACE;
   
    //Functions used to create the overview hash
    //If boxsets are enabled then the overview should equate all shows with the same season.
    //TODO we need to find a generic image for the box set!
//int (*eq_fn)(DbRowId *rid1,DbRowId *rid2);
//unsigned int (*hash_fn)(void *rid);
    void *eq_fn;
    void *hash_fn;

    if (strcmp(view,VIEW_TV) == 0 || strcmp(view,VIEW_MOVIE) == 0) {
TRACE;

        //At this level equality is based on file name. 
        //This means that duplicate episodes appear twice - which is what we want
        hash_fn = db_overview_file_path_hashf;
        eq_fn = db_overview_file_path_eqf;
        //hash_fn = db_overview_name_season_episode_hashf;
        //eq_fn = db_overview_name_season_episode_eqf;

    } else if (use_boxsets()) {
TRACE;
        if (strcmp(view,VIEW_TVBOXSET) == 0) {
            // BoxSet equality function equates tv shows by name/season
            // if view=tv or file doesnt matter as we have already filtered down past this level
            // but if view = boxset then it matters
            hash_fn = db_overview_name_season_hashf;
            eq_fn = db_overview_name_season_eqf;
        } else {
            // Main menu view Overview equality function equates tv shows by name
            hash_fn = db_overview_name_hashf;
            eq_fn = db_overview_name_eqf;
        }
    } else {
TRACE;
        // Overview equality function equates tv shows by name/season
        hash_fn = db_overview_name_season_hashf;
        eq_fn = db_overview_name_season_eqf;
    }
TRACE;

    //tv Items with the same title/season are the same
    overview = create_hashtable(100,hash_fn,eq_fn);
TRACE;

    int rowset_count=0;
    if (rowsets) {
TRACE;

        DbRowSet **rowset_ptr;
        for(rowset_ptr = rowsets ; *rowset_ptr ; rowset_ptr++ ) {
TRACE;

            int i;
            HTML_LOG(1,"dbg: overview merging rowset[%d]",++rowset_count);

            for( i = 0 ; i < (*rowset_ptr)->size ; i++ ) {

                total++;

TRACE;
                DbRowId *rid = (*rowset_ptr)->rows+i;

                HTML_LOG(2,"dbg: overview merging [%s][%s]",rid->db->source,rid->title);


TRACE;
                DbRowId *match = hashtable_search(overview,rid);
TRACE;

                if (match) {
TRACE;

                    HTML_LOG(1,"overview: match [%s] with [%s]",rid->title,match->title);

                    //Move most recent age to the first overview item
                    if (rid->date > match->date ) {
                        match->date = rid->date;
                    }
//DELETE
//DELETE                    //*If item is unwatched then set overview as unwatched.
//DELETE                    if (rid->watched == 0 ) {
//DELETE                       match->watched = 0;
//DELETE                    }

                    // Add rid to linked list at match->linked
                    rid->linked = match->linked;
                    match->linked = rid;

                } else {
TRACE;

                    HTML_LOG(3,"overview: new entry [%s]",rid->title);
                    hashtable_insert(overview,rid,rid);
                }
TRACE;
                //HTML_LOG(3,"dbg done [%s]",rid->title);
            }
TRACE;
        }
TRACE;
    }
TRACE;
    HTML_LOG(0,"overview: %d entries created from %d records",hashtable_count(overview),total);
    overview_dump(3,"ovw create:",overview);
    return overview;
}



DbRowId **flatten_hash_to_array(struct hashtable *overview) {
    DbRowId **ids = MALLOC((hashtable_count(overview)+1) * sizeof(DbRowId *) );

    struct hashtable_itr *itr;
    DbRowId *k;

    int i = 0;
    for (itr=hashtable_loop_init(overview) ; hashtable_loop_more(itr,&k,NULL) ; ) {

        ids[i++] = k;
    }
    ids[i] = NULL;
    return ids;
}

DbRowId **sort_overview(struct hashtable *overview, int (*cmp_fn)(const void *,const void *)) {

    DbRowId **ids = flatten_hash_to_array(overview);
    int total = hashtable_count(overview);

    HTML_LOG(0,"sorting %d items",total);
    overview_array_dump(3,"ovw flatten",ids);
    qsort(ids,hashtable_count(overview),sizeof(DbRowId *),cmp_fn);
    HTML_LOG(1,"sorted %d items",total);
    overview_array_dump(2,"ovw sorted",ids);

    return ids;
}



void db_overview_hash_destroy(struct hashtable *ovw_hash) {
    hashtable_destroy(ovw_hash,0,0);
}
