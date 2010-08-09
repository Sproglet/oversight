// String functions to determine formats of displayed data

function ovsString_tvBoxset(title, seasonCount, year) {
	return title + " (" + seasonCount + " Seasons)";
}

function ovsString_movieBoxset(title, movieCount) {
	return title + " (" + movieCount + " Movie Boxset)";
}

function ovsString_tv(title, season, cert) {
	return title + " - Season " + season;
}

function ovsString_movie(title, year, cert) {
	return title + " (" + year + ")";
}
