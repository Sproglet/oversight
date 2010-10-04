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
    ks="if( then else while( do return match( substr( index( sub( gsub( gensub( in getline ";
    ks=ks" RSTART RLENGTH print print( systime( open( close( FS NF exit break for( system( ";
    ks=ks" delete return return( split( tolower( toupper( length( continue sprintf( int";
    ks=ks" rand( printf and( lshift( rshift( strftime(";
    gsub(/ +/," ",ks);
    gsub(/^ +/,"",ks);
    gsub(/ +$/,"",ks);
    split(ks,k," ");
    for (i in k) {
        reserved_words[k[i]]=1;
    }
    inawk=1;
}

END {
    for(fidx in fnames) {
        fname_hash[fnames[fidx]] = 1;
        #print "function "fnames[fidx];
    }

    for(fidx = 1 ; fidx <= fcount ; fidx++ ) {
        analyse(fnames[fidx]);
    }
}

/^#BEGINAWK/ { inawk=1; }
/^#ENDAWK/ { inawk=1; }

inawk {
    gsub(/\\./,""); #remove escaped characters.

    # comments
    gsub(/^ *#.*/,"");
    gsub(/[{;}] *#.*/,"");

    #quoted strings - keep @ there to stop g"text"( becoming g( and looking like a function call
    gsub(/"[^\"]*"/,"@");

    #quoted regex`
    gsub(/\/.*[^\/]\//,"@"); 


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

    l = $0;

    debug = 0;

    #eg a(b (c)) + ( 6 ) 

    #remove all spaces surrounding open brackets 
    #eg a(b(c))+(6) 
    gsub(/ *\( */,"(",l); 
    if (debug) print "X1X ["l"]";

    # insert one space after open brackets
    #eg a( b( c))+( 6) 
    gsub(/\(/,"( ",l); 
    if (debug) print "X2X ["l"]";

    # remove all open brackets that are not preceded by alnum (also removes the non-alnum but we dont care)
    #eg a( b( c))+ 6) 
    while(match(l,"[^_0-9A-Za-z]\\(")) {
        l = substr(l,1,RSTART) substr(l,RSTART+RLENGTH);
    }
    if (debug) print "X3X ["l"]";

    # remove all non alphanumerics leave function calls as name(
    gsub(/[^_0-9A-Za-z(]+/," ",l);
    if (debug) print "X4X ["l"]";

    body[fname] = body[fname] " " l;

    if (br_close && br_count == 0) {
        part="ignore";
    }
}

# remove all integers and all non-alphanumber strings (keep open brackets for function calls)
function clean(t) {
    gsub(/\<[0-9]+\>/,"",t);
    gsub(/[^_0-9A-Za-z(]+/," ",t);
    return t;
}

function parse(t,names,\
tmp) {
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

    #debug = (index(body[f],"unit5"));
    debug = 0;

    for(token in par) {
        if (!(token in bdy)) {
            print prefix"Unused parameter "token;
            err=1;
        }
    }
    for(token in loc) {
        if (!(token in bdy)) {
            print prefix"Unused local "token;
            err=2;
        }
    }

    # check undefined functions

    for(token in bdy) {
        #params keys on all functions names

        if (match(token,"\\($") ) {

            # check function name
            if (debug) print "CHECKING function ["token"]";

            token = substr(token,1,RSTART-1);

            if (debug) print "is "token" function = "(token in fname_hash);
            if (debug) print "is "token" keyword = "(token"(" in reserved_words);

            if (!(token in fname_hash) && !(token"(" in reserved_words)) {
                print prefix"undefined function "token;
            }
        } else {
            # check variable
            if (debug) print "CHECKING variable ["token"]";

            if (!(token in reserved_words) && !(token in params) && !(token in par) && !(token in loc)) {
                if (token !~ "^g[_A-Z]" && token !~ "^[_A-Z0-9]" ) {
                    print prefix"global?\t"token;
                    err=3;
                }
            }
        }
    }
}

/^#ENDAWK/ {
    part="";
}

    ' "$@"
}

lint "$@"
