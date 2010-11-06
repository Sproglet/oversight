# return last n parts of path. If no more then return empty string.
function last_path_parts(minfo,n,\
ret,i,j,dirCount,dirs) {

    ret = remove_format_tags(minfo["mi_media"]);
    if (n > 1 ) {
       dirCount = split(minfo["mi_folder"],dirs,"/");
       if (n > dirCount ) {
           ret = ""; # no more n
       } else {
           for (i = 1 ; i <= n -1 ; i++ ) {
               j = dirCount + 1 - i;
               if (j >= 1) {
                   ret = dirs[j] "/" ret;
               }
           }
       }
   }
   return ret;
}
        
# IN plugin thetvdb/tvrage
# IN path_parts = number of trailing parts of the path to use. 0=Try all parts.
# IN minfo - current scrapped show
# OUT more_info - bit yucky returns additional info
#    currently more_info[1] indicates if abbrevation searches should be used when scraping later on.
# RET 0 - no format found
#     1 - tv format found - needs to be confirmed by scraping 
#
function checkTvFilenameFormat(minfo,plugin,path_parts,more_info,\
details,line,ret,name,i,start,end) {

    ret = 0;
   delete more_info;
   #First get season and episode information

   name = minfo["mi_media"];

   id1("checkTvFilenameFormat "plugin);

   if (path_parts == 0) {
       start = 1;
       end = 3;
   } else {
       start = end = path_parts;
   }

   for(i = start ; i <= end ; i++ ) {
    

       line = last_path_parts(minfo,i);

       if (line) {
           DEBUG("CHECK TV ["line"] vs ["name"]");


           # After extracting the title text we look for matching tv programs
           # We only look at abbreviations if the title did NOT use the folder name.
           # The assumption is the people abbreviate file names but not folder names.
           more_info[1]=(path_parts == 1); # enable abbrevation scraping later only at filename level

            if (extractEpisodeByPatterns(minfo,plugin,line,details)==1) {
                   ret = 1;

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


                minfo_set_id(plugin,details[TVID],minfo);

                # This is the weakest form of tv categorisation, as the filename may just look like a TV show
                # So only set if it is blank
                if (minfo["mi_category"] == "") {
                    minfo["mi_category"] = "T";
                }

                minfo["mi_additional_info"] = details[ADDITIONAL_INF];
                # Now check the title.
                #TODO
                break;
            }
        }
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
    if (plugin == "thetvdb") {
        terms="\"season "details[SEASON]"\" \""details[EPISODE]" : "clean_title(details[ADDITIONAL_INF])"\" site:thetvdb.com";
        # Bing seems a bit better than google for this. For "The office" anyway.
        # But google finds 1x5 Jersey Devil = X Files.
        results = scanPageFirstMatch(g_search_bing terms,"seriesid","seriesid=[0-9]+",0);
        #results = scanPageFirstMatch(g_search_google terms,"seriesid","seriesid=[0-9]+",0);
        if (split(results,parts,"=") == 2) {
            id = parts[2];
        }
    } else if (plugin == "tvrage") {
        terms="\"season "details[SEASON]"\" "details[SEASON]"x"sprintf("%02d",details[EPISODE])" \""clean_title(details[ADDITIONAL_INF])"\" site:tvrage.com";
        url = scan_page_for_first_link(g_search_google terms,"tvrage",0);
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
function extractEpisodeByPatterns(minfo,plugin,line,details,\
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
            ret = extractEpisodeByDates(minfo,plugin,line,details);
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

function extractEpisodeByDates(minfo,plugin,line,details,\
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

            #if (get_tv_series_info(plugin,tmp_info,get_tv_series_api_url(plugin,tvdbid)) > 0) {

            if (plugin == "thetvdb" ) {

                #TODO We could get all the series info - this would be cached anyway.
                result = extractEpisodeByDates_TvDb(tmp_info,tvdbid,y,m,d,details);

            } else if (plugin == "tvrage" ) {

                result = extractEpisodeByDates_rage(tmp_info,tvdbid,y,m,d,details);

            } else {
                plugin_error(plugin);
            }
            if (result) {
                INF("Found episode of "closeTitles[tvdbid]" on "y"-"m"-"d);
                details[TVID]=tvdbid;
                id0(result);
                break;
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
        ERR("Error message from server : "episodeInfo["/Data/Error"]);
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

        return 1;
    }
    return 0;
}

# 0=match -1=ep before date 1=episode after date 2=no such episode
function cmp_rage_ep(tvdbid,season,ep,date_string,xml,\
url_root,key,ret) {
    id1("XX cmp_rage_ep "season"x"ep" vs "date_string);
    key = "/show/episode/airdate";
    url_root = g_tvrage_api"/feeds/episodeinfo.php?sid="tvdbid"&ep=";
    ret = 2;
    if(fetchXML(url_root season"x"ep,"rage",xml)) {
        if (key in xml) {
            if (xml[key] == date_string) {
                ret = 0;
            } else if (xml[key] < date_string ) {
                ret = -1;
            } else {
                ret = 1;
            }
        }
    }
    id0("xml"xml[key]"="ret);
    return ret;
}

# at time of writing there is no direct search-by-date api function for tvrage.
# this code  steps through seasons and uses a binary chop.
# as shows that are datestamped tend to be the daily ones with 150+ episodes per season.
# the alternative is to parse all XML but this is very CPU intensive in awk on NMT
function extractEpisodeByDates_rage(minfo,tvdbid,y,m,d,details,\
xml,match_date,result,cmp,season,ep,low,high) {

    result=0;
    match_date=sprintf("%4d-%02d-%02d",y,m,d);

    # First step through seasons jumping 3 at a time
    
    season = 1;
    ep = 1;
    while((cmp = cmp_rage_ep(tvdbid,season,ep,match_date,xml)) == -1) {
        season += 3;
    }
    if (cmp != 0 ) {
        season -= 3;
        # search forward one at a time
        while((cmp = cmp_rage_ep(tvdbid,season,ep,match_date,xml)) == -1) {
            season ++;
        }
    }
    DEBUG("extractEpisodeByDates_rage season = "(season-1));

    # now do binary chop on episode.
    if (cmp != 0 ) {
        season --;
        if (season > 0 ) {
            low = 1;
            high = 512;
            while (low < high) {
                ep = int((low+high)/2);
                cmp = cmp_rage_ep(tvdbid,season,ep,match_date,xml);
                if (cmp == 0 ) {
                    break;
                }
                if (cmp == -1 ) {
                    low = ep+1;
                } else {
                    high = ep ;
                }
            }
        }
    }
    if (cmp == 0) {

        minfo["mi_airdate"]=formatDate(match_date);
        details[SEASON] = season;
        details[EPISODE] = ep;
        details[ADDITIONAL_INF]=xml["/show/episode/title"];
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
plugin,cat,p,tv_status,do_search,search_abbreviations,more_info,path_num,ret) {


    ret = "";

    # loop through path levels
    for(path_num = 1 ; path_num <= g_path_depth ; path_num ++ ) {

        for (p in g_tv_plugin_list) {

            if (tv_status) break;


            plugin = g_tv_plugin_list[p];

            # demote back to imdb title
            if (minfo["mi_imdb_title"] != minfo["mi_title"] && minfo["mi_imdb_title"] != "" ) {

                INF("*** revert title from "minfo["mi_title"]" to "minfo["mi_imdb_title"]);
                minfo["mi_title"] = minfo["mi_imdb_title"];
            }

            # checkTvFilenameFormat also uses the plugin to detect daily formats.
            # so if ellen.2009.03.13 is rejected at tvdb it is still passed by tvrage.

            do_search = 1;

            if (check_tv_names) {

                if (checkTvFilenameFormat(minfo,plugin,path_num,more_info)) {

                    search_abbreviations = more_info[1];

                    #minfo["mi_imdb"] may have been set by a date lookup
                    if (bestUrl == "") {
                        bestUrl = extractImdbLink(imdb(minfo));
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
    tvDbSeriesPage = get_tv_series_api_url(plugin,minfo_get_id(minfo,plugin));

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
            } else {
                # we also know the imdb id
                iid=imdb(minfo);
                if(iid == "") {
                    # use the tv id to find the imdb id
                    iid=tv2imdb(minfo);
                }
            }
            cat = get_imdb_info(extractImdbLink(iid),minfo);
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
        if (plugin == "thetvdb") {
            WARNING("Please update the IMDB ID for this series at the thetvdb website for improved scanning");
        }

        result = 0;
    }
    id0(result);
    return 0+ result;
}

# use the title and year to find the imdb id
function tv2imdb(minfo,\
key,iid) {

    iid = imdb(minfo);
    if (iid == "") {
    
        key=minfo["mi_title"]" "minfo["mi_year"];
        DEBUG("tv2imdb key=["key"]");
        if (!(key in g_tv2imdb)) {

            # Search for imdb page  - try to filter out Episode pages.
            iid = g_tv2imdb[key] = extractImdbId(web_search_first_imdb_link(key" +site:imdb.com \"TV Series\" -\"Episode Cast\"",key)); 
        }
        minfo_set_id("imdb",iid,minfo);
    }
    return iid;
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
initial,names) {

    delete alternateTitles;

    INF("Search Phase: epguid abbreviations");

    if (0) {
        initial = epguideInitial(abbrev);
        get_epguide_names_by_letter(initial,names);
        clean_titles_for_abbrev(names);
        searchAbbreviation(initial,names,abbrev,alternateTitles);

        #if the abbreviation begins with t it may stand for "the" so we need to 
        #check the index against the next letter. eg The Ultimate Fighter - tuf on the u page!
        if (initial == "t" ) {
            initial = epguideInitial(substr(abbrev,2));
            if (initial != "t" ) {
                get_epguide_names_by_letter(initial,names);
                clean_titles_for_abbrev(names);
                searchAbbreviation(initial,names,abbrev,alternateTitles);
            }
        }
    } else {
        # New method for abbreviations - use tvrage index
        initial = substr(abbrev,1,1);
        get_tvrage_names_by_letter(initial,names);
        clean_titles_for_abbrev(names);
        searchAbbreviation(initial,names,abbrev,alternateTitles);
    }
    dump(0,"abbrev["abbrev"]",alternateTitles);
}

function clean_titles_for_abbrev(names,\
i) {
    for(i in names) {
        names[i] = tolower(clean_title(names[i]));
    }
}

function possible_tv_titles(plugin,title,closeTitles,\
ret) {

    if (plugin == "thetvdb" ) {

        ret = searchTv(plugin,title,closeTitles);

    } else if (plugin == "tvrage" ) {

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

    if (plugin == "thetvdb") {

        url=expand_url(g_thetvdb_web"/api/GetSeries.php?seriesname=",title);
        filter_search_results(url,title,"/Data/Series","SeriesName","seriesid",allTitles);

    } else if (plugin == "tvrage") {

        url=g_tvrage_api"/feeds/search.php?show="title;
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
url,id2,date,nondate,key,filter,showInfo,year_range,title_regex,tags) {
    # If site does not have IMDB ids then use the title and premier date to search via web search
    if (imdbid) {

        key = plugin"/"imdbid;
        if (key in g_imdb2tv) {

            id2 = g_imdb2tv[key];

        } else {

            # First try API search or direct imdb search 
            if(plugin == "thetvdb") {

                id2 = imdb2thetvdb(imdbid);
            }

            if (id2 == "" || 1 ) {

                # search for series name directly using raw(ish) imdb name
                extractDate(minfo["mi_premier"],date,nondate);
                # We do a fuzzy year search esp for programs that have a pilot in the
                # year before episode 1
                #
                # This may cause a false match if two series with exactly the same name
                # started within two years of one another.
                year_range="("(minfo["mi_year"]-1)"|"minfo["mi_year"]"|"(minfo["mi_year"]+1)")";
                title_regex=tv_title2regex(minfo["mi_title"]);

                if(plugin == "thetvdb") {

                    url=expand_url(g_thetvdb_web"//api/GetSeries.php?seriesname=",minfo["mi_title"]);
                    if (fetchXML(url,"imdb2tvdb",showInfo,"")) {
                        #allow for titles "The Office (US)" or "The Office" and 
                        # hope the start year is enough to differentiate.
                        filter["/SeriesName"] = "~:^"title_regex"$";
                        filter["/FirstAired"] = "~:^"year_range"-";
                        if (find_elements(showInfo,"/Data/Series",filter,1,tags)) {
                            INF("Looking at tvdb "showInfo[tags[1]"/SeriesName"]);
                            id2 = showInfo[tags[1]"/seriesid"];
                        }
                    }

                } else if(plugin == "tvrage") {

                    if (fetchXML(g_tvrage_api"/feeds/search.php?show="minfo["mi_title"],"imdb2tvdb",showInfo,"")) {
                        #allow for titles "The Office (US)" or "The Office" and 
                        # hope the start year is enough to differentiate.
                        filter["/name"] = "~:^"title_regex"$";
                        filter["/started"] = "~:"year_range;
                        if (find_elements(showInfo,"/Results/show",filter,1,tags)) {
                            INF("Looking at tv rage "showInfo[tags[1]"/name"]);
                            id2 = showInfo[tags[1]"/showid"];
                        }
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
    imdb_id = imdb(minfo);
    if (imdb_id) {
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

function tvdb_series_url(id,lang) {

    return g_thetvdb_web"/data/series/"id"/"lang".xml";

}

function get_tv_series_api_url(plugin,tvdbid,\
url,i,num,langs,word,key) {
    if (tvdbid != "") {

        key=plugin":"tvdbid;
        if (plugin == "thetvdb") {

            if (!(key  in g_tvurl)) {
                #thetvdb returns English if the required language does not exist.
                #but there is no indication that this has happen. So we have to checl non-english request for English words.
                # or simply compare against the English version.
                num = get_langs(langs);
                for(i = 1 ; i <= num ; i++ ) {

                    url = tvdb_series_url(tvdbid,langs[i]);

                    if (url_state(url) == 0) {
                        if (langs[i] == "en" ) {
                            break;
                        } else if (langs[i+1] != "en" && (word=scanPageFirstMatch(url,"","\\<([Ss]he|[Hh]e|[Tt]he|and|[Tt]hey|their)\\>",1)) != "") {
                            INF("expected lang="langs[i]" but found "word" in text");
                        } else {
                            break;
                        }
                    }
                }
                g_tvurl[key] = url;
            }
            url = g_tvurl[key];

        } else if (plugin == "tvrage") {
            url = "http://services.tvrage.com/myfeeds/showinfo.php?key="g_api_rage"&sid="tvdbid;
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

    #DEBUG("XX Checking ["titleIn"] against ["possible_title"]");

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

    # Extract any bracketed qualifiers - eg (year) or (US)
    if (match(possible_title," \\([^)]+")) {
        yearOrCountry=tolower(clean_title(substr(possible_title,RSTART+2,RLENGTH-2),1));
        DEBUG("Qualifier ["yearOrCountry"]");
    }

    # change year to bracketed qualifier.
    #sub(/\<2[0-9][0-9][0-9]$/," (&)",titleIn);
    sub(/\<2[0-9][0-9][0-9]$/,"(&)",titleIn); # Removed space for now. Will fix with proper regex.

    # store anything before comma as shortName
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

    #DEBUG("XX titleIn["titleIn"]");
    #DEBUG("XX possible_title["possible_title"]");
#    INF("qualifed titleIn["titleIn" ("yearOrCountry")]");

    if (index(possible_title,titleIn) == 1) {
        #eg "jay leno show","jay leno"
        #eg "tonight show with jay leno","jay leno"



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

        } else if ( index(possible_title,titleIn" show")) {

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
    } else if ( index(possible_title,"late night with "titleIn)) {
        # Late Night With Some Person might just be known as "Some Person"
        # eg The Tonight Show With Jay Leno
        matchLevel = 4;

    } else if ( index(possible_title,"show with "titleIn)) {

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

function get_tvrage_names_by_letter(letter,names,\
url,count,i,names2,regex,parts) {

    delete names;
    id1("get_tvrage_names_by_letter abbeviations for "letter);
    regex="<id>([^<]+)</id><name>([^<]*)</name>";
    url = g_tvrage_api"/feeds/show_list_letter.php?letter="letter;
    scan_page_for_match_order(url,"<name>",regex,0,1,"",names2);
    for(i in names2) {
        gsub(/\&amp;/,"And",names2[i]);
        split(gensub(regex,SUBSEP"\\1"SUBSEP"\\2"SUBSEP,"g",names2[i]),parts,SUBSEP);
        names[parts[2]] = parts[3];
        count++;
    }
    id0(count);
    return count;
}

    
    



# Return the list of names in the epguide menu indexed by link
function get_epguide_names_by_letter(letter,names,\
url,title,link,links,i,count2) {
    id1("get_epguide_names_by_letter abbeviations for "letter);
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
    id0(count2);
    return 0+ count2;
}

# Search epGuide menu page for all titles that match the possible abbreviation.
# IN letter - menu page to search. Usually first letter of abbreviation except if abbreviation begins
#             with t then search both t page and subsequent letter - to account for "The xxx" on page x
# IN list of names that start with letter.
# IN titleIn - The thing we are looking for - eg ttscc
# IN/OUT alternateTitles - hash of titles - index is the title, value is 1
function searchAbbreviation(letter,names,titleIn,alternateTitles,\
possible_title,i,ltitle) {

    ltitle = tolower(titleIn);

    id1("Checking "titleIn" for abbeviations on menu page - "letter);
    #dump(0,"searchAbbreviation:",names);

    if (ltitle == "" ) return ;


    for(i in names) {


        possible_title = names[i];

        #DEBUG("searchAbbreviation ["ltitle"] vs ["possible_title"]");

        sub(/\(.*/,"",possible_title);
        gsub(/'/,"",possible_title);

        if (abbrevMatch(ltitle,possible_title)) {

            alternateTitles[possible_title]="abbreviation-initials";

        } else if (abbrevMatch(ltitle ltitle,possible_title)) { # eg "CSI: Crime Scene Investigation" vs csicsi"

            alternateTitles[possible_title]="abbreviation-double";

        } else if (abbrevContraction(ltitle,possible_title)) {

            alternateTitles[possible_title]="abbreviation-contraction";
        }

    }
    dump(0,"abbrevs",alternateTitles);
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

#function is_contraction(string,short,end_on_word,\
#i,short_len,offset) {
#
#    short_len = length(short);
#    if (end_on_word) {
#        short_len --;
#    }
#
#    offset = 1;
#    for(i = 1 ; i <= short_len ; i++ ) {
#        # look for letter in rest of string
#        if (j = index(substr(string,offset),substr(short,i,i))) {
#            offset = offset-1 + j;
#        } else {
#            return 0;
#        }
#    }
#    # Last letter
#    if  (end_on_word) {
#        return match(substr(string,offset),substr(short,i,i)"\\>");
#    } else {
#        return 1;
#    }
#}

# match tblt to tablet , grk greek etc.
# The contraction is allowed to match from the beginning of the title to the
# end of any whole word. eg greys = greys anatomy 
function abbrevContraction(abbrev,possible_title,\
found,regex,part) {


    # Use regular expressions to do the heavy lifting.
    # First if abbreviation is grk convert to ^g.*r.*k\>
    #
    # TODO Performance can be improved by just calling index for each letter in a loop. see is_contraction
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
    if (plugin == "thetvdb") {
        #Note episode may be 23,24 so convert to number.
        if (sub(/[a-z][a-z].xml$/,"default/"season"/"(episode+0)"/&",episodeUrl)) {
            return episodeUrl;
        }
    } else if (plugin == "tvrage") {

        sub(/showinfo/,"episodeinfo",episodeUrl);
        return episodeUrl"&ep="season"x"(episode+0);
    }
    return "";
}

#Get episode info by changing base url - this should really use the id
#but no time to refactor calling code at the moment.
function get_episode_xml(plugin,seriesUrl,season,episode,episodeInfo,\
episodeUrl,result) {
    delete episodeInfo;

    id1("get_episode_xml");

    gsub(/[^0-9,]/,"",episode);

    episodeUrl = get_episode_url(plugin,seriesUrl,season,episode);
    if (episodeUrl != "") {
        if (plugin == "thetvdb") {

            result = fetchXML(episodeUrl,plugin"-episode",episodeInfo);

        } else if (plugin == "tvrage" ) {
            result = fetchXML(episodeUrl,plugin"-episode",episodeInfo);
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

# get thetvdbid from imdbid
function imdb2thetvdb(imdbid,\
ret,xml) {
    #id1("XX NEW CHECK imdb2thetvdb "imdbid);
    if (!(imdbid in g_imdb2thetvdb)) {
        fetchXML(g_thetvdb_web"/api/GetSeriesByRemoteID?imdbid="imdbid,"imdb2tv",xml);
        # always set value regardless of fetchXML error status - to prevent re-query
        g_imdb2thetvdb[imdbid] = xml["/Data/Series/seriesid"];
    }
    ret = g_imdb2thetvdb[imdbid];
    id0(ret);
    return ret;
}

# Follow linked websites from tvrage to tvdb
# Note tvrage and thetvdb have recently become partners so this may become a direct link 
function rage_get_other_ids(minfo,\
rageid,showurl,thetvdb,imdb,ret,partners,p,partner,idlist) {

    rageid = minfo_get_id(minfo,"tvrage");


    if (rageid && !(rageid in g_rage2tvdb)) {

        id1("rage_get_other_ids "rageid);
        showurl = g_tvrage_web"/shows/id-"rageid;

        # Possible routes to thetvdb are: 

        # tvrage -> sharetv -> tvdb
        # tvrage -> epguide -> sharetv -> tvdb

        # tvrage -> sharetv -> imdb -> tvdb
        # tvrage -> epguide -> imdb -> tvdb
        # tvrage -> epguide -> sharetv->imdb -> tvdb
        # Using imdb link will only work if IMDB is set on thetvdb.

        # ideally the following line will work one day if tvrage add partner links to thetvdb
        imdb = minfo_get_id(minfo,"imdb");
        thetvdb = minfo_get_id(minfo,"thetvdb");

        partners[1] = "sharetv";
        partners[2] = "epguides";
        for(p = 1; p <= 2 ; p++ ) {
            if (imdb && thetvdb) break;

            # scan for partner link
            partner  = scan_page_for_first_link(showurl,partners[p],1);
            if (partner) {
                if (!imdb) {
                    imdb = extractImdbId(scan_page_for_first_link(partner,"imdb",1));
                }
                if (!thetvdb) {
                    thetvdb = scan_page_for_first_link(partner,"thetvdb",1);
                    if (match(thetvdb,"[?&]id=[0-9]+")) {
                        thetvdb = substr(thetvdb,RSTART+4,RLENGTH-4);
                    }
                }
            }
        }


        if (imdb) {
            idlist = idlist " imdb:"imdb;
        }
        if (thetvdb) {
            idlist = idlist " thetvdb:"thetvdb;
        }
        g_rage2tvdb[rageid] = idlist;
        id0(idlist);
    }

    if (g_rage2tvdb[rageid]) {
        minfo_merge_ids(minfo,g_rage2tvdb[rageid]);
        ret = 1;
    }
    id0(ret);
    return ret;
}

# 0=nothing 1=series 2=series+episode
function get_tv_series_info(plugin,minfo,tvDbSeriesUrl,\
result,minfo2,thetvdbid) {

    id1("get_tv_series_info("plugin"," tvDbSeriesUrl")");



    # mini-series may not have season set
    if (minfo["mi_season"] == "") {
        minfo["mi_season"] = 1;
    }

    if (plugin == "thetvdb") {
        result = get_tv_series_info_tvdb(minfo2,tvDbSeriesUrl,minfo["mi_season"],minfo["mi_episode"]);

    } else if (plugin == "tvrage") {

        result = get_tv_series_info_rage(minfo2,tvDbSeriesUrl,minfo["mi_season"],minfo["mi_episode"]);
        if (result) {
            #get posters from thetvdb
            rage_get_other_ids(minfo2);
        }

    } else {
        plugin_error(plugin);
    }

    thetvdbid = minfo_get_id(minfo2,"thetvdb");

    if (result && thetvdbid) {
        getTvDbSeasonBanner(minfo2,thetvdbid);
    }

#    ERR("UNCOMMENT THIS CODE");
    if (minfo["mi_episode"] ~ "^DVD[0-9]+$" ) {
        result++;
    }
#    ERR("UNCOMMENT THIS CODE");

    if (result) {
        minfo_merge(minfo,minfo2,plugin);

        DEBUG("Title:["minfo["mi_title"]"] Episode:["minfo["mi_eptitle"]"]"minfo["mi_season"]"x"minfo["mi_episode"]" date:"minfo["mi_airdate"]);
        DEBUG("");
    }

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
function get_tv_series_info_tvdb(minfo,tvDbSeriesUrl,season,episode,\
seriesInfo,episodeInfo,result,iid) {

    result=0;

    
    fetchXML(tvDbSeriesUrl,"thetvdb-series",seriesInfo);
    if ("/Data/Series/id" in seriesInfo) {

        dump(0,"tvdb series",seriesInfo);

        minfo["mi_season"]=season;
        minfo["mi_episode"]=episode;
        #Refine the title.
        minfo["mi_title"] = remove_br_year(seriesInfo["/Data/Series/SeriesName"]);

        minfo["mi_year"] = substr(seriesInfo["/Data/Series/FirstAired"],1,4);
        minfo["mi_premier"] = formatDate(seriesInfo["/Data/Series/FirstAired"]);
        minfo["mi_plot"]= clean_plot(seriesInfo["/Data/Series/Overview"]);
        minfo["mi_genre"]= seriesInfo["/Data/Series/Genre"];
        minfo["mi_certrating"] = seriesInfo["/Data/Series/ContentRating"];
        minfo["mi_rating"] = seriesInfo["/Data/Series/Rating"];
        minfo["mi_poster"]=tvDbImageUrl(seriesInfo["/Data/Series/poster"]);

        minfo_set_id("thetvdb",seriesInfo["/Data/Series/id"],minfo);

        iid = seriesInfo["/Data/Series/IMDB_ID"];
        minfo_set_id("imdb",iid,minfo);

        result ++;

        # For twin episodes just use the first episode number for lookup by adding 0
        dump(0,"pre-episode",minfo);

        if (episode ~ "^[0-9,]+$" ) {

            if (get_episode_xml("thetvdb",tvDbSeriesUrl,season,episode,episodeInfo)) {

                if ("/Data/Episode/id" in episodeInfo) {
                    minfo["mi_airdate"]=formatDate(episodeInfo["/Data/Episode/FirstAired"]);

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

    if (iid == "" ) {
        WARNING("get_tv_series_info returns blank imdb url. Consider updating the imdb field for this series at "g_thetvdb_web);
    } else {
        DEBUG("get_tv_series_info returns imdb url ["iid"]");
    }
    return 0+ result;
}

function tvDbImageUrl(path) {
    if(path != "") {
        return "http://thetvdb.com/banners/" url_encode(html_decode(path));
    } else {
        return "";
    }
}

function getTvDbSeasonBanner(minfo,tvdbid,\
xml,filter,r,bannerApiUrl,get_poster,get_fanart,fetched,xmlout,langs,lnum,i) {

    lnum = get_langs(langs);

    bannerApiUrl = g_thetvdb_web"/data/series/"tvdbid"/banners.xml";
    r="/Banners/Banner";
    get_poster = getting_poster(minfo,1);
    get_fanart = getting_fanart(minfo,1);

    if (get_poster || get_fanart) {
        fetched = fetchXML(bannerApiUrl,"banners",xml,"");
    }

    if (get_poster && fetched) {
        delete filter;
        filter["/BannerType"] = "season";
        filter["/Season"] = minfo["mi_season"];
        for(i = 1 ; i <= lnum ; i++ ) {
            filter["/Language"] = langs[i];
            if (find_elements(xml,"/Banners/Banner",filter,1,xmlout)) {
                minfo["mi_poster"]=tvDbImageUrl(xml[xmlout[1]"/BannerPath"]);
                DEBUG("Season Poster = "minfo["mi_poster"]);
                break;
            }
        }
    }

    if (get_fanart && fetched) {

        delete filter;
        filter["/BannerType"] = "fanart";
        for(i = 1 ; i <= lnum ; i++ ) {
            filter["/Language"] = langs[i];
            if (find_elements(xml,"/Banners/Banner",filter,1,xmlout)) {
                minfo["mi_fanart"]=tvDbImageUrl(xml[xmlout[1]"/BannerPath"]);
                DEBUG("Fanart = "minfo["mi_fanart"]);
                break;
            }
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
function get_tv_series_info_rage(minfo,tvDbSeriesUrl,season,episode,\
seriesInfo,episodeInfo,filter,url,e,result,pi) {

    pi="tvrage";
    result = 0;
    delete filter;

    if (fetchXML(tvDbSeriesUrl,"tvinfo-show",seriesInfo,"")) {

        dump(0,"tvrage series",seriesInfo);
        minfo["mi_season"]=season;
        minfo["mi_episode"]=episode;
        minfo["mi_title"]=clean_title(remove_br_year(seriesInfo["/Showinfo/showname"]));
        minfo["mi_year"] = substr(seriesInfo["/Showinfo/started"],8,4);
        minfo["mi_premier"]=formatDate(seriesInfo["/Showinfo/started"]);


        url=urladd(seriesInfo["/Showinfo/showlink"],"remove_add336=1&bremove_add=1");
        minfo["mi_plot"]=clean_plot(seriesInfo["/Showinfo/summary"]);

        minfo_set_id("tvrage",seriesInfo["/Showinfo/showid"],minfo);
        result ++;

        rage_get_other_ids(minfo);

        dump(0,"pre-episode",minfo);

        e="/show/episode";
        if (episode ~ "^[0-9,]+$" ) {
            if (get_episode_xml(pi,tvDbSeriesUrl,season,episode,episodeInfo)) {

                set_eptitle(minfo,episodeInfo[e"/title"]);

                minfo["mi_airdate"]=formatDate(episodeInfo[e"/airdate"]);

                if (minfo["mi_epplot"] == "") {
                    minfo["mi_epplot"] = clean_plot(episodeInfo[e"/summary"]);
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
            if (plugin == "thetvdb") {

                ageHash[id] = xml["/Data/Episode/FirstAired"];
                eptitle = tolower(xml["/Data/Episode/EpisodeName"]);

            } else if (plugin == "tvrage" ) {

                ageHash[id] = xml["/show/episode/airdate"];
                eptitle = tolower(xml["/show/episode/title"]);

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


