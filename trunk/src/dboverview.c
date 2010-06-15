// $Id:$
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <assert.h>

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

static inline int in_same_db_imdb_group(DbRowId *rid1,DbRowId *rid2,MovieBoxsetMode movie_boxset_mode);

DbGroupIMDB *db_group_imdb_new(
        int size // max number of imdb entries 0 = IMDB_GROUP_MAX_SIZE
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

int in_db_custom_group(DbRowId *rid,DbGroupCustom *g)
{
    html_error("in_db_custom_group not implemented");
    return 0;
}

int in_db_name_season_group(DbRowId *rid,DbGroupNameSeason *g)
{
    int result = 0 ;
    if (rid->category == 'T' ) {
        if (g->season <= 0 || g->season == rid->season) {
            result = STRCMP(g->name,rid->title) == 0;
        }
    }
    return result;
}

int in_db_imdb_group(DbRowId *rid,DbGroupIMDB *g)
{
    int result = 0 ;
    if (g && rid->external_id ) {
        result = bchop(rid->external_id,g->dbgi_size,g->dbgi_ids) >= 0;
    } 
    return result;
}

int in_db_group(DbRowId *rid,DbGroupDef *g)
{
    int result = 0;
    switch(g->dbg_type) {
        case DB_GROUP_BY_CUSTOM_TAG:
            result = in_db_custom_group(rid,&(g->u.dbgc));
        case DB_GROUP_BY_NAME_TYPE_SEASON:
            result = in_db_name_season_group(rid,&(g->u.dbgns));
        case DB_GROUP_BY_IMDB_LIST:
            result = in_db_imdb_group(rid,&(g->u.dbgi));
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
int db_overview_cmp_by_age(DbRowId **rid1,DbRowId **rid2) {
    //return (*rid2)->date - (*rid1)->date;
    return *timestamp_ptr(*rid2)- *timestamp_ptr(*rid1);
}


int index_STRCMP(char *a,char *b) {
    if (STARTS_WITH_THE(a)) a+= 4;
    if (STARTS_WITH_THE(b)) b+= 4;
    //if (strncasecmp(a,"the ",4)==0) a+= 4;
    //if (strncasecmp(b,"the ",4)==0) b+= 4;
    return strcasecmp(a,b);
}

// This function is just used for sorting the overview AFTER it has been created.
int db_overview_cmp_by_title(DbRowId **rid1,DbRowId **rid2) {

    int c;

    // If titles are different - return comparison
    if ((c=index_STRCMP(NVL((*rid1)->title),NVL((*rid2)->title))) != 0) {
        return c;
    }

    if ((*rid1)->category == 'T' && (*rid2)->category=='T') {
        // Compare by season

        int d = (*rid1)->season-(*rid2)->season;
        if (d == 0) {
            d = numSTRCMP(NVL((*rid1)->episode),NVL((*rid2)->episode));
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
        return STRCMP(rid1->title,rid2->title) ==0;
    }
}
// overview hash function based on titles only. This is used in boxset mode.
unsigned int db_overview_name_hashf(void *rid) {

    unsigned int h;
    h  = stringhash(((DbRowId *)rid)->title);
    return h;
}



// Compare numeric field of records. (casting void* to DbRowId*)
#define EQ_NUM(rid1,rid2,fld) (((DbRowId*)(rid1))->fld == ((DbRowId*)(rid2))->fld)

// Compare string field of records. (casting void* to DbRowId*)
#define EQ_STR(rid1,rid2,fld) (STRCMP(((DbRowId*)(rid1))->fld,((DbRowId*)(rid2))->fld) ==0)

// true if two records have the same file. (should never happen really so just return 0
//#define EQ_FILE(rid1,rid2) EQ_STR(rid1,rid2,file) && EQ_SHOW(rid1,rid2,source)
#define EQ_FILE(rid1,rid2) 0

#define EQ_MOVIE(rid1,rid2) EQ_NUM(rid1,rid2,external_id)

// true if two records are part of the same show. Assuemes category=T already tested.
#define EQ_SHOW(rid1,rid2) (EQ_NUM(rid1,rid2,year) && EQ_STR(rid1,rid2,title))

// true if two records are part of the same season. Assuemes category=T already tested.
#define EQ_SEASON(rid1,rid2) (EQ_NUM(rid1,rid2,season) && EQ_SHOW((rid1),(rid2)))
/*
 * This function may get called 1000s of times so avoid further function calls,
 * and use static data where possible.
 */
int db_overview_general_eqf(void *rid1,void *rid2) {
    static int tvbox=-1;
    static MovieBoxsetMode moviebox=MOVIE_BOXSETS_UNSET;
    static int mode=-1;
    int ret=0;

    if (tvbox == -1) {
        tvbox = use_tv_boxsets();
        moviebox = movie_boxset_mode();
        mode = get_view_mode();
    }

    if (((DbRowId*)rid1)->category != ((DbRowId*)rid2)->category) {
        ret = 0;

    } else if (((DbRowId*)rid1)->category == 'T' ) {
        switch(mode) {
            case MENU_VIEW_ID:
                if (tvbox) {
                   ret = EQ_SHOW(rid1,rid2);
                } else {
                   ret = EQ_SEASON(rid1,rid2);
                }
                break;
            case TVBOXSET_VIEW_ID:
               ret = EQ_SEASON(rid1,rid2);
                break;
            case TV_VIEW_ID:
            case ADMIN_VIEW_ID:
               ret = EQ_FILE(rid1,rid2);
                break;
            default:
                assert(0);
                break;
        }
    } else if (((DbRowId*)rid1)->category == 'M' ) {
        switch(mode) {
            case MENU_VIEW_ID:
               ret = in_same_db_imdb_group(((DbRowId*)rid1),((DbRowId*)rid2),moviebox);
               break;
            case MOVIEBOXSET_VIEW_ID:
            case MOVIE_VIEW_ID:
                ret = EQ_MOVIE(rid1,rid2);
                break;
            case ADMIN_VIEW_ID:
               ret = EQ_FILE(rid1,rid2);
                break;
            default:
                assert(0);
                break;
        } 
    } else {
           ret = EQ_FILE(rid1,rid2);
    }
    return ret;

}

// Used to iterate over the various movie connections.
// return the next valid movie connection.
// r = row id
// *list = 1 (return from comes_after ) =2 return external_id , =3 return from comes_before
// *idx = index within the above list.
// If *idx exceeeds list size then *list is incremented.
//
static inline int get_imdbid_from_connections(DbRowId *r,int *list,int *idx) {
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
#define FIRST_CONNECTION(r) ((r)->comes_after?(r)->comes_after->dbgi_ids[0]:(r)->external_id)
#define LAST_CONNECTION(r) ((r)->comes_before?(r)->comes_before->dbgi_ids[(r)->comes_before->dbgi_size-1]:(r)->external_id)

static inline int in_same_db_imdb_group(DbRowId *rid1,DbRowId *rid2,MovieBoxsetMode movie_boxset_mode)
{
   int ret = 0;
   //int log=0;

   //HTML_LOG(0,"in_same_db_imdb_group [%s] against [%s]", rid1->title,rid2->title);

   if (rid1->external_id && rid2->external_id ) {

       if (rid1->external_id == rid2->external_id) {
           ret = 1;

       } else {
           //if (rid1->external_id == 78748) log=1;
           //if (rid2->external_id == 78748) log=1;

           switch(movie_boxset_mode) {
               case MOVIE_BOXSETS_FIRST:
                   ret = FIRST_CONNECTION(rid1) == FIRST_CONNECTION(rid2);
                   break;
               case MOVIE_BOXSETS_LAST:
                   ret = LAST_CONNECTION(rid1) == LAST_CONNECTION(rid2);
                   break;
               case MOVIE_BOXSETS_ANY:
                       // only check for overlap if at least one of the movies has before/after sets
                   if ( rid1->comes_before || rid1->comes_after || rid2->comes_before || rid2->comes_after ) {
                       // Step over both rid1 and rid2 movie connections until we hit a connection.
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
                           if ((imdb1= get_imdbid_from_connections(rid1,&rid1list,&rid1idx)) == 0 ) {
                               break;
                           }

                           if ((imdb2= get_imdbid_from_connections(rid2,&rid2list,&rid2idx)) == 0 ) {
                               break;
                           }

                           //if (log) {
                               //HTML_LOG(0,"cmp [%s/%d/%d]=%d against [%s/%d/%d]=%d",
                                       //rid1->title,rid1list,rid1idx,imdb1,
                                       //rid2->title,rid2list,rid2idx,imdb2);
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
                  ret = EQ_FILE(rid1,rid2);
                  break;
              default:
                  ret = EQ_FILE(rid1,rid2);
                  break;
          }
      }
   }
   return ret;
}

#define DBR(x) ((DbRowId *)(x))
unsigned int db_overview_general_hashf(void *rid)
{
    static int tvbox=-1;
    static MovieBoxsetMode moviebox=MOVIE_BOXSETS_UNSET;
    static int mode=-1;
    int h=0;

    if (tvbox == -1) {
        tvbox = use_tv_boxsets();
        moviebox = movie_boxset_mode();
        mode = get_view_mode();
    }
    switch(DBR(rid)->category) {
        case 'T':
        switch(mode) {
            case MENU_VIEW_ID:
                if (tvbox) {
                    h  = stringhash(DBR(rid)->title);
                    HASH_ADD(h,DBR(rid)->year);
                } else {
                    h  = stringhash(DBR(rid)->title);
                    HASH_ADD(h,DBR(rid)->year);
                    HASH_ADD(h,DBR(rid)->season);
                }
                break;
            case TVBOXSET_VIEW_ID:
                h  = stringhash(DBR(rid)->title);
                HASH_ADD(h,DBR(rid)->year);
                HASH_ADD(h,DBR(rid)->season);
                break;
            case TV_VIEW_ID:
                h  = stringhash(DBR(rid)->file);
                break;
            case ADMIN_VIEW_ID:
                h  = stringhash(DBR(rid)->file);
                break;
            default:
                html_error("unknown view for item %d[%s - %s]",DBR(rid)->id,DBR(rid)->title,DBR(rid)->file);
                assert(0);
        } 
        break;
    case 'M':
        switch(mode) {
            case MENU_VIEW_ID:
                if (DBR(rid)->external_id == 0) {
                    // External ID not set - just use the title
                    h  = stringhash(DBR(rid)->file);
                } else {
                    switch(moviebox) {
                        case MOVIE_BOXSETS_FIRST:
                            if (DBR(rid)->comes_after == NULL) {
                                // If it doesnt follow anything then it is the main item
                                h = DBR(rid)->external_id ;
                            } else {
                                h = DBR(rid)->comes_after->dbgi_ids[0];
                            }
                            break;
                        case MOVIE_BOXSETS_LAST:
                            if (DBR(rid)->comes_before == NULL) {
                                // If nothing follows it is the last item
                                h = DBR(rid)->external_id ;
                            } else {
                                int size = DBR(rid)->comes_before->dbgi_size;
                                h = DBR(rid)->comes_before->dbgi_ids[size-1];
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
                            h  = stringhash(DBR(rid)->file);
                            break;
                        default:
                            // All movies are unique by file
                            h  = stringhash(DBR(rid)->file);
                            break;
                    }
                }
                break;
            case MOVIEBOXSET_VIEW_ID:
            case MOVIE_VIEW_ID:
            case ADMIN_VIEW_ID:
                h  = stringhash(DBR(rid)->file);
                break;
            default:
                html_error("unknown view for item %d[%s - %s]",DBR(rid)->id,DBR(rid)->title,DBR(rid)->file);
                assert(0);
        } 
        break;
    default:
        h  = stringhash(((DbRowId *)rid)->file);
    }
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


/**
  Change overview from a hash to a list of lists. This is to allow an item to be in multiple places.
  At the moment the menu and tv box set grids, each icon replresents all items with the same hash.
  This will not scale to work with movie and custom box sets. Eg AvP may be in a Predator Box set,
  and an Aliens box set. etc.
  Because an item can appear in multiple places we need to build a list of lists.
  */
 
void db_set_visited(DbRowSet **rowsets,int val) {
    if (rowsets) {

        int i,j;
        for( i = 0 ; rowsets[i] ; i++ ) {
            for( j = 0 ; j < rowsets[i]->size ; j++ ) {
                DbRowId *r = rowsets[i]->rows+j;
                r->visited = val;
            }
        }
    }
}

struct hashtable *db_overview_hash_create(DbRowSet **rowsets) {
    
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

    overview = create_hashtable("db_overview",100,db_overview_general_hashf,db_overview_general_eqf);
TRACE;

    int rowset_count=0;
    if (rowsets) {
TRACE;

        DbRowSet **rowset_ptr;
        for(rowset_ptr = rowsets ; *rowset_ptr ; rowset_ptr++ ) {
TRACE;

            int i;
            HTML_LOG(1,"dbg: overview merging rowset[%d]",++rowset_count);
            total += (*rowset_ptr)->size;

            for( i = 0 ; i < (*rowset_ptr)->size ; i++ ) {


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
                    if (*timestamp_ptr(rid) > *timestamp_ptr(match) ) {
                        *timestamp_ptr(match) = *timestamp_ptr(rid);
                    }

                    // Add rid to linked list at match->linked
                    rid->linked = match->linked;
                    match->linked = rid;
                    match->link_count++;

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

DbRowId **sort_overview(struct hashtable *overview, int (*cmp_fn)(DbRowId **,DbRowId **)) {

    DbRowId **ids = flatten_hash_to_array(overview);
    int total = hashtable_count(overview);

    HTML_LOG(0,"sorting %d items",total);
    overview_array_dump(3,"ovw flatten",ids);
    qsort(ids,hashtable_count(overview),sizeof(DbRowId *),(void *)cmp_fn);
    HTML_LOG(0,"sorted %d items",total);
    overview_array_dump(2,"ovw sorted",ids);

    return ids;
}



void db_overview_hash_destroy(struct hashtable *ovw_hash) {
    hashtable_destroy(ovw_hash,0,0);
}

void db_group_imdb_add(DbGroupIMDB *g,int id) {

    int size = g->dbgi_size;
    assert(size < IMDB_GROUP_MAX_SIZE-1);
    g->dbgi_ids[size++] = id;
    g->dbgi_size = size;
}

/**
 * Parse a list of imdb ids. They may be ascii strings eg tt123,tt456
 * or in base IMDB_GROUP_BASE format with characters offset by 128.
 * eg. in base 128 with offset 128 then the sequence
 * chr(129)chr(130) = 12(base 128) = 1*128 + 2 = 130(dec)
 * This compresses an id tt1999999 down to 3 bytes, .
 */
DbGroupIMDB *parse_imdb_list(
        char *val,
        int val_len
        )
{
    DbGroupIMDB *group = NULL;
    if (val != NULL && val_len > 0 ) {
        unsigned char *p,*start = (unsigned char *)val;
        unsigned char *end = start+val_len;
        int id = 0;
        for(p = start ; p < end ; ) {
            if (*p == 't') {
                // Parse tt0000000
                char *q;
                p++;
                assert(*p == 't');
                p ++;
                id = strtol((char *)p,&q,10);
                p = (unsigned char *)q;

            } else if (*p && *p != IMDB_GROUP_SEP) {
                // Parse number in base n where each character is a digit offset
                // by 128. (to avoid clash with ascii7 )
                id = id * IMDB_GROUP_BASE + (*p - 128);
                p++;
            } else {
                if (group == NULL) {
                    group = db_group_imdb_new(0);
                }
                db_group_imdb_add(group,id);
                id = 0;
                p++;
            }
        }
        if (id != 0) {
            if (group == NULL) {
                group = db_group_imdb_new(0);
            }
            db_group_imdb_add(group,id);
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
char *db_group_imdb_string_static(DbGroupIMDB *g)
{
    static char buffer[(MAX_IMDB_IDLEN+1)*IMDB_GROUP_MAX_SIZE]; // tt9999999=4 characters compressed.
    char *p = buffer;
    if (g) {
        int i;
        for(i = 0 ; i < g->dbgi_size ; i++ ) {

            int id = g->dbgi_ids[i];
            // Copy seperator
            if (i) {
                *p++ = IMDB_GROUP_SEP;
            }
            p += sprintf(p,"tt%07d",id);
        }
    }
    *p = '\0';
    return buffer;
}

// vi:sw=4:et:ts=4
