// $Id:$
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <assert.h>

#include "oversight.h"
#include "db.h"
#include "dboverview.h"
#include "util.h"
#include "gaya_cgi.h"
#include "hashtable.h"
#include "display.h"
#include "hashtable_loop.h"

#define IMDB_GROUP_MAX_SIZE 50
#define IMDB_GROUP_SEP ','
#define IMDB_GROUP_BASE 128

static inline int in_same_db_imdb_group(DbItem *item1,DbItem *item2,MovieBoxsetMode movie_boxset_mode);

DbGroupIMDB *db_group_imdb_new(
        int size,      // max number of imdb entries 0 = IMDB_GROUP_MAX_SIZE
        char *prefix   // IMDB id prefix tt or nm - do not free
)
{
    if (size == 0) {
        size = IMDB_GROUP_MAX_SIZE;
    }
    DbGroupIMDB *g = MALLOC(sizeof(DbGroupIMDB));
    memset(g,0,sizeof(DbGroupIMDB));

    int *list = CALLOC(size,sizeof(int));

    g->dbgi_max_size = size;
    g->dbgi_size = 0;
    g->dbgi_ids = list;
    g->prefix = prefix;
    g->dbgi_sorted = 1; // Start off sorted.



    return g;
}
void db_group_imdb_free(DbGroupIMDB *g,int free_parent)
{
    if (g) {
        FREE(g->dbgi_ids);
        if (free_parent) {
            FREE(g);
        }
    }
}

int in_db_custom_group(DbItem *item,DbGroupCustom *g)
{
    html_error("in_db_custom_group not implemented");
    return 0;
}

int in_db_name_season_group(DbItem *item,DbGroupNameSeason *g)
{
    int result = 0 ;
    if (item->category == 'T' ) {
        if (g->season <= 0 || g->season == item->season) {
            result = STRCMP(g->name,item->title) == 0;
        }
    }
    return result;
}

#define IN_SORTED_IMDB_LIST(id,g) (bchop((id),(g)->dbgi_size,(g)->dbgi_ids) >= 0)


int in_unsorted_imdb_list(int id,DbGroupIMDB *g)
{
    int i;
    for(i = 0 ; i < g->dbgi_size ; i ++ ) { 
        if (g->dbgi_ids[i] == id) return 1;
    }
    return 0;
}

int id_in_db_imdb_group(int id,DbGroupIMDB *g)
{
    int result=0;
    if (g) {
        EVALUATE_GROUP(g);
        if (g->dbgi_sorted) {
            result = IN_SORTED_IMDB_LIST(id,g);
        } else {
            result = in_unsorted_imdb_list(id,g);
        }
    }
    return result;
}

int in_db_imdb_group(DbItem *item,DbGroupIMDB *g)
{
    int result = 0 ;
    if (g && item->external_id ) {
        EVALUATE_GROUP(g);
        if (g->dbgi_sorted) {
            result = IN_SORTED_IMDB_LIST(item->external_id,g);
        } else {
            result = in_unsorted_imdb_list(item->external_id,g);
        }
    } 
    return result;
}

int in_db_group(DbItem *item,DbGroupDef *g)
{
    int result = 0;
    switch(g->dbg_type) {
        case DB_GROUP_BY_CUSTOM_TAG:
            result = in_db_custom_group(item,&(g->u.dbgc));
        case DB_GROUP_BY_NAME_TYPE_SEASON:
            result = in_db_name_season_group(item,&(g->u.dbgns));
        case DB_GROUP_BY_IMDB_LIST:
            result = in_db_imdb_group(item,&(g->u.dbgi));
        default:
            assert(0);
    }
    return result;
}

//Compare a string - numeric compare of numeric parts.
int numSTRCMP(char *a,char *b) {
    int anum,bnum;
    char *anext,*bnext;

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
int db_overview_cmp_by_age_desc(DbItem **item1,DbItem **item2)
{
    //return (*item2)->date - (*item1)->date;
    return *timestamp_ptr(*item2)- *timestamp_ptr(*item1);
}
// This function is just used for sorting the overview AFTER it has been created.
int db_overview_cmp_by_year_asc(DbItem **item1,DbItem **item2)
{
    int ret;
    ret = (*item1)->year - (*item2)->year;
    if (ret == 0) {
        // Compare imdb ids if movie in the same year - eg Matrix Reloaded/Revolution
        ret = (*item1)->external_id - (*item2)->external_id;
    }
    return ret;
}
// This function is just used for sorting the overview AFTER it has been created.
int db_overview_cmp_by_season_asc(DbItem **item1,DbItem **item2)
{
    return (*item1)->season - (*item2)->season;
}


// This function is just used for sorting the overview AFTER it has been created.
int db_overview_cmp_by_title(DbItem **item1,DbItem **item2) {

    int c;

    // If titles are different - return comparison
    if ((c=index_STRCMP(NVL((*item1)->title),NVL((*item2)->title))) != 0) {
        return c;
    }

    if ((*item1)->category == 'T' && (*item2)->category=='T') {
        // Compare by season

        int d = (*item1)->season-(*item2)->season;
        if (d == 0) {
            d = numSTRCMP(NVL((*item1)->episode),NVL((*item2)->episode));
        }
        return d;
    } else {
        // Same title - arbitrary comparison
        return (*item1) - (*item2);
    }
}

// overview equality function based on titles only. This is used in boxset mode.
int db_overview_name_eqf(DbItem *item1,DbItem *item2) {

    if (item1->category != item2->category) {
        return 0;
    } else {
        return STRCMP(item1->title,item2->title) ==0;
    }
}
// overview hash function based on titles only. This is used in boxset mode.
unsigned int db_overview_name_hashf(void *item) {

    unsigned int h;
    h  = stringhash(((DbItem *)item)->title);
    return h;
}



// Compare numeric field of records. (casting void* to DbItem*)
#define EQ_NUM(item1,item2,fld) (((DbItem*)(item1))->fld == ((DbItem*)(item2))->fld)

// Compare string field of records. (casting void* to DbItem*)
#define EQ_STR(item1,item2,fld) (STRCMP(((DbItem*)(item1))->fld,((DbItem*)(item2))->fld) ==0)

// true if two records have the same file. (should never happen really so just return 0
//#define EQ_FILE(item1,item2) EQ_NUM(item1,item2,db) && EQ_STR(item1,item2,file) && EQ_SHOW(item1,item2,source)
#define EQ_FILE(item1,item2) (item1 == item2)

#define EQ_MOVIE(item1,item2) EQ_NUM(item1,item2,db) && EQ_NUM(item1,item2,external_id)

// true if two records are part of the same show. Assuemes category=T already tested.
#define EQ_SHOW(item1,item2) (EQ_NUM(item1,item2,year) && EQ_STR(item1,item2,title))

// true if two records are part of the same season. Assuemes category=T already tested.
#define EQ_SEASON(item1,item2) (EQ_NUM(item1,item2,season) && EQ_SHOW((item1),(item2)))
/*
 * This function may get called 1000s of times so avoid further function calls,
 * and use static data where possible.
 */
#define DBR(x) ((DbItem *)(x))
int db_overview_tv_eqf(void *item1,void *item2) {

    int ret = 0;
    if (((DbItem*)item1)->category == 'T' && ((DbItem*)item1)->category == ((DbItem*)item2)->category ) {
       ret = EQ_FILE(item1,item2);
    } else {
        html_error("%s:%d non-tv in tv view %s[%c] %s[%c]",
                __FILE__,__LINE__,
                ((DbItem*)item1)->file,((DbItem*)item1)->category,
                ((DbItem*)item2)->file,((DbItem*)item2)->category);
        //assert(0);
    }
    return ret;
}
unsigned int db_overview_tv_hashf(void *item) {

    if (DBR(item)->tmp_hash == 0) {
        DBR(item)->tmp_hash = stringhash(DBR(item)->file);
    }
    return DBR(item)->tmp_hash;
}

int db_overview_tvboxset_eqf(void *item1,void *item2) {

    int ret = 0;
    if (((DbItem*)item1)->category != ((DbItem*)item2)->category) {
       assert(0);
    } else if (((DbItem*)item1)->category == 'T' ) {
       ret = EQ_SEASON(item1,item2);
    } else {
       assert(0);
    }
    return ret;
}
unsigned int db_overview_tvboxset_hashf(void *item)
{
    if (DBR(item)->tmp_hash == 0) {
        unsigned int h  = stringhash(DBR(item)->title);
        HASH_ADD(h,DBR(item)->year);
        HASH_ADD(h,DBR(item)->season);
        DBR(item)->tmp_hash = h;
    }
    return DBR(item)->tmp_hash;
}

int db_overview_movie_eqf(void *item1,void *item2)
{

    int ret = 0;
    if (((DbItem*)item1)->category != ((DbItem*)item2)->category) {
       assert(0);
    } else if (((DbItem*)item1)->category == 'M' ) {
       ret = EQ_MOVIE(item1,item2);
    } else {
       assert(0);
    }
    return ret;
}
unsigned int db_overview_movie_hashf(void *item)
{
    if (DBR(item)->tmp_hash == 0) {
        DBR(item)->tmp_hash =  stringhash(DBR(item)->file);
    }
    return DBR(item)->tmp_hash;
}

// Movieboxset eq and hash
//
int db_overview_movieboxset_eqf(void *item1,void *item2)
{
    return db_overview_movie_eqf(item1,item2);
}
unsigned int db_overview_movieboxset_hashf(void *item)
{
    if (DBR(item)->tmp_hash == 0) {
        DBR(item)->tmp_hash =  stringhash(DBR(item)->file);
    }
    return DBR(item)->tmp_hash;
}


int db_overview_admin_eqf(void *item1,void *item2) {
   return EQ_FILE(item1,item2);
}
unsigned int db_overview_admin_hashf(void *item)
{
    return stringhash(DBR(item)->file);
}


int db_overview_other_eqf(void *item1,void *item2) {
   return EQ_FILE(item1,item2);
}
unsigned int db_overview_other_hashf(void *item)
{
    if (DBR(item)->tmp_hash == 0) {
        DBR(item)->tmp_hash =  stringhash(DBR(item)->file);
    }
    return DBR(item)->tmp_hash;
}


int db_overview_mixed_eqf(void *item1,void *item2)
{
    int ret = 0;
   if (((DbItem*)item1)->category == ((DbItem*)item2)->category) {
        switch(((DbItem*)item1)->category ) {
            case 'T':
                ret = db_overview_tvboxset_eqf(item1,item2);
                break;
            case 'M':
                ret = db_overview_movieboxset_eqf(item1,item2);
                break;
            default:
               ret = db_overview_other_eqf(item1,item2);
               break;
        }
   }
   return ret;
}
unsigned int db_overview_mixed_hashf(void *item)
{
    if (DBR(item)->tmp_hash == 0) {
        int h=0;
        switch(((DbItem*)item)->category ) {
            case 'T':
                h = db_overview_tvboxset_hashf(item);
                break;
            case 'M':
                h = db_overview_movieboxset_hashf(item);
                break;
            default:
                h = db_overview_other_hashf(item);
                break;
        }
        DBR(item)->tmp_hash = h;
    }
    return DBR(item)->tmp_hash;
}

int db_overview_menu_eqf(void *item1,void *item2) {
    int ret = 0 ;

    if (((DbItem*)item1)->category == ((DbItem*)item2)->category) {
        switch(((DbItem*)item1)->category ) {
            case 'T':
                if (g_tvboxset_mode) {
                   ret = EQ_SHOW(item1,item2);
                } else {
                   ret = EQ_SEASON(item1,item2);
                }
                break;
            case 'M':
               ret = in_same_db_imdb_group(((DbItem*)item1),((DbItem*)item2),g_moviebox_mode);
                break;
            default:
               ret = EQ_FILE(item1,item2);
        }

    }
    return ret;
}
unsigned int db_overview_menu_hashf(void *item)
{
    if (DBR(item)->tmp_hash == 0) {
        unsigned int h;

        switch(((DbItem*)item)->category ) {
            case 'T':
                h  = stringhash(DBR(item)->title);
                HASH_ADD(h,DBR(item)->year);
                if (!g_tvboxset_mode) {
                    HASH_ADD(h,DBR(item)->season);
                }
                break;
            case 'M':
                if (DBR(item)->external_id == 0) {

                    h  = stringhash(DBR(item)->file);

                } else {

                    switch(g_moviebox_mode) {
                        case MOVIE_BOXSETS_FIRST:
                            if (DBR(item)->comes_after == NULL) {
                                // If it doesnt follow anything then it is the main item
                                h = DBR(item)->external_id ;
                            } else {
                                h = DBR(item)->comes_after->dbgi_ids[0];
                            }
                            break;
                        case MOVIE_BOXSETS_LAST:
                            if (DBR(item)->comes_before == NULL) {
                                // If nothing follows it is the last item
                                h = DBR(item)->external_id ;
                            } else {
                                int size = DBR(item)->comes_before->dbgi_size;
                                h = DBR(item)->comes_before->dbgi_ids[size-1];
                            }
                            break;
                        case MOVIE_BOXSETS_ANY:
                            // If we are comparing any item then all items 
                            // have the same hash value and the eq fn does the 
                            // heavy lifting.
                            // This may not work as expected.
                            h = 1;
                            break;
                        case MOVIE_BOXSETS_NONE:
                            // All movies are unique by file
                            h  = stringhash(DBR(item)->file);
                            break;
                        default:
                            // All movies are unique by file
                            h  = stringhash(DBR(item)->file);
                            break;
                    }
                }
                //HTML_LOG(0,"%d title[%s (%d)] hash [%u]",g_moviebox_mode,DBR(item)->title,DBR(item)->year,h);
                break;
            default:
                    h  = stringhash(DBR(item)->file);
        }
        DBR(item)->tmp_hash = h;
    }
    return DBR(item)->tmp_hash;
}

// Used to iterate over the various movie connections.
// return the next valid movie connection.
// r = row id
// *list = 1 (return from comes_after ) =2 return external_id , =3 return from comes_before
// *idx = index within the above list.
// If *idx exceeeds list size then *list is incremented.
// group must be evaluated first.
//
static inline int get_imdbid_from_connections(DbItem *r,int *list,int *idx) {
    switch(*list) {
        case 0: // looking at ->comes_after
            if (r->comes_after==NULL || *idx >= r->comes_after->dbgi_size ) {
                *idx = 0;
                (*list)++;
                // fall thru
            } else {
                return r->comes_after->dbgi_ids[*idx];
            }
        case 1: // looking at ->external_id
            if (*idx >= 1) {
                *idx = 0;
                (*list)++;
                // fall thru
            } else {
                return r->external_id;
            }
        case 2: // looking at ->comes_before
            if (r->comes_before==NULL || *idx >= r->comes_before->dbgi_size ) {
                *idx = 0;
                (*list)++;
                // fall thru
            } else {
                return r->comes_before->dbgi_ids[*idx];
            }
        default:
            return 0;
    }
}
#define FIRST_CONNECTION(r) ((r)->comes_after\
        ?(r)->comes_after->dbgi_ids[0]\
        :(r)->external_id)

#define LAST_CONNECTION(r) ((r)->comes_before\
        ?(r)->comes_before->dbgi_ids[(r)->comes_before->dbgi_size-1]\
        :(r)->external_id)

static inline int in_same_db_imdb_group(DbItem *item1,DbItem *item2,MovieBoxsetMode movie_boxset_mode)
{
   int ret = 0;
   //int log=0;

   //HTML_LOG(0,"in_same_db_imdb_group [%s] against [%s]", item1->title,item2->title);

   if (item1->external_id && item2->external_id ) {

       if (item1->external_id == item2->external_id) {
           ret = 1;

       } else {
           //if (item1->external_id == 78748) log=1;
           //if (item2->external_id == 78748) log=1;

           switch(movie_boxset_mode) {
               case MOVIE_BOXSETS_FIRST:
                   //EVALUATE_GROUP(item1->comes_after);
                   //EVALUATE_GROUP(item2->comes_after);
                   ret = FIRST_CONNECTION(item1) == FIRST_CONNECTION(item2);
                   break;
               case MOVIE_BOXSETS_LAST:
                   //EVALUATE_GROUP(item1->comes_before);
                   //EVALUATE_GROUP(item2->comes_before);
                   ret = LAST_CONNECTION(item1) == LAST_CONNECTION(item2);
                   break;
               case MOVIE_BOXSETS_ANY:
                   //EVALUATE_GROUP(item1->comes_after);
                   //EVALUATE_GROUP(item2->comes_after);
                   //EVALUATE_GROUP(item1->comes_before);
                   //EVALUATE_GROUP(item2->comes_before);
                       // only check for overlap if at least one of the movies has before/after sets
                   if ( item1->comes_before || item1->comes_after || item2->comes_before || item2->comes_after ) {
                       // Step over both item1 and item2 movie connections until we hit a connection.
                       // This is coded to be a O(n) search. Step over both sets of movie connections 
                       // at the same time.
                       // The code is a little messy because movie connections are split into 3 parts
                       // comes_after, external_id and comes_before.
                       // We could join it together and have a neat iteration over a single array for each item but that is more clock cycles.
                       int rid1list = 0;
                       int rid2list = 0;
                       int rid1idx = 0;
                       int rid2idx = 0;

                       int imdb1,imdb2;
                       while(1) {
                           if ((imdb1= get_imdbid_from_connections(item1,&rid1list,&rid1idx)) == 0 ) {
                               break;
                           }

                           if ((imdb2= get_imdbid_from_connections(item2,&rid2list,&rid2idx)) == 0 ) {
                               break;
                           }

                           //if (log) {
                               //HTML_LOG(0,"cmp [%s/%d/%d]=%d against [%s/%d/%d]=%d",
                                       //item1->title,rid1list,rid1idx,imdb1,
                                       //item2->title,rid2list,rid2idx,imdb2);
                           //}

                           if (imdb1 < imdb2 ) {
                               rid1idx ++;
                           } else if (imdb1 > imdb2 ) {
                               rid2idx ++;
                           } else {
                               ret = 1;
                               break;
                           }
                       }
                   }
                  break;
              case MOVIE_BOXSETS_NONE:
                  ret = EQ_FILE(item1,item2);
                  break;
              default:
                  ret = EQ_FILE(item1,item2);
                  break;
          }
      }
   }
   return ret;
}


void overview_dump(int level,char *label,struct hashtable *overview) {
    struct hashtable_itr *itr;
    DbItem *k;

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

void overview_array_dump(int level,char *label,DbItem **arr) {
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


/**
  Change overview from a hash to a list of lists. This is to allow an item to be in multiple places.
  At the moment the menu and tv box set grids, each icon replresents all items with the same hash.
  This will not scale to work with movie and custom box sets. Eg AvP may be in a Predator Box set,
  and an Aliens box set. etc.
  Because an item can appear in multiple places we need to build a list of lists.
  */
 
void db_set_visited(DbItemSet **rowsets,int val) {
    if (rowsets) {

        int i,j;
        for( i = 0 ; rowsets[i] ; i++ ) {
            for( j = 0 ; j < rowsets[i]->size ; j++ ) {
                DbItem *r = rowsets[i]->rows+j;
                r->visited = val;
            }
        }
    }
}

struct hashtable *db_overview_hash_create(DbItemSet **rowsets,ViewMode *view) {
    
    int total=0;
    struct hashtable *overview = NULL;

TRACE;
   
    /*
     * Functions used to create the overview hash
     *
     * When looking at the main menu , or a box set, each cell is a collection of programs.
     * This code sets up the relevant equality fns(and corresponding hash fns) that determine
     * which files share a cell (ie are equivalent).
     *
     * For example. In the main menu - All Tv episodes in the same show are considered equivalent
     * but at the box set level, only episodes in the same season are equivalent.
     *
     * Also if using movie box sets , then all movies in the same IMDB movie connections are 
     * equivalent. In this case it is not sufficient to use the movie name , as unrelated movies
     * might have the same name. (esp movies with one word titles - eg Venom)
     */
    //TODO we need to find a generic image for the box set!
     unsigned int (*hashf) (void*);
     int (*eqf) (void*,void*);

     hashf = view->item_hash_fn;
     eqf = view->item_eq_fn;

    overview = create_hashtable("db_overview",100,hashf,eqf);
TRACE;

    int rowset_count=0;
    if (rowsets) {
TRACE;

        DbItemSet **rowset_ptr;
        for(rowset_ptr = rowsets ; *rowset_ptr ; rowset_ptr++ ) {
TRACE;

            int i;
            HTML_LOG(1,"dbg: overview merging rowset[%d]",++rowset_count);
            total += (*rowset_ptr)->size;

            for( i = 0 ; i < (*rowset_ptr)->size ; i++ ) {


TRACE;
                DbItem *item = (*rowset_ptr)->rows+i;

                HTML_LOG(2,"dbg: overview merging [%s][%s]",item->db->source,item->title);


TRACE;
                DbItem *match = hashtable_search(overview,item);
TRACE;

                if (match) {
TRACE;

                    HTML_LOG(1,"overview: match [%s] with [%s]",item->title,match->title);

                    //Move most recent age to the first overview item
                    if (*timestamp_ptr(item) > *timestamp_ptr(match) ) {
                        *timestamp_ptr(match) = *timestamp_ptr(item);
                    }

                    // Add item to linked list at match->linked
                    item->linked = match->linked;
                    match->linked = item;
                    match->link_count++;

                } else {
TRACE;

                    HTML_LOG(3,"overview: new entry [%s]",item->title);
                    hashtable_insert(overview,item,item);
                }
TRACE;
                //HTML_LOG(3,"dbg done [%s]",item->title);
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



DbItem **flatten_hash_to_array(struct hashtable *overview) {
    DbItem **ids = MALLOC((hashtable_count(overview)+1) * sizeof(DbItem *) );

    struct hashtable_itr *itr;
    DbItem *k;

    int i = 0;
    for (itr=hashtable_loop_init(overview) ; hashtable_loop_more(itr,&k,NULL) ; ) {

        ids[i++] = k;
    }
    ids[i] = NULL;
    return ids;
}

DbItem **sort_overview(struct hashtable *overview, int (*cmp_fn)(DbItem **,DbItem **)) {

    DbItem **ids = flatten_hash_to_array(overview);
    int total = hashtable_count(overview);

    HTML_LOG(1,"sorting %d items",total);
    overview_array_dump(3,"ovw flatten",ids);
    qsort(ids,hashtable_count(overview),sizeof(DbItem *),(void *)cmp_fn);
    HTML_LOG(1,"sorted %d items",total);
    overview_array_dump(2,"ovw sorted",ids);

    return ids;
}



void db_overview_hash_destroy(struct hashtable *ovw_hash) {
    hashtable_destroy(ovw_hash,0,0);
}

void db_group_imdb_add(DbGroupIMDB *g,int id) {

    int size = g->dbgi_size;
    //assert(size < IMDB_GROUP_MAX_SIZE-1);
    if (size >= IMDB_GROUP_MAX_SIZE ) {
        HTML_LOG(0,"truncated imdb starting %07d. %07d not added",
                g->dbgi_ids[0],id);
    } else {

        // If an item is added out of order - then clear dbgi_sorted field.
        // This means we dont use bchop looking for items. Just a linear scan.
        if (g->dbgi_sorted && size && id < g->dbgi_ids[size-1] ) {
            g->dbgi_sorted = 0;
        }

        g->dbgi_ids[size++] = id;
        g->dbgi_size = size;
    }
}

DbGroupIMDB *get_raw_imdb_list(
        char *val,
        int val_len,
        char *prefix
        )
{
    DbGroupIMDB *group = NULL;
    if (val != NULL && val_len > 0 ) {
        group = db_group_imdb_new(0,prefix);
        group->raw = COPY_STRING(val_len,val);
        group->raw_len = val_len;
        group->evaluated = 0;
    }
    return group;
}

void evaluate_group(DbGroupIMDB *group) 
{
    if (!group->evaluated) {
        HTML_LOG(1,"Group eval");
        if (parse_imdb_list(group->prefix,group->raw,group->raw_len,group) == group) {
            FREE(group->raw);
            group->raw = NULL;
            group->raw_len = 0;
            group->evaluated = 1;
        }
    }
}

/**
 * Parse a list of imdb ids. They may be ascii strings eg tt123,tt456
 * or in base IMDB_GROUP_BASE format with characters offset by 128.
 * eg. in base 128 with offset 128 then the sequence
 * chr(129)chr(130) = 12(base 128) = 1*128 + 2 = 130(dec)
 * This compresses an id tt1999999 down to 3 bytes, .
 */
DbGroupIMDB *parse_imdb_list(
        char *prefix, // tt or nm
        char *val,
        int val_len,
        DbGroupIMDB *group // If NULL create new group.
        )
{
    int prefix_len = strlen(prefix);

    if (val != NULL && val_len > 0 ) {
        unsigned char *p,*start = (unsigned char *)val;
        unsigned char *end = start+val_len;
        int id = 0;
        for(p = start ; p < end ; ) {
            // tt or nm
            if (*p == *prefix && util_starts_with((char *)p,prefix)) {
                // Parse tt0000000 or nm00000
                p += prefix_len;
                char *q;
                id = strtol((char *)p,&q,10);
                p = (unsigned char *)q;

            } else if (*p && *p != IMDB_GROUP_SEP) {
                if (*p >= 128) {
                    // Parse number in base n where each character is a digit offset
                    // by 128. (to avoid clash with ascii7 )
                    id = id * IMDB_GROUP_BASE + (*p - 128);
                    p++;
                } else if (isdigit(*p)) {
                    // normal number.
                    id = id * 10 + (*p - '0');
                    p++;
                } else {
                    assert(0);
                }

            } else {
                if (group == NULL) {
                    group = db_group_imdb_new(0,prefix);
                }
                db_group_imdb_add(group,id);
                id = 0;
                p++;
            }
        }
        if (id != 0) {
            if (group == NULL) {
                group = db_group_imdb_new(0,prefix);
            }
            db_group_imdb_add(group,id);
        }
        if (group) {
            group->evaluated = 1;
        }
    }

#if 0
    // Debug/test code.
    if (group) {
        int i;
        for(i = 0 ; i < group->dbgi_size ; i++ ) {
            HTML_LOG(0,"tt%d",group->dbgi_ids[i]);
        }
        HTML_LOG(0,"compressed[%s]",db_group_imdb_compressed_string_static(group));
    }
#endif
    return group;
}

#define MAX_IMDB_BASE_N_DIGITS 5
//
// Get compressed string representation of a list of imdb ids.
// Each id is represented by a base128 number. (ascii(128) to ascii(255)
//
char *db_group_imdb_compressed_string_static(DbGroupIMDB *g)
{
    static char buffer[(MAX_IMDB_BASE_N_DIGITS+1)*IMDB_GROUP_MAX_SIZE]; // tt9999999=4 characters compressed.
    char *p = buffer;

    if (g) {

        EVALUATE_GROUP(g);

        int i;
        for(i = 0 ; i < g->dbgi_size ; i++ ) {

            // Convert Id to  IMDB_GROUP_BASE (reverse division)
            unsigned char num[MAX_IMDB_BASE_N_DIGITS+1],*numptr=num;
            int id = g->dbgi_ids[i];
            do {
                *numptr++ = 128 + id % IMDB_GROUP_BASE;
                id /= IMDB_GROUP_BASE;
            } while(id);
            assert(numptr < num+MAX_IMDB_BASE_N_DIGITS);
            // Copy seperator
            if (i) {
                *p++ = IMDB_GROUP_SEP;
            }
            // Reverse Copy bytes into p
            while (--numptr >= num) {
                *p++ = *numptr;
            }
        }
    }
    *p = '\0';
    return buffer;
}
// Get string representation of a list of imdb ids.
#define MAX_IMDB_IDLEN 9  // tt8888888
char *db_group_imdb_string_static(
        DbGroupIMDB *g
        )
{
    static char buffer[(MAX_IMDB_IDLEN+1)*IMDB_GROUP_MAX_SIZE]; // tt9999999=4 characters compressed.
    char *p = buffer;
    if (g) {
        EVALUATE_GROUP(g);

        int i;
        for(i = 0 ; i < g->dbgi_size ; i++ ) {

            int id = g->dbgi_ids[i];
            // Copy seperator
            if (i) {
                *p++ = IMDB_GROUP_SEP;
            }
            p += sprintf(p,"%s%07d",g->prefix,id);
        }
    }
    *p = '\0';
    return buffer;
}

ViewMode *new_view(
        char *name,
        int view_class,
        int row_select,
        int has_playlist,
        char *dimension_cell_suffix,
        char *media_types,
        int (*default_sort)(),
        int (*item_eq_fn)(void *,void *), // used to build hashtable of items
        unsigned int (*item_hash_fn)(void *)) // used to build hashtable of items
{
    static int i = 0;
    ViewMode *vm = CALLOC(sizeof(ViewMode),1);
    vm->name = name;
    vm->view_class = view_class;
    vm->row_select = row_select;
    vm->has_playlist = has_playlist;
    vm->dimension_cell_suffix = dimension_cell_suffix;
    vm->media_types = media_types;
    vm->default_sort = default_sort;
    vm->item_eq_fn = item_eq_fn;
    vm->item_hash_fn = item_hash_fn;

    i++;
    g_view_modes = REALLOC(g_view_modes,(i+1) * sizeof(ViewMode *));
    g_view_modes[i-1] = vm;
    g_view_modes[i] = NULL;
    return vm;
}


void init_view()
{
    VIEW_ADMIN
        = new_view( "admin"       ,VIEW_CLASS_ADMIN,ROW_BY_ID, 0 , NULL, DB_MEDIA_TYPE_ANY , NULL,
       db_overview_admin_eqf ,
       db_overview_admin_hashf );

    VIEW_TV
        = new_view( "tv"          ,VIEW_CLASS_DETAIL,ROW_BY_SEASON, 1 , NULL, DB_MEDIA_TYPE_TV ,
            db_overview_cmp_by_title,
       db_overview_tv_eqf ,
       db_overview_tv_hashf );

    VIEW_MOVIE
        = new_view( "movie"       ,VIEW_CLASS_DETAIL,ROW_BY_ID, 1 , NULL, DB_MEDIA_TYPE_FILM , NULL,
       db_overview_movie_eqf ,
       db_overview_movie_hashf );

    VIEW_OTHER
        = new_view( "other"       ,VIEW_CLASS_DETAIL,ROW_BY_ID, 1 , NULL, DB_MEDIA_TYPE_OTHER , NULL,
       db_overview_other_eqf ,
       db_overview_other_hashf );

    VIEW_PERSON
        = new_view( "person"      ,VIEW_CLASS_BOXSET,ROW_BY_ID, 0 , NULL, DB_MEDIA_TYPE_ANY ,
            db_overview_cmp_by_year_asc,
       db_overview_mixed_eqf ,
       db_overview_mixed_hashf );

    VIEW_TVBOXSET
        = new_view( "tvboxset"    ,VIEW_CLASS_BOXSET,ROW_BY_TITLE, 0 ,"_tvboxset"  , DB_MEDIA_TYPE_TV ,
            db_overview_cmp_by_season_asc,
       db_overview_tvboxset_eqf ,
       db_overview_tvboxset_hashf );

    VIEW_MOVIEBOXSET
        = new_view( "movieboxset" ,VIEW_CLASS_BOXSET,ROW_BY_ID, 0 , "_movieboxset" , DB_MEDIA_TYPE_FILM ,
       db_overview_cmp_by_year_asc,
       db_overview_movieboxset_eqf ,
       db_overview_movieboxset_hashf );

    VIEW_MENU
        = new_view( "menu"        ,VIEW_CLASS_MENU,ROW_BY_ID, 0 , NULL  , DB_MEDIA_TYPE_ANY , NULL,
       db_overview_menu_eqf ,
       db_overview_menu_hashf );

    VIEW_MIXED
        = new_view( "mixed"       ,VIEW_CLASS_MENU,ROW_BY_ID, 0 , NULL  , DB_MEDIA_TYPE_ANY , NULL,
       db_overview_mixed_eqf ,
       db_overview_mixed_hashf );
}


// vi:sw=4:et:ts=4
