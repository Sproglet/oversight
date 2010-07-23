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
		if (confirm("Are you sure you want to DELETE the FILES for "+g_title+"?")) {
	          action('delete');
	     }
   	}
}

function ovs_watched() {
    if (g_idlist) {
    	action('watch');
    }
}

function ovs_unwatched() {
    if (g_idlist) {
    	action('unwatch');
    }
}
function ovs_lock() {
    if (g_idlist) {	        
          action('lock');
   	}
}
function ovs_unlock() {
    if (g_idlist) {	        
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

function getPixelsFromTop(obj){
	var objFromTop = obj.offsetTop;
	while(obj.offsetParent!=null) {
		var objParent = obj.offsetParent;
		objFromTop += objParent.offsetTop;
		var obj = objParent;
	}
	return objFromTop;
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
