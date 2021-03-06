function to_string(fieldid,v,\
type) {
    type = g_dbtype[fieldid];
    if(type == g_dbtype_string) {
        v=v"";
    } else if(type == g_dbtype_int) {
        v=v+0;
    } else if (type == g_dbtype_time) {
        v= longtime(v);
    } else if (type == g_dbtype_year) {
        if (length(v) < 4) {
            v= long_year(v);
        }
    } else if (type == g_dbtype_path) {
        if (!STANDALONE) {
            v=long_path(v);
        }
    } else if (type == g_dbtype_genre) {
        v= long_genre(v);
    } else if (type == g_dbtype_imdblist) {
        v= imdb_list_expand(v,",",128);
    } else {
        ERR("Unknown db type ["type"] for fieldid ["fieldid"]");
    }
    return v;

}
function shortform(fieldid,v,\
type) {
    type = g_dbtype[fieldid];
    if(type == g_dbtype_string) {
        v=v"";
    } else if(type == g_dbtype_int) {
        v = v+0;
    } else if (type == g_dbtype_time) {
        v= shorttime(v);
    } else if (type == g_dbtype_year) {
        if (length(v) == 4) {
            v= short_year(v);
        }
    } else if (type == g_dbtype_path) {
        if (!STANDALONE) {
            v=short_path(v);
        }
    } else if (type == g_dbtype_genre) {
        v= short_genre(v);
    } else if (type == g_dbtype_imdblist) {
        v= imdb_list_shrink(v,",",128);
    } else {
        ERR("Unknown db type ["type"] for fieldid ["fieldid"]");
    }
    return v;

}
# convert yyyymmddHHMMSS to bitwise yyyyyy yyyymmmm dddddhhh hhmmmmmm
function shorttime(t,\
y,m,d,hr,mn,r) {
    r = t;
    if (length(t) >= 8 ) {

        y = num(substr(t,1,4))-1900;
        m = num(substr(t,5,2));
        d = num(substr(t,7,2));
        hr = num(substr(t,9,2));
        mn = num(substr(t,11,2));

        r = lshift(lshift(lshift(lshift(and(y,1023),4)+m,5)+d,5)+hr,6)+mn;
        r= sprintf("%x",r);
    }
    #if(LD)DETAIL("shorttime "t" = "r);
    return r;
}
function longtime(t,\
y,m,d,hr,mn) {
    if (length(t) < 8 ) {
        t = hex2dec(t);
        mn = and(t,63); t = rshift(t,6);
        hr = and(t,31); t = rshift(t,5);
        d = and(t,31); t = rshift(t,5);
        m = and(t,15); t = rshift(t,4);
        y = t + 1900;
        t = sprintf("%04d%02d%02d%02d%02d00",y,m,d,hr,mn);
    }
    return t;

}
function imdb_list_shrink(s,sep,base,\
i,n,out,ids,m,id,ascii_offset) {

    if (sep == "") sep = ",";
    if (base == "") base = 128;
    ascii_offset = 128;

    n = split(s,ids,sep);
    for(i = 1 ; i <= n ; i++ ) {


        if (index(ids[i],"tt") == 1 || index(ids[i],"nm") == 1) {

            id = substr(ids[i],3);

            m = basen(id,base,ascii_offset);

            out = out sep m ;
        } else {
            out = out sep ids[i] ;
        }
    }
    out = substr(out,1+length(sep));
    if(LD)DETAIL("compress ["s"] = ["out"]");

    return out;
}
function imdb_list_expand(s,sep,base,\
i,n,out,ids,m,ascii_offset) {

    if (sep == "") sep = ",";
    if (base == "") base = 128;
    ascii_offset = 128;

    n = split(s,ids,sep);
    for(i = 1 ; i <= n ; i++ ) {


        if (index(ids[i],"tt") == 0) {

            m = base10(ids[i],base,ascii_offset);
            out = out sep "tt" sprintf("%07d",m) ;
        } else {
            out = out sep ids[i] ;
        }
    }
    out = substr(out,1+length(sep));
    if(LD)DETAIL("expand ["s"] = ["out"]");
    return out;
}
function short_year(y,\
ret) {
    if (y != "" && length(y) == 4 ) ret = sprintf("%x",y-1900);
    return ret;
}

function long_year(y,\
ret) {

    if (y != "" && length(y) < 4 ) ret = hex2dec(y)+1900;
    return ret;
}

function short_genre(g) {
    return convert_genre(g,g_genre_long2short);
}

function long_genre(g) {
    return convert_genre(g,g_genre_short2long);
}

function convert_genre(g,genre_map,\
i) {
    genre_init();
    for(i in genre_map) {
        if (match(g,i) ) {
           g = substr(g,1,RSTART-1) genre_map[i] substr(g,RSTART+RLENGTH); 
       }
    }
    gsub(/[- /,|]+/,"|",g);
    gsub(/^[|]/,"",g);
    gsub(/[|]$/,"",g);
    return g;
}

function genre_init(\
gnames,i) {
    
    if (!g_genre_count) {
        g_genre_count = split(g_settings["catalog_genre"],gnames,",");
    }
    for(i = 1 ; i <= g_genre_count ; i += 2) {
        g_genre_long2short["\\<"gnames[i]"o?\\>"] = gnames[i+1];
        g_genre_short2long["\\<"gnames[i+1]"\\>"] = gnames[i];
    }

}

