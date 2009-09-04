#!/bin/sh
# oversight launcher - once out of beta this will be replaced with a direct call

ROOT=/share/Apps/oversight
html=$ROOT/tmp/$$.html
err=$ROOT/tmp/$$.err

case "$1" in 
    *admin*)
        chown -R nmt:nmt $ROOT >/dev/null 2>&1  
        ;;
esac

if /share/Apps/oversight/oversight "$@" > "$html" 2>"$err" ; then
    cat "$html"
    rm -f -- "$html" "$err"
else
    echo "Content-Type: text/html"
    echo
    cat "$html"
    cat "$err"
fi

