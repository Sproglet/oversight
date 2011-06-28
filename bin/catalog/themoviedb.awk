# 1=found movie in required language
# 0=not found
function get_themoviedb_info(imdb_id,minfo,\
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
