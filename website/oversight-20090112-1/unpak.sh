#!/bin/sh --
# MSDOS HEADER: keep comments and blanks
true                             #

if [ $? != 0 ]; then             #
    sed 's/$//' "$0" > /tmp/$$ #
    cat /tmp/$$ > "$0"           #
    exec /bin/sh "$0" "$@"       #
    exit                         #
fi                               #
# REAL SCRIPT FOLLOWS
#TODO scanning log error

#--------------------------------------------------------------------------
#!/bin/sh 
# $Id$
set -u  #Abort with unset variables
set -e  #Abort with any error can be suppressed locally using EITHER cmd||true OR set -e;cmd;set +e
#
# unpak.sh - 
#   nzbget post processing script for Popcornhour. Based on the one release
# with the August 2008 firmware.
#
# The script just uses syntax/commands found on the Popcorn Hour (busybox/ash)
# So not all commands are present (eg wc,tail) and some do not support GNU switches.
# TODO Can delete rars after sucessful unrar if no pars or par repair done
# (otherwise might be needed for par repair)
# TODO Problem displaying '%' in nzbget.log test INFO and echo
# TODO Fix double title match.. eg nzb=blah s01e03 .. blah ..s01e03.nzb usually "blah"  has message part nos eg " - nnnn -" "- [nn/nn] -"
# TODO Check symlinks created if no tv match
# TODO Test Par check with multiple mp3.

VERSION=20090111-1
#   Fixed temp file location
#VERSION=20081207-BETA07
#   Test _brokenlog.txt and get pars right away if present.
#   Kill unrar process as soon as errors are detected.
#   Made RE_ESCAPE more portable (tx doctorvangogh/nzbget )
#   Works if par binary not available (reported GibberishDriftword/readynas)
#   changed Recent to use html page.
#   Setting to delete sample files after extracting
#   
#VERSION=20081009-BETA06
#   Fixed to allow _partnnn.rar (underscore)(found by geeks @ nmt forums)
#   Fixed to remove leading zero from 00.n% correctly when unraring (found by geeks @ nmt forums)
#   Fixed unpack *.001 archives whether RAR or split. (retest)
#   Removed FAKEFILES functionality
#   Renamed par2s .1 extension to .damaged. (similar to split/rar format)
#   Do not attempt to process Password protected rars
#VERSION=20081009-BETA05
#   Small bugfix detected rar parts.
#VERSION=20081009-BETA04
#   Small bugfix for extracting name from nfo
#VERSION=20081009-BETA03
#   Allow _partnnn (underscore)
#VERSION=20081009-BETA02
#   Also Get TV Name from NFO file if available.
#   Small bug fixes.
#VERSION=20081002-BETA01
#   Added PIN:FOLDER 'hack' until Parental lock arrives.
#   Auto Category looks at NZB name in preference to media names
#   Added Recently Downloaded folders (using managed hard links)
#   Added IMDB Movie categorisation.
#   Diskspace check
#   Checked unrar status 'All OK' in stdout.
#   many bugfixes.
#VERSION=20080911-01
#   Option to pause for entire duration of script.
#   Fixed MOVE_RAR_CONTENTS to use -e test rather than -f
#   Fixed Par repair bug (failing to match par files to rar file)
# VERSION=20080909-02
#   Fixed MOVE_RAR_CONTENTS to use mv checkingfor hidden files and avoiding glob failure.
# VERSION=20080909-01
#   Do a par repair if there are no rar files at all (using *.par2 not *PAR2) eg for mp3 folders.
#   Fixed subtitle rar overwriting main rar if they have the same name.
#   Autocategory for Music and simple TV series names. 
#   Join avi files if not joined by nzbget.
# VERSION=20080905-03
#   Minor Bug Fix - removed symlink to par2
#VERSION=20080905-02
#   Typo Bug Fix
#VERSION=20080905-01
#   Specify Alternative Completed location
#   Log Estimate of time to Repair Pars and only do repairs that will be less than n minutes (configurable)
#   Better logic to work with twin rar,par sets (eg cd1,cd2) where one rar works but the other needs pars.
#   Better logic to work with missing start volumes.
#   Stopped using hidden files as they prevent deleting via Remote Control
#   Rar Parts are deleted right at the end of processing rather than during. This may help with pars that span multiple rar sets.
#VERSION=20080902-01
#   Better checks to ensure settings are consistent between nzbget.conf and unpak.sh.
#   Copied logic used by nzbget to convert an NZB file name to the group/folder name.
# v 20080901-02
#   Bug fix - getting ids when there are square brackets or certain meta-characters in nzb name.
# v 20080901-01
#   Bug fixes. Settings verification.
# v 20080831-04
#  External Par Repair option
# v 20080831-03
#   Minor fixes.
# v 20080831-01
#   Sanity check if nzbget did not do any par processing.
#   NZBGet , unrar paths set as options.
#   Unpacking depth configurable.
#   MediaCentre feature: HTML Logging for viewing in file browser mode.
#   MediaCentre feature: Error Status via fake AVI file
#   More bug fixes. (Rar Sanity Check)
# v 20080828-03
#   Added better test for ParCheck/_unbroken courtesy Hugbug.
# v 20080828-02
#   Fixed nested unrar bug.
#   Added purging of old NZBs
# v 20080828-01
#   Does a quick sanity check on the rar file before unpacking. 
#   added IFS= to stop read command trimming white space.
# v 20080827-02 
#   Fixed multiple attempts to unpack failed archives
# v 20080827-01 
# - Delete files only if unrar is sucessful.
# - Cope with multiple ts files in the same folder.
# - Deleting is on by default - as it is more careful
# --------------------------------------------------------------------
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

# Notes
# Careful using ls * if there are directories (ls -d *)

#########################################################################
# Settings section - see unpak.cfg.example
#########################################################################
# Settings are read from the file specified. If the file does not exist
# it will be created from the unpak.cfg.example file.
# If unpak_load_settings starts with '/' it's location is absolute,
# otherwise it is relative to the location of this script.
unpak_load_settings=unpak.cfg

########################################################################
# SECTION: LOGGING FUNCTIONS
########################################################################

# Add logging text to stdout of some other command.
# echo hello | LOGSTREAM INFO test  > [INFO] test:hello
# echo "" | LOGSTREAM INFO test  > {nothing}
LOGSTREAM() {
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

#Get nzbget's settings. Not these are read direct from the config file
#and not the ones that nzbget may be using internally??
LOAD_NZBGET_SETTINGS() {
    #eg ParCheck will become nzbget_ParCheck
    #Get all lines with / = / remove spaces around '=' , prefix with nzbget_ , replace x.y=z with x_y=z
    NZBGET -p | grep ' = ' | sed 's/^/nzbget_/;s/ = /=/;s/\.\([^=]*\)=/_\1=/' | grep -v 'nzbget_server' > "$gTmpFile.nzb_cfg"
    . "$gTmpFile.nzb_cfg"
    rm "$gTmpFile.nzb_cfg"
    set | grep '^nzbget_' | LOGSTREAM DEBUG "conf"
}

SET_DEFAULT_SETTINGS() {

    # :r! grep '^unpak_' /mnt/popcorn/.nzbget/unpak.cfg  | grep -v subfolder
    unpak_settings_version=1
    unpak_nzbget_bin="/mnt/syb8634/bin/nzbget"
    unpak_nzbget_conf="/share/.nzbget/nzbget.conf"
    unpak_unrar_bin="/mnt/syb8634/bin/unrar"
    unpak_par2_bin="/mnt/syb8634/bin/par2"
    unpak_completed_dir="../Complete" #Default location for completed downloads

    #unpak_movie_folder_format="/share/Movies/{:TITLE:}{-:CERT:}"
    #unpak_tv_file_format="/share/Tv/{:TITLE:}{ - Season :SEASON:}/{:NAME:}"
    unpak_movie_folder_format=
    unpak_tv_file_format=
    unpak_music_folder=
    unpak_debug_mode=0
    unpak_sanity_check_rar_files=1
    unpak_rename_img_to_iso=1
    unpak_check_for_new_versions=1
    unpak_delete_rar_files=1
    unpak_max_nzbfile_age=30
    unpak_nested_unrar_depth=3
    unpak_disable_external_par_repair=0
    unpak_external_par_repair_tidy_queue=1
    unpak_pause_nzbget=0
    unpak_pause_nzbget_during_unrar=0
    unpak_maximum_par_repair_minutes=300

    unpak_filter_erotica=1
    unpak_nmt_pin="2468" 
    unpak_nmt_pin_root="/share/~Other"
    unpak_nmt_pin_folder_scramble_windows_share=1

    unpak_delete_samples=1
}

unpak_settings_version=1
# Cant call logging yet.
MERGE_UNPAK_SETTINGS() {

    case "$unpak_load_settings" in
        /*) true;;
        *) unpak_load_settings="$SCRIPT_FOLDER/$unpak_load_settings" ;;
    esac

    INFO "MERGE_UNPAK_SETTINGS [$unpak_load_settings]"

    if [ -n "$unpak_load_settings" ] ; then
        #If there is no sample cfg - create one
        if [ ! -f "$unpak_load_settings" ] ; then
            cp "$SCRIPT_FOLDER/unpak.cfg.example" "$unpak_load_settings"
            echo "Create $unpak_load_settings file from example"
        fi

        if [ -f "$unpak_load_settings" ] ; then
            if egrep -q "^ *unpak_settings_version=('|)$unpak_settings_version($|[^0-9])" "$unpak_load_settings" ; then
                echo "Loading settings from $unpak_load_settings"
                . "$unpak_load_settings"
            else
                echo "Settings in $unpak_load_settings ignored. Not compatible"
            fi
        else
            echo "Using Default Settings"
        fi
    fi
}

CHECK_SETTINGS() {
    settings=0
    LOAD_NZBGET_SETTINGS
    if [ "$nzbget_ParCheck" = "yes" ] ; then
        INFO "config: Mandatory parchecking already enabled in nzbget.conf"
        external_par_check=0
    else
        if [ "$unpak_disable_external_par_repair" -eq 1 ] ; then
            INFO "config: ALL parchecking/reparing is completely disabled."
            external_par_check=0
        else
            if [ "$arg_par_check" -eq 0 ]; then 
                INFO "config: Parchecking enabled in $SCRIPT_NAME"
                external_par_check=1
            else
                ERROR "config: nzbget has Parchecked although this is disabled in nzbget.conf. May need to restart nzbget"
                external_par_check=0
            fi
        fi
    fi
    if [ "$external_par_check" -eq 1 ] ; then
#        if [ "$unpak_delete_rar_files" -eq 0 ] ; then
#           ERROR "config:unpak_delete_rar_files should be set if using external par repair feature"
#           settings=1
#       fi
        if [ "$nzbget_LoadPars" != "all" ] ; then
            if [ "$nzbget_AllowReProcess" != "yes" ] ; then
                WARNING "config: IF LoadPars is not all then AllowReProcess should be yes in nzbget.conf"
               settings=1
            fi
        else
            if [ "$nzbget_AllowReProcess" = "yes" ] ; then
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
SET_WAITING_FOR_PARS() { touch "$par_flag" ; }
CLEAR_WAITING_FOR_PARS() { rm -f -- "$par_flag" ; }
WAITING_FOR_PARS() { [ -e "$par_flag" ] ; }

GET_PAUSED_IDS() {
    # Look in the nzbget list for the given group.

    # search list using fgrep to avoid metacharacter issues '][.'
    # However this may lead to substring matches (no anchoring), so surround the group name with
    #asterisks first as these cannot appear inside an group name.

    #Was using NZB_NICE_NAME but arg_download_dir may be better.
    ids="$NZB_NICE_NAME"
    ids=`BASENAME "$arg_download_dir" ""`
    ids=$(NZBGET -L | sed 's/ / */;s,/,*/,' | fgrep "*$ids*/" | sed -n '/[Pp][Aa][Rr]2 (.*paused)$/ s/^\[\([0-9]*\)\].*/\1/p')
    echo $ids | sed 's/ /,/g'
}
#Unpauses par files. Returns error if nothing to unpause.
UNPAUSE_PARS_AND_REPROCESS() {
    if [ "$nzbget_AllowReProcess" != "yes" ] ; then
        ERROR "AllowReProcess disabled. Cannot repair"
        return 1
    fi
    INFO "Downloading pars in $arg_nzb_file"
    ids=$(GET_PAUSED_IDS)
    if [ -n "$ids" ] ; then
        NZBGET -E U $ids
        NZBGET -E T $ids
        SET_WAITING_FOR_PARS
    else
        return 1
    fi
}
DELETE_PAUSED_PARS() {
    if [ "$unpak_external_par_repair_tidy_queue" -eq 1 ] ; then
        INFO "Deleting paused parts of $arg_nzb_file"
        ids=$(GET_PAUSED_IDS)
        if [ -n "$ids" ] ; then
            NZBGET -E D $ids
        fi
    fi
}

#Spent over an hour before realising permisions not set properly on par2!
#Make an executable copy so users dont need to telnet in
NMT_FIX_PAR2_PERMISSIONS() {
    if [ ! -x "$unpak_par2_bin" ] ; then
        PAR2Alternative=/share/.nzbget/par2
        if [ -x "$PAR2Alternative" ] ; then
            unpak_par2_bin="$PAR2Alternative"
        else
            cp "$unpak_par2_bin" "$PAR2Alternative"
            chmod o+x "$PAR2Alternative"
            if [ ! -x "$PAR2Alternative" ] ; then
                ERROR "Make sure $unpak_par2_bin has execute permissions"
            else
                unpak_par2_bin="$PAR2Alternative"
            fi
        fi
    fi
}

#In case there are two or more par sets just look for .par2 files. (not PAR2 files)
#TODO. We may need to know which Pars fix which rars in future so we can be more
#selective with unraring when errors occur. But for now take an all or nothing approach.
PAR_REPAIR_ALL() {
    INFO "Start Par Repair"
    if [ ! -f "$unpak_par2_bin" ] ; then
        WARNING "PAR2Binary [$unpak_par2_bin] not present. Skipping repair"
        return 1
    fi
    NMT_FIX_PAR2_PERMISSIONS

    ORDERED_PAR_LIST > "$gTmpFile.par_size" 
    #First identify parsets for all FAILED or UNKNOWN rars.
    if NO_RARS ; then
        # Process a folder that does not contain any rar files.
        # ------------------------------------------------------
        # Maybe mp3s etc. Just look at *.par2.
        # TODO. Identify par sets correctly rather than just looking at *par2
        while IFS= read p ; do
            PAR_REPAIR "$p" || true
        done < "$gTmpFile.par_size"
    else
        #Fix all broken rars only. These will only be top level rars.
        # -----------------------------------------------------------
        LIST_RAR_STATES "(FAILED|UNKNOWN)" > "$gTmpFile.failed_or_unknown"
        while IFS= read rarPart ; do
            #Find the first par file that looks like it may fix the rar file.
            #TODO This may fail occasionally with accidental substring matches. But its quick and easy
            INFO "Finding PARS for $rarPart"
            while IFS= read p ; do
                if [ -f "$p" ] && fgrep -l "$rarPart." "$p" > /dev/null ; then
                    if PAR_REPAIR "$p" ; then
                        SET_RAR_STATE "$rarPart" REPAIRED
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
ORDERED_PAR_LIST() {
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

PAR_REPAIR() {
    parFile="$1"

    INFO "Par Repair using $parFile"

    if [ "$pause_nzbget_during_par2repair" -eq 1 ] ; then
        PAUSE_NZBGET
    fi

    set +e
    out="$gTmpFile.p2_out"
    err="$gTmpFile.p2_err"
    "$unpak_par2_bin" repair "$parFile" > "$out" 2>"$err" &
    PAR_MONITOR "$out"
    set -e

    par_state=1
    if grep -q "Repair complete" "$out" ; then
        if [ ! -s "$err" ] ; then
            par_state=0
        fi
    fi


    if [ "$pause_nzbget_during_par2repair" -eq 1 ] ; then
        UNPAUSE_NZBGET
    fi

    if [ $par_state -eq 0 ] ; then

        INFO "Repair OK : $parFile"
        #We delete par files right away once par is repaired
        # as it speeds up matching a rar to remaining pars.
        DELETE_PAR_FILES "$out"

    else

        ERROR "Repair FAILED : $parFile"
        awk '!/\r/' "$out" | LOGSTREAM ERROR "par2out"
        LOGSTREAM ERROR "par2err" < "$err"

    fi

    #Avoid confusion due to .1 extension
    PAR_RENAME_DAMAGED_FILES "$out"
    rm -f -- "$err" "$out"
    return $par_state
}

# Input $1 = par stdout file (with emedded \r's)
PAR_CLEAN_OUTPUT() {
    awk '{ 
            gsub(/\r$/,"") ;        #remove last CR 
            gsub(/.*\r/,"") ;       #Strip all text
            print;
        }' "$1" 
}

#Delete Par files based on Par Output eg.
# <Loading "my.par.file.vol001+02.PAR2".>
DELETE_PAR_FILES() {
    DETAIL "Deleting Par Files"
    PAR_CLEAN_OUTPUT "$1" |\
    sed -rn 's/^Loading "(.*)"\.$/\1/p' |\
    EXEC_FILE_LIST "rm -f \1" ""
}

#Par uses .n extension for damaged files. Eg file.avi.1 
#this causes problems because .1 is also a possible Rar or Split extension.
#So find any damaged files and rename file.1 to file.1.damaged
# Input $1 = par stdout file (with emedded \r's)
PAR_RENAME_DAMAGED_FILES() {
    # [Scanning: "filename": nn.n%] -> [Scanning: "filename"]
    PAR_CLEAN_OUTPUT "$1" |\
    awk '/Verifying repaired files/,/Repair complete/ {print}'  |\
    sed -rn 's/Target: "(.*)" - found\.$/\1.1/p' |\
    EXEC_FILE_LIST '[ ! -e \1 ] || mv \1 \1.damaged' ""
}

# Return name of current file beg
PAR_OUTPUT_GET_CURRENT_ACTION() {
    # [Scanning: "filename": nn.n%] -> [Scanning: "filename"]
    sed -n '/^[A-Z][a-z]*:/ s/": [^"]*$/"/p'
}
PAR_OUTPUT_GET_CURRENT_PERCENTAGE() {
    # [Repairing: "filename": nn.n%] -> [nnn] (ie 000 to 1000 )
    sed -nr '/^Repairing:/ { s/^.*": 0*([0-9]*)(|\.)[0-9]*\%.*/\1\2/p}'
}

#Get the last line from Par output. Each line may have many <CR>. 
#we need the text between the last two <CR>s on the last line.
PAR_OUTPUT_GET_LAST_LINE() {
    outfile=$1
    awk 'END { 
            gsub(/\r$/,"") ;        #remove last CR 
            gsub(/.*\r/,"") ;       #Strip all text
            print;
        }' "$outfile"
}

PAR_MONITOR() {
    outfile=$1
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
    DEBUG "PAR_MONITOR"
    touch "$outfile"
    p2pid=$(GETPID "$unpak_par2_bin" "$PWD")
    if [ ! -n "$p2pid" ] ; then
        return 1
    fi

    while true ; do
        sleep $poll_time
        if [ ! -f "$outfile" ] ; then break ; fi
        if [ ! -d "/proc/$p2pid" ] ; then break ; fi # Par process gone?
        





        line=$(PAR_OUTPUT_GET_LAST_LINE "$outfile")
        case "$line" in
            Repairing:*)
            #Get percentage nn.m% and convert to nnm
            percent_new=$(echo "$line" | PAR_OUTPUT_GET_CURRENT_PERCENTAGE)
            if [ -n "$percent_new" ] ; then
                gap=$(( $gap + $poll_time ))
                DEBUG "$percent_old - $percent_new after $gap secs"
                if [ -n "$percent_old" -a "$percent_old" -ne $percent_new ] ; then

                    if [ $loggedParStats -eq 0 ]; then
                        loggedParStats=1
                        awk '!/\r/' "$outfile" | LOGSTREAM DEBUG "par2out"
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
            par_action_new=$(echo "$line" | PAR_OUTPUT_GET_CURRENT_ACTION)
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
GETPID() {
    bin="$1"
    d="$2"

    for i in 1 2 3 4 5 ; do
        for pid in /proc/[0-9]* ; do
            if [ "$pid/cwd" -ef "$d" -a "$pid/exe" -ef "$bin" ] ; then
                DEBUG "PID dir for $bin = $pid"
                echo "$pid" | sed 's;/proc/;;'
                return 0
            fi
        done
        sleep 1
    done
    ERROR "Couldn't find pid for $bin in $d"
}

#####################################################################
# SECTION: UNRAR
#####################################################################
unrar_tmp_dir="unrar.tmp.dir"

FIRST_VOLUMES() {
    # Exclude rars matching
    # .*[._]part[0-9]*[02-9].rar or 
    # .*[._]part[0-9]*[1-9][0-9]*1.rar
    #  (ie end in 1.rar but not 0*1.rar ) 
    # .*.[0-9]*[02-9]
    # .*.[0-9]*[1-9][0-9]*1
    find . -name \*.rar -o -name \*1 2>/dev/null |\
    sed 's;\./;;' |\
    FIRST_RARNAME_FILTER
}
        
UNRAR_ALL() {
    loop=1
    INFO "Unrar all files"
    if [ "$unpak_pause_nzbget_during_unrar" -eq 1 ] ; then
        PAUSE_NZBGET
    fi
    failed=0

    # If there are broken files then fail right away and get pars.
    if [ -e _brokenlog.txt -a "$gPass" -eq 1 ] ; then
        ERROR "Detected brokenlog. Getting pars"
        return 1
    fi


    while [ $failed -eq 0 -a $loop -le $unpak_nested_unrar_depth ] ; do
        DETAIL "UNRAR-PASS $loop"
        if FIRST_VOLUMES > "$gTmpFile.unrar" ; then
            while IFS= read rarfile ; do
                if ! UNRAR_ONE "$rarfile" ; then
                    if [ "$gPass" -eq 1 ] ; then
                        #no point in trying any more until we get all pars.
                        DEBUG "Abort UNRAR_ALL"
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
    if [ "$unpak_pause_nzbget_during_unrar" -eq 1 ] ; then
        UNPAUSE_NZBGET
    fi

    if CHECK_TOP_LEVEL_UNRAR_STATE 1 ; then
        TIDY_RAR_FILES
        TIDY_NONRAR_FILES
        return 0
    else
        ERROR "UNRAR_ALL FAILED"
        return 1
    fi
}

#If some top level rars are untouched then there are also missing start volumes
#$1 =1 log errors
CHECK_TOP_LEVEL_UNRAR_STATE() {
    if [ -f "$rar_state_list" ] ; then
        if egrep '^[^/]+(FAILED|UNKNOWN)' "$rar_state_list" > "$gTmpFile.state"  ;  then
            if [ "$1" == 1 ] ; then
                LOGSTREAM ERROR "finalstate"  < "$gTmpFile.state"
            fi
            rm -f -- "$gTmpFile.state"
            return 1
        else
            rm -f -- "$gTmpFile.state"
        fi
    fi
    return 0
}

#This will do a quick sanity test for missing rar parts.
#It checks number of expect parts and file size and the rar volume headers.
#The main advantage of doing this check is when no par files are present. This will
#check for missing volume files, and also if a rar is corrupted prior to being uploaded,
#then it may catch some simple header errors.
#Note if nzbget is in direct write mode then the file space is pre-allocated and the
# file sizes will be correct regardless of content.
RAR_SANITY_CHECK() {

    rarfile="$1"
    result=0
    size=$(ls -l "$rarfile" | awk '{print $5}')
    INFO "Checking : $rarfile"
    DEBUG RAR CHECK BEGIN
    wrong_size_count=0

    RELATED_RAR_FILES "$rarfile" > "$gTmpFile.ls"

    num_actual_parts=$(cat "$gTmpFile.ls" | LINE_COUNT)

    DEBUG "RAR_SANITY_CHECK $rarfile"

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
            prenum="[._]r"
            num="[0-9][0-9]" 
            num="[0-9]+"
            postnum=""
            #Remove the .rar volume
            grep -v 'rar$' "$gTmpFile.ls" > "$gTmpFile.ls2" 
            mv "$gTmpFile.ls2" "$gTmpFile.ls"
            ;;
        *)
            WARNING unknown file $rarfile
            return 1
            ;;
    esac

    DEBUG "RAR_SANITY_CHECK num_actual_parts = $num_actual_parts offset $offset"
    if [ $num_actual_parts -eq 1 -a $offset -eq 2 ] ; then
        last_part="$rarfile"
        num_expected_parts=1
        wrong_size_count=0
    else
        last_part=$(cat "$gTmpFile.ls" | LAST_LINE)
        DEBUG " last $last_part pre $prenum num $num post $postnum"
        num_expected_parts=$(echo "$last_part" | sed -r "s/.*${prenum}0*($num)$postnum\$/\1/" )
        num_expected_parts=$(( $num_expected_parts + $offset ))
        if [ "$nzbget_DirectWrite" != "yes" ] ; then
            wrong_size_count=$(cat "$gTmpFile.ls" | WRONG_SIZE_COUNT $size )
        fi

        DEBUG "PRE RAR_SANITY_CHECK CHECK PARTS"

        cat "$gTmpFile.ls" | CHECK_PARTS || result=$?
        DEBUG "POST RAR_SANITY_CHECK CHECK PARTS $result"
        case $result in
            1) return $result ;; #Error
            2) return $result ;; #Password protected
            3) result=0;         #Possibly a split file
        esac
    fi

    rm -f -- "$gTmpFile.ls"

    DEBUG RAR CHECK END $(date)
    DEBUG RAR CHECK num_actual_parts $num_actual_parts num_expected_parts $num_expected_parts wrong_size_count $wrong_size_count

    if [ "$num_expected_parts" -lt "$num_actual_parts" ] ; then
        ERROR "Missing parts for $rarfile expected $num_expected_parts got $num_actual_parts"
        result=1
    else
        if [ "$num_expected_parts" -gt "$num_actual_parts" ] ; then
            WARNING "Too many parts for $rarfile expected $num_expected_parts got $num_actual_parts"
        fi
    fi
    if ! CHECK_LAST_RAR_PART "$last_part"  ; then
        ERROR "End parts missing for $rarfile"
        result=1
    fi
    if [ "$wrong_size_count" -ne 0 ] ; then
        ERROR "Unexpected size for parts of $rarfile"
        result=1
    fi

    if [ $(( $size * $num_actual_parts / 1024 )) -ge `FREE_KB "."` ] ; then
        ERROR "Low Disk space `FREE_KB` Remaining"
        result=1
    fi

    return $result
}

# Do a quick header check on each part.
#result:
# 0= all OK 
# 1= Error
# 2 = Password protected
# 3 = Error but possibly a split file
CHECK_PARTS() {

    first=1
    while IFS= read part ; do
        DEBUG "Header part=[$part] first=[$first]"

        CHECK_HEADER "$part"
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
        *) WARNING "Unknown state from CHECK_HEADER $?"
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
CHECK_HEADER() {
    DETAIL Checking header for "$1"
    one_header=0
    if  "$unpak_unrar_bin" lb "$1" > "$gTmpFile.rar_hdr" 2> "$gTmpFile.rar_hdr_err" ; then
        if [ ! -s "$gTmpFile.rar_hdr" ] ; then
            DEBUG "$1 rar header is bad"
            one_header=1
        fi
    else
        DEBUG "$1 rar header is very bad"

        one_header=1
    fi
    if grep -q 'Enter password' "$gTmpFile.rar_hdr_err" ; then
        one_reader= 2
    fi

    rm -f -- "$gTmpFile.rar_hdr" "$gTmpFile.rar_hdr_err"

    return $one_header
}

#Incomplete - need nice way of testing first 4 bytes are 'Rar!' but they could be
#any binary value which may break script. Also no 'diff' on PCH.
IS_RAR() {
    dd bs=4 count=1 if="$1" of="$gTmpFile.rar_hdr"
}


#Takes ls -l of rar parts as input and returns number of parts with unexpected size.
WRONG_SIZE_COUNT() {
    size=$1
    ALL_BUT_LAST_LINE | awk '$5 != '$size' {print $5}' | LINE_COUNT
}

#If the last file is missing the 'num_expected_parts' will be wrong, so list the 
#contents of the last part and check it is either '100%' or '<--'
CHECK_LAST_RAR_PART() {
    count=$("$unpak_unrar_bin" vl "$1" | LINE_COUNT)
    code=$("$unpak_unrar_bin" vl "$1" | awk 'NR == '$count'-3 { print $3 }')
    [ "$code" != "-->" -a "$code" != "<->" ]
}

UNRAR_ONE() {
    
    rarfile="$1"
    if [ -e "$rarfile" ] ; then
        #We only change the state of rar's whose state is already set.
        #These will be top level rars only. Nested rar's do not exist when the 
        #state list is being populated.
        #This ensures that the par-repair stage is only called if  a top-level unrar fails.
        state=$(GET_RAR_STATE "$rarfile")

        DEBUG "RARFILE $rarfile STATE = $state"
        if [ "$state" = "UNKNOWN" -o "$state" = "REPAIRED" -o "$state" = "" ] ; then
            #Perform additional checks if nzbget did not do any parchecking.
            if [ "$arg_par_check" -eq 0 ] ; then
                if [ $unpak_sanity_check_rar_files -eq 1 ] ; then
                    if ! RAR_SANITY_CHECK "$rarfile" ; then
                        # Only set top level RARs as failed. (by using CHANGE_RAR_STATE not SET_RAR_STATE)
                        CHANGE_RAR_STATE "$rarfile" "FAILED"
                        return 1
                    fi
                fi
            fi
            INFO "Extracting : $1"
            d=$(DIRNAME "$rarfile")
            r=$(BASENAME "$rarfile" "")
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
            CHECK_HEADER "$rarfile"
            hdr=$?
            case $hdr in
            0)
                # Unrar file
                mkdir -p "$d/$unrar_tmp_dir" 
                ( cd "$d/$unrar_tmp_dir" && "$unpak_unrar_bin" x -y -p- "../$r" 2>"$rar_std_err" |\
                    TEE "$rar_std_out" |\
                    LOGSTREAM INFO "unrar" 
                ) &
                sleep 1
                ls -l "$rar_std_out" | LOGSTREAM INFO ls
                UNRAR_MONITOR "$rar_std_err" "$d/$unrar_tmp_dir"
                ls -l "$rar_std_out" | LOGSTREAM INFO ls

                if grep -q '^All OK' "$rar_std_out" ; then
                    ls -l "$d/$unrar_tmp_dir" | LOGSTREAM DEBUG "rarcontents"
                    #Extract all lines with filenames from unrar log and add to delete queue
                    sed -n "s#^Extracting from ../\(.*\)#$d/\1#p" "$rar_std_out" >> "$delete_queue"

                    rarState=0
                fi
                ;;
            1)
                if echo "$rarfile" | grep -q '\.0*1$' ; then
                    #If CHECK_HEADER fails use the cat command. Not this only works if rar segments are in order
                    WARNING "$rarfile does not appear to be a rar archive. Joining using cat"
                    mkdir -p "$d/$unrar_tmp_dir";
                    target=$(RARNAME "$d/$unrar_tmp_dir/$r")
                    if [ -f "$target" ] ; then
                        ERROR "Target alread exists. <$target>"
                    else
                        #Note we only set rarState and the end using joinState. This ensures if the script is
                        #interrupted for any reason, rarState has the correct 'failed' value.
                        joinState=0
                        RELATED_RAR_FILES "$rarfile" > "$gTmpFile.volumes"

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
                ERROR "Unkown state $hdr from CHECK_HEADER $rarfile"
                ;;
            esac


            set -e
            if [ $rarState -eq 0 ] ; then
                INFO "Extract OK : $rarfile"
                SET_RAR_STATE "$rarfile" "OK"
            else
                ERROR "Unrar FAILED : $rarfile"
                # Only set top level RARs as failed. (by using CHANGE_RAR_STATE not SET_RAR_STATE)
                CHANGE_RAR_STATE "$rarfile" "FAILED"
                LOGSTREAM ERROR "unrar-err" < "$rar_std_err" 
                rarState=1
            fi
            rm -f -- "$rar_std_out" "$rar_std_err"
            return $rarState
        fi
    fi
}

# Abort unrar as soon as errors appear on stderr
UNRAR_MONITOR() {
    errfile="$1"
    dir="$2"
    touch "$errfile"
    unrarpid=$(GETPID "$unpak_unrar_bin" "$dir")
    if [ ! -n "$unrarpid" ] ; then
        return 0
    fi
    poll_time=5
    while true ; do
        sleep $poll_time
        #DEBUG "check /proc/$unrarpid"
        if [ ! -d "/proc/$unrarpid" ] ; then
            INFO "Unrar process $unrarpid finished"
            break
        fi

        if [ -s "$errfile" ] ; then
            ERROR "Found unrar errors - stopping unrar job"
            LOGSTREAM ERROR "unrar-err" < "$errfile"
            kill  $unrarpid
            break
        fi
    done
    DEBUG "end monitor"
}



###############################################################################
# SECTION: UTILS
###############################################################################
FREE_KB() {
    free_space=$(df -k "$1" | awk 'NR==2 {print $4}')
    INFO "Freespace [$1] = $free_space"
    echo "$free_space"
}

#Get last line of stdin 'tail -1'
LAST_LINE() {
    awk 'END { print }'
}

#wc -l
LINE_COUNT() {
    awk 'END { print NR }'
}

ALL_BUT_LAST_LINE() {
    sed 'x;1 d'
}

NZBGET() {
   DEBUG "nzbget $@"
   "$unpak_nzbget_bin" -c "$unpak_nzbget_conf" "$@"
}
PAUSE_NZBGET() { NZBGET -P; }
UNPAUSE_NZBGET() { NZBGET -U; }

GET_NICE_NZBNAME() {
    #The NZBFile is converted to a nice name which is used for the group name in the nzbget list,
    # and also for the folder name (if AppendNzbDir is set)
    #From NZBSource the conversion is (strchr("\\/:*?\"><'\n\r\t", *p) then trailing dots and spaces are removed.
    #The following sed does the same - except for the whitespace
    BASENAME "$arg_nzb_file" .nzb | sed "s#['"'"*?:><\/]#_#g;s/[ .]*$//'
}

#For now we can only do .01 .001 etc. Unfortunately par repair also uses .1 suffix for backups.
rar_re='[._](part[0-9]+\.rar|rar|r[0-9]{2}|[0-9]{2,})$'

#Same as rarname but remove quotes.
FLAGID() {
    echo "$1" | sed -r "s/$rar_re//;s/["'"'"']//g;"
}
#Note. Only top level rars that exist on the first pass have their state stored.
#So we dont need to bother with nested paths.
RARNAME() {
    echo "$1" | sed -r "s/$rar_re//"
}

# An additional string can be inserted to match the basename.
# /a/b/c.rar -> /a/b/c
# /a/b/c.jpg -> nothing
RARNAME_FILTER_WITH_PREFIX() {
    s=$(echo "$1" | RE_ESCAPE)
    egrep "^($s)$rar_re"
}
RELATED_RAR_FILES() {
    r=$(RARNAME "$1")
    r2=$( echo "$r" | RE_ESCAPE )
    ls -d "$r"* | egrep "^$r2$rar_re"
}
FIRST_RARNAME_FILTER() {
    egrep -v '([._]part[0-9]*([02-9]|[1-9][0-9]*1).rar|rar.[0-9]+)$' | egrep '[._](part0*1\.rar|rar|0*1)$'
}

#Add '\' to regular expression metacharacters in a string.
#resulting string can be passed to grep,awk or sed -r (not plain sed)
#Required so we can search for the string whilst using regualr expressions.
# eg grep "^$string$". this will fail if string contains '[].* etc.
RE_ESCAPE() {
    sed 's/\([].[*/\(|)]\)/\\\1/g'
}


# $1=file $2=re for extension
BASENAME() {
    echo "$1" | sed "s:.*/::;s:$2\$::"
}
DIRNAME() {
    echo "$1" | sed 's|^\([^/.]\)|./\1|;s|\(.\)/[^/]*$|\1|'
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

CHANGE_CASE() {
    case "$1" in
        *upper) CHANGE_CASE_AWK toupper ;;
        *lower) CHANGE_CASE_AWK tolower;;
        caps) CHANGE_CASE_AWK caps;;
        *) cat;;
    esac
}

# Input - stdin $1=upper,lower,caps : output : stdout
CHANGE_CASE_AWK() {

    awk '
    function caps(str) {
        if (match(str,/^[a-zA-Z]/)) { 
            return toupper(substr(str, 1, 1))tolower(substr(str, 2))
        } else {
            return substr(str,1,1)toupper(substr(str, 2, 1))tolower(substr(str, 3))
        }
    }

    {
        gsub(/\//,"/ "); 
        for(i=1;i<=NF;i++){
            #Change words that have alphabetic chars only
            #if (match($i,/^[a-zA-Z]+$/)) {
                $i='"$1"'($i)
            #}
        }
        gsub(/\/ /,"/"); 
        print 
    }'
}
# Input $1=field sep + data from std in
# Output 'stdin on one line joined by field sep
FLATTEN() {
    awk '{printf "%s%s" (NR==1?"":"'"$1"'") $0}'
}

# Tee command - borrowed from http://www.gnu.org/manual/gawk/html_node/Tee-Program.html
# 'Arnold Robbins, arnold@gnu.org, Public Domain 'and tweaked a bit.
TEE() {
    awk '
BEGIN {
  append=(ARGV[1] == "-a")
  for(i=append+1 ; i<ARGC;i++) {
      copy[i]=ARGV[i]
      if (append == 0) printf "" > copy[i];
  }
  ARGC=1; #Force stdin

}


{ print ; 
for (i in copy) { 
    print >> copy[i];
}
system(""); # Flush all buffers
#fflush("");
}
END { for (i in copy) close(copy[i]) }
      ' "$@"
}
#Special Tee command for nzbget logging. The main command pipes
#its stdout and stderr to TEE_LOGFILES which then sends it to
#1. stdout (to be captured by nzbget)
#2. unpak.txt (local log file)
TEE_LOGFILES() {

    #Check time functions are supported. Reported by niours.
    T='strftime("%T",systime())'
    if ! echo | awk 'BEGIN { x='"$T"'; }' 2>/dev/null ; then
        T='""'
    fi
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
JOINFILES() {

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

#is $1 a sub directory of $2 ?
IS_SUBDIR() {
    sub=$(cd "$1" ; pwd)
    while [ ! "$sub" -ef "/" ] ; do
        if [ "$2" -ef "$sub" ] ; then
            DEBUG "subdir [$1] [$2] = YES"
            return 0
        fi
        sub=$(cd "$sub/.." ; pwd )
        #DEBUG "Subdir = [$sub]" ;
    done
    DEBUG "subdir [$1] [$2] = NO"
    return 1
}

TIDY_RAR_FILES() {
    if CHECK_TOP_LEVEL_UNRAR_STATE 0 ; then
        if [ "$arg_par_check" -eq 0 -a "$external_par_check" -eq 1 ] ; then
            DELETE_PAUSED_PARS
        fi
        DELETE_RAR_FILES
        if [ "$unpak_delete_samples" -eq 1 ] ; then
            DELETE_SAMPLES
        fi
        MOVE_RAR_CONTENTS .
        CLEAR_ALL_RAR_STATES 0


    else
        #Easier to keep NZB Local
        if [ -f "$arg_nzb_file" ] ; then cp "$arg_nzb_file" . ; fi
        if [ -f "$arg_nzb_file.queued" ] ; then cp "$arg_nzb_file.queued" . ; fi
    fi
}
TIDY_NONRAR_FILES() {
    DEBUG "TIDY_NONRAR_FILES"
    JOINFILES ".0001.ts"

    rm -f *.nzb *.sfv *.damaged _brokenlog.txt *.[pP][aA][rR]2 *.queued 
    if [ "$unpak_rename_img_to_iso" -eq 1 ] ; then
        ls *.img 2>/dev/null | EXEC_FILE_LIST "mv \1 \2\3.iso" ""
    fi
    TIDY_NZB_FILES
}

#Rename nzb.queued to nzb$finished_nzb_ext then delete any old *$finished_nzb_ext files.
TIDY_NZB_FILES() {
    if [ -f "$arg_nzb_file" ] ; then 
        mv "$arg_nzb_file" "$arg_nzb_file$finished_nzb_ext"
    fi
    if [ -f "$arg_nzb_file.queued" ] ; then 
        mv "$arg_nzb_file.queued" "$arg_nzb_file$finished_nzb_ext"
    fi
    if [ $unpak_max_nzbfile_age -gt 0 ] ; then
        #-exec switch doesnt seem to work
        d=$(DIRNAME "$arg_nzb_file")
        INFO Deleting NZBs older than $unpak_max_nzbfile_age days from $d
        find "$d" -name \*$finished_nzb_ext -mtime +$unpak_max_nzbfile_age > "$gTmpFile.nzb"
        LOGSTREAM DETAIL "old nzb" < "$gTmpFile.nzb"
        sed "s/^/rm '/;s/$/'/" "$gTmpFile.nzb" | sh
        rm -f "$gTmpFile.nzb"
    fi
}

#Notification of changes to unpak.sh.
VERSION_CHECK() {
    if [ "$unpak_check_for_new_versions" -eq 1 ] ; then
        latest=$(wget -O- http://www.prodynamic.co.uk/nzbget/unpak.version 2>/dev/null)
        if [ -n "$latest" -a "$latest" != "$VERSION" ] ; then
            INFO "Version $latest is available (current = $VERSION )"
        fi
    fi
}

CLEAR_TMPFILES() {
    rm -f /tmp/unpak.$$.*
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

GET_RAR_STATE() {
    r=$(FLAGID "$1")
    [ ! -f $rar_state_list ] || awk "-F$rar_state_sep" '$1 == "'"$r"'" {print $2}' $rar_state_list
}
#Change if it already exists
CHANGE_RAR_STATE() {
    r=$(FLAGID "$1")
    s="$2"
    touch "$rar_state_list"
    awk "-F$rar_state_sep" '{ if ( $1=="'"$r"'" ) { print $1"'"$rar_state_sep$s"'" } else { print }}' $rar_state_list > $rar_state_list.1 &&\
    mv $rar_state_list.1 $rar_state_list
}
SET_RAR_STATE() {
    r=$(FLAGID "$1")
    s="$2"
    DEBUG "FLAGID [$1]=[$r]"
    touch "$rar_state_list"
    awk "-F$rar_state_sep" '{ if ( $1 != "'"$r"'" ) { print }} END { print "'"$r$rar_state_sep$s"'" } ' $rar_state_list > $rar_state_list.1 &&\
    mv $rar_state_list.1 $rar_state_list
    DEBUG "SET RARSTATE [$r]=[$s]"
}

LIST_RAR_STATES() {
    state_pattern="$1"
    touch "$rar_state_list"
    awk "-F$rar_state_sep" '{ if ( $2 ~ "'"$state_pattern"'" ) { print $1 }}' $rar_state_list
}

#The script is rar-driven (we may not have downloaded any pars yet and unrar before looking at pars)
#However, the initial rar file may be missing. So we need to look at all rar files present to 
#know the state of rar files.
#The only situation we cant manage is where there are no rar parts at all. Unlikely.


INIT_ALL_RAR_STATES() {
    CLEAR_ALL_RAR_STATES 1
    lastPart=

    # Initialise the rar state file. This consist of each rar archive name
    # in the top level directory followed by '*UNKNOWN' (ie state is unknown)
    # There is one entry per multi-volume archive.
    # There are only entries if volumes are present at the start of processing.
    ls | awk '
    BEGIN {last_flag=""}
    {
    if (sub(/'"$rar_re"'/,"")) {
        gsub(/["'"'"']/,"") #REMOVE quotes to get FLAGID
        flag=$0
        if (flag != last_flag) {
            print flag "'$rar_state_sep'UNKNOWN"
            last_flag = flag
        }
    }}' > "$rar_state_list"
    
    LOGSTREAM DEBUG "init" < "$rar_state_list"
}

#We have previously unpacked each rar in its own folder to avoid clashes.
#This function should be called right at the end to push everything up
#to the main folder.

#TODO ensure that we can download two dvd's eg 2*VIDEO_TS

MOVE_RAR_CONTENTS() {

    #INFO "Move rar contents into $1 = $(pwd)"
    if [ -d "$unrar_tmp_dir" ]; then 
        DEBUG "Moving rar contents up from [$PWD/$unrar_tmp_dir]"
        ( cd "$unrar_tmp_dir"; MOVE_RAR_CONTENTS "../$1" )
        #Copy directory up. 
        #
        # could use mv $unrar_tmp_dir/* . but two problems.
        #
        # Hidden files and 
        # mv with globbing will return an error if no files match.
        #But we dont really mind that, we only want an error if there was
        #a problem actually moving a real file.
        # 
        ls -A "$unrar_tmp_dir" | EXEC_FILE_LIST "mv '$unrar_tmp_dir/'\1 ." -e
        rmdir "$unrar_tmp_dir"
    fi
}


#Delete rar files. These should be deleted at the end of all processing,
#as they may be needed for a par repair of a different rar file
#Some par sets span multiple rars.
DELETE_RAR_FILES() {
    if [ -f "$delete_queue" ] ; then
        if [ $unpak_delete_rar_files -eq 1 ] ; then
            EXEC_FILE_LIST "rm \1" "-e" < "$delete_queue"
        else
            mv "$delete_queue" "$delete_queue.bak"
        fi
    fi
    rm -f "$delete_queue"
}

#Delete sample files if there are other media files present.
DELETE_SAMPLES() {
    all_media=$( ls -l *.avi *.mkv 2>/dev/null | LINE_COUNT )
    sample_media=$( ls -l *[-.]sample.avi *[-.]sample.mkv *[-.]samp.avi *[-.]samp.mkv 2>/dev/null | LINE_COUNT )
    if [ "$sample_media" -gt 0 -a "$all_media" -gt "$sample_media" ] ; then
        rm -f *[-.]sample.avi *[-.]sample.mkv *[-.]samp.avi *[-.]samp.mkv 2>/dev/null
    fi
}

CLEAR_ALL_RAR_STATES() {
    force=$1
    if [ "$force" -eq 1 -o $unpak_debug_mode -eq 0 ] ; then
        rm -f "$rar_state_list"
    fi
}

LOG_ARGS() {
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
MERGE_FOLDERS() {
    if [ ! "$1" -ef "$2" ] ; then
        DEBUG "MERGE CONTENTS [$1]->[$2]"
        if [ ! -e "$2" ] ; then
            mkdir -p "$2"
        fi
        ls -A "$1" | while IFS= read f ; do
            if [ -d "$1/$f" ] ;then
                if [ -e "$2/$f" ] ; then
                    MERGE_FOLDERS "$1/$f" "$2/$f"
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

# Create Genre Folder. This will have sub folders based on Genre
# Action/Drama etc. and Certification UK:PG etc.

CSV_TO_EGREP() {
    echo "$1" | sed 's/^/(/;s/,/|/g;s/\./\\./g;s/$/)/'
}

# Pass a list of files to some command
# stdin = list of files.
# $1 = command to execute where '\1' is the file path \2=folder \3=name(without ext) \4=ext
# (Shell meta-characters are backslash escaped before applying the command. So additional
# quotes should not be used.
#
# eg echo filename.exe | EXEC_FILE_LIST 'rm \1' 
# if filename contains single or double quotes, *, ? , []  these will be escaped.
# 
# $2 = any shell options or "--" if none
# Leaving $2 unquoted allows ""
EXEC_FILE_LIST() {
    sep=":"
    sep2=";"
    dir="(|.*\/)"
    nameExt="([^/]+)(\.[^./]*)"
    nameNoExt="([^./]+)()" #Note must anchor with '$' when used otherwise will match extensions.
    case "$1" in *$sep*) sep="$sep2" ;; esac

    # Save list and replace shell expansion meta chars.
    sed -r "s/([][\(\|\);' *?"'"'"])/\\\&/g" > "$gTmpFile.exec"

    #Now apply the substitution in $1
    sed -rn "s$sep^($dir$nameExt)\$$sep$1${sep}p" "$gTmpFile.exec" > "$gTmpFile.sh"
    sed -rn "s$sep^($dir$nameNoExt)\$$sep$1${sep}p" "$gTmpFile.exec" >> "$gTmpFile.sh"

    if [ $unpak_debug_mode -eq 1 ] ; then
        DEBUG "BEGIN FILE LIST for $1 : $2"
        LOGSTREAM DEBUG "sh-file" < "$gTmpFile.exec"
        LOGSTREAM DEBUG "sh-cmd" < "$gTmpFile.sh"
        #( echo "$1" ; cat "$gTmpFile.exec" ; cat "$gTmpFile.sh" ) >> "$gTmpFile.shall"
    fi
    rm -f -- "$gTmpFile.exec"

    ( echo 'set -e ' ; cat "$gTmpFile.sh" ) | sh $2

    rm -f -- "$gTmpFile.sh"
}
NO_RARS() { ! ls *.rar > /dev/null 2>&1 ; }
SET_PASS() { gPass=$1 ; INFO "PASS $1" ; }

############################################################################
# PIN FOLDER HACK 
# If a category begins with 'PIN:FOLDER' then replace that with the path
# to the pin folder. This is simply a folder burried in a heirachy of
# similarly named folders. The path to the folder is defined by
# $unpak_nmt_pin_root and the $unpak_nmt_pin
############################################################################

NMT_MAKE_PIN_FOLDER() {
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
        if [ $(ls | LINE_COUNT) -le 1 ] ; then
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
NMT_GET_PIN_FOLDER() {

    #Convert 2468 to /pin/path/2/4/6/8/
    nmt_pin_path="$unpak_nmt_pin_root/"$(echo $unpak_nmt_pin | sed 's/\(.\)/\/\1/g')   

    if [ ! -d "$nmt_pin_path" ] ; then
        ( NMT_MAKE_PIN_FOLDER "$nmt_pin_path" )
    fi

    echo $nmt_pin_path
}

AUTO_CATEGORY_FROM_NEWSGROUPS_INSIDE_NZB() {
    if [ "$unpak_auto_categorisation_from_newsgroups" -ne 1 ] ; then return 0 ; fi
    #Get values of all subfolder_by_newsgroup_ variables.
    set | sed -n '/^unpak_subfolder_by_newsgroup_[0-9]/ s/^[^=]*=//p' | sed "s/^' *//g;s/ *: */=/;s/ *'$//g" |\
        while IFS== read keyword destination ; do
            DEBUG "Check category $keyword=$destination"
            if grep -ql "<group>.*$keyword.*</group>" "$arg_nzb_file".* ; then
                INFO "Getting category from newsgroup matching [$keyword]"

                case "$destination" in 
                    PIN:FOLDER) destination=`NMT_GET_PIN_FOLDER` ;;
                esac

                # Resolve relative dirs, create destination folder and send to stdout
                ( cd $nzbget_DestDir ;  cd $unpak_completed_dir ; mkdir -p "$destination" ; cd "$destination" ; pwd )

                break
            fi
        done
}

##################################################################################
#Some global settings
finished_nzb_ext=".completed"
gTmpFile="/tmp/unpak.$$"
flatten="=@="
#
##################################################################################
# MAIN SCRIPT
##################################################################################
MAIN() {
    INFO "SCRIPT_FOLDER=[$SCRIPT_FOLDER] PIN $unpak_nmt_pin"

    if [ $unpak_pause_nzbget -eq 1 ] ; then
        PAUSE_NZBGET
    fi


    LOG_ARGS "$@"

    NZB_NICE_NAME=$(GET_NICE_NZBNAME "$arg_nzb_file") 


    #Only run at the end of nzbjob
    if [ "$arg_nzb_state" -ne 1 ] ; then
        exit
    fi

    INFO " ====== Post-process Started : $NZB_NICE_NAME $(date '+%T')======"

    CHECK_SETTINGS || exit 1

    if [ "$arg_par_fail" -ne 0 ] ; then
        ERROR "Previous par-check failed, exiting"
        exit 1
    fi

    case "$arg_par_check" in
        0)
            if [ -f _brokenlog.txt -a "$external_par_check" -ne 1 ] ; then
                ERROR "par-check is disabled or no pars present, but a rar is broken, exiting"
                exit 1
            fi
            ;;
       1) ERROR "par-check failed, exiting" 
          exit 1 ;;
       2) true ;; # Checked and repaired.
       3) WARNING "Par can be repaired but repair is disabled, exiting"
          exit 1 ;;
    esac

    VERSION_CHECK
    #---------------------------------------------------------

    if [ "$arg_par_check" -eq 0 -a "$external_par_check" -eq 1 ] ; then
        if ! WAITING_FOR_PARS ; then
            SET_PASS 1
            #First pass. Try to unrar. 
            INFO "$SCRIPT_NAME : PASS 1"
            INIT_ALL_RAR_STATES
            if NO_RARS || ! UNRAR_ALL ; then
                # unpause pars. UNPAUSE_PARS_AND_REPROCESS will return error and set WAITING_FOR_PARS if
                # nothing to unpause.
                if ! UNPAUSE_PARS_AND_REPROCESS ; then
                    # No pars to unpause so start Pass2 immediately (par repair followed by unrar)
                    SET_PASS 2
                    PAR_REPAIR_ALL && UNRAR_ALL || true
                fi
            fi
        else
            SET_PASS 2
            INFO "$SCRIPT_NAME : PASS 2"
            #Second pass. Now pars have been fetched try to repair and unrar
            CLEAR_WAITING_FOR_PARS
            PAR_REPAIR_ALL && UNRAR_ALL || true
        fi
    else
        # One pass  - no rars (no pars or nzbget has repaired already)
        SET_PASS 0
        INIT_ALL_RAR_STATES
        UNRAR_ALL || true
    fi

    #---------------------------------------------------------

    chmod -R a+rw . || true
    # No logging after this point as folder is moved.
    if [ $unpak_pause_nzbget -eq 1 ] ; then
        UNPAUSE_NZBGET
    fi

    #---------------------------------------------------------

    cat=
    if ! WAITING_FOR_PARS ; then
        if CHECK_TOP_LEVEL_UNRAR_STATE 0 ; then
            if [ -n "$unpak_completed_dir" -a "$nzbget_AppendNzbDir" = "yes" ] ; then
                b=`BASENAME "$arg_download_dir" ""`

                dest=`AUTO_CATEGORY_FROM_NEWSGROUPS_INSIDE_NZB`
                if [ -n "$dest" ] ; then 

                    case "$dest" in
                        $unpak_nmt_pin_root*)
                            #The colon forces short dos names from windows share.
                            if [  "$unpak_nmt_pin_folder_scramble_windows_share" = 1 ] ; then
                                b="$b:"
                            fi
                            ;;
                    esac
                    mv "$arg_download_dir" "$dest/$b"
                else
                    #Everything else 
                    unpak_completed_dir=$( cd "$nzbget_DestDir" ; cd "$unpak_completed_dir" ; pwd )
                    mv "$arg_download_dir" "$unpak_completed_dir/."
                    if [ -f "$SCRIPT_FOLDER/catalog.sh" ] ; then
                        sh "$SCRIPT_FOLDER/catalog.sh" "FILM_FOLDER_FMT=$unpak_movie_folder_format" "TV_FILE_FMT=$unpak_tv_file_format" "$unpak_completed_dir/$b"
                    else
                        INFO "Catalog script not present in $SCRIPT_FOLDER"
                    fi
                fi
            fi
        fi
    fi

    # ----- END GAME -----

    s=
    if WAITING_FOR_PARS ; then s="Waiting for PARS" ; fi
    if CHECK_TOP_LEVEL_UNRAR_STATE 1 ; then 
        INFO " ====== Post-process Finished : $1 : $NZB_NICE_NAME : $s $(date '+%T') ======"
    else
        ERROR " ====== Post-process Finished : $1 : $NZB_NICE_NAME : $s $(date '+%T') ======"
    fi
}

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

if [ "$#" -lt 6 ]
then
    echo "*** NZBGet post-process script ***"
    echo "This script is supposed to be called from nzbget."
    echo "usage: $0 dir nzbname parname parcheck-result nzb-job-state failed-jobs"
    #exit
fi

arg_download_dir="$1"   
arg_nzb_file="$2" 
arg_par_check="$4" 
arg_nzb_state="$5"  
arg_par_fail="$6" 
arg_category="${7:-}"


SCRIPT_NAME=$(BASENAME "$0" "")

SCRIPT_FOLDER=$( cd $(DIRNAME "$0") ; pwd )

SET_DEFAULT_SETTINGS

MERGE_UNPAK_SETTINGS

cd "$arg_download_dir" 

#mkdir -p "$arg_download_dir.2"
#ln * "$arg_download_dir.2/."


MAIN "$@" 2>&1 | TEE_LOGFILES unpak.log || CLEAR_TMPFILES
if CHECK_TOP_LEVEL_UNRAR_STATE 0  ; then
  rm -f unpak.html
fi

#
# vi:shiftwidth=4:tabstop=4:expandtab
#
