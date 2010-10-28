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

function scrape_imdb_line(line,imdbContentPosition,minfo,f,pagestate,namestate,\
title,poster_imdb_url,i,orig_country_pos,aka_country_pos,orig_title_country,aka_title_country,tmp) {


    if (imdbContentPosition == "footer" ) {
        return imdbContentPosition;
    } else if (imdbContentPosition == "head" ) {

        #Only look for title at this stage
        #First get the HTML Title
        if (index(line,"<title>")) {
            if (index(line,"</title>")) {
                title = extractTagText(line,"title");
            } else {
                title=trimAll(scrape_until("ititle",f,"</title>",1));
            }
            DEBUG("Title found ["title "] current title ["minfo["mi_title"]"]");

            #extract right most year in title
            if (minfo["mi_year"] == "" && match(title,".*\\("g_year_re)) {
                minfo["mi_year"] = substr(title,RSTART+RLENGTH-4,4);
                DEBUG("IMDB: Got year ["minfo["mi_year"]"]");
            }

            # Get the almost raw Imdb title. This may have ampersand which 
            # helps to differentiate shows. This is more important if
            # later on we need to # do a lookup from imdb back to a tvdatabase site eg
            # Brothers & Sisters != Brothers and Sisters.
            #
            # It is not so important when mapping filenames to tv shows. in that
            # case we need to be more flexible ( see expand_url() and similarTitles() )
            minfo["mi_motech_title"]=tolower(title);
            gsub(/[^a-z0-9]+/,"-",minfo["mi_motech_title"]);
            gsub(/-$/,"",minfo["mi_motech_title"]);

            minfo["mi_imdb_title"]=extract_imdb_title_category(minfo,title);

            if (adjustTitle(minfo,minfo["mi_imdb_title"],"imdb")) {
                minfo["mi_orig_title"] = minfo["mi_title"];
            }
        }
        if (index(line,"<h1")) {
            imdbContentPosition="body";
        }

    } else if (imdbContentPosition == "body") {

        if (index(line,">Company:")) {

            DEBUG("Found company details - ending");
            imdbContentPosition="footer";

        } else {

            #This is the main information section

            if ((i=index(line,"a name=\"poster\"")) > 0) {
                poster_imdb_url = extractAttribute(substr(line,i-1),"img","src");
                if (poster_imdb_url != "") {

                    #Save it for later. 
                    minfo["mi_imdb_img"]=imdb_img_url(poster_imdb_url);
                    DEBUG("IMDB: Got imdb poster ["minfo["mi_imdb_img"]"]");
                }
            }
            if (index(line,"Director") && match(line,"Directors?:?\\>")) {
                minfo["role"] ="director";
                minfo["role_max"] = g_max_directors;
                INF("set role "minfo["role_max"]":"minfo["role"]);

            } else if (index(line,"Writer") && match(line,"Writers?:?\\>")) {

                minfo["role"] ="writer";
                minfo["role_max"] = g_max_writers;
                INF("set role "minfo["role_max"]":"minfo["role"]);

            } else if (index(line,"Cast")) {

                minfo["role"] ="actor";
                minfo["role_max"] = g_max_actors;
                INF("set role "minfo["role_max"]":"minfo["role"]);
            }
            get_names("imdb",line,minfo,minfo["role"],minfo["role_max"],pagestate,namestate);
            #TODO shrink minfo["mi_actor"]

            # "Plot" on normal page - "Plot Summary" on mobile pages.
            if (minfo["mi_plot"] == "" && ( index(line,">Plot:<") ||index(line,">Plot Summary<")) ) {
                set_plot(minfo,"mi_plot",scrape_until("iplot",f,"</div>",0));
                sub(/\|.*/,"",minfo["mi_plot"]);
                sub(/[Ff]ull ([Ss]ummary|[Ss]ynopsis).*/,"",minfo["mi_plot"]);
                #DEBUG("imdb plot "minfo["mi_plot"]);
            }

            #IMDB Genre takes precedence
            if (minfo["mi_genre"] == "" && index(line,">Genre")) {

                minfo["mi_genre"]=trimAll(scrape_until("igenre",f,"</div>",0));

                gsub(/,/,"|",minfo["mi_genre"]); # mobile site uses commas.

                DEBUG("Genre=["minfo["mi_genre"]"]");
                sub(/ +[Ss]ee /," ",minfo["mi_genre"]);
                sub(/ +[Mm]ore */,"",minfo["mi_genre"]);
            }

            #desktop
            if (minfo["mi_runtime"] == "" && (index(line,">Runtime:") || index(line,">Run time"))) {
                tmp=trimAll(scrape_until("irtime",f,"</div>",1));
                minfo["mi_runtime"] = extract_duration(tmp);

            }

            # Always overwrite tvdb ratings with imdb ones.
            # desktop -  <b>7.1/10</b> 
            if (index(line,"/10</b>") && match(line,"[0-9.]+/10") ) {
                minfo["mi_rating"]=0+substr(line,RSTART,RLENGTH-3);
               DEBUG("IMDB: Got Rating = ["minfo["mi_rating"]"]");
            }
            #mobile - <strong>7.1</strong>&#47;10 &#40;148,280 votes&#41;
            if (index(line,"&#47;10") && match(line,"[0-9.]+</strong>") ) {
                minfo["mi_rating"]=0+substr(line,RSTART,RLENGTH-3);
               DEBUG("IMDB: Got Rating = ["minfo["mi_rating"]"]");
            }

            # Desktop - full certificate scrape
            if (index(line,"certificates")) {

                scrapeIMDBCertificate(minfo,line);

            }
            # mobile - just get rated.
            if (index(line,">Rated<")) {
                minfo["mi_certrating"]=trimAll(scrape_until("irtime",f,"</div>",1));
                minfo["mi_certcountry"]="USA";
            }



            # Title is the hardest due to original language titling policy.
            # Good Bad Ugly, Crouching Tiger, Two Brothers, Leon lots of fun!! 

            if (index(line,"Also Known")) DEBUG("AKA "minfo["mi_orig_title"]" vs "minfo["mi_title"]);

            if (minfo["mi_orig_title"] == minfo["mi_title"] && index(line,"Also Known As:")) {
                line = raw_scrape_until("aka",f,"</div>",1);

                DEBUG("AKA:"line);

                aka_title_country = scrapeIMDBAka(minfo,line);

            }

            if (index(line,"Country:")) {
                # There may be multiple countries. Only scrape the first one.
                orig_title_country = scrape_until("title",f,"</a>",1);
                orig_country_pos = index(g_settings["catalog_title_country_list"],orig_title_country);
                aka_country_pos = index(g_settings["catalog_title_country_list"],aka_title_country);

                if (orig_country_pos > 0 ) {
                    if (aka_title_country == "" ||  orig_country_pos <= aka_country_pos ) {
                        adjustTitle(minfo,minfo["mi_orig_title"],"imdb_orig"); 
                    }
                }
            }
        }
    } else {
        DEBUG("Unknown imdbContentPosition ["imdbContentPosition"]");
    }
    return imdbContentPosition;
}

function imdb_list_shrink(s,sep,base,\
i,n,out,ids,m,id) {
    n = split(s,ids,sep);
    for(i = 1 ; i <= n ; i++ ) {


        if (index(ids[i],"tt") == 1 || index(ids[i],"nm") == 1) {

            id = substr(ids[i],3);

            m = basen(id,base);

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

            m = base10(ids[i],base);
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
    url = "http://uk.imdb.com/title/"extractImdbId(id)"/movieconnections";
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
        #DEBUG("Extracted IMDB Id ["id"]");
    } else if (match(text,"Title.[0-9]+\\>")) {
        id = "tt" substr(text,RSTART+8,RLENGTH-8);
        #DEBUG("Extracted IMDB Id ["id"]");
    } else if (!quiet) {
        WARNING("Failed to extract imdb id from ["text"]");
    }
    if (id != "" && length(id) != 9) {
        id = sprintf("tt%07d",substr(id,3));
    }
    return id;
}

function extractImdbLink(text,quiet,lang,\
t) {
    t = extractImdbId(text,quiet);
    if (t != "") {
        t = "http://www.imdb.com/title/"t"/"; # Adding the / saves a redirect
        if (lang && lang != "en" ) {
            if(lang ~ /^(de|dk|ee|es|fm|fr|ge|it|pt)$/ ) {
                sub("com",lang,t);
            } else {
                INF("No localized imdb for "lang);
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

function scrapeIMDBCertificate(minfo,line,\
l,cert_list,certpos,cert,c,total,i,flag) {

    flag="certificates=";

    #Old style  -- <a href="/List?certificates=UK:15&&heading=14;UK:15">
    total = get_regex_pos(line, flag"[^&\"]+",0,cert_list,certpos);

    for(i = 1 ; i - total <= 0 ; i++ ){

        l = substr(cert_list[i],index(cert_list[i],flag)+length(flag));

        split(l,cert,"[:|]");

        #Now we only want to assign the certificate if it is in our desired list of countries.
        for(c = 1 ; (c in gCertificateCountries ) ; c++ ) {
            if (minfo["mi_certcountry"] == gCertificateCountries[c]) {
                #Keep certificate as this country is early in the list.
                return;
            }
            if (cert[1] == gCertificateCountries[c]) {
                #Update certificate
                minfo["mi_certcountry"] = cert[1];

                minfo["mi_certrating"] = toupper(cert[2]);
                gsub(/%20/," ",minfo["mi_certrating"]);
                DEBUG("IMDB: set certificate ["minfo["mi_certcountry"]"]["minfo["mi_certrating"]"]");
                return;
            }
        }
    }
}



