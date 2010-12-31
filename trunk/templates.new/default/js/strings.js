// String functions to determine formats of displayed data

function ovsString_tvBoxset(title, seasonCount, year) {
	return title + " Boxed set - " + seasonCount + " seasons";
}

function ovsString_movieBoxset(title, movieCount) {
	return title + " Boxed set - " + movieCount + " movies";
}

function ovsString_tv(title, season, cert) {
	return title + " - Season " + season;
}

function ovsString_movie(title, year, cert) {
	return title + " (" + year + ")";
}
