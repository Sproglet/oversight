#!/bin/sh -- #
# Convert script from DOS
true                            #

if [ $? != 0 ]; then            #
    set -e                      #
    sed 's/.$//' "$0" > /tmp/$$ #
    cat /tmp/$$ > "$0"          #
    rm /tmp/$$                  #
    exec /bin/sh "$0" "$@"      #
    exit                        #
fi                              #

VERSION=20090110-2
#Cant use named pipes due to blocking at script level
EXE=$0
while [ -L "$EXE" ] ; do
    EXE=$( ls -l "$EXE" | sed 's/.*-> //' )
done
HOME=$( echo $EXE | sed -r 's|[^/]+$||' )
HOME=$(cd "${HOME:-.}" ; pwd )
TVMODE=`cat /tmp/tvmode`
OWNER=nmt
GROUP=nmt
appname=oversight
CMD_BUF="$HOME/tmp/oversight.cmd"
LOCK="$HOME/tmp/oversight.lck"

NMT="$HOME/install.bin"
LISTEN() {
        date
        if [ -e "$LOCK" ] ; then
            pid=`cat "$LOCK"`
            if [ -d "/proc/$pid" ] ; then
                echo "locked by another process"
                exit;
            fi
        fi
        echo $$ > "$LOCK"

        if [ -e "$CMD_BUF.pending" ] ; then
            mv "$CMD_BUF.pending" "$CMD_BUF.live"
            while read prefix command ; do
                echo "$prefix[$command]"
                case "$prefix" in
                    oversight:) eval  "$command" ;;
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


case "$1" in 
    REBOOTFIX)
        ln -sf "$HOME/$appname.cgi" /opt/sybhttpd/default/.
        "$NMT" NMT_CRON_ADD nmt "$appname" "* * * * * cd '$HOME' && './$appname.sh' LISTEN >/dev/null 2>&1 &"
        exit ;;
    LISTEN)
        if [ -e "$CMD_BUF.pending" ] ; then
            SWITCHUSER "$OWNER" "$@"
            LISTEN >> "$HOME/logs/listen.log" 2>&1 || rm -f "$LOCK"
        fi
        exit;;
    UNINSTALL)
        "$NMT" NMT_CRON_DEL nmt "$appname" 
        "$NMT" NMT_CRON_DEL root "$appname" 
        rm -f "/opt/sybhttpd/default/oversight.cgi" /tmp/oversight.constants "$CMD_BUF.pending" "$CMD_BUF.live"
        exit;;
    SAY)
        shift;
        #Avoid blocking for pipe
        A="$(ARGLIST "$@")"
        echo "oversight: $A" >> "$CMD_BUF.pending"
        chown $OWNER:$GROUP "$CMD_BUF.pending"
        exit;;
    *) echo "usage: $0 REBOOTFIX|LISTEN|SAY|UNINSTALL";;
esac
