#!/bin/sh
# oversight launcher - once out of beta this will be replaced with a direct call

ROOT=/share/Apps/oversight
html=$ROOT/tmp/$$.html
err=$ROOT/tmp/$$.err
if /share/Apps/oversight/oversight "$@" > "$html" 2>"$err" ; then
    cat "$html"
else
    echo "Content-Type: text/html"
    echo
    cat "$err"
fi

case "$1" in 
    *admin*)
        chown -R nmt:nmt $ROOT
        ;;
esac
# comment out the following line to diagnose problems.
rm -f -- "$html" "$err"
