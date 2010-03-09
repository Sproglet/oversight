#ifndef __DB_OVERVIEW_ALORD__
#define __DB_OVERVIEW_ALORD__


unsigned int db_overview_hashf(DbRowId *rid);
int db_overview_cmp_by_title(DbRowId *rid1,DbRowId *rid2);
int db_overview_cmp_by_age(DbRowId *rid1,DbRowId *rid2);
int db_overview_name_eqf(void *rid1,void *rid2);
DbRowId **sort_overview(struct hashtable *overview, int (*cmp_fn)(DbRowId *,DbRowId *));
struct hashtable *db_overview_hash_create(DbRowSet **rowsets);
void db_overview_hash_destroy(struct hashtable *ovw_hash);

#endif
