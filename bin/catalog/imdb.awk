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

        if (in_top250(id)) {
            minfo[TOP250] = 1;
        }

        id1("getMovieConnections:"id);

        if(id) {
            imdb_movie_connections1(id,series,versions,0);
            asort(series);

            #Only add sets if there are two or more movies (inclusive)
            if (series[2] != "") {
                set_name_from_titles(id,minfo[TITLE]);
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

function imdb_trvia_url(id) {
    return "http://www.imdb.com/title/"id"/trivia?tab=mc";
}

function imdb_movie_connections1(id,series,versions,get_version_series,\
sections,sec,i,sec_count,v,url,response,ids) {


    if(id && !(id in series)){

        # Make sure this id goes in its own collection
        series[id] = id;

        url = imdb_trvia_url(id);

        id1("getMovieConnections1:"url);

        # Use the inline browser - this is not as robust as external command line but should be faster.
        # could have just sef g_fetch["force_awk"] and hand off to scan_page_for_match_order()
        # but beneficial to remove a lot of stuff from the page first.

        if (url_get(url,response,"",1)) {
            
            sec_count = split(response["body"],sections,"(<a name=\"|TOP_RHS)");
            #dump(1,"connections page",sections);
        }

        for(sec = 1 ; sec <= sec_count ; sec++ ) {
            if (index(sections[sec],"follow") == 1) {
                ovs_patsplit(sections[sec],ids,g_imdb_regex);
                dump(1,substr(sections[sec],1,20),ids);
                for(i in ids) {
                    series[ids[i]] = ids[i];
                }
            } else if (index(sections[sec],"rema") == 1 || index(sections[sec],"version") == 1) {
                ovs_patsplit(sections[sec],ids,g_imdb_regex);
                dump(1,substr(sections[sec],1,20),ids);
                for(i in ids) {
                    versions[ids[i]] = ids[i];
                }
            }
        }

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

function in_top250(id) {
    load_top250(g_top250);
    return (id in g_top250);
}

function load_top250(top) {
    if(!(1 in top)) {
        DETAIL("scanning top250");
        scan_page_for_match_order("http://www.imdb.com/chart/top","",g_imdb_regex,0,0,top);
        hash_invert(top,top);
        dump(0,"top250",top);
        top[1]=1;
        DETAIL("end scanning top250");
    }
}

