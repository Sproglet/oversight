#include "dbfield.h"
#include "util.h"
#define NULL ((void *)0)

struct hashtable *dbf_ids = NULL;

void dbf_ids_init() {

    if (dbf_ids != NULL) return;

    dbf_ids = string_string_hashtable();

    hashtable_insert(dbf_ids,DB_FLDID_ID,"ID");
    hashtable_insert(dbf_ids,DB_FLDID_WATCHED,"Watched");
    hashtable_insert(dbf_ids,DB_FLDID_ACTION,"Next Operation");
    hashtable_insert(dbf_ids,DB_FLDID_PARTS,"PARTS");
    hashtable_insert(dbf_ids,DB_FLDID_FILE,"FILE");
    hashtable_insert(dbf_ids,DB_FLDID_NAME,"NAME");
    hashtable_insert(dbf_ids,DB_FLDID_DIR,"DIR");


    hashtable_insert(dbf_ids,DB_FLDID_ORIG_TITLE,"ORIG_TITLE");
    hashtable_insert(dbf_ids,DB_FLDID_TITLE,"Title");
    hashtable_insert(dbf_ids,DB_FLDID_AKA,"AKA");

    hashtable_insert(dbf_ids,DB_FLDID_CATEGORY,"Category");
    hashtable_insert(dbf_ids,DB_FLDID_ADDITIONAL_INFO,"Additional Info");
    hashtable_insert(dbf_ids,DB_FLDID_YEAR,"Year");

    hashtable_insert(dbf_ids,DB_FLDID_SEASON,"Season");
    hashtable_insert(dbf_ids,DB_FLDID_EPISODE,"Episode");
    hashtable_insert(dbf_ids,DB_FLDID_SEASON0,"0SEASON");
    hashtable_insert(dbf_ids,DB_FLDID_EPISODE0,"0EPISODE");

    hashtable_insert(dbf_ids,DB_FLDID_GENRE,"Genre");
    hashtable_insert(dbf_ids,DB_FLDID_RATING,"Rating");
    hashtable_insert(dbf_ids,DB_FLDID_CERT,"CERT");
    hashtable_insert(dbf_ids,DB_FLDID_PLOT,"Plot");
    hashtable_insert(dbf_ids,DB_FLDID_URL,"URL");
    hashtable_insert(dbf_ids,DB_FLDID_POSTER,"Poster");

    hashtable_insert(dbf_ids,DB_FLDID_DOWNLOADTIME,"Downloaded");
    hashtable_insert(dbf_ids,DB_FLDID_INDEXTIME,"Indexed");
    hashtable_insert(dbf_ids,DB_FLDID_FILETIME,"Modified");

    hashtable_insert(dbf_ids,DB_FLDID_SEARCH,"Search URL");
    hashtable_insert(dbf_ids,DB_FLDID_PROD,"ProdId.");
    hashtable_insert(dbf_ids,DB_FLDID_AIRDATE,"Air Date");
    hashtable_insert(dbf_ids,DB_FLDID_TVCOM,"TvCom");
    hashtable_insert(dbf_ids,DB_FLDID_EPTITLE,"Episode Title");
    hashtable_insert(dbf_ids,DB_FLDID_EPTITLEIMDB,"Episode Title(imdb)");
    hashtable_insert(dbf_ids,DB_FLDID_AIRDATEIMDB,"Air Date(imdb)");
    hashtable_insert(dbf_ids,DB_FLDID_NFO,"NFO");
}

char *dbf_label(char *id) {
    if (dbf_ids == NULL) {
        dbf_ids_init();
    }

    return hashtable_search(dbf_ids,id);
}

