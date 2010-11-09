#ifndef __DB_FIELD_ALORD__
#define __DB_FIELD_ALORD__

#define DB_FLDID_ID "_id"
#define DB_FLDID_SEASONID "_si"

#define DB_FLDID_WATCHED "_w"
#define DB_FLDID_LOCKED "_l"
#define DB_FLDID_ACTION "_a"
#define DB_FLDID_PARTS "_pt"
#define DB_FLDID_FILE "_F"
#define DB_FLDID_NAME "_N"
#define DB_FLDID_DIR "_D"


#define DB_FLDID_ORIG_TITLE "_ot"
#define DB_FLDID_TITLE "_T"
#define DB_FLDID_AKA "_K"

#define DB_FLDID_CATEGORY "_C"
#define DB_FLDID_ADDITIONAL_INFO "_ai"
#define DB_FLDID_YEAR "_Y"

#define DB_FLDID_SEASON "_s"
#define DB_FLDID_EPISODE "_e"
#define DB_FLDID_SEASON0 "0_s"
#define DB_FLDID_EPISODE0 "0_e"

#define DB_FLDID_RUNTIME "_rt"
#define DB_FLDID_GENRE "_G"
#define DB_FLDID_RATING "_r"
#define DB_FLDID_CERT "_R"
#define DB_FLDID_DIRECTOR_LIST "_d"
#define DB_FLDID_EPPLOT "_ep"
#define DB_FLDID_PLOT "_P"
#define DB_FLDID_URL "_U"
#define DB_FLDID_POSTER "_J"
#define DB_FLDID_FANART "_fa"

#define DB_FLDID_DOWNLOADTIME "_DT"
#define DB_FLDID_INDEXTIME "_IT"
#define DB_FLDID_FILETIME "_FT"

#define DB_FLDID_SEARCH "_SRCH"
#define DB_FLDID_PROD "_p"
#define DB_FLDID_AIRDATE "_ad"
#define DB_FLDID_TVCOM "_tc"
#define DB_FLDID_EPTITLE "_et"
#define DB_FLDID_EPTITLEIMDB "_eti"
#define DB_FLDID_AIRDATEIMDB "_adi"
#define DB_FLDID_NFO "_nfo"
#define DB_FLDID_COMES_AFTER "_a"
#define DB_FLDID_COMES_BEFORE "_b"
#define DB_FLDID_REMAKE "_k"
#define DB_FLDID_ACTOR_LIST "_A"
#define DB_FLDID_WRITER_LIST "_W"

#define FIELD_TYPE_NONE '-'
#define FIELD_TYPE_STR 's'
#define FIELD_TYPE_DOUBLE 'f'
#define FIELD_TYPE_CHAR 'c'
#define FIELD_TYPE_LONG 'l'
#define FIELD_TYPE_YEAR 'y'
#define FIELD_TYPE_INT 'i'
#define FIELD_TYPE_DATE 'd'
#define FIELD_TYPE_TIMESTAMP 't'
#define FIELD_TYPE_IMDB_LIST 'I'
#define FIELD_TYPE_IMDB_LIST_NOEVAL 'j'

char *dbf_macro_to_fieldid(char *macro);
char *dbf_fieldid_to_macro(char *fieldid);

#endif
