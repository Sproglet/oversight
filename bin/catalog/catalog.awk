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

function TODO(x) {
    if(LG)DEBUG("TODO:"x);
}


function plugin_error(p) {
    ERR("Unknown plugin "p);
}

# Note we dont call the real init code until after the command line variables are read.
BEGIN {

    default_settings();
    load_catalog_settings();
    g_articles["en"]="\\<([Tt]he)\\>";
    g_articles["de"]="\\<(([Dd](er|ie|as|es|em|en))|([Ee]in(|e[rmn]?)))\\>";
    g_articles["nl"]="\\<([Dd]e|[Hh]et|[Ee]en)\\>";
    g_articles["es"]="\\<(Ee]l|[Ll]a|[Ll][oa]s|[Uu]n(|as?|os))\\>";
    g_articles["pt"]="\\<([OoAa]s?|[Uu]m(|as?)|[Uu]ns)\\>";
    g_articles["fr"]="\\<([Ll](|a|e?)|[Uu]ne?|[Dd]es|[Dd]u|[De] la?)\\>";
    g_articles["it"]="\\<([Ii]l?|[Ll][oae]?|[Gg]li|[Uu]n[oa]?|[Dd]el(|l[oae]?)|[Dd]ei|[Dd]egli)\\>";
    g_multpart_tags = "cd|disk|disc|part";
    g_max_plot_len=800;
    g_min_plot_len=90; # this is th eminimum length when scraping - not via api
    g_max_db_len=4000;
    g_path_depth=3;
    g_indent="";
    g_sigma="Σ"; # Tv rage uses Sigma in title like Greek - in place of the e.
    g_start_time = systime();
    g_thetvdb_web="http://www.thetvdb.com";
    g_tvrage_web="http://www.tvrage.com";
    g_tvrage_api="http://services.tvrage.com";

    g_dbtype_genre="g";
    g_dbtype_time="t";
    g_dbtype_year="y";
    g_dbtype_imdblist="i";
    g_dbtype_int="I";
    g_dbtype_string="s";
    g_dbtype_path="p";


    #Matches most english prose for plots / summary - cant use words that appear in other languages. of , it?
    # 'The' only counts if followed by lowecase. This allows its use in titles eg Edward the Longshanks?
    # Cant use 'man' as it is in Dutch an Swedish
    # Using word boundaries \<,\> does not seem to work reliably with binary(utf-8) strings, so punctualtion and spaces explicitly added.
    g_english_start_re="(^|[,.?! ])";
    g_english_end_re="([ .,!?]|$)";
    # there is some overlap between words and phrases - eg 'and' - this will be refined over time. Esp with Germanic languages some
    # short words may not be enough to distinguish
    g_english_words_re="([Ww]oman|girls?|boys?|family|group|[Ss]he|[Hh]e|from|who|what|where|when|how|with|his|and|for|are|[Tt]hey|their|them|attempt(|s|ed)|decides?|learns?|forced|offers|goes|plans?|wants?|tries|try|until|became|becomes?|lives?|life|have|after|before|must|plays?|years?|come|has|out|stops?|helps?|will|finds?|reali[sz]es?|that|into|falls|retrieve|[Ii]nvestigat(es?|ing)|a plot|[Ss]muggl(es?|ing)|to be|plan(s?|ning)|destroys?)"g_english_end_re;
    # Investigating / smuggling / planning / replaced with [[:lower:]]+[bcdfghj-np-tv-z]ing
    g_english_phrase_re="((in|to|by|for|is|on|as|of|and) (a|an|the|his|her|their|they|order)"g_english_end_re"|[Tt]he +[a-z])";
    g_english_re=g_english_start_re"("g_english_words_re"|"g_english_phrase_re")";

    g_tv_check_urls["tvrage"]=g_tvrage_web;
    g_tv_check_urls["thetvdb"]=g_thetvdb_web;

    g_cvs_sep=" *, *";
    g_opt_dry_run=0;
    yes="yes";
    no="no";

    g_8bit="�-�"; // range 0x80 - 0xff

    g_alnum8 = "[:alnum:]" g_8bit;

    # Remove any punctuation except quotes () [] {} - also keep high bit
    # Added Semicolon for titles such as Terminator:Sarah Connor Chronicles, Star Wars: Clone Wars etc.
    g_punc[0]="[^][}{&#()'!:?" g_alnum8 "-]+";
    # Remove any punctuation except quotes () - also keep high bit
    g_punc[1]="[^&'!?()"g_alnum8"-]+";
    # Remove any punctuation except quotes () - also keep high bit
    g_punc[2]="[^&'!?"g_alnum8"-]+";

    g_nonquote_regex = "[^\"']";

    #g_imdb_regex="\\<tt[0-9]+\\>";
    g_imdb_regex="tt[[:digit:]]{5,7}"; #bit better performance

    g_year_re="(20[01][0-9]|19[0-9][0-9])";
    g_imdb_title_re="[[:upper:][:digit:]"g_8bit"]["g_alnum8"& '.]*[ (.]"g_year_re"[).]?";

    g_roman_regex="i|ii|iii|iv|v|vi|vii|viii|ix|x|xi|xii|xiii|xiv|xv";

    g_url_regex = "https?://[^\"'\\/]*"re_escape(site)"[^\"']+";


    split(g_roman_regex,g_roman,"[|]");
    hash_invert(g_roman,g_roman);

    ELAPSED_TIME=systime();
    GET_POSTERS=1;
    GET_FANART=1;
    GET_PORTRAITS=1;
    GET_BANNERS=1;

    UPDATE_POSTERS=0;
    UPDATE_FANART=0;
    UPDATE_PORTRAITS=0;
    UPDATE_BANNERS=0;

    g_db = 1; # true if db is updated - yes for oversight no for anything else.

    g_api_tvdb="A110A5718F912D21070AF";
    g_api_tmdb="2d51eee0579c36499df410b337edcdac1ae14";
    g_api_rage="fP8i46657c9qept4Mu554AHh7";
    g_api_bing="4C83349CD70CC9F6125EA40CACED1D950730533E97EA0";

    if(LD)DETAIL("$Id$");

    STANDALONE = !isnmt();

    get_folders_from_args(FOLDER_ARR);

    if(LI)INF("Mode="(STANDALONE?"STANDALONE":"OVERSIGHT"));

    if (STANDALONE) {
        # true if catalog.sh is running is a generic scraper.
        # info and images files are written to media location.
        # index.db is not built.
        # portraits are not downloaded.
        g_settings["catalog_nfo_write"] = "if_none_exists"; # WRITE_NFO
    }
}

function report_status(msg) {
    if (msg == "") {
        rm(g_status_file,1);
    } else {
        print msg > g_status_file;
        close(g_status_file);
        if(LD)DETAIL("status:"msg);
        set_permissions(g_status_file);
    }
}


END{


    g_state_file=OVS_HOME"/.state";

    load_state(g_state_file,g_state);

    if (!g_db) {
        # Running without oversight jukebox - switch off all poster fetching etc.
        GET_POSTERS = UPDATE_POSTERS = 0;
        GET_FANART = UPDATE_FANART = 0;
        GET_BANNERS = UPDATE_BANNERS = 0;
        GET_PORTRAITS = UPDATE_PORTRAITS = 0;
    }
    if(LD)DETAIL("g_db = "g_db);
    #path for actor db etc.
    DBDIR = OVS_HOME"/db";

    g_set_file=DBDIR"/set.db";

    print PROCINFO["pid"] > PIDFILE;
    close(PIDFILE);

    g_max_id_file = INDEX_DB".maxid";
    INDEX_DB_TMP = INDEX_DB "." JOBID ".tmp";
    INDEX_DB_NEW = INDEX_DB "." JOBID ".new";
    INDEX_DB_OLD = INDEX_DB "." DAY;

    g_user_agent="Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20040613 Firefox/0.8.0+";
    #g_user_agent="Opera/9.80 (Windows NT 6.0; U; en) Presto/2.8.99 Version/11.10";
    g_yahoo_user_agent="PHP/5.2.9"; # Stop yahoo doing weird stuff to links 

    g_iphone_user_agent="Mozilla/5.0 (iPhone; U; CPU iPhone OS 3_0 like Mac OS X; en-us) AppleWebKit/420.1 (KHTML, like Gecko) Version/3.0 Mobile/1A542a Safari/419.3";

    # Note keep timout above 30 seconds to allow for the DNS bug where first lookup takes 30 seconds
    # on some combinations of NMT/network and DNS server.
    g_wget_opts="-T 31 -t 2 -w 2 -q --no-check-certificate --ignore-length ";
    g_art_timeout=" -T 90";


    g_mount_root="/opt/sybhttpd/localhost.drives/NETWORK_SHARE/";
    g_winsfile = OVS_HOME"/conf/wins.txt";
    g_item_count = 0;


    g_plot_file=PLOT_DB;
    g_plot_file_queue=PLOT_DB".queue";
    g_plot_app=qa(OVS_HOME"/bin/plot.sh");

    for(gI in g_settings) {
        g_settings_orig[gI] = g_settings[gI];
    }

    g_db_lock_file=OVS_HOME"/catalog.lck";
    g_scan_lock_file=OVS_HOME"/catalog.scan.lck";
    g_status_file=OVS_HOME"/catalog.status";
    g_abc="abcdefghijklmnopqrstuvwxyz"; # slight rearrange - probably makes no diff
    g_ABC=toupper(g_abc);
    g_tagstartchar=g_ABC g_abc":_";

    report_status("scanning");

    g_lang_articles = g_articles[main_lang()];
    if(LD)DETAIL("Articles="g_lang_articles);


    g_max_actors=g_settings["catalog_max_actors"];
    g_max_directors = 3;
    g_max_writers = 3;

    split(tolower(g_settings["catalog_tv_plugins"]),g_tv_plugin_list,g_cvs_sep);

    if(LD)DETAIL("RENAME_TV="RENAME_TV);
    if(LD)DETAIL("RENAME_FILM="RENAME_FILM);

    set_db_fields();

    #Values for action field
    ACTION_NONE="0";
    ACTION_REMOVE="r";
    ACTION_DELETE_MEDIA="d";
    ACTION_DELETE_ALL="D";

    # underscores should also be treated as word boundaries.

    gTmp = tolower(g_settings["catalog_format_tags"]);

    # allow tag to be at beginning or end of a word.
    g_settings["catalog_format_tags"]="(((\\<|_)("gTmp"))|(("gTmp")(_|\\>)))";

    if(LD)DETAIL("catalog_format_tags="g_settings["catalog_format_tags"]);

    gExtList1="avi|divx|mkv|mp4|ts|m2ts|xmv|mpg|mpeg|mov|m4v|wmv";
    gExtList2="img|iso";

    gExtList1=tolower(gExtList1) "|" toupper(gExtList1);
    gExtList2=tolower(gExtList2) "|" toupper(gExtList2);

    gExtRegexIso="\\.("gExtList2")$";
    #if(LD)DETAIL(gExtRegexIso);

    gExtRegEx1="\\.("gExtList1")$";
    #if(LD)DETAIL(gExtRegEx1);

    gExtRegExAll="\\.("gExtList1"|"gExtList2")$";
    #if(LD)DETAIL(gExtRegExAll);

    g_months_short="Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec"
    monthHash(g_months_short,"|",gMonthConvert);

    g_months_long="January|February|March|April|May|June|July|August|September|October|November|December";
    monthHash(g_months_long,"|",gMonthConvert);
    split(g_months_long,g_month_en,"|");


    if ( g_settings["catalog_tv_file_fmt"] == "" ) RENAME_TV=0;
    if  ( g_settings["catalog_film_folder_fmt"] == "") RENAME_FILM=0;

    CAPTURE_PREFIX=g_tmp_dir"/catalog."

    #url_get("http://m.bing.com/search/search.aspx?A=webresults;D=Web;q=mission%20impossible%20ghost%20protocol%20+%2B+2011+imdb"); exit;
    #if(LD)DETAIL("noaccent:"no_accent("���������������������������������������������������������������������"));

    # Bing and yahoo are in the process of merging. I expect this means they will soon
    # start returning the same results. This will invalidate the searh voting.
    # A way around this is to skew one of the search results with other movie related keywords.
    # eg. subtitles or movie or download. or site:opensubtitles.org
    # ask is powered by google.
    # Another option is to search sites directly but thier search algorithms are usually too strict
    # with scoring each keyword.
    g_search_yahoo = "http://search.yahoo.com/search?ei=UTF-8;eo=UTF-8;p=";

    g_search_bing_desktop = "http://www.bing.com/search?q=";
    g_search_bing_api = "http://api.search.live.net/json.aspx?";
    g_search_bing = g_search_bing_desktop;

    g_search_bing2 = "http://www.bing.com/search?q=subtitles+";
    # Google must have &q= not ;q=
    g_search_google = "http://www.google.com/search?ie=utf-8;oe=utf-8;q=";
    g_search_google1 = "http://search.alot.com/web?q=";

    g_search_mysterbin = "http://www.mysterbin.com/search?q=";
    g_search_nzbindex = "http://www.nzbindex.nl/rss/?q=";
    g_search_binsearch = "http://binsearch.info/?max=25&adv_age=&q=";
    g_search_nzbclub = "http://www.nzbclub.com/nzbfeed.aspx?q=";

    g_themoviedb_api_url = "http://api.themoviedb.org/3";

    # Following search engines are used in round robi,=n
    g_search_engine[0]=g_search_bing_desktop;
    g_search_engine[1]=g_search_yahoo;

    #g_search_engine[2]=g_search_ask; results too similar to google giving false +ves.
    g_search_engine_count=hash_size(g_search_engine);
    g_search_engine_current=0;

    engine_check(g_search_google);
    engine_check(g_search_bing);
    engine_check(g_search_yahoo);

    THIS_YEAR=substr(NOW,1,4);

    unit(1);

    # Process folders in reverse order. This is in the hope that a last episode gives a little
    # more chance of correctly identifying a season of a remake show.
    scan_options="-Rl";
    if (g_settings["catalog_follow_symlinks"]==1) {
        scan_options= scan_options"L";
    }

    if (RESCAN == 1 || NEWSCAN == 1) {
        if (!(1 in FOLDER_ARR)) {
            # Get default folder list

            if (NEWSCAN == 1) {
                # Get watch folders only
                if(LD)DETAIL("Scanning watch paths");
                folder_list=g_settings["catalog_watch_paths"];
            } else {
                # Get all folders only
                if(LD)DETAIL("Scanning default and watch paths");
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
                if(LD)DETAIL("Scan already in progress");
                exit;
            }
        }
    }

    g_timestamp_file=OVS_HOME"/.lastscan";


    replace_share_names(FOLDER_ARR);

    make_paths_absolute(FOLDER_ARR);

    for(gF in FOLDER_ARR) {
        if(LD)DETAIL("Folder "gF"="FOLDER_ARR[gF]);
    }

    gLS_FILE_POS=0; # Position of filename in ls format
    gLS_TIME_POS=0; # Position of timestamp is ls format
    findLSFormat();

    #plugin_check();

    gMovieFileCount = 0;
    gMaxDatabaseId = 0;

    g_api_tvdb = apply(g_api_tvdb);
    g_api_tmdb = apply(g_api_tmdb);
    g_api_rage = apply(g_api_rage);
    g_api_bing = apply(g_api_bing);

    if (EXPORT_XML) {
        if (FOLDER_ARR[1] != "") {
            export_xml(FOLDER_ARR[1]);
        } else {
            export_xml(INDEX_DB);
        }
    } else {
        if (hash_size(FOLDER_ARR)) {

            g_grand_total = scan_folder_for_new_media(FOLDER_ARR,scan_options);

            delete g_updated_plots;


            et=systime()-ELAPSED_TIME;

            if(LI)INF(sprintf("Finished: Elapsed time %dm %ds",int(et/60),(et%60)));

            #Check script
            for(gI in g_settings) {
                if (!(gI in g_settings_orig)) {
                    WARNING("Undefined setting "gI" referenced");
                }
            }

        }
    }

    clean_capture_files();

    rm(g_status_file);


    if (RESCAN == 1 || NEWSCAN == 1) {
        print "last scan at " strftime(systime()) > g_timestamp_file;
        close(g_timestamp_file);
        unlock(g_scan_lock_file);
    }
    if (g_db && g_grand_total) {
        if (lock(g_db_lock_file,1)) {
            #if we cant get the lock assume other task will prune anyway.
            remove_absent_files_from_new_db(INDEX_DB);
            system(g_plot_app" compact "qa(g_plot_file)" "qa(INDEX_DB));
            unlock(g_db_lock_file);
        }
    }
    rm(PIDFILE);

    if (g_grand_total) {
        g_f = g_settings["catalog_touch_file"];
        if (g_f != "") {
            touch(g_f);
        }
    }
    #Following line is used to tidy log files
    if(LD)DETAIL("Total files added : "g_grand_total);

    url_stats();
}

function replace_share_name(indir,\
out,share_name) {
    out = indir;
    if (out ~ /^[^\/.]/  ) {
        # Assume it is a share
        share_name=out;
        sub(/\/.*/,"",share_name);

        if (!(share_name in g_share_name_to_folder)) {
            g_share_name_to_folder[share_name] = nmt_mount_share(share_name,g_tmp_settings);
            if(LD)DETAIL("share name "share_name" = "g_share_name_to_folder[share_name]);
        }
        if (g_share_name_to_folder[share_name]) {

            g_share_map[out] = share_name;
            out = nmt_get_share_path(out);

        } else if (START_DIR != "/share/Apps/oversight" && is_file_or_folder(START_DIR"/"out)) {
            out = START_DIR"/"out;
        } else {
            WARNING(out" not a share or file");
            out = "";
        }
    }
    return out;
}

function replace_share_names(folders,\
f) {
    if (isnmt()) {
        #If a pth does not begin with . or / then check if the first part is the 
        #name of an NMT network_share. If so - replace with the share path.
        for(f in folders) {
            folders[f] = replace_share_name(folders[f]);
            if (folders[f] == "") {
                delete folders[f];
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
        if (getUrl(g_tv_check_urls[plugin],"test.xml",0) == "" ) {
            WARNING("Removing plugin "plugin);
            delete g_tv_plugin_list[p];
        }
    }
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

function long_path(path) {
    if (path !~ /^\//  && isnmt() ) {
        path = g_mount_root path;
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
    #if(LG)DEBUG("already seen "path);
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
        return OVS_HOME"/db/global/"substr(name,5);
    } else {
        #Other paths are relative to video folder.
        return localPath"/"name;
    }
}

function re_escape(s) {
    gsub("[][*.{}()+]","\\\\&",s);
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
    name=minfo[NAME];
    if(name !~ "/$") {
        # remove extension
        sub(/\.[^.\/]+$/,"",name);
        # name=remove_format_tags(name);

        # no point in removing the CD parts as this makes binsearch more inaccurate

        #    if (minfo[PARTS] != "" ) {
        #        #remove  part qualifier xxxx1 or xxxxxa
        #        sub(/(|cd|part)[1a]$/,"",name);
        #    }
    }
    name=trimAll(name);
    return name;
}

# Check we havent set any bad fields in movie information array
function verify(minfo,\
ret,f,numok,numbad) {

    id1("verify");
    ret=1;
    for (f in minfo) {
        if (!(f in g_db_field_name) && f !~ /_source$/ && f != "mi_do_scrape" && f != "mi_multipart_tag_pos" ) {
            ERR("bad field ["f"] = ["minfo[f]"]");
            numbad++;
        }  else {
            if (match(f,"^mi_[[:lower:]]+_(names|ids)$")  && index(minfo[f],"@") == 0) {
                #format should be domain@id1@id2@.. or domain@name1@name2@..
                #eg imdb@nm0000123@nm0000456 or allocine@Sean Connery@Roger Moore@
                ERR("bad format field ["f"] = ["minfo[f]"]");
                numbad++;
            } else {
                #if(LD)DETAIL("ok field ["f"] = ["minfo[f]"]");
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
        gsub(/[&][[:lower:]]+;/,"",line);
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
    #dump(0,"getMax",arr);
    for(i in arr) {
        if (arr[i]-best >= 0 ) {
            nextBest = best;
            nextBestName = maxName;
            best = threshold = arr[i]+0;
            maxName = i;

        } else if (arr[i]-nextBest >= 0 ) {

            nextBest = arr[i]+0;
            nextBestName = i;
        }
    }

    if (0+best < 0+requiredThreshold ) {
        if(LG)DEBUG("getMax: Rejected "maxName":"best" as does not meet requiredThreshold of "requiredThreshold);
        maxName = "";

    }
    if (requireDifferenceSquared ) {

        diff=best-nextBest;
        if (diff * diff < best ) {

            if(LG)DEBUG("getMax: rejected "maxName":"best" too close to next best "nextBestName":"nextBest" to be certain");
            maxName = "";

        }
    }
    if(LG)DEBUG("getMax: best=["maxName":"(maxName?arr[maxName]:"")"]");
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
        scan_page_for_match_counts(g_search_yahoo keywords,"tt",g_imdb_regex,0,0,matchList);
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

    if(LG)DEBUG("Get strings "isoPath);

    if(LG)DEBUG("tmp file "tmpFile);

    system(AWK" 'BEGIN { FS=\"_\" } { gsub(/[^ -~]+/,\"~\"); gsub(\"~+\",\"~\") ; split($0,w,\"~\"); for (i in w)  if (w[i]) print w[i] ; }' "isoPart" > "tmpFile);
    getline f < tmpFile;
    getline f < tmpFile;
    system("rm -f -- "tmpFile" "isoPart);
    if(LD)DETAIL("iso title for "isoPath" = ["f"]");
    gsub(/[Ww]in32/,"",f);
    return clean_title(f);
    close(tmpFile);
}

# Make two urls point to the same cache page.
function equate_urls(u1,u2) {

    if(LD)DETAIL("equate ["u1"] =\n\t ["u2"]");

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

# If no title set - just use the filename
function fixTitles(minfo,\
t) {

    t = minfo[TITLE];
    if (t == "") {
        t = minfo[NAME];
        sub(/\/$/,"",t);
        sub(/.*\//,"",t); #remove path
        t = remove_format_tags(t);
        gsub("[^" g_alnum8 "]"," ",t); #remove odd chars
        if(LG)DEBUG("Setting title to file["t"]");
    }

    minfo[TITLE]=clean_title(t);
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
function num(x) \
{
    sub(/^[^-0-9]*0*/,"",x);
#    if (0+x == 0 ) {
#        if(LD)DETAIL("n("x") = "0);
#    }
    return 0+x;
}

#Move folder names from argument list
function get_folders_from_args(folder_arr,\
i,folderCount,moveDown) {
    folderCount=0;
    moveDown=0;
    for(i = 1 ; i - ARGC < 0 ; i++ ) {
        if(LI)INF("Arg:["ARGV[i]"]");
        if (ARGV[i] == "IGNORE_NFO" ) {
            g_settings["catalog_nfo_read"] = "no";
            moveDown++;

        } else if (ARGV[i] == "STANDALONE" ) {
            STANDALONE=1;
            moveDown++;
        } else if (ARGV[i] == "NOSTANDALONE" ) {
            STANDALONE=0;
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
        } else if (ARGV[i] ~ "^LOGERR" ) {
            g_catalog_log_level=3;
            moveDown++;
        } else if (ARGV[i] ~ "^LOGWARN" ) {
            g_catalog_log_level=2;
            moveDown++;
        } else if (ARGV[i] ~ "^LOGINFO" ) {
            g_catalog_log_level=1;
            moveDown++;
        } else if (ARGV[i] ~ "^LOGDETAIL" ) {
            g_catalog_log_level=0;
            moveDown++;
        } else if (ARGV[i] ~ "^LOGDEBUG" ) {
            g_catalog_log_level=-1;
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

        } else if (ARGV[i] == "NO_DB" )  {
            g_db = 0;
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
        } else if (ARGV[i] == "NO_BANNERS" )  {
            GET_BANNERS = UPDATE_BANNERS = 0;
            moveDown++;
        } else if (ARGV[i] == "UPDATE_BANNERS" )  {
            GET_BANNERS = UPDATE_BANNERS = 1;
            moveDown++;

        } else if (ARGV[i] == "GET_FANART"  || ARGV[i] == "GET_POSTERS"  || ARGV[i] == "GET_PORTRAITS" || ARGV[i] == "GET_BANNERS" )  {
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
        } else if (ARGV[i] == "CHECK_FREE_SPACE" )  {
            # Do a scan if free space on the device has changed
            CHECK_FREE_SPACE=1;
            moveDown++;
        } else if (ARGV[i] == "CHECK_TRIGGER_FILES" )  {
            # Do a scan if any of the files listed in catalog_trigger_files have changed.
            CHECK_TRIGGER_FILES=1;
            moveDown++;
        } else if (ARGV[i] == "RESCAN" )  {
            RESCAN=1;
            moveDown++;

        } else if (ARGV[i] == "EXPORT_XML" )  {

            EXPORT_XML=1;
            moveDown++;

        } else if (ARGV[i] == "PARALLEL_SCAN" )  {
            PARALLEL_SCAN=1;
            moveDown++;
        } else if (match(ARGV[i],"^[[:alpha:]_]+=")) {
            #variable assignment - keep for awk to process
        } else {
            # A folder or file
            if(LI)INF("Scan Path:["ARGV[i]"]");
            folder_arr[++folderCount] = ARGV[i];
            moveDown++;
        }
    }
    if(LD)DETAIL("============ END ARGS ============"moveDown);
    ARGC -= moveDown;
    # Add dev null as dummy input
    ARGV[ARGC++] = "/dev/null";
    return folderCount;
    for(i = 1 ; i <= ARGC ; i++ ) {
        if(LD)DETAIL("Final arg["i"] = ["ARGV[i]"]");
    }
}

function unit1(label,value) {
    print "unit" label ( value ? "OK" : "Failed");
    fflush();
}

function unit(doit) {
    if (doit) {
        DIV0("BEGIN UNIT TEST");
        get_locales(g_tmp);
        dump(0,"locales",g_tmp);
        get_langs(g_tmp);
        dump(0,"langs",g_tmp);

        json_parse("{\"first\":\"andrew\" , \"age\" : 31 }");

        if(LD)DETAIL("1." subexp("Title?012345","Title.([0-9]+)\\>"));
        if(LD)DETAIL("2." subexp("Title?012345 ","Title.([0-9]+)\\>"));
        if(LD)DETAIL("3." subexp("Title?012345","Title.([0-9]+)"));
        if(LD)DETAIL("4." subexp("Title?012345 ","Title.([0-9]+)"));

        unit1("html_to_utf8",(html_to_utf8("z&#1001;a") == "z"g_chr[0xcf]g_chr[0xA9]"a"));
        unit1("utf8len",(utf8len("z&#1001;a") == 3));
        unit1("utf8len",(utf8len(g_chr[192]g_chr[128]"a") == 2));
        unit1("utf8len",(utf8len(g_chr[224]g_chr[128]g_chr[128]"a") == 2));
        unit1("utf8len",(utf8len(g_chr[240]g_chr[128]g_chr[128]g_chr[128]"a") == 2));
        unit1("utf8len",(utf8len(g_chr[248]g_chr[128]g_chr[128]g_chr[128]g_chr[128]"a") == 2));
        unit1("utf8len",(utf8len(g_chr[252]g_chr[128]g_chr[128]g_chr[128]g_chr[128]g_chr[128]"a") == 2));
        unit1("utf8len",(utf8len(g_chr[252]g_chr[128]g_chr[128]g_chr[128]g_chr[128]g_chr[128]"&nbsp;&#1001;a") == 4));

        unit1("hex2dec",(hex2dec("ff") == 255 ));
        unit1("edit_dist1",(edit_dist("abc","abc") == 0));
        unit1("edit_dist2",(edit_dist("abc","abjc") == 1));
        unit1("edit_dist3",(edit_dist("abc","ac") == 1));
        unit1("edit_dist4",(edit_dist("abc","a") == 2));
        unit1("edit_dist5",(edit_dist("kitten","sitting") == 3));

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
        unit1("abbr9",(abbreviated_substring("one two three","","nte",0) == "ne two three"));

        unit1("Trim",(trim(" a ") == "a"));
        unit1("Roman",(roman_replace("fredii") == "fred2"));
        unit1("preserve1",(preserve_src_href("<a href=\"1112\">bbb</a>") == " href=\"1112\" <a >bbb</a>"));
        unit1("preserve2",(preserve_src_href("<img src=\"3333\">") == " img=\"3333\" <img >" ));
        unit1("preserve3",(preserve_src_href("<a href='1112'>bbb</a>") == " href=\"1112\" <a >bbb</a>"));
        unit1("preserve4",(preserve_src_href("<img src='3333'>") == " src=\"3333\" <img >" ));

        unit1("preserve5",(preserve_src_href("<img src='http://images.allocine.fr/cx_120_90/b_1_x/o_play.png_5_se/medias/nmedia/00/02/53/34/18352141_rep.gif'") == " img=\"http://images.allocine.fr/cx_120_90/b_1_x/o_play.png_5_se/medias/nmedia/00/02/53/34/18352141_rep.gif\" <img " ));

        unit1("html1",(html_decode("A&amp;B&nbsp;C") == "A&B C"));
        unit1("html2",(html_decode("A&#x20;B&#65;C") == "A BAC"));

        # var i,ulang,minfo
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

