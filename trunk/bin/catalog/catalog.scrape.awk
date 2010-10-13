# Given a movie title and year try to find a site in the required language and scrape
# INPUT title
# INPUT year
# IN/OUT minfo - Movie info
# RETURN 0 = no errors
function find_movie_page(title,year,runtime,minfo,\
langs,num,i,err,minfo2) {

    err = 1;
    id1("find_movie_page "title" ("year")");

    num = split(g_settings["catalog_languages"],langs,",");
    for ( i = 1 ; i <= num ; i++ ) {
        err=find_movie_by_lang(langs[i],title,year,runtime,minfo2);
        if (!err) {
            hash_merge(minfo,minfo2);
            break;
        }
    }
    id0(err);
    return err;
}

# Given a movie title and year try to find a site in the required language and scrape
# INPUT lang - 2 letter language code 
# INPUT title - movie title
# INPUT year 
# IN/OUT minfo - Movie info
# RETURN 0 = no errors
function find_movie_by_lang(lang,title,year,runtime,minfo,\
i,num,sites,minfo2,err,searchhist) {

    err=1;
    id1("find_movie_by_lang:"lang);
    if (load_plugin_settings("lang",lang)) {


        num=split(g_settings["lang:catalog_lang_movie_site_search"],sites,",");
        for ( i = 1 ; i <= num ; i++ ) {
            err=find_movie_by_site_lang(sites[i],lang,title,year,runtime,minfo2,searchhist);
            if (!err) {
                hash_merge(minfo,minfo2);
                break;
            }
        }
    }
    id0(err);
    return err;
}

# Search Engine query to hopefully find movie url 
# IN site  - from cf file, used in search. It may be just domain (site:xxx) or include part of the url (inurl:)
# IN lang - 2 letter language code
# IN title - movie title - passed to query
# IN year  - passed to query
# OUT minfo - Movie info - cleared before use.
# IN/OUT searchhist - hash of visited urls(keys) and domains.
# RETURN 0 = no errors
function find_movie_by_site_lang(site,lang,title,year,runtime,minfo,searchhist,\
minfo2,err,url,qualifier,keyword,matches,num,search_domain,url_domain,url_text,url_regex,i,max_allowed_results) {

    err = 1;
    id1("find_movie_by_site_lang("site","lang")");

    if (index(site,"/")) {
        keyword="inurl:";
    } else {
        keyword="site:";
    }

    qualifier = url_encode("\""title"\" "year" "keyword site);

    url = g_search_google qualifier;

    search_domain = get_main_domain(site);
    if(search_domain) {
        if (load_plugin_settings("domain",search_domain)) {
            max_allowed_results = 2;
            # match any url where the site is part of the URL and also
            url_regex = "href=.http://[^\"\\/]*"re_escape(site)"[^\"]+";
            url_text = search_domain;
        } else {
            max_allowed_results = 0;
        }
    } else {
        if (load_plugin_settings("domain","default")) {
            # scraping TLD eg .fr .it etc.
            max_allowed_results = 5;
            url_text = site;
        }
    }

    if (max_allowed_results) {
        num = scan_page_for_matches(url,url_text,url_regex,0,0,"",1,matches);

        for(i in matches) {
            sub(/href=./,"",matches[i]);
        }

        dump(0,"matches",matches);
        if(search_domain) {
            num = remove_non_movie_urls(num,matches,g_settings["domain:catalog_domain_movie_url_regex"]);
        }
        num = remove_suburls(matches);
        num = remove_visited_urls(num,matches,searchhist);

        if (num < max_allowed_results) {
            num = max_allowed_results;
        }

        dump(0,"filtered matches",matches);
        for(i = 1 ; i <= num ; i++ ) {
            url_domain = get_main_domain(matches[i]);

            if (is_visited_domain(url_domain,searchhist)) {
                INF("ignoring ["matches[i]"] - previous visit to site does not have plot");
            } else {

                set_visited_url(matches[i],searchhist);
                err = scrape_movie_page(title,year,runtime,matches[i],lang,search_domain,minfo2);
                if (!err) {
                    hash_merge(minfo,minfo2);
                    break;
                } else if (err == 2) {
                    # scrape ok but no plot - ignore entire domain
                    INF("ignoring further searches at "url_domain);
                    set_visited_domain(url_domain,searchhist);
                }
            }

        }
    }

    id0(err);
    return err;
}

function set_visited_domain(domain,hist) {
    hist["domain@" domain] = 1;
}
function set_visited_url(domain,hist) {
    hist["url@" domain] = 1;
}
function is_visited_domain(domain,hist) {
   return  ("domain@"domain in hist);
}
function is_visited_url(url,hist) {
   return  ("url@"url in hist);
}

function remove_visited_urls(num,matches,hist,\
i,j,keep,keep_num) {
    keep_num = num;

    j = 0;
    for(i = 1 ; i<= num ; i++ ) {

        if (is_visited_url(matches[i],hist) ) {

            # ignore - duplicate url
            INF("ignore ["matches[i]"] - already visited");

        } else if (is_visited_domain(get_main_domain(matches[i]),hist) ) {

            INF("ignore ["matches[i]"] - previous visit to site does not have plot");
        } else {
            keep[++j] = matches[i];
        }
    }
    hash_copy(matches,keep);
    keep_num = j;
    return keep_num;
}
# Remove all urls that do not look like movie urls for this domain.
function remove_non_movie_urls(num,matches,regex,\
i,j,keep,keep_num) {
    keep_num = num;

    if (regex && regex != "." ) {
        j = 0;
        for(i = 1 ; i<= num ; i++ ) {
            if (matches[i] ~ regex ) {
                keep[++j] = matches[i];
            } else {
                INF("ignore ["matches[i]"] - not a movie url");
            }
        }
        hash_copy(matches,keep);
        keep_num = j;
    }
    return keep_num;
}

# Remove any urls that are subsets of others.
# IN/OUT matches hash of urls => order in web page.
function remove_suburls(matches,\
i,j,keep) {

    # Set value of all longer urls to 0
    for ( i in matches ) {
        if (matches[i]) {
            for ( j in matches ) {
                if (j != i && matches[j]) {
                    if (index(matches[j],matches[i]) == 1 ) {
                        matches[j] = 0;
                    }
                }
            }
        }
    }

    # copy all urls with non-zero value

    j = 0;
    for ( i = 1 ; (i in matches) ; i++ ) {
        if (matches[i] == 0) {
            DEBUG("removing ["matches[i]"] ");
        } else {
            keep[++j] = matches[i];
        }
    }
    hash_copy(matches,keep);
    return j;
}

# Scrape a movie page - results into minfo
# IN title - movie title
# IN year 
# IN url - page to scrape
# IN lang - 2 letter language code
# IN domain  - main domain of site eg imdb, allocine etc.
# OUT minfo - Movie info - cleared before use.
# RETURN 0 if no issues, 1 if title or field mismatch. 2 if no plot (skip rest of this domain)
function scrape_movie_page(title,year,runtime,url,lang,domain,minfo,
f,minfo2,err,line,pagestate,namestate) {

    delete minfo;
    err = 0;
    id1("scrape_movie_page("url","lang","domain","title","year")");

    if (url && lang && title )  {

        f=getUrl(url,lang":"domain":"title":"year,1);
        if (f) {

            pagestate["mode"] = "head";
            while(enc_getline(f,line) > 0  ) {
                err = scrape_movie_line(title,year,runtime,lang,domain,line[1],minfo2,pagestate,namestate);
                if (err) {
                    INF("abort page");
                    break;
                }
            }
            close(f);
        }
            
    }

    if (!err) {
        err = !check_title(title,minfo2) || !check_year(year,minfo2) || !check_runtime(runtime,minfo2);
    }

    if (!err  &&  !is_prose(minfo2["mi_plot"]) ) {
        #We got the movie but there is no plot;
        #The main reason for alternate site scraping is to get a title and a plot, so a missing plot is
        #a significant failure. Most other scraped info is language neutral.
        INF("missing plot");
        err = 2;
    }

    if (err) {
        dump(0,"bad page info",minfo2);
    } else {
        hash_merge(minfo,minfo2);
        dump(0,title"-"year"-"domain"-"lang,minfo);
    }

    id0(err);
    return err;
}

function check_year(year,minfo,\
ret) {
    ret = 1;
    if (year && minfo["mi_year"]) {
        ret = year-minfo["mi_year"];
        ret = ((ret*ret) <= 1);
        if (ret) {
            DEBUG("year scraped ok");
        } else {
            INF("page rejected by year ["minfo["mi_year"]"] != ["year"]");
        }
    }
    return ret;
}

function check_title(title,minfo,\
ret) {
    ret = 1;
    if (title && minfo["mi_title"]) {
        ret = (index(tolower(minfo["mi_title"]),tolower(title)) || index(tolower(minfo["mi_orig_title"]),tolower(title)));
        if (ret) {
            DEBUG("title scraped ok");
        } else {
            INF("page rejected title ["minfo["mi_title"]"] or ["minfo["mi_title"]"] != ["title"]");
        }
    }
    return ret;
}
function check_runtime(runtime,minfo,\
ret) {
    ret = 1;

    if (runtime && minfo["mi_runtime"]) {

        ret = (runtime == minfo["mi_runtime"]);

        if (ret) {
            DEBUG("runtime scraped ok");
        } else {
            INF("page rejected by runtime ["minfo["mi_runtime"]"] != ["runtime"]");
        }
    }

    return ret;
}

#
# This function moves src=url or href=url  outside of the tag.
# it is called before calling remove_tags so that the urls are 
# still available for further processing.
# This is requred because the urls often contain actor ids.
function preserve_src_href(line,\
line2,do_href,do_img) {
    
    # Before removing tags we want to preserve (img)src= or href= 
    # as these are used by the get_names function, to process people.

    do_href = (index(line,"<a") || index(line,"<A"));
    do_img = (index(line,"<img") || index(line,"<IMG"));

    while(do_href) {

        # <a attr1 href=xxx attr2 >Label</a>
        # to
        # href=xxx <a attr1 attr2 >Label</a>
        line2 = gensub(/(<[Aa][^>]+)[hH][rR][eE][fF]=[\"']([^\"']+)[\"']([^>]*)/,"href=\"\\2\"\\1\\3","g",line);
        if (line2 == line) break;
        line = line2;
    }

    while(do_img) {
        # <img attr1 src=xxx attr2 />
        # to
        # img=xxx <img attr1 attr2 />
        line2 = gensub(/(<[iI][mM][gG][^>]+)src=[\"']([^\"']+)[\"']([^>]*)/,"img=\"\\2\"\\1\\3","g",line);
        if (line2 == line) break;
        line = line2;
    }
    if (line2) DEBUG("srchref=["line"]");
    return line;
}

# Remove html tags  - and break into sections defined by tags td,tr,table,div,
# INPUT line - html text
# OUTPUT sections - array of logical segments with markup removed.
# Href labels surrounded with @label@ - this is so that actor names can be recognized by get_names


function reduce_markup(line,sections,pagestate,\
sep,ret,lcline) {

    delete sections;

    if (pagestate["debug"]) DEBUG("reduce_markup0:["line"]");

    line = trim(line);

    if (line) {
        lcline = tolower(line);

        sep="#";
        #DEBUG("reduce_markup0:["line"]");
        gsub(/<\/?(table|TABLE|tr|TR|td|TD|div|DIV|br|BR|hr|HR|[Hh][1-5])[^>]*>/,sep,line);
        #DEBUG("reduce_markup1:["line"]");

        # remove option list text, otherwise after removing html tags a long list(imdb) can look too
        # much like prose, and be mistaken for the plot.
        if(index(lcline,"option")) {
            gsub(/<(option|OPTION)[^>]*>[^<]+<\/(option|OPTION)>/,"",line);
        }

        line = preserve_src_href(line);

        if (index(lcline,"<a") ) {
            line = gensub(/(<[Aa][^>]*>)([^<]+)(<\/[aA]>)/,"\\1@label@\\2@label@\\3","g",line);
        }

        if (pagestate["mode"] != "body") {

            if (pagestate["titletag"] <= 2 ) {
                # check for TITLE tags.
                if (index(lcline,"title") ) {
                    if (sub(/<(title|TITLE)[^>]*>/,"@title-start@",line)) {
                        pagestate["titletag"]++;
                        pagestate["mode"] = "titletag";
                    }
                    if (sub(/<\/(title|TITLE)>/,"@title-end@",line)) {
                        pagestate["titletag"]++;
                        pagestate["mode"] = "titletag";
                    }

                } else if (pagestate["mode"] == "titletag" && pagestate["titletag"] == 2) {

                    pagestate["mode"] = "head";
                }
            }

            # check for end of HEAD start of BODY
            if (index(lcline,"</html>") || index(lcline,"<body") ) {
                pagestate["mode"]="body";
            }
        }

        line = trim(remove_tags(line));

        # remove spaces around sep
        gsub(" +"sep,sep,line);
        gsub(sep" +",sep,line);

        # remove multiple sep
        gsub(sep"+",sep,line);

        if (line != sep) {
            ret = split(line,sections,sep);
        }
    }
    if (pagestate["debug"]) DEBUG("reduce_markup9:["line"]");
    #DEBUG("reduce_markup9:["line"]="ret);
    return ret;
}

# Scrape a movie page - results into minfo
# IN lang - 2 letter language code
# IN domain  - main domain of site eg imdb, allocine etc.
# IN line - a line of text 
# IN/OUT minfo - Movie info
# IN/OUT pagestate - info about which tag we are parsing
# IN/OUT namestate - info about which person we are parsing
# RETURN 0 if no issues, 1 if title or field mismatch.
function scrape_movie_line(title,year,runtime,lang,domain,line,minfo,pagestate,namestate,\
i,num,sections,err) {

    err = 0;
    sub(/^ */,"",line);

    pagestate["debug"] = index(line,"Avec");

    num = reduce_markup(line,sections,pagestate);
    if (num) {
        if (pagestate["mode"] != "head" ) {

            if (pagestate["debug"]) {
                dump(0,"fragments",sections);
            }

            for(i = 1 ; i <= num ; i++ ) {
                if (sections[i]) {
                    err = scrape_movie_fragment(title,year,runtime,lang,domain,sections[i],minfo,pagestate,namestate);
                    if (err) {
                        INF("abort line");
                        break;
                    }
                }
            }
        }
    }
    return err;
}

# Scrape a movie page - results into minfo
# IN lang - 2 letter language code
# IN domain  - main domain of site eg imdb, allocine etc.
# IN fragment - page text - cleaned of most markup by reduce_markup
# IN/OUT minfo - Movie info
# IN/OUT pagestate - info about which tag we are parsing
# IN/OUT namestate - info about which person we are parsing
# RETURN 0 if no issues, 1 if title or field mismatch.
function scrape_movie_fragment(title,year,runtime,lang,domain,fragment,minfo,pagestate,namestate,\
mode,rest_fragment,max_people,field,value,tmp,err) {

    DEBUG("scrape_movie_fragment:["pagestate["mode"]":"fragment"]");
    #DEBUG("scrape_movie_fragment:("lang","domain","fragment")");
    # Check if fragment is a fieldname eg Plot: Cast: etc.
    mode = get_movie_fieldname(lang,fragment,rest_fragment,pagestate);
    if(mode) {
        pagestate["mode"] = mode;
        fragment = rest_fragment[1];
        pagestate["keyword_count"] ++;
        DEBUG("@@@ mode = "mode);
    }
    mode = pagestate["mode"];

    if (mode == "titletag" ) {

        if ( index(fragment,"@title-start") ) {
            pagestate["intitle"]=1;
        }
        if (pagestate["intitle"]) {
            pagestate["title"] = pagestate["title"]fragment;
            if ( index(fragment,"@title-end") ) {
                pagestate["intitle"]=0;
                field="mi_title";
                value=pagestate["title"];
                gsub(/@title-(start|end)@/,"",value);
            }
        }

    } else if(mode == "director" || mode == "actor" || mode == "writer") {

        max_people = g_settings["catalog_max_"mode"s"];
        if (!max_people) max_people = 3;
        get_names(domain,fragment,minfo,mode,max_people,pagestate,namestate);

    } else if ( mode == "title" ) {

        field="mi_title";
        value = trim(fragment);

    } else if ( mode == "year" ) {

        field="mi_year";
        if (minfo[field] == "") {
            value = gensub(".*("g_year_re").*","\\1",1,fragment);
#        if (match(fragment,".*"g_year_re)) {
#            # Add .* to get the last year mentioned.
#            value = substr(fragment,RSTART,RLENGTH);
#        }
        }

    } else if ( mode == "country" ) {

        field="mi_country";
        value = trim(fragment);

    } else if ( mode == "original_title" ) {

        field = "mi_orig_title";
        value = trim(fragment);

    } else if ( mode == "duration" ) {

        field = "mi_runtime";
        value = extract_duration(fragment);

    } else if ( mode == "genre" ) {

        if (index(fragment,"@label@")) {
            field = "mi_genre";
            split(fragment,tmp,"@label@");

            minfo[field] = minfo[field]"|"tmp[2];
            DEBUG("genre set to ["minfo[field]"]");
        }

    } else if ( mode == "plot" ) {

        if (is_prose(fragment)) {
            field = "mi_plot";
            value = fragment;
        } else if (length(fragment > 20) ) {
            if (!("badplot" in pagestate)){ 
                DEBUG("Missing plot ???");
                pagestate["badplot"] = 1;
            }
        }

    } else if ( mode == "title" ) {
        field = "mi_title";
        value = fragment;
    }
    err = 0;
    if (field && value ) {
        if (minfo[field]) {
            DEBUG("scrape_movie_fragment:"field"=["value"] but already have ["minfo[field]"]");
        } else {
            INF("scrape_movie_fragment:"field"=["value"]");
            minfo[field]=value;
            if (field == "mi_year" && !check_year(year,minfo)) {
                err = 1;
            } else if (field=="mi_runtime" && !check_runtime(runtime,minfo)) {
                err = 1;
            } else if (field=="mi_title" && !check_title(title,minfo)) {
                err = 1;
            }
        }
    }
    return err;
}

function is_prose(text,\
tmp,num) {
    if (length(text) > g_min_plot_len) {
        num = split(text,tmp," ")+0;
        #DEBUG("words = "num" required "(length(text)/10));
        if (num >= length(text)/10 ) {
            return 1;
        }
    }
    return 0;
}

function keyword_list_to_regex(list) {
    list = re_escape(list);
    gsub(/,/,"|",list);
    return "("list")";
}

# Check if a page fragment begins with a keyword.
# IN lang 2 letter language code
# IN fragment
# RETURN keyword eg plot, cast, genre
# OUT rest[1] = remaining fragment if keyword present.
function get_movie_fieldname(lang,fragment,rest,pagestate,\
key,regex,ret,lcfragment) {

    rest[1] = fragment;

    if (!("badplot" in pagestate) && is_prose(fragment)) {

       ret = "plot";

    }  else {

        lcfragment = tolower(fragment);

        # Get language regexs
        if (!pagestate["lang_regex"]) {
            pagestate["lang_regex"] = 1;
            for (key in g_settings) {
                if (index(key,"lang:catalog_lang_keyword_") == 1) {
                    if (g_settings[key]) {
                        if (!(key in pagestate)) {
                            pagestate[key] = "^ *"keyword_list_to_regex(tolower(g_settings[key]))"( *:? *| )";
                        }
                    }
                }
            }
        }
        for (key in pagestate) {
            if (index(key,"lang:catalog_lang_keyword_") == 1) {
                regex = pagestate[key];
                if (pagestate["debug"]) {
                    DEBUG("checking fragment["fragment"] against ["key"]="regex);
                }
                if (match(lcfragment,regex)) {
                    rest[1] = substr(fragment,RSTART+RLENGTH);

                    ret = gensub(/lang:catalog_lang_keyword_/,"",1,key);
                    DEBUG("matching regex = ["regex"]");
                    break;
                }
            }
        }
    }
    if (ret) {
        DEBUG("matched "ret" rest = ["rest[1]"]");
    }
    return ret;
}

# return ""=unknown "M"=movie "T"=tv??
function scrapeIMDBTitlePage(minfo,url,lang,\
domain,f,line,imdbContentPosition,connections,remakes,ret,pagestate,namestate) {

    if (url == "" ) return;

#ALL TODO    domain=get_main_domain(url);

#ALL TODO    if (!load_plugin_settings("domain",domain)) {
#ALL TODO        return;
#ALL TODO    }

    #Remove /combined/episodes from urls given by epguides.
    url=extractImdbLink(url); # TODO Generic ID extraction

    if (url == "" ) return;

    id1("scrape lang="lang" domain="domain" ["url"]");

    if (minfo["mi_imdb"] == "") {
        minfo["mi_imdb"] = extractImdbId(url);
    }
    if (minfo["mi_imdb_scraped"] != minfo["mi_imdb"] ) {
        
        INF("scraping "url);

        f=getUrl(url,"imdb_main",1);

        if (f != "" ) {

            imdbContentPosition="head";

            DEBUG("START IMDB: title:"minfo["mi_title"]" poster "minfo["mi_poster"]" genre "minfo["mi_genre"]" cert "minfo["mi_certrating"]" year "minfo["mi_year"]);

            FS="\n";
            minfo["role"] = "";

            while(imdbContentPosition != "footer" && enc_getline(f,line) > 0  ) {
                imdbContentPosition=scrape_imdb_line(line[1],imdbContentPosition,minfo,f,pagestate,namestate);
            }

            delete minfo["role"];
            delete minfo["role_max"];

            enc_close(f);

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


#
# Extract Actor names and portraits from html.
#
# expect image to be  <a HREF=.. ><img SRC=...></a>
# expect name to be  <a HREF=.. >NAME</a>
#
# INPUT domain  =imdb,allocine etc loads domain config file.
# INPUT text    = html text to parse.
# INPUT minfo   = details for current item being scanned/scraped.
# INPUT role    = actor,writer,director
# INPUT maxnames = maximum number of names to scrape 
# IN/OUT namesstate = this tracks the src=,img= tags as it drops through the HTML
# RETURN number of names parsed.
# GLOBAL updates minfo[mi_role_names/mi_role_ids] with cast names and external ids.
# GLOBAL updates g_portrait_queue with url to portrait picture.

# The input should have been cleaned using reduce_markup this will remove homst html markup
# but convert <a href="some_url" >text</a> to href="some_url"@label@some label@label@
# 
function get_names(domain,text,minfo,role,maxnames,pagestate,namestate,\
csv,total,i,num){
    # split by commas - this will fail if there is a comma in the URL
    if (index(text,",")) {
        num = split(text,csv,",");
    } else {
        num = 1;
        csv[1] = text;
    }
    for(i = 1 ; i <= num ; i++ ) {
        total += get_names_by_comma(domain,csv[i],minfo,role,maxnames,pagestate,namestate);
    }
    return total;
}

# INPUT domain  =imdb,allocine etc loads domain config file.
# INPUT text    = html text to parse.
# INPUT minfo   = details for current item being scanned/scraped.
# INPUT role    = actor,writer,director
# INPUT maxnames = maximum number of names to scrape 
# IN/OUT namesstate = this tracks the src=,img= tags as it drops through the HTML
# RETURN number of names parsed.
# GLOBAL updates minfo[mi_role_names/mi_role_ids] with cast names and external ids.
# GLOBAL updates g_portrait_queue with url to portrait picture.

# The input should have been cleaned using reduce_markup this will remove homst html markup
# but convert <a href="some_url" >text</a> to href="some_url"@label@some label@label@
function get_names_by_comma(domain,text,minfo,role,maxnames,pagestate,namestate,\
dtext,dnum,i,count,href_reg,src_reg,name_reg) {

    if (role ) {
        count = minfo["mi_"role"_total"];

        if(count < maxnames) {
            # Assumes a text does not have any markup inside. just a plain name
            # <a href=url ><img src=url /></a><a href=url ><img src=url /></a>
            # split by <a or a>

            if (index(text,"href=") || index(text,"img=") ) {

                href_reg = "href=\"[^\"]+";
                src_reg = "img=\"[^\"]+";
                name_reg = ">[^<]+";
                name_reg = "@label@[^@]+@label@";

                dnum = get_regex_pos(text,"("href_reg"|"src_reg"|"name_reg")",0,dtext);

                for(i = 1 ; i <= dnum && count < maxnames ; i++ ) {

                    if (index(dtext[i],"img=") == 1) {

                    # Convert URL from thumbnail to big
                        namestate["src"] = person_get_img_url(domain,substr(dtext[i],6));
                        if (namestate["id"]) {
                            # Store it for later download once we know the oversight id for this 
                            # person. After the people.db us updated.
                            g_portrait_queue[domain":"namestate["id"]] = namestate["src"];
                            INF("Image for ["namestate["id"]"] = ["namestate["src"]"]");
                        }

                    } else if (index(dtext[i],"@label@") ) {

                        namestate["name"] = gensub(/@label@/,"","g",dtext[i]);

                        if (namestate["id"] && namestate["name"]) {

                            INF("get_names:name="namestate["name"]"...");

                            if (! ("mi_"role"_names" in minfo) ) {
                                minfo["mi_"role"_names"]  = domain;
                                minfo["mi_"role"_ids"]  = domain;
                            }
                                
                            if (index(minfo["mi_"role"_ids"]"@","@"namestate["id"]"@") == 0) { 
                                    minfo["mi_"role"_names"]  = minfo["mi_"role"_names"] "@" namestate["name"];
                                minfo["mi_"role"_ids"]  = minfo["mi_"role"_ids"] "@" namestate["id"];
                                count++;
                            }
                        }
                        delete namestate;

                    } else if (index(dtext[i],"href=") == 1) {

                        namestate["href"] = substr(dtext[i],7);
                        namestate["id"] = person_get_id(domain,namestate["href"]);
                    }
                }

            }
            if (count) {
                minfo["mi_"role"_total"] = count;
                INF("get_names:"role"="count);
            }
        }
    }
    return count;
}

# return number of minutes.
function extract_duration(text,\
num,n,p) {
    num = get_regex_pos(text,"[0-9]+",0,n,p);
    if (num == 1) {
        return n[1]+0;
    } else if (num >= 2) {
        return n[1]*60 + n[2];
    }
}
