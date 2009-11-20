#!/bin/sh
# oversight launcher - once out of beta this will be replaced with a direct call

OVS_ROOT=/share/Apps/oversight
html=$OVS_ROOT/tmp/$$.html
err=$OVS_ROOT/tmp/$$.err

case "$1" in 
    *admin*)
        chown nmt:nmt $OVS_ROOT/* $OVS_ROOT/conf/* $OVS_ROOT/db/* $OVS_ROOT/db/*/* /share/tmp >/dev/null 2>&1  
        chmod 777 /share/tmp /tmp $OVS_ROOT/tmp 2>&1
        ;;
esac

ARCH=nmt100
case "$CPU_MODEL" in
    74K) ARCH=nmt200;;
esac

export PATH="$OVS_ROOT/bin/$ARCH:$OVS_ROOT/bin:$PATH"
bin="$OVS_ROOT/bin/$ARCH/oversight"
cgi="$0"

#The first time the script runs it will replace itself with the oversight binary file.
#To re-instate this wrapper script (eg for debugging) copy oversight.cgi.safe to oversight.cgi

REPLACE_BINARY() {
    sed 's/^REPLACE_BINARY$/#REPLACE_BINARY/' "$cgi" > "$cgi.safe"
    exec cat "$bin"  > "$cgi" # exec this to stop shell reading the binary file!
}



if oversight "$@" > "$html" 2>"$err" ; then
    cat "$html"
    rm -f -- "$html" "$err"
else
    echo "Content-Type: text/html"
    echo
    cat "$html"
    cat "$err"
fi

#Uncomment the following line
REPLACE_BINARY
