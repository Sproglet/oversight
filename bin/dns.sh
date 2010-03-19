#!/bin/sh
# $Id$
#
# NMT dns lookups in wget take a LONG time with some servers. (30 seconds)
# This looks like some kind of reverse DNS lookup issue within wget.
#
# NMT have coded around this by caching data in /tmp/dns_cache
# this is a binary file. format
# <gross record length:1 byte><ip address:4 bytes><domain:nul terminated string>
#
# Simplest approach is to provide a button for the user to reseed this file.
# The button runs this script!
# 
# note wget may follow http redirects so its not enough to just use nslookup etc.
#
# This script will be called by oversight actions.c
#

d=/share/Apps/oversight

get_domains() {
    awk  '
    {   s="YYWW" ;
        gsub(/[a-z][a-z0-9.]+\.(com|org|[a-z][a-z])\>/,s"&"s) ;
        j=split($0,p,s) ;
        for(i=2;i<j;i+=2) h[p[i]]=1;
    }
    END {
        for(d in h) if (d !~ ".(sh|db)$") print d;
    } ' "$d/catalog.sh"
}

w() {
    mkdir -p "$d/logs/dns"
    for site in "$@" ; do
        log="$d/logs/dns/wget.$site.log" 
        wget "http://$site" -O /dev/null -S -o "$log" 2>/dev/null
    done
}

#get_domains ; exit 0
rm -f /tmp/dns_cache
w `get_domains`

