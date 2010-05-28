// $Id:$

// g_idlist and g_title are set by the movie_listing code in oversight
var g_info='';

function ovs_delist() {
    if (confirm("Delist ["+g_title+"]?")) {
        action('delist');
    }
}
function ovs_delete() {
    if (confirm("Delete files for "+g_title+"?")) {
        action('delete');
    }
}
function set_info(info) {
    g_info=info;
}

function ovs_info() {
    alert(g_info);
}
function ovs_watched() {
    action('watch');
}

function ovs_unwatched() {
    action('unwatch');
}

function action(a) {
    var sep;
    if (window.location.href.indexOf('?') == -1 ) {
        sep='?';
    } else {
        sep = '&';
    }

    location.replace(window.location.href + sep + "action="+a+"&actionids="+g_idlist);
}
