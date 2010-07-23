// $Id:$
var g_idlist='';
var titlecell = document.getElementById('tvplot').firstChild;
var genrecell = document.getElementById('genre').firstChild;
var episodecell = document.getElementById('episode').firstChild;
var episodedatecell = document.getElementById('epDate').firstChild;
var g_epno='';
var g_info='';

function ovs_delist() {  
    if (g_epno != '') {
		if (confirm("Delist " + g_epno + "?")) {
			action('delist');
		}
	}
}

function ovs_delete() {   
    if (g_epno != '') {
		if (confirm("Are you sure you want to DELETE the FILES for " + g_epno + "?")) {
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
