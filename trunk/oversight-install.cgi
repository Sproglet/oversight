#!/bin/sh
# $Id$ 
INSTALL_DIR=$( echo "$0" | sed -r 's/[^/]+$//' )
INSTALL_DIR=$( cd "$INSTALL_DIR" ; pwd )

appname="oversight"
wsname="OverSight"
cgiName="oversight.cgi"
shPath="$INSTALL_DIR/bin/$appname.sh"
start_command="$shPath REBOOTFIX"

httpd="http://127.0.0.1:8883"

NMT="$INSTALL_DIR/install.sh"

FIND_FILE() {
    f="$1" ; shift;
    for i in "$@" ; do
        if [ -f "$i/$f" ] ; then
            echo "$i/$f"
            return 0
        fi
    done
    echo UNSET
    return 1
}

unpak_nzbget_bin="`FIND_FILE nzbget /share/Apps/NZBget/bin /mnt/syb8634/bin`"
unpak_nzbget_conf="`FIND_FILE nzbget.conf /share/Apps/NZBget/.nzbget /share/.nzbget`"
UNPAK_CONF="$INSTALL_DIR/conf/unpak.cfg"
CATALOG_CONF="$INSTALL_DIR/conf/catalog.cfg"

NZBGET() {
    "$unpak_nzbget_bin" -c "$unpak_nzbget_conf" "$@"
}

echo "Content-Type: text/html"
echo

CP() {
    cp "$1" "$2" && chown -R nmt:nmt "$2"
}

RELOCATE_CONFIGS() {
    for i in  catalog.cfg oversight.cfg unpak.cfg ; do
        if [ -f "$i" ] ; then
            if [ ! -f "conf/$i" ] ; then
                mv "$i" "./conf/$i"
            fi
        fi
    done

    for i in *.example  ; do
        if [ -f "$i" ] ; then
            mv "$i" "./tmp/$i.delete_me"
        fi
    done
}

cd "$INSTALL_DIR"

RELOCATE_CONFIGS


if [ ! -f "$UNPAK_CONF" ] ; then
    echo $unpak_nzbget_bin
    echo $unpak_nzbget_conf
        sed -ir "s@(unpak_nzbget_conf=).*@\\1'$unpak_nzbget_conf'@" "$UNPAK_CONF.example"
        sed -ir "s@(unpak_nzbget_bin=).*@\\1'$unpak_nzbget_bin'@" "$UNPAK_CONF.example"
        CP "$UNPAK_CONF.example" "$UNPAK_CONF"
fi

# $1=config file
# $2=version tag
UPGRADE_CONFIG() {
    if [ ! -f "$1" ] ; then
        CP "$1".example "$1"
    else
        if ! grep -ql "$2" "$1" ; then
            CP "$1" "$1".PRE_UPGRADE
            CP "$1".example "$1"
        fi
    fi
}

SKIN_INSTALL() {

    # Move new skins into place
    if [ -d templates.new ] ; then

        rm -fr templates.old
        mv templates templates.old || true
        mv templates.new templates

        if [ -d templates.old ] ; then
            # Move skins that are not superceeded.
            ( cd templates.old ;
              for i in * ; do
                  if [ -e "$i" ] ; then
                      if [ ! -e "../templates/$i" ] ; then
                          cp -a "$i" "../templates/$i"
                      fi
                  fi
              done
            )
            # copy config files
            ( cd templates.old ; tar cf - */conf/*.cfg ) | ( cd templates ; tar xf - ) || true

        fi
    fi

    # run any skin installers
    for inst in "$INSTALL_DIR"/templates/*/install.sh ; do

        if [ -f "$inst" ] ; then

            /bin/sh "$inst"

        fi

    done

    # remove bad skin
    rm -fr "$INSTALL_DIR/templates/gaya"
}

INSTALL() {
        "$shPath" UNINSTALL
        NZBGET_UNPAK_INSTALL 
        #FIX_NZBGET_DAEMON
        TRANSMISSION_UNPAK_INSTALL

        ( cd "$INSTALL_DIR/cache" && rm -f tt[0-9]*[0-9] ) # clear cache

        #not sure how people are still getting wget in busybox but rename it
        if [ -f /share/bin/wget ] ; then
            mv /share/bin/wget /share/bin/wget2 || true
        fi

        SKIN_INSTALL

        chmod -R 775 "$INSTALL_DIR"
        chown -R nmt:nmt "$INSTALL_DIR"
        "$NMT" NMT_UNINSTALL "$appname"
        "$NMT" NMT_INSTALL "$appname" "$start_command"
        "$NMT" NMT_CRON_DEL nmt "$appname" #old cron job
        eval "$start_command"
        "$NMT" NMT_INSTALL_WS "$wsname" "$httpd/$appname/$cgiName"


        UPGRADE_CONFIG conf/catalog.cfg catalog_config_version=1
        UPGRADE_CONFIG conf/oversight.cfg ovs_config_version=1

        if [ ! -f "index.db.idx" ] ; then
            touch "index.db"
            touch "index.db.idx"
        fi
        touch conf/catalog.cfg conf/oversight.cfg conf/unpak.cfg

        chmod a+r /dev/random /dev/urandom
        BOUNCE_NZBGET
        "$NMT" NMT_INSTALL_WS_BANNER "$wsname" "Installation Complete"
}


TRANSMISSION_UNRAR_FILE=/share/.transmission/unrar.sh

TRANSMISSION_UNPAK_INSTALL() {
    if [ -f "$TRANSMISSION_UNRAR_FILE" ] ; then
        TRANSMISSION_UNPAK_UNINSTALL
        sed -i '
2 i\
exec '"$INSTALL_DIR"'/bin/unpak.sh torrent_seeding "$@"
' $TRANSMISSION_UNRAR_FILE
    chown nmt:nmt "$TRANSMISSION_UNRAR_FILE"
    fi
}

TRANSMISSION_UNPAK_UNINSTALL() {
    if [ -f "$TRANSMISSION_UNRAR_FILE" ] ; then
        sed -i '/unpak.sh torrent_seeding/ d' "$TRANSMISSION_UNRAR_FILE"
        chown nmt:nmt "$TRANSMISSION_UNRAR_FILE"
    fi
}

FIX_NZBGET_DAEMON() {
    # If nzbget is restarted via nzbget_web it is started as root rather than nmt user
    # even though DaemonUserName is set. 
    f="/share/Apps/NZBget/daemon.sh"

}

NZBGET_UNPAK_INSTALL() {
    NZBGET_UNPAK_UNINSTALL
    CP "$unpak_nzbget_conf" "$unpak_nzbget_conf.pre_oversight" &&\
    awk '
function debug(x) {
    print "#INSTALL#"x
}
BEGIN {

    #Repair
    set["postprocess"]="'"$INSTALL_DIR"'/bin/unpak.sh" ;
    set["allowreprocess"]="yes" ;
    set["parcheck"]="no";
    set["renamebroken"]="no";

    # Logging
    set["detailtarget"]="none";
    set["debugtarget"]="none";
    set["infotarget"]="screen";
    set["warningtarget"]="both";
    set["errortarget"]="both";
    set["createlog"]="yes";
    set["createbrokenlog"]="yes";
    set["resetlog"]="yes";
    set["logbuffersize"]="100";

    #IO Performance
    set["directwrite"]="yes";
    set["continuepartial"]="no";

    # Added for standard nzbget.conf
    set["outputmode"]="loggable";
    set["nzbdirfileage"]="12";
    set["dupecheck"]="yes";
    set["threadlimit"]="10";

    pat="";
    for(k in set) { pat=pat"|"tolower(k) ; }
    pat="("substr(pat,2)")";
}

match(tolower($0),"^"pat"=") {
    k=substr($0,RSTART,RLENGTH-1);
    lc_k = tolower(k);
    found[lc_k]=1;
    v=set[lc_k];
    if (index(tolower($0),tolower(v)) == 0) {
        print "#Changed By Oversight#";
        print k"="v;
        $0="#PreOversight#"$0;
    } 
}

{ print }

END {
    #Add all missing keywords
    for (k in set) {
        if (!(k in found)) {
            print "#Changed By Oversight#";
            print k"="set[k];
        }
    }
}' "$unpak_nzbget_conf.pre_oversight" > "$unpak_nzbget_conf.new" && mv "$unpak_nzbget_conf.new" "$unpak_nzbget_conf" 

}

NZBGET_UNPAK_UNINSTALL() {
    CP "$unpak_nzbget_conf" "$unpak_nzbget_conf.post_oversight"
    awk '
BEGIN { activeCount=0; }

/Changed By Oversight/ { getline ; next };
/^#PreOversight#/  {
    $0 = substr($0,15);
}

{ print }
' "$unpak_nzbget_conf.post_oversight" > "$unpak_nzbget_conf.new" && mv "$unpak_nzbget_conf.new" "$unpak_nzbget_conf" 
}

LOCK=/tmp/oversight-install.lck
if [ -f $LOCK ] ; then
    if [ -d /proc/`cat $LOCK` ] ; then
        exit
    fi
fi
echo $$ > $LOCK

PERMS() {
    chmod -R 775 "$INSTALL_DIR"
    chown -R nmt:nmt "$INSTALL_DIR"
    chown -R nmt:nmt /share/.nzbget/nzbget.conf*
}

BOUNCE_NZBGET() {
    #Bounce nzbget if its running
    #nmt should set its own Daemon user - but wrapped command with su 
    #because of reports of nzbget running as nobody.

    # "$INSTALL_DIR/bin/unpak.sh nzbget_cmd restart"

    su -s /bin/sh nmt -c "$INSTALL_DIR/bin/unpak.sh nzbget_cmd restart"
}


case "$1" in 
    install|oversight-install)
        PERMS
        set -x
        INSTALL > "$INSTALL_DIR/logs/install.log" 2>&1
        set +x
        PERMS
        BOUNCE_NZBGET
        ;;
    uninstall)
        NZBGET_UNPAK_UNINSTALL
        TRANSMISSION_UNPAK_UNINSTALL
        "$shPath" UNINSTALL
        "$NMT" NMT_UNINSTALL "$appname"
        "$NMT" NMT_UNINSTALL_WS "$wsname" 
        "$NMT" NMT_INSTALL_WS_BANNER "$wsname" "Uninstalled"
        PERMS
        ;;
    check)
        $NMT NMT_CHECK "$INSTALL_DIR" 2> "$INSTALL_DIR/check.err"
        cat "$INSTALL_DIR/logs/listen.log" >> "$INSTALL_DIR/check.log"
        mv $INSTALL_DIR/check.log $INSTALL_DIR/logs/check.log
        "$NMT" NMT_INSTALL_WS_BANNER "$wsname" "Output saved in logs/check.log"
        PERMS
        ;;
esac

rm -f $LOCK
