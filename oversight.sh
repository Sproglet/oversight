#!/bin/sh
VERSION=20090707-1BETA
# Fixed reference to NZBOP_APPBIN
#VERSION=20090605-1BETA
#Cant use named pipes due to blocking at script level
EXE=$0
while [ -L "$EXE" ] ; do
    EXE=$( ls -l "$EXE" | sed 's/.*-> //' )
done
APPDIR=$( echo $EXE | sed -r 's|[^/]+$||' )
APPDIR=$(cd "${APPDIR:-.}" ; pwd )
TVMODE=`cat /tmp/tvmode`

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

CMD_BUF="$TMPDIR/cmd"
LOCK="$TMPDIR/oversight.lck"
CACHE_DIR="$TMPDIR/cache"
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
                        if [ "$command" = "$lastCommand" ] ; then
                            echo "Skipping duplicate command [$command]"
                        else
                            eval  "$command"
                            lastCommand="$command";


                        fi
                        ;;
                    *) echo "Ignoring [$command]" ;;
                esac
            done < "$CMD_BUF.live"
            rm -f "$CMD_BUF.live"
        fi

        rm -f "$LOCK"
}

#If a beta is currently installed check for any upgrade else check stable only
check_for_upgrades() {
    if grep -q "^VERSION.*BETA" $APPDIR/oversight.cgi ; then
        "$APPDIR/upgrade.sh" oversight check_stable_or_beta 
    else
        "$APPDIR/upgrade.sh" oversight check_stable 
    fi
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

UPGRADE() {
    if "$APPDIR/upgrade.sh" oversight "$@" ; then
        case "$1" in
            upgrade|undo) 
                CLEAR_CACHE
                ;;
        esac
    fi

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

CLEAR_CACHE() {
    if [ -d "$CACHE_DIR" ] ; then rm -f -- "$CACHE_DIR"/* ; fi
    if [ -d "$CACHE_DIR.old" ] ; then rm -f -- "$CACHE_DIR.old"/* ; fi
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

case "$1" in 
    REBOOTFIX)
        ln -sf "$APPDIR/" /opt/sybhttpd/default/.
        "$NMT" NMT_CRON_ADD nmt "$appname" "* * * * * [ -e $PENDING_FILE ] && cd '$APPDIR' && './$appname.sh' LISTEN >/dev/null 2>&1 &"
        #This detects new versions but need to check spindown
        #"$NMT" NMT_CRON_ADD nmt "$appname" "* * * * * cd '$APPDIR' && './$appname.sh' LISTEN >/dev/null 2>&1 &"
        #Include message for the old v1 link for the time being.
        oldcgi="/opt/sybhttpd/default/oversight.cgi"
        rm -f $oldcgi || true
        cat <<HERE >$oldcgi
#!/bin/sh
cat <<HERE2
Content-Type: text/html

Oversight has moved. Please update your bookmarks.
<a href="/oversight/oversight.cgi">Click here to continue</a>
HERE2
HERE
        exit ;;
    LISTEN)
        log="$APPDIR/logs/listen.log" 
        if [ -f /tmp/oversight.disable ] ; then
            echo "disabled" >> "$log"
            exit
        fi
        if [ -e "$PENDING_FILE" ] ; then
            SWITCHUSER "$OWNER" "$@"
            LISTEN >> "$log" 2>&1 || rm -f "$LOCK"
        fi
        if [ `date '+%H%M'` = 0000 ] ; then
            check_for_upgrades
        fi
        exit;;
    UNINSTALL)
        "$NMT" NMT_CRON_DEL nmt "$appname" 
        "$NMT" NMT_CRON_DEL root "$appname" 
        rm -f "/opt/sybhttpd/default/oversight" "$PENDING_FILE" "$CMD_BUF.live"
        exit;;
    SAY)
        shift;
        SAY "$@"
        exit;;
    CLEAR_CACHE) CLEAR_CACHE ;;
    UPGRADE) UPGRADE "$2" ;;
    FIND_REMOTE) shift ; FIND_REMOTE "$@" ;;
    REMOUNT) shift ; REMOUNT "$@" ;;
    SHARE) shift ; SHARE "$@" ;;
    *) echo "[$*???] usage: $0 REBOOTFIX|LISTEN|SAY|UNINSTALL|FIND_REMOTE|REMOUNT|SHARE";;
esac
