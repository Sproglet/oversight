# 1=found movie in required language
# 0=not found
function get_themoviedb_info(imdb_id,minfo,\
url,empty_filter,xml,i,num,langs,root,ret,xmlret,source) {

    source = "themoviedb";
    id1("get_themoviedb_info "imdb_id);
    num = get_langs(langs);

    ret = 0 ;
    root="/OpenSearchDescription/movies/movie";

    for(i = 1 ; i<= num ; i++ ) {
        url="http://api.themoviedb.org/2.1/Movie.imdbLookup/"langs[i]"/xml/"g_api_tmdb"/"imdb_id;

        xmlret = fetch_xml_single_child(url,"themoviedb",root,empty_filter,xml);

        #dump(0,"themoviedb",xml);

        if (xmlret == 0) {

            INF("error parsing reslts");
            break;

        } else if (xml[root"/translated"] == "" ) {

            INF("page not on themoviedb");
            break;

        } else if (xml[root"/translated"] == "true") {

            best_source(minfo,"mi_plot",xml[root"/overview"],source);

            minfo["mi_certrating"]=xml[root"/certification"];

            best_source(minfo,"mi_runtime",xml[root"/runtime"],source);

            adjustTitle(minfo,xml[root"/name"],source);

            best_source(minfo,"mi_orig_title",clean_title(xml[root"/original_name"]),source);

            best_source(minfo,"mi_url",xml[root"/url"],source);

            DEBUG("XXX pre get_moviedb_img root=["root"]");
            best_source(minfo,"mi_poster",get_moviedb_img(xml,root,"poster","mid"),source);

            best_source(minfo,"mi_fanart",get_moviedb_img(xml,root,"backdrop","original"),source);
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

    DEBUG("XX get_moviedb_img["root"]");
    if (find_elements(xml,root"/images/image",filters,1,tags)) {
        ret = xml[tags[1]"#url"];
    }
    return ret;
}
