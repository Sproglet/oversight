#!/bin/sh -eu
# $Id$ 

download_dir=/share/Download
seed_dir=/share/Complete
unpak=/share/Apps/oversight/unpak.sh

# IN $1=torrent id
unpak_index_torrent() {

    # If the torrent does not have folders then a folder is created
    # for it when it is moved (see get_outer_seeding_path )
    # so when the new_inner_path is computed after moving it can 
    # be passed directly to unpak.sh
    
    name="`bt_get_name "$1"`"
    outer_path="`bt_get_outer_path "$1"`"
    dest="`get_outer_seeding_path "$1"`"
    
    if [ "$outer_path" -ef "$dest" ] ; then
    	echo "[$1:$name] Already moved"
    else
    
        # Very unlikely but check the seeding path doesnt already exist
        # if we are breating a new folder 
        if [ -n "`bt_get_inner_folder_name "$1"`" ] ; then
    	    if [ -e "$dest" ] ; then
    	        dest="${dest}`date +%u`"
    	    fi
            mkdir -p "$dest"
        fi
        
        echo "$1:$name :"
        echo "   DEST is [$dest]"
        echo "   PARENT is [$outer_path]"
        echo "   ROOT is [`get_inner_path "$1"`]"

        bt_move_torrent "$1" "$dest"

        echo Moved
    fi

    new_inner_path="`get_inner_path "$1"`" 

    echo "   DEST is [$dest]"
    echo "   PARENT is [`bt_get_outer_path "$1"`]"
    echo "   ROOT is [$new_inner_path]"

    bt_completed_files "$1" > "$new_inner_path/unpak_files.txt"
    $unpak torrent_seeding "$new_inner_path" "$new_inner_path/unpak_files.txt"
}

unpak_all() {
    for i in `newly_completed_torrents` ; do
        unpak_index_torrent "$i"
    done
}



# Get the list of completed torrents that are  still in the Download folder
newly_completed_torrents() {
    for t in `bt_completed_torrents` ; do
        d=`bt_get_outer_path "$t"`
        if [ "$d" -ef "$download_dir" ] ; then
            echo $t
        fi
    done
}

#If a torrent has its own folder then use seed_dir else create a folder for it
get_outer_seeding_path() {

    if [ -n "`bt_get_inner_folder_name "$1"`" ] ; then
        echo "$seed_dir"
    else
        echo "$seed_dir/bt_`bt_get_name "$1"`"
    fi
}

# Get full path to torrent inner folder
get_inner_path() {
    echo "`bt_get_outer_path "$1"`/`bt_get_inner_folder_name "$1"`"
}

count_lines() {
    awk 'END { print NR; }'
}

active_torrent_count() {
    bt_list_active_torrents | count_lines
}

# $1 = total bandwidth available kbytes
# $2 = bandwidth per slot required kbytes
set_upload_slots_kbytes() {
    echo 1111
    active_torrents=`active_torrent_count`
    echo 2222
    if [ "$active_torrents" -ne 0 ] ; then
        bw_per_torrent=$(( $1 / $active_torrents ))
        slots_per_torrent=$(( $bw_per_torrent / $2 ))
        bt_set_upload_slots_per_torrent $slots_per_torrent
    fi
}

# Set uploads using Azuerus recommendations
# $1 = total bandwidth kbytes
set_upload_slots_standard() {
    active_torrents=`active_torrent_count`
    if [ "$active_torrents" -ne 0 ] ; then
        slots_per_torrent=$(( $1 / $active_torrents / 5 ))
        bt_set_upload_slots_per_torrent $slots_per_torrent
    fi
}

show_methods() {
    clients="transmission"
    cat <<HERE

    $0 $clients method args

== MAIN ENTRY POINT ===

    $0 $clients unpak_all 
    Do the primary function of unpaking all completed torrents.

== core methods ==

For each different torrent client the following 6 funtions must be written.
The function name must begin with the torrent client name eg
transmission_get_name() { ...}

    $0 $clients bt_get_name <id>
        # name of the torrent with id <id>

    $0 $clients bt_completed_torrents
        # list ids of all completed torrents

    $0 $clients bt_get_outer_path <id>
        # the current folder that contains the torrent - but not in the torrent eg /share/Download

    $0 $clients bt_get_inner_folder_name <id>
        # Get the name of the root folder INSIDE the torrent that contains ALL files - otherwise blank

    $0 $clients bt_move_torrent <id>
        # move a torrent but keep seeding it.

    $0 $clients bt_completed_files <id>
        # list all completed files relative to inner path

== depedent methods ==

   - these use the core methods. so do not need client specific inplementations

    $0 $clients get_inner_path <id>
        # Get the path to the folder that contains all torrent files.

    $0 $clients newly_completed_torrents
        # get ids of torrents that are completed but still in download folder

    $0 $clients unpak_index_torrent <id>
        # unpak and index a torrent - calls unpak/catalog
        
    $0 $clients get_outer_seeding_path <id>
        # Get folder where torrent should be seeded from

    $0 $clients active_torrent_count

    $0 $clients set_upload_slots_standard totalkbytes 
        # Set slot bw using azureus formula

    $0 $clients set_upload_slots_kbytes totalkbytes slotkbytes
        # Set slot bw using absolute formula

HERE
exit 1;
}


case "${1:-}" in
    transmission|ctorrent) 
        g_torrent_app="$1"
        shift
        ;;
    *)
        show_methods
        exit 1
        ;;
esac

DIRNAME() {
    if ! dirname "$1" 2>/dev/null ; then
        #Add ./ to any path that doesnt start with / or .  
        #Then find   (.)/[^/]*$ and replace with \1 
        # eg /a/b/c/d.e find c/d.e replace with c
        # then emit a/b/c
        echo "$1" | sed -r 's|^([^/.])|./\1|;s|(.)/[^/]*$|\1|'
    fi
}

. `DIRNAME $0`/torrent_plugin_$g_torrent_app.sh

case "${1:-}" in
    "")
        show_methods
        ;;
    *) g_entry="$1"
        shift
        "$g_entry" "$@"
        ;;
esac



