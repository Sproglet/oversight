// String functions to determine formats of displayed data

function ovsString_tvBoxset(title, menu) {
	return title + " - [ Boxset - " + menu["num_seasons"] + " seasons ]";
}

function ovsString_movieBoxset(title, movieCount) {
	return title + " - [ Boxset - " + menu["count"] + " movies ]";
}

function ovsString_tv(title, menu ) {
	return title + " - Season " + menu["season"];
}

function ovs_source_quality(menu) {

    var inf = "";
    var q = ovs_quality(menu);
    if (menu["videosource"]) inf = inf + "," + menu["videosource"];
    if (q) inf = inf +"," + q; 
    if (inf != "") {
        inf = "(" + inf.substring(1) + ") ";
    }
    return inf;
}
function ovs_quality(menu) {
    // use width to determin quality as letterboxing makes height shorter.
    var vid,height;
    vid = menu["video"];
    vid.match(/w0=([0-9]+)/);
    height = RegExp.$1;
    if (height == "" ) return "?";
    else if (height >= 1920 ) return "1080p";
    else if (height >= 1280 ) return "720p";
    else return "sd";
    
}

function ovsString_movie(title, menu) {
	title =  title + " - " + menu["cert"] + " (" + menu["year"] + ") " + ovs_source_quality(menu);
	return title;
}
