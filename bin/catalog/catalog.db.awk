
# changes here should be reflected in db.c:write_row()
function createIndexRow(minfo,db_index,watched,locked,index_time,\
row,est,nfo,op,start) {

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
    if (minfo["mi_orig_title"] != "" && minfo["mi_orig_title"] != minfo["mi_title"] ) {
        row=row"\t"ORIG_TITLE"\t"minfo["mi_orig_title"];
    }
    if (minfo["mi_season"] != "") row=row"\t"SEASON"\t"minfo["mi_season"];

    row=row"\t"RATING"\t"minfo["mi_rating"];

    if (minfo["mi_episode"] != "") row=row"\t"EPISODE"\t"minfo["mi_episode"];

    row=row"\t"GENRE"\t"short_genre(minfo["mi_genre"]);
    row=row"\t"RUNTIME"\t"minfo["mi_runtime"];

    if (minfo["mi_parts"]) row=row"\t"PARTS"\t"minfo["mi_parts"];

    row=row"\t"YEAR"\t"short_year(minfo["mi_year"]);

    start=1;
    if (index(minfo["mi_file"],g_mount_root) == 1) {
        start += length(g_mount_root);
    }
    row=row"\t"FILE"\t"substr(minfo["mi_file"],start);

    if (minfo["mi_additional_info"]) row=row"\t"ADDITIONAL_INF"\t"minfo["mi_additional_info"];


    if (minfo["mi_imdb"] == "") {
        # Need to have some kind of id for the plot.
        minfo["mi_imdb"]=minfo["mi_tvid_plugin"]"_"minfo["mi_tvid"];
        if (minfo["mi_imdb"] == "") {
            # Need to have some kind of id for the plot.
            minfo["mi_imdb"]="ovs"PID"_"systime();
        }
    }
    row=row"\t"URL"\t"minfo["mi_imdb"];

    row=row"\t"CERT"\t"minfo["mi_certcountry"]":"minfo["mi_certrating"];
    if (minfo["mi_director"]) row=row"\t"DIRECTOR"\t"minfo["mi_director"];
    if (minfo["mi_actors"]) row=row"\t"ACTORS"\t"minfo["mi_actors"];
    if (minfo["mi_writers"]) row=row"\t"WRITERS"\t"minfo["mi_writers"];

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
    return row"\t";
}
function short_year(y) {
  return sprintf("%x",y-1900);
}
function short_genre(g,\
i,gnames,gcount) {
    gcount = split(g_settings["catalog_genre"],gnames,",");
    for(i = 1 ; i <= gcount ; i += 2) {
        if (match(g,"\\<"gnames[i]"o?\\>") ) {
           g = substr(g,1,RSTART-1) gnames[i+1] substr(g,RSTART+RLENGTH); 
       }
    }
    gsub(/[^-A-Za-z]+/,"|",g);
    return g;
}

# convert yyyymmddHHMMSS to bitwise yyyyyy yyyymmmm dddddhhh hhmmmmmm
function shorttime(t,\
y,m,d,hr,mn,r) {
    r = t;
    if (length(t) > 8 ) {

        y = n(substr(t,1,4))-1900;
        m = n(substr(t,5,2));
        d = n(substr(t,7,2));
        hr = n(substr(t,9,2));
        mn = n(substr(t,11,2));

        r = lshift(lshift(lshift(lshift(and(y,1023),4)+m,5)+d,5)+hr,6)+mn;
        r= sprintf("%x",r);
    }
    #INF("shorttime "t" = "r);
    return r;
}
function replace_database_with_new(newdb,currentdb,olddb) {

    INF("Replace Database ["newdb"] to ["currentdb"] to ["olddb"]");

    exec("cp -f "qa(currentdb)" "qa(olddb));

    touch_and_move(newdb,currentdb);

    set_permissions(qa(currentdb)" "qa(olddb));
}
function set_db_fields() {
    #DB fields should start with underscore to speed grepping etc.
    # Fields with @ are not written to the db.
    ID=db_field("_id","ID","",0);

    WATCHED=db_field("_w","Watched","watched") ;
    LOCKED=db_field("_l","Locked","locked") ;
    PARTS=db_field("_pt","PARTS","");
    FILE=db_field("_F","FILE","filenameandpath");
    NAME=db_field("_@N","NAME","");
    DIR=db_field("_@D","DIR","");
    EXT=db_field("_ext","EXT",""); # not a real field


    ORIG_TITLE=db_field("_ot","ORIG_TITLE","originaltitle");
    TITLE=db_field("_T","Title","title",1) ;
    DIRECTOR=db_field("_d","Director","director",1) ;
    ACTORS=db_field("_A","Actors","actors",1) ;
    WRITERS=db_field("_W","Writers","writers",1) ;
    CREATOR=db_field("_c","Creator","creator") ;
    AKA=db_field("_K","AKA","",1);

    CATEGORY=db_field("_C","Category","");
    ADDITIONAL_INF=db_field("_ai","Additional Info","");
    YEAR=db_field("_Y","Year","year",1) ;

    SEASON=db_field("_s","Season","season") ;
    EPISODE=db_field("_e","Episode","episode");

    GENRE=db_field("_G","Genre","genre",1) ;
    RUNTIME=db_field("_rt","Runtime","runtime",1) ;
    RATING=db_field("_r","Rating","rating",1);
    CERT=db_field("_R","CERT","mpaa"); #Not standard?

    PLOT=db_field("_P","Plot","plot",1);
    #EPPLOT=db_field("_ep","Plot","plot");

    URL=db_field("_U","URL","url");
    POSTER=db_field("_J","Poster","thumb");
    FANART=db_field("_fa","Fanart","fanart");

    DOWNLOADTIME=db_field("_DT","Downloaded","");
    INDEXTIME=db_field("_IT","Indexed","");
    FILETIME=db_field("_FT","Modified","");

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
    CONN_FOLLOWS=db_field("_a","FOLLOWS",""); # Comes After
    CONN_FOLLOWED=db_field("_b","FOLLOWED",""); # Comes Before
    CONN_REMAKES=db_field("_k","REMAKES",""); # Movies remaKes
}


#Setup db_field identifier, pretty name ,
# IN key = database key and html parameter
# IN name = logical name
# IN tag = xml tag in xmbc nfo files.
# IN imdbsrc just indicates that this value can appear on imdb page.
# it is only used to warn if imdb has changed thier page format - again.
function db_field(key,name,tag,imdbsrc) {
    g_db_field_name[key]=name;
    gDbTag2FieldId[tag]=key;
    gDbFieldId2Tag[key]=tag;
    if (imdbsrc) {
        g_imdb_sections[key]=name;
    }
    return key;
}
