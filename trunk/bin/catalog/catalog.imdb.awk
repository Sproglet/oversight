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

# isection tracks sections found. This helps alert us to IMDB changes.
function scrape_imdb_line(line,imdbContentPosition,minfo,f,isection,\
title,poster_imdb_url,i,sec,orig_country_pos,aka_country_pos,orig_title_country,aka_title_country,tmp) {


    if (imdbContentPosition == "footer" ) {
        return imdbContentPosition;
    } else if (imdbContentPosition == "header" ) {

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
                delete isection[YEAR];
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
            sec=TITLE;
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
                sec=POSTER;
            }
            # Scrape mobile page
            if (minfo["mi_actors"] == "" && index(line,">Top Billed Cast")) {
                minfo["mi_actors"] = get_names("actors",raw_scrape_until("actors",f,"</section>",0),g_max_actors);
                minfo["mi_actors"] = imdb_list_shrink(minfo["mi_actors"],",",128);
                sec=ACTORS;
            }
            # Scrape desktop  page
            if (minfo["mi_actors"] == "" && index(line,">Cast") ) {
                minfo["mi_actors"] = get_names("actors",raw_scrape_until("actors",f,"</table>",0),g_max_actors);
                minfo["mi_actors"] = imdb_list_shrink(minfo["mi_actors"],",",128);
                sec=ACTORS;
            }

            if (minfo["mi_director"] == "" && index(line,">Director")) {
                minfo["mi_director"] = get_names("directors",raw_scrape_until("director",f,"</div>",0),g_max_directors);
                minfo["mi_director_name"] = g_first_name;
                minfo["mi_director"] = imdb_list_shrink(minfo["mi_director"],",",128);
                sec=DIRECTOR;
            }
            if (minfo["mi_writers"] == "" && index(line,">Writer")) {
                minfo["mi_writers"] = get_names("writers",raw_scrape_until("writers",f,"</div>",0),g_max_writers);
                minfo["mi_writers"] = imdb_list_shrink(minfo["mi_writers"],",",128);
                sec=WRITERS;
            }

            # "Plot" on normal page - "Plot Summary" on mobile pages.
            if (minfo["mi_plot"] == "" && ( index(line,">Plot:<") ||index(line,">Plot Summary<")) ) {
                set_plot(minfo,"mi_plot",scrape_until("iplot",f,"</div>",0));
                sub(/\|.*/,"",minfo["mi_plot"]);
                sub(/[Ff]ull ([Ss]ummary|[Ss]ynopsis).*/,"",minfo["mi_plot"]);
                #DEBUG("imdb plot "minfo["mi_plot"]);
               sec=PLOT;
            }

            #IMDB Genre takes precedence
            if (minfo["mi_genre"] == "" && index(line,">Genre")) {

                minfo["mi_genre"]=trimAll(scrape_until("igenre",f,"</div>",0));

                gsub(/,/,"|",minfo["mi_genre"]); # mobile site uses commas.

                DEBUG("Genre=["minfo["mi_genre"]"]");
                sub(/ +[Ss]ee /," ",minfo["mi_genre"]);
                sub(/ +[Mm]ore */,"",minfo["mi_genre"]);
               sec=GENRE;
            }

            #desktop
            if (minfo["mi_runtime"] == "" && (index(line,">Runtime:") || index(line,">Run time"))) {
                tmp=trimAll(scrape_until("irtime",f,"</div>",1));
                if (match(tmp,"[0-9]+ h")) {
                    minfo["mi_runtime"] = 60 * substr(tmp,RSTART,RLENGTH);
                }
                if (match(tmp,"[0-9]+ m")) {
                    minfo["mi_runtime"] += substr(tmp,RSTART,RLENGTH);
                }
               sec=RUNTIME;
            }

            # Always overwrite tvdb ratings with imdb ones.
            # desktop -  <b>7.1/10</b> 
            if (index(line,"/10</b>") && match(line,"[0-9.]+/10") ) {
                minfo["mi_rating"]=0+substr(line,RSTART,RLENGTH-3);
               DEBUG("IMDB: Got Rating = ["minfo["mi_rating"]"]");
               sec=RATING;
            }
            #mobile - <strong>7.1</strong>&#47;10 &#40;148,280 votes&#41;
            if (index(line,"&#47;10") && match(line,"[0-9.]+</strong>") ) {
                minfo["mi_rating"]=0+substr(line,RSTART,RLENGTH-3);
               DEBUG("IMDB: Got Rating = ["minfo["mi_rating"]"]");
               sec=RATING;
            }

            # Desktop - full certificate scrape
            if (index(line,"certificates")) {

                scrapeIMDBCertificate(minfo,line);
                sec=CERT;

            }
            # mobile - just get rated.
            if (index(line,">Rated<")) {
                minfo["mi_certrating"]=trimAll(scrape_until("irtime",f,"</div>",1));
                minfo["mi_certcountry"]="USA";
                sec=CERT;
            }



            # Title is the hardest due to original language titling policy.
            # Good Bad Ugly, Crouching Tiger, Two Brothers, Leon lots of fun!! 

            if (index(line,"Also Known")) DEBUG("AKA "minfo["mi_orig_title"]" vs "minfo["mi_title"]);

            if (minfo["mi_orig_title"] == minfo["mi_title"] && index(line,"Also Known As:")) {
                line = raw_scrape_until("aka",f,"</div>",1);

                DEBUG("AKA:"line);

                aka_title_country = scrapeIMDBAka(minfo,line);
                sec=AKA;

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
    if (sec) delete isection[sec];
    return imdbContentPosition;
}

# name_db is always "actors"
# text = imdb text to be parsed for nm0000 ids.
# maxnames = max number of names to fetch ( -1 = all )
function get_names(name_db,text,maxnames,\
dtext,dpos,dnum,i,id,name,dlist,count,img,img_folder) {

    img_folder = name_db;

    # This is a hack - we also want the first director name for scraping non-english sites
    g_first_name = ""; 

    # Extract nm0000 text OR anchor text(actor name) OR jpg url
    dnum = get_regex_pos(text,"(/nm[0-9]+|>[^<]+</a>|"g_nonquote_regex"+\\.jpg)",0,dtext,dpos);
    for(i = 1 ; i <= dnum ; i++ ) {
        #INF(name_db"["dtext[i]"]");

        if (dtext[i] ~ "jpg$") {

            img = imdb_img_url(dtext[i]);

        } else if (substr(dtext[i],1,3) == "/nm" ) {

            id=substr(dtext[i],2);

        } else if (id ) {
            if (index(dlist,","id) == 0) {
                count++;
                if (maxnames+0 >= 0 && count+0 > maxnames+0) {
                    break;
                }
                # Extract name from <a> tag
                name=extractTagText("<a"dtext[i],"a");

                dlist=dlist ","id;

                # output just the name - the is a risk of namesakes occuring with writers or directors.
                # take that risk for now
                #print id"\t"name > g_tmp_dir"/"name_db".db."PID  ;
                print name > names_tmp_file(name_db)  ;

                INF(name_db"|"id"|"name"|"img);

                if (g_first_name == "") {
                    g_first_name = name;
                }

                # Seems to have a lot of portraits
           #     if (img == "") {
           #         img = "http://www.turkcealtyazi.org/film/images/"id".jpg";
           #         # http://ownfilmcollection.com/ERaImage/DCimages/name/nm2652511.jpg
           #     }

                get_image(id,img,APPDIR"/db/global/"img_folder"/"g_settings["catalog_poster_prefix"] id".jpg");
            }
            id="";
            img="";
        }
    }
    close(names_tmp_file(name_db));
    #INF(name_db":"dlist);
    return substr(dlist,2);
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
    url = extractImdbLink(id)"movieconnections";
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

# return ""=unknown "M"=movie "T"=tv??
function scrapeIMDBTitlePage(minfo,url,\
f,line,imdbContentPosition,isection,connections,remakes,ret) {

    if (url == "" ) return;

    #Remove /combined/episodes from urls given by epguides.
    url=extractImdbLink(url);

    if (url == "" ) return;

    id1("scrape imdb ["url"]");


    if (minfo["mi_imdb"] == "") {
        minfo["mi_imdb"] = extractImdbId(url);
    }
    if (minfo["mi_imdb_scraped"] != minfo["mi_imdb"] ) {
        
        INF("scraping "url);

        f=getUrl(url,"imdb_main",1);
        hash_copy(isection,g_imdb_sections);

        if (f != "" ) {

            imdbContentPosition="header";

            DEBUG("START IMDB: title:"minfo["mi_title"]" poster "minfo["mi_poster"]" genre "minfo["mi_genre"]" cert "minfo["mi_certrating"]" year "minfo["mi_year"]);

            FS="\n";
            while(imdbContentPosition != "footer" && enc_getline(f,line) > 0  ) {
                imdbContentPosition=scrape_imdb_line(line[1],imdbContentPosition,minfo,f,isection);
            }
            enc_close(f);

            if (hash_size(isection) > 0 ) {
                ERR("Unparsed imdb sections ");
                dump(0,"missing",isection);
            }


            if (minfo["mi_certcountry"] != "" && g_settings[g_country_prefix minfo["mi_certcountry"]] != "") {
                minfo["mi_certcountry"] = g_settings[g_country_prefix minfo["mi_certcountry"]];
            }

        }

        if (minfo["mi_category"] == "M" ) {
            getNiceMoviePosters(minfo,extractImdbId(url));
            getMovieConnections(extractImdbId(url),connections);
            if (connections["Remake of"] != "") {
                getMovieConnections(connections["Remake of"],remakes);
            }
            minfo["mi_conn_follows"]= connections["Follows"];
            minfo["mi_conn_followed_by"]= connections["Followed by"];
            minfo["mi_conn_remakes"]=remakes["Remade as"];
            INF("follows="minfo["mi_conn_follows"]);
            INF("followed_by="minfo["mi_conn_followed_by"]);
            INF("remakes="minfo["mi_conn_remakes"]);
        }

        # make sure we dont scrape this id for this item again
        minfo["mi_imdb_scraped"] = minfo["mi_imdb"];
    }
    ret = minfo["mi_category"];
# Dont need premier anymore - this was for searching from imdb to tv database
# we just use the year instead.
#    if (minfo["mi_category"] == "T" && minfo["mi_premier"] == "" ) {
#        minfo["mi_premier"] = remove_tags(scanPageFirstMatch(url"/releaseinfo","BusinessThisDay.*",1));
#        DEBUG("IMDB Premier = "minfo["mi_premier"]);
#    }
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

function extractImdbLink(text,quiet,\
t) {
    t = extractImdbId(text,quiet);
    if (t != "") {
        t = "http://www.imdb.com/title/"t"/"; # Adding the / saves a redirect
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

    DEBUG("Imdb title = ["title"]");
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


