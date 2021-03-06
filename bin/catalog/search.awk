# Functions for searching and scraping

# Google is MILES ahead of yahoo and bing for the kind of searching oversight is doing.
# its a shame that it will blacklist repeat searches very quickly, so we use the 
# other engines in round-robin. If they disagree then google cast the deciding vote.
#
# Special case is if searching via IMDB search page - then the imdb_qual is used
function web_search_first_imdb_link(qualifier) {
    return web_search_first(qualifier,1,"imdbid","tt",g_imdb_regex);
}
function web_search_first_imdb_title(qualifier) {
    return web_search_first(qualifier,0,"imdbtitle","",g_imdb_title_re);
}

# search for either first occurence OR most common occurences.
# return is array matches(index=matching text, value is incremented for each match)
# also match_src contains all urls that matched each pattern.
# results are merged into existing array values.
function scrapeMatches(url,freqOrFirst,helptxt,regex,matches,match_src,\
match1,submatch,dots) {

    if (freqOrFirst == 1) {

        match1=scanPageFirstMatch(url,helptxt,regex,1);
        if (match1) {
            submatch[match1] = 1;
        }
    } else {

        scanPageMostFreqMatch(url,helptxt,regex,1,submatch);
    }
    # for each match we increment its score by one.

    for(match1 in submatch) {
        #Remove elipses often used between different parts of context in SERPS.
        if ((dots = index(match1,"...")) != 0) {
            match1 = trim(substr(match1,dots+3));
        }

        matches[match1] ++; 
        if (index(match_src[match1],":" url ":") == 0) {
            match_src[match1]=match_src[match1] ":" url ":";
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
t,t2,y,quoted) {

    dump(0,"normalise titles in ",matches);
    delete normed;
    for(t in matches) {
        t2=t;
        gsub(/'[Ss]\>/,"s",t2);
        gsub("[^"g_alnum8"]"," ",t2);
        gsub(/  +/," ",t2);
        t2 = capitalise(trim(t2));


        #Ignore anything that looks like a date.
        if (t2 !~ "(©|Gmt|Pdt|("g_months_short"|"g_months_long")(| [0-9][0-9])) "g_year_re"$" ) {
            #or a sentence blah blah blah In 2003
            if (t2 !~ "([[:upper:]][[:lower:]]* ){3}(In|Of) "g_year_re"$" ) {

                # remove tags from "movie name DVD 2009" etc.
                if (match(t2," \\(?"g_year_re"\\)?$")) {
                    y = substr(t2,RSTART);
                    t2 = substr(t2,1,RSTART-1);
                }
                t2 = remove_format_tags(t2) y;

                if(LD)DETAIL("["t"]=>["t2"]");


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
    dump(0,"normalise titles out",normed);

    # Finally quote title - might not work for 3d type titles?
    if(0) {
        # disabled for now - behaviour has not been fully tested.
        for(t in normed) {
            if (index(t,"\"") == 0) {
                t2=t;
                sub(" "g_year_re"$","\" &",t2);
                quoted["\""t2] = normed[t];
            } else {
                quoted[t] = normed[t];
            }
        }

        dump(0,"quoted normalised titles out",quoted);
        hash_copy(normed,quoted);
    }
}

# Special case is if searching via IMDB search page - then the imdb_qual is used
# the help text just helps avoid overhead of regex matching.
# freqOrFirst =0 freq match | =1 first match
#
# normedt = normalized titles. eg The Movie (2009) = the.movie.2009 etc.
function web_search_first(qualifier,freqOrFirst,mode,helptxt,regex,\
u,ret,i,matches,freq,freq1,best1,freq_target,bestmatches,match_src,round_robin,target,num) {

    g_fetch["force_awk"] = 1;
    if (mode == "imdbid") {
        g_fetch["no_encode"] = 1; # dont care about encoding
    } else {
        g_fetch["no_encode"] = 0; # need utf-8 for titles
    }

    ############################################################################
    ## Now Yahoo is powered by BING the search results are the same. So there
    ## is no easy way to check for false positives any more.
    ## The previous logic of search Yahoo & Bing for agreeemnt, if not letting Google decide no longer holds.
    ## Google itself can supply great results but it will lock us out fast.
    ## Instead we now just use Bing mobile. / or yahoo - doesnt matter which.
    ## If no results then use google.

    ## Update: Although yahoo is powered by Bing, it appears to be filtering results.
    ## So existing system is still useful.
    ## Eg. Consider query for "mhd begi imdb" which should give Beginners 2010
    ## Also m.bing.com may give different results to www.bing.com
    ############################################################################
    round_robin = 0;
    num = 0;

    # During this search cache all pages in case we need to do a cross page ranking against prior results.
    set_cache_prefix("@");

    id1("web_search_first "mode" ["qualifier"]");

    # target[n] = how many times a match must come first , on its own to "win"
    # eg scan1  tt0000001 = 1  tt0000002 = 1 - not unique but score is kept for next scan
    # eg scan2  tt0000001 += 1 tt0000002 += 0 - tt0000001 now scores 2.
    if (round_robin) {
        u[++num] = search_url("SEARCH" qualifier); target[num]=1;
        u[++num] = search_url("SEARCH" qualifier); target[num]=2;
        u[++num] = search_url("SEARCH" qualifier); target[num]=2;
        u[++num] = g_search_google qualifier; target[num]=2;
    } else {
        # Bing seems a bit better still -
        u[++num] = g_search_bing_desktop qualifier; target[num]=1;
        u[++num] = g_search_google qualifier; target[num]=2;

        #u[++num] = g_search_bing_desktop qualifier; target[num]=2;
        #yahoo gives too many false positives even with Bing technology. eg. http://search.yahoo.com/search?ei=UTF-8&eo=UTF-8&p=Family+Guy+0914+imdb - give sopranos
        #u[++num] = g_search_yahoo qualifier; target[num]=2;
    }

    #The search string itself will be present not only in the serp but also in the title and input box
    #So if searching for "DVD Aliens (1981)" then the most popular result may include DVD.
    #we can remove these matches by modifying the search string slighty so it will give same results 
    #but will not match the imdb title regex. To do this convert eg. Fred (2009) to "Fred + (2009)"
    for(i in u) {
        sub("\\<"g_year_re"\\>","+%2B+&",u[i]);
    }

    # Add some more specialised searches. These will not need/understand syntax manipulation above.
    if(mode == "imdbtitle" && p2p_filename(qualifier) ) {
        #u[++num] = g_search_binsearch qualifier; target[num]=2;
        u[++num] = g_search_nzbindex qualifier; target[num]=2;
    }

    # Cycle through each URL grabbing best id and merging into matches.
    # For each match the urls are also tracked in case we to a "cross-page" ranking later.
    for(i = 1 ; i <= num ; i++ ) {

        if (u[i]) {

            scrapeMatches(u[i],freqOrFirst,helptxt,regex,matches,match_src);
            dump(0,"websearch-matches",matches);

            if (bestScores(matches,bestmatches,0) >= target[i] ) {
               dump(0,"websearch-best",bestmatches);

               best1 = firstIndex(bestmatches);
               if (i == 1 && target[i] == 1 ) {
                   # As we have only searched one page and looking for the first match.
                   # to reduce false positive also make sure it is most frequent match and occurs 2 or more times.

                   if (best1 != "") {
                       if (1) {
                           freq1 = scanPageMostSignificantMatch(u[i],helptxt,regex,1,freq);
                       } else {
                           # Changed down from 3 to 2 to reduce amount of times google is used.
                           # IF this gives false positives then change scanPageMostFreqMatch to just return count of all patterns
                           # and make sure the best is the same as the first. and is significantly more than the second.
                           scanPageMostFreqMatch(u[i],helptxt,regex,1,freq);
                           dump(0,"websearch-freq",freq);
                           freq1 = firstIndex(freq);
                       }

                       freq_target = 3; # changed back to 3 to avoid false positives. May invoke google block.

                       if (freq1 != best1 ) {
                           if(LD)DETAIL(best1" is not most frequent. ["freq1"]  - continue searching ...");
                           continue;
                       } else if (freq[freq1] < freq_target) {
                           if(LD)DETAIL(best1" does not occur "freq_target" or more times on first search result  - continue searching ...");
                           continue;
                       } else if (hash_size(freq) > 1) {
                            if(LD)DETAIL(best1" does not occur more frequently than others");
                       } 
                   } 
               }

               #check exactly one match only.
               if (hash_size(bestmatches) == 1) {
                   ret = best1;
                   break;
               }

           }
       }
    }

    if (ret == "") {
        ret = cross_page_rank(mode,bestmatches,match_src,u);
    }

    g_fetch["no_encode"] = 0;
    g_fetch["force_awk"] = 0;
    #delete all cached pages.
    clear_cache_prefix("@");
    id0(ret);
    return ret;
}

function cross_page_rank(mode,matches,match_src,urls,\
m,s,i,pages,subtotal,ret,noyear) {
    # No match stands out.
    #Go through each match and see how many times it appears on the other pages.
    # this is why we track the matching urls in the match_src array.
    for(m in matches) {
        id1("cross_page_rank "m"|");
        pages=0;
        subtotal=0;
        for(i in urls ) {
            if (urls[i]) {
                #if the url did dot contribute to this matches best score
                if (index(match_src[m],":"urls[i]":") == 0) {
                    s = scan_page_for_match_counts(urls[i],m,title_to_re(m),0,1);

                    if (mode == "imdbtitle" ) {
                        # Now get number of occurences without the year. 
                        # This also includes ocurrences with the year so adds suitable weight to names with years.
                        noyear = gensub(/ [12][0-9]{3}\>/,"","g",m);
                        if (noyear != m ) {
                            s += scan_page_for_match_counts(urls[i],noyear,title_to_re(noyear),0,1);
                            s  =s **= 2;
                        }
                    }
                    if (s != 0) pages++;
                    subtotal += s;
                }
            }
        }
        matches[m] += pages * subtotal;
        id0(pages*subtotal);
    }
    ret = getMax(matches,4,1);
    return ret;
}

# This is disabled -  I think it was too intensive and too many false positives.
function web_search_frequent_imdb_link(minfo,\
url,txt) {

    id1("web_search_frequent_imdb_link");
    
    txt = basename(minfo[NAME]);
    if (tolower(txt) != "dvd_volume" ) {
        url=searchHeuristicsForImdbLink(txt);
    }

    if (url == "" && match(minfo[NAME],gExtRegexIso)) {
        txt = getIsoTitle(minfo[DIR]"/"minfo[NAME]);
        if (length(txt) - 3 > 0 ) {
            url=searchHeuristicsForImdbLink(txt);
        }
    }

    if (url == "" && folderIsRelevant(minfo[DIR])) {
        url=searchHeuristicsForImdbLink(tolower(basename(minfo[DIR])));
    }

    id0(url);
    return url;
}

function remove_part_suffix(minfo,\
txt) {
    # Remove first word - which is often a scene tag
    #This could affect the search adversely, esp if the film name is abbreviated.
    # Too much information is lost. eg coa-v-xvid will eventually become just v
    #so we do this last. 
    txt = tolower(basename(minfo[NAME]));

    #Remove the cd1 partb bit.
    if (minfo["mi_multipart_tag_pos"]) {
        txt = substr(txt,1,minfo["mi_multipart_tag_pos"]-1);
        sub("("g_multpart_tags"|)[1a]$","",txt);
        if(LG)DEBUG("MultiPart Suffix removed = ["txt"]");
    }

    return txt;
}

function mergeSearchKeywords(text,keywordArray,\
heuristicId,keywords) {
    # Build array of different styles of keyword search. eg [a b] [+a +b] ["a b"]
    for(heuristicId =  0 ; heuristicId -1  <= 0 ; heuristicId++ ) {
        keywords =textToSearchKeywords(text,heuristicId);
        if (keywords) {
            keywordArray[keywords]=1;
        }
    }
}


function searchHeuristicsForImdbLink(text,\
linksRequired,bestUrl,k,text_no_underscore) {

    linksRequired = 0+g_settings["catalog_imdb_links_required"];
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
#If stripFormatTags set then only portion before recognised format tags (eg 720p etc) is search.
#This helps broaden results and get better consensus from google.
function textToSearchKeywords(f,heuristic\
) {

    if (f != "") {
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
                if(LG)DEBUG("Base query = "f);
                gsub(/[-+.]/,"+%2B",f);
                f="%2B"f;
            }

            gsub(/^\+/,"",f);
            gsub(/\+$/,"",f);

        } else if (heuristic == 2) {

            f = "%22"f"%22"; #double quotes
        }
        if(LG)DEBUG("Using search method "heuristic" = ["f"]");
    }
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
        if(LG)DEBUG("found start format tag ["substr(text,RSTART,RLENGTH)"]");
        sub(/^[[:alnum:]]+[^[:alnum:]]*/,"",text);
    }

    # Remove all trailing tags and any other text.
    if (match(tolower(text),tags)) {
        if(LG)DEBUG("found format tag ["substr(text,RSTART,RLENGTH)"]");
        text = substr(text,1,RSTART-1);
    }

    #remove trailing punctuation
    return trimAll(text);
}

# Convert a movie title and year to a regular expression that should match 
# similar web results eg the.movie 2009 and  The Movie (2009)
# The incoming titles will not have brackets on the year.
function title_to_re(s,\
i,s2,ch) {

    # "the movie 2009" to "the movie \(?2009\)?"
    sub(g_year_re"$","\\(?&\\)?",s); 

    # "the movie" to "[Tt][Hh][Ee] [Mm][Oo]vie"
    # could use tolower() but this means another parameter to scan_page_for_match_counts and complicates
    # returning matches as the match string is modified by tolower().
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
# searchOnlineNfoLinksForImdb(minfo,"http://www.bintube.com","/?q=","/nfo/pid/[0-9a-f]+") 
function searchOnlineNfoLinksForImdb(name,domain,queryPath,nfoPathRegex,maxNfosToScan,inurlFind,inurlReplace,
nfo,nfo2,nfoPaths,imdbIds,totalImdbIds,wgetWorksWithMultipleUrlRedirects,id,count,result) {


    if (length(name) <= 4 || name !~ "^[-.[:alnum:]]+$" ) {
        if(LD)DETAIL("onlinenfo: ["name"] ignored");
    } else {

        id1("Online nfo search for ["name"]");

        sub(/QUERY/,name,queryPath);
        if(LD)DETAIL("query["queryPath"]");

        #Get all nfo links
        scan_page_for_match_counts(domain queryPath,"",nfoPathRegex,maxNfosToScan,1,nfoPaths);

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

                if (scan_page_for_match_counts(nfo2,"tt", g_imdb_regex ,0,1, imdbIds) == 0) {
                    scanPageForIMDBviaLinksInNfo(nfo2,imdbIds);
                }

                for(id in imdbIds) {
                    totalImdbIds[id] += imdbIds[id];
                }
            }
    #    }

        if (hash_size(totalImdbIds) > 3 ) {
            if(LD)DETAIL("Too many nfo results from online search");
        } else {

            #return most frequent match
            bestScores(totalImdbIds,totalImdbIds,0);
            count = hash_size(totalImdbIds);
            if (count == 1) {

                result = extractImdbLink(firstIndex(totalImdbIds));

            } else if (count == 0) {

                if(LD)DETAIL("No matches");

            } else {

                if(LD)DETAIL("To many equal matches. Discarding results");
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
    if (scan_page_for_match_counts(url, "amazon","http://(www.|)amazon[ !#-;=?-~]+",0,1,amazon_urls)) {
        for(amzurl in amazon_urls) {
            if (scan_page_for_match_counts(amzurl, "/tt", g_imdb_regex ,0,1, imdb_per_page)) {
                for(imdb_id in imdb_per_page) {
                    if(LD)DETAIL("Found "imdb_id" via amazon link");
                    imdbIds[imdb_id] += imdb_per_page[imdb_id];
                }
            }
        }
    }
}
# returns 1 if title adjusted or is the same.
# returns 0 if title ignored.
function adjustTitle(minfo,newTitle,source) {
    best_source(minfo,TITLE,clean_title(newTitle),source);
}

function init_priority(\
langs) {
    if (!("default" in gPriority)) {
        #initialise
        gPriority["default"]=0;
        gPriority[TITLE,"filename"]=1;
        gPriority[TITLE,"search"]=10;
        gPriority[TITLE,"tvrage"]=20; # demote tvrage due to non-accented Carnivale
        gPriority[TITLE,"imdb"]=30;
        gPriority[TITLE,"epguides"]=30;
        gPriority[TITLE,"imdb_aka"]=40;
        gPriority[TITLE,"imdb_orig"]=50;

        # themoviedb is demoted below IMDB as some entries not good eg tt0892769 it:Dragons instead of it:Dragon Trainer
        # Also in themoviedb people link DVD shorts to the main ttid causing imdb lookup to fail eg Desplicable Me -> Minion Madness

        #however themoviedb title is prefered for localisation.
        gPriority[TITLE,"imdb"]=60;
        gPriority[TITLE,"themoviedb"]=65;
        gPriority[TITLE,"thetvdb"]=70;

        gPriority[ORIG_TITLE,"themoviedb"]=60; 

        gPriority[POSTER,"imdb"]=40;
        gPriority[POSTER,"thetvdb"]=80;
        gPriority[POSTER,"web"]=70;

        get_langs(langs);

        if(langs[1] == "en" ) {
            gPriority[POSTER,"web"]=70;
            gPriority[POSTER,"movieposterdb"]=80; 
            gPriority[POSTER,"themoviedb"]=90; 
            gPriority[POSTER,"thetvdb"]=90;
        } else {
            gPriority[POSTER,"thetvdb"]=70;
            gPriority[POSTER,"web"]=70;
            gPriority[POSTER,"themoviedb"]=80; 
            gPriority[POSTER,"movieposterdb"]=90; 
        }
        gPriority[POSTER,"local"]=100;

        gPriority[FANART,"thetvdb"]=60;
        gPriority[FANART,"web"]=70;
        gPriority[FANART,"themoviedb"]=90; # increased now api v3 has localised posters
        gPriority[FANART,"local"]=100;

        gPriority[RATING,"themoviedb"]=20;
        gPriority[RATING,"thetvdb"]=20;
        gPriority[RATING,"imdb"]=60;

        gPriority[RUNTIME,"themoviedb"]=50;
        gPriority[RUNTIME,"imdb"]=60;

        # If info obtained from TV websites then ignore imdb category
        # Sometimes wrong for mini-series etc wg Thorne tt1610518
        gPriority[CATEGORY,"thetvdb"]=70;
        gPriority[CATEGORY,"tvrage"]=70;
        gPriority[CATEGORY,"imdb"]=60;

        gPriority["mi_certrating","themoviedb"]=70;
        gPriority["mi_certcountry","themoviedb"]=70;
        gPriority["mi_certrating","imdb"]=60;
        gPriority["mi_certcountry","imdb"]=60;

        gPriority[GENRE,"themoviedb"]=40;
        gPriority[GENRE,"thetvdb"]=40;
        gPriority[GENRE,"imdb"]=50;

        gPriority[SET,"imdb"]=50;
        gPriority[SET,"themoviedb"]=30;
    }
}
function minfo_field_priority(minfo,field,\
key,source) {
    key=field"_source";
    if (key in minfo) source = minfo[key];

    return field_priority(field,source,minfo[field]);
}

# TODO plot could be weighted by language match
function field_priority(field,source,value,\
score) {

    init_priority();

    score = 0;

    if (value != "") {
        if (source ~ "^[0-9]+") {
            # if source is numeric then it IS the score.
            score = 0+source;
        } else if (field == PLOT || field == EPPLOT) {
            if (source == "@nfo" ) {
                score = plot_score("@nfo");
            } else {
                score = plot_score(value);
            }
        } else if (source != "") {
            score = gPriority[field,source];
        }
        if (score) {

            #if(LG)DEBUG("field_priority("field","source")="score);

        } else {

            # Generally give priority to tmdb and thetvdb first, then imdb (which we are phasing out) , finally anything else.
            if (source == "@nfo" ) {
                score = 99; # default nfo score - highest
            } else if (source == "@imdb" ) {
                score = 1; # default imdb score 
            } else {
                score = gPriority["default"];
            }
            #if(LG)DEBUG("field_priority: "field" source ["source"] defaults to "score);
        }
    }
    return score;
}

# Value is plot in form "lang:plot text" (see add_lang_to_plot() ) OR just "@nfo"
function plot_score(plot,\
score,langs,plot_lang,i,num,lang_score,len_score) {
    score = 0;
    if (plot) {
        if (plot == "@nfo" ) {
            lang_score = 1000;
            len_score = 9999;
        } else {
            len_score = utf8len(plot);
            if (substr(plot,3,1) == ":") {
                plot_lang = lang(plot);
                num = get_langs(langs);
                for(i = 1 ; i<= num ; i++ ) {
                    if (plot_lang == langs[i]) {
                        lang_score = 1000-10*i;
                        break;
                    }
                }
            }
        }
        if (lang_score || len_score) {
            score = lang_score * 10000 + len_score;
        }
    }
    return score;
}

function is_better_source(minfo,field,source,value,\
old_inf,new_inf,ret,old_num,new_num,old_src_key,old_src,n) {

    n = db_fieldname(field);
    source = tolower(source);

    old_src_key = field"_source";
    if (old_src_key in minfo) {
        old_src = minfo[old_src_key];
    }

    old_inf="["old_src":"minfo[field]"]";
    new_inf="["source":"value"]";

    old_num = field_priority(field,old_src,minfo[field])+0;
    new_num = field_priority(field,source,value)+0; 

    old_inf = old_inf"("old_num")";
    new_inf = new_inf"("new_num")";

    if (new_num >= old_num ) {

        ret = 1;

    } else {

        ret = 0;
    }
    if (old_src) {
        if (ret) {
            if(LD)DETAIL("updated "n" "new_inf" was "old_inf);
        } else {
            if(LD)DETAIL("kept "n" "old_inf" ignore "new_inf);
        }
    } else {
        if(LD)DETAIL("added "n" "new_inf);
    }
    return ret;
}
function best_source(minfo,field,value,source,\
ret) {

    source = tolower(source);

    ret = 0;
    if (value) {
        if (is_better_source(minfo,field,source,value)) {
            #if(LG)DEBUG("xx updating ["source":"value"]");
            minfo[field] = value;
            minfo[field"_source"] = source;
            ret = 1;
        }
    } else {
        if(LD)DETAIL("blank value for "field" ignored");
    }
    return ret;
}

#Searching is more intensive now and it is easy to get google rejecting searches based on traffic.
#So we apply round-robin (yahoo,msn,ask) to avoid getting blacklisted.

#
function search_url(url) {
    sub(/^SEARCH/,g_search_engine[(g_search_engine_current++) % g_search_engine_count],url);
    return url;
}

function isreg(t) {
    if (index(t,"\\<")) return 1;
    gsub(/\\./,"",t);
    return match(t,"[][().|$^+*]");
}
function scrape_until(f,end_text,inclusive) {
    
    return trim(remove_tags(raw_scrape_until(f,end_text,inclusive)));
}
function raw_scrape_until(f,end_text,inclusive,\
line,out,ending,isre) {
    ending = 0;
    isre = isreg(end_text);
    #if(LG)DEBUG("isreg["end_text"] = "isre);


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
        #if(LD)DETAIL("removing "substr(out,start_pos,end_pos-start_pos));
        out = substr(out,1,start_pos-1) tail;
    }
    return out;
}


function copy_ids_and_titles(ids,input,out) {
    delete out;
    return merge_ids_and_titles(ids,input,out);
}

function merge_ids_and_titles(ids,input,out,\
new_total,i,dupe_check,new_id,new_title) {
    new_total = out["total"]+0;
    for (i in ids) {

        new_id = input[i,1];
        new_title = input[i,2];

        if (dupe_check[new_id] != new_title) {
            new_total++;
            out[new_total,1] = new_id;
            out[new_total,2] = new_title;

            dupe_check[new_id] = new_title;
        }
    }
    out["total"] = new_total;
    return new_total;
}
# remove dupliace ids,titles from array if id,title pairs. [x,1]=id [x,2]=title
# dedup_level=0 - remove duplicate titles.
# dedup_level=1 - Also remove duplicate ids (possible different titles for i18n)
function dedup_ids_and_titles(input,dedup_level,\
out,i,n,total,dup,id,title_lc) {

    total = n = input["total"];

    if (!n) {

        n = hash_size(input);
        if (n%1) {
            ERR("Odd total "n" for data");
            return;
        }
        n = int(n/2);
        if (n) {
            ERR("Missing total "n" from data");
            dump(0,"data",input);
        }
    }

    total = 0;

    for(i = 1 ; i <= n ; i++ ) {
        id = input[i,1];
        if (dedup_level == 0 ) {
            # Keep unique titles (case insensitive).
            title_lc = tolower(input[i,2]);
            if (dup[id] != title_lc) {
                total++;
                out[total,1] = id;
                out[total,2] = input[i,2];
                dup[id] = title_lc;
            }
        } else if (dedup_level == 1) {
            # Keep unique ids.
            if (!(id in dup)) {
                total++;
                out[total,1] = id;
                out[total,2] = input[i,2];
                dup[id] = 1;
            }
        }
    }
    if (total < n ) {
        hash_copy(input,out);
    }
    input["total"] = total;
    return input["total"];
}

function clean_html(fin,fout,\
line,e,inbody) {

    inbody = 0;

    while(enc_getline(fin,line) > 0 ) {
        line[1] = tolower(line[1]);

        if (!inbody && index(line[1],"<body")) inbody = 1;

        if (inbody) {
            gsub(/<[^>]+>/,"",line[1]);

            # Ignore full-stops eg Gilmore.Girls.S10 and Hyphens Brothers-and-sisters.
            gsub(/[-.]/," ",line[1]);
            line[1] = clean_title(line[1]);

            if (line[1] != "") {
                #print "clean_html ["line[1]"]";
                print line[1] >> fout;
            }
        }
    }
    if (e >= 0) {
        enc_close(fin);
    }
    close(fout);
}

#Find title that appears most in web page search
function filter_web_titles2(engine,count,titles,filterText,\
keep,new,newtotal,url,f,fclean,i,e,line,title,num,tmp) {
    newtotal = count;
    if (count > 1) {
        id1("filter_web_titles2 "engine" in="count);

        #url = g_search_yahoo url_encode("+\""filterText"\"");
        url = engine url_encode(filterText);
        f = getUrl(url,".html",0);
        if (f) {

            if(LD)DETAIL("File = "f);

            fclean=f".clean";
            clean_html(f,fclean);

            #Get number of occurences of tv show
            for(i = 1 ; i<= count ; i++ ) {

                title = clean_title(titles[i,2]);
                # Ignore full-stops eg Gilmore.Girls.S10
                gsub(/\./," ",title);

                num = 0;

                # Check for occurences of title in each line of the file
                while( (e =  (getline line < fclean ) ) > 0) {
                    if (index(line,title)) {
                        num += split(line,tmp,"\\<"title"\\>") - 1;
                        if(LD)DETAIL("found:["title"x"num"]["line"]");
                    }
                }
                if (e >= 0) {
                    close(fclean);
                }
                if (num > 2) {
                    # Select longest title : eg "Brothers" vs "Brothers and Sisters" which both abbreviate bs
                    keep[i] = num*length(title);
                }
                if(num) {
                    if(LD)DETAIL("Title count "title" = "num" ["line"]");
                }
            }

        }

        bestScores(keep,keep);
        if (hash_size(keep)) {
            newtotal = copy_ids_and_titles(keep,titles,new);
            delete titles;
            hash_copy(titles,new);
        }
        id0(newtotal);
    }
    return newtotal;
}


# Find title that returns largest page size.
function filter_web_titles(count,titles,filterText,filteredTitles,\
keep,new,newtotal,size,url,i,blocksz) {

    if (count) {
        id1("filter_web_titles in="count);

        newtotal=0;
        blocksz = 2000;

        if (count > 36 ) {
            WARNING("Too many titles to filter. Aborting");
        } else {

            url = g_search_yahoo url_encode("+\""filterText"\"");

            #Establish baseline for no matches.
            if (!g_filter_web_titles_baseline) {
                g_filter_web_titles_baseline = get_page_size(url url_encode(" +"rand()systime()));
                g_filter_web_titles_baseline = int(g_filter_web_titles_baseline/blocksz);
            }

            for(i = 1 ; i<= count ; i++ ) {
                size = get_page_size(url url_encode(" +\""titles[i,2]"\""));
                size = int(size / blocksz );
                if (size > g_filter_web_titles_baseline) {
                    keep[i] = size;
                } else {
                    if(LG)DEBUG("Discarding "titles[i,1]":"titles[i,2]);
                }
            }

            bestScores(keep,keep);
            newtotal = copy_ids_and_titles(keep,titles,new);
            delete filteredTitles;
            hash_copy(filteredTitles,new);
        }

        id0(newtotal);
    }
    return newtotal;
}

function get_bing_json_serp(body,titles,\
i,sections,total,num) {

    delete titles;

    num = split(body,sections,"\"Title\":\"");
    for(i = 2 ; i <= num ; i++) {
        titles[++total] = gensub(/",".*/,"",1,sections[i]);
    }
    dump(0,"bing json serps",titles);
    return total;
}
function get_bing_mobile_serp(body,titles,\
i,pos,sections,total,num) {

    num = ovs_patsplit(body,sections,"href=\"/search[^<]+</a>");
    for(i = 1 ; i <= num ; i++) {
        if (index(sections[i],"redirurl") && index(sections[i],"rid=")) {
            titles[++total] = sections[i];
        }

    }
    for(i = 1 ; i <= total ; i++) {


        titles[i] = de_emphasise(titles[i]);

        sub(/<\/a>$/,"",titles[i]);

        pos=index(titles[i],">");
        if (pos > 0) {
            titles[i] = substr(titles[i],pos+1);
        }           
    }
    dump(0,"bing serps?",titles);
    return total;
}
