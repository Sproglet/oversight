
function scrape_cache_clear() {
    #DEBUG("scrape_cache_clear");
    delete g_scrape_cache;
}

function scrape_cache_add(url,minfo,\
i) {
    for ( i in minfo ) { 
        g_scrape_cache[url SUBSEP i] = minfo[i];
        #DEBUG("scrape_cache_add ["url SUBSEP i"] = ["minfo[i]"]");
    }
    g_scrape_cache[url] = 1;
    INF("scrape_cache_added ["url"]");
}
function scrape_cache_present(url) {
    return (url in g_scrape_cache);
}

function scrape_cache_get(url,minfo,\
i,ret,offset) {
    ret = 0;
    if (url in g_scrape_cache) {
        ret = 1;
        url = url SUBSEP;
        offset = length(url) + 1;
        for ( i in g_scrape_cache ) { 
            if ( index(i,url) == 1 && i != url ) {
                minfo[substr(i,offset)] = g_scrape_cache[i];
                DEBUG("scrape_cache_get ["url substr(i,offset) "] = [" minfo[substr(i,offset)]"]");
            }
        }
    }
    #dump(0,"scrape_cache_get",minfo);
    INF("scrape_cache_get ["url"] = "ret);
    return ret;
}

