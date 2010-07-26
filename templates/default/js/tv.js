// $Id:$
var g_idlist='';
var titlecell = ovs_util_getcell('tvplot');
var genrecell = ovs_util_getcell('genre');
var episodecell = ovs_util_getcell('episode');
var episodedatecell = ovs_util_getcell('epDate');
var g_epno='';
var g_info='';

function ovs_delist() {  
    ovs_util_action('delist',g_idlist,"Delist "+g_epno+"?");
}

function ovs_delete() {   
    ovs_util_action('delete',g_idlist,"Delete files for "+g_epno+"?");
}

function ovs_info() {
    alert(g_info);
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


function ovs_ep(ep)
{
    var epTitle = ep["title"];
    var epDate = ep["date"];
    var epNo =  ep["episode"];

    // Set globals for mark/delist/delete functions.

    g_idlist = ep["idlist"];
    g_epno =  ep["episode"];
    g_info = ep["info"];

    // Create nicer skin specific date and titles.
    if (epNo == "") {

        // Main show
        epTitle = "Show Summary - ";
        epDate = "";

    } else {

        // Episode
        if (epDate != "" ) {
            epDate = "("+epDate+")";
        }

        if (epNo != "" && epTitle.indexOf(epNo) >= 0) {
            epTitle = epNo  + " - ";
        } else {
            epTitle = epNo + " : " + epTitle  + " - ";
        }
    }

    // Set cell content based on selected episode

    titlecell.nodeValue = ep["plot"];
    episodecell.nodeValue = epTitle;
    episodedatecell.nodeValue = epDate;
}
