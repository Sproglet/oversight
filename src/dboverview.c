#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "db.h"
#include "util.h"
#include "gaya_cgi.h"
#include "hashtable.h"
#include "display.h"
#include "hashtable_loop.h"

// This function is inverted to usual sense as we wnat the oldest first.
// This function is just used for sorting the overview AFTER it has been created.
int db_overview_cmp_by_age(DbRowId **rid1,DbRowId **rid2) {
    return (*rid2)->date - (*rid1)->date;
}

int index_strcmp(char *a,char *b) {
    if (strncasecmp(a,"the ",4)==0) a+= 4;
    if (strncasecmp(b,"the ",4)==0) b+= 4;
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

        return ( 
                (((*rid1)->season*1000)+(*rid1)->episode) 
                - (((*rid2)->season*1000)+(*rid2)->episode)
               );
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
        return strcmp(rid1->title,rid2->title) ==0;
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
       } else {
          return ((rid1->season<<9)+rid1->episode) == ((rid2->season<<9)+rid2->episode);
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
        h = ( h << 5 ) + h + ((DbRowId *)rid)->episode;
    }
    return h;
}

void overview_dump(int level,char *label,struct hashtable *overview) {
    struct hashtable_itr *itr;
    DbRowId *k;

    if (level <= html_log_level_get()) {
        if (hashtable_count(overview) ) {
            for (itr=hashtable_loop_init(overview) ; hashtable_loop_more(itr,&k,NULL) ; ) {

                html_log(1,"%s key=[%c %s s%02d]",label,k->category,k->title,k->season);
            }
        } else {
            html_log(1,"%s EMPTY",label);
        }
    }
}

void overview_array_dump(int level,char *label,DbRowId **arr) {
    if (level <= html_log_level_get()) {
        if (*arr) {
            while (*arr) {
                html_log(level,"%s key=[%c\t%s s%02de%02d date:%d]",label,(*arr)->category,(*arr)->title,(*arr)->season,(*arr)->episode,(*arr)->date);
                arr++;
            }
        } else {
            html_log(level,"%s EMPTY",label);
        }
    }
}


struct hashtable *db_overview_hash_create(DbRowSet **rowsets) {
    
    int total=0;
    struct hashtable *overview = NULL;

    char *view=query_val("view");
   
    //Functions used to create the overview hash
    //If boxsets are enabled then the overview should equate all shows with the same season.
    //TODO we need to find a generic image for the box set!
//int (*eq_fn)(DbRowId *rid1,DbRowId *rid2);
//unsigned int (*hash_fn)(void *rid);
    void *eq_fn;
    void *hash_fn;

    if (strcmp(view,"tv") == 0 || strcmp(view,"movie") == 0) {

        hash_fn = db_overview_name_season_episode_hashf;
        eq_fn = db_overview_name_season_episode_eqf;

    } else if (use_boxsets()) {
        if (strcmp(view,"tvboxset") == 0) {
            // BoxSet equality function equates tv shows by name/season
            // if view=tv or file doesnt matter as we have already filtered down past this level
            // but if view = boxset then it matters
            hash_fn = db_overview_name_season_hashf;
            eq_fn = db_overview_name_season_eqf;
        } else {
            // Overview equality function equates tv shows by name
            hash_fn = db_overview_name_hashf;
            eq_fn = db_overview_name_eqf;
        }
    } else {
        // Overview equality function equates tv shows by name/season
        hash_fn = db_overview_name_season_hashf;
        eq_fn = db_overview_name_season_eqf;
    }

    //tv Items with the same title/season are the same
    overview = create_hashtable(100,hash_fn,eq_fn);

    DbRowSet **rowset_ptr;
    for(rowset_ptr = rowsets ; *rowset_ptr ; rowset_ptr++ ) {

        int i;
        for( i = 0 ; i < (*rowset_ptr)->size ; i++ ) {

            total++;

            DbRowId *rid = (*rowset_ptr)->rows+i;

            //html_log(2,"dbg: overview merging [%s]",rid->title);

            DbRowId *match = hashtable_search(overview,rid);

            if (match) {

                html_log(0,"overview: match [%s] with [%s]",rid->title,match->title);

                //Move most recent age to the first overview item
                if (rid->date > match->date ) {
                    match->date = rid->date;
                }

                //*If item is unwatched then set overview as unwatched.
                if (rid->watched == 0 ) {
                   match->watched = 0;
                }

                // Add rid to linked list at match->linked
                rid->linked = match->linked;
                match->linked = rid;

            } else {

                html_log(2,"overview: new entry [%s]",rid->title);
                hashtable_insert(overview,rid,rid);
            }
            //html_log(2,"dbg done [%s]",rid->title);
        }
    }
    html_log(0,"overview: %d entries created from %d records",hashtable_count(overview),total);
    overview_dump(4,"ovw create:",overview);
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

    html_log(0,"sorting %d items",hashtable_count(overview));
    overview_array_dump(4,"ovw flatten",ids);
    qsort(ids,hashtable_count(overview),sizeof(DbRowId *),cmp_fn);
    html_log(0,"sorted %d items",hashtable_count(overview));
    overview_array_dump(1,"ovw sorted",ids);

    return ids;
}



void db_overview_hash_destroy(struct hashtable *ovw_hash) {
    hashtable_destroy(ovw_hash,0,0);
}
