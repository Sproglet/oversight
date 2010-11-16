#! $Id$
# web_search_first_imdb_link has now been disabled in tv_search(Sep 2010), as well as being
# previously disabled in movie search. This is to avoid excessive googling for tv shows, 
# as if a tv show cannot be found , it will switch to looking for movies which also uses 
# other 'google' search methods. If the resulting program is a tv show according to IMDB,
# then it will switch back to tv search mode. see catalog.tv.awk tvsearch().
# ----------------------------------------------------------------------------------------
#
# ensure svn keyword expansion is enabled
#
# Script to metch meta-data for Movie and TV media.
# The result is stored in a flat file index.db
# The facility to create XMBC conformant nfo files will be re-enabled soon.
#
#
# This is a sprawling mess. due to evolving over time, and lack of structures meaning lots
# of global arrays causing memory problems. Esp with busybox awk.
#
# ==================================================================================
#
# This script uses awk in the 'bad' way. It does not use awks pattern matching on input.
# but works as a simple procedural program. Everything is triggered from the END clause.
#
# I would rather have used perl, but this was not available at the time.
# Using awk in the 'good' way, does not really fit with what the scanner is trying to do.
# For example many input files do not exist at the time the script is started.
#
# ==================================================================================
#
# AWK funnies - mostly from busybox awk
# Sometimes awk seems to do a string compare when both values look like numbers.
#Ive tried to isolate but cant, its something to do with parameter passing I think. 
# anyway most number comparisons are eg.  "x - y > 0" instead of "x > y"
#
# Watch out when logging results of a function. This may turn a numeric result into a string. bug fixed in newer bbawk.
# 
# ==================================================================================
# Character Encodings - coping with accented characters.
#
# In C and awk character encoding must be handled carefully. esp as oversight moves
# towards i18n support.
#
# Where possible all html/xml input is utf-8. 
# Two exceptions are imdb and epguides which both use the 1252 codepage thing.
# plan to port iconv and drop utf8 awk function.
# but uft8 occurs after html_decode so need a html decoder binary.
#
# On NMT platform the ls command also returns UTF-8 filenames.
# (via cygwin it is 8bit ascii)
#
# The api sites expect urls to be utf8 wrapped in url encoding. They do not work with any codepage format.
#
# capitalise()
# There are issues identifying which utf8 chars are letters and which are punctuation.
# for now all are treated as letters hence Wall-e not Wall-E
#
# adjustTitle()
# adjustTitle gives priority to names with high bit characters. Its assumed these 
# are close to the real name the user expects to see.
#

#Pad episode but dont assume its a number .eg 03a for Big Brother
#BEGINAWK
#!catalog
function pad_episode(e) {
    if (match(e,"^[0-9][0-9]")) {
        return e;
    } else {
        return "0"e;
    }
}

function timestamp(label,x) {

    if (index(x,g_api_tvdb) ) gsub(g_api_tvdb,".",x);
    if (index(x,g_api_tmdb) ) gsub(g_api_tmdb,".",x);
    if (index(x,g_api_rage) ) gsub(g_api_rage,".",x);

    if (index(x,"d=") ) {
        sub("password.?=([^,]+)","password=***",x);
        sub("pwd=([^,]+)","pwd=xxx",x);
        sub("passwd=([^,]+)","passwd=***",x);
    }

    if (systime() != g_last_ts) {
        g_last_ts=systime();
        g_last_ts_str=strftime("%H:%M:%S : ",g_last_ts);
    }
    print label" "LOG_TAG" "g_last_ts_str g_indent x;
}

function TODO(x) {
    DEBUG("TODO:"x);
}


function plugin_error(p) {
    ERR("Unknown plugin "p);
}

# IN domain = original domain yahoo.com etc
# IN context = /search
# IN param = ?p= or ?q=
function get_local_search_engine(domain,context,param,\
i,links,best_url) {

    #param must not use & separater as this gets mangled when using gsub() 
    # eg url=http:/.../ie=utf8&q=SEARCH then gsub(/SEARCH/,"real query",url)
    # replace & with ;



    best_url = domain context param;
    scan_page_for_match_counts(best_url "test",context,"http://[-_.a-z0-9/]+"context "\\>",0,0,"",links);
    bestScores(links,links,0);
    for(i in links) {
        best_url = i param; #http.../search ?q=
        break;
    }
    gsub(/\&/,";",best_url);
    INF("remapping "domain context param "=>" best_url);
    return best_url;
}

# Note we dont call the real init code until after the command line variables are read.
BEGIN {
    verify_setup();
    g_multpart_tags = "cd|disk|disc|part";
    g_max_plot_len=3000;
    g_min_plot_len=70;
    g_max_db_len=4000;
    g_path_depth=3;
    g_country_prefix="country_";
    g_indent="";
    g_sigma="Î£"; # Tv rage uses Sigma in title like Greek - in place of the e.
    g_start_time = systime();
    g_thetvdb_web="http://www.thetvdb.com";
    g_tvrage_web="http://www.tvrage.com";
    g_tvrage_api="http://services.tvrage.com";

    # Additional argument passed to jpg_fetch_and_scale - comment out to do all images last
    g_fetch_images_concurrently="START";

    g_tv_check_urls["tvrage"]=g_tvrage_web;
    g_tv_check_urls["thetvdb"]=g_thetvdb_web;

    g_batch_size=30;
    g_cvs_sep=" *, *";
    g_opt_dry_run=0;
    yes="yes";
    no="no";

    g_8bit="€-ÿ"; // range 0x80 - 0xff

    g_alnum8 = "a-zA-Z0-9" g_8bit;

    # Remove any punctuation except quotes () [] {} - also keep high bit
    g_punc[0]="[^][}{&()'!?" g_alnum8 "-]+";
    # Remove any punctuation except quotes () - also keep high bit
    g_punc[1]="[^&'!?()"g_alnum8"-]+";
    # Remove any punctuation except quotes () - also keep high bit
    g_punc[2]="[^&'!?"g_alnum8"-]+";

    g_nonquote_regex = "[^\"']";

    #g_imdb_regex="\\<tt[0-9]+\\>";
    g_imdb_regex="tt[0-9][0-9][0-9][0-9][0-9]+"; #bit better performance

    g_year_re="(20[01][0-9]|19[0-9][0-9])";
    g_imdb_title_re="[A-Z0-9"g_8bit"]["g_alnum8"& '.]* \\(?"g_year_re"\\)?";

    g_roman_regex="i|ii|iii|iv|v|vi|vii|viii|ix|x|xi|xii|xiii|xiv|xv";

    split(g_roman_regex,g_roman1,"[|]");
    hash_invert(g_roman1,g_roman);

    ELAPSED_TIME=systime();
    GET_POSTERS=1;
    GET_FANART=1;
    GET_PORTRAITS=1;
    UPDATE_POSTERS=0;
    UPDATE_FANART=0;
    UPDATE_PORTRAITS=0;

    g_api_tvdb="A110A5718F912D21070A77194F";
    g_api_tmdb="2d51eee0579c36499df410b337edc79658dac1ae14";
    g_api_rage="fP8i46657c9qe22678pt4M08315u554A68263Hh7";

    INF("$Id$");
    get_folders_from_args(FOLDER_ARR);
}

function report_status(msg) {
    if (msg == "") {
        rm(g_status_file,1);
    } else {
        print msg > g_status_file;
        close(g_status_file);
        INF("status:"msg);
        set_permissions(g_status_file);
    }
}


END{

    #path for actor db etc.
    DBDIR = APPDIR"/db";

    g_max_id_file = INDEX_DB".maxid";
    INDEX_DB_TMP = INDEX_DB "." JOBID ".tmp";
    INDEX_DB_NEW = INDEX_DB "." JOBID ".new";
    INDEX_DB_OLD = INDEX_DB "." DAY;

    g_user_agent="Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20040613 Firefox/0.8.0+";

    # Note keep timout above 30 seconds to allow for the DNS bug where first lookup takes 30 seconds
    # on some combinations of NMT/network and DNS server.
    g_wget_opts="-T 31 -t 2 -w 2 -q --no-check-certificate --ignore-length ";
    g_art_timeout=" -T 60";


    g_mount_root="/opt/sybhttpd/localhost.drives/NETWORK_SHARE/";
    g_winsfile = APPDIR"/conf/wins.txt";
    g_item_count = 0;


    g_plot_file=PLOT_DB;
    g_plot_file_queue=PLOT_DB".queue";
    g_plot_app=qa(APPDIR"/bin/plot.sh");

    for(i in g_settings) {
        g_settings_orig[i] = g_settings[i];
    }

    g_db_lock_file=APPDIR"/catalog.lck";
    g_scan_lock_file=APPDIR"/catalog.scan.lck";
    g_status_file=APPDIR"/catalog.status";
    g_abc="abcdefghijklmnopqrstuvwxyz"; # slight rearrange - probably makes no diff
    g_ABC=toupper(g_abc);
    g_tagstartchar=g_ABC g_abc":_";

    report_status("scanning");

    load_catalog_settings();

    g_max_actors=g_settings["catalog_max_actors"];
    g_max_directors = 3;
    g_max_writers = 3;

    split(tolower(g_settings["catalog_tv_plugins"]),g_tv_plugin_list,g_cvs_sep);

    DEBUG("RENAME_TV="RENAME_TV);
    DEBUG("RENAME_FILM="RENAME_FILM);

    set_db_fields();

    #Values for action field
    ACTION_NONE="0";
    ACTION_REMOVE="r";
    ACTION_DELETE_MEDIA="d";
    ACTION_DELETE_ALL="D";

    # underscores should also be treated as word boundaries.

    tmp = tolower(g_settings["catalog_format_tags"]);

    gsub(/\\>/,"(\\>|_)",tmp); # allow underscore to match end of word.

    g_settings["catalog_format_tags"]="(\\<|_)("tmp")";

    DEBUG("catalog_format_tags="g_settings["catalog_format_tags"]);

    gsub(/ /,"%20",g_settings["catalog_cert_country_list"]);

    gsub(/\<UK\>/,"UK,gb",g_settings["catalog_cert_country_list"]);
    gsub(/\<USA\>/,"USA,us",g_settings["catalog_cert_country_list"]);
    gsub(/\<Ireland\>/,"Ireland,ie",g_settings["catalog_cert_country_list"]);

    split(g_settings["catalog_cert_country_list"],gCertificateCountries,",");

    gExtList1="avi|divx|mkv|mp4|ts|m2ts|xmv|mpg|mpeg|mov|m4v|wmv";
    gExtList2="img|iso";

    gExtList1=tolower(gExtList1) "|" toupper(gExtList1);
    gExtList2=tolower(gExtList2) "|" toupper(gExtList2);

    gExtRegexIso="\\.("gExtList2")$";
    #INF(gExtRegexIso);

    gExtRegEx1="\\.("gExtList1")$";
    #INF(gExtRegEx1);

    gExtRegExAll="\\.("gExtList1"|"gExtList2")$";
    #INF(gExtRegExAll);

    split(g_settings["catalog_title_country_list"],gTitleCountries,g_cvs_sep);

    g_months_short="Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec"
    monthHash(g_months_short,"|",gMonthConvert);

    g_months_long="January|February|March|April|May|June|July|August|September|October|November|December";
    monthHash(g_months_long,"|",gMonthConvert);
    split(g_months_long,g_month_en,"|");


    if ( g_settings["catalog_tv_file_fmt"] == "" ) RENAME_TV=0;
    if  ( g_settings["catalog_film_folder_fmt"] == "") RENAME_FILM=0;

    CAPTURE_PREFIX=g_tmp_dir"/catalog."

    #INF("noaccent:"no_accent("ŠŒŽšœžŸ¥µÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝßàáâãäåæçèéêëìíîïðñòóôõöøùúûüýÿ"));

    # Bing and yahoo are in the process of merging. I expect this means they will soon
    # start returning the same results. This will invalidate the searh voting.
    # A way around this is to skew one of the search results with other movie related keywords.
    # eg. subtitles or movie or download. or site:opensubtitles.org
    # ask is powered by google.
    # Another option is to search sites directly but thier search algorithms are usually too strict
    # with scoring each keyword.
    g_search_yahoo = get_local_search_engine("http://search.yahoo.com","/search","?ei=UTF-8;eo=UTF-8;p=");
    g_search_ask = get_local_search_engine("http://ask.com","/web","?q=");
    g_search_bing = "http://www.bing.com/search?q=";
    g_search_bing2 = "http://www.bing.com/search?q=subtitles+";
    # Google must have &q= not ;q=
    g_search_google = "http://www.google.com/search?ie=utf-8&oe=utf-8&q=";

    #g_search_engine[0]=g_search_bing2;
    g_search_engine[0]=g_search_yahoo;
    g_search_engine[1]=g_search_bing;
    #g_search_engine[2]=g_search_ask; results too similar to google giving false +ves.
    g_search_engine_count=2;
    g_search_engine_current=0;

    THIS_YEAR=substr(NOW,1,4);

    unit(1);

    scan_options="-Rl";
    if (g_settings["catalog_follow_symlinks"]==1) {
        scan_options= scan_options"L";
    }

    if (RESCAN == 1 || NEWSCAN == 1) {
        if (!(1 in FOLDER_ARR)) {
            # Get default folder list

            if (NEWSCAN == 1) {
                # Get watch folders only
                INF("Scanning watch paths");
                folder_list=g_settings["catalog_watch_paths"];
            } else {
                # Get all folders only
                INF("Scanning default and watch paths");
                folder_list=g_settings["catalog_scan_paths"];
                if (g_settings["catalog_watch_paths"] != "") {
                    folder_list = folder_list "," g_settings["catalog_watch_paths"];
                }
            }
            trim(folder_list);
            sub(/^,+/,"",folder_list);
            sub(/,+$/,"",folder_list);

            split(folder_list,FOLDER_ARR,g_cvs_sep);
        }
        if (PARALLEL_SCAN != 1 ) {
            if (lock(g_scan_lock_file) == 0 ) {
                INF("Scan already in progress");
                exit;
            }
        }
    }

    g_timestamp_file=APPDIR"/.lastscan";


    replace_share_names(FOLDER_ARR);

    make_paths_absolute(FOLDER_ARR);

    for(f in FOLDER_ARR) {
        INF("Folder "f"="FOLDER_ARR[f]);
    }

    gLS_FILE_POS=0; # Position of filename in LS format
    gLS_TIME_POS=0; # Position of timestamp is LS format
    findLSFormat();

    plugin_check();

    if (hash_size(FOLDER_ARR)) {

        gMovieFileCount = 0;
        gMaxDatabaseId = 0;
        
        load_settings("",UNPAK_CFG,1);

        g_api_tvdb = apply(g_api_tvdb);
        g_api_tmdb = apply(g_api_tmdb);
        g_api_rage = apply(g_api_rage);

        g_grand_total = scan_folder_for_new_media(FOLDER_ARR,scan_options);

        delete g_updated_plots;

        clean_capture_files();

        et=systime()-ELAPSED_TIME;

        DEBUG(sprintf("Finished: Elapsed time %dm %ds",int(et/60),(et%60)));

        #Check script
        for(i in g_settings) {
            if (!(i in g_settings_orig)) {
                WARNING("Undefined setting "i" referenced");
            }
        }

    }

    rm(g_status_file);


    if (RESCAN == 1 || NEWSCAN == 1) {
        print "last scan at " strftime(systime()) > g_timestamp_file;
        close(g_timestamp_file);
        unlock(g_scan_lock_file);
    }
    if (g_grand_total) {
        if (lock(g_db_lock_file,1)) {
            #if we cant get the lock assume other task will prune anyway.
            remove_absent_files_from_new_db(INDEX_DB);
            system(g_plot_app" compact "qa(g_plot_file)" "qa(INDEX_DB));
            unlock(g_db_lock_file);
        }
    }
    if (g_fetch_images_concurrently == "") {
        exec(APPDIR"/bin/jpg_fetch_and_scale START &");
    }
}

function replace_share_names(folders,\
f,share_name) {
    if (isnmt()) {
        #If a pth does not begin with . or / then check if the first part is the 
        #name of an NMT network_share. If so - replace with the share path.
        for(f in folders) {
            if (folders[f] ~ /^[^\/.]/  ) {
                # Assume it is a share
                share_name=folders[f];
                sub(/\/.*/,"",share_name);

                if (!(share_name in g_share_name_to_folder)) {
                    g_share_name_to_folder[share_name] = nmt_mount_share(share_name,g_tmp_settings);
                    DEBUG("share name "share_name" = "g_share_name_to_folder[share_name]);
                }
                if (g_share_name_to_folder[share_name]) {

                    g_share_map[folders[f]] = share_name;
                    folders[f] = nmt_get_share_path(folders[f]);

                } else if (START_DIR != "/share/Apps/oversight" && is_file_or_folder(START_DIR"/"folders[f])) {
                    folders[f] = START_DIR"/"folders[f];
                } else {
                    WARNING(folders[f]" not a share or file");
                    delete folders[f];
                }
            }
        }
    }
}

function make_paths_absolute(folders,\
f) {
    ## Make sure all paths are absolute
    for(f in folders) {

        if (index(folders[f],".") == 1) {
            folders[f] = START_DIR"/"folders[f];
        }
        folders[f] = clean_path(folders[f]);
    }
}

function plugin_check(\
p,plugin) {
    for (p in g_tv_plugin_list) {
        plugin = g_tv_plugin_list[p];
        if (getUrl(g_tv_check_urls[plugin],"test",0) == "" ) {
            WARNING("Removing plugin "plugin);
            delete g_tv_plugin_list[p];
        }
    }
}


function merge_queue(qfile,person_extid2name) {

    if (g_opt_dry_run) {

        INF("Database update skipped - dry run");

    } else {

        if(lock(g_db_lock_file)) {
            sort_and_merge_index(INDEX_DB,qfile,INDEX_DB_OLD,person_extid2name);
            unlock(g_db_lock_file);
        }
    }
    rm(qfile);
    delete person_extid2name;
}












function set_maxid(file,max_id,\
filemax) {
    filemax = file".maxid";
    print max_id > filemax;
    close(filemax);
    INF("set_maxid["file"]="max_id);
}


function get_maxid(file,\
max_id,line,fields,filemax,tab) {
    max_id = 0;
    filemax = file".maxid";

    if (!is_file(filemax)) {
        if (is_file(file)) {
            if (file == INDEX_DB ) {
                # get mex id from main database index.db - using field _ID
                while ((line = get_dbline(file) ) != "") {
                    parseDbRow(line,fields,0);
                    if (fields[ID]+0 > max_id+0) {
                        max_id = fields[ID];
                    }
                }
            } else {
                # id is the first field
                while ((getline line < file ) > 0) {
                    if ((tab = index(line,"\t")) > 0) {
                        line = substr(line,1,tab-1);
                        if (index(line,"nm") == 1) {
                            #remove imdb nm prefix
                            line = substr(line,3);
                        }
                        if (line + 0 > max_id+0) {
                            max_id = line;
                        }
                    }
                    max_id = fields[1];
                }
            }
            close(file);
        }
        set_maxid(file,max_id);

    } else {
        getline max_id < filemax;
        close(filemax);
        max_id += 0;
        INF("get_maxid["file"]="max_id);
    }
    return max_id;
}


function next_folder(path,base,\
path_parts,base_parts,bpcount,pcount) {
    if (index(path,base) == 1) {

        bpcount = split(base,base_parts,"/");
        if (base_parts[bpcount] == "" ) bpcount--; # ignore trailing /

        pcount = split(path,path_parts,"/");

        # if the base includes part of a folder name then return that folder name
        # otherwie return the next folder name.
        # so /opt/sy.../USB_DRIVE_  returns USB_DRIVE_A-1
        # but /opt/sy../NETWORK_DRIVE/ returns the mount folder abcd
        if (path_parts[bpcount] == base_parts[bpcount] ) {
            return base "/" path_parts[bpcount+1];
        } else {
            sub(/\/[^\/]+$/,"",base);
            return base "/" path_parts[bpcount];
        }
    }
    return "";
}


function mount_point(d) {
    if (index(d,"/share/") == 1) return "/share";
    if ( index(d,g_mount_root) == 1 || index(d,"/USB_DRIVE_") == 1 || index(d,"/opt/sybhttpd/localhost.drives/USB_DRIVE_") == 1 ) {
        return next_folder(d,g_mount_root);
    }
}

function short_path(path) {
    if (index(path,g_mount_root) == 1) {
        path = substr(path,length(g_mount_root)+1);
    }
    return path;
}

function in_list(path,list,\
result) {
    path = short_path(path);
    if ( index(path,list["@PREFIX"]) ) {
       result = ( path in list);
   }
   return result;
}

function add_file(path,list) {
    path = short_path(path);
    DEBUG("already seen "path);
    list[path] = 1;
}

function remove_brackets(s) {

    # A while loop is used for nested brackets. It happens.
    while (gsub(/\[[^][]*\]/,"",s) || gsub(/\{[^}{]*\}/,"",s)) continue;

    # remove round brackets only if content is non-numeric nor blank
    while (gsub(/\([^()]*[^0-9 ][^()]*\)/,"",s)) continue;

    return s;
}

function getPath(name,localPath) {
    if (substr(name,1,1) == "/" ) {
        #absolute
        return name;
    } else if (substr(name,1,4) == "ovs:" ) {
        #Paths with ovs:  are relative to oversight folder and are shared between items.(global)
        return APPDIR"/db/global/"substr(name,5);
    } else {
        #Other paths are relative to video folder.
        return localPath"/"name;
    }
}

function re_escape(s) {
    gsub("[][*.{}()]","\\\\&",s);
    return s;
}

function calcTimestamp(lsMonth,lsDate,lsTimeOrYear,_default,\
    val,y,m,d,h,min,checkFuture) {
    # Calculate file time...
    if (lsMonth == "" ) {
        return _default;
    } else {
        m=gMonthConvert[lsMonth];
        d=lsDate;
        if (index(lsTimeOrYear,":")) {
            #MON dd hh:mm
            y=THIS_YEAR;
            h=substr(lsTimeOrYear,1,2);
            min=substr(lsTimeOrYear,4,2);
            checkFuture=1; # check if date is in future - if so subtract 1 year.
        } else {
            #MON dd yyyy
            y=lsTimeOrYear;
            h=7;
            min=0;
            checkFuture=0;
        }
        val = sprintf("%04d%02d%02d%02d%02d00",y,m,d,h,min); 
        if (checkFuture && (val - NOW) > 0 ) {
            y--;
            val = sprintf("%04d%02d%02d%02d%02d00",y,m,d,h,min); 
        }
        return val; 
    }
}

############### GET IMDB URL FROM NFO ########################################

function cleanSuffix(minfo,\
name) {
    name=minfo["mi_media"];
    if(name !~ "/$") {
        # remove extension
        sub(/\.[^.\/]+$/,"",name);
        # name=remove_format_tags(name);

        # no point in removing the CD parts as this makes binsearch more inaccurate

        #    if (minfo["mi_parts"] != "" ) {
        #        #remove  part qualifier xxxx1 or xxxxxa
        #        sub(/(|cd|part)[1a]$/,"",name);
        #    }
    }
    name=trimAll(name);
    return name;
}





# Given a bunch of titles keep the ones where the filename has been posted with that title
#IN filterText - text to look for along with each title. This is usually filename w/o ext ie cleanSuffix(minfo)
#IN titles hash(showId=>title)
#OUT filteredTitles hashed by show ID ONLY if result = 1 otherwise UNCHANGED
#
# Two engines are used bintube and binsearch in case
# a) one is unavailable.
# b) binsearch has slightly better search of files within collections. eg if a series posted under one title.
function filterUsenetTitles(titles,filterText,filteredTitles,\
result) {
result = filterUsenetTitles1(titles,"http://binsearch.info/?max=25&adv_age=&q=\""filterText"\" QUERY",filteredTitles);
#   if (result == 0 ) {
#       result = filterUsenetTitles1(titles,"http://bintube.com/?q=\""filterText"\" QUERY",filteredTitles);
#   }
   return 0+ result;
}

# Given a bunch of titles keep the ones where the filename has been posted with that title
#IN filterText - text to look for along with each title. This is usually filename w/o ext ie cleanSuffix(minfo)
#IN titles - hased by show ID
#OUT filteredTitles hashed by show ID ONLY if result = 1 otherwise UNCHANGED
function filterUsenetTitles1(titles,usenet_query_url,filteredTitles,\
t,count,tmpTitles,origTitles,dummy,found,query,baseline,link_count) {

    found = 0;
    dump(2,"pre-usenet",titles);

    # save for later as titles and filteredTitles may be the same hash
    hash_copy(origTitles,titles);

    # First get a dummy item to compare
    dummy=rand()systime()rand();
    query = usenet_query_url;
    sub(/QUERY/,dummy,query);
    baseline = scan_page_for_match_counts(query,"</","</[Aa]>",0,1,"",tmpTitles);

    DEBUG("number of links for no match "baseline);

    for(t in titles) {
        #Just count the number of table links
        query = usenet_query_url;
        sub(/QUERY/,norm_title(clean_title(titles[t])),query);
        link_count = scan_page_for_match_counts(query,"</","</[Aa]>",0,1,"",tmpTitles);
        DEBUG("number of links "link_count);
        if (link_count-baseline > 0) {
            count[t] = link_count;
            found=1;
        }
        if (link_count == 0 ) {
            scan_page_for_match_counts(query,"</","</[Aa]>",0,1,"",tmpTitles,1);
        }
    }

    if (found) {
        # Now keep the ones with most matches
        bestScores(count,count,0);

        delete filteredTitles;
        for(t in count) {
            filteredTitles[t] = origTitles[t];
        }
        INF("best titles on usenet using "usenet_query_url);
        dump(0,"post-usenet",filteredTitles);
    } else {
        INF("No results found using "usenet_query_url);
    }
    return 0+ found;
}

function verify_setup(\
tmp,tmp2) {
    tmp = "mi_additional_info mi_airdate mi_category mi_certcountry mi_certrating mi_conn_followed_by mi_conn_follows mi_conn_remakes mi_director mi_director_name mi_episode mi_epplot mi_eptitle mi_fanart mi_file mi_file_time mi_folder mi_genre mi_imdb_title mi_media mi_motech_title mi_multipart_tag_pos mi_nfo_default mi_orig_title mi_parts mi_plot mi_poster mi_premier mi_rating mi_runtime mi_season mi_title mi_title_rank mi_title_source mi_writers mi_year mi_actor_ids mi_actor_names mi_writer_ids mi_writer_names mi_director_ids mi_directo_names mi_actor_total mi_director_total mi_writer_total mi_do_scrape mi_url";
    split(tmp,tmp2," ");
    hash_invert(tmp2,g_verify);
}

# Check we havent set any bad fields in movie information array
function verify(minfo,\
ret,f,numok,numbad) {

    id1("verify");
    ret=1;
    for (f in minfo) {
        if (!(f in g_verify)) {
            ERR("bad field ["f"] = ["minfo[f]"]");
            numbad++;
        }  else {
            if (match(f,"^mi_[a-z]+_(names|ids)$")  && index(minfo[f],"@") == 0) {
                #format should be domain@id1@id2@.. or domain@name1@name2@..
                #eg imdb@nm0000123@nm0000456 or allocine@Sean Connery@Roger Moore@
                ERR("bad format field ["f"] = ["minfo[f]"]");
                numbad++;
            } else {
                INF("ok field ["f"] = ["minfo[f]"]");
                numok++;
            }
        }
    }
    if (numbad > 0 || numok == 0) {
        ERR("Failed verification bad="numbad" ok="numok);
        ret = 0;
    }
    id0(ret);
    return ret;
}

# This is used in tv comparison functions for qualified matches so it must not remove any country
# or year designation
# deep - if set then [] and {} are removed from text too
function clean_title(t,deep,\
punc) {

    #ALL# gsub(/[&]/," and ",t);
    gsub(/[&]amp;/,"\\&",t);

    sub(/[-_ .]+$/,"",t);

    #Collapse abbreviations. Only if dot is sandwiched between single letters.
    #c.s.i.miami => csi.miami
    #this has to be done in two stages otherwise the collapsing prevents the next match.
    while (match(t,"\\<[A-Za-z]\\>[.]\\<[A-Za-z]\\>")) {
        t = substr(t,1,RSTART) "@@" substr(t,RSTART+2);
    }

    gsub(/@@/,"",t);

    punc = g_punc[deep+0];
    if (index(t," ") ) {
        # If there is a space then also preserve . and _ . These are often used as spaces
        # but if there is aready a space , assume they are significant.

        # first remove any trailing dot
        gsub(punc"$","",t);

        #Now modify regex to keep any internal dots.
        if (sub(/-\]/,"_.-]",punc) != 1) {
            ERR("Fix punctuation string");
        }
    }
    gsub(punc," ",t);

    gsub(/ +/," ",t);

    t=trim(capitalise(tolower(t)));

    return t;
}

# remove html markup from a line.
function remove_tags(line) {

    if (index(line,"<")) {
        gsub(/<[^>]+>/," ",line);
    }

    if (index(line,"  ")) {
        gsub(/ +/," ",line);
    }

    if (index(line,"amp")) {
        gsub(/\&amp;/," \\& ",line);
    }

    if (index(line,"&")) {
        gsub(/[&][a-z]+;?/,"",line);
    }

    #line=de_emphasise(line);

    return line;
}

# This finds the item with the most votes and returns it if it is > threshold.
# Special case: If threshold = -1 then the votes must exceed the square of the 
# difference between next largest amount.
function getMax(arr,requiredThreshold,requireDifferenceSquared,\
maxName,best,nextBest,nextBestName,diff,i,threshold) {
    nextBest=0;
    maxName="";
    best=0;
    dump(0,"getMax",arr);
    for(i in arr) {
        if (arr[i]-best >= 0 ) {
            nextBest = best;
            nextBestName = maxName;
            best = threshold = arr[i];
            maxName = i;

        } else if (arr[i]-nextBest >= 0 ) {

            nextBest = arr[i];
            nextBestName = i;
        }
    }
    DEBUG("Best "best"*"arr[i]". Required="requiredThreshold);

    if (0+best < 0+requiredThreshold ) {
        DEBUG("Rejected as "best" does not meet requiredThreshold of "requiredThreshold);
        maxName = "";

    } else if (requireDifferenceSquared ) {

        diff=best-nextBest;
        DEBUG("Next best count = "nextBest" diff^2 = "(diff*diff));
        if (diff * diff - best  < 0 ) {

            DEBUG("But rejected as "best" too close to next best "nextBest" to be certain");
            maxName = "";

        }
    }
    DEBUG("getMax: best index = ["maxName"]");
    return maxName;
}


# Search a google page for most frequently occuring imdb link
function searchForIMDB(keywords,linkThreshold,\
i1,result,matchList,bestUrl) {
    id1("Search ["keywords"]");
    if (!(keywords in g_imdb_link_search)) {

        #We want imdb links but not from imdb themselves as this skews the results.
        #Also keeping the number of results down helps focus on early matches.
        #yahoo : inurl:imdb.com is only applied to the site. to apply to url just use imdb.
        keywords = keywords"+%2Bimdb+%2Btitle+-inurl%3Aimdb";

        # bing is not very good here.
        scan_page_for_match_counts(g_search_yahoo keywords,"tt",g_imdb_regex,0,0,"",matchList);
        # Find the url with the highest count for each index.
        #To help stop false matches we requre at least two occurences.
        bestUrl=getMax(matchList,linkThreshold,1);
        if (bestUrl != "") {
            i1 = extractImdbLink(bestUrl);
        }
        g_imdb_link_search[keywords] = i1;

    }
    result = g_imdb_link_search[keywords];

    id0(result);
    return result;
}


# Try to read the title embedded in the iso.
# This is stored after the first 32K of undefined data.
# Normally strings would work but this is not on all platforms!
# returns number of strings found and array of strings in outputText

function getIsoTitle(isoPath,\
sep,tmpFile,f,outputWords,isoPart,outputText) {
    FS="\\n";
    sep="~";
    outputWords=0;
    tmpFile=g_tmp_dir"/bytes."JOBID;
    isoPart=g_tmp_dir"/bytes."JOBID".2";
    delete outputText;

    if (exec("dd if="qa(isoPath)" of="isoPart" bs=1024 count=10 skip=32") != 0) {
        return 0;
    }

    DEBUG("Get strings "isoPath);

    DEBUG("tmp file "tmpFile);

    system(AWK" 'BEGIN { FS=\"_\" } { gsub(/[^ -~]+/,\"~\"); gsub(\"~+\",\"~\") ; split($0,w,\"~\"); for (i in w)  if (w[i]) print w[i] ; }' "isoPart" > "tmpFile);
    getline f < tmpFile;
    getline f < tmpFile;
    system("rm -f -- "tmpFile" "isoPart);
    INF("iso title for "isoPath" = ["f"]");
    gsub(/[Ww]in32/,"",f);
    return clean_title(f);
    close(tmpFile);
}

# Make two urls point to the same cache page.
function equate_urls(u1,u2) {

    INF("equate ["u1"] =\n\t ["u2"]");

    if (u1 in gUrlCache) {

        gUrlCache[u2]=gUrlCache[u1];

    } else if (u2 in gUrlCache) {

        gUrlCache[u1]=gUrlCache[u2];
    }
}

function xmlEscape(text) {
    gsub(/[&]/,"\\&amp;",text);
    gsub(/</,"\\&lt;",text);
    gsub(/>/,"\\&gt;",text);
    return text;
}

# Some times epguides and imdb disagree. We only give a title if both are the same.
#
function fixTitles(minfo,\
t) {

    t = minfo["mi_title"];
    # If no title set - just use the filename
    if (t == "") {
        t = minfo["mi_media"];
        sub(/\/$/,"",t);
        sub(/.*\//,"",t); #remove path
        t = remove_format_tags(t);
        gsub("[^" g_alnum8 "]"," ",t); #remove odd chars
        DEBUG("Setting title to file["t"]");
    }

    minfo["mi_title"]=clean_title(t);
}

function file_time(f) {
    if (f in g_file_date) {
        return g_file_date[f];
    } else {
        return "";
    }
}

#busybox awk - I think has some issues converting numbers with leading zeroes
#this will try to return an integer extracted from a string. Just guesswork
#would not be needed with well behaved awk
function n(x) \
{
    sub(/^[^-0-9]*0*/,"",x);
#    if (0+x == 0 ) {
#        INF("n("x") = "0);
#    }
    return 0+x;
}

#Move folder names from argument list
function get_folders_from_args(folder_arr,\
i,folderCount,moveDown) {
    folderCount=0;
    moveDown=0;
    for(i = 1 ; i - ARGC < 0 ; i++ ) {
        INF("Arg:["ARGV[i]"]");
        if (ARGV[i] == "IGNORE_NFO" ) {
            g_settings["catalog_nfo_read"] = "no";
            moveDown++;

        } else if (ARGV[i] == "WRITE_NFO" ) {

            g_settings["catalog_nfo_write"] = "if_none_exists";
            moveDown++;

        } else if (ARGV[i] == "NOWRITE_NFO" ) {

            g_settings["catalog_nfo_write"] = "never";
            moveDown++;

        } else if (ARGV[i] == "REBUILD" ) {
            REBUILD=1;
            moveDown++;
        } else if (ARGV[i] ~ "^DEBUG[0-9]$" ) {
            DBG=substr(ARGV[i],length(ARGV[i])) + 0;
            print("DBG = "DBG);
            DBG=1;
            print("DBG = "DBG);
            moveDown++;
        } else if (ARGV[i] == "STDOUT" ) {
            STDOUT=1;
            moveDown++;
        } else if (ARGV[i] == "DRYRUN" ) {
            RENAME_TV=1;
            RENAME_FILM=1;
            g_opt_dry_run=1;
            moveDown++;
        } else if (ARGV[i] == "RENAME" ) {
            RENAME_TV=1;
            RENAME_FILM=1;
            moveDown++;
        } else if (ARGV[i] == "RENAME_TV" ) {
            RENAME_TV=1;
            moveDown++;
        } else if (ARGV[i] == "RENAME_FILM" ) {
            RENAME_FILM=1;
            moveDown++;

        } else if (ARGV[i] == "NO_POSTERS" )  {
            GET_POSTERS = UPDATE_POSTERS = 0;
            moveDown++;
        } else if (ARGV[i] == "UPDATE_POSTERS" )  {
            GET_POSTERS = UPDATE_POSTERS = 1;
            moveDown++;

        } else if (ARGV[i] == "NO_FANART" )  {
            GET_FANART = UPDATE_FANART = 0;
            moveDown++;
        } else if (ARGV[i] == "UPDATE_FANART" )  {
            GET_FANART = UPDATE_FANART = 1;
            moveDown++;

        } else if (ARGV[i] == "GET_FANART"  || ARGV[i] == "GET_POSTERS"  || ARGV[i] == "GET_PORTRAITS" )  {
            #deperecate
            moveDown++;

        } else if (ARGV[i] == "NO_PORTRAITS" )  {
            GET_PORTRAITS = UPDATE_PORTRAITS = 0;
            moveDown++;
        } else if (ARGV[i] == "UPDATE_PORTRAITS" )  {
            GET_PORTRAITS = UPDATE_PORTRAITS = 1;
            moveDown++;

        } else if (ARGV[i] == "NEWSCAN" )  {
            NEWSCAN=1;
            moveDown++;
        } else if (ARGV[i] == "RESCAN" )  {
            RESCAN=1;
            moveDown++;
        } else if (ARGV[i] == "PARALLEL_SCAN" )  {
            PARALLEL_SCAN=1;
            moveDown++;
        } else if (match(ARGV[i],"^[a-zA-Z_]+=")) {
            #variable assignment - keep for awk to process
        } else {
            # A folder or file
            INF("Scan Path:["ARGV[i]"]");
            folder_arr[++folderCount] = ARGV[i];
            moveDown++;
        }
    }
    INF("============ END ARGS ============"moveDown);
    ARGC -= moveDown;
    # Add dev null as dummy input
    ARGV[ARGC++] = "/dev/null";
    return folderCount;
    for(i = 1 ; i <= ARGC ; i++ ) {
        INF("Final arg["i"] = ["ARGV[i]"]");
    }
}

function unit1(label,value) {
    print "unit" label ( value ? "OK" : "Failed");
}

function unit(doit,\
minfo,i,ulang) {
    if (doit) {
        DIV0("BEGIN UNIT TEST");

        INF("1." subexp("Title?012345","Title.([0-9]+)\\>"));
        INF("2." subexp("Title?012345 ","Title.([0-9]+)\\>"));
        INF("3." subexp("Title?012345","Title.([0-9]+)"));
        INF("4." subexp("Title?012345 ","Title.([0-9]+)"));

        unit1("subexp",(subexp("Title?012345","Title.([0-9]+)\\>")  == "012345"));
        unit1("imdb1",(extractImdbId("http://us.imdb.com/Title?0318247  ") == "tt0318247"));
        unit1("imdb2",(extractImdbId("http://us.imdb.com/title/tt0318247  ") == "tt0318247"));

        unit1("abbr1",(abbreviated_substring("law and order los angeles","^","law and order la",1) == "law and order los a"));
        unit1("abbr2",(abbreviated_substring("law and order los angeles","^","law and order la",0) == "law and order los a"));
        unit1("abbr3",(abbreviated_substring("law and order los angeles","^","law and order lg",1) == ""));
        unit1("abbr4",(abbreviated_substring("law and order los angeles","^","law and order lg",0) == "law and order los ang"));
        unit1("abbr5",(abbreviated_substring("one two three","^","ott",1) == "one two t"));
        unit1("abbr6",(abbreviated_substring("one two three","^","ote",1) == "one two three"));
        unit1("abbr7",(abbreviated_substring("one two three","^","nte",1) == ""));
        unit1("abbr8",(abbreviated_substring("one two three","","nte",1) == "ne two three"));
        unit1("abbr9",(abbreviated_substring("one two three","","nte",0) == "ne two thre"));

        unit1("Trim",(trim(" a ") == "a"));
        unit1("Roman",(roman_replace("fredii") == "fred2"));
        unit1("preserve1",(preserve_src_href("<a href=\"1112\">bbb</a>") == " href=\"1112\" <a >bbb</a>"));
        unit1("preserve2",(preserve_src_href("<img src=\"3333\">") == " img=\"3333\" <img >" ));
        unit1("preserve3",(preserve_src_href("<a href='1112'>bbb</a>") == " href=\"1112\" <a >bbb</a>"));
        unit1("preserve4",(preserve_src_href("<img src='3333'>") == " src=\"3333\" <img >" ));

        unit1("preserve5",(preserve_src_href("<img src='http://images.allocine.fr/cx_120_90/b_1_x/o_play.png_5_se/medias/nmedia/00/02/53/34/18352141_rep.gif'") == " img=\"http://images.allocine.fr/cx_120_90/b_1_x/o_play.png_5_se/medias/nmedia/00/02/53/34/18352141_rep.gif\" <img " ));

#        split("en",ulang,",");
        #find_movie_page("Matrix Reloaded",2003,138,"Wachowski",minfo);
        #dump(0,"moviepage",minfo);
#        for(i in ulang) {
#            find_movie_by_lang(ulang[i],"Matrix Reloaded",2003,138,minfo);
#            dump(0,"lang "ulang[i]"=",minfo);
#            delete minfo;
#        }
        DIV0("END UNIT TEST");
    }
}

#ENDAWK
# vi:sw=4:et:ts=4

