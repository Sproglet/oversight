function default_settings() {
    g_settings["catalog_scan_batch_size"]=30;
}

function load_catalog_settings(\
ign_path,env) {

    for(env in ENVIRON) {
        if (env ~ "^(catalog|unpak)_") {
            g_settings[env] = ENVIRON[env];
        }
    }
    dump(0,"settings",g_settings);

    ign_path = "catalog_ignore_paths";


    gsub(/,/,"|",g_settings["catalog_format_tags"]);
    gsub(/,/,"|",g_settings["catalog_ignore_names"]);
    gsub(/,/,"|",g_settings[ign_path]);

    g_settings["catalog_ignore_names"]="^"glob2re(g_settings["catalog_ignore_names"])"$";

    # Check for empty ignore path
    g_settings[ign_path]=trim(g_settings[ign_path]);
    if ( g_settings[ign_path] == "" ) {
        g_settings[ign_path] = ""; #regex will only match empty path
    } else {
        g_settings[ign_path]="^"glob2re(g_settings[ign_path]);
    }
    INF("ignore name = ["g_settings["catalog_ignore_names"]"]");
    INF("ignore path = ["g_settings[ign_path]"]");

    #catalog_scene_tags = csv2re(tolower(catalog_scene_tags));

    #Search engines used for simple keywords+"imdb" searches.
    split(tolower(g_settings["catalog_search_engines"]),g_link_search_engines,g_cvs_sep);
}

# Load configuration file
# Return 1=success 0 = failed
function load_settings(prefix,file_name,verbose,\
i,n,v,option,ret,err,cfg) {

    id1("load_settings "file_name);
    FS="\n";
    while((err = (getline option < file_name )) > 0 ) {

        #remove comment - hash without a preceeding blackslash
        if ((i=match(option,"[^\\\\]#")) > 0) {
            option = substr(option,1,i);
        }

        #remove spaces around =
        sub(/ *= */,"=",option);
        option=trim(option);
        # remove outer quotes
        sub("=[\"']","=",option);
        sub("[\"']$","",option);
        if (match(option,"^[[:alnum:]_]+=")) {
            n=prefix substr(option,1,RLENGTH-1);
            v=substr(option,RLENGTH+1);
            #gsub(/ *[,] */,",",v);

            g_settings_orig[n]=v;
            cfg[n] = g_settings[n] = v;
            if (verbose) {
                INF(n"=["g_settings[n]"]");
            }
        }
    }
    if (err >= 0 ) {
        close(file_name);
        ret = 1;
    } else {
        ret = 0;
    }
    dump(0,file_name,cfg);
    id0(ret);
    return ret;
}

# remove settings that match the regex
function remove_settings(regex,\
i) {
    for(i in g_settings) {
        if (i ~ regex) {
            delete g_settings[i];
        }
    }
}

function cookie_file(url,\
f) {
    f= plugin_file("domain",get_main_domain(url));
    return gensub(/cfg$/,"cki",1,f);
}

function plugin_file(type,name) {
    return OVS_HOME"/conf/"type"/catalog."type"."name".cfg";
}


# load plugin settings
# Return 1= success 0 = failed.
function load_plugin_settings(type,name,\
ret) {

    ret = 0;

    #DEBUG("type=["type"] last=["g_last_plugin[type]"] name=["name"]");

    if (g_last_plugin[type] != name) {
        INF("loading...");
        remove_settings("^"type ":");
        ret = load_settings(type":",plugin_file(type,name),1);
        g_last_plugin[type] = name;
    } else {
        ret = 1; # already loaded
    }
    return ret;
}

function load_state(f,arr,\
l,words) {
    while((getline l < f) > 0) {
        split(l,words,SUBSEP);
        arr[words[1]] = words[2];
    }
    close(f);
    arr[".loaded"] = 1;
    dump(0,"state",arr);
}
function save_state(arr,f,\
i) {
    for(i in arr) {
        print i SUBSEP arr[i] > f;
    }
    close(f);
}

function update_state(key,val) {
    if (!g_state[".loaded"]) {
        load_state(g_state_file,g_state);
    }
    g_state[key]=val;
    save_state(g_state,g_state_file);
}

