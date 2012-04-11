
function getUrl(url,capture_label,cache,referer,quiet_fail,\
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
        if (index(url,".imdb.")) {
            if (url ~ ".imdb.com/title/tt[0-9]+/?$" ) {
                f = persistent_cache(extractImdbId(url),cache_suffix);
                cache=1;
            } else if (index(url,"tab=mc" )) {
                f = persistent_cache(extractImdbId(url),cache_suffix "_mc");
                cache=1;
            }
        }
    }

    if (f =="" ) {
        f=new_capture_file(capture_label);
    }
    if (is_file(f) == 0) {

        if (wget(url,f,referer,quiet_fail) ==0) {
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
    referer = url;
    i = index(substr(url,10),"/");
    if (i) {
        referer=substr(url,1,9+i);
    }
    return referer;
}

# Note nmt wget has a bug when using -O flag. Must use proper wget.

#Get a url. Several urls can be passed if separated by tab character, if so they are put in the same file.
# Note nmt wget has a bug when using -O flag. Only one file is redirected.
function wget(url,file,referer,quiet_fail,\
args,html_filter,unzip_cmd,cmd,htmlFile,downloadedFile,targetFile,result,default_referer,ua,old_cf,new_cf,arg_cf,filter_count) {

    filter_count = 0;
    if (index(url,"/app.")) { 
        ua = g_iphone_user_agent;
    } else if (index(url,g_search_yahoo)) { 
        #Yahoo returns weird bloated results with most end-user browsers.
        ua = g_yahoo_user_agent;
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
    if (index(url,g_themoviedb_api_url)) {
        args=args" --header=\"Accept: application/json\" ";
    }

    # Some domains need cookie tracking to bypass advertising.
    old_cf = cookie_file(url);
    new_cf = old_cf".new";

    if (is_file(old_cf)) {
        if (!is_file(new_cf)){
            INF("setting default cookies");
            file_copy(old_cf,new_cf);
        }
    }
    arg_cf=" --keep-session-cookies --load-cookies="qa(new_cf)" --save-cookies="qa(new_cf)" --keep-session-cookies";
    args=args arg_cf;
    #INF(arg_cf);

    targetFile=qa(file);
    htmlFile=targetFile;

    # wget doesnt combine multiple files and compression
    if (index(url,"\t")) {
        downloadedFile=qa(file".dl");
        unzip_cmd=" cat "downloadedFile" "; 
    } else {
        args=args" --header=\"Accept-Encoding: gzip, deflate\" "
        downloadedFile=qa(file".gz");
        unzip_cmd="( gunzip -c "downloadedFile" || cat "downloadedFile") "; 
        filter_count ++;
    }

    if (g_fetch_filter) {
        html_filter = html_filter" | "g_fetch_filter;
        filter_count ++;
    }

    if (index(file,".html")) {
        # Long html lines were split to avoid memory issues with bbawk.
        # With gawk it may be possible to go back to using cat.

        #Insert line feeds - but try not to split text that has bold or span tags.
        html_filter = html_filter" | "AWK" '{ gsub(/<([hH][1-5]|div|DIV|td|TD|tr|TR|p|P|LI|li|script|SCRIPT|style|STYLE)[ >]/,\"\\n&\") ; print ; }' ";
        filter_count ++;
    }

    if (filter_count) {
        unzip_cmd=unzip_cmd" "html_filter" > "htmlFile" 2>/dev/null && rm "downloadedFile;
    } else {
        unzip_cmd="mv "downloadedFile" "htmlFile;
    }

    gsub(/;/,"\\&",url); # m.bing.com doesnt like ;
    gsub(/ /,"+",url);

    # nmt wget has a bug that causes a segfault if the url basename already exists and has no extension.
    # To fix either make sure action url basename doesnt already exist (not easy with html redirects)
    # or delete the -O target file and use the -c option together.

    rm(downloadedFile,1);

    #d=g_tmp_dir"/wget."PID;

    url=qa(url);

    #For tab separated urls - pass as separate args.
    gsub(/\t/,"' '",url);

    cmd = "wget -O "downloadedFile" "args" "url;
    #cmd="( mkdir "d" ; cd "d" ; "cmd" ; rm -fr -- "d" ) ";
    # Get url if we havent got it before or it has zero size. --no-clobber switch doesnt work on NMT

    # Set this between 1 and 4 to throttle speed of requests to the same domain

    INF("WGET ["url"]");
    result = exec(cmd,0,quiet_fail);
    if (result == 0 ) {
        #INF("WGET ["unzip_cmd"]");
        result = exec(unzip_cmd,0,quiet_fail);
    }
    if (result != 0) {
        rm(downloadedFile,1);
    }
    return 0+ result;
}

# url_online 1=OK 0=failed
function url_online(url,tries,timeout,quiet_fail,\
cmd,ret) {
    # slight bug with wget 1.12 return code 4 when OK so grep output for 'Remote file exists'
    cmd ="wget --spider --no-check-certificate -t "tries" -T "timeout" --referer="get_referer(url)" -S -O - "qa(url)" 2>&1 | grep -q '200 OK'";
    
    ret = exec(cmd,0,quiet_fail);
    return ret;
}

# Filter a bunch of urls at the same domain
function spiders(url_list,tries,timeout,\
list2,f,n,i,batch,cmd,total,inv,u,txt,s,code) {
    batch = 20;
    n = hash_size(url_list);
    hash_invert(url_list,inv);
    s = 1;
    f = new_capture_file("wget");

    cmd="";
    id1("spidering "n" urls");
    for (i in url_list) {
        s++;
        cmd=cmd"\t"qa(url_list[i]);
        if (s%batch == 0 || s == n) {
            exec("wget --spider --no-check-certificate -t "tries" -T "timeout" -O - "cmd" >"qa(f)" 2>&1 || true ");
            while ((code = (getline txt < f )) > 0 ) {
                #INF("spider ["txt"]");
                if (match(txt,"--  http://")) {
                    u = substr(txt,RSTART+4);
                    #INF("url="u);
                } else if (match(txt,"^Remote file exists.")) {
                    list2[inv[u]] = u;
                    INF("found url "u);
                    total++;
                }
            }
            if (code == 0) close(f);
        }
    }
    if (total) {
        hash_copy(url_list,list2);
        dump(0,"spiders",url_list);
    } else {
        INF("unchanged");
        total = n;
    }
    id0(total);
    return total;
}


#TODO We have to watch out for dns servers that return false hits on bad domains.
#for time being this should mainly be called to check a url on a known web server so DNS issues should not matter.
# 0=ok 1=error 2=timeout
function url_state(url,\
ret,start,tries,timeout) {

    start=systime();
    ret = 0;
    tries=2;
    timeout=5;
    
    if (!url_online(url,tries,timeout,1)) {

        #if wget ok - check timeout
        if (systime() - start >= tries * timeout ) { 
            WARNING("timeout with domain ["url"]");
            ret = 2;
        } else if (ret) { # some other error occured
            ret = 1;
        }
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

# url - the url
function get_url_source(url,cache,\
f,code,txt,source) {
    f = getUrl(url,"raw.img",cache);
    while((code = getline txt < f) > 0) {
        source = source txt;
    }
    if (!code) close(f);
    INF("fetched "length(source)" bytes for "url);
    return source;
}
