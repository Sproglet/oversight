#!/bin/sh
# $Id$ 
# Fixed reference to NZBOP_APPBIN
#VERSION=20090605-1BETA
#Cant use named pipes due to blocking at script level
EXE=$0
while [ -L "$EXE" ] ; do
    EXE=$( ls -l "$EXE" | sed 's/.*-> //' )
done
APPDIR=$( echo $EXE | sed -r 's|[^/]+$||' )
export APPDIR=$(cd "${APPDIR:-.}" ; pwd )
TVMODE=`cat /tmp/tvmode`

CONF=$APPDIR/conf/catalog.cfg

OWNER=nmt
GROUP=nmt
appname=oversight
cd "$APPDIR"

TMPDIR="$APPDIR/tmp"
if [ ! -d $TMPDIR ] ; then
    if id | grep -q root ; then
        mkdir -p $TMPDIR
        chown $OWNER:$GROUP $TMPDIR
    fi
fi

# ------- GET NMT Version and set NMT specific paths if applicable ---------

NMT_APP_DIR=
nmt_version=unknown
#Thanks to Jorge for pointing out C200 changes.
for d in /mnt/syb8634 /nmt/apps ; do
    if [ -f $d/MIN_FIRMWARE_VER ] ; then
        NMT_APP_DIR=$d
        nmt_version=`cat $NMT_APP_DIR/VERSION`
    fi
done

case "$nmt_version" in
    *-408)
        export PATH="$APPDIR/bin/nmt200:$PATH"
        ;;
    *-402|*-403)
        export PATH="$APPDIR/bin/nmt100:$PATH"
        ;;
esac

# -----------------------------------------------------

CMD_BUF="$TMPDIR/cmd"
LOCK="$TMPDIR/oversight.lck"
PENDING_FILE="$TMPDIR/cmd.pending"

NMT="$APPDIR/install.sh"
LISTEN() {
        #We add the current APPDIR to the path. This allows
        #oversight.cgi to send commands to oversight.sh running as a cron on the remote nmt.
        #oversight.sh will use its own idea of APPDIR (ie /share/Apps/oversight) rather than
        #oversight.cgi home eg /opt/sybhttpd/local.drives/NETWORK_DRIVE/nmt2/Apps/oversight )
        #
        # So instead of sending commands as $APPDIR/catalog.sh we just send ./catalog.sh
        # and let the cron job determine what APPDIR is. (ie from the perspective of the remote box)

        PATH="$APPDIR:$PATH"

        date
        if [ -e "$LOCK" ] ; then
            pid=`cat "$LOCK"`
            if [ -d "/proc/$pid" ] ; then
                echo "locked by another process"
                exit;
            fi
        fi
        echo $$ > "$LOCK"

        if [ -e "$PENDING_FILE" ] ; then
            mv "$PENDING_FILE" "$CMD_BUF.live"
            lastCommand=""
            while read prefix command ; do
                echo "$prefix[$command]"
                case "$prefix" in
                    oversight:)
                        case "$command" in
                        "$lastCommand")
                            echo "Skipping duplicate command [$command]"
                            ;;
                        *PARALLEL_SCAN*)
                            eval  "$command" &
                            lastCommand="$command";
                            ;;
                        *)
                            eval  "$command"
                            lastCommand="$command";
                            ;;

                        esac
                        ;;
                    *) echo "Ignoring [$command]" ;;
                esac
            done < "$CMD_BUF.live"
            rm -f "$CMD_BUF.live"
        fi

        rm -f "$LOCK"
}

ARGLIST() {
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
    if ! id | fgrep -q "($OWNER)" ; then
        u=$1
        shift;
        echo "[$USER] != [$u]"
        
        #Write args to a file. - probably a neater way...
        a="$0 $(ARGLIST "$@")"
        echo "CMD=$a"
        exec su $u -s /bin/sh -c "$a"
    fi
}

# Add command to the queue
SAY() {
    #Avoid blocking for pipe
    A="$(ARGLIST "$@")"
    echo "oversight: $A" >> "$PENDING_FILE"
    chown $OWNER:$GROUP "$PENDING_FILE"
}

PERMS() {
    chown $OWNER:$GROUP "$1" "$1"/*
}

HTML() {
    echo "<p>$@<p>"
}

MYIP() {
    #ifconfig eth0 | awk '/inet/ { sub(/[^:]*:/,"",$2) ; print $2; }'
    awk -F== '/eth_ipaddr/ {print $2} {next}' /tmp/setting.txt
}

LOAD_SETTINGS() {
    #load all settings from syabas generated file (esp Workgroup & ipaddress)
    sed '/=/ {s/=/="/;s/$/"/}' /tmp/setting.txt > /tmp/setting.txt.sh
    . /tmp/setting.txt.sh
}

#This file contains lines copied from mtab with a comment appended so we know which logical name to associate 
#the mount point with.
mounts="$APPDIR/oversight.mounts"
REMOUNT() {
    targetPath="/opt/sybhttpd/localhost.drives/NETWORK_SHARE/$1"
    targetURL="http://localhost.drives:8883/NETWORK_SHARE/$1"
    if  grep -q "/$1 " /etc/mtab ; then
        REDIRECT_TO_REMOTE "$targetURL" 
    else
        mkdir -p "$targetPath"
        if grep "/$1 " "$mounts" | sh ; then
            REDIRECT_TO_REMOTE "$targetURL"
        else 
    cat <<HERE2
<html>
<body>
Unable to mount $1 at $targetPath
</body>
</html>
HERE2
        fi
    fi
}

# Mount a predefined share
# $1 = share name
SHARE() {
    i=`sed -rn '/^servname.='"$1"'$/ { s/servname// ; s/=.*//p }' /tmp/setting.txt`
    link=`sed -rn '/^servlink'$i'=/ { s/[^=]*=//p }' /tmp/setting.txt`
    case "$link" in
        smb:*) /opt/sybhttpd/default/smbclient.cgi "smb.name=$1&smb.cmd=mount&smb.opt=$link" >/dev/null 2>&1 ;;
        nfs:*) /opt/sybhttpd/default/smbclient.cgi "smb.name=$2&smb.client=nfs&smb.cmd=mount&smb.opt=$link" >/dev/null 2>&1 ;;
    esac
    REDIRECT_TO_REMOTE "http://localhost.drives:8883/NETWORK_SHARE/$1"
}

REDIRECT_TO_REMOTE() {
    #skip <html><head> as this is alread output before stylesheet
    cat <<HERE
</style>
<meta http-equiv="refresh" content="0;$1/Apps/oversight/oversight.cgi" />
</head>
<body>
echo hello
</body>
</html>
HERE
}

# Look in the standard places for any mounted remote oversights.
FIND_REMOTE() {
    path=/opt/sybhttpd/localhost.drives/NETWORK_SHARE
    if [ ! -d "$path" ] ; then return ; fi

    (cd "$path" ; ls -A ) | while IFS= read remote ; do
        
        if [ -d "$path/$remote/Apps/oversight" ] ; then

            d="$path/$remote"
            #device=`df "$d" | awk 'NR==2 { gsub(/[s]/,"\\\\\\\\&"); print $1 }'`
            device=`df "$d" | grep -v Filesystem | sed -r 's/ .*//;s@([/\\\\])@\\\\\1@g'`


            echo "DEVICE IS $device"

            if [ "$remote" = "NETWORK_BROWSER" ] ; then
                remote=`echo $device | sed 's/\/share//;s/[\\\/:]//g'`
            fi
            remote=`echo "$remote" | sed 's/^ovs-//'`
            echo "REMOTE IS $remote"

            wsname="OverSight-$remote"
            mountName="ovs-$remote"
            echo "MOUNT NAME IS $mountName"

            url="http://localhost:8883/oversight/oversight.cgi?remote=$mountName"

            $APPDIR/install.sh NMT_INSTALL_WS "$wsname" "$url"
            echo "<p>Added Web Service $wsname"


            if [ -f "$mounts" ] ; then

                #delete any existing remotes with the same tag name
                echo sed -i "/\/$mountName\ / d" "$mounts"
                sed -i "/\/$mountName\ / d" "$mounts"

                #delete any existing remotes with the same device name
                echo sed -i "/^$device\ / d" "$mounts"
                sed -i "/^$device\ / d" "$mounts"
            fi

            #Grab the current mtab line - changing mount location to ovs-
            awk '
/^'$device'\ / { 
    #Change last folder of path to be our new mount name
    sub(/[^\/]+$/,"'"$mountName"'",$2);
    #Remove following mount options
    gsub(/,(domain|unc)=[^,]*/,"",$4);
    gsub(/\\134/,"/",$1);
    print "mount -t "$3" "$1" "$2" -o "$4($3=="cifs"?",password="PASSWORD:"");
}
{ next }
' PASSWORD=1234 /etc/mtab >> "$mounts"
        fi
    done
    echo "<p>OverSight mounts:<pre>"
    cat "$mounts"
    echo "</pre>"
}

# $1=max value
# $2=period
# $3=offset
# return list of minute values. eq 20,3 returns 3,23,43

get_period() {
    startms=$(( $2 + $3 ))
    ms=$startms

    i=0

    while [ "$i" -le "$1" ] ; do

        if [ $(( $i % $startms )) -eq 0 -a $i -ne $startms ] ; then

            ms="$ms,$i"

        fi

        i=$(( $i + 1 ))

    done
    echo $ms
}
            

# $1=frequency
# $2=cron tag
# $3=function eg "./catalog.sh function"
# $4=hour offset
# $5=minute offset

add_watch_cron() {
    if [ "$1" != "off" ] ; then
        d="*"
        m="*"
        h="*"
        case "$1" in
            10m) d="*"    ; h="*" ; m="`get_period 59 10 $5`";;
            15m) d="*"    ; h="*" ; m="`get_period 59 15 $5`";;
            20m) d="*"    ; h="*" ; m="`get_period 59 20 $5`";;
            30m) d="*"    ; h="*" ; m="`get_period 59 30 $5`" ;;
            1h)  d="*"    ; h="0-23" ; m="$5" ;;
            2h)  d="*"    ; h="`get_period 23 2 $4`" ; m="$5" ;;
            3h)  d="*"    ; h="`get_period 23 3 $4`" ; m="$5" ;;
            4h)  d="*"    ; h="`get_period 23 4 $4`" ; m="$5" ;;
            6h)  d="*"    ; h="`get_period 23 6 $4`" ; m="$5" ;;
            8h)  d="*"    ; h="`get_period 23 8 $4`" ; m="$5" ;;
            12h) d="*"    ; h="`get_period 23 12 $4`" ; m="$5" ;;
            1d)  d="1-31" ; h=0 ; m=$5 ;;
        esac
        if [ "$d$m$h" != "***" ] ; then
            "$NMT" NMT_CRON_ADD root "$appname.$2" "$m $h $d * * cd '$APPDIR' && JOBID=newscan.$$ './catalog.sh' $3 >/dev/null 2>&1 &"
        fi
    else
        "$NMT" NMT_CRON_DEL root "$appname.$2"
    fi
}


case "$1" in 
    NEWSCAN)
        "$APPDIR/catalog.sh" NEWSCAN GET_POSTERS GET_FANART

        if grep -q /^catalog_watch_torrents=.*1/ $CONF* ; then
            "$APPDIR/bin/torrent.sh" transmission unpak_all
        fi
        ;;

    WATCH_FOLDERS)
        add_watch_cron "$2" "watch" "NEWSCAN" 0 0
        ;;

    REBOOTFIX)
        # NMT find siliently fails with -mtime and -newer
        if [ ! -L "$APPDIR/bin/nmt100/find" ] ; then
            ln -sf $APPDIR/bin/nmt100/busybox $APPDIR/bin/nmt100/find
        fi

        # Restore website link
        ln -sf "$APPDIR/" /opt/sybhttpd/default/.

        # Restore cronjobs
        "$NMT" NMT_CRON_ADD root "$appname" "* * * * * [ -e $PENDING_FILE ] && cd '$APPDIR' && './$appname.sh' LISTEN >/dev/null 2>&1 &"
        freq="`awk -F= '/^catalog_watch_frequency=/ { gsub(/"/,"",$2) ; print $2 }' $CONF`"
        add_watch_cron "$freq" "watch" "NEWSCAN" 0 0

        # Delete any catalog 2 oversight messages
        rm -f "$APPDIR/catalog.status"
        ;;

    LISTEN)
        log="$APPDIR/logs/listen.log" 
        if [ -f /tmp/oversight.disable ] ; then
            echo "disabled" >> "$log"
            exit
        fi
        if [ -e "$PENDING_FILE" ] ; then
            #SWITCHUSER "$OWNER" "$@"
            LISTEN >> "$log" 2>&1 || rm -f "$LOCK"
        fi


        exit;;
    UNINSTALL)
        "$NMT" NMT_CRON_DEL root "$appname" 
        "$NMT" NMT_CRON_DEL root "$appname" 
        "$NMT" NMT_CRON_DEL root "$appname.watch"
        rm -f "/opt/sybhttpd/default/oversight" "$PENDING_FILE" "$CMD_BUF.live"
        exit;;
    SAY)
        shift;
        SAY "$@"
        exit;;
    FIND_REMOTE) shift ; FIND_REMOTE "$@" ;;
    REMOUNT) shift ; REMOUNT "$@" ;;
    SHARE) shift ; SHARE "$@" ;;
    *) echo "[$*???] usage: $0 REBOOTFIX|LISTEN|SAY|UNINSTALL|FIND_REMOTE|REMOUNT|SHARE";;
esac
