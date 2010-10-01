
# load domain specific settings
function domain_load_settings(domain,\
domain_file) {
    if (!(domain in g_domain_loaded)) {

        domain_file = APPDIR"/conf/domain/catalog.domain."domain".cfg";

        load_settings(domain":",domain_file,1);
        g_domain_loaded[domain] = 1;
    }
}

# Apply sequence of regex substitutions and extractions to text.
# the regexs are loaded from the domain config file.
function domain_edits(domain,text,keyword,\
plist,ret) {

    ret = text;

    if(ret) {
        domain_load_settings("default");
        domain_load_settings(domain);


        plist=g_settings[domain":"keyword];
        if (plist == "") {
            plist=g_settings["default:"keyword];
        }
        if (plist) {
            ret=apply_edits(ret,plist);
        } else {
            ERR("domain keyword not found :"keyword);
        }
    }
    INF("domain_edits:["domain":"text"]=["ret"]");
    return ret;
}

