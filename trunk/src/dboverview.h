#ifndef __DB_OVERVIEW_ALORD__
#define __DB_OVERVIEW_ALORD__

#include "db.h"

// A Group of related rows. This may be :
// a movie boxset (a list of related imdb numbers)
// a tv box set. ( a Title and a Season. )
// a tv box series. ( a Title . )
// a custom group (A tag which will be stored against the item)
typedef enum DbGroupType_enum { DB_GROUP_BY_IMDB_LIST , DB_GROUP_BY_NAME_TYPE_SEASON , DB_GROUP_BY_CUSTOM_TAG } DbGroupType;

typedef struct DbGroupIMDB_struct {
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
        DbGroupNameSeason dbgnts;
        DbGroupCustom dbgc;
    } u;
    DbGroupType dbg_type;

} DbGroupDef;


unsigned int db_overview_hashf(DbRowId *rid);
int db_overview_cmp_by_title(DbRowId *rid1,DbRowId *rid2);
int db_overview_cmp_by_age(DbRowId *rid1,DbRowId *rid2);
int db_overview_name_eqf(void *rid1,void *rid2);
DbRowId **sort_overview(struct hashtable *overview, int (*cmp_fn)(DbRowId *,DbRowId *));
struct hashtable *db_overview_hash_create(DbRowSet **rowsets);
void db_overview_hash_destroy(struct hashtable *ovw_hash);

#endif
