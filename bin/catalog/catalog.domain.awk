
# Extract significant part of domain name. eg imdb from imdb.com and imdb.de
function get_main_domain(url) {

    sub(/^https?:\/\//,"",url);

    sub(/\/.*/,"",url); # remove url path

    sub(/^www\./,"",url); 

    # Special case for big international sites with local presense. Any more of these and it should be handled by using 
    # include files for the domain properties. eg imdb.fr includes imdb.com
    if (index(url,"imdb")==1) url="imdb";
    if (index(url,"amazon")==1) url="amazon";

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
            INF("keyword ["key"] not present for domain ["domain"]");
        }
    }
    DEBUG("domain_edits:["domain":"text"]=["ret"]");
    return ret;
}

