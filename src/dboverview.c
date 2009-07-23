#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "db.h"
#include "util.h"
#include "gaya_cgi.h"
#include "hashtable.h"
#include "hashtable_loop.h"

unsigned int db_overview_hashf(void *rid) {
    unsigned int h;
    if (((DbRowId *)rid)->category == 'T') {
        // tv shows Unique per title/season/category
        h  = stringhash(((DbRowId *)rid)->title);
        h = ( h << 5 ) + h + ((DbRowId *)rid)->season;
    } else {
        // Anything else is unique
        h = (int)rid;
    }
    return h;
}

int db_overview_cmp_by_age(DbRowId **rid1,DbRowId **rid2) {
    return (*rid1)->date - (*rid2)->date;
}

int db_overview_cmp_by_title(DbRowId **rid1,DbRowId **rid2) {

    int c;
    // If titles are different - return comparison
    if ((c=strcmp((*rid1)->title,(*rid2)->title)) != 0) {
        return c;
    }

    if ((*rid1)->category == 'T' && (*rid2)->category=='T') {
        // Compare by season
        return ((*rid1)->season - (*rid2)->season);
    } else {
        // Same title - arbitrary comparison
        return (*rid1) - (*rid2);
    }
}
int db_overview_name_eqf(void *rid1,void *rid2) {
    return db_overview_cmp_by_title(&rid1,&rid2) == 0;
}

void overview_dump(char *label,struct hashtable *overview) {
    struct hashtable_itr *itr;
    DbRowId *k;

    if (hashtable_count(overview) ) {
        for (itr=hashtable_loop_init(overview) ; hashtable_loop_more(itr,&k,NULL) ; ) {

            html_log(1,"%s key=[%c %s s%02d]",label,k->category,k->title,k->season);
        }
    } else {
        html_log(1,"%s EMPTY",label);
    }
}

void overview_array_dump(char *label,DbRowId **arr) {
    if (*arr) {
        while (*arr) {
            html_log(1,"%s key=[%c\t%s\ts%02d\t%d]",label,(*arr)->category,(*arr)->title,(*arr)->season,(*arr)->date);
            arr++;
        }
    } else {
        html_log(1,"%s EMPTY",label);
    }
}


struct hashtable *db_overview_hash_create(DbRowSet **rowsets) {
    
    int total=0;
    struct hashtable *overview = create_hashtable(100,db_overview_hashf,db_overview_name_eqf);
    DbRowSet **rowset_ptr;
    for(rowset_ptr = rowsets ; *rowset_ptr ; rowset_ptr++ ) {

        int i;
        for( i = 0 ; i < (*rowset_ptr)->size ; i++ ) {

            total++;

            DbRowId *rid = (*rowset_ptr)->rows+i;

            DbRowId *match = hashtable_search(overview,rid);

            if (match) {

                html_log(0,"overview: match [%s] with [%s]",rid->title,match->title);
                // Add rid to linked list at match->linked
                rid->linked = match->linked;
                match->linked = rid;

            } else {

                html_log(0,"overview: new entry [%s]",rid->title);
                hashtable_insert(overview,rid,rid);
            }
        }
    }
    html_log(0,"overview: %d entries created from %d records",hashtable_count(overview),total);
    overview_dump("ovw create:",overview);
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
    overview_array_dump("ovw flatten",ids);
    qsort(ids,hashtable_count(overview),sizeof(DbRowId *),cmp_fn);
    overview_array_dump("ovw sorted",ids);

    return ids;
}



void db_overview_hash_destroy(struct hashtable *ovw_hash) {
    hashtable_destroy(ovw_hash,0,0);
}
