
# Extract the filename from the path. Note if the file ends in / then the folder is the filename
function basename(f) {
    if (match(f,"/[^/]+$")) {
        # /path/to/file return "file"
        f=substr(f,RSTART+1);
    } else if (match(f,"/[^/]+/$")) {
        # "/path/to/folder/" return "folder"
        f=substr(f,RSTART+1,RLENGTH-2);
    }
    sub(gExtRegExAll,"",f); #remove extension
    return f;
}

function hasContent(f,\
tmp,err) {
    err = (getline tmp < f );
    if (err != -1) close(f);
    return (err == 1 );
}

function isnmt() {
    return 0+ is_file(NMT_APP_DIR"/MIN_FIRMWARE_VER");
}

# changed from getline error check because gawk 3.1.6 has uncatchable error if input is a directory
# echo /etc/..  | gawk '{ e = (getline tmp < $0 ) ; print "error ",$0,e }'
# gawk: (FILENAME=- FNR=1) fatal: file `/etc/..' is a directory

function is_file(f) {
    return test("-f",f);
}

function is_empty(d) {
    return system("ls -1A "qa(d)" | grep -q .") != 0;
}

function is_dir(f) {
    return test("-d",f"/.");
}

function is_file_or_folder(f) {
    return test("-e",f);
}

function file_copy(old,new) {
    return exec("cp -f "qa(old)" "qa(new));
}

function test(t,f) {
    return system("test "t" "qa(f)) == 0;
}

function ascii8(s) {
    return s ~ "["g_8bit"]";
}

#ALL# #set up accent translations
#ALL# function accent_init(\
#ALL# asc7,asc8,c7,c8,i) {
#ALL#     if (!("Ï" in g_acc )) {
#ALL#         asc8="¥µÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝßàáâãäåæçèéêëìíîïðñòóôõöøùúûüýÿ";
#ALL#                asc7="SOZsozYYuAAAAAAACEEEEIIIIDNOOOOOOUUUUYsaaaaaaaceeeeiiiionoooooouuuuyy";
#ALL#         for(i = 1 ; i <= length(asc8) ; i++ ) {
#ALL#             c7=substr(asc7,i,1)
#ALL#             c8=substr(asc8,i,1)
#ALL#             g_acc[c8] = c7;
#ALL#             g_acc[utf8_encode(c8)] = c7;
#ALL#         }
#ALL#     }
#ALL# }
#ALL# 
#ALL# #http://weblogtoolscollection.com/b2-img/convertaccents.phps
#ALL# function no_accent(s,\
#ALL# i,j,out,s1,s2) {
#ALL#     if (ascii7(s) == 0) {
#ALL#         accent_init();
#ALL#         for(i = 1 ; i <= length(s) ; i++ ) {
#ALL#             c=substr(s,i,1);
#ALL#             if ( c"" <= "~" ) {
#ALL#                 out = out c;
#ALL#             } else if ((c2=g_acc[c]) != "") {
#ALL#                 out = out c2;
#ALL#             } else if ((c2=g_acc[substr(s,i,2)]) != "") {
#ALL#                 out = out c2;
#ALL#                 i++;
#ALL#             } else {
#ALL#                 out = out "?";
#ALL#                 i++;
#ALL#             }
#ALL#                 
#ALL#             if ((j=index(s1,c)) > 0) {
#ALL#                 s = substr(s,1,i-1) substr(s2,i,1) substr(s,i+1);
#ALL#             }
#ALL#         }
#ALL#     }
#ALL#     return s;
#ALL# }

function prepare_path(f) {
    return system("mkdir -p "qa(f)" && rmdir -- "qa(f)) == 0;
}

#--------------------------------------------------------------------
# Convinience function. Create a new file to capture some information.
# At the end capture files are deleted.
#--------------------------------------------------------------------
function new_capture_file(label,\
    fname) {
    # fname = CAPTURE_PREFIX JOBID  "." CAPTURE_COUNT "__" label; # ALL
    fname = CAPTURE_PREFIX PID  "." CAPTURE_COUNT "__" label;
    prepare_path(fname);
    CAPTURE_COUNT++;
    return fname;
}

function clean_capture_files() {
    INF("Clean up");
    exec("rm -f -- "qa(CAPTURE_PREFIX JOBID) ".* 2>/dev/null");
}
function DEBUG(x) {
        
    if ( DBG ) {
        timestamp("[DEBUG]  ",x);
    }

}

function DIV0(x) {
    INF("\n\t\t@@@@@@@\t"x"\t@@@@@@@@@@\n");
}
function DIV(x) {
    INF("\t===\t"x"\t===");
}

function INF(x) {
    timestamp("[INFO]   ",x);
}
function WARNING(x) {
    timestamp("[WARNING]",x);
}
function ERR(x) {
    timestamp("[ERR]    ",x);
}
function DETAIL(x) {
    timestamp("[DETAIL] ",x);
}

function timestamp(label,x) {

    if (index(x,g_api_tvdb) ) gsub(g_api_tvdb,".",x);
    if (index(x,g_api_tmdb) ) gsub(g_api_tmdb,".",x);
    if (index(x,g_api_rage) ) gsub(g_api_rage,".",x);

    if (index(x,"app.i") ) {
        sub("app.i[[:alnum:]/?=&]+","",x);
    }
    if (index(x,"d=") ) {
        sub("password.?=([^,]+)","password=***",x);
        sub("pwd=([^,]+)","pwd=xxx",x);
        sub("passwd=([^,]+)","passwd=***",x);
    }

    if (systime() != g_last_ts) {
        g_last_ts=systime();
        g_last_ts_str=strftime("%H:%M:%S : ",g_last_ts);
    }
    print label" "LOG_TAG" "g_last_ts_str g_indent x;
    fflush();
}

# Remove spaces and non alphanum
function trimAll(str) {
    sub(g_punc[0]"$","",str);
    sub("^"g_punc[0],"",str);
    return str;
}

function trim(str) {
    sub(/^[[:space:]]+/,"",str);
    sub(/[[:space:]]$/,"",str);
    return str;
}

function apply(text) {
    gsub(/[0-9][0-9][0-9][0-9][0-9]/,"",text);
    return text;
}
#baseN - return a number base n. All output bytes are offset by 128 so the characters will not 
#clash with seperators and other ascii characters.

function basen(i,n,offset,\
out) {
    if (g_chr[32] == "" ) {
        decode_init();
    }

    while(i+0 > 0) {
        out = g_chr[(i%n)+offset] out;
        i = int(i/n);
    }
    if (out == "") out=g_chr[offset];
    return out;
}
#base10 - convert a base n number back to base 10. All input bytes are offset by 'offset'
#so the characters will not clash with seperators and other ascii characters.
function base10(input,n,offset,\
out,digits,ln,i) {
    if (g_chr[32] == "" ) {
        decode_init();
    }
    ln = split(input,digits,"");
    for(i = 1 ; i <= ln ; i++ ) {
        out = out *n + (g_ascii[digits[i]]-offset);
    }
    if (out == "") out=0;
    return out+0;
}

function firstIndex(inHash,\
i) {
    for (i in inHash) return i;
}

function hex2dec(s) {
    return strtonum( "0x"s ) ;
}

function firstDatum(inHash,\
i) {
    for (i in inHash) return inHash[i];
}

#Find all the entries that share the highest score.
#using a tmp array allows same array to be used for in and out
function bestScores(inHash,outHash,textMode,\
i,bestScore,count,tmp,isHigher) {
    
    #dump(1,"pre best",inHash);
    count = 0;
    for(i in inHash) {
        if (textMode) {
            isHigher= ""inHash[i] > ""bestScore; #ie 2>11 OR 2009-10 > 2009-09
        } else {
            isHigher= 0+inHash[i] > 0+bestScore;
        }
        if (bestScore=="" || isHigher) {
            delete tmp;
            tmp[i]=bestScore=inHash[i];
        } else if (inHash[i] == bestScore) {
            tmp[i]=inHash[i];
        }
    }
    #copy outHash
    delete outHash;
    for(i in tmp) {
        outHash[i] = tmp[i];
        count++;
    }
    dump(0,"post best",outHash);
    INF("bestScore = "bestScore);
    return bestScore;
}

function p2p_filename(f) {
    return f ~ /^[[:alnum:]]+-[[:alnum:]-]*$/ ;
}

#result in a2
function hash_invert(a1,a2,\
i) {
    delete a2;
    for(i in a1) a2[a1[i]] = i;
}

# result in a1
function hash_copy(a1,a2) {
    delete a1 ; 
    return hash_merge(a1,a2) ;
}
# result in a1
function hash_merge(a1,a2,\
i,total) {
    total=0;
    for(i in a2) {
        if (a2[i] != "")    {
            a1[i] = a2[i];
            total++;
        }
    }
    return total;
}
# result in a1
function hash_add(a1,a2,\
i,total) {
    total = 0;
    for(i in a2) {
        a1[i] += a2[i];
        total++;
    }
    return total;
}

function hash_size(h,\
s,i){
    s = 0 ; 
    for(i in h) s++;
    return 0+ s;
}

function id1(x) {

    #Track stack calls
    g_idstack2[g_idtos] = length(g_indent);

    g_idstack[g_idtos++] = x;
    INF(">Begin " x);
    g_indent="\t"g_indent;
    
}

function id0(x) {
    g_indent=substr(g_indent,2);
    
    INF("<End "g_idstack[--g_idtos]"=[" ( (x!="") ? "=["x"]" : "") "]");

    #check stack
    if (g_idtos > 1 && g_idstack2[g_idtos] != length(g_indent)) {
        ERR("**MISSING STACK CALL dropping from  "g_idstack[g_idtos+1]" to "g_idstack[g_idtos]);
    }
}

function dump(lvl,label,array,\
i,key,n) {
    if (DBG-lvl >= 0)   {
        for(i in array) {
            if (i ~ "^[0-9]+$") {
                key[++n] = i+0;
            } else {
                key[++n] = i;
            }
        }
        asort(key);
        for(i = 1 ; i<= n ; i++ ) {
            DEBUG(" "label":"key[i]"=["array[key[i]]"]");
        }
        if (n == 0 ) {
            DEBUG("  "label":<empty>");
        }
    }
}

function sort_file(f,args,\
tmpf,ret) {
    tmpf=f"."PID;
    if (is_file(f)) {
        if (exec("sort "args" "qa(f)" > "qa(tmpf)" && mv "qa(tmpf)" "qa(f)) == 0) {
            set_permissions(f);
            ret = 1;
        }
    }
    return ret;
}

function set_permissions(shellArg) {
    if (ENVIRON["USER"] != UID ) {
        return system("chown "OVERSIGHT_ID" "shellArg);
    }
    return 0;
}

function capitalise(text,\
i,words,wcount,s,w2) {

    wcount= split(tolower(text),words," ");
    text = "";

    s["in"] = s["of"] = s["and"] = s["it"] = s["or"] = s["not"] = s["a"] = 1;

    for(i = 1 ; i<= wcount ; i++) {
        if (i== 1 || i==wcount || length(words[i]) > 3 || !(words[i] in s) ) {
            w2=toupper(substr(words[i],1,1)) substr(words[i],2);

            # Check for roman numerals
            if (w2 ~ /^[IVX][ivx]+$/ ) {
                w2 = toupper(w2);
            }

            text = text " " w2;
        } else {
            text = text " " words[i];
        }
    }

    return substr(text,2);
}

function is_locked(lock_file,\
pid) {
    if (is_file(lock_file) == 0) return 0;

    pid="";
    if ((getline pid < lock_file) >= 0) {
        close(lock_file);
    }
    if (pid == "" ) {
       DEBUG("Not Locked = "pid);
       return 0;
    } else if (is_dir("/proc/"pid)) {
        if (pid == PID ) {
            DEBUG("Locked by this process "pid);
            return 0;
        } else {
            DEBUG("Locked by another process "pid " not "PID);
            return 1;
        }
    } else {
        DEBUG("Was locked by dead process "pid " not "PID);
        return 0;
    }
}

function lock(lock_file,fastfail,\
attempts,sleep,backoff) {
    attempts=0;
    sleep=10;
    split("10,10,30,30,60,120,300,600,1200,1200",backoff,",");
    for(attempts=1 ; (attempts in backoff) ; attempts++) {
        if (is_locked(lock_file) == 0) {
            print PID > lock_file;
            close(lock_file);
            INF("Locked "lock_file);
            set_permissions(qa(lock_file));
            return 1;
        }
        if (fastfail != 0) break;
        sleep=backoff[attempts];
        WARNING("Failed to get exclusive lock. Retry in "sleep" seconds.");
        system("sleep "sleep);
    }
    ERR("Failed to get exclusive lock");
    return 0;
}

function unlock(lock_file) {
    INF("Unlocked "lock_file);
    system("rm -f -- "qa(lock_file));
}

function monthHash(nameList,sep,hash,\
names,i) {
    split(nameList,names,sep);
    for(i in names) {
        hash[tolower(names[i])] = i+0;
    }
} 

# Convert a glob pattern to a regular exp.
# *=anything,?=single char, <=start of word , >=end of word |=OR
function glob2re(glob) {
    gsub(/[.]/,"\\.",glob);
    gsub(/[*]/,".*",glob);
    gsub(/[?]/,".",glob);
    gsub(/[<]/,"\\<",glob);
    gsub(/ *, */,"|",glob);
    gsub(/[>]/,"\\>",glob);

    #remove empty words
    gsub("^\\|","",glob);
    gsub("\\|$","",glob);
    gsub("\\|\\|","",glob);

    return "("glob")";
}

function csv2re(text) {
    gsub(/ *, */,"|",text);
    return "("text")";
}

function exec(cmd,\
err) {
   #DEBUG("SYSTEM : "substr(cmd,1,100)"...");
   #DEBUG("SYSTEM : [["cmd"]]");
   if ((err=system(cmd)) != 0) {
      ERR("Return code "err" executing "cmd) ;
  }
  return 0+ err;
}

# Extract the dir`name from the path. Note if the file ends in / then the parent is used (for VIDEO_TS)
function dirname(f) {

    #Special case - paths ending in /, the / indicates it is a VIDEO_TS folder and should otherwise be ignored.
    sub(/\/$/,"",f);

    #Relative paths
    if (f !~ "^[/$]" ) {
        f = "./"f;
    }

    #remove filename
    sub(/\/[^\/]+$/,"",f);
    return f;
}

# remove /xxx/../   or /./ or // from a path
function clean_path(f) {
    if (index(f,"../")) {
        while (gsub(/\/[^\/]+\/\.\.\//,"/",f) ) {
            continue;
        }
    }
    while (index(f,"/./")) {
        gsub(/\/\.\//,"/",f);
    }
    while (index(f,"//")) {
        gsub(/\/\/+/,"/",f);
    }
    return f;
}

#Return single quoted file name. Inner quotes are backslash escaped.
function qa(f) {
    gsub(/'/,"'\\''",f);
    return "'"f"'";
}

#return 1 if catalog script is running standalone - ie not on nmt
function scanner_only() {
    if (g_scanner_only == "") {
        g_scanner_only = !is_dir("/opt/sybhttpd/default/oversight");
    }
    return g_scanner_only;
}

function formatDate(line,\
date,nonDate) {
    if (extractDate(line,date,nonDate) == 0) {
        return line;
    }
    line=sprintf("%04d-%02d-%02d",date[1],date[2],date[3]);
    return line;
}


# Input date text
# Output array[1]=y [2]=m [3]=d 
#nonDate[1]=bit before date, nonDate[2]=bit after date
# or empty array
function extractDate(line,date,nonDate,\
y4,d1or2,m1or2,d,m,y,matches,textMonth,s,mword,ret,ss,capture,m2,d2) {

    line = tolower(line);
    textMonth = 0;
    delete date;
    delete nonDate;
    #Extract the date.

    y4=g_year_re;
    ss = SUBSEP;
    s="[-_. /]0*";
    m1or2 = "([1-9]|0[1-9]|10|11|12)";
    d1or2 = "([1-9]|[012][0-9]|30|31)";
    m2 = "(0[1-9]|10|11|12)";
    d2 = "([012][1-9]|30|31)";

    capture=ss"\\1"ss"\\2"ss"\\3"ss; # capture regex subexpressions

    #mword="[[:alpha:]]+";
    mword=tolower("("g_months_short"|"g_months_long")");

    if (split(gensub(g_year_re s m1or2 s d1or2,capture,1,line),matches,ss) == 5) {
        y = matches[2];
        m = matches[3];
        d = matches[4];
    } else if (split(gensub(m1or2 s d1or2 s g_year_re,capture,1,line),matches,ss) == 5) {
        m = matches[2];
        d = matches[3];
        y = matches[4];
    } else if (split(gensub(d1or2 s m1or2 s g_year_re,capture,1,line),matches,ss) == 5) {
        d = matches[2];
        m = matches[3];
        y = matches[4];
    } else if (split(gensub(d1or2 s mword s g_year_re,capture,1,line),matches,ss) == 5) {
        d = matches[2];
        m = matches[3];
        y = matches[4];
        textMonth=1;
    } else if (split(gensub(mword s d1or2 s g_year_re,capture,1,line),matches,ss) == 5) {
        m = matches[2];
        d = matches[3];
        y = matches[4];
        textMonth=1;
    } else if (split(gensub(g_year_re m2 d2,capture,1,line),matches,ss) == 5) {
        y = matches[2];
        m = matches[3];
        d = matches[4];
    }
    if (d && m && y ) {
        nonDate[1] = matches[1];
        nonDate[2] = matches[5];
        date[1]=y+0;
        date[2]=tolower(trim(m));
        date[3]=d+0;

        if ( textMonth == 1 ) {
            DEBUG("date[2]="date[2]);
            if (date[2] in gMonthConvert ) {
                date[2] = 0+gMonthConvert[date[2]];
                DEBUG(m"="date[2]);
                ret = 1;
            }
        } else {
            ret = 1;
        }
    }
    if (ret) {
        DEBUG("Found date ["date[1]"/"date[2]"/"date[3]"] in "line);
    }
    return ret;
}

#replace last roman characters - eg 'fredii' becoumes 'fred2'
#input should be lower case.
function roman_replace(s,\
out) {
    if (match(s,"("g_roman_regex")$")) {
        out = substr(s,1,RSTART-1) g_roman[substr(s,RSTART,RLENGTH)];
        INF("roman_replace = "s);
        INF("roman_replace = "out);
        s = out;
    }
    return s;
}

function indexFrom(str,x,startPos,\
    j) {
    if (startPos<1) startPos=1;
    j=index(substr(str,startPos),x);
    if (j == 0) return 0;
    return j+startPos-1;
}

function rm(x,quiet,quick) {
    removeContent("rm -f -- ",x,quiet,quick);
}
function rmdir(x,quiet,quick) {
    removeContent("rmdir -- ",x,quiet,quick);
}
function removeContent(cmd,x,quiet,quick) {

    if (changeable(x) == 0) return 1;

    if (!quiet) {
        INF("Deleting "x);
    }
    cmd=cmd qa(x)" 2>/dev/null ";
    if (quick) {
        return exec("(" cmd ") & ");
    } else {
        return exec("(" cmd " || true ) ");
    } 
}

function isDvdDir(f) {
    return substr(f,length(f)) == "/";
}

function touch(x) {
    return system("touch "qa(x));
}

function touch_and_move(x,y) {
    return system("touch "qa(x)" ; mv "qa(x)" "qa(y));
}
function gsub_hash(reg,val,h,\
i) {
    for(i in h) {
        gsub(reg,val,h[i]);
    }
}

function touch_parents(f) {
    do {
        f = dirname(f);
        INF("touch "f);
        if (touch(f) != 0) break;
    } while(f != "" && f != "/" && f != ".");
}

# split array at unescaped char
function split_list(list,char,out,\
split_suffix) {
    # Check escape characters - if present add SUBSEP to all dividers
    if (index(list,"\\"char)) {
        # convert normal , to ,SUBSEP and split on ,SUBSEP
        gsub("[^\\]["char"]","&"SUBSEP,list);
        split_suffix = SUBSEP;
    }
    return split(list,out,char split_suffix);
}

# Apply sequence of regex to a string.
# e/REGEX = extract the regex. - if not blank
# s/REGEX/VALUE = substitute regex - REGEX must be present if not blank

# there is a bug splitting values. The code tries to preserve for escaped characters eg \, but not bracket sequence [,]

function apply_edits(text,plist,verbose,\
i,num,patterns,matched,pinfo,ret,prev,sep,lcop) {

    ret = text;
    #DEBUG("using "plist);

    # Split at unescaped forward slashes
    num = split_list(plist,",",patterns);

    for(i = 1 ; i <= num ; i++ ) {

        prev =ret;

        # Split at second character.
        sep = "/";
        if (index(patterns[i],sep) != 1) {
            sep = substr(patterns[i],2,1);
        }
        split_list(patterns[i],sep,pinfo);

        if (verbose) {
            DEBUG("apply_edits["text"] split="sep);
            dump(0,"apply_edits",pinfo);
        }

        matched = 0;
        lcop = tolower(pinfo[1]);
        if (lcop == "s") { # substitute

            if (index(tolower(pinfo[4]),"g")) { # global
                matched = gsub(pinfo[2],pinfo[3],ret);
            } else if (pinfo[4] == "" ) {
                matched = sub(pinfo[2],pinfo[3],ret);
            } else {
                ERR("apply_edits: Bad value ["patterns[i]"]");
            }
            if (verbose) DEBUG(pinfo[4]"sub("pinfo[2]","pinfo[3]","prev")=["matched"|"ret"]");

        } else if (lcop == "e") { # extract

            if (pinfo[3] != "" ) {
                ERR("apply_edits: Bad value ["patterns[i]"]");
            } else if (match(ret,pinfo[2])) {
                matched = 1;
                ret = substr(ret,RSTART,RLENGTH);
            }
            if (verbose) DEBUG(pinfo[4]"extract match("prev","pinfo[2]")=["matched"|"ret"]");

        } else if (lcop == "t") { # following text must occur - faster than regex - matches t/dddd/

            if (pinfo[3] != "" ) {
                ERR("apply_edits: Bad value ["patterns[i]"]");
            } else if (index(ret,pinfo[2])) {
                matched = 1;
            }
            if (verbose) DEBUG("text "pinfo[2]" = "matched);

        } else if (pinfo[1] == "" || pinfo[1] == "r" ) { # matches /dddd/

            if (pinfo[3] != "" ) {
                ERR("apply_edits: Bad value ["patterns[i]"]");
            } else if (match(ret,pinfo[2])) {
                matched = 1;
            }
            if (verbose) DEBUG("match "pinfo[2]" = "matched);
        }
        # If there was no match, and a lower case operation was used then clear the entire result.
        #ie if s/ or e/ used then the regex must be present
        if (!matched && pinfo[1] == lcop) {
            ret = "";
            break;
        }
    }
    #DEBUG("apply_edits:["text"]=["ret"]");
    return ret;
}

# Get first matching sub exression of a regular expression
# Bug. if the sub expression is empty then this looks the same as no matches.
# IN text - text to match against
# IN regex - regular expression
# IN n = the number of the sub expreassion (default 1)
# Using split rather then gensub(/.*(..).*/ avoids regex backtracking which is very slow.
function subexp(text,regex,n,\
matches,ret) {

    if (length(n) == 0 ) {
        # default if ( matchon first else match on all regex (n=0)
        if (index(regex,"(")) {
            n = 1;
        } else {
            n = 0;
        }
    }

    if (split(gensub(regex,SUBSEP"\\"n SUBSEP,1,text),matches,SUBSEP) == 3) {
        ret = matches[2];
    }
    return ret;
}

# Split a line at regex boundaries.
# used by get_regex_counts
# IN s - line to split
# IN regex - regular expression
# OUT parts - index 1,2,3.. values text,match1,text,match2,...
# RET number of parts.
function chop(s_in,regex,parts,\
flag,i,s) {
    #first find split text that doesnt occur in the string.
    #flag="=#z@~";
    flag=SUBSEP;

    # insert the split text around the regex boundaries

    s = s_in;

    if (gsub(regex,flag "&" flag , s )) {
        # now split at boundaries.
        i = split(s,parts,flag);
        if (i % 2 == 0) ERR("Even chop of ["s"] by ["flag"]");
    } else {
        i = 1;
        delete parts;
        parts[1] = s_in;
    }
    return i+0;
}




# Find all occurences of a regular expression within a string, and return in an array.
# IN Line to match against.
# IN regex to match with.
# IN max = max occurences (0 = all)
# OUT matches is updated with (text=>num occurrences)
# RET total number of occurences.
function get_regex_counts(line,regex,max,matches) {
    return 0+get_regex_count_or_pos("c",line,regex,max,matches);
}
# Find all occurences of a regular expression within a string, and return in an array.
# IN mode : c=count matches  p=return match positions.
# IN Line to match against.
# IN regex to match with.
# IN max = max occurences (0 = all)
# OUT rtext is updated with (order=>match text)
# OUT rstart  is updated with (order -> start pos)
# RET total number of occurences.
function get_regex_pos(line,regex,max,rtext,rstart) {
    return 0+get_regex_count_or_pos("p",line,regex,max,rtext,rstart);
}


# Find all occurences of a regular expression within a string, and return in an array.
# IN mode : c=count matches  p=return match positions.
# IN Line to match against.
# IN regex to match with.
# IN max = max occurences (0 = all)
# mode=c:
# OUT rtext is updated with (mode=c:text=>num occurrences mode=p:order=>match text)
# mode=p:
# OUT rtext is updated with (order=>match text)
# OUT rstart  is updated with (order -> start pos)
# OUT total number of occurences.
function get_regex_count_or_pos(mode,line,regex,max,rtext,rstart,\
count,fcount,i,parts,start) {
    count =0 ;

    delete rtext;
    delete rstart;

    fcount = chop(line,regex,parts);

    start=1;
    max = max+0;
    if (mode == "c") {
        for(i=2 ; i-fcount <= 0 ; i += 2 ) {
            count++;
            rtext[parts[i]]++;
            if (max > 0 && count >= max ) {
                break;
            }
        }
    } else {
        for(i=2 ; i-fcount <= 0 ; i += 2 ) {
            count++;
            rtext[count] = parts[i];

            start += length(parts[i-1]);
            rstart[count] = start;
            start += length(parts[i]);
            if (max > 0 && count >= max ) {
                break;
            }
        }
    }

    dump(3,"get_regex_count_or_pos:"mode,rtext);

    return 0+count;
}


# Levenshtein or Edit distance - metric of how similar two strings are.
# http://www.merriampark.com/ld.htm
# http://www.merriampark.com/ldcpp.htm

#added threshold to short circuit
function edit_dist(source,target,threshold,\
m,n,i,j,matrix,cell,left,above,diag,s_i,t_j,ss,tt) {


    #n = length(source);
    #m = length(target);
    n = split(source,ss,"");
    m = split(target,tt,"");
    if (n == 0) {
        return m;
    }
    if (m == 0) {
        return n;
    }

    for (i = 0; i <= n; i++) {
        matrix[i,0]=i;
    }

    for (j = 0; j <= m; j++) {
        matrix[0,j]=j;
    }

    if (threshold == 0) {
        threshold = m+n;
    }

    for (i = 1; i <= n; i++) {

        #s_i = substr(source,i,1);
        s_i = ss[i];

        for (j = 1; j <= m; j++) {

            #t_j = substr(target,j,1);
            t_j = tt[j];

            diag = matrix[i-1,j-1] ;

            if (s_i == t_j) {
                cell = diag;
            } else {
                above = matrix[i-1,j] + 1;
                left = matrix[i,j-1] + 1;
                diag++;

                cell = diag;
                if (left < cell) cell = left;
                if (above < cell) cell = above;

                if (cell > threshold && m-i == n-j ) {
                    #INF("abort edit_dist:["source"] ["target"] = " cell);
                    return cell;
                }
            }

            # Not really interested in transpositions for this application but c source is 
            # // Step 6A: Cover transposition, in addition to deletion,
            # // insertion and substitution. This step is taken from:
            # // Berghel, Hal ; Roach, David : "An Extension of Ukkonen's 
            # // Enhanced Dynamic Programming ASM Algorithm"
            # // (http://www.acm.org/~hlb/publications/asm/asm.html)

            # if (i>2 && j>2) {
            #   int trans=matrix[i-2][j-2]+1;
            #   if (source[i-2]!=t_j) trans++;
            #   if (s_i!=target[j-2]) trans++;
            #   if (cell>trans) cell=trans;
            # }

            matrix[i,j]=cell;
        }
    }

    INF("edit distance:["source"] ["target"] = " matrix[n,m]);
    return matrix[n,m];
}

# return edit distance / length of string 
# 0 = same 1=very different >1 = one string was blank - very very different
# e=4 s1=4 s2=5 = 1 
# e=4 s1=40 s2=40 = 0.1 
# e=99 s1=99 s2=99  1
function similar(s1,s2,\
    n,m,e,min,ret) {
    s1 = norm_title(remove_brackets(s1));
    s2 = norm_title(remove_brackets(s2));

    m = length(s1);
    n = length(s2);
    if (n < m ) min  = n; else min = m;

    if (min == 0 ) min = 1;

    e = edit_dist(s1,s2);
    ret = e / min ;
    INF("similar:" ret);
    return ret;
}

function get_page_size(url,\
f) {
    f = getUrl(url,".html",0);
    return get_file_size(f);
}

function get_file_size(f,\
line,code,total) {
    total = 0;

    if (f) {
        while ((code = (getline line < f )) > 0 ) {
            total += length(line);
        }
        if (code == 0) {
            close(f);
        }
    }
    DEBUG("size["f"] = "total" bytes");
    return total;
}
    
# this corrupts a title but makes it easier to match on other similar titles.
function norm_title(t,\
keep_the) {
    if (!keep_the) {
        sub("^"g_lang_articles" ","",t);
        sub(" "g_lang_articles"$","",t);
    }
    gsub(/[&]/,"and",t);
    gsub(/'/,"",t);

    # Clean title only removes . and _ if it has no spaces.
    # For similar title matching to work we remove all punctuation
    gsub(g_punc[0]," ",t);

    # Fix for Spider-man vs spiderman
    if (index(t,"-")) gsub(/-/,"",t);

    gsub(/  +/," ",t);

    return tolower(trim(t));
}

#Collapse abbreviations. Only if dot is sandwiched between single letters.
#c.s.i.miami => csi.miami
#this has to be done in two stages otherwise the collapsing prevents the next match. 
# eg C.S.I. -> CS.I but now CS . I will not match - and dots after words must be preserved as 
# they could represent spaces in scne names.
function collapse_dotted_abbr(t,\
t2,changed) {
    changed=0;
    if (index(t,".")) {
        do {
            t2=gensub(/\<([[:alpha:]])\.([[:alpha:]])\>/,"\\1@@\\2","g",t);
            if (t2 ==t) {
                if (changed) gsub(/@@/,"",t);
                break;
            }
            t=t2;
            changed=1;
        } while(1);

#        while (match(t,"\\<[[:alpha:]]\\>[.]\\<[[:alpha:]]\\>")) {
#            t = substr(t,1,RSTART) "@@" substr(t,RSTART+2);
#        }
#        gsub(/@@/,"",t);
    }
    return t;
}

# This is used in tv comparison functions for qualified matches so it must not remove any country
# or year designation
# deep - if set then [] and {} are removed from text too
function clean_title(t,deep,\
punc,last) {

    #ALL# gsub(/[&]/," and ",t);
    if (index(t,"amp")) gsub(/[&]amp;/,"\\&",t);

    last = substr(t,length(t));
    if (index("-_ .",last)) {
        sub(/[-_ .]+$/,"",t);
    }

    t = collapse_dotted_abbr(t);

    punc = g_punc[deep+0];
    if (index(t," ") ) {
        # If there is a space then also preserve . and _ . These are often used as spaces
        # but if there is aready a space , assume they are significant.

        # first remove any trailing dot
        sub(punc"$","",t);

        #Now modify regex to keep any internal dots.
        if (sub(/-\]/,"_.-]",punc) != 1) {
            ERR("Fix punctuation string");
        }
    }
    gsub(punc," ",t);

    if (index(t,"  ")) gsub(/ +/," ",t);
    return capitalise(t);
}
