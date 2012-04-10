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
    echo "usage $0 [-older days] [all] - fetch TV shows starting with the given letter/number - or 'all' for all shows"
    exit 1
fi

case "$1" in
    all) items="$all_roman";;
    *) items="$@";;
esac


letter_path() {
    echo "$DIR/catalog/tvdb/tvdb-$1.$ext"
}

update() {
    local letter=$1;

    local output="`letter_path $letter`"

    if find "$output" -mtime -$refresh_age | grep -q $ext && [ -s "$output" ] ; then
        false
        #echo $letter is up to date
    else
        echo updating index $letter
        local zip="--header=accept-encoding: gzip"
        wget "$zip" -q -c -O - "http://thetvdb.com/?string=$letter&searchseriesid=&tab=listseries&function=Search" |\
        gunzip -c |\
        sed -rn "s/.*tab=series.amp;id=([0-9]+).amp.lid=[0-9]+.>($letter[^<]+).*/\1:\2/p" > "$output.tmp" &&\
        mv "$output.tmp" "$output" &&\
        sort_index $letter
        true
    fi
}

merge() {
    local letter="$1"
    local prefix="$2"
    local words="$3"

    if [ $letter != $prefix ] ; then
        input="`letter_path $prefix`"
        output="`letter_path $letter`"
        if egrep "^[0-9]*:($3) $letter" "$input" >> "$output" ; then
            #echo merged $prefix into $letter
            #echo "adding $prefix $input to $letter $output "
            #egrep "^[0-9]*:($3) $letter" "$input" 
            sort_index "$letter"
        fi
    fi
}

sort_index() {
    local input="`letter_path $1`"
    sort -u "$input" > "$input.tmp" && mv "$input.tmp" "$input"
}

mergeall() {
    merge $1 A 'A|An|As' 
    merge $1 E 'Ein(|ne[rsmn]?)' 
    merge $1 D 'Des' 
    merge $1 I 'I|Il'
    merge $1 O 'O|Os' 
    merge $1 T The 
    merge $1 U 'Un|Una|Unos|Unas|Um|Uma|Uns|Umas|Une' 
    sort_index $1
}

items="`echo "$items" | tr a-z A-Z`"

ext=list

do_short_words=0
for i in $items ; do
    if update $i ; then
        do_short_words=1
    fi
done

shorts="T A D E I O U"

if [ $do_short_words = 1 ] ; then
    # Get all series that begin with prepositions or articles and merge into main list.
    # eg "The Walking Dead" should be merged into the 'W' list, as people might call it "Walking Dead"
    for x in $shorts ; do
        case "$items" in
            *$x*) ;;
            *) update $x || true 
        esac
    done
    echo "Merging prefixes for [$items]"
    for i in $items ; do
        mergeall $i
    done

    # restore short files
    echo "Merging prefixes for [$shorts]"
    for i in $shorts ; do
        case "$items" in
            *$i*) ;;
            *) mergeall $i ;;
        esac
    done
fi
