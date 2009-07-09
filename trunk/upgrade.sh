#!/bin/sh
# $Id$ 
#Cant use named pipes due to blocking at script level

#######################################################
# THIS IS ALL BROKEN For a number of reasons.
# Main one - hdx has no de-compression tools.
# no unzip or gunzip - only common tool is unrar
# but I dont want to create rar files as they 
# are not free.
####################################################
# Now csi uses tar wrapped in zip so we should
# standardise on zip for simplicity.
# but it means hdx/egreat users must instally a newer busybox
# #################################################
EXE=$0
while [ -L "$EXE" ] ; do
    EXE=$( ls -l "$EXE" | sed 's/.*-> //' )
done
APPDIR=$( echo $EXE | sed -r 's|[^/]+$||' )
APPDIR=$(cd "${APPDIR:-.}" ; pwd )
TVMODE=`cat /tmp/tvmode`
OWNER=nmt
GROUP=nmt
cd "$APPDIR"

PERMS() {
    chown $OWNER:$GROUP "$1" "$1"/*
}

HTML() {
    echo "<p>$@<p>"
}


site="http://prodynamic.co.uk/nmt/"
site="http://$appnname.googlecode.com/svn/trunk/packages/"

backupdir="$APPDIR.backup_undo"

# $1 = remove version file
get_new_version() {
    rm -f $$.v
    if wget -q -O $$.v "$site/$1" ; then
        cat $$.v
    else
        echo ""
    fi
    rm -f $$.v
}


UPGRADE() {

    appname="$1"

    cd "$APPDIR"

    new_version_file=version.dl

    echo "<p>Start $1<p>"
    case "$2" in 
        check_stable)
            v=`get_new_version $1.version`
            if [ -n "$v" ] ; then
                echo $v > $new_version_file
            else
                echo ERROR > $new_version_file
            fi
            chown -R $OWNER:$GROUP $new_version_file
            ;;
        check_stable_or_beta)
            #Check both beta and offical releases.
            v=`get_new_version $1.version`
            vb=`get_new_version $1.beta.version`

            #use awk for ordered string compare
            echo | awk '
            END {
  v="'"$v"'";
  vb="'"$vb"'";
  if (v > vb ) {
      print v;
  } else if (vb != "" ) {
    print vb;
  } else {
    print "ERROR";
  }
}' > $new_version_file
            chown -R $OWNER:$GROUP $new_version_file
            ;;
        re-install|install)
            #This is not a first time install but just to overwrite files with
            # downloaded ones. see install-cgi for first time install
            NEWVERSION=`cat $new_version_file`
            tardir="$APPDIR/versions"
            newtgzfile="$appname-$NEWVERSION.tgz" 
            newtarfile="$appname-$NEWVERSION.tar" 

            if [ ! -d "$tardir" ] ; then mkdir p "$tardir" ; fi
            PERMS .

            #Get new
            HTML Fetch $site/$appname/$newtgzfile 
            rm -f -- "$tardir/$newtgzfile"
            if ! wget -q  -O "$tardir/$newtgzfile" "$site/$appname/$newtgzfile" ; then
                echo "ERROR getting $site/$appname/$newtgzfile" > $new_version_file;
                PERMS .
                exit 1
            fi

            $APPDIR/gunzip.php "$tardir/$newtgzfile" "$tardir/$newtarfile"
            rm -f "$tardir/$newtgzfile"

            HTML Backup old files
            if [ -d "$backupdir" ] ; then
                if [ -d "$backupdir.2" ] ; then
                    rm -fr -- "$backupdir.2"
                fi
                mv "$backupdir" "$backupdir.2"
            fi
            cp -a "$APPDIR" "$backupdir"

            if [ -f post-update.sh ] ; then rm -f ./post-update.sh || true ; fi

            HTML Unpack new files
            tar xf "$tardir/$newtarfile"
            chown -R $OWNER:$GROUP .

            HTML Set Permissions
            PERMS "$tardir"

            HTML Post Update actions
            if [ -f post-update.sh ] ; then
                APPDIR="$APPDIR" ./post-update.sh || true
                rm -f ./post-update.sh || true
            fi
            rm -f $new_version_file

            HTML Upgrade Complete
            ;;

        undo)

            if [ ! -d "$backupdir" ] ; then
                echo Cant undo : no folder "$backupdir"
                return 1;
            fi

            if [ -d "$backupdir.abort" ] ; then
                rm -fr -- "$backupdir.abort"
            fi

            mv "$APPDIR" "$backupdir.abort"
            mv "$backupdir" "$APPDIR"
            chown -R $OWNER:$GROUP .

            rm -f $new_version_file
            HTML Undo Complete
            ;;
    esac

}

#
# DISABLED UNTIL DONE PROPERLY
#
#logdir="$APPDIR/logs"
#
#mkdir -p "$logdir"
#
#UPGRADE "$@" > $logdir/upgrade.$$.log 2>&1
#
#chown -R $OWNER:$GROUP $logdir
#
