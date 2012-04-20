# IMDB functions. Until IMDB provide a stable API, oversight should emphasise using
# 1. information from themoviedb.org (stable API).
# 2. very generic format tolerant web scraping of arbitry sites (intelligent scraping).
#

function imdb_img_height(url,n) {
    #Get smaller image from server.
    if (!sub(/_SY[0-9]+/,"_SY"n,url)) {
        sub(/_.jpg$/,"._SY"n".jpg",url);
    }
    return url;
}

#Get highest quality imdb image by removing dimension info
function imdb_img_url(url) {
    while (sub(/\.?_(SX|SY|CR)[0-9,]+/,"",url)) {
        #donothing;

    }
    return url;
}

# input imdb id
# OUT: id of lowest movie id in Follows(prequels)
# updates minfo[SET]
function imdb_movie_connections(minfo,\
id,series,versions,ret) {

    if (minfo[CATEGORY] == "M") {
        id = imdb(minfo);
        id1("getMovieConnections:"id);

        if(id) {
            imdb_movie_connections1(id,series,versions,3);
            asort(series);

            if (series[1] != "") {
                ret = minfo[SET] = "imdb:"series[1];
            }
        }
        id0(ret);
    }
    return ret;
}
function remove_unwanted_html(body,
i,j,cut) {
    # remove top of page
    i = index(body,"<h1");
    if (i) body = substr(body,i);
    #remove end of page
    cut[1] = ">References";
    cut[2] = ">Referenced in";
    cut[3] = "TOP_RHS";
    for(i = 1 ; i<= 3 ; i++ ) {
        if ((j = index(body,cut[i])) > 0) {
            body = substr(body,1,j);
            break;
        }
    }
    return body;
}

function imdb_movie_connections1(id,series,versions,get_version_series,\
sections,series_heading,version_heading,end,numsections,\
found_section,relationship,i,count,html,txt,v,url,hdr,body,regex,response) {

    series_heading = 1;
    version_heading = 2;
    end=99;
    sections["Follows"] = sections["Followed by"] = series_heading;


    sections["Remake of"] = sections["Remade as"] = sections["Version of"] = end;
    # uncomment this like to get remakes into boxsets.
    #sections["Remake of"] = sections["Remade as"] = sections["Version of"] = version_heading;
    sections["References"] = sections["Referenced in"] = end;
    numsections = hash_size(sections);
    regex = "(<h[1-5][^>]*>[^<&]+|\\<"g_imdb_regex")" ; # Grab headings or imdb ids
    url = "http://www.imdb.com/title/"id"/trivia?tab=mc";

    if(id && !(id in series)){

        id1("getMovieConnections1:"id);

        # Use the inline browser - this is not as robust as external command line but should be faster.
        # could have just sef g_fetch["force_awk"] and hand off to scan_page_for_match_order()
        # but beneficial to remove a lot of stuff from the page first.

        if (url_get(url,response,"",0)) {
            body = remove_unwanted_html(response["body"]);
            count = get_matches(1,body,regex,0,0,html,0);
        }

        #dump(0,"movieconnections-"count,html);
        for(i = 1 ; i <= count ; i++ ) {
            txt = html[i];
            if (substr(txt,1,2) == "tt" ) {
                if (relationship in sections) {
                    # Sequels may have lower ID eg Star Wars etc. Prequels made after first movie.
                    if (sections[relationship] == series_heading) {
                        series[txt] = txt;
                    } else if (sections[relationship] == version_heading) {
                        versions[txt] = txt;
                    }
                }
            } else {
                
                if (sections[relationship] ) {
                    found_section ++;
                    if (found_section == numsections) {
                        break;
                    }
                }

                # <h4,,,>Header
                split(txt,hdr,">");
                relationship=trim(hdr[2]);

                if (sections[relationship] == end) break;
            }
        }
        # Make sure this id goes in its own collection
        series[id] = id;

        if (get_version_series > 0) {
            for(v in versions) {
                imdb_movie_connections1(v,series,versions,get_version_series-1);
            }
        }
        if (hash_size(series)) dump(0,"series",series);
        if (hash_size(versions)) dump(0,"versions",versions);
    }
    id0();
}

function extractImdbId(text,quiet,\
id) {
    if (match(text,g_imdb_regex)) {
        id = substr(text,RSTART,RLENGTH);

    } else if ((id = subexp(text,"Title.([0-9]+)\\>") ) != "") {

        id = "tt"id;

    } else if (!quiet) {
        if (text) WARNING("Failed to extract imdb id from ["text"]");
    }
    if (id != "" && length(id) != 9) {
        id = sprintf("tt%07d",substr(id,3));
    }
    return id;
}

function extractImdbLink(text,quiet,locale,\
t) {
    if (text != "-1") {
        t = extractImdbId(text,quiet);
        if (t != "") {
            t = "http://www.imdb.com/title/"t"/"; # Adding the / saves a redirect

            if (locale) {
                if (locale == "fi_FI" )  sub("www","finnish",t);
                else if (locale == "en_GB" ) sub("www","uk",t);
                else if (locale == "en_US" ) sub("www","m",t);
                else if (locale == "it_IT" || locale == "fr_FR" || locale == "pt_PT" || locale == "es_ES" || locale == "ee_EE" ) {
                    sub("com",tolower(substr(locale,4)),t);
                } else {
                   if(LD)DETAIL("No localized imdb for "locale);
                   t = "";
                }
            }
        }
    }
    return t;
}


function extract_imdb_title_category(minfo,title\
) {
    # semicolon,quote,quotePos,title2
    #If title starts and ends with some hex code ( &xx;Name&xx; (2005) ) extract it and set tv type.
    minfo[CATEGORY]="M";
    if(LG)DEBUG("imdb title=["title"]");
    if (match(title,"^\".*\"") ) {   # www.imdb.com
        title=substr(title,RSTART+1,RLENGTH-2);
        minfo[CATEGORY]="T";
    } else if (sub(/ ?T[vV] [Ss]eries ?/,"",title)) { # m.imdb.com
        minfo[CATEGORY]="T";
    }

    #Remove the year
    gsub(/ \((19|20)[0-9][0-9](\/I|)\) *(\([A-Z]+\)|)$/,"",title);

    if(LG)DEBUG("Imdb title = "minfo[CATEGORY]":["title"]");
    return title;
}
