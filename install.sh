#!/bin/sh
# $Id$ 
#--------------------------------------------------------------------------
# INSTALL SCRIPTS FOR SYABAS NMT PLATFORM (eg PopcornHour)
# (C) Alord 2008 GPL 2 License
#--------------------------------------------------------------------------
set -eu
VERSION=20090605-1BETA

for d in /mnt/syb8634 /nmt/apps ; do
    if [ -f $d/MIN_FIRMWARE_VER ] ; then
        NMT_APP_DIR=$d
    fi
done

NMT_INSTALL_HELP() {
    cat <<HERE
This provides some functions to aid installing/uninstalling.

 -------------------------------------------------------------------

 NMT_INSTALL keyword command

       Add a line command to the community agreed startup file.
       Note that the comment characters ' #{keyword} is added to the command to simplify removal
       Example:
               ./INSTALL.sh NMT_INSTALL myapp "/share/Apps/myhome/myapp.sh &"

       Or to be slightly more efficient:

       if grep -q '#{myapp}' /share/start_app.sh ; then 
           ./INSTALL.sh INSTALL myapp "/share/Apps/myhome/myapp.sh &"
       fi

 -------------------------------------------------------------------

 NMT_UNINSTALL keyword

   Remove all lines matching keyword from the community startup file.
   The file is searched for '#{keyword}'
       Example:
               ./INSTALL.sh NMT_UNINSTALL myapp

 -------------------------------------------------------------------

 NMT_INSTALL_WITHOUT_LABEL keyword command

       Add a line command to the community agreed startup file.
       No additional text is added, this may produce false positives when uninstalling.

 -------------------------------------------------------------------

 NMT_UNINSTALL_WITHOUT_LABEL text

   Remove all lines matching keyword from the community startup file.
   The file is searched for 'text', so ensure the text is unique.
   This is to allow removal of lines that were not added with the keyword comment.
       Example:
               ./INSTALL.sh NMT_UNINSTALL_BY_TEXT myoldapp.sh

 -------------------------------------------------------------------

 NMT_LINE_REMOVE text file

    Remove any lines from file that match 'text', creating a backup.

 -------------------------------------------------------------------

NMT_INSTALL_WS name url

    Add/Change a web service.
    If the name already exists the url will be updated otherwise added.
    If the url is blank it will be deleted.

 -------------------------------------------------------------------

NMT_UNINSTALL_WS name

    Remove named webservice.

 -------------------------------------------------------------------

 NMT_CRON_ADD user id line
 NMT_CRON_DEL user id

 -------------------------------------------------------------------

 
HERE
}

LOAD_SETTINGS() {
    #load all settings from syabas generated file (esp Workgroup & ipaddress)
    sed '/=/ {s/=/="/;s/$/"/}' /tmp/setting.txt > /tmp/setting.txt.sh
    . /tmp/setting.txt.sh
}

NMT_INSTALL_STARTSH="/share/start_app.sh"
NMT_INSTALL_MARKER="#M_A_R_K_E_R_do_not_remove_me"

#This is the standard NMT script which will be modified to launch the community install script.
#Dont change this otherwise the community script may get launched twice.
NMT_INSTALL_STANDARD_SCRIPT="$NMT_APP_DIR/etc/ftpserver.sh"

#--------------------------------------------------------------------------
#
# Create the startup script
#
NMT_INSTALL_CREATE_STARTFILE() {

    if [ ! -f "$NMT_INSTALL_STARTSH" ] ; then
        cat <<HERE > "$NMT_INSTALL_STARTSH"
#!/bin/sh
#
$NMT_INSTALL_MARKER

exit 0
HERE
        chmod ugo+x "$NMT_INSTALL_STARTSH"
    fi
    NMT_LINE_APPEND start_app.sh "$NMT_INSTALL_STANDARD_SCRIPT" "^start\(\)" "\t$NMT_INSTALL_STARTSH &"
}

#--------------------------------------------------------------------------
#
#
# Add a line to a script.
#
# $1=keyword to check if line is present.
# $2=path to script
# $3=Marker below which line is added.
# $4=line of text to add (note the comment #{keyword} is added to the line.)

NMT_LINE_SET() {
    NMT_LINE_REMOVE "$1" "$2" && NMT_LINE_APPEND "$1" "$2" "$3" "$4"
}

# $1=keyword to check if line is present. (only used during removal)
# $2=path to script
# $3=Marker below which line is added.
# $4=line of text to add (note the comment #{keyword} is added to the line.)
NMT_LINE_APPEND() {
    touch "$2"
    if [ -f "$2" ] ; then
        if ! fgrep -ql "$1" "$2" ; then
            if awk '
BEGIN {
    keyword="'"$1"'";
    file="'"$2"'";
    marker="'"$3"'";
    new_line="'"$4"'";
}

{ print } 
        
marker != "" && match($0,marker) {
    printf "%s #{%s}\n",new_line,keyword;
}

END {
    #If there is no keyword add at the end
    if (marker == "") {
        printf "%s #{%s}\n",new_line,keyword;
    }
}
' "$2" > "$2.new" ; then
                cp "$2" "$2.bak"
                cat "$2.new" > "$2" && rm -f "$2.new" #cat keeps perms of original
            fi
        fi
    fi
}

#--------------------------------------------------------------------------
#
# Install a new startup line into start_app.sh. This does not add a label to the line.
#$1=keyword.
#$2=line to be added.
NMT_INSTALL_WITHOUT_LABEL() {
    if [ ! -f "$NMT_INSTALL_STARTSH" ] ; then
        NMT_INSTALL_CREATE_STARTFILE
    fi
    NMT_LINE_APPEND "$1" "$NMT_INSTALL_STARTSH" "$NMT_INSTALL_MARKER" "$2"
}
#--------------------------------------------------------------------------
#
# Install a new startup line into start_app.sh. This adds a label for easy removal
#$1=keyword.
#$2=line to be added.
NMT_INSTALL() {
    if [ ! -f "$NMT_INSTALL_STARTSH" ] ; then
        NMT_INSTALL_CREATE_STARTFILE
    fi
    NMT_LINE_APPEND "$1" "$NMT_INSTALL_STARTSH" "$NMT_INSTALL_MARKER" "$2 #{$1}"
}

#--------------------------------------------------------------------------
#
#Perform an uninstall by looking for the keyword.
#$1=keyword
NMT_UNINSTALL() {
    NMT_LINE_REMOVE "#{$1}" "$NMT_INSTALL_STARTSH"
}

#--------------------------------------------------------------------------
#
#Perform an uninstall by looking for raw text. Use this for apps that were added using other code.
#$1=text
NMT_UNINSTALL_WITHOUT_LABEL() {
    NMT_LINE_REMOVE "$1" "$NMT_INSTALL_STARTSH"
}

#$1=keyword $2=file
NMT_LINE_REMOVE() {
    if grep -ql "$1" "$2" ; then
        grep -v "$1" "$2" > "$2.new" 
        cat "$2.new" > "$2" && rm -f "$2.new" #cat keeps perms of original
    fi
}

#--------------------------------------------------------------------------
#
# We could split this out into 3 functions , NMT_INSTALL_WS_GET_INDEX , NMT_INSTALL_WS_NEXT_BLANK etc.
# Add/Change a web service
#$1=Name $2=url
NMT_INSTALL_WS() {

    #Escape meta-chars
    #n=`echo "$1" | sed -r 's/([][.*()^$\\])/\\\\\1/g'`
    
    ws=`grep -i "services_name.=$1\$" /tmp/setting.txt | head -1 | sed 's/services_name//;s/=.*//'`
    if [ -n "$ws" ] ; then
        if [ -z "$2" ] ; then
            pflash set services_name$ws ""
        fi
        pflash set services_url$ws "$2"
        /opt/sybhttpd/default/webservices.cgi
    else
        #Look for empty lost
        if [ -n "$2" ] ; then
            #Get first empty slot - note they are not in order nor all present in /mp/setting.txt
            ws=`awk '
BEGIN {for(i=1;i<=9;i++) ws[i]=1; } 
/^services_name([0-9])=./ {i=substr($0,index($0,"=")-1,1)+0; ws[i]=0; } 
END {for(i=1;i<=9;i++) if (ws[i]==1) { print i; exit 0; } ; }' /tmp/setting.txt`
            if [ -n "$ws" ] ; then
                pflash set services_name$ws "$1"
                pflash set services_url$ws "$2"
                /opt/sybhttpd/default/webservices.cgi
            else
                echo "No spare Web service slots"
            fi
        fi
    fi
}

#--------------------------------------------------------------------------
#
#Remove a WebService # all case variants
# $1=Name
NMT_UNINSTALL_WS() {
    while grep -i "services_name.=$1\$" /tmp/setting.txt ; do
        NMT_INSTALL_WS "$1" ""
    done
}

URL_ESCAPE() {
    #sed -r 's/[?]/%3F/g;s/\&/%26/g;s/\:/%3A/g;s/\//%2F/g'
    sed -r 's/[?]/%3F/g;s/\&/%26/g;s/%20/ /g'
}

#Show a simply install complete banner. This could be changed to a div
#$1 title
#$2 message
NMT_INSTALL_WS_BANNER() {

    cat <<HERE
<body bgcolor="#000022" text="white" link="white"><center>
$1
<hr>
$2
         <br><a href="http://127.0.0.1:8883/webservices_list.html">Show Webservice List</a>
         <br><a href="http://127.0.0.1:8883/setups.cgi?%7FhiDe=9">Setup</a>

</center></body>
HERE

}

cronclean() {
    rm -f /tmp/crontab.$$ /tmp/crontab.$$.new
}
#Add Crontab line with a id comment 
# $1=user
# $2=appid 
# $3=full line
NMT_CRON_ADD() {
    touch /tmp/crontab.$$
    if [ -f /tmp/cron/crontabs/$1 ] ; then
        crontab -u $1 -l > /tmp/crontab.$$
    fi
    if awk '
/#'"$2"'$/ { print "'"$3"' #'"$2"'" ; f=1; next } 
1 
END { if(!f) print "'"$3"' #'"$2"'"; }' /tmp/crontab.$$ > /tmp/crontab.$$.new ; then
    crontab /tmp/crontab.$$.new -u $1 && cronclean
    fi
}

#Remove Crontab line with a id comment 
# $1=user 
# $2=appid 
NMT_CRON_DEL() {
    if [ -f /tmp/cron/crontabs/$1 ] ; then
        crontab -u $1 -l > /tmp/crontab.$$
        grep -v "#$2$" /tmp/crontab.$$ > /tmp/crontab.$$.new || true
        crontab /tmp/crontab.$$.new -u $1 && cronclean
    fi
}

TEST1() {
    NMT_INSTALL google "#Google "
    NMT_INSTALL_WS google "http://m.google.com/?dc=gbackstop"
}

TEST2() {
    NMT_UNINSTALL google
    NMT_INSTALL_WS google ""
}

NMT_INSTALL_TEST() {
    TEST1
    echo press
    read x
    TEST2
}

# $1 = install dir
NMT_CHECK() {
    rm -f "$1/check.log"
    SCRIPT "$1" | DO > "$1/check.log" 2>&1
}
DO() {
    set -e
    while IFS= read cmd ; do
        #echo "==============`date` ======================="
        echo "========= CMD:$cmd: =============="
        ( eval "$cmd || echo ERROR" ) || echo parse err 
        echo
    done
}

SCRIPT() {
    LOAD_SETTINGS
cat <<HERE
    env
    date
    uptime
    cat $NMT_APP_DIR/VERSION
    grep ^VERSION "$1/"*
    $NMT_APP_DIR/bin/nzbget -v
    egrep -iv '(^#|^$|username|password)' /share/.nzbget/nzbget.conf
    sed -r 's/(passwd|password)=.*/\1=XXX/' /tmp/setting.txt | egrep -v '(wlan|audio|BTPD|hostname)'
    crontab -u root -l 
    crontab -u nmt -l
    cat /etc/cron.hourly
    cat /etc/cron.weekly
    df
    ls -Rl "$1"
    ls -l /share/start_app.sh
    cat /share/start_app.sh
    awk "/^start()/,/^stop()/ 1" $NMT_APP_DIR/etc/ftpserver.sh
    for i in *cgi ; do echo CGI \$i ; ./\$i | head -5 ; done
    ls -Rl /tmp/local*8883
    ps  | grep " nmt" 
    ps  | grep " nobody" 
    ps  | grep " root" | egrep -v "(upnp|sbin)"
    /bin/busybox | awk '/^Usage/,/^Currently/ { next; } 1'
    /share/bin/busybox*  | awk '/^Usage/,/^Currently/ { next; } 1'
    ping $eth_gateway -c 1 
    ping news.bbc.co.uk -c 1
    ping 4.2.2.1 -c 1
    nslookup google.com $eth_dns
    nslookup google.com $eth_dns2
HERE
}

case "${1:-}" in
    NMT_*) "$@" ;;
    TEST) NMT_INSTALL_TEST ;;
    *)
        echo "$@"
        NMT_INSTALL_HELP;;
esac

# vi:shiftwidth=4:tabstop=4:expandtab
