// $Id:$
var g_idlist='';
var titlecell = document.getElementById('tvplot').firstChild;
var genrecell = document.getElementById('genre').firstChild;
var g_epno='';
var g_info='';

function ovs_delist() {
    if (g_epno != '') {
        if (confirm("Delist ["+g_epno+"]?")) {
            action('delist');
        }
    }
}
function ovs_delete() {
    if (g_epno != '') {
        if (confirm("Delete files for episode "+g_epno+"?")) {
            action('delete');
        }
    }
}
function ovs_info() {
    alert(g_info);
}
function ovs_watched() {
    if (g_epno != '') {
        action('watch');
    }
}

function ovs_unwatched() {
    if (g_epno != '') {
        action('unwatch');
    }
}
function ovs_lock() {
    if (g_epno != '') {
          action('lock');
   	}
}
function ovs_unlock() {
    if (g_epno != '') {
          action('unlock');
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

function showep(ep)
{
    g_idlist = ep["idlist"];
    g_epno = ep["episode"];
    g_info = ep["info"];
    var eptitle = ep["title"];

    if (epno != '' ) {
        genrecell.nodeValue = g_epno + ' : ' + eptitle;
    } else {
        genrecell.nodeValue = eptitle;
    }
    titlecell.nodeValue = ep["plot_text"];
}

// deprecated function - use ovs_ep directly
function show(idlist,epno,plot_text,info,eptitle)
{
    ovs_ep( { idlist:idlist , episode:epno , plot:plot_text , info:info , title:eptitle } );
}
