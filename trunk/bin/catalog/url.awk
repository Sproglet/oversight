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
#  See http://www.gnu.org/software/gawk/manual/gawkinet/html_node/GETURL.html
#
# At present IO (reading to body) seems slow on embedded systems as to make spawning WGET a faster option. Might revisit in near future.
# This module is disbled for now, but I dont want to lose code.
# might be useful for spidering/HEAD etc.

BEGIN {
    g_url_agent="Oversight";
}

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
function url_parts(url,parts,\
tmp) {
    print url;
    print match(url,"http:..[^/:]+");
    if (match(url,/(https?):\/\/([^/:]+)(|:([0-9]+))(\/[^#]*)/,tmp)) {
        parts["proto"]=tmp[1];
        parts["host"]=tmp[2];
        parts["port"]=(tmp[4]?tmp[4]:80); # no ssl
        parts["path"]=tmp[5];
        return 1;
    }
    return 0;
}

function url_connect(url,request,\
parts,con,i) {

    delete request;
    if (url_parts(url,parts)) {
        con = "/inet/tcp/0/"parts["host"]"/"parts["port"];

        DEBUG("connecting ["con"]");
        printf "GET %s HTTP/1.1\r\n",parts["path"] |& con;

        request["Host"] = parts["host"];
        request["User-Agent"] = g_user_agent; #g_url_agent;
        request["Accept"] = "*/*";
        request["Accept-Encoding"] = "";
        request["Referer"] = url_referer(url);
        request["Connection"] = "Keep-Alive";

        for(i in request) {
            printf "%s: %s\r\n", i,request[i];
            printf "%s: %s\r\n", i,request[i] |& con;
        }
        printf "\r\n" |& con;
        fflush(con);
        return con;
    }
}

function url_headers(con,response,\
code,bytes,i) {
    DEBUG("begin headers");
    _RS = RS;
    RS="\r\n";
    while ( (code = ( con |& getline bytes ) ) > 0 ) {
        print "hdr["bytes"]";
        if (bytes == "" ) break;
        if ((i=index(bytes,":")) > 0) {
            response[tolower(substr(bytes,1,i-1))] =  substr(bytes,i+2);
        } else {
            # HTTP/1.1 200 OK
            response["@status"] = bytes;
        }
    }
    RS = _RS;
    return index(response["@status"],"200");
}

function l(x) {
    return length(x) ;  #index(x"@$","@$");
}
function url_eof_init() {
    if (!(1 in g_url_eof)) {
        g_url_eof[1]=1;
        # g_url_eof must a a string that grabs very lasy byte for the site.
        # if not specified it uses the application type. json='}' html='</html>' xml='>'
        g_url_eof["www.thetvdb.com"] = "\n";
    }
}
function url_eof(request,response,rec_sep,\
ct,host) {
    if (response["transfer-encoding"] == "chunked") {
        rec_sep = "\r\n";

    } else if (rec_sep) {
        INF("using supplied record sep"rec_sep);
    } else {
        host = request["Host"];

        if (!(1 in g_url_eof)) {
            url_eof_init();
        }
        if (host in g_url_eof) {
            rec_sep = g_url_eof[host];
            INF("using default record sep for host "host" "rec_sep);

        } else {

            ct = response["content-type"];
            if (ct ~ "json" ) {
                rec_sep = "}";
            } else if (ct ~ "html" ) {
                rec_sep = "html>";
            } else if (ct ~ "xml" ) {
                rec_sep = "/[[:alnum:]]+>";
            } else {
                rec_sep = "\r\n";
            }
            INF("using default record sep for host ["host"] content-type "ct" "rec_sep);
        }
    }
    return rec_sep;
}

# Fetch a URL and keep connection open.
# Doesn not work well with pure binary data.
# A record separator must be passed that matches the last bytes of the content , but must not match too many other records.
# eg for JSON "}" for XML ">" for HTML </html> 
# Performance for HTML m
function url_get(url,response,rec_sep,\
request,bytes,bytes2,ret,con,body,chunked,chunk_len,content_length,read_body) {

    gsub(/ /,"%20",url);

    id1("url_get "url);
    delete response;

    con = url_connect(url,request);
    ret=url_headers(con,response);

    if (!ret) {
        close(con);
        delete g_url_open[con];

        DEBUG("reconnecting...");
        con = url_connect(url,request);
        ret=url_headers(con,response);
        g_url_reopened[con]++;
    } 

    if (ret) {
        if (++g_url_open[con] > 1) {
            g_url_reconnected[con]++;
            INF("reusing connection to "con);
        }
    }


    rec_sep = url_eof(request,response,rec_sep);
    if (response["transfer-encoding"] == "chunked") {
        chunked = 1;
    }

    if (ret) {
        read_body = 1;
    } else if (response["content-length"] ) {
        WARNING("Error in response headers - reading body...");
        read_body = 1;
    } else {
        WARNING("Error in response headers - ignoring body...");
    }

    if (read_body) {

        DEBUG("begin body sep="rec_sep);
        _RS = RS;
        RS=rec_sep;

        if (chunked) {
            while ( con |& getline bytes ) {
                chunk_len=strtonum("0x"bytes);

                DEBUG("chunked  len["bytes"] = "chunk_len" bytes");

                if (chunk_len == 0) {
                    # for tvdb read one more blank record - will probably break for imdb
                    DEBUG("read final blank");
                    con |& getline bytes2;
                    break;
                }
                bytes="";
                while ( con |& getline bytes2 ) {
                    bytes = bytes bytes2 RT;


                    DEBUG("chunked data["substr(bytes2,1,20)"..."substr(bytes2,length(bytes2)-20)"] "length(bytes)" vs "chunk_len" = "(length(bytes) >= chunk_len));
                    #DEBUG("chunked data["bytes2"] "length(bytes)" vs "chunk_len" = "(length(bytes) >= chunk_len));
                    if (length(bytes) >= chunk_len) {
                        # remove final RT
                        bytes=substr(bytes,1,chunk_len);
                        break;
                    }
                }
                body = body bytes;
            }
        } else {
            content_length = response["content-length"]+0;
            while ( con |& getline bytes ) {
                body = body bytes RT;
                if (content_length && l(body)+0 >= content_length) break;
            }
        }
        RS = _RS;
        DEBUG("end body");
        response["body"] = body;
        fflush(con);
        #close(con);
        url_gunzip(response);

        ret = (response["body"] != "");
    }

    DEBUG( url"=>"response["body"]);
    id0(response["@status"] ~ "200");
    return ret;
}

function url_gunzip(response,\
zip_pipe,b,txt) {
    if (response["content-encoding"] == "gzip" ) {
        INF("url_gunzip decompressing ...");
        zip_pipe = "gunzip";
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
