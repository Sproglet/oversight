#!/bin/sh



##########  YOUR VARS ##########
RARFILE=oversight-20090112-1.rar
TARGET=/share/Apps/oversight
#DAEMON_PROCESS=udpxy
#DAEMON_START="/share/udpxy/udpxy -p 81 -B 262144 -H 8 &"
##########  YOUR VARS ##########




##########  DEFAULT VARS ########## 
MARKER="#M_A_R_K_E_R_do_not_remove_me"
STARTER="/opt/sybhttpd/localhost.drives/HARD_DISK/start_app.sh"
##########  DEFAULT VARS ########## 




##########  DEFAULT METHODS ########## 
start_html()
{
    echo "Content-Type: text/html"
    echo ""
    cat <<EOF
<html>
<head>
<title>
Application installer
</title>
</head>
<body>
EOF
}

end_html() 
{
    cat <<EOF
</body>
</html>
EOF
}

autostart_add()
{
    /bin/cat "$STARTER" | /bin/grep -q "$DAEMON_START"
    if [ $? == 0 ]; then
        echo "Application already set to start on boot, skipping <br>"
    else
        echo "Adding Application to community agreed startup script.<br>"
            
            rm -f /tmp/.starter.tmp
            IFS=""
            cat "$STARTER" | while read line 
            do
                echo "$line" >> /tmp/.starter.tmp
                if [ x"$line" == x"$MARKER" ]; then
                    echo "$DAEMON_START" >> /tmp/.starter.tmp
                fi
            done
        cat < /tmp/.starter.tmp > "$STARTER"
        chmod 755 "$STARTER"
        rm -f /tmp/.starter.tmp
    fi
}
##########  DEFAULT METHODS ##########




##########  YOUR INSTALL CODE ##########
install()
{
    echo -n "Installing new files: "

    #If target folder already exists; remove target folder
    #to enable a clean upgrade
    if [ -d "$TARGET" ]; then
        rm -Rf $TARGET
    fi
    
    #Make sure the target folder exists
    mkdir -p $TARGET
    
    #extract the tar file to target folder
    cd $TARGET
    /mnt/syb8634/bin/unrar x /share/$RARFILE >/dev/null
    
    #start lordy's installer
    chmod +x $TARGET/*.cgi 2>/dev/null
    chmod +x $TARGET/*.sh 2>/dev/null
    chmod +x $TARGET/*.bin 2>/dev/null
    $TARGET/oversight-install.cgi oversight-install
    
    echo "Done<br>"
}
##########  YOUR INSTALL CODE ##########




##########  YOUR STARING AND STOPPING ##########
stop()
{
    echo -n "Stopping current Application: "

    if [ -n "`pidof $DAEMONPROCESS`" ]; then
        kill `pidof $DAEMONPROCESS`
    fi

    TEST=`pidof $DAEMONPROCESS`
    while [ -n "$TEST" ]
    do
        sleep 1
        TEST=`pidof $DAEMONPROCESS`
    done
    echo "Done<br>"
}

start()
{
    echo -n "Starting Application: "
    cd $TARGET
    `$DAEMON_START`
    echo "Done<br>"
}
##########  YOUR STARING AND STOPPING ##########





##########  ENTRY POINT ##########
start_html
#stop
install
#autostart_add
#start
end_html
