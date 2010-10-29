# IN plugin THETVDB/TVRAGE
# IN minfo - current scrapped show
# OUT more_info - bit yucky returns additional info
#    currently more_info[1] indicates if abbrevation searches should be used when scraping later on.
# RET 0 - no format found
#     1 - tv format found - needs to be confirmed by scraping 
#
function checkTvFilenameFormat(minfo,plugin,more_info,\
details,line,dirs,d,dirCount,dirLevels,ret,name) {

   delete more_info;
   #First get season and episode information

   name = minfo["mi_media"];

   id1("checkTvFilenameFormat "plugin);

   line = remove_format_tags(name);
   DEBUG("CHECK TV ["line"] vs ["name"]");

   dirCount = split(minfo["mi_folder"],dirs,"/");
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

       if (d == dirLevels) {
           INF("No tv series-episode format in ["line"]");
           break;
       }
       line=dirs[dirCount-d]"/"line;
       more_info[1]=0; # disable abbrevation scrape
   }


    if (ret == 1) {

        if (details[TITLE] == "" ) {
            # format = 202 some text...
            # title may be in parent folder. but we will try to search by additional info first.
            searchByEpisodeName(plugin,details);
        }
        adjustTitle(minfo,details[TITLE],"filename");


        minfo["mi_season"]=details[SEASON];
        minfo["mi_episode"]=details[EPISODE];

        INF("Found tv info in file name:"line" title:["minfo["mi_title"]"] ["minfo["mi_season"]"] x ["minfo["mi_episode"]"]");
        
        ## Commented Out As Double Episode checked elsewhere to shrink code ##
        ## Left In So We Can Ensure It's Ok ##
        ## If the episode is a twin episode eg S05E23E24 => 23e24 then replace e with ,
        ## Then prior to any DB lookups we just use the first integer (episode+0)
        ## To avoid changing the e in the BigBrother d000e format first check its not at the end 

        # local ePos

        #ePos = index(minfo["mi_episode"],",");
        #if (ePos -1 >= 0 && ( ePos - length(minfo["mi_episode"]) < 0 )) {
        #    #gsub(/[-e]+/,",",minfo["mi_episode"]);
        #    #sub(/[-]/,"",minfo["mi_episode"]);
        #    DEBUG("Double Episode : "minfo["mi_episode"]);
        #}


        minfo["mi_tvid"] = details[TVID];
        minfo["mi_tvid_plugin"] = plugin;

        # This is the weakest form of tv categorisation, as the filename may just look like a TV show
        # So only set if it is blank
        if (minfo["mi_category"] == "") {
            minfo["mi_category"] = "T";
        }

        minfo["mi_additional_info"] = details[ADDITIONAL_INF];
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
# If Plugin != "" then it will also check episodes by date.
function extractEpisodeByPatterns(plugin,line,details,\
ret,p,pat,i,parts,sreg,ereg) {

    #Note if looking at entire path name folders are seperated by /


    line = tolower(line);

    #id1("extractEpisodeByPatterns["line"]");

    ret=0;

    sreg="([0-5][0-9]|[0-9])";

    ereg="([0-9][0-9]?)";

    # Each pattern has format  regex @ title suffix capture @ series capture index @ episode capture index @ episode prefix @ 
    # where capture index is the regex index for the bracketed pair for that item. eg \\1 etc
    #
    # title suffix capture is that part of the regex that belongs to the end of the title.
    # We could have used full matching to extract the title but this would use .* which is slow.
    p=0
    # s00e00e01
    pat[++p]="s()"sreg"[/ .]?[e/]([0-9]+[-,e0-9]+)@\\1\t\\2\t\\3@";
    # long forms season 1 ep  3
    pat[++p]="\\<()(series|season|saison|s)[^a-z0-9]*"sreg"[/ .]?(e|ep.?|episode|/)[^a-z0-9]*"ereg"@\\1\t\\3\t\\5@";

    # TV DVDs
    pat[++p]="\\<()(series|season|saison|seizoen|s)[^a-z0-9]*"sreg"[/ .]?(disc|dvd|d)[^a-z0-9]*"ereg"@\\1\t\\3\t\\5@dvd";

    #s00e00 (allow d00a for BigBrother)
    pat[++p]="s()?"sreg"[-/ .]?[e/]([0-9]+[a-e]?)@\\1\t\\2\t\\3@";

    # season but no episode
    pat[++p]="\\<()(series|season|saison|seizoen|s)[^a-z0-9]*"sreg"()@\\1\t\\3\t\\4@FILE";

    #00x00
    pat[++p]="([^a-z0-9])"sreg"[/ .]?x"ereg"@\\1\t\\2\t\\3@";


    #Try to extract dates before patterns because 2009 could be part of 2009.12.05 or  mean s20e09
    # extractEpisodeByDates is also called by other logic. 
    pat[++p]="DATE";
    ## just numbers.
    pat[++p]="([^-0-9])([1-9]|2[1-9]|1[0-8]|[03-9][0-9])/?([0-9][0-9])@\\1\t\\2\t\\3@";

    # Part n - no season
    pat[++p]="\\<()()(part|pt|episode|ep)[^a-z0-9]?("ereg"|"g_roman_regex")@\\1\t\\2\t\\4@";

    for(i = 1 ; ret+0 == 0 && p-i >= 0 ; i++ ) {
        if (pat[i] == "DATE" && plugin != "" ) {
            ret = extractEpisodeByDates(plugin,line,details);
        } else {
            split(pat[i],parts,"@");
            #dump(0,"epparts",parts);
            ret = episodeExtract(line,parts[1],parts[2],details);
            if (ret+0) {
                # For DVDs add DVD prefix to Episode
                details[EPISODE] = parts[3] details[EPISODE];
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
function episodeExtract(line,regex,capture_list,details,\
rtext,rstart,count,i,ret) {

    #To detect word boundaries remove _ - this may affect Lukio_. Only TV show with an underscore in IMDB
    if (index(line,"_")) gsub(/_/," ",line);

    count = 0+get_regex_pos(line,regex "\\>",0,rtext,rstart);
    if (count) {
        id1("episodeExtract:["line "] [" regex "]");

        for(i = 1 ; i+0 <= count ; i++ ) {
            if ((ret = extractEpisodeByPatternSingle(line,regex,capture_list,rstart[i],rtext[i],details)) != 0) {
                break;
            }
        }
        id0(ret);
    }
    return 0+ret;
}

#This would be easier using sed submatches.
#More complex approach will fail on backtracking
function extractEpisodeByPatternSingle(line,regex,capture_list,reg_pos,reg_match,details,\
tmpTitle,ret,ep,season,title,inf,matches) {

    ret = 0;

    delete details;

    if (reg_match ~ "([XxHh.]?264|1080)$" ) {

        DEBUG("ignoring ["reg_match"]");

    } else if (split(gensub("^"regex"$",capture_list,1,reg_match),matches,"\t") != 3) {

        WARNING("Expected 3 parts");

    } else {
        id1("extractEpisodeByPatternSingle:"reg_match);


        INF("regex=["regex"]");
        INF("capture_list=["capture_list"]");
        INF("reg_match=["reg_match"]");
        dump(0,"extractEpisodeByPatternSingle",matches);

        # split the line up
        title = substr(line,1,reg_pos-1) matches[1];

        season = matches[2];
        ep = matches[3];

        inf=substr(line,reg_pos+length(reg_match));

        # clean up episode ----------------------------

        if (ep == "") ep="0";
        ep = roman_replace(ep);

        # clean up season ----------------------------

        if(season == "") season = 1; # mini series

        # clean up info ----------------------------

        if (match(inf,gExtRegExAll) ) {
            details[EXT]=inf;
            gsub(/\.[^.]*$/,"",inf);
            details[EXT]=substr(details[EXT],length(inf)+2);
        }

        inf=clean_title(inf,2);
            
        # clean up title ----------------------------

        if (match(title,": *")) {
            title = substr(title,RSTART+RLENGTH);
        }
        #DEBUG("ExtractEpisode:2 Title= ["title"]");
        #Remove release group info
        if (match(title,"^[a-z][a-z0-9]+[-]")) {
           tmpTitle=substr(title,RSTART+RLENGTH);
           if (tmpTitle != "" ) {
               INF("Removed group was ["title"] now ["tmpTitle"]");
               title=tmpTitle;
           }
        }

        #DEBUG("ExtractEpisode: Title= ["title"]");
        title = clean_title(title,2);
        
        DEBUG("ExtractEpisode: Title= ["title"]");

        #============----------------------------------

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
        id0(ret);
    }

    #Return results
    if (ret != 1 ) delete details;
    return ret;
}

function extractEpisodeByDates(plugin,line,details,\
date,nonDate,title,rest,y,m,d,tvdbid,result,closeTitles,tmp_info) {

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

            if (get_tv_series_info(plugin,tmp_info,get_tv_series_api_url(plugin,tvdbid)) > 0) {

                if (plugin == "THETVDB" ) {

                    #TODO We could get all the series info - this would be cached anyway.
                    result = extractEpisodeByDates_TvDb(tmp_info,tvdbid,y,m,d,details);

                } else if (plugin == "TVRAGE" ) {

                    result = extractEpisodeByDates_rage(tmp_info,tvdbid,y,m,d,details);

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
function extractEpisodeByDates_TvDb(minfo,tvdbid,y,m,d,details,\
episodeInfo,url) {

    
    url=g_thetvdb_web"/api/GetEpisodeByAirDate.php?apikey="g_api_tvdb"&seriesid="tvdbid"&airdate="y"-"m"-"d;
    fetchXML(url,"epbydate",episodeInfo);

    if ( "/Data/Error" in episodeInfo ) {
        ERR(episodeInfo["/Data/Error"]);
        tvdbid="";
    }
    if (tvdbid != "") {
        dump(0,"ep by date",episodeInfo);

        minfo["mi_airdate"]=formatDate(episodeInfo["/Data/Episode/FirstAired"]);
        details[SEASON]=episodeInfo["/Data/Episode/SeasonNumber"];
        details[EPISODE]=episodeInfo["/Data/Episode/EpisodeNumber"];
        details[ADDITIONAL_INF]=episodeInfo["/Data/Episode/EpisodeName"];
        #TODO We can cache the above url for later use instead of fetching episode explicitly.
        # Setting this will help short circuit searching later.

        equate_urls(url,g_thetvdb_web"/data/series/"tvdbid"/default/"details[SEASON]"/"details[EPISODE]"/en.xml");

        #minfo["mi_imdb"]=get_tv_series_api_url(tvdbid);
        #DEBUG("Season "details[SEASON]" episode "details[EPISODE]" external source "minfo["mi_imdb"]);
        #dump(0,"epinfo",episodeInfo);
        return 1;
    }
    return 0;
}
function extractEpisodeByDates_rage(minfo,tvdbid,y,m,d,details,\
episodeInfo,match_date,result,filter) {

    result=0;
    match_date=sprintf("%4d-%02d-%02d",y,m,d);


    filter["/Show/Episodelist/Season/episode/airdate"] = match_date;
    if (fetch_xml_single_child(get_tv_series_api_url("TVRAGE",tvdbid),"bydate","/Show/Episodelist/Season/episode",filter,episodeInfo)) {
        minfo["mi_airdate"]=formatDate(match_date);
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

function tv_search_simple(minfo,bestUrl) {
    id1("tv_search_simple");
    return tv_check_and_search_all(minfo,bestUrl,0);
}

function tv_search_complex(minfo,bestUrl) {
    id1("tv_search_complex ");
    return tv_check_and_search_all(minfo,bestUrl,1);
}


# For each tv plugin - search for a match.
# idx = current show
# bestUrl = imdb url
# check_tv_names - if 1 then we do not have any imdb info - check tv formats and check abbreviations.
#   if 0 then we know it is a tv show from IMDB - just search the TV site directly.
#
# returns cat="T" tv show , "M" = movie , "" = unknown.

function tv_check_and_search_all(minfo,bestUrl,check_tv_names,\
plugin,cat,p,tv_status,do_search,search_abbreviations,more_info) {


    for (p in g_tv_plugin_list) {
        plugin = g_tv_plugin_list[p];

        # demote back to imdb title
        if (minfo["mi_imdb_title"] != minfo["mi_title"] && minfo["mi_imdb_title"] != "" ) {

            INF("*** revert title from "minfo["mi_title"]" to "minfo["mi_imdb_title"]);
            minfo["mi_title"] = minfo["mi_imdb_title"];
        }

        # checkTvFilenameFormat also uses the plugin to detect daily formats.
        # so if ellen.2009.03.13 is rejected at tvdb it is still passed by tvrage.
        minfo["mi_tvid_plugin"] = minfo["mi_tvid"]="";

        do_search = 1;

        if (check_tv_names) {

            if (checkTvFilenameFormat(minfo,plugin,more_info)) {

                search_abbreviations = more_info[1];

                #minfo["mi_imdb"] may have been set by a date lookup
                if (bestUrl == "" && minfo["mi_imdb"] != "" ) {
                    bestUrl = extractImdbLink(minfo["mi_imdb"]);
                }
            } else {
                do_search = 0;
            }
        } else {
            # We have a name from IMDB and are certain it is a TV show
            search_abbreviations = 0;
        }
        if (do_search) {
            tv_status = tv_search(plugin,minfo,bestUrl,search_abbreviations);
            if (minfo["mi_episode"] !~ "^[0-9]+$" ) {
                #no point in trying other tv plugins
                break;
            }
            if (tv_status == 2 ) break;

        }
    }
    if (tv_status) {
        cat = minfo["mi_category"];
    }
    id0(cat);
    return cat;
}

# 0=nothing found 1=series but no episode 2=series+episode
function tv_search(plugin,minfo,imdbUrl,search_abbreviations,\
tvDbSeriesPage,result,tvid,cat,iid) {

    result=0;

    id1("tv_search ("plugin","imdbUrl","search_abbreviations")");

    #This will succedd if we already have the tvid when doing the checkTvFilenameFormat
    #checkTvFilenameFormat() may fetch the tvid while doing a date check for daily shows.
    tvDbSeriesPage = get_tv_series_api_url(plugin,minfo["mi_tvid"]);

    if (tvDbSeriesPage == "" && imdbUrl == "" ) { 
        # do not know tvid nor imdbid - use the title to search tv indexes.
        tvDbSeriesPage = search_tv_series_names(plugin,minfo,minfo["mi_title"],search_abbreviations);
    }

    if (tvDbSeriesPage != "" ) { 
        # We know the TV id - use this to get the imdb id
        result = get_tv_series_info(plugin,minfo,tvDbSeriesPage); #this may set imdb url
        if (result) {
            if (imdbUrl) {
                iid=extractImdbId(imdbUrl);
            } else if (minfo["mi_imdb"]) {
                # we also know the imdb id
                iid=minfo["mi_imdb"];
            } else {
                # use the tv id to find the imdb id
                iid=tv2imdb(minfo);
            }
            cat = get_imdb_info(iid,minfo);
        }
    } else {
        # dont know the tvid
        if (imdbUrl == "") {
            # If we get here we dont know the tvid nor imdbid and a lookup by title has also failed
            # At this stage we use the file name to search the web for an imdb url.
            # TODO This should filter out movie results.

            # TODO This is disabled for now, as the movie search will also do frequent link searching.
            # and if the movie search returns a TV page then a tv search will be tried again using 
            # the new IMDB title.
            # This may impact searches for badly titled tv shows.
            # TODO: imdbUrl=web_search_frequent_imdb_link(minfo);
        }
        if (imdbUrl != "") {
            # use the imdb id to find the tv id
            cat = get_imdb_info(imdbUrl,minfo);
            if (cat != "M" ) {
                # find the tvid - this can miss if the tv plugin api does not have imdb lookup
                tvid = find_tvid(plugin,minfo,extractImdbId(imdbUrl));
                if(tvid != "") {
                    tvDbSeriesPage = get_tv_series_api_url(plugin,tvid);
                    result = get_tv_series_info(plugin,minfo,tvDbSeriesPage);
                }
            }
        }
    }
    
    if (cat == "M" ) {
        WARNING("Error getting IMDB ID from tv - looks like a movie??");
        if (plugin == "THETVDB") {
            WARNING("Please update the IMDB ID for this series at the THETVDB website for improved scanning");
        }

        result = 0;
    }
    id0(result);
    return 0+ result;
}

# use the title and year to find the imdb id
function tv2imdb(minfo,\
key) {

    if (minfo["mi_imdb"] == "") {
    
        key=minfo["mi_title"]" "minfo["mi_year"];
        DEBUG("tv2imdb key=["key"]");
        if (!(key in g_tv2imdb)) {

            # Search for imdb page  - try to filter out Episode pages.
            g_tv2imdb[key] = web_search_first_imdb_link(key" +site:imdb.com \"TV Series\" -\"Episode Cast\"",key); 
        }
        minfo["mi_imdb"] = g_tv2imdb[key];
    }
    DEBUG("tv2imdb end=["minfo["mi_imdb"]"]");
    return extractImdbLink(minfo["mi_imdb"]);
}

function search_tv_series_names(plugin,minfo,title,search_abbreviations,\
tnum,t,i,url) {

    tnum = alternate_titles(title,t);

    for(i = 0 ; i-tnum < 0 ; i++ ) {
        url = search_tv_series_names2(plugin,minfo,t[i],search_abbreviations);
        if (url != "") break;
    } 
    return url;
}

function search_tv_series_names2(plugin,minfo,title,search_abbreviations,\
tvDbSeriesPage,alternateTitles,title_key,cache_key,showIds,tvdbid) {

    title_key = plugin"/"minfo["mi_folder"]"/"title;
    id1("search_tv_series_names "title_key);

    if (title_key in g_tvDbIndex) {
        DEBUG(plugin" use previous mapping "title_key" -> ["g_tvDbIndex[title_key]"]");
        tvDbSeriesPage =  g_tvDbIndex[title_key]; 
    } else {

        tvDbSeriesPage = searchTvDbTitles(plugin,minfo,title);

        DEBUG("search_tv_series_names: bytitles="tvDbSeriesPage);
        if (tvDbSeriesPage) {

            # do nothing

        } else if ( search_abbreviations ) {

            # Abbreviation search

            cache_key=minfo["mi_folder"]"@"title;

            if(cache_key in g_abbrev_cache) {

                tvDbSeriesPage = g_abbrev_cache[cache_key];
                INF("Fetched abbreviation "cache_key" = "tvDbSeriesPage);

            } else {

                searchAbbreviationAgainstTitles(title,alternateTitles);

                filterTitlesByTvDbPresence(plugin,alternateTitles,showIds);
                if (hash_size(showIds)+0 > 1) {

                    filterUsenetTitles(showIds,cleanSuffix(minfo),showIds);
                }

                tvdbid = selectBestOfBestTitle(plugin,minfo,showIds);

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

function possible_tv_titles(plugin,title,closeTitles,\
ret) {

    if (plugin == "THETVDB" ) {

        ret = searchTv(plugin,title,closeTitles);

    } else if (plugin == "TVRAGE" ) {

        ret = searchTv(plugin,title,closeTitles);

    } else {

        plugin_error(plugin);

    } 
    g_indent=substr(g_indent,2);
    dump(0,"searchTv out",closeTitles);
    return ret;

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
function selectBestOfBestTitle(plugin,minfo,titles,\
bestId,bestFirstAired,age_scores,eptitle_scores,count) {
    dump(0,"closely matched titles",titles);
    count=hash_size(titles);

    if (count == 0) {
        bestId = "";
    } else if (count == 1) {
        bestId = firstIndex(titles);
    } else {
        TODO("Refine selection rules here.");

        INF("Getting the most recent first aired for s"minfo["mi_season"]"e"minfo["mi_episode"]);
        # disabled in the hope another search method is triggered
        if(1) {
            bestFirstAired="";

            getRelativeAgeAndEpTitles(plugin,minfo,titles,age_scores,eptitle_scores);

            bestScores(eptitle_scores,eptitle_scores,1);
            bestId = firstIndex(eptitle_scores);

            if (bestId == "") {
                bestScores(age_scores,age_scores,1);
                bestId = firstIndex(age_scores);
            }
        }
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
# RETURNS Similarity Score - eg Office UK vs Office UK is a fully qualifed match high score.
# This wrapper function will search with or without the country code.
function searchTv(plugin,title,closeTitles,\
allTitles,url,ret) {

    id1("searchTv Checking ["plugin"/"title"]" );
    delete closeTitles;

    if (plugin == "THETVDB") {

        url=expand_url(g_thetvdb_web"//api/GetSeries.php?seriesname=",title);
        filter_search_results(url,title,"/Data/Series","SeriesName","seriesid",allTitles);

    } else if (plugin == "TVRAGE") {

        url=g_tvrage_web"/feeds/search.php?show="title;
        filter_search_results(url,title,"/Results/show","name","showid",allTitles);

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
function filter_search_results(url,title,seriesPath,nameTag,idTag,allTitles,\
info,currentId,currentName,i,num,series,empty_filter) {

    if (fetchXML(url,"tvsearch",info,"")) {

        num = find_elements(info,seriesPath,empty_filter,0,series);
        for(i = 1 ; i <= num ; i++ ) {

            currentName = clean_title(info[series[i]"/"nameTag]);

            currentId = info[series[i]"/"idTag];

            allTitles[currentId] = currentName;
        }
    }

    dump(0,"search results["title"]",allTitles);
    #filterSimilarTitles is called by the calling function
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

# Create a regex for searching titles , allowing for optional punctuation at the end of each word 
# eg dot following abbreviations , and optional year or country qualifier.
function tv_title2regex(title) {
    #gsub(/[A-Za-z0-9]\>/,"&"g_punc[0]"?",title);
    gsub(/[A-Za-z0-9]\>/,"&[.?!]?",title);
    return title"(| \\([a-z0-9]\\))";
}

# IN imdb id tt0000000
# RETURN tvdb id
function find_tvid(plugin,minfo,imdbid,\
url,id2,date,nondate,regex,key,filter,showInfo,year_range,title_regex) {
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
                extractDate(minfo["mi_premier"],date,nondate);
                # We do a fuzzy year search esp for programs that have a pilot in the
                # year before episode 1
                #
                # This may cause a false match if two series with exactly the same name
                # started within two years of one another.
                year_range="("(minfo["mi_year"]-1)"|"minfo["mi_year"]"|"(minfo["mi_year"]+1)")";
                title_regex=tv_title2regex(minfo["mi_title"]);

                if(plugin == "THETVDB") {

                    #allow for titles "The Office (US)" or "The Office" and 
                    # hope the start year is enough to differentiate.
                    filter["/Data/Series/SeriesName"] = "~:^"title_regex"$";
                    filter["/Data/Series/FirstAired"] = "~:^"year_range"-";

                    url=expand_url(g_thetvdb_web"//api/GetSeries.php?seriesname=",minfo["mi_title"]);
                    if (fetch_xml_single_child(url,"imdb2tvdb","/Data/Series",filter,showInfo)) {
                        INF("Looking at tvdb "showInfo["/Data/Series/SeriesName"]);
                        id2 = showInfo["/Data/Series/seriesid"];
                    }

#                    regex="[&?;]id=[0-9]+";
#                    local ,premier_mdy
#                    if (1 in date) premier_mdy=sprintf("\"%s %d, %d\"",g_month_en[0+date[2]],date[3],date[1]);
#
#                    id2 = scan_tv_via_search_engine(regex,minfo["mi_title"]" site:thetvdb.com intitle:\"Series Info\" ",premier_mdy,minfo["mi_year"]);
#                    if (id2 != "" ) {
#                        id2=substr(id2,5);
#                    }

                } else if(plugin == "TVRAGE") {

                    #allow for titles "The Office (US)" or "The Office" and 
                    # hope the start year is enough to differentiate.
                    filter["/Results/show/name"] = "~:^"title_regex"$";
                    filter["/Results/show/started"] = "~:"year_range;
                    
                    if (fetch_xml_single_child(g_tvrage_web"/feeds/search.php?show="minfo["mi_title"],"imdb2rage","/Results/show",filter,showInfo)) {
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

function searchTvDbTitles(plugin,minfo,title,\
tvdbid,tvDbSeriesUrl,imdb_id,closeTitles,noyr) {

    id1("searchTvDbTitles");
    if (minfo["mi_imdb"]) {
        imdb_id = minfo["mi_imdb"];
        tvdbid = find_tvid(plugin,minfo,imdb_id);
    }
    if (tvdbid == "") {
        possible_tv_titles(plugin,title,closeTitles);
        tvdbid = selectBestOfBestTitle(plugin,minfo,closeTitles);
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
    	    tvdbid = selectBestOfBestTitle(plugin,minfo,closeTitles);
    	}
    }
    if (tvdbid != "") {
        tvDbSeriesUrl=get_tv_series_api_url(plugin,tvdbid);
    }

    id0(tvDbSeriesUrl);
    return tvDbSeriesUrl;
}

function get_tv_series_api_url(plugin,tvdbid,\
url,i,num,langs) {
    if (tvdbid != "") {
        if (plugin == "THETVDB") {


            num = get_langs(langs);
            for(i = 1 ; i <= num ; i++ ) {
                if (g_tvdb_user_per_episode_api) {
                    url = g_thetvdb_web"/data/series/"tvdbid"/"langs[i]".xml";
                } else {
                    url = g_thetvdb_web"/data/series/"tvdbid"/all/"langs[i]".xml";
                }
                if (url_state(url) == 0) break;
            }
        } else if (plugin == "TVRAGE") {
            url = "http://services.tvrage.com/feeds/full_show_info.php?sid="tvdbid;
        }
    }
    return url;
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

function get_episode_url(plugin,seriesUrl,season,episode,\
episodeUrl ) {
    episodeUrl = seriesUrl;
    if (plugin == "THETVDB") {
        if (g_tvdb_user_per_episode_api) {
            #Note episode may be 23,24 so convert to number.
            if (sub(/[a-z][a-z].xml$/,"default/"season"/"(episode+0)"/&",episodeUrl)) {
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
function get_tv_series_info(plugin,minfo,tvDbSeriesUrl,\
result) {

    id1("get_tv_series_info("plugin"," tvDbSeriesUrl")");

    # mini-series may not have season set
    if (minfo["mi_season"] == "") {
        minfo["mi_season"] = 1;
    }

    if (plugin == "THETVDB") {
        result = get_tv_series_info_tvdb(minfo,tvDbSeriesUrl);
    } else if (plugin == "TVRAGE") {
        result = get_tv_series_info_rage(minfo,tvDbSeriesUrl);
    } else {
        plugin_error(plugin);
    }
#    ERR("UNCOMMENT THIS CODE");
    if (minfo["mi_episode"] ~ "^DVD[0-9]+$" ) {
        result++;
    }
#    ERR("UNCOMMENT THIS CODE");

    DEBUG("Title:["minfo["mi_title"]"] "minfo["mi_season"]"x"minfo["mi_episode"]" date:"minfo["mi_airdate"]);
    DEBUG("Episode:["minfo["mi_eptitle"]"]");

    id0(result"="(result==2?"Full Episode Info":(result?"Series Only":"Not Found")));
    return 0+ result;
}

# return 1 if setting the value
function setFirst(minfo,field,value,\
ret) {
    ret = 0;
    if (minfo[field] == "") {
        minfo[field] = value;
        print "["field"] set to ["value"]";
        ret = 1;
    } else {
        print "["field"] already set to ["minfo[field]"] ignoring ["value"]";
    }
    return ret;
}

function remove_br_year(t) {
    sub(" *\\("g_year_re"\\)","",t); #remove year
    return t;
}

function remove_tv_year(t) {
    if(length(t) > 4) {
    sub(" *"g_year_re,"",t);
    }
    return t;
}
function clean_plot(txt) {
    txt = substr(txt,1,g_max_plot_len);
    if (index(txt,"Remove Ad")) {
        sub(/\[[Xx]\] Remove Ad/,"",txt);
    }
    return txt;
}
# Scrape theTvDb series page, populate arrays and return imdb link
# http://thetvdb.com/api/key/series/73141/default/1/2/en.xml
# http://thetvdb.com/api/key/series/73141/en.xml
# 0=nothing 1=series 2=series+episode
function get_tv_series_info_tvdb(minfo,tvDbSeriesUrl,\
seriesInfo,episodeInfo,bannerApiUrl,result,empty_filter) {

    result=0;

    
    #fetchXML(tvDbSeriesUrl,"thetvdb-series",seriesInfo);
    fetch_xml_single_child(tvDbSeriesUrl,"thetvdb-series","/Data/Series",empty_filter,seriesInfo);
    if ("/Data/Series/id" in seriesInfo) {

        dump(0,"tvdb series",seriesInfo);

        setFirst(minfo,"mi_imdb",extractImdbId(seriesInfo["/Data/Series/IMDB_ID"]));
        #Refine the title.
        adjustTitle(minfo,remove_br_year(seriesInfo["/Data/Series/SeriesName"]),"thetvdb");

        minfo["mi_year"] = substr(seriesInfo["/Data/Series/FirstAired"],1,4);
        setFirst(minfo,"mi_premier",formatDate(seriesInfo["/Data/Series/FirstAired"]));
        best_source(minfo,"mi_plot",clean_plot(seriesInfo["/Data/Series/Overview"]),"thetvdb");

        #Dont use thetvdb genre - its too confusing when mixed with imdb movie genre

        minfo["mi_certrating"] = seriesInfo["/Data/Series/ContentRating"];

        # Dont use tvdb rating - prefer imdb one.
        #minfo["mi_rating"] = seriesInfo["/Data/Series/Rating"];

        best_source(minfo,"mi_poster",tvDbImageUrl(seriesInfo["/Data/Series/poster"]),"thetvdb");
        minfo["mi_tvid_plugin"]="THETVDB";
        minfo["mi_tvid"]=seriesInfo["/Data/Series/id"];
        result ++;


        bannerApiUrl = tvDbSeriesUrl;
        sub(/(all.|)[a-z][a-z].xml$/,"banners.xml",bannerApiUrl);

        getTvDbSeasonBanner(minfo,bannerApiUrl,"en");

        # For twin episodes just use the first episode number for lookup by adding 0
        dump(0,"pre-episode",minfo);

        if (minfo["mi_episode"] ~ "^[0-9,]+$" ) {

            if (get_episode_xml("THETVDB",tvDbSeriesUrl,minfo["mi_season"],minfo["mi_episode"],episodeInfo)) {

                if ("/Data/Episode/id" in episodeInfo) {
                    setFirst(minfo,"mi_airdate",formatDate(episodeInfo["/Data/Episode/FirstAired"]));

                    set_eptitle(minfo,episodeInfo["/Data/Episode/EpisodeName"]);

                    if (minfo["mi_epplot"] == "") {
                        minfo["mi_epplot"] = clean_plot(episodeInfo["/Data/Episode/Overview"]);
                    }

                    if (minfo["mi_eptitle"] != "" ) {
                       if ( minfo["mi_eptitle"] ~ /^Episode [0-9]+$/ && minfo["mi_plot"] == "" ) {
                           INF("Due to Episode title of ["minfo["mi_eptitle"]"] Demoting result to force another TV plugin search");
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

    if (minfo["mi_imdb"] == "" ) {
        WARNING("get_tv_series_info returns blank imdb url. Consider updating the imdb field for this series at "g_thetvdb_web);
    } else {
        DEBUG("get_tv_series_info returns imdb url ["minfo["mi_imdb"]"]");
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

function getTvDbSeasonBanner(minfo,bannerApiUrl,language,\
xml,filter,r) {

    if (getting_poster(minfo,1) || getting_fanart(minfo,1)) {
        r="/Banners/Banner";
        delete filter;
        filter[r"/Language"] = language;
        filter[r"/BannerType"] = "season";
        filter[r"/Season"] = minfo["mi_season"];
        if (fetch_xml_single_child(bannerApiUrl,"banners","/Banners/Banner",filter,xml) ) {
            best_source(minfo,"mi_poster",tvDbImageUrl(xml[r"/BannerPath"]),"thetvdb");
        }

        delete filter;
        filter[r"/Language"] = language;
        filter[r"/BannerType"] = "fanart";
        if (fetch_xml_single_child(bannerApiUrl,"banners","/Banners/Banner",filter,xml) ) {
            best_source(minfo,"mi_fanart",tvDbImageUrl(xml[r"/BannerPath"]),"thetvdb");
        }
    }
}

function set_eptitle(minfo,title) {
    if (minfo["mi_eptitle"] == "" ) {

        minfo["mi_eptitle"] = title;
        INF("Setting episode title ["title"]");

    } else if (title != "" && title !~ /^Episode [0-9]+$/ && minfo["mi_eptitle"] ~ /^Episode [0-9]+$/ ) {

        INF("Overiding episode title ["minfo["mi_eptitle"]"] with ["title"]");
        minfo["mi_eptitle"] = title;
    } else {
        INF("Keeping episode title ["minfo["mi_eptitle"]"] ignoring ["title"]");
    }
}

# 0=nothing 1=series 2=series+episode
function get_tv_series_info_rage(minfo,tvDbSeriesUrl,\
seriesInfo,episodeInfo,filter,url,e,result,pi,p,ignore,flag,plot) {

    pi="TVRAGE";
    result = 0;
    delete filter;

    ignore="/Show/Episodelist";
    if (fetch_xml_single_child(tvDbSeriesUrl,"tvinfo-show","/Show",filter,seriesInfo,ignore)) {
        dump(0,"tvrage series",seriesInfo);
        adjustTitle(minfo,remove_br_year(seriesInfo["/Show/name"]),pi);
        minfo["mi_year"] = substr(seriesInfo["/Show/started"],8,4);
        setFirst(minfo,"mi_premier",formatDate(seriesInfo["/Show/started"]));


        url=urladd(seriesInfo["/Show/showlink"],"remove_add336=1&bremove_add=1");
        plot = clean_plot(scrape_one_item("tvrage_plot",url,"id=.iconn1",0,"iconn2|<center>|^<br>$",0,1));
        best_source(minfo,"mi_plot",plot,"tvrage");

        minfo["mi_tvid_plugin"]="TVRAGE";
        minfo["mi_tvid"]=seriesInfo["/Show/showid"];
        result ++;

        #get imdb link - via links page and then epguides.
        if(minfo["mi_imdb"] == "") {
            url = scanPageFirstMatch(url,"/links/",g_nonquote_regex"+/links/",1);
            if (url != "" ) {
                url = scanPageFirstMatch(g_tvrage_web url,"epguides", "http"g_nonquote_regex "+.epguides." g_nonquote_regex"+",1);
                if (url != "" ) {
                    minfo["mi_imdb"] = scanPageFirstMatch(url,"tt",g_imdb_regex,1);
                }
            }
        }

        dump(0,"pre-episode",minfo);

        e="/Show/Episodelist/Season/episode";
        if (minfo["mi_episode"] ~ "^[0-9,]+$" ) {
            if (get_episode_xml(pi,tvDbSeriesUrl,minfo["mi_season"],minfo["mi_episode"],episodeInfo)) {

                set_eptitle(minfo,episodeInfo[e"/title"]);

                minfo["mi_airdate"]=formatDate(episodeInfo[e"/airdate"]);
                url=seriesInfo["/Show/showlink"] "/printable?nocrew=1&season=" minfo["mi_season"];
                #OLDWAY#url=urladd(episodeInfo[e"/link"],"remove_add336=1&bremove_add=1");

                if (minfo["mi_epplot"] == "" ) {
                    #p = scrape_one_item("tvrage_epplot",url,"id=.ieconn2",0,"</tr>|^<br>$|<a ",1);


                    flag=sprintf(":%02dx%02d",minfo["mi_season"],minfo["mi_episode"]);
                    p = scrape_one_item("tvrage_epplot", url, flag",<p>", 1, "</div>", 0, 1);


                    #OLDWAY#p = scrape_one_item("tvrage_epplot",url,">Episode Summary</h",0,"^<br>$|<a href",1,0);



                    sub(/ *There are no foreign summaries.*/,"",p);
                    if (p != "" && index(p,"There is no summary") == 0) {
                        minfo["mi_epplot"] = clean_plot(p);
                        DEBUG("rage epplot :"minfo["mi_epplot"]);
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

# This should only be called fairly late in the selection process.
#
# It scans all eligible series for the given episode.
#
# If the Episode Name matches the additional info then that is noted in eptitleHash
#
# otherwise
#
# It returns the newest item. It may not be a valid thing to do
# but if we end up having to chose between two films with no other
# information should either make a choice OR give up.
# The relative age is just a metric that can be compared between films
# eg IMDBID is a rough relative age indicator.
# For other databases we may need to get the actual air date.
# it should return array of strings (not numbers) that can be compared using < >.
# eg 2009-03-31 ok but 31-03-2009 bad.
# IN minfo - current media item
# IN titleHash - Indexed by imdb/tvdbid etc
# OUT ageHash - age indicator  Indexed by imdb/tvdbid etc
# OUT eptitleHash - set to 1 if episode title = additional info
function getRelativeAgeAndEpTitles(plugin,minfo,titleHash,ageHash,eptitleHash,\
id,xml,eptitle) {
   for(id in titleHash) {
        if (get_episode_xml(plugin,get_tv_series_api_url(plugin,id),minfo["mi_season"],minfo["mi_episode"],xml)) {
            if (plugin == "THETVDB") {

                ageHash[id] = xml["/Data/Episode/FirstAired"];
                eptitle = tolower(xml["/Data/Episode/EpisodeName"]);

            } else if (plugin == "TVRAGE" ) {

                ageHash[id] = xml["/Show/Episodelist/Season/episode/airdate"];
                eptitle = tolower(xml["/Show/Episodelist/Season/episode/title"]);

            } else {
                plugin_error(plugin);
            }

            if (tolower(eptitle) == tolower(minfo["mi_additional_info"])) {
                eptitleHash[id] = 2;
            }
        }
    }
    dump(1,"episode title ",eptitleHash);
    dump(1,"Age indicators",ageHash);
 }

