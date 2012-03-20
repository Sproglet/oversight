
function scrape_cache_clear() {
    #DEBUG("scrape_cache_clear");
    delete g_scrape_cache;
    delete g_scrape_cache_index;
    g_scrape_cache_index_size=0;
}

function scrape_cache_index(url) {
    if (!g_scrape_cache_index[url] ) {
        g_scrape_cache_index[url] = ++g_scrape_cache_index_size SUBSEP "|";
    }
    return g_scrape_cache_index[url];
}

function scrape_cache_add(url,minfo,\
i) {
    url = scrape_cache_index(url);
    for ( i in minfo ) { 
        g_scrape_cache[url i] = minfo[i];
        #DEBUG("scrape_cache_add ["url SUBSEP i"] = ["minfo[i]"]");
    }
    g_scrape_cache[url] = 1;
    INF("scrape_cache_added ["url"]");
}

function scrape_cache_get(url,minfo,\
i,ret,offset,fld) {
    ret = 0;
    if (url in g_scrape_cache_index) {
        url = scrape_cache_index(url);
        ret = 1;
        offset = length(url) + 1;
        for ( i in g_scrape_cache ) { 
            if ( index(i,url) == 1 && i != url ) {
                fld = substr(i,offset);
                minfo[fld] = g_scrape_cache[i];
                DEBUG("scrape_cache_get ["url fld "] = [" minfo[fld]"]");
            }
        }
    }
    #dump(0,"scrape_cache_get",minfo);
    INF("scrape_cache_get ["url"] = "ret);
    return ret;
}

