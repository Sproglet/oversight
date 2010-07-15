#ifndef __DB_OVERVIEW_ALORD__
#define __DB_OVERVIEW_ALORD__

#include "types.h"
#include "db.h"

void init_view();
// A Group of related rows. This may be :
// a movie boxset (a list of related imdb numbers)
// a tv box set. ( a Title and a Season. )
// a tv box series. ( a Title . )
// a custom group (A tag which will be stored against the item)
typedef enum DbGroupType_enum { DB_GROUP_BY_IMDB_LIST , DB_GROUP_BY_NAME_TYPE_SEASON , DB_GROUP_BY_CUSTOM_TAG } DbGroupType;

typedef struct DbGroupIMDB_struct {
    int evaluated; // To improve page load performance groups are only evaluated when needed.
    char *raw; // Raw string for this group. This should be freed when the ids are evaluated.
    int raw_len;

    char *prefix; // tt or nm - do not free
    int dbgi_max_size;
    int dbgi_size;
    int *dbgi_ids;
} DbGroupIMDB;

typedef struct DbGroupNameSeason_struct {
    char *name;
    int type;
    int season;
} DbGroupNameSeason;

typedef struct DbGroupCustom_struct {
    char *dbgc_tag;
} DbGroupCustom;

typedef struct DbGroupDef_struct {
    union {
        DbGroupIMDB dbgi;
        DbGroupNameSeason dbgns;
        DbGroupCustom dbgc;
    } u;
    DbGroupType dbg_type;

} DbGroupDef;

char *db_group_imdb_string_static(
        DbGroupIMDB *g,
        char *prefix // tt or nm
        );
char *db_group_imdb_compressed_string_static(DbGroupIMDB *g);

DbGroupIMDB *db_group_imdb_new(int size);
void db_group_imdb_free(DbGroupIMDB *g,int free_parent);
DbGroupIMDB *parse_imdb_list(char *val,int val_len,DbGroupIMDB *group);
DbGroupIMDB *get_raw_imdb_list(char *val,int val_len);

unsigned int db_overview_hashf(DbItem *item);
int db_overview_cmp_by_title(DbItem **item1,DbItem **item2);
int db_overview_cmp_by_age_desc(DbItem **item1,DbItem **item2);
int db_overview_cmp_by_year_asc(DbItem **item1,DbItem **item2);
int db_overview_cmp_by_season_asc(DbItem **item1,DbItem **item2);
int db_overview_name_eqf(DbItem *item1,DbItem *item2);
DbItem **sort_overview(struct hashtable *overview, int (*cmp_fn)(DbItem **,DbItem **));
struct hashtable *db_overview_hash_create(DbItemSet **rowsets,ViewMode *view);
void db_overview_hash_destroy(struct hashtable *ovw_hash);
void evaluate_group(DbGroupIMDB *group);

#define EVALUATE_GROUP(g) if (!(g)->evaluated) evaluate_group(g);

#endif
