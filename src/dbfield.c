// $Id$
#include "dbfield.h"
#include "util.h"
#define NULL ((void *)0)

struct hashtable *dbf_macro_to_id = NULL;
struct hashtable *dbf_id_to_macro = NULL; 

void add_label(char *field_id,char *macro_tag)
{
    hashtable_insert(dbf_macro_to_id,macro_tag,field_id);
    hashtable_insert(dbf_id_to_macro,field_id,macro_tag);
}

void dbf_ids_init()
{

    if (dbf_id_to_macro) return;

    dbf_id_to_macro = string_string_hashtable("field_id_to_macro",32);
    dbf_macro_to_id = string_string_hashtable("field_macro_to_id",32);

    add_label(DB_FLDID_ID,"ID");
    add_label(DB_FLDID_WATCHED,"WATCHED");
    add_label(DB_FLDID_LOCKED,"LOCKED");
    add_label(DB_FLDID_PARTS,"PARTS");
    add_label(DB_FLDID_FILE,"FILE");
    add_label(DB_FLDID_NAME,"NAME");
    add_label(DB_FLDID_DIR,"DIR");
    add_label(DB_FLDID_DIRECTOR_LIST,"DIRECTORS");
    add_label(DB_FLDID_ACTOR_LIST,"ACTORS");
    add_label(DB_FLDID_WRITER_LIST,"WRITERS");


    add_label(DB_FLDID_ORIG_TITLE,"ORIG_TITLE");
    add_label(DB_FLDID_TITLE,"TITLE");
    add_label(DB_FLDID_AKA,"AKA");

    add_label(DB_FLDID_CATEGORY,"CATEGORY");
    add_label(DB_FLDID_ADDITIONAL_INFO,"EXTRA_INFO");
    add_label(DB_FLDID_YEAR,"YEAR");

    add_label(DB_FLDID_SEASON,"SEASON");
    add_label(DB_FLDID_EPISODE,"EPISODE");

    add_label(DB_FLDID_GENRE,"GENRE");
    add_label(DB_FLDID_RATING,"RATING");
    add_label(DB_FLDID_CERT,"CERT");
    add_label(DB_FLDID_PLOT,"PLOT");
    add_label(DB_FLDID_EPPLOT,"EPPLOT");
    add_label(DB_FLDID_URL,"URL");
    add_label(DB_FLDID_POSTER,"POSTER");

    add_label(DB_FLDID_DOWNLOADTIME,"DOWNLOADTIME");
    add_label(DB_FLDID_INDEXTIME,"INDEXTIME");
    add_label(DB_FLDID_FILETIME,"FILETIME");

    add_label(DB_FLDID_PROD,"PRODID");
    add_label(DB_FLDID_AIRDATE,"AIRDATE");
    add_label(DB_FLDID_TOP250,"TOP250");
    add_label(DB_FLDID_EPTITLE,"EPTITLE");
    add_label(DB_FLDID_EPTITLEIMDB,"IMDB_EPTITLE");
    add_label(DB_FLDID_AIRDATEIMDB,"IMDB_AIRDATE");
    add_label(DB_FLDID_NFO,"NFO");

    add_label(DB_FLDID_VIDEO,"VIDEO");
    add_label(DB_FLDID_AUDIO,"AUDIO");
    add_label(DB_FLDID_VIDEOSOURCE,"VIDEOSOURCE");
    add_label(DB_FLDID_SIZEMB,"SIZEMB");
    add_label(DB_FLDID_SUBTITLES,"SUBTITLES");
}

char *dbf_macro_to_fieldid(char *macro)
{
    if (dbf_macro_to_id == NULL) {
        dbf_ids_init();
    }
    return hashtable_search(dbf_macro_to_id,macro);
}

char *dbf_fieldid_to_macro(char *fieldid)
{
    if (dbf_id_to_macro == NULL) {
        dbf_ids_init();
    }
    return hashtable_search(dbf_id_to_macro,fieldid);
}

// vi:sw=4:et:ts=4
