#""=not found "M"=movie "T"=tv??
function movie_search(minfo,bestUrl,\
name,i,\
n,name_seen,name_list,name_id,name_try,\
search_regex_key,search_order_key,search_order,s,search_order_size,ret,title,\
year,scrape_imdb,text) {

    id1("movie search");
    ret=0;

    minfo["mi_tvid"]="";
    # search online info using film basename looking for imdb link
    # -----------------------------------------------------------------------------
    name_id=0;

    scrape_imdb = 1;


    name_list[++name_id] = remove_format_tags(remove_brackets(basename(minfo["mi_media"])));

    if (minfo["mi_parts"] != "") {
        name_list[++name_id]=remove_part_suffix(minfo);
    }

    name=cleanSuffix(minfo);


    # Build hash of name->order
    if (match(name,g_imdb_regex)) {
        name_list[++name_id] = substr(name,RSTART,RLENGTH);
    }
    if (match(name,g_imdb_title_re))  {
        name_list[++name_id] = substr(name,RSTART,RLENGTH);
    }

    name_list[++name_id] = name;



    dump(0,"name_tries",name_list);


    #Read search order definitions from config file.
    for(i = 1 ; i < 5 ; i++ ) {
        search_regex_key="catalog_movie_search_regex"i;

        #Find any search order that matches the file format
        if (name ~ g_settings[search_regex_key]) {

            search_order_key="catalog_movie_search_order"i;
            if (!(search_order_key in g_settings)) {
                ERR("Missing setting "search_order_key);
            } else {
                search_order_size = split(g_settings[search_order_key],search_order," *, *");
                break;
            }
        }
        delete search_order;
    }

    dumpord(0,"search order",search_order);

    for( s = 1 ; bestUrl=="" && s-search_order_size <= 0 ; s++ ) { # Must do them in strict sequence

        if (search_order[s] == "IMDBLINKS") {

            #TODO Merge the web_search_frequent_imdb_link heuristics into this functions logic.
            INF("DISABLED: Search Phase: "search_order[s]);
            #id1("Search Phase: "search_order[s]);
            #bestUrl=web_search_frequent_imdb_link(minfo);
            #id0(bestUrl);

        } else {

            for(n = 1 ; bestUrl=="" && n-name_id <= 0 ; n++) {

                name_try = name_list[n];

                if (!name_seen[name_try,s]  && name_try != "") {

                    name_seen[name_try,s]=1;

                    id1("Search Phase: "search_order[s]"["name_try"]");

                    if (search_order[s] == "ONLINE_NFO") {

                        #Add a dot on the end to stop binsearch false matching sub words.
                        #eg binsearch will find "a-bcd" given "a-b" to prevent this 
                        # change a-b to "a-b."
                        #bintube will ignore the dot.
                        bestUrl = searchOnlineNfoImdbLinks(name_try".");

                    } else if (search_order[s] == "IMDB") {

                        #This is a web search of imdb site returning the first match.

                        bestUrl=web_search_first_imdb_link(name_try"+"url_encode("site:imdb.com"),name_try);

                    } else if (search_order[s] == "IMDBFIRST") {

                        if (name_try ~ "^[a-zA-Z0-9]+-[a-zA-Z0-9]+$" ) {
                            # quote hyphenated file names
                            name_try = "\""name_try"\"";
                        } else {
                            # Remove punctuation runs
                            gsub("[^()"g_alnum8" ]+"," ",name_try);
                            name_try = trim(name_try);
                        }

                        title="";

                        bestUrl=web_search_first_imdb_link(name_try"+"url_encode("imdb"),name_try);

                    } else if (search_order[s] == "TITLEYEAR") {

                        # look for imdb style titles 
                        title = web_search_first_imdb_title(name_try,"");
                        if (title == "" ) {
                            title = web_search_first_imdb_title(name_try"+movie","");
                        }

                        if (title != "" && title != name_try) {


                            text = "";
                            if (match(title,g_year_re"$")) {
                                year = substr(title,RSTART,RLENGTH);
                                title = trim(substr(title,1,RSTART-1));
                            } else {
                                year = "";
                            }
                        } else {
                            text = name_try;
                            title = "";
                            year = "";
                        }

                        if (find_movie_page(text,title,year,"","",minfo) == 0) {
                            ret = 1;
                            bestUrl = minfo["mi_url"];
                            scrape_imdb = 0; # already scraped.
                            INF("Found at "bestUrl);
                        }

                    } else {

                        ERR("Unknown search method "search_order[s]);
                    }

                    id0(bestUrl);
                }
            }
        }
    }
    DEBUG("movie_search bestUrl=["bestUrl"]");

    # Finished Search. Scrape IMDB
    if (bestUrl && scrape_imdb) {

        get_themoviedb_info(extractImdbId(bestUrl),minfo);

        ret = get_imdb_info(bestUrl,minfo);

    } 
    id0(bestUrl);
    return ret;
}

