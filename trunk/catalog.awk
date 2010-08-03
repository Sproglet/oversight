#! $Id$
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


# Load configuration file
function load_settings(prefix,file_name,\
i,n,v,option) {

    INF("load "file_name);
    FS="\n";
    while((getline option < file_name ) > 0 ) {

        #remove comment - hash without a preceeding blackslash
        if ((i=match(option,"[^\\\\]#")) > 0) {
            option = substr(option,1,i);
        }

        #remove spaces around =
        sub(/ *= */,"=",option);
        option=trim(option);
        # remove outer quotes
        sub("=[\"']","=",option);
        sub("[\"']$","",option);
        if (match(option,"^[A-Za-z0-9_]+=")) {
            n=prefix substr(option,1,RLENGTH-1);
            v=substr(option,RLENGTH+1);
            #gsub(/ *[,] */,",",v);

            if (n in g_settings) {

                if (n ~ "movie_search") DEBUG("index check "n"="index(n,"catalog_movie_search")); #TODO remove

                if (index(n,"catalog_movie_search") || n == "catalog_format_tags" || n == "catalog_format_tags" ) {

                    INF("Ignoring user setings for "n);

                } else {
                    if (g_settings[n] != v ) {
                        INF("Overriding "n": "g_settings[n]" -> "v);
                    }
                    g_settings[n] = v;
                }
            } else {
                g_settings_orig[n]=v;
                g_settings[n] = v;
                INF(n"=["g_settings[n]"]");
            }
        }
    }
    close(file_name);
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
    g_multpart_tags = "cd|disk|disc|part";
    g_max_plot_len=3000;
    g_max_db_len=4000;
    g_country_prefix="country_";
    g_indent="";
    g_sigma="Î£"; # Tv rage uses Sigma in title like Greek - in place of the e.
    g_start_time = systime();
    g_thetvdb_web="http://www.thetvdb.com";
    g_tvrage_web="http://www.tvrage.com";

    # Additional argument passed to jpg_fetch_and_scale - comment out to do all images last
    #g_fetch_images_concurrently="START";

    g_tv_check_urls["TVRAGE"]=g_tvrage_web;
    g_tv_check_urls["THETVDB"]=g_thetvdb_web;

    g_batch_size=30;
    g_tvdb_user_per_episode_api=1;
    g_cvs_sep=" *, *";
    g_opt_dry_run=0;
    yes="yes";
    no="no";

    g_8bit="€-ÿ"; // range 0x80 - 0xff

    g_alnum8 = "a-zA-Z0-9" g_8bit;

    # Remove any punctuation except quotes () [] {} - also keep high bit
    g_punc[0]="[^][}{&()'" g_alnum8 "-]+";
    # Remove any punctuation except quotes () - also keep high bit
    g_punc[1]="[^&()'"g_alnum8"-]+";
    # Remove any punctuation except quotes () - also keep high bit
    g_punc[2]="[^&'"g_alnum8"-]+";

    g_nonquote_regex = "[^\"']";

    #g_imdb_regex="\\<tt[0-9]+\\>";
    g_imdb_regex="\\<tt[0-9][0-9][0-9][0-9][0-9]+\\>"; #bit better performance

    g_year_re="(20[01][0-9]|19[0-9][0-9])";
    g_imdb_title_re="[A-Z0-9"g_8bit"]["g_alnum8"& '.]* \\(?"g_year_re"\\)?";

    ELAPSED_TIME=systime();
    UPDATE_TV=1;
    UPDATE_MOVIES=1;
    GET_POSTERS=0;
    GET_FANART=0;
    GET_PORTRAITS=0;
    UPDATE_POSTERS=0;
    UPDATE_FANART=0;
    UPDATE_PORTRAITS=0;

    g_api_tvdb="AQ1W1R0GAY5H7K1L8MFN9P1T2YDUAJF";
    g_api_tmdb="2qdr5t1vexeyep0k5l7m9nchdjfs4zz10xbv3s3w7qsehndjmckldplagscql1wnarkepv14";

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

function get_mounts(mtab,\
line,parts,f) {
    if ("@ovs_fetched" in mtab) return;
    f="/etc/mtab";
    while((getline line < f ) > 0) {
        split(line,parts," ");
        mtab[parts[2]]=1;
        DEBUG("mtab ["parts[2]"]");
    }
    mtab["@ovs_fetched"] = 1;
}

function get_settings(settings,\
line,f,n,v,n2,v2) {
    if ("@ovs_fetched" in settings) return;

    f="/tmp/setting.txt";
    while((getline line < f ) > 0) {
        n=index(line,"=");
        v=substr(line,n+1);
        n=substr(line,1,n-1);

        if ( index(n,"_BKMRK_") == 0) {

            settings[n] = v;
            DEBUG("setting ["n"]=["v"]");

            # if servname2=nas then store servname_nas=2 - this makes it easier to
            # find the corresponding servlink2 using the share name.
            if (n ~ /^servname/ ) {

                n2="servname_"v;
                v2="servlink"substr(n,length(n));

                settings[n2] = v2;
                DEBUG("setting *** ["n2"]=["v2"]");
            }
        }
    }
    close(f);
    settings["@ovs_fetched"] = 1;
}

function parse_link(link,details,\
parts,i,x) {
    #link is nfs:/..../&smb.user=fred&smb.passwd=pwd
    if (link == "") return 0;

    split("link="link,parts,"&");
    # now have link=nfs:/..../ , smb.user=fred ,  smb.passwd=pwd

    if (!(3 in parts)) return 0;
    for(i in parts) {
        split(parts[i],x,"=");
        details[x[1]]=x[2];
    }
    return 1;
}

function is_mounted(path,\
f,result,line) {
    result = 0;
    f = "/etc/mtab";
    while ((getline line < f) > 0) {
        if (index(line," "path" cifs ") || index(line," "path" nfs ")) {
           result=1;
           break;
       }
    }
    close(f);
    DEBUG("is mounted "path" = "result);
    return 0+ result;
}

# We could use smbclient.cgi but this would unmount other drives.
function nmt_mount_share(s,settings,\
path,link_details,p,newlink,usr,pwd,lnk) {

    path = g_mount_root s;

    if (is_mounted(path)) {

        DEBUG(s " already mounted at "path);
        return path;
    }

    get_settings(settings);

    DEBUG("servname_"s" = "settings[settings["servname_"s]]);
    if (parse_link(settings[settings["servname_"s]],link_details) == 0) {
        DEBUG("Could not find "s" in shares");
        return "";
    }

    lnk=link_details["link"];
    usr=link_details["smb.user"];
    pwd=link_details["smb.passwd"];

    DEBUG("Link for "s" is "lnk);

    p = mount_link(path,lnk,usr,pwd) ;

    #if we failed and it is a samba link but not an ip then try to resolve netbios name - microsoft grrr
    if ( p == "" ) {
       if ( index(lnk,"smb:") ) {
          if ( match(lnk,"[0-9]\\.[0-9]") == 0) {
            INF("Trying to resolve windows name");
            newlink = wins_resolve(lnk);
            if (newlink != "" && newlink != lnk ) {
                p = mount_link(path,newlink,usr,pwd) ;
            }
          }
        }
    }
    return p;
}

function mount_link(path,link,user,password,\
remote,cmd,result,t) {

    remote=link;

    sub(/^(nfs:\/\/|smb:)/,"",remote);

    if (link ~ "nfs:") {

        cmd = "mkdir -p "qa(path)" && mount -o soft,nolock,timeo=10 "qa(remote)" "qa(path);

    } else if (link ~ "smb:") {

        cmd = "mkdir -p "qa(path)" && mount -t cifs -o username="user",password="password" "qa(remote)" "qa(path);
        #cifs mount on nmt doesnt like blank passwords
        sub(/ username=,/," username=x,",cmd);

    } else {

        ERR("Dont know how to mount "link);
        path="";
    }
    t = systime();
    result = exec(cmd);
    if (result == 255 && systime() - t <= 1 ) {
        # if you try to double mount smb share you get error 255. Which is a meaningless error really.
        # Just assume it worked if it happened quickly.
        INF("Ignoring mount error");
        result=0;
    }
    if (result) {
        ERR("Unable to mount share "link);
        path="";
    }
    return path;
}

#Resolve wins name
function wins_resolve(link,\
line,host,ip,newlink,hostend,cmd) {

    cmd = "nbtscan "g_tmp_settings["eth_gateway"]"/24 > "qa(g_winsfile);
    DEBUG(cmd);
    exec(cmd);;
    if(match(link,"smb://[^/]+")) {
        hostend=RSTART+RLENGTH;
        host=substr(link,7,RLENGTH-6);
        
        while (newlink == "" && (getline line < g_winsfile ) > 0 ) {
            if (index(line," "g_tmp_settings["workgroup"]"\\"host" ")) {
                INF("Found Wins name "line);
                if (match(line,"^[0-9.]+")) {
                    ip=substr(line,RSTART,RLENGTH);
                    newlink="smb://"ip substr(link,hostend);
                    break;
                }
            } else {
                DEBUG("skip "line);
            }
        }
        close(g_winsfile);
    }
    INF("new link "newlink);
    return newlink;
}

# Given a path without a / find the mounted path
function nmt_get_share_path(f,\
share,share_path,rest) {
    if (f ~ "^/") {
        DEBUG("nmt_get_share_path "f" unchanged");
        return f;
    } else {
        share=g_share_map[f];
        rest=f;
        sub(/^[^\/]+/,"",rest);
        share_path=g_share_name_to_folder[share] rest;

        DEBUG("nmt_get_share_path "f" = "share_path);
        return share_path;
    }
}


END{
    g_user_agent="Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20040613 Firefox/0.8.0+";
    g_wget_opts="-T 30 -t 2 -w 2 -q --no-check-certificate --ignore-length ";
    g_art_timeout=" -T 60";


    g_mount_root="/opt/sybhttpd/localhost.drives/NETWORK_SHARE/";
    g_winsfile = APPDIR"/conf/wins.txt";
    g_item_count = 0;

    g_plot_file=PLOT_DB;
    g_plot_app=qa(APPDIR"/bin/plot.sh");

    for(i in g_settings) {
        g_settings_orig[i] = g_settings[i];
    }

    # code was originally written so that get_tv_series_info and get_episode_xml
    # write into lots of global arrays g_Season, g_episode, gTitle , g_imdb etc etc,
    # the idex being the item number.
    # However sometimes we need to call these functions but we dont want to keep the results.
    # (eg when tying to find which of Late night with Conan O Brien or Tonight Show with Conan Obrien
    # showed on a particular date.). This will make get_tv_series_info calls to both shows initially.
    #which then unfortunately writes results into the same global arrays.
    # Really the code needs a re-write to use a single temporary local array, for a single item
    # or a string even. This can then be inserted back into the global arrays when needed to be kept. 
    # 
    # Until code cleanup, best use a temporary index which is ignored by the main output loops.
    g_tmp_idx_prefix="tmp_";
    g_tmp_idx_count=0;

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

    split(g_settings["catalog_tv_plugins"],g_tv_plugin_list,g_cvs_sep);

#    split(g_settings["catalog_tv_plugins"],g_tv_plugin_list,g_cvs_sep);
#    g_tv_plugin_list = g_tv_plugin_list[1];
#    if (g_tv_plugin_list !~ "^(THETVDB|TVRAGE)$" ) {
#        ERR("Unknown tv plugin");
#        exit;
#    }

    INDEX_DB_NEW = INDEX_DB "." JOBID ".new";
    INDEX_DB_OLD = INDEX_DB "." DAY;

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

    #unit_tests();

    if (hash_size(FOLDER_ARR)) {

        gMovieFileCount = 0;
        gMaxDatabaseId = 0;
        
        load_settings("",UNPAK_CFG);

        g_api_tvdb = apply(g_api_tvdb);
        g_api_tmdb = apply(g_api_tmdb);
        g_grand_total = scan_folder_for_new_media(FOLDER_ARR,scan_options);

        delete g_occurs;
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


#IN indexToMergeHash - hash whose indexes are for scanned items ready to be processed.
function update_db(indexToMergeHash) {

    if (hash_size(indexToMergeHash) == 0 ) {
        INF("Nothing to merge");

    } else if (g_opt_dry_run) {

        INF("Database update skipped - dry run");

    } else if (lock(g_db_lock_file)) {

        ## clear new file
        printf "" > INDEX_DB_NEW;
        close(INDEX_DB_NEW);

        copyUntouchedToNewDatabase(INDEX_DB,INDEX_DB_NEW,indexToMergeHash);

        #new files are added first and removed from file_to_db list.
        add_new_scanned_files_to_database(indexToMergeHash,INDEX_DB_NEW);

        replace_database_with_new(INDEX_DB_NEW,INDEX_DB,INDEX_DB_OLD);

        unlock(g_db_lock_file);

        delete indexToMergeHash;
    }

}

function is_locked(lock_file,\
pid) {
    if (is_file(lock_file) == 0) return 0;

    pid="";
    if ((getline pid < lock_file) >= 0) {
        close(lock_file);
    }
    if (pid == "" ) {
       DEBUG("Not Locked = "pid);
       return 0;
    } else if (is_dir("/proc/"pid)) {
        if (pid == PID ) {
            DEBUG("Locked by this process "pid);
            return 0;
        } else {
            DEBUG("Locked by another process "pid " not "PID);
            return 1;
        }
    } else {
        DEBUG("Was locked by dead process "pid " not "PID);
        return 0;
    }
}

function lock(lock_file,fastfail,\
attempts,sleep,backoff) {
    attempts=0;
    sleep=10;
    split("10,10,20,30,60,120,300,300,300,300,300,600,600,600,600,600,1200",backoff,",");
    for(attempts=1 ; (attempts in backoff) ; attempts++) {
        if (is_locked(lock_file) == 0) {
            print PID > lock_file;
            close(lock_file);
            INF("Locked "lock_file);
            set_permissions(qa(lock_file));
            return 1;
        }
        if (fastfail != 0) break;
        sleep=backoff[attempts];
        WARNING("Failed to get exclusive lock. Retry in "sleep" seconds.");
        system("sleep "sleep);
    }
    ERR("Failed to get exclusive lock");
    return 0;
}

function unlock(lock_file) {
    INF("Unlocked "lock_file);
    system("rm -f -- "qa(lock_file));
}

function monthHash(nameList,sep,hash,\
names,i) {
    split(nameList,names,sep);
    for(i in names) {
        hash[tolower(names[i])] = i+0;
    }
} 

function replace_database_with_new(newdb,currentdb,olddb) {

    INF("Replace Database");

    system("cp -f "qa(currentdb)" "qa(olddb));

    touch_and_move(newdb,currentdb);

    set_permissions(qa(currentdb)" "qa(olddb));
}

function set_permissions(shellArg) {
    if (ENVIRON["USER"] != UID ) {
        return system("chown "OVERSIGHT_ID" "shellArg);
    }
    return 0;
}

function capitalise(text,\
i,rtext,rstart,words,wcount) {

    wcount= split(tolower(text),words," ");
    text = "";

    for(i = 1 ; i<= wcount ; i++) {
        text = text " " toupper(substr(words[i],1,1)) substr(words[i],2);
    }

    ## Uppercase roman
    if (get_regex_pos(text,"\\<[IVX][ivx]+\\>",0,rtext,rstart)) {
        for(i in rtext) {
            text = substr(text,1,rstart[i]-1) toupper(rtext[i]) substr(text,rstart[i]+length(rtext[i]));
        }
    }
    return substr(text,2);
}

function set_db_fields() {
    #DB fields should start with underscore to speed grepping etc.
    ID=db_field("_id","ID","",0);

    WATCHED=db_field("_w","Watched","watched") ;
    LOCKED=db_field("_l","Locked","locked") ;
    PARTS=db_field("_pt","PARTS","");
    FILE=db_field("_F","FILE","filenameandpath");
    NAME=db_field("_N","NAME","");
    DIR=db_field("_D","DIR","");
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

function scan_folder_for_new_media(folderArray,scan_options,\
f,fcount,total,done) {

    for(f in folderArray ) {

        if (folderArray[f] && !(f in done)) {
            report_status("folder "++fcount);
            total += scan_contents(folderArray[f],scan_options);
            done[f]=1;
        }
    }

    return 0+total;

}

#  Do ls -l on a known file and check position of filename and time
function findLSFormat(\
tempFile,i,procfile) {

    DEBUG("Finding LS Format");

    procfile="/proc/"PID"/fd"; #Fd always has a recent timestamp even on cygwin
    tempFile=new_capture_file("LS")


    exec(LS" -ld "procfile" > "qa(tempFile) );
    FS=" ";
    
    while ((getline < tempFile) > 0 ) {
        for(i=1 ; i - NF <= 0 ; i++ ) {
            if ($i == procfile) gLS_FILE_POS=i;
            if (index($i,":")) gLS_TIME_POS=i;
        }
        break;
    }
    close(tempFile);
    INF("ls -l file position at "gLS_FILE_POS);
    INF("ls -l time position at "gLS_TIME_POS);

}
function is_hidden_fldr(d,\
ur) {
    ur = g_settings["unpak_nmt_pin_root"];
    return ur != "" && index(d,ur) == 1;
}

function is_movie_structure_fldr(d) {
    return is_videots_fldr(d) || is_bdmv_subfldr(d);
}

function is_bdmv_subfldr(d) {
    return tolower(d) ~ "/bdmv/(playlist|clipinf|stream|auxdata|backup|jar|meta|bdjo)\\>";
}
function is_bdmv_fldr(d) {
    return tolower(d) ~ "/bdmv$" && dir_contains(d"/STREAM","m2ts$");
}
function is_videots_fldr(d) {
    return tolower(d) ~ "/video_ts$" && dir_contains(d,"vob$");
}
function dir_contains(dir,pattern) {
    return exec("ls "qa(dir)" 2>/dev/null | egrep -iq "qa(pattern) ) ==0;
}

# Input is ls -lR or ls -l
function scan_contents(root,scan_options,\
tempFile,currentFolder,skipFolder,i,folderNameNext,perms,w5,lsMonth,\
lsDate,lsTimeOrYear,f,d,extRe,pos,store,lc,nfo,quotedRoot,scan_line,scan_words,ts,total) {

    DEBUG("Scanning "root);
    if (root == "") return;

    if (NEWSCAN) {
        get_files(root,INDEX_DB);
    }

    tempFile=new_capture_file("MOVIEFILES");

    #Remove trailing slash. This ensures all folder paths end without trailing slash
    if (root != "/" ) {
        gsub(/\/+$/,"",root); 
    }

    quotedRoot=qa(root);

    extRe="\\.[^.]+$";

    #We use ls -R instead of find to get a sorted list.
    #There may be some issue with this.

    # We want to list a file which may be a file, folder or symlink.
    # ls -Rl x/ will do symlink but not normal file.
    #so do  ls -Rl x/ || ls -Rl x  
    # note ls -L will follow symlinks at any depth - this is passed via catalog_follow_symlinks
    exec("( "LS" "scan_options" "quotedRoot"/ || "LS" "scan_options" "quotedRoot" ) > "qa(tempFile) );
    currentFolder = root;
    skipFolder=0;
    folderNameNext=1;

    while((getline scan_line < tempFile) > 0 ) {


        #DEBUG( "ls: ["scan_line"]"); 
        #INF("scan_line: length="length(scan_line)" "url_encode(scan_line));

        store=0;

        if (scan_line == "") continue;

        if (match(scan_line,"^total [0-9]+$")) continue;

        split(scan_line,scan_words," +");

        perms=scan_words[1];

        if (!match(substr(perms,2,9),"^[-rwxsSt]+$") ) {
            #Just entered a folder

            # If the folder has changed and we have more than n items then process them
            # this is to save memory. As this removes stored data we only do this if we 
            # change folder. This ensures we process multipart files together.
            if (gMovieFileCount > g_batch_size ) {
                total += identify_and_catalog_scanned_files();
            }


           currentFolder = scan_line;
           sub(/\/*:$/,"",currentFolder);
           DEBUG("Folder = "currentFolder);
           folderNameNext=0;
            if ( currentFolder ~ g_settings["catalog_ignore_paths"] ) {

                skipFolder=1;
                INF("Ignore path "currentFolder);

            } else if ( is_movie_structure_fldr(currentFolder)) {

                INF("Ignore DVD/BDMV sub folder "currentFolder);
                skipFolder=1;

            } else if(is_hidden_fldr(currentFolder)) {

                skipFolder=1;
                INF("SKIPPING "currentFolder);

            } else if (currentFolder in g_fldrCount) {

                WARNING("Already visited "currentFolder);
                skipFolder=1;


            } else {
                skipFolder=0;
                g_fldrMediaCount[currentFolder]=0;
                g_fldrInfoCount[currentFolder]=0;
                g_fldrCount[currentFolder]=0;
            }

        } else if (!skipFolder) {

            lc=tolower(scan_line);

            if ( lc ~ g_settings["catalog_ignore_names"] ) {
                DEBUG("Ignore name "scan_line);
                continue;
            }

            w5=lsMonth=lsDate=lsTimeOrYear="";

            # ls -l format. Extract file time...
            w5=scan_words[5];

            if ( gLS_TIME_POS ) {
                lsMonth=tolower(scan_words[gLS_TIME_POS-2]);
                lsDate=scan_words[gLS_TIME_POS-1];
                lsTimeOrYear=scan_words[gLS_TIME_POS];
            }

            #Get Position of word at gLS_FILE_POS.
            #(not cannot change $n variables as they cause corruption of scan_line.eg 
            #double spaces collapsed.
            pos=index(scan_line,scan_words[2]);
            for(i=3 ; i - gLS_FILE_POS <= 0 ; i++ ) {
                pos=indexFrom(scan_line,scan_words[i],pos+length(scan_words[i-1]));
            }
            scan_line=substr(scan_line,pos);
            lc=tolower(scan_line);


            if (substr(perms,1,1) != "-") { # Not a file

                if (substr(perms,1,1) == "d") { #Directory

                    if (currentFolder in g_fldrCount) {
                        g_fldrCount[currentFolder]++;
                    }

                    DEBUG("Folder ["scan_line"]");

                    if (is_videots_fldr(currentFolder"/"scan_line) || is_bdmv_fldr(currentFolder"/"scan_line) ) {

                        if (match(currentFolder,"/[^/]+$")) {
                            f = substr(currentFolder,RSTART+1);
                            d = substr(currentFolder,1,RSTART-1);
                        }

                        ts=calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW);

                        storeMovie(gMovieFileCount,f"/",d,ts,"/$",".nfo");
                    }
                }

            } else {
                

                # Its a regular file

                # because we use ls to scan we must check if the file path was passed directly to ls
                # rather than part of a recursive listing.
                # This is all a bit yucky and needs a rewrite - but here we are..

                # eg mkdir a ; touch a/b a/c
                # ls -Rl a gives
                # a:
                # -rw-r--r--    1 root     root            0 Nov 15 03:12 b
                # -rw-r--r--    1 root     root            0 Nov 15 03:12 c
                # but
                # ls -Rl a a/b gives
                # -rw-r--r--    1 root     root            0 Nov 15 03:12 a/b
                # 
                # a:
                # -rw-r--r--    1 root     root            0 Nov 15 03:12 b
                # -rw-r--r--    1 root     root            0 Nov 15 03:12 c

                # the following code intercepts the "a/b" and makes it look like the recursive form.
                # maybe the much simple altermative is to test each ls argument and process one way
                # if its a folder or another if its a file.


                if (match(scan_line,"[^/]/")) { 
                    # get the currentFolder from the file path
                    i = match(scan_line,".*[^/]/"); # use .*  to get the last path component
                    # Current folder should be root at this stage as ls -Rl will gather all file arguments first.
                    currentFolder = substr(scan_line,1,RLENGTH-1);
                    if ( index(currentFolder,"/") != 1 ) {
                        currentFolder =  root "/" currentFolder;
                    }
                    currentFolder = clean_path( currentFolder );

                    scan_line = substr(scan_line,RLENGTH+1);
                    lc = tolower(scan_line);
                    INF("Looking at direct file argument ["currentFolder"]["scan_line"]");
                }

                # Now continue to check the file 

                if (match(lc,gExtRegexIso)) {
                    #ISO images.

                    # Check image size. Images should be very large or for testing only, very small.
                    if (length(w5) > 1 && length(w5) - 10 < 0) {
                        INF("Skipping image ["scan_line"] - too small");
                    } else {
                        store=1;
                    }

                } else if (match(scan_line,"unpak.???$")) {
                    
                    gDate[currentFolder"/"scan_line] = calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW);

                } else if (match(lc,gExtRegEx1)) {

                    #DEBUG("g_fldrMediaCount[currentFolder]="g_fldrMediaCount[currentFolder]);
                    #Only add it if previous one is not part of same file.
                    if (g_fldrMediaCount[currentFolder] > 0 && gMovieFileCount - 1 >= 0 ) {
                      if ( checkMultiPart(scan_line,gMovieFileCount) ) {
                          #replace xxx.cd1.ext with xxx.nfo (Internet convention)
                          #otherwise leave xxx.cd1.yyy.ext with xxx.cd1.yyy.nfo (YAMJ convention)
                          if ( !setNfo(gMovieFileCount-1,".(|"g_multpart_tags")[1-9]" extRe,".nfo") ) {
                              setNfo(gMovieFileCount-1, extRe,".nfo");
                          }
                      } else {
                          store=2;
                      }
                   } else {
                       #This is the first/only avi for this film/show
                       store=2;
                   }

                } else if (match(lc,"\\.nfo$")) {

                    nfo=currentFolder"/"scan_line;
                    g_fldrInfoCount[currentFolder]++;
                    g_fldrInfoName[currentFolder]=nfo;
                    gDate[nfo] = calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW);
                }

                if (store) {
                    ts=calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW);
                    storeMovie(gMovieFileCount,scan_line,currentFolder,ts,"\\.[^.]+$",".nfo")
                }
            }
        }

    }

    close(tempFile);

    total += identify_and_catalog_scanned_files();

    DEBUG("Finished Scanning "root);
    return 0+total;
}

# Convert a glob pattern to a regular exp.
# *=anything,?=single char, <=start of word , >=end of word |=OR
function glob2re(glob) {
    gsub(/[.]/,"\\.",glob);
    gsub(/[*]/,".*",glob);
    gsub(/[?]/,".",glob);
    gsub(/[<]/,"\\<",glob);
    gsub(/ *, */,"|",glob);
    gsub(/[>]/,"\\>",glob);

    #remove empty words
    gsub("^\\|","",glob);
    gsub("\\|$","",glob);
    gsub("\\|\\|","",glob);

    return "("glob")";
}

function csv2re(text) {
    gsub(/ *, */,"|",text);
    return "("text")";
}

function storeMovie(idx,file,folder,timeStamp,nfoReplace,nfoExt,\
path) {

    path=clean_path(folder"/"file);

    DEBUG("Storing " path);

    g_fldrMediaCount[folder]++;

    g_fldr[idx]=folder;
    g_media[idx] = file;


    #gMovieFilePresent is used when pruning the old index.
    #
    # if doing a new scan do not set it if the path is in the database.
    # ie set if any other type of scan OR
    # if NEWSCAN and path not in database.
    if (! (NEWSCAN == 1  &&  in_db(path))) {
        gMovieFilePresent[path] = idx;
    }

    g_file_time[idx] = timeStamp;

    setNfo(gMovieFileCount,nfoReplace,nfoExt);

    gMovieFileCount++;
}

#Check if a filename is similar to the previous stored filename.
# lcName         : lower case file name
# count          : next index in array
# multiPartRegex : regex that matches the part tag of the file
function checkMultiPart(name,count,\
lastNameSeen,i,lastch,ch) {

    lastNameSeen = g_media[count-1];

    #DEBUG("Multipart check ["lastNameSeen"] vs ["name"]");
    if (length(lastNameSeen) != length(name)) {
        #DEBUG("length ["lastNameSeen"] != ["name"]");
        return 0;
    }
    if (lastNameSeen == name) return 0;

    for(i=1 ; i - length(lastNameSeen) <= 0 ; i++ ) {
        lastch = substr(lastNameSeen,i,1);
        ch = substr(name,i,1);
        if (lastch != ch) {
            break;
        }
    }

    # Check following characters...
    if (substr(lastNameSeen,i+1) != substr(name,i+1)) {
        #DEBUG("no match last bit ["substr(lastNameSeen,i+1)"] != ["substr(name,i+1)"]");
        return 0;
    }

    lastch = tolower(lastch);
    ch = tolower(ch);

    # i is the point at which the filenames differ.

    if (lastch == "1" ) {
        if (index("2345",ch) == 0) {
            return 0;
        }
        # Ignore double digit xxx01 xxx02 these are likely tv series.
        if (substr(lastNameSeen,i-1,2) ~ "[0-9]1" ) {
            return 0;
        }
        # Avoid matching tv programs e0n x0n 11n
        # At this stage we have not done full filename analysis to determine if it matches a tv program
        # That is done during the scrape stage by "checkTvFilenameFormat". This is just a quick way.
        # reject 0e1 0x1 "ep 1" "dvd 1" etc.
        # we could change this to a white list instead. eg part01 cd1 etc.
        if (tolower(substr(lastNameSeen,1,i)) ~ "([0-9][.edx]|dvd|disc|ep|episode) *1$") {
            return 0;
        }

        #continue 

    } else if (lastch == "a") {

        if (index("bcdef",ch) == 0) {
            return 0;
        }
        #continue 
    } else {
        return 0;
    }

    INF("Found multi part file - linked with "lastNameSeen);
    gParts[count-1] = (gParts[count-1] =="" ? "" : gParts[count-1]"/" ) name;
    gMultiPartTagPos[count-1] = i;
    return 1;
}

# set the nfo file by replacing the pattern with the given text.
function setNfo(idx,pattern,replace,\
nfo,lcNfo) {
    #Add a lookup to nfo file
    nfo=g_media[idx];
    lcNfo = tolower(nfo);
    if (match(lcNfo,pattern)) {
        nfo=substr(nfo,1,RSTART-1) replace substr(nfo,RSTART+RLENGTH);
        gNfoDefault[idx] = getPath(nfo,g_fldr[idx]);
        return 1;
    } else {
        return 0;
    }
}

function exec(cmd,\
err) {
   #DEBUG("SYSTEM : "substr(cmd,1,100)"...");
   DEBUG("SYSTEM : [["cmd"]]");
   if ((err=system(cmd)) != 0) {
      ERR("Return code "err" executing "cmd) ;
  }
  return 0+ err;
}

#A folder is relevant if it is tightly associated with the media it contains.
#ie it was created just for that film or tv series.
# True is the folder was included as part of the scan and is specific to the current media file
function folderIsRelevant(dir) {

    DEBUG("Check parent folder relation to media ["dir"]");
        if ( !(dir in g_fldrCount) || g_fldrCount[dir] == "") { 
            DEBUG("unknown folder ["dir"]" );
            return 0;
        }
    #Ensure the folder was scanned and also it has 2 or fewer sub folders (VIDEO_TS,AUDIO_TS)
    if (g_fldrCount[dir] - 2 > 0 ) {
        DEBUG("Too many sub folders - general folder");
        return 0;
    }
   if (g_fldrMediaCount[dir] - 2 > 0 ) {
       DEBUG("Too much media  general folder");
       return 0;
   }
   return 1;
}

# Google is MILES ahead of yahoo and bing for the kind of searching oversight is doing.
# its a shame that it will blacklist repeat searches very quickly, so we use the 
# other engines in round-robin. If they disagree then google cast the deciding vote.
#
# Special case is if searching via IMDB search page - then the imdb_qual is used
function web_search_first_imdb_link(qualifier,imdb_qual) {
    return web_search_first(qualifier,imdb_qual,1,"imdbid","/tt",g_imdb_regex);
}
function web_search_first_imdb_title(qualifier,imdb_qual) {
    return web_search_first(qualifier,imdb_qual,0,"imdbtitle","",g_imdb_title_re);
}


# search for either first occurence OR most common occurences.
# return is array matches(index=matching text, value is incremented for each match)
# also src contains all urls that matched each pattern.
# results are merged into existing array values.
function scrapeMatches(url,freqOrFirst,helptxt,regex,matches,src,\
match1,submatch) {

    delete submatch;
    if (freqOrFirst == 1) {

        match1=scanPageFirstMatch(url,helptxt,regex,1);
        if (match1) {
            submatch[match1] = 1;
        }
    } else {

        scanPageMostFreqMatch(url,helptxt,regex,1,"",submatch);
    }
    # for each match we increment its score by one.

    for(match1 in submatch) {
        matches[match1] ++; 
        if (index(src[match1],":" url ":") == 0) {
            src[match1]=src[match1] ":" url ":";
        }
    }
}

# When searching for a title we may see.
# The Movie (2009)
# The Movie 2009
# the movie 2009
# The.Movie 2009
# Download The Movie 2009 
# Input "matches" hash of raw titles and counts
# Output "normed" hash of normalised titles and counts
function normalise_title_matches(matches,normed,\
t,t2,y) {

    delete normed;
    for(t in matches) {
        t2=t;
        gsub("[^"g_alnum8"]"," ",t2);
        gsub(/  +/," ",t2);
        t2 = capitalise(trim(t2));


        #Ignore anything that looks like a date.
        if (t2 !~ "(©|Gmt|Pdt|("g_months_short"|"g_months_long")(| [0-9][0-9])) "g_year_re"$" ) {
            #or a sentence blah blah blah In 2003
            if (t2 !~ "[A-Z][a-z]* [A-Z][a-z]* [A-Z][a-z]* (In|Of) "g_year_re"$" ) {

                # remove tags from "movie name DVD 2009" etc.
                if (match(t2," \\(?"g_year_re"\\)?$")) {
                    y = substr(t2,RSTART);
                    t2 = substr(t2,1,RSTART-1);
                }
                t2 = remove_format_tags(t2) y;

                INF("["t"]=>["t2"]");


                normed[t2] += matches[t];
            }
        }
    }
    # Any that are substrings inherit the score of the superstring.
    # eg "The Movie 2009" and "Download The Movie 2009"
    # But only add the score if the longer title appears less frequently than the short title.
    # this is to help ensure that a title that is broken by a page break does not get a big score.
    # eg.
    # --------------
    # Star Wars 1977
    # Star Wars 1977
    # Star Wars 1977
    # Wars 1977
    # --------------
    # In the above case we do NOT want Wars 1977 to have a high score. But...
    # --------------
    # Download Star Wars 1977
    # Star Wars 1977
    # Star Wars 1977
    # Star Wars 1977
    # --------------
    # In the above case we DO want Star Wars 1977 to inherit the score for "Download Star Wars 1977"
    # This presents a problem for
    # --------------
    # Download Star Wars 1977
    # Download Star Wars 1977
    # Star Wars 1977
    #---------------
    # So only inherit the score if #short + 2 >= #long (This is just arbitrary heuristic)

    for(t in normed) {
        for(t2 in normed) {
            if (t != t2 && index(t2,t)) {
                if (normed[t]+2 >= normed[t2]+0 ) {
                    normed[t] += normed[t2];
                }
            }
        }
    }
    dump(0,"normalise title matches out",normed);
}

# Special case is if searching via IMDB search page - then the imdb_qual is used
# the help text just helps avoid overhead of regex matching.
# freqOrFirst =0 freq match | =1 first match
#
# normedt = normalized titles. eg The Movie (2009) = the.movie.2009 etc.
function web_search_first(qualifier,imdb_qual,freqOrFirst,mode,helptxt,regex,\
u,s,pages,subtotal,ret,i,matches,m,src) {


    set_cache_prefix("@");
    id1("web_search_first "mode" ["qualifier"]");
    u[1] = search_url("SEARCH" qualifier);
    u[2] = search_url("SEARCH" qualifier);
    u[3] = g_search_google qualifier;
    u[4] = "http://www.imdb.com/find?s=tt&q=" imdb_qual;
    
    #The search string itself will be present not only in the serp but also in the title and input box
    #So if searching for "DVD Aliens (1981)" then the most popular result may include DVD.
    #we can remove these matches by modifying the search string slighty so it will give same results 
    #but will not match the imdb title regex. To do this convert eg. Fred (2009) to "Fred + (2009)"
    for(i = 1 ; i-2 <= 0 ; i++ ) {
        sub("\\<"g_year_re"\\>","+%2B+&",u[i]);
    }

    #Check first two search engines.
    for(i = 1 ; i-2 <= 0 ; i++ ) {
        scrapeMatches(u[i],freqOrFirst,helptxt,regex,matches,src);
    }
    i = bestScores(matches,matches,0);
    if (i == 2 ) {

        ret = firstIndex(matches);

    } else if ( i == 1 ) {

        # previous searches have different results. 
        # merge in google results.
        #
        scrapeMatches(u[3],freqOrFirst,helptxt,regex,matches,src);
        if (bestScores(matches,matches,0) == 2 ) {

            ret = firstIndex(matches);

        } else {

            if (imdb_qual != "" ) {
                # TODO Try direct imdb search
                scrapeMatches(u[4],freqOrFirst,helptxt,regex,matches,src);
                
                if (bestScores(matches,matches,0) == 2 ) {

                    ret = firstIndex(matches);
                }
            }
            
            if (ret == "") {

                # Still nothing appears twice. 
                #Go through each match and see how many times it appears on the other pages.
                # this is why we track the matching urls in the src array.
                for(m in matches) {
                    id1("cross_page_rank "m"|");
                    pages=0;
                    subtotal=0;
                    for(i = 1 ; i-3 <= 0 ; i++ ) {
                        if (index(src[m],":"u[i]":") == 0) {
                            s = scan_page_for_match_counts(u[i],m,title_to_re(m),0,1,"");
                            if (s != 0) pages++;
                            subtotal += s;
                        }
                    }
                    matches[m] += pages * subtotal;
                    id0(pages*subtotal);
                }
                ret = getMax(matches,4,1);
            }
        }
    }

    clear_cache_prefix("@");
    id0(ret);
    return ret;
}

# If no direct urls found. Search using file names.
function web_search_frequent_imdb_link(idx,\
url,txt,linksRequired) {

    id1("web_search_frequent_imdb_link");
    linksRequired = 0+g_settings["catalog_imdb_links_required"];
    
    txt = basename(g_media[idx]);
    if (tolower(txt) != "dvd_volume" ) {
        url=searchHeuristicsForImdbLink(txt,linksRequired);
    }

    if (url == "" && match(g_media[idx],gExtRegexIso)) {
        txt = getIsoTitle(g_fldr[idx]"/"g_media[idx]);
        if (length(txt) - 3 > 0 ) {
            url=searchHeuristicsForImdbLink(txt,linksRequired);
        }
    }

    if (url == "" && folderIsRelevant(g_fldr[idx])) {
        url=searchHeuristicsForImdbLink(tolower(basename(g_fldr[idx])),linksRequired);
    }

    id0(url);
    return url;
}

function remove_part_suffix(idx,\
txt) {
    # Remove first word - which is often a scene tag
    #This could affect the search adversely, esp if the film name is abbreviated.
    # Too much information is lost. eg coa-v-xvid will eventually become just v
    #so we do this last. 
    txt = tolower(basename(g_media[idx]));

    #Remove the cd1 partb bit.
    if (idx in gMultiPartTagPos) {
        txt = substr(txt,1,gMultiPartTagPos[idx]);
        sub("("g_multpart_tags"|)[1a]$","",txt);
        DEBUG("MultiPart Suffix removed = ["txt"]");
    }

    return txt;
}

function mergeSearchKeywords(text,keywordArray,\
heuristicId,keywords) {
    # Build array of different styles of keyword search. eg [a b] [+a +b] ["a b"]
    for(heuristicId =  0 ; heuristicId -1  <= 0 ; heuristicId++ ) {
        keywords =textToSearchKeywords(text,heuristicId);
        keywordArray[keywords]=1;
    }
}


function searchHeuristicsForImdbLink(text,linksRequired,\
bestUrl,k,text_no_underscore) {

    mergeSearchKeywords(text,k);

    text_no_underscore = text;
    gsub(/_/," ",text_no_underscore);
    gsub("[[][^]]+[]]","",text_no_underscore);
    if (text_no_underscore != text) {
        mergeSearchKeywords(text_no_underscore,k);
    }

    bestUrl = searchArrayForIMDB(k,linksRequired);

    return bestUrl;
}

# Try all of the array indexs(not values) in web search for imdb link.
# Try with and without tv tags
function searchArrayForIMDB(k,linkThreshold,\
bestUrl,keywords,keywordsSansEpisode) {

    id1("direct search...");
    bestUrl = searchArrayForIMDB2(k,linkThreshold);

    if (bestUrl == "") {
        # Remove episode tags and try again
        for(keywords in k) {
            if (sub(/ *[sS][0-9][0-9][eE][0-9][0-9].*/,"",keywords)) {
                keywordsSansEpisode[keywords]=1;
            }
        }
        bestUrl = searchArrayForIMDB2(keywordsSansEpisode,linkThreshold);
    }
    id0(bestUrl);

    return bestUrl;
}

function searchArrayForIMDB2(k,linkThreshold,\
bestUrl,keywords) {
    # Try simple keyword searches with imdb keywords added.
    for(keywords in k) {
        bestUrl = searchForIMDB(keywords,linkThreshold);
        if (bestUrl != "") {
            return bestUrl;
        }
    }
    return "";
}

# Extract the dir`name from the path. Note if the file ends in / then the parent is used (for VIDEO_TS)
function dirname(f) {

    #Special case - paths ending in /, the / indicates it is a VIDEO_TS folder and should otherwise be ignored.
    sub(/\/$/,"",f);

    #Relative paths
    if (f !~ "^[/$]" ) {
        f = "./"f;
    }

    #remove filename
    sub(/\/[^\/]+$/,"",f);
    return f;
}

# Extract the filename from the path. Note if the file ends in / then the folder is the filename
function basename(f) {
    if (match(f,"/[^/]+$")) {
        # /path/to/file return "file"
        f=substr(f,RSTART+1);
    } else if (match(f,"/[^/]+/$")) {
        # "/path/to/folder/" return "folder"
        f=substr(f,RSTART+1,RLENGTH-2);
    }
    sub(gExtRegExAll,"",f); #remove extension
    return f;
}

#If stripFormatTags set then only portion before recognised format tags (eg 720p etc) is search.
#This helps broaden results and get better consensus from google.
function textToSearchKeywords(f,heuristic\
) {

    #heuristic 0 - All words optional (+) and strip format tags strip episode s0ne0n
    #heuristic 1 - All words mandatory (+%2B) and strip format tags strip episode s0ne0n
    #heuristic 2 - Quoted file search 
    f=tolower(f);

    if (heuristic == 0 || heuristic == 1) {

        #removed hyphen from list
        gsub("[^" g_alnum8"]+","+",f);

        #remove words ending with numbers
        #gsub(/\<[A-Za-z]+[0-9]+\>/,"",f);

        #remove everything after a year
        if (match(f,"\\<"g_year_re"\\>")) {
            f = substr(f,1,RSTART+RLENGTH-1);
        }
#        #remove everything after episode
#        if (match(f,"\\<[sS][0-9][0-9][eE][0-9][0-9]")) {
#            f = substr(f,1,RSTART+RLENGTH-1);
#        }

        f = remove_format_tags(f);

        #Make words mandatory
        if (heuristic == 1) {
            DEBUG("Base query = "f);
            gsub(/[-+.]/,"+%2B",f);
            f="%2B"f;
        }

        gsub(/^\+/,"",f);
        gsub(/\+$/,"",f);

    } else if (heuristic == 2) {

        f = "%22"f"%22"; #double quotes
    }
    DEBUG("Using search method "heuristic" = ["f"]");
    return f;
}


# remove all text after a format tag. eg "blah blah dvdrip blah2" => "blah blah"
# but if the first word matches a format tag then that word is removed.
# eg. "dvdrip blah 720p blah2" => "blah"
function remove_format_tags(text,\
                            tags) {

    tags = g_settings["catalog_format_tags"];

    # Remove format tags at the beginning
    while (match(tolower(text),"^"tags)) {
        # Remove the first word (the format tag may only be a partial word match)
        DEBUG("format tag prefix ["text"]");
        sub(/^[a-zA-Z0-9]+[^a-zA-Z0-9]*/,"",text);
        DEBUG("format tag prefix ["text"]");
    }

    # Remove all trailing tags and any other text.
    if (match(tolower(text),tags)) {
        text = substr(text,1,RSTART-1);
    }

    #remove trailing punctuation
    return trimAll(text);
}

# input imdb id
# OUT: list - array of strings of CSV imdb ids.
# list["Follows"]     = list of imdb ids that follow this movie etc.
# list["Followed by"] = 
# list["Remade as"]   =
# list["Remake of"]   =
#
function getMovieConnections(id,list,\
url,htag,connections,i,count,relationship,ret,txt,sep) {
    id1("getMovieConnections");
    delete list;
    htag = "h5";
    sep=",";
    url = extractImdbLink(id)"movieconnections";
    count=scan_page_for_match_order(url,"","(<h[1-5]>[^<]+</h[1-5]>|"g_imdb_regex")",0,0,"",connections);
    #dump(0,"movieconnections-"count,connections);
    for(i = 1 ; i <= count ; i++ ) {
        txt = connections[i];
        if (substr(txt,1,2) == "tt" ) {
            if (relationship != "") {
                list[relationship] = list[relationship] sep connections[i];
            }
        } else if(index(txt,"<") ) {
            if (match(txt,">[^<]+")) {
                relationship=substr(txt,RSTART+1,RLENGTH-1);
            }
        } else {
            relationship="";
        }
    }
    # remove leading comma
    for(i in list) {
        list[i] = imdb_list_shrink(substr(list[i],length(sep)+1),sep,128);
    }
    dump(0,id" movie connections",list);
    id0(ret);
    return ret;
}

function scrapeIMDBTitlePage(idx,url,\
f,line,imdbContentPosition,isection) {

    if (url == "" ) return;

    #Remove /combined/episodes from urls given by epguides.
    url=extractImdbLink(url);

    if (url == "" ) return;

    id1("scrape imdb ["url"]");

    if (g_imdb[idx] == "") {
        g_imdb[idx] = extractImdbId(url);
    }
    
    f=getUrl(url,"imdb_main",1);
    hash_copy(isection,g_imdb_sections);

    if (f != "" ) {

        imdbContentPosition="header";

        DEBUG("START IMDB: title:"gTitle[idx]" poster "g_poster[idx]" genre "g_genre[idx]" cert "gCertRating[idx]" year "g_year[idx]);

        FS="\n";
        while(imdbContentPosition != "footer" && enc_getline(f,line) > 0  ) {
            imdbContentPosition=scrape_imdb_line(line[1],imdbContentPosition,idx,f,isection);
        }
        enc_close(f);

        if (hash_size(isection) > 0 ) {
            ERR("Unparsed imdb sections ");
            dump(0,"missing",isection);
        }


        if (gCertCountry[idx] != "" && g_settings[g_country_prefix gCertCountry[idx]] != "") {
            gCertCountry[idx] = g_settings[g_country_prefix gCertCountry[idx]];
        }

    }
# Dont need premier anymore - this was for searching from imdb to tv database
# we just use the year instead.
#    if (g_category[idx] == "T" && g_premier[idx] == "" ) {
#        g_premier[idx] = remove_tags(scanPageFirstMatch(url"/releaseinfo","BusinessThisDay.*",1));
#        DEBUG("IMDB Premier = "g_premier[idx]);
#    }
    id0("category = "g_category[idx] );
}


##### LOADING INDEX INTO DB_ARR[] ###############################

#Used by generate nfo
function parseDbRow(row,arr,\
fields,i,fnum) {
    fnum = split(row,fields,"\t");
    for(i = 2 ; i-fnum <= 0 ; i+=2 ) {
        arr[fields[i]] = fields[i+1];
    }
    if (index(arr[FILE],"/") != 1 ) {
        arr[FILE] = g_mount_root arr[FILE];
    }
    arr[FILE] = clean_path(arr[FILE]);
}

function clean_path(f) {
    if (index(f,"../")) {
        while (gsub(/\/[^\/]+\/\.\.\//,"/",f) ) {
            continue;
        }
    }
    while (index(f,"/./")) {
        gsub(/\/\.\//,"/",f);
    }
    while (index(f,"//")) {
        gsub(/\/\/+/,"/",f);
    }
    return f;
}

function get_name_dir_fields(arr,\
f,fileRe) {

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

# Go through old index.db 
# if any file is in the new scan, add the updated entry to the new file (copying watched flags)
# otherwise if it is not in the ignore list, add it directly to the new file
function copyUntouchedToNewDatabase(db_file,new_db_file,indexToMergeHash,\
kept_count,updated_count,total_lines,f,dbline,dbline2,dbfields,idx) {

    kept_count=0;
    updated_count=0;

    INF("read_database");


    FS="\n";
    close(db_file);
    while((getline dbline < db_file) > 0 ) {

        total_lines++;

        if ( index(dbline,"\t") != 1 ) { continue; }

        parseDbRow(dbline,dbfields);
        get_name_dir_fields(dbfields);

        f = dbfields[FILE];

        
        if (f in gMovieFilePresent) {

            idx=gMovieFilePresent[f];
            if (idx != -1 ) {
                # Update the old entry with the new data
                dbline2 = createIndexRow(idx,dbfields[ID],dbfields[WATCHED],dbfields[LOCKED],""); #dbfields[INDEXTIME]);
                if (length(dbline2) - g_max_db_len < 0) {
                    print dbline2"\t" >> new_db_file;
                    updated_count++;
                    update_plots(g_plot_file,idx);
                }
                delete indexToMergeHash[idx];
                #make sure we dont add it later.
                gMovieFilePresent[f] = -1;
            } else {
                INF("Duplicate ["dbfields[FILE]"]");
            }

        } else if ( dbfields[DIR] ~ g_settings["catalog_ignore_paths"] ) {

            INF("Removing Ignored Path ["dbfields[FILE]"]");

        } else if ( dbfields[NAME] ~ g_settings["catalog_ignore_names"] ) {

            INF("Removing Ignored Name "dbfields[FILE]"]");

        } else {

            kept_count++;
            print dbline >> new_db_file;
        }
        # sanity check
        if ( dbfields[FILE] == "" ) {
            ERR("Blank file for ["dbline"]");
        }
        if (dbfields[ID] - gMaxDatabaseId > 0) {
            gMaxDatabaseId = dbfields[ID];
        }
    }
    close(db_file);

    close(new_db_file);

    delete gMovieFilePresent;

    INF("Existing database: size:"total_lines" untouched "kept_count" updated "updated_count);
    return kept_count+updated_count;
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

function in_db(path,verbose\
) {
    path = short_path(path);
    if (index(path,g_occurs_prefix) != 1) {
        ERR("Cannot check ["path"] occurs agains current prefix ["g_occurs_prefix"]");
        exit;
    }
    if (path in g_occurs) {
        if (verbose) INF("["path"] already scanned");
        return 1;
    } else {
        INF("["path"] not in db");
        return 0;
    }
}

function add_file(path) {
    if (NEWSCAN == 1) g_occurs[short_path(path)]++;
}

# Get all of the files that have already been scanned that start with the 
# same prefix.
function get_files(prefix,db,\
dbline,dbfields,err,count,filter) {

    id1("get_files ["prefix"]");
    delete g_occurs;
    g_occurs_prefix = short_path(prefix);

    filter = "\t" FILE "\t" g_occurs_prefix;
    INF("get_files filter = "filter);

    while((err = (getline dbline < db )) > 0) {

        if ( index(dbline,filter) ) {

            parseDbRow(dbline,dbfields);

             add_file(dbfields[FILE]);
#        # Only treat video as scanned if it was previously categorised.
#        # This allows rescans of bad files.
#        if (index("MT",dbfields[CATEGORY]) > 0) {
#            add_file(dbfields[FILE]);
#        }
            count++;
        }
    }
    if (err == 0 ) close(db);
    #dump(0,"scanned",g_occurs);
    id0(count" files");
}

function remove_brackets(s) {

    # A while loop is used for nested brackets. It happens.
    while (gsub(/\[[^][]*\]/,"",s) || gsub(/\{[^}{]*\}/,"",s)) continue;

    # remove round brackets only if content is non-numeric nor blank
    while (gsub(/\([^()]*[^0-9 ][^()]*\)/,"",s)) continue;

    return s;
}

# Re-instate old pruning test with extra folder check for absent media
# Because we need to check every file in the database it can take some time
# also if using awk we want to avoid spawning a process (or two) for each check
# so ls is used. If a file is absent then it is removed only if its grandparent is 
# present - this is to allow for detached devices. (sort of)
function remove_absent_files_from_new_db(db,\
    tmp_db,dbfields,\
    list,f,shortf,maxCommandLength,dbline,keep,\
    gp,blacklist_re,blacklist_dir,timer,in_scanned_list) {
    list="";
    maxCommandLength=3999;

    INF("Pruning...");
    tmp_db = db "." JOBID ".tmp";

    get_files("",db);

    if (lock(g_db_lock_file)) {
        g_kept_file_count=0;
        g_absent_file_count=0;

        close(db);
        while((getline dbline < db ) > 0) {

            if ( index(dbline,"\t") != 1 ) { continue; }

            parseDbRow(dbline,dbfields);

            f = dbfields[FILE];
            shortf = short_path(f);
            #INF("Prune ? ["f"]");

            keep=1;

            in_scanned_list = (shortf in g_occurs);

            if (in_scanned_list == 1 && NEWSCAN == 1 && g_occurs[shortf] == 0 ) {

                #For duplicate files we want to keep the first one (g_occurs[]=1) as this is the one 
                #that gets updated during a rescan. So if g_occurs(f) > 1 then
                # set it to 0 at the end of this loop. Then the next duplicate will 
                # trigger this code.

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
            if (in_scanned_list == 1 && NEWSCAN == 1 && g_occurs[shortf] - 1 > 0) {
                #For duplicate files we want to keep the first one as this is the one 
                #that gets updated during a rescan. So if g_occurs(f) > 1 then
                # set it to 0. Then the next duplicate will trigger delete code.
                g_occurs[shortf] = 0;
            }
        }
        close(tmp_db);
        close(db);
        INF("unchanged:"g_kept_file_count);
        INF("removed:"g_absent_file_count);
        replace_database_with_new(tmp_db,db,INDEX_DB_OLD);
    }
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

##### PRUNING DELETED ENTRIES FROM INDEX ###############################

#Return single quoted file name. Inner quotes are backslash escaped.
function qa(f) {
    gsub(/'/,"'\\''",f);
    return "'"f"'";
}

# Convert a movie title and year to a regular expression that should match 
# similar web results eg the.movie 2009 and  The Movie (2009)
# The incoming titles will not have brackets on the year.
function title_to_re(s,\
i,words,count,s2,ch) {

    # "the movie 2009" to "the movie \(?2009\)?"
    sub(g_year_re"$","\\(?&\\)?",s); 

    # "the movie" to "[Tt][Hh][Ee] [Mm][Oo]vie"
    # could use tolower() but this means another parameter to scan_page_for_match_counts and complicates
    # returning matches as the match string is modified by tolower().
    count = chop(s,"\\<[a-zA-z]",words);
    s2="";
    for(i = 1 ; i - length(s) <= 0 ; i++ ) {
        ch = substr(s,i,1);
        if (tolower(ch) != toupper(ch) ) {
            s2 = s2 "[" tolower(ch) toupper(ch) "]";
        } else {
            s2 = s2 ch;
        }
    }

    # "[Tt]he [Mm]ovie" to "[Tt]he.[Mm]ovie"
    sub(/ /,"[. ]",s2); 

    return "\\<"s2"\\>";
}


#ALL#function re_escape(s) {
#ALL#    gsub("[^- _"g_alnum8"]","\\&",s);
#ALL#    return s;
#ALL#}

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

# IN plugin THETVDB/TVRAGE
# IN idx - global arrays for current scrapped show
# OUT more_info - bit yucky returns additional info
#    currently more_info[1] indicates if abbrevation searches should be used when scraping later on.
# RET 0 - no format found
#     1 - tv format found - needs to be confirmed by scraping 
#
function checkTvFilenameFormat(plugin,idx,more_info,\
details,line,dirs,d,dirCount,dirLevels,ret) {

    delete more_info;
    #First get season and episode information

   id1("checkTvFilenameFormat "plugin);

   line = remove_format_tags(g_media[idx]);
   DEBUG("CHECK TV ["line"] vs ["g_media[idx]"]");

   dirCount = split(g_fldr[idx],dirs,"/");
   dirLevels=2;

   # After extracting the title text we look for matching tv programs
   # We only look at abbreviations if the title did NOT use the folder name.
   # The assumption is the people abbreviate file names but not folder names.
   more_info[1]=1; # enable abbrevation scraping for later

   for(d=0 ; d-dirLevels <= 0  ; d++ ) {

       if (extractEpisodeByPatterns(plugin,line,details)==1) {
           ret = 1;
           break;
       }
       if (episodeExtract(tolower(line),0,"\\<","","[/ .]?(ep?[^a-z0-9]?|episode)[^a-z0-9]*[0-9][0-9]?",details)) { #00x00 
          dump(0,"details",details);
          ret = 1;
          break;
       }
       if (d == dirLevels) {
           INF("No tv series-episode format in ["line"]");
           break;
       }
       line=dirs[dirCount-d]"/"line;
       more_info[1]=0; # disable abbrevation scrape
   }


#ALL#   # try looking for mini series formats.
#ALL#   if (ret == 0 ) {
#ALL#       more_info[1]=1; # enable abbrevation scraping for later
#ALL#       line = remove_format_tags(g_media[idx]);
#ALL#       for(d=0 ; d-dirLevels <= 0  ; d++ ) {
#ALL#           INF("xx1 ["line"]");
#ALL#           if (episodeExtract(tolower(line),0,"\\<","","[/ .]?(ep?[^a-z0-9]?|episode)[^a-z0-9]*[0-9][0-9]?",details)) { #00x00 
#ALL#              dump(0,"details",details);
#ALL#              ret = 1;
#ALL#              break;
#ALL#           }
#ALL#           if (d == dirLevels) {
#ALL#               INF("No mini-series format in ["line"]");
#ALL#               break;
#ALL#           }
#ALL#           line=dirs[dirCount-d]"/"line;
#ALL#           more_info[1]=0; # disable abbrevation scrape
#ALL#        }
#ALL#    }

    if (ret == 1) {

        if (details[TITLE] == "" ) {
            # format = 202 some text...
            # title may be in parent folder. but we will try to search by additional info first.
            searchByEpisodeName(plugin,details);
        }
        adjustTitle(idx,details[TITLE],"filename");


        g_season[idx]=details[SEASON];
        g_episode[idx]=details[EPISODE];

        INF("Found tv info in file name:"line" title:["gTitle[idx]"] ["g_season[idx]"] x ["g_episode[idx]"]");
        
        ## Commented Out As Double Episode checked elsewhere to shrink code ##
        ## Left In So We Can Ensure It's Ok ##
        ## If the episode is a twin episode eg S05E23E24 => 23e24 then replace e with ,
        ## Then prior to any DB lookups we just use the first integer (episode+0)
        ## To avoid changing the e in the BigBrother d000e format first check its not at the end 

        # local ePos

        #ePos = index(g_episode[idx],",");
        #if (ePos -1 >= 0 && ( ePos - length(g_episode[idx]) < 0 )) {
        #    #gsub(/[-e]+/,",",g_episode[idx]);
        #    #sub(/[-]/,"",g_episode[idx]);
        #    DEBUG("Double Episode : "g_episode[idx]);
        #}


        g_tvid[idx] = details[TVID];
        g_tvid_plugin[idx] = plugin;
        g_category[idx] = "T";
        gAdditionalInfo[idx] = details[ADDITIONAL_INF];
        # Now check the title.
        #TODO
    }
    id0(ret);
    return ret;
}

function searchByEpisodeName(plugin,details,\
terms,results,id,url,parts,showurl) {
    # search the tv sites using season , episode no and episode name.
    # ony bing or google - yahoo is not good here
    id1("searchByEpisodeName "plugin);
    dump(0,"searchByEpisodeName",details);
    if (plugin == "THETVDB") {
        terms="\"season "details[SEASON]"\" \""details[EPISODE]" : "clean_title(details[ADDITIONAL_INF])"\" site:thetvdb.com";
        # Bing seems a bit better than google for this. For "The office" anyway.
        # But google finds 1x5 Jersey Devil = X Files.
        results = scanPageFirstMatch(g_search_bing terms,"seriesid","seriesid=[0-9]+",0);
        #results = scanPageFirstMatch(g_search_google terms,"seriesid","seriesid=[0-9]+",0);
        if (split(results,parts,"=") == 2) {
            id = parts[2];
        }
    } else if (plugin == "TVRAGE") {
        terms="\"season "details[SEASON]"\" "details[SEASON]"x"sprintf("%02d",details[EPISODE])" \""clean_title(details[ADDITIONAL_INF])"\" site:tvrage.com";
        url = scanPageFirstMatch(g_search_google terms,"tvrage","http://[a-z0-9.]+.tvrage."g_nonquote_regex"+",0);
        if (url != "") {
            scan_page_for_match_counts(url,"/shows/","/shows/[0-9]+",0,0,"",results);
            showurl=getMax(results,1,1);
            if (split(showurl,parts,"/") == 2) {
                id = parts[2];
            }
        }
    } 
    id0(id);
    details[TVID]=id;
    return id;
}

#
# If Plugin != "" then it will also check episodes by date.
function extractEpisodeByPatterns(plugin,line,details,\
ret,p,pat,i,parts,sreg,ereg) {

    #Note if looking at entire path name folders are seperated by /


    line = tolower(line);

    #id1("extractEpisodeByPatterns["line"]");

    ret=0;

    sreg="([0-5][0-9]|[0-9])";

    ereg="[0-9][0-9]?";

    # Each pattern has format  prefix match len @ prefix regex @ series regex @ episode regex @ episode prefix
    # This mess is because awk regex dont have captures.
    p=0
    # s00e00e01
    pat[++p]="0@@s"sreg"@[/ .]?[e/][0-9]+[-,e0-9]+@";
    # long forms season 1 ep  3
    pat[++p]="0@\\<@(series|season|saison|s)[^a-z0-9]*"sreg"@[/ .]?(e|ep.?|episode|/)[^a-z0-9]*"ereg"@";

    # TV DVDs
    pat[++p]="0@\\<@(series|season|saison|seizoen|s)[^a-z0-9]*"sreg"@[/ .]?(disc|dvd|d)[^a-z0-9]*"ereg"@DVD";

    #s00e00 (allow d00a for BigBrother)
    pat[++p]="0@@s?"sreg"@[-/ .]?[e/][0-9]+[a-e]?@";

    # season but no episode
    pat[++p]="0@\\<@(series|season|saison|seizoen|s)[^a-z0-9]*"sreg"@@FILE";

    #00x00
    pat[++p]="1@[^a-z0-9]@"sreg"@[/ .]?x"ereg"@";
    #Try to extract dates before patterns because 2009 could be part of 2009.12.05 or  mean s20e09
    #TODO blank idx passed. need to tidy up code here?
    # extractEpisodeByDates is also called by other logic. 
    # we need to be clear why idx is passed.
    pat[++p]="DATE";
    ## just numbers.
    pat[++p]="1@[^-0-9]@([1-9]|2[1-9]|1[0-8]|[03-9][0-9])@/?[0-9][0-9]@";

    for(i = 1 ; ret+0 == 0 && p-i >= 0 ; i++ ) {
        if (pat[i] == "DATE" && plugin != "" ) {
            ret = extractEpisodeByDates(plugin,line,details);
        } else {
            split(pat[i],parts,"@");
            #dump(0,"epparts",parts);
            ret = episodeExtract(line,parts[1]+0,parts[2],parts[3],parts[4],details);
            if (ret+0) {
                # For DVDs add DVD prefix to Episode
                details[EPISODE] = parts[5] details[EPISODE];
            }
        }
    }

    if (ret+0 != 0) {
        id1("extractEpisodeByPatterns: line["line"]");
        dump(0,"details",details);
        id0(ret);
    }
    #id0(ret);
   #Note 4 digit season/episode matcing [12]\d\d\d will fail because of confusion with years.
    return 0+ret;
}

function formatDate(line,\
date,nonDate) {
    if (extractDate(line,date,nonDate) == 0) {
        return line;
    }
    line=sprintf("%04d-%02d-%02d",date[1],date[2],date[3]);
    return line;
}


# Input date text
# Output array[1]=y [2]=m [3]=d 
#nonDate[1]=bit before date, nonDate[2]=bit after date
# or empty array
function extractDate(line,date,nonDate,\
y4,d1,d2,d1or2,m1,m2,m1or2,d,m,y,datePart,textMonth,s,mword) {

    line = tolower(line);
    textMonth = 0;
    delete date;
    delete nonDate;
    #Extract the date.
    #because awk doesnt capture submatches we have to do this a slightly painful way.
    y4=g_year_re;
    m2="(0[1-9]|1[012])";
    m1=d1="[1-9]";
    d2="([012][0-9]|3[01])";
    s="[-_. /]0*";
    m1or2 = "(" m1 "|" m2 ")";
    d1or2 = "(" d1 "|" d2 ")";
    #mword="[A-Za-z]+";
    mword=tolower("("g_months_short"|"g_months_long")");

    d = m = y = 0;
    if  (match(line,y4 s m1or2 s d1or2)) {

        y=1 ; m = 2 ; d=3;

    } else if(match(line,m1or2 s d1or2 s y4)) { #us match before plain eu match

        m=1 ; d = 2 ; y=3;

    } else if(match(line,d1or2 s m1or2 s y4)) { #eu

        d=1 ; m = 2 ; y=3;

    } else if(match(line,d1or2 s mword s y4)) { 

        d=1 ; m = 2 ; y=3;
        textMonth = 1;

    } else if(match(line,mword s d1or2 s y4)) {
        m=1 ; d = 2 ; y=3;
        textMonth = 1;

    } else {

        return 0;
    }
    datePart = substr(line,RSTART,RLENGTH);

    nonDate[1]=substr(line,1,RSTART-1);
    nonDate[2]=substr(line,RSTART+RLENGTH);

    split(datePart,date,s);
    #DEBUG("Date1 ["date[1]"/"date[2]"/"date[3]"] in "line);
    d = date[d];
    m = date[m];
    y = date[y];

    date[1]=y;
    date[2]=tolower(trim(m));
    date[3]=d;
    #DEBUG("Date2 ["date[1]"/"date[2]"/"date[3]"] in "line);

    if ( textMonth == 1 ) {
        DEBUG("date[2]="date[2]);
        if (date[2] in gMonthConvert ) {
            date[2] = gMonthConvert[date[2]];
            DEBUG(m"="date[2]);
        } else {
            return 0;
        }
    }
    #DEBUG("Date3 ["date[1]"/"date[2]"/"date[3]"] in "line);
    date[1] += 0;
    date[2] = 0 + date[2];
    date[3] += 0;
    DEBUG("Found ["date[1]"/"date[2]"/"date[3]"] in "line);
    return 1;
}

function extractEpisodeByDates(plugin,line,details,\
date,nonDate,title,rest,y,m,d,tvdbid,result,closeTitles,tmpIdx) {

    result=0;
    #id1("extractEpisodeByDates "plugin" "line);
    if (extractDate(line,date,nonDate)) {
        rest=nonDate[2];

        details[TITLE]= title = clean_title(nonDate[1]);

        y = date[1];
        m = date[2];
        d = date[3];

        #search for matching shownames and pick the one that has an episode for the given date.
        possible_tv_titles(plugin,title,closeTitles);

        DEBUG("Checking the following series for "title" "y"/"m"/"d);
        dump(0,"date check",closeTitles);

        for (tvdbid in closeTitles) {

            id1("Checking "tvdbid);

            # This is nasty. We have to reuse some of the functions to get series and episode info.
            # These write deirectly into gloabal arrays. So we have to use a 'made up' item index.
            #
            # The real fix is to change the functions to write into a single local multi-dimension array
            # details["IMDB"] = tt0000
            # details["SEASON"= = 4 etc

            # and the output of this array is copied into the global arrays only if it is needed later
            # otherwise it is discarded.

            # However to minimise code changes at present we will use index 'TMP'count. 
            # and make sure the main program ignores such index - I need a shower...

            tmpIdx = g_tmp_idx_prefix (++g_tmp_idx_count);
            if (get_tv_series_info(plugin,tmpIdx,get_tv_series_api_url(plugin,tvdbid)) > 0) {

                if (plugin == "THETVDB" ) {

                    #TODO We could get all the series info - this would be cached anyway.
                    result = extractEpisodeByDates_TvDb(tmpIdx,tvdbid,y,m,d,details);

                } else if (plugin == "TVRAGE" ) {

                    result = extractEpisodeByDates_rage(tmpIdx,tvdbid,y,m,d,details);

                } else {
                    plugin_error(plugin);
                }
                if (result) {
                    INF(":) Found episode of "closeTitles[tvdbid]" on "y"-"m"-"d);
                    details[TVID]=tvdbid;
                    id0(result);
                    break;
                }
            }
            id0(result);
        }
        if (result == 0) {
            INF(":( Couldnt find episode "y"/"m"/"d" - using file information");
            details[SEASON]=y;
            details[EPISODE]=sprintf("%02d%02d",m,d);
            sub(/\....$/,"",rest);
            details[ADDITIONAL_INF]=clean_title(rest);
        }
    }
    #id0(result);
    return 0+ result;
}

# If a line looks like show.name.2009-06-16 then look for episode by date. It requires that
# show.name results in good unique match at thetvdb.com. otherwise the show.name is left 
# unchanged and the episode number is set to mmdd
function extractEpisodeByDates_TvDb(idx,tvdbid,y,m,d,details,\
episodeInfo,url) {

    
    url=g_thetvdb_web"/api/GetEpisodeByAirDate.php?apikey="g_api_tvdb"&seriesid="tvdbid"&airdate="y"-"m"-"d;
    fetchXML(url,"epbydate",episodeInfo);

    if ( "/Data/Error" in episodeInfo ) {
        ERR(episodeInfo["/Data/Error"]);
        tvdbid="";
    }
    if (tvdbid != "") {
        dump(0,"ep by date",episodeInfo);

        gAirDate[idx]=formatDate(episodeInfo["/Data/Episode/FirstAired"]);
        details[SEASON]=episodeInfo["/Data/Episode/SeasonNumber"];
        details[EPISODE]=episodeInfo["/Data/Episode/EpisodeNumber"];
        details[ADDITIONAL_INF]=episodeInfo["/Data/Episode/EpisodeName"];
        #TODO We can cache the above url for later use instead of fetching episode explicitly.
        # Setting this will help short circuit searching later.
        equate_urls(url,g_thetvdb_web"/api/"g_api_tvdb"/series/"tvdbid"/default/"details[SEASON]"/"details[EPISODE]"/en.xml");
        #g_imdb[idx]=get_tv_series_api_url(tvdbid);
        #DEBUG("Season "details[SEASON]" episode "details[EPISODE]" external source "g_imdb[idx]);
        #dump(0,"epinfo",episodeInfo);
        return 1;
    }
    return 0;
}
function extractEpisodeByDates_rage(idx,tvdbid,y,m,d,details,\
episodeInfo,match_date,result,filter) {

    result=0;
    match_date=sprintf("%4d-%02d-%02d",y,m,d);


    filter["/Show/Episodelist/Season/episode/airdate"] = match_date;
    if (fetch_xml_single_child(get_tv_series_api_url("TVRAGE",tvdbid),"bydate","/Show/Episodelist/Season/episode",filter,episodeInfo)) {
        gAirDate[idx]=formatDate(match_date);
        details[SEASON] = episodeInfo["/Show/Episodelist/Season#no"] ;
        details[EPISODE] = episodeInfo["/Show/Episodelist/Season/episode/seasonnum"] ;

        #details[SEASON]=episodeInfo["/Show/Episodelist/Season/episode/seasonnum"];
        #details[EPISODE]=episodeInfo["/Show/Episodelist/Season/episode/epnum"];
        details[ADDITIONAL_INF]=episodeInfo["/Show/Episodelist/Season/episode/title"];
        result=1;
    }
    return 0+ result;
}

function remove_season(t) {
    sub(/(S|Series *|Season *)[0-9]+.*/,"",t);
    return clean_title(t);
}

function episodeExtract(line,prefixReLen,prefixRe,seasonRe,episodeRe,details,\
rtext,rstart,count,i,ret) {

    #To detect work boundaries remove _ - this may affect Lukio_. Only TV show with an underscore in IMDB
    if (index(line,"_")) gsub(/_/," ",line);

    #id1("episodeExtract:["prefixRe "] [" seasonRe "] [" episodeRe"]");
    #DEBUG("episodeExtract:["prefixRe "] [" seasonRe "] [" episodeRe"]");
    count = 0+get_regex_pos(line,prefixRe seasonRe episodeRe "\\>",0,rtext,rstart);
    #dump(0,"rtext",rtext);
    #dump(0,"rstart",rstart);
    #INF("count="count);
    for(i = 1 ; i+0 <= count ; i++ ) {
        if ((ret = extractEpisodeByPatternSingle(line,prefixReLen,seasonRe,episodeRe,rstart[i],rtext[i],details)) != 0) {
            INF("episodeExtract:["prefixRe "] [" seasonRe "] [" episodeRe"]");
            break;
        }
    }
    #id0(ret);
    return 0+ret;
}

#This would be easier using sed submatches.
#More complex approach will fail on backtracking
function extractEpisodeByPatternSingle(line,prefixReLen,seasonRe,episodeRe,reg_pos,reg_match,details,\
tmpTitle,ret,reg_len,ep,season,title,inf) {

    ret = 0;
    id1("extractEpisodeByPatternSingle:"reg_match);

    delete details;

    if (reg_match ~ "([XxHh.]?264|1080)$" ) {

        DEBUG("ignoring ["reg_match"]");

    } else {


        reg_pos += prefixReLen;
        reg_len = length(reg_match)-prefixReLen;

        DEBUG("ExtractEpisode:0 Title= ["line"]");
        title = substr(line,1,reg_pos-1);
        DEBUG("ExtractEpisode:1 Title= ["title"]");

        inf=substr(line,reg_pos+reg_len);

        if (match(inf,gExtRegExAll) ) {
            details[EXT]=inf;
            gsub(/\.[^.]*$/,"",inf);
            details[EXT]=substr(details[EXT],length(inf)+2);
        }

        inf=clean_title(inf,2);

        line=substr(reg_match,prefixReLen+1); # season episode

        if (match(title,": *")) {
            title = substr(title,RSTART+RLENGTH);
        }
        DEBUG("ExtractEpisode:2 Title= ["title"]");
        #Remove release group info
        if (match(title,"^[a-z][a-z0-9]+[-]")) {
           tmpTitle=substr(title,RSTART+RLENGTH);
           if (tmpTitle != "" ) {
               INF("Removed group was ["title"] now ["tmpTitle"]");
               title=tmpTitle;
           }
        }

        DEBUG("ExtractEpisode: Title= ["title"]");
        title = clean_title(title,2);
        
        DEBUG("ExtractEpisode: Title= ["title"]");


        #Reject this could be 64(x264) or 80(hd1080)

        if (episodeRe == "") {
            ep="0";
            season = line;
        } else {
            #Match the episode first to handle 3453 and 456
            match(line,episodeRe "$" );
            ep = substr(line,RSTART,RLENGTH); 
            if (seasonRe == "") {
                season = 1; #mini-series without season qualifier
            } else {
                season = substr(line,1,RSTART-1);
            }
        }

        if (season - 50 > 0 ) {

            DEBUG("Reject season > 50");

        } else if (ep - 52 > 0 ) {

            DEBUG("Reject episode > 52 : expect date format ");

        } else {

            #BigBrother episodes with trailing character.
            gsub(/[^0-9]+/,",",ep); #
            DEBUG("Episode : "ep);
            gsub(/\<0+/,"",ep);
            gsub(/,,+/,",",ep);
            sub(/^,+/,"",ep);

            details[EPISODE] = ep;
            details[SEASON] = n(season);
            details[TITLE] = title;
            details[ADDITIONAL_INF]=inf;
            ret=1;
        }
    }

    #Return results
    if (ret != 1 ) delete details;
    id0(ret);
    return ret;
}

############### GET IMDB URL FROM NFO ########################################
function setImplicitNfo(idx,path,\
ret) {

    if (isDvdDir(path)) path = substr(path,1,length(path)-1);

    if (g_fldrMediaCount[path]+0 <= 1 ) { # if 1 or less media files (could be 0 for nfo inside a dvd structure)
       
        if ( g_fldrInfoCount[path] == 1 ) { # if only one nfo file in this folder
           
           if( is_file(g_fldrInfoName[path])) {

               DEBUG("Using single nfo "g_fldrInfoName[path]);

               gNfoDefault[idx] = g_fldrInfoName[path];

               ret = 1;
           }
       }
   }
   return ret;
}

function identify_and_catalog_scanned_files(\
idx,file,fldr,bestUrl,scanNfo,thisTime,numFiles,eta,\
ready_to_merge,ready_to_merge_count,scanned,tv_status,p,plugin,total,more_info,search_abbreviations,\
tvid,tvDbSeriesPage) {

    numFiles=hash_size(g_media);

    INF("Processing "numFiles" items");

    eta="";
   
    for ( idx = 0 ; idx - numFiles < 0 ; idx++ ) {

#dep#        begin_search("");


        bestUrl="";

        scanNfo=0;

        file=g_media[idx];
        fldr=g_fldr[idx];

        if (file == "" ) continue;

        if (NEWSCAN==1 && in_db(fldr"/"file)) {
            continue;
        }

        DIV0("Start item "(g_item_count)": ["file"]");

        report_status("item "(++g_item_count));

        DEBUG("folder :["fldr"]");

        if (isDvdDir(file) == 0 && !match(file,gExtRegExAll)) {
            WARNING("Skipping unknown file ["file"]");
            continue;
        }

        thisTime = systime();


        if (g_settings["catalog_nfo_read"] != "no") {

            if (is_file(gNfoDefault[idx])) {

               DEBUG("Using default info to find url");
               scanNfo = 1;

            # Look at other files in the same folder.
            } else if  (setImplicitNfo(idx,fldr) ) {
                scanNfo = 1;

            # Look inside movie_structire
            } else if ( isDvdDir(file) && setImplicitNfo(idx,fldr"/"file) ) {
                scanNfo = 1;
           }
        }

        if (scanNfo){
           bestUrl = scanNfoForImdbLink(gNfoDefault[idx]);
        }

        # This bit needs review.
        # Esp if we have an IMDB - use that to determine category first.
        #This will help for TV shows that have odd formatting.

        scanned = 0;
        tv_status = 0; #0=nothing 1=found series only 2=found episode also

        for (p in g_tv_plugin_list) {
            plugin = g_tv_plugin_list[p];

            # checkTvFilenameFormat also uses the plugin to detect daily formats.
            # so if ellen.2009.03.13 is rejected at tvdb it is still passed by tvrage.
            DIV("checkTvFilenameFormat "plugin);
            g_tvid_plugin[idx] = g_tvid[idx]="";

            if (checkTvFilenameFormat(plugin,idx,more_info)) {
                search_abbreviations = more_info[1];

                if (UPDATE_TV)  {
                    #g_imdb[idx] may have been set by a date lookup
                    if (bestUrl == "" && g_imdb[idx] != "" ) {
                        bestUrl = extractImdbLink(g_imdb[idx]);
                    }
                    tv_status = tv_search(plugin,idx,bestUrl,search_abbreviations);
                    scanned= (tv_status != 0);
                    #if (tv_status == 0 || g_episode[idx] !~ "^[0-9]+$" ) 
                    if (g_episode[idx] !~ "^[0-9]+$" ) {
                        #no point in trying other tv plugins
                        break;
                    }
                    if (tv_status == 2 ) break;
                }
            }
        }
        DEBUG("premovie tv_status "tv_status);
        if (tv_status == 0 && UPDATE_MOVIES) {
            g_tvid_plugin[idx] = g_tvid[idx]="";

            #More yuckiness. Sometimes the movie search does a better job of finding unidentified 
            # tv shows. If so we go back and do a tv scrape.

            #0 = not found 1=movie 2=tv?
            if (movie_search(idx,bestUrl) == 2) {
                # Looks like tv show after all?
                if (UPDATE_TV) {
                    INF("Going back to TV search");
                    for (p in g_tv_plugin_list) {
                        plugin = g_tv_plugin_list[p];
                        tvid = find_tvid(plugin,idx,extractImdbId(g_imdb[idx]));
                        if(tvid != "") {
                            tvDbSeriesPage = get_tv_series_api_url(plugin,tvid);
                            if (get_tv_series_info(plugin,idx,tvDbSeriesPage) != 0) {
                                break;
                            }
                        }
                    }
                }
            }

            scanned=1;
        }

        if (scanned) {

            #If poster is blank fall back to imdb
            if (g_poster[idx] == "") {
                g_poster[idx] = g_imdb_img[idx];
            }
            fixTitles(idx);

            #Only get posters if catalog is installed as part of oversight
            if (index(APPDIR,"/oversight") ) {

                if (g_poster[idx] != "" && GET_POSTERS) {
                    g_poster[idx] = download_image(POSTER,g_poster[idx],idx);
                }

                if (g_fanart[idx] != "" && GET_FANART) {
                    g_fanart[idx] = download_image(FANART,g_fanart[idx],idx);
                }
            }

            relocate_files(idx);



            if (g_opt_dry_run) {
                print "dryrun: "g_file[idx]" -> "gTitle[idx];
            }
            #Batch updates so that user sees some progress
            ready_to_merge[idx]=1;
            ready_to_merge_count++

        } else {
            INF("Skipping item "g_media[idx]);
        }

        thisTime = systime()-thisTime ;
        g_process_time += thisTime;
        g_elapsed_time = systime() - g_start_time;
        g_total ++;
        #lang_test(idx);

        DEBUG(sprintf("processed in "thisTime"s net av:%.1f gross av:%.1f" ,(g_process_time/g_total),(g_elapsed_time/g_total)));

    }
    # At the end we always make sure update_db has been called
    # at least once as this loads the database and carries out any file actions
    if (ready_to_merge_count) {
        DIV("merge");
        update_db(ready_to_merge);
    }

    clean_globals();
    return 0+total;
}

function DIV0(x) {
    INF("\n\t===\n\t"x"\n\t===\n");
}
function DIV(x) {
    INF("\t===\t"x"\t===");
}

# 0=nothing found 1=series but no episode 2=series+episode
function tv_search(plugin,idx,imdbUrl,search_abbreviations,\
tvDbSeriesPage,result,tvid) {

    result=0;

    id1("tv_search ("plugin","idx","imdbUrl","search_abbreviations")");

    #This will succedd if we already have the tvid when doing the checkTvFilenameFormat
    #checkTvFilenameFormat() may fetch the tvid while doing a date check for daily shows.
    tvDbSeriesPage = get_tv_series_api_url(plugin,g_tvid[idx]);

    if (tvDbSeriesPage == "" && imdbUrl == "" ) { 
        # do not know tvid nor imdbid - use the title to search tv indexes.
        tvDbSeriesPage = search_tv_series_names(plugin,idx,gTitle[idx],search_abbreviations);
    }

    if (tvDbSeriesPage != "" ) { 
        # We know the TV id - use this to get the imdb id
        result = get_tv_series_info(plugin,idx,tvDbSeriesPage); #this may set imdb url
        if (result) {
            if (g_imdb[idx] != "") {
                # we also know the imdb id
                scrapeIMDBTitlePage(idx,g_imdb[idx]);
            } else {
                # use the tv id to find the imdb id
                scrapeIMDBTitlePage(idx,tv2imdb(idx));
            }
        }
    } else {
        # dont know the tvid
        if (imdbUrl == "") {
            # If we get here we dont know the tvid nor imdbid and a lookup by title has also failed
            # At this stage we use the file name to search the web for an imdb url.
            # TODO This should filter out movie results.
            imdbUrl=web_search_frequent_imdb_link(idx);
        }
        if (imdbUrl != "") {
            # but do know imdbid - use the imdb id to find the tv id
            scrapeIMDBTitlePage(idx,imdbUrl);
            if (g_category[idx] != "M" ) {
                # find the tvid - this can miss if the tv plugin api does not have imdb lookup
                tvid = find_tvid(plugin,idx,extractImdbId(imdbUrl));
                tvDbSeriesPage = get_tv_series_api_url(plugin,tvid);
                result = get_tv_series_info(plugin,idx,tvDbSeriesPage);
            }
        }
    }
    
    if (g_category[idx] == "M" ) {
        WARNING("Error getting IMDB ID from tv - looks like a movie??");
        if (plugin == "TVRAGE") {
            WARNING("Please update the IMDB ID for this series at the TVRAGE website for improved scanning");
        }

        result = 0;
    }
    id0(result);
    return 0+ result;
}

#0=not found 1=movie 2=tv??
function movie_search(idx,bestUrl,\
name,i,\
n,name_seen,name_list,name_id,name_try,\
search_regex_key,search_order_key,search_order,s,search_order_size,ret,title,\
imdb_title_q,imdb_id_q,connections,remakes) {

    id1("movie search");

    # search online info using film basename looking for imdb link
    # -----------------------------------------------------------------------------
    name_id=0;


    if (gParts[idx] != "") {
        name_list[++name_id]=remove_part_suffix(idx);
    }

    name=cleanSuffix(idx);


    # Build hash of name->order
    if (match(name,g_imdb_regex)) {
        name_list[++name_id] = substr(name,RSTART,RLENGTH);
    }
    if (match(name,g_imdb_title_re))  {
        name_list[++name_id] = substr(name,RSTART,RLENGTH);
    }

    name_list[++name_id] = name;

    name_list[++name_id] = remove_format_tags(remove_brackets(basename(g_media[idx])));


    dump(0,"name_tries",name_list);


    #Read search order definitions from config file.
    for(i = 1 ; i < 5 ; i++ ) {
        search_regex_key="catalog_movie_search_regex"i;

        #Find any search order that matches the file format
        if (name ~ g_settings[search_regex_key]) {

            search_order_key="catalog_movie_search_order"i;
            if (!(search_order_key in g_settings)) {
                ERR("Missing setting "search_order_key);
            } else {
                search_order_size = split(g_settings[search_order_key],search_order," *, *");
                break;
            }
        }
        delete search_order;
    }

    dump(0,"search order",search_order);

    for( s = 1 ; bestUrl=="" && s-search_order_size <= 0 ; s++ ) { # Must do them in strict sequence

        if (search_order[s] == "IMDBLINKS") {

            #TODO Merge the web_search_frequent_imdb_link heuristics into this functions logic.
            INF("DISABLED: Search Phase: "search_order[s]);
            #id1("Search Phase: "search_order[s]);
            #bestUrl=web_search_frequent_imdb_link(idx);
            #id0(bestUrl);

        } else {

            delete name_seen;
            for(n = 1 ; bestUrl=="" && n-name_id <= 0 ; n++) {

                name_try = name_list[n];

                if (!(name_try in name_seen) && name_try != "") {

                    name_seen[name_try]=n;

                    id1("Search Phase: "search_order[s]"["name_try"]");

                    if (search_order[s] == "ONLINE_NFO") {

                        #Add a dot on the end to stop binsearch false matching sub words.
                        #eg binsearch will find "a-bcd" given "a-b" to prevent this 
                        # change a-b to "a-b."
                        #bintube will ignore the dot.
                        bestUrl = searchOnlineNfoImdbLinks(name_try".");

                    } else if (search_order[s] == "IMDB") {

                        #This is a web search of imdb site returning the first match.

                        bestUrl=web_search_first_imdb_link(name_try"+"url_encode("site:imdb.com"),name_try);

                    } else if (search_order[s] == "IMDBFIRST") {

                        if (name_try ~ "^[a-zA-Z0-9]+-[a-zA-Z0-9]+$" ) {
                            # quote hyphenated file names
                            name_try = "\""name_try"\"";
                        } else {
                            # Remove punctuation runs
                            gsub("[^()"g_alnum8" ]+"," ",name_try);
                            name_try = trim(name_try);
                        }


                        imdb_title_q=url_encode("imdb");
                        imdb_id_q = url_encode("imdb");
                        #imdb_id_q = url_encode("site:imdb.com");
                        #imdb_id_q = url_encode("+imdb")"+"url_encode("+title");

                        bestUrl=web_search_first_imdb_link(name_try"+"imdb_id_q,name_try);
                        if (bestUrl == "" ) {

                            # look for imdb style titles 
                            title = web_search_first_imdb_title(name_try,"");
                            if (title == "" ) {
                                title = web_search_first_imdb_title(name_try"+movie","");
                            }
                            if (title != "" && title != name_try) {
                                bestUrl=web_search_first_imdb_link(title"+"imdb_title_q,title);
                                if (bestUrl == "") {
                                    bestUrl=web_search_first_imdb_link(title"+"imdb_id_q,title);
                                }
                            }
                        }

                    } else {
                        ERR("Unknown search method "search_order[s]);
                    }

                    id0(bestUrl);
                }
            }
        }
    }

    # Finished Search. Scrape IMDB
    ret=0;
    if (bestUrl != "") {

        scrapeIMDBTitlePage(idx,bestUrl);
        # fallback to tv search doesnt make sense here - we have no season / episode info
        if (g_category[idx] == "T" ) {
            WARNING("Unidentifed TV show ???");
            ret=2;
        } else {
            ret=1;
            getNiceMoviePosters(idx,extractImdbId(bestUrl));
            getMovieConnections(extractImdbId(bestUrl),connections);
            if (connections["Remake of"] != "") {
                getMovieConnections(connections["Remake of"],remakes);
            }
            g_conn_follows[idx]= connections["Follows"];
            g_conn_followed_by[idx]= connections["Followed by"];
            g_conn_remakes[idx]=remakes["Remade as"];
            INF("follows="g_conn_follows[idx]);
            INF("followed_by="g_conn_followed_by[idx]);
            INF("remakes="g_conn_remakes[idx]);
        }

    } 
    id0(bestUrl);
    return ret;
}

function tv2imdb(idx,\
terms,key) {

    if (g_imdb[idx] == "") {
    
        key=gTitle[idx]"+"g_year[idx];
        DEBUG("tv2imdb key=["key"]");
        if (!(key in g_tv2imdb)) {

            # Search for imdb page  - try to filter out Episode pages.
            #terms=gTitle[idx]" "g_year[idx]" +site:imdb.com \"TV Series\" \"User Rating\" Moviemeter Seasons ";
        
            g_tv2imdb[key] = web_search_first_imdb_link(terms" +site:imdb.com \"TV Series\" Overview -\"Episode Cast\"",terms); 
        }
        g_imdb[idx] = g_tv2imdb[key];
    }
    DEBUG("tv2imdb end=["g_imdb[idx]"]");
    return extractImdbLink(g_imdb[idx]);
}

# This is a temporary measure. The long term goal is to get
# scanner to write all info to a new file then merge this file
# with the main index.db. Then the following arrays should 
# become scalar.
# Its messy because the scanner started out as a single file
# incremental scanner. so everything was loaded into memory for speed
# however this is bad when doing the initial scan of a NAS etc.
function clean_globals() {
    delete g_media;
    delete g_scraped;
    delete g_imdb_title;
    delete g_motech_title;
    delete gNfoDefault;
    delete g_fldrMediaCount;
    delete g_fldrInfoCount;
    delete g_fldrInfoName;
    delete g_fldrCount;
    delete g_fldr;
    delete gParts;
    delete gMultiPartTagPos;
    delete gCertRating;
    delete gCertCountry;
    delete g_director;
    delete g_writers;
    delete g_actors;
    delete g_poster;
    delete g_genre;
    delete g_runtime;
    delete gProdCode;
    delete gTitle;
    delete gOriginalTitle;
    delete gAdditionalInfo;
    delete g_tvid_plugin;
    delete g_tvid;
    delete g_imdb_img;
    delete g_file;
    delete g_file_time;
    delete g_episode;
    delete g_seasion;
    delete g_imdb;
    delete g_year;
    delete g_premier;
    delete gAirDate;
    delete gTvCom;
    delete gEpTitle;
    delete g_epplot;
    delete g_plot;
    delete g_fanart;
    delete gCertRating;
    delete g_rating;
    delete g_category;
    delete gDate;
    delete g_title_rank;
    delete g_title_source;
    delete g_conn_follows;
    delete g_conn_followed_by;
    delete g_conn_remakes;

    gMovieFileCount = 0;
    INF("Reset scanned files store");
}

function cleanSuffix(idx,\
name) {
    name=g_media[idx];
    if(name !~ "/$") {
        # remove extension
        sub(/\.[^.\/]+$/,"",name);
        # name=remove_format_tags(name);

        # no point in removing the CD parts as this makes binsearch more inaccurate

        #    if (gParts[idx] != "" ) {
        #        #remove  part qualifier xxxx1 or xxxxxa
        #        sub(/(|cd|part)[1a]$/,"",name);
        #    }
    }
    name=trimAll(name);
    return name;
}

#Alternate between various nfo search engines. 
#These engines should take a file name as input and return a page with links to nfo files.
#The resultant links are scraped for imdb ids.
# Not newzleech not used as the search is too vague. bintube and binsearch have exact search.
function searchOnlineNfoImdbLinks(name,\
url) {
    url=searchOnlineNfoImdbLinksFilter(name,"",150);
    if (url == "") {
        url=searchOnlineNfoImdbLinksFilter(name,"+nfo","");
    }
    return url;
}

function searchOnlineNfoImdbLinksFilter(name,additionalKeywords,minSize,\
choice,i,url) {
    g_nfo_search_choices =1;

    for(i = 0 ; i - g_nfo_search_choices < 0 ; i++ ) {

        g_nfo_search_engine_sequence++;
        choice = g_nfo_search_engine_sequence % g_nfo_search_choices ;

        #choice = 2; g_nfo_search_choices=1; # Uncomment and set choice = n to test particular engine

        if (choice == 0 ) {

#            # Film - search bintube for nfos
#            url = searchOnlineNfoLinksForImdb(name,\
#                "http://www.bintube.com",\
#                "/?b="minSize"&q=\"QUERY\"" additionalKeywords,\
#                "/nfo/pid/[^\"]+",20,"nfo/","nfo/display/text/");
#
#        } else if (choice == 1 ) {

            # search binsearch.info 
            url = searchOnlineNfoLinksForImdb(name,\
                "https://www.binsearch.info",\
                "/index.php?q=\"QUERY\""additionalKeywords"&minsize="minSize"&max=20&adv_age=999&adv_sort=date&adv_nfo=on&postdate=on&hideposter=on&hidegroup=on",\
                "/viewNFO[^\"]+",20,"","");

# ngindex search not accurate enough
#        } else {
#
#            # search ngindex - order by score so only look at top 5
#            url = searchOnlineNfoLinksForImdb(name,\
#                "http://www.ngindex.com",\
#                "/nfos.php?method=and&type=2&sort=score&matchesperpage=50&archive=all&FT=4&words=QUERY",\
#                "/setinfo.php[^\"']+",5);
        }
        if (url != "") {
            break;
        }
    }
    return url;
}

# Search a web page <domain><query path=><keywords> for a given file name.
# Then extract all of the links to nfo pages in the results and search again 
# for imdb links , keeping a tally as we go.
# example
# searchOnlineNfoLinksForImdb(idx,"http://www.bintube.com","/?q=","/nfo/pid/[0-9a-f]+") 
function searchOnlineNfoLinksForImdb(name,domain,queryPath,nfoPathRegex,maxNfosToScan,inurlFind,inurlReplace,
nfo,nfo2,nfoPaths,imdbIds,totalImdbIds,wgetWorksWithMultipleUrlRedirects,id,count,result) {


    if (length(name) <= 4 || name !~ "^[-.a-zA-Z0-9]+$" ) {
        INF("onlinenfo: ["name"] ignored");
    } else {

        id1("Online nfo search for ["name"]");

        sub(/QUERY/,name,queryPath);
        INF("query["queryPath"]");

        #Get all nfo links
        scan_page_for_match_counts(domain queryPath,"",nfoPathRegex,maxNfosToScan,1,"",nfoPaths);

        #Scan each link for imdb matches and tally

        #Note wget has a bug when using -O flag. Only one file is redirected.
        wgetWorksWithMultipleUrlRedirects=0;
    #    if (wgetWorksWithMultipleUrlRedirects) {
    #        nfo2="";
    #        for(nfo in nfoPaths) {
    #            nfo2 = nfo2 "\t" domain nfo;
    #            if (inurlFind != "") {
    #                sub(inurlFind,inurlReplace,nfo2);
    #            }
    #        }
    #        sub(/[&]amp;/,"\\&",nfo2);
    #        if (scan_page_for_match_counts(nfo2, g_imdb_regex ,0,1,"", imdbIds) == 0) {
    #            scanPageForIMDBviaLinksInNfo(nfo2,imdbIds);
    #        }
    #        for(id in imdbIds) {
    #            totalImdbIds[id] += imdbIds[id];
    #        }
    #    } else {
            for(nfo in nfoPaths) {
                nfo2 = domain nfo;
                if (inurlFind != "") {
                    sub(inurlFind,inurlReplace,nfo2);
                }
                sub(/[&]amp;/,"\\&",nfo2);

                if (scan_page_for_match_counts(nfo2,"tt", g_imdb_regex ,0,1,"", imdbIds) == 0) {
                    scanPageForIMDBviaLinksInNfo(nfo2,imdbIds);
                }

                for(id in imdbIds) {
                    totalImdbIds[id] += imdbIds[id];
                }
            }
    #    }

        if (hash_size(totalImdbIds) > 3 ) {
            INF("Too many nfo results from online search");
        } else {

            #return most frequent match
            bestScores(totalImdbIds,totalImdbIds,0);
            count = hash_size(totalImdbIds);
            if (count == 1) {

                result = extractImdbLink(firstIndex(totalImdbIds));

            } else if (count == 0) {

                INF("No matches");

            } else {

                INF("To many equal matches. Discarding results");
            }
        }
        id0(result);
    }
    return result;
}

# Search for imdb ids in any pages referenced by the nfo file.
# This is really for amazon links in nfo files but might work for some other sites.
function scanPageForIMDBviaLinksInNfo(url,imdbIds,\
amzurl,amazon_urls,imdb_per_page,imdb_id) {
    if (scan_page_for_match_counts(url, "amazon","http://(www.|)amazon[ !#-;=?-~]+",0,1,"",amazon_urls)) {
        for(amzurl in amazon_urls) {
            if (scan_page_for_match_counts(amzurl, "/tt", g_imdb_regex ,0,1,"", imdb_per_page)) {
                for(imdb_id in imdb_per_page) {
                    INF("Found "imdb_id" via amazon link");
                    imdbIds[imdb_id] += imdb_per_page[imdb_id];
                }
            }
        }
    }
}


function firstIndex(inHash,\
i) {
    for (i in inHash) return i;
}

function firstDatum(inHash,\
i) {
    for (i in inHash) return inHash[i];
}

#Find all the entries that share the highest score.
#using a tmp array allows same array to be used for in and out
function bestScores(inHash,outHash,textMode,\
i,bestScore,count,tmp,isHigher) {
    
    #dump(1,"pre best",inHash);
    count = 0;
    for(i in inHash) {
        if (textMode) {
            isHigher= ""inHash[i] > ""bestScore; #ie 2>11 OR 2009-10 > 2009-09
        } else {
            isHigher= 0+inHash[i] > 0+bestScore;
        }
        if (bestScore=="" || isHigher) {
            delete tmp;
            tmp[i]=bestScore=inHash[i];
        } else if (inHash[i] == bestScore) {
            tmp[i]=inHash[i];
        }
    }
    #copy outHash
    delete outHash;
    for(i in tmp) {
        outHash[i] = tmp[i];
        count++;
    }
    dump(0,"post best",outHash);
    INF("bestScore = "bestScore);
    return bestScore;
}

#returns imdb url
function scanNfoForImdbLink(nfoFile,\
foundId,line) {

    foundId="";
    INF("scanNfoForImdbLink ["nfoFile"]");

    if (system("test -f "qa(nfoFile)) == 0) {
        FS="\n";
        while(foundId=="" && (getline line < nfoFile) > 0 ) {

            foundId = extractImdbLink(line,1);

        }
        close(nfoFile);
    }
    INF("scanNfoForImdbLink = ["foundId"]");
    return foundId;
}

############### GET IMDB PAGE FROM URL ########################################

function search_tv_series_names(plugin,idx,title,search_abbreviations,\
tnum,t,i,url) {

    tnum = alternate_titles(title,t);

    for(i = 0 ; i-tnum < 0 ; i++ ) {
        url = search_tv_series_names2(plugin,idx,t[i],search_abbreviations);
        if (url != "") break;
    } 
    return url;
}

function search_tv_series_names2(plugin,idx,title,search_abbreviations,\
tvDbSeriesPage,alternateTitles,title_key,cache_key,showIds,tvdbid) {

    title_key = plugin"/"g_fldr[idx]"/"title;
    id1("search_tv_series_names "title_key);

    if (title_key in g_tvDbIndex) {
        DEBUG(plugin" use previous mapping "title_key" -> ["g_tvDbIndex[title_key]"]");
        tvDbSeriesPage =  g_tvDbIndex[title_key]; 
    } else {

        tvDbSeriesPage = searchTvDbTitles(plugin,idx,title);

        DEBUG("search_tv_series_names: bytitles="tvDbSeriesPage);
        if (tvDbSeriesPage) {

            # do nothing

        } else if ( search_abbreviations ) {

            # Abbreviation search

            cache_key=g_fldr[idx]"@"title;

            if(cache_key in g_abbrev_cache) {

                tvDbSeriesPage = g_abbrev_cache[cache_key];
                INF("Fetched abbreviation "cache_key" = "tvDbSeriesPage);

            } else {

                searchAbbreviationAgainstTitles(title,alternateTitles);

                filterTitlesByTvDbPresence(plugin,alternateTitles,showIds);
                if (hash_size(showIds)+0 > 1) {

                    filterUsenetTitles(showIds,cleanSuffix(idx),showIds);
                }

                tvdbid = selectBestOfBestTitle(plugin,idx,showIds);

                tvDbSeriesPage=get_tv_series_api_url(plugin,tvdbid);

                if (tvDbSeriesPage) {
                    g_abbrev_cache[cache_key] = tvDbSeriesPage;
                    INF("Caching abbreviation "cache_key" = "tvDbSeriesPage);
                }
            }
        }

        if (tvDbSeriesPage == "" ) {
            WARNING("search_tv_series_names could not find series page");
        } else {
            DEBUG("search_tv_series_names Search looking at "tvDbSeriesPage);
            g_tvDbIndex[title_key] = tvDbSeriesPage;
        }
    }
    id0(tvDbSeriesPage);

    return tvDbSeriesPage;
}

# Search the epguides menus for names that could be represented by the abbreviation 
# IN abbrev - abbreviated name eg ttscc
# OUT alternateTitles - hash of matching names eg {Terminator The Sarah Conor Chronicles,...} indexed by title.
function searchAbbreviationAgainstTitles(abbrev,alternateTitles,\
initial) {

    delete alternateTitles;

    INF("Search Phase: epguid abbreviations");

    initial = epguideInitial(abbrev);
    searchAbbreviation(initial,abbrev,alternateTitles);

    #if the abbreviation begins with t it may stand for "the" so we need to 
    #check the index against the next letter. eg The Ultimate Fighter - tuf on the u page!
    if (initial == "t" ) {
        initial = epguideInitial(substr(abbrev,2));
        if (initial != "t" ) {
            searchAbbreviation(initial,abbrev,alternateTitles);
        }
    }
    dump(0,"abbrev["abbrev"]",alternateTitles);
}

function hash_copy(a1,a2) {
    delete a1 ; hash_merge(a1,a2) ;
}
function hash_merge(a1,a2,\
i) {
    for(i in a2) a1[i] = a2[i];
}
function hash_add(a1,a2,\
i) {
    for(i in a2) a1[i] += a2[i];
}
function hash_size(h,\
s,i){
    s = 0 ; 
    for(i in h) s++;
    return 0+ s;
}

function id1(x) {
    g_idstack[g_idtos++] = x;
    INF(">Begin " x);
    g_indent="\t"g_indent;
}

function id0(x) {
    g_indent=substr(g_indent,2);
    
    INF("<End "g_idstack[--g_idtos]"=[" ( (x!="") ? "=["x"]" : "") "]");
}

function possible_tv_titles(plugin,title,closeTitles,\
ret) {

    if (plugin == "THETVDB" ) {

        ret = searchTv(plugin,title,"FirstAired",closeTitles);

    } else if (plugin == "TVRAGE" ) {

        ret = searchTv(plugin,title,"started",closeTitles);

    } else {

        plugin_error(plugin);

    } 
    g_indent=substr(g_indent,2);
    dump(0,"searchTv out",closeTitles);
    return ret;

}

# Given a bunch of titles keep the ones where the filename has been posted with that title
#IN filterText - text to look for along with each title. This is usually filename w/o ext ie cleanSuffix(idx)
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
#IN filterText - text to look for along with each title. This is usually filename w/o ext ie cleanSuffix(idx)
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

# This should only be called fairly late in the selection process.
# It returns the newest item. It may not be a valid thing to do
# but if we end up having to chose between two films with no other
# information should either make a choice OR give up.
# The relative age is just a metric that can be compared between films
# eg IMDBID is a rough relative age indicator.
# For other databases we may need to get the actual air date.
# it should return array of strings (not numbers) that can be compared using < >.
# eg 2009-03-31 ok but 31-03-2009 bad.
# IN idx - index to global arrays
# IN titleHash - Indexed by imdb/tvdbid etc
# OUT ageHash - age indicator  Indexed by imdb/tvdbid etc
function getRelativeAge(plugin,idx,titleHash,ageHash,\
id,xml) {
   for(id in titleHash) {
        if (get_episode_xml(plugin,get_tv_series_api_url(plugin,id),g_season[idx],g_episode[idx],xml)) {
            if (plugin == "THETVDB") {
                ageHash[id] = xml["/Data/Episode/FirstAired"];
            } else if (plugin == "TVRAGE" ) {
                ageHash[id] = xml["/Show/Episodelist/Season/episode/airdate"];
            } else {
                plugin_error(plugin);
            }
        }
    }
    dump(1,"Age indicators",ageHash);
 }

# TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO 
# This is the function which will eventually discern between two very closely matched titles.
# Eg given conan.obrien.2009.06.24 how do we select between The Late Show with Conan OBrien or the tonight show with Conan OBrien
# It is called when there is not enough information in the titles alone to make the call.
# it will do things like the following:
# IF its a Season 5 DVDRIP then it cant match a show that doesnt have a Season 5 or one
# where season 5 is currently airing (watch out for long split season programs like LOST )
# Also vice versa if its a TV rip then its probably a show which is currently airing THAT season.
# The above rules are also dependent on time of scan so have to be careful.
# Another one, for conan obrien use thetvdb get episode by date api call to differentiate between shows.
# This is all yucky edge case stuff. And its not coded. In the mean time I will just return the first element :)
# @param plugin - thetvdb  or tvrage
# @param idx - the current item being processed
# @param titles - hash of show titles keyed by show id.
function selectBestOfBestTitle(plugin,idx,titles,\
bestId,bestFirstAired,ages,count) {
    dump(0,"closely matched titles",titles);
    count=hash_size(titles);

    if (count == 0) {
        bestId = "";
    } else if (count == 1) {
        bestId = firstIndex(titles);
    } else {
        TODO("Refine selection rules here.");

        INF("Getting the most recent first aired for s"g_season[idx]"e"g_episode[idx]);
        bestFirstAired="";

        getRelativeAge(plugin,idx,titles,ages);

        bestScores(ages,ages,1);

        bestId = firstIndex(ages);
        #TODO also try to get first episode of season.
    }
    INF("Selected:"bestId" = "titles[bestId]);
    return bestId;
}

# Search tvDb for different titles and return the ones that have the highest similarity scores.
# This multiple search is used when an abbbrevation gives 2 or more possible titles.
# eg trh = The Real Hustle or The Road Home 
# We then hope we can weed out sime titles through various means starting with lack of requiredTags eg. Overview and FirstAired 
# IN titleInHash - the title we are looking for. hashed by title => any thing
# IN requiredTagList - list of tags which must be present - to filter out obscure shows noone cares about
# OUT showIdHash - hash of matching titles. hashed by showid => title
# RETURNS number of matches
function filterTitlesByTvDbPresence(plugin,titleInHash,showIdHash,\
bestScore,potentialTitle,potentialMatches,origTitles,score) {
    bestScore=-1;

    dump(0,"pre tvdb check",titleInHash);

    #Make a safe copy in case titleInHash is the same as showIdHash
    hash_copy(origTitles,titleInHash);

    delete showIdHash;

    for(potentialTitle in origTitles) {
        id1("Checking potential title "potentialTitle);
        score = possible_tv_titles(plugin,potentialTitle,potentialMatches);
        if (score - bestScore >= 0 ) {
            if (score - bestScore > 0 ) delete showIdHash;
            hash_merge(showIdHash,potentialMatches);
            bestScore = score;
        }
        id0(score);
    }

    #copy to output
    dump(0,"post filterTitle",showIdHash);
}

function remove_country(t) {
    if (match(tolower(t)," (au|uk|us)( |$)")) {
        t=substr(t,1,RSTART-1) substr(t,RSTART+RLENGTH);
    }
    return t;
}

#return array of alternate titles in array t.
function alternate_titles(title,t,\
tnum,tried,tmp) {
    # Build list of possible titles.
    tnum = 0;
    tmp = clean_title(title,1);
    tried[tmp]=1;
    t[tnum++] = tmp;

    tmp = clean_title(remove_brackets(title),1);
    if (!(tmp in tried)) {
        tried[tmp]=1;
        t[tnum++] = tmp;
    }

    tmp = clean_title(remove_country(title),1);
    if (!(tmp in tried)) {
        tried[tmp]=1;
        t[tnum++] = tmp;
    }

    tmp = clean_title(remove_country(remove_brackets(title)),1);
    if (!(tmp in tried)) {
        tried[tmp]=1;
        t[tnum++] = tmp;
    }

    dump(0,"alternate_titles",t);

    return tnum+0;

}

# Search tvDb and return titles hashed by seriesId
# Series are only considered if they have the tags listed in requiredTags
# IN title - the title we are looking for.
# OUT closeTitles - matching titles hashed by tvdbid. 
# IN requiredTagList - list of tags which must be present - to filter out obscure shows noone cares about
# RETURNS Similarity Score - eg Office UK vs Office UK is a fully qualifed match high score.
# This wrapper function will search with or without the country code.
function searchTv(plugin,title,requiredTagList,closeTitles,\
requiredTagNames,allTitles,url,ret) {

    id1("searchTv Checking ["plugin"/"title"]" );
    split(requiredTagList,requiredTagNames,",");
    delete closeTitles;

    if (plugin == "THETVDB") {

        url=expand_url(g_thetvdb_web"//api/GetSeries.php?seriesname=",title);
        filter_search_results(url,title,"/Data/Series","SeriesName","seriesid",requiredTagNames,allTitles);

    } else if (plugin == "TVRAGE") {

        url=g_tvrage_web"/feeds/search.php?show="title;
        filter_search_results(url,title,"/Results/show","name","showid",requiredTagNames,allTitles);

    } else {
        plugin_error(plugin);
    }

    ret = filterSimilarTitles(title,allTitles,closeTitles);
    id0(ret);
    return 0+ret;
}

#If the search engine differentiates between &/and or obrien o brien then we need multiple searches.
# 
function expand_url(baseurl,title,\
url) {
    url = baseurl title;
    if (match(title," [Aa]nd ")) {
        #try "a and b\ta & b"
        url=url"\t"url;
        sub(/ [Aa]nd /," %26 ",url); 
        #sub(/ [Aa]nd /," \\& ",url); 
    }
    if (match(title," O ")) {
        #try "Mr O Connor\tMr OConnor"
        url=url"\t"url;
        sub(/ O /," O",url); 
    }
    return url;
}

# Search tvDb and return titles hashed by seriesId
# Series are only considered if they have the tags listed in requiredTags
# IN title - the title we are looking for.
# OUT closeTitles - matching titles hashed by tvdbid. 
# IN requiredTagNames - array of tags which must be present - to filter out obscure shows noone cares about
function filter_search_results(url,title,seriesPath,nameTag,idTag,requiredTagNames,allTitles,\
f,line,info,currentId,currentName,add,i,seriesTag,seriesStart,seriesEnd,count,filter_count) {

    f = getUrl(url,"tvdb_search",1);
    count = 0;
    filter_count = 0;

    if (f != "") {
        seriesTag = seriesPath;
        sub(/.*\//,"",seriesTag);
        seriesStart="<"seriesTag">";
        seriesEnd="</"seriesTag">";
        FS="\n";
        while(enc_getline(f,line) > 0 ) {

            #DEBUG("IN:"line[1]);

            if (index(line[1],seriesStart) > 0) {
                clean_xml_path(seriesPath,info);
            }

            parseXML(line[1],info);

            if (index(line[1],seriesEnd) > 0) {

#dump(0,"@@filter_search_results@@",info);

                currentName = clean_title(info[seriesPath"/"nameTag]);

                currentId = info[seriesPath"/"idTag];
                count ++;

                add=1;
#                for( i in requiredTagNames ) {
#                    if (! ( seriesPath"/"requiredTagNames[i] in info ) ) {
#                        dump(0,"info",info);
#                        DEBUG("["currentName"] rejected due to missing "requiredTagNames[i]" tag");
#                        add=0;
#                        filter_count++;
#                        break;
#                    }
#                }

                if (add) {
                    allTitles[currentId] = currentName;
                }
                clean_xml_path(seriesPath,info);

            }
        }
        enc_close(f);
    }
    dump(0,"search["title"]",allTitles);
    #filterSimilarTitles is called by the calling function
    INF("Search results : Found "count" removed "filter_count);
}

function dump(lvl,label,array,\
i,c) {
    if (DBG-lvl >= 0)   {
        for(i in array) {
            DEBUG(" "label":"i"=["array[i]"]");
            c++;
        }
        if (c == 0 ) {
            DEBUG("  "label":<empty>");
        }
    }
}

#ALL# function scan_tv_via_search_engine(regex,keywords,premier_mdy,year,\
#ALL# url,id2) {
#ALL#     
#ALL#     if (premier_mdy != "") {
#ALL#         url=keywords " " premier_mdy;
#ALL#         id2 = scanPageFirstMatch(g_search_bing" "keywords " \"" premier_mdy"\"","",regex,0);
#ALL#     }
#ALL# #    if (id2 == "" ) {
#ALL# #        id2 = scanPageFirstMatch(g_search_bing" "keywords " "year ,"",regex,0);
#ALL# #    }
#ALL#     return id2;
#ALL# }

# IN imdb id tt0000000
# RETURN tvdb id
function find_tvid(plugin,idx,imdbid,\
url,id2,premier_mdy,date,nondate,regex,key,filter,showInfo,year_range) {
    # If site does not have IMDB ids then use the title and premier date to search via web search
    if (imdbid) {

        key = plugin"/"imdbid;
        if (key in g_imdb2tv) {

            id2 = g_imdb2tv[key];

        } else {

            # First try API search or direct imdb search 
            if(plugin == "THETVDB") {
                regex="[&?;]id=[0-9]+";
                #first try api search
                url = g_thetvdb_web"/index.php?imdb_id="imdbid"&order=translation&searching=Search&tab=advancedsearch";
                id2 = scanPageFirstMatch(url,"",regex,0);
                if (id2 != "" ) {
                    id2=substr(id2,5);
                }
            }

            if (id2 == "" ) {

                # search for series name directly using raw(ish) imdb name
                extractDate(g_premier[idx],date,nondate);
                # We do a fuzzy year search esp for programs that have a pilot in the
                # year before episode 1
                #
                # This may cause a false match if two series with exactly the same name
                # started within two years of one another.
                year_range="("(g_year[idx]-1)"|"g_year[idx]"|"(g_year[idx]+1)")";

                if(plugin == "THETVDB") {

                    #allow for titles "The Office (US)" or "The Office" and 
                    # hope the start year is enough to differentiate.
                    filter["/Data/Series/SeriesName"] = "~:^"gTitle[idx]"(| \\([a-z0-9]\\))$";
                    filter["/Data/Series/FirstAired"] = "~:^"year_range"-";

                    url=expand_url(g_thetvdb_web"//api/GetSeries.php?seriesname=",gTitle[idx]);
                    if (fetch_xml_single_child(url,"imdb2tvdb","/Data/Series",filter,showInfo)) {
                        INF("Looking at tvdb "showInfo["/Data/Series/SeriesName"]);
                        id2 = showInfo["/Data/Series/seriesid"];
                    }

#                    regex="[&?;]id=[0-9]+";
#
#                    if (1 in date) premier_mdy=sprintf("\"%s %d, %d\"",g_month_en[0+date[2]],date[3],date[1]);
#
#                    id2 = scan_tv_via_search_engine(regex,gTitle[idx]" site:thetvdb.com intitle:\"Series Info\" ",premier_mdy,g_year[idx]);
#                    if (id2 != "" ) {
#                        id2=substr(id2,5);
#                    }

                } else if(plugin == "TVRAGE") {

                    #allow for titles "The Office (US)" or "The Office" and 
                    # hope the start year is enough to differentiate.
                    filter["/Results/show/name"] = "~:^"gTitle[idx]"(| \\(a-z0-9]\\))$";
                    filter["/Results/show/started"] = "~:"year_range;
                    
                    if (fetch_xml_single_child(g_tvrage_web"/feeds/search.php?show="gTitle[idx],"imdb2rage","/Results/show",filter,showInfo)) {
                        INF("Looking at tv rage "showInfo["/Results/show/name"]);
                        id2 = showInfo["/Results/show/showid"];
                    }

                } else {
                    plugin_error(plugin);
                }
            }
            if (id2) g_imdb2tv[key] = id2;
        }

        DEBUG("imdb id "imdbid" =>  "plugin"["id2"]");
    }
    return id2;
}

function searchTvDbTitles(plugin,idx,title,\
tvdbid,tvDbSeriesUrl,imdb_id,closeTitles,noyr) {

    id1("searchTvDbTitles");
    if (g_imdb[idx]) {
        imdb_id = g_imdb[idx];
        tvdbid = find_tvid(plugin,idx,imdb_id);
    }
    if (tvdbid == "") {
        possible_tv_titles(plugin,title,closeTitles);
        tvdbid = selectBestOfBestTitle(plugin,idx,closeTitles);
    }
    if (tvdbid == "") {
        noyr  = remove_tv_year(title);
    	if(title != noyr) {
    	    INF("Try Again Without A Year If Nothing Found Thus Far");
            # the tvdb api can return better hits without the year.
            # compare e.g.
            # http://www.thetvdb.com/api/GetSeries.php?seriesname=Carnivale%202003 Bad
            # http://www.thetvdb.com/api/GetSeries.php?seriesname=Carnivale Good
            #
            # tv rage should work with the year. compare .e.g
            # http://services.tvrage.com/feeds/search.php?show=carnivale Good
            # vs http://services.tvrage.com/feeds/search.php?show=carnivale%202003 OK
    	    possible_tv_titles(plugin,noyr,closeTitles);
    	    tvdbid = selectBestOfBestTitle(plugin,idx,closeTitles);
    	}
    }
    if (tvdbid != "") {
        tvDbSeriesUrl=get_tv_series_api_url(plugin,tvdbid);
    }

    id0(tvDbSeriesUrl);
    return tvDbSeriesUrl;
}

function get_tv_series_api_url(plugin,tvdbid) {
    if (tvdbid != "") {
        if (plugin == "THETVDB") {
            if (g_tvdb_user_per_episode_api) {
                return g_thetvdb_web"/api/"g_api_tvdb"/series/"tvdbid"/en.xml";
            } else {
                return g_thetvdb_web"/api/"g_api_tvdb"/series/"tvdbid"/all/en.xml";
            }
        } else if (plugin == "TVRAGE") {
            return "http://services.tvrage.com/feeds/full_show_info.php?sid="tvdbid;
        }
    }
    return "";
}

#Load an xnl file into array - note duplicate elements are clobbered.
#To parse xml with duplicate lements call parseXML in a loop and trigger on index(line,"</tag>")
function fetchXML(url,label,xml,ignorePaths,\
f,line,result) {
    result = 0;
    f=getUrl(url,label,1);
    if (f != "" ) {
        FS="\n";
        while((getline line < f) > 0 ) {
            parseXML(line,xml,ignorePaths);
        }
        close(f);
        result = 1;
    }
    return 0+ result;
}

#Parse flat XML into an array - does NOT clear xml array as it is used in fetchXML
# @ignorePaths = csv of paths to ignore
#sep is used if merging repeated element values together
function parseXML(line,info,ignorePaths,\
sep,\
currentTag,i,j,tag,text,lines,parts,sp,slash,tag_data_count,\
attr,a_name,a_val,eq,attr_pairs,single_tag) {

    if (index(line,"<?")) return;

    if (sep == "") sep = "<";

    if (ignorePaths != "") {
        gsub(/,/,"|",ignorePaths);
        ignorePaths = "^("ignorePaths")\\>";
    }

    if (index(line,g_sigma) ) { 
        INF("Sigma:"line);
        gsub(g_sigma,"e",line);
        INF("Sigma:"line);
    }



    #break at each tag/endtag
    # <tag1>text1</tag1>midtext<tag2>text2</tag2> becomes
    # BLANK
    # tag1>text1
    # /tag1>midtext
    # tag2>text2
    # /tag2>
    #
    # <tag1><tag2 /></tag1> becomes
    # tag1>
    # tag2 />
    # /tag1> 

    tag_data_count = split(line,lines,"<");

    currentTag = info["@CURRENT"];

    if (tag_data_count  && currentTag ) {
        #If the line starts with text then add it to the current tag.
        info[currentTag] = info[currentTag] lines[1];
        #first item is blank
    }


    for(i = 2 ; i <= tag_data_count ; i++ ) {


        # lines[i] = tag>text
        # lines[i] = tag attr >text
        # lines[i] = tag attr />
        # lines[i] = /tag>

        #split <tag>text  [ or </tag>parenttext ]
        split(lines[i],parts,">");

        # part[1] = tag 
        # part[1] = tag attr1
        # part[1] = tag attr1 /
        # part[1] = /tag
        # part[2] = text


        tag = parts[1];
        text = parts[2];
        single_tag = 0;

        if (i == tag_data_count) {
            # Carriage returns mess up parsing
            j = index(text,"\r");
            if (j) text = substr(text,1,j-1);

            j = index(text,"\n");
            if (j) text = substr(text,1,j-1);
        }

        slash = index(tag,"/");
        if (slash == 1 )  {

            # end tag
            # part[1] = /tag

            currentTag = substr(currentTag,1,length(currentTag)-length(tag));

        } else {

            # part[1] = tag 
            # part[1] = tag attr1
            # part[1] = tag attr1 /

            if ( slash == length(tag) ||  (slash != 0 && substr(tag,length(tag)) == "/")) {
                # part[1] = tag attr1 /
                # Check appears more complex in case attribute contains slash.
                single_tag = 1;
            }


            if ((sp=index(tag," ")) != 0) {
                #Remove attributes Possible bug if space before element name
                tag=substr(tag,1,sp-1);
            }

            currentTag = currentTag "/" tag;


             #If merging element values add a sepearator
            if (currentTag in info) {
                text = sep text;
            }

        }

        if (text) {
            if (ignorePaths == "" || currentTag !~ ignorePaths) {
                info[currentTag] = info[currentTag] text;
            }
        }

        #parse attributes.
        
        if (index(parts[1],"=")) {
            get_regex_counts(parts[1],"[:A-Za-z_][-_A-Za-z0-9.]+=((\"[^\"]*\")|([^\"][^ \"'>=]*))",0,attr_pairs);
            for(attr in attr_pairs) {
                eq=index(attr,"=");
                a_name=substr(attr,1,eq-1);
                a_val=substr(attr,eq+1);
                if (index(a_val,"\"")) {
                    sub(/^"/,"",a_val);
                    sub(/"$/,"",a_val);
                }
                info[currentTag"#"a_name]=a_val;
            }

        }
        if (single_tag) {
            currentTag = substr(currentTag,1,length(currentTag)-length(tag));
        }

    }

    info["@CURRENT"] = currentTag;
}

# this corrupts a title but makes it easier to match on other similar titles.
function norm_title(t,\
keep_the) {
    if (!keep_the) {
        sub(/^[Tt]he /,"",t);
        sub(/ [Tt]he$/,"",t);
    }
    gsub(/[&]/,"and",t);
    gsub(/'/,"",t);

    # Clean title only removes . and _ if it has no spaces.
    # For similar title matching to work we remove all punctuation
    gsub(g_punc[0]," ",t);
    gsub(/  +/," ",t);

    return tolower(t);
}

# Return 3 if a possible Title is a very good match for titleIn
# Return 2 if it is a likely match
# Return 1 if it is an initial or abbreviated type of match.
# else return 0
function similarTitles(titleIn,possible_title,\
cPos,yearOrCountry,matchLevel,diff,shortName) {

    matchLevel = 0;
    yearOrCountry="";

    #DEBUG("Checking ["titleIn"] against ["possible_title"]");

    # Conan O Brien is a really tricky show to match on!
    # Its a daily,
    # It has two very good alternatives both of which have more than just Conan O Brien in the title,
    # it has "O" which thetvdb handles inconsistently.
    # The following tweak is for the latter issue.
    if (sub(/ [Oo] /," O",possible_title)) {
        possible_title=clean_title(possible_title);
    }
    if (sub(/ [Oo] /," O",titleIn)) {
        titleIn=clean_title(titleIn);
    }

    if (match(possible_title," \\([^)]+")) {
        yearOrCountry=tolower(clean_title(substr(possible_title,RSTART+2,RLENGTH-2),1));
        DEBUG("Qualifier ["yearOrCountry"]");
    }

    # change year to bracketed qualifier.
    #sub(/\<2[0-9][0-9][0-9]$/," (&)",titleIn);
    sub(/\<2[0-9][0-9][0-9]$/,"(&)",titleIn); # Removed space for now. Will fix with proper regex.

    if ((cPos=index(possible_title,",")) > 0) {
        shortName=clean_title(substr(possible_title,1,cPos-1),1);
    }

    possible_title=clean_title(possible_title);

    possible_title=norm_title(possible_title);
    titleIn=norm_title(titleIn);

#    if (substr(titleIn,2) == substr(possible_title,2)) {
#        DEBUG("Checking ["titleIn"] against ["possible_title"]");
#    }
    if (yearOrCountry != "") {
        DEBUG("Qualified title ["possible_title"]");
    }

#    INF("titleIn["titleIn"]");
#    INF("possible_title["possible_title"]");
#    INF("qualifed titleIn["titleIn" ("yearOrCountry")]");

    if (index(possible_title,titleIn) == 1) {
        #TODO Note we could keep the 1 match levels here and below, but if so
        #we should still go on to search abbreviations. For now easier to comment out.
        #The zero score will trigger the abbreviation code.
        #
        # Enabling this would allow "curb" to match "curb your enthusiasm"
        # but may false match abbreviations?
        #matchLevel = 1;

        #This will match exact name OR if BOTH contain original year or country
        if (possible_title == titleIn) {

            matchLevel=5;

            #If its a qualified match increase score further
            #eg xxx UK matches xxx UK
            #or xxx 2000 matches xxx 2000
            if (yearOrCountry != "") {
                matchLevel=10;
            }

        } else  if (titleIn == shortName) {
            #Check for comma. eg maych House to House,M D
            matchLevel=5;

        #This will match if difference is year or country. In this case just pick the 
        # last one and user can fix up
        } else if ( possible_title == titleIn " (" yearOrCountry ")" ) {
            INF("match for ["titleIn"+"yearOrCountry"] against ["possible_title"]");
            #unqualified match xxxx vs xxxx YYYY
            #We have to allow for example BSG to match the new series rather 
            # than the old , however new series is qualified (2003) at thetvdb
            matchLevel = 5;

        } else if ( index(possible_title,titleIn" Show")) {

            # eg "(The) Jay Leno Show" vs "Jay Leno"
            matchLevel = 4;

        } else {
            DEBUG("No match for ["titleIn"+"yearOrCountry"] against ["possible_title"]");
        }
    } else if (index(titleIn,possible_title) == 1) {
        #Check our title just has a country added

        #TODO Note we could keep the 1 match levels here and above, but if so
        #we should still go on to search abbreviations. For now easier to comment out.
        #The zero score will trigger the abbreviation code.

        #matchLevel = 1;
        diff=substr(titleIn,length(possible_title)+1);
        if ( diff ~ " "g_year_re"$" || diff ~ " (uk|us|au|nz|de|fr)" ) {
            #unqualified match xxxx 2000 vs xxxx
            matchLevel = 5;
            INF("match for ["titleIn"] containing ["possible_title"]");
        }
    } else if ( index(possible_title,"Late Night With "titleIn)) {
        # Late Night With Some Person might just be known as "Some Person"
        # eg The Tonight Show With Jay Leno
        matchLevel = 4;

    } else if ( index(possible_title,"Show With "titleIn)) {

        # The blah blah Show With Some Person might just be known as "Some Person"
        # eg The Tonight Show With Jay Leno
        matchLevel = 4;

    }
    return 0+ matchLevel;
}

#Given a title - scan an array or potential titles and return the best matches along with a score
#The indexs are carried over to new hash
# IN title
# IN titleHashIn - best titles so far hashed by tvdb id
# OUT titleHashOut - titles with highest similarilty scores hashed by tvdbid
# RETURNS Similarity Score - eg Office UK vs Office UK is a fully qualifed match high score.
function filterSimilarTitles(title,titleHashIn,titleHashOut,\
i,score,bestScore,tmpTitles) {

    id1("Find similar "title);
    #Save a copy in case titleHashIn = titleHashOut
    hash_copy(tmpTitles,titleHashIn);

    #Build score hash
    for(i in titleHashIn) {
        score[i] = similarTitles(title,titleHashIn[i]);
        DEBUG("["title"] vs ["i":"titleHashIn[i]"] = "score[i]);
    }

    #get items with best scores into titleHashOut
    bestScores(score,titleHashOut,0);

    #Replace scores with original ids
    for(i in titleHashOut) {
        titleHashOut[clean_title(i)] = tmpTitles[i];
    }

    dump(0,"matches",titleHashOut);
    bestScore = score[firstIndex(titleHashOut)];
    if (bestScore == "" ) bestScore = -1;

    INF("Filtered titles with score = "bestScore);
    dump(0,"filtered = ["title"]=",titleHashOut);

    if (bestScore == 0 ) {
        DEBUG("all zero score - discard them all to trigger another match method");
        delete titleHashOut;
    }

    id0(bestScore);

    return 0+ bestScore;
}

# Return the list of names in the epguide menu indexed by link
function getEpguideNames(letter,names,\
url,title,link,links,i,count2) {
    url = "http://epguides.com/menu"letter;

    scan_page_for_match_counts(url,"<li>","<li>(|<b>)<a.*</li>",0,1,"",links);
    count2 = 0;

    for(i in links) {

        if (index(i,"[radio]") == 0) {

            title = extractTagText(i,"a");

            #DEBUG(i " -- " links[i] " -- " title);

            if (title != "") {
                link = extractAttribute(i,"a","href");
                sub(/\.\./,"http://epguides.com",link);
                gsub(/\&amp;/,"And",title);

                # First hardcoded title. :(
                #epguide has the name listed differently to every other site in the world.
                #epguide is only used because, compared to the other sites, it is easy to
                #extract a list of all programs beginning with the same letter.
                #So I feel a little justified in hacking this list to be inline with everyone else.
                if (title == "C.S.I.") {
                    title = "C.S.I Crime Scene Investigation";
                }
                names[link] = title;
                count2++;

                #DEBUG("name list "title);
            }
        }
    }
    DEBUG("Loaded "count2" names");
    return 0+ count2;
}

# Search epGuide menu page for all titles that match the possible abbreviation.
# IN letter - menu page to search. Usually first letter of abbreviation except if abbreviation begins
#             with t then search both t page and subsequent letter - to account for "The xxx" on page x
# IN titleIn - The thing we are looking for - eg ttscc
# IN/OUT alternateTitles - hash of titles - index is the title, value is 1
function searchAbbreviation(letter,titleIn,alternateTitles,\
possible_title,names,i,ltitle) {

    ltitle = tolower(titleIn);

    id1("Checking "titleIn" for abbeviations on menu page - "letter);

    if (ltitle == "" ) return ;

    getEpguideNames(letter,names);

    for(i in names) {

        possible_title = names[i];

        sub(/\(.*/,"",possible_title);

        possible_title = clean_title(possible_title);

        if (abbrevMatch(ltitle,possible_title)) {
            alternateTitles[possible_title]="abbreviation-initials";
        } else if (abbrevMatch(ltitle ltitle,possible_title)) { # eg "CSI: Crime Scene Investigation" vs csicsi"
            alternateTitles[possible_title]="abbreviation-double";
        } else if (abbrevContraction(ltitle,possible_title)) {
            alternateTitles[possible_title]="abbreviation-contraction";
        }

    }
    id0();
}

#split title into words then see how many words or initials we can match.
# eg desperateh fguy  "law and order csi"
#note if a word AND initial match then we try to match the word first.
#I cant think of a scenario where we would have to backtract and try
# the initial instead.
#
#eg toxxx might abbreviate "to xxx" or "t" ...
function abbrevMatch(abbrev , possible_title,\
wrd,a,words,rest_of_abbrev,found,abbrev_len,short_words) {
    split(tolower(possible_title),words," ");
    a=1;
    wrd=1;
    abbrev_len = length(abbrev);

    short_words["and"] = short_words["in"] = short_words["it"] = short_words["of"] = 1;

    while(abbrev_len-a  >= 0 && (wrd in words)) {
        rest_of_abbrev = substr(abbrev,a);

        if (index(   rest_of_abbrev  ,   words[wrd]  ) == 1) {
            #abbreviation starts with entire word.
            a += length(words[wrd]);
            wrd++;
        } else if (substr(words[wrd],1,1) == substr(rest_of_abbrev,1,1)) {
            a ++;
            wrd++;
        } else if (substr(rest_of_abbrev,1,1) == " ") {
            a ++;
        } else if (words[wrd] in short_words ) {
            wrd++;
        } else {
            #no match
            break;
        }
    }
    found = ((a -abbrev_len ) > 0 ) && !(wrd in words);
    if (found) {
        INF(possible_title " abbreviated by ["abbrev"]");
    }
    return 0+ found;
}


# remove all words of 3 or less characters
function significant_words(t) {
    gsub(/\<[^ ]{1,3}\>/,"",t);
    gsub(/  +/," ",t);
    return trim(t);
}

function get_initials(title,\
initials) {
    initials = tolower(title);
    while(match(initials,"[^ ][^ ]+ ")) {
        initials = substr(initials,1,RSTART) " " substr(initials,RLENGTH+RSTART);
    }
    while(match(initials,"[^ ][^ ]+$")) {
        initials = substr(initials,1,RSTART);
    }
    gsub(/ /,"",initials);
    return initials;
}

# Return a regex that will find any embedded occurence of the given string. lowercase only
# ie aBc => a.*b.*c
function embedded_lc_regex(s) {
    gsub(//,".*",s);
    return tolower(substr(s,3,length(s)-4));
}

# match tblt to tablet , grk greek etc.
# The contraction is allowed to match from the beginning of the title to the
# end of any whole word. eg greys = greys anatomy 
function abbrevContraction(abbrev,possible_title,\
found,regex,part) {


    # Use regular expressions to do the heavy lifting.
    # First if abbreviation is grk convert to ^g.*r.*k\>
    #
    regex= embedded_lc_regex(abbrev);

    possible_title = norm_title(possible_title,1);
    found = match(possible_title,"^"regex"\\>");


    #DEBUG("abbrev:["abbrev"] ["regex"] ["possible_title"] = "found);

    if (found) {
        #  contraction will usually contain the initials of the part of the pattern that it matched.
        part=substr(possible_title,RSTART,RLENGTH);
        # 
        if (abbrev !~ embedded_lc_regex(get_initials(significant_words(part))) ) {
            INF("["possible_title "] rejected. Abbrev ["abbrev"]. doesnt contain initials of ["part"].");
            found = 0;
        }
    }

    return 0+ found;
}

function epguideInitial(title,\
letter) {

    sub(/^[Tt]he /,"",title);
    letter=tolower(substr(title,1,1));

    #Thank you epguides for silly numeric-alpha index eg 24 on page t, 90210 page n but 1990 page n too!
    if (match(title,"^10") ) {
        letter = "t";
    } else if (match(title,"^11") ) {
        letter = "e";
    } else if (match(title,"^1[2-9]") ) {
        letter = substr(title,2,1);
    }

    if ( letter == "1" ) {
        letter = "o";
    }else if (match(letter,"^[23]")  ) {
        letter = "t";
    }else if (match(letter,"^[45]") ) {
        letter = "f";
    }else if (match(letter,"^[67]") ) {
        letter = "s";
    }else if ( letter == "8" ) {
        letter = "e";
    }else if ( letter == "9" ) {
        letter = "n";
    }
    return letter;
}

# This is used in tv comparison functions for qualified matches so it must not remove any country
# or year designation
# deep - if set then [] and {} are removed from text too
function clean_title(t,deep,\
punc) {

    #ALL# gsub(/[&]/," and ",t);
    gsub(/[&]amp;/,"\\&",t);

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

function remove_tags(line) {

    gsub(/<[^>]+>/," ",line);

    if (index(line,"  ")) {
        gsub(/ +/," ",line);
    }

    if (index(line,"amp")) {
        gsub(/\&amp;/," \\& ",line);
    }

    gsub(/[&][a-z]+;?/,"",line);

    line=de_emphasise(line);

    return line;
}

function de_emphasise(html) {
    if (index(html,"<b") || index(html,"</b") ||\
       index(html,"<em") || index(html,"</em") ||\
       index(html,"<strong") || index(html,"</strong") ) {
        gsub(/<\/?(b|em|strong)>/,"",html); #remove emphasis tags
    }
    if (index(html,"wbr")) {
        # Note yahoo will sometimes break an imdb tag with a space and wbr eg. tt1234 <wbr>567
        gsub(/ *<\/?wbr>/,"",html); #remove emphasis tags
    }
    if (index("/>",html)) {
        #gsub(/<[^\/][^<]+\/>/,"",html); #remove single tags eg <wbr />
        gsub(/<[a-z]+ ?\/>/,"",html); #remove single tags eg <wbr />
    }
    return html;
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

function get_episode_url(plugin,seriesUrl,season,episode,\
episodeUrl ) {
    episodeUrl = seriesUrl;
    if (plugin == "THETVDB") {
        if (g_tvdb_user_per_episode_api) {
            #Note episode may be 23,24 so convert to number.
            if (sub(/en.xml$/,"default/"season"/"(episode+0)"/en.xml",episodeUrl)) {
                return episodeUrl;
            }
        } else {
            #same url
            return episodeUrl;
        }
    } else if (plugin == "TVRAGE") {
        #same url
        return episodeUrl;
    }
    return "";
}

#Get episode info by changing base url - this should really use the id
#but no time to refactor calling code at the moment.
function get_episode_xml(plugin,seriesUrl,season,episode,episodeInfo,\
episodeUrl,filter,result) {
    delete episodeInfo;

    id1("get_episode_xml");

    gsub(/[^0-9,]/,"",episode);

    episodeUrl = get_episode_url(plugin,seriesUrl,season,episode);
    if (episodeUrl != "") {
        if (plugin == "THETVDB") {

            if (g_tvdb_user_per_episode_api) {
                result = fetchXML(episodeUrl,plugin"-episode",episodeInfo);
            } else {
                filter["/Data/Episode/SeasonNumber"] = season;
                filter["/Data/Episode/EpisodeNumber"] = episode;
                result = fetch_xml_single_child(episodeUrl,plugin"-episode","/Data/Episode",filter,episodeInfo);
            }

        } else if (plugin == "TVRAGE" ) {
            filter["/Show/Episodelist/Season#no"] = season;
            filter["/Show/Episodelist/Season/episode/seasonnum"] = episode;
            result = fetch_xml_single_child(episodeUrl,plugin"-episode","/Show/Episodelist/Season/episode",filter,episodeInfo);
        } else {
            plugin_error(plugin);
        }
        dump(0,"episode-xml",episodeInfo);
    } else {
        INF("cant determine episode url from "seriesUrl);
    }
    id0(result);
    return 0+ result;
}

# 0=nothing 1=series 2=series+episode
function get_tv_series_info(plugin,idx,tvDbSeriesUrl,\
result) {

    id1("get_tv_series_info("plugin","idx"," tvDbSeriesUrl")");

    # mini-series may not have season set
    if (g_season[idx] == "") {
        g_season[idx] = 1;
    }

    if (plugin == "THETVDB") {
        result = get_tv_series_info_tvdb(idx,tvDbSeriesUrl);
    } else if (plugin == "TVRAGE") {
        result = get_tv_series_info_rage(idx,tvDbSeriesUrl);
    } else {
        plugin_error(plugin);
    }
#    ERR("UNCOMMENT THIS CODE");
    if (g_episode[idx] ~ "^DVD[0-9]+$" ) {
        result++;
    }
#    ERR("UNCOMMENT THIS CODE");

    DEBUG("Title:["gTitle[idx]"] "g_season[idx]"x"g_episode[idx]" date:"gAirDate[idx]);
    DEBUG("Episode:["gEpTitle[idx]"]");

    id0(result"="(result==2?"Full Episode Info":(result?"Series Only":"Not Found")));
    return 0+ result;
}

function setFirst(array,field,value) {
    if (array[field] == "") {
        array[field] = value;
        print "["field"] set to ["value"]";
    } else {
        print "["field"] already set to ["array[field]"] ignoring ["value"]";
    }
}

function remove_year(t) {
    sub(" *\\("g_year_re"\\)","",t); #remove year
    return t;
}

function remove_tv_year(t) {
    if(length(t) > 4) {
    sub(" *"g_year_re,"",t);
    }
    return t;
}
function set_plot(idx,plotv,txt) {
    plotv[idx] = substr(txt,1,g_max_plot_len);
    if (index(plotv[idx],"Remove Ad")) {
        sub(/\[[Xx]\] Remove Ad/,"",plotv[idx]);
    }
}
# Scrape theTvDb series page, populate arrays and return imdb link
# http://thetvdb.com/api/key/series/73141/default/1/2/en.xml
# http://thetvdb.com/api/key/series/73141/en.xml
# 0=nothing 1=series 2=series+episode
function get_tv_series_info_tvdb(idx,tvDbSeriesUrl,\
seriesInfo,episodeInfo,bannerApiUrl,result,empty_filter) {


    result=0;
    
    #fetchXML(tvDbSeriesUrl,"thetvdb-series",seriesInfo);
    fetch_xml_single_child(tvDbSeriesUrl,"thetvdb-series","/Data/Series",empty_filter,seriesInfo);
    if ("/Data/Series/id" in seriesInfo) {

        dump(0,"tvdb series",seriesInfo);

        setFirst(g_imdb,idx,extractImdbId(seriesInfo["/Data/Series/IMDB_ID"]));
        #Refine the title.
        adjustTitle(idx,remove_year(seriesInfo["/Data/Series/SeriesName"]),"thetvdb");

        g_year[idx] = substr(seriesInfo["/Data/Series/FirstAired"],1,4);
        setFirst(g_premier,idx,formatDate(seriesInfo["/Data/Series/FirstAired"]));
        set_plot(idx,g_plot,seriesInfo["/Data/Series/Overview"]);

        #Dont use thetvdb genre - its too confusing when mixed with imdb movie genre
        #setFirst(g_genre,idx,seriesInfo["/Data/Series/Genre"]);

        gCertRating[idx] = seriesInfo["/Data/Series/ContentRating"];

        # Dont use tvdb rating - prefer imdb one.
        #g_rating[idx] = seriesInfo["/Data/Series/Rating"];

        setFirst(g_poster,idx,tvDbImageUrl(seriesInfo["/Data/Series/poster"]));
        g_tvid_plugin[idx]="THETVDB";
        g_tvid[idx]=seriesInfo["/Data/Series/id"];
        result ++;


        bannerApiUrl = tvDbSeriesUrl;
        sub(/(all.|)en.xml$/,"banners.xml",bannerApiUrl);

        getTvDbSeasonBanner(idx,bannerApiUrl,"en");

        # For twin episodes just use the first episode number for lookup by adding 0

        if (g_episode[idx] ~ "^[0-9,]+$" ) {

            if (get_episode_xml("THETVDB",tvDbSeriesUrl,g_season[idx],g_episode[idx],episodeInfo)) {

                if ("/Data/Episode/id" in episodeInfo) {
                    setFirst(gAirDate,idx,formatDate(episodeInfo["/Data/Episode/FirstAired"]));

                    set_eptitle(idx,episodeInfo["/Data/Episode/EpisodeName"]);

                    if (g_epplot[idx] == "") {
                        set_plot(idx,g_epplot,episodeInfo["/Data/Episode/Overview"]);
                    }

                    if (gEpTitle[idx] != "" ) {
                       if ( gEpTitle[idx] ~ /^Episode [0-9]+$/ && g_plot[idx] == "" ) {
                           INF("Due to Episode title of ["gEpTitle[idx]"] Demoting result to force another TV plugin search");
                       } else {
                           result ++;
                       }
                    }
                }
            }
        }
    } else {
        WARNING("Failed to find ID in XML");
    }


    if (g_imdb[idx] == "" ) {
        WARNING("get_tv_series_info returns blank imdb url. Consider updating the imdb field for this series at "g_thetvdb_web);
    } else {
        DEBUG("get_tv_series_info returns imdb url ["g_imdb[idx]"]");
    }
    return 0+ result;
}

function tvDbImageUrl(path) {
    if(path != "") {

        #return "http://images.thetvdb.com/banners/_cache/" path;
        return "http://thetvdb.com/banners/" url_encode(html_decode(path));
    } else {
        return "";
    }
}

function getTvDbSeasonBanner(idx,bannerApiUrl,language,\
xml,filter,r) {

    if (getting_poster(idx,1) || getting_fanart(idx,1)) {
        r="/Banners/Banner";
        delete filter;
        filter[r"/Language"] = language;
        filter[r"/BannerType"] = "season";
        filter[r"/Season"] = g_season[idx];
        if (fetch_xml_single_child(bannerApiUrl,"banners","/Banners/Banner",filter,xml) ) {
            g_poster[idx] = tvDbImageUrl(xml[r"/BannerPath"]);
            DEBUG("Season Poster URL = "g_poster[idx]);
        }

        delete filter;
        filter[r"/Language"] = language;
        filter[r"/BannerType"] = "fanart";
        if (fetch_xml_single_child(bannerApiUrl,"banners","/Banners/Banner",filter,xml) ) {
            g_fanart[idx] = tvDbImageUrl(xml[r"/BannerPath"]);
            DEBUG("Fanart URL = "g_fanart[idx]);
        }
    }
}

function set_eptitle(idx,title) {
    if (gEpTitle[idx] == "" ) {

        gEpTitle[idx] = title;
        INF("Setting episode title ["title"]");

    } else if (title != "" && title !~ /^Episode [0-9]+$/ && gEpTitle[idx] ~ /^Episode [0-9]+$/ ) {

        INF("Overiding episode title ["gEpTitle[idx]"] with ["title"]");
        gEpTitle[idx] = title;
    } else {
        INF("Keeping episode title ["gEpTitle[idx]"] ignoring ["title"]");
    }
}

# 0=nothing 1=series 2=series+episode
function get_tv_series_info_rage(idx,tvDbSeriesUrl,\
seriesInfo,episodeInfo,filter,url,e,result,pi,p,ignore,flag) {

    pi="TVRAGE";
    result = 0;
    delete filter;

    ignore="/Show/Episodelist";
    if (fetch_xml_single_child(tvDbSeriesUrl,"tvinfo-show","/Show",filter,seriesInfo,ignore)) {
        dump(0,"tvrage series",seriesInfo);
        adjustTitle(idx,remove_year(seriesInfo["/Show/name"]),pi);
        g_year[idx] = substr(seriesInfo["/Show/started"],8,4);
        setFirst(g_premier,idx,formatDate(seriesInfo["/Show/started"]));


        url=urladd(seriesInfo["/Show/showlink"],"remove_add336=1&bremove_add=1");
        set_plot(idx,g_plot,scrape_one_item("tvrage_plot",url,"id=.iconn1",0,"iconn2|<center>|^<br>$",0,1));

        g_tvid_plugin[idx]="TVRAGE";
        g_tvid[idx]=seriesInfo["/Show/showid"];
        result ++;

        #get imdb link - via links page and then epguides.
        if(g_imdb[idx] == "") {
            url = scanPageFirstMatch(url,"/links/",g_nonquote_regex"+/links/",1);
            if (url != "" ) {
                url = scanPageFirstMatch(g_tvrage_web url,"epguides", "http"g_nonquote_regex "+.epguides." g_nonquote_regex"+",1);
                if (url != "" ) {
                    g_imdb[idx] = scanPageFirstMatch(url,"tt",g_imdb_regex,1);
                }
            }
        }


        e="/Show/Episodelist/Season/episode";
        if (g_episode[idx] ~ "^[0-9,]+$" ) {
            if (get_episode_xml(pi,tvDbSeriesUrl,g_season[idx],g_episode[idx],episodeInfo)) {

                set_eptitle(idx,episodeInfo[e"/title"]);

                gAirDate[idx]=formatDate(episodeInfo[e"/airdate"]);
                url=seriesInfo["/Show/showlink"] "/printable?nocrew=1&season=" g_season[idx];
                #OLDWAY#url=urladd(episodeInfo[e"/link"],"remove_add336=1&bremove_add=1");

                if (g_epplot[idx] == "" ) {
                    #p = scrape_one_item("tvrage_epplot",url,"id=.ieconn2",0,"</tr>|^<br>$|<a ",1);


                    flag=sprintf(":%02dx%02d",g_season[idx],g_episode[idx]);
                    p = scrape_one_item("tvrage_epplot", url, flag",<p>", 1, "</div>", 0, 1);


                    #OLDWAY#p = scrape_one_item("tvrage_epplot",url,">Episode Summary</h",0,"^<br>$|<a href",1,0);



                    sub(/ *There are no foreign summaries.*/,"",p);
                    if (p != "" && index(p,"There is no summary") == 0) {
                        set_plot(idx,g_epplot,p);
                        DEBUG("rage epplot :"g_epplot[idx]);
                    }
                }
                result ++;
            } else {
                WARNING("Error getting episode xml");
            }
        }

    } else {
        WARNING("Error getting series xml");
    }

    return 0+ result;
}

function urladd(a,b) {
    return a (index(a,"?") ? "&" : "?" ) b;
}

function clean_xml_path(xmlpath,xml,\
t,xmlpathSlash,xmlpathHash) {

    #This is the proper way to remove the element
    #delete the current child - its slow
    xmlpathSlash=xmlpath"/";
    xmlpathHash=xmlpath"#";

#DEBUG("@@ clean_xml_path ["xmlpath"]");

    #index function is faster than substr
    for(t in xml) {
        if (index(t,xmlpath) == 1) {
            if (t == xmlpath || index(t,xmlpathSlash) == 1 || index(t,xmlpathHash) == 1) {
                delete xml[t];
            }
        }
    }
}

# certain paths can be ignored to reduce memory footprint.
function fetch_xml_single_child(url,filelabel,xmlpath,tagfilters,xmlout,ignorePaths,\
f,found) {

   f = getUrl(url,filelabel,1);
   id1("fetch_xml_single_child ["url"] path = "xmlpath);
   found =  scan_xml_single_child(f,xmlpath,tagfilters,xmlout,ignorePaths);
   id0(found);
   return 0+ found;
}

# split the filter list into numbers , strings and regexs
function reset_filters(tagfilters,numbers,strings,regexs,\
t) {
   for(t in tagfilters) {
       DEBUG("filter ["t"]=["tagfilters[t]"]");

       if (tagfilters[t] ~ "^[0-9]+$" ) {
           numbers[t] = tagfilters[t];

       } else if (substr(tagfilters[t],1,2) == "~:") {

           regexs[t] = tolower(substr(tagfilters[t],3));

       } else {

           strings[t] = tagfilters[t];

       }
   }
}

# certain paths can be ignored to reduce memory footprint.
function scan_xml_single_child(f,xmlpath,tagfilters,xmlout,ignorePaths,\
numbers,strings,regexs,\
line,start_tag,end_tag,found,t,last_tag,number_type,regex_type,string_type) {

   delete xmlout;
   found=0;

   number_type=1;
   regex_type=2;
   string_type=3;

   last_tag = xmlpath;
   sub(/.*\//,"",last_tag);

   start_tag="<"last_tag">";
   end_tag="</"last_tag">";

   reset_filters(tagfilters,numbers,strings,regexs);

   dump(0,"numbers",numbers);
   dump(0,"strings",strings);
   dump(0,"regexs",regexs);


    if (f != "") {
        FS="\n";

        while((getline line < f) > 0 ) {


            if (index(line,start_tag) > 0) {
                # start of new child we are interested in. Clear all existing
                # child info. But keep parent info.
                clean_xml_path(xmlpath,xmlout);
            }


            parseXML(line,xmlout,ignorePaths);

            if (index(line,end_tag) > 0) {

                found=1;

                for(t in numbers) {
                    if (!(t in xmlout) || (xmlout[t] - numbers[t] != 0) ) {
                        found =0 ; break;
                    }
                }
                for(t in strings) {
                    if (!(t in xmlout) || (xmlout[t]"" != strings[t] ) ) {
                        found =0 ; break;
                    }
                }
                for(t in regexs) {
                    if (!(t in xmlout) || (tolower(xmlout[t]) !~ regexs[t] ) ) {
                        found =0 ; break;
                    }
                }

                if (found) {
                    DEBUG("Filter matched.");
                    break;
                }

            }

        }
        close(f);
    }
    if (!found) {
        clean_xml_path(xmlpath,xmlout);
    }
    return 0+ found;
}

# returns 1 if title adjusted or is the same.
# returns 0 if title ignored.
function adjustTitle(idx,newTitle,source,\
oldSrc,newSrc,newRank) {

    if (!("filename" in gTitlePriority)) {
        #initialise
        gTitlePriority[""]=-1;
        gTitlePriority["filename"]=0;
        gTitlePriority["search"]=1;
        gTitlePriority["imdb"]=2;
        gTitlePriority["epguides"]=2;
        gTitlePriority["imdb_aka"]=3;
        gTitlePriority["imdb_orig"]=4;
        gTitlePriority["thetvdb"]=5;
        gTitlePriority["THETVDB"]=5;
        gTitlePriority["TVRAGE"]=5;
    }
    newTitle = clean_title(newTitle);

    oldSrc=g_title_source[idx]":["gTitle[idx]"] ";
    newSrc=source":["newTitle"] ";

    if (!(source in gTitlePriority)) {

        ERR("Bad value ["source"] passed to adjustTitle");

    } else {
        newRank = gTitlePriority[source];
        #if  (ascii8(newTitle)) newRank += 10; # Give priority to accented names
        if (gTitle[idx] == "" || newRank - g_title_rank[idx] > 0) {
            DEBUG(oldSrc" promoted to "newSrc);
            gTitle[idx] = newTitle;
            g_title_source[idx] = source;
            g_title_rank[idx] = newRank;;
            return 1;
        } else {
            DEBUG("current title "oldSrc "outranks " newSrc);
            return 0;
        }
    }
}

function extractImdbId(text,quiet,\
id) {
    if (match(text,g_imdb_regex)) {
        id = substr(text,RSTART,RLENGTH);
        #DEBUG("Extracted IMDB Id ["id"]");
    } else if (match(text,"Title.[0-9]+\\>")) {
        id = "tt" substr(text,RSTART+8,RLENGTH-8);
        #DEBUG("Extracted IMDB Id ["id"]");
    } else if (!quiet) {
        WARNING("Failed to extract imdb id from ["text"]");
    }
    if (id != "" && length(id) != 9) {
        id = sprintf("tt%07d",substr(id,3));
    }
    return id;
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

function extractImdbLink(text,quiet,\
t) {
    t = extractImdbId(text,quiet);
    if (t != "") {
        t = "http://www.imdb.com/title/"t"/"; # Adding the / saves a redirect
    }
    return t;
}

function extractAttribute(str,tag,attr,\
    tagPos,closeTag,endAttr,attrPos) {

    tagPos=index(str,"<"tag);
    closeTag=indexFrom(str,">",tagPos);
    attrPos=indexFrom(str,attr"=",tagPos);
    if (attrPos == 0 || attrPos-closeTag >= 0 ) {
        ERR("ATTR "tag"/"attr" not in "str);
        ERR("tagPos is "tagPos" at "substr(str,tagPos));
        ERR("closeTag is "closeTag" at "substr(str,closeTag));
        ERR("attrPos is "attrPos" at "substr(str,attrPos));
        return "";
    }
    attrPos += length(attr)+1;
    if (substr(str,attrPos,1) == "\"" ) {
        attrPos++;
        endAttr=indexFrom(str,"\"",attrPos);
    }  else  {
        endAttr=indexFrom(str," ",attrPos);
    }
    #DEBUG("Extracted attribute value ["substr(str,attrPos,endAttr-attrPos)"] from tag ["substr(str,tagPos,closeTag-tagPos+1)"]");
    return substr(str,attrPos,endAttr-attrPos);
}

function extractTagText(str,startText,\
    i,j) {
    i=index(str,"<"startText);
    i=indexFrom(str,">",i) + 1;
    j=indexFrom(str,"<",i);
    return trim(substr(str,i,j-i));
}

function indexFrom(str,x,startPos,\
    j) {
    if (startPos<1) startPos=1;
    j=index(substr(str,startPos),x);
    if (j == 0) return 0;
    return j+startPos-1;
}

# encode a string to utf8
function utf8_encode(text,\
text2,part,parts,count) {
    if (g_chr[32] == "" ) {
        decode_init();
    }


    if (ascii8(text)) {
        count = chop(text,"["g_8bit"]+",parts);
        for(part=2 ; part-count <= 0 ; part += 2 ) {
            text2=text2 parts[part-1] utf8_encode2(parts[part]);
            #INF("utf8 [["substr(parts[part-1],length(parts[part-1])-20)"]]...[["substr(parts[part+1],1,20)"]]");
        }
        text2 = text2 parts[count];
        if (text != text2 ) {
            text = text2;
        }
    }
    return text;
}
# encode a string to utf8 that alread consists entirely of chr(128-255)
# called by utf8_encode
function utf8_encode2(text,\
i,text2,ll) {

    ll=length(text);
    for(i = 1 ; i - ll <= 0 ; i++ ) {
        text2 = text2 g_utf8[substr(text,i,1)];
    }
#    if (text != text2 ) {
#        DEBUG("utf8_encode2 ["text"]=["text2"]");
#    }
    return text2;
}


function url_encode(text,\
i,text2,ll,c) {

    if (g_chr[32] == "" ) {
        decode_init();
    }

    text2="";
    ll=length(text);
    for(i = 1 ; i - ll <= 0 ; i++ ) {
        c=substr(text,i,1);
        if (index("% =()[]+",c) || g_ascii[c] -128 >= 0 ) {
            text2= text2 "%" g_hex[g_ascii[c]];
        } else {
            text2=text2 c;
        }
    }
    if (text != text2 ) {
        DEBUG("url encode ["text"]=["text2"]");
    }

    return text2;
}

function decode_init(\
i,c,h,b1,b2) {
    DEBUG("create decode matrix");
    for(i=0 ; i - 256 < 0 ; i++ ) {
        c=sprintf("%c",i);
        h=sprintf("%02x",i);
        g_chr[i] = c;
        g_chr["x"h] = c;
        g_ascii[c] = i;
        g_hex[i]=h;

    }
    for(i=0 ; i - 128 < 0 ; i++ ) {
        c = g_chr[i];
        g_utf8[c]=c;
    }
    for(i=128 ; i - 256 < 0 ; i++ ) {
        c = g_chr[i];
        b1=192+rshift(i,6);
        b2=128+and(i,63);
        g_utf8[c]=g_chr[b1+0] g_chr[b2+0];
    }
    #special html - all sites return utf8 except for IMDB and epguides.
    # IMDB doesnt use symbolic names - mostly hexcodes. So we can probably 
    # not bother with anything except for amp. see what happens.
    #s="amp|38|gt|62|lt|60|divide|247|deg|176|copy|169|pound|163|quot|34|nbsp|32|cent|162|";
    g_chr["amp"] = "&";
    g_chr["quot"] = "\"";
    g_chr["lt"] = "<";
    g_chr["gt"] = ">";
    g_chr["nbsp"] = " ";
}

function html_decode(text,\
parts,part,count,code,newcode,text2) {
    if (g_chr[32] == "" ) {
        decode_init();
    }
    if (index(text,"&")) {

        count = chop(text,"[&][#0-9a-zA-Z]+;",parts);

        for(part=2 ; part-count < 0 ; part += 2 ) {

            newcode="";

            code=parts[part];
            if (code != "") {

                code=tolower(code); # "&#xff;" "&#255;" "&nbsp;"

                if (index(code,"&#") == 1) {
                    # &#xff; => xff   &#255; => 255
                    code = substr(code,3,length(code)-3);
                    if (index(code,"x") == 1) {
                        # xff;
                        newcode=g_chr[code];
                    } else {
                        # &#255;
                        newcode=g_chr[0+code];
                    }
                } else {
                    # "&nbsp;" => "nbsp"
                    newcode=g_chr[substr(code,2,length(code)-2)];
                }
            }
            if (newcode == "") {
                newcode=parts[part]; #unchanged
            }
            text2=text2 parts[part-1] newcode;
            #INF("utf8 [["substr(parts[part-1],length(parts[part-1])-20)"]]...[["substr(parts[part+1],1,20)"]]");
        }
        text2 = text2 parts[count];
        if (text != text2 ) {
            text = text2;
        }
    }
    return text;
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

#imdb files dont change much - apart from rating. Keep them forever
#to get new ratings then delete cache
#if file cant be created return blank
function persistent_cache(fname,\
dir) {
    dir=APPDIR"/cache";
    if (g_cache_ok == 0) { #first time check
        g_cache_ok=2; #bad
        system("mkdir -p "qa(dir));
        if (set_permissions(qa(dir)"/.") == 0) {
            g_cache_ok=1; #good
        }
    }
    
    if (g_cache_ok == 1) { # good
        INF("Using persistent cache");
        return dir"/"fname;
    } else if (g_cache_ok == 2) { # bad
        return "";
    }
}
    
function set_cache_prefix(p) { 
    g_cache_prefix=p;
}
function clear_cache_prefix(p,\
u) { 
    for(u in gUrlCache) {
        if (index(u,p) == 1) {
            DEBUG("Deleting cache entry "u);
            delete gUrlCache[u];
        }
    }
    g_cache_prefix="";
}

function getUrl(url,capture_label,cache,referer,\
    f,label,url2) {
    
    label="getUrl:"capture_label": ";

    #DEBUG(label url);

    if (url == "" ) {
        WARNING(label"Ignoring empty URL");
        return;
    }

    url2 = g_cache_prefix url;

    if(cache && (url2 in gUrlCache) ) {

        DEBUG(label" fetched ["url2"] from cache");
        f = gUrlCache[url2];
    }

    if (g_settings["catalog_cache_film_info"] == "yes") {
        if (url ~ ".imdb.com/title/tt[0-9]+/?$" ) {
            f = persistent_cache(extractImdbId(url));
            cache=1;
        }
    }

    if (f =="" ) {
        f=new_capture_file(capture_label);
    }
    if (is_file(f) == 0) {

        if (wget(url,f,referer) ==0) {
            if (cache) {
                gUrlCache[url2]=f;
                #DEBUG(label" Fetched & Cached ["url"] to ["f"]");
            } else {
                #DEBUG(label" Fetched ["url"] into ["f"]"); 
            }
        } else {
            ERR(label" Failed getting ["url"] into ["f"]");
            f = "";
        }
    }
    return f;
}

function get_referer(url,\
i,referer) {
    # fake referer anyway
    i = index(substr(url,10),"/");
    if (i) {
        referer=substr(url,1,9+i);
    }
    return referer;
}

# Note nmt wget has a bug when using -O flag. Only one file is redirected.
function wget(url,file,referer,\
i,urls,tmpf,qf,r) {
    split(url,urls,"\t");
    tmpf = file ".tmp";
    qf = qa(tmpf);

    r=1;
    for(i in urls) {
        if (urls[i] != "") {
            if (wget2(urls[i],tmpf,referer) == 0) {

                # Long html lines were split to avoid memory issues with bbawk.
                # With gawk it may be possible to bo back to using cat.

                #Insert line feeds - but try not to split text that has bold or span tags.

                #exec("cat "qf" >> "qa(file));
                exec(AWK " '{ gsub(/<([hH][1-5]|div|DIV|td|TD|tr|TR|p|P)[ >]/,\"\\n&\") ; print ; }' "qf" >> "qa(file));
                r=0;
            }
        }
        system("rm -f "qf);
    }
    return r;
}

#Get a url. Several urls can be passed if separated by tab character, if so they are put in the same file.
# Note nmt wget has a bug when using -O flag. Only one file is redirected.
function wget2(url,file,referer,\
args,unzip_cmd,cmd,htmlFile,downloadedFile,targetFile,result,default_referer) {

    args=" -U \""g_user_agent"\" "g_wget_opts;
    default_referer = get_referer(url);
    if (check_domain_ok(default_referer) == 0) {
        return 1;
    }
    if (referer == "") {
        referer = default_referer;
    }

    if (referer != "") {
        args=args" --referer=\""referer"\" ";
    }

    targetFile=qa(file);
    htmlFile=targetFile;

    args=args" --header=\"Accept-Encoding: gzip\" "
    downloadedFile=qa(file".gz");
    #some devices have gzip not gunzip and vice versa
    unzip_cmd=" && ( gunzip -c "downloadedFile" || gzip -c -d "downloadedFile" || cat "downloadedFile") > "htmlFile" 2>/dev/null && rm "downloadedFile;

    gsub(/ /,"+",url);

    # nmt wget has a bug that causes a segfault if the url basename already exists and has no extension.
    # To fix either make sure action url basename doesnt already exist (not easy with html redirects)
    # or delete the -O target file and use the -c option together.
    rm(downloadedFile,1);
    args = args " -c ";

    #d=g_tmp_dir"/wget."PID;

    url=qa(url);

#ALL#    if (url in g_url_blacklist) {
#ALL#
#ALL#        WARNING("Skipping url ["url"] due to previous error");
#ALL#        result = 1;
#ALL#
#ALL#    } else {

        cmd = "wget -O "downloadedFile" "args" "url" "unzip_cmd  ;
        #cmd="( mkdir "d" ; cd "d" ; "cmd" ; rm -fr -- "d" ) ";
        # Get url if we havent got it before or it has zero size. --no-clobber switch doesnt work on NMT

        # Set this between 1 and 4 to throttle speed of requests to the same domain

        DEBUG("WGET ["url"]");
        result = exec(cmd);
        if (result != 0) {
#ALL#            g_url_blacklist[url] = 1;
#ALL#            WARNING("Blacklisting url ["url"]");
            rm(downloadedFile,1);
        }
#ALL#    }
    return 0+ result;
}

#Return reference to an internal poster location. eg
# ovs:<field>"/"ovs_Terminator_1993.jpg
#
# ovs: indicates internal database path. 
# field is a sub folder. All internal posters are stored under "ovs:"POSTER"/"...
function internal_poster_reference(field_id,idx,\
poster_ref) {
    poster_ref = gTitle[idx]"_"g_year[idx];
    gsub("[^-_&" g_alnum8 "]+","_",poster_ref);
    if (g_category[idx] == "T" ) {
        poster_ref = poster_ref "_" g_season[idx];
    } else {
        poster_ref = poster_ref "_" g_imdb[idx];
    }
    #"ovs:" means store in local database. This abstract path is used because when using
    #crossview in oversight jukebox, different posters have different locations.
    #It also allows the install folder to be changed as it is not referenced within the database.
    return "ovs:" field_id "/" g_settings["catalog_poster_prefix"] poster_ref ".jpg";
}

function getting_fanart(idx,lg) {
    return 0+ getting_image(idx,FANART,GET_FANART,UPDATE_FANART,lg);
}

function getting_poster(idx,lg) {
    return 0+ getting_image(idx,POSTER,GET_POSTERS,UPDATE_POSTERS,lg);
}

function getting_image(idx,image_field_id,get_image,update_image,lg,\
poster_ref,internal_path) {

    poster_ref = internal_poster_reference(image_field_id,idx);
    internal_path = getPath(poster_ref,g_fldr[idx]);

    if (internal_path in g_image_inspected) {
        if(lg) INF("Already looked at "poster_ref);
        return 0;
    } else if (update_image) {
        if(lg) INF("Force Update of "poster_ref);
        return 1;
    } else if (!get_image) {
        if(lg) INF("Skipping "poster_ref);
        return 0;
    } else if (hasContent(internal_path)) {
        if(lg) INF("Already have "poster_ref" ["internal_path"]");
        return 0;
    } else {
        if(lg) INF("Getting "poster_ref);
        return 1;
    }
}
    
# Check for locally held poster otherwise fetch one. This may be held locally(with media)
# or internally in a common folder.
# Note if poster may be url<tab>referer_url
function download_image(field_id,url,idx,\
    poster_ref,internal_path,urls,referer,wget_args,get_it,script_arg,default_referer) {

    id1("download_image["field_id"]["url"]");
    if (url != "") {

        #Posters are all held in the same folder so
        #need a name that is unique per movie or per season

        #Note for internal posters the reference contains a sub path.
        # (relative to database folder ovs: )
        poster_ref = internal_poster_reference(field_id,idx);
        internal_path = getPath(poster_ref,g_fldr[idx]);

        #DEBUG("internal_path = ["internal_path"]");
        #DEBUG("poster_ref = ["poster_ref"]");
        #DEBUG("new poster url = "url);

        get_it = 0;
        if (field_id == POSTER) {
            get_it = getting_poster(idx,0);
        } else if (field_id == FANART) {
            get_it = getting_fanart(idx,0);
        }

        INF("getting image = "get_it);

        if (get_it ) {


            #create the folder.
            preparePath(internal_path);

            split(url,urls,"\t");
            url=urls[1];
            referer=urls[2];

            # -t retries - oversight runs the command twice so halve number of retries.
            # -w time between retries.
            # -T network timeouts
            wget_args=g_wget_opts g_art_timeout;

            DEBUG("Image url = "url);
            default_referer = get_referer(url);
            if (referer == "" ) {
                referer = default_referer;
            }
            if (referer != "" ) {
                DEBUG("Referer = "referer);
                wget_args = wget_args " --referer=\""referer"\" ";
            }
            wget_args = wget_args " -U \""g_user_agent"\" ";

            # Script to fetch poster and create sd and hd versions
            if (field_id == POSTER) {
                script_arg="poster";
            } else {
                script_arg="fanart";
            }


            rm(internal_path,1);
            exec(APPDIR"/bin/jpg_fetch_and_scale "g_fetch_images_concurrently" "PID" "script_arg" "qa(url)" "qa(internal_path)" "wget_args" &");
            g_image_inspected[internal_path]=1;
        }
    }

    id0(poster_ref);

    return poster_ref;
}

# Check a domain responds quickly.
function check_domain_ok(url,\
start,tries,timeout) {

    if (!(url in g_domain_status)) {
        start=systime();
        tries=2;
        timeout=5;
        if (system("wget --spider --no-check-certificate -t "tries" -T "timeout" -q -O /dev/null "qa(url)"/favicon.ico") ) {
            g_domain_status[url]=1;
        } else if (systime() - start  >= tries * timeout ) {
            WARNING("Error with domain ["url"]");
            g_domain_status[url]=0;
        } else {
            # Error getting page but not a timeout so assume domain is ok
            g_domain_status[url]=1;
        }
    }
    return g_domain_status[url];
}

#ALL# To be implemented - maybe
#ALL# # q = query terms
#ALL# # wdivh = required width div height ratio (approx)
#ALL# # dimAfterLink is whether dimension occurs after link in the search results.
#ALL# # dimreg = regex that matches dimensions 
#ALL# function bingimg(q,minw,minh,wdivh,dimAfterLink,dimreg,\
#ALL# url,f,imgurl,txt,html,numhtml,i,w,h,zero,dim,href_regex,len) {
#ALL#     url="http://www.bing.com/images/search?q="q"&FORM=BIFD";
#ALL#     #href_regex="http:[-_%A-Za-z0-9.?&:=]+(jpg|png)";
#ALL#     href_regex="http://[^\"<>]+(jpg|png)";
#ALL# 
#ALL#     f = getUrl(url,"image",0);
#ALL#     if (f) {
#ALL#         FS="\n";
#ALL#         while((getline txt < f) > 0 && imgurl == "" ) {
#ALL#             numhtml = split(txt,html,dimreg);
#ALL#             if (numhtml -1 > 0 ) INF("Image search found "numhtml" images");
#ALL#             len=0;
#ALL#             #loop through html segments - looking at each dimension split.
#ALL#             #as we are looking at the splitsnote we dont need to loop on the last item
#ALL#             for(i = 1 ; i - numhtml < 0 && imgurl == "" ; i++ ) {
#ALL# 
#ALL#                 #track the length as we go along so we know how many chars matched each dimension regex from split
#ALL#                 len += length(html[i]);
#ALL# 
#ALL#                 #extract the dimension
#ALL#                 dim = substr(txt,len+1);
#ALL#                 if (match(dim,"^"dimreg)) {
#ALL#                     dim=substr(dim,1,RLENGTH);
#ALL#                     len += RLENGTH;
#ALL#                     INF("Got dimension ["dim"]");
#ALL#                 } else {
#ALL#                     ERR("Expected dimension here ["substr(text,len+1,10)"...]");
#ALL#                     continue;
#ALL#                 }
#ALL#                 # Check dimensions
#ALL#                 w = h = 0;
#ALL#                 if (match(dim,"^[0-9]+")) w=substr(dim,1,RLENGTH);
#ALL#                 if (match(dim,"[0-9]+$")) h=substr(dim,RSTART);
#ALL#                 if (w-minw < 0 || h-minh < 0 ) { INF("Skipping size "dim) ; break }
#ALL#                 zero = (h * wdivh / w) - 1 ;
#ALL#                 if (zero * zero > 0.1 ) { INF("Skipping a/r "dim) ; break ; }
#ALL# 
#ALL#                 #now try to extract the image
#ALL#                 if (dimAfterLink) {
#ALL#                     #get first image url in the next html segment
#ALL#                     if (match(html[i+1],href_regex) ) {
#ALL#                         imgurl=substr(html[i+1],RSTART,RLENGTH);
#ALL#                     }
#ALL#                 } else {
#ALL#                     #get the last image url in the current html segment
#ALL#                     if (match(html[i+1],".*"href_regex)) {
#ALL#                         if ( match(substr(html[i+1],RSTART,RLENGTH) , href_regex"$" )) {
#ALL#                             imgurl=substr(html[i+1],RSTART,RLENGTH);
#ALL#                         }
#ALL#                     }
#ALL#                 }
#ALL#                 INF("Found ["imgurl"] with dimension "dim);
#ALL#             }
#ALL#         }
#ALL#     }
#ALL# }
#ALL# 

#movie db - search direct for imdbid then extract picture
#id = imdbid
function getNiceMoviePosters(idx,imdb_id,\
poster_url,backdrop_url,xmlp,url,tagfilter,xml) {


    if (getting_poster(idx,1) || getting_fanart(idx,1)) {

        DEBUG("Poster check imdb_id = "imdb_id);

        #poster_url = bingimg(gTitle[idx]" "g_year[idx]"+site%3aimpawards.com",300,450,2/3,0,"[0-9]+ x [0-9]+");

            # Get posters from TMDB usiong the API. Unfortunately this doesnt expose poster rating.
        if (poster_url == "" && getting_poster(idx,1) ) {
            poster_url = get_moviedb_img(imdb_id,"poster","mid");
        }

        if (getting_fanart(idx,1) ) {
            backdrop_url = get_moviedb_img(imdb_id,"backdrop","original");
        }

        if (poster_url == "") {
            poster_url = get_motech_img(idx);
        }
        INF("movie poster ["poster_url"]");
        g_poster[idx]=poster_url;

        INF("movie backdrop ["backdrop_url"]");
        g_fanart[idx]=backdrop_url;
    }
}

function get_motech_img(idx,\
referer_url,url,url2) {
    #if (1) {
    referer_url = "http://www.motechposters.com/title/"g_motech_title[idx]"/";
    #} else {
    #search_url="http://www.google.com/search?q=allintitle%3A+"gTitle[idx]"+("g_year[idx]")+site%3Amotechposters.com";
    #referer_url=scanPageFirstMatch(search_url,"http://www.motechposters.com/title[^\"]+",0);
    #}
    DEBUG("Got motech referer "referer_url);
    if (referer_url != "" ) {
        url2=scanPageFirstMatch(referer_url,"/posters","/posters/[^\"]+jpg",0);
        if (url2 != ""  && index(url2,"thumb.jpg") == 0 ) {
            url="http://www.motechposters.com" url2;

            url=url"\t"referer_url;
            DEBUG("Got motech poster "url);
        } 
    }
    return url;
}

# search :
#
#<OpenSearchDescription xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">
#  <opensearch:Query searchTerms="tt0418279"/>
#    <opensearch:totalResults>1</opensearch:totalResults>
#      <movies>
#        <movie>
#          <name>Transformers</name>
#            <images>
#              <poster id="30030">
#                <image url="http://images....org/posters/30030/Transformers_v3.jpg" size="original"/>
#                <image url="http://images....org/posters/30030/Transformers_v3_thumb.jpg" size="thumb"/>
#                <image url="http://images....org/posters/30030/Transformers_v3_mid.jpg" size="mid"/>
#                <image url="http://images....org/posters/30030/Transformers_v3_cover.jpg" size="cover"/>
#              </poster>
#
function get_moviedb_img(imdb_id,type,size,\
search_url,txt,xml,f,url,url2) {

    search_url="http://api.themoviedb.org/2.1/Movie.imdbLookup/en/xml/"g_api_tmdb"/"imdb_id;

# the first one is the one with the highest ratings. At present rating order is NOT returned using 
# getImages so using imdbLookup instead.

    id1("get_moviedb_img "imdb_id" "type" "size);
    f=getUrl(search_url,"moviedb",0);

    #scan_xml_single_child(f,"/OpenSearchDescription/movies/movie/images",tagfilters,xmlout,\
    if (f != "") {
        FS="\n";
        while((getline txt < f) > 0 ) {

            if (index(txt,"<image")) {

                delete xml;
                parseXML(txt,xml);
                if (xml["/image#type"] == type && xml["/image#size"] == size ) {
                    url2=url_encode(html_decode(xml["/image#url"]));
                    if (exec("wget "g_wget_opts" --spider "url2) == 0 ) {
                        url = url2;
                        break;
                    }
                }
            }

        }
        close(f);
    }
    id0(url);
    return url;
}

# Scan a page for matches to regular expression
# IN fixed_text, - fixed text to help speed up scan
# matches = array of matches index 1,2,...
# max = max number to match
# returns match or empty.
# if freqOrFirst=1 return first match else
# =0 return most common matches in best(index by match id, value = count)
function scanPageFirstMatch(url,fixed_text,regex,cache,referer,\
matches,ret) {
    id1("scanPageFirstMatch");
    scan_page_for_match_counts(url,fixed_text,regex,1,cache,referer,matches);
    ret = firstIndex(matches);
    id0(ret);
    return ret;
}

# Scan a page for given regex return the most frequently occuring matching text.
# fixed_text is used to quickly filter strings that may match the regex.
# result returned in matches as count index by matching text.
# return value is the number of matches.
function scanPageMostFreqMatch(url,fixed_text,regex,cache,referer,matches,\
normedt,ret) {
    id1("scanPageMostFreqMatch");
    scan_page_for_match_counts(url,fixed_text,regex,0,cache,referer,matches);
    if (regex == g_imdb_title_re) {
        normalise_title_matches(matches,normedt);
        hash_copy(matches,normedt);
    }
    ret=bestScores(matches,matches,0);
    id0(ret);
    return ret;
}

#Searching is more intensive now and it is easy to get google rejecting searches based on traffic.
#So we apply round-robin (yahoo,msn,ask) to avoid getting blacklisted.

#
function search_url(url) {
    sub(/^SEARCH/,g_search_engine[(g_search_engine_current++) % g_search_engine_count],url);
    return url;
}

function search_url2file(url,cache,referer,\
i,url2,f) {
    for(i = 0 ; i < 0+g_search_engine_count ; i++ ) {

        url2 = search_url(url);

        f=getUrl(url2,"scan4match",cache,referer);

        if (f != "") break;
    }
    return f;
}

#getline_encode
# read a line from html or xml and apply html_decoding and utf8_encoding
# based on encoding flags at the start of the content.
# TODO only check xml encoding for first line.
# returns getline code and line contents in line[1]
function enc_getline(f,line,\
code,t) {

    code = ( getline t < f );

    if (code > 0) {
        #TODO - remove this debug code

        if (g_f_utf8[f] == "" ) {

            # check encoding

            g_f_utf8[f] = check_utf8(t);


        } else {

            t = html_decode(t);

            if (g_f_utf8[f] != 1) {
                t = utf8_encode(t);
            }
        }
        line[1] = t;
    }
    return code;
}

function enc_close(f) {
    delete g_f_utf8[f];
    close(f);
}

# TODO only check xml encoding for first line.
function check_utf8(line,\
utf8) {
    line=tolower(line);
    if (index(line,"<?xml") || index(line,"charset")) {

        utf8 = index(line,"utf-8")?1:-1;

    } else if (index(line,"</head>")) {
        utf8 = -1;
    }
    if (utf8) INF("UTF-8 Encoding:" utf8);
    return utf8;
}

# Scan a page for matches to regular expression
# IN url to scan
# IN fixed_text, - fixed text to help speed up scan
# IN regex to scan for
# IN max = max number to match 0=all
# OUT matches = array of matches index by the match text value = number of occurences.
# return number of matches
function scan_page_for_match_counts(url,fixed_text,regex,max,cache,referer,matches,verbose) {
    return scan_page_for_matches(url,fixed_text,regex,max,cache,referer,0,matches,verbose);
}
# Scan a page for matches to regular expression
# IN url to scan
# IN fixed_text, - fixed text to help speed up scan
# IN regex to scan for
# IN max = max number to match 0=all
# OUT matches = array of matches index by the match text value = number of occurences.
# return number of matches
function scan_page_for_match_order(url,fixed_text,regex,max,cache,referer,matches,verbose) {
    return scan_page_for_matches(url,fixed_text,regex,max,cache,referer,1,matches,verbose);
}
# Scan a page for matches to regular expression
# IN url to scan
# IN fixed_text, - fixed text to help speed up scan
# IN regex to scan for
# IN max = max number to match 0=all
# IN count_or_order = 0=count 1=order
# OUT matches = array of matches index by the match text value = number of occurences.
# return number of matches
function scan_page_for_matches(url,fixed_text,regex,max,cache,referer,count_or_order,matches,verbose,\
f,line,count,linecount,remain,is_imdb,matches2,i) {

    delete matches;
    id1("scan_page_for_matches["url"]");
    INF("["fixed_text"]["\
        (regex == g_imdb_regex\
            ?"<imdbtag>"\
            :(regex==g_imdb_title_re\
                ?"<imdbtitle>"\
                :regex\
              )\
       )"]["max"]");

    if (index(url,"SEARCH") == 1) {
        f = search_url2file(url,cache,referer);
    } else {
        f=getUrl(url,"scan4match",cache,referer);
    }

    count=0;

    is_imdb = (regex == g_imdb_regex );

    if (f != "" ) {

        FS="\n";
        remain=max;

        while(enc_getline(f,line) > 0 ) {

            line[1] = de_emphasise(line[1]);

            # Quick hack to find Title?0012345 as tt0012345  because altering the regex
            # itself is more work - for example the results will come back as two different 
            # counts. 
            if (is_imdb && index(line[1],"/Title?") ) {
                gsub(/\/Title\?/,"/tt",line[1]);
            }

            if (verbose) DEBUG("scanindex = "index(line[1],fixed_text));
            if (verbose) DEBUG(line[1]);

            if (fixed_text == "" || index(line[1],fixed_text)) {

                if (count_or_order) {
                    # Get all ordered matches. 1=>test1, 2=>text2 , etc.
                    linecount = get_regex_pos(line[1],regex,remain,matches2);
                    # 
                    # Append the matches2 array of ordered regex matches. Index by order.
                    for(i = 1 ; i+0 <= linecount+0 ; i++) {
                        matches[count+i] = matches2[i];
                    }
                } else {
                    # Get all occurence counts text1=m , text2=n etc.
                    linecount = get_regex_counts(line[1],regex,remain,matches2);
                    # Add to the total occurences so far , index by pattern.
                    hash_add(matches,matches2);
                }

                count += linecount;
                if (max > 0) {
                    remain -= count;
                    if (remain <= 0) {
                        break;
                    }
                }
            }
        }
        close(f);
    }
    dump(2,count" matches",matches);
    id0(count);
    return 0+ count;
}

# Split a line at regex boundaries.
# used by get_regex_counts
# IN s - line to split
# IN regex - regular expression
# OUT parts - index 1,2,3.. values text,match1,text,match2,...
# RET number of parts.
function chop(s_in,regex,parts,\
flag,i,s) {
    #first find split text that doesnt occur in the string.
    flag="=#z@~";
#    while (index(s,flag) ) {
#        WARNING("Regex flag clash "flag); #log this so I will know when to use a better seed flag.
#        flag = flag "£" flag; #dodgy line but should work!
#    }

    # insert the split text around the regex boundaries

    s = s_in;

    if (gsub(regex,flag "&" flag , s )) {
        # now split at boundaries.
        i = split(s,parts,flag);
        if (i % 2 == 0) ERR("Even chop of ["s"] by ["flag"]");
    } else {
        i = 1;
        delete parts;
        parts[1] = s_in;
    }
    return i+0;
}




# Find all occurences of a regular expression within a string, and return in an array.
# IN Line to match against.
# IN regex to match with.
# IN max = max occurences (0 = all)
# OUT matches is updated with (text=>num occurrences)
# RET total number of occurences.
function get_regex_counts(line,regex,max,matches) {
    return 0+get_regex_count_or_pos("c",line,regex,max,matches);
}
# Find all occurences of a regular expression within a string, and return in an array.
# IN mode : c=count matches  p=return match positions.
# IN Line to match against.
# IN regex to match with.
# IN max = max occurences (0 = all)
# OUT rtext is updated with (order=>match text)
# OUT rstart  is updated with (order -> start pos)
# RET total number of occurences.
function get_regex_pos(line,regex,max,rtext,rstart) {
    return 0+get_regex_count_or_pos("p",line,regex,max,rtext,rstart);
}


# Find all occurences of a regular expression within a string, and return in an array.
# IN mode : c=count matches  p=return match positions.
# IN Line to match against.
# IN regex to match with.
# IN max = max occurences (0 = all)
# mode=c:
# OUT rtext is updated with (mode=c:text=>num occurrences mode=p:order=>match text)
# mode=p:
# OUT rtext is updated with (order=>match text)
# OUT rstart  is updated with (order -> start pos)
# OUT total number of occurences.
function get_regex_count_or_pos(mode,line,regex,max,rtext,rstart,\
count,fcount,i,parts,start) {
    count =0 ;

    delete rtext;
    delete rstart;

    fcount = chop(line,regex,parts);
    start=1;
    for(i=2 ; i-fcount <= 0 ; i += 2 ) {
        count++;
        if (mode == "c") {
            rtext[parts[i]]++;
        } else {
            rtext[count] = parts[i];

            start += length(parts[i-1]);
            rstart[count] = start;
            start += length(parts[i]);
        }
        if (max+0 > 0 ) {
            if (count - max >= 0) {
                break;
            }
        }
    }

    dump(3,"get_regex_count_or_pos:"mode,rtext);

    return 0+count;
}

#Get highest quality imdb image by removing dimension info
function imdb_img_url(url) {
    sub(/\._S[XY][0-9]+_S[XY][0-9]+_/,"",url);
    return url;
}

# isection tracks sections found. This helps alert us to IMDB changes.
function scrape_imdb_line(line,imdbContentPosition,idx,f,isection,\
title,poster_imdb_url,i,sec,orig_country_pos,aka_country_pos,orig_title_country,aka_title_country) {


    if (imdbContentPosition == "footer" ) {
        return imdbContentPosition;
    } else if (imdbContentPosition == "header" ) {

        #Only look for title at this stage
        #First get the HTML Title
        if (index(line,"<title>")) {
            title = extractTagText(line,"title");
            DEBUG("Title found ["title "] current title ["gTitle[idx]"]");

            #extract right most year in title
            if (g_year[idx] == "" && match(title,".*\\("g_year_re)) {
                g_year[idx] = substr(title,RSTART+RLENGTH-4,4);
                DEBUG("IMDB: Got year ["g_year[idx]"]");
                delete isection[YEAR];
            }

            # Get the almost raw Imdb title. This may have ampersand which 
            # helps to differentiate shows. This is more important if
            # later on we need to # do a lookup from imdb back to a tvdatabase site eg
            # Brothers & Sisters != Brothers and Sisters.
            #
            # It is not so important when mapping filenames to tv shows. in that
            # case we need to be more flexible ( see expand_url() and similarTitles() )
            g_motech_title[idx]=tolower(title);
            gsub(/[^a-z0-9]+/,"-",g_motech_title[idx]);
            gsub(/-$/,"",g_motech_title[idx]);

            g_imdb_title[idx]=extract_imdb_title_category(idx,title);

            if (adjustTitle(idx,g_imdb_title[idx],"imdb")) {
                gOriginalTitle[idx] = gTitle[idx];
            }
            sec=TITLE;
        }
        if (index(line,"pagecontent")) {
            imdbContentPosition="body";
        }

    } else if (imdbContentPosition == "body") {

        if (index(line,">Company:")) {

            DEBUG("Found company details - ending");
            imdbContentPosition="footer";

        } else {

            #This is the main information section

            if ((i=index(line,"a name=\"poster\"")) > 0) {
                poster_imdb_url = extractAttribute(substr(line,i-1),"img","src");
                if (poster_imdb_url != "") {

                    #Save it for later. 
                    g_imdb_img[idx]=imdb_img_url(poster_imdb_url);
                    DEBUG("IMDB: Got imdb poster ["g_imdb_img[idx]"]");
                }
                sec=POSTER;
            }
            if (g_actors[idx] == "" && index(line,">Cast")) {
                g_actors[idx] = get_names("actors",raw_scrape_until("actors",f,"</table>",0),g_max_actors);
                g_actors[idx] = imdb_list_shrink(g_actors[idx],",",128);
                sec=ACTORS;
            }
            if (g_director[idx] == "" && index(line,">Director")) {
                g_director[idx] = get_names("actors",raw_scrape_until("director",f,"</div>",0),g_max_directors);
                g_director[idx] = imdb_list_shrink(g_director[idx],",",128);
                sec=DIRECTOR;
            }
            if (g_writers[idx] == "" && index(line,">Writer")) {
                g_writers[idx] = get_names("actors",raw_scrape_until("writers",f,"</div>",0),g_max_writers);
                g_writers[idx] = imdb_list_shrink(g_writers[idx],",",128);
                sec=WRITERS;
            }

            if (g_plot[idx] == "" && index(line,"Plot:")) {
                set_plot(idx,g_plot,scrape_until("iplot",f,"</div>",0));
                sub(/\|.*/,"",g_plot[idx]);
                sub(/[Ff]ull ([Ss]ummary|[Ss]ynopsis).*/,"",g_plot[idx]);
                #DEBUG("imdb plot "g_plot[idx]);
               sec=PLOT;
            }

            #IMDB Genre takes precedence
            if (g_genre[idx] == "" && index(line,"Genre:")) {

                g_genre[idx]=trimAll(scrape_until("igenre",f,"</div>",0));
                DEBUG("Genre=["g_genre[idx]"]");
                sub(/ +[Ss]ee /," ",g_genre[idx]);
                sub(/ +[Mm]ore */,"",g_genre[idx]);
               sec=GENRE;
            }
            if (g_runtime[idx] == "" && index(line,"Runtime:")) {
                g_runtime[idx]=trimAll(scrape_until("irtime",f,"</div>",1));
                if (match(g_runtime[idx],"[0-9]+")) {
                    g_runtime[idx] = substr(g_runtime[idx],RSTART,RLENGTH);
                }
               sec=RUNTIME;
            }

            # Always overwrite tvdb ratings with imdb ones.
            if (index(line,"/10</b>") && match(line,"[0-9.]+/10") ) {
                g_rating[idx]=0+substr(line,RSTART,RLENGTH-3);
               DEBUG("IMDB: Got Rating = ["g_rating[idx]"]");
               sec=RATING;
            }
            if (index(line,"certificates")) {

                scrapeIMDBCertificate(idx,line);
                sec=CERT;

            }
            # Title is the hardest due to original language titling policy.
            # Good Bad Ugly, Crouching Tiger, Two Brothers, Leon lots of fun!! 

            if (index(line,"Also Known")) DEBUG("AKA "gOriginalTitle[idx]" vs "gTitle[idx]);

            if (gOriginalTitle[idx] == gTitle[idx] && index(line,"Also Known As:")) {
                line = raw_scrape_until("aka",f,"</div>",1);

                DEBUG("AKA:"line);

                aka_title_country = scrapeIMDBAka(idx,line);
                sec=AKA;

            }

            if (index(line,"Country:")) {
                # There may be multiple countries. Only scrape the first one.
                orig_title_country = scrape_until("title",f,"</a>",1);
                orig_country_pos = index(g_settings["catalog_title_country_list"],orig_title_country);
                aka_country_pos = index(g_settings["catalog_title_country_list"],aka_title_country);

                if (orig_country_pos > 0 ) {
                    if (aka_title_country == "" ||  orig_country_pos <= aka_country_pos ) {
                        adjustTitle(idx,gOriginalTitle[idx],"imdb_orig"); 
                    }
                }
            }
        }
    } else {
        DEBUG("Unknown imdbContentPosition ["imdbContentPosition"]");
    }
    if (sec) delete isection[sec];
    return imdbContentPosition;
}

# name_db is always "actors"
# text = imdb text to be parsed for nm0000 ids.
# maxnames = max number of names to fetch ( -1 = all )
function get_names(name_db,text,maxnames,\
dtext,dpos,dnum,i,id,name,dlist,count,img) {
    # Extract nm0000 text OR anchor text(actor name) OR jpg url
    dnum = get_regex_pos(text,"(/nm[0-9]+|>[^<]+</a>|"g_nonquote_regex"+\\.jpg)",0,dtext,dpos);
    for(i = 1 ; i <= dnum ; i++ ) {
        #INF(name_db"["dtext[i]"]");

        if (dtext[i] ~ "jpg$") {

            img = imdb_img_url(dtext[i]);

        } else if (substr(dtext[i],1,3) == "/nm" ) {

            id=substr(dtext[i],2);

        } else if (id ) {
            if (index(dlist,","id) == 0) {
                count++;
                if (maxnames+0 >= 0 && count+0 > maxnames+0) {
                    break;
                }
                # Extract name from <a> tag
                name=extractTagText("<a"dtext[i],"a");
                dlist=dlist ","id;
                print id"\t"name > g_tmp_dir"/"name_db".db."PID  ;

                INF(name_db"|"id"|"name"|"img);

                # Seems to have a lot of portraits
                if (img == "") {
                    img = "http://www.turkcealtyazi.org/film/images/"id".jpg";
                    # http://ownfilmcollection.com/ERaImage/DCimages/name/nm2652511.jpg
                }

                get_image(id,img,APPDIR"/db/global/_A/"g_settings["catalog_poster_prefix"] id".jpg");
            }
            id="";
            img="";
        }
    }
    #INF(name_db":"dlist);
    return substr(dlist,2);
}

function get_image(id,url,file,\
ret) {
    ret = 0;
    if (url && GET_PORTRAITS && !(id in g_portrait)) {
        if (UPDATE_PORTRAITS || !hasContent(file) ) {
            if (preparePath(file) == 0) {
                g_portrait[id]=1;
                #ret = exec("wget -o /dev/null -O "qa(file)" "qa(url));
                ret = exec(APPDIR"/bin/jpg_fetch_and_scale "g_fetch_images_concurrently" "PID" actor "qa(url)" "qa(file)" "g_wget_opts" -U \""g_user_agent"\" &");
            }
        }
    }
    return ret;
}

function extract_imdb_title_category(idx,title\
) {
    # semicolon,quote,quotePos,title2
    #If title starts and ends with some hex code ( &xx;Name&xx; (2005) ) extract it and set tv type.
    g_category[idx]="M";
    DEBUG("imdb title=["title"]");
    if (match(title,"^\".*\"") ) {
        title=substr(title,RSTART+1,RLENGTH-2);
        g_category[idx]="T";
    }

    #Remove the year
    gsub(/ \((19|20)[0-9][0-9](\/I|)\) *(\([A-Z]+\)|)$/,"",title);

    DEBUG("Imdb title = ["title"]");
    return title;
}

# Looks for matching country in AKA section. The first match must simply contain (country)
# If it contains any qualifications then we stop looking at any more matches and reject the 
# entire section.
# This is because IMDB lists AKA in order of importance. So this helps weed out false matches
# against alternative titles that are further down the list.

function scrapeIMDBAka(idx,line,\
akas,a,c,bro,brc,akacount,country) {

    if (gOriginalTitle[idx] != gTitle[idx] ) return ;

    bro="(";
    brc=")";

    akacount = split(de_emphasise(line),akas,"<br>");

    dump(0,"AKA array",akas);

    for(a = 1 ; a <= akacount ; a++ ) {
        akas[a] = remove_tags(akas[a]);
        DEBUG("Checking aka ["akas[a]"]");
        for(c in gTitleCountries ) {
            if (index(akas[a], gTitleCountries[c])) {
                if (match(akas[a], "- .*\\<"gTitleCountries[c]":")) {
                    #We hit a matching AKA country but it has some kind of qualification
                    #which suggest that weve already passed a better match - ignore rest of section.
                    # eg USA (long title)
                    DEBUG("Ignoring aka section");
                    return;
                }
                if (match(akas[a],"- .*\\<" gTitleCountries[c] "\\>")) {
                    #We hit a matching AKA country ...
                    if (match(akas[a],"longer version|season title|poster|working|literal|IMAX|promotional|long title|short title|rerun title|script title|closing credits|informal alternative|Spanish title|video box title")) {
                        #the qualifications again suggest that weve already passed a better match
                        # ignore rest of section.
                        DEBUG("Ignoring aka section");
                        return;
                    }
                    #Use first match from AKA section 
                    if (match(akas[a],"\".*\" -")) {
                        country=gTitleCountries[c];
                        adjustTitle(idx,clean_title(substr(akas[a],RSTART+1,RLENGTH-4)),"imdb_aka"); 
                    }
                    return country;
                }
            }
        }
    }
}

function scrapeIMDBCertificate(idx,line,\
l,cert_list,certpos,cert,c,total,i,flag) {

    flag="certificates=";

    #Old style  -- <a href="/List?certificates=UK:15&&heading=14;UK:15">
    total = get_regex_pos(line, flag"[^&\"]+",0,cert_list,certpos);

    for(i = 1 ; i - total <= 0 ; i++ ){

        l = substr(cert_list[i],index(cert_list[i],flag)+length(flag));

        split(l,cert,"[:|]");

        #Now we only want to assign the certificate if it is in our desired list of countries.
        for(c = 1 ; (c in gCertificateCountries ) ; c++ ) {
            if (gCertCountry[idx] == gCertificateCountries[c]) {
                #Keep certificate as this country is early in the list.
                return;
            }
            if (cert[1] == gCertificateCountries[c]) {
                #Update certificate
                gCertCountry[idx] = cert[1];

                gCertRating[idx] = toupper(cert[2]);
                gsub(/%20/," ",gCertRating[idx]);
                DEBUG("IMDB: set certificate ["gCertCountry[idx]"]["gCertRating[idx]"]");
                return;
            }
        }
    }
}



# start_text = csv list of tokens to be matched in sequence before we extract the item
# start_include = include line that matched the last start token if true
# end_text = last line of the extracted item
# end_include = include line that matched the end_text if true
# cache = store in cache
function scrape_one_item(label,url,start_text,start_include,end_text,end_include,cache,\
f,line,out,found,tokens,token_count,token_i) {
    #DEBUG("scrape_one_item "label" start at ["start_text"]");
    f=getUrl(url,label,cache);

    token_count = split(start_text,tokens,",");
    if (f) {
        token_i = 1;
        while(enc_getline(f,line) > 0 ) {
            # eat up start tokens
            if (token_i - token_count <= 0 ) {
                if (match(line[1],tokens[token_i])) {
                    INF("matched token ["tokens[token_i]"]");
                    token_i++;
                }
            }
            if (token_i - token_count > 0 ) {
                # Now parse the item we want
                out = scrape_until(label,f,end_text,end_include);
                if (start_include) {
                    #DEBUG("scrape_one_item line = "line[1]);
                    out = remove_tags(line[1]) out;
                    #DEBUG("scrape_one_item out = "out);
                }
                found = 1;
                break;
            }
        }
        enc_close(f);
    }
    if (found != 1) {
        ERR("Cant find ["start_text"] in "label":"url);
    }
    #DEBUG("scrape_one_item "label" out ["out"]");
    return out;
}

function isreg(t) {
    if (index(t,"\\<")) return 1;
    gsub(/\\./,"",t);
    return match(t,"[][().|$^+*]");
}
function scrape_until(label,f,end_text,inclusive) {
    
    return trim(remove_tags(raw_scrape_until(label,f,end_text,inclusive)));
}
function raw_scrape_until(label,f,end_text,inclusive,\
line,out,ending,isre) {
    ending = 0;
    isre = isreg(end_text);
    #DEBUG("isreg["end_text"] = "isre);


    while(!ending && enc_getline(f,line) > 0) {
        if (isre) {
            ending =match(line[1],end_text);
        } else {
            ending =index(line[1],end_text);
        }
        if (!ending || inclusive) {
            out = out " " line[1];
        }
    }
    gsub(/ +/," ",out);
    out =remove_html_section(out,"script");
    out =remove_html_section(out,"style");
    #INF("raw_scrape_until "label"/"end_text":=["out"]");
    return out;
}

# remove javascript or embedded css.
function remove_html_section(input,tag,\
out,tag_start,tag_end,start_pos,end_pos,tail) {

    out=input ;

    tag_start="<"tag;

    tag_end="</"tag">";

    while((start_pos=index(out,tag_start)) > 0) {
        tail="";
        end_pos=index(out,tag_end);
        if (end_pos > 0 ) {
            tail = substr(out,end_pos+length(tag)+3);
        }
        #INF("removing "substr(out,start_pos,end_pos-start_pos));
        out = substr(out,1,start_pos-1) tail;
    }
    return out;
}


function relocating_files(i) {
    return (RENAME_TV == 1 && g_category[i] == "T") ||(RENAME_FILM==1 && g_category[i] == "M");
}

function relocate_files(i,\
newName,oldName,nfoName,oldFolder,newFolder,fileType,epTitle) {

   DEBUG("relocate_files");

    newName="";
    oldName="";
    fileType="";
    if (RENAME_TV == 1 && g_category[i] == "T") {

        oldName=g_fldr[i]"/"g_media[i];
        newName=g_settings["catalog_tv_file_fmt"];
        newName = substitute("SEASON",g_season[i],newName);
        newName = substitute("EPISODE",g_episode[i],newName);
        newName = substitute("INF",gAdditionalInfo[i],newName);

        epTitle=gEpTitle[i];
        gsub("[^-" g_alnum8 ",. ]","",epTitle);
        gsub(/[{]EPTITLE[}]/,epTitle,newName);

        newName = substitute("EPTITLE",epTitle,newName);
        newName = substitute("0SEASON",sprintf("%02d",g_season[i]),newName);
        newName = substitute("0EPISODE",pad_episode(g_episode[i]),newName);

        fileType="file";

    } else if (RENAME_FILM==1 && g_category[i] == "M") {

        oldName=g_fldr[i];
        newName=g_settings["catalog_film_folder_fmt"];
        fileType="folder";

    } else {
        return;
    }
    # TODO there seems to be a bug here. Why are following settings only applied
    # if name has changed at this point ?
    if (newName != "" && newName != oldName) {

        oldFolder=g_fldr[i];

        if (fileType == "file") {
            newName = substitute("NAME",g_media[i],newName);
            if (match(g_media[i],"[.][^.]+$")) {
                #DEBUG("BASE EXT="g_media[i] " AT "RSTART);
                newName = substitute("BASE",substr(g_media[i],1,RSTART-1),newName);
                newName = substitute("EXT",substr(g_media[i],RSTART),newName);
            } else {
                #DEBUG("BASE EXT="g_media[i] "]");
                newName = substitute("BASE",g_media[i],newName);
                newName = substitute("EXT","",newName);
            }
        }
        newName = substitute("DIR",g_fldr[i],newName);
        newName = substitute("TITLE",gTitle[i],newName);
        newName = substitute("YEAR",g_year[i],newName);
        newName = substitute("CERT",gCertRating[i],newName);
        newName = substitute("GENRE",g_genre[i],newName);

        #Remove characters windows doesnt like
        gsub(/[\\:*\"<>|]/,"_",newName); #"

        newName = clean_path(newName);

        if (newName != oldName) {
           if (fileType == "folder") {
               if (moveFolder(i,oldName,newName) != 0) {
                   return;
               }

               delete gMovieFilePresent[oldName];
               gMovieFilePresent[newName]=i;

               g_file[i]="";
               g_fldr[i]=newName;
           } else {

               # Move media file
               if (moveFileIfPresent(oldName,newName) != 0 ) {
                   return;
               }

               delete gMovieFilePresent[oldName];
               gMovieFilePresent[newName]=i;

               g_fldrMediaCount[g_fldr[i]]--;
               g_file[i]=newName;

               newFolder=newName;
               sub(/\/[^\/]+$/,"",newFolder);

               #Update new folder location
               g_fldr[i]=newFolder;

               g_media[i]=newName;
               sub(/.*\//,"",g_media[i]);

               # Move nfo file
               DEBUG("Checking nfo file ["gNfoDefault[i]"]");
               if(is_file(gNfoDefault[i])) {

                   nfoName = newName;
                   sub(/\.[^.]+$/,"",nfoName);
                   nfoName = nfoName ".nfo";

                   if (nfoName == newName ) {
                       return;
                   }

                   DEBUG("Moving nfo file ["gNfoDefault[i]"] to ["nfoName"]");
                   if (moveFileIfPresent(gNfoDefault[i],nfoName) != 0) {
                       return;
                   }
                   if (!g_opt_dry_run) {

                       gDate[nfoName]=gDate[gNfoDefault[i]];
                       delete gDate[gNfoDefault[i]];

                       gNfoDefault[i] = nfoName;
                       DEBUG("Moved nfo file ["gNfoDefault[i]"]");
                   }
               }

               #Rename any other associated files (sub,idx etc) etc.
               rename_related(oldName,newName);

               #Move everything else from old to new.
               moveFolder(i,oldFolder,newFolder);
           }
        }

        INF("checking "qa(oldFolder));
        if (is_dir(oldFolder) ) {

            system("rmdir -- "qa(oldFolder)); # only remove if empty
        }

    } else {
        # Name unchanged
        if (g_opt_dry_run) {
            print "dryrun:\t"newName" unchanged.";
            print "dryrun:";
        } else {
            INF("rename:\t"newName" unchanged.");
        }
    }
}

function rm(x,quiet,quick) {
    removeContent("rm -f -- ",x,quiet,quick);
}
function rmdir(x,quiet,quick) {
    removeContent("rmdir -- ",x,quiet,quick);
}
function removeContent(cmd,x,quiet,quick) {

    if (changeable(x) == 0) return 1;

    if (!quiet) {
        INF("Deleting "x);
    }
    cmd=cmd qa(x)" 2>/dev/null ";
    if (quick) {
        return "(" cmd ") & ";
    } else {
        return "(" cmd " || true ) ";
    } 
}

function substitute(keyword,value,str,\
    oldStr,hold) {

    oldStr=str;
    if (index(value,"&")) {
        gsub(/[&]/,"\\\\&",value);
    }
    if (index(str,keyword)) {
        while(match(str,"[{][^{}]*:"keyword":[^{}]*[}]")) {
            hold=substr(str,RSTART,RLENGTH);
            if (value=="") {
                hold="";
            } else {
                sub(":"keyword":",value,hold);
                hold=substr(hold,2,length(hold)-2); #remove braces
            }
            str=substr(str,1,RSTART-1) hold substr(str,RSTART+RLENGTH);
        }
    }

    if ( oldStr != str ) {
        DEBUG("Keyword ["keyword"]=["value"]");
        DEBUG("Old path ["oldStr"]");
        DEBUG("New path ["str"]");
    }

    return str;
}

function rename_related(oldName,newName,\
    extensions,ext,oldBase,newBase) {
    split("jpg png srt idx sub nfo",extensions," ");

    oldBase = oldName;
    sub(/\....$/,".",oldBase);

    newBase = newName;
    sub(/\....$/,".",newBase);

    for(ext in extensions) {
        moveFileIfPresent(oldBase extensions[ext],newBase extensions[ext]);
    }

}

function preparePath(f) {
    f = qa(f);
    return system("if [ ! -e "f" ] ; then mkdir -p "f" && chown "OVERSIGHT_ID" "f"/.. &&  rmdir -- "f" ; fi");
}

#This is used to double check we are only manipulating files that meet certain criteria.
#More checks can be added over time. This is to prevent accidental moving of high level files etc.
#esp if the process has to run as root.
function changeable(f) {
    #TODO Expand to include only paths listed in scan list.

    #Check folder depth to avoid nasty accidents.
    if (index(f,"/tmp/") == 1) return 1;
    if (index(f,"/share/tmp/") == 1) return 1;

    if (!match(f,"/[^/]+/[^/]+/")) {
        WARNING("Changing ["f"] might be risky. please make manual changes");
        return 0;
    }
    return 1;
}

# 0 = OK or absent 1=BAD
function moveFileIfPresent(oldName,newName) {

    if (is_file(oldName)) {
        return moveFile(oldName,newName);
    } else {
        return 0;
    }
}

# 0 = OK 1=BAD or missing
function moveFile(oldName,newName,\
    new,old,ret) {

    if (changeable(oldName) == 0 ) {
        return 1;
    }
    new=qa(newName);
    old=qa(oldName);
    if (g_opt_dry_run) {
        if (match(oldName,gExtRegExAll) && is_file(oldName)) {
            print "dryrun: from "old" to "new;
        }
        return 0;
    } else {
    # INF("move file:\t"old" --> "new);
        if ((ret=preparePath(newName)) == 0) {
            ret = exec("mv "old" "new);
        }
       return 0+ ret;
   }
}

function isDvdDir(f) {
    return substr(f,length(f)) == "/";
}

#Moves folder contents.
function moveFolder(i,oldName,newName,\
    cmd,new,old,ret,err) {

   ret=1;
   err="";

   if (folderIsRelevant(oldName) == 0) {

       err="not listed in the arguments";

   } else if ( g_fldrCount[oldName] - 2*(isDvdDir(g_media[i])) > 0 ) {

       err= g_fldrCount[oldName]" sub folders";

   } else if (g_fldrMediaCount[oldName] - 1 > 0) {

       err = g_fldrMediaCount[oldName]" media files";

   } else if (changeable(oldName) == 0 ) {

       err="un changable folder";

   } else {
       new=qa(newName);
       old=qa(oldName);
       if (g_opt_dry_run) { 
           print "dryrun: from "old"/* to "new"/";
           ret = 0;
       } else if (is_empty(oldName) == 0) {
           INF("move folder:"old"/* --> "new"/");
           cmd="mkdir -p "new" ;  mv "old"/* "new" ; mv "old"/.[^.]* "new" ; rmdir "old;
           err = "unknown error";
           ret = exec(cmd);
           system("rmdir "old" 2>/dev/null" );
       }
   }
   if (ret != 0) {
       WARNING("folder contents ["oldName"] not renamed to ["newName"] : "err);
   }
   return 0+ ret;
}

function hasContent(f,\
tmp,err) {
    err = (getline tmp < f );
    if (err != -1) close(f);
    return (err == 1 );
}

function isnmt() {
    return 0+ is_file(NMT_APP_DIR"/MIN_FIRMWARE_VER");
}
function is_file(f,\
tmp,err) {
    err = (getline tmp < f );
    if (err == -1) {
        #DEBUG("["f"] doesnt exist");
    } else {
        close(f);
    }
    return (err != -1 );
}
function is_empty(d) {
    return system("ls -1A "qa(d)" | grep -q .") != 0;
}
function is_dir(f) {
    return 0+ test("-d",f"/.");
}
function is_file_or_folder(f,\
r) {
    r = (is_file(f) || is_dir(f));
    if (r == 0) WARNING(f" is neither file or folder");
    return r;
}

function test(t,f) {
    return system("test "t" "qa(f)) == 0;
}

#Write a .nfo file if one didnt exist. This will make it easier 
#to rebuild the DB_ARR at a later date. Esp if the file names are no
#longer appearing in searches.
function generate_nfo_file(nfoFormat,dbrow,\
movie,tvshow,nfo,dbOne,fieldName,fieldId,nfoAdded,episodedetails) {

    nfoAdded=0;
    if (g_settings["catalog_nfo_write"] == "never" ) {
        return;
    }
    parseDbRow(dbrow,dbOne);
    get_name_dir_fields(dbOne);

    if (dbOne[NFO] == "" ) return;

    nfo=getPath(dbOne[NFO],dbOne[DIR]);


    if (is_file(nfo) && g_settings["catalog_nfo_write"] != "overwrite" ) {
        DEBUG("nfo already exists - skip writing");
        return;
    }
    
    if (nfoFormat == "xmbc" ) {
        movie=","TITLE","ORIG_TITLE","RATING","YEAR","DIRECTOR","PLOT","POSTER","FANART","CERT","WATCHED","IMDBID","FILE","GENRE",";
        tvshow=","TITLE","URL","RATING","PLOT","GENRE","POSTER","FANART",";
        episodedetails=","EPTITLE","SEASON","EPISODE","AIRDATE",";
    }


    if (nfo != "" && !is_file(nfo)) {

        #sub(/[nN][Ff][Oo]$/,g_settings["catalog_nfo_extension"],nfo);

        DEBUG("Creating ["nfoFormat"] "nfo);

        if (nfoFormat == "xmbc") {
            if (dbOne[CATEGORY] =="M") {

                if (dbOne[URL] != "") {
                    dbOne[IMDBID] = extractImdbId(dbOne[URL]);
                }

                startXmbcNfo(nfo);
                writeXmbcTag(dbOne,"movie",movie,nfo);
                nfoAdded=1;

            } else if (dbOne[CATEGORY] == "T") {

                startXmbcNfo(nfo);
                writeXmbcTag(dbOne,"tvshow",tvshow,nfo);
                writeXmbcTag(dbOne,"episodedetails",episodedetails,nfo);
                nfoAdded=1;
            }
        } else {
            #Flat
            print "#Auto Generated NFO" > nfo;
            for (fieldId in dbOne) {
                if (dbOne[fieldId] != "") {
                    fieldName=g_db_field_name[fieldId];
                    if (fieldName != "") {
                        print fieldName"\t: "dbOne[fieldId] > nfo;
                    }
                }
            }
            nfoAdded=1;
        }
    }
    if(nfoAdded) {
        close(nfo);
        set_permissions(qa(nfo));
    }
}

function startXmbcNfo(nfo) {
    print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > nfo;
    print "<!-- #Auto Generated NFO by catalog.sh -->" > nfo;
}
#dbOne = single row of index.db
function writeXmbcTag(dbOne,tag,children,nfo,\
fieldId,text,attr,childTag) {
    print "<"tag">" > nfo;

    #Define any additional tag attributes here.
    attr["movie","id"]="moviedb=\"imdb\"";

    for (fieldId in dbOne) {

        text=dbOne[fieldId];

        if (text != "") {
            if (index(children,fieldId)) {
                childTag=gDbFieldId2Tag[fieldId];
                if (childTag != "") {
                    if (childTag == "thumb") {
#                       if (g_settings["catalog_poster_location"] == "with_media" ) {
#                            #print "\t<"childTag">file://"dbOne[DIR]"/"text"</"childTag">" > nfo;
#                            print "\t<"childTag">file://./"xmlEscape(text)"</"childTag">" > nfo;
#                        } else {
                            print "\t<!-- Poster location not exported catalog_poster_location="g_settings["catalog_poster_location"]" -->" > nfo;
                            print "\t<"childTag">"xmlEscape(text)"</"childTag">" > nfo;
#                        }
                    } else {
                        if (childTag == "watched" ) text=((text==1)?"true":"false");
                        print "\t<"childTag" "attr[tag,childTag]">"xmlEscape(text)"</"childTag">" > nfo;
                    }
                }
            }
        }
    }
    print "</"tag">" > nfo;
}

function xmlEscape(text) {
    gsub(/[&]/,"\\&amp;",text);
    gsub(/</,"\\&lt;",text);
    gsub(/>/,"\\&gt;",text);
    return text;
}

# Some times epguides and imdb disagree. We only give a title if both are the same.
#
function fixTitles(idx,\
t) {

    t = gTitle[idx];
    # If no title set - just use the filename
    if (t == "") {
        t = g_media[idx];
        sub(/\/$/,"",t);
        sub(/.*\//,"",t); #remove path
        t = remove_format_tags(t);
        gsub("[^" g_alnum8 "]"," ",t); #remove odd chars
        DEBUG("Setting title to file["t"]");
    }

    gTitle[idx]=clean_title(t);
}

function file_time(f) {
    if (f in gDate) {
        return gDate[f];
    } else {
        return "";
    }
}

# changes here should be reflected in db.c:write_row()
function createIndexRow(i,db_index,watched,locked,index_time,\
row,est,nfo,op,start) {

    # Estimated download date. cant use nfo time as these may get overwritten.
    est=file_time(g_fldr[i]"/unpak.log");
    if (est == "") {
        est=file_time(g_fldr[i]"/unpak.txt");
    }
    if (est == "") {
        est = g_file_time[i];
    }

    if (g_file[i] == "" ) {
        g_file[i]=getPath(g_media[i],g_fldr[i]);
    }
    g_file[i] = clean_path(g_file[i]);

    if ((g_file[i] in g_fldrCount ) && g_fldrCount[g_file[i]]) {
        DEBUG("Adjusting file for video_ts");
        g_file[i] = g_file[i] "/";
    }

    op="update";
    if (db_index == -1 ) {
        db_index = ++gMaxDatabaseId;
        op="add";
    }
    row="\t"ID"\t"db_index;
    INF("dbrow "op" ["db_index":"g_file[i]"]");

    row=row"\t"CATEGORY"\t"g_category[i];

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
    row=row"\t"TITLE"\t"gTitle[i];
    if (gOriginalTitle[i] != "" && gOriginalTitle[i] != gTitle[i] ) {
        row=row"\t"ORIG_TITLE"\t"gOriginalTitle[i];
    }
    if (g_season[i] != "") row=row"\t"SEASON"\t"g_season[i];

    row=row"\t"RATING"\t"g_rating[i];

    if (g_episode[i] != "") row=row"\t"EPISODE"\t"g_episode[i];

    row=row"\t"GENRE"\t"short_genre(g_genre[i]);
    row=row"\t"RUNTIME"\t"g_runtime[i];

    if (gParts[i]) row=row"\t"PARTS"\t"gParts[i];

    row=row"\t"YEAR"\t"short_year(g_year[i]);

    start=1;
    if (index(g_file[i],g_mount_root) == 1) {
        start += length(g_mount_root);
    }
    row=row"\t"FILE"\t"substr(g_file[i],start);

    if (gAdditionalInfo[i]) row=row"\t"ADDITIONAL_INF"\t"gAdditionalInfo[i];


    if (g_imdb[i] == "") {
        # Need to have some kind of id for the plot.
        g_imdb[i]=g_tvid_plugin[i]"_"g_tvid[i];
        if (g_imdb[i] == "") {
            # Need to have some kind of id for the plot.
            g_imdb[i]="ovs"PID"_"systime();
        }
    }
    row=row"\t"URL"\t"g_imdb[i];

    row=row"\t"CERT"\t"gCertCountry[i]":"gCertRating[i];
    if (g_director[i]) row=row"\t"DIRECTOR"\t"g_director[i];
    if (g_actors[i]) row=row"\t"ACTORS"\t"g_actors[i];
    if (g_writers[i]) row=row"\t"WRITERS"\t"g_writers[i];

    row=row"\t"FILETIME"\t"shorttime(g_file_time[i]);
    row=row"\t"DOWNLOADTIME"\t"shorttime(est);
    #row=row"\t"SEARCH"\t"g_search[i];
    #row=row"\t"PROD"\t"gProdCode[i]; #todo remove without affecting load loop in oversight.cgi


    if (gAirDate[i]) row=row"\t"AIRDATE"\t"gAirDate[i];

    #row=row"\t"TVCOM"\t"gTvCom[i];
    if (gEpTitle[i]) row=row"\t"EPTITLE"\t"gEpTitle[i];
    nfo="";

    if (g_settings["catalog_nfo_write"] != "never" || is_file(gNfoDefault[i]) ) {
        nfo=gNfoDefault[i];
        gsub(/.*\//,"",nfo);
    }
    if (is_file(g_fldr[i]"/"nfo)) {
        row=row"\t"NFO"\t"nfo;
    }
    if (g_conn_follows[i]) row=row"\t"CONN_FOLLOWS"\t"g_conn_follows[i];
    if (g_conn_followed_by[i]) row=row"\t"CONN_FOLLOWED"\t"g_conn_followed_by[i];
    if (g_conn_remakes[i]) row=row"\t"CONN_REMAKES"\t"g_conn_remakes[i];
    return row;
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

# IN indexToMergeHash - hash whose indexes are the items we want to add during this iteration.
# IN output_file = Name of the database
# IN db_size = Size of the database
# IN added_to_db - index=file value=idx
function add_new_scanned_files_to_database(indexToMergeHash,output_file,\
i,row,f) {

    report_status("New Records: " hash_size(indexToMergeHash));

    gMaxDatabaseId++;

    for(i in indexToMergeHash) {

        f=g_media[i];

        if (g_media[i] == "") continue;

        add_file(g_fldr[i]"/"g_media[i]);

        row=createIndexRow(i,-1,0,0,"");
        if (length(row) - g_max_db_len < 0) {

            print row"\t" >> output_file;

            # Plots are added to a seperate file.
            update_plots(g_plot_file,i);
        }

        # If plots need to be written to nfo file then they should 
        # be added to the row at this point.
        row = row "\t"PLOT"\t"g_plot[i];
        generate_nfo_file(g_settings["catalog_nfo_format"],row);
    }
    close(output_file);
}

function ascii8(s) {
    return s ~ "["g_8bit"]";
}

#ALL# #set up accent translations
#ALL# function accent_init(\
#ALL# asc7,asc8,c7,c8,i) {
#ALL#     if (!("Ï" in g_acc )) {
#ALL#         asc8="ŠŒŽšœžŸ¥µÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝßàáâãäåæçèéêëìíîïðñòóôõöøùúûüýÿ";
#ALL#                asc7="SOZsozYYuAAAAAAACEEEEIIIIDNOOOOOOUUUUYsaaaaaaaceeeeiiiionoooooouuuuyy";
#ALL#         for(i = 1 ; i <= length(asc8) ; i++ ) {
#ALL#             c7=substr(asc7,i,1)
#ALL#             c8=substr(asc8,i,1)
#ALL#             g_acc[c8] = c7;
#ALL#             g_acc[utf8_encode(c8)] = c7;
#ALL#         }
#ALL#     }
#ALL# }
#ALL# 
#ALL# #http://weblogtoolscollection.com/b2-img/convertaccents.phps
#ALL# function no_accent(s,\
#ALL# i,j,out,s1,s2) {
#ALL#     if (ascii7(s) == 0) {
#ALL#         accent_init();
#ALL#         for(i = 1 ; i <= length(s) ; i++ ) {
#ALL#             c=substr(s,i,1);
#ALL#             if ( c"" <= "~" ) {
#ALL#                 out = out c;
#ALL#             } else if ((c2=g_acc[c]) != "") {
#ALL#                 out = out c2;
#ALL#             } else if ((c2=g_acc[substr(s,i,2)]) != "") {
#ALL#                 out = out c2;
#ALL#                 i++;
#ALL#             } else {
#ALL#                 out = out "?";
#ALL#                 i++;
#ALL#             }
#ALL#                 
#ALL#             if ((j=index(s1,c)) > 0) {
#ALL#                 s = substr(s,1,i-1) substr(s2,i,1) substr(s,i+1);
#ALL#             }
#ALL#         }
#ALL#     }
#ALL#     return s;
#ALL# }

function update_plots(pfile,idx,\
id,key,cmd,cmd2,ep) {
    id=g_imdb[idx];

    if (id != "") {
        ep = g_episode[idx];
        INF("updating plots for "id"/"ep);

        key=qa(id)" "(g_category[idx]=="T"?qa(g_season[idx]):qa(""));

        cmd=g_plot_app" update "qa(pfile)" "key;

        if (g_plot[idx] != "" && !(key in g_updated_plots) ) {
            cmd2 = cmd" "qa("");
            #INF("updating main plot :"cmd2);
            exec(cmd2" "qa(g_plot[idx]));
            g_updated_plots[key]=1;
        }

        key=key" "qa(ep);
        if (g_category[idx] == "T" && g_epplot[idx] != "" && !(key in g_updated_plots) ) {
            cmd2 = cmd" "qa(ep);
            #INF("updating episode plot :"cmd2);
            exec(cmd2" "qa(g_epplot[idx]));
            g_updated_plots[key]=1;
        }
    }
}

function touch_and_move(x,y) {
    system("touch "qa(x)" ; mv "qa(x)" "qa(y));
}

#--------------------------------------------------------------------
# Convinience function. Create a new file to capture some information.
# At the end capture files are deleted.
#--------------------------------------------------------------------
function new_capture_file(label,\
    fname) {
    fname = CAPTURE_PREFIX JOBID  "." CAPTURE_COUNT "__" label;
    CAPTURE_COUNT++;
    return fname;
}

function clean_capture_files() {
    INF("Clean up");
    exec("rm -f -- "qa(CAPTURE_PREFIX JOBID) ".* 2>/dev/null");
}
function DEBUG(x) {
        
    if ( DBG ) {
        timestamp("[DEBUG]  ",x);
    }

}
function INF(x) {
    timestamp("[INFO]   ",x);
}
function WARNING(x) {
    timestamp("[WARNING]",x);
}
function ERR(x) {
    timestamp("[ERR]    ",x);
}
function DETAIL(x) {
    timestamp("[DETAIL] ",x);
}

# Remove spaces and non alphanum
function trimAll(str) {
    sub(g_punc[0]"$","",str);
    sub("^"g_punc[0],"",str);
    return str;
}

function trim(str) {
    sub(/^[- ]+/,"",str);
    sub(/[- ]+$/,"",str);
    return str;
}

function apply(text) {
    gsub(/[^A-Fa-f0-9]/,"",text);
    return text;
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
        } else if (ARGV[i] == "GET_POSTERS" )  {
            GET_POSTERS=1;
            moveDown++;
        } else if (ARGV[i] == "UPDATE_POSTERS" )  {
            UPDATE_POSTERS=1;
            GET_POSTERS=1;
            moveDown++;
        } else if (ARGV[i] == "GET_FANART" )  {
            GET_FANART=1;
            moveDown++;
        } else if (ARGV[i] == "UPDATE_FANART" )  {
            UPDATE_FANART=1;
            GET_FANART=1;
            moveDown++;
        } else if (ARGV[i] == "GET_PORTRAITS" )  {
            GET_PORTRAITS=1;
            moveDown++;
        } else if (ARGV[i] == "UPDATE_PORTRAITS" )  {
            UPDATE_PORTRAITS=1;
            GET_PORTRAITS=1;
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
    ARGC -= moveDown;
    # Add dev null as dummy input
    ARGV[ARGC++] = "/dev/null";
    return folderCount;
}

#baseN - return a number base n. All output bytes are offset by 128 so the characters will not 
#clash with seperators and other ascii characters.

function basen(i,n,\
out) {
    if (g_chr[32] == "" ) {
        decode_init();
    }
    while(i+0 > 0) {
        out = g_chr[(i%n)+128] out;
        i = int(i/n);
    }
    if (out == "") out=g_chr(128);
    return out;
}
#base10 - convert a base n number back to base 10. All input bytes are offset by 128
#so the characters will not clash with seperators and other ascii characters.
function base10(input,n,\
out,digits,ln,i) {
    if (g_chr[32] == "" ) {
        decode_init();
    }
    ln = split(input,digits,"");
    for(i = 1 ; i <= ln ; i++ ) {
        out = out *n + (g_ascii[digits[i]]-128);
    }
    if (out == "") out=0;
    return out+0;
}

function imdb_list_shrink(s,sep,base,\
i,n,out,ids,m,id) {
    n = split(s,ids,sep);
    for(i = 1 ; i <= n ; i++ ) {


        if (index(ids[i],"tt") == 1 || index(ids[i],"nm") == 1) {

            id = substr(ids[i],3);

            m = basen(id,base);

            out = out sep m ;
        } else {
            out = out sep ids[i] ;
        }
    }
    out = substr(out,2);
    INF("compress ["s"] = ["out"]");

    return out;
}
function imdb_list_expand(s,sep,base,\
i,n,out,ids,m) {
    n = split(s,ids,sep);
    for(i = 1 ; i <= n ; i++ ) {


        if (index(ids[i],"tt") == 0) {

            m = base10(ids[i],base);
            out = out sep "tt" sprintf("%07d",m) ;
        } else {
            out = out sep ids[i] ;
        }
    }
    out = substr(out,2);
    INF("expand ["s"] = ["out"]");
    return out;
}


function load_catalog_settings() {

    load_settings("",DEFAULTS_FILE);
    load_settings("",CONF_FILE);

    load_settings(g_country_prefix , COUNTRY_FILE);

    gsub(/,/,"|",g_settings["catalog_format_tags"]);
    gsub(/,/,"|",g_settings["catalog_ignore_paths"]);
    gsub(/,/,"|",g_settings["catalog_ignore_names"]);

    g_settings["catalog_ignore_names"]="^"glob2re(g_settings["catalog_ignore_names"])"$";

    g_settings["catalog_ignore_paths"]="^"glob2re(g_settings["catalog_ignore_paths"]);

    INF("ignore path = ["g_settings["catalog_ignore_paths"]"]");

    # Check for empty ignore path
    if ( "x" ~ "^"g_settings["catalog_ignore_paths"]"x$" ) {
        g_settings["catalog_ignore_paths"] = "^$"; #regex will only match empty path
        INF("ignore path = ["g_settings["catalog_ignore_paths"]"]");
    }

    #catalog_scene_tags = csv2re(tolower(catalog_scene_tags));

    #Search engines used for simple keywords+"imdb" searches.
    split(tolower(g_settings["catalog_search_engines"]),g_link_search_engines,g_cvs_sep);
}

function lang_test(idx) {
    scrape_es(idx);
    scrape_fr(idx);
    scrape_it(idx);
}

function first_result() {
    INF("first_result: not impleneted");
}
function get_director_name() {
    INF("get_director_name: not impleneted");
}
function scrape_es(idx,details,\
url) {
    delete details;
    url=first_result(url_encode("intitle:"gTitle[idx]" ("g_year[idx]")")"+"get_director_name(idx)"+"url_encode("inurl:http://www.filmaffinity.com/en"));
    if (sub("/en/","/es/",url)) {
        HTML_LOG(0,"es "url);
    }
}
function scrape_fr(idx,details,\
url) {
    delete details;
    url=first_result(url_encode("intitle:"gTitle[idx]" ("g_year[idx]")")"+"get_director_name(idx)"+"\
    url_encode("inurl:http://www.screenrush.co.uk")"+"\
    url_encode("inurlfichefilm_gen_cfilm"));
    if (sub("/screenrush.co.uk/","/allocine.fr/",url)) {
        HTML_LOG(0,"fr "url);
    }
}
function scrape_it(idx,details,\
url) {
    delete details;
    url=first_result(gTitle[idx]" "get_director_name(idx)" "url_encode("intitle:Scheda")"+"\
    url_encode("site:filmup.leonardo.it"));
    HTML_LOG(0,"it "url);
}
#ENDAWK
# vi:sw=4:et:ts=4
