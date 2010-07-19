#!/bin/sh
#! $Id$
#!This is a compacted file. If looking for the source see catalog.sh.full
#!If not compressed then awk will report "bad address" error on some platforms.
#!
#!blank lines kept to preserve line numbers reported in errors.
#!All leading white space trimmed so make sure lines ending in \ have any mandatory white space included.
#!
#! See end of file for Compress command.

# TODO Any more memory errors remove :
# IMDBLINKS code
# nfo file generation.


set -u  #Abort with unset variables
set -e  #Abort with any error can be suppressed locally using EITHER cmd||true OR set -e;cmd;set +e
VERSION=20100228-1BETA

NMT_APP_DIR=
nmt_version=unknown
#Thanks to Jorge for pointing out C200 changes.
for d in /mnt/syb8634 /nmt/apps ; do
    if [ -f $d/MIN_FIRMWARE_VER ] ; then
        NMT_APP_DIR=$d
        nmt_version=`cat $NMT_APP_DIR/VERSION`
    fi
done

# Fixed reference to NZBOP_APPBIN
#VERSION=20090605-1BETA
# Added more checking around nfo name

# TV AWK INTERFACE
# This script is horrendous. My comment!
# Pushing limits of awks usability. Next time I'll use <insert any other scripting language here>
# Also sometimes lines are left in for debugging
#
#TODO should check write permissions to nfo file - not urgent
#TODO Error displaying titles for Leon Wall-E etc. special chars.
# (c) Andy Lord andy@lordy.org.uk #License GPLv3

DEBUG=1
#Find install folder
EXE=$0
while [ -L "$EXE" ] ; do
    EXE=$( ls -l "$EXE" | sed 's/.*-> //' )
done
APPDIR=$( echo $EXE | sed -r 's|[^/]+$||' )
APPDIR=$(cd "${APPDIR:-.}" ; pwd )

is_nmt() {
    [ -n "$NMT_APP_DIR" ]
}

NMT=0
if is_nmt ; then
    uid=nmt
    gid=nmt
    if [ -d /share/bin ] ; then
        PATH="/share/bin:$PATH" && export PATH
    fi
else
    uid=root
    gid=None
fi

# also used by plot.db
export OVERSIGHT_ID="$uid:$gid"

AWK=awk
#AWK="$BINDIR/gawk --posix "

#Get newer gzip and wget
# nmt busybox wget is primitive.
# nmt /bin/wget is buggy
# nmt busybox gzip is not graceful for passthru of uncompressed data

SORT=sort
if [ -d "$APPDIR/bin" ] ; then

    if grep -q "MIPS 74K" /proc/cpuinfo ; then
        BINDIR="$APPDIR/bin/nmt200"
    else
        BINDIR="$APPDIR/bin/nmt100"
    fi
    SORT="$BINDIR/busybox sort"

    export PATH="$PATH:$BINDIR:$APPDIR/bin"

    AWK="$BINDIR/gawk --re-interval "

fi



set +e

PERMS() {
    chown -R $OVERSIGHT_ID "$@" || true
}

tmp_root=/tmp/oversight
if is_nmt ; then
    # on nmt something sometimes changes /tmp permissions so only root can write
    tmp_root="$APPDIR/tmp"
fi

#unpak.sh may pass the JOBID to catalog.sh via JOBID env. This allows
#the log files to share the same number.
if [ -z "${JOBID:-}" ] ; then
    JOBID=$$
fi

g_tmp_dir="$tmp_root/$JOBID"
rm -fr "$g_tmp_dir"
mkdir -p $g_tmp_dir
PERMS $g_tmp_dir

INDEX_DB="$APPDIR/index.db"
if [ ! -s "$INDEX_DB" ] ; then
    echo "#Index" > "$INDEX_DB";
    PERMS "$INDEX_DB"
fi

PLOT_DB="$APPDIR/plot.db"
if [ ! -s "$PLOT_DB" ] ; then
    touch "$PLOT_DB"
    PERMS "$PLOT_DB"
fi

COUNTRY_FILE="$APPDIR/conf/country.txt"
CONF_FILE="$APPDIR/conf/catalog.cfg"
DEFAULTS_FILE="$APPDIR/conf/.catalog.cfg.defaults"

if [ ! -f "$CONF_FILE" ] ; then
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
        for nzd in "$APPDIR/conf" /share/Apps/NZBGet/.nzbget /share/.nzbget ; do
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

    #for nmt platform use /share/bin/ls for ls if available, but
    #we cant just add /share/bin to path as this forces busybox wget.

    LS=ls
    if [ -f /share/bin/ls ] ; then
        LS=/share/bin/ls
    fi

    # use index before match
    # clear arrays using split("",array,"")

        $AWK -f $APPDIR/catalog.awk \
    JOBID="$JOBID" PID=$$ NOW=`date +%Y%m%d%H%M%S` \
    DAY=`date +%a.%P` \
    "START_DIR=$START_DIR" \
    "LS=$LS" \
    "APPDIR=$APPDIR" \
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

    rm -f "$APPDIR/catalog.lck" "$APPDIR/catalog.status"

    #update_imdb_list "directors.db"
    update_imdb_list "actors.db"
    #update_imdb_list "writers.db"
}

# If a new file has been created - merge it with the existing one and sort.
# We may need to specify the sort key more precisely if the id length varies.
update_imdb_list() {

    dnew="$g_tmp_dir/$1.$$"
    dold="$APPDIR/db/$1"

    set -x

    if [ -f "$dnew" ] ; then
        touch "$dold" || true
        $SORT -u "$dnew" "$dold" > "$dnew.new" &&\
        mv "$dnew.new" "$dold" &&\
        PERMS "$dold" &&\
        rm -f "$dnew"
        # convert colons to tabs
        sed -i 's/\(^nm.......\):/\1\t/' "$dold"
    fi
     
    set +x
}

tidy() {
    rm -f "$APPDIR/catalog.status"
    clean_all_files
}

trap "rm -f $APPDIR/catalog.status" INT TERM EXIT

main() {

    clean_all_files

    set +e
    sed 's/^/\[INFO\] os version /' /proc/version
    if is_nmt ; then
        sed -rn '/./ s/^/\[INFO\] nmt version /p' /???/*/VERSION
    fi
    #echo "[INFO] HD:`dmesg | egrep '(, ATA|ATA-)'`"
    catalog DEBUG$DEBUG "$@" 
    x=$?
    set -e

    rm -fr -- "$g_tmp_dir"
    chown -R $OVERSIGHT_ID $INDEX_DB* "$PLOT_DB" "$APPDIR/tmp" || true
    return $x
}

#-------------------------------------------------------------------------



# $1 = dir
# $2 = file pattern
# $3 = age
# find exec doesnt work on nmt
clean_files() {
    find "$1" -name "$2" -mtime "+$3" | while IFS= read f ; do
        rm -f -- "$f"
    done
}

clean_all_files() {
    clean_files "$tmp_root" "." 2
    clean_files "$APPDIR/logs" "catalog.*.log" 5 
    clean_files "$APPDIR/cache" "tt*" 30
}

#Due to a very nasty root renaming incident - reinstated user switch
#SWITCHUSER "$uid" "$@"

if [ "$STDOUT" -eq 1 ] ; then
    LOG_TAG="catalog:"
    main "$@"
else
    LOG_TAG=
    #LOG_FILE="$APPDIR/logs/catalog.`date +%d%H%M`.$$.log"
    LOG_DIR="$APPDIR/logs"
    mkdir -p "$LOG_DIR"
    LOG_NAME="catalog.$JOBID.log"
    LOG_FILE="$LOG_DIR/$LOG_NAME"

    (cd "$LOG_DIR" && ( mv "last.log" "prev.log" || true ) && ln -sf "$LOG_NAME" "last.log" )

    main "$@" > "$LOG_FILE" 2>&1
    if [ -z "${REMOTE_ADDR:-}" ] ;then
        echo "[INFO] $LOG_FILE"
    fi
    grep dryrun: "$LOG_FILE"
    PERMS "$APPDIR/logs"
fi
if [ -f "$APPDIR/oversight.sh" ] ; then
    $APPDIR/oversight.sh CLEAR_CACHE
fi
# vi:sw=4:et:ts=4
