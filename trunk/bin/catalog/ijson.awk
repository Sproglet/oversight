BEGIN {
    g_has_ijson=1; # change to 1 to enable advanced mode
}

function fetch_ijson(fn,args,out,\
url,num,langs,i,ret,locale) {

    ret = 0;
    id1("fetch_ijson "fn);

    num = get_langs(langs);
    for(i = 1 ; i<= num ; i++ ) {
        # locale needs fixing - should allow it in the configuration - or use /tmp/setting.txt
        if (langs[i]=="en") {
            locale="en_US" ;
        } else {
            locale=tolower(langs[i])"_"toupper(langs[i]);
        }
        url = "http://aZZpp.ZZimdb.com/"fn"?ZZapi=v1&ZZappid=ZZiphone1&locale="locale"&"args;
        gsub(/ZZ/,"",url);
        if (fetch_json(url,"imdb",out)) {
            ret = 1;
            break;
        }
    }

    id0(ret);
    return ret;
}
	
function fetch_ijson_plot(id,minfo,\
json,ret) {
    
    fetch_ijson("titleZZ/plot","tcZZonst="id,json);
    if ( "xxxx" in json) {
    }
    return ret;
}

function fetch_ijson_details(id,minfo,\
json,cast,ret,i,tag) {
    
    id1("fetch_ijson_details "id);
    ret = 0;
    if (1||g_has_ijson) {

        if (!scrape_cache_get("imdb:"id,minfo)) {
            if (fetch_ijson("titleZZ/maindZZetails","tcZZonst="id,json)) {

                if ( "data:year" in json) {
                    ret = 1;
                    minfo["mi_year"] = json["data:year"];
                    minfo["mi_cert"] = json["data:certificate:certificate"];
                    minfo["mi_poster"] = json["data:image:url"];
                    minfo["mi_rating"] = json["data:rating"];
                    minfo["mi_runtime"] = json["data:runtime:time"]/60;
                    minfo["mi_title"] = json["data:title"];
                    minfo["mi_plot"] = json["data:plot:outline"];

                    if (json["data:type"] == "tv_series" ) {
                        minfo["mi_category"] = "T";
                    } else if (json["data:type"] == "feature" ) {
                        minfo["mi_category"] = "M";
                    }

                    # Genres
                    for(i = 1 ; ; i++ ) {
                        tag = "data:genres#"i;
                        if (!(tag in json)) break;
                        minfo["mi_genre"] = minfo["mi_genre"] "|" json[tag];
                    }

                    set_ijson_people(json,"data:writers_summary",minfo,"writer");
                    set_ijson_people(json,"data:directors_summary",minfo,"director");
                    set_ijson_people(json,"data:cast_summary",minfo,"actor");

    #                if (0) { #~~~~~~~~~~~~~~~~~~~~~~~~~~
    #                    #get cast
    #                    fetch_ijson("titleZZ/fullcZZredits","tcZZonst="id,cast);
    #                    for(i = 1 ; ; i++ ) {
    #                        tag = "data:credits#"i;
    #                        if (!(tag":token" in cast)) break;
    #                        if (cast[tag":token"] == "cast") {
    #                            set_ijson_people(cast,tag":list",minfo,"actor");
    #                            break;
    #                        }
    #                    }
    #                }
                    minfo_set_id("imdb",id,minfo);
                    scrape_cache_add("imdb:"id,minfo);
                }
            }
        }
    }
    id0(ret);
    return ret;
}

function set_ijson_people(json,json_tag,minfo,role,\
i,tag,img,url,id,total,max) {
    max = g_settings["catalog_max_"role"s"];
    if (!max) max=3;

    total=minfo["mi_"role"_total"];

    for(i = 1 ;  ; i++ ) {
        tag = json_tag "#"i ":name";
        if (!(tag":name" in json)) break;

        if (total+0 >= max) break;

        id = json[tag":nconst"];
        sub(/^nm/,"",id);

        if (index(minfo["mi_"role"_ids"]"@","@"id"@") == 0) {

            total++;
            if (total == 1) {
                minfo["mi_"role"_names"] = "imdb";
                minfo["mi_"role"_ids"] = "imdb";
            }
            minfo["mi_"role"_names"] = minfo["mi_"role"_names"]"@"json[tag":name"];
            minfo["mi_"role"_ids"] = minfo["mi_"role"_ids"]"@"id;

            if (role == "actor") {
                img = tag":name:image:url";
                if (img in json) {
                    g_portrait_queue["imdb:"json[tag":nconst"]] = json[url];
                }
            }
        }
    }
    minfo["mi_"role"_total"] = total;
}
