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
		if (confirm("Delete files for "+g_title+"?")) {
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


// Deperecated function so external skins will work
// New skins should call ovs_menu directly
function showt(title_text,idlist,unwatched,watched)
{
    var item = {
        title:title_text,
        idlist:idlist,
        unwatched:unwatched,
        watched:watched
    };
    ovs_menu(item);
}

function ovs_menu(menu)
{
    var watched = menu["watched"];
    var unwatched = menu["unwatched"];

   // Set global values for mark and delist functions
   if (menu["idlist"] != '') {
       g_idlist = menu["idlist"];
   }
   g_title = menu["title"];

   // To get multi-colour text is displated in different cells
   // depending on watched/unwatched count.
   var title_text = "";
   var watched_text = '';
   var unwatched_text = '';

   if (unwatched == '-' ) {
       // Neutral colour
       title_text = g_title;

    } else if (unwatched > 0 ) {
       // Unwatched colour - default green
       unwatched_text = g_title;
    } else {
       // watched colour - default red
       watched_text = g_title;
    }

   // Set cell values
    title.nodeValue = title_text;
    watchedNode.nodeValue = watched_text;
    unwatchedNode.nodeValue = unwatched_text;
}

function title0() { ovs_menu({title:'.',idlist:'',unwatched:'',watched:''}); }
