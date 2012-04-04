
function scrape_cache_clear() {
    #DEBUG("scrape_cache_clear");
    delete g_scrape_cache;
    g_scrape_cache_index_size=0;
}

function scrape_cache_gen_index(url) {
    if (url in g_scrape_cache) {
        ERR("duplicate cache entry");
        exit;
    }
    return ++g_scrape_cache_index_size SUBSEP "|";
}

function scrape_cache_add(url,minfo,\
i,id) {
    id = scrape_cache_gen_index(url);
    g_scrape_cache[url] = id;

    for ( i in minfo ) { 
        g_scrape_cache[id i] = minfo[i];
    }
    dump(0,"scrape_cache_add",minfo);
    INF("scrape_cache_added ["url","id"]");
}

function scrape_cache_get(url,minfo,\
i,ret,offset,fld,id) {
    ret = 0;

    if (url in g_scrape_cache) {
        id = g_scrape_cache[url];
        ret = 1;
        offset = length(id) + 1;
        for ( i in g_scrape_cache ) { 
            if ( index(i,id) == 1 && i != id ) {
                fld = substr(i,offset);
                minfo[fld] = g_scrape_cache[i];
            }
        }
    }
    #dump(0,"scrape_cache_get",minfo);
    INF("scrape_cache_get ["url","id"] = "ret);
    return ret;
}
