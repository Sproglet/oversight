#==========================================================================
# CTorrent functions
#==========================================================================
# Return list of completed torrent ids
bt_list_completed_torrents() {
    echo
}
# Return list of active torrent ids
bt_list_active_torrents() {
    echo
}
# return the location folder that contains the torrent.
# This is not part of the torrent structure
bt_get_location_path() {
    echo
}
# Return the sub paths of all folders *inside* the torrent.
# if the torrent has no inner folders this is blank.
bt_get_inner_folder_name() {
    echo
}

# List all files that are completed. This information is useful to
# when unpacking torrents where not all files have been downloaded.
#
# The file names listed must be relative to the inner root folder
# of of the #torrent
bt_completed_files() {
    echo
}
# IN $1=id $2=outer destination
bt_move_torrent() {
    echo
}
# IN $1=id
bt_get_name() {
    echo
}

bt_set_upload_slots_per_torrent() {
}
