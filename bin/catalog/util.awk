
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
    if (f=="") {
        ERR("hasContent:blank file?");
    } else if (system("test -e "qa(f)" && ! test -f "qa(f)) == 0) {
        ERR("hasContent:not file? ["f"]");
    } else {
        err = (getline tmp < f );
        if (err != -1) close(f);
    }
    return (err == 1 );
}

function isnmt() {
    return ENVIRON["FAMILY"] == "nmt";
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
    if(LI)INF("Clean tmp files");
    exec("rm -f -- "qa(CAPTURE_PREFIX JOBID) ".* 2>/dev/null");
}
function DEBUG(x) {
        
    if ( g_catalog_log_level < 0 ) {
        timestamp(-1,x);
    }

}

function rs_push(x) {
    g_rs[++g_rs_top] = RS;
    RS = x;
}
function rs_pop() {
    RS = g_rs[g_rs_top--];
}

function DIV0(x) {
    if(LI)INF("\n\t\t@@@@@@@\t"x"\t@@@@@@@@@@\n");
}
function DIV(x) {
    if(LI)INF("\t===\t"x"\t===");
}

function INF(x) {
    timestamp(1,x);
}
function WARNING(x) {
    timestamp(2,x);
}
function ERR(x) {
    timestamp(3,x);
}
function DETAIL(x) {
    timestamp(0,x);
}

function timestamp(lvl,x,\
new_str,gap) {
    if (lvl >= g_catalog_log_level ) {

        if (!(1 in g_log_labels)) {

            g_log_labels[-1] = "[DEBUG]  "LOG_TAG" ";
            g_log_labels[0]  = "[DETAIL] "LOG_TAG" ";
            g_log_labels[1]  = "[INFO]   "LOG_TAG" ";
            g_log_labels[2]  = "[WARN]   "LOG_TAG" ";
            g_log_labels[3]  = "[ERR]    "LOG_TAG" ";
        }

        if (g_api_tvdb && index(x,g_api_tvdb) ) gsub(g_api_tvdb,"-t-",x);
        if (g_api_tmdb && index(x,g_api_tmdb) ) gsub(g_api_tmdb,"-m-",x);
        if (g_api_rage && index(x,g_api_rage) ) gsub(g_api_rage,"-r-",x);
        if (g_api_bing && index(x,g_api_bing) ) gsub(g_api_bing,"-b-",x);

        if (index(x,"app.i") ) {
            sub("app.i[[:alnum:]/?=&]+","movieapi",x);
        }
        if (index(x,"d=") ) {
            sub("password.?=([^,]+)","password=***",x);
            sub("pwd=([^,]+)","pwd=xxx",x);
            sub("passwd=([^,]+)","passwd=***",x);
        }

        if (systime() != g_last_ts) {

            new_str=strftime("%H:%M:%S : ",systime());

            gap = systime() - g_last_ts;
            if (!g_catalog_log_level && !g_ignore_log_gap && g_last_ts && gap > 30) {
                print g_log_labels[2]new_str"going slow? "gap" seconds elapsed";
            }
            g_ignore_log_gap = 0;

            g_last_ts=systime();
            g_last_ts_str=new_str;
            fflush();
        }

        print g_log_labels[lvl] g_last_ts_str g_indent x;
    }
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
    sub(/[0-9]{5}/,"",text);
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
    if(LD)DETAIL("bestScore = "bestScore);
    return bestScore;
}

function p2p_filename(f) {
    return f ~ /^[[:alnum:]]+-[[:alnum:]-]*$/ ;
}

#result in a2
function hash_invert(a1,a2,\
i,tmp) {
    for(i in a1) tmp[a1[i]] = i;
    hash_copy(a2,tmp);
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
function hash_append(a1,a2,\
i,total) {
    total = hash_size(a1);
    for(i in a2) {
        a1[++total] += a2[i];
    }
    return total;
}

function hash_size(h,\
s,i){
    s = 0 ; 
    for(i in h) s++;
    return 0+ s;
}

function hash_val_sub(h,old,new,\
i) {
    for(i in h) if ( h[i] == old ) h[i] = new;
}

function hash_val_del(h,old,\
i) {
    for(i in h) if ( h[i] == old ) delete h[i];
}

function id1(x) {

    if (g_catalog_log_level <= 0) {
        #Track stack calls
        g_idstack2[g_idtos] = length(g_indent);

        g_idstack[g_idtos++] = x;
        if(LD)DETAIL(">Begin " x);
        g_indent="\t"g_indent;
    }
    
}

function id0(x) {
    if (g_catalog_log_level <= 0) {
        g_indent=substr(g_indent,2);
    
        if(LD)DETAIL("<End "g_idstack[--g_idtos]"=[" ( (x!="") ? "=["x"]" : "") "]");

        #check stack
        if (g_idtos > 1 && g_idstack2[g_idtos] != length(g_indent)) {
            ERR("**MISSING STACK CALL dropping from  "g_idstack[g_idtos+1]" to "g_idstack[g_idtos]);
        }
    }
}

function dump(lvl,label,array,\
i,key,n) {
    n = asorti(array,key);
    if (lvl >= g_catalog_log_level) {
        for(i = 1 ; i<= n ; i++ ) {
            timestamp(lvl,label" : "key[i]" =["array[key[i]]"]");
        }
        if (n == 0 ) {
            timestamp(lvl,label":<empty>");
        }
    }
}

function join(a,sep,\
i,s,n) {
    n = hash_size(a);

    s = a[1];
    for(i = 2 ; i<= n ; i++ ){
        s = s sep a[i];
    }
    return s;
}


function sort_file(f_in,args,f_out,\
tmpf,ret,cmd) {
    if (is_file(f_in)) {
        if (f_out == "" || f_out == f_in) {
            f_out = f_in;
            tmpf=f_in"."PID;
            cmd = "sort "args" "qa(f_in)" > "qa(tmpf)" && mv "qa(tmpf)" "qa(f_in);
        } else {
            cmd = "sort "args" "qa(f_in)" > "qa(f_out);
        }
            
        if (exec(cmd) == 0) {
            set_permissions(f_out);
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

function is_alive(pid,\
code,f,line) {
    # Cant use is_file as that spawns a process to avoid fatal error if file is a directory
    f="/proc/"pid"/cmdline";
    code = (getline line < f );
    if (code >= 0) {
        close(f);
        return 1;
    }
    return 0;
}

function is_locked(lock_file,\
pid) {
    if (is_file(lock_file) == 0) return 0;

    pid="";
    if ((getline pid < lock_file) >= 0) {
        close(lock_file);
    }
    if (pid == "" ) {
       if(LG)DEBUG("Not Locked = "pid);
       return 0;
    } else if (is_alive(pid)) {
        if (pid == PID ) {
            if(LG)DEBUG("Locked by this process "pid);
            return 0;
        } else {
            if(LG)DEBUG("Locked by another process "pid " not "PID);
            return 1;
        }
    } else {
        if(LG)DEBUG("Was locked by dead process "pid " not "PID);
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
            if(LD)DETAIL("Locked "lock_file);
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
    if(LD)DETAIL("Unlocked "lock_file);
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

function exec(cmd,verbose,quiet,\
err) {
   #if(LG)DEBUG("SYSTEM : "substr(cmd,1,100)"...");
   if (verbose) if(LG)DEBUG("SYSTEM : [ "cmd" ]");
   g_ignore_log_gap=1;
   if ((err=system(cmd)) != 0) {
      if(!quiet) {
          ERR("Return code "err" executing "cmd) ;
      }
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
            if(LG)DEBUG("date[2]="date[2]);
            if (date[2] in gMonthConvert ) {
                date[2] = 0+gMonthConvert[date[2]];
                if(LG)DEBUG(m"="date[2]);
                ret = 1;
            }
        } else {
            ret = 1;
        }
    }
    if (ret) {
        if(LG)DEBUG("Found date ["date[1]"/"date[2]"/"date[3]"] in "line);
    }
    return ret;
}

#replace last roman characters - eg 'fredii' becoumes 'fred2'
#input should be lower case.
function roman_replace(s,\
out) {
    if (match(s,"("g_roman_regex")$")) {
        out = substr(s,1,RSTART-1) g_roman[substr(s,RSTART,RLENGTH)];
        if(LD)DETAIL("roman_replace = "s);
        if(LD)DETAIL("roman_replace = "out);
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
        if(LD)DETAIL("Deleting "x);
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
        if(LD)DETAIL("touch "f);
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
    #if(LG)DEBUG("using "plist);

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
            if(LG)DEBUG("apply_edits["text"] split="sep);
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
            if (verbose) if(LG)DEBUG(pinfo[4]"sub("pinfo[2]","pinfo[3]","prev")=["matched"|"ret"]");

        } else if (lcop == "e") { # extract

            if (pinfo[3] != "" ) {
                ERR("apply_edits: Bad value ["patterns[i]"]");
            } else if (match(ret,pinfo[2])) {
                matched = 1;
                ret = substr(ret,RSTART,RLENGTH);
            }
            if (verbose) if(LG)DEBUG(pinfo[4]"extract match("prev","pinfo[2]")=["matched"|"ret"]");

        } else if (lcop == "t") { # following text must occur - faster than regex - matches t/dddd/

            if (pinfo[3] != "" ) {
                ERR("apply_edits: Bad value ["patterns[i]"]");
            } else if (index(ret,pinfo[2])) {
                matched = 1;
            }
            if (verbose) if(LG)DEBUG("text "pinfo[2]" = "matched);

        } else if (pinfo[1] == "" || pinfo[1] == "r" ) { # matches /dddd/

            if (pinfo[3] != "" ) {
                ERR("apply_edits: Bad value ["patterns[i]"]");
            } else if (match(ret,pinfo[2])) {
                matched = 1;
            }
            if (verbose) if(LG)DEBUG("match "pinfo[2]" = "matched);
        }
        # If there was no match, and a lower case operation was used then clear the entire result.
        #ie if s/ or e/ used then the regex must be present
        if (!matched && pinfo[1] == lcop) {
            ret = "";
            break;
        }
    }
    #if(LG)DEBUG("apply_edits:["text"]=["ret"]");
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

# This emulates gawk 4 patsplit() 
# the text that matches the regex is put in array
# the text that follows the regex is put in seps.
# The initial text before the first match is put in seps[0]
function ovs_patsplit(text,array,regex,seps,\
i,n,expand,parts,ret) {
    #return patsplit(text,array,regex,seps);

    # eg -1-SEP-2-SEP2-3- => -1-,SEP,-2-,SEP2,-3-
    expand = gensub(regex,SUBSEP"&"SUBSEP,"g",text);

    # eg 1=-1- 2=SEP 3=-2- 4=SEP2 5=-3-
    n=split(expand,parts,SUBSEP);

    ret = 0;
    i=0;

    #eg seps[0]=-1- -2- -4- array=[1..]=SEP SEP2
    for (i = 1 ; i < n ; i+= 2) {
        seps[ret] = parts[i];
        array[++ret] = parts[i+1];
    }
    seps[ret] = parts[n];
    return ret;
}

# Find all occurences of a regular expression within a string, and return in an array.
# IN Line to match against.
# IN regex to match with.
# IN max = max occurences (0 = all)
# OUT matches is updated with (text=>num occurrences)
# RET total number of occurences.
function get_regex_counts(line,regex,max,matches,\
i,n,pieces) {
    n = ovs_patsplit(line,pieces,regex);
    delete matches;
    if (max == 0 || max > n) max = n;
    for(i=1 ; i<= max ; i++ ) {
        matches[pieces[i]]++;
    }
    return max;
}

# PAt split but only return first few results.
function patsplitn(line,regex,max,rtext,\
i,count,tmp) {
    if (max == 0) {
        count = ovs_patsplit(line,rtext,regex);
    } else {
        # copy max elements
        count = ovs_patsplit(line,tmp,regex);
        if (max > count) max = count;
        for(i = 1 ; i<= max ; i++ ) {
            rtext[i] = tmp[i];
        }
    }
    return count;
}

# Find all occurences of a regular expression within a string, and return in an array.
# IN mode : c=count matches  p=return match positions.
# IN Line to match against.
# IN regex to match with.
# IN max = max occurences (0 = all)
# OUT rtext is updated with (order=>match text)
# OUT rstart  is updated with (order -> start pos)
# RET total number of occurences.
function get_regex_pos(line,regex,max,rtext,rstart,\
count,i,start,seps) {

    delete rstart;

    count = ovs_patsplit(line,rtext,regex,seps);

    start=1;

    if (max == 0 || max > count) max = count;

    for(i = 1 ; i <= max ; i++ ) {

        start += length(seps[i-1]);
        rstart[i] = start;
        start += length(rtext[i]);
    }

    return count;
}


# Levenshtein or Edit distance - metric of how similar two strings are.
# http://www.merriampark.com/ld.htm
# http://www.merriampark.com/ldcpp.htm

#added threshold to short circuit
function edit_dist(source,target,threshold,\
m,n,i,j,matrix,cell,left,above,diag,s_i,t_j,ss,tt,early_fail) {


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
        threshold = 2;
    }

    for (i = 1; i <= n; i++) {

        #s_i = substr(source,i,1);
        s_i = ss[i];

        early_fail=1;
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
                    #if(LI)INF("abort edit_dist:["source"] ["target"] = " cell);
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
            if (cell <= threshold) early_fail = 0;
        }
        if (early_fail) {
            INF("Abort "n","m" at "i","j);
            matrix[n,m] = 9999;
            break;
        }
    }

    if(LD)DETAIL("edit distance:["source"] ["target"] = " matrix[n,m]);
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
    if(LD)DETAIL("similar:" ret);
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
    if(LG)DEBUG("size["f"] = "total" bytes");
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

function left(str,n) {
    if (length(str) > n ) {
        str = substr(str,length(str)-n+1);
    }
    return str;
}

# This is used in tv comparison functions for qualified matches so it must not remove any country
# or year designation
# deep - if set then [] and {} are removed from text too
function clean_title(t,deep,\
punc,last) {

    if (index(t,"-")) gsub(/-/," ",t);

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

function log_bigstring(label,body,sz,\
l) {
    l = length(body) - sz; 
    if(LG)DEBUG( label " "length(body)" bytes ["substr(body,1,sz)"..."(l>1 ? substr(body,l)"]" : "" ) );
}

