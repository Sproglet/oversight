#Grab imdb files.

update() {
    files='aka-titles
    certificates
    countries
    directors
    genres
    movies
    plot
    producers
    ratings
    release-dates';

    mirrors='ftp://ftp.fu-berlin.de/pub/misc/movies/database/
    ftp://ftp.funet.fi/pub/mirrors/ftp.imdb.com/pub/
    ftp://ftp.sunet.se/pub/tv+movies/imdb/';

    tmp=/tmp/$$.imdb

    for f in $files ; do
        for m in $mirrors ; do
            echo checking $m $f.list
            if wget -N $m/$f.list.gz > $tmp 2>&1  ; then
                if grep "'$f.list.gz' saved" $tmp ; then
                    chown nmt:nmt $f.list.gz
                    echo unzipping $f.list
                    cat $f.list.gz | gunzip > $f.list
                    chown nmt:nmt $f.list
                fi
                break
            fi
        done
    done
}

usage() {
    cat <<HERE
    $0 UPDATE : update all listings"
    $0 PLOT "title" Year"
    $0 DIRECTOR "title" Year"
    $0 GENRE "title" Year"
    $0 CERTIFICATE "title" Year" "Country"
    $0 RATING "title" Year" 
HERE
}

fn="$1" ; shift;
case "$fn" in
    update) update "$@" ;;
    plot) plot "$@" ;;
    director) director "$@" ;;
        genre) genre "$@" ;;
    cert*) certificate "$@" ;;
    rating) rating "$@" ;;
    search) search "$@" ;;
    *) usage;;
esac
