#!/bin/sh --
true # A Header to fix and run DOS format sh scripts. ALord/Ydrol

if [ $? != 0 ]; then             #
    sed 's/$//' "$0" > /tmp/$$ #
    cat /tmp/$$ > "$0"           #
    rm -f /tmp/$$                #
    exec /bin/sh "$0" "$@"       #
    exit                         #
fi                               #
# REAL SCRIPT FOLLOWS
#--------------------------------------------------------------------------
VERSION=20090111-1
INSTALL_DIR=$( echo "$0" | sed -r 's/[^/]+$//' )
INSTALL_DIR=$( cd "$INSTALL_DIR" ; pwd )

appname="oversight"
wsname="OverSight"
cgiName="oversight.cgi"
cgiPath="$INSTALL_DIR/$cgiName"
shPath="$INSTALL_DIR/$appname.sh"
start_command="$shPath REBOOTFIX"

httpd="http://127.0.0.1:8883"

NMT="$INSTALL_DIR/install.bin"

NZBGET_CONF=/share/.nzbget/nzbget.conf
UNPAK_CONF="$INSTALL_DIR/unpak.cfg"

NZBGET() {
    /mnt/syb8634/server/nzb "$1" >/dev/null 2>&1
}

echo "Content-Type: text/html"
echo

CP() {
    cp "$1" "$2" && chown -R nmt:nmt "$2"
}

if [ ! -f "$UNPAK_CONF" ] ; then
        CP "$UNPAK_CONF.example" "$UNPAK_CONF"
fi

INSTALL() {
        "$shPath" UNINSTALL
        UNPAK_INSTALL 
        chmod -R 775 "$INSTALL_DIR"
        chown -R nmt:nmt "$INSTALL_DIR"
        "$NMT" NMT_INSTALL_WS "$wsname" "$httpd/$cgiName"
        "$NMT" NMT_INSTALL "$appname" "$start_command"
        eval "$start_command"

        if [ ! -f "$INSTALL_DIR/index.db.idx" ] ; then
            CP "$INSTALL_DIR/index.db.example" "$INSTALL_DIR/index.db"
            CP "$INSTALL_DIR/index.db.idx.example" "$INSTALL_DIR/index.db.idx"
            "$shPath" SAY "$INSTALL_DIR/catalog.sh" FORCE /share/
        fi
        "$NMT" NMT_INSTALL_WS_BANNER "$wsname" "Installation Complete"
}


UNPAK_INSTALL() {
    UNPAK_UNINSTALL
    cp "$NZBGET_CONF" "$NZBGET_CONF.pre_oversight"
    awk '
BEGIN { f=0 ; newScript="PostProcess='"$INSTALL_DIR"'/unpak.sh" ; }

/^#PreOversight#PostProcess=/ {
    "#"$0; 
}

/^PostProcess=/ {
    f=1;
    if (index($0,"'"$INSTALL_DIR"'/unpak.sh") == 0)  {
        print newScript;
        $0="#PreOversight#"$0;
    } 
}

{ print }

END {
    if(!f) { 
        print newScript;
    }
}' "$NZBGET_CONF.pre_oversight" > "$NZBGET_CONF.new" && mv "$NZBGET_CONF.new" "$NZBGET_CONF" 
}

UNPAK_UNINSTALL() {
    cp "$NZBGET_CONF" "$NZBGET_CONF.post_oversight"
    awk '
BEGIN { activeCount=0; }
/^PostProcess/ {
    if (index($0,"'"$INSTALL_DIR"'/unpak.sh")) { next; }
    activeCount++;
}

/^#PreOversight#PostProcess/ && activeCount==0 {
    
    
    $0 = substr($0,15);
    activeCount++;
}

{ print }
' "$NZBGET_CONF.post_oversight" > "$NZBGET_CONF.new" && mv "$NZBGET_CONF.new" "$NZBGET_CONF" 
}

LOCK=/tmp/oversight-install.lck
if [ -f $LOCK ] ; then
    if [ -d /proc/`cat $LOCK` ] ; then
        exit
    fi
fi
echo $$ > $LOCK

DO() {
    ( echo "CMD:$1: " ;\
    eval "$1" ;\
    echo "==============`date` ======================="\
    ) >> "$INSTALL_DIR/check.log" 2>&1
}

PERMS() {
    chmod -R 775 "$INSTALL_DIR"
    chown -R nmt:nmt "$INSTALL_DIR"
    chown -R nmt:nmt /share/.nzbget/nzbget.conf*
}

case "$1" in 
    *oversight-install*)
        INSTALL
        PERMS
        ;;
    *restart*)
        NZBGET stop
        NZBGET start
        ;;
    *oversight-uninstall*)
        UNPAK_UNINSTALL
        "$shPath" UNINSTALL
        "$NMT" NMT_UNINSTALL "$appname"
        "$NMT" NMT_UNINSTALL_WS "$wsname" 
        "$NMT" NMT_INSTALL_WS_BANNER "$wsname" "Uninstalled"
        PERMS
        ;;
    *check*)
        rm -f "$INSTALL_DIR/check.log"
        DO env
        DO date
        DO "uname"
        DO "uname -a"
        DO "uptime"
        DO "cat /mnt/syb8634/VERSION"
        DO "grep ^VERSION '$INSTALL_DIR/'*"
        DO "grep Post /share/.nzbget/nzbget.conf"
        DO "sed -rn '/url/ s/.*name=.(.(name|url)[1-9]).*value=.([^"'"'"]*).*/|\1|\3|/p' /opt/sybhttpd/default/webservices_edit*html"
        DO "crontab -l"
        DO "crontab -l nmt"
        DO "df"
        DO "ls -l '$INSTALL_DIR'"
        DO "ls -l '$INSTALL_DIR/logs'"
        DO "cat '$INSTALL_DIR/logs/listen.log'"
        DO "ls -l /share/start_app.sh"
        DO "awk '/M_A_R/,/exit/ 1' /share/start_app.sh"
        DO "awk '/^start()/,/^stop()/ 1' /mnt/syb8634/etc/ftpserver.sh"
        DO "$INSTALL_DIR/oversight.cgi | head -5"
        DO "ls -Rl /tmp/local*8883"
        DO "ps -w | grep ' nmt' "
        DO "ps -w | grep ' nobody' "
        DO "ps -w | grep ' root' | egrep -v '(upnp|sbin|\\[)'"
        DO "busybox"
        DO "ifconfig" 
        DO "ls -l /proc/$$" #This is how we work out ls format.
        DO "cat /etc/resolv.conf"
        DO " sed -rn 's/nameserver/ping -c 1 /p' /etc/resolv.conf | /bin/sh"
        DO "ping news.bbc.co.uk -c 1"
        DO "ping 4.2.2.1 -c 1"

        mv $INSTALL_DIR/check.log $INSTALL_DIR/logs/check.log
        "$NMT" NMT_INSTALL_WS_BANNER "$wsname" "Output saved in logs/check.log"
        PERMS
        ;;
esac

rm -f $LOCK
