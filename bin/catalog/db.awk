function sequence() {
    return ++gMaxDatabaseId;
}

function replace_database_with_new(newdb,currentdb,olddb) {

    if(LD)DETAIL("Replace Database ["newdb"] to ["currentdb"] to ["olddb"]");

    file_copy(currentdb,olddb);

    touch_and_move(newdb,currentdb);

    set_permissions(qa(currentdb)" "qa(olddb));
}
function set_db_fields() {
    #DB fields should start with underscore to speed grepping etc.
    # Fields with @ are not written to the db.
    ID=db_field("_id","ID","",g_dbtype_int,1);

    WATCHED=db_field("_w","Watched","watched",g_dbtype_int,1) ;
    LOCKED=db_field("_l","Locked","locked",g_dbtype_int,1) ;
    PARTS=db_field("_pt","PARTS","",g_dbtype_string,1);
    FILE=db_field("_F","FILE","filenameandpath",g_dbtype_path,1);
    NAME=db_field("_@N","NAME","",g_dbtype_string,0);
    DIR=db_field("_@D","DIR","",g_dbtype_string,0);
    EXT=db_field("_ext","EXT","",g_dbtype_string,0); # not a real field

    ORIG_TITLE=db_field("_ot","ORIG_TITLE","originaltitle",g_dbtype_string,1);
    TITLE=db_field("_T","Title","title",g_dbtype_string,1) ;
    DIRECTORS=db_field("_d","Director","director",g_dbtype_string,1) ;
    ACTORS=db_field("_A","Actors","actors",g_dbtype_string,1) ;
    WRITERS=db_field("_W","Writers","writers",g_dbtype_string,1) ;

    CATEGORY=db_field("_C","Category","",g_dbtype_string,1);
    ADDITIONAL_INF=db_field("_ai","Additional Info","",g_dbtype_string,1);
    YEAR=db_field("_Y","Year","year",g_dbtype_year,1) ;

    SEASON=db_field("_s","Season","season",g_dbtype_string,1) ;
    EPISODE=db_field("_e","Episode","episode",g_dbtype_string,1);

    GENRE=db_field("_G","Genre","genre",g_dbtype_genre,1) ;
    RUNTIME=db_field("_rt","Runtime","runtime",g_dbtype_string,1) ;
    RATING=db_field("_r","Rating","rating",g_dbtype_string,1);
    CERT=db_field("_R","CERT","mpaa",g_dbtype_string,1); #Not standard?

    PLOT=db_field("_P","Plot","plot",g_dbtype_string,0);
    EPPLOT=db_field("_ep","EpPlot","plot",g_dbtype_string,0);

    IDLIST=db_field("_U","IDs","idlist",g_dbtype_string,1);
    POSTER=db_field("_J","Poster","thumb",g_dbtype_string,0);
    FANART=db_field("_fa","Fanart","fanart",g_dbtype_string,0);

    DOWNLOADTIME=db_field("_DT","Downloaded","",g_dbtype_time,1);
    INDEXTIME=db_field("_IT","Indexed","",g_dbtype_time,1);
    FILETIME=db_field("_FT","Modified","",g_dbtype_time,1);

    SEARCH=db_field("_SRCH","Search URL","search",g_dbtype_string,0);
    AIRDATE=db_field("_ad","Air Date","aired",g_dbtype_string,1);
    EPTITLE=db_field("_et","Episode Title","title",g_dbtype_string,1);
    NFO=db_field("_nfo","NFO","nfo",g_dbtype_string,0);

    IMDBID=db_field("_imdb","IMDBID","id",g_dbtype_string,0);
    TVID=db_field("_tvid","TVID","id",g_dbtype_string,0);
    SET=db_field("_a","SET","set",g_dbtype_string,1); 

    VIDEO=db_field("_v","VIDEO","",g_dbtype_string,1);
    AUDIO=db_field("_S","SOUND","",g_dbtype_string,1);
    SUBTITLES=db_field("_L","SUBS","",g_dbtype_string,1);
    VIDEOSOURCE=db_field("_V","VIDEOSOURCE","",g_dbtype_string,1);
    SIZEMB=db_field("_m","SIZEMB","",g_dbtype_string,1);

    # Transitory fields - add to suppress unknown dbtype errors
    db_field("mi_do_scrape","","",g_dbtype_string,1);
    db_field("mi_writer_total","","",g_dbtype_string,1);
    db_field("mi_writer_names","","",g_dbtype_string,1);
    db_field("mi_writer_ids","","",g_dbtype_string,1);
    db_field("mi_actor_total","","",g_dbtype_string,1);
    db_field("mi_actor_ids","","",g_dbtype_string,1);
    db_field("mi_actor_names","","",g_dbtype_string,1);
    db_field("mi_director_total","","",g_dbtype_string,1);
    db_field("mi_director_names","","",g_dbtype_string,1);
    db_field("mi_director_ids","","",g_dbtype_string,1);
    db_field("mi_certcountry","","",g_dbtype_string,1);
    db_field("mi_certrating","","",g_dbtype_string,1);
    db_field("mi_visited","","",g_dbtype_string,1);
    db_field("mi_imdb_title","","",g_dbtype_string,1);
    db_field("mi_url","","",g_dbtype_string,1);
    db_field("mi_set_name","","",g_dbtype_string,1);
}

function db_fieldname(fld,\
ret) {
    ret = g_db_field_name[fld];
    if (ret == "") ret = fld;
    return ret;
}

#Setup db_field identifier, pretty name ,
# IN key = database key and html parameter
# IN name = logical name
# IN tag = xml tag in xmbc nfo files.
function db_field(key,name,tag,type,keep) {
    if (keep == "") {
        if(LD)DETAIL("bad args db_field "key name tag type);
        exit;
    }
    if (name == "") name = key;
    gsub(/ /,"_",name);
    g_db_field_name[key]=name;
    gDbTag2FieldId[tag]=key;
    gDbFieldId2Tag[key]=tag;
    g_dbtype[key]=type;
    g_dbkeep[key]=keep; #if written to final index.db
    return key;
}
##### LOADING INDEX INTO DB_ARR[] ###############################

#Used by generate nfo
function parseDbRow(row,arr,add_mount,\
fields,i,fnum) {

    delete arr;

    fnum = split(row,fields,"\t");
    for(i = 2 ; i-fnum <= 0 ; i+=2 ) {
        arr[fields[i]] = fields[i+1];
    }
    if (add_mount &&  arr[FILE] != "" && index(arr[FILE],"/") != 1 ) {
        arr[FILE] = g_mount_root arr[FILE];
    }
    arr[FILE] = clean_path(arr[FILE]);
}

function get_name_dir_fields(arr,\
f,fileRe) {

    if (!arr[NAME] && !arr[DIR]) {
        f =  arr[FILE];

        if (isDvdDir(f)) {
            fileRe="/[^/]+/$"; # /path/to/name/[VIDEO_TS]
        } else {
            fileRe="/[^/]+$";  # /path/to/name.avi
        }

        if (match(f,fileRe)) {
            arr[NAME] = substr(f,RSTART+1);
            arr[DIR] = substr(f,1,RSTART-1);
        }
    }
}

# Sort index by file path
function sort_index(file_in,file_out) {
    return sort_index_by_field(FILE,file_in,file_out);
}

function sort_index_by_field(fieldId,file_in,file_out) {
    return exec("sed -r 's/(.*)(\t"fieldId"\t[^\t]*)(.*)/\\2\\1\\3/' "qa(file_in)" | sort > "qa(file_out)) == 0;
}

function get_dbline(file,\
line) {
    while ((getline line < file ) > 0 ) {
        if (index(line,"\t") == 1) {
            return line;
            break;
        }
    }
    close(file);
    #if(LG)DEBUG("eof:"file);
    return "";
}

function keep_dbline(fields,\
result) {

    get_name_dir_fields(fields);

    if ( g_settings["catalog_ignore_paths"] != "" && fields[DIR] ~ g_settings["catalog_ignore_paths"] ) {

        if(LD)DETAIL("Removing Ignored Path ["fields[FILE]"]");

    } else if ( fields[NAME] ~ g_settings["catalog_ignore_names"] ) {

        if(LD)DETAIL("Removing Ignored Name "fields[FILE]"]");

    } else {
        result = 1;
    }
    return result;
}

function write_dbline(fields,file,final,\
f,est,line) {
    if (fields[FILE] == "" ) {
        fields[FILE]=getPath(fields[NAME],fields[DIR]);
    }
    fields[FILE] = clean_path(fields[FILE]);

    if ((fields[FILE] in g_fldrCount ) && g_fldrCount[fields[FILE]]) {
        if(LG)DEBUG("Adjusting file for video_ts");
        fields[FILE] = fields[FILE] "/";
    }

    if (fields[CERT] == "") {
        fields[CERT] = fields["mi_certcountry"]":"fields["mi_certrating"];
        sub(/^:/,"",fields[CERT]);
    }
    if (g_settings["catalog_nfo_write"] != "never" || is_file(fields[NFO]) ) {
        gsub(/.*\//,"",fields[NFO]);
    } else {
        fields[NFO] = "";
    } 
    if (fields[ORIG_TITLE] != "" && norm_title(fields[ORIG_TITLE]) == norm_title(fields[TITLE]) ) {
        fields[ORIG_TITLE] = "";
    }

    # Estimated download date. cant use nfo time as these may get overwritten.
    est=file_time(fields[DIR]"/unpak.log");
    if (est == "") {
        est=file_time(fields[DIR]"/unpak.txt");
    }
    if (est == "") {
        est = fields[FILETIME];
    }
    fields[DOWNLOADTIME] = est;

    if (RESCAN == 1 ) {
        fields[INDEXTIME] = est;
    } else {
        fields[INDEXTIME] = NOW;
    }

    for (f in fields) {
        if (f && f ~ /^_/ ) {
            if (!final || g_dbkeep[f]) { #write field if intermediate computation  OR it is flagged for final index.db(g_dbkeep)
                if (fields[f] != "") {
                    line = line "\t" f "\t" shortform(f,fields[f]);
                }
            }
        }
    }
    print line"\t" >> file;
}




# Get all of the files that have already been scanned that start with the 
# same prefix.
function get_files_in_db(prefix,db,list,\
dbline,dbfields,err,count,filter) {

    count = 0;
    delete list;
    list["@PREFIX"] = prefix =  short_path(prefix);
    list["@REGEX"] = filter = "\t" FILE "\t" re_escape(prefix) "/?[^/]*\t";

    #if(LD)DETAIL("filter=["filter"]");

    while((err = (getline dbline < db )) > 0) {

        if ( index(dbline,prefix) && dbline ~ filter ) {

            parseDbRow(dbline,dbfields,1);

            add_file(dbfields[FILE],list);

            count++;
        }
    }
    if (err >= 0 ) close(db);
    #if(LG)DEBUG("get_files_in_db ["prefix"]="count" files");
}



# Re-instate old pruning test with extra folder check for absent media
# Because we need to check every file in the database it can take some time
# also if using awk we want to avoid spawning a process (or two) for each check
# so ls is used. If a file is absent then it is removed only if its grandparent is 
# present - this is to allow for detached devices. (sort of)
function remove_absent_files_from_new_db(db,\
    tmp_db,dbfields,\
    list,f,shortf,last_shortf,maxCommandLength,dbline,keep,\
    gp,blacklist_re,blacklist_dir,timer) {
    list="";
    maxCommandLength=3999;

    if(LD)DETAIL("Pruning...");
    tmp_db = db "." JOBID ".tmp";

    # TODO if index is sorted by file we can do this a folder at a time.
    # TODO : not needed : get_files_in_db("",db);

    if (lock(g_db_lock_file)) {
        exec("wc -l "qa(db));
        g_kept_file_count=0;
        g_absent_file_count=0;

        close(db);
        while((getline dbline < db ) > 0) {

            if ( index(dbline,"\t") != 1 ) { continue; }

            parseDbRow(dbline,dbfields,1);

            f = dbfields[FILE];
            shortf = short_path(f);
            #if(LD)DETAIL("Prune ? ["f"]");

            keep=1;

            # as db is in file order we can prune duplicates by comparing with last file
            if (shortf == last_shortf) {
                keep = 0;
                WARNING("Skipping "f" - duplicate");


            } else if (blacklist_re != "" && f ~ "NETWORK_SHARE/("blacklist_re")" ) {

                WARNING("Skipping "f" - blacklisted device");
            } else {

                timer = systime();
                if (is_file_or_folder(f) == 0 ) {
                    if (systime()-timer > 10) {
                        # error accessing nas - blacklist this path.
                        blacklist_dir = f;
                        if (match(f,"NETWORK_SHARE/[^/]+/")) {
                            blacklist_dir = substr(f,RSTART,RLENGTH);
                            sub(/.*NETWORK_SHARE/,"",blacklist_dir);
                            ERR("Unresponsive device : Blacklisting access to NETWORK_SHARE"blacklist_dir);
                            blacklist_re = blacklist_re "|" blacklist_dir;
                            if(LG)DEBUG("re = "blacklist_re);
                        }
                    } else {
                        gp = mount_point(f);
                        if (gp != "/share" ) {
                            #if gp folder is present then delete
                            if (is_dir(gp) && !is_empty(gp)) {
                                keep=0;
                            } else {
                                if(LD)DETAIL("Not mounted?");
                            }
                        } else {
                            # just delete it.
                            keep=0;
                        }
                    }
                }
            }


            if (keep) {
                print dbline > tmp_db;
                g_kept_file_count++;
            } else {
                if(LD)DETAIL("Removing "f);
                g_absent_file_count++;
                
            }
            last_shortf = shortf;
        }
        close(tmp_db);
        close(db);
        if(LD)DETAIL("unchanged:"g_kept_file_count);
        if(LD)DETAIL("removed:"g_absent_file_count);
        replace_database_with_new(tmp_db,db,INDEX_DB_OLD);
        exec("wc -l "qa(db));
        unlock(g_db_lock_file);
    }
}

