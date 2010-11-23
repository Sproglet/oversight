#!/bin/sh

exit
for i in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z 0  1 2 3 4 5 6 7 8 9 ; do
    wget -c -O - "http://thetvdb.com/?string=$i&searchseriesid=&tab=listseries&function=Search" |\
    sed -rn "s/.*tab=series.amp;id=([0-9]+).amp.lid=[0-9]+.>($i[^<]+).*/\1:\2/p" |\
    sort -u > tvdb-$i.list
    sleep 60
done
