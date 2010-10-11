
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
function is_file(f,\
tmp,err) {
    err = -1;
    if (f) {
        err = (getline tmp < f );
        if (err == -1) {
            #DEBUG("["f"] doesnt exist");
        } else {
            close(f);
        }
    }
    return (err != -1 );
}
function is_empty(d) {
    return system("ls -1A "qa(d)" | grep -q .") != 0;
}
function is_dir(f) {
    return 0+ test("-d",f"/.");
}
function is_file_or_folder(f,\
r) {
    r = (is_file(f) || is_dir(f));
    if (r == 0) WARNING(f" is neither file or folder");
    return r;
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

# Remove spaces and non alphanum
function trimAll(str) {
    sub(g_punc[0]"$","",str);
    sub("^"g_punc[0],"",str);
    return str;
}

function trim(str,\
i,j) {
    sub(/^[	 ]+/,"",str);

    # trim trailing space 
    # this was using sub(/ +$/,"",str) 
    # but if the string has a lot of spaces this can cause a lot of backtracking
    # eg [one sp sp sp  ... sp sp two sp ]
    #
    j = i = length(str);
    while (i >= 1 && index(" \t\n\r",substr(str,i,1))) {
        i--;
    }

    if(i != j) {
        str = substr(str,1,i);
    }
    return str;
}

function apply(text) {
    gsub(/[^A-Fa-f0-9]/,"",text);
    return text;
}
#baseN - return a number base n. All output bytes are offset by 128 so the characters will not 
#clash with seperators and other ascii characters.

function basen(i,n,\
out) {
    if (g_chr[32] == "" ) {
        decode_init();
    }
    while(i+0 > 0) {
        out = g_chr[(i%n)+128] out;
        i = int(i/n);
    }
    if (out == "") out=g_chr(128);
    return out;
}
#base10 - convert a base n number back to base 10. All input bytes are offset by 128
#so the characters will not clash with seperators and other ascii characters.
function base10(input,n,\
out,digits,ln,i) {
    if (g_chr[32] == "" ) {
        decode_init();
    }
    ln = split(input,digits,"");
    for(i = 1 ; i <= ln ; i++ ) {
        out = out *n + (g_ascii[digits[i]]-128);
    }
    if (out == "") out=0;
    return out+0;
}

function firstIndex(inHash,\
i) {
    for (i in inHash) return i;
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

#result in a2
function hash_invert(a1,a2,\
i) {
    delete a2;
    for(i in a1) a2[a1[i]] = i;
}

# result in a1
function hash_copy(a1,a2) {
    delete a1 ; hash_merge(a1,a2) ;
}
# result in a1
function hash_merge(a1,a2,\
i) {
    for(i in a2) a1[i] = a2[i];
}
# result in a1
function hash_add(a1,a2,\
i) {
    for(i in a2) a1[i] += a2[i];
}
function hash_size(h,\
s,i){
    s = 0 ; 
    for(i in h) s++;
    return 0+ s;
}

function id1(x) {
    g_idstack[g_idtos++] = x;
    INF(">Begin " x);
    g_indent="\t"g_indent;
}

function id0(x) {
    g_indent=substr(g_indent,2);
    
    INF("<End "g_idstack[--g_idtos]"=[" ( (x!="") ? "=["x"]" : "") "]");
}

function dump(lvl,label,array,\
i,c) {
    if (DBG-lvl >= 0)   {
        for(i in array) {
            DEBUG(" "label":"i"=["array[i]"]");
            c++;
        }
        if (c == 0 ) {
            DEBUG("  "label":<empty>");
        }
    }
}

function sort_file(f,args,\
tmpf) {
    tmpf=f"."PID;
    if (exec("sort  "args" "qa(f)" > "qa(tmpf)" && mv "qa(tmpf)" "qa(f)) == 0) {
        set_permissions(f);
    }
}

function set_permissions(shellArg) {
    if (ENVIRON["USER"] != UID ) {
        return system("chown "OVERSIGHT_ID" "shellArg);
    }
    return 0;
}

function capitalise(text,\
i,rtext,rstart,words,wcount) {

    wcount= split(tolower(text),words," ");
    text = "";

    for(i = 1 ; i<= wcount ; i++) {
        text = text " " toupper(substr(words[i],1,1)) substr(words[i],2);
    }

    ## Uppercase roman
    if (get_regex_pos(text,"\\<[IVX][ivx]+\\>",0,rtext,rstart)) {
        for(i in rtext) {
            text = substr(text,1,rstart[i]-1) toupper(rtext[i]) substr(text,rstart[i]+length(rtext[i]));
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
    split("10,10,20,30,60,120,300,300,300,300,300,600,600,600,600,600,1200",backoff,",");
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
   DEBUG("SYSTEM : [["cmd"]]");
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
y4,d1,d2,d1or2,m1,m2,m1or2,d,m,y,datePart,textMonth,s,mword) {

    line = tolower(line);
    textMonth = 0;
    delete date;
    delete nonDate;
    #Extract the date.
    #because awk doesnt capture submatches we have to do this a slightly painful way.
    y4=g_year_re;
    m2="(0[1-9]|1[012])";
    m1=d1="[1-9]";
    d2="([012][0-9]|3[01])";
    s="[-_. /]0*";
    m1or2 = "(" m1 "|" m2 ")";
    d1or2 = "(" d1 "|" d2 ")";
    #mword="[A-Za-z]+";
    mword=tolower("("g_months_short"|"g_months_long")");

    d = m = y = 0;
    if  (match(line,y4 s m1or2 s d1or2)) {

        y=1 ; m = 2 ; d=3;

    } else if(match(line,m1or2 s d1or2 s y4)) { #us match before plain eu match

        m=1 ; d = 2 ; y=3;

    } else if(match(line,d1or2 s m1or2 s y4)) { #eu

        d=1 ; m = 2 ; y=3;

    } else if(match(line,d1or2 s mword s y4)) { 

        d=1 ; m = 2 ; y=3;
        textMonth = 1;

    } else if(match(line,mword s d1or2 s y4)) {
        m=1 ; d = 2 ; y=3;
        textMonth = 1;

    } else {

        return 0;
    }
    datePart = substr(line,RSTART,RLENGTH);

    nonDate[1]=substr(line,1,RSTART-1);
    nonDate[2]=substr(line,RSTART+RLENGTH);

    split(datePart,date,s);
    #DEBUG("Date1 ["date[1]"/"date[2]"/"date[3]"] in "line);
    d = date[d];
    m = date[m];
    y = date[y];

    date[1]=y;
    date[2]=tolower(trim(m));
    date[3]=d;
    #DEBUG("Date2 ["date[1]"/"date[2]"/"date[3]"] in "line);

    if ( textMonth == 1 ) {
        DEBUG("date[2]="date[2]);
        if (date[2] in gMonthConvert ) {
            date[2] = gMonthConvert[date[2]];
            DEBUG(m"="date[2]);
        } else {
            return 0;
        }
    }
    #DEBUG("Date3 ["date[1]"/"date[2]"/"date[3]"] in "line);
    date[1] += 0;
    date[2] = 0 + date[2];
    date[3] += 0;
    DEBUG("Found ["date[1]"/"date[2]"/"date[3]"] in "line);
    return 1;
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

    if (quiet) {
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

function touch_and_move(x,y) {
    system("touch "qa(x)" ; mv "qa(x)" "qa(y));
}
function gsub_hash(reg,val,h,\
i) {
    for(i in h) {
        gsub(reg,val,h[i]);
    }
}

# Apply sequence of regex to a string.
# e/REGEX = extract the regex. - if not blank
# s/REGEX/VALUE = substitute regex - REGEX must be present if not blank

function apply_edits(text,plist,verbose,\
i,num,patterns,matched,pinfo,ret,prev) {

    ret = text;
    #DEBUG("using "plist);

    gsub(/\\,/,"@comma@",plist)
    gsub(/\\\//,"@backslash@",plist)

    num = split(plist,patterns,",");

    gsub_hash("@comma@",",",patterns);

    for(i = 1 ; i <= num ; i++ ) {

        prev =ret;

        split(patterns[i],pinfo,"/");

        gsub_hash("@backslash@","/",pinfo);

        if (verbose) {
            DEBUG("apply_edits["text"]");
            dump(0,"apply_edits",pinfo);
        }

        matched = 0;
        if (tolower(pinfo[1]) == "s") { # substitute

            if (index(tolower(pinfo[4]),"g")) { # global
                matched = gsub(pinfo[2],pinfo[3],ret);
            } else {
                matched = sub(pinfo[2],pinfo[3],ret);
            }
            if (verbose) DEBUG(pinfo[4]"sub("pinfo[2]","pinfo[3]","prev")=["matched"|"ret"]");

        } else if (tolower(pinfo[1]) == "e") { # extract

            if (match(ret,pinfo[2])) {
                matched = 1;
                ret = substr(ret,RSTART,RLENGTH);
            }
            if (verbose) DEBUG(pinfo[4]"extract match("prev","pinfo[2]")=["matched"|"ret"]");
        }
        # If there was no match, and a lower case operation was used then clear the entire result.
        #ie if s/ or e/ used then the regex must be present
        if (!matched && pinfo[1] == tolower(pinfo[1])) {
            ret = "";
            break;
        }
    }
    #DEBUG("apply_edits:["text"]=["ret"]");
    return ret;
}

