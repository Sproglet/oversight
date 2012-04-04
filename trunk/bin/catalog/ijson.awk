BEGIN {
    g_has_ijson=1; # change to 1 to enable advanced mode
}

function fetch_ijson_by_locale(fn,args,locale,out,\
url,ret) {
    ret = 0;
    id1("fetch_ijson_by_locale "fn","args","locale);
    url = "http://a-pp.imdb.com/"fn"?api=v1&app-id=i-phone1&locale="locale"&"args;
    gsub(/-/,"",url);
    if (fetch_json(url,"imdb",out)) {
        out["@locale@"] = locale;
        #dump(0,locale,out);
        ret = 1;
    }
    id0(ret);
    return ret;
}

function fetch_ijson(fn,args,out,\
num,locales,i,ret) {

    ret = 0;
    id1("fetch_ijson "fn);

    num = get_locales(locales);
    for(i = 1 ; i<= num ; i++ ) {
        if (fetch_ijson_by_locale(fn,args,locales[i],out) ) {
            ret = 1;
            break;
        }
    }

    id0(ret);
    return ret;
}
	
function fetch_ijson_details(id,minfo,\
num,locales,i,ret) {

    ret = 0;

    if(id) {
        id1("fetch_ijson_details "id);

        num = get_locales(locales);
        for(i = 1 ; i<= num ; i++ ) {
            if (fetch_ijson_details_by_locale(id,locales[i],minfo) ) {
                ret = 1;
                break;
            }
        }

        id0(ret);
    }
    return ret;
}
function fetch_ijson_details_by_locale(id,locale,minfo,\
json,ret,i,tag,minfo2) {
    
    id1("fetch_ijson_details_by_locale "id","locale);
    if (id && g_has_ijson) { #TODO fix disable of ijson

        if (!scrape_cache_get("imdb:"id,minfo2)) {
            if (fetch_ijson_by_locale("title/main-details","t-const="id,locale,json)) {

                if ( "data:year" in json) {
                    ret = 1;
                    minfo2[PLOT] = add_lang_to_plot(locale,clean_plot(json["data:plot:outline"]));
                    minfo2[YEAR] = json["data:year"];
                    minfo2["mi_certrating"] = json["data:certificate:certificate"];
                    minfo2["mi_certcountry"] = substr(json["@locale@"],4);
                    minfo2[POSTER] = json["data:image:url"];
                    minfo2[RATING] = json["data:rating"];
                    minfo2[RUNTIME] = json["data:runtime:time"]/60;
                    minfo2[TITLE] = json["data:title"];

                    # other values are "feature" and "documentary" - for now treat all non-tv_series as feature and use genre to differentiate.
                    if (json["data:type"] == "tv_series" ) {
                        minfo2[CATEGORY] = "T";
                    } else if (json["data:type"] == "tv_episode" ) {
                        INF("This is episode data - go to series data");
                        id = json["data:series:tconst"]; 
                        return fetch_ijson_details_by_locale(id,locale,minfo);
                    } else {
                        minfo2[CATEGORY] = "M";
                    }

                    # Genres
                    for(i = 1 ; ; i++ ) {
                        tag = "data:genres#"i;
                        if (!(tag in json)) break;
                        minfo2[GENRE] = minfo2[GENRE] "|" json[tag];
                    }
                    sub(/^[|]/,"",minfo2[GENRE]);

                    set_ijson_people(json,"data:writers_summary",minfo2,"writer");
                    set_ijson_people(json,"data:directors_summary",minfo2,"director");
                    set_ijson_people(json,"data:cast_summary",minfo2,"actor");

    #                if (0) { #~~~~~~~~~~~~~~~~~~~~~~~~~~
    # var cast
    #                    #get cast
    #                    fetch_ijson("title/full-credits","t-const="id,cast);
    #                    for(i = 1 ; ; i++ ) {
    #                        tag = "data:credits#"i;
    #                        if (!(tag":token" in cast)) break;
    #                        if (cast[tag":token"] == "cast") {
    #                            set_ijson_people(cast,tag":list",minfo,"actor");
    #                            break;
    #                        }
    #                    }
    #                }
                    minfo_set_id("imdb",id,minfo2);
                }
            }
            scrape_cache_add("imdb:"id,minfo2);
        }
        minfo_merge(minfo,minfo2,"imdb");
    }
    ret= (minfo2[YEAR] != "");
    id0(ret);
    return ret;
}

function set_ijson_people(json,json_tag,minfo,role,\
i,tag,img,id,total,max,mi_total,mi_names,mi_ids) {
    max = g_settings["catalog_max_"role"s"];
    if (!max) max=3;

    mi_total = "mi_"role"_total";
    mi_names = "mi_"role"_names";
    mi_ids = "mi_"role"_ids";

    total=minfo[mi_total];

    for(i = 1 ;  ; i++ ) {
        tag = json_tag "#"i ":name";
        if (!(tag":name" in json)) break;

        if (total+0 >= max) break;

        id = json[tag":nconst"];
        sub(/^nm/,"",id);

        if (index(minfo[mi_ids]"@","@"id"@") == 0) {

            total++;
            if (total == 1) {
                minfo[mi_names] = "imdb";
                minfo[mi_ids] = "imdb";
            }
            minfo[mi_names] = minfo[mi_names]"@"json[tag":name"];
            minfo[mi_ids] = minfo[mi_ids]"@"id;

            if (role == "actor") {
                img = tag":image:url";
                if (img in json) {
                    g_portrait_queue["imdb:"id] = json[img];
                }
            }
        }
    }
    minfo[mi_total] = total;
}
