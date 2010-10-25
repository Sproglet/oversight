#Grab imdb files.


user=nmt:nmt

DIRNAME() {
    echo "$1" | sed 's/\/.*//'
}

dbdir=`DIRNAME "$0"`
dbdir=$( cd $dbdir ; pwd )
dbdir="$dbdir/download"
mkdir -p "$dbdir" && ( chown -R $user $dbdir || true )


update() {
    files='aka-titles
    certificates
    countries
    directors
    genres
    movies
    movie-links
    plot
    producers
    actors
    actresses
    ratings
    release-dates';

    files='movies actors actresses';
    files='movies';

    mirrors='ftp://ftp.fu-berlin.de/pub/misc/movies/database/
    ftp://ftp.funet.fi/pub/mirrors/ftp.imdb.com/pub/
    ftp://ftp.sunet.se/pub/tv+movies/imdb/';

    tmp=/tmp/$$.imdb

    cd $dbdir

    for f in $files ; do
        for m in $mirrors ; do
            echo checking $m $f.list
            if wget -N $m/$f.list.gz > $tmp 2>&1  ; then
                #echo ====
                #cat $tmp
                #echo ====
                echo
                if grep "gz.*saved" $tmp ; then
                    echo unzipping $f.list
                    cat $f.list.gz | gunzip > $f.list
                    chown $user $f.list.gz $f.list || true
                fi
                break
            fi
        done
    done
}

usage() {
    cat <<HERE
    $0 update : update all listings"
    $0 plot "title" Year"
    $0 director "title" Year"
    $0 genre "title" Year"
    $0 certificate "title" Year" "Country"
    $0 rating "title" Year" 
    $0 countries "title" Year" 
HERE
exit 1
}

tab="	"

director() {
    namesearch directors "$@"
}

producer() {
    namesearch producers "$@"
}

namesearch() {
    file="$1" ; shift ;
    # for all lines not starting with tab.
    # 
    sed -rn "
# hold any lines with director name
/^[^$tab]/ { h } 

# If there is a move match get the held line and spit it and quit. 
/${tab}$1 \($2\)/ { g ; s/$tab.*// ; p ; q }" $dbdir/$file.list
}

rating() {
    # eg 
    #       0000000115  446522   9.1  The Shawshank Redemption (1994)
    # no tabs.
    sed -rn "
/  $1 \($2\)/ {
    # remove first two fields
    s/^ +[^ ]+ +[^ ]+ +// ; 
    # remove everything after first field 
    s/ +.*// ; 
    p ; 
    q 
}" $dbdir/ratings.list
}

genre() {
    # Transformers (2007)^I^I^I^I^IAction$
    # Transformers (2007)^I^I^I^I^ISci-Fi$
    film_then_value genres "$@"
}

certificate() {
    # Transformers (2007)                 South Korea:12
    # Transformers (2007)^I^I^I^I^ISouth Korea:12$
    # Tabs!
    film_then_value certificates "$@"
}

countries() {
    # Transformers (2007)^I^I^I^I^IUSA
    film_then_value countries "$@"
}


film_then_value() {
    file="$1" ; shift ;
    sed -rn "
/^$1 \($2\)/ {
    s/^[^$tab]+$tab+// ; 
    p ;
} " $dbdir/$file.list
}

plot() {
    # MV: Title (Year)
    # PL: xxxxx
    awk '
/^MV: '"$1"' \('"$2"'\)/ {
    getline; #skip blank
    while ((getline plot ) > 0 ) {
        if (index(plot,"PL:") != 1) break;
        print substr(plot,5);
    }
    exit;
}
' $dbdir/plot.list
}

reduce_links() {
$ sed -rn '1,/===/ d ; /^"/,/^$/ d; /\((reference|spoof|feature|version|edited)/ d ; /./ p' movie-l
inks.list > short.list
}


if [ -z "$1" ] ; then usage ; fi

fn="$1" ; shift;
case "$fn" in
    update) update "$@" ;;
    plot) plot "$@" ;;
    director) director "$@" ;;
    producer) producer "$@" ;;
    genre) genre "$@" ;;
    cert*) certificate "$@" ;;
    rating) rating "$@" ;;
    countr*) countries "$@" ;;
    search) search "$@" ;;
    *) usage;;
esac
