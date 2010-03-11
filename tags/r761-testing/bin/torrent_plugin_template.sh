#==========================================================================
# Generic torrent plugin template.
# If supporting new clients copy this file and inplement the functions
#==========================================================================
# Return newline separated list of completed torrent ids
bt_list_completed_torrents() {

}

# Return newline separated list of active torrent ids
bt_list_active_torrents() {

}

# return the location folder that contains the torrent.
# This is not part of the torrent structure
# $1 = torrent id
bt_get_outer_path() {

}

# Return the name of the main folder *within* the torrent.
# if the torrent has any files without a folder this is blank.
# $1 = torrent id
bt_get_inner_folder_name() {
}
# List all files that are completed. This information is useful to
# when unpacking torrents where not all files have been downloaded.
#
# The file names listed must be relative to the inner root folder
# of of the #torrent
# $1 = torrent id
bt_completed_files() {
}
# $1 = torrent id
# $2 = new location
bt_move_torrent() {
}

# $1 = torrent id
bt_get_name() {
}

#Set an arbitrary option on this client
bt_set_option() {
}

# set upload slots per torrent - use bt_set_option
bt_set_upload_slots_per_torrent() {

}

bt_start() {

}

bt_stop() {

}

