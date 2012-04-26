#ifndef __DB_OVERVIEW_ALORD__
#define __DB_OVERVIEW_ALORD__

#include "types.h"
#include "db.h"

void init_view();
char *db_group_imdb_string_static(
        DbGroupIMDB *g
        );
char *db_group_imdb_compressed_string_static(DbGroupIMDB *g);

DbGroupIMDB *db_group_imdb_new(int size,char *prefix);
void db_group_imdb_free(DbGroupIMDB *g,int free_parent);
DbGroupIMDB *parse_imdb_list(char *prefix,char *val,int val_len,DbGroupIMDB *group);
DbGroupIMDB *get_raw_imdb_list(char *val,int val_len,char *prefix);

unsigned int db_overview_hashf(DbItem *item);
int db_overview_cmp_by_title(DbItem **item1,DbItem **item2);
int db_overview_cmp_by_age_desc(DbItem **item1,DbItem **item2);
int db_overview_cmp_by_year_asc(DbItem **item1,DbItem **item2);
int db_overview_cmp_by_season_asc(DbItem **item1,DbItem **item2);
int db_overview_name_eqf(DbItem *item1,DbItem *item2);
DbItem **sort_overview(struct hashtable *overview, int (*cmp_fn)(DbItem **,DbItem **));
DbItem **sort_linked_items(DbItem *item,int (*cmp_fn)(DbItem **,DbItem **));
struct hashtable *db_overview_hash_create(DbItemSet **rowsets,ViewMode *view);
void db_overview_hash_destroy(struct hashtable *ovw_hash);
void evaluate_group(DbGroupIMDB *group);
int id_in_db_imdb_group(int id,DbGroupIMDB *g);
#define EVALUATE_GROUP(g) if (!(g)->evaluated) evaluate_group(g);

#endif
