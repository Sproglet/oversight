// $Id:$
var titleNode = ovs_util_getcell('menutitle');
var watchedNode = ovs_util_getcell('watchedtotal');
var unwatchedNode = ovs_util_getcell('unwatchedtotal');

var g_item;
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

// This is called when the focus moves away from a grid media item
function ovs_menu_clear() {
    ovs_menu( { } );
}

// This is called when the focus on to a grid media item
function ovs_menu(menu)
{
    g_item = menu;
    var title = '';
    var watched = menu["watched"];
    var unwatched = menu["unwatched"];

   // To get multi-colour text is displated in different cells
   // depending on watched/unwatched count.
   var title_text = ovs_nbsp();
   var watched_text = '';
   var unwatched_text = '';

   if (menu["title"]) {
       title = menu["title"];
       if (menu["view"] == "tvboxset" ) {

           title = title + " - [ Boxset - "+menu["num_seasons"] + " seasons ]";

       } else if (menu["view"] == "movieboxset" ) {

           title = title + "- [ Boxset - "+menu["count"] + " movies ]";

       } else if (menu["view"] == "tv" ) {

           title = title + " - Season " + menu["season"];

       } else if (menu["view"] == "movie" ) {

           title = title + " - " + menu["cert"] + " (" + menu["year"] + ")";

       }

       var show_movie_watch_state = 1;

       if (!show_movie_watch_state && menu["view"] && menu["view"].indexOf("movie") >= 0 ) {
           // Neutral colour
           title_text = title;

        } else if (unwatched > 0 ) {
           // Unwatched colour - default green
           unwatched_text = title;
        } else {
           // watched colour - default red
           watched_text = title;
        }
    }

   // Set global values for mark and delist functions
   g_idlist = menu["idlist"];
   g_title = title;

   // Set cell values
    titleNode.firstChild.nodeValue = title_text;
    watchedNode.firstChild.nodeValue = watched_text;
    unwatchedNode.firstChild.nodeValue = unwatched_text;
}

function title0() { ovs_menu({title:'.',idlist:'',unwatched:'',watched:''}); }
