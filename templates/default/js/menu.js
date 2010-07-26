// $Id:$
var title = ovs_util_getcell('menutitle');
var watchedNode = ovs_util_getcell('watchedtotal');
var unwatchedNode = ovs_util_getcell('unwatchedtotal');

var g_idlist = '';
var g_title = '';

function ovs_delist() {
    ovs_util_action('delist',g_idlist,"Delist "+g_title+"?");
}

function ovs_delete() {
    ovs_util_action('delete',g_idlist,"Delete files for "+g_title+"?");
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
