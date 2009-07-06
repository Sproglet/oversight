#!/bin/sh -x

download_dir=/share/Download
seed_dir=/share/Complete
tr_remote=/share/Apps/Transmission/bin/transmission-remote
unpak=/share/Apps/oversight/unpak.sh

main() {
    for i in `newly_completed_torrents` ; do
        dest="`get_parent_destination $i`"
        echo "torret $i dest = $dest"

        "$tr_remote" -t $i --move "$dest"

        list_completed_files $i
        echo "DEST is [$dest]"
        echo "PARENT is [`get_parent_folder`]"
        echo "ROOT is [`get_root_folder`]"
        list_completed_files $i > "$dest/unpak_files.txt"
        ls -l "$dest"

        #$unpak torrent_seeding "$dest" "$dest/unpak_files.txt"
    done
}

list_completed_files() {
    "$tr_remote" -t $1 -f | awk '$1 ~ "^[0-9]+:$" && $2 == "100%" { sub(/[^\/]*\//,"",$0) ; print $0 ; }'
}

completed_torrents() {
    "$tr_remote" -l | awk '$2 = "100%" { print $1 }';
}

newly_completed_torrents() {
    for t in `completed_torrents` ; do
        d=`get_parent_folder "$t"`
        if [ "$d" -ef "$download_dir" ] ; then
            echo $t
        fi
    done
}

#If a torrent has its own folder then use seed_dir else create a folder for it
get_parent_destination() {
    "$tr_remote" -t $1 -f | awk '$1 ~ "^[0-9]+:$" { if ( index($0,"/") == 0) { print $0 ; exit 1;} }'
    if [ $? != 0 ] ; then
        echo "$seed_dir/torrent_$1"
    else
        echo "$seed_dir"
    fi
}

get_parent_folder() {
    "$tr_remote" -t $1 -i | awk '$1 == "Location:" { print $2; }'
}

get_local_folder_name() {
    "$tr_remote" -t $1 -f | awk '$1 ~ "^0:$" { $1 = $2 = $3 = $4 = $5 = $6 = ""; sub(/^ +/,"",$0) ; sub(/\/.*/,"",$0) ; print $0 ; }'
}

get_root_folder() {
    a="`get_parent_folder $0`"
    b="`get_local_folder_name $0`"
    echo "$a/$b"
}

main
