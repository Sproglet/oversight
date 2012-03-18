
# changes here should be reflected in db.c:write_row()
function createIndexRow(minfo,db_index,watched,locked,index_time,\
row,est,nfo,op) {

    # Estimated download date. cant use nfo time as these may get overwritten.
    est=file_time(minfo["mi_folder"]"/unpak.log");
    if (est == "") {
        est=file_time(minfo["mi_folder"]"/unpak.txt");
    }
    if (est == "") {
        est = minfo["mi_file_time"];
    }

    if (minfo["mi_file"] == "" ) {
        minfo["mi_file"]=getPath(minfo["mi_media"],minfo["mi_folder"]);
    }
    minfo["mi_file"] = clean_path(minfo["mi_file"]);

    if ((minfo["mi_file"] in g_fldrCount ) && g_fldrCount[minfo["mi_file"]]) {
        DEBUG("Adjusting file for video_ts");
        minfo["mi_file"] = minfo["mi_file"] "/";
    }

    op="update";
    if (db_index == -1 ) {
        db_index = ++gMaxDatabaseId;
        op="add";
    }
    row="\t"ID"\t"db_index;
    INF("dbrow "op" ["db_index":"minfo["mi_file"]"]");

    row=row"\t"CATEGORY"\t"minfo["mi_category"];

    if (index_time == "") {
        if (RESCAN == 1 ) {
            index_time = est;
        } else {
            index_time = NOW;
        }
    }

    row=row"\t"INDEXTIME"\t"shorttime(index_time);

    row=row"\t"WATCHED"\t"watched;
    row=row"\t"LOCKED"\t"locked;

    #Title and Season must be kept next to one another to aid grepping.
    #Put the overview items near the start to speed up scanning
    row=row"\t"TITLE"\t"minfo["mi_title"];
    if (minfo["mi_orig_title"] != "" && norm_title(minfo["mi_orig_title"]) != norm_title(minfo["mi_title"]) ) {
        row=row"\t"ORIG_TITLE"\t"minfo["mi_orig_title"];
    }
    if (minfo["mi_season"] != "") row=row"\t"SEASON"\t"minfo["mi_season"];

    row=row"\t"RATING"\t"minfo["mi_rating"];

    if (minfo["mi_episode"] != "") row=row"\t"EPISODE"\t"minfo["mi_episode"];

    row=row"\t"GENRE"\t"short_genre(minfo["mi_genre"]);
    row=row"\t"RUNTIME"\t"minfo["mi_runtime"];

    if (minfo["mi_parts"]) row=row"\t"PARTS"\t"minfo["mi_parts"];

    row=row"\t"YEAR"\t"short_year(minfo["mi_year"]);

    row=row"\t"FILE"\t"short_path(minfo["mi_file"]);

    if (minfo["mi_additional_info"]) row=row"\t"ADDITIONAL_INF"\t"minfo["mi_additional_info"];

    row=row"\t"URL"\t"minfo["mi_idlist"];

    row=row"\t"CERT"\t"minfo["mi_certcountry"]":"minfo["mi_certrating"];

    if (minfo["mi_director_ids"]) row=row"\t"DIRECTORS"\t"minfo["mi_director_ids"];
    if (minfo["mi_actor_ids"]) row=row"\t"ACTORS"\t"minfo["mi_actor_ids"];
    if (minfo["mi_writer_ids"]) row=row"\t"WRITERS"\t"minfo["mi_writer_ids"];

    row=row"\t"FILETIME"\t"shorttime(minfo["mi_file_time"]);
    row=row"\t"DOWNLOADTIME"\t"shorttime(est);
    #row=row"\t"SEARCH"\t"g_search[i];


    if (minfo["mi_airdate"]) row=row"\t"AIRDATE"\t"minfo["mi_airdate"];

    if (minfo["mi_eptitle"]) row=row"\t"EPTITLE"\t"minfo["mi_eptitle"];
    nfo="";

    if (g_settings["catalog_nfo_write"] != "never" || is_file(minfo["mi_nfo_default"]) ) {
        nfo=minfo["mi_nfo_default"];
        gsub(/.*\//,"",nfo);
    }
    if (is_file(minfo["mi_folder"]"/"nfo)) {
        row=row"\t"NFO"\t"nfo;
    }
    if (minfo["mi_conn_follows"]) row=row"\t"CONN_FOLLOWS"\t"minfo["mi_conn_follows"];
    if (minfo["mi_conn_followed_by"]) row=row"\t"CONN_FOLLOWED"\t"minfo["mi_conn_followed_by"];
    if (minfo["mi_conn_remakes"]) row=row"\t"CONN_REMAKES"\t"minfo["mi_conn_remakes"];
    if (minfo["mi_video"]) row=row"\t"VIDEO"\t"minfo["mi_video"];
    if (minfo["mi_audio"]) row=row"\t"AUDIO"\t"minfo["mi_audio"];
    if (minfo["mi_mb"]) row=row"\t"SIZEMB"\t"minfo["mi_mb"];
    if (minfo["mi_videosource"]) row=row"\t"VIDEOSOURCE"\t"minfo["mi_videosource"];
    if (minfo["mi_subtitles"]) row=row"\t"SUBTITLES"\t"minfo["mi_subtitles"];

    return row"\t";
}
function genre_init(\
gnames,i) {
    
    if (!g_genre_count) {
        g_genre_count = split(g_settings["catalog_genre"],gnames,",");
    }
    for(i = 1 ; i <= g_genre_count ; i += 2) {
        g_genre_long2short["\\<"gnames[i]"o?\\>"] = gnames[i+1];
        g_genre_short2long["\\<"gnames[i+1]"\\>"] = gnames[i];
    }

}

function short_genre(g) {
    return convert_genre(g,g_genre_long2short);
}

function long_genre(g) {
    return convert_genre(g,g_genre_short2long);
}

function convert_genre(g,genre_map,\
i) {
    genre_init();
    for(i in genre_map) {
        if (match(g,i) ) {
           g = substr(g,1,RSTART-1) genre_map[i] substr(g,RSTART+RLENGTH); 
       }
    }
    gsub(/[- /,|]+/,"|",g);
    gsub(/^[|]/,"",g);
    gsub(/[|]$/,"",g);
    return g;
}

function replace_database_with_new(newdb,currentdb,olddb) {

    INF("Replace Database ["newdb"] to ["currentdb"] to ["olddb"]");

    file_copy(currentdb,olddb);

    touch_and_move(newdb,currentdb);

    set_permissions(qa(currentdb)" "qa(olddb));
}
function set_db_fields() {
    #DB fields should start with underscore to speed grepping etc.
    # Fields with @ are not written to the db.
    ID=db_field("_id","ID","");

    WATCHED=db_field("_w","Watched","watched") ;
    LOCKED=db_field("_l","Locked","locked") ;
    PARTS=db_field("_pt","PARTS","");
    FILE=db_field("_F","FILE","filenameandpath");
    NAME=db_field("_@N","NAME","");
    DIR=db_field("_@D","DIR","");
    EXT=db_field("_ext","EXT",""); # not a real field


    ORIG_TITLE=db_field("_ot","ORIG_TITLE","originaltitle");
    TITLE=db_field("_T","Title","title") ;
    DIRECTORS=db_field("_d","Director","director") ;
    ACTORS=db_field("_A","Actors","actors") ;
    WRITERS=db_field("_W","Writers","writers") ;
    CREATOR=db_field("_c","Creator","creator") ;
    AKA=db_field("_K","AKA","");

    CATEGORY=db_field("_C","Category","");
    ADDITIONAL_INF=db_field("_ai","Additional Info","");
    YEAR=db_field("_Y","Year","year",g_dbtype_year) ;

    SEASON=db_field("_s","Season","season") ;
    EPISODE=db_field("_e","Episode","episode");

    GENRE=db_field("_G","Genre","genre",g_dbtype_genre) ;
    RUNTIME=db_field("_rt","Runtime","runtime") ;
    RATING=db_field("_r","Rating","rating");
    CERT=db_field("_R","CERT","mpaa"); #Not standard?

    PLOT=db_field("_P","Plot","plot");
    #EPPLOT=db_field("_ep","Plot","plot");

    URL=db_field("_U","URL","url");
    POSTER=db_field("_J","Poster","thumb");
    FANART=db_field("_fa","Fanart","fanart");

    DOWNLOADTIME=db_field("_DT","Downloaded","",g_dbtype_time);
    INDEXTIME=db_field("_IT","Indexed","",g_dbtype_time);
    FILETIME=db_field("_FT","Modified","",g_dbtype_time);

    SEARCH=db_field("_SRCH","Search URL","search");
    PROD=db_field("_p","ProdId.","");
    AIRDATE=db_field("_ad","Air Date","aired");
    TVCOM=db_field("_tc","TvCom","");
    EPTITLE=db_field("_et","Episode Title","title");
    EPTITLEIMDB=db_field("_eti","Episode Title(imdb)","");
    AIRDATEIMDB=db_field("_adi","Air Date(imdb)","");
    NFO=db_field("_nfo","NFO","nfo");

    IMDBID=db_field("_imdb","IMDBID","id");
    TVID=db_field("_tvid","TVID","id");
    CONN_FOLLOWS=db_field("_a","FOLLOWS","",g_dbtype_imdblist); # Comes After
    CONN_FOLLOWED=db_field("_b","FOLLOWED","",g_dbtype_imdblist); # Comes Before
    CONN_REMAKES=db_field("_k","REMAKES","",g_dbtype_imdblist); # Movies remaKes

    VIDEO=db_field("_v","VIDEO","");
    AUDIO=db_field("_S","SOUND","");
    SUBTITLES=db_field("_L","SUBS","");
    VIDEOSOURCE=db_field("_V","VIDEOSOURCE","");
    SIZEMB=db_field("_m","SIZEMB","");
}


#Setup db_field identifier, pretty name ,
# IN key = database key and html parameter
# IN name = logical name
# IN tag = xml tag in xmbc nfo files.
function db_field(key,name,tag,type) {
    gsub(/ /,"_",name);
    g_db_field_name[key]=name;
    gDbTag2FieldId[tag]=key;
    gDbFieldId2Tag[key]=tag;
    g_dbtype[key]=type;
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
    return exec("sed -r 's/(.*)(\t"fieldId"\t[^\t]*)(.*)/\\2\\1\\3/' "qa(file_in)" | "SORT" > "qa(file_out)) == 0;
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
    #DEBUG("eof:"file);
    return "";
}

function keep_dbline(row,fields,\
result) {

    get_name_dir_fields(fields);

    if (length(row) > g_max_db_len ) {

        INF("Row too long");

    } else if ( g_settings["catalog_ignore_paths"] != "" && fields[DIR] ~ g_settings["catalog_ignore_paths"] ) {

        INF("Removing Ignored Path ["fields[FILE]"]");

    } else if ( fields[NAME] ~ g_settings["catalog_ignore_names"] ) {

        INF("Removing Ignored Name "fields[FILE]"]");

    } else {
        result = 1;
    }
    return result;
}

function write_dbline(fields,file,\
f) {
    for (f in fields) {
        if (f && index(f,"@") == 0) {
            if (f == FILE) {
                printf "\t%s\t%s",f,short_path(fields[f]) >> file;
            } else {
                printf "\t%s\t%s",f,fields[f] >> file;
            }
        }
    }
    printf "\t\n" >> file;
}




# Get all of the files that have already been scanned that start with the 
# same prefix.
function get_files_in_db(prefix,db,list,\
dbline,dbfields,err,count,filter) {

    count = 0;
    delete list;
    list["@PREFIX"] = prefix =  short_path(prefix);
    list["@REGEX"] = filter = "\t" FILE "\t" re_escape(prefix) "/?[^/]*\t";

    #INF("filter=["filter"]");

    while((err = (getline dbline < db )) > 0) {

        if ( index(dbline,prefix) && dbline ~ filter ) {

            parseDbRow(dbline,dbfields,1);

            add_file(dbfields[FILE],list);

            count++;
        }
    }
    if (err >= 0 ) close(db);
    #DEBUG("get_files_in_db ["prefix"]="count" files");
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

    INF("Pruning...");
    tmp_db = db "." JOBID ".tmp";

    # TODO if index is sorted by file we can do this a folder at a time.
    # TODO : not needed : get_files_in_db("",db);

    if (lock(g_db_lock_file)) {
        g_kept_file_count=0;
        g_absent_file_count=0;

        close(db);
        while((getline dbline < db ) > 0) {

            if ( index(dbline,"\t") != 1 ) { continue; }

            parseDbRow(dbline,dbfields,1);

            f = dbfields[FILE];
            shortf = short_path(f);
            #INF("Prune ? ["f"]");

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
                            DEBUG("re = "blacklist_re);
                        }
                    } else {
                        gp = mount_point(f);
                        if (gp != "/share" ) {
                            #if gp folder is present then delete
                            if (is_dir(gp) && !is_empty(gp)) {
                                keep=0;
                            } else {
                                INF("Not mounted?");
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
                INF("Removing "f);
                g_absent_file_count++;
                
            }
            last_shortf = shortf;
        }
        close(tmp_db);
        close(db);
        INF("unchanged:"g_kept_file_count);
        INF("removed:"g_absent_file_count);
        replace_database_with_new(tmp_db,db,INDEX_DB_OLD);
        unlock(g_db_lock_file);
    }
}

