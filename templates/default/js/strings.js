// String functions to determine formats of displayed data

function ovsString_tvBoxset(title, seasonCount) {
	return title + " - [ Boxset - " + seasonCount + " seasons ]";
}

function ovsString_movieBoxset(title, movieCount) {
	return title + " - [ Boxset - " + movieCount + " movies ]";
}

function ovsString_tv(title, season, year, cert) {
	return title + " - Season " + season;
}

function ovsString_movie(title, year, cert) {
	return title + " - " + cert + " (" + year + ")";
}
