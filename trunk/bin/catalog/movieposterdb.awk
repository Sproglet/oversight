function mpdb_get_poster(id,title,force_country,\
countries,country_count,i,count,url,matches,ret) {

    id1("mpdb_get_poster id="id);

    g_fetch["force_awk"] = 1;
    g_fetch["no_encode"] = 1;

    if (id) {

        g_mpdb = "http://www.movieposterdb.com";

        # determine country
        if (force_country) {
            country_count = 1;
            countries[country_count] = force_country;
        } else {
            country_count = get_countries(countries);
        }
        dump(0,"countries",countries);

        # Get main page

        url= g_mpdb"/movie/"gensub(/^tt/,"",1,id)"/"title".html";

        g_fetch_filter = " sed '1,/<body>/ d;/id=.footer/,$ d' ";
        count=scan_page_for_match_order(url,"","/poster/[0-9a-f]+",0,0,"",groups,0,"raw.img");
        g_fetch_filter = "";

        for(i = 1 ; i <= count ; i++ ) {

            if (mpdb_parse_group(groups[i],countries,matches)) {
                break;
            }
        }

        dump(0,"matches",matches);
        for(i = 1 ; i<= country_count ; i++ ) {
            if (( ret = matches[countries[i]]) != "") {
                break;
            }
        }
    }
    g_fetch["force_awk"] = 0;
    g_fetch["no_encode"] = 0;

    id0(ret);
    return ret;
}

function mpdb_parse_group(group,countries,matches,\
i,url,count,posters_and_flags,current_poster,ret,cap,flag,country_hash) {

    url=g_mpdb group;

    if(LD)DETAIL("mpdb_parse_group "url);

    hash_invert(countries,country_hash);

    g_fetch_filter = " sed '1,/<body>/ d;/id=.footer/,$ d' ";
    count=scan_page_for_match_order(url,"","(/posters/[^\"'[:space:]]+jpg|/images/flags/[[:alpha:]]+.png)",0,0,"",posters_and_flags,0,"raw.img");
    g_fetch_filter = "";

    for(i = 1 ; i <= count ; i++ ) {
        if (posters_and_flags[i] ~ /posters/ ) {

            current_poster = posters_and_flags[i];

            #if(LD)DETAIL(" poster= " g_mpdb current_poster);

        } else if (match(posters_and_flags[i],"/flags/([[:alpha:]]+)",cap) ) {

            flag = cap[1];
            if (flag == "UK") {
               if ("GB" in country_hash) flag = "GB";
               else if ("IE" in country_hash) flag = "IE"; # Is this OK?
            }

            #if(LG)DEBUG("flag="flag);

            if (flag in country_hash) {
                if (current_poster) {
                    if (!matches[flag]) {
                        matches[flag] = g_mpdb gensub(/\/[a-z]_/,"/l_",1,current_poster);
                        if(LD)DETAIL("Stored "flag" = "matches[flag]);
                    
                        # check if users main country
                        if (country_hash[flag] == 1) {
                            if(LD)DETAIL("Found Primary country");
                            break;
                        }
                    }
                }
            }
            
        } else {
            ERR("skipping "posters_and_flags[i]);
        }
    }

    ret = (matches[countries[1]] != "");
    return ret;
}
