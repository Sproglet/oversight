#!/bin/sh
# $Id$ 

# Force bash else run under current shell and hope it can cope - eg *some* busybox
[ -z "${OVS_ENV_UNPAK:-}" ] && which bash > /dev/null && OVS_ENV_UNPAK=1 exec bash "$0" "$@"


# unpak script for nzbget.

nzb_launch_dir="$OLDPWD"
#--------------------------------------------------------------------------
set -u  #Abort with unset variables


#
# unpak.sh - 
#   nzbget post processing script for Popcornhour. Based on the one release
# with the August 2008 firmware.
#
# The script just uses syntax/commands found on the Popcorn Hour (busybox/ash)
# So not all commands are present (eg wc,tail) and some do not support GNU switches.
# TODO Test Par check with multiple mp3.
#TODO Cope with par,zip combos. Currently it will try to repair rather than unzip-repair
#this IS the default bevaviour for non-rar sets. but other types of archive maybe not best.

#Find install folder
EXE="$0"
while [ -h "$EXE" ] ; do EXE="$(readlink "$EXE")"; done
BINDIR="$( cd "$( dirname "$EXE" )" && pwd )"

source $BINDIR/ovsenv

# Copyright (C) 2008/9 Andrew Lord <nzbget @ lordy.org.uk>
# 
# Contributers:
# Original Version: Peter Roubos,Otmar Werner
# Suggestions: Andrei Prygounkov
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.


#########################################################################
# Settings section - see unpak.cfg.example
#########################################################################
# Settings are read from the file specified. If the file does not exist
# it will be created from the unpak.cfg.example file.
# If unpak_load_settings starts with '/' it's location is absolute,
# otherwise it is relative to the location of this script.
unpak_default_settings=conf/.unpak.cfg.defaults
unpak_load_settings=conf/unpak.cfg

########################################################################
# SECTION: LOGGING FUNCTIONS
########################################################################

# Add logging text to stdout of some other command.
# echo hello | log_stream INFO test  > [INFO] test:hello
# echo "" | log_stream INFO test  > {nothing}
log_stream() {
    # Sed doesnt flush stdout in a timely fashion
    #sed "/^\$/d;s/^/[$1] $2:/" >&2
    # system("") forces flush
    awk '/^$/ { next } { printf "['"$1"'] '"${2:-}"':%s\n",$0 ; system("") ; }' >&2
}

LOG() {
    label="$1" ; shift;
    if [ -n "$*" ] ; then
        echo "[$label] $@"  >&2 
    fi
}

INFO() { LOG INFO "$@" ; }
WARNING() { LOG WARNING "$@" ; }
ERROR() { LOG ERROR "$@" ; }
DEBUG() { LOG DEBUG "$@"; }
DETAIL() { LOG DETAIL "$@"; }

########################################################################
# SECTION: CONFIG FUNCTIONS
########################################################################


set_p2p_exit_codes() {
        POSTPROCESS_ERROR=1
        POSTPROCESS_SUCCESS=0
}

# General comparison using awk. Some devices has bourne or ash (not bash)
cmp() {
    echo | awk "{ s= ( \"$1\" $2 \"$3\" ); } END { exit(1-s); }"
}

set_nzbget_exit_codes() {
    if cmp "${NZBOP_VERSION:-}" ">" "0.7.0-testing-r341" ; then
        POSTPROCESS_PARCHECK_CURRENT=91
        POSTPROCESS_PARCHECK_ALL=92
        POSTPROCESS_SUCCESS=93
        POSTPROCESS_ERROR=94
        POSTPROCESS_NONE=95
    else
        POSTPROCESS_ERROR=94
        POSTPROCESS_SUCCESS=0
    fi
}

#Get nzbget's settings if they are not in the environment. This is for older versions.
#Get all lines with / = / remove spaces around '=' , prefix with NZBOP_ , upper case , replace x.y=z with x_y=z
load_nzbget_settings_pre_v7() {
    #eg ParCheck will become NZBOP_PARCHECK
    if [ -z "${NZBOP_APPBIN:-}" ] ; then
    nzbget_cmd -p | awk '
/ = / {
    $0 = "NZBOP_"$0;
    $1=toupper($1);
    gsub(/\./,"_",$1);
    sub(/ = /,"=");
    print $0;
}' > "$gTmpFile.nzb_cfg"
        #nzbget_cmd -p | grep ' = ' | sed 's/^/NZBOP_/;s/ = /=/;s/\.\([^=]*\)=/_\1=/' | grep -v 'nzbget_server' > "$gTmpFile.nzb_cfg"
        . "$gTmpFile.nzb_cfg"
        rm "$gTmpFile.nzb_cfg"
        set | grep '^NZBOP_' | grep -iv password | log_stream DEBUG "conf"
    fi
}

WHICH() {
    # search path 
    for d in "$NMT_APP_DIR/bin" "${unpak_nzbget_bin%/nzbget}" ${PATH//:/ } ; do
        if [ -f "$d/$1" ] ; then
            INFO "Using $d/$1"
            echo "$d/$1"
            return 0
        else
            INFO "$1 not in $d"
        fi
    done
    WARNING "can not find $1"
    return 0
}

#Determine unpak_nzbget_bin and unpak_nzbget_conf
#For current nzbget there are no env vars with this setting. This may change
#in the future
get_nzbpath() {
    #If future variables are defined. These might be the names.
    if [ -z "${unpak_nzbget_bin:-}" -a -n "${NZBOP_APPBIN:-}" ] ; then
        unpak_nzbget_bin="$NZBOP_APPBIN"
    fi
    if [ -z "${unpak_nzbget_conf:-}" -a -n "${NZBOP_CONFIGFILE:-}" ] ; then
        unpak_nzbget_conf="$NZBOP_CONFIGFILE"
    fi

    if [ -z "${unpak_nzbget_bin:-}" -o -z "${unpak_nzbget_conf:-}" ] ; then
        get_nzbpath_pre_v7
    fi
    INFO "unpak_nzbget_bin=${unpak_nzbget_bin:-}"
    INFO "unpak_nzbget_conf=${unpak_nzbget_conf:-}"
    if [ -z "${unpak_nzbget_bin:-}" ]; then ERROR "unpak_nzbget_bin unset" ; abort ; fi
    if [ -z "${unpak_nzbget_conf:-}" ]; then
        ERROR "unpak_nzbget_conf unset" ; abort ; 
    else
        if [ ! -f "${unpak_nzbget_conf}" ] ; then
            #relative path maybe. OLDPWD should be the folder nzbget was initially started from
            unpak_nzbget_conf="$nzb_launch_dir/$unpak_nzbget_conf"
            if [ ! -f "${unpak_nzbget_conf}" ] ; then
                ERROR "Require absolute path to configuration file $unpak_nzbget_conf"
                ERROR "Either declare unpak_nzbget_conf in unpak.cfg or restart nzbget with full path to config file"
                exit
            fi 
        fi 
    fi
    INFO "unpak_nzbget_conf=${unpak_nzbget_conf:-}"
}

#This will get nzbget path from versions of nzbget earlier than 0.7
get_nzbpath_pre_v7() {
    pid=
    #Try to find nzbget pid from lock file. could also use pidof
    if [ -z "${NZBOP_LOCKFILE:-}" ] ; then
        for d in /share/tmp /tmp /var/tmp ; do
            if [ -f "$d/nzbget.lock" ] ; then
                if [ -n "${NZBOP_LOCKFILE:-}" ] ; then
                    if [ ! "$NZBOP_LOCKFILE" -ef "$d/nzbget.lock" ] ; then
                        #Note nmt can have two common nzbget install locations. so check until this is resolved
                        #(by CSI installer using same lockfile for both)
                        ERROR "multiple nzblock files. Please stop one nzbget" 
                        abort
                    fi
                fi
                NZBOP_LOCKFILE="$d/nzbget.lock"
                echo lock $NZBOP_LOCKFILE
            fi
        done
    fi
    if [ -z "$pid" ] ; then
        #pidof doesnt tell us the oldest process. so look at proc/*/status for name and ppid=1
        for st in $( grep -l 'Name:.nzbget$' /proc/*/status ) ; do
            if grep -q 'PPid:.1$' $st 2>/dev/null ; then
                pid="${st#/proc/}"
                pid="${pid%/status}"
                break
            fi
        done
        echo from proc pid = $pid
    fi
    if [ -n "$pid" ] ; then
        if [ -z "${unpak_nzbget_bin:-}" ]; then
            #Note unpak may be running as different user to one that started nzbget so no access
            #to /proc/$pid/exe (on NMT) however we can get this from the first line of /proc/$pid/maps
            #unpak_nzbget_bin=/proc/$pid/ex\e
            unpak_nzbget_bin="`sed -n '1 s,^[^/]*,,p' /proc/$pid/maps`"
        fi
        #cmdline=arg\0arg\0arg\0...
        #gnu awk reads this as a single line 
        #busybox awk reads it as seperate lines.
        #so first awk below split it at \0 into seperate lines
        #second awk extracts the line after -c
        #This will fail if conf file is relative path, but we can use OLDPWD hopefully
        if [ -z "${unpak_nzbget_conf:-}" ]; then
            #for backtick we need to double escape the \0 - one for awk and one for backtick
            unpak_nzbget_conf="`awk '{ split($0,args,"\\\\0");for (a=1;(a in args);a++) print args[a];}' /proc/$pid/cmdline | awk '/^-c$/ { getline ; print }'`"
        fi
    fi
}

# This is a hook for the oversight installer to find the nzbget command.
# it is not used by the stand-alone unpak scripts.
nzbget_cmd_request() {
    get_nzbpath
    if [ -f "$unpak_nzbget_bin" -a -f "$unpak_nzbget_conf" ] ; then
        if [ "$1" = "restart" ] ; then
            #need restart command because we cant find nzbget details after it is stopped.
            nzbget_cmd -Q
            sleep 5
            nzbget_cmd -D
        else
            nzbget_cmd "$@"
        fi
    fi
}

unpak_settings_version=1
# Cant call logging yet.
load_unpak_settings() {

    cfg="$1"
    case "$cfg" in
        /*) true;;
        *) cfg="$OVS_HOME/$cfg" ;;
    esac

    INFO "load_unpak_settings [$cfg]"

    if [ -n "$cfg" ] ; then
        #If there is no sample cfg - create one
        if [ ! -f "$cfg" ] ; then
            if [ ! -f "$cfg.example" ] ; then
                cp ".$cfg.defaults" "$cfg.example"
            fi
            cp "$cfg.example" "$cfg"
            echo "Create $cfg file from example"
        fi

        # fix endings for notepad people
        dos2unix "$cfg" || true
        source "$cfg"
    fi
}

check_settings() {
    if [ "$mode" != nzbget ] ; then return ; fi
    settings=0
    external_par_check=0
    load_nzbget_settings_pre_v7
    if [ "$NZBOP_PARCHECK" = "yes" ] ; then
        INFO "config: Mandatory parchecking already enabled in nzbget.conf"
    else
        if [ "$unpak_disable_external_par_repair" -eq 1 ] ; then
            INFO "config: ALL parchecking/reparing is completely disabled."
        else
            if [ "$arg_par_check" -eq 0 ]; then 
                INFO "config: Parchecking enabled in $script_name"
                external_par_check=1
            else
                ERROR "config: nzbget has Parchecked although this is disabled in nzbget.conf. May need to restart nzbget"
            fi
        fi
    fi
    if [ "$external_par_check" -eq 1 ] ; then
#        if [ "$unpak_delete_rar_files" -eq 0 ] ; then
#           ERROR "config:unpak_delete_rar_files should be set if using external par repair feature"
#           settings=1
#       fi
        if [ "$NZBOP_LOADPARS" != "all" ] ; then
            if [ "$NZBOP_ALLOWREPROCESS" != "yes" ] ; then
                WARNING "config: IF LoadPars is not all then AllowReProcess should be yes in nzbget.conf"
               settings=1
            fi
        else
            if [ "$NZBOP_ALLOWREPROCESS" = "yes" ] ; then
                WARNING "config: If AllowReProcess is 'yes' then its more efficient to set LoadPars=none in nzbget.conf"
            fi
        fi
    fi
    [ "$settings" -eq 0 ]
}

#####################################################################
# SECTION: PAR REPAIR
#####################################################################

par_flag="unpak.need.pars";
set_waiting_for_pars() { touch "$par_flag" ; }

clear_waiting_for_pars() { rm -f -- "$par_flag" ; }

waiting_for_pars() { [ -e "$par_flag" ] ; }

get_paused_ids() {
    # Look in the nzbget list for the given group.

    # search list using fgrep to avoid metacharacter issues '][.'
    # However this may lead to substring matches (no anchoring), so surround the group name with
    #asterisks first as these cannot appear inside an group name.

    #Was using NZB_NICE_NAME but arg_download_dir may be better.
    ids="$NZB_NICE_NAME"
    ids=`basename "$arg_download_dir" ""`
    ids=$(nzbget_cmd -L | sed 's/ / */;s,/,*/,' | fgrep "*$ids*/" | sed -n '/[Pp][Aa][Rr]2\>.*paused)$/ s/^\[\([0-9]*\)\].*/\1/p')
    echo $ids | sed 's/ /,/g'
}
#Unpauses par files. Returns error if nothing to unpause.
unpause_pars_and_reprocess() {
    if [ "$mode" != nzbget ] ; then return ; fi
    if [ "$NZBOP_ALLOWREPROCESS" != "yes" ] ; then
        ERROR "AllowReProcess disabled. Cannot repair"
        return 1
    fi
    INFO "Downloading pars in $arg_nzb_file"
    ids=$(get_paused_ids)
    INFO "Unpaused ids [$ids]"
    if [ -n "$ids" ] ; then
        nzbget_cmd -E U $ids
        nzbget_cmd -E T $ids
        set_waiting_for_pars
    else
        return 1
    fi
}
delete_paused_pars() {
    if [ "$mode" != nzbget ] ; then return ; fi
    if [ "$arg_par_check" -eq 0 -a "$external_par_check" -eq 1 -a "$unpak_external_par_repair_tidy_queue" -eq 1 ] ; then
        INFO "Deleting paused parts of $arg_nzb_file"
        ids=$(get_paused_ids)

        if [ -n "$ids" ] ; then
            nzbget_cmd -E D $ids
        fi
    fi
}

#In case there are two or more par sets just look for .par2 files. (not PAR2 files)
#TODO. We may need to know which Pars fix which rars in future so we can be more
#selective with unraring when errors occur. But for now take an all or nothing approach.
par_repair_all() {
    INFO "Start Par Repair"

    ordered_par_list > "$gTmpFile.par_size" 
    #First identify parsets for all FAILED or UNKNOWN rars.
    if no_rars ; then
        # Process a folder that does not contain any rar files.
        # ------------------------------------------------------
        # Maybe mp3s etc. Just look at *.par2.
        # TODO. Identify par sets correctly rather than just looking at *par2
        while IFS= read p ; do
            par_repair "$p" || true
        done < "$gTmpFile.par_size"
    else
        #Fix all broken rars only. These will only be top level rars.
        # -----------------------------------------------------------
        list_rar_states "(FAILED|UNKNOWN)" > "$gTmpFile.failed_or_unknown"
        while IFS= read rarPart ; do
            #Find the first par file that looks like it may fix the rar file.
            #TODO This may fail occasionally with accidental substring matches. But its quick and easy
            INFO "Finding PARS for $rarPart"
            while IFS= read p ; do
                name_re="`echo "$rarPart." | re_escape`(part|rar|r[0-9][0-9])"
                if [ -f "$p" ] && egrep -il "$name_re" "$p" > /dev/null ; then
                    if par_repair "$p" ; then
                        set_rar_state "$rarPart" REPAIRED
                    fi
                    break
                fi
            done < "$gTmpFile.par_size"
        done < "$gTmpFile.failed_or_unknown"
        rm -f -- "$gTmpFile.failed_or_unknown"
    fi
    rm -f -- "$gTmpFile.par_size"
}

#Get one file from each par set ordered by size. This assumes the convention of consistently named parsets.
# http://parchive.sourceforge.net/docs/specifications/parity-volume-spec/article-spec.html#i__134603784_1147
ordered_par_list() {
    ls -rS *[Pp][Aa][Rr]2 2>/dev/null | awk '
match($0,/.*\.[Vv][Oo][Ll][0-9]/) { setpar(substr($0,1,RLENGTH-5),$0); next ; }
match($0,/.*\.[Pp][Aa][Rr]2/) { setpar(substr($0,1,RLENGTH-5),$0); next ; }
function setpar(prefix,file) {
    if (p[prefix] == "" ) {
        p[prefix]=file;
    }
}
END {
    for (i in p) {
       print p[i];
   }
}' 
}

par_repair() {
    if [ "$mode" != nzbget ] ; then return ; fi
    parFile="$1"

    INFO "Par Repair using $parFile"

    if [ "$pause_nzbget_during_par2repair" -eq 1 ] ; then
        pause_nzbget
    fi

    set +e
    out="$gTmpFile.p2_out"
    err="$gTmpFile.p2_err"
    par2 repair "$parFile" > "$out" 2>"$err" &
    par_monitor "$out" "$parFile"

    par_state=1
    if egrep -q "(Repair complete|All files are correct)" "$out" ; then
        if [ ! -s "$err" ] ; then
            par_state=0
        fi
    fi



    if [ "$pause_nzbget_during_par2repair" -eq 1 ] ; then
        unpause_nzbget
    fi

    if [ "$par_state" -eq 0 ] ; then

        INFO "Repair OK : $parFile"
        #We delete par files right away once par is repaired
        # as it speeds up matching a rar to remaining pars.
        delete_par_files "$out"

    else

        ERROR "Repair FAILED : $parFile"
        awk '!/\r/' "$out" | log_stream ERROR "par2out"
        log_stream ERROR "par2err" < "$err"

    fi

    #Avoid confusion due to .1 extension
    par_rename_damaged_files "$out"
    rm -f -- "$err" "$out"
    return "$par_state"
}

# Input $1 = par stdout file (with emedded \r's)
par_clean_output() {
    awk '{ 
            gsub(/\r$/,"") ;        #remove last CR 
            gsub(/.*\r/,"") ;       #Strip all text
            print;
        }' "$1" 
}

#Delete Par files based on Par Output eg.
# <Loading "my.par.file.vol001+02.PAR2".>
delete_par_files() {
    DETAIL "Deleting Par Files"
    par_clean_output "$1" |\
    sed -rn 's/^Loading "(.*)"\.$/\1/p' |\
    exec_file_list "rm -f \1" ""
}

#Par uses .n extension for damaged files. Eg file.avi.1 
#this causes problems because .1 is also a possible Rar or Split extension.
#So find any damaged files and rename file.1 to file.1.damaged
# Input $1 = par stdout file (with emedded \r's)
par_rename_damaged_files() {
    # [Scanning: "filename": nn.n%] -> [Scanning: "filename"]
    par_clean_output "$1" |\
    awk '/Verifying repaired files/,/Repair complete/ {print}'  |\
    sed -rn 's/Target: "(.*)" - found\.$/\1.1/p' |\
    exec_file_list '[ ! -e \1 ] || mv \1 \1.damaged' ""
}

# Return name of current file beg
par_output_get_current_action() {
    # [Scanning: "filename": nn.n%] -> [Scanning: "filename"]
    sed -n '/^[A-Z][a-z]*:/ s/": [^"]*$/"/p'
}
par_output_get_current_percentage() {
    # [Repairing: "filename": nn.n%] -> [nnn] (ie 000 to 1000 )
    sed -nr '/^Repairing:/ { s/^.*": 0*([0-9]*)(|\.)[0-9]*\%.*/\1\2/p}'
}

#Get the last line from Par output. Each line may have many <CR>. 
#we need the text between the last two <CR>s on the last line.
par_output_get_last_line() {
    #We really want sep to be \r but this doesnt work as a parameter.
    awk 'BEGIN{ FS="\r";} END {  print $(NF-1); }' "$1"
}

par_monitor() {
    outfile="$1"
    cmdTxt="$2"
    percent_old=
    scanning_old=""
    loggedParStats=0
    gap=0
    eta=0
    initial_poll=10
    scan_poll=10
    short_repair_poll=20 #seconds
    long_repair_poll=600 #seconds
    poll_time=$initial_poll
    bad_eta_count=0
    DEBUG "par_monitor"
    touch "$outfile"
    p2pid=$(get_pid_by_exe par2 "$PWD" "$cmdTxt" )
    if [ ! -n "$p2pid" ] ; then
        return 1
    fi

    while true ; do
        sleep "$poll_time"
        if [ ! -f "$outfile" ] ; then break ; fi
        if [ ! -d "/proc/$p2pid" ] ; then break ; fi # Par process gone?
        
        line=$(par_output_get_last_line "$outfile")
        case "$line" in
            Repairing:*)
            #Get percentage nn.m% and convert to nnm
            percent_new=$(echo "$line" | par_output_get_current_percentage)
            if [ -n "$percent_new" ] ; then
                gap=$(( $gap + $poll_time ))
                DEBUG "$percent_old - $percent_new after $gap secs"
                if [ -n "$percent_old" -a "$percent_old" -ne $percent_new ] ; then

                    if [ $loggedParStats -eq 0 ]; then
                        loggedParStats=1
                        awk '!/\r/' "$outfile" | log_stream DEBUG "par2out"
                    fi

                    eta=$(( (1000-$percent_new)*$gap/($percent_new-$percent_old) ))

                    if [ $eta -lt 60 ] ; then
                        eta_text="${eta}s"
                    else
                        eta_text="$(( $eta/60 ))m $(( $eta % 60 ))s"
                    fi

                    msg="Par repair will complete in approx. $eta_text"
                    if [ $unpak_maximum_par_repair_minutes -gt 0 -a  $eta -gt $(( $unpak_maximum_par_repair_minutes * 60 )) ] ; then
                        msg="$msg ( limit is ${unpak_maximum_par_repair_minutes}m )"
                        if [ $bad_eta_count -le 1 ] ; then
                            WARNING "$msg"
                            bad_eta_count=$(( $bad_eta_count + 1 ))
                        else
                            ERROR "$msg"
                            kill $p2pid
                            break
                        fi

                    else
                        INFO "$msg"
                    fi

                    gap=0
                fi
                percent_old=$percent_new
            fi
            #Once we have got an eta  , adjust the reporting interval 
            # if par2repair looks like it is going to be a while
            poll_time=$(( $eta / 20 ))
            if [ $poll_time -lt $short_repair_poll ] ; then poll_time=$short_repair_poll ; fi
            if [ $poll_time -gt $long_repair_poll ] ; then poll_time=$long_repair_poll ; fi

            ;;
        *)  # Show General Par action. Some lines will be skipped due to polling
            par_action_new=$(echo "$line" | par_output_get_current_action)
            if [ -n "$par_action_new" ] ; then
                poll_time=$scan_poll
                if [ "$par_action_new" != "$scanning_old" ] ; then
                    INFO "PAR repair $par_action_new"
                    scanning_old="$par_action_new"
                fi
            fi
        esac
    done
}

#If a par2 process will take too long we want to kill it.
#We could use killall but this may kill other par processes.
#Not sure how to find the 'process group' with limited environment.
#One way to identify the correct one may be to look in /proc/*/
#Works on Linux only
#$1 = binary
#$2 = home folder
#$3 = some text on command line
get_pid_by_exe() {
    INFO "getpid [$1]"
    for i in 1 2 3 4 5 ; do
        for pid in /proc/[0-9]* ; do
            if [ "$pid/cwd" -ef "$2" ] ; then
                case "`readlink "$pid/exe"`" in
                    *$1 )
                        if fgrep -q "$3" "$pid/cmdline" ; then
                            DEBUG "PID dir for $1 = $pid"
                            echo "$pid" | sed 's;/proc/;;'
                            return 0
                        fi
                        ;;
                esac
            fi
        done
        sleep 1
    done
    ERROR "Couldn't find pid for $1 in $2"
}

#####################################################################
# SECTION: UNRAR
#####################################################################
unrar_tmp_dir="unrar.tmp.dir"

first_volumes() {
    # Exclude rars matching
    # .*[._]part[0-9]*[02-9].rar or 
    # .*[._]part[0-9]*[1-9][0-9]*1.rar
    #  (ie end in 1.rar but not 0*1.rar ) 
    # .*.[0-9]*[02-9]
    # .*.[0-9]*[1-9][0-9]*1
    if [ "$mode" = nzbget ] ; then
        #Get all possible rar files at any depth
        find . -name \*.rar -o -name \*1 2>/dev/null |\
        sed 's;\./;;' |\
        first_rarname_filter
    else
        #only get top level rars that are in the completed list
        #or nested rars that are in unrar sub folders.
        cat $torrent_completed_list | first_rarname_filter
        if [ -f "$unrar_tmp_dir" ] ; then
            find "$unrar_tmp_dir" -name \*.rar -o -name \*1 2>/dev/null |\
            sed 's;\./;;' |\
            first_rarname_filter
        fi
    fi
}
        
unrar_all() {
    loop=1
    INFO "Unrar all files"
    if [ "$mode" = nzbget ] ; then
        if [ "$unpak_pause_nzbget_during_unrar" -eq 1 ] ; then
            pause_nzbget
        fi
    fi

    failed=0

    if [ "$mode" = nzbget ] ; then
        # If there are broken files then fail right away and get pars.
        if [ -e _brokenlog.txt -a "$gPass" -eq 1 ] ; then
            ERROR "Detected brokenlog. Getting pars"
            return 1
        fi
    fi


    while [ $failed -eq 0 -a $loop -le $unpak_nested_unrar_depth ] ; do
        DETAIL "UNRAR-PASS $loop"
        if first_volumes > "$gTmpFile.unrar" ; then
            while IFS= read rarfile ; do
                if ! unrar_one "$rarfile" ; then
                    if [ "$mode" = nzbget -a  "$gPass" -eq 1 ] ; then
                        #no point in trying any more until we get all pars.
                        DEBUG "Abort unrar_all"
                        failed=1
                        break
                    fi
                fi
            done < "$gTmpFile.unrar"
        fi
        rm -f -- "$gTmpFile.unrar"

        loop=$(($loop+1))
    done
    DEBUG "Done STEPS"
    # Unpause NZBGet
    if [ "$mode" = nzbget ] ; then
        if [ "$unpak_pause_nzbget_during_unrar" -eq 1 ] ; then
            unpause_nzbget
        fi
    fi

    if check_top_level_unrar_state 1 ; then
        tidy_rar_files
        return 0
    else
        ERROR "unrar_all FAILED"
        return 1
    fi
}

#If some top level rars are untouched then there are also missing start volumes
#$1 =1 log errors
check_top_level_unrar_state() {
    if [ -f "$rar_state_list" ] ; then
        if egrep '^[^/]+(FAILED|UNKNOWN)' "$rar_state_list" > "$gTmpFile.state"  ;  then
            if [ "$1" = 1 ] ; then
                log_stream ERROR "finalstate"  < "$gTmpFile.state"
            fi
            rm -f -- "$gTmpFile.state"
            return 1
        else
            rm -f -- "$gTmpFile.state"
        fi
    fi
    return 0
}

# $1 = rarfile 
rar_sanity_check() {
    related_rar_files "$1" > "$gTmpFile.related"
    cat "$gTmpFile.related" | log_stream INFO "related"
    if [ "$mode" = nzbget ] ; then 
        rar_sanity_check_nzb "$1" "$gTmpFile.related"
    else
        rar_sanity_check_torrent "$1" "$gTmpFile.related"
    fi
    rar_sanity_check_out=$?
    rm -f -- "$gTmpFile.related"
    return $rar_sanity_check_out
}

# $1 = rarfile $2=related rar list
rar_sanity_check_torrent() {
    rarfile="$1"
    INFO "Checking : $rarfile"
    wrong_size_count=0

    while IFS=read part ; do
        if ! fgrep "^$part\$" "$torrent_completed_list" ; then
            INFO Part "$part incomplete or missing."
            return 1;
        fi
    done < "$2"
    return 0;
}

#This will do a quick sanity test for missing rar parts.
#It checks number of expect parts and file size and the rar volume headers.
#The main advantage of doing this check is when no par files are present. This will
#check for missing volume files, and also if a rar is corrupted prior to being uploaded,
#then it may catch some simple header errors.
#Note if nzbget is in direct write mode then the file space is pre-allocated and the
# file sizes will be correct regardless of content.

# This is also used to check torrents. Normally not necessary because bittorrent is self 
# checking however I very much like the ability to watch torrent with multiple files,
# as it is downloading. In this case each time the 'watcher' sees a new parts as a torrent is 
#downloading. it calls the unpak script, which will unpak a little bit more each time.
#this is called every minute if a new file has completed, and all the files 'related' to it
#are completed too. ? Not 100% sure this is in the right place for torrents. Sleep on it.
# $1 = rarfile $2=related rar list
rar_sanity_check_nzb() {

    rarfile="$1"
    result=0
    size=$(ls -l "$rarfile" | awk '{print $5}')
    INFO "Checking : $rarfile"
    wrong_size_count=0

    num_actual_parts=$(cat "$2" | line_count)

    DEBUG "rar_sanity_check $rarfile"

    # prenum is regex for bit that occurs before the number
    # num is regex for numeric bit.
    # postnum is regex for bit following the number.
    case "$rarfile" in
        *1)
            #TODO We cant unpack .1 because were are not sure if it is a rar file.
            #For now we can only do .01 .001 etc. Unfortunately par repair also uses .1 suffix for backups.
            offset=0
            prenum="[._]"
            num="[0-9][0-9]+"
            num="[0-9]+"
            postnum="" 
            ;;
        *[._]part*1.rar) 
            offset=0
            prenum="[._]part"
            num="[0-9]+"
            postnum="\.rar"
            ;;
        *.rar) 
            offset=2
            prenum="[._][rstu]"
            num="[0-9][0-9]" 
            num="[0-9]+"
            postnum=""
            #Remove the .rar volume
            grep -v 'rar$' "$2" > "$2.new" 
            mv "$2.new" "$2"
            ;;
        *)
            WARNING unknown file $rarfile
            return 1
            ;;
    esac

    DEBUG "rar_sanity_check num_actual_parts = $num_actual_parts offset $offset"
    if [ $num_actual_parts -eq 1 -a $offset -eq 2 ] ; then
        last_part="$rarfile"
        num_expected_parts=1
        wrong_size_count=0
    else
        last_part=$(awk 'END { print }' "$2" )
        DEBUG " last of [$2]=[$last_part] pre $prenum num $num post $postnum"
        num_expected_parts=$(echo "$last_part" | sed -r "s/.*${prenum}0*($num)$postnum\$/\1/" )
        num_expected_parts=$(( $num_expected_parts + $offset ))
        if [ $mode = nzbget ] ; then
            if [ "$NZBOP_DIRECTWRITE" != "yes" ] ; then
                wrong_size_count=$(cat "$2" | wrong_size_count $size )
            fi
        fi

        DEBUG "PRE rar_sanity_check CHECK PARTS"
        cat "$2" | check_parts || result=$?
        DEBUG "POST rar_sanity_check CHECK PARTS $result"
        case $result in
            1) return $result ;; #Error
            2) return $result ;; #Password protected
            3) result=0;         #Possibly a split file
        esac
    fi

    DEBUG RAR CHECK END $(date)
    DEBUG RAR CHECK num_actual_parts $num_actual_parts num_expected_parts $num_expected_parts wrong_size_count $wrong_size_count

    if [ "$num_expected_parts" -gt "$num_actual_parts" ] ; then
        ERROR "Missing parts for $rarfile expected $num_expected_parts got $num_actual_parts"
        result=1
    else
        if [ "$num_expected_parts" -lt "$num_actual_parts" ] ; then
            WARNING "Too many parts for $rarfile expected $num_expected_parts got $num_actual_parts"
        fi
    fi
    if ! check_last_rar_part "$last_part"  ; then
        ERROR "End parts missing for $rarfile"
        result=1
    fi
    if [ "$wrong_size_count" -ne 0 ] ; then
        ERROR "Unexpected size for parts of $rarfile"
        result=1
    fi

    #There is a bug in df - cant do df -k . but df -k ./ works
    free_space=$(( $( free_space ./ ) / 1024 ))
    queued_size=$(( $size * $num_actual_parts / 1024 / 1024 ))
    INFO "Freespace $free_space MB"
    if [ $queued_size -ge "$free_space"  ] ; then
        ERROR "Low Disk space $free_space MB Remaining. $queued_size MB queued"
        result=1
    fi

    return $result
}

# Check free space - watch out for df split across lines.
free_space() {
    df -k "$1" | awk 'END { print (index($0," ")==1 ? $3 : $4 ); }'
}

# Do a quick header check on each part.
#result:
# 0= all OK 
# 1= Error
# 2 = Password protected
# 3 = Error but possibly a split file
check_parts() {


    first=1
    while IFS= read part ; do
        #DEBUG "Header part=[$part] first=[$first]"

        check_header "$part"
        case $? in
        0) 
            DEBUG "$part rar header is good"
            ;;
        2)
            return 2
            ;;
        1)
            #Flag the error
            DEBUG "Header part=[$part] first=[$first]"
            #If it is a 001 file and not a RAR file this is OK for now
            # as it may be a split file.
            if [ $first -eq 1 ] ; then
                if echo "$part" | egrep -q "\.0*1$" ; then
                    INFO "Header part=[$part] first=[$first]"
                    return 3
                fi
            fi
            ERROR "Archive Error for $part"
            return 1
            ;;
        *) WARNING "Unknown state from check_header $?"
            ;;
        esac
        first=0
    done
    return 0
}

# $1 = rar file
# result
# 0= OK 
# 1= Error
# 2 = Password protected
check_header() {
    DETAIL Checking header for "$1"
    one_header=0
    if  unrar lb "$1" > "$gTmpFile.rar_hdr" 2> "$gTmpFile.rar_hdr_err" ; then
        if [ ! -s "$gTmpFile.rar_hdr" ] ; then
            WARNING "$1 rar header is bad"
            one_header=1
        fi
    else
        WARNING "$1 rar header is very bad"

        one_header=1
    fi
    if grep -q 'Enter password' "$gTmpFile.rar_hdr_err" ; then
        one_reader= 2
    fi

    rm -f -- "$gTmpFile.rar_hdr" "$gTmpFile.rar_hdr_err"

    return $one_header
}

#Takes ls -l of rar parts as input and returns number of parts with unexpected size.
wrong_size_count() {
    size="$1"
    all_but_last_line | awk '$5 != '$size' {print $5}' | line_count
}

#If the last file is missing the 'num_expected_parts' will be wrong, so list the 
#contents of the last part and check it is either '100%' or '<--'
check_last_rar_part() {
    count=$(unrar vl "$1" | line_count)
    code=$(unrar vl "$1" | awk 'NR == '$count'-3 { print $3 }')
    [ "$code" != "-->" -a "$code" != "<->" ]
}

unrar_one() {
    
    rarfile="$1"
    if [ -e "$rarfile" ] ; then
        #We only change the state of rar's whose state is already set.
        #These will be top level rars only. Nested rar's do not exist when the 
        #state list is being populated.
        #This ensures that the par-repair stage is only called if  a top-level unrar fails.
        state=$(get_rar_state "$rarfile")

        DEBUG "RARFILE $rarfile STATE = $state"
        dirname=$(dirname "$rarfile")
        rarname=$(basename "$rarfile" "")

        case "$dirname" in
            .) is_toplevel_rar=1 ; is_inner_rar=0 ;;
            *) is_toplevel_rar=0 ; is_inner_rar=1 ; INFO "Inner rar" ;;
        esac

        if [ "$state" = "UNKNOWN" -o "$state" = "REPAIRED" -o "$state" = "" ] ; then
            #Perform additional checks if nzbget did not do any parchecking.
            if [ "$arg_par_check" -eq 0 -a $unpak_sanity_check_rar_files -eq 1 -a $is_toplevel_rar -eq 1 ] ; then
                if ! rar_sanity_check "$rarfile" ; then
                    # Only set top level RARs as failed. (by using change_rar_state not set_rar_state)
                    change_rar_state "$rarfile" "FAILED"
                    return 1
                fi
            fi
            INFO "Extracting : $1"
            rar_std_out="$gTmpFile.rar.out" 
            rar_std_err="$gTmpFile.rar.err" 

            #To avoid overlap issues every rar must unpack to a different local folder.
            #At the very end of ALL processing we can move all infomation up into the root folder.
            #
            # This complexity is needed if for example we have a.rar and a.sub.rar(with a.rar(2) inside).
            #
            # if a.sub.rar succeeds it produces a.rar(2) 
            # if a.rar(1) then fails we cannot copy up a.rar(2) yet. We have to keep it down until a.rar(1) is repaired.
            # This means the list of rar states may need to be updated to list rars in nested folders!
            rarState=1

            set +e
            check_header "$rarfile"
            hdr=$?
            case $hdr in
            0)
                # Unrar file
                mkdir -p "$dirname/$unrar_tmp_dir" 
                ( cd "$dirname/$unrar_tmp_dir" && unrar x -y -p- "../$rarname" 2>"$rar_std_err" |\
                    TEE "$rar_std_out" |\
                    log_stream INFO "unrar" 
                ) &
                    #sed 's/.*//' 
                sleep 1
                ls -l "$rar_std_out" | log_stream INFO ls
                unrar_monitor "$rar_std_err" "$dirname/$unrar_tmp_dir" "$rarname"
                ls -l "$rar_std_out" | log_stream INFO ls

                if grep -q '^All OK' "$rar_std_out" ; then
                    ls -l "$dirname/$unrar_tmp_dir" | log_stream DEBUG "rarcontents"
                    #Extract all lines with filenames from unrar log and add to delete queue
                    if [ $unpak_delete_rar_files -eq 1 -o $is_inner_rar -eq 1 ] ; then
                        related_rar_files "$rarname" >> "$delete_queue"
                    fi

                    rarState=0
                else
                    cat "$rar_std_err" | log_stream ERROR unrar
                fi
                ;;
            1)
                if echo "$rarfile" | grep -q '\.0*[01]$' ; then
                    #If check_header fails with xxx.001 or xxx.000 then use the cat command.
                    # This only works if rar segments are in order
                    WARNING "$rarfile does not appear to be a rar archive. Joining using cat"
                    mkdir -p "$dirname/$unrar_tmp_dir";
                    target="$dirname/$unrar_tmp_dir/`basename "$rarfile" '\.0*1'`"
                    if [ -f "$target" ] ; then
                        ERROR "Target already exists. <$target>"
                    else
                        #Note we only set rarState and the end using joinState. This ensures if the script is
                        #interrupted for any reason, rarState has the correct 'failed' value.
                        joinState=0
                        related_rar_files "$rarfile" > "$gTmpFile.volumes"

                        while IFS= read part ; do
                            INFO "Joining <$part> -> <$target>"
                            if ! cat "$part" >> "$target" ; then
                                joinState=1
                                ERROR "Joining <$part> -> <$target>"
                            fi
                        done < "$gTmpFile.volumes"

                        if [ $joinState -eq 0 ] ; then
                            cat "$gTmpFile.volumes" >> "$delete_queue"
                            rarState=0
                        fi
                        rm -f -- "$gTmpFile.volumes"
                    fi
                fi
                ;;
            2)
                ERROR "Password protected file : $rarfile"
                ;;
            *)
                ERROR "Unkown state $hdr from check_header $rarfile"
                ;;
            esac

            if [ $rarState -eq 0 ] ; then
                INFO "Extract OK : $rarfile"
                set_rar_state "$rarfile" "OK"
            else
                ERROR "Unrar FAILED : $rarfile"
                # Only set top level RARs as failed. (by using change_rar_state not set_rar_state)
                change_rar_state "$rarfile" "FAILED"
                log_stream ERROR "unrar-err" < "$rar_std_err" 
                rarState=1
            fi
            rm -f -- "$rar_std_out" "$rar_std_err"
            return $rarState
        fi
    fi
}

# Abort unrar as soon as errors appear on stderr
unrar_monitor() {
    errfile="$1"
    dir="$2"
    cmdtxt="$3"
    touch "$errfile"
    unrarpid=$(get_pid_by_exe unrar "$dir" "$cmdtxt" )
    if [ ! -n "$unrarpid" ] ; then
        return 0
    fi
    poll_time=10
    while true ; do
        sleep $poll_time
        #DEBUG "check /proc/$unrarpid"
        if [ ! -d "/proc/$unrarpid" ] ; then
            INFO "Unrar process $unrarpid finished"
            break
        fi

        if [ -s "$errfile" ] ; then
            ERROR "Found unrar errors - stopping unrar job"
            log_stream ERROR "unrar-err" < "$errfile"
            kill  $unrarpid
            break
        fi
    done
    DEBUG "end monitor"
}



###############################################################################
# SECTION: UTILS
###############################################################################

#wc -l
line_count() {
    awk 'END { print NR }'
}

all_but_last_line() {
    #sed reads lines into hold space, x swaps next line with previous and emiits previous (except first)
    sed 'x;1 d'
}

nzbget_cmd() {
    case "$mode" in
        nzbget*) "$unpak_nzbget_bin" -c "$unpak_nzbget_conf" "$@" ;;
    esac
}

pause_nzbget() { nzbget_cmd -P; }

unpause_nzbget() { nzbget_cmd -U; }

#For now we can only do .01 .001 etc. Unfortunately par repair also uses .1 suffix for backups.
rar_re='[._](part[0-9]+\.rar|rar|[rstu][0-9][0-9]|[0-9][0-9][0-9]*)$'

#Same as rarname but remove quotes.
flagid() {
    rarname "$1" | sed -r "s/["'"'"']//g;"
}
#Note. Only top level rars that exist on the first pass have their state stored.
#So we dont need to bother with nested paths.
rarname() {
    if [ -f "$1" ] ; then
        echo "$1" | sed -r "s/$rar_re//"
    else
        #if the file does not exist do not strip the extension.
        #it probably means the extension has already been stripped.
        echo "$1"
    fi
}

related_rar_files() {
    r=$(rarname "$1")
    r2=$( echo "$r" | re_escape )
    #ls -d "$r"* | egrep "^$r2$rar_re"
    ls -d "$r"* | awk "/^$r2$rar_re/ && length(\$0) == length(\"$1\") { print }"
}
first_rarname_filter() {
    egrep -v '([._]part[0-9]*([02-9]|[1-9][0-9]*1).rar|rar.[0-9]+)$' | egrep '[._](part0*1\.rar|rar|0*1)$'
}

#Add '\' to regular expression metacharacters in a string.
#resulting string can be passed to grep,awk or sed -r (not plain sed)
#Required so we can search for the string whilst using regualr expressions.
# eg grep "^$string$". this will fail if string contains '[].* etc.
#
# Dont escape quotes - \' is a GNU extension 
re_escape() {
    #sed 's/\([].[*/\(|)]\)/\\\1/g'
    sed -r 's/([^'"'"'a-zA-Z0-9_])/\\\1/g'
}

quote_file() {
    sed "s/'/'\\''/g;s/^/'/;s/$/'/"
}


# MV a file and create any necessary path
# $1=source $2=dest
COPY() {
    MVCP cp "$@"
}
MV() {
    MVCP mv "$@"
}
MVCP() {
    #Create the destination path.
    if [ ! -e "$3" ] ; then 
        mkdir -p "$3"
        if [ -d "$3" ] ; then  rmdir "$3" ; fi
    fi
    $1 "$2" "$3"
}

#Special Tee command for nzbget logging. The main command pipes
#its stdout and stderr to tee_logfiles which then sends it to
#1. stdout (to be captured by nzbget)
#2. unpak.txt (local log file)
tee_logfiles() {

    #Check time functions are supported. Reported by niours.
    T='strftime("%T",systime())'
    if ! echo | awk 'BEGIN { x='"$T"'; }' 2>/dev/null ; then
        T='""'
    fi
    unpak_debug_mode=1
    awk '
function timestamp() {
return '"$T"';
}
BEGIN {
  debug='$unpak_debug_mode'
  txt=ARGV[1];
  ARGC=1; #Force stdin

}
/^$/ { next ; }
/^Exit_Code/ { exit($2); }

{
if (substr($1,1,1) != "[" ) {
    if($0 == "Request sent") {
        $0="[DETAIL] "$0
    } else if ( match($0,"^server returned:.*success") ) {
        $0="[DETAIL] "$0
    } else {
        #Line did not appear via log funtions. This is either
        #some unprocessed stdout or stderr. Best give a warning.
        $0="[WARNING] "$0
    }
}
v=substr($0,2,3);
if ( debug==1 || v!="DEB" ) {
    sub(/\]/,"] unpak:" timestamp());
    print ; 
    print >> txt;
    c="blue";
    system(""); # Flush all buffers
}
}
END { close(txt); }
      ' "$@"
}

#Join files with the format *.nnnn.ext or *.ext.nnnn
joinfiles() {

    ext="$1"
    extname=$(echo "$ext" | sed -r 's/\.[0-9]+//g') #remove digits from extension
    glob=$(echo "$ext" | sed 's/[0-9]/[0-9]/g')            # glob pattern

    for part in *$ext ; do
        DEBUG "join part $part"
        if [ -f "$part" ] ; then
            bname=$(echo "$part" | sed 's/\.[^.]*\.[^.]*$//') #remove last two extensions
            newname="$bname$extname"
            INFO "Joining $newname"
            if [ -f "$newname" ] ; then
                WARNING "$newname already exists"
            else
                if cat "$bname"$glob > "$newname" ; then
                    rm -f "$bname"$glob
                    #true
                else
                    mv  "$newname" "damaged_$newname"
                fi
            fi
        fi
    done
}

tidy_rar_files() {
    if check_top_level_unrar_state 0 ; then
        delete_paused_pars
        move_rar_contents .
        delete_samples
        clear_all_rar_states 0


    else
        #Easier to keep NZB Local
        if [ -n "$arg_nzb_file" ] ; then
            if [ -f "$arg_nzb_file" ] ; then cp "$arg_nzb_file" . ; fi
            if [ -f "$arg_nzb_file.queued" ] ; then cp "$arg_nzb_file.queued" . ; fi
        fi
    fi
}
tidy_nonrar_files() {
    DEBUG "tidy_nonrar_files"
    joinfiles ".0001.ts"

    if ! par_set ; then
        delete_extended_glob_pattern "$unpak_delete_files"
    fi

    if [ "$unpak_rename_img_to_iso" -eq 1 ] ; then
        ls *.img 2>/dev/null | exec_file_list "mv \1 \2\3.iso" ""
    fi
}

#Rename nzb.queued to nzb$finished_nzb_ext then delete any old *$finished_nzb_ext files.
tidy_nzb_files() {
    if [ -z "$arg_nzb_file" ] ; then return 0 ; fi

    finished_nzb_full_path=`prepare_target_folder "$NZBOP_NZBDIR" "$finished_nzb_folder"`

    if [ -f "$arg_nzb_file" ] ; then 
        mv "$arg_nzb_file" "$arg_nzb_file$finished_nzb_ext"
        mv "$arg_nzb_file$finished_nzb_ext" "$finished_nzb_full_path"
    fi
    if [ -f "$arg_nzb_file.queued" ] ; then 
        mv "$arg_nzb_file.queued" "$arg_nzb_file$finished_nzb_ext"
        mv "$arg_nzb_file$finished_nzb_ext" "$finished_nzb_full_path"
    fi
    if [ $unpak_max_nzbfile_age -gt 0 ] ; then
        #-exec switch doesnt seem to work
        d=$(dirname "$arg_nzb_file")
        INFO Deleting NZBs older than $unpak_max_nzbfile_age days from $d
        find "$d" -name \*$finished_nzb_ext -mtime +$unpak_max_nzbfile_age > "$gTmpFile.nzb"
        log_stream DETAIL "old nzb" < "$gTmpFile.nzb"
        sed "s/'/'\\\\''/g;s/^/rm '/;s/$/'/" "$gTmpFile.nzb" | sh
        rm -f "$gTmpFile.nzb"
    fi
}

clear_tmpfiles() {
    rm -f "$OVS_TMP/unpak.$$."*
}

#Store the state of each rar file.
# This is simply in a flat file with format
# id*STATE
# where id is the id based on the basename of the rar file  and
# state is its current state.
#
# If a rar file has no state it was likely extracted from inside another rar file.
# as all of the initial states are set prior to extraction. This means that at least
# one volume of a rar file must be present for it to be correctly registered.
#
# STATE   | Next Action | Next States   | Comment
# none    | UNRAR       |   none        | this could be a rar created from another rar file
# UNKNOWN | UNRAR       | OK,FAILED     | this is a top-level rar identified from any one of its parts
# OK      | All Done    |     -         | Sucess.Keep the state to avoid re-visiting when nested unpacking.
# FAILED  | par fix.    |REPAIRED,FAILED| State will stay failed. 
# REPAIRED| UNRAR       | OK,FAILED     |
# 
rar_state_list="unpak.state.db"
rar_state_sep="*" #Some char unlikely to appear in filenames. but not quotes. E.g. * : / \
delete_queue="unpak.delete.sh"

get_rar_state() {
    r=$(flagid "$1")
    [ ! -f "$rar_state_list" ] || awk "-F$rar_state_sep" '$1 == "'"$r"'" {print $2}' "$rar_state_list"
}
#Change if it already exists
change_rar_state() {
    INFO "change_rar_state $1 = $2"
    r=$(flagid "$1")
    s="$2"
    touch "$rar_state_list"
    awk "-F$rar_state_sep" '{ if ( $1=="'"$r"'" ) { print $1"'"$rar_state_sep$s"'" } else { print }}' "$rar_state_list" > "$rar_state_list.1" &&\
    mv "$rar_state_list.1" "$rar_state_list"
}
set_rar_state() {
    INFO "set_rar_state $1 = $2"
    r=$(flagid "$1")
    s="$2"
    DEBUG "flagid [$1]=[$r]"
    touch "$rar_state_list"
    awk "-F$rar_state_sep" '{ if ( $1 != "'"$r"'" ) { print }} END { print "'"$r$rar_state_sep$s"'" } ' "$rar_state_list" > "$rar_state_list.1" &&\
    mv "$rar_state_list.1" "$rar_state_list"
    DEBUG "SET RARSTATE [$r]=[$s]"
}

list_rar_states() {
    state_pattern="$1"
    touch "$rar_state_list"
    awk "-F$rar_state_sep" '{ if ( $2 ~ "'"$state_pattern"'" ) { print $1 }}' "$rar_state_list"
}

#The script is rar-driven (we may not have downloaded any pars yet and unrar before looking at pars)
#However, the initial rar file may be missing. So we need to look at all rar files present to 
#know the state of rar files.
#The only situation we cant manage is where there are no rar parts at all. Unlikely.


init_all_rar_states() {
    clear_all_rar_states 1
    lastPart=

    # Initialise the rar state file. This consist of each rar archive name
    # in the top level directory followed by '*UNKNOWN' (ie state is unknown)
    # There is one entry per multi-volume archive.
    # There are only entries if volumes are present at the start of processing.
    ls | awk '
    BEGIN {last_flag=""}
    {
    if (sub(/'"$rar_re"'/,"")) {
        gsub(/["'"'"']/,"") #REMOVE quotes from filename to get flagid
        flag=$0
        if (flag != last_flag) {
            print flag "'$rar_state_sep'UNKNOWN"
            last_flag = flag
        }
    }}' > "$rar_state_list"
    
    log_stream DEBUG "init" < "$rar_state_list"
}

#We have previously unpacked each rar in its own folder to avoid clashes.
#This function should be called right at the end to push everything up
#to the main folder.

#TODO ensure that we can download two dvd's eg 2*VIDEO_TS

move_rar_contents() {

    #INFO "Move rar contents into $1 = $(pwd)"
    if [ -d "$unrar_tmp_dir" ]; then 
        DEBUG "Moving rar contents up from [$PWD/$unrar_tmp_dir]"

        if [ "$unpak_touch_files" -eq 1 ] ; then
            touch "$unrar_tmp_dir"/* || true
            touch "$unrar_tmp_dir"/*/* || true
            touch "$unrar_tmp_dir"/*/*/* || true
        fi

        ( cd "$unrar_tmp_dir"; move_rar_contents "../$1" )
        #Copy directory up. 
        #
        # could use mv $unrar_tmp_dir/* . but two problems.
        #
        # Hidden files and 
        # mv with globbing will return an error if no files match.
        #But we dont really mind that, we only want an error if there was
        #a problem actually moving a real file.
        # 
        ls -A "$unrar_tmp_dir" | exec_file_list "mv '$unrar_tmp_dir/'\1 ." -e
        rmdir "$unrar_tmp_dir"
    fi
}


#Delete rar files. These should be deleted at the end of all processing,
#as they may be needed for a par repair of a different rar file
#Some par sets span multiple rars.
delete_files() {

    if [ $mode = torrent_seeding ] ; then return ; fi

    if [ -f "$delete_queue" ] ; then
        exec_file_list "rm -f \1" "--" < "$delete_queue"
        #mv "$delete_queue" "$delete_queue.bak"
        rm -f "$delete_queue"
    fi
}

#more than 50% pars
par_set() {
    par_count=`ls *[Pp][Aa][Rr]2 2>/dev/null | line_count`
    all_count=`ls | line_count`
    [ $(( $par_count * 2 )) -gt $all_count ]
}

media_count() {
 list_extended_glob_pattern "*($unpak_video_extension)" | line_count
}

#Delete sample files if there are other media files present.
delete_samples() {
    DEBUG "unpak_delete_samples=[$unpak_delete_samples]"
    if [ -n "$unpak_delete_samples" ] ; then
        all_media=$( media_count )
        sample_media=$( list_extended_glob_pattern "($unpak_delete_samples)($unpak_video_extension)" | line_count )
        DEBUG all_media $all_media sample_media $sample_media
        if [ "$sample_media" -gt 0 -a "$all_media" -gt "$sample_media" ] ; then
            delete_extended_glob_pattern "($unpak_delete_samples)($unpak_video_extension)"
        fi
    fi
}

list_extended_glob_pattern () {
    if [ -n "$1"  ] ; then
        #Pattern is glob format plus <> for word boundaries. Convert to regexp
        #convert . to \. then * to .* then < > to \< \>
       p="${1//./\.}"
       p="${p//\?/.}"
       p="${p//\*/.*}"
       p="${p//</\<}"
       p="${p//>/\>}"
       DEBUG "search for files matching $p"
       ls -A 2>/dev/null | egrep -i "^($p)$" | log_stream DEBUG
       ls -A 2>/dev/null | egrep -i "^($p)$"
    fi
}

delete_extended_glob_pattern() {
    list_extended_glob_pattern "$1" >> "$delete_queue"
}

clear_all_rar_states() {
    force="$1"
    if [ "$force" -eq 1 -o $unpak_debug_mode -eq 0 ] ; then
        rm -f "$rar_state_list"
    fi
}

log_args() {
    cmd="'$0'"
    for i in "$@" ; do
        cmd="$cmd '$i' "
    done
    INFO "ARGS: $cmd"
}

#Move command that merges non-empty directories.
#$1=source
#$2=dest
#stdout = list of moved files. 
merge_folders() {
    if [ ! "$1" -ef "$2" ] ; then
        DEBUG "MERGE CONTENTS [$1]->[$2]"
        if [ ! -e "$2" ] ; then
            mkdir -p "$2"
        fi
        ls -A "$1" | while IFS= read f ; do
            if [ -d "$1/$f" ] ;then
                if [ -e "$2/$f" ] ; then
                    merge_folders "$1/$f" "$2/$f"
                else
                    DEBUG "MVD [$1/$f] [$2/.]"
                    mv "$1/$f" "$2/."
                fi
            else
                DEBUG "MVF [$1/$f] [$2/.]"
                rm -f "$2/$f"
                mv "$1/$f" "$2/."
                echo "$2/$f" #output
            fi
        done
        rmdir "$1"
        DEBUG "END MERGE CONTENTS [$1]->[$2]"
    fi
}

# Pass a list of files to some command
# stdin = list of files.
# $1 = command to execute where '\1' is the file path \2=folder \3=name(without ext) \4=ext
# (Shell meta-characters are backslash escaped before applying the command. So additional
# quotes should not be used.
#
# eg echo filename.exe | exec_file_list 'rm \1' 
# if filename contains single or double quotes, *, ? , []  these will be escaped.
# 
# $2 = any shell options or "--" if none
# Leaving $2 unquoted allows ""
exec_file_list() {
    sep=":"
    sep2=";"
    dir="(|.*\/)"
    nameExt="([^/]+)(\.[^./]*)"
    nameNoExt="([^./]+)()" #Note must anchor with '$' when used otherwise will match extensions.
    case "$1" in *$sep*) sep="$sep2" ;; esac

    # Save list and replace shell expansion meta chars.
    sed -r "s/([][&\(\|\);' *?"'"'"])/\\\&/g" > "$gTmpFile.exec"

    #Now apply the substitution in $1
    sed -rn "s$sep^($dir$nameExt)\$$sep$1${sep}p" "$gTmpFile.exec" > "$gTmpFile.sh"
    sed -rn "s$sep^($dir$nameNoExt)\$$sep$1${sep}p" "$gTmpFile.exec" >> "$gTmpFile.sh"

    if [ $unpak_debug_mode -eq 1 ] ; then
        DEBUG "BEGIN FILE LIST for $1 : $2"
        log_stream DEBUG "sh-file" < "$gTmpFile.exec"
        log_stream DEBUG "sh-cmd" < "$gTmpFile.sh"
        #( echo "$1" ; cat "$gTmpFile.exec" ; cat "$gTmpFile.sh" ) >> "$gTmpFile.shall"
    fi
    rm -f -- "$gTmpFile.exec"

    sh $2 "$gTmpFile.sh"

    rm -f -- "$gTmpFile.sh"
}

no_rars() {
    [ ! -s "$rar_state_list" ]

#    if ls *.rar > /dev/null 2>&1 ; then
#
#        INFO "rar files present"
#        return 1
#    else
#        INFO "No rar files"
#        return 0
#    fi
}

set_pass() { gPass=$1 ; INFO "PASS $1" ; }

############################################################################
# PIN FOLDER HACK 
# If a category begins with 'PIN:FOLDER' then replace that with the path
# to the pin folder. This is simply a folder burried in a heirachy of
# similarly named folders. The path to the folder is defined by
# $unpak_nmt_pin_root and the $unpak_nmt_pin
############################################################################

nmt_make_pin_folder() {
    INFO "CREATING PIN FOLDER"
    folders="1 2 3 4 5 6 7 8 9"
    start="$PWD"

    #Make the target folder.
    mkdir -p "$nmt_pin_path"

    #We create some dummy folders. Recursive Symlinks would have been perfect here
    # as the would create unlimited depth unfortunately
    #they dont show up in the NMT browser. 
    #so we only create a subset of possible combinations. (to conserve disk space)
    cd "$nmt_pin_path"
    last_digit=1
    while [ ! "$PWD" -ef "$unpak_nmt_pin_root" -a "$PWD" != "/" ] ; do
        cd ..
        if [ $(ls | line_count) -le 1 ] ; then
            mkdir -p $folders
            if [ $last_digit -eq 0 ]; then
                # Create some more dummy folders in 'cousin' folders of correct letters.
                for i in $folders ; do
                    (cd $i ; mkdir -p $folders ; cd .. ) 
                done
            fi
        fi
        last_digit=0
    done
    chmod -R a+rw "$unpak_nmt_pin_root"
    cd "$start"
    INFO "DONE CREATING PIN FOLDER"
}

#Output = Pin Folder susbstituted
nmt_get_pin_folder() {

    #Convert 2468 to /pin/path/2/4/6/8/
    nmt_pin_path="$unpak_nmt_pin_root/"$(echo $unpak_nmt_pin | sed 's/\(.\)/\/\1/g')   

    if [ ! -d "$nmt_pin_path" ] ; then
        ( nmt_make_pin_folder "$nmt_pin_path" )
    fi

    echo $nmt_pin_path
}

# Ensure a folder exists by following all relative paths and doing mkdir
prepare_target_folder() {
    if [ "$mode" = nzbget ] ; then
        prepare_target_folder2 "$NZBOP_DESTDIR" "$unpak_completed_dir" "$@"
    else
        prepare_target_folder2 "$unpak_completed_dir" "$@"
    fi
}
prepare_target_folder2() {
    (for i in "$@" ; do mkdir -p "$i" ; cd "$i" ; done ; pwd )
}

auto_category_from_newsgroups_inside_nzb() {

    if [ "$unpak_auto_categorisation_from_newsgroups" -ne 1 ] ; then return 0 ; fi
    if [ -z "$arg_nzb_file" ] ; then return 0 ; fi
    #Get values of all subfolder_by_newsgroup_ variables.
    set | sed -n '/^unpak_subfolder_by_newsgroup_[0-9]/ s/^[^=]*=//p' | sed "s/^' *//g;s/ *: */=/;s/ *'$//g" |\

        while IFS== read keyword destination ; do

            DEBUG "Check category $keyword=$destination"

            if egrep -ql "<group>.*$keyword.*</group>" "$arg_nzb_file" "$arg_nzb_file".* 2>/dev/null ; then

                INFO "Getting category from newsgroup matching [$keyword]"

                case "$destination" in 
                    PIN:FOLDER) destination=`nmt_get_pin_folder` ;;
                esac

                # Resolve relative dirs, create destination folder and send to stdout
                prepare_target_folder "$destination"

                break
            fi

        done
}

relocate() {

    local b=`basename "$arg_download_dir" ""`
    local move_it=0


    if [ -n "$arg_category" ] ; then
        if [ -n "$unpak_catalog_category_include" ] && echo "$arg_category" | egrep -iq "($unpak_catalog_category_include)" ; then
            if [ -n "$unpak_catalog_category_exclude" ] && echo "$arg_category" | egrep -iq "($unpak_catalog_category_exclude)" ; then
                INFO "category $arg_category excluding from indexing"
            else
                INFO "Indexing category $arg_category"
                move_it=1
            fi
        else
            INFO "Not indexing category $arg_category"
        fi
        if [ $move_it = 0 ] ; then
            unpak_completed_dir=`prepare_target_folder "$arg_category"`
            INFO Using user category $arg_category == $unpak_completed_dir
            mvlog "$arg_download_dir" "$unpak_completed_dir"
            cd "$unpak_completed_dir/$b"
        fi
    else
        dest=`auto_category_from_newsgroups_inside_nzb`
        if [ -n "$dest" ] ; then 
            case "$dest" in
                $unpak_nmt_pin_root*)
                    #The colon forces short dos names from windows share.
                    if [  "$unpak_nmt_pin_folder_scramble_windows_share" = 1 ] ; then
                        b="$b:"
                    fi
                    ;;
            esac
            dest="`prepare_target_folder "$dest"`/$b"
            mvlog "$arg_download_dir" "$dest"
            cd "$dest"
        else
            move_it=1
        fi
    fi
    if [ $move_it = 1 ] ; then
        #Everything else 
        dest=`prepare_target_folder`/"$b"
        mvlog "$arg_download_dir" "$dest"
        cd "$dest"
        #run_catalog "$unpak_completed_dir/$b" RENAME STDOUT
        run_catalog "$dest" RENAME WRITE_NFO
    fi
}

mvlog() {
    INFO "moving [$1] to [$2]"
    mv "$1" "$2"
}

create_resume_file() {
    file="$1"
    shift
    if [ -n "$1" ] ; then
        arg_list "$@" > "$file"
    fi
    if [ "$is_nmt" = "Y" ] ; then
        echo "chown -R "$uid:$gid" ." >> "$file"
    fi
    chmod ugo+x "$file"
    cat "$file" | log_stream INFO
}

PERMS() {
    if [ "$is_nmt" = "Y" ] ; then
        chown -R "$uid:$gid" "$@"
    fi
}

# $@ = args to catalog.sh
run_catalog() {
    folder="$1"
    shift
    if [ -f "$OVS_HOME/bin/catalog.sh" ] ; then
        #User has a correct unpak.cfg file.
        if [ "$is_nmt" = "Y" ] ; then
	        JOBID="$log_name" "$OVS_HOME/bin/catalog.sh" "$folder" "$@" || true
	    else
	        #JOBID="$log_name" "$OVS_HOME/bin/catalog.sh" "$folder" NO_DB WRITE_NFO "$@" || true
	        JOBID="$log_name" "$OVS_HOME/bin/catalog.sh" "$folder" "$@" || true
	    fi
        #create_resume_file "$folder/unpak.resume" "$OVS_HOME/bin/catalog.sh" "$folder" "$@"
    else
        INFO "Catalog script not present in $OVS_HOME"
    fi
}

multi_pass_with_par_repair() {

    if ! waiting_for_pars ; then

        set_pass 1
        #First pass. Try to unrar. 
        INFO "$script_name : PASS 1"
        init_all_rar_states

        if no_rars || ! unrar_all ; then
            # unpause pars. unpause_pars_and_reprocess will return error and set waiting_for_pars if
            # nothing to unpause.
            if ! unpause_pars_and_reprocess ; then
                # No pars to unpause so start Pass2 immediately (par repair followed by unrar)
                set_pass 2
                par_repair_all && unrar_all || true
            fi
        fi

    else
        set_pass 2
        INFO "$script_name : PASS 2"
        #Second pass. Now pars have been fetched try to repair and unrar
        clear_waiting_for_pars
        par_repair_all && unrar_all || true
    fi
}
single_pass() {
    # One pass  - no rars (no pars or nzbget has repaired already)
    #For torrents - single pass is really one real pass which logs all files to
    #be deleted. Then a second pass simply deletes the files.
    set_pass 0
    unrar_all || true
}

#
##################################################################################
# main SCRIPT
##################################################################################

POSTPROCESS_ERROR=1

# This mess is because bash doesnt pass exit codes between piped processes.
# but all of main is piped to a log handler - which would otherwise always return 
# success. So the log handler listens for a line 'Exit_Code #' Probably a nicer way.
exit_with() {
    clear_tmpfiles
    INFO "Exit_Code $1"
    echo Exit_Code $1;
    exit $1;
}

abort() {
    exit_with $POSTPROCESS_ERROR
}

main() {

    exit_code=1
    INFO 'unpak version $Id$ '
    INFO "OVS_HOME [$OVS_HOME]"
    INFO "$os_version $nmt_version"

    env | grep -iv password | log_stream DEBUG env

    log_args "$@"

    NZB_NICE_NAME=$(basename "$arg_download_dir" "")

    if [ "$mode" = nzbget ] ; then
        check_settings || exit 1
        set_nzbget_exit_codes
    else
        set_p2p_exit_codes
    fi

    #Only run at the end of nzbjob
    if [ "$arg_nzb_state" -ne 1 ] ; then
        exit_with $POSTPROCESS_SUCCESS
    fi

    INFO " ====== Post-process Started : $NZB_NICE_NAME $(date '+%T')======"

    exit_code="$POSTPROCESS_ERROR"

    if [ "$arg_par_fail" -ne 0 ] ; then
        ERROR "Previous par-check failed, exiting"
        abort
    fi

    case "$arg_par_check" in
        0)
            if [ "$mode" = nzbget ] ; then
                if [ -f _brokenlog.txt -a "$external_par_check" -ne 1 ] ; then
                    ERROR "par-check is disabled or no pars present, but a rar is broken, exiting"
                    abort
                fi
            fi
            ;;
       1) ERROR "par-check failed, exiting" 
          abort ;;
       2) true ;; # Checked and repaired.
       3) WARNING "Par can be repaired but repair is disabled, exiting"
          abort ;;
    esac

    #---------------------------------------------------------

    case "$mode" in
        nzbget)
            if [ $unpak_pause_nzbget -eq 1 ] ; then
                pause_nzbget
            fi
            if [ "$arg_par_check" -eq 0 -a "$external_par_check" -eq 1 ] ; then
                multi_pass_with_par_repair
            else
                init_all_rar_states
                single_pass
            fi
            if [ $unpak_pause_nzbget -eq 1 ] ; then
                unpause_nzbget
            fi
            ;;
        torrent_seeding)
            # Torrents may make multiple passes - each time calling the same 
            # single_pass. This simply unpacks files until failure.
            # This will hopfully allow incremental unpacking of seasons etc.
            # Each time a season hits 100% downloaded. this is called.
            if [ !-f "$rar_state_list" ] ; then
                init_all_rar_states
            fi
            single_pass
            ;;
        torrent_finished)
            INFO Torrent finised. removing rar files.
            ;;
    esac

    if ! waiting_for_pars ; then
        if check_top_level_unrar_state 0 ; then
            tidy_nonrar_files
            create_resume_file unpak.resume ""
            chmod -R a+rw . || true
            case $mode in
            nzbget)
                delete_files
                if [ -n "$unpak_completed_dir" -a "$NZBOP_APPENDNZBDIR" = "yes" ] ; then
                    relocate #runs catalog.sh
                fi
                tidy_nzb_files
                ;;
            torrent_seeding)
                #Just add to the catalog. No renaming - no moving
                run_catalog "$arg_download_dir"
                ;;
            torrent_finished)
                delete_files
                #If run twice unpack should do nothing but move and catalog. No unraring.
                #Oversight will flag as new again. May add a switch to prevent that
                run_catalog "$arg_download_dir" RENAME
                ;;
            esac
        fi
    fi

    # ----- END GAME -----

    s=
    if waiting_for_pars ; then
        s="Waiting for PARS"
        exit_code="$POSTPROCESS_SUCCESS"
    else
        if check_top_level_unrar_state 1 ; then 
            INFO "$s"
            exit_code="$POSTPROCESS_SUCCESS"
        else
            ERROR "$s"
            exit_code="$POSTPROCESS_ERROR"
        fi
    fi
    s=" ====== Post-process Finished : $1 : $NZB_NICE_NAME : $s $(date '+%T') ======";
    exit_with $exit_code
}

script_name=$(basename "$0" "")

##################################################################################
# something sometimes changes /tmp permissions so only root can write
is_nmt=N

if [  "$FAMILY" = nmt ] ; then
    is_nmt=Y
fi

#Some global settings
finished_nzb_folder="processed"
finished_nzb_ext=".processed"
gTmpFile="$OVS_TMP/unpak.$$"
flatten="=@="
###################### Parameters #####################################

# Parameters passed to script by nzbget:
#  1 - path to destination dir, where downloaded files are located;
#  2 - name of nzb-file processed;
#  3 - name of par-file processed (if par-checked) or empty string (if not);
#  4 - result of par-check:
#      0 - not checked: par-check disabled or nzb-file does not contain any
#          par-files;
#      1 - checked and failed to repair;
#      2 - checked and sucessfully repaired;
#      3 - checked and can be repaired but repair is disabled;
#  5 - state of nzb-job:
#      0 - there are more collections in this nzb-file queued;
#      1 - this was the last collection in nzb-file;
#  6 - indication of failed par-jobs for current nzb-file:
#      0 - no failed par-jobs;
#      1 - current par-job or any of the previous par-jobs for the
#          same nzb-files failed;
# Check if all is downloaded and repaired

arg_nzb_file="" 
arg_par_check="2" 
arg_nzb_state="1"  
arg_par_fail="0" 
arg_category=""
log_name=$$
mode=${1:-}
case $mode in 
    torrent_seeding)
        mode="$1" # torrent_seeding (catalog in place)
        arg_download_dir="$2"
        torrent_file="$3"
        #List of completed files is passed to the rar sanity checker.
        #Only those files are unpacked.
        #TODO Modify sanity check to only check file is in this list for torrents.
        #This allows for torrents to be extracted incrementally - useful for large
        #series downloads.
        torrent_completed_list="${3:-}"
        ;;
    torrent_finished)
        mode="$1" # torrent_finished (delete files/move/catalog)
        arg_download_dir="$2"
        ;;
    nzbget_cmd)
        # This is a hook for the oversight installer to find the nzbget command.
        # it is not used by the stand-alone unpak scripts.
        shift
        nzbget_cmd_request "$@"
        exit
        ;;
    *)
        if [ "$#" -lt 6 ]
        then
            cat <<HERE
NZBGet post-process script

usage:

  $0 dir nzbname parname parcheck-result nzb-job-state failed-jobs

or to manually run a failed job. cd to the folder and then:

  $0 torrent_seeding folder"
  $0 torrent_finished folder"

current args: $@
HERE

            get_nzbpath
            abort
        else
            mode=nzbget
            arg_download_dir="$1"   
            arg_nzb_file="$2" 
            arg_par_check="$4" 
            arg_nzb_state="$5"  
            arg_par_fail="$6" 
            arg_category="${7:-}"
            log_name="`basename "$arg_download_dir" | sed -r 's/[^A-Za-z0-9]+/./g'`.$$"
        fi
esac

log_dir="$OVS_HOME/logs"

mkdir -p $log_dir

log_file="$log_dir/unpak.$log_name.log"

clean_logs() {
    find "$1" -name unpak.\*.log -mtime +5 | while IFS= read f ; do
        rm -f -- "$f"
    done
}

clean_logs "$log_dir"



cd "$arg_download_dir"
create_resume_file unpak.resume "$OVS_HOME/bin/unpak.sh" "$@"

INFO "OVS_TMP=[$OVS_TMP]"

load_unpak_settings "$unpak_default_settings"

load_unpak_settings "$unpak_load_settings"

if [ $mode = nzbget ] ; then
    get_nzbpath
fi

if [ $mode = torrent_seeding ] ; then
    #only delete rar files if coming from nzbget with 6 parameters.
    #this may need to be revised!
    unpak_delete_rar_files=0
fi

cd "$arg_download_dir" 

#mkdir -p "$arg_download_dir.2"
#ln * "$arg_download_dir.2/."


main "$@" 2>&1 | tee_logfiles "$log_file"
exit_code=$?

archive "$log_file"

exit $exit_code
#
# vi:shiftwidth=4:tabstop=4:expandtab
#
