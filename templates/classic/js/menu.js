// $Id:$
var title = document.getElementById('menutitle').firstChild;
var watchedNode = document.getElementById('watchedtotal').firstChild;
var unwatchedNode = document.getElementById('unwatchedtotal').firstChild;

var g_idlist = '';
var g_title = '';

function ovs_delist() {
    if (g_idlist) {
        if (confirm("Delist "+g_title+"?")) {
            action('delist');
        }
    }
}
function ovs_delete() {
    if (g_idlist) {
        if (confirm("Delete files for "+g_title+" ?")) {
            action('delete');
        }
    }
}
function ovs_watched() {
    if (g_idlist) {
        //if (confirm("Mark "+g_title+" as watched?")) {
            action('watch');
        //}
    }
}
function ovs_unwatched() {
    if (g_idlist) {
        //if (confirm("Mark "+g_title+"as NOT watched?")) {
            action('unwatch');
        //}
    }
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

function showt(title_text,idlist,unwatched,watched)
{
   if (idlist != '') g_idlist = idlist;
   g_title = title_text;
   if (unwatched == '-' ) {
       title.nodeValue = g_title;
       watchedNode.nodeValue = '';
       unwatchedNode.nodeValue = '';
    } else if (unwatched > 0 ) {
       title.nodeValue = '';
       watchedNode.nodeValue = '';
       unwatchedNode.nodeValue = g_title;
    } else {
       title.nodeValue = ' ';
       watchedNode.nodeValue = g_title;
       unwatchedNode.nodeValue = ' ';
    }
}

function title0() { showt('.','','',''); }
