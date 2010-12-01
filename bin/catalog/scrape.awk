# Given a movie title and year try to find a site in the required language and scrape
# IN text - text so search for. May not necessarily be exact title eg from filename.
# INPUT title - movie title - used for validation can be blank
# INPUT year  - used for validation can be blank
# INPUT runtime  - used for validation can be blank
# INPUT director  - used for validation can be blank
# IN/OUT minfo - Movie info
# RETURN 0 = no errors
function find_movie_page(text,title,year,runtime,director,minfo,\
i,err,minfo2,num,locales) {

    err = 1;
    id1("find_movie_page text ["text"] title ["title"] year("year")");

    num = get_locales(locales);
    for ( i = 1 ; i <= num ; i++ ) {
        err=find_movie_by_locale(locales[i],text,title,year,runtime,director,minfo2);
        if (!err) {
            minfo_merge(minfo,minfo2);
            break;
        }
    }
    id0(err);
    return err;
}

function load_locale_settings(locale,\
ret) {
    ret = load_plugin_settings("locale",locale);
    if (!ret) {
        if (length(locale) > 2 ) {
            # just try the language 
            ret = load_plugin_settings("locale",substr(locale,1,2));
        }
    }
    return ret;
}


# Given a movie title and year try to find a site in the required language and scrape
# INPUT locale - eg en_US
# IN text - text so search for. May not necessarily be exact title eg from filename.
# INPUT title - movie title - used for validation can be blank
# INPUT year  - used for validation can be blank
# INPUT runtime  - used for validation can be blank
# INPUT director  - used for validation can be blank

# IN/OUT minfo - Movie info
# RETURN 0 = no errors
function find_movie_by_locale(locale,text,title,year,runtime,director,minfo,\
i,num,sites,minfo2,err,searchhist) {

    err=1;
    id1("find_movie_by_locale:"locale" text ["text"] title ["title"] year("year")");
    if (load_locale_settings(locale)) {


        num=split(g_settings["locale:catalog_locale_movie_site_search"],sites,",");
        for ( i = 1 ; i <= num ; i++ ) {
            err=find_movie_by_site_locale(sites[i],locale,text,title,year,runtime,director,minfo2,searchhist);
            if (!err) {
                minfo_merge(minfo,minfo2);
                break;
            }
        }
    }
    id0(err);
    return err;
}

# Search for a movie by title year using multiple search engines. 
# filter urls that score highly (bing is bad for these types of searches. may need to use ask/google)
#
# IN search_engine_prefix eg http://google.com/q=
# IN text - text to find - eg filename may be blank if title set
# IN title - movie title
# IN year - year of release
# IN site - site to search - eg allocine.fr if / present then inurl is added eg inurl:imdb.com/title
# OUT matches - array of matching urls.
function find_links_all_engines(text,title,year,site,matches) {

    return find_links_1engine(g_search_google,text,title,year,site,matches);

}


# Search for a movie by title year and a site: or inurl: and return all matching links.
# The links are filtered according to the regex in conf/domain/catalog.domain.xxx.cfg
#
# IN search_engine_prefix eg http://google.com/q=
# IN text - text to find - eg filename may be blank if title set
# IN title - movie title
# IN year - year of release
# IN site - site to search - eg allocine.fr if / present then inurl is added eg inurl:imdb.com/title
# OUT matches - array of matching urls.

function find_links_1engine(search_engine_prefix,text,title,year,site,matches,\
keyword,qualifier,url,search_domain,url_text,url_regex,num,i) {

    id1("find_links_1engine:"search_engine_prefix);

    # set search qualifier and build search url
    if (index(site,"/")) {
        keyword="inurl:";
    } else {
        keyword="site:";
    }
    qualifier = url_encode(text" "title" "year" "keyword site);
    url = search_engine_prefix qualifier;

    # load config file for this domain (load defaults if a top level domain)
    search_domain = get_main_domain(site);
    url_regex = "href=.http://[^\"'\\/]*"re_escape(site)"[^\"']+";
    url_text = search_domain;
    if (!load_plugin_settings("domain",search_domain)) {
        load_plugin_settings("domain","default");
    }

    # get the links from page one of the search
    num = scan_page_for_matches(url,url_text,url_regex,0,0,"",1,matches);

    for(i in matches) {
        sub(/href=./,"",matches[i]);
    }

    # filter links according to domain definitions
    dumpord(0,"matches",matches);

    num = remove_non_movie_urls(num,matches,g_settings["domain:catalog_domain_movie_url_regex"]);
    num = remove_suburls(matches);

    id0(num);
    return num;
}

# Search Engine query to hopefully find movie url 
# IN site  - from cf file, used in search. It may be just domain (site:xxx) or include part of the url (inurl:)
# IN locale - eg en_US
# IN text - text so search for. May not necessarily be exact title eg from filename.
# IN title - movie title - passed to query
# IN year  - passed to query
# OUT minfo - Movie info - cleared before use.
# IN/OUT searchhist - hash of visited urls(keys) and domains.
# RETURN 0 = no errors
function find_movie_by_site_locale(site,locale,text,title,year,runtime,director,minfo,searchhist,\
minfo2,err,matches,num,url_domain,i,max_allowed_results) {

    err = 1;
    id1("find_movie_by_site_locale("site","locale")");



    num = find_links_all_engines(text,title,year,site,matches);
    num = remove_visited_urls(num,matches,searchhist);

    # Set maximum allowed results
    if (site ~ "^\\.[a-z]+$") {
        max_allowed_results = 5;
    } else {
        max_allowed_results = 2;
    }
    if (num > max_allowed_results) {
        num = max_allowed_results;
    }

    dump(0,"filtered matches",matches);
    for(i = 1 ; i <= num ; i++ ) {
        url_domain = get_main_domain(matches[i]);

        if (is_visited_domain(url_domain,searchhist)) {
            INF("ignoring ["matches[i]"] - previous visit to site does not have plot");
        } else {

            set_visited_url(matches[i],searchhist);
            err = scrape_movie_page(text,title,year,runtime,director,matches[i],locale,url_domain,minfo2);
            if (!err) {
                minfo_merge(minfo,minfo2,url_domain);
                break;
            } else if (err == 2) {
                # scrape ok but no plot - ignore entire domain
                INF("ignoring further searches at "url_domain);
                set_visited_domain(url_domain,searchhist);
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
    if (keep_num != num) {
        dumpord(0,"matches--removed non movie",matches);
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
# IN text - text so search for. May not necessarily be exact title eg from filename.
# IN title - movie title
# IN year 
# IN runtime of movie in minutes (used for validation - mostly ignore for the time being - movies like Leon have varied runtimes)
# IN director - Director surname - may have problems matching  other alphabets. Russian / Greek
# IN url - page to scrape
# IN locale - eg en_US, fr_FR
# IN domain  - main domain of site eg imdb, allocine etc.
# OUT minfo - Movie info - cleared before use.
# RETURN 0 if no issues, 1 if title or field mismatch. 2 if no plot (skip rest of this domain)
function scrape_movie_page(text,title,year,runtime,director,url,locale,domain,minfo,\
f,minfo2,err,line,pagestate,namestate,store) {

    err = 0;
    id1("scrape_movie_page("url","locale","domain","text","title","year")");

    if (have_visited(minfo,domain":"locale)) {

        INF("Already visited");

    } else if (url && locale )  {

        if (!scrape_cache_get(url,minfo2)) {

            store = 1;

            f=getUrl(url,locale":"domain":"title":"year,1);
            if (f) {

                minfo2["mi_url"] = url;
                minfo2["mi_category"] = "M";
                pagestate["mode"] = "head";
                while(enc_getline(f,line) > 0  ) {
                    err = scrape_movie_line(locale,domain,line[1],minfo2,pagestate,namestate);
                    if (err) {
                        INF("abort page");
                        break;
                    }
                }
                close(f);
            }
        } 

        #This will get merged in if page is succesful.
        #if page fails then the normal logical flow of the program should prevent re-visits. not the visited flag.
        set_visited(minfo2,domain":"locale);
            
    } else {
        ERR("paramters missing");
    }

    if (minfo2["mi_category"] == "M") {

        if (!err) {
            # at the moment - check title will just shour circuit if similar score < 0.3
            err = !check_title(title,minfo2) || !check_year(year,minfo2) || !check_director(director,minfo2);
        }

        if (!err  &&  !is_prose(minfo2["mi_plot"]) ) {
            #We got the movie but there is no plot;
            #The main reason for alternate site scraping is to get a title and a plot, so a missing plot is
            #a significant failure. Most other scraped info is language neutral.
            INF("missing plot");
            #err = 2;
        }
    }

    if (err) {
        dump(0,"bad page info",minfo2);
    } else {
        if(index(domain,"imdb")) {
            imdb_extra_info(minfo2,url);
        }
        if (store) {
            scrape_cache_add(url,minfo2);
        }
        minfo_merge(minfo,minfo2,domain);
        dump(0,title"-"year"-"domain"-"locale,minfo);
    }

    id0(err);
    return err;
}

function minfo_merge(current,new,default_source,\
f,source) {

    id1("minfo_merge["default_source"]");
    # Keep best title
    new["mi_title"] = clean_title(new["mi_title"]);
    new["mi_visited"] = current["mi_visited"] new["mi_visited"];
    minfo_merge_ids(current,new["mi_idlist"]);

    for(f in new) {
        if (f !~ "_source$" && f != "mi_visited" && f != "mi_idlist" ) {
            if (f"_source" in new) {
                source = new[f"_source"];
            }
            if (source == "") {
                source = default_source;
            }
            best_source(current,f,new[f],source);
        }
    }
    id0("");
}

#add a website id to the id list - internal format is {<space><domain>:value} 
# eg "imdb:tt1234567 thetvdb:77304"
function minfo_set_id(domain,id,minfo) {
    domain = tolower(domain);
    if (id &&  index(minfo["mi_idlist"]," "domain":") == 0) {
        minfo["mi_idlist"] =  minfo["mi_idlist"]" "domain":"id;
        INF("idlist = "minfo["mi_idlist"]);
    }
}
function get_id(text,domain,adddomain,\
ret) {
    ret = subexp(text,"( |^)("domain":[^ ]+)",2);
    if (!adddomain) {
        sub(/^[^:]+:/,"",ret); # remove domain
    }
    return ret;
}

# return a website id from the idlist
function minfo_get_id(minfo,domain,\
id) {
    id = get_id(minfo["mi_idlist"],domain);
    if (!id) {
        WARNING("blank id for "domain" current list = ["minfo["mi_idlist"]"]");
    }
    return id;
}
# Marge a space separated list of ids into the media info
# eg "imdb:tt1234567 thetvdb:77304"
function minfo_merge_ids(minfo,idlist,\
num,i,ids,parts) {
    num = split(idlist,ids," ");
    for(i in ids) {
        if (split(ids[i],parts,":") == 2) {
            minfo_set_id(parts[1],parts[2],minfo);
        }
    }
}
    
function imdb(minfo) {
    return minfo_get_id(minfo,"imdb");
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
ret,similar_threshold) {

    similar_threshold = 0.3 ; # edit distance / string length.
    ret = 1;
    title = remove_brackets(title);
    if (title && minfo["mi_title"]) {


       ret = 0 ;

       # At present search short circuits as soom as a similar title is found. 
       #For better results we should scrape all pages and pick the one with the most similar title but
       # a. this is time consuming.
       # b. the order of URLS come from a SERP so its expected that the earlier ones should be more relevant.
       if (index(tolower(minfo["mi_title"]),tolower(title)) || index(tolower(minfo["mi_orig_title"]),tolower(title)))  {
           
           ret = 1
           DEBUG("check_title - titles are substrings");
           
       } else if (similar(minfo["mi_title"],title) < similar_threshold || similar(minfo["mi_orig_title"],title) < similar_threshold ) {

           ret = 1;
           DEBUG("check_title - titles are similar");
       } else {
           INF("page rejected title ["minfo["mi_title"]"] or ["minfo["mi_orig_title"]"] != ["title"]");
       }
    }
    return ret;
}
function check_runtime(runtime,minfo,\
ret) {
    ret = 1;

    # Runtime varies too much for some movies that get a lot of scenes cut like Leon
    DEBUG("check_runtime disabled");
#    if (runtime && minfo["mi_runtime"]) {
#
#        ret = (runtime == minfo["mi_runtime"]);
#
#        if (ret) {
#            DEBUG("runtime scraped ok");
#        } else {
#            INF("page rejected by runtime ["minfo["mi_runtime"]"] != ["runtime"]");
#        }
#    }

    return ret;
}

function check_director(runtime,minfo,\
ret) {
    ret = 1;

    # Runtime varies too much for some movies that get a lot of scenes cut like Leon
    DEBUG("check_director disabled");
#    if (runtime && minfo["mi_runtime"]) {
#
#        ret = (runtime == minfo["mi_runtime"]);
#
#        if (ret) {
#            DEBUG("runtime scraped ok");
#        } else {
#            INF("page rejected by runtime ["minfo["mi_runtime"]"] != ["runtime"]");
#        }
#    }

    return ret;
}

#
# This function moves src=url or href=url  outside of the tag.
# it is called before calling remove_tags so that the urls are 
# still available for further processing.
# This is requred because the urls often contain actor ids.
#
# It also checks <link rel=image_src href=some_image > as IMDB uses this for IE UA
#
function preserve_src_href(line,\
line2) {
    
    # Before removing tags we want to preserve (img)src= or href= 
    # as these are used by the get_names function, to process people.
    line2 = tolower(line);

    if(index(line2,"href=")) {

        # <a attr1 href=xxx attr2 >Label</a>
        # to
        # href=xxx <a attr1 attr2 >Label</a>
        #
        # three ways of extracting attributes "x" or 'x' or x
        line = gensub(/(<([Aa]|[Ll][Ii][Nn][Kk])[^>]* )[hH][rR][eE][fF]=("([^"]+)"|'([^']+)'|([^ >]+))([^>]*)/," href=\"\\4\\5\\6\" \\1\\7","g",line);
    }

    if(index(line2,"src=")) {
        # <img attr1 src=xxx attr2 />
        # to
        # src=xxx <img attr1 attr2 />
        line = gensub(/(<[iI][mM][gG][^>]* )[Ss][Rr][Cc]=("([^"]+)"|'([^']+)'|([^ >]+))([^>]*)/," src=\"\\3\\4\\5\" \\1\\6","g",line);
    }
    #if (line != line2) {
    #    if (index(line2,"name/nm")) {
    #        DEBUG("XX preserve_src_href ["line"]");
    #        DEBUG("XX preserve_src_href ["line2"]");
    #    }
    #}
    return line;
}

# Remove html tags  - and break into sections defined by tags td,tr,table,div,
# INPUT line - html text
# OUTPUT sections - array of logical segments with markup removed.
# Href labels surrounded with @label@ - this is so that actor names can be recognized by get_names


function reduce_markup(line,sections,pagestate,\
sep,ret,lcline,arr,styleOrScript) {

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

        #Flag link text.
        if (index(lcline,"<a") ) {
            line = gensub(/(<[Aa][^>]*>)([^<]+)(<\/[aA]>)/,"\\1@label@\\2@label@\\3","g",line);
        }

        #Set pagestate to ignore embedded stylesheets and scripts

        if (index(lcline,"script") || index(lcline,"style")) {
            if (index(lcline,"<script") || index(lcline,"<style") ||  index(lcline,"/script>") || index(lcline,"/style>")) {
                styleOrScript = split(lcline,arr,"<(script|style)")-split(lcline,arr,"</(script|style)>");
                pagestate["script"] +=  styleOrScript;
                #INF("pagestate[script]="pagestate["script"]":due to ["lcline"]");
            }
        }

        # Extract title from <title> tag - can be spread across multiple lines.

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
                pagestate["inbody"]=1;
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
# IN locale - eg en_US
# IN domain  - main domain of site eg imdb, allocine etc.
# IN line - a line of text 
# IN/OUT minfo - Movie info
# IN/OUT pagestate - info about which tag we are parsing
# IN/OUT namestate - info about which person we are parsing
# RETURN 0 if no issues, 1 if title or field mismatch.
function scrape_movie_line(locale,domain,line,minfo,pagestate,namestate,\
i,num,sections,err) {

    err = 0;
    sub(/^ */,"",line);

    pagestate["debug"] = index(line,"Avec");

    num = reduce_markup(line,sections,pagestate);
    if (num) {
        if (!pagestate["script"] ) {
            # INF("skip script or style");
        #} else if (pagestate["mode"] != "head" ) {

            if (pagestate["debug"]) {
                dump(0,"fragments",sections);
            }

            for(i = 1 ; i <= num ; i++ ) {
                if (sections[i]) {
                    err = scrape_movie_fragment(locale,domain,sections[i],minfo,pagestate,namestate);
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
# IN domain  - main domain of site eg imdb, allocine etc.
# IN locale - eg en_US
# IN domain  - main domain of site eg imdb, allocine etc.
# IN fragment - page text - cleaned of most markup by reduce_markup
# IN/OUT minfo - Movie info
# IN/OUT pagestate - info about which tag we are parsing
# IN/OUT namestate - info about which person we are parsing
# RETURN 0 if no issues, 1 if title or field mismatch.
function scrape_movie_fragment(locale,domain,fragment,minfo,pagestate,namestate,\
mode,rest_fragment,max_people,field,value,tmp,err,matches) {

    #DEBUG("scrape_movie_fragment:["pagestate["mode"]":"fragment"]");
    #DEBUG("scrape_movie_fragment:("locale","domain","fragment")");
    # Check if fragment is a fieldname eg Plot: Cast: etc.
    mode = get_movie_fieldname(locale,fragment,rest_fragment,pagestate);
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

                value=trim(value);

                # extract the year if present AND in brackets
                if (index(value,"(") || index(value,"[")) {
                    if (split(gensub("([[(].*)("g_year_re")(.*[])])","\t\\1\t\\2\t\\3\t",1,value),matches,"\t") == 5) {
                        minfo["mi_year"] = matches[3];
                        INF("Year="minfo["mi_year"]);
                        value=trim(matches[1]);
                    }
                    #dumpord(0,"findyear",matches);
                }
                if(value) {
                    minfo["title_source"] = domain;
                }

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
            value = subexp(fragment,"("g_year_re")");
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

    } else if ( mode == "released" ) {

        if (extractDate(fragment,matches)) {
            field="mi_year";
            value=matches[1];
        }

    } else if ( mode == "plot" && pagestate["mode"] != "head" ) {

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

    # category - special case for imdb only
    if (domain == "imdb" && index(fragment,"/episodes\"")) {
        minfo["mi_category"] = "T";
    }

    extract_rating(fragment,minfo,domain);

    # check for poster. Need to check hrefs too as imdb uses link image_src for IE user agent
    if (field == "" && minfo["mi_poster"] == "" && (index(fragment,"src=") || index(fragment,"href="))) {

        value = domain_edits(domain,fragment,"catalog_domain_poster_url_regex_list",0);
        if (value) {
            field = "mi_poster";
            DEBUG(field"?["value"]");
        }
    }

    err = 0;
    if (field && value ) {
        if (minfo[field]) {
            #DEBUG("scrape_movie_fragment:"field" ignoring ["value"]");
        } else {

            INF("scrape_movie_fragment:"field"=["value"]");

            if (field == "mi_title") {
                value=domain_edits(domain,value,"catalog_domain_clean_title_regex_list",0);
            }
            minfo[field]=value;
            minfo[field"_source"]=domain;

            if (field == "mi_poster" || field == "mi_title" || field == "mi_plot" ) {
                minfo[field"_source"] = domain;
            }
        }
    }
    return err;
}

function extract_rating(text,minfo,domain,\
ret) {
    if (minfo["mi_rating"] == "") {
        if (index(text,"/") ) {
            ret = subexp(text,"([0-9][,.][0-9]+) ?\\/? ?10");
        }
        if (ret == "" && index(text,"(")) {
            ret = subexp(text,"\\(([0-9][,.][0-9]+)\\)");
        }
        if (ret) {
            best_source(minfo,"mi_rating",ret,domain);
            INF("Rating set ["ret"]");
        }
    }
}

function is_prose(text,\
words,num,i,len) {
    len = length(text);

    #remove hyperlinked text
    if (index(text,"@label@")) {
        gsub(/@label@[^@]+/,"",text);
    }

    #remove Attributes eg alt="blah blah blah"
    if (index(text,"=\"") || index(text,"='")) {
        gsub(/=["'][^'"]+/,"",text);
    }

    if (len > g_min_plot_len ) {
        num = split(text,words," ")+0;
        #DEBUG("words = "num" required "(length(text)/10));
        if (num >= len/8 ) { #av word length less than 10 chars
            if (num <= len/5 ) { # av word length > 4 chars (minus space)
                if ( index(text,"Mozilla") == 0) {
                    for(i in words) if (length(words[i]) > 30) return 0;
                    return 1;
                }
            }
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
# IN locale eg en_US
# IN fragment
# RETURN keyword eg plot, cast, genre
# OUT rest[1] = remaining fragment if keyword present.
function get_movie_fieldname(locale,fragment,rest,pagestate,\
key,regex,ret,lcfragment,dbg,all_keys) {

    rest[1] = fragment;

    #dbg = index(fragment,"Billed Cast");

    # if there is a bit of prose without a keyword - assume it is the plot
    if (!("badplot" in pagestate) && pagestate["inbody"] && is_prose(fragment)) {

       ret = "plot";

    }  else {

        lcfragment = tolower(fragment);

        if (dbg) {
            dump(0,"pagestate-pre-release",pagestate);
        }
        # Get language regexs
        if (!pagestate["locale_regex"]) {
            INF("loading locale_regex");
            if (load_locale_settings(locale)) {
                pagestate["locale_regex"] = 1;
                for (key in g_settings) {
                    if (index(key,"locale:catalog_locale_keyword_") == 1) {
                        if (g_settings[key]) {
                            if (!(key in pagestate)) {
                                regex = keyword_list_to_regex(tolower(g_settings[key]));
                                pagestate[key] = "^ *"regex" *(: *|$)";
                                all_keys = all_keys "|" regex; 
                            }
                        }
                    }
                }
                pagestate["locale_all_keys"] = "^ *("substr(all_keys,2)") *(: *|$)";
            }
            dump(0,"pagestate-load",pagestate);
        }
        if (dbg) {
            dump(0,"pagestate-release",pagestate);
        }
        if (match(lcfragment,pagestate["locale_all_keys"])) {
            for (key in pagestate) {
                if (index(key,"locale:catalog_locale_keyword_") == 1) {
                    regex = pagestate[key];
                    if (pagestate["debug"] || dbg) {
                        DEBUG("checking fragment["fragment"] against ["key"]="regex);
                    }
                    if (match(lcfragment,regex)) {
                        rest[1] = substr(fragment,RSTART+RLENGTH);

                        ret = gensub(/locale:catalog_locale_keyword_/,"",1,key);
                        DEBUG("matching regex = ["regex"]");
                        break;
                    }
                }
            }
        }
    }
    if (ret) {
        DEBUG("matched "ret" rest = ["rest[1]"]");
    }
    return ret;
}

function get_locales(locales,\
i,has_english) {
    delete locales;
    for(i = 1; g_settings["catalog_locale"i] ~ /[a-z]+/ ; i++) {
        locales[i] = g_settings["catalog_locale"i];
        if (index(locales[i],"en") == 1)  has_english = 1;
    }
    if (!has_english) {
        locales[++i] = "en_US";
    }
    return i;
}

# get unique languages from locales
function get_langs(langs,\
i,locales,tmp,ret,lng,num) {
    delete langs;
    ret = 0;
    num = get_locales(locales);
    for( i = 1 ; i <= num ; i++ ) {
        lng = substr(locales[i],1,2);
        if (!(lng in tmp)) {
            tmp[lng] = 1;
            langs[++ret] = lng;
        }
    }
    return ret;
}
# get unique countries from locales
function get_countries(countries,\
i,locales,tmp,ret,c) {
    ret = get_locales(locales);
    for(i in locales ) { 
        if (match(locales[i],"_")) {
            c = substr(locales[i],RSTART+1);
            tmp[c] = 1;
        }
    }
    for ( i in tmp ) {
        countries[++ret] = i;
    }
    return ret;
}


# Note where we have already visisted. Usually domain:locale
function set_visited(minfo,key) {
    minfo["mi_visited"] = minfo["mi_visited"] " " key ;
}
function have_visited(minfo,key,\
ret) {
    ret = ( minfo["mi_visited"] ~ "\\<"key"\\>" );
    if (ret) {
        INF("already visited "key);
    }
    return ret;
}

# return ""=unknown "M"=movie "T"=tv??
function get_imdb_info(url,minfo,\
i,num,locales,minfo2) {

    if (!have_visited(minfo,"imdb")) {

        if (fetch_ijson_details(extractImdbId(url),minfo2)) {

            imdb_extra_info(minfo2,url);
            minfo_merge(minfo,minfo2,"imdb");

        } else {

            #dump(0,"ijson",minfo2);
            delete minfo2;

            num = get_locales(locales);
            for(i = 1 ; i <= num ; i++) {

                delete minfo2;
                if (scrape_movie_page("","","","","",extractImdbLink(url,"",locales[i]),locales[i],"imdb",minfo2) == 0) {
                    if (minfo2["mi_certrating"]) {
                        minfo2["mi_certcountry"] = substr(locales[i],4);
                    }
                    minfo_set_id("imdb",extractImdbId(url),minfo2);
                    #dump(0,"scrape",minfo2);
                    minfo_merge(minfo,minfo2,"imdb");
                    break;
                }
            }
        }
    }
    return minfo["mi_category"];
}

# Get extra imdb info
function imdb_extra_info(minfo,url,\
ret,remakes,connections) {
    minfo_set_id("imdb",extractImdbId(url),minfo);
    if (minfo["mi_category"] == "M") {

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
    ret = minfo["mi_category"];
    return ret;
}

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
# IN/OUT namesstate = this tracks the src= tags as it drops through the HTML
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
        num = split(text,csv,", +");
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
# IN/OUT namesstate = this tracks the src= tags as it drops through the HTML
# RETURN number of names parsed.
# GLOBAL updates minfo[mi_role_names/mi_role_ids] with cast names and external ids.
# GLOBAL updates g_portrait_queue with url to portrait picture.

# The input should have been cleaned using reduce_markup this will remove homst html markup
# but convert <a href="some_url" >text</a> to href="some_url"@label@some label@label@
function get_names_by_comma(domain,text,minfo,role,maxnames,pagestate,namestate,\
dtext,dnum,i,count,href_reg,src_reg,name_reg,check_img) {

    if (role ) {
        count = minfo["mi_"role"_total"];

        if(count < maxnames) {
            # Assumes a text does not have any markup inside. just a plain name
            # <a href=url ><img src=url /></a><a href=url ><img src=url /></a>
            # split by <a or a>

            if (index(text,"href=") || index(text,"src=") ) {

                href_reg = "href=\"[^\"]+";
                src_reg = "src=\"[^\"]+";
                name_reg = ">[^<]+";
                name_reg = "@label@[^@]+@label@";

                #DEBUG("XX1 text=["text"]");

                dnum = get_regex_pos(text,"("href_reg"|"src_reg"|"name_reg")",0,dtext);

                for(i = 1 ; i <= dnum && count < maxnames ; i++ ) {

                    check_img = 0; 

                    if (index(dtext[i],"src=") == 1) {

                        #DEBUG("XX1 got image ["dtext[i]"]");
                        dump(0,"xx namestate",namestate);

                    # Convert URL from thumbnail to big
                        namestate["src"] = person_get_img_url(domain,substr(dtext[i],6));
                        #DEBUG("XX1 got full size image ["namestate["src"]"]");
                        check_img = 1;

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
                        check_img = 3;
                    }

                    if  (check_img) {
                        # if an image has recently occured then link it to the current name.
                        # and then clear the namestate.
                        dump(0,"check_img",namestate);
                        if (namestate["id"] && namestate["src"]) {
                            # Store it for later download once we know the oversight id for this 
                            # person. After the people.db us updated.
                            g_portrait_queue[domain":"namestate["id"]] = namestate["src"];
                            INF("Image for ["namestate["id"]"] = ["namestate["src"]"]");
                            delete namestate["src"];
                        }
                    }
                }

            }
            if (count > minfo["mi_"role"_total"] ) {
                minfo["mi_"role"_total"] = count;
                INF("get_names:"role"="count);
            }
        }
    }
    return count;
}

# return number of minutes.
function extract_duration(text,\
num,n,p,ret) {
    num = get_regex_pos(text,"[0-9]+",0,n,p);

    if (num == 1 && n[1] > 3 ) {
        # If there is one number then it is minutes if > 3 else assume hours.
        ret = n[1]+0;
    } else {
        # First number is hours if there are two number OR if 1st number = 1,2,3
        ret = n[1]*60 + n[2];
    }
    return ret;
}
