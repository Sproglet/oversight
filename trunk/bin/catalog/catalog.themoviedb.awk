# 1=found movie in required language
# 0=not found
function get_themoviedb_info(imdb_id,minfo,\
url,empty_filter,xml,i,num,langs,root,ret,xmlret) {

    id1("get_themoviedb_info "imdb_id);
    num = get_langs(langs);

    ret = 0 ;
    root="/OpenSearchDescription/movies/movie";

    for(i = 1 ; i<= num ; i++ ) {
        url="http://api.themoviedb.org/2.1/Movie.imdbLookup/"langs[i]"/xml/"g_api_tmdb"/"imdb_id;

        xmlret = fetch_xml_single_child(url,"themoviedb",root,empty_filter,xml);

        dump(0,"themoviedb",xml);

        if (xmlret == 0) {

            INF("error parsing reslts");
            break;

        } else if (xml[root"/translated"] == "" ) {

            INF("page not on themoviedb");
            break;

        } else if (xml[root"/translated"] == "true") {

            best_source(minfo,"mi_plot",xml[root"/overview"]);
            minfo["mi_certrating"]=xml[root"/certification"];
            minfo["mi_runtime"]=xml[root"/runtime"];
            minfo["mi_title"]=xml[root"/name"];
            minfo["mi_orig_title"]=xml[root"/original_name"];
            minfo["mi_url"]=xml[root"/url"];
            ret = 1;
            break;
        }
    }
    id0(ret);
    return ret;
}
