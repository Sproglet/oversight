# 1=found movie in required language
# 0=not found
function get_themoviedb_info(imdb_id,minfo,\
url,xml,i,num,langs,root,ret,xmlret,minfo2) {

    id1("get_themoviedb_info "imdb_id);
    num = get_langs(langs);

    ret = 0 ;
    root="/OpenSearchDescription/movies/movie";

    for(i = 1 ; i<= num ; i++ ) {
        url="http://api.themoviedb.org/2.1/Movie.imdbLookup/"langs[i]"/xml/"g_api_tmdb"/"imdb_id;

        xmlret = fetchXML(url,"themoviedb",xml);

        #dump(0,"themoviedb",xml);

        if (xmlret == 0) {

            INF("error parsing results");
            break;

        } else if (xml[root"/translated"] == "" ) {

            INF("page not on themoviedb");
            break;

        } else if (xml[root"/translated"] == "true") {

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
filters,ret,tags) {
    filters["#type"] = type;
    filters["#size"] = size;

    if (find_elements(xml,root"/images/image",filters,1,tags)) {
        ret = xml[tags[1]"#url"];
        if (index(ret,"/") == 1) ret = "http://hwcdn.themoviedb.org"ret;
    }
    return ret;
}
