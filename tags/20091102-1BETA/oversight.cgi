#!/bin/sh
# oversight launcher - once out of beta this will be replaced with a direct call

OVS_ROOT=/share/Apps/oversight
html=$OVS_ROOT/tmp/$$.html
err=$OVS_ROOT/tmp/$$.err

case "$1" in 
    *admin*)
        chown nmt:nmt $OVS_ROOT/* $OVS_ROOT/conf/* $OVS_ROOT/db/* $OVS_ROOT/db/*/* /share/tmp >/dev/null 2>&1  
        chmod 777 /share/tmp /tmp 2>&1
        ;;
esac

ARCH=nmt100
case "$CPU_MODEL" in
    74K) ARCH=nmt200;;
esac

export PATH="$OVS_ROOT/bin/$ARCH:$OVS_ROOT/bin:$PATH"

if oversight "$@" > "$html" 2>"$err" ; then
    cat "$html"
    rm -f -- "$html" "$err"
else
    echo "Content-Type: text/html"
    echo
    cat "$html"
    cat "$err"
fi

