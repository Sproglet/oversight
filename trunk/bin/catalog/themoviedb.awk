# 1=found movie in required language
# 0=not found
# Works with imdb id or tmdb id
function get_themoviedb_info(id,minfo,\
url,url2,json,json2,jsonret,i,num,langs,ret,minfo2,name,set,merge) {

    if (id) {
        id1("get_themoviedb_info "id);
        num = get_langs(langs);

        ret = 0 ;

        for(i = 1 ; i<= num ; i++ ) {
            url=g_themoviedb_api_url"/movie/"id"?api_key="g_api_tmdb"&language="langs[i];
            url2=g_themoviedb_api_url"/movie/"id"/releases?api_key="g_api_tmdb"&language="langs[i];

            jsonret = fetch_json(url,"json",json);
            #dump(0,"themoviedb3",json);
            #dump(0,"themoviedb3-2",json2);
            if (jsonret == 0) {

                ERR("parsing json results for ["url" | "url2"]");
                break;

            } else if ("status_code" in json ) {

                ERR(" themoviedb : "json["status_message"]);
                break;

            }
            hash_val_del(json,"null");

            minfo2[IDLIST]="themoviedb:"json["id"];
            if ( "imdb_id" in json) {
                if (json["imdb_id"] ~ /^tt[0-9]/) {
                    if (id ~ /^tt[0-9]/ && json["imdb_id"] != id ) {
                        ERR("tmdb : imdbid mismatch "id" != "json["imdb_id"]);
                        break;
                    }
                    minfo2[IDLIST] = minfo2[IDLIST]" imdb:"json["imdb_id"];
                }
            }

            merge = 1;

            name = html_to_utf8(json["name"]);

            if (sub(/^Duplicate: /,"",name)) {
                INF("Duplicate: "name);
                # Duplicate movie - go to original
                id = subexp(name,"([0-9]+).$");
                if (id) {
                    id0("duplicate movie "id);
                    return get_themoviedb_info(id,minfo);
                }
            }


            # Get TMDB posters if present - if plot is not translated then assume posters arent too?
            if (minfo2[POSTER]=="" && json["poster_path"] ) {
                minfo2[POSTER]=tmdb_config("poster_path")json["poster_path"];
            }

            if (minfo2[FANART]=="" && json["backdrop_path"] ) {
                minfo2[FANART]=tmdb_config("backdrop_path")json["backdrop_path"];
            }

            minfo2[RATING]=json["vote_average"];

            #minfo2["mi_certrating"]=tmdb_get_release(json["id"]);
            if (minfo2["mi_certrating"] == "") {
                fetch_json(url2,"json",json2);
                minfo2["mi_certrating"]=tmdb_match_release(json2);
            }

            minfo2[RUNTIME]=json["runtime"];


            minfo2[ORIG_TITLE]=html_to_utf8(json["original_title"]);


            set = json["belongs_to_collection:id"];
            if (set) {
                minfo2[SET] = sprintf("themoviedb:%06d",set);
                minfo2["mi_set_name"] = json["belongs_to_collection:name"];
            }
            if (json["overview"] != "" && length(json["overview"]) > 1 ) {

                minfo2[PLOT]=add_lang_to_plot(langs[i],clean_plot(json["overview"]));

                # Keep title and language the same
                minfo2[TITLE]=html_to_utf8(json["title"]);

                ret = 1;
                break;

            }
            INF("page not translated to "langs[i]);
        }
        if (merge) {
            minfo_merge(minfo,minfo2,"themoviedb");
        }
        id0(ret);
    }
    return ret;
}

function tmdb_match_release(json,\
countries,num,i,j,cert,country_key) {
    num = get_countries(countries);
    for( i = 1 ; i <= num ; i++ ) {
        INF("looking for release in "countries[i]);
        for(j = 1 ; (country_key = "countries#"j":iso_3166_1" )  in json ; j++ ) {
            if (json[country_key] == countries[i]) {
                cert = json["countries#"j":certification"];
                if (cert != "") {
                    INF("found cert = "cert);
                    return cert;
                }
            }
        }
    }
    return "";
}

function tmdb_config(key,\
url) {
    if (g_tmdb_config["@state"] != 1) {
        url=g_themoviedb_api_url"/configuration?api_key="g_api_tmdb;
        if (fetch_json(url,"json",g_tmdb_config) == 0) {
            ERR("Error getting TMDB configuration");
        } else {
            dump(0,"themoviedb3 config",g_tmdb_config);
            g_tmdb_config["poster_path"]=g_tmdb_config["images:base_url"]"/w500"; #g_tmdb_config["images:poster_sizes#5"];
            g_tmdb_config["backdrop_path"]=g_tmdb_config["images:base_url"]"/w1280"; #g_tmdb_config["images:backdrop_sizes#3"];
            g_tmdb_config["profile_path"]=g_tmdb_config["images:base_url"]"/h632"; #g_tmdb_config["images:profile_sizes#3"];
            g_tmdb_config["@state"]=1;
        }
    }
    return g_tmdb_config[key];
}
