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


function imdb_list_shrink(s,sep,base,\
i,n,out,ids,m,id) {
    n = split(s,ids,sep);
    for(i = 1 ; i <= n ; i++ ) {


        if (index(ids[i],"tt") == 1 || index(ids[i],"nm") == 1) {

            id = substr(ids[i],3);

            m = basen(id,base,128);

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

            m = base10(ids[i],base,128);
            out = out sep "tt" sprintf("%07d",m) ;
        } else {
            out = out sep ids[i] ;
        }
    }
    out = substr(out,2);
    INF("expand ["s"] = ["out"]");
    return out;
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
    url = "http://imdb.com/title/"extractImdbId(id)"/movieconnections";
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

# Looks for matching country in AKA section. The first match must simply contain (country)
# If it contains any qualifications then we stop looking at any more matches and reject the 
# entire section.
# This is because IMDB lists AKA in order of importance. So this helps weed out false matches
# against alternative titles that are further down the list.

function scrapeIMDBAka(minfo,line,\
akas,a,c,bro,brc,akacount,country) {

    if (minfo["mi_orig_title"] != minfo["mi_title"] ) return ;

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
                        adjustTitle(minfo,clean_title(substr(akas[a],RSTART+1,RLENGTH-4)),"imdb_aka"); 
                    }
                    return country;
                }
            }
        }
    }
}

