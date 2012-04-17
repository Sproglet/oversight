#""=not found "M"=movie "T"=tv??
function movie_search(minfo,\
bestUrl,\
name,\
n,name_list,name_id,name_try,\
search_order,s,search_order_size,title,\
year) {

    id1("movie search");

    name_id = build_query_list(minfo,name_list);

    if(LG)DEBUG("name_tries"join(name_list," / "));

    search_order_size = get_search_order(name,search_order);

    if(LG)DEBUG("search order "join(search_order," / "));


    # At this point there are two lists.
    # 1. A list of search texts in name_list[]
    # 2. A list of search methods in search_order[]
    #
    # Loop though each search method..
    #    Some methods will then loop throough each name time

    for( s = 1 ; bestUrl=="" && s-search_order_size <= 0 ; s++ ) { # Must do them in strict sequence

        if (search_order[s] == "IMDBLINKS") {

            #TODO Merge the web_search_frequent_imdb_link heuristics into this functions logic.
            if(LD)DETAIL("DISABLED: Search Phase: "search_order[s]);
            #id1("Search Phase: "search_order[s]);
            #bestUrl=web_search_frequent_imdb_link(minfo);
            #id0(bestUrl);

        } else {

            for(n = 1 ; bestUrl=="" && n-name_id <= 0 ; n++) {

                name_try = name_list[n];

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

                    if (name_try ~ "^[[:alnum:]]+-[[:alnum:]]+$" ) {
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

                        # We have found a title by looking at SERPS for 'title (year)'

                        if (match(title,g_year_re"$")) {
                            year = substr(title,RSTART,RLENGTH);
                            title = trim(substr(title,1,RSTART-1));
                        } else {
                            year = "";
                        }

                        # First look for imdb id associated with this name.
                        bestUrl=web_search_first_imdb_link(url_encode("+\""title"\" "year" imdb"),name_try);

                        if (!bestUrl) {
                            # Still not found - try searching local sites sirectly.

                            if (find_movie_page(title,year,"","",minfo,"") == 0) {
                                bestUrl = minfo["mi_url"];
                            }
                        }
                    }

                } else if (search_order[s] == "WEB") {

                    # look for anything with title=name_try
                    if (find_movie_page(name_try,"","","",minfo,"") == 0) {
                        bestUrl = minfo["mi_url"];
                    }

                } else {

                    ERR("Unknown search method "search_order[s]);
                }

                id0(bestUrl);
            }
        }
    }
    if(LI)INF("movie_search "minfo[TITLE]" ["bestUrl"]");

    id0(bestUrl);
    return bestUrl;
}

# Build list of diffent queries based on the file name
function build_query_list(minfo,name_list,\
 name_id,name,dups) {

    dups[""]=1; 
    name_id=0;

    name =remove_format_tags(remove_brackets(basename(minfo[NAME])));
    name_id = add_unique(name,name_id,name_list,dups);

    if (minfo[PARTS] != "") {
        name = remove_part_suffix(minfo);
        name_id = add_unique(name,name_id,name_list,dups);
    }

    name=cleanSuffix(minfo);

    # Build hash of name->order
    # need imdbregex without word boundary for _tt1234
    if (match(name,"tt[0-9]{5,9}")) {
        name_id = add_unique(substr(name,RSTART,RLENGTH),name_id,name_list,dups);
    }
    if (match(name,g_imdb_title_re))  {
        name_id = add_unique(substr(name,RSTART,RLENGTH),name_id,name_list,dups);
    }

    name_id = add_unique(name,name_id,name_list,dups);

    return name_id;
}
function add_unique(value,count,list,dups) {
    value = tolower(value);
    if (!(value in dups)) {
        list[++count] = value;
        dups[value] = 1;
    }
    return count;
}

function get_search_order(name,search_order,\
order) {
    # Search methods - all started by searching on parts of filename:
    # IMDBFIRST - look at first imdb id returned in SERPS, if id does not occur 3 times then look at other engines.
    # TITLEYEAR - look at SERPS for frequent occurrences of "xxxx (year)" then search on that ..
    # ONLINE_NFO - search nzb indexers
    # WEB - search for "file details +site:xxx.com" where site is listed in ./conf/locale/catalog.locale.<LANG>.cfg
    # http://code.google.com/p/oversight/wiki/SearchMethods

    #scene names - online_nfo is often best?
    if (name ~ "^[[:alnum:]]+[-.][-.[:alnum:]]+\\.[[:alnum:]]{2,3}$") {

        order = "IMDBFIRST,ONLINE_NFO,TITLEYEAR,WEB";

    } else if (name ~ ".{30,}" ) {

        #Long title
        order="IMDBFIRST,TITLEYEAR,WEB,ONLINE_NFO";

    } else if (name ~ " .(20|19)[0-9][0-9]" ) {

        #something with the year in it.
        order = "IMDBFIRST,TITLEYEAR,ONLINE_NFO,WEB";

    } else {
        order="IMDBFIRST,TITLEYEAR,ONLINE_NFO,WEB"
    }

    return split(order,search_order,",");
}

