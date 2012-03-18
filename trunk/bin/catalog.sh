#!/bin/sh
# $Id$

# Detect and rename media files. Sounds simple huh?
# Initially written for NMT platform that has a limited subset of busybox commands and no perl.

# Requires wget (not busybox)

set -u  #Abort with unset variables
set -e  #Abort with any error can be suppressed locally using EITHER cmd||true OR set -e;cmd;set +e

NMT_APP_DIR=

# This script is horrendous. My comment!

DEBUG=1
#Find install folder
EXE=$0
while [ -h "$EXE" ] ; do EXE="$(readlink "$EXE")"; done
APPBINDIR="$( cd "$( dirname "$EXE" )" && pwd )"
OVS_HOME="$( cd "$( dirname "$EXE" )"/.. && pwd )"

. $APPBINDIR/ovsenv

echo "[INFO] family=$FAMILY arch=$ARCH"

NMT=0

AWK=gawk
#AWK="$BINDIR/gawk --posix "

set +e

PERMS() {
    chown -R $OVERSIGHT_ID "$@" || true
}


# If /tmp is on a hard drive use it
if df /tmp | grep -q '/[sh]d[a-f]' ; then
    tmp_root=/tmp/oversight
else
    # on nmt something sometimes changes /tmp permissions so only root can write
    tmp_root="$OVS_HOME/tmp"
fi

#unpak.sh may pass the JOBID to catalog.sh via JOBID env. This allows
#the log files to share the same number.
if [ -z "${JOBID:-}" ] ; then
    #JOBID=$$
    JOBID=`date +%m%d%H%M%S`
    #JOBID=`date +%s`
fi

g_tmp_dir="$tmp_root/$JOBID"
rm -fr "$g_tmp_dir"
mkdir -p $g_tmp_dir
PERMS $g_tmp_dir

INDEX_DB="$OVS_HOME/index.db"
if [ ! -s "$INDEX_DB" ] ; then
    echo "#Index" > "$INDEX_DB";
    PERMS "$INDEX_DB"
fi

PLOT_DB="$OVS_HOME/plot.db"
if [ ! -s "$PLOT_DB" ] ; then
    touch "$PLOT_DB"
    PERMS "$PLOT_DB"
fi

COUNTRY_FILE="$OVS_HOME/conf/country.txt"
CONF_FILE="$OVS_HOME/conf/catalog.cfg"
DEFAULTS_FILE="$OVS_HOME/conf/.catalog.cfg.defaults"

if [ ! -f "$CONF_FILE" ] ; then
    if [ ! -f "$CONF_FILE.example" ] ; then
        cp "$DEFAULTS_FILE" "$CONF_FILE.example"
    fi
    cp "$CONF_FILE.example" "$CONF_FILE"
fi

# Have to do fix endings because of WordPad. Also not all platforms have sed -i
#cat preserves dest permissions
# note replace ^M with ^L-^N to avoid eol issues with subervsion
# eol-style not doing as expected via cygwin/windows.
if grep -q '[-]' "$CONF_FILE" ; then
    tmpFile="$g_tmp_dir/catalog.cfg.$$"
    sed 's/[-]$//' "$CONF_FILE" > "$tmpFile"
    cat "$tmpFile" > "$CONF_FILE"
    rm -f "$tmpFile"
fi
. "$DEFAULTS_FILE"
. "$CONF_FILE"

check_missing_settings() {
    # Just in case user has an earlier config file that doesnt have these settings.
    if [ -z "$catalog_tv_file_fmt" ] ; then 
        catalog_tv_file_fmt="/share/Tv/{:TITLE:}{ - Season :SEASON:}/{:NAME:}"
        echo "[WARNING] Please add catalog_tv_file_fmt settings to catalog.cfg. See catlog.cfg.example for examples."
    fi
    if [ -z "$catalog_film_folder_fmt" ] ; then 
        catalog_film_folder_fmt="/share/Movies/{:TITLE:}{-:CERT:}"
        echo "[WARNING] Please add catalog_film_folder_fmt settings to catalog.cfg. See catlog.cfg.example for examples."
    fi
}


RENAME_TV=0
RENAME_FILM=0
STDOUT=0

START_DIR="$PWD"

check_missing_settings

if [ -z "$*" ] ; then
    cat<<USAGE
    usage $0 [STDOUT] [IGNORE_NFO] [WRITE_NFO] [DEBUG] [REBUILD] [NOACTIONS] [RESCAN] [NEWSCAN]
             [RENAME] [RENAME_TV] [RENAME_FILM] [DRYRUN]
             [GET_POSTERS] [UPDATE_POSTERS]
             [GET_FANART] [UPDATE_FANART]
             [GET_PORTRAITS] [UPDATE_PORTRAITS]
             ..folders..
____________________________________________________________________________________________________________________    
To simply index all files in a folder:

        $0 Folder

        This is usually all that is needed. The new oversight viewer will take care of showing nice names to the user.
____________________________________________________________________________________________________________________    
Other options 
    RENAME_TV      - Move the tv folders.
    RENAME_FILM    - Move the film folders.
    RENAME         - Rename both tv and film
    DRYRUN         - Show effects of RENAME but dont do it.
    EXPORT_XML     - Export XML database to /tmp/indexdb.xml
    IGNORE_NFO     - dont look in existing NFO for any infomation
    WRITE_NFO      - write NFO files
    NOWRITE_NFO    - dont write NFO files
    DEBUG          - lots of logging
    REBUILD        - Run even if no folders. Usually to tidy database.
    RESCAN         - Rescan default paths
    NEWSCAN        - Rescan default paths - new media only
    PARALLEL_SCAN  - Allow multiple scans with RESCAN or NEWSCAN keyword
    NOACTIONS      - Do not run any actions and hide Delete actions from overview.
    STDOUT         - Write to stdout (if not present output goes to log file)
    GET_POSTERS    - Download posters
    UPDATE_POSTERS- Fetch new posters for each scanned item.
    GET_FANART     - Download fanart
    UPDATE_FANART - Fetch new fanart for each scanned item.
    GET_PORTRAITS    - Download actor portraits
    UPDATE_PORTRAITS - Fetch new actor portrait for each scanned item.
USAGE
    exit 0
fi

quoted_arg_list() {
    ARGS=""
    for i in "$@" ; do
        case "$i" in
        *\'*)
            case "$i" in
            *\"*) ARGS=`echo "$ARGS" | sed -r 's/[][ *"()?!'"'"']/\\\1/g'` ;;
            *) ARGS="$ARGS "'"'"$i"'"' ;;
            esac
            ;;
        *) ARGS="$ARGS '$i'" ;;
        esac
    done
    echo "$ARGS"
}

SWITCHUSER() {
    if ! id | fgrep -q "($1)" ; then
        u=$1
        shift;
        echo "[$USER] != [$u]"
        
        a="$0 $(quoted_arg_list "$@")"
        echo "CMD=$a"
        exec su $u -s /bin/sh -c "$a"
    fi
}

get_unpak_cfg() {
    for ext in cfg cfg.example ; do
        for nzd in "$OVS_HOME/conf" /share/Apps/NZBGet/.nzbget /share/.nzbget ; do
            if [ -f "$nzd/unpak.$ext" ] ; then 
                echo "$nzd/unpak.$ext"
                return
            fi
        done
    done
}

catalog() {

    #Look at the old unpak file - to make sure we dont index pin folder.
    UNPAK_CFG=`get_unpak_cfg`
    echo UNPAK="[$UNPAK_CFG]"

    Q="'"

    # use index before match
    # clear arrays using split("",array,"")

    awk_prg="$AWK "
    for f in $OVS_HOME/bin/catalog/*.awk ; do
        awk_prg="$awk_prg -f $f"
    done

    echo "PRG = $awk_prg"

    cd /tmp

    pid_dir="$OVS_HOME/tmp/pid"
    mkdir -p "$pid_dir"
    PIDFILE="$pid_dir/$$.pid"

    $awk_prg \
    JOBID="$JOBID" PID=$$ NOW=`date +%Y%m%d%H%M%S` \
    DAY=`date +%a.%P` \
    "PIDFILE=$PIDFILE" \
    "START_DIR=$START_DIR" \
    "OVS_HOME=$OVS_HOME" \
    "CONF_FILE=$CONF_FILE" \
    "COUNTRY_FILE=$COUNTRY_FILE" \
    "DEFAULTS_FILE=$DEFAULTS_FILE" \
    "LOG_TAG=$LOG_TAG" \
    "PLOT_DB=$PLOT_DB" \
    "UNPAK_CFG=$UNPAK_CFG" \
    "UID=$uid" \
    "OVERSIGHT_ID=$OVERSIGHT_ID" \
    "AWK=$AWK" \
    "NMT_APP_DIR=$NMT_APP_DIR" \
    g_tmp_dir="$g_tmp_dir" \
    "INDEX_DB=$INDEX_DB" "$@"

    rm -f "$OVS_HOME/catalog.lck" "$OVS_HOME/catalog.status" "$PIDFILE"

}


tidy() {
    rm -f "$OVS_HOME/catalog.lck" "$OVS_HOME/catalog.status" "$PIDFILE"
    clean_all_files
}

trap "rm -f $OVS_HOME/catalog.status" INT TERM EXIT

main() {

    clean_all_files

    set +e
    echo "[INFO] $os_version $nmt_version"
    catalog DEBUG$DEBUG "$@" 
    x=$?
    set -e

    rm -fr -- "$g_tmp_dir"
    chown -R $OVERSIGHT_ID $INDEX_DB* "$PLOT_DB" "$OVS_HOME/tmp" 2>/dev/null || true
    return $x
}

#-------------------------------------------------------------------------



# $1 = dir
# $2 = file pattern
# $3 = age
# find exec doesnt work on nmt
clean_files() {
    find "$1" -name "$2" -mtime "+$3" | while IFS= read f ; do
        rm -fr -- "$f"
    done
}

clean_all_files() {
    clean_files "$tmp_root" "*" 2
    clean_files "$OVS_HOME/logs" "[cu]*.log" 5 
    clean_files "$OVS_HOME/cache" "tt*" 30
}

#Due to a very nasty root renaming incident - reinstated user switch
#SWITCHUSER "$uid" "$@"

if [ "$STDOUT" -eq 1 ] ; then
    LOG_TAG="catalog:"
    main "$@"
else
    LOG_TAG=
    #LOG_FILE="$OVS_HOME/logs/catalog.`date +%d%H%M`.$$.log"
    LOG_DIR="$OVS_HOME/logs"
    mkdir -p "$LOG_DIR"

    EMPTY_DIR="$LOG_DIR/emptyscans"
    mkdir -p "$EMPTY_DIR"

    LAST_LOG="$LOG_DIR/last.log"

    LOG_NAME="catalog.$JOBID.log"
    LOG_FILE="$LOG_DIR/$LOG_NAME"

    ln -sf "$LOG_FILE" "$LAST_LOG"
    main "$@" > "$LOG_FILE" 2>&1

    #If lauched from command line - display log file location
    if [ -z "${REMOTE_ADDR:-}" ] ;then
        echo "[INFO] $LOG_FILE"
    fi

    if grep -q "Total files added : 0" "$LOG_FILE" ; then
        EMPTY_LOG="$LOG_DIR/catalog.emptyscan.log"
        mv "$LOG_FILE" "$EMPTY_DIR"
        ln -sf "$EMPTY_DIR/$LOG_NAME" "$LAST_LOG"
    fi

    grep dryrun: "$LOG_FILE"
    PERMS "$OVS_HOME/logs"
fi
if [ -f "$OVS_HOME/oversight.sh" ] ; then
    $OVS_HOME/oversight.sh CLEAR_CACHE
fi
# vi:sw=4:et:ts=4
