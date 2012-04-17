
function scrape_cache_clear() {
    #DEBUG("scrape_cache_clear");
    delete g_scrape_cache_vals;
    delete g_scrape_cache_flds;
    g_scrape_cache_index_size=0;
}

# Id must include some text not normally in a string
function scrape_cache_gen_index(url) {
    if (url in g_scrape_cache_vals) {
        ERR("duplicate cache entry");
        exit;
    }
    return ++g_scrape_cache_index_size SUBSEP "|";
}

function scrape_cache_add(url,minfo,\
fld,id) {
    id = scrape_cache_gen_index(url);
    g_scrape_cache_vals[url] = id;

    for ( fld in minfo ) { 
        g_scrape_cache_flds[id,fld] = fld;
        g_scrape_cache_vals[id,fld] = minfo[fld];
    }
    #dump(0,"scrape_cache_add",minfo);
    DETAIL("scrape_cache_added ["url","id"]");
}

function scrape_cache_get(url,minfo,\
i,ret,fld,id) {
    ret = 0;

    if (url in g_scrape_cache_vals) {
        id = g_scrape_cache_vals[url];
        ret = 1;
        for ( i in g_scrape_cache_vals ) { 
            if ( index(i,id) == 1 && i != id ) {
                fld        = g_scrape_cache_flds[i];
                minfo[fld] = g_scrape_cache_vals[i];
            }
        }
    }
    #dump(0,"scrape_cache_get",minfo);
    DETAIL("scrape_cache_get ["url","id"] = "ret);
    return ret;
}
