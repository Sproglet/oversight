#==========================================================================
# Transmission functions
#==========================================================================
# Return list of completed torrent ids
tr_remote=/share/Apps/Transmission/bin/transmission-remote
bt_config=/share/Apps/Transmission/.transmission/settings.json


bt_list_completed_torrents() {
    "$tr_remote" -l | awk '$2 == "100%" { print $1 }';
}

#Return new-line separated list of active torrent ids.
bt_list_active_torrents() {
    "$tr_remote" -l | awk '
#Cant use word variables due to spaces in  ETA and Status Up & Down
#So compute column position
NR == 1 {
    statusPos=index($0,"Status");
    namePos=index($0,"Name");
    statusLen=namePos-statusPos;
    next;
}
$1 ~ "^[0-9]+$" {
    status=substr($0,statusPos,statusLen);
    if (index(status,"Seeding") || index(status,"Up")) {
        print $1;
    }
}
';
}

bt_set_global_seed_ratio() {
    #"$tr_remote" --global-seedratio "$1"
    bt_set_option "ratio-limit" "$1"
    bt_set_option "ratio-limit-enabled" true
}

bt_list_active_seeding_torrents() {
    "$tr_remote" -l | awk '$1 ~ /^[0-9]+$/ && $2 == "100%" && index($0,"Seeding") { print $1 }';
}

bt_list_incomplete_stopped_torrents() {
    "$tr_remote" -l | awk '$1 ~ /^[0-9]+$/ && $2 != "100%" && index($0,"Stopped") { print $1 }';
}

bt_list_incomplete_torrents() {
    "$tr_remote" -l | awk '$1 ~ /^[0-9]+$/ && $2 != "100%" { print $1 }';
}


# return the location folder that contains the torrent.
# This is not part of the torrent structure
bt_get_outer_path() {
    "$tr_remote" -t $1 -i |\
    awk '$1 == "Location:" { sub(/^[^\/]+/,"") ; print $0; }'
}

# Return the name of the root folder *within* the torrent.
# if the torrent has no root folder this is blank.
bt_get_inner_folder_name() {
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
bt_list_completed_files() {
    inner_root="`bt_get_inner_folder_name $1`";

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
bt_move_torrent() {
    "$tr_remote" -t $1 --move "$2"
}

bt_get_name() {
    "$tr_remote" -l | awk '
#Cant use word variables due to spaces in  ETA and Status Up & Down
#So comput column position
NR == 1 {
    namePos=index($0,"Name");
    next;
}

$1 == "'$1'" {
    print substr($0,namePos);
}'
}


# $1=option (unquoted) $2=value (including quotes if a string )
bt_set_option() {
    cp "$bt_config" "$bt_config.old" 
    awk '
BEGIN {
    key="\"'$1'\"";
    val="'$2'";
    if (val != "true" && val != false && val !~ /^[0-9]+\.?[0-9]*$/ && val !~ /^\.[0-9]+$/ ) {
        val="\""val"\"";
    }
}

index($0,key) { 
    if (sub(/:.*, *$/,": "val",",$0) ) {
        #value with comma
        changed=1;
    } else if ( sub(/:.*/,": "val) ) {
        changed=1;
    }
}

/".*" *:.*, *$/ {
    print $0;
    next;
}
# The last setting without a comma
/".*" *:/ {
    if (!changed) {
        print "  "key": "val",";
    }
}

1 # print the current line
' "$bt_config.old" > "$bt_config"
}

bt_set_upload_slots_per_torrent() {
    bt_set_option "upload-slots-per-torrent" "$1";
}
bt_set_peers_per_torrent() {
    bt_set_option "peer-limit-per-torrent" "$1";
}
bt_set_peers_global() {
    bt_set_option "peer-limit-global" "$1";
}

bt_startup() {
    TRANSMISSION_WEB_HOME=/share/Apps/Transmission/webui \
    /share/Apps/Transmission/bin/transmission-daemon \
    -g /share/Apps/Transmission/.transmission -T -w /share/Download
}

bt_shutdown() {
    kill `ps | awk '/[t]ransmission-daemon/ {print $1}'` || true
}

bt_stop_torrent() {
    echo "Stopping torrent $1"
    $tr_remote -t "$1" --stop | grep success
}
bt_start_torrent() {
    echo "Starting torrent $1"
    $tr_remote -t "$1" --start | grep success
}

