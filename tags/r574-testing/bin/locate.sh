#!/bin/sh

# $Id$
# geo location script

get_location1() {
    site="$1"
    tag="$2"
    ua="Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 2.0.50727; .NET CLR 1.1.4322; .NET CLR 3.0.04506.30; .NET CLR 3.0.04506.648)"
    wget -q -O - "$site" -U "$ua" | grep "$tag" | sed -r 's/.*\<([a-z]+)\.(png|gif).*/\1/'
    #wget -q -O - "$site" -U "$ua" | grep "$tag" 
}

get_location() {
#        get_location http://www.ip-adress.com/ "ip address flag"
#        get_location http://www.123myip.co.uk/ "img.country" 
#        get_location http://www.spyber.com/ "src=.flags" 
#        get_location http://www.ipaddresslocation.org "src=.ip.world" 
    if [ !-f $location_file ] ; then

        if ! get_location1 http://www.ip-adress.com/ "ip address flag" ; then
            if ! get_location1 http://www.123myip.co.uk/ "img.country" ; then
                if ! get_location1 http://www.spyber.com/ "src=.flags" ; then
                    get_location1 http://www.ipaddresslocation.org "src=.ip.world" 
                fi
            fi
        fi
    fi
}

if [ $# -eq 0 ] ; then
    echo "usage : location file - return contents of the location file."
    echo "if file doesnt exist the users location is updated from various websites"
else
    file="$1"
    if [ ! -f "$file" ] ; then
        get_location > "$file"
    fi
    cat "$file"
fi
