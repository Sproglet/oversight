// $Id:$

// g_idlist and g_title are set by the movie_listing code in oversight

function ovs_del() {
    if (confirm("Remove ["+g_title+"]?")) {
        if (confirm("Also delete  "+g_title+" files ?!!!")) {
            if(confirm("Deleting media files") ) {
                action('delete');
            } 
        } else {
            action('delist');
        }
    }
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
