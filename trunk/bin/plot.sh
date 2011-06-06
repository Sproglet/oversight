#!/bin/sh

# manage the plot file.
#
# format
#
# id tab season tab episode tab plot
#
# where id = some unique id eg imdbid for now. Maybe later tvdb-# or tvrage-# etc.
# season = show season number or blank
# episode = show episode number or blank

tab="	"

# this should be passed by catalog.sh
if [ -z "$OVERSIGHT_ID" ] ; then
    OVERSIGHT_ID="nmt:nmt"
fi

# like mv but keep perms on original file
replace() {
    b="$2.`date +%a.%P`"
    cp "$2" "$b" && chown "$OVERSIGHT_ID" "$b"
    cat "$1" > "$2" && rm -f "$1" && chown "$OVERSIGHT_ID" "$2"
}

plot() {
    action="$1" ; shift;
    file="$1" ; shift
    if [ $# -gt 0 ] ; then
        id="$1" ;  shift;
        compact_ref="$id" # for compacting this param is the reference file
    fi
    if [ $# -gt 0 ] ; then
        season="$1"; shift;
        episode="$1"; shift;
    fi

    tag="_@${id}@${season}@${episode}@_"

    case "$action" in
        del|delete)
            sed -i "/^$tag/ { d ; q }" "$file"
            ;;
        ins|insert)
            echo "$tag$@" >> "$file"
            ;;
        upd|update)
            # Because the plot may contain weird characters its easier to just delete it an re-add using echo.
            sed -i "/^$tag/ { d ; q }" "$file"
            echo "$tag$@" >> "$file"

             ;;

        exists)
            grep -q "$tag" "$file"
            ;;
        compact)
            prune "$file" "$compact_ref"
            ;;
            
        *)
            echo "$0: unknown plot operation $action"
            usage
            ;;
    esac

}

usage() {
    cat <<HERE
        usage $0 update|insert file id season episode plot

        usage $0 delete|exists file id season episode
          Check if the plot tag is anywhere in the file

        usage $0 tag file id season episode
          display the internal plot tag 

        usage $0 compact file referencefile
           remove all plot ids that are not present in the reference file
HERE
    exit 1
}

prune() {
    plotfile="$1"
    reffile="$2"

    #pwd
    #ls -l /share/Apps/oversight

    awk '
#BEGINAWK

END {
    plotfile="'"$plotfile"'";
    reffile="'"$reffile"'";
    g_pid="'$$'";

    g_plotpattern="_@[0-9a-zA-Z]+@[0-9]*@[0-9a-z]*@_";

    inf("Plotfile=["plotfile"]");
    inf("Reffile=["reffile"]");

    
    extract_plot_tags(reffile,keep);

    #inf("Keeping plots..");
    #for(i in keep) inf("keep plot["i"]");

    prune_plotfile(plotfile,keep);
}

function inf(x) {
    print "[INFO] "x;
}

function err(x) {
    print "[ERROR] "x;
}

function getField(id,line,\
out,offset,i) {
    offset = length(id)+2;
    id = "\t"id"\t";

    if ( match(line,id "[^\t]+") ) {
        out=substr(line,RSTART+offset,RLENGTH-offset);
    }
    #inf("["id"] = ["out"]");
    return out;

}


# compute all of the plot keys from the ttids , seasons and episodes in the file.
function extract_plot_tags(f,keep,\
ref,m,i,num) {

    inf("Extract plot tags from "f);
    while ((getline ref < f ) > 0) {

        url=getField("_U",ref);
        num = split(url,ids);
        for (i = 1 ; i <= num ; i++ ) {

            if (ids[i] != "" ) {

                cat=getField("_C",ref);

                if (cat == "T") {

                    season=getField("_s",ref);
                    episode=getField("_e",ref);

                    keep[ids[i]"@"season] = 1;
                    keep[ids[i]"@"season"@"episode] = 1;
                } else {
                    keep[ids[i]] = 1;
                }
            }
        }
    }
    close(f);
}

# Go through each line of the plot file, if the plot
# is in the "keep" array, keep the line.
function prune_plotfile(f,keep,\
id,tmpf,kept_count,removed_count,plot,err,parts) {

    tmpf=f"."g_pid;
    inf("Prune plots in "f " using "tmpf);

    kept_count = removed_count = 0;

    printf "" > tmpf;
    while ((err = (getline plot < f )) > 0) {


        if (split(plot,parts,"\t") > 0) {

            id = parts[1];

            if (id in keep) {
                print plot > tmpf;
                kept_count ++;
            } else {
                print "Removing plot "id;
                removed_count ++;
            }
        }
    }
    if (err == 0 ) close(f);
    close(tmpf);
    print "plot compact: kept "kept_count" : removed "removed_count;
}

#ENDAWK
' </dev/null

    #echo ====
    #ls -l /share/Apps/oversight
    #echo ====
    #echo replace "$plotfile.$$" "$plotfile"
    replace "$plotfile.$$" "$plotfile"

}

plot "$@"
