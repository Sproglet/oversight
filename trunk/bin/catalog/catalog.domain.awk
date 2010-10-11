
# Extract significant part of domain name. eg imdb from imdb.com and imdb.de
function get_main_domain(url,\
i) {

    sub(/^https?:\/\//,"",url);

    sub(/\/.*/,"",url); # remove url path

    sub(/\.(com|org|[a-z][a-z])$/,"",url); # remove TLD
    sub(/\.[a-z][a-z]$/,"",url); # remove co in co.uk etc
    sub(/.*\./,"",url); #remove front bit
    return url;
}


# Apply sequence of regex substitutions and extractions to text.
# the regexs are loaded from the domain config file.
function domain_edits(domain,text,keyword,verbose,\
plist,ret,key) {

    ret = text;

    if(ret) {
        load_plugin_settings("domain",domain);

        key = "domain:"keyword;
        plist=g_settings[key];
        if (plist) {
            ret=apply_edits(ret,plist,verbose);
        } else {
            ERR("keyword not found ["key"]");
        }
    }
    DEBUG("domain_edits:["domain":"text"]=["ret"]");
    return ret;
}

