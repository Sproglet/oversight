#!/bin/sh

#quick awk script to check some things. gnu --lint didnt do the checks I wanted
# maybe better to patch lint mode of gnu awk than to put any more effort into this script,
#
# As awk args are used as local variables so to distinguish between them
# it expects functions to be coded as follows

# function somename(arg1,arg2,arg2,\ #an actual backslash at end of main args
# local1,local2,local3) {
#    ...
# }
#

lint() {

    awk '

BEGIN {
    ks="if then else while do return match substr index sub gsub in getline ";
    ks=ks" RSTART RLENGTH print systime open close FS NF exit break for system ";
    ks=ks" delete return split tolower toupper length continue sprintf int";
    ks=ks" rand printf and lshift rshift strftime";
    gsub(/ +/," ",ks);
    gsub(/^ +/,"",ks);
    gsub(/ +$/,"",ks);
    split(ks,k," ");
    for (i in k) {
        kwd[k[i]]=1;
    }
    inawk=1;
}

END {
    for(fidx = 1 ; fidx <= fcount ; fidx++ ) {
        analyse(fnames[fidx]);
    }
}

/^#BEGINAWK/ { inawk=1; }
/^#ENDAWK/ { inawk=1; }

inawk {
    gsub(/\\./,""); #remove escaped characters.

    gsub(/"[^\"]*"/," "); #quoted strings
    gsub(/\/[^\/]*\//," "); #regex quotes
    gsub(/#.*/,""); #comments
    gsub(/^[ \t]+/,""); # leading space
    gsub(/[ \t]+$/,""); # trailing space
    br_open=(index($0,"{") != 0);
    br_close=(index($0,"}") != 0);
    br_count += (br_open ) - (br_close) ;
    cont_line=(substr($0,length($0)) == "\\");
}

/^function/ && inawk {
   gsub(/[^_0-9A-Za-z]+/," ",$0);
   fname=$2
   $1 = $2 = "";
   fnames[++fcount]=fname;
   params[fname]=$0;
   lineno[fname]=FNR;
   file[fname]=FILENAME;
   gsub(/[^_0-9A-Za-z]+/," ",params[fname]);
   #print "params "params[fname];
   if (br_open) {
       part="body";
   } else if (cont_line) {
       part="local";
   } else {
       part="params";
   }
   next;
}

part=="params" {
      params[fname] = params[fname] " " $0;
      gsub(/[^_0-9A-Za-z]+/," ",params[fname]);
      if (br_open) {
          part="body";
      } else if (cont_line) {
          part="local";
      }
      next;
}

part=="local" {
      local[fname] = local[fname] " " $0;
      gsub(/[^_0-9A-Za-z]+/," ",local[fname]);
      if (br_open) {
          part="body";
      } else if (cont_line) {
          part="local";
      }
      next;
}

part=="body" {
    body[fname] = body[fname] " " $0;
    gsub(/[^_0-9A-Za-z]+/," ",body[fname]);
    if (br_close && br_count == 0) {
        part="ignore";
    }
}

function clean(t) {
    gsub(/\<[0-9]+\>/,"",t);
    gsub(/[^_0-9A-Za-z]+/," ",t);
    return t;
}

function parse(t,names,tmp) {
    delete names;
    split(clean(t),tmp," ");
    for(i in tmp) {
        names[tmp[i]] = 1;
    }
}


function analyse(f,\
 msg,prefix) {

    err=0;
    prefix = file[f]":"lineno[f]": error: "f"():";
    parse(params[f],par);
    parse(local[f],loc);
    parse(body[f],bdy);

    #msg = msg "\n\tparams:\t"params[f];
    #msg = msg "\n\tlocal:\t"local[f];
    for(i in par) {
        if (!(i in bdy)) {
            msg = msg "\n"prefix"Unused parameter "i;
            err=1;
        }
    }
    for(i in loc) {
        if (!(i in bdy)) {
            msg = msg "\n"prefix"Unused local "i;
            err=2;
        }
    }
    for(i in bdy) {
        #params keys on all functions names
        if (!(i in kwd) && !(i in params) && !(i in par) && !(i in loc)) {
            if (i !~ "^g[_A-Z]" && i !~ "^[_A-Z0-9]" ) {
                msg = msg "\n"prefix"global?\t"i;
                err=3;
            }
        }
    }
    if (err)    {
        print msg;
    }
}

/^#ENDAWK/ {
    part="";
}

    ' "$@"
}

lint "$@"
