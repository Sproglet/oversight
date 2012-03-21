# 1=found movie in required language
# 0=not found
function get_themoviedb_info(imdb_id,minfo) {
    #return get_themoviedb_info21(imdb_id,minfo);
    return get_themoviedb_info30(imdb_id,minfo);
}

# This function to be obsoleted soon
#
function get_themoviedb_info21(imdb_id,minfo,\
url,xml,i,num,langs,root,ret,xmlret,minfo2,ln,name,id) {

    id1("get_themoviedb_info "imdb_id);
    num = get_langs(langs);

    ret = 0 ;
    root="/OpenSearchDescription/movies/movie";

    for(i = 1 ; i<= num ; i++ ) {
        url="http://api.themoviedb.org/2.1/Movie.imdbLookup/"langs[i]"/xml/"g_api_tmdb"/"imdb_id;

        xmlret = fetchXML(url,"themoviedb",xml);
        ln = "";

        #dump(0,"themoviedb",xml);

        if (xmlret == 0) {

            INF("error parsing results");
            break;

        } else if (xml[root"/translated"] == "" ) {

            INF("page not on themoviedb");
            break;

        } else if (xml[root"/translated"] == "true") {

            ln = langs[i];

        } else if (xml[root"/translated"] == "false" && length(xml[root"/overview"]) > 20 && i<num && langs[i+1] == "en" ) {
            # next page was English - might as well use this one.
            INF("page not translated but using as English");
            ln = "en";
            i++;
        }

        if (ln) {

            #dumpxml("themoviedb",xml);
            
            name = html_to_utf8(xml[root"/name"]);

            if (sub(/^Duplicate: /,"",name)) {
                INF("Duplicate: "name);
                # Duplicate movie - go to original
                id = subexp(name,"([0-9]+).$");
                if (id) {
                    url="http://api.themoviedb.org/2.1/Movie.getInfo/"ln"/xml/"g_api_tmdb"/"id;
                    xmlret = fetchXML(url,"themoviedb",xml);
                    #dumpxml("themoviedb-orig",xml);
                    if (xmlret == 0) {
                        ln = "";
                    }
                }
            }
        }
        if (ln) {

            minfo2["mi_plot"]=add_lang_to_plot(langs[i],clean_plot(xml[root"/overview"]));

            minfo2["mi_certrating"]=xml[root"/certification"];

            minfo2["mi_runtime"]=xml[root"/runtime"];

            minfo2["mi_title"]=html_to_utf8(xml[root"/name"]);

            minfo2["mi_orig_title"]=html_to_utf8(xml[root"/original_name"]);

            minfo2["mi_url"]=xml[root"/url"];

            minfo2["mi_idlist"]="themoviedb:"xml[root"/id"];
            if ( root"/imdb_id" in xml) {
                minfo2["mi_idlist"] = minfo2["mi_idlist"]" imdb:"xml[root"/imdb_id"];
            }

            minfo2["mi_poster"]=get_moviedb_img(xml,root,"poster","mid");

            minfo2["mi_fanart"]=get_moviedb_img(xml,root,"backdrop","original");

            minfo_merge(minfo,minfo2,"themoviedb");
            ret = 1;
            break;

        } else {
            INF("page not translated");
        }
    }
    id0(ret);
    return ret;
}
# Works with imdb id or tmdb id
function get_themoviedb_info30(id,minfo,\
url,url2,json,json2,jsonret,i,num,langs,ret,minfo2,ln,name) {

    id1("get_themoviedb_info "id);
    num = get_langs(langs);

    ret = 0 ;

    for(i = 1 ; i<= num ; i++ ) {
        url=g_themoviedb_api_url"/movie/"id"?api_key="g_api_tmdb"&language="langs[i];
        url2=g_themoviedb_api_url"/movie/"id"/releases?api_key="g_api_tmdb"&language="langs[i];

        jsonret = fetch_json2(url"\t"url2,"json",json,json2);
        #dump(0,"themoviedb3",json);
        #dump(0,"themoviedb3-2",json2);
        if (jsonret == 0) {

            ERR("parsing results");
            break;

        } else if ("status_code" in json ) {

            ERR(" themoviedb : "json["status_message"]);
            break;

        } else if (json["overview"] != "null" && length(json["overview"]) > 1 ) {

            ln = langs[i];

        }

        if (ln) {

            dumpxml("themoviedb",json);
            
            name = html_to_utf8(json["name"]);

            if (sub(/^Duplicate: /,"",name)) {
                INF("Duplicate: "name);
                # Duplicate movie - go to original
                id = subexp(name,"([0-9]+).$");
                if (id) {
                    return get_themoviedb_info30(id,minfo);
                }
            }
        }
        if (ln) {

            minfo2["mi_plot"]=add_lang_to_plot(langs[i],clean_plot(json["overview"]));

            minfo2["mi_rating"]=json["vote_average"];

            #minfo2["mi_certrating"]=tmdb_get_release(json["id"]);
            minfo2["mi_certrating"]=tmdb_match_release(json2);

            minfo2["mi_runtime"]=json["runtime"];

            minfo2["mi_title"]=html_to_utf8(json["name"]);

            minfo2["mi_orig_title"]=html_to_utf8(json["original_name"]);

            minfo2["mi_url"]="http://www.themoviedb.org/movie/"json["id"];

            minfo2["mi_idlist"]="themoviedb:"json["id"];
            if ( "imdb_id" in json) {
                minfo2["mi_idlist"] = minfo2["mi_idlist"]" imdb:"json["imdb_id"];
            }

            minfo2["mi_poster"]=tmdb_config("poster_path")json["poster_path"];

            minfo2["mi_fanart"]=tmdb_config("backdrop_path")json["backdrop_path"];

            minfo_merge(minfo,minfo2,"themoviedb");
            ret = 1;
            break;

        } else {
            INF("page not translated");
        }
    }
    id0(ret);
    return ret;
}

# obsoleted 
function tmdb_get_release(id,\
ret,url,rel) {
    url=g_themoviedb_api_url"/movie/"id"/releases?api_key="g_api_tmdb;
    if (fetch_json(url,"json",rel) == 0) {

        ERR("parsing release results");
    } else if ("status_code" in rel ) {
        ERR(" themoviedb release info : "rel["status_message"]);
    } else {
        ret = tmdb_match_release(rel);
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

function get_moviedb_img(xml,root,type,size,\
filters,ret,tags,num,i,url) {
    filters["#type"] = type;
    filters["#size"] = size;

    num = find_elements(xml,root"/images/image",filters,0,tags);

    #themoviedb has a few poster fererences that do not exist - so spider each in turn
    for( i = 1 ; i <= num ; i++ ){

        url = xml[tags[i]"#url"];
        sub(/^\//,"http://hwcdn.themoviedb.org/",url);

        if (url_online(url,2,2)) {
            ret = url;
            break;
        }
    }
    return ret;
}
