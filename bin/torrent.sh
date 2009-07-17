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
    new_outer_path="`get_outer_seeding_path "$1"`"
    
    if [ "$outer_path" -ef "$new_outer_path" ] ; then
    	echo "[$1:$name] Already moved"
    else
    
        # Very unlikely but check the seeding path doesnt already exist
        # if we are creating a new folder 
        if [ -z "`bt_get_inner_folder_name "$1"`" ] ; then
    	    if [ -e "$new_outer_path" ] ; then
    	        new_outer_path="${new_outer_path}/`date +%u`"
    	    fi
            mkdir -p "$new_outer_path"
        fi
        
        echo "$1:$name :"
        echo "   DEST is [$new_outer_path]"
        echo "   PARENT is [$outer_path]"
        echo "   ROOT is [`get_inner_path "$1"`]"

        bt_move_torrent "$1" "$new_outer_path"

        echo Moved
    fi

    new_inner_path="`get_inner_path "$1"`" 

    echo "   DEST is [$new_outer_path]"
    echo "   PARENT is [`bt_get_outer_path "$1"`]"
    echo "   ROOT is [$new_inner_path]"

    bt_list_completed_files "$1" > "$new_inner_path/unpak_files.txt"

    ( cd "$new_outer_path" && "$unpak" torrent_seeding "$new_inner_path" "$new_inner_path/unpak_files.txt" )

}

unpak_all() {
    max_downloading_count=2
    max_seeding_count=1
    seed_ratio=1.0

    manage_queue "$max_downloading_count" "$max_seeding_count" "$seed_ratio"

    for i in `list_newly_completed_torrents` ; do
        unpak_index_torrent "$i"
    done
}



# Get the list of completed torrents that are  still in the Download folder
list_newly_completed_torrents() {
    for t in `bt_list_completed_torrents` ; do
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

active_seeding_count() {
    bt_list_active_seeding_torrents | count_lines
}

downloading_count() {
    bt_list_downloading_torrents | count_lines
}

active_torrent_count() {
    $(( `active_seeding_count` + `downloading_count` ))
}

# $1 = downloding count
# $2 = seeding count
# $3 = global seed ratio
manage_queue() {

    incomplete_torrents="`bt_list_incomplete_stopped_torrents`"

    start_torrent_id=`echo $incomplete_torrents | awk '{ print $1}'`

    #Set ratio
    if [ -n "$3" ] ; then
        bt_set_global_seed_ratio_live "$3"
    fi

    #Check seeding count
    seeding="`active_seeding_count`"
    if [ "$seeding" -gt "$2" ] ; then
        # queue is full - look for first seeding torrent and stop it
        #this can be more intelligent later
        for tid in `bt_list_active_seeding_torrents` ; do
            if [ "$seeding" -gt "$2" ] ; then
                bt_stop_torrent "$tid" || true
                seeding=$(( $seeding - 1 ))
            fi
        done
    fi

    #Stop excess downloading torrents
    downloading=`downloading_count`
    if [ "$downloading" -gt "$1" ] ; then
        for tid in `bt_list_downloading_torrents` ; do
            if [ "$downloading" -gt "$1" ] ; then
                bt_stop_torrent "$tid" || true
                downloading=$(( $downloading - 1 ))
            fi
        done
    fi

    # Start up any stopped torrents
    if [ "$downloading" -lt "$1" ] ; then
        for tid in `bt_list_incomplete_stopped_torrents` ; do
            if [ "$downloading" -lt "$1" ] ; then
                bt_start_torrent "$tid" || true
                downloading=$(( $downloading + 1 ))
            fi
        done
    fi
}

# $1 = total bandwidth available kbytes
# $2 = bandwidth per slot required kbytes
calc_upload_slots_kbytes() {
    active_torrents=`active_torrent_count`
    if [ "$active_torrents" -ne 0 ] ; then
        bw_per_torrent=$(( $1 / $active_torrents ))
        slots_per_torrent=$(( $bw_per_torrent / $2 ))
        echo $slots_per_torrent
    fi
}

# Set uploads using Azuerus recommendations
# $1 = total bandwidth kbytes
calc_upload_slots_standard() {
    active_torrents=`active_torrent_count`
    if [ "$active_torrents" -ne 0 ] ; then
        slots_per_torrent=$(( $1 / $active_torrents / 5 ))
        echo $slots_per_torrent
    fi
}

set_nmt_settings() {
    slots_per_torrent="`calc_upload_slots_kbytes 80 10`"
    bt_shutdown
    echo "slots_per_torrent=$slots_per_torrent"
    bt_set_global_seed_ratio 1.0
    g_global_peers=100
    g_active_count=2
    bt_set_peers_global $g_global_peers
    bt_set_peers_per_torrent $(( $g_global_peers / $g_active_count ))
    bt_set_upload_slots_per_torrent $slots_per_torrent
    bt_startup
}

show_methods() {
    clients="transmission"
    cat <<HERE

    $0 $clients method args

== MAIN ENTRY POINT ===

$0 $clients unpak_all                     | Do the primary function of unpaking all completed torrents.

== core methods ==

For each different torrent client the following 6 funtions must be written.
The function name should begin with "bt_" eg
bt__get_name() { ...}

$0 $clients bt_get_name <id>              | name of the torrent with id <id>
$0 $clients bt_list_completed_torrents    | list ids of all completed torrents
$0 $clients bt_get_outer_path <id>        | the current system folder that contains the torrent
$0 $clients bt_get_inner_folder_name <id> | Get the name of the root folder INSIDE the torrent that contains ALL files - otherwise blank
$0 $clients bt_move_torrent <id>          | move a torrent but keep seeding it.
$0 $clients bt_completed_files <id>       | list all completed files relative to inner path
$0 $clients bt_list_incomplete_stopped_torrents 
$0 $clients bt_list_downloading_torrents 
$0 $clients bt_list_active_seeding_torrents 
$0 $clients bt_list_incomplete_torrents  
$0 $clients bt_startup  
$0 $clients bt_shutdown  
$0 $clients bt_start_torrent <id>  
$0 $clients bt_stop_torrent <id>  
$0 $clients bt_set_upload_slots_per_torrent
$0 $clients bt_set_peers_per_torrent
$0 $clients bt_set_peers_global

== depedent methods ==

   - these use the core methods. so do not need client specific inplementations

$0 $clients get_inner_path <id>        | Get the path to the folder that contains all torrent files.
$0 $clients list_newly_completed_torrents | get ids of torrents that are completed but still in download folder
$0 $clients unpak_index_torrent <id>      | unpak and index a torrent - calls unpak/catalog
$0 $clients get_outer_seeding_path <id>   | Get folder where torrent should be seeded from
$0 $clients downloading_count
$0 $clients calc_upload_slots_standard totalkbytes | Set slot bw using azureus formula
$0 $clients calc_upload_slots_kbytes totalkbytes slotkbytes | Set slot bw using absolute formula
$0 $clients manage_queue <max downloading> <max seeding> <seed ratio>    | Cant believe transmission doesnt have a queue

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



