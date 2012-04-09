#!/bin/sh
# $Id$

# Make sure running bash
# Different embedded environments use different shells and have bash in different places. /opt/bin/ /ffp/bin
# For same reason /usr/bin/env might not always work
case "`ls -l /proc/$$/exe`" in # no readlink on nmt
    */bash|*/busybox) ;;
    *) exec bash "$0" "$@" || exec busybox sh "$0" "$@" ;;
esac


# Detect and rename media files. Sounds simple huh?
# Initially written for NMT platform that has a limited subset of busybox commands and no perl.

# Requires wget (not busybox)

set -u  #Abort with unset variables
set -e  #Abort with any error can be suppressed locally using EITHER cmd||true OR set -e;cmd;set +e

# This script is horrendous. My comment!

DEBUG=1
#Find install folder
EXE="$0"
while [ -h "$EXE" ] ; do EXE="$(readlink "$EXE")"; done
APPBINDIR="$( cd "$( dirname "$EXE" )" && pwd )"
source $APPBINDIR/ovsenv

echo "[INFO] family=$FAMILY arch=$ARCH"

NMT=0

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
    JOBID=`date +%d-%H%M%S`
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

RENAME_TV=0
RENAME_FILM=0
STDOUT=0

START_DIR="$PWD"

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
    RENAME_TV        - Move the tv folders.
    RENAME_FILM      - Move the film folders.
    RENAME           - Rename both tv and film
    EXPORT_XML       - Export XML database to /tmp/indexdb.xml (Experimental)

    IGNORE_NFO       - dont look in existing NFO for any infomation
    WRITE_NFO        - write NFO files
    NOWRITE_NFO      - Dont write NFO files

    DEBUG            - lots of logging
    NOACTIONS        - Do not run any actions and hide Delete actions from overview.
    DRYRUN           - Show effects of RENAME but dont do it.

    REBUILD          - Run even if no folders. Usually to tidy database.
    RESCAN           - Rescan default paths
    NEWSCAN          - Rescan default paths - new media only
    PARALLEL_SCAN    - Allow multiple scans with RESCAN or NEWSCAN keyword
    STDOUT           - Write to stdout (if not present output goes to log file)

    GET_POSTERS      - Download posters if not present
    UPDATE_POSTERS   - Download fresh posters for scanned items.
    GET_FANART       - Download fanart if not present
    UPDATE_FANART    - Download fresh fanart for scanned items.
    GET_PORTRAITS    - Download actor portraits
    UPDATE_PORTRAITS - Download fresh portraits for actors associated with scanned items.
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

    AWK="gawk --re-interval "
    awk_prg="$AWK "
    for f in "$OVS_HOME/bin/catalog/"*.awk ; do
        awk_prg="$awk_prg -f $f"
    done

    echo "PRG = $awk_prg"

    cd /tmp

    pid_dir="$OVS_HOME/tmp/pid"
    mkdir -p "$pid_dir"
    PIDFILE="$pid_dir/$$.pid"

    LC_ALL=C $awk_prg \
    JOBID="$JOBID" PID=$$ NOW=`date +%Y%m%d%H%M%S` \
    DAY=`date +%a.%P` \
    "PIDFILE=$PIDFILE" \
    "START_DIR=$START_DIR" \
    "OVS_HOME=$OVS_HOME" \
    "LOG_TAG=$LOG_TAG" \
    "PLOT_DB=$PLOT_DB" \
    "UNPAK_CFG=$UNPAK_CFG" \
    "UID=$uid" \
    "OVERSIGHT_ID=$OVERSIGHT_ID" \
    "AWK=$AWK" \
    g_tmp_dir="$g_tmp_dir" \
    "INDEX_DB=$INDEX_DB" "$@"

    tidy

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
    find "$1" -name "$2*" -mtime "+$3" | while IFS= read f ; do
        rm -fr -- "$f"
    done
}

clean_all_files() {
    clean_files "$tmp_root" "*" 2
    clean_files "$OVS_HOME/logs" "[cu]*.log" 5 
    clean_files "$EMPTY_DIR" "[cu]*.log" 1
    clean_files "$OVS_HOME/cache" "tt*" 30
}

errors() {
awk '

/(Start|Merge) item/ { i=$0 ; system(""); } 

/^(\[ERR\]|Terminated)/ { if (i) { printf "\n%s\n\n",i ; i="" ;} ; print "'"$1"':"$0 ; } 

END { exit c }' 
}

LOG_DIR="$OVS_HOME/logs"
mkdir -p "$LOG_DIR"

EMPTY_DIR="$LOG_DIR/emptyscans"
mkdir -p "$EMPTY_DIR"

if [ "$STDOUT" -eq 1 ] ; then
    LOG_TAG="catalog:"
    main "$@"
else
    LOG_TAG=
    #LOG_FILE="$OVS_HOME/logs/catalog.`date +%d%H%M`.$$.log"

    LOG_NAME="catalog.$JOBID.log"

    # quicker to find current scans - prefix with 0
    TMP_LOG_FILE="$LOG_DIR/0-$LOG_NAME"
    LOG_FILE="$LOG_DIR/$LOG_NAME"

    TMP_ERR_FILE="$TMP_LOG_FILE.err"
    ERR_FILE="$LOG_FILE.err"

    ( main "$@" 2>&1 ) | tee "$TMP_LOG_FILE" | errors "$LOG_NAME" > "$TMP_ERR_FILE"

    mv "$TMP_LOG_FILE" "$LOG_FILE"

    # Rename or delete error file
    if [ -s "$TMP_ERR_FILE" ] ; then
        mv "$TMP_ERR_FILE" "$ERR_FILE"
    else
        rm -f "$TMP_ERR_FILE"
    fi

    if grep -q "Total files added : 0" "$LOG_FILE" ; then
        mv "$LOG_FILE"* "$EMPTY_DIR"
        LOG_FILE="$EMPTY_DIR/$LOG_NAME" 
    fi
    archive "$LOG_FILE"

    #If lauched from command line - display log file location
    if [ -z "${REMOTE_ADDR:-}" ] ;then
        echo "[INFO] $LOG_FILE.gz"
    fi

fi
# vi:sw=4:et:ts=4
