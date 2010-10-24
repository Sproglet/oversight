
#imdb files dont change much - apart from rating. 
#to get new ratings then delete cache
#if file cant be created return blank
function persistent_cache(fname,suffix,\
dir) {
    dir=APPDIR"/cache";
    if (g_cache_ok == 0) { #first time check
        g_cache_ok=2; #bad
        system("mkdir -p "qa(dir));
        if (set_permissions(qa(dir)"/.") == 0) {
            g_cache_ok=1; #good
        }
    }
    
    if (g_cache_ok == 1) { # good
        INF("Using persistent cache");
        return dir "/" fname suffix ;
    } else if (g_cache_ok == 2) { # bad
        return "";
    }
}
    
function set_cache_prefix(p) { 
    g_cache_prefix=p;
}
function clear_cache_prefix(p,\
u) { 
    for(u in gUrlCache) {
        if (index(u,p) == 1) {
            DEBUG("Deleting cache entry "u);
            delete gUrlCache[u];
        }
    }
    g_cache_prefix="";
}


