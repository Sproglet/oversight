#!/bin/sh

# kill all scans
#

appdir=/share/Apps/oversight

killscans() {
for i in "$appdir/tmp/pid/"*.pid ; do
    if [ -f "$i" ] ; then
        p=`cat $i`
        if [ -d "/proc/$p" ] ; then
            kill "$p" && rm -f "$p"
        fi
    fi
done
}

killscans
"$appdir/bin/jpg_fetch_and_scale" STOP
