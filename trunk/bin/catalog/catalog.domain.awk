
# load domain specific settings
function domain_load_settings(domain,\
domain_file) {
    if (!(domain in g_domain_loaded)) {

        domain_file = APPDIR"/conf/domain/catalog."domain".cfg";

        load_settings(domain":",domain_file);
        g_domain_loaded[domain] = 1;
    }
}

