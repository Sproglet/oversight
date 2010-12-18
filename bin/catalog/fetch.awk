
function getUrl(url,capture_label,cache,referer,\
    f,label,url_key,cache_suffix) {
    
    label="getUrl:"capture_label": ";

    #DEBUG(label url);

    if (url == "" ) {
        WARNING(label"Ignoring empty URL");
        return;
    }

    if (g_settings["catalog_imdb_source"] == "mobile" ) {
        if (url ~ ".imdb.com/title/tt[0-9]+/?$" ) {
            # use mobile website
            sub(/\/\/(www\.|)imdb\./,"//m.imdb.",url);
            cache_suffix="_mb";
        }
    }

    url_key = g_cache_prefix url;

    if(cache && (url_key in gUrlCache) ) {

        DEBUG(label" fetched ["url_key"] from cache");
        f = gUrlCache[url_key];
    }

    if (g_settings["catalog_cache_film_info"] == "yes") {
        if (url ~ ".imdb.com/title/tt[0-9]+/?$" ) {
            f = persistent_cache(extractImdbId(url),cache_suffix);
            cache=1;
        } else if (url ~ ".imdb.com/title/tt[0-9]+/movieconnections$" ) {
            f = persistent_cache(extractImdbId(url),cache_suffix "_mc");
            cache=1;
        }
    }

    if (f =="" ) {
        f=new_capture_file(capture_label);
    }
    if (is_file(f) == 0) {

        if (wget(url,f,referer) ==0) {
            if (cache) {
                gUrlCache[url_key]=f;
                #DEBUG(label" Fetched & Cached ["url"] to ["f"]");
            } else {
                #DEBUG(label" Fetched ["url"] into ["f"]"); 
            }
        } else {
            ERR(label" Failed getting ["url"] into ["f"]");
            f = "";
        }
    }
    return f;
}

function get_referer(url,\
i,referer) {
    # fake referer anyway
    i = index(substr(url,10),"/");
    if (i) {
        referer=substr(url,1,9+i);
    }
    return referer;
}

# Note nmt wget has a bug when using -O flag. Only one file is redirected.
function wget(url,file,referer,\
i,urls,tmpf,qf,r) {
    split(url,urls,"\t");
    tmpf = file ".tmp";
    qf = qa(tmpf);

    r=1;
    for(i in urls) {
        if (urls[i] != "") {
            if (wget2(urls[i],tmpf,referer) == 0) {

                # Long html lines were split to avoid memory issues with bbawk.
                # With gawk it may be possible to go back to using cat.

                #Insert line feeds - but try not to split text that has bold or span tags.

                #exec("cat "qf" >> "qa(file));
                exec(AWK " '{ gsub(/<([hH][1-5]|div|DIV|td|TD|tr|TR|p|P)[ >]/,\"\\n&\") ; print ; }' "qf" >> "qa(file));
                r=0;
            }
        }
        system("rm -f "qf);
    }
    return r;
}

#Get a url. Several urls can be passed if separated by tab character, if so they are put in the same file.
# Note nmt wget has a bug when using -O flag. Only one file is redirected.
function wget2(url,file,referer,\
args,unzip_cmd,cmd,htmlFile,downloadedFile,targetFile,result,default_referer,ua) {

    if (index(url,"/app.")) { 
        ua = g_iphone_user_agent;
    } else {
        ua = g_user_agent;
    }
    args=" -U \""ua"\" "g_wget_opts;
    default_referer = get_referer(url);
    if (check_domain_speed(default_referer) == 0) {
        return 1;
    }
    if (referer == "") {
        referer = default_referer;
    }

    if (referer != "") {
        args=args" --referer=\""referer"\" ";
    }

    targetFile=qa(file);
    htmlFile=targetFile;

    args=args" --header=\"Accept-Encoding: gzip\" "
    downloadedFile=qa(file".gz");
    #some devices have gzip not gunzip and vice versa
    unzip_cmd="( gunzip -c "downloadedFile" || gzip -c -d "downloadedFile" || cat "downloadedFile") > "htmlFile" 2>/dev/null && rm "downloadedFile;

    gsub(/ /,"+",url);

    # nmt wget has a bug that causes a segfault if the url basename already exists and has no extension.
    # To fix either make sure action url basename doesnt already exist (not easy with html redirects)
    # or delete the -O target file and use the -c option together.
    rm(downloadedFile,1);
    args = args " -c ";

    #d=g_tmp_dir"/wget."PID;

    url=qa(url);

#ALL#    if (url in g_url_blacklist) {
#ALL#
#ALL#        WARNING("Skipping url ["url"] due to previous error");
#ALL#        result = 1;
#ALL#
#ALL#    } else {

        cmd = "wget -O "downloadedFile" "args" "url;
        #cmd="( mkdir "d" ; cd "d" ; "cmd" ; rm -fr -- "d" ) ";
        # Get url if we havent got it before or it has zero size. --no-clobber switch doesnt work on NMT

        # Set this between 1 and 4 to throttle speed of requests to the same domain

        INF("WGET ["url"]");
        result = exec(cmd);
        if (result == 0 ) {
            result = exec(unzip_cmd);
        }
        if (result != 0) {
#ALL#            g_url_blacklist[url] = 1;
#ALL#            WARNING("Blacklisting url ["url"]");
            rm(downloadedFile,1);
        }
#ALL#    }
    return 0+ result;
}

#TODO We have to watch out for dns servers that return false hits on bad domains.
#for time being this should mainly be called to check a url on a known web server so DNS issues should not matter.
# 0=ok 1=error 2=timeout
function url_state(url,\
ret,start,tries,timeout) {
    tries=2;
    timeout=5;
    start=systime();
    ret = system("wget --spider --no-check-certificate -t "tries" -T "timeout" -q -O /dev/null "qa(url));

    #if wget ok - check timeout
    if (systime() - start >= tries * timeout ) { 
        WARNING("timeout with domain ["url"]");
        ret = 2;
    } else if (ret) { # some other error occured
        ret = 1;
    }
    return ret;
}

# Check a domain responds quickly. 1=ok
function check_domain_speed(url) {

    if (!(url in g_domain_status)) {
        # As long as domain resonds we only care about timeouts
        g_domain_status[url] = (url_state(url"/favicon.ico") != 2 );
    }
    return g_domain_status[url];
}

