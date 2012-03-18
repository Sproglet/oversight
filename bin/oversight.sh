#!/bin/sh
# $Id$ 
# Fixed reference to NZBOP_APPBIN
#VERSION=20090605-1BETA
#Cant use named pipes due to blocking at script level
EXE=$0
while [ -h "$EXE" ] ; do EXE="$(readlink "$EXE")"; done
d="$( cd "$( dirname "$EXE" )" && pwd )"

TVMODE=`cat /tmp/tvmode`
. "$d/ovsenv"

CONF="$OVS_HOME/conf/catalog.cfg"

appname=oversight
cd "$OVS_HOME"

TMPDIR="$OVS_HOME/tmp"
if [ ! -d "$TMPDIR" ] ; then
    mkdir -p "$TMPDIR"
    if [ `id -u` = 0 ] ; then
        chown "$uid:$gid" "$TMPDIR"
    fi
fi

# This file will be created by oversight if it crashed whilst masquerading as wget.
# If it IS present during a reboot the all of the wget masquerading function is
# disabled.
OVERSIGHT_WGET_ERROR="$OVS_HOME/conf/wget.wrapper.error"

# This file must be present to make oversight intercept oversight urls when the
# oversight binary is also called "wget". If it is not present then oversight will
# try to invoke the real wget in /bin/wget.real
# If it is NOT present during a reboot the all of the wget masquerading function is
# disabled.
OVERSIGHT_USE_WGET="$OVS_HOME/conf/use.wget.wrapper"


WGET_BACKUP="$OVS_HOME/wget.original"
WGET_BIN=/bin/wget

# -----------------------------------------------------

CMD_BUF="$TMPDIR/cmd"
LOCK="$TMPDIR/oversight.lck"
PENDING_FILE="$TMPDIR/cmd.pending"

NMT="$OVS_HOME/install.sh"
LISTEN() {
        #We add the current OVS_HOME to the path. This allows
        #oversight.cgi to send commands to oversight.sh running as a cron on the remote nmt.
        #oversight.sh will use its own idea of OVS_HOME (ie /share/Apps/oversight) rather than
        #oversight.cgi home eg /opt/sybhttpd/local.drives/NETWORK_DRIVE/nmt2/Apps/oversight )
        #
        # So instead of sending commands as $OVS_HOME/bin/catalog.sh we just send ./bin/catalog.sh
        # and let the cron job determine what OVS_HOME is. (ie from the perspective of the remote box)

        PATH="$OVS_HOME:$PATH"

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
    if ! id | fgrep -q "($uid)" ; then
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
    chown $uid:$gid "$PENDING_FILE"
}

PERMS() {
    chown $uid:$gid "$1" "$1"/*
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
mounts="$OVS_HOME/oversight.mounts"
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

            $OVS_HOME/install.sh NMT_INSTALL_WS "$wsname" "$url"
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

# $1=frequency
# $2=cron tag
# $3=function eg "./bin/catalog.sh function"

add_watch_cron() {
    if [ "$1" != "off" ] ; then
        d="*"
        h="*"
        m="*"
        case "$1" in
            *m) m="*/`echo $1 | sed 's/m//'`" ;;
            *h) h="*/`echo $1 | sed 's/h//'`" ; m=0 ;;
            *d) d="*/`echo $1 | sed 's/d//'`" ; h=0 ; m=0 ;;
            *) echo Unknown cron format $1 ;;
        esac
        if [ "$d$m$h" != "***" ] ; then
            "$NMT" NMT_CRON_ADD root "$appname.$2" "$m $h $d * * cd '$OVS_HOME/bin' && './oversight.sh' $3 >/dev/null 2>&1 &"
        fi
    else
        "$NMT" NMT_CRON_DEL root "$appname.$2"
    fi
}

is_wget() {
    [ -x "$1" ] && grep -iq "GNU Wget" "$1"
}

install_as_wget() {
    # Replace wget binary with oversight. This allows faster page load.
    if [ ! -f "$OVERSIGHT_USE_WGET" ] ; then
        echo "wget wrapper disabled: could not find $OVERSIGHT_USE_WGET"
       
    else 
       if [ -f "$OVERSIGHT_WGET_ERROR" ] ; then
           echo "wget wrapper disabled: found $OVERSIGHT_WGET_ERROR"
       else
            if is_wget "$WGET_BIN" ; then
                cp -a "$WGET_BIN" "$WGET_BACKUP"
                # use rm then cp to avoid symlink overwrite of unexpected file
                rm -f "$WGET_BIN.real"
                mv "$WGET_BIN" "$WGET_BIN.real" && \
                ln -sf "$OVS_HOME/bin/oversight" "$WGET_BIN"
            else
                # if wget is not really wget it could be an old file based version of oversight
                # replace it with a symlink.
                ln -sf "$OVS_HOME/bin/oversight" "$WGET_BIN"
            fi
            echo "wget wrapper installed"
        fi
    fi
}

uninstall_as_wget() {
    # Restore wget binary
    if ! is_wget "$WGET_BIN" ; then
        if rm -f "$WGET_BIN" ; then
            if is_wget "$WGET_BIN.real" ; then
                mv "$WGET_BIN.real" "$WGET_BIN"
            else
                if is_wget "$WGET_BACKUP" ; then 
                    cp -a "$WGET_BACKUP" "$WGET_BIN"
                fi
            fi
        fi
        echo "wget wrapper removed"
    fi
}

reboot_fix() {

    ln -sf "$OVS_HOME/bin/$ARCH/oversight" "$OVS_HOME/oversight.cgi"

    install_as_wget

    # Restore website link
    ln -sf "$OVS_HOME/" /opt/sybhttpd/default/.

    # Create symlink to html
    ln -sf /tmp/0 "$OVS_HOME/logs/gui.log"

    # Restore cronjobs

    freq="`awk -F= '/^catalog_watch_frequency=/ { gsub(/"/,"",$2) ; print $2 }' $CONF`"
    add_watch_cron "$freq" "watch" "NEWSCAN CHECK_TRIGGER_FILES" 

    # Delete any catalog 2 oversight messages
    rm -f "$OVS_HOME/catalog.status"
}

case "$1" in 
    NEWSCAN)
        "$OVS_HOME/bin/catalog.sh" "$@" 

        if grep -q /^catalog_watch_torrents=.*1/ $CONF* ; then
            "$OVS_HOME/bin/torrent.sh" transmission unpak_all
        fi
        ;;

    WATCH_FOLDERS)
        add_watch_cron "$2" "watch" "NEWSCAN CHECK_TRIGGER_FILES" 
        ;;

    INSTALL_AS_WGET)
        install_as_wget
        ;;

    UNINSTALL_AS_WGET)
        uninstall_as_wget
        ;;

    REBOOTFIX)
        set -x
        reboot_fix > "$OVS_HOME/logs/reboot.log" 2>&1
        set +x

        ;;

    LISTEN)
        log="$OVS_HOME/logs/listen.log" 
        if [ -f /tmp/oversight.disable ] ; then
            echo "disabled" >> "$log"
            exit
        fi
        if [ -e "$PENDING_FILE" ] ; then
            #SWITCHUSER "$uid" "$@"
            LISTEN >> "$log" 2>&1 || rm -f "$LOCK"
        fi


        exit;;
    UNINSTALL)
        "$NMT" NMT_CRON_DEL root "$appname" 
        "$NMT" NMT_CRON_DEL root "$appname.watch"
        rm -f "/opt/sybhttpd/default/oversight" "$PENDING_FILE" "$CMD_BUF.live"
        uninstall_as_wget
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
