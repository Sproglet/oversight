#!/bin/sh
#
# At time of writing there is no API to get entire list of shows from TVDB.
#
# This script downloads all shows that start with the given ascii letter/numeral - or 'all' to donwload all.
# It will only download the index if it is older than a certain age (default 30 days).
#
# The indexes are used to search for various abbreviations and close matches.

EXE=$0
while [ -h "$EXE" ] ; do EXE="$(readlink "$EXE")"; done
DIR="$( cd "$( dirname "$EXE" )" && pwd )"

. $DIR/ovsenv

refresh_age=30

all_roman="A B C D E F G H I J K L M N O P Q R S T U V W X Y Z 0 1 2 3 4 5 6 7 8 9"

if [ "x$1" = "x-older" ] ; then
    shift
    refresh_age="$1"
    shift
fi

if [ -z "$1" ] ; then
    echo "ussage [-older days] $0 [all] - fetch TV shows starting with the given letter/number - or 'all' for all shows"
    exit 1
fi

case "$1" in
    all) items="$all_roman";;
    *) items="$@";;
esac



items="`echo "$items" | $TR a-z A-Z`"

ext=list
for i in $items ; do
    output="$DIR/catalog/tvdb/tvdb-$i.$ext"

    if find "$output" -mtime -$refresh_age | grep -q $ext && [ -s "$output" ] ; then
        true
        #echo $i is up to date
    else
        echo updating index $i
        zip="--header=accept-encoding: gzip"
        wget "$zip" -q -c -O - "http://thetvdb.com/?string=$i&searchseriesid=&tab=listseries&function=Search" |\
        gunzip -c |\
        sed -rn "s/.*tab=series.amp;id=([0-9]+).amp.lid=[0-9]+.>($i[^<]+).*/\1:\2/p" |\
        sort -u > "$output.tmp" && mv "$output.tmp" "$output"
    fi
done
