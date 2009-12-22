#!/bin/sh
#Convert date formats

convert() {
        awk '

function bin(t,\
r,b,i) {

    r="";
    b=1;
    for(i = 1 ; i <= 32 ; i++ ) {
        r= (and(t,b) > 0) r ;
        b = lshift(b,1);
        if (i%8 == 0) r = " "r;
    }
    if (r == "") r = 0;
    return r;
}

function hex2dec(t,\
i,h) {
    i = 0;
    for(i = 1 ; i <= length(t) ; i++ ) {
        h *= 16;
        h += index("123456789abcdef",tolower(substr(t,i,1)));
    }
    return h;
}

# convert yyyymmddHHMMSS to bitwise yyyyyy yyyymmmm dddddhhh hhmmmmmm
function longtime(t,\
y,m,d,hr,mn,r) {
    if (t != "") {
        t = hex2dec(t);
        mn = and(t,63);
        hr = and(rshift(t,6),31);
        d = and(rshift(t,11),31);
        m = and(rshift(t,16),15);
        y = and(rshift(t,20),1023)+1900;
        print y,m,d,hr,mn
        r = sprintf("%04d%02d%02d%02d%02d",y,m,d,hr,mn);
    }
    return r;
}

function shorttime(t,\
y,m,d,hr,mn,r) {
    if (t != "") {

        y = 0+substr(t,1,4)-1900;
        m = 0+substr(t,5,2);
        d = 0+substr(t,7,2);
        hr = 0+substr(t,9,2);
        mn = 0+substr(t,11,2);

        r = lshift(lshift(lshift(lshift(and(y,1023),4)+m,5)+d,5)+hr,6)+mn;
        r= sprintf("%x",r);
    }
    return r;
}

END {
    gdate="'"$1"'";
    if (length(gdate) <= 8 ) {
        print gdate "=" longtime(gdate);
    } else {
        print gdate "=" shorttime(gdate);
    }
}
' </dev/null
}

if [ -z "$1" ] ; then
    cat <<HERE
convert date formats:

    $0 yyyymmddHHMM  output hhhhhh

    or 
    $0 hhhhhh  output yyyymmddHHMM
HERE
    exit 1
fi


convert "$1"
# vi:syntax=awk:sw=4:et:ts=4
