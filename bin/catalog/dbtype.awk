function to_string(fieldid,v,\
type) {
    type = g_dbtype[fieldid];
    if(type == "") {
    } else if (type == g_dbtype_time) {
        v= longtime(v);
    } else if (type == g_dbtype_year) {
        if (length(v) < 4) {
            v= long_year(v);
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
    #INF("shorttime "t" = "r);
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
    INF("compress ["s"] = ["out"]");

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
    INF("expand ["s"] = ["out"]");
    return out;
}
function short_year(y,\
ret) {
    if (y != "" ) ret = sprintf("%x",y-1900);
    return ret;
}

function long_year(y,\
ret) {

    if (y != "" ) ret = hex2dec(y)+1900;
    return ret;
}

