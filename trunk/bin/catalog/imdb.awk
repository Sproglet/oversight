# IMDB functions. Until IMDB provide a stable API, oversight should emphasise using
# 1. information from themoviedb.org (stable API).
# 2. very generic format tolerant web scraping of arbitry sites (intelligent scraping).
#

#Get highest quality imdb image by removing dimension info
function imdb_img_url(url) {
    while (sub(/\.?_(SX|SY|CR)[0-9,]+/,"",url)) {
        #donothing;

    }
    return url;
}

# input imdb id
# OUT: id of lowest movie id in Follows(prequels)
# updates minfo["mi_set"]
function imdb_movie_connections(minfo,\
id,url,htag,connections,i,count,relationship,ret,txt,sep,hdr,prequels,sequels,sections,set) {


    prequels = "Follows";
    sequels = "Followed by";

    if (minfo["mi_category"] == "M") {
        id = imdb(minfo);
        id1("getMovieConnections:"id);

        if(id) {
            htag = "h5";
            sep=",";
            url = "http://www.imdb.com/title/"id"/trivia?tab=mc";
            count=scan_page_for_match_order(url,"","(<h[1-5][^>]*>[^<&]+|"g_imdb_regex")",0,0,"",connections);

            #dump(0,"movieconnections-"count,connections);
            set[id] = id;
            for(i = 1 ; i <= count ; i++ ) {
                txt = connections[i];
                if (substr(txt,1,2) == "tt" ) {
                    if (relationship == prequels || relationship == sequels ) {
                        # Sequels may have lower ID eg Star Wars etc. Prequels made after first movie.
                        set[txt] = txt;
                    }
                } else {
                    if (relationship == prequels ) sections++;
                    else if (relationship == sequels ) sections++;
                    else if (sections == 2) break;
                    # <h4,,,>Header
                    split(txt,hdr,">");
                    relationship=trim(hdr[2]);
                }
            }
            asort(set);
            if (sections) {
                ret = minfo["mi_set"] = "imdb:"set[1];
            }
        }
        id0(ret);
    }
    return ret;
}

function extractImdbId(text,quiet,\
id) {
    if (match(text,g_imdb_regex)) {
        id = substr(text,RSTART,RLENGTH);

    } else if ((id = subexp(text,"Title.([0-9]+)\\>") ) != "") {

        id = "tt"id;

    } else if (!quiet) {
        WARNING("Failed to extract imdb id from ["text"]");
    }
    if (id != "" && length(id) != 9) {
        id = sprintf("tt%07d",substr(id,3));
    }
    return id;
}

function extractImdbLink(text,quiet,locale,\
t) {
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
               INF("No localized imdb for "locale);
               t = "";
            }
        }
    }
    return t;
}


function extract_imdb_title_category(minfo,title\
) {
    # semicolon,quote,quotePos,title2
    #If title starts and ends with some hex code ( &xx;Name&xx; (2005) ) extract it and set tv type.
    minfo["mi_category"]="M";
    DEBUG("imdb title=["title"]");
    if (match(title,"^\".*\"") ) {   # www.imdb.com
        title=substr(title,RSTART+1,RLENGTH-2);
        minfo["mi_category"]="T";
    } else if (sub(/ ?T[vV] [Ss]eries ?/,"",title)) { # m.imdb.com
        minfo["mi_category"]="T";
    }

    #Remove the year
    gsub(/ \((19|20)[0-9][0-9](\/I|)\) *(\([A-Z]+\)|)$/,"",title);

    DEBUG("Imdb title = "minfo["mi_category"]":["title"]");
    return title;
}
