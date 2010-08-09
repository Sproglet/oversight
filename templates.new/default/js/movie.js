// $Id:$

// g_idlist and g_title are set by the movie_listing code in oversight
var g_info='';

function ovs_delist() {   
    ovs_util_action('delist',g_idlist,"Delist "+g_title+"?");
}

function ovs_delete() {   
    ovs_util_action('delete',g_idlist,"Delete files for "+g_title+"?");
}

function set_info(info) {
    g_info=info;
}

function ovs_info() {
    alert(g_info);
}

function ovs_watched() {
    ovs_util_action('watch',g_idlist);
}

function ovs_unwatched() {
    ovs_util_action('unwatch',g_idlist);
}
function ovs_lock() {
    ovs_util_action('lock',g_idlist);
}
function ovs_unlock() {
    ovs_util_action('unlock',g_idlist);
}
