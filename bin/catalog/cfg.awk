
function load_catalog_settings(\
ign_path) {

    load_settings("",DEFAULTS_FILE,1);
    load_settings("",CONF_FILE,1);

    load_settings(g_country_prefix , COUNTRY_FILE,0);

    ign_path = "catalog_ignore_paths";


    gsub(/,/,"|",g_settings["catalog_format_tags"]);
    gsub(/,/,"|",g_settings["catalog_ignore_names"]);
    gsub(/,/,"|",g_settings[ign_path]);

    g_settings["catalog_ignore_names"]="^"glob2re(g_settings["catalog_ignore_names"])"$";

    g_settings[ign_path]="^"glob2re(g_settings[ign_path]);

    INF("ignore path = ["g_settings[ign_path]"]");

    # Check for empty ignore path
    if ( trim(g_settings[ign_path]) == "" ) {
        g_settings[ign_path] = "^$"; #regex will only match empty path
        INF("ignore path = ["g_settings[ign_path]"]");
    }

    #catalog_scene_tags = csv2re(tolower(catalog_scene_tags));

    #Search engines used for simple keywords+"imdb" searches.
    split(tolower(g_settings["catalog_search_engines"]),g_link_search_engines,g_cvs_sep);
}

# Load configuration file
# Return 1=success 0 = failed
function load_settings(prefix,file_name,verbose,\
i,n,v,option,ret,err) {

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
        if (match(option,"^[A-Za-z0-9_]+=")) {
            n=prefix substr(option,1,RLENGTH-1);
            v=substr(option,RLENGTH+1);
            #gsub(/ *[,] */,",",v);

            if (n in g_settings) {

                if (n ~ "movie_search") DEBUG("index check "n"="index(n,"catalog_movie_search")); #TODO remove

                if (index(n,"catalog_movie_search") || n == "catalog_format_tags" || n == "catalog_format_tags" ) {

                    INF("Ignoring user setings for "n);

                } else {
                    if (g_settings[n] != v ) {
                        INF("Overriding "n": "g_settings[n]" -> "v);
                    }
                    g_settings[n] = v;
                }
            } else {
                g_settings_orig[n]=v;
                g_settings[n] = v;
                if (verbose) {
                    INF(n"=["g_settings[n]"]");
                }
            }
        }
    }
    if (err >= 0 ) {
        close(file_name);
        ret = 1;
    } else {
        ret = 0;
    }
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


# load plugin settings
# Return 1= success 0 = failed.
function load_plugin_settings(type,name,\
plugin_file,ret) {

    ret = 0;
    plugin_file = APPDIR"/conf/"type"/catalog."type"."name".cfg";

    if (g_last_plugin[type] != name) {
        remove_settings("^"type ":");
        ret = load_settings(type":",plugin_file,1);
        g_last_plugin[type] = name;
    } else {
        ret = 1; # already loaded
    }
    return ret;
}

