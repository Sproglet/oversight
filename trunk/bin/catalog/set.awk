# Map set id to a set name (set id is usually imdb id of the earliest produced movie in the set)
BEGIN {
    g_set_file=SET_DB;
    g_set_prefix="SET:";
    g_set_state=0; #0=not loaded #1=loaded #2+ = changed
}

function set_save_all(\
i) {
    if (g_set_state > 1) {
        for(i in g_settings) {
            if (index(i,g_set_prefix) == 1) {
                print substr(i,length(g_set_prefix))"=\"" g_settings[i] "\"" > g_set_file;
            }
        }
        close(g_set_file);
    }
}

# IN imdb_id
# IN titles
function set_name_from_titles(imdb_id,main_title,\
titles,num,name,key) {

#    # Load the set config file
#    if (!g_set_state) {
#        load_settings(g_set_prefix,g_set_file,1);
#        g_set_state=1;
#    }
    INF("set file disabled");
    key = g_set_prefix imdb_id;

    # Check if user defined set name for ttid.
    if (key in g_settings) {
        name = g_settings[key];

    } else if ((num=set_all_titles(imdb_id,main_title,titles)) > 0) { # get all titles for set

        # search titles for common text
        name = common_text(num,titles,1); 
        ERR("set_name_from_titles=" name);
        if (name == "") {
            # search web for common text
            name = set_name_from_web(titles);
        } else {
            ERR("vs web name "set_name_from_web(titles));
        }
        if (name) {
            g_settings[key] = name;
        }
    }

    INF("box set for "imdb_id" = "name);
    return name;
}

function get_bing_serp(body,titles,\
i,pos,sections,total,num) {

    num = ovs_patsplit(body,sections,"href=\"/search[^<]+</a>");
    for(i = 1 ; i <= num ; i++) {
        if (index(sections[i],"redirurl") && index(sections[i],"rid=")) {
            titles[++total] = sections[i];
        }

    }
    for(i = 1 ; i <= total ; i++) {


        titles[i] = de_emphasise(titles[i]);

        sub(/<\/a>$/,"",titles[i]);

        pos=index(titles[i],">");
        if (pos > 0) {
            titles[i] = substr(titles[i],pos+1);
        }           
    }
    dump(2,"bing serps?",titles);
    return total;
}


# IN imdb_id
# IN titles
function set_name_from_web(titles,\
body,response,num,sections,ret) {
    if (url_get(g_search_bing_mobile url_encode("\""titles[1]"\" \""titles[2]"\" box set"),response,"",1)) {
        body = tolower(response["body"]);

        num = get_bing_serp(body,sections);
        ret = common_text(num,sections,0);
    }           
    ERR("set_name_from_web=" ret);
    return ret;
}


# Get all titles in an imdb set
# IN imdb_id
# OUT array of titles
function set_all_titles(imdb_id,main_title,all_titles,\
response,body,sections,num,tnum,i,j,titles,total,url) {

    all_titles[++total] = main_title;

    url = imdb_trvia_url(imdb_id);
    if (url_get(url,response,"",1)) {
        body = response["body"];

        #get named sections
        num=split(body,sections,"(<a name=\"|TOP_RHS)");

        for(i = 1 ; i<= num ; i++ ) {

            WARNING(substr(sections[i],1,30));

            #parse follows or followed_by
            if (index(sections[i],"follow") == 1) {

                #get titles
                tnum = ovs_patsplit(sections[i],titles,">[^<]+</a>");
                for(j = 1 ; j <= tnum ; j++ ) {
                    all_titles[++total] = substr(titles[j],2,length(titles[j])-5);
                }
            }
        }
        dump(1,"all titles",all_titles);
    }
    return total;
}


function common_text(num,t,start,\
wrd,t2,best,phrase,phrases,i,j,skip,inc,cap) {

    for(i in t) {
        t2[i]=tolower(t[i])" ";

        gsub(/:/," ",t2[i]);
        gsub(/  +/," ",t2[i]);

        #If something looks like a sequel use that
        if (t2[i] ~ / (2|ii) $/) {
            best = gensub(/ (2|ii) $/,"",1,t2[i]);
            break;
        }
        # Fix for LOTR: The blah blah => "LOTR The"
        sub(/: the .*/," ",t2[i]);
    }
    if (!best) {
        wrd="[^ ]+ ";
        for(i = 1 ; i <= num ; i++ ) {
            #print "process "t2[i];
            inc=1;
            for( skip = 0 ; match(t2[i],"^("wrd"){"skip"}"wrd) ; skip ++ ) {
                for(inc = 1; match(t2[i],"^("wrd"){"skip"}(("wrd"){"inc"})",cap) ; inc ++ ) {

                    phrase = cap[2];
                    if (!(phrase in phrases) && phrase != "the") {
                        phrases[phrase]++;
                        # count occurences in other titles.
                        for(j = i + 1 ; j <= num ; j++ ) {
                            if (index(t2[j],phrase)) phrases[phrase]++;
                        }
                    }
                }
                if (start)break; # the phrase must be at the start of the string skip=0
            }
        }

        # pick longest title with more than 50% occurence
        best="";
        for (i in phrases) {
            if (phrases[i] >= 2) {
                if (length(i) > length(best)) best = i;
            }
        }
    }
    return clean_title(gensub(/[: ]+$/,"",1,best));
}
