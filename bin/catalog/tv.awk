# called from main scan function at the start of each new scan folder.
function clear_tv_folder_info() {
    delete g_default_tv_title_for_folder;
    delete g_tvDbIndex;
    #if(LG)DEBUG("Reset tv folder details");
}

# return last n parts of path. If no more then return empty string.
function last_path_parts(minfo,n,\
ret,i,j,dirCount,dirs) {

    ret = remove_format_tags(minfo[NAME]);
    if (n > 1 ) {
       dirCount = split(minfo[DIR],dirs,"/");
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
function checkTvFilenameFormat(minfo,plugin,path_parts,more_info,episode_sep_present,episode_sep_absent,\
details,line,ret,name,i,start,end) {

    ret = 0;
   delete more_info;
   #First get season and episode information

   name = minfo[NAME];


   # During normal TV scan path_parts is set from calling function.
   # hoever it is also called with 0 from scan.awk

   if (path_parts == 0) {
       start = 1;
       end = 3;
   } else {
       start = end = path_parts;
   }

   for(i = start ; i <= end ; i++ ) {
    

       line = last_path_parts(minfo,i);

       if (match(tolower(line),"(video|tv|movies).*\\/")) {
           if(LD)DETAIL("Generic folder? "line);
           break;
       }

       if (line == "") break;


       # After extracting the title text we look for matching tv programs
       # We only look at abbreviations if the title did NOT use the folder name.
       # The assumption is the people abbreviate file names but not folder names.
       more_info[1]=(path_parts == 1); # enable abbrevation scraping later only at filename level

        if (extractEpisodeByPatterns(plugin,line,details,episode_sep_present,episode_sep_absent)==1) {


            if (details[TITLE] == "" ) {
                # format = 202 some text...
                # title may be in parent folder. but we will try to search by additional info first.
                searchByEpisodeName(plugin,details);
            }
            if (details[TITLE] ) {

                adjustTitle(minfo,details[TITLE],"filename");

                ret = 1;

                minfo[SEASON]=details[SEASON];
                minfo[EPISODE]=details[EPISODE];

                if(LD)DETAIL("Found tv info in file name:"line" title:["minfo[TITLE]"] ["minfo[SEASON]"] x ["minfo[EPISODE]"]");

                ## Commented Out As Double Episode checked elsewhere to shrink code ##
                ## Left In So We Can Ensure It's Ok ##
                ## If the episode is a twin episode eg S05E23E24 => 23e24 then replace e with ,
                ## Then prior to any DB lookups we just use the first integer (episode+0)
                ## To avoid changing the e in the BigBrother d000e format first check its not at the end 

                # local ePos

                #ePos = index(minfo[EPISODE],",");
                #if (ePos -1 >= 0 && ( ePos - length(minfo[EPISODE]) < 0 )) {
                #    #gsub(/[-e]+/,",",minfo[EPISODE]);
                #    #sub(/[-]/,"",minfo[EPISODE]);
                #    if(LG)DEBUG("Double Episode : "minfo[EPISODE]);
                #}


                minfo_set_id(plugin,details[TVID],minfo);

                # This is the weakest form of tv categorisation, as the filename may just look like a TV show
                # So only set if it is blank
                if (minfo[CATEGORY] == "") {
                    minfo[CATEGORY] = "T";
                }

                minfo[ADDITIONAL_INF] = clean_title(details[ADDITIONAL_INF]);
                # Now check the title.
                #TODO
                break;
            }
        }
    }
    return ret;
}

function searchByEpisodeName(plugin,details,\
terms,results,ret,url,domain,filter_text,filter_regex,minfo2,\
    bing_url,google_url,\
    bing_id,google_id) {
    # search the tv sites using season , episode no and episode name.
    # ony bing or google - yahoo is not good here
    id1("searchByEpisodeName "plugin);
    dump(0,"searchByEpisodeName",details);

    if (!(plugin in g_default_tv_title_for_folder)) {

        if (plugin == "thetvdb") {
            terms="\"season "details[SEASON]"\" \""details[EPISODE]" : "clean_title(details[ADDITIONAL_INF])"\" site:thetvdb.com";
            domain="thetvdb";
            filter_text="seriesid=";
            filter_regex="seriesid=[0-9]+";

        } else if (plugin == "tvrage") {
            terms="\"season "details[SEASON]"\" "details[SEASON]"x"sprintf("%02d",details[EPISODE])" \""clean_title(details[ADDITIONAL_INF])"\" site:tvrage.com";
            domain="tvrage";
            filter_text="/shows/";
            filter_regex="/shows/[0-9]+";
        } 

        if (domain) {

            bing_url = scan_page_for_first_link(g_search_bing terms,domain,0);

            if (bing_url != "") {
                scan_page_for_match_counts(bing_url,filter_text,filter_regex,0,0,results);
                bing_id = subexp(getMax(results,1,1),"[0-9]+");
                if(LD)DETAIL("bing_id="bing_id);

                google_url = scan_page_for_first_link(g_search_google terms,domain,0);

                if (google_url != "") {
                    scan_page_for_match_counts(google_url,filter_text,filter_regex,0,0,results);
                    google_id = subexp(getMax(results,1,1),"[0-9]+");
                    if(LD)DETAIL("google_id="google_id);
                }

                if (bing_id == google_id) {

                    url = get_tv_series_api_url(plugin,bing_id);
                    if (get_tv_series_info(plugin,minfo2,url,details[SEASON],details[EPISODE])) {
                        if (similar(minfo2[EPTITLE],details[ADDITIONAL_INF]) < 0.5 ) {

                            if (minfo2[EPTITLE] != "Pilot" || details[SEASON]details[EPISODE] != 11 ) {

                                #This maps all blank titles to a given title for the current folder.
                                g_default_tv_title_for_folder[plugin,TITLE] = minfo2[TITLE];
                                g_default_tv_title_for_folder[plugin] = bing_id;

                                #Now also add the maapinf from the title to the specifc show id.
                                plugin_title_set_url(plugin,g_default_tv_title_for_folder[plugin,TITLE],get_tv_series_api_url(plugin,bing_id));
                            }
                        }
                    }
                } else {
                    if(LD)DETAIL("different ids bing:"bing_id" != google:"google_id" - ignoring");
                }
            }
        } else {
            WARNING("unknown plugin ["plugin"]");
        }
    }

    if (plugin in g_default_tv_title_for_folder) {

        details[TITLE] = g_default_tv_title_for_folder[plugin,TITLE];
        ret = details[TVID] = g_default_tv_title_for_folder[plugin];
        if(LG)DEBUG("Using "ret":"details[TITLE]);
    }

    id0(ret);
    return ret;
}
# If Plugin != "" then it will also check episodes by date.
function extractEpisodeByPatterns(plugin,line,details,episode_sep_present,episode_sep_absent,\
ret,p,pat,i,parts,sreg,ereg,sep,\
season_prefix,ep_prefix,dvd_prefix,part_prefix) {

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

    season_prefix="(SERIES|SEASON|SAISON|[Ss]eries|[Ss]eason|[Ss]aison|[Ss])";
    ep_prefix="(EPISODE|EP.?|[Ee]pisode|[Ee]p.?|[Ee]|/)";
    dvd_prefix="(DISC|DVD|[Dd]isc|[Dd]vd|[Dd])";
    part_prefix="\\<(PART|PT|EPISODE|[Pp]art|[Pp]t|[Ee]pisode|[Ee][Pp]?)";
    sep="[-_./ ]*";


    # Text is between season and episode - search these before movies.
    if (episode_sep_present) {
        #pat[++p]="s()"sreg"[/ .]?[e/]([0-9]+[-,e0-9]+)@\\1\t\\2\t\\3@";

        #multi episode
        pat[++p]="s()"sreg sep "[eE/]([0-9][0-9]?([-,eE]+[0-9][0-9]?){1,})@\\1\t\\2\t\\3@";
        # long forms season 1 ep  3
        pat[++p]="\\<()"season_prefix"[^[:alnum:]]*"sreg sep ep_prefix"[^[:alnum:]]*"ereg"@\\1\t\\3\t\\5@";

        # TV DVDs
        pat[++p]="\\<()"season_prefix"[^[:alnum:]]*"sreg sep dvd_prefix"[^[:alnum:]]*"ereg"@\\1\t\\3\t\\5@dvd";

        #s00e00 (allow d00a for BigBrother)
        pat[++p]="s()?"sreg sep "[Ee/]([0-9]+[a-e]?)@\\1\t\\2\t\\3@";

        #00x00
        pat[++p]="([^[:alnum:]])"sreg sep "x" sep ereg"@\\1\t\\2\t\\3@";
        #Try to extract dates before patterns because 2009 could be part of 2009.12.05 or  mean s20e09
        # extractEpisodeByDates is also called by other logic. 
        pat[++p]="DATE";
    }

    #just a number - search these last after trying movies first.
    if(episode_sep_absent) {
        pat[++p]="([^-0-9]|\\<)([1-9]|2[1-9]|1[0-8]|[03-9][0-9])"sep"([0-9][0-9])@\\1\t\\2\t\\3@";

        #exclude 720p
        # pat[++p]="([^-0-9]|\\<)([1-689]|2[1-9]|1[0-8]|[03-9][0-9])"sep"([0-9][0-9])@\\1\t\\2\t\\3@";
        #pat[++p]="([^-0-9]|\\<)(7)"sep"([013-9][0-9]|2[1-9])@\\1\t\\2\t\\3@";

        # Part n - no season
        pat[++p]="\\<()()"part_prefix"[^[:alnum:]]?("ereg"|"g_roman_regex")@\\1\t\\2\t\\4@";

        # season but no episode
        # eg Season 9/family guy 0915 will match this but episode will be blank, so matching is deferred until 2nd phase
        # of TV searching when the 0915 pattern will get matched first
        # 
        pat[++p]="\\<()"season_prefix"[^[:alnum:]]*"sreg"()@\\1\t\\3\t\\4@FILE";

    }



    for(i = 1 ; p-i >= 0 ; i++ ) {
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
        if (ret) break;
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
        dump(0,"matches",rtext);

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

        if(LG)DEBUG("ignoring ["reg_match"]");

    } else if (split(gensub("^"regex"$",capture_list,1,reg_match),matches,"\t") != 3) {

        WARNING("Expected 3 parts");

    } else {
        id1("extractEpisodeByPatternSingle:"reg_match);


        #if(LD)DETAIL("regex=["regex"]");
        #if(LD)DETAIL("capture_list=["capture_list"]");
        #if(LD)DETAIL("reg_match=["reg_match"]");
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
        #if(LG)DEBUG("ExtractEpisode:2 Title= ["title"]");
        #Remove release group info only if there is no space in the title.
        #scene releases are often group-title.s01e01.avi with no spaces and all lower case.
        if (index(title,"-")) {
            if (!index(line," ") &&  match(title,"^[[:alpha:]][[:alnum:]]+[-][[:alnum:]]+$")) {
               tmpTitle=substr(title,RSTART+RLENGTH);
               if (tmpTitle != "" ) {
                   if(LD)DETAIL("Removed group was ["title"] now ["tmpTitle"]");
                   title=tmpTitle;
               }
            } else {
               if(LD)DETAIL("Using full hyphenated title "title);
            }
        }

        #if(LG)DEBUG("ExtractEpisode: Title= ["title"]");
        title = clean_title(title,2);
        
        if(LG)DEBUG("ExtractEpisode: Title= ["title"]");

        #============----------------------------------

        if (season - 50 > 0 ) {

            if(LG)DEBUG("Reject season > 50");

        } else if (ep - 52 > 0  && index(ep,"e") == 0 ) {

            if(LG)DEBUG("Reject episode "ep" > 52 : expect date format ");

        } else {

            #BigBrother episodes with trailing character.
            gsub(/[^0-9]+/,",",ep); #
            if(LG)DEBUG("Episode : "ep);
            gsub(/\<0+/,"",ep);
            gsub(/,,+/,",",ep);
            sub(/^,+/,"",ep);

            details[EPISODE] = ep;
            details[SEASON] = num(season);
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
date,nonDate,title,rest,y,m,d,tvdbid,result,closeTitles,tmp_info,total,i) {

    result=0;
    id1("extractEpisodeByDates "plugin" "line);
    if (extractDate(line,date,nonDate)) {
        rest=nonDate[2];

        details[TITLE]= title = clean_title(nonDate[1]);

        y = date[1];
        m = date[2];
        d = date[3];

        #search for matching shownames and pick the one that has an episode for the given date.
        total = searchTv(plugin,title,closeTitles);

        if(LG)DEBUG("Checking the following series for "title" "y"/"m"/"d);
        dump(0,"date check",closeTitles);

        for(i = 1 ; i<= total ; i++ ) {

            tvdbid = closeTitles[i,1];

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
                if(LD)DETAIL("Found episode of "tvdbid":"closeTitles[i,2]" on "y"-"m"-"d);
                details[TVID]=tvdbid;
                break;
            }
        }
        if (result == 0) {
            if(LD)DETAIL(":( Couldnt find episode "y"/"m"/"d" - using file information");
            details[SEASON]=y;
            details[EPISODE]=sprintf("%02d%02d",m,d);
            sub(/\....$/,"",rest);
            details[ADDITIONAL_INF]=clean_title(rest);
        }
    }
    id0(result);
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

        minfo[AIRDATE]=formatDate(episodeInfo["/Data/Episode/FirstAired"]);
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
    id1("cmp_rage_ep "season"x"ep" vs "date_string);
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
    if(LG)DEBUG("extractEpisodeByDates_rage season = "(season-1));

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

        minfo[AIRDATE]=formatDate(match_date);
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

function tv_search_simple(minfo,bestUrl,episode_sep_present,episode_sep_absent) {
    return tv_check_and_search_all(minfo,bestUrl,0,episode_sep_present,episode_sep_absent);
}

function tv_search_complex(minfo,bestUrl,episode_sep_present,episode_sep_absent) {
    return tv_check_and_search_all(minfo,bestUrl,1,episode_sep_present,episode_sep_absent);
}


# For each tv plugin - search for a match.
# idx = current show
# bestUrl = imdb url
# check_tv_names - if 1 then we do not have any imdb info - check tv formats and check abbreviations.
#   if 0 then we know it is a tv show from IMDB - just search the TV site directly.
#
# returns cat="T" tv show , "M" = movie , "" = unknown.

function tv_check_and_search_all(minfo,bestUrl,check_tv_names,episode_sep_present,episode_sep_absent,\
plugin,cat,p,tv_status,do_search,search_abbreviations,more_info,path_num,ret) {


    id1("tv_check_and_search_all check_tv_names="check_tv_names);
    ret = "";

    # loop through path levels
    for(path_num = 1 ; path_num <= g_path_depth ; path_num ++ ) {

        for (p in g_tv_plugin_list) {

            if (tv_status) break;


            plugin = g_tv_plugin_list[p];

            # demote back to imdb title
            if (minfo["mi_imdb_title"] != minfo[TITLE] && minfo["mi_imdb_title"] != "" ) {

                if(LD)DETAIL("*** revert title from "minfo[TITLE]" to "minfo["mi_imdb_title"]);
                minfo[TITLE] = minfo["mi_imdb_title"];
            }

            # checkTvFilenameFormat also uses the plugin to detect daily formats.
            # so if ellen.2009.03.13 is rejected at tvdb it is still passed by tvrage.

            do_search = 1;

            ## The check for blank episode is a result of some dodgy coding.
            # see split_episode_search in scan.awk.
            ################################################################
            if (check_tv_names || minfo[EPISODE] == "" ) {

                if (checkTvFilenameFormat(minfo,plugin,path_num,more_info,episode_sep_present,episode_sep_absent)) {

                    search_abbreviations = more_info[1];

                    #minfo["mi_imdb"] may have been set by a date lookup in checkTvFilenameFormat or by tvdb info in tv_search
                    if (bestUrl == "") {
                        bestUrl = extractImdbLink(imdb(minfo));
                        if (bestUrl) {
                            if (get_imdb_info(bestUrl,minfo) != "T") {
                                do_search = 0;
                            }
                        }
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
                if (minfo[EPISODE] !~ "^[0-9]+$" ) {
                    #no point in trying other tv plugins
                    break;
                }
                if (tv_status == 2 ) break;

            }
        }
    }
    if (tv_status) {
        cat = minfo[CATEGORY];
    }
    #minfo["mi_imdb"] may have been set by tvdb info in tv_search
    if (bestUrl == "") {
        bestUrl = extractImdbLink(imdb(minfo));
        if (bestUrl) {
            if (get_imdb_info(bestUrl,minfo) != "T") {
                do_search = 0;
            }
        }
    }
    id0(cat);
    return cat;
}

# 0=nothing found 1=series but no episode 2=series+episode
# If imdbUrl is set the details have already been fetched and it looks like a tv show on IMDB
function tv_search(plugin,minfo,imdbUrl,search_abbreviations,\
tvDbSeriesPage,result,tvid,cat,iid) {

    result=0;

    id1("tv_search ("plugin",imdb="imdbUrl",abbr="search_abbreviations")");

    #This will succedd if we already have the tvid when doing the checkTvFilenameFormat
    #checkTvFilenameFormat() may fetch the tvid while doing a date check for daily shows.
    tvDbSeriesPage = get_tv_series_api_url(plugin,minfo_get_id(minfo,plugin));

    if (tvDbSeriesPage == "" && imdbUrl == "" ) { 
        # do not know tvid nor imdbid - use the title to search tv indexes.
        tvDbSeriesPage = search_tv_series_names(plugin,minfo,minfo[TITLE],search_abbreviations);
    }

    if (tvDbSeriesPage != "" ) { 
        # We know the TV id - use this to get the imdb id
        result = get_tv_series_info(plugin,minfo,tvDbSeriesPage); #this may set imdb url
        if (result) {
            if (!imdbUrl) {
                # we didn't know the imdb id before - but do now.
                iid=imdb(minfo);
                if(iid == "") {
                    # use the tv id to find the imdb id
                    iid=tv2imdb(minfo);
                }
                if(iid) {
                    cat = get_imdb_info(extractImdbLink(iid),minfo);
                    if (cat == "M" ) {
                        WARNING("Error getting IMDB ID from tv - looks like a movie??");
                        if (plugin == "thetvdb") {
                            WARNING("Please update the IMDB ID for this series at the thetvdb website for improved scanning");
                        }

                        result = 0;
                    }
                }
            }
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
            # use the imdb id to find the tv id - if imdbUrl is set and we get here then IMDB thinks it's a tv show.
            # find the tvid - this can miss if the tv plugin api does not have imdb lookup
            tvid = find_tvid(plugin,minfo,extractImdbId(imdbUrl));
            if(tvid != "") {
                tvDbSeriesPage = get_tv_series_api_url(plugin,tvid);
                result = get_tv_series_info(plugin,minfo,tvDbSeriesPage);
            }
        }
    }
    # check if imdb info has just been obtained from tv website
    if (result && !imdbUrl && imdb(minfo)) {
        get_imdb_info(extractImdbLink(iid),minfo);
    }
    
    id0(minfo[TITLE]" - "result);
    return 0+ result;
}

function tv_title_year_to_imdb(title,year,\
key,iid) {
    key=title" "year;
    if (!(key in g_tv2imdb)) {

        # Search for imdb page  - try to filter out Episode pages.
        g_tv2imdb[key] = extractImdbId(web_search_first_imdb_link(key" +site:imdb.com \"TV\"")); 
    }
    iid = g_tv2imdb[key];
    if(LG)DEBUG("tv_title_year_to_imdb key=["key"]="iid);
    return iid;
}

# use the title and year to find the imdb id
function tv2imdb(minfo,\
iid) {

    iid = imdb(minfo);
    if (iid == "") {

        iid = tv_title_year_to_imdb(minfo[TITLE],minfo[YEAR]);
    
        minfo_set_id("imdb",iid,minfo);
    }
    return iid;
}

function search_tv_series_names(plugin,minfo,title,search_abbreviations,\
tnum,t,i,url,dups) {

    tnum = alternate_titles(tnum,title,t,dups);
    if (tolower(title) ~ /^bbc /) {
        tnum = alternate_titles(tnum,substr(title,4),t,dups);
    }
    # Remove possible scene name prefix? xx-show.s01e01 xx-show-s01e01
    if (match(minfo[NAME],"^[a-z]+-[-.a-z0-9]+$")) {
        tnum = alternate_titles(tnum,gensub(/[^ ]+ /,"",1,title),t,dups);
    }

    dump(0,"search_tv_series_names titles",t);

    for(i = 1 ; i <= tnum ; i++ ) {
        url = search_tv_series_names2(plugin,minfo,t[i],search_abbreviations);
        if (url != "") break;
    } 
    return url;
}

function plugin_title_get_url(plugin,title,\
ret,key) {
    key=plugin"/"title;
    if ((key in g_tvDbIndex)) {
        ret = g_tvDbIndex[key];
        if(LD)DETAIL("previous tv mapping ["key"] -> ["ret"]");
    } else {
        if(LD)DETAIL("no tv mapping ["key"]");
    }
    return ret;
}

function plugin_title_set_url(plugin,title,url,\
key) {
    key=plugin"/"title;
    if(LD)DETAIL("set tv mapping ["key"] = ["url"]");
    g_tvDbIndex[key] = url;
}

function search_tv_series_names2(plugin,minfo,title,search_abbreviations,\
tvDbSeriesPage) {

    id1("search_tv_series_names2 "plugin":"title);

    if ((tvDbSeriesPage = plugin_title_get_url(plugin,title)) == "") {

        tvDbSeriesPage = searchTvDbTitles(plugin,minfo,title);
        if(LG)DEBUG("search_tv_series_names: bytitles=["tvDbSeriesPage"]"search_abbreviations);
    }
    if (tvDbSeriesPage == "" && search_abbreviations) {

        tvDbSeriesPage = search_abbreviations(plugin,minfo,title);
        if(LG)DEBUG("search_tv_series_names: search_abbreviations =["tvDbSeriesPage"]");
    }

    if(LG)DEBUG("search_tv_series_names: pre search_close_spelling =["tvDbSeriesPage"]["plugin"]");
    if (tvDbSeriesPage == "" && plugin == "thetvdb") {

        # Only call this if there is no exact match via standard apis
        tvDbSeriesPage = search_close_spelling(plugin,minfo,title);
        if(LG)DEBUG("search_tv_series_names: search_close_spelling =["tvDbSeriesPage"]");

    }

    if (tvDbSeriesPage == "" ) {
        WARNING("search_tv_series_names could not find series page");
    } else {
        if(LG)DEBUG("search_tv_series_names Search looking at "tvDbSeriesPage);
        plugin_title_set_url(plugin,title,tvDbSeriesPage);
    }
    id0(tvDbSeriesPage);

    return tvDbSeriesPage;
}

function search_close_spelling(plugin,minfo,title,\
tvDbSeriesPage,tvdbid,total,closeTitles) {
    id1("Find title with shortest edit distance.");
    total = closest_title_in_list(title,closeTitles);
    tvdbid = selectBestOfBestTitle(plugin,minfo,total,closeTitles);
    if (tvdbid != "") {
        tvDbSeriesPage=get_tv_series_api_url(plugin,tvdbid);
    }
    id0(tvDbSeriesPage);
    return tvDbSeriesPage;
}

function same_show_diff_titles(total,showIds,\
all_same,i,id,title) {
    if (total > 1) {
        id=showIds[1,1];
        title=showIds[1,2];
        if(LG)DEBUG(" Check if this is alternate names for same show . eg 'CSI NY' 'CSI: NY'");
        all_same=1;
        for(i = 2; i<= total ; i++ ) {
            if (showIds[i,1] != id) {
                all_same=0;
                break;
            }
        }
        if (all_same) {
            total = 1;
            if(LD)DETAIL("Selecting first show");
            delete showIds;
            showIds[1,1]=id;
            showIds[1,2]=title;
        }
    }
    return total;
}

# Given a list of potential show ids, a season and an episode,  go through then all to check the page exists.
function filter_episode_exists(plugin,total,showIds,minfo,\
s,e,i,newShows,newTotal,u,ulist) {

    id1("filter_episode_exists "total);
    e=minfo[EPISODE];
    s=minfo[SEASON];
    newTotal = total;
    if (s ~ /^[0-9]+$/ && e ~ /^[0-9]+$/ ) {
        for(i = 1 ; i<= total ; i++ ) {
            u = get_tv_series_api_url(plugin,showIds[i,1]);
            u = get_episode_url(plugin,u,s,e);
            ulist[i] = u;
        }
        if (spiders(ulist,1,5)) {
            newTotal = copy_ids_and_titles(ulist,showIds,newShows);
        }
    }

    dump(0,"filter_episode_exists",showIds);
    id0(newTotal);

    return newTotal;
}


function search_abbreviations(plugin,minfo,title,\
cache_key,tvDbSeriesPage,tvdbid,showIds,total) {
    # Abbreviation search

    cache_key=minfo[DIR]"@"title;

    if(cache_key in g_abbrev_cache) {

        tvDbSeriesPage = g_abbrev_cache[cache_key];
        if(LD)DETAIL("Fetched abbreviation "cache_key" = "tvDbSeriesPage);

    } else {

        id1("search_abbreviations");

        # List of letters to check - in order.
        # First try to match abbreviation against all shows beggining with the same letter.
        # Note the indexes are built so that 'The Walking Dead' is under both T and W.
        delete showIds;

        # Check the letter if it is the first letter of the abbreviation 
        total=searchAbbreviationAgainstTitles(plugin,tolower(substr(title,1,1)),title,showIds);
        if (total == 0 && index(title,"-")) {
            sub(/[^-]+-/,"",title);
            if(LD)DETAIL("removed prefix ["title"]");
            total=searchAbbreviationAgainstTitles(plugin,tolower(substr(title,1,1)),title,showIds);
        }

        dump_ids_and_titles("possible matches",total,showIds);

        #If a show is abbreviated then always do a web search to confirm - even if number of options is 1.
        total = filter_web_titles2(g_search_google,total,showIds,cleanSuffix(minfo));
        total = filter_web_titles2(g_search_bing_desktop,total,showIds,cleanSuffix(minfo));
        total = filter_web_titles2(g_search_nzbindex,total,showIds,cleanSuffix(minfo));
        total = filter_web_titles2(g_search_mysterbin,total,showIds,cleanSuffix(minfo));
        #total = filter_web_titles2(g_search_binsearch,total,showIds,cleanSuffix(minfo));

        if (total > 1) {
            total = filter_episode_exists(plugin,total,showIds,minfo);
        }
        #
        total = same_show_diff_titles(total,showIds);
        if (total == 1) {
            # If total is 1, then we could still do a filename search to confirm.
            # This will reduce false positives for downloaded content, but may not be so good for user generated files 
            # or oldder files. So for now we will disable checking if total  = 1.
            if(LD)DETAIL("Title is only option so assuming it is correct. Skipping filename checks ");

        }

        dump_ids_and_titles("filtered matches",total,showIds);


        # TODO the selectBestOfBestTitle calls the relativeAge function which also
        # picks the episode title with the shortest edit distance. Because this does
        # a query by SnnEnn this is more concrete information than the check for link counts
        # performed by filterUsenetTitles - so the getRelativeAgeAndEpTitles should be
        # split into:
        # 1. a plain filter that checks the SnnEnn exists for a given show ( which is called before the usenet/link count filter.)
        # 2. A filter that picks episode title with lowest edit distance.
        tvdbid = selectBestOfBestTitle(plugin,minfo,total,showIds);

        tvDbSeriesPage=get_tv_series_api_url(plugin,tvdbid);

        if (tvDbSeriesPage) {
            g_abbrev_cache[cache_key] = tvDbSeriesPage;
            if(LD)DETAIL("Caching abbreviation "cache_key" = "tvDbSeriesPage);
        }

        id0(tvDbSeriesPage);
    }
    return tvDbSeriesPage;
}

# Search the tv menus for names that could be represented by the abbreviation 
# IN abbrev - abbreviated name eg ttscc
# IN/OUT alternateTitles - hash of titles [n,1]=id [n,2]=title (as shows may have titles in other languages)

# return number of matches
function searchAbbreviationAgainstTitles(plugin,initial,abbrev,alternateTitles,\
names,count) {

    id1("searchAbbreviationAgainstTitles plugin="plugin" initial="initial" abbrev="abbrev);


    # New method for abbreviations - use tvrage index
    if (plugin == "thetvdb" ) {
        count = get_tvdb_names_by_letter(initial,names);
    } else if (plugin == "tvrage" ) {
        count = get_tvrage_names_by_letter(initial,names);
    } else {
        ERR("@@@ Bad plugin ["plugin"]");
    }
    clean_titles_for_abbrev(count,names);
    #dump_ids_and_titles("initial",count,names);
    count = searchAbbreviation(initial,count,names,abbrev,alternateTitles);
    if (count == -1) {
        if(LD)DETAIL("too many matches - clearing");
        delete alternateTitles;
        count = 0;
    }
    id0(count);
    return count;
}

function clean_titles_for_abbrev(count,names,\
i) {
    for(i = 1 ; i <= count ; i++ ) {
        names[i,2] = tolower(clean_title(names[i,2]));
    }
}

function dump_ids_and_titles(label,total,ids,\
i) {
    id1(label);
    if (total >= 1) {
        for(i = 1 ; i <= total ; i++ ) {
            if(LD)DETAIL(label":"i"/"total":"ids[i,1]":"ids[i,2]);
        }
    }
    id0(total);
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
function selectBestOfBestTitle(plugin,minfo,total,titles,\
bestId,bestFirstAired,age_scores,eptitle_scores) {
    dump(0,"closely matched titles",titles);

    if (total == 0) {
        bestId = "";
    } else if (total == 1) {
        bestId = titles[1,1];
    } else {
        TODO("Refine selection rules here.");

        if(LD)DETAIL("Getting the most recent first aired for s"minfo[SEASON]"e"minfo[EPISODE]);
        # disabled in the hope another search method is triggered
        if(1) {
            bestFirstAired="";

            getRelativeAgeAndEpTitles(plugin,minfo,total,titles,age_scores,eptitle_scores);

            bestScores(eptitle_scores,eptitle_scores,0);
            bestId = firstIndex(eptitle_scores);

            if (bestId == "") {
                bestScores(age_scores,age_scores,1);
                bestId = firstIndex(age_scores);
            }
        }
        #TODO also try to get first episode of season.
    }
    if(LD)DETAIL("Selected:"bestId);
    return bestId;
}

function remove_country(t) {
    if (match(tolower(t)," (au|uk|us)( |$)")) {
        t=substr(t,1,RSTART-1) " " substr(t,RSTART+RLENGTH);
    }
    return t;
}

# Add alternate titles to list of titles in title_list
#IN tnum - current title count
#IN title - base title to add
#IN/OUT title_list - ordered search title list
#IN/OUT dups - hash of unique titles - used to screen out duplicates
#RETURN new title count 
function alternate_titles(tnum,title,title_list,dups,\
tmp) {
    # Build list of possible titles.
    tmp = clean_title(title,1);
    tnum = add_title(tnum,tmp,title_list,dups);

    tmp = clean_title(remove_brackets(title),1);
    tnum = add_title(tnum,tmp,title_list,dups);

    tmp = clean_title(remove_country(title),1);
    tnum = add_title(tnum,tmp,title_list,dups);

    tmp = clean_title(remove_country(remove_brackets(title)),1);
    tnum = add_title(tnum,tmp,title_list,dups);

    return tnum;
}

function add_title(count,title,list,dups) {
    if (!(title in dups)) {
        dups[title]=1;
        list[++count] = title;
    }
    return count;
}

# Search tvDb and return titles hashed by seriesId
# Series are only considered if they have the tags listed in requiredTags
# IN title - the title we are looking for.
# OUT closeTitles - matching titles hashed by tvdbid. 
# RETURNS total matches
# This wrapper function will search with or without the country code.
function searchTv(plugin,title,closeTitles,\
allTitles,url,ret,total) {

    id1("searchTv Checking ["plugin"/"title"]" );
    delete closeTitles;

    if (plugin == "thetvdb") {

        url=tvdb_get_series(title);
        total = filter_search_results(url,title,"Series","SeriesName","seriesid",allTitles);

    } else if (plugin == "tvrage") {

        url=g_tvrage_api"/feeds/search.php?show="title;
        total = filter_search_results(url,title,"show","name","showid",allTitles);

    } else {
        plugin_error(plugin);
    }

    if (total == 1) {
        if(LD)DETAIL("One result - assume it is the match we are looking for - skip similarity check");
        hash_copy(closeTitles,allTitles);
        ret = 1;
    } else {
        ret = filterSimilarTitles(title,total,allTitles,closeTitles);
    }
    id0(ret);
    return 0+ret;
}

function tvdb_get_series(title,\
url) {
    url = g_thetvdb_web"/api/GetSeries.php?language=all&seriesname=";
    return expand_url(url,title);
}

#If the search engine differentiates between &/and or obrien o brien then we need multiple searches.
# 
function expand_url(baseurl,title,\
url,url2) {
    url = baseurl title ;
    url2 = gensub(/ [Aa]nd /," %26 ","g",url);
    if (url2 != url) {
        #try "a and b\ta & b"
        url=url"\t"url2;
    }
    if (index(title," O ")) {
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
function filter_search_results(url,title,series_tag,nameTag,idTag,allTitles,\
info,currentId,currentName,i,num,response) {

    num = 0;
    id1("filter_search_results");
    delete allTitles;

    if (url_get(url,response,"",1)) {
        num = xml_chop(response["body"],series_tag,info);
        if (num == 101 && series_tag == "Series" ) { # tvdb limits to 100
            if(LI)DETAIL("100 results returned - using internal tvdb data because thetvdb may have truncated results");
            num = get_tvdb_names_by_letter(substr(title,1,1),allTitles);
        } else {
            for(i = 1 ; i < num ; i++ ) { # ignore last fragment

                currentName = clean_title(xml_extract(info[i],nameTag));
                currentId = xml_extract(info[i],idTag);

                allTitles[i,1] = currentId;
                allTitles[i,2] = currentName;
            }
            allTitles["total"] = i;
            dedup_ids_and_titles(allTitles);
        }
    }

    dump(0,"search results["title"]",allTitles);
    id0(num);
    return num;
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
    #gsub(/[[:alnum:]]\>/,"&"g_punc[0]"?",title);
    gsub(/[[:alnum:]]\>/,"&[.?!]?",title);
    return title"(| \\([[:alnum:]]\\))";
}

# IN imdb id tt0000000
# RETURN tvdb id
function find_tvid(plugin,minfo,imdbid,\
url,id2,key,filter,showInfo,year_range,title_regex,tags) {
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

            if (id2 == "" ) {

                # We do a fuzzy year search esp for programs that have a pilot in the
                # year before episode 1
                #
                # This may cause a false match if two series with exactly the same name
                # started within two years of one another.
                year_range="("(minfo[YEAR]-1)"|"minfo[YEAR]"|"(minfo[YEAR]+1)")";
                title_regex=tv_title2regex(minfo[TITLE]);

                if(plugin == "thetvdb") {

                    url=tvdb_get_series(minfo[TITLE]);

                    if (fetchXML(url,"imdb2tvdb",showInfo,"")) {
                        #allow for titles "The Office (US)" or "The Office" and 
                        # hope the start year is enough to differentiate.
                        filter["/SeriesName"] = "~:^"title_regex"$";
                        filter["/FirstAired"] = "~:^"year_range"-";
                        if (find_elements(showInfo,"/Data/Series",filter,1,tags)) {
                            if(LD)DETAIL("Looking at tvdb "showInfo[tags[1]"/SeriesName"]);
                            id2 = showInfo[tags[1]"/seriesid"];
                        }
                    }

                } else if(plugin == "tvrage") {

                    if (fetchXML(g_tvrage_api"/feeds/search.php?show="minfo[TITLE],"imdb2tvdb",showInfo,"")) {
                        #allow for titles "The Office (US)" or "The Office" and 
                        # hope the start year is enough to differentiate.
                        filter["/name"] = "~:^"title_regex"$";
                        filter["/started"] = "~:"year_range;
                        if (find_elements(showInfo,"/Results/show",filter,1,tags)) {
                            if(LD)DETAIL("Looking at tv rage "showInfo[tags[1]"/name"]);
                            id2 = showInfo[tags[1]"/showid"];
                        }
                    }

                } else {
                    plugin_error(plugin);
                }
            }
            if (id2) g_imdb2tv[key] = id2;
        }

        if(LG)DEBUG("imdb id "imdbid" =>  "plugin"["id2"]");
    }
    return id2;
}

function closest_title_in_list(title,allTitles,\
bestTitles,keep,i,num,d,threshold,len,lctitle) {

    num = get_tvdb_names_by_letter(substr(title,1,1),allTitles);
    clean_titles_for_abbrev(num,allTitles);
    
    lctitle = norm_title(title);
    len = length(title);

    threshold = 2; # number of letter transformations allowed 
    for(i = 1 ; i<=num ; i++ ) {
        d = len - length(allTitles[i,2]);
        if (d*d <= 4 ) {

            d = edit_dist(tolower(allTitles[i,2]),lctitle,threshold);

            if (d <= threshold) {
                keep[i] = 100 - d;
            }
        }
    }
    bestScores(keep,keep);
    #d = getMax(keep,-1,4);
    #delete keep;
    #keep[d]  = 1;

    copy_ids_and_titles(keep,allTitles,bestTitles);
    dump(0,"closest_title_in_list",bestTitles);
    dedup_ids_and_titles(bestTitles,1);

    hash_copy(allTitles,bestTitles);
    return allTitles["total"];
}


function searchTvDbTitles(plugin,minfo,title,\
tvdbid,tvDbSeriesUrl,imdb_id,closeTitles,total,alt) {

    id1("searchTvDbTitles");
    imdb_id = imdb(minfo);
    if (imdb_id) {
        tvdbid = find_tvid(plugin,minfo,imdb_id);
    }
    if (tvdbid == "") {
        total = searchTv(plugin,title,closeTitles);
        tvdbid = selectBestOfBestTitle(plugin,minfo,total,closeTitles);
    }
    if (tvdbid == "") {

        alt = gensub("([^ 0-9])("g_year_re")","\\1 \\2","g",title);
        if (alt != title) {
            if(LD)DETAIL("Try to insert a space before year - eg v2009 -> v 2009");
            total = searchTv(plugin,alt,closeTitles);
            tvdbid = selectBestOfBestTitle(plugin,minfo,total,closeTitles);
        }
    }

#    var u
#    if (tvdbid == "") {
#        u = searchHeuristicsForImdbLink(searchHeuristicsForImdbLink(title,3));
#        if(LD)DETAIL("XXXX new search here = "u);
#    }

    if (tvdbid == "") {
        alt  = remove_tv_year(title);
    	if(title != alt) {
    	    if(LD)DETAIL("Try without a year");
            # the tvdb api can return better hits without the year.
            # compare e.g.
            # http://www.thetvdb.com/api/GetSeries.php?seriesname=Carnivale%202003 Bad
            # http://www.thetvdb.com/api/GetSeries.php?seriesname=Carnivale Good
            #
            # tv rage should work with the year. compare .e.g
            # http://services.tvrage.com/feeds/search.php?show=carnivale Good
            # vs http://services.tvrage.com/feeds/search.php?show=carnivale%202003 OK
    	    total = searchTv(plugin,alt,closeTitles);
    	    tvdbid = selectBestOfBestTitle(plugin,minfo,total,closeTitles);
    	}
        
    }

    if (tvdbid != "") {
        tvDbSeriesUrl=get_tv_series_api_url(plugin,tvdbid);
    }

    id0(tvDbSeriesUrl);
    return tvDbSeriesUrl;
}

function tvdb_series_url(id,lang) {

    return g_thetvdb_web"/data/series/"id"/all/"lang".xml";
}

# IN plugin tvrage|thetvdb
# IN tvdbid show id
# OUT xml for tv show - this is only popluated as a side effect of checking if the plot for tvdb is English. Unfortunately
# there is no simple flag in the response to indicate if a page is translated or not. (at time of writing)
# For now this xml is ignored but a later re-write should use it to avoid double parse of the page.
function get_tv_series_api_url(plugin,tvdbid,xml,\
url,i,num,langs,key,plot) {
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
                        } else if (langs[i+1] != "en" ) {
                            #if the *next* language is also NOT English then check the overview has been translated.
                            if (fetchXML(url,"tvxml",xml,"")) {
                                plot = xml["/Data/Series/Overview"];
                                if (is_english(plot)) {
                                    if(LD)DETAIL("expected lang="langs[i]" but found "show_english(plot));
                                } else {
                                    break;
                                }
                            }
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


# This function is now just too messy and needs a careful re-write
# return 0=no match , 5=excellent match, and values in between.
function similarTitles(titleIn,possible_title,\
cPos,yearOrCountry,matchLevel,shortName,unqualified_title,\
possible_in_title,title_in_possible,unqualified_in_title,qualifier_re) {

    matchLevel = 0;
    yearOrCountry="";

    #if(LG)DEBUG("XX Checking ["titleIn"] against ["possible_title"]");

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

    unqualified_title=SUBSEP;
    # Extract any bracketed qualifiers - eg (year) or (US)
    if (match(possible_title," \\([^)]+")) {
        unqualified_title = norm_title(substr(possible_title,1,RSTART-1));
        yearOrCountry=tolower(clean_title(substr(possible_title,RSTART+2,RLENGTH-2),1));
        if(LG)DEBUG("Qualifier ["yearOrCountry"]");
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
#        if(LG)DEBUG("Checking ["titleIn"] against ["possible_title"]");
#    }
    if (yearOrCountry != "") {
        if(LG)DEBUG("Qualified title ["possible_title"]");
    }

    #if(LG)DEBUG("XX titleIn["titleIn"]");
    #if(LG)DEBUG("XX possible_title["possible_title"]");
#    if(LD)DETAIL("qualifed titleIn["titleIn" ("yearOrCountry")]");

    #This will match exact name OR if BOTH contain original year or country
    
    if (possible_title == titleIn) {

        matchLevel=5;

        #If its a qualified match increase score further
        #eg xxx UK matches xxx UK
        #or xxx 2000 matches xxx 2000
        if (yearOrCountry != "") {
            matchLevel=10;
        }

    } else {

        title_in_possible = index(possible_title,titleIn);
        possible_in_title = index(titleIn,possible_title);
        unqualified_in_title = index(titleIn,unqualified_title);

        qualifier_re = "^ \\(?("g_year_re"|uk|us|au|nz|de|fr)\\>\\)?";

        if (unqualified_in_title==1 && yearOrCountry && substr(titleIn,length(unqualified_title)+1) ~ " \\(?"yearOrCountry"\\)?") {

            if(LD)DETAIL("titleIn["titleIn"] matches unqualified_title["unqualified_title"] + qualification["yearOrCountry"]");
            # eg the titleIn had qualification without brackets. eg "The Office US"
            # The possible_title had qualification with brackets "The Office (US)"
            # These essentially match but there is a slim to non-existant chance it may
            # false match on a show where 'Us' is the last word of the show title.
            # Very unlikely though as there are usually no shows that match the title sans 'us'
            # to false +ve against. 
            matchLevel = 5;

        } else if (unqualified_in_title==1 && yearOrCountry && ( unqualified_title  == titleIn )) {

            if(LD)DETAIL("titleIn["titleIn"] matches unqualified_title["unqualified_title"]  but not qualification["yearOrCountry"]");
            matchLevel = 3;

        } else if (title_in_possible == 1 && titleIn == shortName) {
                #Check for comma. eg maych House to House,M D
            if(LD)DETAIL("titleIn["titleIn"] matches shortName["shortName"]");
            matchLevel=5;

        } else if (title_in_possible == 1 && index(possible_title,titleIn" show")) {
            #eg "jay leno show","jay leno"
            # eg "(The) Jay Leno Show" vs "Jay Leno"
            if(LD)DETAIL("titleIn["titleIn"]+show matches shortName["possible_title"]");
            matchLevel = 4;

        } else if (title_in_possible == 1 && (substr(possible_title,length(titleIn)+1) ~ qualifier_re )) {

            if(LD)DETAIL("titleIn +["titleIn"]+some qualifier matches possible_title["possible_title"]");
            matchLevel = 5;

        } else if (possible_in_title == 1 && (substr(titleIn,length(possible_title)+1) ~ qualifier_re )) {

            if(LD)DETAIL("titleIn +["titleIn"] matches possible_title["possible_title"] + some qualifier");
            matchLevel = 5;

        } else if (title_in_possible &&  index(possible_title,"late night with "titleIn)) {
            # Late Night With Some Person might just be known as "Some Person"
            # eg The Tonight Show With Jay Leno
            if(LD)DETAIL("titleIn late night with+["titleIn"]+show matches shortName["possible_title"]");
            matchLevel = 4;

        } else if (title_in_possible && index(possible_title,"show with "titleIn)) {

            # The blah blah Show With Some Person might just be known as "Some Person"
            # eg The Tonight Show With Jay Leno
            if(LD)DETAIL("titleIn show with+["titleIn"]+show matches shortName["possible_title"]");
            matchLevel = 4;

        }
    }
    return 0+ matchLevel;
}

#Given a title - scan an array or potential titles and return the best matches along with a score
#The indexs are carried over to new hash
# IN title
# IN titleHashIn - best titles so far hashed by tvdb id
# OUT titleHashOut - titles with highest similarilty scores hashed by tvdbid
# RETURNS Similarity Score - eg Office UK vs Office UK is a fully qualifed match high score.
function filterSimilarTitles(title,intotal,titleHashIn,titleHashOut,\
i,score,bestScore,tmpTitles,total) {

    id1("Find similar "title);
    dump_ids_and_titles("filterSimilarTitles in ",intotal,titleHashIn);

    #Save a copy in case titleHashIn = titleHashOut
    hash_copy(tmpTitles,titleHashIn);

    #Build score hash
    for(i = 1 ; i<= intotal ; i++ ) {
        score[i] = similarTitles(title,titleHashIn[i,2]);
        if(LG)DEBUG("["title"] vs ["i":"titleHashIn[i,2]"] = "score[i]);
    }

    #get items with best scores into titleHashOut
    bestScore = bestScores(score,score,0);

    total = 0;
    delete titleHashOut;
    if (bestScore == 0 ) {
        if(LD)DETAIL("all zero score - discard them all to trigger another match method");
    } else {
        for(i in score) {
            total++;
            titleHashOut[total,1] = tmpTitles[i,1];
            titleHashOut[total,2] = tmpTitles[i,2];
            if(LD)DETAIL("similar:"titleHashOut[i,1]":"titleHashOut[i,2]);
        }
    }

    dump_ids_and_titles("filterSimilarTitles out ",total,titleHashOut);
    id0(total);
    return total;
}

# IN start letter
# OUT names -> hash of values = [n,1]=id [n,2]=title # to allow for multiple language titles.
# return number of items
function get_tvrage_names_by_letter(letter,names,\
url,count,i,names2,regex,parts) {

    delete names;
    id1("get_tvrage_names_by_letter abbreviations for "letter);

    g_fetch["force_awk"]=1;

    regex="<id>([^<]+)</id><name>([^<]*)</name>";
    url = g_tvrage_api"/feeds/show_list_letter.php?letter="letter;
    scan_page_for_match_order(url,"<name>",regex,0,1,names2);

    g_fetch["force_awk"]=0;

    for(i in names2) {
        gsub(/\&amp;/,"And",names2[i]);
        split(gensub(regex,SUBSEP"\\1"SUBSEP"\\2"SUBSEP,"g",names2[i]),parts,SUBSEP);
        count++;
        names[count,1] = parts[2];
        names[count,2] = parts[3];
    }
    names["total"] = count;

    dedup_ids_and_titles(names);

    id0(names["total"]);
    return names["total"];
}

# IN start letter
# OUT names -> hash of values = [n,1]=id [n,2]=title # to allow for multiple language titles.
# return number of items
function get_tvdb_names_by_letter(letter,names,\
f,d,count,line,colon,dup,id,title,title_lc) {

    delete names;
    id1("get_tvdb_names_by_letter abbreviations for "letter);
    d=OVS_HOME"/bin/catalog/tvdb/";
    f=d"tvdb-"toupper(letter)".list";

    exec("sh "qa(OVS_HOME"/bin/tvdblist.sh")" "letter);

    while(( getline line < f ) > 0 ) {
        colon = index(line,":");
        if (colon) {

            id = substr(line,1,colon-1);
            title = substr(line,colon+1);
            title_lc = tolower(title);

            if (dup[id] != title_lc) {
                count++;
                names[count,1] = id;
                names[count,2] = title;
                dup[id] = title_lc;
            }
        }
    }
    names["total"] = count;
    close(f);
    id0(count);
    return count;
}

# Search epGuide menu page for all titles that match the possible abbreviation.
# IN letter - menu page to search. Usually first letter of abbreviation except if abbreviation begins
#             with t then search both t page and subsequent letter - to account for "The xxx" on page x
# IN list of names that start with letter.
# IN titleIn - The thing we are looking for - eg ttscc
# IN/OUT alternateTitles - hash of titles [n,1]=id [n,2]=title (as shows may have titles in other languages)
# Return number of titles -1 = error
function searchAbbreviation(letter,count,names,titleIn,alternateTitles,\
possible_title,i,ltitle,add,total,a) {

    total = 0;
    ltitle = norm_title(titleIn);

    if (ltitle == "" ) return ;

    id1("Checking "titleIn" for abbreviations on menu page - "letter);
    #dump(0,"searchAbbreviation:",names);

    for(i = 1 ; i<= count ; i++ ) {

        possible_title = names[i,2];
        a = 0;

        #if(LG)DEBUG("searchAbbreviation ["ltitle"] vs ["possible_title"]");

        sub(/\(.*/,"",possible_title);
        gsub(/'/,"",possible_title);

        # note double abbreviation is checked for "CSI: Crime Scene Investigation" vs csicsi"
        if (abbrevMatch(ltitle,possible_title) || (length(ltitle) >= 3 && abbrevMatch(ltitle ltitle,possible_title)) || abbrevContraction(ltitle,possible_title)) {
            add[i] = 1;
        }
    }
    total = merge_ids_and_titles(add,names,alternateTitles);
    id0(total);
    return total;
}

#split title into words then see how many words or initials we can match.
# eg desperateh fguy  "law and order csi"
#note if a word AND initial match then we try to match the word first.
#I cant think of a scenario where we would have to backtrack and try
# the initial instead.
#
#eg toxxx might abbreviate "to xxx" or "t" ...
function abbrevMatch(abbrev , possible_title,\
word_no,a,words,rest_of_abbrev,found,abbrev_len,short_words,num_words,current_word,current_letter) {
    num_words = split(tolower(possible_title),words," ");
    a=1;
    word_no=1;
    abbrev_len = length(abbrev);

    short_words["and"] = short_words["on"] = short_words["in"] = short_words["it"] = short_words["of"] = 1;

    while(abbrev_len-a  >= 0 && word_no <= num_words) {
        rest_of_abbrev = substr(abbrev,a);
        current_word = words[word_no];

        if (index(   rest_of_abbrev  ,   current_word  ) == 1) {
            #abbreviation starts with entire word. eg "depserate" of desperateh or "guy" of fguy.
            a += length(current_word);
            word_no++;
        } else {
            current_letter = substr(rest_of_abbrev,1,1);
            if (substr(current_word,1,1) == current_letter) {
                a ++;
                word_no++;
            } else if (current_letter == " ") {
                a ++;
            } else if (current_word in short_words ) {
                word_no++;
            } else {
                #no match
                break;
            }
        }
    }
    found = ((a -abbrev_len ) > 0 ) && word_no > num_words;
    if (found) {
        if(LD)DETAIL(possible_title " abbreviated by ["abbrev"]");
    }
    return 0+ found;
}


# remove all words of 3 or less characters
function significant_words(t) {
    gsub(/\<(and|the|on|or|of|in|vs|de|en|its?)\>/,"",t);
    #gsub(/\<[^ ]{1,3}\>/,"",t);
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

# return part of  s1 that contains abbrev s2
# eg s1=hello there s2=ho   then result is hello
#
#because backtracking is involed best to use regex. eg g.*r.*k to match greek.
# but .* can be very inefficient so we screen the string first t make sure it contains g,r and k in order.
function abbreviated_substring(s1,start_regex_anchor,abbrev,end_on_word,\
ret,i,j,s1lc,abbrevlc,len1,len2,regex,ch) {
    j = 0;
    s1lc = tolower(s1);
    abbrevlc = tolower(abbrev);
    len1 = length(s1lc);
    len2 = length(abbrevlc);
    
    ret = 1;

    # Check all letters in abbreviation appear in order without using expensive .* regex.
    for(i = 1 ; i <= len2 ; i++ ) {
        ch = substr(abbrevlc,i,1);
        j = index(s1lc,ch);
        s1lc = substr(s1lc,j+1);
        if (j == 0) {
            ret = "";
            break;
        }
    }
    if (ret == 1) {
        regex = gensub(/./,".*&","g",abbrevlc);
        regex = start_regex_anchor substr(regex,3);
        if (end_on_word) sub(/.$/,"(\\<&|&\\>)",regex);
        ret =  "" ;
        if (match(tolower(s1),regex)) {
            ret = substr(s1,RSTART,RLENGTH);
            if (index(substr(s1,RSTART+RLENGTH)," ")) {
                #if(LD)DETAIL("abbreviation ["s1"] ignored due to trailng words/space after ["ret"]");
                ret = "";
            }
        } 
    }
    return ret;
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
found,part,sw,ini) {

    found=0;

    # Use regular expressions to do the heavy lifting.
    # First if abbreviation is grk convert to ^g.*r.*k\>
    #
    # TODO Performance can be improved by just calling index for each letter in a loop. see is_contraction
    #
    possible_title = norm_title(possible_title,1);


    # Dont necessarilly end on a word eg 'mb' abbreviates 'Mythbusters'
    part = abbreviated_substring(possible_title,"\\<",abbrev,0);



    if (part != "") {
        #  check contraction will usually contain the initials of the entire title it matched against
        # 
        sw = significant_words(possible_title);
        ini = get_initials(sw);
        #if(LD)DETAIL("abbrev["abbrev"] possible_title=["possible_title"] part=["part"] sig=["sw"] init=["ini"]");

        if (abbreviated_substring(abbrev,"",ini,0) == "") {
            #if(LD)DETAIL("["possible_title "] rejected. ["ini"] not in abbrev ["abbrev"]");
        } else {
            found = 1;
        }
    }

    return found;
}

function get_episode_url(plugin,seriesUrl,season,episode,\
episodeUrl ) {
    episodeUrl = seriesUrl;
    if (plugin == "thetvdb") {
        #Note episode may be 23,24 so convert to number.
        if (sub(/(all\/|)[a-z][a-z].xml$/,"default/"season"/"(episode+0)"/&",episodeUrl)) {
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
# IN plugin id thetvdb/tvrage
# IN seriesUrl
# IN season number
# IN episode number
# OUT episodeInfo
# RETURN result=0 fail !=0 success
function get_episode_xml(plugin,seriesUrl,season,episode,episodeInfo,\
episodeUrl,result) {
    delete episodeInfo;

    id1("get_episode_xml");

    gsub(/[^0-9,]/,"",episode);

    episodeUrl = get_episode_url(plugin,seriesUrl,season,episode);
    if (episodeUrl != "") {
        if (plugin == "thetvdb" || plugin == "tvrage" ) {

            result = fetchXML(episodeUrl,plugin"-episode",episodeInfo,"",1);

        } else {
            plugin_error(plugin);
        }
        dumpxml("episode-xml",episodeInfo);
    } else {
        if(LD)DETAIL("cant determine episode url from "seriesUrl);
    }
    id0(result);
    return 0+ result;
}

# get thetvdbid from imdbid
function imdb2thetvdb(imdbid,\
ret,xml) {
    if (!(imdbid in g_imdb2thetvdb)) {
        fetchXML(g_thetvdb_web"/api/GetSeriesByRemoteID?imdbid="imdbid,"imdb2tv",xml);
        # always set value regardless of fetchXML error status - to prevent re-query
        g_imdb2thetvdb[imdbid] = xml["/Data/Series/seriesid"];
    }
    ret = g_imdb2thetvdb[imdbid];
    if(LD)DETAIL("imdb2thetvdb "imdbid" = "ret);
    return ret;
}

# Follow linked websites from tvrage to tvdb
# Note tvrage and thetvdb have recently become partners so this may become a direct link 
function rage_get_other_ids_in_minfo(minfo,\
rageid,ret,idlist,ids) {

    rageid = minfo_get_id(minfo,"tvrage");


    id1("rage_get_other_ids_in_minfo "rageid);

    # Possible routes to thetvdb are: 

    # ideally the following line will work one day if tvrage add partner links to thetvdb in the api
    ids["imdb"] = minfo_get_id(minfo,"imdb");
    ids["thetvdb"] = minfo_get_id(minfo,"thetvdb");

    rage_get_other_ids(rageid,ids);

    if (ids["imdb"]) {
        idlist = idlist " imdb:"ids["imdb"];
    }
    if (ids["thetvdb"]) {
        idlist = idlist " thetvdb:"ids["thetvdb"];
    }

    if (idlist) {
        minfo_merge_ids(minfo,idlist);
        ret = 1;
    }
    id0(idlist);
    return ret;
}

    # tvrage -> sharetv -> tvdb
    # tvrage -> epguide -> sharetv -> tvdb

    # tvrage -> sharetv -> imdb -> tvdb
    # tvrage -> epguide -> imdb -> tvdb
    # tvrage -> epguide -> sharetv->imdb -> tvdb
    # Using imdb link will only work if IMDB is set on thetvdb.

function rage_get_other_ids(rageid,ids,\
partners,p,partner,showurl,link,ret) {

    showurl = g_tvrage_web"/shows/id-"rageid;
    partners[1] = "sharetv";
    partners[2] = "epguides";
    partners[3] = "imdb";

    if (!ids["imdb"] && (rageid in g_tvrage_to_imdb ) ) {
        ids["imdb"] = g_tvrage_to_imdb[rageid];
    }

    if (!ids["thetvdb"] && (rageid in g_tvrage_to_imdb ) ) {
        ids["thetvdb"] = g_tvrage_to_thetvdb[rageid];
    }

    for(p = 1; ( p in partners) ; p++ ) {
        if (ids["imdb"] && ids["thetvdb"]) break;

        # scan for partner link
        partner  = scan_page_for_first_link(showurl,partners[p],1);
        if (partner) {

            if (!ids["imdb"]) {
                ids["imdb"] = extractImdbId(partner);
            }

            if (!ids["imdb"]) {
                link = scan_page_for_first_link(partner,"imdb",1);
                ids["imdb"] = extractImdbId(link);
                if (!ids["imdb"]) {
                    ids["imdb"]=scanPageFirstMatch(link,"title",g_imdb_regex,0);
                }
            }

            if (!ids["thetvdb"]) {
                link = scan_page_for_first_link(partner,"thetvdb",1);
                if (match(link,"[?&]id=[0-9]+")) {
                    ids["thetvdb"] = substr(link,RSTART+4,RLENGTH-4);
                }
            }
        }
    }

    if (ids["imdb"] && ! ids["thetvdb"] ) {
        ids["thetvdb"] = imdb2thetvdb(ids["imdb"]);
    }

    if (ids["thetvdb"] ) {
        g_tvrage_to_thetvdb[rageid] = ids["thetvdb"];
        ret++;
    }
    if (ids["imdb"] ) {
        g_tvrage_to_imdb[rageid] = ids["imdb"];
        ret++;
    }

    dump(0,"rage "rageid,ids);
    return ret;
}

# 0=nothing 1=series 2=series+episode
function get_tv_series_info(plugin,minfo,tvDbSeriesUrl,season,episode,\
result,minfo2,tvdbid) {

    id1("get_tv_series_info("plugin"," tvDbSeriesUrl")");

    if (season != "") {
        minfo[SEASON] = season;
    }
    if (episode != "") {
        minfo[EPISODE] = episode;
    }

    # mini-series may not have season set
    if (minfo[SEASON] == "") {
        minfo[SEASON] = 1;
    }

    if (plugin == "thetvdb") {

        result = get_tv_series_info_tvdb(minfo2,tvDbSeriesUrl,minfo[SEASON],minfo[EPISODE]);

    } else if (plugin == "tvrage") {

        result = get_tv_series_info_rage(minfo2,tvDbSeriesUrl,minfo[SEASON],minfo[EPISODE]);

    } else {
        plugin_error(plugin);
    }
    if (result) {
        minfo[CATEGORY] = "T";
    }


#    ERR("UNCOMMENT THIS CODE");
    if (minfo[EPISODE] ~ "^DVD[0-9]+$" ) {
        result++;
    }
#    ERR("UNCOMMENT THIS CODE");

    if (result) {
        minfo_merge(minfo,minfo2,plugin);

        # Once items are merged we have NAME and DIR fields in order to determine iamge destinations.
        tvdbid = minfo_get_id(minfo,"thetvdb");
        if (tvdbid) {
            getTvDbSeasonBanner(minfo,tvdbid);
        }

        if(LG)DEBUG("Title:["minfo[TITLE]"] Episode:["minfo[EPTITLE]"]"minfo[SEASON]"x"minfo[EPISODE]" date:"minfo[AIRDATE]);
        if(LG)DEBUG("");
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
        if(LG)DEBUG( "["field"] set to ["value"]");
        ret = 1;
    } else {
        if(LG)DEBUG( "["field"] already set to ["minfo[field]"] ignoring ["value"]");
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

function clean_plot(txt,\
i) {
    # We need to check to utf8 and html characters here.
    txt = html_to_utf8(txt);
    txt = substr(txt,1,g_max_plot_len);
    i = index(txt,"Recap:");
    if (i > 100) {
        # remove Recaps
        txt = substr(txt,1,i-1);
    }
    # This should be obsoleted now using tvrage api
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
seriesInfo,result,iid,thetvdbid,lang,plot,xmlstr,num) {

    result=0;

    if (!scrape_cache_get(season":"tvDbSeriesUrl,seriesInfo)) {

        if (url_get(tvDbSeriesUrl,xmlstr,"",1)) {
            num = xml_chop(xmlstr["body"],"Episode|Series",seriesInfo);
            xml_reindex(seriesInfo,"SeasonNumber EpisodeNumber");
            scrape_cache_add(season":"tvDbSeriesUrl,seriesInfo);
        }
    }


    if (index(seriesInfo[1],"<id")) {

        minfo[SEASON]=season;
        #Refine the title.
        minfo[TITLE] = remove_br_year(xml_extract(seriesInfo[1],"SeriesName"));

        minfo[YEAR] = substr(xml_extract(seriesInfo[1],"FirstAired"),1,4);

        lang=xml_extract(seriesInfo[1],"Language");
        plot=clean_plot(xml_extract(seriesInfo[1],"Overview"));
        minfo[PLOT]=add_lang_to_plot(lang,plot);

        minfo[GENRE]= xml_extract(seriesInfo[1],"Genre");
        minfo["mi_certrating"] = xml_extract(seriesInfo[1],"ContentRating");
        minfo[RATING] = xml_extract(seriesInfo[1],"Rating");

        #minfo[POSTER]=tvDbImageUrl(xml_extract(seriesInfo[1],"poster"));
        #minfo[FANART]=tvDbImageUrl(xml_extract(seriesInfo[1],"fanart"));
        #minfo[BANNER]=tvDbImageUrl(xml_extract(seriesInfo[1],"banner"));

        thetvdbid = xml_extract(seriesInfo[1],"id");
        minfo_set_id("thetvdb",thetvdbid,minfo);

        iid = xml_extract(seriesInfo[1],"IMDB_ID");
        minfo_set_id("imdb",iid,minfo);

        result ++;
    }

    if (result) {

        # For twin episodes just use the first episode number for lookup by adding 0
        minfo[EPISODE]=episode;


        if (episode ~ "^[0-9,]+$" ) {

            if(tvDbEpisode(minfo,seriesInfo[0,season,0+episode])) {
                if (minfo[EPTITLE] != "" ) {
                   if ( minfo[EPTITLE] ~ /^Episode [0-9]+$/ && minfo[EPPLOT] == "" ) {
                       if(LD)DETAIL("Due to Episode title of ["minfo[EPTITLE]"] Demoting result to force another TV plugin search");
                   } else {
                       result ++;
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
        if(LG)DEBUG("get_tv_series_info returns imdb url ["iid"]");
    }
    return 0+ result;
}

function tvDbEpisode(minfo,episodeInfo,\
lang,plot,ret) {
    if (index(episodeInfo,"<id")) {
        ret = 1;
        minfo[AIRDATE]=formatDate(xml_extract(episodeInfo,"FirstAired"));

        set_eptitle(minfo,xml_extract(episodeInfo,"EpisodeName"));

        if (minfo[EPPLOT] == "") {
            lang=xml_extract(episodeInfo,"Language");
            plot=clean_plot(xml_extract(episodeInfo,"Overview"));
            minfo[EPPLOT] = add_lang_to_plot(lang,plot);
        }
    } else {
        ERR("missing episode id? "episodeInfo);
    }
    return ret;
}

function tvDbImageUrl(path) {
    if(path != "") {
        return "http://thetvdb.com/banners/" url_encode(html_decode(path));
    } else {
        return "";
    }
}

function getTvDbSeasonBanner(minfo,tvdbid,\
xmlstr,xml,r,bannerApiUrl,num,get_poster,get_fanart,langs,lnum,key,size,season) {

    lnum = get_langs(langs);

    season = minfo[SEASON];

    bannerApiUrl = g_thetvdb_web"/data/series/"tvdbid"/banners.xml";

    r="/Banners/Banner";
    get_poster = getting_poster(minfo,1) && !g_image_inspected[tvdbid,POSTER,season];
    get_fanart = getting_fanart(minfo,1) && !g_image_inspected[tvdbid,FANART,season];
    get_banner = getting_banner(minfo,1) && !g_image_inspected[tvdbid,BANNER,season];

    if (get_poster || get_fanart || get_banner) {

        key="banners:"tvdbid ":" minfo[SEASON];

        if (!scrape_cache_get(key,xml)) {

            if (url_get(bannerApiUrl,xmlstr,"",0)) {
                num = xml_chop(xmlstr["body"],"Banner",xml);

                scrape_cache_add(key,xml);
            }
        }

        if (firstIndex(xml) != "") {

            if (get_poster) {
                if (!best_best_banner_score(tvdbid,POSTER,xml,minfo,"season","season",season,lnum,langs)) {
                    best_best_banner_score(tvdbid,POSTER,xml,minfo,"poster","","",lnum,langs);
                }
            }
            if (get_banner) {
                best_best_banner_score(tvdbid,BANNER,xml,minfo,"series","graphical","",lnum,langs);
            }
            if (get_fanart) {
                if (g_settings["catalog_image_fanart_width"]  == 1920 ) {
                    size = "1920x1080";
                } else {
                    size = "1280x720";
                }
                best_best_banner_score(tvdbid,FANART,xml,minfo,"fanart","","",lnum,langs,size);
            }
        }
    }
}

function best_best_banner_score(tvdbid,fld,xml,minfo,filter1,filter2,filter3,lnum,langs,size,\
banner_scores,i,url,banners,ret) {
    for(i in xml) {
        if (index(xml[i],"BannerType>"filter1"<")) {
           if(filter2 =="" || index(xml[i],"BannerType2>"filter2"<")) {
               if(filter3 =="" || index(xml[i],"Season>"filter3"<")) {
                   url = xml_extract(xml[i],"BannerPath");
                   banner_scores[tvDbImageUrl(url)] = banner_score(xml[i],lnum,langs,size);
               }
           }
        }
    }
    dump(0,"image "fld,banner_scores);
    if (bestScores(banner_scores,banner_scores)) {
        banners[fld] = minfo[fld] = firstIndex(banner_scores);
        ret = g_image_inspected[tvdbid,fld,minfo[SEASON]]=1;
        if(LG)DEBUG(fld" = "minfo[fld]);
    }
    return ret;
}

function banner_score(xml,lnum,langs,size,\
i,xrating,xlang,xsize,sc) {

    xrating = xml_extract(xml,"Rating") - 5;
    xrating *= xml_extract(xml,"RatingCount");
    xlang = xml_extract(xml,"Language");
    if (size) {
        xsize = xml_extract(xml,"BannerType2"); # only for fanart
    }
    for(i = 1 ; i <= lnum ; i++ ) {
        if (xlang == langs[i]) break;
    }
    sc = -i*1000 + 100 * ( xsize == size) + 10 * xrating;
    #DEBUG("score "sc" for "xml);
    return sc;
}

function set_eptitle(minfo,title) {
    if (minfo[EPTITLE] == "" ) {

        minfo[EPTITLE] = title;
        if(LD)DETAIL("Setting episode title ["title"]");

    } else if (title != "" && title !~ /^Episode [0-9]+$/ && minfo[EPTITLE] ~ /^Episode [0-9]+$/ ) {

        if(LD)DETAIL("Overiding episode title ["minfo[EPTITLE]"] with ["title"]");
        minfo[EPTITLE] = title;
    } else {
        if(LD)DETAIL("Keeping episode title ["minfo[EPTITLE]"] ignoring ["title"]");
    }
}

# 0=nothing 1=series 2=series+episode
function get_tv_series_info_rage(minfo,tvDbSeriesUrl,season,episode,\
seriesInfo,episodeInfo,filter,url,e,result,pi,thetvdbid) {

    pi="tvrage";
    result = 0;
    delete filter;

    if (scrape_cache_get(season":"tvDbSeriesUrl,minfo)) {

        result = 1;

    } else if (fetchXML(tvDbSeriesUrl,"tvinfo-show",seriesInfo,"") && ( "/Showinfo/showid" in seriesInfo ) ) {

        dumpxml("tvrage series",seriesInfo);
        minfo[SEASON]=season;
        minfo[TITLE]=clean_title(remove_br_year(seriesInfo["/Showinfo/showname"]));
        minfo[YEAR] = substr(seriesInfo["/Showinfo/started"],8,4);
        #minfo["mi_premier"]=formatDate(seriesInfo["/Showinfo/started"]);


        url=urladd(seriesInfo["/Showinfo/showlink"],"remove_add336=1&bremove_add=1");
        minfo[PLOT]=clean_plot(seriesInfo["/Showinfo/summary"]);

        minfo_set_id("tvrage",seriesInfo["/Showinfo/showid"],minfo);

        rage_get_other_ids_in_minfo(minfo);

        thetvdbid = minfo_get_id(minfo,"thetvdb");
        if (thetvdbid) {
            getTvDbSeasonBanner(minfo,thetvdbid);
        }
        scrape_cache_add(season":"tvDbSeriesUrl,minfo);
        result ++;
    }

    if (result) {

        minfo[EPISODE]=episode;

        e="/show/episode";
        if (episode ~ "^[0-9,]+$" ) {
            if (get_episode_xml(pi,tvDbSeriesUrl,season,episode,episodeInfo)) {

                set_eptitle(minfo,episodeInfo[e"/title"]);

                minfo[AIRDATE]=formatDate(episodeInfo[e"/airdate"]);

                if (minfo[EPPLOT] == "") {
                    minfo[EPPLOT] = clean_plot(episodeInfo[e"/summary"]);
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
# IN titleHash - [n,1]=tvid [n,2]=title # allows multilingual titles.
# OUT ageHash - age indicator  Indexed by imdb/tvdbid etc
# OUT eptitleHash - set to 1 if episode title = additional info
function getRelativeAgeAndEpTitles(plugin,minfo,total,titleHash,ageHash,eptitleHash,\
id,xml,eptitle,i) {
    for(i = 1 ; i <= total ; i++) {
        id = titleHash[i,1];
        if (id) {
            if (get_episode_xml(plugin,get_tv_series_api_url(plugin,id),minfo[SEASON],minfo[EPISODE],xml)) {
                if (plugin == "thetvdb") {

                    ageHash[id] = xml["/Data/Episode/FirstAired"];
                    eptitle = tolower(xml["/Data/Episode/EpisodeName"]);

                } else if (plugin == "tvrage" ) {

                    ageHash[id] = xml["/show/episode/airdate"];
                    eptitle = tolower(xml["/show/episode/title"]);

                } else {
                    plugin_error(plugin);
                }

                if (minfo[ADDITIONAL_INF]) {
                    eptitleHash[id] = -edit_dist(eptitle,minfo[ADDITIONAL_INF]); # bigger number closer the string.
                }
            }
        }
    }
    dump(1,"episode title ",eptitleHash);
    dump(1,"Age indicators",ageHash);
 }


