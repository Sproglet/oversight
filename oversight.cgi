#!/bin/sh
# oversight launcher - once out of beta this will be replaced with a direct call

ROOT=/share/Apps/oversight
html=$ROOT/tmp/$$.html
err=$ROOT/tmp/$$.err
if /share/Apps/oversight/oversight "$@" > "$html" 2>"$err" ; then
    cat "$html"
    rm -f -- "$html" "$err"
else
    echo "Content-Type: text/html"
    echo
    cat "$html"
    cat "$err"
fi

case "$1" in 
    *admin*)
        chown -R nmt:nmt $ROOT
        ;;
esac
