# Fetch a URL and keep connection open.
# Doesn not work well with pure binary data.
# A record separator must be passed that matches the last bytes of the content , but must not match too many other records.
# eg for JSON "}" for XML ">" for HTML </html> 
# Performance for HTML m

# IN url
# IN headers - SUBSEP list of headers.
# OUT response
function url_get(url,response,rec_sep,cache,headers,\
ret,code,f,body,line) {

    if (cache) {
        f = g_url_cache[url];

        if (!f || !is_file(f)) {
            if ((ret = url_get_uncached(url,response,rec_sep,headers)) != 0) {
                f = new_capture_file("url_get");
                if(LD)DETAIL("saving to cache "f);
                printf "%s",response["body"] > f;
                close(f);
                g_url_cache[url] = f;
            }
        } else {
            if(LD)DETAIL("loading from cache "f);
            while((code=getline line < f) > 0) {
                body = body line;
            }
            if (code >= 0) {
                close(f);
            }
            response["body"] = body;
            ret = 1;
        }
    } else {
        ret = url_get_uncached(url,response,rec_sep,headers);
   }
   if(LI)INF("url_get [ "url" ] = "ret);
   return ret;
}

function url_get_uncached(url,response,rec_sep,headers,\
ret) {
    if (g_settings["catalog_awk_browser"] && !index(url,"thetvdb") ) {
        ret = url_get_awk(url,response,rec_sep,headers);
    } else {
        delete response;
        ret = url_get_wget(url,response,headers);
    }
    if(LD)DETAIL("url_get_uncached [ "url" ] = "ret);
    return ret;
}

# Get a URL with wget
function url_get_wget(url,response,headers,\
cmd,body,ret,i,hdr,txt,enc,code) {

    cmd = "wget -q --referer "get_referer(url);
    cmd = cmd " -U "qa(set_user_agent(url));
    cmd = cmd " --header='Accept-Encoding: gzip' "qa(url)" -O -";

    if (headers) {
        split(headers,hdr,SUBSEP);
        for(i in hdr) {
            if (!index(hdr[i],"gzip")) {
                cmd=cmd " --header='"hdr[i]"'";
            }
        }
    }
    if(LD)DETAIL("url_get_wget cmd = ["cmd"]");

    while ((code = ( cmd |& getline txt )) > 0) {
        body = body txt RT;
    }
    if (code >= 0) {
        close(cmd);
        response["body"] = body;
        if(LD)DETAIL("response body len = "length(body));
        url_gunzip(response); 
        if (!enc) {
            response["enc"] = extract_encoding(response["body"]);
        }
        url_encode_utf8(response);
        ret = length(response["body"]);
    }
    if(LD)DETAIL("url_get_wget [ "cmd" ] = "ret);
    return ret;
}

# Unzip Body - return 1 if work done.
function url_gunzip(response,\
zip_pipe,b,txt,ret,code) {
    ret = 0;

    b = response["body"];
#    if (response["content-encoding"] && index(response["content-encoding"],"gzip") == 0 ) {
#        # nothing to do
#        ret = 0;
#    } else
    if (substr(b,1,1) == "") { # gzip magin number 0x8b1f starts with 1f > 0a < 20

        if(LD)DETAIL("url_gunzip decompressing ...");
        zip_pipe = "gunzip 2>/dev/null ";

        #awk strings can contain nul \0 so this will work!
        printf "%s",b |& zip_pipe
        fflush(zip_pipe);
        close(zip_pipe,"to");
        b="";
        while ( ( code = ( zip_pipe |& getline txt ) ) > 0) {
            b = b txt RT;
        }
        if (code >= 0 ) {
            if (length(b)) {
                response["body"] = b;
                ret = 1;
            }
            close(zip_pipe);
        } else {
            WARNING("url_gunzip pipe error");
        }
    }
    if(LD)DETAIL("url_gunzip = "ret"  out body length = ["length(response["body"])"]");
    return ret;
}

# Make sure file is UTF8
function url_encode_utf8(response,\
iconv_pipe,b,txt,enc,ret,code) {
    enc = response["enc"] ;
    if (enc ) {
       if (enc == "utf-8" ) {
           ret = 1;
       } else if (g_fetch["no_encode"]) {
           if(LD)DETAIL("leaving "enc" to utf-8 ...");
       } else {
           if(LD)DETAIL("converting "enc" to utf-8 ...");
           iconv_pipe = "iconv -f "enc" -t utf-8";

           printf "%s",response["body"] |& iconv_pipe
           fflush(iconv_pipe);
           close(iconv_pipe,"to");
           while ( ( code = ( iconv_pipe |& getline txt )) > 0 ) {
                b = b txt RT;
           }
           if (code >= 0) {
               response["body"] = b;
               response["enc"] = "utf-8";
               close(iconv_pipe);
               ret = 1;
            } else {
                WARNING("url_encode_utf8 pipe error");
           }
       }
    }
    if(LD)DETAIL("url_encode_utf8 = "ret" in body length = ["length(response["body"])"]");
    return ret;
}

#
# Beyond this point is a classic case of wrong tool for the job. Trying to use awk as a web browser...
# Why? Re-using connections can save a LOT of time, but not many widely available tools
# will let me drip-feed them with URLs whils maintaining keep-alive.
# in perl this would have been simple, but awk has issues reading to exact EOF for fixed
# content length.
#
# So this hack was born - more out of challenge really
#  See http://www.gnu.org/software/gawk/manual/gawkinet/html_node/GETURL.html
#
#
# This url grabber can be used for lots small requests rather than invoking wget.
# advantage:
#    is that data comes directly into awk,
#    no spawning wget, gzip processes
#    it can re-use connections
# disadvantage:
#   is data is not compressed.
#   awk cannot properly read the final record of binary data, so we have to pass what we hope is the last byte.
#   requires LC_ALL=C  to compute content lengths correctly- this might be a good thing.
#   but means we may lose the utf-8 features elsewhere.
#
# To read to end of line the ASSUMPTION we are making is that for a given domain the EOF is the same.
# Initially for JSON this is }[[:space:]]* and for XML this is >[[:space:]]*
#
# Using a regular expression as RS invokes an automatic 2 sencond penalty - dont know why, awk waiting to be greedy I guess.
# Also it will tend to encourage the remote server to drop the connection so..
#
# This module will initially use a suffix of [[:space:]]* the first time only. After that it will review
# the actual EOF sequence and use that next time.
# Fraught with danger ...

END {

    #url_get("http://api.themoviedb.org/3/movie/tt0848228?api_key=2d51eee0579cdf410b337edcdac1ae14",r1);
    #url_get("http://api.themoviedb.org/3/movie/tt0091530?api_key=2d51eee0579cdf410b337edcdac1ae14",r1);

    #url_get("http://app.imdb.com/title/maindetails?api=v1&appid=iphone1&locale=fr_FR&tconst=tt0167260",r1);
    #url_get("http://app.imdb.com/title/maindetails?api=v1&appid=iphone1&locale=fr_FR&tconst=tt0091530",r1);

    #url_get("http://www.thetvdb.com/data/series/257364/default/2/1/en.xml",r1);
    #url_get("http://www.thetvdb.com/data/series/257360/en.xml",r1);
    ##url_get("http://www.thetvdb.com/data/series/257364/default/2/1/en.xml",r1,"\n");
    #url_get("http://www.thetvdb.com/data/series/257364/default/2/1/en.xml",r1,"\n");
    #url_get("http://www.thetvdb.com/data/series/257360/en.xml",r1,"\n");
    #url_get("http://www.thetvdb.com/data/series/257360/en.xml",r1,"\n");
    #url_get("http://www.thetvdb.com/data/series/257364/default/2/1/en.xml",r1,"\n");
    #url_get("http://www.thetvdb.com/data/series/257364/default/2/1/en.xml",r1,"\n");
}

function url_dump(label,h,i) {
    for(i in h ) print label" "i":"h[i];
}
function url_split_parts(url,parts,\
tmp) {
    if (match(url,/(|(https?):\/\/([^/:]+)(|:([0-9]+)))(|\/[^#?]*)(|[?#].*)$/,tmp)) {
        parts["proto"]=tmp[2];
        parts["host"]=tmp[3];
        parts["port"]=tmp[5]; # no ssl
        parts["path"]=tmp[6];
        parts["query"]=tmp[7];
        if (parts["proto"] == "http" && !parts["port"] ) {
            parts["port"] = 80;
        } else if (parts["proto"] == "https" && !parts["port"] ) {
            parts["port"] = 443;
        }
        #dump(0,"parts",parts);
        return 1;
    }
    ERR("failed to parse url "url);
    return 0;
}
function url_join_parts(parts,\
url,port) {
    port = parts["port"];
    if (parts["proto"] == "http" && port == 80 ) {
        port = "";
    } else if (parts["proto"] == "https" && port == 443 ) {
        port = "";
    } else {
        port = ":" port;
    }
    url =parts["proto"] "://" parts["host"] port  parts["path"] parts["query"];
    return url;
}

function url_merge(url1,url2,\
parts1,parts2,i) {
    url_split_parts(url1,parts1);
    url_split_parts(url2,parts2);
    for(i in parts1) {
        if (parts2[i] != "") {
            parts1[i] = parts2[i];
        }
    }
    return url_join_parts(parts1);
}

# we specifiy explit source port because if server has closed a connection
# the client will take a long time to close it. So we want a differnt connection
#and let OS close the old one down in its own time.
# We can still do this using ephemeral ports by using /0/ /00/ etc !
function url_next_source_port(host_port) {
    g_url_source_port[host_port] = "0"g_url_source_port[host_port];
    if (length(g_url_source_port[host_port]) > 60) {
        ERR("Resetting ephemeral port counter for "host_port" - tcp with awk - hmmm");
       g_url_source_port[host_port] = "";
   }
}

function url_con_str(parts,\
host_port) {
    host_port = parts["host"]"/"parts["port"];
    return "/inet/tcp/"g_url_source_port[host_port]0"/"parts["host"]"/"parts["port"];
}

# IN url
# IN headers - SUBSEP list of headers.
# OUT request 
# OUT response
function url_connect(url,headers,request,response,\
parts,con,host,host_port,i,ret,elapsed,count,redirect_max,msg,hdr) {

    delete request;
    redirect_max = 6;
    for(count = 1 ; count <= redirect_max ; count++ ) {
        # Loop while following redirects...
        if (url_split_parts(url,parts)) {

            host = parts["host"];
            host_port = host"/"parts["port"];

            con = url_con_str(parts);


            elapsed = url_con_elapsed(con);

            if (1) {
                msg = con" elapsed "elapsed;
                msg = msg" created "strftime("%H:%M:%S",g_url_con_createtime[con]);
                msg = msg" used "strftime("%H:%M:%S",g_url_con_usedtime[con]);
                msg = msg" timout "host_port" = "url_host_timeout(host_port);
                if(LG)DEBUG(msg);
            }
            url_connection_purge();

            if (g_url_con_usedtime[con] && (elapsed > url_host_timeout(host_port) )) {
                url_disconnect(con,(elapsed < 20),"elapsed time = "elapsed);
                # regenerate connection name in case it changed.
                con = url_con_str(parts);
            }

            if (!g_url_con_usedtime[con]) {
                # new connection
                g_url_con_createtime[con] = systime();
            }

            if(LG)DEBUG("connecting ["con"]");

            printf "GET %s%s HTTP/1.1\r\n",parts["path"],parts["query"] |& con;

            request["Host"] = parts["host"];
            request["User-Agent"] = set_user_agent(url);
            request["Accept"] = "*/*";
            request["Accept-Encoding"] = "";
            request["Referer"] = get_referer(url);
            request["TE"] = "chunked";
            request["Connection"] = "Keep-Alive";

            if (headers) {
                split(headers,hdr,SUBSEP);
                for(i in hdr) {
                    #if(LG)DEBUG("Header : "hdr[i]);
                    printf "%s\r\n", hdr[i] |& con;
                }
            }
            for(i in request) {
                if (!index(headers,i)) {
                    #if(LG)DEBUG("Header : " i ": "request[i]);
                    printf "%s: %s\r\n", i,request[i] |& con;
                }
            }
            printf "\r\n" |& con;
            fflush(con);

            # Read headers
            ret=url_get_headers(con,response);

            if(LG)DEBUG("hdr state = "ret);

            if (ret == 1) {
            
                g_url_con_usedtime[con] = systime();
                g_url_con_opened[con]++;
                g_url_con_persist_subtotal[con]++;

                if (index(response["@status"],"1.1 2")) {

                    url_log_state((g_url_con_persist_subtotal[con]==1?"reconnect":"open"),con);
                    break;

                } else if (response["@status"] ~ "1 3[0-9][0-9]") {
                    # Redirect
                    url=url_merge(url,response["location"]) ;
                    if(LD)DETAIL("redirect to "url);
                    con=""; # clear con in case redirection loop exhausted 

                } else if (index(response["@status"],"1.1 4") || index(response["@status"],"1.1 5")) {

                    ERR("Error response : "response["@status"]" closing "url);
                    url_disconnect(con,1);
                    con="";
                    break;

                } else {
                    ERR("Dont understand response from server? - if any");
                    dump(0,"response",response);
                    # Anything else break
                    break;
                }
            } else if (ret == 0) {

                url_disconnect(con,1,"eof reading headers");
                con="";
                break;

            } else if (ret == -1) { #Error

                url_disconnect(con,0,"error reading headers");
                con="";
                break;

            }
        }
    }
    if (count >= redirect_max) {
        ERR("Redirections exhausted");
        con="";
    }
    return con;
}

# We must check connections regularly and close them down if they are idle
# for more than a few seconds. Otherwise the remote server abandons the socket,
# and the close from the client will timeout. In that case its better not to 
# close the socket but start a new one using local port /00/ /000/ etc ..
# call with (0,0,0) to force a disconnect
function url_connection_purge(max_idle,max_age,max_used,\
con,idle,age,host_max_age,host_max_idle,host_max_used,host_port,poll_time,final) {

    if (g_settings["catalog_awk_browser"]) {
        if (!g_url_host_max_init) {
            g_url_host_max_init = 1;
            g_url_host_max_idle["www.thetvdb.com/80"] = 3;
            g_url_host_max_age["www.thetvdb.com/80"] = 5;
            #g_url_host_max_used["www.thetvdb.com/80"] = 6;
        }

        poll_time = 3;

        while (systime() - g_url_con_purge_time > poll_time) {

            # If we took too long to close a conection then others might by going stale too
            # so go around again.
            g_url_con_purge_time = systime();

            for(con in g_url_con_usedtime) {
                if (con) {

                    host_port = url_extract_host_port(con);

                    host_max_idle = max_idle;
                    host_max_age  = max_age;
                    host_max_used = max_used;

                    if (host_max_idle=="") host_max_idle = g_url_host_max_idle[host_port];
                    if (host_max_age=="")  host_max_age = g_url_host_max_age[host_port];
                    if (host_max_used=="") host_max_used = g_url_host_max_used[host_port];
                    
                    if (host_max_idle=="") host_max_idle = 10;
                    if (host_max_age=="")  host_max_age = 20;
                    if (host_max_used=="") host_max_used = 50;

                    if(LG)DEBUG("host "host_port" "host_max_idle"/"host_max_age"/"host_max_used);

                    idle = url_con_elapsed(con);
                    age = (g_url_con_createtime[con]? systime() - g_url_con_createtime[con] : 0) ;

                    if (host_max_used == 0) {
                        final = "final ";
                    }

                    if (idle >= host_max_idle) {

                        url_disconnect(con,(idle <= 30),final" idle for "idle);

                    } else if (age >= host_max_age ) {

                       # prune threads that have been alive too long.
                       # this is really only foe tvdb.com other sites not too bothered.
                       url_disconnect(con,(age < host_max_age+10),final" age="age);

                    } else if (g_url_con_persist_subtotal[con] > host_max_used ) {

                        # check usage
                        url_disconnect(con,1,"max reconnections > "host_max_used);

                    } else {
                        if(LD)DETAIL((age?"keeping":"new")" connection "con" idle for "idle);
                    }
                }
            }
        }
    }
}

function url_disconnect(con,do_close,msg) {

    if(do_close) {
        close(con);
        url_log_state("closed: reason "msg,con);
    } else {
        url_next_source_port(url_extract_host_port(con));
        url_log_state("abandoned: reason "msg,con);
    }

    delete g_url_con_usedtime[con];
    delete g_url_con_createtime[con];
    g_url_con_closed[con]++;
    delete g_url_con_persist_subtotal[con];
}

# return true if headers read OK
function url_get_headers(con,response,\
code,bytes,i,num,j,all_hdrs) {

    #if(LG)DEBUG("url_get_headers");

    rs_push("\r\n\r\n");

    delete response;

    code = ( con |& getline all_hdrs );

    if (code > 0) {
        num = split(all_hdrs,bytes,"\r\n");

        for(i = 1 ; i<= num ; i++) {

            if (bytes[i]) {

                if (1 || bytes[i] ~ /^(HTTP|[Cc]on)/) {
                    if(LD)DETAIL("hdr["bytes[i]"]");
                }

                if ((j=index(bytes[i],":")) > 0) {
                    response[tolower(substr(bytes[i],1,j-1))] =  trim(substr(bytes[i],j+2));

                } else if (index(bytes[i],"HTTP/1")) {
                    # HTTP/1.1 200 OK
                    response["@status"] = bytes[i];

                } else {
                    ERR("dont understand header ["bytes[i]"]");
                }
            }
        }
    } else {
        ERR("Error "code" getting headers ");
    }
    rs_pop();
    return (code);
}

function url_eof_init() {
    if (!(1 in g_url_eof)) {
        g_url_eof[1]=1;
        # g_url_eof must a a string that grabs very lasy byte for the site.
        # if not specified it uses the application type. json='}' html='</html>' xml='>'
        #g_url_eof["www.thetvdb.com"] = ">[[:space:]]*";

        # To avoid long initial timeouts terminatos can be added here.
        # then there is no learning period.
        # This is not needed if chunked transfers are used.
        g_url_eof["www.thetvdb.com","xml"] = ">\n";
        g_url_eof["www.thetvdb.com","json"] = "}\n";
        g_url_eof["www.thetvdb.com","html"] = ">\n";

        g_url_eof["api.themoviedb.org","json"] = "}";
        g_url_eof["api.themoviedb.org","xml"] = ">";

        g_url_eof["m.bing.com","xhtml"] = ">";

        # Generic EOF markers - these will fail if the site sends trailing white space CR/LF etc.
        g_url_eof["xml"] = ">"; #any end tag followed by optional white space
        g_url_eof["json"] = "}";
        g_url_eof["html"] = ">";
        g_url_eof["xhtml"] = ">";
    }
}
function url_ct(response,\
ct) {
    ct = response["content-type"];
    if (index(ct,"json")) return "json";
    else if (index(ct,"xhtml")) return "xhtml";
    else if (index(ct,"xml")) return "xml";
    else if (index(ct,"html")) return "html";
}

function url_eof_key(request,response) {
    return request["Host"] SUBSEP url_ct(response);
}

function url_eof(request,response,rec_sep,\
ct,key) {
    if (response["transfer-encoding"] == "chunked") {
        rec_sep = "\r\n";

    } else if (rec_sep) {
        if(LD)DETAIL("using supplied record sep"rec_sep);
    } else {

        key = url_eof_key(request,response);

        if (!(1 in g_url_eof)) {
            url_eof_init();
        }
        rec_sep = g_url_eof[key];

        if (rec_sep == "") {

            ct = url_ct(response);
            rec_sep = g_url_eof[ct] "[[:space:]]*"; #change to ? from *
            if(LD)DETAIL("using default record sep for key "key"  = "rec_sep);
        }
    }
    return rec_sep;
}

# Update the EOF for the host by looking at the trailing space on the end of the body
function url_eof_learn(request,response,\
key,ct,tail,rec_sep) {

    key = url_eof_key(request,response);
    rec_sep = g_url_eof[key];
    if (rec_sep == "") {

        rec_sep = url_eof(request,response);

        if (match(response["body"],"[[:space:]]*$")) {

            tail = substr(response["body"],RSTART,RLENGTH);

            ct = url_ct(response);

            g_url_eof[key] = g_url_eof[ct] tail;

            if(LG)DEBUG("Updating EOF marker for "key" = ["g_url_eof[key]"]");

        } else {
            WARNING("unable to learn EOF for "key);
        }
    }
}

# IN url
# IN headers - SUBSEP list of headers.
# OUT response
function url_get_awk(url,response,rec_sep,headers,\
request,ret,con,body,chunked,read_body,tries,try,ct,enc) {

    if (ENVIRON["LC_ALL"] != "C") {
        ERR("length byte count may be wrong");
    }
    gsub(/;/,"\\&",url); # m.bing.com doesnt like ;
    gsub(/ /,"+",url);
    #gsub(/ /,"%20",url);

    #for tvdb.com it sometimes sends gzip even though Accept-Encoding is blank
    #this can be prevented by adding query to the request.
    if (index(url,"tvdb.com/") && !index(url,"?")) {
        url = url "?";
    }

    id1("url_get "url);
    delete response;

    tries = 2;


    for(try = 1 ; !con &&  try <= tries ; try++ ) {

        if (try > 1) {
            
            if(LG)DEBUG("reconnect attempt "try);
        }

        con = url_connect(url,headers,request,response);

        if (con && response["content-encoding"] == "gzip" && response["transfer-encoding"] != "chunked") {

            url_disconnect(con,1);
            con = "";

            id0("non-chunked binary transfer - using external function");

            response["body"] = get_url_source(url,0);

            return (response["body"] != "");

        }

    }

    if (con) {

        read_body = 1;

    } else if (response["content-length"] ) {

        WARNING("Error in response headers - ignoring body...");

        read_body = 0;

    } else {

        WARNING("Error in response headers - ignoring body...");
    }

    if (read_body) {

        #get encoding - assume xml / json is utf-8
        ct = url_ct(response);
        if (index("json,xml,xhtml",ct)) enc="utf-8";
        else if (index(tolower(response["content-type"]),"utf-8")) enc = "utf-8";

        #if(LG)DEBUG("pre-encoding type = "enc);

        rec_sep = url_eof(request,response,rec_sep);
        if (response["transfer-encoding"] == "chunked") {
            chunked = 1;
        }

        rs_push(rec_sep);

        if (chunked) {
            body = url_read_chunked(con);
        } else {
            if(LG)DEBUG("begin body sep="rec_sep);
            body = url_read_fixed(con,response,rec_sep);
            url_eof_learn(request,response);
        }
        rs_pop()
        #if(LG)DEBUG("end body");

        response["body"] = body;
        fflush(con);

        #close(con);
        url_gunzip(response); 
        if (!enc) {
            enc = extract_encoding(response["body"]);
        }
        url_encode_utf8(response);

        ret = (response["body"] != "");
        if (response["connection"] == "close" ) {
            url_disconnect(con,1,"closed by server");
        } else if (index(response["@status"],"1.0") && !response["connection"] == "keep-alive" ) {
            url_disconnect(con,1,"assume closed by server");
        }
    }

    response["enc"] = enc;
    #log_bigstring(enc" body",response["body"],20);
    id0(response["@status"] ~ "200");


    return ret;
}

# timeout after which connections are closed by this client
function url_host_timeout(con,\
ret) {
    ret = g_url_timeout[con];
    if (!ret) ret = 10;
    return ret+0;
}
function url_con_elapsed(con,\
ts) {
    ts = g_url_con_usedtime[con];
    if (!ts) {
        return 0;
    } else {
        return systime() - ts;
    }
}

# /inet/tcp/0/host/port
function url_extract_host_port(con,\
i) {
    i = index(con,"0/");
    return substr(con,i+2);
}

#function url_adjust_timout(con,\
#host_port,elapsed) {
#
#    host_port = url_extract_host_port(con);
#    elapsed = url_con_elapsed(con);
#
#    # Something went wrong with connection.
#    if (elapsed < url_host_timeout(host_port)) {
#        if(LD)DETAIL("elapsed time = "elapsed" current timout = "url_host_timeout(host_port));
#        g_url_timeout[host_port] = elapsed - 1;
#        if (g_url_timeout[host_port] < 5) g_url_timeout[host_port] = 5;
#        if(LD)DETAIL("Adjusted client timeout for "host_port" to "g_url_timeout[host_port]);
#    }
#}
#

# read chunked stream
function url_read_chunked(con,\
body,bytes,bytes2,chunk_len,code) {

    while ( (code =  ( con |& getline bytes )) > 0) {
        chunk_len=strtonum("0x"bytes);

        #if(LG)DEBUG("chunked  len["bytes"] = "chunk_len" bytes");

        if (chunk_len == 0) {
            # for tvdb read one more blank record - will probably break for imdb
            #if(LG)DEBUG("read final blank");
            con |& getline bytes2;
            break;
        }
        bytes="";
        while ( (code =  ( con |& getline bytes2 )) > 0) {
            bytes = bytes bytes2 RT;


            #log_bigstring("chunk",bytes2,10);
            #if(LG)DEBUG(length(bytes)" of "chunk_len);

            if (length(bytes) >= chunk_len) {
                # remove final RT
                bytes=substr(bytes,1,chunk_len);
                break;
            }
        }
        body = body bytes;
    }
    return body;
}

# read fixed stream
function url_read_fixed(con,response,initial_rs,\
content_length,body,bytes,is_xml,code) {

    content_length = response["content-length"]+0;

    rs_push(RS);
    if (index(response["content-type"],"xml")) {
        is_xml=1;
    }
    while ( (code =  ( con |& getline bytes )) > 0) {
        body = body bytes RT;
        #if(LG)DEBUG("[" bytes "][" RT "]");
        
        if (content_length && length(body)+0 >= content_length) break;

        # If XML then change RS to be the expected end tag corresponding the the first opening tag.

        #disabled = use > markers - safe if all content is not in second read.
        if (0 && is_xml==1) {
            if (match(bytes,"<[^[:space:]>?/!]+")) { # opening tag

                is_xml++; # only do this once

                #RS = substr(bytes,RSTART+1,RLENGTH-1)"[[:space:]]*" initial_rs;
                RS = substr(bytes,RSTART+1,RLENGTH-1) initial_rs;
                if(LG)DEBUG("xml eof changed to "RS);
            }
        }
    }
    rs_pop();
    return body;
}


function url_log_state(label,con) {
    if(LD)DETAIL(label" : connection "con" reconnect sub total "g_url_con_persist_subtotal[con]" opened "g_url_con_opened[con]" closed "(g_url_con_closed[con]+0));
}
function url_stats(\
con) {
    if (!g_settings["catalog_awk_browser"]) {
        for( con in g_url_con_opened) {
            url_log_state("final",con);
        }
    }
}
