#!/bin/sh
VERSION=20090605-1BETA

OVS_HOME=$( echo $0 | sed -r 's|[^/]+$||' )
OVS_HOME=$(cd "${OVS_HOME:-.}" ; cd .. ; pwd )

TMPDIR="$OVS_HOME/tmp"

#echo "OVS_HOME=$OVS_HOME"

#$1 = file
#$2 = variable
#$3=value
OPTION_SET() {
    vPatt=`echo "$2" | sed -r 's/([][])/\\\\\1/g'` #escape square brackets a[b] to a\[b\]
    if [ -f "$1" ] && grep -q "^$vPatt=" "$1" ; then
        cp "$1" "$1.old"

        sed "s^$vPatt=.*$2="'"'"$3"'"' "$1.old" > "$1"
    else
        echo "$2="'"'"$3"'"' >> "$1"
    fi
}

# $1=help file format <option name:help text|choice1|..|choicen>
# $2=cfg file  format <option name=value>
OPTION_GET() {
    OPTION_PARSE MODE=GET "$@"
}


# $1=help file format <option name:help text|choice1|..|choicen>
# $2=cfg file  format <option name=value>
# $3 optional awk variables eg HIDE_VAR_PREFIX=unpak_ will remove unpak_ prefix from displayed names.
OPTION_TABLE() {
    OPTION_PARSE MODE=TABLE "$@"
}
OPTION_TABLE2() {
    OPTION_PARSE MODE=TABLE2 "$@"
}

OPTION_PARSE() {

    for i in "$@" ; do
        case "$i" in
            *=*)
                opts="$opts $i"
                ;;
            *)
                if [ -f "$i" ] ; then
                    opts="$opts $i"
                fi
                ;;
        esac
    done

    cd "$OVS_HOME"

    awk '
# { print "<!-- "FILENAME " : " $0 "-->"; }
/^#/ { next }

FILENAME ~ "help$" {
     addVal(clean($0),":",help,1);
     next;
}

FILENAME ~ "(cfg|defaults)$" {
    addVal(clean($0),"=",val,0);
    next;
}

function clean(line,\
i) {
    sub(/\r$/,"",line);
    i=index(line,"#");
    if ( i > 0 ) { line = substr(line,1,i-1); }
    return line;
}

function addVal(line,sep,arr,addToOrder,   i,name,rest) {

    # if (MODE ~ "^TABLE") { print "<!-- "FILENAME " : " sep " : " $0 "-->"; }
    sub(/$/,"",line);
    i = index(line,sep);
    if (i > 0 ) {
        name=trim(substr(line,1,i-1));
        rest=trim(substr(line,i+1));
        if (addToOrder && !(name in help)) {
            order = order "|" name ;
        }
        arr[name] = rest;
        # print "<!-- "name"="rest" -->";
    }
}

# Trim trailing quote only if leading quote present.
function trim(x) {
    sub(/^ +/,"",x);
    sub(/ +$/,"",x);

    if (sub(/^["'"'"']+/,"",x) ) {
        sub(/["'"'"']+$/,"",x);
    }
    return x;
}

# input opt[1]=var name opt[2]=parent folder
# output opt[1]=var name opt[2...n]=child folder

function run_option_command(cmd,opts,\
tmpf,count,err) {

    delete opts;
    tmpf = "'"$TMPDIR/option.$$"'";
    cmd = cmd" > "quoteFile(tmpf);
    if (system(cmd) == 0 ) {
        count = 1;
        while ( err = (getline opts[count] < tmpf ) > 0  ) {
            count++;
        }
        count--;
        if (err != -1)  {
            close(tmpf)
        }
    } else {
        print "<-- ERROR: failed to run ["cmd"] -->";
    }
    system("rm -f "quoteFile(tmpf));
    return count;
}

function html_table(    i,n,current,sel,opts,optCount) {
    i=1;
    print "<table class=\"options\" width=\"100%\" >";

    if (MODE=="TABLE") {
    print "<tr class=\"optionrow\" ><th class=\"optionname\" width=20% >Option</td><th class=\"optionval\" width=40% >Value</td><th class=\"optionhelp\" width=40% >Description</td></tr>";
    } else {
        print "<tr class=\"optionrow\" ><th class=\"optionname\" >Option</td><th class=\"optionhelp\" >Description</td></tr>";
    }

    split(substr(order,2),ord,"|");

    for(i=1 ; ord[i] != "" ; i++) {

        n=ord[i];

        current=(n in val)?val[n]:""

        draw_choice="";
        if (n in options) {


            if (match(options[n],"@CMD:")) {

                optCount = run_option_command(substr(options[n],RSTART+RLENGTH),opts);
            } else {
                optCount = split(options[n],opts,"|");
            }

            if (optCount > 0 && !(n in val) ) {
                #Take default from first option
                current = val[n]=opts[1];
            }

            if (optCount > 1) {

                draw_choice = sprintf("<select name=option_%s>",n);
                for(o=1 ; o <= optCount ; o++) {
                    if (opts[o] == current) {
                        sel=" selected=\"selected\"";
                    } else {
                        sel="";
                    }
                    # if the value = "display=>&htmlparam=val" then only display the "display" bit.
                    display_text = opts[o];
                    display_and_value=index(opts[o],"=>");
                    if ( display_and_value ) {
                        # just use the inital part for the displayed text.
                        display_text = substr(display_text,1,display_and_value-1);
                    }
                    draw_choice = draw_choice sprintf("\t<option value=\"%s\" %s>%s</option>\n",opts[o],sel,display_text);
                }
                draw_choice = draw_choice "</select>";
            }

        }
        if (draw_choice == "") {
            draw_choice = sprintf("<input type=text size=20 name=option_%s value=\"%s\" >",n,current);
        }

        shortName=n;
        if (HIDE_VAR_PREFIX != "" ) {
           shortName=substr(n,index(n,"_")+1);
       }
        print "<tr class=optionrow"(i%2)"><td class=optionname><b>"shortName"</b>";
#        if (ENVIRON["REMOTE_ADDR"] != "127.0.0.1") {
#            printf "(%s)",(n in val)?val[n]:"unset";
#        }
        print "<input type=hidden name=orig_option_"n" value=\""val[n]"\" >";

        if (MODE == "TABLE") {
            print "</td><td class=optionval>";
        } else {
            print "<br>";
        }

        print draw_choice;
        print "<td class=optionhelp>"help[n]"</td></tr>";
        q="'"'"'";
        #print "<td class=optionhelp><a href=\"javascript:alert("q help[n] q");\" >?</a></td></tr>";
    }
    print "</table>";
}

#Return file name with shell meta-chars escaped.
function quoteFile(f,
    q) {
    q="'"'"'";
    gsub(q, q "\\" q q,f);
    return q f q;
}

function shell_assign() {
    for (n in help) {
        if (n in val) {
            v=val[n];
        } else {
            split(options[n],opts,"|");
            v=opts[1];
        }
        printf "option_%s=%s;",n,quoteFile(v);
    }
    #Also do additional options in the cfg but not in the help
    for (n in val) {
        if(!(n in help)) {
            printf "option_%s=%s;",n,quoteFile(val[n]);
        }
    }
}

END {
    for (n in help) {
        i=index(help[n],"|");
        if (i > 0 ) {
            options[n]=substr(help[n],i+1);
            help[n]=substr(help[n],1,i-1);

        }
    }
    if (index(MODE,"TABLE") ) {
        html_table();
    } else if (MODE == "GET") {
        shell_assign();
    } else {
        print "ERROR";
    }
}
' $opts
}

func=$1
shift
case "$func" in
    TABLE) OPTION_TABLE "$@" ;; ## help config defaults
    TABLE2) OPTION_TABLE2 "$@" ;;
    GET) OPTION_GET "$@" ;;
    SET) OPTION_SET "$@" ;;
    *) cat <<HERE
$0 TABLE helpFile configFile
    Draw html table to set options.
    help file format <option name:help text|choice1|..|choicen>
    cfg file  format <option name=value>

$0 TABLE2 helpFile configFile
   Another table with two columns. name and value in the same html table cell

$0 GET helpFile configFile
    Disply a line of all settings. This can be passed to eval eg.
    eval \`$0 GET helpfile configfile\`
    Note options that are not set in cfg take first value in help as thier default values

$0 SET configFile name value
HERE
    ;;
esac

#OPTION_TABLE test_option.cfg.help test_option.cfg
#OPTION_SET test_option.cfg free slave2
#OPTION_SET test_option.cfg slave prisoner

# vi:shiftwidth=4:tabstop=4:expandtab
