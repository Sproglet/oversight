# Map set id to a set name (set id is usually imdb id of the earliest produced movie in the set)
BEGIN {
    g_set_prefix="SET"SUBSEP;
    g_set_state=0; #0=not loaded #1=loaded #2+ = changed
}

function set_save_names(\
i,f) {
    if (g_set_state > 1) {
        f = g_set_file"."PID;
        for(i in g_settings) {
            if (index(i,g_set_prefix) == 1) {
                print substr(i,length(g_set_prefix)+1)"=\"" g_settings[i] "\"" >> f;
            }
        }
        close(f);
        g_set_state=1;
        sort_file(f,"-u",g_set_file);
    }
}

# IN imdb_id
# IN titles
function set_name_from_titles(imdb_id,main_title,\
titles,num,name,key) {

    # Load the set config file
    if (!g_set_state) {
        load_settings(g_set_prefix,g_set_file,1);
        g_set_state=1;
    }
    INF("set file disabled");
    key = g_set_prefix "imdb:"imdb_id;

    # Check if user defined set name for ttid.
    if (key in g_settings) {
        name = g_settings[key];

    } else if ((num=set_all_titles(imdb_id,main_title,titles)) > 0) { # get all titles for set

        # search titles for common text
        name = common_text(num,titles,1,int(num/2)+1,3); 
        if(LD)DETAIL("set_name_from_titles=" name);
        if (name == "") {
            # search web for common text
            name = set_name_from_web(titles);
            if (name == "") {
                name = titles[1];
            }
        }
        if (name) {
            g_settings[key] = name;
            g_set_state++;
        }
    }

    INF("box set for "imdb_id" = "key"=["name"]");
    return name;
}



# IN imdb_id
# IN titles
function set_name_from_web(titles,\
response,num,sections,ret,url,query,i) {
    #if (url_get(g_search_bing_mobile url_encode("\""titles[1]"\" \""titles[2]"\" \""titles[3]"\" box set"),response,"",1)) 
    #   2Y body = tolower(response["body"]);
    #    num = get_bing_serp(body,sections);


    query = "+box +set \""titles[1]"\" \""titles[2]"\" \""titles[3]"\" -imdb";

    url=g_search_bing_api"Appid="g_api_bing;
    url = url "&sources=web";
    url = url "&query="url_encode(query);

    if (url_get(url,response,"",0)) {
        num = get_bing_json_serp(response["body"],sections);
        for(i in sections) {
            gsub(/(DVD|dvd|[Bb]lu-?[Rr]ay|Wikipedia).*/,"",sections[i]);
        }
        ret = common_text(num,sections,0,4,num);
        sub(/(box set|collection).*/,"",ret);
        sub(/ (2|3|ii)$/,"",ret);
    }           
    if (index(tolower(ret),tolower(titles[1]))) {
        ret = titles[1];
    }
    if(LD)DETAIL("set_name_from_web=" ret);
    return ret;
}


# Get all titles in an imdb set
# IN imdb_id
# OUT array of titles
function set_all_titles(imdb_id,main_title,all_titles,\
response,body,sections,num,tnum,i,j,titles,total,url) {

    all_titles[++total] = main_title;

    url = imdb_trvia_url(imdb_id);

    INF("getting "url);
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


# Find common text
# IN num - number of items
# IN t - text items
# IN start - if 1 then common text must start each item
# IN threshold - text must appear at least this many times.
# first_n - only use phrases from the first 'n' items. (could replace 'num')
function common_text(num,t,start,threshold,first_n,\
wrd,t2,best,phrase,phrases,i,j,skip,inc,cap) {

    DETAIL("common_text start="start" threshold="threshold" first_n="first_n);

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
        dump(0,"common_text",t2);
        wrd="[^ ]+ ";
        for(i = 1 ; i <= first_n ; i++ ) {
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

        dump(0,"phrases",phrases);

        # pick longest title with more than 50% occurence
        best="";
        for (i in phrases) {
            if (phrases[i] >= threshold+0) {
                if (length(i) > length(best)) best = i;
            }
        }
    }
    return clean_title(gensub(/[: ]+$/,"",1,best));
}
