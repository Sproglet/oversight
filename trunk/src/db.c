#include "db.h"

char *db_get_lock_file_name() {
    char *s;
    ovs_asprintf(&s,"%s/catalog.lck",getenv("APPDIR"));
    return s;
}

int db_lock(char *source) {

    int backoff[] = { 10,10,10,10,10,10,20,30, 0 };
    char *lockfile = db_get_lock_file_name(source);

    int attempt;

    for(attempt = 0 ; backoff[attempt] ; attempt++ ) {

        if (!db_is_locked(source)) {
            sleep(backoff[attempt]);
            html_log(0,"Sleeping for %d\n",backoff[attempt]);

            FILE *fp = fopen(lockfile,"w");
            fprintf("%d\n",getpid());
            fclose(fp);
            free(lockfile);
            return 1;
        }
    }
    html_error("Failed to get lock [%s]\n",lockfile);
    free(lockfile);
    return 0;
}

int db_unlock(char *source) {
    char *lockfile = db_get_lock_file_name(source);
    unlink(lockfile);
}

/*
 * Load the database. Each database entry will just be an ID and a pointer to the DB file position
 * (see DbRow)
 */
Db *db_init(char *filename, // path to the file
        char *source       // logical name or tag - local="*"
        ) {
    Db db = MALLOC(sizeof(Db));

    db->path =  STRDUP(filename);
    db->source= STRDUP(source);


}

void db_scan_titles(
        Db *db,
        char *name_filter,  // only load lines whose titles match the filter
        int media_type,     // 1=TV 2=MOVIE 3=BOTH 
        int watched         // 1=watched 2=unwatched 3=any
        ){

    regex_t pattern;
    FILE *fp = fopen(db->fopen,"r");
    struct hashtable *rows = db_create_hashtable();

    html_log(3,"Creating db scan pattern..");

    if (name_filter) {
        // Take the pattern and turn it into <TAB>_ID<TAB>pattern<TAB>
        char *full_regex_text;

        ovs_asprintf(&pattern,"\t%s\t%s\t",DB_FIELD_ID_ID,name_filter);

        if ((status = regcomp(&pattern,full_regex_text,REG_EXTENDED)) != 0) {

#define BUFSIZE 256
            char buf[BUFSIZE];
            regerror(status,&re,buf,BUFSIZE);
            fprintf(stderr,"%s\n",buf);
            assert(1);

            return NULL;
        }
        free(full_regex_text);
    }

    html_log(3,"db scanning...");

    FILE *fp = fopen(db->filename);
    if (fp) {
        unsigned long pos;
        while (1) {
            pos = ftell(fp);
            if (fgets(dbrow,DB_ROW_BUF_SIZE,fp) == NULL) break;

            if (chomp(dbrow) == 0 ) {
                html_error("Long db line alert");
                exit(1);
            }
    }
    fclose(fp);
// DO WE JUST USE AN ARRAY AND SCAN IT OR DO WE MAINTAIN AN ELABORATE HASH STRUCTURE

}



