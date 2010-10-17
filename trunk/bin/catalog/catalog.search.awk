# Functions for searching and scraping


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

    dump(0,"normalise titles in ",matches);
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
    dump(0,"normalise titles out",normed);
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
function web_search_frequent_imdb_link(minfo,\
url,txt,linksRequired) {

    id1("web_search_frequent_imdb_link");
    linksRequired = 0+g_settings["catalog_imdb_links_required"];
    
    txt = basename(minfo["mi_media"]);
    if (tolower(txt) != "dvd_volume" ) {
        url=searchHeuristicsForImdbLink(txt,linksRequired);
    }

    if (url == "" && match(minfo["mi_media"],gExtRegexIso)) {
        txt = getIsoTitle(minfo["mi_folder"]"/"minfo["mi_media"]);
        if (length(txt) - 3 > 0 ) {
            url=searchHeuristicsForImdbLink(txt,linksRequired);
        }
    }

    if (url == "" && folderIsRelevant(minfo["mi_folder"])) {
        url=searchHeuristicsForImdbLink(tolower(basename(minfo["mi_folder"])),linksRequired);
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
    txt = tolower(basename(minfo["mi_media"]));

    #Remove the cd1 partb bit.
    if (minfo["mi_multipart_tag_pos"]) {
        txt = substr(txt,1,minfo["mi_multipart_tag_pos"]-1);
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
# returns 1 if title adjusted or is the same.
# returns 0 if title ignored.
function adjustTitle(minfo,newTitle,source,\
oldSrc,newSrc,newRank) {

    source = tolower(source);

    if (!("filename" in gTitlePriority)) {
        #initialise
        gTitlePriority[""]=-1;
        gTitlePriority["filename"]=0;
        gTitlePriority["search"]=10;
        gTitlePriority["tvrage"]=20; # demote TVRAGE due to non-accented Carnivale
        gTitlePriority["imdb"]=30;
        gTitlePriority["epguides"]=30;
        gTitlePriority["imdb_aka"]=40;
        gTitlePriority["imdb_orig"]=50;
        gTitlePriority["thetvdb"]=60;
    }
    newTitle = clean_title(newTitle);

    oldSrc=minfo["mi_title_source"]":["minfo["mi_title"]"] ";
    newSrc=source":["newTitle"] ";

    if (!(source in gTitlePriority)) {

        ERR("Unknown [title source "source"] passed to adjustTitle");
        newRank = gTitlePriority["imdb"];

    } else {
        newRank = gTitlePriority[source];
    }
    #if  (ascii8(newTitle)) newRank += 10; # Give priority to accented names
    if (minfo["mi_title"] == "" || newRank - minfo["mi_title_rank"] > 0) {
        INF("adjustTitle: "oldSrc" promoted to "newSrc);
        minfo["mi_title"] = newTitle;
        minfo["mi_title_source"] = source;
        minfo["mi_title_rank"] = newRank;;
        return 1;
    } else {
        INF("adjustTitle: current title "oldSrc "outranks " newSrc);
        return 0;
    }
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


