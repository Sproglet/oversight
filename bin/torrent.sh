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
    
    name="`get_name "$1"`"
    outer_path="`get_outer_path "$1"`"
    dest="`get_outer_seeding_path "$1"`"
    
    if [ "$outer_path" -ef "$dest" ] ; then
    	echo "[$1:$name] Already moved"
    else
    
        # Very unlikely but check the seeding path doesnt already exist
        # if we are breating a new folder 
        if [ -n "`get_inner_folder_name "$1"`" ] ; then
    	    if [ -e "$dest" ] ; then
    	        dest="${dest}`date +%u`"
    	    fi
            mkdir -p "$dest"
        fi
        
        echo "$1:$name :"
        echo "   DEST is [$dest]"
        echo "   PARENT is [$outer_path]"
        echo "   ROOT is [`get_inner_path "$1"`]"

        move_torrent "$1" "$dest"

        echo Moved
    fi

    new_inner_path="`get_inner_path "$1"`" 

    echo "   DEST is [$dest]"
    echo "   PARENT is [`get_outer_path "$1"`]"
    echo "   ROOT is [$new_inner_path]"

    completed_files "$1" > "$new_inner_path/unpak_files.txt"
    $unpak torrent_seeding "$new_inner_path" "$new_inner_path/unpak_files.txt"
}

unpak_all() {
    for i in `newly_completed_torrents` ; do
        unpak_index_torrent "$i"
    done
}



# Get the list of completed torrents that are  still in the Download folder
newly_completed_torrents() {
    for t in `completed_torrents` ; do
        d=`get_outer_path "$t"`
        if [ "$d" -ef "$download_dir" ] ; then
            echo $t
        fi
    done
}

#If a torrent has its own folder then use seed_dir else create a folder for it
get_outer_seeding_path() {

    if [ -n "`get_inner_folder_name "$1"`" ] ; then
        echo "$seed_dir"
    else
        echo "$seed_dir/bt_`get_name "$1"`"
    fi
}

# Get full path to torrent inner folder
get_inner_path() {
    echo "`get_outer_path "$1"`/`get_inner_folder_name "$1"`"
}

count_lines() {
    awk 'END { print NR; }'
}


#==========================================================================
# Transmission functions
#==========================================================================
# Return list of completed torrent ids
tr_remote=/share/Apps/Transmission/bin/transmission-remote
transmission_completed_torrents() {
    "$tr_remote" -l | awk '$2 == "100%" { print $1 }';
}

# return the location folder that contains the torrent.
# This is not part of the torrent structure
transmission_get_location_path() {
    "$tr_remote" -t $1 -i |\
    awk '$1 == "Location:" { sub(/^[^\/]+/,"") ; print $0; }'
}

# Return the name of the root folder *within* the torrent.
# if the torrent has no root folder this is blank.
transmission_get_inner_folder_name() {
    "$tr_remote" -t $1 -f |\
    awk '
# Pattern to match each file line in the torrent.
# Check ALL files have the same top level path.
$1 ~ "^[0-9]+:$" {

    # Get the path to the file
    $1 = $2 = $3 = $4 = $5 = $6 = "";
    sub(/^ +/,"",$0) ;  # Trim
    
    # Remove sub path and filename
    if (sub(/\/.*/,"",$0) == 0) {
    	$0="";
    }
    path=$0;

    if (path == "" ) {
        inner_folder="";
        exit;
    } else if ( inner_folder == "" ) {
        inner_folder = path;
    } else if (inner_folder != path ) {
        # Multiple top level folders found
        inner_folder="";
        exit;
    }
}

END {
    if (inner_folder != "") print inner_folder;
}
'
}

# List all files that are completed. This information is useful to
# when unpacking torrents where not all files have been downloaded.
#
# The file names listed must be relative to the inner root folder
# of of the #torrent
transmission_completed_files() {
    inner_root="`get_inner_folder_name $1`";

    "$tr_remote" -t $1 -f | awk '
BEGIN {
    inner_root="'"$inner_root"'";
    inner_root_len=length(inner_root);
}

$1 ~ "^[0-9]+:$" && $2 == "100%" {
    # Get the path to the file
    $1 = $2 = $3 = $4 = $5 = $6 = "";
    sub(/^ +/,"",$0) ;  # Trim
    $0 = substr($0,inner_root_len+1);
    sub(/^\//,"",$0); #remove leading slash
    print $0 ;
}'
}
transmission_move_torrent() {
    "$tr_remote" -t $1 --move "$2"
}
transmission_get_name() {
    "$tr_remote" -l | awk '
NR == 1 {
    namePos=index($0,"Name");
    next;
}

$1 == "'$1'" {
    print substr($0,namePos);
}'
}
#==========================================================================
# CTorrent functions
#==========================================================================
# Return list of completed torrent ids
ctorrent_completed_torrents() {
    echo
}
# return the location folder that contains the torrent.
# This is not part of the torrent structure
ctorrent_get_location_path() {
    echo
}
# Return the sub paths of all folders *inside* the torrent.
# if the torrent has no inner folders this is blank.
ctorrent_get_inner_folder_name() {
    echo
}

# List all files that are completed. This information is useful to
# when unpacking torrents where not all files have been downloaded.
#
# The file names listed must be relative to the inner root folder
# of of the #torrent
ctorrent_completed_files() {
    echo
}
# IN $1=id $2=outer destination
ctorrent_move_torrent() {
    echo
}
# IN $1=id
ctorrent_get_name() {
    echo
}
#==========================================================================
# Generic torrent functions
#==========================================================================
# Return list of completed torrent ids
completed_torrents() {
    ${g_torrent_app}_completed_torrents "$@"
}

# return the location folder that contains the torrent.
# This is not part of the torrent structure
get_outer_path() {
    ${g_torrent_app}_get_location_path "$1"
}

# Return the name of the main folder *within* the torrent.
# if the torrent has any files without a folder this is blank.
get_inner_folder_name() {
    ${g_torrent_app}_get_inner_folder_name "$1"
}
# List all files that are completed. This information is useful to
# when unpacking torrents where not all files have been downloaded.
#
# The file names listed must be relative to the inner root folder
# of of the #torrent
completed_files() {
    ${g_torrent_app}_completed_files "$1"
}
move_torrent() {
    ${g_torrent_app}_move_torrent "$1" "$2"
}
get_name() {
    ${g_torrent_app}_get_name "$1"
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

    $0 $clients get_name <id>
        # name of the torrent with id <id>

    $0 $clients completed_torrents
        # list ids of all completed torrents

    $0 $clients get_outer_path <id>
        # the current folder that contains the torrent - but not in the torrent eg /share/Download

    $0 $clients get_inner_folder_name <id>
        # Get the name of the root folder INSIDE the torrent that contains ALL files - otherwise blank

    $0 $clients move_torrent <id>
        # move a torrent but keep seeding it.

    $0 $clients completed_files <id>
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

HERE
exit 1;
}


case "${1:-}" in
    "")
        show_methods
        exit 1
        ;;
    transmission|ctorrent) 
        g_torrent_app="$1"
        shift
        case "${1:-}" in
            "")
                show_methods
                ;;
            *) g_entry="$1"
                shift
                "$g_entry" "$@"
                ;;
        esac
        ;;
esac



