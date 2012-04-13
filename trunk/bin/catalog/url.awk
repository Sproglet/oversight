#
# A classic case of wrong tool for the job. Trying to use awk as a web browser...
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
#   but means we may lose the utf8 features elsewhere.
#
#
# At present IO (reading to body) seems slow on embedded systems as to make spawning WGET a faster option. Might revisit in near future.
# This module is disbled for now, but I dont want to lose code.
# might be useful for spidering/HEAD etc.
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

function url_referer(url) {
    return gensub(/([a-z])\/.*/,"\\1",1,url);
}

function url_dump(label,h,i) {
    for(i in h ) print label" "i":"h[i];
}
function url_split_parts(url,parts,\
tmp) {
    if (match(url,/(https?):\/\/([^/:]+)(|:([0-9]+))(\/[^#?]*)(|[?#].*)$/,tmp)) {
        parts["proto"]=tmp[1];
        parts["host"]=tmp[2];
        parts["port"]=tmp[4]; # no ssl
        parts["path"]=tmp[5];
        parts["query"]=tmp[6];
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
function url_join_parts(parts,add_query,\
url,port) {
    port = parts["port"];
    if (parts["proto"] == "http" && port == 80 ) {
        port = "";
    } else if (parts["proto"] == "https" && port == 443 ) {
        port = "";
    } else {
        port = ":" port;
    }
    url =parts["proto"] "://" parts["host"] port  parts["path"];
    if (add_query) {
        url = url parts["query"];
    }
    return url;
}

function url_get_stored_redirect(parts,\
key,query) {
    query = parts["query"];

    key =  url_join_parts(parts,0);

    while (key in g_fetch_redirect) {
        key = g_fetch_redirect[key];
        INF("stored redirect = "key);
    }
    url_split_parts(key query,parts);
    return key query;
}

# we specifiy explit source port because if server has closed a connection
# the client will take a long time to close it. So we want a differnt connection
#and let OS close the old one down in its own time.
# We can still do this using ephemeral ports by using /0/ /00/ etc !
function url_next_source_port(host_port) {
    g_url_source_port[host_port] = "0"g_url_source_port[host_port];
    if (length(g_url_source_port[host_port]) > 40) {
        ERR("Resetting ephemeral port counter for "host_port" - tcp with awk - hmmm");
       g_url_source_port[host_port] = "";
   }
}

function url_connect(url,request,response,attempt,\
parts,con,host,host_port,i,old_key,new_key,query,ret,elapsed,count,redirect_max) {

    delete request;
    redirect_max = 6;
    for(count = 1 ; count <= redirect_max ; count++ ) {
        # Loop while following redirects...
        if (url_split_parts(url,parts)) {

            url = url_get_stored_redirect(parts);

            host = parts["host"];
            host_port = host"/"parts["port"];

            con = "/inet/tcp/"g_url_source_port[host_port]0"/"host"/"parts["port"];


            dump(0,"stamps",g_url_con_timestamps);
            elapsed = url_con_elapsed(con);

            DEBUG("elapsed time "con" = "elapsed);
            DEBUG("systime time = "systime());
            DEBUG("timestamp "con" = "g_url_con_timestamps[con]);
            DEBUG("timout time "host_port" = "url_host_timeout(host_port));

            if (g_url_con_timestamps[con] && (elapsed > url_host_timeout(host_port) )) {
                if (elapsed < 20) {
                    INF("closing stale connection "con": elapsed time = "elapsed);
                    url_disconnect(con);
                } else {
                    INF("abandoning stale connection "con": elapsed time = "elapsed);
                    # Get a new connection
                    # just bump up to next source port.
                    url_next_source_port(host_port);
                    con = "/inet/tcp/"g_url_source_port[host_port]0"/"host"/"parts["port"];
                }
            }

            DEBUG("connecting ["con"]");

            printf "GET %s%s HTTP/1.1\r\n",parts["path"],parts["query"] |& con;

            request["Host"] = parts["host"];
            request["User-Agent"] = set_user_agent(url);
            request["Accept"] = "*/*";
            request["Accept-Encoding"] = "";
            request["Referer"] = url_referer(url);
            request["Connection"] = "Keep-Alive";

            for(i in request) {
                #DEBUG("Header : " i ": "request[i]);
                printf "%s: %s\r\n", i,request[i] |& con;
            }
            printf "\r\n" |& con;
            fflush(con);

            # Read headers
            ret=url_get_headers(con,response);

            DEBUG("hdr state = "ret);

            if (!ret) {

                if (attempt == 1) {
                    url_adjust_timout(host_port);
                }
                
                url_disconnect(con);
                con="";
                break;

            } else {
            
                g_url_con_timestamps[con] = systime();
                g_url_con_opened[con]++;

                if (index(response["@status"],"1.1 2")) {

                    url_log_state("open",con);
                    break;

                } else if (response["@status"] ~ "1 3[0-9][0-9]") {
                    # Redirect
                    url_disconnect(con);
                    con="";

                    query = parts["query"];
                    old_key = url_join_parts(parts,0);
                    new_key = response["location"]
                    if (old_key == new_key) {
                        ERR("redirection loop "con" ?");
                        break;
                    } 
                    g_fetch_redirect[old_key] = new_key;

                    url=new_key query ;
                    INF("redirect to "url);

                } else if (index(response["@status"],"1.1 4") || index(response["@status"],"1.1 5")) {

                    ERR("Error response : "response["@status"]" closing "url);
                    url_disconnect(con);
                    con="";
                    break;

                } else {
                    ERR("Dont understand response from server? - if any");
                    dump(0,"response",response);
                    # Anything else break
                    break;
                }
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
function url_connection_purge(age,\
con,idle,start) {
    if (!age) age = 10;

    do {
        id1("purge connections older than "age);
        start = systime();

        for(con in g_url_con_timestamps) {
            if (index(con,"/inet")) {
                idle = url_con_elapsed(con);
                if (idle > age) {
                    if (idle > 30) {
                        # too old to close quickly - change from port /0/ to port /00/ etc
                        ERR("abandoning "con" idle for "idle" - review logic to avoid");
                        url_next_source_port(url_extract_host_port(con));
                        delete g_url_con_timestamps[con];
                    } else {
                        INF("closing "con" idle for "idle);
                        url_disconnect(con);
                    }
                } else {
                    INF("connection "con" idle for "idle);
                }
            }
        }

        id0();
        # If we took too long to close a conection then others might by going stale too
        # so go around again.
    } while( (systime() - start) > age );

}

function url_disconnect(con) {
    close(con);
    INF("closed "con);
    delete g_url_con_timestamps[con];
    g_url_con_closed[con]++;
    url_log_state("closed",con);
    return "";
}

# return true if headers read OK
function url_get_headers(con,response,\
code,bytes,i,num,j,all_hdrs) {

    #DEBUG("url_get_headers");

    _RS = RS;
    RS="\r\n\r\n";
    code = ( con |& getline all_hdrs );

    num = split(all_hdrs,bytes,"\r\n");

    for(i = 1 ; i<= num ; i++) {

        if (bytes[i]) {

            if (bytes[i] ~ /^(HTTP|[Cc]on)/) {
                INF("hdr["bytes[i]"]");
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
    RS = _RS;
    return index(response["@status"],"HTTP/1");
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
        g_url_eof["www.thetvdb.com","html"] = "html>\n";

        g_url_eof["api.themoviedb.org","json"] = "}";
        g_url_eof["api.themoviedb.org","xml"] = ">";

        g_url_eof["m.bing.com","xhtml"] = ">";

        # Generic EOF markers - these will fail if the site sends trailing white space CR/LF etc.
        g_url_eof["xml"] = ">"; #any end tag followed by optional white space
        g_url_eof["json"] = "}";
        g_url_eof["html"] = "html>";
        g_url_eof["xhtml"] = "html>";
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
        INF("using supplied record sep"rec_sep);
    } else {

        key = url_eof_key(request,response);

        if (!(1 in g_url_eof)) {
            url_eof_init();
        }
        rec_sep = g_url_eof[key];

        if (rec_sep == "") {

            ct = url_ct(response);
            rec_sep = g_url_eof[ct] "[[:space:]]*"; #change to ? from *
            INF("using default record sep for key "key"  = "rec_sep);
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

            DEBUG("Updating EOF marker for "key" = ["g_url_eof[key]"]");

        } else {
            WARNING("unable to learn EOF for "key);
        }
    }
}

# Fetch a URL and keep connection open.
# Doesn not work well with pure binary data.
# A record separator must be passed that matches the last bytes of the content , but must not match too many other records.
# eg for JSON "}" for XML ">" for HTML </html> 
# Performance for HTML m
function url_get(url,response,rec_sep,cache,\
ret,code,f,body,line) {

    if (cache) {
        f = g_url_cache[url];

        if (!f || !is_file(f)) {
            if ((ret = url_get2(url,response,rec_sep)) != 0) {
                f = new_capture_file("url_get");
                INF("saving to cache "f);
                printf "%s",response["body"] > f;
                close(f);
                g_url_cache[url] = f;
            }
        } else {
            INF("loading from cache "f);
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
        ret = url_get2(url,response,rec_sep);
   }
   return ret;
}

function url_get2(url,response,rec_sep,\
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
            
            DEBUG("reconnect attempt "try);
        }

        con = url_connect(url,request,response,try);

        if (con && response["content-encoding"] == "gzip" && response["transfer-encoding"] != "chunked") {

            con = url_disconnect(con,1);

            id0("non-chunked binary transfer - using external function");

            response["body"] = get_url_source(url,0);

            return (response["body"] != "");

        }

    }

    if (con) {

        read_body = 1;

    } else if (response["content-length"] ) {

        WARNING("Error in response headers - reading body...");

        read_body = 1;

    } else {

        WARNING("Error in response headers - ignoring body...");
    }

    if (read_body) {

        #get encoding - assume xml / json is utf8
        ct = url_ct(response);
        if (index("json,xml,xhtml",ct)) enc="utf-8";
        else if (index(tolower(response["content-type"]),"utf-8")) enc = "utf-8";

        #DEBUG("pre-encoding type = "enc);

        rec_sep = url_eof(request,response,rec_sep);
        if (response["transfer-encoding"] == "chunked") {
            chunked = 1;
        }

        _RS = RS; RS = rec_sep;

        if (chunked) {
            body = url_read_chunked(con);
        } else {
            DEBUG("begin body sep="rec_sep);
            body = url_read_fixed(con,response,rec_sep);
            url_eof_learn(request,response);
        }
        RS = _RS;
        #DEBUG("end body");

        response["body"] = body;
        fflush(con);

        #close(con);
        if (!enc) {
            enc = extract_encoding(body);
        }

        url_gunzip(response); 
        url_encode_utf8(response);

        ret = (response["body"] != "");
    }

    response["enc"] = enc;
    log_bigstring(enc" body",response["body"],20);
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
    ts = g_url_con_timestamps[con];
    if (!ts) {
        return 0;
    } else {
        return systime() - ts;
    }
}

function url_extract_host_port(con) {
    return gensub(/\/inet\/tcp\/0+\//,"",1,con);
}

function url_adjust_timout(con,\
host_port,elapsed) {

    host_port = url_extract_host_port(con);
    elapsed = url_con_elapsed(con);

    # Something went wrong with connection.
    if (elapsed < url_host_timeout(host_port)) {
        INF("elapsed time = "elapsed" current timout = "url_host_timeout(host_port));
        g_url_timeout[host_port] = elapsed - 1;
        if (g_url_timeout[host_port] < 5) g_url_timeout[host_port] = 5;
        INF("Adjusted client timeout for "host_port" to "g_url_timeout[host_port]);
    }
}


# read chunked stream
function url_read_chunked(con,\
body,bytes,bytes2,chunk_len) {

    while ( con |& getline bytes ) {
        chunk_len=strtonum("0x"bytes);

        #DEBUG("chunked  len["bytes"] = "chunk_len" bytes");

        if (chunk_len == 0) {
            # for tvdb read one more blank record - will probably break for imdb
            #DEBUG("read final blank");
            con |& getline bytes2;
            break;
        }
        bytes="";
        while ( con |& getline bytes2 ) {
            bytes = bytes bytes2 RT;


            #log_bigstring("chunk",bytes2,10);
            #DEBUG(length(bytes)" of "chunk_len);

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
content_length,body,bytes,is_xml) {

    content_length = response["content-length"]+0;

    if (index(response["content-type"],"xml")) {
        is_xml=1;
    }
    while ( con |& getline bytes ) {
        body = body bytes RT;
        #DEBUG("[" bytes "][" RT "]");
        
        if (content_length && length(body)+0 >= content_length) break;

        # If XML then change RS to be the expected end tag corresponding the the first opening tag.

        #disabled = use > markers - safe if all content is not in second read.
        if (0 && is_xml==1) {
            if (match(bytes,"<[^[:space:]>?/!]+")) { # opening tag

                is_xml++; # only do this once

                #RS = substr(bytes,RSTART+1,RLENGTH-1)"[[:space:]]*" initial_rs;
                RS = substr(bytes,RSTART+1,RLENGTH-1) initial_rs;
                DEBUG("xml eof changed to "RS);
            }
        }
    }
    return body;
}


function url_gunzip(response,\
zip_pipe,b,txt) {
    if (response["content-encoding"] == "gzip" ) {
        INF("url_gunzip decompressing ...");
        zip_pipe = "gunzip";

        #awk strings can contain nul \0 so this will work!
        printf "%s",response["body"] |& zip_pipe
        fflush(zip_pipe);
        close(zip_pipe,"to");
        while ( zip_pipe |& getline txt ) {
            b = b txt;
        }
        response["body"] = b;
        close(zip_pipe);
    }
}
function url_encode_utf8(response,\
iconv_pipe,b,txt,enc) {
    enc = response["enc"] ;
    if (enc && (enc != "utf8" )) {
        if (g_fetch["no_encode"]) {
            INF("leaving "enc" to utf8 ...");
        } else {
            INF("converting "enc" to utf8 ...");
            iconv_pipe = "iconv -f "enc" -t utf-8";

            printf "%s",response["body"] |& iconv_pipe
            fflush(iconv_pipe);
            close(iconv_pipe,"to");
            while ( iconv_pipe |& getline txt ) {
                b = b txt;
            }
            response["body"] = b;
            response["enc"] = "utf-8";
            close(iconv_pipe);
        }
    }
}

function url_log_state(label,con) {
    INF(label" : connection "con" opened "g_url_con_opened[con]" closed "g_url_con_closed[con]);
}
function url_stats(\
con) {
    for( con in g_url_con_opened) {
        url_log_state("final",con);
    }
}
