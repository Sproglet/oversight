
function load_catalog_settings() {

    load_settings("",DEFAULTS_FILE,1);
    load_settings("",CONF_FILE,1);

    load_settings(g_country_prefix , COUNTRY_FILE,0);

    gsub(/,/,"|",g_settings["catalog_format_tags"]);
    gsub(/,/,"|",g_settings["catalog_ignore_paths"]);
    gsub(/,/,"|",g_settings["catalog_ignore_names"]);

    g_settings["catalog_ignore_names"]="^"glob2re(g_settings["catalog_ignore_names"])"$";

    g_settings["catalog_ignore_paths"]="^"glob2re(g_settings["catalog_ignore_paths"]);

    INF("ignore path = ["g_settings["catalog_ignore_paths"]"]");

    # Check for empty ignore path
    if ( "x" ~ "^"g_settings["catalog_ignore_paths"]"x$" ) {
        g_settings["catalog_ignore_paths"] = "^$"; #regex will only match empty path
        INF("ignore path = ["g_settings["catalog_ignore_paths"]"]");
    }

    #catalog_scene_tags = csv2re(tolower(catalog_scene_tags));

    #Search engines used for simple keywords+"imdb" searches.
    split(tolower(g_settings["catalog_search_engines"]),g_link_search_engines,g_cvs_sep);
}

# Load configuration file
function load_settings(prefix,file_name,verbose,\
i,n,v,option) {

    INF("load "file_name);
    FS="\n";
    while((getline option < file_name ) > 0 ) {

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
    close(file_name);
}
