// $Id:$
var g_idlist='';
var titlecell = document.getElementById('tvplot').firstChild;
var genrecell = document.getElementById('genre').firstChild;
var g_epno='';
var g_info='';

function ovs_del() {
    if (g_epno != '') {
        if (confirm("Remove ["+g_epno+"]?")) {
            if (confirm("Also Delete "+g_info)) {
                if(confirm("Deleting media files") ) {
                    action('delete');
                }
            } else {
                action('delist');
            }
        }
    }
}
function ovs_info() {
    alert(g_info);
}
function ovs_watched() {
    if (g_epno != '') {
        //if (confirm("Mark episode "+g_epno+"\n as watched?")) {
            action('watch');
        //}
    }
}

function ovs_unwatched() {
    if (g_epno != '') {
        //if (confirm("Mark episode"+g_epno+"\nas NOT watched?")) {
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
function show(idlist,epno,plot_text,info,eptitle)
{
    g_idlist = idlist;
    g_epno = epno;
    g_info = info;
    titlecell.nodeValue = plot_text;
    if (epno != '' ) {
        genrecell.nodeValue = epno + ' : ' + eptitle;
    } else {
        genrecell.nodeValue = eptitle;
    }
}
