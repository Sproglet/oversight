
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

#--------------------------------------------------------------------
# Convinience function. Create a new file to capture some information.
# At the end capture files are deleted.
#--------------------------------------------------------------------
function new_capture_file(label,\
    fname) {
    # fname = CAPTURE_PREFIX JOBID  "." CAPTURE_COUNT "__" label; # ALL
    fname = CAPTURE_PREFIX PID  "." CAPTURE_COUNT "__" label;
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

function trim(str) {
    sub(/^[- ]+/,"",str);
    sub(/[- ]+$/,"",str);
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

