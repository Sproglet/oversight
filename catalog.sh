#!/bin/sh
#! $Id$
#!This is a compacted file. If looking for the source see catalog.sh.full
#!Compressed with
#!sed -r 's/^[  ]+/ /;/^ #/ {s/.*//};/^#[^!]/ {s/.*//};/^$/ {s/.*//}' catalog.sh.full > catalog.sh
#!note [    ] is [<space><tab>]
#!If not compressed then awk will report "bad address" error on some platforms.
#



#
#
set -u  #Abort with unset variables
set -e  #Abort with any error can be suppressed locally using EITHER cmd||true OR set -e;cmd;set +e
VERSION=20090707-1BETA








#




#






DEBUG=1
EXE=$0
while [ -L "$EXE" ] ; do
 EXE=$( ls -l "$EXE" | sed 's/.*-> //' )
done
APPDIR=$( echo $EXE | sed -r 's|[^/]+$||' )
APPDIR=$(cd "${APPDIR:-.}" ; pwd )

NMT=0
if [ -f /mnt/syb8634/VERSION ] ; then
 uid=nmt
 gid=nmt
 if [ -d /share/bin ] ; then
 PATH="/share/bin:$PATH" && export PATH
 fi
else
 uid=root
 gid=None
fi



AWK="/share/Apps/gawk/bin/gawk"
if [ ! -x "$AWK" ] ; then
 AWK=awk
fi
AWK=awk



set +e
echo | gunzip 2>/dev/null
gunzip_error=$?
set -e
gunzip_cmd=
GUNZIP_SCRIPT="$APPDIR/gunzip.php"
if [ "$gunzip_error" = 127 ] ; then

 php_path=/mnt/syb8634/server/php 
 if [ -x "$php_path" ] ; then
 echo Using PHP gunzip
 gunzip_cmd="$GUNZIP_SCRIPT"
 fi
else
 gunzip_cmd=gunzip
fi

PERMS() {
 chown -R $uid:$gid "$@" || true
}


tmp_dir=/tmp
if [ -f /mnt/syb8634/VERSION  ] ; then
 tmp_dir=/share/tmp
 mkdir -p $tmp_dir
 PERMS $tmp_dir

fi

INDEX_DB="$APPDIR/index.db"
if [ ! -s "$INDEX_DB" ] ; then
 echo "#Index" > "$INDEX_DB"; #There must always be one line!
 PERMS "$INDEX_DB"
fi

if [ ! -f "$APPDIR/catalog.cfg" ] ; then
 cp "$APPDIR/catalog.cfg.example" "$APPDIR/catalog.cfg"
fi



if grep -q '$' "$APPDIR/catalog.cfg" ; then
 tmpFile="$tmp_dir/catalog.cfg.$$"
 sed 's/$//' "$APPDIR/catalog.cfg" > "$tmpFile"
 cat "$tmpFile" > "$APPDIR/catalog.cfg"
 rm -f "$tmpFile"
fi
. "$APPDIR/catalog.cfg"

check_missing_settings() {

 if [ -z "$catalog_tv_file_fmt" ] ; then 
 catalog_tv_file_fmt="/share/Tv/{:TITLE:}{ - Season :SEASON:}/{:NAME:}"
 echo "[WARNING] Please add catalog_tv_file_fmt settings to catalog.cfg. See catlog.cfg.example for examples."
 fi
 if [ -z "$catalog_film_folder_fmt" ] ; then 
 catalog_film_folder_fmt="/share/Movies/{:TITLE:}{-:CERT:}"
 echo "[WARNING] Please add catalog_film_folder_fmt settings to catalog.cfg. See catlog.cfg.example for examples."
 fi
}


RENAME_TV=0
RENAME_FILM=0
STDOUT=0

full_path() {
 if [ -d "$1" ] ; then
 (cd "$1" ; pwd )
 else
 BASE=$( sed -r "s,[^/]+$,.," "$1" )
 FILE=$( sed -r "s,.*/,," "$1" )
 BASE=$(cd "$BASE" ; pwd )
 echo "$BASE/$FILE"
 fi
}

check_missing_settings

if [ -z "$*" ] ; then
 cat<<USAGE
 usage $0 [STDOUT] [IGNORE_NFO] [WRITE_NFO] [DEBUG] [REBUILD] [NOACTIONS] [RESCAN] 
 [RENAME] [RENAME_TV] [RENAME_FILM] [DRYRUN] [UPDATE_POSTERS]
 ..folders..
____________________________________________________________________________________________________________________    
To simply index all files in a folder:

 $0 Folder

 This is usually all that is needed. The new oversight viewer will take care of showing nice names to the user.
____________________________________________________________________________________________________________________    
Other options 
 RENAME_TV      - Move the tv folders.
 RENAME_FILM    - Move the film folders.
 RENAME         - Rename both tv and film
 DRYRUN         - Show effects of RENAME but dont do it.
 IGNORE_NFO     - dont look in existing NFO for any infomation
 WRITE_NFO      - write NFO files
 NOWRITE_NFO    - dont write NFO files
 DEBUG          - lots of logging
 REBUILD        - Run even if no folders. Usually to tidy database.
 RESCAN         - Rescan default paths
 NOACTIONS      - Do not run any actions and hide Delete actions from overview.
 STDOUT         - Write to stdout (if not present output goes to log file)
 UPDATE_POSTERS - Fetch new posters for each scanned item.
USAGE
 exit 0
fi

quoted_arg_list() {
 ARGS=""
 for i in "$@" ; do
 case "$i" in
 *\'*)
 case "$i" in
 *\"*) ARGS=`echo "$ARGS" | sed -r 's/[][ *"()?!'"'"']/\\\1/g'` ;;
 *) ARGS="$ARGS "'"'"$i"'"' ;;
 esac
 ;;
 *) ARGS="$ARGS '$i'" ;;
 esac
 done
 echo "$ARGS"
}

SWITCHUSER() {
 if ! id | fgrep -q "($1)" ; then
 u=$1
 shift;
 echo "[$USER] != [$u]"
 
 a="$0 $(quoted_arg_list "$@")"
 echo "CMD=$a"
 exec su $u -s /bin/sh -c "$a"
 fi
}

get_unpak_cfg() {
 for ext in cfg cfg.example ; do
 for nzd in "$APPDIR" /share/Apps/NZBGet/.nzbget /share/.nzbget ; do
 if [ -f "$nzd/unpak.$ext" ] ; then 
 echo "$nzd/unpak.$ext"
 return
 fi
 done
 done
}

catalog() {


 UNPAK_CFG=`get_unpak_cfg`

 Q="'"




 LS=ls
 if [ -f /share/bin/ls ] ; then
 LS=/share/bin/ls
 fi




 $AWK '




function pad_episode(e) {
 if (match(e,"^[0-9][0-9]")) {
 return e;
 } else {
 return "0"e;
 }
}

function DEBUG(x) {
 
 if ( DBG ) {

 if (index(x,g_tk) ) sub(g_tk,"",x);

 print "[DEBUG] '$LOG_TAG' " (systime()-ELAPSED_TIME)" : " x;
 }

}


function DEBUG2(x) {
 
 if ( DBG-1 > 0 ) {

 if (index(x,g_tk) ) sub(g_tk,"",x);
 print "[DEBUG] '$LOG_TAG' " (systime()-ELAPSED_TIME)" : " x;
 }

}


function load_settings(file_name,\
i,n,v,option) {

 INFO("load "file_name);
 FS="\n";
 while((getline option < file_name ) > 0 ) {


 if ((i=match(option,"[^\\\\]#")) > 0) {
 option = substr(option,1,i);
 }


 sub(/ *= */,"=",option);
 option=trim(option);

 sub("=[\""g_quote"]","=",option);
 sub("[\""g_quote"]$","",option);
 if (match(option,"^[A-Za-z0-9_]+=")) {
 n=substr(option,1,RLENGTH-1);
 v=substr(option,RLENGTH+1);
 gsub(/ *[,|] */,"|",v);

 if (n in g_settings) {
 INFO("Setting "n" already overidden as "g_settings[n]" not "v"]");
 } else {
 g_settings[n] = v;
 g_settings_orig[n]=v;
 INFO(n"=["v"]");
 }
 }
 }
 close(file_name);
}


BEGIN {
 g_opt_dry_run=0;
 yes="yes";
 no="no";
 g_quote="'"'"'";

 g_imdb_regex="\\<tt[0-9]+\\>";

 ELAPSED_TIME=systime();
 if (gunzip != "") {
 INFO("using gunzip="gunzip);
 }
 get_folders_from_args(FOLDER_ARR);
}

function status(msg) {
 if (msg == "") {
 rm(g_status_file,1);
 } else {
 print msg > g_status_file;
 close(g_status_file);
 INFO("status:"msg);
 set_permissions(g_status_file);
 }
}

END{
 g_user_agent="Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20040613 Firefox/0.8.0+";

 for(i in g_settings) {
 g_settings_orig[i] = g_settings[i];
 }

 g_lock_file=APPDIR"/catalog.lck";
 g_status_file=APPDIR"/catalog.status";

 load_catalog_settings(APPDIR"/catalog.cfg");


 INDEX_DB_NEW = INDEX_DB "." JOBID ".new";
 INDEX_DB_OLD = INDEX_DB ".old";

 INDEX_DB_OVW = INDEX_DB ".idx";
 INDEX_DB_OVW_NEW = INDEX_DB_OVW "." JOBID ".new";


 DEBUG("RENAME_TV="RENAME_TV);
 DEBUG("RENAME_FILM="RENAME_FILM);

 set_db_fields();


 ACTION_NONE="0";
 ACTION_REMOVE="r";
 ACTION_DELETE_MEDIA="d";
 ACTION_DELETE_ALL="D";

 g_settings["catalog_format_tags"]="\\<("tolower(g_settings["catalog_format_tags"])")\\>";

 gsub(/ /,"%20",g_settings["catalog_cert_country_list"]);
 split(g_settings["catalog_cert_country_list"],gCertificateCountries,"|");

 gExtList1="avi|mkv|mp4|ts|m2ts|xmv|mpg|mpeg|wmv";
 gExtList2="img|iso";

 gExtList1=tolower(gExtList1) "|" toupper(gExtList1);
 gExtList2=tolower(gExtList2) "|" toupper(gExtList2);

 gExtRegexIso="\\.("gExtList2")$";
 INFO(gExtRegexIso);

 gExtRegEx1="\\.("gExtList1")$";
 INFO(gExtRegEx1);

 gExtRegExAll="\\.("gExtList1"|"gExtList2")$";
 INFO(gExtRegExAll);

 split(g_settings["catalog_title_country_list"],gTitleCountries,"|");

 monthHash("Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec",gMonthConvert);
 g_tk="AQ1W1R0GAY5H7K1L8MFN9P1T2YDUAJF";
 monthHash("January,February,March,April,May,June,July,August,September,October,November,December",gMonthConvert);

 g_tk = fix1(g_tk);


 ABC_STR="ABCDEFGHIJKLMNOPQRSTUVWXYZ";
 abc_str=tolower(ABC_STR);
 split(ABC_STR,ABC,"");
 split(abc_str,abc,"");
 
 if ( g_settings["catalog_tv_file_fmt"] == "" ) RENAME_TV=0;
 if  ( g_settings["catalog_film_folder_fmt"] == "") RENAME_FILM=0;

 CAPTURE_PREFIX="'$tmp_dir'/catalog."

 ov_count=0;

 THIS_YEAR=substr(NOW,1,4);

 if (RESCAN == 1) {
 INFO("Scanning default paths");
 split(g_settings["catalog_scan_paths"],FOLDER_ARR,"[,|]");
 }

 for(f in FOLDER_ARR) {
 DEBUG("Folder:\t"FOLDER_ARR[f]);
 }
 gMovieFileCount = 0;
 gMaxDatabaseId = 0;

 
 if (!g_opt_no_actions) {
 load_settings("'$UNPAK_CFG'");
 unpak_nmt_pin_root=unpak_option["unpak_nmt_pin_root"];
 }

 if (1 in FOLDER_ARR) {

 status("Scanning");
 scan_folder_for_new_media(FOLDER_ARR);

 process_scanned_files(20);
 }

 clean_capture_files();

 et=systime()-ELAPSED_TIME;

 for(dm in g_search_count) {
 DEBUG(dm" : "g_search_count[dm]" searches"); 
 }
 for(method in g_search_total) {

 DEBUG(method" Search hits/total = "g_search_hits[method]"/"g_search_total[method]"="(100.0*g_search_hits[method]/g_search_total[method])"%");
 }
 DEBUG(sprintf("Finished: Elapsed time %dm %ds",int(et/60),(et%60)));


 for(i in g_settings) {
 if (!(i in g_settings_orig)) {
 WARNING("Undefined setting "i" referenced");
 }
 }

 rm(g_status_file);
}


function merge_subset_of_scanned_files(indexHash,\
file_to_db,overview_db,ov_count,deleteCount) {
 if (g_opt_dry_run) {
 INFO("Database update skipped - dry run");
 return;
 }
 DB_SIZE = loadDatabase(INDEX_DB,DB_ARR,file_to_db);
 if (lockdb()) {
 if (g_pruned || g_opt_no_actions) {



 exec("cp "quoteFile(INDEX_DB)" "quoteFile(INDEX_DB_NEW));
 } else {
 remove_absent_files_from_new_db(DB_SIZE,DB_ARR,INDEX_DB_NEW); 
 g_pruned=1;
 }

 deleteCount = remove_files_with_delete_actions(DB_ARR,DB_SIZE);

 add_new_scanned_files_to_database(indexHash,INDEX_DB_NEW,DB_ARR,file_to_db);

 ov_count = build_overview_array(INDEX_DB_NEW,overview_db);

 add_overview_indices(overview_db,ov_count);

 write_overview(overview_db,INDEX_DB_OVW_NEW);

 replace_database_with_new();

 unlockdb();
 }
}

function dbIsLocked(\
pid) {
 if (!exists(g_lock_file)) return 0;

 pid="";
 if ((getline pid < g_lock_file) >= 0) {
 close(g_lock_file);
 }
 if (pid == "" ) {
 DEBUG("Not Locked = "pid);
 return 0;
 } else if (isDirectory("/proc/"pid)) {
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

function lockdb(\
attempts,sleep,backoff) {
 attempts=0;
 sleep=10;
 split("10,10,20,30,60,120",backoff,",");
 for(attempts=1 ; (attempts in backoff) && dbIsLocked(g_lock_file) ; attempts++) {
 sleep=backoff[attempts];
 WARNING("Failed to get exclusive lock. Retry in "sleep" seconds.");
 system("sleep "sleep);
 }
 if (dbIsLocked(g_lock_file)) {
 ERROR("Failed to get exclusive lock");
 return 0;
 } else {
 INFO("Locked Database");
 print PID > g_lock_file;
 close(g_lock_file);
 set_permissions(quoteFile(g_lock_file));
 return 1;
 }
}

function unlockdb() {
 INFO("Unlocked Database");
 rm(g_lock_file);
 status("");
}

function monthHash(nameList,hash,\
names,i) {
 split(nameList,names,",");
 for(i in names) {
 hash[tolower(names[i])] = i+0;
 }
} 

function replace_database_with_new() {

 INFO("Replace Database");

 system("cp -f "quoteFile(INDEX_DB)" "quoteFile(INDEX_DB_OLD));

 touch_and_move(INDEX_DB_NEW,INDEX_DB);
 touch_and_move(INDEX_DB_OVW_NEW,INDEX_DB_OVW);

 set_permissions(quoteFile(INDEX_DB)"*");
}

function set_permissions(shellArg) {
 if (ENVIRON["USER"] != '$uid' ) {
 system("chown '$uid:$gid' "shellArg);
 }
}

function caps(text,\
i,j,abc_str,abc,ABC) {

 if ((j=index(abc_str,substr(text,1,1))) > 0) {
 text = ABC[j] substr(text,2);
 }

 for(i in ABC) {
 while ((j=index(text," " abc[i] )) > 0) {
 text=substr(text,1,j) ABC[i] substr(text,j+2);
 }
 }
 return text;
}

function set_db_fields() {

 ID=db_field("_id","ID","",0);


 OVERVIEW_DETAILIDLIST=db_field("_did" ,"Ids","",0);
 OVERVIEW_EXT_LIST = db_field("_ext","Extensions","",0);

 WATCHED=db_field("_w","Watched","watched",0) ;
 ACTION=db_field("_a","Next Operation","",0); # ACTION Tell catalog.sh to do something with this entry (ie delete)
 PARTS=db_field("_pt","PARTS","","");
 FILE=db_field("_F","FILE","filenameandpath","");
 NAME=db_field("_N","NAME","","");
 DIR=db_field("_D","DIR","","");


 ORIG_TITLE=db_field("_ot","ORIG_TITLE","originaltitle","");
 TITLE=db_field("_T","Title","title",".titleseason") ;
 AKA=db_field("_K","AKA","","");

 CATEGORY=db_field("_C","Category","",0);
 ADDITIONAL_INFO=db_field("_ai","Additional Info","","");
 YEAR=db_field("_Y","Year","year",0) ;

 SEASON=db_field("_s","Season","season",0) ;
 EPISODE=db_field("_e","Episode","episode","");
 SEASON0=db_field("0_s","0SEASON","","");
 EPISODE0=db_field("0_e","0EPISODE","","");

 GENRE=db_field("_G","Genre","genre",0) ;
 RATING=db_field("_r","Rating","rating","");
 CERT=db_field("_R","CERT","mpaa",0); #Not standard?
 PLOT=db_field("_P","Plot","plot","");
 URL=db_field("_U","URL","url","");
 POSTER=db_field("_J","Poster","thumb",0);

 DOWNLOADTIME=db_field("_DT","Downloaded","",0);
 INDEXTIME=db_field("_IT","Indexed","",1);
 FILETIME=db_field("_FT","Modified","",0);

 SEARCH=db_field("_SRCH","Search URL","search","");
 PROD=db_field("_p","ProdId.","","");
 AIRDATE=db_field("_ad","Air Date","aired","");
 TVCOM=db_field("_tc","TvCom","","");
 EPTITLE=db_field("_et","Episode Title","title","");
 EPTITLEIMDB=db_field("_eti","Episode Title(imdb)","","");
 AIRDATEIMDB=db_field("_adi","Air Date(imdb)","","");
 NFO=db_field("_nfo","NFO","nfo","");

 IMDBID=db_field("_imdb","IMDBID","id","");
}







function db_field(key,name,tag,overview) {
 g_db_field_name[key]=name;
 gDbTag2FieldId[tag]=key;
 gDbFieldId2Tag[key]=tag;
 if (overview != "" ) {
 if (overview == 1 ) {
 OVERVIEW_FIELDS[key] = key;
 DEBUG("Overview field ["key"] = ["name"] sorted");
 } else {
 OVERVIEW_FIELDS[key] = overview;
 if (overview == 0) {
 DEBUG("Overview field ["key"] = ["name"] unsorted");
 } else {
 DEBUG("Overview field ["key"] = ["name"] sorted by ["overview"]");
 }
 }
 }
 return key;
}

function scan_folder_for_new_media(folderArray,\
temp,f) {


 gLS_FILE_POS=0;
 gLS_TIME_POS=0; 

 temp=NEW_CAPTURE_FILE("MOVIEFILES")

 findLSFormat(temp);

 for(f in folderArray) {
 scan_contents(folderArray[f],temp);
 }
}

function findLSFormat(temp,\
folderNameNext,i,currentFolder) {
 DEBUG("Finding LS Format");
 exec(LS" -Rl /proc/"JOBID" > "temp );
 FS=" ";
 folderNameNext=1;
 
 while((getline < temp) > 0 ) {
 if (folderNameNext) {
 currentFolder = $0;
 sub(/\/*:/,"",currentFolder);
 DEBUG("Folder = "currentFolder);
 folderNameNext=0;
 } else if ($0 == "" ) {
 folderNameNext=1;
 }  else {
 if (substr(currentFolder,1,5) == "/proc" ) {
 if (index($0,"fd") && match($0,"\\<fd\\>")) {
 INFO("LS Format "$0);
 for(i=1 ; i - NF <= 0 ; i++ ) {
 if ($i == "fd") gLS_FILE_POS=i;
 if (index($i,":")) gLS_TIME_POS=i;
 }
 DEBUG("File Position at "gLS_FILE_POS);
 DEBUG("Time Position at "gLS_TIME_POS);
 break;
 } 
 }
 }
 }
 close(temp);
}


function scan_contents(root,temp,
currentFolder,skipFolder,i,folderNameNext,perms,w5,lsMonth,\
lsDate,lsTimeOrYear,f,d,extRe,pos,store,lc,nfo,quotedRoot) {

 DEBUG("PreScanning "root);
 if (root == "") return;


 if (root != "/" ) {
 gsub(/\/+$/,"",root); 
 }

 quotedRoot=quoteFile(root);

 extRe="\\.[^.]+$";





 DEBUG("Scanning "quotedRoot);



 exec("( "LS" -Rl "quotedRoot"/ || "LS" -Rl "quotedRoot" ) > "temp );
 FS=" ";
 currentFolder = root;
 skipFolder=0;
 folderNameNext=1;
 while((getline < temp) > 0 ) {


 DEBUG( "ls: ["$0"]"); 

 store=0;
 perms=$1;

 if ($0 == "") continue;

 if (match($0,"^total [0-9]+$")) continue;

 if (!match(substr(perms,2,9),"^[-rwxsSt]+$") ) {

 currentFolder = $0;
 sub(/\/*:/,"",currentFolder);
 DEBUG("Folder = "currentFolder);
 folderNameNext=0;
 if ( currentFolder ~ g_settings["catalog_ignore_paths"] ) {
 skipFolder=1;
 INFO("Ignore path "currentFolder);
 } else if(unpak_nmt_pin_root != "" && index(currentFolder,unpak_nmt_pin_root) == 1) {
 skipFolder=1;
 INFO("SKIPPING "currentFolder);
 } else if (currentFolder in gFolderCount) {

 WARNING("Already visited "currentFolder);
 skipFolder=1;


 } else {
 skipFolder=0;
 gFolderMediaCount[currentFolder]=0;
 gFolderInfoCount[currentFolder]=0;
 gFolderCount[currentFolder]=0;
 DEBUG("Clear folder count ["currentFolder"]");
 }

 } else if (!skipFolder) {

 lc=tolower($0);

 if ( lc ~ g_settings["catalog_ignore_names"] ) {
 INFO("Ignore name "$0);
 continue;
 }

 w5=lsMonth=lsDate=lsTimeOrYear="";


 w5=$5;

 if ( gLS_TIME_POS ) {
 lsMonth=$(gLS_TIME_POS-2);
 lsDate=$(gLS_TIME_POS-1);
 lsTimeOrYear=$(gLS_TIME_POS);
 }




 pos=index($0,$2);
 for(i=3 ; i - gLS_FILE_POS <= 0 ; i++ ) {
 pos=indexFrom($0,$i,pos+length($(i-1)));
 }
 $0=substr($0,pos);
 lc=tolower($0);


 if (substr(perms,1,1) != "-") {
 if (substr(perms,1,1) == "d") {

 if (currentFolder in gFolderCount) {
 gFolderCount[currentFolder]++;
 }

 DEBUG("Folder ["$0"]");

 if ($0 == "VIDEO_TS") {

 if (match(currentFolder,"/[^/]+$")) {
 f = substr(currentFolder,RSTART+1);
 d = substr(currentFolder,1,RSTART-1);
 }

 storeMovie(gMovieFileCount,f"/",d,calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW));
 setNfo(gMovieFileCount,"/$",".nfo");
 gMovieFileCount++;
 skipFolder=1;
 }
 }
 continue;
 }
 

 if (match(lc,gExtRegexIso)) {


 if (length(w5) - 10 < 0) {
 INFO("Skipping image - too small");
 } else {
 store=1;
 }

 } else if (match($0,"unpak.???$")) {
 
 gDate[currentFolder"/"$0] = calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW);

 } else if (match(lc,gExtRegEx1)) {

 DEBUG("gFolderMediaCount[currentFolder]="gFolderMediaCount[currentFolder]);

 if (gFolderMediaCount[currentFolder] > 0 && gMovieFileCount - 1 >= 0 ) {
 if ( checkMultiPart($0,gMovieFileCount) ) {


 if ( !setNfo(gMovieFileCount-1,".(|cd|disk|disc|part)[1-9]" extRe,".nfo") ) {
 setNfo(gMovieFileCount-1, extRe,".nfo");
 }
 } else {
 store=2;
 }
 } else {

 store=2;
 }

 } else if (match(lc,"\\.nfo$")) {

 nfo=currentFolder"/"$0;
 gFolderInfoCount[currentFolder]++;
 gFolderInfoName[currentFolder]=nfo;
 gDate[nfo] = calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW);
 }

 if (store) {

 storeMovie(gMovieFileCount,$0,currentFolder,calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW));
 setNfo(gMovieFileCount,"\\.[^.]+$",".nfo");
 gMovieFileCount++;
 }
 }
 }
 close(temp);
 DEBUG("Found "gMovieFileCount" items to add");
}



function glob2re(glob) {
 gsub(/[.]/,"\\.",glob);
 gsub(/[*]/,".*",glob);
 gsub(/[?]/,".",glob);
 gsub(/[<]/,"\\<",glob);
 gsub(/ *, */,"|",glob);
 gsub(/[>]/,"\\>",glob);
 return "^("glob")$";
}

function csv2re(text) {
 gsub(/ *, */,"|",text);
 return "("text")";
}

function storeMovie(idx,file,folder,timeStamp) {

 gFolderMediaCount[folder]++;

 gFolder[idx]=folder;
 gMovieFiles[idx] = file;
 DEBUG("Storing ["gFolder[idx]"]["gMovieFiles[idx]"]");


 gMovieFilePresent[folder"/"file] = 1;
 g_file_time[idx] = timeStamp;
}





function checkMultiPart(name,count,\
i,firstName) {
 firstName=gMovieFiles[count-1];

 DEBUG("Multipart check ["firstName"] vs ["name"]");
 if (length(firstName) != length(name)) {
 DEBUG("length ["firstName"] != ["name"]");
 return 0;
 }
 if (firstName == name) return 0;

 for(i=1 ; i - length(firstName) <= 0 ; i++ ) {
 if (substr(firstName,i,1) != substr(name,i,1)) {
 break;
 }
 }
 DEBUG2("difference at character "i);

 if (substr(firstName,i+1) != substr(name,i+1)) {
 DEBUG("no match last bit ["substr(firstName,i+1)"] != ["substr(name,i+1)"]");
 return 0;
 }

 if (substr(firstName,i-1,2) ~ "[^0-9]1" || substr(firstName,i-2,3) ~ "[^EeXx0-9][0-9]1" ) {




 if (!(substr(name,i,1) ~ "[2-9]")) {
 DEBUG("no match on [2-9]"substr(name,i,1));
 return 0;
 }

 } else if (substr(firstName,i,1) ~ "[Aa]") {
 if (!(substr(name,i,1) ~ "[A-Fa-f]")) {
 DEBUG("no match on [A-Fa-f]"substr(name,i,1));
 return 0;
 }

 } else {
 DEBUG("no match on [^0-9][Aa1]");
 return 0;
 }

 INFO("Found multi part file - linked with "firstName);
 gParts[count-1] = (gParts[count-1] =="" ? "" : gParts[count-1]"/" ) name;
 gMultiPartTagPos[count-1] = i;
 return 1;
}


function setNfo(idx,pattern,replace,\
nfo,lcNfo) {

 nfo=gMovieFiles[idx];
 lcNfo = tolower(nfo);
 if (match(lcNfo,pattern)) {
 nfo=substr(nfo,1,RSTART-1) replace substr(nfo,RSTART+RLENGTH);
 gNfoDefault[idx] = getPath(nfo,gFolder[idx]);
 DEBUG("Storing default nfo path ["gNfoDefault[idx]"]");
 return 1;
 } else {
 return 0;
 }
}

function exec(cmd, err) {

 DEBUG2("SYSTEM : [["cmd"]]");
 if ((err=system(cmd)) != 0) {
 ERROR("Return code "err" executing "cmd) ;
 }
 return err;
}


function build_overview_array(databaseIndex,overview_db,\
first_tv_db_entry,\
i,ext,seriesId,fields,ep1,ov_count,db_count) {

 DEBUG("build_overview_array");
 FS="\t";
 ov_count=0;
 db_count=0;
 while((getline < databaseIndex ) > 0 ) {

 if (substr($0,1,1) == "\t") {

 db_count++;

 delete fields;
 for(i=2 ; i - NF < 0 ; i+= 2 ) {
 fields[$i] = $(i+1);
 }



 if (fields[ACTION] != ACTION_NONE && g_opt_no_actions==1) {
 INFO("noactions:Excluding item "fields[ID]" from overview list");
 continue;
 }

 seriesId=tolower(fields[TITLE]"\t"fields[SEASON]);

 ext=fields[FILE];
 if (isDvdDir(ext)) {
 ext = "/"; #VIDEO_TS
 } else {
 ext=tolower(ext);
 sub(/.*\./,"",ext);
 }

 if (fields[CATEGORY] != "T" || !( seriesId in first_tv_db_entry )) {


 fields[OVERVIEW_EXT_LIST]=ext;
 fields[OVERVIEW_DETAILIDLIST]=fields[ID];


 if (fields[CATEGORY] == "T") {
 first_tv_db_entry[seriesId] = ov_count;
 }

 sub(/^[Tt]he /,"",seriesId);
 overview_db[".titleseason",ov_count] = seriesId;

 for(i in OVERVIEW_FIELDS) {
 if(i in fields) {
 overview_db[i,ov_count] = fields[i];
 }
 }

 if (fields[CATEGORY] == "") {
 overview_db[FILE,ov_count] = fields[FILE];
 }
 ov_count++;

 } else {


 ep1 = first_tv_db_entry[seriesId];

 overview_db[OVERVIEW_DETAILIDLIST,ep1] =overview_db[OVERVIEW_DETAILIDLIST,ep1]  "|" fields[ID];

 if (index(overview_db[OVERVIEW_EXT_LIST,ep1],ext) == 0) {
 overview_db[OVERVIEW_EXT_LIST,ep1]=overview_db[OVERVIEW_EXT_LIST,ep1] "|" ext;
 }

 if (fields[FILETIME] > overview_db[FILETIME,ep1]) {
 overview_db[FILETIME,ep1]=fields[FILETIME];
 }
 if (fields[INDEXTIME] > overview_db[INDEXTIME,ep1]) {
 overview_db[INDEXTIME,ep1]=fields[INDEXTIME];
 }
 if (fields[DOWNLOADTIME] > overview_db[DOWNLOADTIME,ep1]) {
 overview_db[DOWNLOADTIME,ep1]=fields[DOWNLOADTIME];
 }

 if (fields[WATCHED] == 0) {
 overview_db[WATCHED,ep1]=0;
 }
 }
 }
 }
 close(databaseIndex);
 INFO("Read "db_count" items from full db and added "ov_count" items to the overview array");
 return ov_count;
}

function add_overview_indices(overview_db,ov_count,\
 f) {

 DEBUG("add_overview_indices");



 for(f in OVERVIEW_FIELDS) {
 if (OVERVIEW_FIELDS[f] != 0) {
 add_overview_index(overview_db,ov_count,f);
 }
 }
}


function add_overview_index(overview_db,ov_count,name,
 row,ord,sortField) {


 for(row = 0 ; row - ov_count < 0 ; row++ ) {
 ord[row]=row;
 }
 dump("Overview pre sort "ov_count":",ord);

 sortField=OVERVIEW_FIELDS[name];
 if (substr(sortField,1,1) == ".") {
 sortField = substr(sortField,2);
 }
 DEBUG("Creating index for "name" using "sortField" on "ov_count" items");
 heapsort(ov_count, OVERVIEW_FIELDS[name],1,ord,overview_db);
 dump("Overview post sort "ov_count":",ord);




 for(row = 0 ; row - ov_count < 0 ; row++ ) {
 overview_db["#"name"#",ord[row]] = row;

 }
}


function write_overview(arr,outFile,\
 line,r,f,dim,sep,fld,idx,count) {

 status("Writing overview");
 for(f in arr) {






 if (substr(f,1,1) == ".") continue;

 sep = index(f,SUBSEP);
 fld=substr(f,1,sep-1);
 idx = substr(f,sep+1);
 line[idx] = line[idx] fld "\t" arr[f] "\t" ;       
 }
 for(r in line) {
 count++;
 print "\t"line[r] > outFile;
 }
 close(outFile);
 INFO("Added "count" records to overview database");
}




function folderIsRelevant(dir) {

 DEBUG("Check parent folder relation to media ["dir"]");
 if ( !(dir in gFolderCount) || gFolderCount[dir] == "") { 
 DEBUG("unknown folder ["dir"]" );
 return 0;
 }

 if (gFolderCount[dir] - 2 > 0 ) {
 DEBUG("Too many sub folders - general folder");
 return 0;
 }
 if (gFolderMediaCount[dir] - 2 > 0 ) {
 DEBUG("Too much media  general folder");
 return 0;
 }
 return 1;
}

function searchInternetForImdbLink(idx,\
url,triedTitles,txt,txt2,titlesRequired,linksRequired) {

 titlesRequired = 0+g_settings["catalog_imdb_titles_required"];
 linksRequired = 0+g_settings["catalog_imdb_links_required"];
 
 txt = basename(gMovieFiles[idx]);
 if (tolower(txt) != "dvd_volume" ) {
 url=searchHeuristicsForImdbLink(idx,txt,triedTitles,titlesRequired,linksRequired);
 }

 if ( url == "" ) {
 txt2 = remove_scene_name_and_parts(idx);
 if (txt2 != txt ) {

 url=searchHeuristicsForImdbLink(idx,txt2,triedTitles,titlesRequired+1,linksRequired+1);
 }
 }

 if (url == "" && match(gMovieFiles[idx],gExtRegexIso)) {
 txt = getIsoTitle(gFolder[idx]"/"gMovieFiles[idx]);
 if (length(txt) - 3 > 0 ) {
 url=searchHeuristicsForImdbLink(idx,txt,triedTitles,titlesRequired,linksRequired);
 }
 }

 if (url == "" && folderIsRelevant(gFolder[idx])) {
 url=searchHeuristicsForImdbLink(idx,tolower(basename(gFolder[idx])),triedTitles,titlesRequired,linksRequired);
 }

 return url;
}

function remove_scene_name_and_parts(idx,\
txt) {




 txt = tolower(basename(gMovieFiles[idx]));


 if (idx in gMultiPartTagPos) {
 txt = substr(txt,1,gMultiPartTagPos[idx]-1);
 }


 sub(/^[a-z]{1,4}-/,"",txt);

 return txt;
}

function mergeSearchKeywords(text,keywordArray,\
heuristicId,keywords) {

 for(heuristicId =  0 ; heuristicId -1  <= 0 ; heuristicId++ ) {
 keywords =fileNameToSearchKeywords(text,heuristicId);
 keywordArray[keywords]=1;
 }
}


function searchHeuristicsForImdbLink(idx,text,triedTitles,titlesRequired,linksRequired,\
bestUrl,k,text_no_underscore) {

 mergeSearchKeywords(text,k);

 text_no_underscore = text;
 gsub(/_/," ",text_no_underscore);
 gsub("[[][^]]+[]]","",text_no_underscore);
 if (text_no_underscore != text) {
 mergeSearchKeywords(text_no_underscore,k);
 }

 bestUrl = searchArrayForIMDB(k,linksRequired,triedTitles);

 if (bestUrl == "" ) {
 DEBUG("Deep search disabled");

 }

 return bestUrl;
}



function searchArrayForIMDB(k,linkThreshold,triedTitles,\
bestUrl,keywords,keywordsSansEpisode) {

 g_search_total["direct"]++;

 DEBUG("direct search...");
 bestUrl = searchArrayForIMDB2(k,linkThreshold,triedTitles);

 if (bestUrl == "") {

 for(keywords in k) {
 if (sub(/ *s[0-9][0-9]e[0-9][0-9].*/,"",keywords)) {
 keywordsSansEpisode[keywords]=1;
 }
 }
 bestUrl = searchArrayForIMDB2(keywordsSansEpisode,linkThreshold,triedTitles);
 }
 if (bestUrl != "") {
 g_search_hits["direct"]++;
 }
 DEBUG("direct search : result ["bestUrl"]");

 return bestUrl;
}

function searchArrayForIMDB2(k,linkThreshold,triedTitles,\
bestUrl,keywords) {

 for(keywords in k) {
 DEBUG("direct search ["keywords"]...");
 if (keywords in triedTitles) {
 INFO("Already tried ["keywords"]");
 } else {
 INFO("direct search ["keywords"]");
 bestUrl = searchForIMDB(keywords,linkThreshold);
 if (bestUrl != "") {
 INFO("direct search : Found ["bestUrl"]with direct search ["keywords"]");
 return bestUrl;
 }
 }
 }
 return "";
}




function deepSearchArrayForIMDB(idx,k,titleThreshold,linkThreshold,triedTitles,\
bestUrl,keywords,text) {

 g_search_total["deep"]++;

 for(keywords in k) {

 text=searchForBestTitleSubstring(keywords ,titleThreshold);
 bestUrl = deepSearchStep2(idx,keywords,text,linkThreshold,triedTitles);
 if (bestUrl == "" ) {

 if (sub(/ *s?[0-9][0-9][ex]?[0-9][0-9].*/,"",text)) {
 bestUrl = deepSearchStep2(idx,keywords,text,linkThreshold,triedTitles);
 }
 }  
 if (bestUrl != "" ) {
 break;
 }
 }
 if (bestUrl != "") {
 g_search_hits["deep"]++;
 }
 DEBUG("Deep search result = ["bestUrl"]");
 return bestUrl;
}
function deepSearchStep2(idx,keywords,text,linkThreshold,triedTitles,\
bestUrl) {
 if (text != "" ) {

 if (text in triedTitles) {
 INFO("Already tried ["text"]");
 } else {
 DEBUG("deep search ["keywords"] => ["text"]");
 triedTitles[text]++;

 if (0 && g_category[idx] == "T") {
 bestUrl=getAllTvInfoAndImdbLink(idx,text);
 }
 if (bestUrl == "") {


 bestUrl = searchForIMDB(text,linkThreshold);
 }
 if (bestUrl != "") {
 INFO("Found with deep search ["keywords"]=>["text"]");
 }
 }
 }
 return bestUrl;
}


function basename(f) {
 if (match(f,"/[^/]+$")) {

 f=substr(f,RSTART+1);
 } else if (match(f,"/[^/]+/$")) {

 f=substr(f,RSTART+1,RLENGTH-2);
 }

 sub(gExtRegExAll,"",f); #remove extension

 return f;
}


function get_frequent_substring(titles,threshold,\
cleaned_titles,i,j,k,substring_count,substring_words,txt) {
 for(i in titles) {
 cleaned_titles[i]=tolower(cleanTitle(titles[i]));
 }

 dump(1,"cleaned",cleaned_titles);


 for(i in cleaned_titles) {

 merge_substring_count(cleaned_titles[i],substring_count,substring_words);
 }


 for(i in substring_count) {
 j = substring_count[i]-1 ;
 k = substring_words[i]-1 ;







 substring_count[i] = j * j * k;
 if (substring_count[i]-threshold >= 0 ) {
 DEBUG("count = "j"\twords="substring_words[i]"\tfinal = "substring_count[i] "\t["i"]");
 } else {
 delete substring_count[i];
 }
 }
 txt = getMax(substring_count,threshold,1,1);
 DEBUG("FOUND["txt"]");
 return txt;
}



function merge_substring_count(title,substring_count,substring_words,\
txt,first_word_pos,e,s,w,start,i,j,sep,current_title_substrings) {

 start = 0 ;
 first_word_pos=0;

 DEBUG("Extracting from ["title"]");


 w=1;
 sep=",+";
 do {
 start ++;
 e[w-1]=start-2;
 s[w++]=start;

 start=indexFrom(title," ",start);
 } while (start > 0);
 e[w-1]=length(title);
 
 for(i=1 ; (i in s) ; i++ ) {
 for(j=i ; (j in s) ; j++ ) {

 txt=substr(title,s[i],e[j]-s[i]+1);


 if (!(txt in current_title_substrings)) {

 substring_count[txt] += 1; # (10-s[i]);
 substring_words[txt]=j-i+1;
 current_title_substrings[txt]=1;
 }
 }
 }
}



function fileNameToSearchKeywords(f,heuristic\
) {




 f=tolower(f);

 if (heuristic == 0 || heuristic == 1) {

 gsub(/[^-_A-Za-z0-9]+/,"+",f);





 if (match(f,"\\<(19|20)[0-9][0-9]\\>")) {
 f = substr(f,1,RSTART+RLENGTH);
 }

 if (match(f,"\\<s[0-9][0-9]e[0-9][0-9]")) {
 f = substr(f,1,RSTART+RLENGTH);
 }


 f = remove_format_tags(f);


 if (heuristic == 1) {
 DEBUG("Base query = "f);
 gsub(/[-+.]/,"+%2B",f);
 f="%2B"f;
 }

 gsub(/^\+/,"",f);
 gsub(/\+$/,"",f);

 } else if (heuristic == 2) {

 f = "%22"f"%22"; #double quotes
 }
 DEBUG("Using search method "heuristic" = ["f"]");
 return f;
}

function remove_format_tags(text,\
t) {
 if ((t = match(tolower(text),g_settings["catalog_format_tags"])) > 0) {
 text = substr(text,1,RSTART-1);
 }

 return trimAll(text);
}

function scrapeIMDBTitlePage(idx,url,\
f,imdbid,imdb,newPosterUrl,line) {

 if (url == "" ) return;


 url=extractImdbLink(url);

 if (url == "" ) return;

 if (gExternalSourceUrl[idx] == url) {
 INFO("Already scraped IMDB "url" for this item");
 return;
 }

 DEBUG("Setting external url to ["url"]");
 gExternalSourceUrl[idx] = url;
 
 f=getUrl(url,"imdb_main",1);

 if (f != "" ) {

 imdbContentPosition="header";

 DEBUG("START IMDB: title:"gTitle[idx]" poster "g_poster[idx]" genre "g_genre[idx]" cert "gCertRating[idx]" year "g_year[idx]);

 FS="\n";
 while(imdbContentPosition != "footer" && (getline line < f) > 0  ) {
 imdbContentPosition=scrapeIMDBLine(line,imdbContentPosition,idx,f);
 }
 close(f);

 }
}





function parseDbRow(row,arr,file_count,\
fields,f,i,fileRe) {
 split(row,fields,"\t");
 for(i=2 ; (i in fields) ; i += 2 ) {
 arr[fields[i],file_count] = fields[i+1];
 }
 f=arr[FILE,file_count];
 if (index(f,"//")) {
 gsub(/\/\/+/,"/",f);
 arr[FILE,file_count] = f;
 }

 if (isDvdDir(f)) {
 fileRe="/[^/]+/$"; # /path/to/name/[VIDEO_TS]
 } else {
 fileRe="/[^/]+$";  # /path/to/name.avi
 }

 if (match(f,fileRe)) {
 arr[NAME,file_count] = substr(f,RSTART+1);
 arr[DIR,file_count] = substr(f,1,RSTART-1);
 }
}

function loadDatabase(db_file,db,file_to_db,\
arr_size,f,record_action) {

 delete db;

 arr_size=0;
 delete file_to_db;

 INFO("read_database");

 FS="\n";
 while((getline < db_file) > 0 ) {
 if ( substr($0,1,1) != "\t" ) { continue; }

 parseDbRow($0,db,arr_size);

 f=db[FILE,arr_size];

 record_action=db[ACTION,arr_size];
 if (g_opt_no_actions==0 && record_action != ACTION_NONE) {

 if (record_action == ACTION_REMOVE) {

 deleteCurrentEntry(db,arr_size);

 } else if (record_action == ACTION_DELETE_MEDIA || record_action == ACTION_DELETE_ALL) {

 deleteFiles(db,arr_size,db[ACTION,arr_size]);
 deleteCurrentEntry(db,arr_size);
 }

 } else if (f in file_to_db ) {
 WARNING("Duplicate detected for "f". Ignoring");
 deleteCurrentEntry(db,arr_size);
 } else {

 if (g_opt_no_actions && record_action != ACTION_NONE) {
 INFO("noactions:Temporarily including item "db[ID,arr_size]" with action "record_action);
 }
 file_to_db[f]=arr_size;


 g_index_line[db[FILE,arr_size]] = $0;

 if ( db[FILE,arr_size] == "" ) {
 ERROR("Blank file for ["$0"]");
 }
 if (db[ID,arr_size] - gMaxDatabaseId > 0) {
 gMaxDatabaseId = db[ID,arr_size];
 }


 arr_size++;
 }
 }
 close(db_file);
 INFO("Loaded "arr_size" records from main database");
 return arr_size;
}

function deleteCurrentEntry(db,idx, i) {

 for(i=2 ; i - NF < 0 ; i+= 2 ) {
 delete db[$i,idx];
 }
}

function getPath(name,localPath) {
 if (substr(name,1,1) == "/" ) {

 return name;
 } else if (substr(name,1,4) == "ovs:" ) {

 return APPDIR"/db/global/"substr(name,5);
 } else {

 return localPath"/"name;
 }
}


function queueFileForDeletion(name,field) {
 gFileToDelete[name]=field;
}


function remove_files_with_delete_actions(db,file_count,\
 f,field,i,deleteFile,count) {

 status("Deleting");

 count = 0;

 for(f in gFileToDelete) {
 field=gFileToDelete[f];
 if (field != "" && field != DIR ) {
 deleteFile=1;

 for(i = 0 ; i - file_count < 0 ; i++ ) {
 if (getPath(db[field,i],db[DIR,i]) == f) {
 INFO(f" still in use by item "db[ID,i]);
 deleteFile=0;
 break;
 }
 }
 if (deleteFile) {
 exec(rm(f,"",1));
 count++;
 }
 }
 }

 INFO("Deleting folders");
 for(f in gFileToDelete) {
 field=gFileToDelete[f];
 if (field == DIR ) {

 DEBUG("Deleting "f" only if empty");
 exec(rmdir(f,"",1));
 }
 }
 return count;
}


function deleteFiles(db,idx,mode,\
 p,parts,i,d,rmList) {
 INFO("Deleting "db[FILE,idx]);
 split(db[PARTS,idx],parts,"/");
 d=db[DIR,idx];



 rmList = quoteFile(db[FILE,idx]);
 for (i in parts) {
 rmList = rmList " " quoteFile(d"/"parts[i]);
 }

 if (mode == ACTION_DELETE_ALL) {

 p=db[FILE,idx];
 sub(/.[^.]+$/,"",p);
 rmList = rmList " " quoteFile(p) ".???" ;
 for(i in parts) {
 p=parts[i];
 sub(/.[^.]+$/,"",p);
 rmList = rmList " " quoteFile(p) ".???" ;
 }
 rmList = rmList " unpak.txt unpak.log unpak.state.db unpak.continue unpak.delete.sh unpak.resume" ;
 rmList = rmList " *[^A-Za-z0-9]sample[^A-Za-z0-9]*.???" ;
 rmList = rmList " *[^A-Za-z0-9]samp[^A-Za-z0-9]*.???" ;
 rmList = rmList " *[^A-Za-z0-9]SAMPLE[^A-Za-z0-9]*.???" ;
 rmList = rmList " *[^A-Za-z0-9]SAMP[^A-Za-z0-9]*.???" ;
 }
 exec(" cd "quoteFile(d)" && rm -f -- "rmList " &");

 if (db[NFO,idx] != "") {
 queueFileForDeletion(getPath(db[NFO,idx],db[DIR,idx]),NFO);
 }
 if (db[POSTER,idx] != "") {
 queueFileForDeletion(getPath(db[POSTER,idx],db[DIR,idx]),POSTER);
 }
 queueFileForDeletion(db[DIR,idx],DIR);
}





function remove_absent_files_from_new_db(dbSize,db,newDbFile,   i,\
 list,f,q,maxCommandLength) {
 list="";
 maxCommandLength=3999;

 status("Pruning");

 print "#Index" > newDbFile;

 kept_file_count=0;
 absent_file_count=0;
 updated_file_count=0;
 f=NEW_CAPTURE_FILE("PROBEMISSING");

 for(i=0 ; i - dbSize < 0 ; i++ ) {

 if (db[FILE,i] == "" ) {

 WARNING("Empty file for index " i);

 } else {

 q=quoteFile(db[FILE,i]);
 list " "q;

 if (length(list)+length(q) - maxCommandLength < 0 ) {
 list=list " "q;
 } else {
 determineFileStatus(f,list,newDbFile);
 list=q
 }
 }
 }
 if ( list != "" ) {
 determineFileStatus(f,list,newDbFile);
 }
 close(newDbFile);
 INFO("UNCHANGED:"kept_file_count);
 INFO("NOT FOUND:"absent_file_count);
 INFO("UPDATING :"updated_file_count);
 INFO("NEW      :"(gMovieFileCount-updated_file_count));
}


function quoteFile(f) {
 gsub(g_quote,g_quote "\\"g_quote g_quote,f);
 return g_quote f g_quote;
}

function determineFileStatus(f,list,newDbFile,\
cmd,i,line) {
 INFO("Checking batch");
 cmd="ls -d -- " list " > " f " 2>&1" 

 system(cmd);
 FS="\n";
 while((getline line < f ) > 0 ) {

 if (line == "" ) continue;

 if ((i=index(line,": No such file or directory")) > 0 || (i=index(line,": Not a directory")) > 0) {
 line = substr(line,1,i-1);
 i = index(line,"/");
 line = substr(line,i);

 INFO("de-listing ["line"]");
 absent_file_count++;

 } else if (gMovieFilePresent[line] == 0) {


 if (line in g_index_line) {
 print g_index_line[line] > newDbFile;
 kept_file_count++;
 } else {
 WARNING("["line"] not present in index");
 }

 } else {

 INFO("UPDATING ["line"] later.");
 updated_file_count++;
 }
 }
 close(f);
}

function calcTimestamp(lsMonth,lsDate,lsTimeOrYear,_default,\
 val,y,m,d,h,min) {

 if (lsMonth == "" ) {
 return _default;
 } else {
 m=gMonthConvert[lsMonth];
 d=lsDate;
 if (index(lsTimeOrYear,":")) {

 y=THIS_YEAR;
 h=substr(lsTimeOrYear,1,2);
 min=substr(lsTimeOrYear,4,2);
 } else {

 y=lsTimeOrYear;
 h=7;
 min=0;
 }
 val = sprintf("%04d%02d%02d%02d%02d00",y,m,d,h,min); 
 if (val - NOW > 0 ) {
 y--;
 val = sprintf("%04d%02d%02d%02d%02d00",y,m,d,h,min); 
 }
 return val; 
 }
}

function checkTvFilenameFormat(idx,\
details,line,dirs,d,dirCount,ePos) {

 line = gMovieFiles[idx];





 if (extractEpisode(line,idx,details)) {
 INFO("Found TV info in file name:"line);
 } else {
 DEBUG("failed level 0 check tv ["line"]");

 split(gFolder[idx],dirs,"/");
 dirCount=0;
 for(d in dirs) dirCount++;

 if (dirCount == 0 ) return 0;

 line=dirs[dirCount]"/"line;

 if (extractEpisode(line,idx,details)) {
 INFO("Found TV Info in dir/file:"line);
 } else {
 DEBUG("failed level 1 check tv ["line"]");
 if (dirCount == 1 ) return 0;
 line=dirs[dirCount-1]"/"line;
 if (extractEpisode(line,idx,details)) {
 INFO("Found TV Info in dir1/dir2/file:"line);
 } else {
 DEBUG("failed level 2 check tv ["line"]");
 return 0;
 }
 }
 }
 DEBUG("CONTINUE CHECK TV "line);

 adjustTitle(idx,details[TITLE],"filename");

 g_season[idx]=details[SEASON];
 g_episode[idx]=details[EPISODE];




 ePos = index(g_episode[idx],"e");
 if (ePos -1 >= 0 && ( ePos - length(g_episode[idx]) < 0 )) {
 gsub(/e/,",",g_episode[idx]);
 DEBUG("Double Episode : "g_episode[idx]);

 }


 g_category[idx] = "T";
 gAdditionalInfo[idx] = details[ADDITIONAL_INFO];



 return 1;
}

function extractEpisodeByPatterns(line,details,idx) {



 line = tolower(line);
 if (!extractEpisodeByPattern(line,0,"\\<","s[0-9][0-9]?","[/ .]?e[0-9]+e[0-9]+",details,idx)) {  # s00e00e01
 if (!extractEpisodeByPattern(line,0,"\\<","s?[0-9][0-9]?","[/ .]?[de][0-9]+[a-e]?",details,idx)) {  #s00e00 (allow d00a for BigBrother)
 if (!extractEpisodeByPattern(line,0,"\\<","[0-9][0-9]?","[/ .]?x[0-9][0-9]?",details,idx)) { #00x00
 if (!extractEpisodeByPattern(line,0,"\\<","(series|season|saison|s)[^a-z0-9]*[0-9][0-9]?","[/ .]?(e|ep.?|episode)[^a-z0-9]*[0-9][0-9]?",details,idx)) { #00x00 


 if (index(line,"x264")) {
 gsub(/\<x264\>/,"x-264",line);
 }
 if (!extractEpisodeByPattern(line,1,"[^-0-9]","([1-9]|2[1-9]|1[0-8]|[03-9][0-9])","/?[0-9][0-9]",details,idx)) { # ...name101...

 return 0;
 }
 }
 }
 }
 }


 return 1;
}

function formatDate(line,\
date,nonDate) {
 if (!extractDate(line,date,nonDate)) {
 return line;
 }
 line=sprintf("%04d-%02d-%02d",date[1],date[2],date[3]);
 return line;
}






function extractDate(line,date,nonDate,\
y4,d1,d2,d1or2,m1,m2,m1or2,d,m,y,datePart,textMonth,s) {

 textMonth = 0;
 delete date;
 delete nonDate;


 y4="20[01][0-9]";
 m2="(0[1-9]|1[012])";
 m1=d1="[1-9]";
 d2="([012][0-9]|3[01])";
 s="[-_. /]";
 m1or2 = "(" m1 "|" m2 ")";
 d1or2 = "(" d1 "|" d2 ")";

 d = m = y = 0;
 if  (match(line,y4 s m1or2 s d1or2)) {

 DEBUG("Date Format found yyyy/mm/dd");
 y=1 ; m = 2 ; d=3;

 } else if(match(line,m1or2 s d1or2 s y4)) { #us match before plain eu match

 DEBUG("Date Format found mm/dd/yyyy");
 m=1 ; d = 2 ; y=3;

 } else if(match(line,d1or2 s m1or2 s y4)) { #eu

 DEBUG("Date Format found dd/mm/yyyy");
 d=1 ; m = 2 ; y=3;

 } else if(match(line,d1or2 s "[A-Za-z]+" s y4)) { #eu

 DEBUG("Date Format found dd Month yyyy");
 d=1 ; m = 2 ; y=3;
 textMonth = 1;

 } else {

 DEBUG("No date format found");
 return 0;
 }
 datePart = substr(line,RSTART,RLENGTH);

 nonDate[1]=substr(line,1,RSTART-1);
 nonDate[2]=substr(line,RSTART+RLENGTH);

 split(datePart,date,s);
 d = date[d];
 m = date[m];
 y = date[y];

 date[1]=y;
 date[2]=tolower(m);
 date[3]=d;

 if ( textMonth == 1 ) {
 if (date[2] in gMonthConvert ) {
 date[2] = gMonthConvert[date[2]];
 } else {
 return 0;
 }

 }
 return 1;
}




function extractEpisodeByDates(idx,line,details,\
tvdbid,episodeInfo,d,m,y,date,nonDate,title,rest) {

 if (!extractDate(line,date,nonDate)) {
 return 0;
 }

 rest=nonDate[2];
 title = cleanTitle(nonDate[1]);

 y = date[1];
 m = date[2];
 d = date[3];

 INFO("Found Date y="y" m="m" d="d);


 tvdbid = search1TvDbId(idx,title);
 if (tvdbid != "") {
 fetchXML("http://thetvdb.com/api/GetEpisodeByAirDate.php?apikey="g_tk"&seriesid="tvdbid"&airdate="y"-"m"-"d,episodeInfo);
 if ( episodeInfo["/Data/Error"] != "" ) {
 ERROR(episodeInfo["/Data/Error"]);
 tvdbid="";
 }
 }
 details[TITLE]=title;
 if (tvdbid != "") {
 details[SEASON]=episodeInfo["/Data/Episode/SeasonNumber"];
 details[EPISODE]=episodeInfo["/Data/Episode/EpisodeNumber"];
 details[ADDITIONAL_INFO]=episodeInfo["/Data/Episode/EpisodeName"];

 } else {
 details[SEASON]=y;
 details[EPISODE]=sprintf("%02d%02d",m,d);
 sub(/\....$/,"",rest);
 details[ADDITIONAL_INFO]=cleanTitle(rest);
 }
 return 1;
}

function extractEpisode(line,idx,details,        d,dir) {


 if (!extractEpisodeByDates(idx,line,details)) {
 if (!extractEpisodeByPatterns(line,details,"")) {
 return 0;
 }
 }

 DEBUG("Extracted title ["details[TITLE] "]");
 if (details[TITLE] == "" ) {



 split(gFolder[idx],dir,"/"); # split folder
 for(d in dir ) { ; } # Count

 details[TITLE] = cleanTitle(dir[d]);
 DEBUG("Using parent folder for title ["details[TITLE] "]");
 sub(/(S[0-9]|Series|Season) *[0-9]+.*/,"",details[TITLE]);
 if (details[TITLE] == "" ) {

 details[TITLE] = cleanTitle(dir[d-1]);
 DEBUG("Using grandparent folder for title ["details[TITLE] "]");
 }
 }

 return 1;
}



function extractEpisodeByPattern(line,prefixReLen,prefixRe,seasonRe,episodeRe,details,idx,  \
 tmpDetails,tmpTitle,ee) {
 if (!match(line,prefixRe seasonRe episodeRe "\\>" )) {
 return 0;
 }

 DEBUG("ExtractEpisode: line["line"] re["prefixRe seasonRe episodeRe "\\>] match["substr(line,RSTART,RLENGTH)"]" );

 RSTART += prefixReLen;
 RLENGTH -= prefixReLen;

 tmpDetails[TITLE] = substr(line,1,RSTART-1);
 tmpDetails[ADDITIONAL_INFO]=substr(line,RSTART+RLENGTH);

 line=substr(line,RSTART,RLENGTH); # season episode

 if (index(tmpDetails[TITLE],":") && match(tmpDetails[TITLE],": *")) {
 tmpDetails[TITLE] = substr(tmpDetails[TITLE],RSTART+RLENGTH);
 }

 if (index(tmpDetails[TITLE],"-") && match(tmpDetails[TITLE],"^[a-z][a-z0-9]+[-]")) {
 tmpTitle=substr(tmpDetails[TITLE],RSTART+RLENGTH);
 if (tmpTitle != "" ) {
 INFO("Removed group was ["tmpDetails[TITLE]"] now ["tmpTitle"]");
 tmpDetails[TITLE]=tmpTitle;
 }
 }

 tmpDetails[TITLE] = cleanTitle(tmpDetails[TITLE]);
 
 DEBUG("ExtractEpisode: Title= ["tmpDetails[TITLE]"]");

 if (match(tmpDetails[ADDITIONAL_INFO],gExtRegExAll) ) {
 tmpDetails[EXT]=tmpDetails[ADDITIONAL_INFO];
 gsub(/\.[^.]*$/,"",tmpDetails[ADDITIONAL_INFO]);
 tmpDetails[EXT]=substr(tmpDetails[EXT],length(tmpDetails[ADDITIONAL_INFO])+2);
 }


 match(line,episodeRe "$" );
 tmpDetails[EPISODE] = substr(line,RSTART,RLENGTH); 
 tmpDetails[SEASON] = substr(line,1,RSTART-1);


 gsub(/^[^0-9]+/,"",tmpDetails[EPISODE]); #BB
 sub(/^0+/,"",tmpDetails[EPISODE]);

 gsub(/^[^0-9]+/,"",tmpDetails[SEASON]);
 sub(/^0+/,"",tmpDetails[SEASON]);


 for(ee in tmpDetails) {
 if (idx != "") {
 details[ee,idx]=tmpDetails[ee];
 } else {
 details[ee]=tmpDetails[ee];
 }
 DEBUG("tv details "g_db_field_name[ee]"."idx" = "tmpDetails[ee]);
 }
 return 1;
}



function process_scanned_files(ready_to_merge_batch_size,\
first_tv_db_entry,\
idx,file,bestUrl,bestUrlViaEpguide,scanNfo,startTime,elapsedTime,thisTime,numFiles,eta,msg,\
ready_to_merge,ready_to_merge_count,bestUrl2,itemStartTime,name,name2) {

 INFO("process_scanned_files");

 startTime = systime();
 numFiles=0;
 for ( idx in gMovieFiles) {
 numFiles++;
 }

 eta="";
 
 for ( idx = 0 ; idx - numFiles < 0 ; idx++ ) {

 msg="Indexing "(idx+1)"/"numFiles;
 itemStartTime = systime();

 if (idx - 1 > 0 ) {
 eta = int( (itemStartTime-startTime) * (numFiles-idx) / idx / 60 ) "m" ;
 msg = msg " " eta;
 }
 status(msg);

 bestUrl="";

 scanNfo=0;

 file=gMovieFiles[idx];
 if (file == "" ) continue;

 INFO("\n\t==\t==\t==\t==\t==\t==\t==\t==\t==\t==\t==\t==\t==\t==\t==\t==\t==\n");
 INFO(idx":"file);

 DEBUG("nfo check :"file);
 if (!isDvdDir(file) && !match(file,gExtRegExAll)) {
 WARNING("Skipping unknown file ["file"]");
 continue;
 }


 if (g_settings["catalog_nfo_read"] != "no") {

 if (exists(gNfoDefault[idx])) {

 DEBUG("Using default info to find url");
 scanNfo = 1;

 } else if (gFolderMediaCount[gFolder[idx]] == 1 && gFolderInfoCount[gFolder[idx]] == 1 && exists(gFolderInfoName[gFolder[idx]])) {

 DEBUG("Using single nfo "gFolderInfoName[gFolder[idx]]" to find url in folder ["gFolder[idx]"] for item "idx);

 gNfoDefault[idx] = gFolderInfoName[gFolder[idx]];
 scanNfo = 1;
 }
 }

 if (scanNfo){
 bestUrl = scanNfoForImdbLink(gNfoDefault[idx]);
 }





 if (checkTvFilenameFormat(idx)) {





 if (bestUrl != "") {


 scrapeIMDBTitlePage(idx,bestUrl);

 INFO("TODO:Need a solid route from imdb link to epguides page");
 
 bestUrlViaEpguide = getAllTvInfoAndImdbLink(idx);

 } else {

 INFO("Seach Phase: tv db");

 bestUrl = getAllTvInfoAndImdbLink(idx);
 if (bestUrl == "") {

 bestUrl=searchInternetForImdbLink(idx);
 scrapeIMDBTitlePage(idx,bestUrl);
 bestUrl2 = getAllTvInfoAndImdbLink(idx);
 } else {
 scrapeIMDBTitlePage(idx,bestUrl);
 }


 }

 } else {




 name=cleanSuffix(idx);





 if (bestUrl == "") {
 INFO("Seach Phase: usenet online nfo");
 bestUrl = searchOnlineNfoLinksForImdbAlternate(name);
 }
 if (bestUrl == "") {
 name2 = remove_format_tags(name);
 if (name2 != name) {
 bestUrl = searchOnlineNfoLinksForImdbAlternate(name2);
 }
 }



 if (bestUrl == "") {

 INFO("Seach Phase: web page + imdb");
 bestUrl=searchInternetForImdbLink(idx);
 }



 if (bestUrl != "") {

 scrapeIMDBTitlePage(idx,bestUrl);

 }

 if (index(g_poster[idx],"themoviedb") == 0 ) {
 DEBUG("pre nice poster title: "gTitle[idx]);
 g_poster[idx] = getNiceMoviePosters(extractImdbId(bestUrl));
 }
 }



 if (g_poster[idx] == "") {
 g_poster[idx] = g_imdb_poster_url[idx];
 }
 fixTitles(idx);

 get_best_episode_title(idx);

 if (g_poster[idx] != "") {

 g_poster[idx] = download_poster(g_poster[idx],idx);
 }

 relocate_files(idx);

 thisTime = systime() - itemStartTime;
 elapsedTime = systime() - startTime;

 if (g_opt_dry_run) {
 print "dryrun: "g_file[idx]" -> "gTitle[idx];
 }
 DEBUG("processed in "thisTime"s | processed "(idx+1)" items in "(elapsedTime)"s av time per item " (elapsedTime/(idx+1)) "s");


 ready_to_merge[idx]=1;

 ready_to_merge_count++
 DEBUG("ready_to_merge_batch_size = "ready_to_merge_batch_size);
 DEBUG("ready_to_merge_count = "ready_to_merge_count);
 if (ready_to_merge_batch_size != 0 ) {
 if ( ready_to_merge_count - ready_to_merge_batch_size > 0 ) {
 merge_subset_of_scanned_files(ready_to_merge);
 delete ready_to_merge;
 ready_to_merge_count=0;
 }
 }
 }
 if (ready_to_merge_count) {
 merge_subset_of_scanned_files(ready_to_merge);
 delete ready_to_merge;
 ready_to_merge_count=0;
 }
}

function cleanSuffix(idx,\
name) {
 name=gMovieFiles[idx];

 sub(/\.[^.]+$/,"",name);


 if (gParts[idx] != "" ) {

 sub(/(|cd|part)[1a]$/,"",name);
 }
 name=trimAll(name);
 return name;
}





function searchOnlineNfoLinksForImdbAlternate(name,\
choice,i,url) {
 g_nfo_search_choices = 2;
 g_search_total["online_nfo"]++;

 for(i = 0 ; i - g_nfo_search_choices < 0 ; i++ ) {

 g_nfo_search_engine_sequence++;
 choice = g_nfo_search_engine_sequence % g_nfo_search_choices ;



 if (choice == 0 ) {


 url = searchOnlineNfoLinksForImdb(name,\
 "http://www.bintube.com",\
 "/?q=\"QUERY\"",\
 "/nfo/pid/[^\"]+",20);

 } else if (choice == 1 ) {


 url = searchOnlineNfoLinksForImdb(name,\
 "https://www.binsearch.info",\
 "/index.php?q=\"QUERY\"&max=50&adv_age=999&adv_sort=date&adv_col=on&adv_nfo=on&postdate=on",\
 "/viewNFO[^\"]+",20);



#





 }
 if (url != "") {
 g_search_hits["online_nfo"]++
 break;
 }
 }
 return url;
}






function searchOnlineNfoLinksForImdb(name,domain,queryPath,nfoPathRegex,maxNfosToScan,
nfo,nfo2,nfoPaths,imdbIds,totalImdbIds,bestId,wgetWorksWithMultipleUrlRedirects,id) {

 INFO("Online nfo search for "name);

 sub(/QUERY/,name,queryPath);


 scanPageForMatches(domain queryPath,nfoPathRegex,maxNfosToScan,1,"",nfoPaths);




 wgetWorksWithMultipleUrlRedirects=0;
 if (wgetWorksWithMultipleUrlRedirects) {
 nfo2="";
 for(nfo in nfoPaths) {
 nfo2 = nfo2 "\t" domain nfo;
 }
 sub(/[&]amp;/,"\\&",nfo2);
 scanPageForMatches(nfo2, g_imdb_regex ,0,1,"", imdbIds);
 for(id in imdbIds) {
 totalImdbIds[id] += imdbIds[id];
 }
 } else {
 for(nfo in nfoPaths) {
 nfo2 = domain nfo;
 sub(/[&]amp;/,"\\&",nfo2);
 scanPageForMatches(nfo2, g_imdb_regex ,0,1,"", imdbIds);
 for(id in imdbIds) {
 totalImdbIds[id] += imdbIds[id];
 }
 }
 }


 bestScores(totalImdbIds,totalImdbIds,0);
 bestId = firstIndex(totalImdbIds);
 INFO("best imdb link ["domain"] = "bestId);
 return extractImdbLink(bestId);

}

function firstIndex(inHash,i) {
 for (i in inHash) return i;
}

function firstDatum(inHash,i) {
 for (i in inHash) return inHash[i];
}



function bestScores(inHash,outHash,textMode,\
i,bestScore,count,tmp,isHigher) {
 
 dump(2,"pre best",inHash);
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

 delete outHash;
 for(i in tmp) {
 outHash[i] = tmp[i];
 count++;
 }
 dump(1,"post best",outHash);
 return count;
}


function scanNfoForImdbLink(nfoFile,\
foundId,line) {

 foundId="";
 INFO("scanNfoForImdbLink ["nfoFile"]");
 g_search_total["nfo"]++;

 if (system("test -f "quoteFile(nfoFile)) == 0) {
 FS="\n";
 while(foundId=="" && (getline line < nfoFile) > 0 ) {

 foundId = extractImdbLink(line);

 }
 close(nfoFile);
 }
 if (foundId) g_search_hits["nfo"]++;
 INFO("scanNfoForImdbLink = ["foundId"]");
 return foundId;
}




function getAllInfoFromTvDbAndImdbLink(idx,title,\
tvDbSeriesPage,alternateTitles) {

 if (title == "") {
 title=gTitle[idx];
 }
 DEBUG("Checking existing mapping for ["title"]");
 tvDbSeriesPage = g_tvDbIndex[title];

 DEBUG("getAllInfoFromTvDbAndImdbLink: intial="tvDbSeriesPage);

 if (tvDbSeriesPage == "" && index(gExternalSourceUrl[idx],"imdb")  ) {
 tvDbSeriesPage = getTvdbSeriesUrl(searchTvDbByImdbId(extractImdbId(gExternalSourceUrl[idx])));
 DEBUG("getAllInfoFromTvDbAndImdbLink: byimdb="tvDbSeriesPage);
 }

 if (tvDbSeriesPage == "" ) {
 g_search_total["thetvdb"]++;
 DEBUG("Checking TvDvTitles for ["title"]");

 tvDbSeriesPage = searchTvDbTitles(idx,title);
 DEBUG("getAllInfoFromTvDbAndImdbLink: bytitles="tvDbSeriesPage);
 if (tvDbSeriesPage) g_search_hits["thetvdb"]++;
 }

 if (tvDbSeriesPage == "" ) {
 g_search_total["tvabbrev"]++;
 searchAbbreviationAgainstTitles(title,alternateTitles);

 if (filterTitlesByTvDbPresence(alternateTitles,"FirstAired,Overview",alternateTitles) - 1 > 0 ) {

 filterTitlesFoundOnUsenetWithSpecificText(alternateTitles,cleanSuffix(idx),alternateTitles);

 }

 title = selectBestOfBestTitle(idx,alternateTitles);

 tvDbSeriesPage = searchTvDbTitles(idx,title);

 if (tvDbSeriesPage) g_search_hits["tvabbrev"]++;
 }

 if (tvDbSeriesPage == "" ) {
 WARNING("getAllInfoFromTvDbAndImdbLink could not find series page");
 return "";
 } else {
 g_tvDbIndex[title]=tvDbSeriesPage;
 DEBUG("getAllInfoFromTvDbAndImdbLink Search looking at "tvDbSeriesPage);
 return getTvDbInfo(idx,tvDbSeriesPage);
 }
}




function searchAbbreviationAgainstTitles(abbrev,alternateTitles,\
initial,i,tmp) {

 delete alternateTitles;

 if (index(abbrev," ") == 0) {

 INFO("Seach Phase: epguid abbreviations");


 if (abbrev in g_abbrev_cache) {
 INFO("Retrived abbreviation "abbrev" from cache");
 split(g_abbrev_cache[abbrev],tmp,"\t");
 for(i in tmp) {
 alternateTitles[tmp[i]] = 1;
 }
 } else {

 initial = epguideInitial(abbrev);
 searchAbbreviation(initial,abbrev,alternateTitles);



 if (initial == "t" ) {
 initial = epguideInitial(substr(abbrev,2));
 if (initial != "t" ) {
 searchAbbreviation(initial,abbrev,alternateTitles);
 }
 }

 INFO("Saved abbreviation "abbrev" to cache");
 for(i in alternateTitles) {
 g_abbrev_cache[abbrev]=g_abbrev_cache[abbrev]"\t"i;
 }
 g_abbrev_cache[abbrev]=substr(g_abbrev_cache[abbrev],2);
 }
 }
 dump(0,"abbrev["abbrev"]",alternateTitles);
}

function copyHash(a1,a2,i) {
 delete a1 ; mergeHash(a1,a2) ;
}
function mergeHash(a1,a2,i) {
 for(i in a2) a1[i] = a2[i];
}
function addHash(a1,a2,i) {
 for(i in a2) a1[i] += a2[i];
}

function search1TvDbId(idx,title,\
closeTitles,best) {

 searchTvDb(title,"FirstAired,Overview",closeTitles);


 best = selectBestOfBestTitle(idx,closeTitles);
 return best;
}





#



function filterTitlesFoundOnUsenetWithSpecificText(titles,filterText,filteredTitles,\
result) {
 result = filterTitlesFoundOnUsenetEngineWithSpecificText(titles,"http://binsearch.info/?max=25&adv_age=&q=\""filterText"\" QUERY",filteredTitles);
 if (result == 0 ) {
 result = filterTitlesFoundOnUsenetEngineWithSpecificText(titles,"http://bintube.com/?q=\""filterText"\" QUERY",filteredTitles);
 }
 return result;
}





function filterTitlesFoundOnUsenetEngineWithSpecificText(titles,usenet_query_url,filteredTitles,\
t,count,tmpTitles,origTitles,dummy,baseline,found,query,baseline,link_count) {

 found = 0;
 dump(2,"pre-usenet",titles);


 copyHash(origTitles,titles);


 dummy=rand()systime()rand();
 query = usenet_query_url;
 sub(/QUERY/,dummy,query);
 baseline = scanPageForMatches(query,"</[Aa]>",0,1,"",tmpTitles);

 DEBUG("number of links for no match "baseline);

 for(t in titles) {

 query = usenet_query_url;
 sub(/QUERY/,t,query);
 link_count = scanPageForMatches(query,"</[Aa]>",0,1,"",tmpTitles);
 DEBUG("number of links "link_count);
 if (link_count-baseline > 0) {
 count[t] = link_count;
 found=1;
 }
 }

 if (found) {

 bestScores(count,count,0);


 delete filteredTitles;
 for(t in count) {
 filteredTitles[t] = origTitles[t];
 }
 INFO("best titles on usenet using "usenet_query_url);
 dump(0,"post-usenet",filteredTitles);
 } else {
 INFO("No results found using "usenet_query_url);
 }
 return found;
}













function getRelativeAge(idx,titleHash,ageHash,\
id,xml) {
 for(id in titleHash) {
 if (g_category[idx] == "T") {
 getTvDbEpisodeXML(getTvdbSeriesUrl(id),g_season[idx],g_episode[idx],xml);
 ageHash[id] = xml["/Data/Episode/FirstAired"];
 } else {

 ageHash[id] = id;
 }
 }
 dump(1,"Age indicators",ageHash);
 }












function selectBestOfBestTitle(idx,titles,\
id,bestId,bestFirstAired,firstAired,ages,count) {
 INFO("TODO:Refine selection rules here. May user should choose");
 for(id in titles) count++;

 if (count = 1) {
 bestId = id;
 } else {
 dump(1,"closely matched titles",titles);

 INFO("For now just getting the most recent first aired for "idx" "g_category[idx]);
 bestFirstAired="";

 getRelativeAge(idx,titles,ages);

 bestScores(ages,ages,1);

 bestId = firstIndex(ages);

 }
 INFO("Selected:"bestId" = "titles[bestId]);
 return bestId;
}









function filterTitlesByTvDbPresence(titleInHash,requiredTags,titleOutHash,\
bestScore,bestTitles,potentialTitle,potentialMatches,origTitles,titleScore,count) {
 bestScore=-1;
 count=0;

 dump(0,"pre tvdb check",titleInHash);


 copyHash(origTitles,titleInHash);

 for(potentialTitle in titleInHash) {
 titleScore[potentialTitle] = searchTvDb(potentialTitle,requiredTags,potentialMatches);
 }
 bestScores(titleScore,titleScore,0);


 delete titleOutHash;
 for(potentialTitle in titleScore) {
 titleOutHash[potentialTitle] = origTitles[potentialTitle];
 count++;
 }
 dump(0,"post tvdb check",titleOutHash);
 return count;
}






function searchTvDb(title,requiredTagList,closeTitles,\
allTitles,f,line,info,bestId,currentId,currentName,requiredTagNames,add,i) {

 delete closeTitles;
 bestMatchLevel = 0;
 DEBUG("Checking ["title"] against list "menuUrl);

 split(requiredTagList,requiredTagNames,",");

 f = getUrl("http://thetvdb.com//api/GetSeries.php?seriesname="title,"tvdb_idx",1);
 if (f != "") {
 FS="\n";
 while((getline line < f) > 0 ) {



 if (index(line,"<Series>") > 0) {

 delete info;
 }

 parseXML(line,info);

 if (index(line,"</Series>") > 0) {

 dump(2,"xmlinfo",info);

 currentName = info["/Series/SeriesName"];

 currentId = info["/Series/seriesid"];

 add=1;
 for( i in requiredTagNames ) {
 if (! ( "/Series/"requiredTagNames[i] in info ) ) {
 DEBUG("["currentName"] rejected due to missing "requiredTagNames[i]" tag");
 add=0;
 break;
 }
 }

 if (add) {
 allTitles[currentId] = currentName;
 }
 delete info;

 }
 }
 close(f);
 }
 dump(1,"search["title"]",allTitles);

 return filterSimilarTitles(title,allTitles,closeTitles);
}

function dump(lvl,label,array,\
i) {
 if (DBG-lvl >= 0) for(i in array) DEBUG(label":"i"=["array[i]"]");
}



function searchTvDbByImdbId(id,\
url,id2) {

 if (id) {
 url = "http://thetvdb.com/index.php?imdb_id="id"&order=translation&searching=Search&tab=advancedsearch";
 id2 = scanPageForMatch(url,"id=[0-9]+[&\"]",1);
 if (id2 != "" ) {
 id2=substr(id2,4,length(id2)-4);
 DEBUG("imdb id "id" => tvdb id "id2);
 } else {
 DEBUG("imdb id "id" not found in tvdb");
 }
 }
 return id2;
}

function searchTvDbTitles(idx,title,\
tvdbid,tvDbSeriesUrl) {

 tvdbid = search1TvDbId(idx,title);
 if (tvdbid != "") {
 tvDbSeriesUrl=getTvdbSeriesUrl(tvdbid);
 }

 DEBUG("Endpage with url = ["tvDbSeriesUrl"]");
 return tvDbSeriesUrl;
}

function getTvdbSeriesUrl(tvdbid) {
 if (tvdbid != "") {
 return "http://thetvdb.com/api/"g_tk"/series/"tvdbid"/en.xml";
 } else {
 return "";
 }
}



function fetchXML(url,label,xml,\
f,line) {
 f=getUrl(url,label,1);
 if (f != "" ) {
 FS="\n";
 while((getline line < f) > 0 ) {
 parseXML(line,xml);
 }
 close(f);
 }
}


function parseXML(line,info,\
currentTag,start,i,tag,text,lines,parts) {


 gsub(/\r/,"",line);
 gsub(/\n/,"",line);



 split(line,lines,"<");

 previousTag = info["@LAST"];
 currentTag = info["@CURRENT"];

 start=1;
 if (substr(line,1,1) != "<") {

 info[currentTag] = info[currentTag] lines[1];
 start = 2;
 }

 for(i = start ; i in lines ; i++ ) {

 previousTag = "";

 split(lines[i],parts,">");
 tag = parts[1];
 sub(/ .*/,"",tag); #Remove attributes Possible bug if space before element name
 text = parts[2];

 if (tag ~ /^\/?[A-Za-z0-9_]+$/ ) {

 if ( substr(tag,1,1) == "/" ) {

 previousTag = currentTag;
 sub(tag"$","",currentTag);

 } else {
 previousTag = currentTag;
 currentTag = currentTag "/" tag;
 }
 } else {


 info[currentTag] = info[currentTag] tag;
 }

 info[currentTag] = info[currentTag] text;




 }
 info["@CURRENT"] = currentTag;
 info["@LAST"] = previousTag;
}





function similarTitles(titleIn,possibleTitleIn,\
bPos,cPos,yearOrCountry,matchLevel,shortName,tmp,possibleTitle) {

 matchLevel = 0;
 yearOrCountry="";

 DEBUG("Checking ["titleIn"] against ["possibleTitleIn"]");

 if ((bPos=index(possibleTitleIn," (")) > 0) {
 yearOrCountry=cleanTitle(substr(possibleTitleIn,bPos+2));
 DEBUG("Qualifier "yearOrCountry);
 }

 if ((cPos=index(possibleTitleIn,",")) > 0) {
 shortName=cleanTitle(substr(possibleTitleIn,1,cPos-1));
 }

 possibleTitle=cleanTitle(possibleTitleIn);

 sub(/^[Tt]he /,"",possibleTitle);
 sub(/^[Tt]he /,"",titleIn);

 if (substr(titleIn,2) == substr(possibleTitle,2)) {
 DEBUG("Checking ["titleIn"] against ["possibleTitle"]");
 }
 if (yearOrCountry != "") {
 DEBUG("Qualified title "possibleTitleIn);
 }
 if (index(possibleTitle,titleIn) == 1) {
 matchLevel = 1;


 if (possibleTitle == titleIn) {

 matchLevel=5;




 if (yearOrCountry != "") {
 matchLevel=10;
 }

 } else  if (titleIn == shortName) {

 matchLevel=5;



 } else if ( possibleTitle == titleIn " " yearOrCountry ) {
 INFO("match for ["titleIn"+"yearOrCountry"] against ["possibleTitle"]");



 matchLevel = 5;
 } else {
 DEBUG("No match for ["titleIn"+"yearOrCountry"] against ["possibleTitle"]");
 }
 } else if (index(titleIn,possibleTitle) == 1) {

 matchLevel = 1;
 diff=substr(titleIn,length(possibleTitle)+1);
 if ( diff ~ " (19|20)[0-9][0-9]$" || diff ~ " (uk|us|au|nz|de|fr)" ) {

 matchLevel = 5;
 INFO("match for ["titleIn"] containing ["possibleTitle"]");
 }
 }
 DEBUG("["titleIn"] vs ["possibleTitle"] = "matchLevel);
 return matchLevel;
}







function filterSimilarTitles(title,titleHashIn,titleHashOut,\
i,score,bestScore,tmpTitles) {


 copyHash(tmpTitles,titleHashIn);


 for(i in titleHashIn) {
 score[i] = similarTitles(title,titleHashIn[i]);
 }


 bestScores(score,titleHashOut,0);


 for(i in titleHashOut) {
 titleHashOut[i] = tmpTitles[i];
 }
 bestScore = score[firstIndex(titleHashOut)];
 if (bestScore == "" ) bestScore = -1;
 DEBUG("Filtered titles with score = "bestScore);

 dump(0,"filtered["title"]=",titleHashOut);
 return bestScore;
}


function getEpguideNames(letter,names,\
url,count,title,link,links,i,count2) {
 url = "http://epguides.com/menu"letter;

 scanPageForMatches(url,"<li>(|<b>)<a.*</li>",0,1,"",links);
 count2 = 0;

 for(i in links) {

 if (index(i,"[radio]") == 0) {

 title = extractTagText(i,"a");



 if (title != "") {
 link = extractAttribute(i,"a","href");
 sub(/\.\./,"http://epguides.com",link);
 gsub(/\&amp;/,"And",title);
 names[link] = title;
 count2++;


 }
 }
 }
 DEBUG("Loaded "count2" names");
 return count2;
}






function searchAbbreviation(letter,titleIn,alternateTitles,\
tmp,possibleTitle,f,names,links,i,ltitle) {

 ltitle = tolower(titleIn);

 DEBUG("Checking "titleIn" for abbeviations on menu page - "letter);

 getEpguideNames(letter,names);

 for(i in names) {

 possibleTitle = names[i];

 sub(/\(.*/,"",possibleTitle);

 possibleTitle = trim(possibleTitle);

 tmp = abbrevTwoOrMoreInitials(possibleTitle);
 if (tmp != "" && ltitle == tmp) {
 alternateTitles[possibleTitle]=1;
 }




 tmp =abbrevInitialThenWord(possibleTitle); 
 if (tmp != "" && ltitle == tmp) {
 alternateTitles[possibleTitle]=1;
 }


 tmp =abbrevWordThenInitial(possibleTitle); 
 if (tmp != "" && ltitle == tmp) {
 alternateTitles[possibleTitle]=1;
 }


 tmp =abbrevRemoveDoubleVowel(possibleTitle); 
 if (tmp != "" && ltitle == tmp) {
 alternateTitles[possibleTitle]=1;
 }






 possibleTitle="";
 }
}








#

#

#




#

#
#





function abbrevInitialThenWord(text,\
spacePos,abbr) {
 spacePos = index(text," ");

 if (spacePos == 0) {
 return "";
 }

 if (text ~ / [^ ]+ /) {
 return "";
 }
 if (spacePos*2 - length(text) < 0) {

 return "";
 }
 abbr = tolower(substr(text,1,1) substr(text,spacePos+1));
 DEBUG2(text"|"abbr);
 return abbr;
}



function abbrevWordThenInitial(text,\
spacePos,abbr) {
 text = tolower(text);
 spacePos = index(text," ");

 if (spacePos == 0) {
 return "";
 }

 if (substr(text,1,4) == "the ") {
 return "";
 }

 if (text ~ / [^ ]+ /) {
 return "";
 }




 abbr = substr(text,1,spacePos-1) substr(text,spacePos+1,1);
 DEBUG2(text"|"abbr);
 return abbr;
}


function threeWordInitials(text,\
abbr) {
 abbr=tolower(text);
 if (abbr !~ / [^ ]+ /) {
 return "";
 }
 while(match(abbr,"[a-z][a-z]+")) {
 abbr = substr(abbr,1,RSTART-1) " " substr(abbr,RSTART,1) " " substr(abbr,RSTART+RLENGTH+1);
 }
 gsub(/ +/,"",abbr);
 DEBUG2(text"|"abbr);
 return abbr;
}


function abbrevTwoOrMoreInitials(text,\
abbr) {
 abbr=tolower(text);
 if (index(abbr," ") ==0) {
 return "";
 }
 while(match(abbr,"[a-z][a-z]+")) {
 abbr = substr(abbr,1,RSTART-1) " " substr(abbr,RSTART,1) " " substr(abbr,RSTART+RLENGTH+1);
 }
 gsub(/ +/,"",abbr);
 DEBUG2(text"|"abbr);
 return abbr;
}


function abbrevRemoveDoubleVowel(text,\
abbr) {
 if (index(text," ")) {
 return "";
 }
 sub(/[aeiouAEIOU][aeiouAEIOU]/,"",text);
 abbr = tolower(text);
 DEBUG2(text"|"abbr);
 return abbr;
}



function getAllTvInfoAndImdbLink(idx,title) {

 return getAllInfoFromTvDbAndImdbLink(idx,title);
}

function getAllInfoFromEpguidesAndImdbLink(idx,title,\
epguideSeriesPage,url,alternateTitles,i) {

 if (title == "") {
 title=gTitle[idx];
 }
 epguideSeriesPage = gEpguideIndex[title];

 if (epguideSeriesPage != "" ) {
 DEBUG("Using existing mapping for ["title"]="epguideSeriesPage);
 } else {

 epguideSeriesPage = searchEpguideTitles(idx,title,1);
 }

 if (epguideSeriesPage == "" ) {
 searchAbbreviationAgainstTitles(title,alternateTitles);




 for(i = 1 ; epguideSeriesPage == "" && (i in alternateTitles) ; i++ ) {
 DEBUG("Checking possible abbreviation "alternateTitles[i]);
 epguideSeriesPage = searchEpguideTitles(idx,alternateTitles[i],1);
 if (epguideSeriesPage != "") {
 gEpguideIndex[alternateTitles[i]] = epguideSeriesPage;
 }

 }
 }

 if (epguideSeriesPage == "" ) {
 WARNING("getAllInfoFromEpguidesAndImdbLink could not find series page");
 return "";
 } else {

 gEpguideIndex[title] = epguideSeriesPage;

 return getEpguideInfo(idx,epguideSeriesPage);
 }
}

function epguideInitial(title,\
letter) {

 sub(/^[Tt]he /,"",title);
 letter=tolower(substr(title,1,1));


 if (match(title,"^10") ) {
 letter = "t";
 } else if (match(title,"^11") ) {
 letter = "e";
 } else if (match(title,"^1[2-9]") ) {
 letter = substr(title,2,1);
 }

 if ( letter == "1" ) {
 letter = "o";
 }else if (match(letter,"^[23]")  ) {
 letter = "t";
 }else if (match(letter,"^[45]") ) {
 letter = "f";
 }else if (match(letter,"^[67]") ) {
 letter = "s";
 }else if ( letter == "8" ) {
 letter = "e";
 }else if ( letter == "9" ) {
 letter = "n";
 }
 return letter;
}


function searchEpguideTitles(idx,title,attempt,\
 letter,names,namess2,epguideSeriesUrl) {


 DEBUG("Search of epGuide titles for ["title"]");



 letter = epguideInitial(title);

 if (match(letter,"[a-z]")) {

 DEBUG("Checking ["title"] against list "letter);
 getEpguideNames(letter,names);

 filterSimilarTitles(title,names,names2);



 epguideSeriesUrl = selectBestOfBestTitle(idx,names2);

 DEBUG("Endpage with url = ["epguideSeriesUrl"]");

 return epguideSeriesUrl;

 } else {
 WARNING("Could not resolve title [" title "] on attempt "attempt);
 return "";
 }
}

function cleanTitle(t) {
 if (index(t,"&") && index(t,";")) {
 gsub(/[&]amp;/,"and",t);
 t = html_decode(t);
 gsub(/[&][a-z0-9]+;/,"",t);
 }
 gsub(/[&]/," and ",t);
 gsub(/['"'"']/,"",t);




 while (match(t,"\\<[A-Za-z]\\>\.\\<[A-Za-z]\\>")) {
 t = substr(t,1,RSTART) "@@" substr(t,RSTART+2);
 }
 gsub(/@@/,"",t);

 gsub(/[^A-Za-z0-9]+/," ",t);
 gsub(/ +/," ",t);
 t=trim(caps(tolower(t)));
 return t;
}

function searchForBestTitleSubstring(query,threshold,\
titles) {
 getTitlesFromGoogle(query,titles);
 return get_frequent_substring(titles,threshold);
}

function de_emphasise(html) {
 gsub(/<(\/|)(b|em|strong|wbr)>/,"",html); #remove emphasis tags
 gsub(/<[^\/][^<]+[\/]>/,"",html); #remove single tags eg <wbr />
 return html;
}



function getTitlesFromGoogle(query,titles,\
f,h3pos,i,pos,html,h3txt ) {
 i=0;
 split("",titles,""); #clear

 f = web_search_to_file(g_title_search_engines,query,"","search4words",1);
 if (f != "") {

 FS="\n";
 while((getline html < f) > 0 ) {

 html = de_emphasise(html);




 if ((pos=index(html,">Results for:")) > 0 ) {
 delete titles;
 html = substr(html,pos);
 }



 while((pos=index(html,"<h3")) > 0) {
 html=substr(html,pos);
 h3pos=index(html,"</h3>");
 h3txt=substr(html,1,h3pos);
 html=substr(html,h3pos+4);


 h3txt = tolower(extractTagText(h3txt,"a"));

 h3txt = remove_format_tags(h3txt);

 if (h3txt != "" ) {
 titles[i++] = h3txt;
 }
 }
 }
 close(f);
 rm(f,1);
 }
}




function getMax(arr,requiredThreshold,requireDifferenceSquared,dontRejectCloseSubstrings,\
maxValue,maxName,best,nextBest,nextBestName,diff,i,threshold,msg) {
 nextBest=0;
 maxName="";
 best=0;
 for(i in arr) {
 msg="Score: "arr[i]" for ["i"]";
 if (arr[i]-best >= 0 ) {
 if (maxName == "") {
 INFO(msg": first value ");
 } else {
 INFO(msg":"(arr[i]>best?"beats":"matches")" current best of " best " held by ["maxName"]");
 }
 nextBest = best;
 nextBestName = maxName;
 best = threshold = arr[i];
 maxName = i;

 } else if (arr[i]-nextBest >= 0 ) {

 INFO(msg":"(arr[i]>nextBest?"beats":"matches")" current next best of " nextBest " held by ["nextBestName"]");
 nextBest = arr[i];
 nextBestName = i;
 INFO(msg": set as next best");

 } else {
 INFO(msg);
 }
 }
 DEBUG("Best "best"*"arr[i]". Required="requiredThreshold);

 if (0+best < 0+requiredThreshold ) {
 DEBUG("Rejected as "best" does not meet requiredThreshold of "requiredThreshold);
 return "";
 }
 if (requireDifferenceSquared ) {
 diff=best-nextBest;
 DEBUG("Next best count = "nextBest" diff^2 = "(diff*diff));
 if (diff * diff - best  >= 0 ) {

 return maxName;

 } else if (dontRejectCloseSubstrings && (index(maxName,nextBestName) || index(nextBestName,maxName))) {

 DEBUG("Match permitted as next best is a substring");
 return maxName;

 } else {

 DEBUG("But rejected as "best" too close to next best "nextBest" to be certain");
 return "";

 }
 } else {
 return maxName;
 }
}









function search_url(search_engines,q,num) {

 ++g_web_search_count;
 if (!(g_web_search_count in search_engines )) g_web_search_count=1;
 if (search_engines[g_web_search_count] == "google") {
 return "http://www.google.com/search?q="q; # (num==""?"":"&num="num);
 } else if (search_engines[g_web_search_count] == "googleie") {
 return "http://www.google.ie/search?q="q; # (num==""?"":"&num="num);
 } else if (search_engines[g_web_search_count] == "yahoouk") {
 return "http://uk.search.yahoo.com/search?p="q; # (num==""?"":"&n="num);
 } else if (search_engines[g_web_search_count] == "yahoo") {
 return "http://search.yahoo.com/search?p="q; # (num==""?"":"&n="num);
 } else if (search_engines[g_web_search_count] == "msn") {
 gsub(/inurl%/,"site%",q);
 return "http://search.msn.com/results.aspx?q="q;
 } else if (search_engines[g_web_search_count] == "msnuk") {
 gsub(/inurl%/,"site%",q);
 return "http://search.msn.co.uk/results.aspx?q="q;
 } else {
 ERROR("Unknown search engine "g_web_search_count" ["search_engines[g_web_search_count]"]");
 exit;
 }
}


function searchForIMDB(keywords,linkThreshold) {


 return scanGoogleForBestMatch(g_link_search_engines,keywords"+%2Bimdb+%2Btitle+-inurl%3Aimdb.com+-inurl%3Aimdb.de",g_imdb_regex,"search4imdb",linkThreshold);
}


function web_search_to_file(search_engines,keywords,num,label,cache,\
f,x) {
 for(x in search_engines) {
 f = getUrl(search_url(search_engines,keywords,num),label,cache);
 if (f != "") {
 return f;
 }
 }
 return "";
}









function scanGoogleForBestMatch(search_engines,keywords,pattern,captureLabel,threshold,\
f,iurl,start,nextStart,matchList,bestUrl,x,html) {

 f = web_search_to_file(search_engines,keywords,20,captureLabel,0);
 if (f != "") {
 FS="\n";

 DEBUG("Looking for "pattern" in "f);

 while((getline html < f) > 0 ) {


 html = de_emphasise(html);












 start=0;


 while (match(substr(html,start+1),pattern) > 0) {
 
 iurl=substr(html,start+RSTART,RLENGTH);
 nextStart=start+RSTART+RLENGTH;

 DEBUG("Possible match "iurl);

 if ( matchList[iurl] == "" ) {
 matchList[iurl]=0;
 }
 matchList[iurl]++;

 start = nextStart;

 }
 }
 close(f);
 }


 bestUrl=getMax(matchList,threshold,1,0);
 if (bestUrl != "") {
 return extractImdbLink(bestUrl);
 } else  {
 return "";
 }
}



function getTvDbEpisodeXML(seriesUrl,season,episode,episodeInfo) {
 delete episodeInfo;

 if (sub(/en.xml$/,"default/"season"/"(episode+0)"/en.xml",seriesUrl)) {
 fetchXML(seriesUrl,"thetvdb-episode",episodeInfo);
 dump(0,"episode-xml",episodeInfo);
 } else {
 INFO("cant determine episode url from "seriesUrl);
 }
}




function getTvDbInfo(idx,tvDbSeriesUrl,\
seriesInfo,episodeUrl,episodeInfo,imdbLink,bannerApiUrl) {


 gEpGuides[idx]=tvDbSeriesUrl;


 fetchXML(tvDbSeriesUrl,"thetvdb-series",seriesInfo);

 bannerApiUrl = episodeUrl = tvDbSeriesUrl;


 sub(/en.xml/,"banners.xml",bannerApiUrl);

 DEBUG("Episode=["g_episode[idx]"] = "(g_episode[idx] ~ "^[0-9,]+$" ));

 if (g_episode[idx] ~ "^[0-9,]+$" ) {

 getTvDbEpisodeXML(tvDbSeriesUrl,g_season[idx],g_episode[idx],episodeInfo);

 }

 if (gExternalSourceUrl[idx]=="" ) {

 imdbLink = extractImdbLink(seriesInfo["/Data/Series/IMDB_ID"]);
 }


 adjustTitle(idx,seriesInfo["/Data/Series/SeriesName"],"thetvdb");

 g_year[idx] = substr(seriesInfo["/Data/Series/FirstAired"],1,4);

 gAirDate[idx]=formatDate(episodeInfo["/Data/Episode/FirstAired"]);

 gEpTitle[idx]=episodeInfo["/Data/Episode/EpisodeName"];

 g_plot[idx] = seriesInfo["/Data/Series/Overview"];
 g_genre[idx] = seriesInfo["/Data/Series/Genre"];
 gCertRating[idx] = seriesInfo["/Data/Series/ContentRating"];
 g_rating[idx] = seriesInfo["/Data/Series/Rating"];

 g_poster[idx] = getTvDbSeasonBanner(bannerApiUrl,g_season[idx]);
 if (g_poster[idx] == "" ) {
 g_poster[idx] = tvDbImageUrl(seriesInfo["/Data/Series/poster"]);
 DEBUG("Series poster = "g_poster[idx]);
 }

 if (imdbLink == "" ) {
 WARNING("getTvDbInfo returns blank imdb url");
 return "";
 return "IGNORE";
 } else {
 DEBUG("getTvDbInfo returns imdb url ["imdbLink"]");
 }
 return imdbLink;
}

function tvDbImageUrl(path) {
 if(path != "") {
 return "http://images.thetvdb.com/banners/_cache/" path;
 } else {
 return "";
 }
}

function getTvDbSeasonBanner(bannerApiUrl,season,\
f,line,url,xml) {
 url = "";
 f = getUrl(bannerApiUrl,"banners",1);
 if (f != "") {
 while((getline line < f) > 0 ) {

 if (index(line,"<Banner>") ) {
 delete xml;
 }

 parseXML(line,xml);

 if (index(line,"</Banner>") ) {

 if (xml["/Banner/BannerType"] == "season" && xml["/Banner/Season"]+0 == season+0 ) {
 url = tvDbImageUrl(xml["/Banner/BannerPath"]);
 DEBUG("Season URL = "url);
 break;
 }
 delete xml;
 }

 }
 close(f);
 }
 DEBUG("Season banner = "url);
 return url;
}


function getEpguideInfo(idx,epguideSeriesUrl,\
f,newTitle,imdbLink,imdbLinkAndText,i,j,line,text2,hyp2,episodeTextHyphen,episodeText,dirName) {


 gEpGuides[idx]=epguideSeriesUrl;

 episodeText=sprintf(" %d-%2d ",g_season[idx],(g_episode[idx]+0));
 episodeTextHyphen=index(episodeText,"-");

 f=getUrl(epguideSeriesUrl,"epguide_nfo",1);

 if (f != "" ) {

 FS="\n";
 while((getline line < f) > 0 ) {



 if (gExternalSourceUrl[idx]=="" ) {

 if (imdbLinkAndText=="" && index(line,"imdb") && match(line,"<a[^<]+imdb[^<]+</a>")) {

 imdbLinkAndText=substr(line,RSTART,RLENGTH);

 imdbLink=extractImdbLink(imdbLinkAndText);


 newTitle=trim(caps(extractTagText(imdbLinkAndText,"a")));
 adjustTitle(idx,newTitle,"epguides");




 imdbLink = extractImdbEpisode(idx,imdbLink,0);
 }

 }



 hyp2=index(line,"-");
 if (hyp2 - 20 < 0 && ( hyp2 - episodeTextHyphen >= 0 ) ) {
 text2=substr(line,hyp2-episodeTextHyphen+1,length(episodeText));


 if (episodeText == text2) {

 gProdCode[idx]=trim(substr(line,14,9));

 g_year[idx]=1900+substr(line,35,2);
 if (g_year[idx] - 1920 < 0 ) { g_year[idx] += 100; } 

 gAirDate[idx]=formatDate(substr(line,28,9));

 gTvCom[idx]=extractAttribute(line,"a","href");

 gEpTitle[idx]=extractTagText(line,"a");

 DEBUG("Found Episode title ["gEpTitle[idx]"]");
 }
 }





 if (index(gEpGuides[idx],".search.") && (i=index(line,"DirName"))>0) {

 i += 8;
 line = substr(line,i);
 j=index(line,"\"");
 dirName=substr(line,1,j-1);

 gEpGuides[idx]="http://epguides.com/"dirName;

 }
 if ( g_poster[idx] == "" && g_settings["catalog_tv_poster_source"] == "epguides" ) {
 if (match(line,"<img[^<]+([Cc]ast|[Ss]how)[^<]+>")) {
 g_poster[idx] = gEpGuides[idx]"/"extractAttribute(substr(line,RSTART,RLENGTH),"img","src");
 }
 }
 if (index(line,"botnavbar")) {
 break;
 }
 }
 close(f);
 }
 if (imdbLink == "" ) {
 WARNING("getEpguideInfo returns blank imdb url");
 } else {
 DEBUG("getEpguideInfo returns imdb url ["imdbLink"]");
 }
 return imdbLink;
}



function adjustTitle(idx,newTitle,source) {

 if (!("filename" in gTitlePriority)) {

 gTitlePriority[""]=-1;
 gTitlePriority["filename"]=0;
 gTitlePriority["search"]=1;
 gTitlePriority["imdb"]=2;
 gTitlePriority["epguides"]=2;
 gTitlePriority["imdb_aka"]=3;
 gTitlePriority["thetvdb"]=4;
 }

 if (!(source in gTitlePriority)) {
 ERROR("Bad value ["source"] passed to adjustTitle");
 return;
 }

 if (gTitlePriority[source] - gTitlePriority[gTitleSource[idx]] > 0) {
 if (newTitle != gTitle[idx] ) {
 DEBUG("title changed from "gTitleSource[idx]":["gTitle[idx]"] to "source":["newTitle"]");
 } else {
 DEBUG("title "gTitleSource[idx]":["gTitle[idx]"] matches "source":["newTitle"]");
 }
 gTitle[idx] = newTitle;
 gTitleSource[idx] = source;
 return 1;
 } else {
 DEBUG("title kept as "gTitleSource[idx]":["gTitle[idx]"] instead of "source":["newTitle"]");
 return 0;
 }
}

function extractImdbId(text,\
id) {
 if (match(text,g_imdb_regex)) {
 id = substr(text,RSTART,RLENGTH);
 DEBUG("Extracted IMDB Id ["id"]");
 } else if (match(text,"Title.[0-9]+\\>")) {
 id = "tt" substr(text,RSTART+8,RLENGTH-8);
 DEBUG("Extracted IMDB Id ["id"]");
 }
 if (id != "" && length(id) != 9) {
 id = sprintf("tt%07d",substr(id,3));
 }
 return id;
}






function getIsoTitle(isoPath,\
sep,tmpFile,f,outputWords,isoPart,outputText) {
 FS="\\n";
 sep="~";
 outputWords=0;
 tmpFile="/tmp/bytes."JOBID;
 isoPart="/tmp/bytes."JOBID".2";
 delete outputText;

 if (exec("dd if="quoteFile(isoPath)" of="isoPart" bs=1024 count=10 skip=32") != 0) {
 return 0;
 }

 DEBUG("Get strings "isoPath);

 DEBUG("tmp file "tmpFile);

 system("awk '"'"'BEGIN { FS=\"_\" } { gsub(/[^ -~]+/,\"~\"); gsub(\"~+\",\"~\") ; split($0,w,\"~\"); for (i in w)  if (w[i]) print w[i] ; }'"'"' "isoPart" > "tmpFile);
 getline f < tmpFile;
 getline f < tmpFile;
 system("rm -f -- "tmpFile" "isoPart);
 INFO("iso title for "isoPath" = ["f"]");
 gsub(/[Ww]in32/,"",f);
 return cleanTitle(f);
}

function extractImdbLink(text,\
t) {
 t = extractImdbId(text);
 if (t != "") {
 t = "http://www.imdb.com/title/"t;
 }
 return t;
}








function extractImdbEpisode(idx,imdbLink,attempts,\
f,s,e,txt,imdbEpisodeUrl,referencedLink,referencedId) {

 INFO("extractImdbEpisode ["imdbLink"]");
 imdbEpisodeUrl = imdbLink "/episodes";

 if (gEpTitleImdb[idx] != "" ) {
 INFO("Episode details already set to "gEpTitleImdb[idx]);
 } else {
 f=getUrl(imdbEpisodeUrl,"imdb_episode",1);
 if (f != "") {
 FS="\n";
 s=g_season[idx];
 e=g_episode[idx];

 while((getline txt < f) > 0 ) {



 if (index(txt,"Season "s", Episode "e":")) {
 gEpTitleImdb[idx]=extractTagText(txt,"a");
 gAirDateImdb[idx]=formatDate(extractTagText(txt,"strong"));
 DEBUG("imdb episode title = ["gEpTitleImdb[idx]"]");
 DEBUG("imdb air date = ["gAirDateImdb[idx]"]");
 break;
 }




 if (match(txt,g_imdb_regex "/episodes")) {
 referencedLink=substr(txt,RSTART,RLENGTH-9);
 referencedId = substr(extractImdbId(referencedLink),3)+0;  #Get Id as a number.

 if (match(imdbEpisodeUrl,"\\<tt0*"referencedId"\\>")) {

 referencedId = referencedLink = "";
 } else {
 INFO("Found another referenced episode link ["referencedLink"/"referencedId"]");
 break;
 }
 }
 }
 close(f);
 if (referencedLink != "" && gEpTitleImdb[idx]=="" && gAirDateImdb[idx] == "") {
 INFO("Had IMDB link ["imdbEpisodeUrl"] but this may be an episode and ["referencedLink"] may be the series");
 if (attempts == 0) {
 return extractImdbEpisode(idx,extractImdbLink(referencedLink),attempts+1);
 }
 }

 }
 }
 return imdbLink;
}

function extractAttribute(str,tag,attr,\
 tagPos,closeTag,endAttr,attrPos) {

 tagPos=index(str,"<"tag);
 closeTag=indexFrom(str,">",tagPos);
 attrPos=indexFrom(str,attr"=",tagPos);
 if (attrPos == 0 || attrPos-closeTag >= 0 ) {
 ERROR("ATTR "tag"/"attr" not in "str);
 ERROR("tagPos is "tagPos" at "substr(str,tagPos));
 ERROR("closeTag is "closeTag" at "substr(str,closeTag));
 ERROR("attrPos is "attrPos" at "substr(str,attrPos));
 return "";
 }
 attrPos += length(attr)+1;
 if (substr(str,attrPos,1) == "\"" ) {
 attrPos++;
 endAttr=indexFrom(str,"\"",attrPos);
 }  else  {
 endAttr=indexFrom(str," ",attrPos);
 }

 return substr(str,attrPos,endAttr-attrPos);
}

function extractTagText(str,startText,\
 i,j) {
 i=index(str,"<"startText);
 i=indexFrom(str,">",i) + 1;
 j=indexFrom(str,"<",i);
 return trim(substr(str,i,j-i));
}

function indexFrom(str,x,startPos,\
 j) {
 if (startPos<1) startPos=1;
 j=index(substr(str,startPos),x);
 if (j == 0) return 0;
 return j+startPos-1;
}

function url_encode(text) {

 if (index(text,"%")) { gsub(/[%]/,"%25",text); }
 if (index(text,"?")) { gsub(/[?]/,"%3F",text); }
 if (index(text,"&")) { gsub(/[&]/,"%26",text); }
 if (index(text," ")) { gsub(/ /,"%20",text); }
 if (index(text,":")) { gsub(/:/,"%3A",text); }
 if (index(text,"=")) { gsub(/=/,"%3D",text); }
 if (index(text,"(")) { gsub(/\(/,"%40",text); }
 if (index(text,")")) { gsub(/\)/,"%41",text); }
 if (index(text,"[")) { gsub(/\[/,"%5B",text); }
 if (index(text,"]")) { gsub(/\]/,"%5D",text); }
 if (index(text,"+")) { gsub(/[+]/,"%43",text); }

 return text;
}

function decode_init(atoi,\
i,c,h) {
 DEBUG("create decode matrix");
 for(i=0 ; i - 256 < 0 ; i++ ) {
 c=sprintf("%c",i);
 h=sprintf("x%02x",i);
 atoi[i] = c;
 atoi[h] = c;
 }
}
function html_decode(text,\
i,j,code,newcode) {
 if (g_atoi[32] == "" ) {
 decode_init(g_atoi);
 }
 i=0;
 while((i=indexFrom(text,"&#",i)) > 0) {
 DEBUG("i="i);
 j=indexFrom(text,";",i);
 code=tolower(substr(text,i+2,j-(i+2)));

 if (substr(code,1,1) == "x") {
 newcode=g_atoi[code];
 } else {
 newcode=g_atoi[0+code];
 }
 text=substr(text,1,i-1) newcode substr(text,j+1);
 }

 return text;
}

function getUrl(url,capture_label,cache,referer,\
 f,label) {
 
 label="getUrl:"capture_label": ";



 if (url == "" ) {
 WARNING(label"Ignoring empty URL");
 return;
 }

 if(cache && (url in gUrlCache) ) {

 DEBUG(label" fetched ["url"] from cache");
 f = gUrlCache[url];
 }

 if (f =="" || !exists(f)) {

 f=NEW_CAPTURE_FILE(capture_label);
 if (wget(url,f,referer) ==0) {
 if (cache) {
 gUrlCache[url]=f;
 DEBUG(label" Fetched & Cached ["url"] to ["f"]");
 } else {
 DEBUG(label" Fetched ["url"] into ["f"]"); 
 }
 } else {
 ERROR(label" Failed getting ["url"] into ["f"]");
 f = "";
 }
 }
 return f;
}


function wget(url,file,referer,\
args,unzip_cmd,cmd,htmlFile,downloadedFile,urls,i,same_domain_delay,targetFile) {

 args=" --no-check-certificate -q -U \""g_user_agent"\" --waitretry=5 -t 4 ";
 if (referer != "") {
 DEBUG("Referer = "referer);
 args=args" --referer=\""referer"\" ";
 }

 targetFile=quoteFile(file);
 htmlFile=targetFile;

 if(gunzip == "") {
 downloadedFile=htmlFile;
 unzip_cmd="";
 } else {
 args=args" --header=\"Accept-Encoding: gzip,deflate\" "
 downloadedFile=quoteFile(file".gz");
 if (index(gunzip,"'"$GUNZIP_SCRIPT"'")) {
 unzip_cmd="&& \""gunzip"\" "downloadedFile" "htmlFile;
 } else { 
 unzip_cmd=" && ( gunzip "downloadedFile" 2>/dev/null || mv "downloadedFile" "htmlFile" ) ";
 }
 }

 gsub(/ /,"+",url);




 rm(downloadedFile,1);
 args = args " -c ";



 split(url,urls,"\t");
 url="";
 for(i in urls) {
 if (urls[i] != "") {
 url = url " "quoteFile(urls[i])" ";
 }
 }

 cmd = WGET" -O "downloadedFile" "args" "url" "unzip_cmd  ;




 same_domain_delay=0;
 cmd = get_sleep_command(url,same_domain_delay) cmd;

 return exec(cmd);
}


function get_sleep_command(url,required_gap,\
domain,remaining_gap) {

 if (match(url,"https?://[a-z0-9A-Z.]+")) {
 domain=substr(url,RSTART,RLENGTH);
 }

 g_search_count[domain]++;
 if (index(domain,"epguide") || index(domain,"imdb")) {
 return "";
 }
 remaining_gap=required_gap - (systime()-g_last_search_time[domain]);
 if ( g_last_search_time[domain] > 0 && remaining_gap > 0 ) {

 g_last_search_time[domain] = systime()+remaining_gap;
 return "sleep "remaining_gap" ; ";
 } else {
 g_last_search_time[domain] = systime();
 return "";
 }
}


function local_poster_path(idx,must_exist,\
 p,ext,e) {
 split(".jpg,.JPG",ext,",");
 p = gFolder[idx] "/" gMovieFiles[idx];
 if (gMovieFiles[idx] ~ "/$") {

 p = gFolder[idx] "/" gMovieFiles[idx] gMovieFiles[idx];
 sub(/\/$/,"",p);
 } else {

 sub(/\.[^.]+$/,"",p);
 }

 for(e in ext) {
 if (exists(p ext[e] )) {
 INFO("Found local poster path "p ext[e]);
 return p ext[e];
 }
 }
 if (must_exist) {
 INFO("No local poster path for "".jpg/.png/...");
 return "";
 } else {
 INFO("Setting default local poster path = "p);
 return p ".jpg";
 }
}



#


function internal_poster_reference(idx,\
poster_ref) {
 poster_ref = gTitle[idx]"_"g_year[idx];
 gsub(/[^-_a-zA-Z0-9]+/,"_",poster_ref);
 if (g_category[idx] == "T" ) {
 poster_ref = poster_ref "_" g_season[idx];
 } else {
 poster_ref = poster_ref "_" extractImdbId(gExternalSourceUrl[idx]);
 }



 return "ovs:" POSTER "/" g_settings["catalog_poster_prefix"] poster_ref ".jpg";
}




function download_poster(url,idx,\
 poster_ref,havePoster,with_media_path,internal_path,urls,referer,args,copy_file,get_it) {



 with_media_path = local_poster_path(idx,1);

 if (hasContent(with_media_path) ) {

 INFO("Using local poster "with_media_path" - superceeds internal poster");
 copy_file=1;
 } 



 DEBUG("Looking for new poster...");






 poster_ref = internal_poster_reference(idx);
 internal_path = getPath(poster_ref,gFolder[idx]);

 DEBUG("internal_path = ["internal_path"]");
 DEBUG("poster_ref = ["poster_ref"]");
 DEBUG("new poster url = "url);

 if(copy_file) {


 preparePath(internal_path);
 system("cp "quoteFile(with_media_path)" "quoteFile(internal_path));
 g_already_fetched_poster[internal_path] = 1;

 } else {

 get_it = 0;


 havePoster = hasContent(internal_path);

 if (g_settings["catalog_fetch_posters"] == "no") {
 INFO("catalog_fetch_posters disabled");
 } else {
 if (!havePoster) {
 get_it = 1;
 } else if (UPDATE_POSTERS == 1 && !g_already_fetched_poster[internal_path]) {
 get_it = 1;
 } else {
 INFO("Already got "internal_path);
 }
 }

 if (get_it) {

 INFO((UPDATE_POSTERS==1?"Forced ":" ") (havePoster?"Updating":"Fetching")" poster "internal_path);

 rm(internal_path,1);


 preparePath(internal_path);

 split(url,urls,"\t");
 url=urls[1];
 referer=urls[2];

 args=" -q -O "quoteFile(internal_path);

 DEBUG("Poster url = "url);
 if (referer != "" ) {
 DEBUG("Referer = "referer);
 args = args " --referer=\""referer"\" ";
 }
 args = args " -U \""g_user_agent"\" ";


 if (exec(WGET args quoteFile(url)) == 0 ) {


 if (hasContent(internal_path) && system("grep -q \"<html\" "quoteFile(internal_path)) != 0) {
 g_already_fetched_poster[internal_path] = 1;

 set_permissions(quoteFile(internal_path));
 }
 } else {
 poster_ref = "";
 }
 }

 }
 return poster_ref;
}



function getNiceMoviePosters(id,\
search_url,poster_url,urlChars,referer_url) {
 DEBUG("Poster check id = "id);

 search_url="http://www.themoviedb.org/search?search[text]="id;






 urlChars="[-_.a-zA-Z0-9/:?&]+";
 poster_url=scanPageForMatch(search_url,urlChars"_thumb.jpg",1);

 if (poster_url != "" ) {
 DEBUG("url = "poster_url);
 if (sub(/_thumb/,"_cover",poster_url) == 1) {
 sub(/^\/image\//,"http://images.themoviedb.org/",poster_url);
 }
 }
 if (poster_url == "") {
 search_url="http://posters.motechnet.com/title/"id"/";
 poster_url=scanPageForMatch(search_url,urlChars"_poster.jpg",1,"http://images.google.com");
 if (poster_url != "" ) {
 poster_url="http://www.motechposters.com" poster_url;



 referer_url = poster_url;
 sub(/\/posters\//,"/title/",referer_url);
 sub(/_poster.jpg/,"",referer_url);
 poster_url=poster_url"\t"referer_url;
 }
 
 }
 INFO("movie poster ["poster_url"]");
 return poster_url;
}





function scanPageForMatch(url,regex,cache,referer,\
matches,i) {
 scanPageForMatches(url,regex,1,cache,referer,matches);


 for(i in matches) {
 return i;
 }
}





function scanPageForMatches(url,regex,max,cache,referer,matches,\
f,line,count,getMore,linematches,linecount) {

 delete matches;

 DEBUG("scan "url" for "regex);
 f=getUrl(url,"scan4match",cache,referer);

 count=0;
 if (f != "" ) {

 FS="\n";
 getMore=1;

 while(getMore && ((getline line < f) > 0)  ) {

 linecount = getMatches(line,regex,(max==0?0:max-count),linematches);

 DEBUG2(regex" match "linecount" in "line);

 addHash(matches,linematches);
 count += linecount;
 if (max > 0) {
 getMore = (max-count) > 0;
 }
 }
 close(f);
 }
 dump(2,count" matches",matches);
 return count;
}

function getMatches(line,regex,max,matches,\
getMore,start,count) {
 getMore = 1;
 start=0;
 count =0 ;
 delete matches;
 while (getMore && match(substr(line,start+1),regex) != 0) {
 matches[substr(line,RSTART+start,RLENGTH)]++;

 count++;
 if (max > 0 ) {
 getMore = (max-count) > 0;
 }

 start += RSTART+RLENGTH;
 }
 dump(3,count " linematches",matches);
 return count;
}


function scrapeIMDBLine(line,imdbContentPosition,idx,f,\
title,y,poster_imdb_url) {

 if (imdbContentPosition == "footer" ) {
 return imdbContentPosition;
 } else if (imdbContentPosition == "header" ) {



 if (index(line,"<title>")) {
 title = extractTagText(line,"title");
 DEBUG("Title found ["title "] current title ["gTitle[idx]"]");

 title=checkIMDBTvTitle(idx,title);
 }
 if (index(line,"pagecontent")) {
 imdbContentPosition="body";
 }

 } else if (imdbContentPosition == "body") {

 if (index(line,">Company:")) {
 DEBUG("Found company details - ending");
 imdbContentPosition="footer";
 } else {



 if (g_year[idx] == "" && (y=index(line,"/Sections/Years/")) > 0) {
 g_year[idx] = substr(line,y+16,4);
 DEBUG("IMDB: Got year ["g_year[idx]"]");
 }
 if (index(line,"a name=\"poster\"")) {
 if (match(line,"src=\"[^\"]+\"")) {

 poster_imdb_url = substr(line,RSTART+5,RLENGTH-5-1);


 sub(/SX[0-9]{2,3}_/,"SX400_",poster_imdb_url);
 sub(/SY[0-9]{2,3}_/,"SY400_",poster_imdb_url);


 g_imdb_poster_url[idx]=poster_imdb_url;
 DEBUG("IMDB: Got imdb poster ["g_imdb_poster_url[idx]"]");
 if (g_poster[idx] == "") {
 g_poster[idx] = poster_imdb_url;
 }
 }
 }
 if (g_plot[idx] == "" && index(line,"Plot:")) {
 g_plot[idx] = scrapeIMDBPlot(f);
 }
 if (g_genre[idx] == "" && index(line,"Genre:")) {
 g_genre[idx]=scrapeIMDBGenre(f);
 }
 if (g_rating[idx] == "" && index(line,"/10</b>") ) {
 g_rating[idx]=0+extractTagText(line,"b");
 DEBUG("IMDB: Got Rating = ["g_rating[idx]"]");
 }
 if (index(line,"certificates")) {

 scrapeIMDBCertificate(idx,line);

 }



 if (gOriginalTitle[idx] == gTitle[idx] && index(line,"Also Known As:")) {

 scrapeIMDBAka(idx,line);

 }
 }
 } else {
 DEBUG("Unknown imdbContentPosition ["imdbContentPosition"]");
 }
 return imdbContentPosition;
}

function checkIMDBTvTitle(idx,title,\
semicolon,quote,quotePos,title2) {

 g_category[idx]="M";
 if (substr(title,1,1) == "&" ) {
 semicolon=index(title,";");
 if (semicolon > 0 ) { 
 quote=substr(title,1,semicolon);
 DEBUG("Imdb tv quote = <"quote">");
 title2=substr(title,semicolon+1);
 DEBUG("Imdb tv title = <"title2">");
 quotePos = index(title2,quote);
 if (quotePos > 0 ) {


 title=substr(title2,1,quotePos-1);
 g_category[idx]="T";

 }
 }
 }


 gsub(/ \((19|20)[0-9][0-9](\/I|)\) *(\([A-Z]+\)|)$/,"",title);

 title=cleanTitle(title);
 if (adjustTitle(idx,title,"imdb")) {
 gOriginalTitle[idx] = gTitle[idx];
 }
 return title;
}







function scrapeIMDBAka(idx,line,\
l,akas,a,c,exclude,e,eEeE) {

 if (gOriginalTitle[idx] != gTitle[idx] ) return ;

 l=substr(line,index(line,"</h")+5);
 split(l,akas,"<br>");
 for(a in akas) {
 DEBUG("Checking aka ["akas[a]"]");
 for(c in gTitleCountries ) {
 if (index(akas[a],"("gTitleCountries[c]":")) {


 DEBUG("Ignoring aka section");
 return;
 eEeE=")"; #Balance brakets in editor!
 }
 if (index(akas[a],"("gTitleCountries[c]")")) {

 split("longer version|season title|poster|working|literal|IMAX|promotional|long title|script title|closing credits|informal alternative",exclude,"|");
 for(e in exclude) {
 if (index(akas[a],exclude[e])) {


 DEBUG("Ignoring aka section");
 return;
 }
 }

 akas[a]=substr(akas[a],1,index(akas[a]," (")-1);
 akas[a]=cleanTitle(akas[a]);
 sub(/ \(.*/,"",akas[a]);
 adjustTitle(idx,akas[a],"imdb_aka"); 
 return;
 
 }
 }
 }
}

function scrapeIMDBCertificate(idx,line,\
l,cert,c) {
 if ( match(line,"List[?]certificates=[^&]+")) {



 l=substr(line,RSTART,RLENGTH);
 l=substr(l,index(l,"=")+1); # eg UK:15
 split(l,cert,":");
 DEBUG("IMDB: found certificate ["cert[1]"]["cert[2]"]");
 

 for(c = 1 ; (c in gCertificateCountries ) ; c++ ) {
 if (gCertCountry[idx] == gCertificateCountries[c]) {

 return;
 }
 if (cert[1] == gCertificateCountries[c]) {

 gCertCountry[idx] = cert[1];
 gCertRating[idx] = cert[2];
 DEBUG("IMDB: set certificate ["gCertCountry[idx]"]["gCertRating[idx]"]");
 return;
 }
 }
 }
}
function scrapeIMDBPlot(f,\
p,i) {
 getline p <f;


 if ((i=index(p," <a")) > 0) {
 p=substr(p,1,i-1);
 }
 if ((i=index(p,"|")) > 0) {
 p=substr(p,1,i-1);
 }
 DEBUG("IMDB: Got plot = ["p"]");
 return p;
}
function scrapeIMDBGenre(f,\
l) {
 getline l <f;
 gsub(/<[^<>]+>/,"",l);
 sub(/ +more */,"",l);
 DEBUG("IMDB: Got genre = ["l"]");
 return l;
}

function relocate_files(i,\
newName,oldName,nfoName,oldFolder,newFolder,fileType,epTitle) {

 DEBUG("relocate_files");

 newName="";
 oldName="";
 fileType="";
 if (RENAME_TV == 1 && g_category[i] == "T") {

 oldName=gFolder[i]"/"gMovieFiles[i];
 newName=g_settings["catalog_tv_file_fmt"];
 newName = substitute("SEASON",g_season[i],newName);
 newName = substitute("EPISODE",g_episode[i],newName);
 newName = substitute("INFO",gAdditionalInfo[i],newName);

 epTitle=gEpTitle[i];
 if (epTitle == "") {
 epTitle = gEpTitleImdb[i];
 }
 gsub(/[^-A-Za-z0-9,. ]/,"",epTitle);
 gsub(/[{]EPTITLE[}]/,epTitle,newName);

 newName = substitute("EPTITLE",epTitle,newName);
 newName = substitute("0SEASON",sprintf("%02d",g_season[i]),newName);
 newName = substitute("0EPISODE",pad_episode(g_episode[i]),newName);

 fileType="file";

 } else if (RENAME_FILM==1 && g_category[i] == "M") {

 oldName=gFolder[i];
 newName=g_settings["catalog_film_folder_fmt"];
 fileType="folder";

 } else {
 return;
 }
 if (newName != "" && newName != oldName) {

 if (fileType == "file") {
 newName = substitute("NAME",gMovieFiles[i],newName);
 if (match(gMovieFiles[i],"\.[^.]+$")) {

 newName = substitute("BASE",substr(gMovieFiles[i],1,RSTART-1),newName);
 newName = substitute("EXT",substr(gMovieFiles[i],RSTART),newName);
 } else {

 newName = substitute("BASE",gMovieFiles[i],newName);
 newName = substitute("EXT","",newName);
 }
 }
 newName = substitute("DIR",gFolder[i],newName);
 newName = substitute("TITLE",gTitle[i],newName);
 newName = substitute("YEAR",g_year[i],newName);
 newName = substitute("CERT",gCertRating[i],newName);
 newName = substitute("GENRE",g_genre[i],newName);


 gsub(/[\\:*\"<>|]/,"_",newName); #"

 gsub(/\/\/+/,"/",newName);

 if (newName != oldName) {
 if (fileType == "folder") {
 if (moveFolder(i,oldName,newName) != 0) {
 return;
 }
 g_file[i]="";
 gFolder[i]=newName;
 } else {


 if (moveFile(oldName,newName) != 0 ) {
 return;
 }
 gFolderMediaCount[gFolder[i]]--;
 g_file[i]=newName;
 
 oldFolder=gFolder[i];

 newFolder=newName;
 sub(/\/[^\/]+$/,"",newFolder);


 gFolder[i]=newFolder;

 gMovieFiles[i]=newName;
 sub(/.*\//,"",gMovieFiles[i]);


 if(exists(gNfoDefault[i])) {

 nfoName = newName;
 sub(/\.[^.]+$/,"",nfoName);
 nfoName = nfoName ".nfo";

 if (nfoName == newName ) {
 return;
 }

 if (moveFile(gNfoDefault[i],nfoName) != 0) {
 return;
 }
 if (!g_opt_dry_run) {

 gDate[nfoName]=gDate[gNfoDefault[i]];
 delete gDate[gNfoDefault[i]];

 gNfoDefault[i] = nfoName;
 }
 }

 if(g_poster[i] != "" && substr(g_poster[i],1,1)!= "/" && substr(g_poster[i],1,4) != "ovs:" ) {
 oldName=oldFolder"/"g_poster[i];
 newName=newFolder"/"g_poster[i];
 if (moveFile(oldName,newName) != 0 ) {
 return;
 }
 }


 rename_related(oldName,newName);


 moveFolder(i,oldFolder,newFolder);
 }
 }
 } else {

 if (g_opt_dry_run) {
 print "dryrun:\t"newName" unchanged.";
 print "dryrun:";
 } else {
 INFO("rename:\t"newName" unchanged.");
 }
 }
}

function rm(x,quiet,quick) {
 removeContent("rm -f -- ",x,quiet,quick);
}
function rmdir(x,quiet,quick) {
 removeContent("rmdir -- ",x,quiet,quick);
}
function removeContent(cmd,x,quiet,quick) {

 if (!changeable(x)) return 1;

 if (!quiet) {
 INFO("Deleting "x);
 }
 cmd=cmd quoteFile(x)" 2>/dev/null ";
 if (quick) {
 return "(" cmd ") & ";
 } else {
 return "(" cmd " || true ) ";
 } 
}

function substitute(keyword,value,str,\
 oldStr,hold) {

 oldStr=str;
 if (index(value,"&")) {
 gsub(/[&]/,"\\\\&",value);
 }
 if (index(str,keyword)) {
 while(match(str,"[{][^{}]*:"keyword":[^{}]*[}]")) {
 hold=substr(str,RSTART,RLENGTH);
 if (value=="") {
 hold="";
 } else {
 sub(":"keyword":",value,hold);
 hold=substr(hold,2,length(hold)-2); #remove braces
 }
 str=substr(str,1,RSTART-1) hold substr(str,RSTART+RLENGTH);
 }
 }

 if ( oldStr != str ) {
 DEBUG("Keyword ["keyword"]=["value"]");
 DEBUG("Old path ["oldStr"]");
 DEBUG("New path ["str"]");
 }

 return str;
}

function rename_related(oldName,newName,\
 extensions,ext,oldBase,newBase) {
 split("srt idx sub",extensions," ");

 oldBase = oldName;
 sub(/\....$/,".",oldBase);

 newBase = newName;
 sub(/\....$/,".",newBase);

 for(ext in extensions) {
 moveFile(oldBase extensions[ext],newBase extensions[ext]);
 }

}

function preparePath(f) {









 f = quoteFile(f);
 return system("if [ ! -e "f" ] ; then mkdir -p "f" && rmdir -- "f" ; fi");
}




function changeable(f) {



 if (substr(f,1,5) == "/tmp/") return 1;

 if (!match(f,"/[^/]+/[^/]+/")) {
 WARNING("Changing ["f"] might be risky. please make manual changes");
 return 0;
 }
 return 1;
}

function moveFile(oldName,newName,\
 new,old,ret) {

 if (!changeable(oldName) ) {
 return 1;
 }
 new=quoteFile(newName);
 old=quoteFile(oldName);
 if (g_opt_dry_run) {
 if (match(oldName,gExtRegExAll) && system("test -f "old) == 0) {
 print "dryrun: from "old
 print "dryrun: to\t"new
 print "dryrun:";
 }
 return 0;
 } else {

 if ((ret=preparePath(newName)) == 0) {
 ret = exec("mv "old" "new);
 }
 return ret;
 }
}

function isDvdDir(f) {
 return substr(f,length(f)) == "/";
}


function moveFolder(i,oldName,newName,\
 cmd,new,old,ret,isDvdDir) {

 if (!(folderIsRelevant(oldName))) {
 WARNING("["oldName"] not renamed as it was not listed in the arguments");
 return 1;
 } else if ( gFolderCount[oldName] - 2*(isDvdDir(gMovieFiles[i])) > 0 ) {
 WARNING("["oldName"] not renamed to ["newName"] due to "gFolderCount[oldName]" sub folders");
 return 1;
 } else if (gFolderMediaCount[oldName] - 1 > 0) {
 WARNING("["oldName"] not renamed to ["newName"] due to "gFolderMediaCount[oldName]" media files");
 return 1;
 } else if (!changeable(oldName) ) {
 return 1;
 } else {
 new=quoteFile(newName);
 old=quoteFile(oldName);
 if (g_opt_dry_run) { 
 print "dryrun: from "old"/* to "new"/";
 return 0;
 } else {
 INFO("move folder:"old"/* --> "new"/");
 cmd="mkdir -p "new" ;  mv "old"/* "new" ; mv "old"/.[^.]* "new" 2>/dev/null ; rmdir "old;
 ret = exec(cmd);
 system("rmdir "old" 2>/dev/null");
 }
 return ret;
 }
}

function hasContent(f) {
 return test("-s",f);
}
function exists(f) {
 return test("-f",f);
}
function isDirectory(f) {
 return test("-d",f);
}
function test(t,f) {
 return system("test "t" "quoteFile(f)) == 0;
}




function generate_nfo_file(nfoFormat,dbrow,\
movie,tvshow,nfo,dbOne,fieldName,fieldId,i,nfoAdded,episodedetails) {

 nfoAdded=0;
 if (g_settings["catalog_nfo_write"] == "never" ) {
 return;
 }
 parseDbRow(dbrow,dbOne,1);

 DEBUG("NFO = "dbOne[NFO,1]);
 DEBUG("DIR = "dbOne[DIR,1]);
 nfo=getPath(dbOne[NFO,1],dbOne[DIR,1]);

 DEBUG("nfo = "nfo);

 if (exists(nfo) && g_settings["catalog_nfo_write"] != "always" ) {
 DEBUG("nfo already exists - skip writing");
 return;
 }
 DEBUG("nfo exists = "exists(nfo));

 DEBUG("nfo style = "nfoFormat);
 
 if (nfoFormat == "xmbc" ) {
 movie=","TITLE","ORIG_TITLE","RATING","YEAR","PLOT","POSTER","CERT","WATCHED","IMDBID","FILE","GENRE",";
 tvshow=","TITLE","URL","RATING","PLOT","GENRE",";
 episodedetails=","EPTITLE","SEASON","EPISODE","AIRDATE",";
 }


 if (nfo != "" && !exists(nfo)) {



 DEBUG("Creating ["nfoFormat"] "nfo);

 if (nfoFormat == "xmbc") {
 if (dbOne[CATEGORY,1] =="M") {

 if (dbOne[URL,1] != "") {
 dbOne[IMDBID,1] = extractImdbId(dbOne[URL,1]);
 }

 startXmbcNfo(nfo);
 writeXmbcTag(dbOne,"movie",movie,nfo);
 nfoAdded=1;

 } else if (dbOne[CATEGORY,1] == "T") {

 startXmbcNfo(nfo);
 writeXmbcTag(dbOne,"tvshow",tvshow,nfo);
 writeXmbcTag(dbOne,"episodedetails",episodedetails,nfo);
 nfoAdded=1;
 }
 } else {

 print "#Auto Generated NFO" > nfo;
 for (i in dbOne) {
 if (dbOne[i] != "") {
 fieldId = substr(i,1,length(i)-2);
 fieldName=g_db_field_name[fieldId];
 if (fieldName != "") {
 print fieldName"\t: "dbOne[i] > nfo;
 }
 }
 }
 nfoAdded=1;
 }
 }
 if(nfoAdded) {
 close(nfo);
 set_permissions(quoteFile(nfo));
 }
}

function startXmbcNfo(nfo) {
 print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > nfo;
 print "<!-- #Auto Generated NFO by catalog.sh -->" > nfo;
}

function writeXmbcTag(dbOne,tag,children,nfo,\
idxPair,fieldId,text,attr,childTag) {
 print "<"tag">" > nfo;


 attr["movie","id"]="moviedb=\"imdb\"";

 for (idxPair in dbOne) {

 text=dbOne[idxPair];

 if (text != "") {
 fieldId = substr(idxPair,1,length(idxPair)-2);
 if (index(children,fieldId)) {
 childTag=gDbFieldId2Tag[fieldId];
 if (childTag != "") {
 if (childTag == "thumb") {




 print "\t<!-- Poster location not exported catalog_poster_location="g_settings["catalog_poster_location"]" -->" > nfo;
 print "\t<"childTag">"xmlEscape(text)"</"childTag">" > nfo;

 } else {
 if (childTag == "watched" ) text=((text==1)?"true":"false");
 print "\t<"childTag" "attr[tag,childTag]">"xmlEscape(text)"</"childTag">" > nfo;
 }
 }
 }
 }
 }
 print "</"tag">" > nfo;
}

function xmlEscape(text) {
 gsub(/[&]/,"\\&amp;",text);
 gsub(/</,"\\&lt;",text);
 gsub(/>/,"\\&gt;",text);
 return text;
}


#
function fixTitles(idx) {


 if (gTitle[idx] == "") {
 gTitle[idx] = gMovieFiles[idx];
 sub(/.*\//,"",gTitle[idx]); #remove path
 gsub(/[^A-Za-z0-9]/," ",gTitle[idx]); #remove odd chars
 DEBUG("Setting title to file["gTitle[idx]"]");
 }


 if ( g_settings["catalog_folder_titles"] == 1 ) {
 gTitle[idx] = gFolder[idx];
 gsub(/.*\//,"",gTitle[idx]); #Remove path
 DEBUG("Setting title to folder["gTitle[idx]"]");
 }
 gTitle[idx]=cleanTitle(gTitle[idx]);
}

function get_best_episode_title(idx,\
 tvcom,epguideTitles) {

 if (g_category[idx] != "T") return;

 DEBUG("gTvCom["idx"]=["gTvCom[idx]"]");
 DEBUG("gEpTitle["idx"]=["gEpTitle[idx]"]");
 DEBUG("gEpTitleImdb["idx"]=["gEpTitleImdb[idx]"]");

 split(gTvCom[idx],tvcom,"\t");
 split(gEpTitle[idx],epguideTitles,"\t");

 if (gEpTitle[idx] == "") {
 gEpTitle[idx] = gEpTitleImdb[idx];
 }

 if (gEpTitle[idx] == "") {
 gEpTitle[idx] = "Episode "g_episode[idx] " " cleanTitle(remove_format_tags(gAdditionalInfo[idx]));
 }
}

function createIndexRow(i,dbArr,file_to_db,\
row,estimate,nfo,dbIdx) {

 estimate=gDate[gFolder[i]"/unpak.log"];
 if (estimate == "") {
 estimate=gDate[gFolder[i]"/unpak.txt"];
 }
 if (estimate == "") {
 estimate = g_file_time[i];
 }

 if (g_file[i] == "" ) {
 g_file[i]=getPath(gMovieFiles[i],gFolder[i]);
 }
 gsub(/\/\/+/,"/",g_file[i]);

 if ((g_file[i] in gFolderCount ) && gFolderCount[g_file[i]]) {
 DEBUG("Adjusting file for video_ts");
 g_file[i] = g_file[i] "/";
 }

 row="\t"ID"\t"(gMaxDatabaseId++);

 if (g_file[i] in file_to_db) {
 dbIdx = file_to_db[g_file[i]];
 row=row"\t"WATCHED"\t"dbArr[WATCHED,dbIdx];
 row=row"\t"ACTION"\t"dbArr[ACTION,dbIdx];
 } else {
 row=row"\t"WATCHED"\t0";
 row=row"\t"ACTION"\t0";
 }


 row=row"\t"TITLE"\t"gTitle[i];
 if (gOriginalTitle[i] != "" && gOriginalTitle[i] != gTitle[i] ) {
 row=row"\t"ORIG_TITLE"\t"gOriginalTitle[i];
 }
 row=row"\t"SEASON"\t"g_season[i];

 row=row"\t"EPISODE"\t"g_episode[i];

 row=row"\t"SEASON0"\t"sprintf("%02d",g_season[i]);
 row=row"\t"EPISODE0"\t"pad_episode(g_episode[i]);

 row=row"\t"YEAR"\t"g_year[i];
 row=row"\t"FILE"\t"g_file[i];
 row=row"\t"ADDITIONAL_INFO"\t"gAdditionalInfo[i];
 row=row"\t"PARTS"\t"gParts[i];
 row=row"\t"URL"\t"gExternalSourceUrl[i];
 row=row"\t"CERT"\t"gCertCountry[i]":"gCertRating[i];
 row=row"\t"GENRE"\t"g_genre[i];
 row=row"\t"RATING"\t"g_rating[i];
 row=row"\t"PLOT"\t"g_plot[i];
 row=row"\t"CATEGORY"\t"g_category[i];
 row=row"\t"POSTER"\t"g_poster[i];
 row=row"\t"FILETIME"\t"g_file_time[i];
 if (gMovieFileCount - 4 > 0) {



 row=row"\t"INDEXTIME"\t"estimate;
 } else {
 row=row"\t"INDEXTIME"\t"NOW;
 }
 row=row"\t"DOWNLOADTIME"\t"estimate;

 row=row"\t"PROD"\t"gProdCode[i];
 row=row"\t"AIRDATE"\t"gAirDate[i];
 row=row"\t"EPTITLEIMDB"\t"gEpTitleImdb[i];
 row=row"\t"AIRDATEIMDB"\t"gAirDateImdb[i];

 row=row"\t"TVCOM"\t"gTvCom[i];
 row=row"\t"EPTITLE"\t"gEpTitle[i];
 nfo="";
 DEBUG("NFO:"gNfoDefault[i]);

 if (g_settings["catalog_nfo_write"] != "never" || exists(gNfoDefault[i]) ) {
 nfo=gNfoDefault[i];
 gsub(/.*\//,"",nfo);
 }
 row=row"\t"NFO"\t"nfo;
 return row;
}






function add_new_scanned_files_to_database(indexHash,output_file,db_arr,file_to_db,\
i,row,fields,f,\
minIdx,maxIdx,inf) {

 status("Merging");
 gMaxDatabaseId++;






 INFO("Adding indexes "minIdx" - "maxIdx);
#

 for(i in indexHash) {

 DEBUG("Adding to db:"i"["gTitle[i]"]["gMovieFiles[i]"]");
 if (gMovieFiles[i] == "") continue;

 row=createIndexRow(i,db_arr,file_to_db);

 print row"\t" >> output_file;

 generate_nfo_file(g_settings["catalog_nfo_format"],row);

 if(DBG-2 >= 0) {
 split(row,fields,"\t");
 for(f=1; (f in fields) ; f++) {
 if (f%2) {
 if(fields[f] != "" ) {
 DEBUG2(inf"=["fields[f]"]");
 }
 } else {
 inf=g_db_field_name[fields[f]]; 
 }
 }
 }
 }
 close(output_file);
}
function touch_and_move(x,y) {
 system("touch "quoteFile(x)" ; mv "quoteFile(x)" "quoteFile(y));
}





function NEW_CAPTURE_FILE(label,\
 CAPTURE_FILE,suffix) {
 suffix= "." CAPTURE_COUNT "__" label;
 CAPTURE_FILE = CAPTURE_PREFIX JOBID suffix;
 CAPTURE_COUNT++;

 return CAPTURE_FILE;
}

function clean_capture_files() {
 INFO("Clean up");
 exec("rm -f -- \""CAPTURE_PREFIX JOBID "\".* ");
}
function INFO(x) {
 if (index(x,g_tk) ) sub(g_tk,"",x);
 print "[INFO]  '$LOG_TAG' "(systime()-ELAPSED_TIME)" : " x;
}
function WARNING(x) {
 if (index(x,g_tk) ) sub(g_tk,"",x);
 print "[WARNING] '$LOG_TAG'"x;
}
function ERROR(x) {
 if (index(x,g_tk) ) sub(g_tk,"",x);
 print "[ERROR] '$LOG_TAG'"x;
}
function DETAIL(x) {
 if (index(x,g_tk) ) sub(g_tk,"",x);
 print "[DETAIL] '$LOG_TAG'"x;
}


function trimAll(str) {
 sub(/([^a-zA-Z0-9]|[ ])+$/,"",str);
 sub(/^([^a-zA-Z0-9]|[ ])+/,"",str);
 return str;
}

function trim(str) {
 gsub(/^ +/,"",str);
 gsub(/ +$/,"",str);
 return str;
}




function heapsort (count, fieldName,fieldOrder,idx,arr,
 end,tmp) {
 heapify(count,fieldName,fieldOrder,idx,arr);
 end=count-1;
 while (end > 0) {
 tmp=idx[0];idx[0]=idx[end];idx[end]=tmp;
 end--;
 siftdown(fieldName,fieldOrder,idx,arr,0,end);
 }
}
function heapify (count, fieldName,fieldOrder,idx,arr,
 start) {
 start=int((count-2)/2)
 while (start >= 0) {
 siftdown(fieldName,fieldOrder,idx,arr,start,count-1);
 start--;
 }
}
function siftdown (fieldName,fieldOrder,idx,arr,start,end,\
 root,child,tmp) {
 root=start;
 while(root*2+1 - end <= 0) {
 child=root*2+1
 if (child+1 <=end && compare(fieldName,fieldOrder,idx,arr,child,child+1) <= 0) {
 child++;
 }
 if (compare(fieldName,fieldOrder,idx,arr,root,child) > 0) {
 return
 }
 tmp=idx[root];idx[root]=idx[child];idx[child]=tmp;
 root=child;
 }
}

function compare(fieldName,fieldOrder,idx,arr,idx1,idx2,
 a,b) {

 a=arr[fieldName,idx[idx1]];
 b=arr[fieldName,idx[idx2]];
 if  (a - b > 0) {
 return fieldOrder;
 } else {
 return -fieldOrder;
 }
}

function fix1(text) {
 gsub(/[^A-F0-9]/,"",text);
 return text;
}


function get_folders_from_args(folder_arr,\
i,folderCount,moveDown) {
 folderCount=0;
 moveDown=0;
 for(i = 1 ; i - ARGC < 0 ; i++ ) {
 INFO("Arg:["ARGV[i]"]");
 if (ARGV[i] == "IGNORE_NFO" ) {
 g_settings["catalog_nfo_read"] = "no";
 moveDown++;

 } else if (ARGV[i] == "WRITE_NFO" ) {

 g_settings["catalog_nfo_write"] = "if_none_exists";
 moveDown++;

 } else if (ARGV[i] == "NOWRITE_NFO" ) {

 g_settings["catalog_nfo_write"] = "never";
 moveDown++;

 } else if (ARGV[i] == "REBUILD" ) {
 REBUILD=1;
 moveDown++;
 } else if (ARGV[i] == "DEBUG" ) {
 DBG=1;
 moveDown++;
 } else if (ARGV[i] == "DEBUG2" ) {
 DBG=2;
 moveDown++;
 } else if (ARGV[i] == "NOACTIONS" ) {
 g_opt_no_actions=1;
 moveDown++;
 } else if (ARGV[i] == "STDOUT" ) {
 STDOUT=1;
 moveDown++;
 } else if (ARGV[i] == "DRYRUN" ) {
 RENAME_TV=1;
 RENAME_FILM=1;
 g_opt_dry_run=1;
 moveDown++;
 } else if (ARGV[i] == "RENAME" ) {
 RENAME_TV=1;
 RENAME_FILM=1;
 moveDown++;
 } else if (ARGV[i] == "RENAME_TV" ) {
 RENAME_TV=1;
 moveDown++;
 } else if (ARGV[i] == "RENAME_FILM" ) {
 RENAME_FILM=1;
 moveDown++;
 } else if (ARGV[i] == "UPDATE_POSTERS" )  {
 UPDATE_POSTERS=1;
 moveDown++;
 } else if (ARGV[i] == "RESCAN" )  {
 RESCAN=1;
 moveDown++;
 } else if (match(ARGV[i],"^[a-zA-Z_]+=")) {

 } else {

 INFO("Scan Path:["ARGV[i]"]");
 folder_arr[++folderCount] = ARGV[i];
 moveDown++;
 }
 }
 ARGC -= moveDown;

 ARGV[ARGC++] = "/dev/null";
 return folderCount;
}


function load_catalog_settings(file_name) {

 load_settings(file_name);

 g_settings["catalog_ignore_paths"]=glob2re(g_settings["catalog_ignore_paths"]);


 gsub(/[|]/,".*|",g_settings["catalog_ignore_paths"]);
 g_settings["catalog_ignore_paths"]=g_settings["catalog_ignore_paths"]".*";

 g_settings["catalog_ignore_names"]=glob2re(g_settings["catalog_ignore_names"]);





 split(tolower(g_settings["catalog_search_engines"]),g_link_search_engines,"|");





 split(tolower(g_settings["catalog_deep_search_engines"]),g_title_search_engines,"|");
 g_web_search_count=0;
}


' JOBID=$JOBID PID=$$ NOW=`date +%Y%m%d%H%M%S` \
 "WGET=/bin/wget" \
 "LS=$LS" \
 "APPDIR=$APPDIR" \
 "gunzip=$gunzip_cmd" \
 "INDEX_DB=$INDEX_DB" "$@"

 rm -f "$APPDIR/catalog.lck" "$APPDIR/catalog.status"
}

main() {

 clean_tmp
 set +e
 echo "[INFO] catalog version $VERSION"
 sed 's/^/\[INFO\] os version /' /proc/version
 if [ -f /mnt/syb8634/VERSION ] ; then
 sed -rn '/./ s/^/\[INFO\] nmt version /p' /mnt/syb8634/VERSION
 fi
 catalog DEBUG "$@" 
 x=$?
 set -e

 clean_tmp
 chown $uid:$gid $INDEX_DB*
 return $x
}




clean_tmp() {
 rm -f $tmp_dir/catalog.[0-9]*__* 2>/dev/null || true
}

clean_logs() {
 find "$APPDIR/logs" -name \*.log -mtime +1 | while IFS= read f ; do
 rm -f -- "$f"
 done
}

clean_logs



if [ -z "${JOBID:-}" ] ; then
 JOBID=$$
fi




if [ "$STDOUT" -eq 1 ] ; then
 LOG_TAG="catalog:"
 main "$@"
else
 LOG_TAG=

 mkdir -p "$APPDIR/logs"
 LOG_FILE="$APPDIR/logs/catalog.$JOBID.log"
 main "$@" > "$LOG_FILE" 2>&1
 if [ -z "${REMOTE_ADDR:-}" ] ;then
 echo "[INFO] $LOG_FILE"
 fi
 grep dryrun: "$LOG_FILE"
 PERMS "$APPDIR/logs"
fi
if [ -f "$APPDIR/oversight.sh" ] ; then
 $APPDIR/oversight.sh CLEAR_CACHE
fi

