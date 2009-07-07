#!/bin/sh
#!This is a compacted file. If looking at the source see oversight.cgi.full
#!Compressed with
#!sed -r 's/^[  ]+/ /;/^ #/ {s/.*//};/^#[^!]/ {s/.*//};/^$/ {s/.*//}' oversight.cgi.full > oversight.cgi
#!note [    ] is [<space><tab>]
#!If not compressed then awk will report "bad address" error.




OWNER=nmt:nmt

DECODE() {
 echo "$1" | sed 's/%20/ /g'
}

IMG() {
 cat <<IMGHDR
Content-Type: $2

IMGHDR
cat "$1" || x=`DECODE "$1"` && cat "$x"
}

case "X$1" in
 X*jpg) echo "Content-Type: image/jpeg" ; echo ;  if ! cat "$1" ; then x=`DECODE "$1"` && cat "$x" ; fi ; exit ;;
 X*png) echo "Content-Type: image/png"  ; echo ;  if ! cat "$1" ; then  x=`DECODE "$1"` && cat "$x" ; fi ; exit ;;
 X*gif) echo "Content-Type: image/gif"  ; echo ;  if ! cat "$1" ; then  x=`DECODE "$1"` && cat "$x" ; fi ; exit ;;
esac









#!/bin/sh









DEBUG=1 #Debug also disables the cache
VERSION=20090707-1BETA

HOSTNAME=`hostname`

APPDIR=/share/Apps/oversight
if [ ! -d "$APPDIR" ] ; then

 EXE=$0
 while [ -L "$EXE" ] ; do
 EXE=$( ls -l "$EXE" | sed 's/.*-> //' )
 done
 APPDIR=$( echo $EXE | sed -r 's|[^/]+$||' )

 cd "${APPDIR:-.}"
 APPDIR="$PWD"
fi


TMPDIR="$APPDIR/tmp"
if [ ! -d $TMPDIR ] ; then
 mkdir -p $TMPDIR
 chown $OWNER $TMPDIR
fi

CACHE_DIR="$TMPDIR/cache"

appname=oversight

unpak_bin="$APPDIR/$appname.sh"

METHOD=POST
UPLOAD_DIR=/share/

INDEX_DB="$APPDIR/index.db"




MAIN_PAGE() {


 cat "$APPDIR/oversight.css" #css link tag broken i think
 Q="'"
 CATALOG_RUNNING=
 if [ -f "$APPDIR/catalog.lck" ] ; then
 if [ -d "/proc/`cat $APPDIR/catalog.lck`" ] ; then
 CATALOG_RUNNING=1
 else

 rm -f "$APPDIR/catalog.lck" "$APPDIR/catalog.status"
 fi

 fi

 CATALOG_MESSAGE=
 if [ -f "$APPDIR/catalog.status" ] ; then
 CATALOG_MESSAGE="`cat $APPDIR/catalog.status`"
 fi

 if [ -f "$TMPDIR/cmd.pending" ] ; then
 CATALOG_PENDING=1
 fi
 if [ -f "$APPDIR/version.dl" ] ; then
 VERSION_DISPLAY=1
 fi

 date > /tmp/d1
 awk '



function appendDatabaseOverview(regexFilter,source_start,source_end,source,overview_file,db_size,db,\
i,filter,noActionText) {
 FS="\t" ;

 db_size+=0; #awk converting to a string at some point!

 source_start[source] = source_end[source] = db_size;

 h_comment("Reading overview file "overview_file" source =["source"] with filter ["regexFilter"]");

 filter = ( gFilterRegex != "");
 noActionText = "\t"ACTION"\t0\t";

 while((getline < overview_file) > 0) {


 if (source=="*" && index($0,"\t")==1) gLocalCount++;


 if (filter) {
 if (match(tolower($0),regexFilter) == 0) {
 continue;
 }
 }


 if (index($0,noActionText) == 0 ) continue;

 if (index($0,gWatchedFilter) == 0) continue;

 db_size=load_index(regexFilter,source,db,db_size);

 }
 close(overview_file);
 source_end[source]=db_size;
 h_comment("DB INDEX: for ["source"] = "db_size" from " source_start[source] " to " source_end[source] );
 h_comment("Local size = "gLocalCount);
 return db_size;
}

function sourceHome(s) {
 return sourceRoot(s) "Apps/oversight/";
}
function sourceRoot(s) {
 if (s == "*" || s == "" ) {
 return "/share/";
 } else {
 return "/opt/sybhttpd/localhost.drives/NETWORK_SHARE/"s"/";
 }
}

function appendMountedDatabaseOverview(regexFilter,source_start,source_end,db_size,db,\
f) {
 f = "/tmp/oversight."PID;
 system("ls /opt/sybhttpd/localhost.drives/NETWORK_SHARE/*/Apps/oversight/index.db.idx 2>/dev/null > "f);
 while((getline < f) > 0) {
 if (match($0,"NETWORK_SHARE/[^/]+")) {
 source = substr($0,RSTART,RLENGTH);
 source = substr(source,index(source,"/")+1);
 h_comment(" pre size["source"] = "db_size);
 db_size = appendDatabaseOverview(regexFilter,source_start,source_end,source,$0,db_size,db);
 h_comment(" total size = "db_size);
 }
 }
 close(f);
 system("rm -f -- "f);
 for(f in source_start) h_comment("Source="f);
 return db_size;
}

function appendDatabase(idlist,source,db,db_size,\
db_file) {

 regexFilter="\t"ID"\t("idlist")\t";
 db_file = sourceHome(source)"index.db";

 h_comment("Append database regex filter = "regexFilter);
 h_comment("source = ["source"] file = "db_file);

 
 FS="\t" ;

 while((getline < db_file) > 0) {
 if (match($0,regexFilter) && index($0,"\t"ACTION"\t0\t")) {

 parse_index_merge(db,db_size);

 db[SOURCE,db_size] = source;
 db[DIR,db_size]=db[FILE,db_size];
 sub(/\/[^\/]*$/,"",db[DIR,db_size]);
 db_size++;

 }
 }
 h_comment("DB:" db_size );
 return db_size;
}

function START_PRE_FORM() {

 db_size=0;

 ID="_id";

 OVERVIEW_DETAILIDLIST="_did" ;
 OVERVIEW_EXT_LIST = "_ext";

 SOURCE="_src";
 WATCHED="_w";
 ACTION="_a"; # Tell catalog.sh to do something with this entry (ie delete)
 PARTS="_pt";

 FILE="_F";
 NAME="_N";
 DIR="_D";
 AKA="_K";
 CATEGORY="_C";
 ADDITIONAL_INFO="_ai";
 DATE="_D";
 YEAR="_Y";
 TITLE="_T";

 SEASON="_s";
 EPISODE="_e";
 SEASON0="0_s";
 EPISODE0="0_e";

 GENRE="_G";
 RATING="_r";
 CERT="_R";
 PLOT="_P";
 URL="_U";
 POSTER="_J"; #JPEG
 DOWNLOADTIME="_DT"; 
 INDEXTIME="_IT"; 
 FILETIME="_FT"; 
 PROD="_p";
 AIRDATE="_ad";
 TVCOM="_tc";
 EPTITLE="_et";
 EPTITLEIMDB="_eti";
 AIRDATEIMDB="_adi";
 NFO="_nfo";


 QTYPE_FILTER="_tf";
 QWATCHED_FILTER="_wf";
 QSORT="s";
 QORDER="o";
 QREG_FILTER="_rf";
 QSEARCH_MODE="_sm";
 CAPTURE_PREFIX = "/tmp/awk." PID ;

 NMT_PLAYLIST="/tmp/playlist.htm";
 printf "" > NMT_PLAYLIST;
 CHECKBOX_PREFIX="cb_";

}

function shellEscape(t) {
 gsub(/[][ *?"'"'"'()]/,"\\\\&",t);
 return t;
}


function selectDatabase(source_start,source_end,db,db_size,\
 i,source,idlist,gIndexFilter,at) {

 if (query[QSORT] == "") { query[QSORT] = INDEXTIME };

 if (query[QORDER] == "") {
 query[QORDER] = -1 ; #timestamps
 if (query[QSORT] == TITLE ) query[QORDER] = 1 ;
 }

 h_comment("View = "query["view"]);
 if (query["view"] == "admin" ) {

 } else if (query["view"] == "tv" || query["view"] == "movie" ) {

 idlist_by_source(query["idlist"],idlist);

 for(source in idlist) {
 db_size=appendDatabase(idlist[source],source,db,db_size);
 }


 } else {

 gIndexFilter="\t";
 if (query[QTYPE_FILTER] != "" ) {
 gIndexFilter="\t"CATEGORY"\t"query[QTYPE_FILTER]"{0,1}\t";
 }

 gWatchedFilter="\t";
 if (query[QWATCHED_FILTER] != "" ) {
 gWatchedFilter="\t"WATCHED"\t"(query[QWATCHED_FILTER] == "W")"\t";
 }

 gFilterRegex="";
 if (query[QREG_FILTER] != "" ) {
 gFilterRegex = "\\<";
 for(i = 1 ; i <= length(query[QREG_FILTER]) ; i++) {
 gFilterRegex = gFilterRegex num2regex[substr(query[QREG_FILTER],i,1)]; 
 }
 h_comment("Tvid Filter " query[QREG_FILTER] " == "gFilterRegex);
 } else if (query["searcht"] != "" && query[QSEARCH_MODE] ) {
 gFilterRegex=tolower(query["searcht"]);
 }

 db_size=0;
 h_comment("Begin appendDatabaseOverview");
 db_size=appendDatabaseOverview(gFilterRegex,source_start,source_end,"*",g_db_fname".idx",db_size,db);
 h_comment("End appendDatabaseOverview");
 if (ovs_crossview == "1") {
 h_comment("Begin appendMountedDatabaseOverview ["ovs_crossview"]");
 db_size=appendMountedDatabaseOverview(gFilterRegex,source_start,source_end,db_size,db);
 h_comment("end appendMountedDatabaseOverview");
 }

 }
 return db_size;
}

function showDatabase(label,db_size,db,\
i) {
 h_comment(label);
 for(i = 0; i < db_size ; i++ ) {
 h_comment("source["db[SOURCE,i]"]: title["i"] = "db[TITLE,i]);
 }
}








#
function idlist_by_source(idlist_query,source_idlist_hash,\
at,by_source,s,source,ids) {

 h_comment("splitting ["idlist_query"]");

 split(idlist_query,by_source,")");

 for(s in by_source) {
 if (by_source[s] != "" ) {
 h_comment("splitting ["by_source[s]"]");
 at = index(by_source[s],"(");
 source = substr(by_source[s],1,at-1);
 ids=substr(by_source[s],at+1);
 source_idlist_hash[source]=ids;
 h_comment("source ["source"]=["ids"]");
 }
 }
}

function exec(cmd) {
 h_comment("SYSTEM : "cmd);
 return system(cmd);
}

function get_new_version_id(\
id,f) {
 if ( "'"$VERSION_DISPLAY"'" != "" ) {
 f = APPDIR"/version.dl";
 getline id < f;
 close(f);
 }
 if (index(id,"ERROR") ) {
 id="";
 }
 h_comment("Online version ["id"]");
 return id;
}

function doFormActions(\
 selectedIdList,s,idlist,page) {

 if (query["searchb"] == "Hide" ) {
 delete query[QSEARCH_MODE];
 delete query["searchb"];
 }






 if (allow_admin && query["view"] == "admin" ) {

 action=tolower(query["action"]);

 if (action == "clearcache") {
 exec(CLEAR_CACHE_CMD);

 } else if (action == "rescan") {

 exec(SEND_COMMAND_TEXT("catalog.sh RESCAN UPDATE_POSTERS NOWRITE_NFO"));

 } else if (match(action,"(check_stable|check_stable_or_beta|re-install|install|undo)")) {

 gUpgradeResult=(exec(APPDIR"/oversight.sh UPGRADE "tolower(action)) == 0);
 if (action != "undo" ) {
 gNewVersion=get_new_version_id();
 }

 } else if (match(action,"^[Ss]ave.[Ss]ettings")) {

 for (option_name in query) {
 if (match(option_name,"^option_")) {
 real_name=substr(option_name,index(option_name,"_")+1);
 value=query[option_name];
 oldvalue=query["orig_"option_name];
 if (value != oldvalue ) {
 system(sprintf("cd \"%s\" && ./options.sh SET \"%s\" %s \"%s\" ",APPDIR,query["file"],real_name,value));
 }
 }
 }
 if (query["file"] == "oversight.cfg" ) {
 exec(CLEAR_CACHE_CMD);
 }


 }

 } else {
 if (query["select"] != ""  ) {

 h_comment("<!-- allow_mark ="allow_mark" allow_delete="allow_delete" action="query["action"]" -->");

 if (allow_mark && query["action"] == "Mark" ) {

 getNewlySelectedIdListBySource(idlist);
 setSelectRecordFields(idlist,WATCHED,1);

 getNewlyDeSelectedIdListBySource(idlist);
 setSelectRecordFields(idlist,WATCHED,0);

 rebuildSources(idlist);

 } else if (allow_delete && query["action"] == "Delete" ) {

 getNewlySelectedIdListBySource(idlist);
 setSelectRecordFields(idlist,ACTION,"D");
 rebuildSources(idlist);
 remove_ids_from_query(idlist); 

 } else if (allow_delist && query["action"] == "Remove_From_List" ) {

 getNewlySelectedIdListBySource(idlist);
 removeSelectedRecords(idlist);
 rebuildSources(idlist);
 remove_ids_from_query(idlist); 
 }
 }
 }
 
 if (g_has_post_data) {
 clearSelection();
 }
}

function isCheckbox(i) {
 if (query[i]!="on") {
 return 0;
 } else if ( match(i,"^"CHECKBOX_PREFIX".*\\([0-9|]+\\)$")) {
 return 1;
 } else if ( match(i,"^orig_"CHECKBOX_PREFIX".*\\([0-9|]+\\)$")) {
 return 1;
 } else if ( match(i,"^option_") || match(i,"^orig_option_") ) {
 return 1;
 } else {
 return 0;
 }
}

function clearSelection() {
 delete query["select"];




 if (query["action"] != "Cancel" ) {
 delete query["action"];
 }
 for(i in query) {
 if (isCheckbox(i)) {
 delete query[i];
 }
 }
}



function re_escape(txt) {
 gsub(/[]|*()]/,"\\\\&",txt);
 return txt;
}



function remove_ids_from_query(idlist,\
i,ids,id,istart,q,s_re) {

 q=query["idlist"];
 h_comment("idlist="query["idlist"]);
 if (query["view"] != "" && query["idlist"] != "" ) {
 for(s in idlist) {
 h_comment("removing ["s"] ["idlist[s]"]");

 s_re=re_escape(s);







 split(idlist[s],ids,"|");
 for(i in ids) {
 id=ids[i];
 h_comment("match(\"" q  "\",\"" s_re  "\\([^(]*\\<" id  "\\>\")");
 if (match(q,s_re"\\([^(]*\\<"id"\\>")) {
 h_comment("RSTART="RSTART" RLENGTH="RLENGTH);

 istart=RSTART+RLENGTH-length(id);
 q=substr(q,1,istart-1) substr(q,RSTART+RLENGTH);
 }
 }

 gsub(/\|+/,"|",q);  #source(1||3) -> source(1|3)
 gsub(/\(\|/,"(",q); #source(|2|3) -> source(2|3)
 gsub(/\|\)/,")",q); #source(1|2|) -> source(1|2)
 sub(s_re"\\(\\)","",q);
 }
 }
 h_comment("modified idlist="q);
 query["idlist"] = q;
}

function removeSelectedRecords(idlist,\
f,src,id,ids) {
 for(src in idlist) {
 if (idlist[src] != "") {

 f=sourceHome(src)"index.db";

 exec(sprintf("sed -ir \"/\t"ID"\t(%s)\t/ d\" \"%s\"",idlist[src],f));
 }
 }
}


function setSelectRecordFields(idlist,fieldName,fieldValue,\
f,src) {
 
 for(src in idlist) {
 if (idlist[src] != "") {


 f=sourceHome(src)"index.db";

 exec("sed -ir \"/\t"ID"\t("idlist[src]")\t/ s/(\t"fieldName"\t)[^\t]+\t/\\1"fieldValue"\t/\" \""f"\"");
 }
 }
}
function rebuildSources(source_list,\
s,h) {
 for(src in source_list) {

 if (source_list[src] != "") {
 h=sourceHome(src);


 exec("su nmt -s /bin/sh -c \""h"/catalog.sh REBUILD NOACTIONS\" ");
 exec(CLEAR_CACHE_CMD);


 exec(SEND_COMMAND_TEXT("catalog.sh REBUILD ",src));
 }
 }
}




function getNewlySelectedIdListBySource(selectedIdList,\
 i,idlist) {
 delete selectedIdList;
 for(i in query) {
 if (query[i] == "on" && isCheckbox(i) && match(i,"^"CHECKBOX_PREFIX) && !("orig_"i in query)) {
 h_comment("checkbox ["i"] just enabled");
 merge_idlist_by_source(substr(i,length(CHECKBOX_PREFIX)+1),selectedIdList);
 } else {
 h_comment("checkbox ["i"] not enabled");
 }
 }
}




function merge_idlist_by_source(idlist,selectedIdList,\
idlist_arr,s,t) {
 idlist_by_source(idlist,idlist_arr);
 for(s in idlist_arr) {
 t=selectedIdList[s];
 if (t == "" ) t=idlist_arr[s] ;
 else t = t "|" idlist_arr[s];
 selectedIdList[s] = t;
 h_comment("List ["s"] = ["selectedIdList[s]"]");
 }
}



function getNewlyDeSelectedIdListBySource(selectedIdList,\
 i,s,idlist,idlist_arr) {
 delete selectedIdList;
 for(i in query) {
 if (query[i] == "on" && isCheckbox(i) && match(i,"^orig_"CHECKBOX_PREFIX) && !(substr(i,6) in query )) {
 h_comment("checkbox ["i"] just disabled");
 merge_idlist_by_source(substr(i,length("orig_"CHECKBOX_PREFIX)+1),selectedIdList);
 } else {
 h_comment("checkbox ["i"] not disabled");
 }
 }
}









function CAPTURE_END() {
 

 if ( FNR == 1  && FS != " " ) { FS=" " ; $0 = $0 };

}

function continueDynamicStyles() {
 print ".dummy {};" #bug in gaya - ignores style after comment
 print ".recent { font-size:"(gFontSize)"; }";
 print "td { font-size:"gFontSize"; font-family:\"arial\";  }"

 if (query["view"] == "movie" || query["view"] == "tv" ) {
 print "font.plot { font-size:"(gFontSize-2)" ; font-weight:normal; }" 


 print "td.ep10 { background-color:#222222; font-weight:bold; font-size:"(gFontSize-2)"; }"
 print "td.ep11 { background-color:#111111; font-weight:bold; font-size:"(gFontSize-2)"; }"
 print "td.ep00 { background-color:#004400; font-weight:bold; font-size:"(gFontSize-2)"; }"
 print "td.ep01 { background-color:#003300; font-weight:bold; font-size:"(gFontSize-2)"; }"
 print ".eptitle { font-size:100% ; font-weight:normal; font-size:"(gFontSize-2)"; }"

 print "h1 { text-align:center; font-size:"gTitleSize"; font-weight:bold; color:#FFFF00; }"
 print ".label { color:red }";
 } else {
 print ".scanlines"scanlines" {color:#FFFF55; font-weight:bold; }"
 }
}


function start_page() {



 continueDynamicStyles();
 print "</style><meta name=\"robots\" content=\"nofollow\" ><title>OverSight Index ("g_hostname")</title>"



 if (query["view"] == "movie" || query["view"] == "tv" ) {
 startCell="0";
 } else {
 if (query[QREG_FILTER] == "") {

 startCell="centreCell";
 } else {

 startCell="filter5";
 }
 }
 print "</head><body onloadset="startCell" focuscolor=yellow focustext=black class=local"g_local_browser" >";

 h_form_start();
}

function copy_db(source,dest,idx,\
 _i) {
 for(_i in source) {
 dest[_i,idx] = source[_i];
 }
}






function parse_index(arr,\
_i,start) {



 start=2;
 if (NF >= 34) {
 arr[ $2] = $3;
 arr[ $4] = $5;
 arr[ $6] = $7;
 arr[ $8] = $9;
 arr[$10] = $11;
 arr[$12] = $13;
 arr[$14] = $15;
 arr[$16] = $17;
 arr[$18] = $19;
 arr[$20] = $21;
 arr[$22] = $23;
 arr[$24] = $25;
 arr[$26] = $27;
 arr[$28] = $29;
 arr[$30] = $31;
 arr[$32] = $33;
 start=34;
 }
 for(_i = start ; _i+1 <= NF ; _i+=2 ) { 
 if ($(_i) != "") arr[$(_i)] = $(_i+1);
 }

}

function parse_index_merge(arr,index2,\
_i,start) {


 start=0;
 if (NF >= 34) {
 arr[ $2,index2] = $3;
 arr[ $4,index2] = $5;
 arr[ $6,index2] = $7;
 arr[ $8,index2] = $9;
 arr[$10,index2] = $11;
 arr[$12,index2] = $13;
 arr[$14,index2] = $15;
 arr[$16,index2] = $17;
 arr[$18,index2] = $19;
 arr[$20,index2] = $21;
 arr[$22,index2] = $23;
 arr[$24,index2] = $25;
 arr[$26,index2] = $27;
 arr[$28,index2] = $29;
 arr[$30,index2] = $31;
 arr[$32,index2] = $33;
 start=34;
 }
 for(_i = start ; _i+1 <= NF ; _i+=2 ) { 
 if ( $(_i) != "") arr[$(_i),index2] = $(_i+1);
 }

 
}

function load_index(regexFilter,source,db,db_size,\
_tmpdb,m,pt,addItem) {

 if (regexFilter == "" ) {

 addItem=1;
 parse_index_merge(db,db_size);

 } else {

 addItem=0;
 parse_index(_tmpdb);

 RLENGTH=-1;

 h_comment("["tolower(_tmpdb[TITLE])"] vs ["regexFilter"]");
 if (match(tolower(_tmpdb[TITLE]),regexFilter) ) {

 if (RLENGTH > 0) {


 db["rstart",db_size] = RSTART;
 db["rlength",db_size] = RLENGTH;
 copy_db(_tmpdb,db,db_size);
 addItem=1;
 }
 }
 }

 if (addItem) {
 db[SOURCE,db_size] = source;
 db_size++;
 }

 if (0 && DEBUG) {
 for(jj in db) {
 if (index(jj,SUBSEP db_size)) {
 split(jj,jjj,SUBSEP);
 h_comment("db "jjj[1] "," jjj[2] " = "db[jj]);
 }
 }
 }

 return db_size+0;
}


function getMountedPath(source,file) {
 h_comment("Get mounted path ["source"]["file"]");
 if (source == "*" ) {
 return file;
 } else if (index(source,"/") == 0 ) {


 if (substr(file,1,7) == "/share/") {
 file=sourceRoot(source) substr(file,8);
 }
 }
 h_comment("=["file"]");
 return file;
}


function mountedPath(file,src,dst) {
 if (substr(file,1,length(src)) == src) {
 return dst substr(file,length(src)+1);
 } else {
 return file;
 }
}

function vod_link(title,src,file,vod_name,vod_number,hrefAttr,class,\
 f,name,_VOD,isIso) {

 if (substr(file,length(file)) == "/") {

 _VOD=" file=c ZCD=2 "hrefAttr;
 file=substr(file,1,length(file)-1);
 isIso=1;
 } else if (match(tolower(file),"[.](iso|img)$")) {
 _VOD=" file=c ZCD=2 "hrefAttr;
 } else {
 _VOD=" vod file=c "hrefAttr;
 }
 gsub(/\|/,"<br>",title);


 name=file;

 file=getMountedPath(src,file);

 gsub(/.*\//,"",name);
 if (!isIso) {
 if (playListStarted == 0 ) {
 printf name "%s|0|0|file://%s|" ,name,file > NMT_PLAYLIST;
 playListStarted = 1;
 } else {
 printf name "%s|0|0|file://%s|" ,name,file >> NMT_PLAYLIST;
 }
 }


 f=url_encode(file);
 if (class != "") {
 return href("file://"f,"name=\""vod_name"\" "_VOD,"<font class=\""class"\">"title"</font>");
 } else {
 return href("file://"f,"name=\""vod_name"\" "_VOD,title);
 }
}


function end_page(source_start,source_end,db_size,db) {


 if (query["view"] == "admin" ) {

 show_admin(query["action"]);

 } else if (query["view"] == "tv" ) {

 end_tv_page(source_start,source_end,0,db_size,db);

 } else if (query["view"] == "movie" ) {

 end_movie_page(source_start,source_end,0,db_size,db);

 } else {

 end_table_page(source_start,source_end,db_size,db);

 }

}

function title_link(db,idx,\
html) {
 html = db[TITLE,idx];
 if (db[CATEGORY,idx] == "T" ) {
 html = html " S"db[SEASON,idx];
 }
 
 if (db[YEAR,idx] != "" ) {
 html = html "("db[YEAR,idx]")";
 }

 html = html certificateImage(db[CERT,idx],gCertAttr);


 if (!g_local_browser && db[URL,idx] != "" )  {
 html = html  "<a href=\""db[URL,idx]"\" >" localImageLink(APPDIR"/images/imdb.gif","imdb",gButtonAttr) "</a>";
 }
 return "<h1><center>" html "</h1></center>";
}

function end_movie_page(source_start,source_end,idx,db_size,db) {

 print "<table width=100% >";
 print "<tr valign=top>";
 print "<td width=30%>"posterImgTag(idx) "</td>";
 print "<td>"programDetailsTable(db,idx);
 movie_listing(db,idx);
 print "<hr></td>";
 print "</tr>";
 print "</table>";
 showSelectControls(0,0,0);
 print "</form>"playButton("")"</body>";
}

function end_tv_page(source_start,source_end,idx,db_size,db) {

 print "<table width=100% >";
 print "<tr>";
 print "<td width=25%><center>"posterImgTag(idx) "</center></td>";
 print "<td>"programDetailsTable(db,idx); showSelectControls(0,0,0); print "</td>";
 print "</tr>";
 print "</table>";
 print "<table width=100% >";
 print "<tr>";
 print "<td class=filelist align=center colspan=2>";


 tv_listing(db,db_size,idx,2);
 print "</td>"
 print "</tr>";
 print "</table></form>"playButton("")"</body>";
}

function playButton(text) {

 return href("file:///tmp/playlist.htm?start_url=","vod=playlist tvid=\"_PLAY\"",text);
}

function getPath(name,mediaFile) {
 if (index(name,"/") == 1) {

 return name;
 } else if (substr(name,1,4) == "ovs:" ) {

 return APPDIR"/db/global/"substr(name,5);
 } else {

 substr(/\/[^\/]+$/,"",mediaFile);
 return mediaFile"/"name;
 }
}

function posterPath(idx,\
url) {
 if (db[POSTER,idx] != "") {
 url=getPath(db[POSTER,idx],db[FILE,idx]);
 url=getMountedPath(db[SOURCE,idx],url);
 }
 return url;
}
function posterImgTag(idx,imgAttr,\
url) {
 h_comment("posterImgTag of "idx);
 if (db[POSTER,idx] != "") {
 url=getPath(db[POSTER,idx],db[FILE,idx]);
 url=getMountedPath(db[SOURCE,idx],url);
 if (db[CATEGORY,idx] == "M") {
 if (imgAttr == "" ) imgAttr = gMoviePosterAttr;
 } else {
 if (imgAttr == "" ) imgAttr = gTvPosterAttr;
 }
 if (index(watchedStyle(db,idx,0),"fresh")) {
 imgAttr = imgAttr " border=2 class=fresh ";
 }
 }
 url = localImageLink(posterPath(idx),db[TITLE,idx],imgAttr);
 return url;
}

function certificateImage(c,imgAttr  , c1) {
 c1 = tolower(c);
 sub(/usa:/,"us:",c1);
 sub(/:/,"/",c1);
 
 return localImageLink(APPDIR"/images/cert/"c1"." ovs_icon_type,c,imgAttr);
}

function programDetailCell(label,txt,tdclass,\
plot) {
 gsub(/ /,"\\&nbsp;",label);
 if(0) {
 return "<tr><td class="tdclass" width=20% align=right>"label"</td><td class="tdclass">"txt"</td></tr>";
 } else {
 return "<tr><td class="tdclass" width=100% align=left><font class=label>"label" :</font>&nbsp;"txt"</td></tr>";
 }
}

function ratingTxt(rating,\
r,r2,txt,i,attr) {
 r = rating+0;
 attr="width=16 heigth=16";
 txt=""
 for(i=1;i<=10;i++) {
 r2="10"
 if (i > int(r)+1 ) {
 r2="0";
 } else if (i == int(r+1) && r != int(r)) {
 r2=int(10*r)%10;
 }
 txt = txt localImageLink(APPDIR"/images/stars/star"r2"."ovs_icon_type,"",attr);
 }
 return txt "&nbsp;&nbsp;" rating;
}

function programDetailsTable(db,idx,\
plot,g,html) {
 g=db[GENRE,idx];
 gsub(/ \|/,",",g);


 plot=db[PLOT,idx];
 if (length(plot) > gPlotLength) plot=substr(plot,1,gPlotLength-3)"...";

 html = title_link(db,idx) "<table class=detail width=100%>" programDetailCell("Genre",g,"list0");
 if ( oversight_display_rating ) {
 html = html programDetailCell("Rating",ratingTxt(db[RATING,idx]),"list1");
 }
 html = html programDetailCell("Plot","<font class=plot>"plot"</font>","list1") "</table>";
 return html;
}

function iconLink(name) {
 
 name=tolower(substr(name,length(name)-2));
 if (substr(name,length(name)) == "/") {
 return container_icon("video_ts",name);
 } else if (index("iso|img|mkv",name)) {
 return container_icon(name,name);
 } else if (name != "avi" ) {
 return "<font size=\"-1\">["name"]</font>";
 }
}

function container_icon(imgName,name,\
t) {
 t = gPrecomputeTag[iconName];
 if (t == "") {
 t = gPrecomputeTag[iconName] = localImageLink(APPDIR"/images/"imgName"."ovs_icon_type,"("name")","width=30 alt=\"["name"]\" style=\"background-color:#AAAAAA\" ");
 }
 return t;
}

function themeImageTag(iconName, buttonAttr,\
t) {
 t = gPrecomputeTag[iconName];
 if (t == "") {
 if (buttonAttr == "" ) buttonAttr = gButtonAttr;
 t = gPrecomputeTag[iconName] = "<img alt=\""iconName"\" border=0 src="iconSrc(iconName)" "buttonAttr" />";
 }
 return t;
}

function themeImageLink(queryString,hrefAttr,iconName,buttonAttr) {
 return selfLinkMulti(queryString,hrefAttr,themeImageTag(iconName,buttonAttr));
}

function localImageLink(path,alt,attrs)  {
 attrs =" alt=\""alt"\" src="localImageSrc(path)" "attrs;
 return "<img "attrs" />";
}
function confirm(name,val_ok,img_ok,val_cancel,img_cancel) {
 return "<table width=100%><tr><td align=center>"themeImageInputButton(name,val_ok,img_ok)"</td><td align=center>"themeImageInputButton(name,val_cancel,img_cancel)"</td></tr>";
}

function themeImageInputButton(name,value,imageName,attrs,\
txt)  {
 txt=imageName;
 gsub(/[^a-zA-Z0-9]/," ",txt);
 if (1 || g_local_browser) {
 return "<input type=submit name=\""name"\" value=\""value"\" />";
 } else {
 return "<input type=image name=\""name"\" value=\""value"\" alt=\""imageName"\" border=0 src="iconSrc(imageName)" "attrs" /><br>"txt;
 }
}
function localImageSrc(path)  {
 if (g_local_browser ) {

 return "\"file://"path"\"";
 } else if (index(path,"/share/Apps/oversight") == 1) {



 return "\"" substr(path,12)"\"";
 } else if (index(path,"/opt/sybhttpd/default") == 1) {


 return "\"" substr(path,22)"\"";
 } else {

 return "\""SELF"?"path"\"";
 }
}
function iconSrc(imageName)  {
 return localImageSrc(APPDIR"/images/"g_icon_set"/"imageName"."ovs_icon_type);
}

function movie_listing(db,idx,\
 parts,style,p,d,otherSize,src,playBtn) {

 style=watchedStyle(db,idx,0);

 d=db[DIR,idx];

 f=substr(db[FILE,idx],length(d)+2);
 h_comment("FILE "f);

 src=db[SOURCE,0];

 if (query["select"] != "") {
 print selectCheckbox(db,idx,db[ID,idx],db[FILE,idx]);
 } else {
 if (db[PARTS,0] != "") {
 print playButton("Play" themeImageTag("player_play"))"<br>";
 otherSize="width=30 height=30";
 } else {
 otherSize=gButtonAttr;
 }
 
 playBtn=themeImageTag("player_play",otherSize);

 print vod_link(f playBtn,src,db[FILE,idx],0,0,"onkeyleftset=up",style);
 split(db[PARTS,0],parts,"/");
 for(p in parts) {
 print "<br>"vod_link(parts[p] playBtn,src,d"/"parts[p],p,p,"",style);
 }
 }
}


function tv_listing(db,db_size,idx,cols, \
 _count,_episode,i,r,c,rowTxt,eptitle,vodTxt,actualIndex,airdate) {



 _count = 0;

 for(i=0 ; i < db_size; i++) {
 _episode[_count++] = i;
 h_comment("i = ["i"] _count=["_count"] db_size=["db_size"]");
 }
 h_comment("IN COUNT:"db_size);
 h_comment("Season:"query["season"]);
 h_comment("OUT COUNT:"_count);

 heapsort(db,_count,EPISODE0,1,_episode);

 rows=int((_count-1)/cols)+1;

 print "<table width=100% class=\"listing\" >";
 for(r=0 ; r < rows ; r++) {

 rowTxt = "<tr>";
 for(c=0 ; c < cols ; c++) {

 i = c*rows + r;

 if (i < _count) {

 actualIndex=_episode[i];

 if (query["select"] == "") {
 width1=4 ; width2=0; width3=int(100/cols-width1-width2);
 } else {
 width1=4 ; width2=0; width3=int(100/cols-width1-width2);
 }
 rowTxt=rowTxt "<td class=ep"db[WATCHED,actualIndex](i%2)" width="width1"% >";

 if (query["select"] == "") {
 vodTxt=db[EPISODE0,actualIndex]".";
 attr = "";
 if (r == 0 ) {

 if (c  == 0 ) { attr = attr " onkeyleftset=up "; }
 }
 rowTxt=rowTxt vod_link(vodTxt,db[SOURCE,actualIndex],db[FILE,actualIndex], i,i,attr,watchedStyle(db,actualIndex,(i%2)));
 } else {
 vodTxt=db[EPISODE0,actualIndex];
 rowTxt=rowTxt selectCheckbox(db,actualIndex,db[ID,actualIndex],vodTxt);
 }
 rowTxt=rowTxt "</td>";



 eptitle = db[EPTITLE,actualIndex];
 if (eptitle == "" ) {
 eptitle = db[EPTITLEIMDB,actualIndex];
 if (eptitle == "" ) {
 eptitle = db[ADDITIONAL_INFO,actualIndex];
 if (eptitle == "" ) {
 eptitle = db[FILE,actualIndex];
 sub(/.*\//,"",eptitle);
 }
 }
 }
 if (length(eptitle) > 37) {
 eptitle=substr(eptitle,1,35)"..";
 }

 if (match(tolower(db[FILE,actualIndex]),"\\<proper\\>")) {
 eptitle=eptitle"&nbsp;<font class=proper>[pr]</proper>";
 }
 if (match(tolower(db[FILE,actualIndex]),"\\<repack\\>")) {
 eptitle=eptitle"&nbsp;<font class=repack>[rpk]</repack>";
 }
 eptitle = eptitle "&nbsp;" iconLink(db[FILE,actualIndex]);

 airdate=db[AIRDATE,actualIndex];
 if (airdate=="") {
 airdate=db[AIRDATEIMDB,actualIndex];
 }
 airdate = formatDate(airdate);

 rowTxt=rowTxt "<td width="width3"% ><font class=eptitle> "eptitle " " airdate "</font></td>\n";
 }
 }

 if (db_size < 2) {
 for(c = db_size ; c < 2 ; c++ ) {
 rowTxt=rowTxt "<td class=ep01 width="width1"% >&nbsp;</td>";
 rowTxt=rowTxt "<td class=ep01>&nbsp;</td>";
 rowTxt=rowTxt "<td class=eptitle width="width3"% >&nbsp;</td>";
 }
 }
 rowTxt=rowTxt "</tr>";
 if (rowTxt == "<tr></tr>" ) {
 break;
 } else {
 print rowTxt;
 }
 }
 print "</table>";
}

function formatDate(line,\
date,nonDate,monthName) {
 if (!extractDate(line,date,nonDate)) {
 return line;
 }
 split("Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec",monthName,",");

 h_comment("Date 2 "date[2]);
 h_comment("Date 2 "monthName[date[2]+0]);

 line=date[3]"."monthName[date[2]+0];
 h_comment("Line = "line);
 return line;
}




function extractDate(line,date,nonDate,\
y4,d1,d2,d1or2,m1,m2,m1or2,d13up,d,m,y,datePart,textMonth) {

 print "<!-- extractDate -->";
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

 h_comment("Date Format found yyyy/mm/dd");
 y=1 ; m = 2 ; d=3;

 } else if(match(line,m1or2 s d1or2 s y4)) { #us match before plain eu match

 h_comment("Date Format found mm/dd/yyyy");
 m=1 ; d = 2 ; y=3;

 } else if(match(line,d1or2 s m1or2 s y4)) { #eu

 h_comment("Date Format found dd/mm/yyyy");
 d=1 ; m = 2 ; y=3;

 } else if(match(line,d1or2 s "[A-Za-z]+" s y4)) { #eu

 h_comment("Date Format found dd Month yyyy");
 d=1 ; m = 2 ; y=3;
 textMonth = 1;

 } else {

 h_comment("No date format found");
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
 initMonthHash();
 if (date[2] in gMonthToNum ) {
 date[2] = gMonthToNum[date[2]];
 } else {
 return 0;
 }

 }
 return 1;
}


function getFileStyle(db,idx,gridToggle) {
 return "grid" db[CATEGORY,idx] "W" db[WATCHED,idx] "_" gridToggle ;
}
 
function trim(s) {
 sub(/^ +/,"",s);
 sub(/ +$/,"",s);
 return s;
}

function shortenMonth(d) {
 sub(/January/,"Jan",d);
 sub(/February/,"Feb",d);
 sub(/March/,"Mar",d);
 sub(/April/,"Apr",d);
 sub(/June/,"Jun",d);
 sub(/July/,"Jul",d);
 sub(/August/,"Aug",d);
 sub(/September/,"Sep",d);
 sub(/October/,"Oct",d);
 sub(/November/,"Nov",d);
 sub(/December/,"Dec",d);
 return d;
}













function get_full_sort_order(source_start,source_end,db_size,db,field,order,order_arr,\
s,order_arr2,order_size2,order_size,i,p,pos,s1,s2,x) {
 h_comment("pre full sort order "db_size);



 for(s in source_start) {
 order_size2 = get_sort_order(s,source_start,source_end,db_size,db,field,order,order_arr2);

 }



 for(s in source_start) {
 pos[s]=source_start[s];
 }

 s1 = s2 = "";
 do {
 s1="";
 s2="";
 for(s in source_start) {
 
 if(0+pos[s] < source_end[s]) {
 if (s1 == "" ) { 
 s1= s;
 } else {
 s2= s;
 x = 0+compare(db,field,order,order_arr2,pos[s1],order_arr2,pos[s2]);
 if (x < 0) {

 } else {
 s1 = s2;
 }
 }
 }
 }
 if (s1 != "" ) {

 order_arr[order_size++] = order_arr2[pos[s1]++];
 }
 } while (s2 != "");

 if ( s1 != "" ) {
 p=pos[s1];
 while(p < source_end[s1]) {
 order_arr[order_size++] = order_arr2[p++];
 }
 }


 h_comment("post get full order "db_size);

 return order_size;
}

function merge_sort_arrays(db_size,db,field,order,order_size,order_arr,order_size2,order_arr2,\
p1,p2,order_arr3,order_size3,i,x) {

 order_size3=0;
 while((p1<order_size)&&(p2<order_size2)) {

 x = 0+compare(db,field,order,order_arr,p1,order_arr2,p2);
 if (x > 0) {
 order_arr3[order_size3++] = order_arr[p1++];
 } else {
 order_arr3[order_size3++] = order_arr2[p2++];
 }

 }
 while(p1<order_size) {
 order_arr3[order_size3++] = order_arr[p1++];
 }
 while(p2<order_size2) {
 order_arr3[order_size3++] = order_arr2[p2++];
 }


 for(i=0; i < order_size3 ; i++ ) {
 order_arr[i] = order_arr3[i];
 }
 return order_size3;
}








function get_sort_order(source,source_start,source_end,db_size,db,field,order,order_arr,\
f,i,pos,maxPos,start,end,sz) {
 f="#"field"#";

 h_comment("pre get sort order "db_size);

 start = source_start[source]+0;
 end = source_end[source]+0;

 h_comment("XX sort ["start"-"end"] by "f" order "order);








 collapse_sort_index(db,start,end,f,order);

 for (i = start ; i < end ; i++ ) {
 pos=db[f,i]; #local indexed position
 order_arr[start+pos]=i;
 }

 h_comment("order size["source"] = "(end-start));

 if (0 && DEBUG) {
 for (i = start ; i < end ; i++ ) {
 h_comment(i"="db[TITLE,order_arr[i]]);
 }
 }

 h_comment("post get sort order "db_size);
 return end-start;
}




function collapse_sort_index(db,start,end,index_field,order,\
minpos,maxpos,pos,i,p,new_sort_idx,db_idx,sort_idx) {


 minpos=9999999;
 maxpos=-1;
 h_comment("index_field["index_field"]");
 for(db_idx = start ; db_idx-end < 0 ; db_idx++ ) {
 p = db[index_field,db_idx];
 if (p-minpos < 0 ) minpos = p+0;
 if (p-maxpos > 0 ) maxpos = p+0;
 sort_idx = db[index_field,db_idx];
 pos[sort_idx] = db_idx;
 }

 h_comment("maxpos="maxpos);
 h_comment("minpos="minpos);


 new_sort_idx = 0;

 if (order == 1) {
 for(sort_idx = minpos ; sort_idx <= maxpos ; sort_idx++ ) {
 if (sort_idx in pos) {
 db[index_field,pos[sort_idx]] = new_sort_idx++;
 }
 }
 } else {
 for(sort_idx = maxpos ; sort_idx >= minpos ; sort_idx-- ) {
 if (sort_idx in pos) {
 db[index_field,pos[sort_idx]] = new_sort_idx++;
 }
 }
 }
 if (new_sort_idx != (end-start)) {
 h_comment("************* Something went wrong collapsing index. "new_sort_idx "," start "," end );
 }
 return new_sort_idx;
}

function end_table_page(source_start,source_end,db_size,db,\
_P,f,o,order_arr) {


 db_size = get_full_sort_order(source_start,source_end,db_size,db,query[QSORT],query[QORDER],order_arr);



 _P=query["p"];
 if (_P == "" ) { _P = 0 };

 showMainTable(db_size,db,order_arr,gRows,gCols,_P);

 print "</form>";
 print "</body>";
}


function selfUrl(nameValuePairs, url,i) {

 n=nameValuePairs;
 gsub(/=[^&]*/,"",n);
 if (!(n in selfLinkArray)) {
 selfLinkArray[n]=selfUrl2(n);
 }
 url=selfLinkArray[n];

 return url (url == SELF ? "?" : "&" ) nameValuePairs;
}

function selfUrl2(appendedNames, url,varname,b) {

 url=SELF;

 appendedNames = "&"appendedNames"&";

 for(varname in query) {




 if (varname != "colour" && index(appendedNames,"&"varname"&") == 0) {
 if (query[varname] != "") {
 if (index(varname,"option_") == 0 ) {
 url=url "&" varname"="query[varname];
 }
 }
 } 
 }
 sub(/[&]/,"?",url);
 return url;
}

function selfLinkMultiJs(nameValuePairs,attributes,title) {
 return "<a href=\"javascript: location.replace('"'"'" selfUrl(nameValuePairs) "'"'"');\" "attributes" >"title"</a>";
}
function selfLinkMulti(nameValuePairs,attributes,title) {

 return "<a href=\"" selfUrl(nameValuePairs) "\" "attributes" >"title"</a>";

}

function selfLinkMultiWithFont(nameValuePairs,attributes,title,fontClass) {
 return selfLinkMulti(nameValuePairs,attributes,"<font class="fontClass">"title"</font>");
}

function selfLinkMultiJsWithFont(nameValuePairs,attributes,title,fontClass) {
 return selfLinkMultiJs(nameValuePairs,attributes,"<font class="fontClass">"title"</font>");
}

function href(link,attr,text) {
 return "<a href="link" "attr" >"text"</a>";
}
function jshref(link,attr,text) {
 return "<a href=\"javascript: location.replace('"'"'"link"'"'"')\" "attr" >"text"</a>";
}

function showMainTable(db_size,db,idx,rows,cols,page,\
display_index,display_count) {

 display_count = get_displayable_cells(db_size,db,idx,rows,cols,page,display_index);

 show_table_header(db_size,db);

 if (display_count < rows * cols ) {
 rows = int( (display_count-1) / cols)+1;
 }


 showTableContents(db_size,db,display_count,display_index,rows,cols,page);
 showSelectControls(page,page>0,display_count>rows*cols);
}

function showStatus(db_size,\
v) {
 v = get_new_version_id();


 if (g_catalog_message != "" ) {
 print "Status : "g_catalog_message;
 } else if (g_catalog_pending == 1 ) {
 print "Catalog update pending...";
 } else if (gLocalCount == 0) {
 print "Video index is empty. Select setup Icon and scan the internal Hard Drive.";
 } else if (ovs_new_version_check=="1" && v != "" && v > g_version ) {

 print selfLinkMulti("view=admin&idlist=&action=showinstall","","Version "v" released.");
 }
}


function getTvidLookup(ch2tvid) {
 ch2tvid["0"]=0 ; 
 ch2tvid["1"]=1;
 ch2tvid["2"]=ch2tvid["a"]=ch2tvid["b"]=ch2tvid["c"]=2;
 ch2tvid["3"]=ch2tvid["d"]=ch2tvid["e"]=ch2tvid["f"]=3;
 ch2tvid["4"]=ch2tvid["g"]=ch2tvid["h"]=ch2tvid["i"]=4;
 ch2tvid["5"]=ch2tvid["j"]=ch2tvid["k"]=ch2tvid["l"]=5;
 ch2tvid["6"]=ch2tvid["m"]=ch2tvid["n"]=ch2tvid["o"]=6;
 ch2tvid["7"]=ch2tvid["p"]=ch2tvid["q"]=ch2tvid["r"]=ch2tvid["s"]=7;
 ch2tvid["8"]=ch2tvid["t"]=ch2tvid["u"]=ch2tvid["v"]=8;
 ch2tvid["9"]=ch2tvid["w"]=ch2tvid["x"]=ch2tvid["y"]=ch2tvid["z"]=9;
}


function buildTvidList(db_size,db,filterSoFar,\
regLengthSoFar,addedTvids, i,ch2tvid,code,w,remainingWord,titleWords,depth,d,depthm) {
 i=i;
 h_comment("PreTvid "db_size);
 getTvidLookup(ch2tvid);



 regLengthSoFar = length(filterSoFar);

 h_comment("Building list :"db_size);


 tvidlink = selfLinkMulti("p=0&"QREG_FILTER"="filterSoFar "@X@X@" ,"tvid=\"@X@X@\"",""); 

 tvidMinDepth=1

 for(i = 0 ; i < db_size ; i++ ) {
 split(tolower(db[TITLE,i]),titleWords," ");
 for(w in titleWords) {
 remainingWord=substr(titleWords[w],regLengthSoFar+1,g_max_tvid_len);

 if (!(remainingWord in seenWordFragment)) {
 if(length(remainingWord) >= tvidMinDepth) {

 if (length(remainingWord) < g_max_tvid_len ) {
 depthm = length(remainingWord);
 } else {
 depthm = g_max_tvid_len;
 }



 code="";
 split(remainingWord,letters,"");
 for(depth = 1 ; depth <= depthm ; depth ++ ) {

 code=code ch2tvid[letters[depth]];


 if (!(code in addedTvids)) {
 tvidlink2=tvidlink;
 gsub(/@X@X@/,code,tvidlink2);
 print tvidlink2;
 addedTvids[code]=1;
 }
 }
 }
 seenWordFragment[remainingWord]=1;
 }
 }
 }
 h_comment("PostTvid "db_size);

}

function selectCheckbox(db,idx,idList,text,\
selected,nm) {
 if (query["select"] != "") {

 nm = CHECKBOX_PREFIX db[SOURCE,idx]"("idList")";

 if ( db[WATCHED,idx] == 1 ) {
 if (query["select"] == "Mark") {
 selected = "CHECKED";
 }
 }
 if (selected) {
 return "\
<input type=checkbox name=\""nm"\" CHECKED >\n\
<input type=hidden name=\"orig_"nm"\" value=on >\n\
<font class="query["select"]">"text"</font>";
 } else {
 return "\
<input type=checkbox name=\""nm"\"  >\n\
<font class="query["select"]">"text"</font>";
 }
 } else {
 return "<font class=Ignore>"text"</font>";
 }
}

function showSelectControls(page,prevPage,nextPage) {
 print "<table class=footer width=100% ><tr valign=top>";
 print "<td width=10%>"pageControl(page,prevPage,-1,"pgup","left")"</td>";
 if (query["view"] != "" && query["select"] == "" ) {
 print "<td align=center>"themeImageLink("view=&idlist=","name=up","back")"</td>";
 }

 print "<td align=center>";

 if (query["view"] == "" ) {
 if ( g_query_string == "" && g_local_browser ) {
 print href("/start.cgi","name=home",themeImageTag("exit"))"</td>";
 } else {
 print href(APPDIR_URL,"name=home TVID=HOME",themeImageTag("home"))"</td>";
 }
 }
 if (query["select"] == "") {
 if (allow_mark) print "<td align=center>"themeImageLink("select=Mark","tvid=EJECT","mark")"</td>";

 if (allow_delete || allow_delist) {
 print "<td align=center>"themeImageLink("select=Delete","tvid=CLEAR","delete")"</td>";
 }


 } else {
 if (query["select"] == "Mark" ) {
 print "<td>"themeImageInputButton("action","Mark","mark")"</td>"
 }
 if (query["select"] == "Delete" ) {
 if (allow_delete) print "<td>"themeImageInputButton("action","Delete","delete_data")"</td>"
 if (allow_delist) print "<td>"themeImageInputButton("action","Remove_From_List","remove_from_list")"</td>"
 }

 print "<td>"themeImageInputButton("select","Cancel","cancel")"</td>"
 }
 print "<td align=right width=10%>"pageControl(page,nextPage,1,"pgdn","right")"</td>";
 print "</tr></table>";
 print selfLinkMulti("view=&idlist=","name=upquick onfocusload",""); #This is between cells
}

function showSortCells(  order,sortField,sortText) {

 typeFilter=query[QTYPE_FILTER];

 if (typeFilter=="" ) { typeFilter="M" ; typeText="TV<br>Film"; }
 else if ( typeFilter == "T" ) { typeFilter="M" ; typeText="<b><u>TV</u></b><br>Film"; }
 else if (typeFilter=="M") { typeFilter="T" ; typeText="TV<br><b><u>Film</u></b>"; }

 watchedFilter=query[QWATCHED_FILTER];
 if (watchedFilter=="" ) { watchedFilter="W" ; watchedText="Unmarked<br>Marked"; }
 else if (watchedFilter == "U" ) { watchedFilter="W" ; watchedText="<b><u>Unmarked</u></b><br>Marked"; }
 else if (watchedFilter=="W") { watchedFilter="U" ; watchedText="Unmarked<br><b><u>Marked</u></b>"; }

 sortField=query[QSORT];

 if (sortField == TITLE ) {
 sortText="<b><u>Name</u></b><br>Age";
 sortField=INDEXTIME;
 order = -1;
 } else {
 sortText="Name<br><b><u>Age</u></b>";
 sortField=TITLE;
 order = 1;
 }


 print "<td class=redbutton>";
 print h_colour_button("red","p=0&"QTYPE_FILTER"="typeFilter,typeText);

 print "</td><td>";
 print h_colour_button("green","p=0&"QWATCHED_FILTER"="watchedFilter,watchedText);
 print "</td><td>";

 print h_colour_button("blue","p=0&"QSORT"="sortField"&"QORDER"="order,sortText);
 print "</td>";
}

function h_colour_button(colour,nameValuePairs,text) {
 return selfLinkMulti(nameValuePairs"&colour="colour,"tvid=\""colour"\"", "<font class=\""colour"button\">"text"</font>");
}

function isFiltered() {
 return (query[QSEARCH_MODE]!="" || query[QREG_FILTER] != "");
}

function show_filter_bar() {

 if (!isFiltered()) {
 print themeImageLink("p=0&"QSEARCH_MODE"=1","","find");
 } else {
 regLength = length(query[QREG_FILTER]);

 if (g_local_browser) {
 print "Use numbers to search";
 print themeImageLink("p=0&"QSEARCH_MODE"=&"QREG_FILTER"=","","start-small","width=20 height=20"); 
 print "<font class=keypad>["query[QREG_FILTER]"]</font>";
 print themeImageLink("p=0&"QSEARCH_MODE"=&"QREG_FILTER"="substr(query[QREG_FILTER],1,regLength-1),"","left-small","width=20 height=20"); 

 } else {
 print "<input type=text name=searcht value=\""query["searcht"]"\">";
 addHidden(QSEARCH_MODE);
 print "<input type=submit name=searchb value=Search >";
 print "<input type=submit name=searchb value=Hide >";
 }
 }
}

function show_table_header(db_size,db) {

 print "<table class=header width=100%><tr>"

 if (query[QTYPE_FILTER] == "M" ) {
 banner("Films");
 } else if (query[QTYPE_FILTER] == "T" ) {
 banner("TV Shows");
 } else {
 banner("All Video");
 }

 showSortCells();
 print "<td>";
 show_filter_bar();
 if (g_local_browser && query["select"]=="") {
 buildTvidList(db_size,db,query[QREG_FILTER]);
 }
 print "</td>";
 print "<td>"; showStatus(db_size); print "</td>";
 print "<td>"; print themeImageLink("view=admin&action=ask","TVID=SETUP","configure"); print "</td>";
 print "</tr></table>"

}
function banner(text,\
x) {
 print "<td align=left width=20%>";
 print "<font size=\"6\">"text"</font>";
 x="V2."substr(g_version,3);
 sub(/BETA/,"b",x);

 print "<br><font size=\"2\">"x" "g_hostname"</font>";
 print "</td>";
}




function get_displayable_cells(db_size,db,idx,rows,cols,page,output_idx,\
 pg,selected,items_per_page,page_start,page_end,_I,displayed,direct_index) {

 _I=0;
 items_per_page = rows*cols;



 displayed=0;
 selected=0;

 page_start=items_per_page*page;
 page_end = page_start+items_per_page;


 for(_I = 0 ; _I < db_size ; _I++ ) {
 direct_index=idx[_I];


 if (displayable(db,direct_index)) {
 if (selected >= page_start && selected <= page_end) {
 output_idx[displayed++] = direct_index;
 }


 if (selected >= page_end) {
 break;
 }
 selected++;
 }
 }
 return displayed;
}


function pageControl(page,on,offset,tvidName,imageBaseName) {
 if (query["select"] != "") return "";
 if (on) {
 return themeImageLink("p="(page+offset),"tvid="tvidName" name="tvidName"1 onfocusload",imageBaseName);
 } else if (query["view"] == "") {
 return themeImageTag(imageBaseName"-off");
 }
}

function showTableContents(db_size,db,count,idxArr,rows,cols,page,\
_R,_C,_I,centreRow,centreCell,w) {

 print "<table class=\"overview\" width=\"100%\" >";

 w=sprintf(" width=%d%%",100/cols);

 _I=0;


 for (_R=0 ; _R<rows ; _R++ ) {
 centreRow = (_R == int(rows/2));
 print "<tr>";
 for (_C=0 ; _C<cols ; _C++ ) {

 _I = _C * rows + _R;
 if (_I < count) {

 leftScroll=(page>0 && _C==0);
 rightScroll=(count > rows*cols && _C+1==cols);
 centreCell=centreRow && _C == int(cols/2);

 displayItem(db_size,db,idxArr,_I,w,(_R+_C)%2,leftScroll,rightScroll,centreCell);
 } else {

 printf "<td%s></td>",w;
 }
 }
 print "</tr>";
 }
 print "</table>";
}


function displayable(db,direct_index,\
 t) {


 t=query[QTYPE_FILTER]db[CATEGORY,direct_index];
 return (t!="MT" && t != "TM" );
}

function displayItem(db_size,db,idxArr,i,widthAttr,gridToggle,leftScroll,rightScroll,centreCell,\
 link,_title,_tmp,_url,attr,n,idList,j,s,t,rs,rl,idx,extensions,e,ext,gridClass,fontClass,src) {

 idx = idxArr[i];

 _title=db[TITLE,idx];
 if (gFilterRegex != "") {
 
 rs=db["rstart",idx];
 rl=db["rlength",idx];
 _title = substr(_title,1,rs-1) "<font class=match>" substr(_title,rs,rl) "</font>" substr(_title,rs+rl);
 }


 cert=db[CERT,idx];
 if ( (_tmp=index(cert,":")) > 1  ) {
 cert = " ("substr(cert,_tmp+1)")";
 } else {
 cert="";
 }

 src=db[SOURCE,idx];


 if (query["select"] == "" ) {
 split(db[OVERVIEW_EXT_LIST,idx],extensions,"|");
 ext = "";
 for(e in extensions) {
 ext = ext  iconLink(extensions[e]);

 }
 if (ext != "") {
 ext="&nbsp;"ext;
 }
 }

 attr="";
 if (centreCell) {
 attr=" name=\"centreCell\" ";
 }
 if (leftScroll) {
 attr=attr " onkeyleftset=pgup1";
 }

 if (rightScroll) {
 attr=attr " onkeyrightset=pgdn1";
 }

 if (gPosterMode == 1 && db[POSTER,idx] != "") {
 gridClass="gc";
 fontClass="fc";
 } else {
 gridClass = getFileStyle(db,idx,gridToggle);
 fontClass = watchedStyle(db,idx,gridToggle);
 }
 idList = src"("db[OVERVIEW_DETAILIDLIST,idx]")";

 if (db[CATEGORY,idx] == "T") {

 t=url_encode(db[TITLE,idx]);
 s=db[SEASON,idx];
 if (s != "" ) {
 _title = _title " S" s;
 }
 _title = addNetworkIcon(src, trimTitle(_title) cert ext);

 epCount = idList;


 gsub(/[^|]+/,"",epCount);
 if (epCount != "" ) {
 _title=_title "&nbsp;<font color=#AAFFFF size=-1>x" (length(epCount)+1)"</font>";
 }
 if (gPosterMode == 1 && db[POSTER,idx] != "") {
 _title = posterImgTag(idx,gPosterModeAttr);
 }

 link=selfLinkMultiWithFont("view=tv&idlist="idList,attr" class="gridClass,_title, fontClass);

 } else if (db[CATEGORY,idx] == "M") {

 _title = addNetworkIcon(src, trimTitle(_title) cert ext);
 if (gPosterMode == 1 && db[POSTER,idx] != "") {
 _title = posterImgTag(idx,gPosterModeAttr);
 }

 link=selfLinkMultiWithFont("view=movie&idlist="idList, attr" class="gridClass, _title, fontClass);

 } else {


 if (centreCell && query[QREG_FILTER]=="") {
 n="centreCell";
 } else {
 n=i;
 }
 _title = addNetworkIcon(src, trimTitle(_title) ext);

 h_comment("FILE = "db[FILE,idx]);
 link = vod_link(_title,src,db[FILE,idx],n,i,attr,fontClass);
 }

 printf "\t<td%s class=\"%s\">\n",widthAttr,gridClass;
 if (query["select"] != "") {
 print selectCheckbox(db,idx,db[OVERVIEW_DETAILIDLIST,idx],_title);
 } else {
 print link;
 }
 print "</td>";

}

function addNetworkIcon(src,txt) {
 if (ovs_crossview == "0") {
 return txt;
 } else if (src == "*" ) {
 return themeImageTag("harddisk","width=20 height=15") txt;
 } else {
 return themeImageTag("network","width=20 height=15") txt;
 }
}

function font(c,t) { return "<font class="c">"t"</font>"; }

function watchedStyle(db,idx,gridToggle) {
 if (db[WATCHED,idx])
 return "watched";
 else if (NOW - db[INDEXTIME,idx] < ovs_new_days*1000000 )
 return "fresh";


 else 
 return getFileStyle(db,idx,gridToggle);
}

function trimTitle(t) {
 if (length(t) > 50 ) {
 t=substr(t,1,48) " ..";
 }




 return t;

}

function quit(q) {
 quitting=1;
 quitCode=q;
 exit(q);
}

function html_encode(text) {
 gsub(/</,"\\\&lt;",text);
 gsub(/>/,"\\\&gt;",text);
 gsub(/[&]/,"\\\&amp;",text);
 gsub(/\"/,"\\\&quot;",text);
 gsub(/'"'"'/,"\\\&#39;",text);
 return text;
}

function url_encode(text) {

 if (index(text,"%")) { gsub(/[%]/,"%25",text); }
 if (index(text,"?")) { gsub(/[?]/,"%3F",text); }
 if (index(text,"&")) { gsub(/[&]/,"%26",text); }
 if (index(text," ")) { gsub(/ /,"%20",text); }
 if (index(text,":")) { gsub(/:/,"%3A",text); }
 if (index(text,"=")) { gsub(/=/,"%3D",text); }


 if (index(text,"[")) { gsub(/\[/,"%5B",text); }
 if (index(text,"]")) { gsub(/\]/,"%5D",text); }
 if (index(text,"+")) { gsub(/[+]/,"%43",text); }

 return text;
}

function url_decode(str, _I,_START) {
 _START=1;
 while ((_I=index(substr(str,_START),"%")) > 0) {
 _I  = (_START-1)+_I;
 c=substr(str,_I+1,2); # hex digits
 c=sprintf("%d",0+( "0x" c )) # Decimal
 c=sprintf("%c",0+c) # Char
 str = substr(str,1,_I-1) c substr(str,_I+3);
 _START = _I+1;
 }
 return str;
}

function parse_query_string(str,dest,\
i,j) {



 split(str,clauses,"&");
 for(i in clauses) {

 eq=index(clauses[i],"=");
 dest[url_decode(substr(clauses[i],1,eq-1))]=url_decode(substr(clauses[i],eq+1));
 }
}

function replace(str,old,new,repeat,   i,_start,_ol,_nl) {
 h_comment("REPLACE ["str"]["old"]["new"]"); 
 _start=0;
 _ol=length(old);
 _nl=length(new);
 while ((i=index(substr(str,_start+1),old)) > 0) {
 str=substr(str,1,_start+i-1) new substr(str,_start+i+_ol);
 _start += _nl;
 if (repeat == "") { break; }
 }
 h_comment("REPLACE OUT ["str"]"); 
 return str;
}

function SEND_COMMAND_TEXT(cmd,source) {
 return "\""sourceHome(source) "oversight.sh\" SAY "cmd;
}

function setDisplayParams(tvmode) {




 SD_TV = 0;
 if (!g_local_browser || tvmode == 6 || tvmode == 10 || tvmode == 13 ) {
 scanlines=720;
 } else if (tvmode <= 5 || (tvmode >= 7 && tvmode <= 9 ) || (tvmode >= 30 && tvmode <= 31) ) {
 scanlines=0;
 SD_TV=1;
 } else {
 scanlines=1080;
 }
 HD_TV = !SD_TV;

 gFontSize=ovs_font_size[scanlines]+0;
 gTitleSize=ovs_title_size[scanlines]+0;

 gPosterModeRows=ovs_poster_mode_rows[scanlines]+0;
 gPosterModeCols=ovs_poster_mode_cols[scanlines]+0;
 gPosterModeHeight=ovs_poster_mode_height[scanlines]+0;
 gPosterModeWidth=ovs_poster_mode_width[scanlines]+0;

 if (gPosterModeHeight == 0) {

 if (scanlines==0) { lines=500; }  else { lines=scanlines; }
 gPosterModeHeight=int(lines/(gPosterModeRows+1.6));
 }

 if (gPosterModeWidth == 0) {

 gPosterModeWidth=gPosterModeHeight*24/35;
 gPosterModeWidth=gPosterModeHeight*30/35;
 }

 gPosterMode = ovs_poster_mode[scanlines];
 if (gPosterMode == 1) {
 gRows=ovs_poster_mode_rows[scanlines]+0;
 gCols=ovs_poster_mode_cols[scanlines]+0;
 } else {
 gRows=ovs_rows[scanlines]+0;
 gCols=ovs_cols[scanlines]+0;
 }


 gPosterModeAttr = "width="gPosterModeWidth" height="gPosterModeHeight;

 gMoviePosterAttr="height="ovs_movie_poster_height[scanlines];
 gTvPosterAttr="height="ovs_tv_poster_height[scanlines];
 gPlotLength=ovs_max_plot_length[scanlines];
 gButtonAttr="width="ovs_button_size[scanlines]" height="ovs_button_size[scanlines];
 gCertAttr="width="ovs_certificate_size[scanlines]" height="ovs_certificate_size[scanlines];
}

function initMonthHash() {
 print "<!-- initMonthHash -->";
 if (!("Jan" in gMonthToNum)) {
 monthHash("Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec",gMonthToNum);
 monthHash("January,February,March,April,May,June,July,August,September,October,November,December",gMonthToNum);
 }
}

function monthHash(nameList,hash,\
names) {
 split(nameList,names,",");
 for(i in names) {
 hash[tolower(names[i])] = i+0;
 }
} 


BEGIN {
 startTime = systime();

 g_quote="'"'"'";

 print startTime % 60 > "/tmp/d2"; # TODO remove


 g_remote_addr=ENVIRON["REMOTE_ADDR"];
 g_query_string=ENVIRON["QUERY_STRING"];
 g_has_post_data=0;
 g_local_browser=(g_remote_addr == "127.0.0.1" )
 loadConfig();

 getline < "/tmp/tvmode" ;
 tvmode=$0;

 g_icon_set="nav/set1";

 g_hostname="'"$HOSTNAME"'";
 g_version="'"$VERSION"'";
 g_catalog_pending="'"$CATALOG_PENDING"'";
 g_catalog_running="'"$CATALOG_RUNNING"'";
 g_catalog_message="'"$CATALOG_MESSAGE"'";
 APPDIR="'$APPDIR'";
 print "<!-- Generated at "strftime()" -->";
 print "<!-- nfo read "catalog_nfo_read "-->";
 print "<!-- nfo fmt "catalog_nfo_format "-->";
 print "<!-- poster "catalog_poster_location "-->";
 print "<!-- Scan path "catalog_scan_paths "-->";
 g_ticks=systime();
 g_hdd_mount="/opt/sybhttpd/localhost.drives/HARD_DISK";

 SELF="";




 g_max_tvid_len = 2;



 num2regex[1]="([1])";
 num2regex[2]="([2abc])";
 num2regex[3]="([3def])";
 num2regex[4]="([4ghi])";
 num2regex[5]="([5jkl])";
 num2regex[6]="([6mno])";
 num2regex[7]="([7pqrs])";
 num2regex[8]="([8tuv])";
 num2regex[9]="([9wxyz])";

 g_http_method=toupper(ENVIRON["HTTP_METHOD"])
 POSTER_FILE="_poster.jpg";

 CLEAR_CACHE_CMD = " \""APPDIR"/oversight.sh\" CLEAR_CACHE ";

 INITIAL_ARGC=ARGC;


 allow_mark = (ovs_wan_mark=="1");

 allow_delete = (ovs_wan_delete=="1");

 allow_delist = (ovs_wan_delist=="1");

 allow_admin = (ovs_wan_admin=="1");

 if (g_local_browser ||\
 substr(g_remote_addr,1,8) == "192.168." ||\
 substr(g_remote_addr,1,3) == "10." ||\
 match(g_remote_addr,"^172\\.([0-9]|[12][0-9]|3[01])\\.") ) {
 allow_delist=allow_delete=allow_admin=allow_mark=1;
 }
 PID='$$' ;

 NOW="'"`date +%Y%m%d%H%M%S`"'" ;

 g_http_method="'"$METHOD"'" ;

 DEBUG="'"$DEBUG"'" ;

 g_db_fname="'"$INDEX_DB"'";


 touch(g_db_fname);
 touch(g_db_fname".idx");
 

 START_PRE_FORM();

 readFormData(query);

 setDisplayParams(tvmode);

 APPDIR_URL=SELF"?";

 if (1 || DEBUG) {
 for (i in ENVIRON) { print "<!-- ENV:" i "=" ENVIRON[i] "-->"; }
 for (i in query) { print "<!-- QUERY:" i "=" query[i] "-->"; }
 }
 doFormActions();
 db_size=0;
 db_size=selectDatabase(g_source_start,g_source_end,db,db_size);

 h_comment("Start page");
 start_page();
 h_comment("End page");
}
END {
 if (quitting) {
 system(""); #flush
 exit quitCode;
 }
 h_comment("Start endpage");
 end_page(g_source_start,g_source_end,0+db_size,db);
 h_comment("end endpage");
}

function readFormData(query,\
query2,q) {

 parse_query_string(ENVIRON["QUERY_STRING"],query);

 readFormData2(query2);


 for(q in query2) {
 query[q]=query2[q];
 }
}


function readFormData2(query,
 formPostData,crlf,unix,in_data,start_data,filename,name,cmd) {

 
 formPostData=ENVIRON["TEMP_FILE"];
 if (formPostData == "" ) return;

 boundary=ENVIRON["POST_BOUNDARY"]
 urlEncodedInPostData = ( g_http_method=="POST" && ENVIRON["POST_TYPE"] == "application/x-www-form-urlencoded" );
 
 crlf=1
 unix=0
 in_data=-1;
 start_data=-2;
 filename="";
 name="";
 g_has_post_data=1;

 while((getline < formPostData ) > 0 ) {
 if ( counter >= 0 ) {  counter++  ; }

 print "<!-- POST : "$0" -->";

 if ( urlEncodedInPostData ) {
 gsub(/[^:]+:/,"");
 parse_query_string($0,query);

 } else if ( index($1,boundary) ) {


 if (filename != "" ) {
 close(filename);
 cmd=sprintf("chown %s \"%s\"",ENVIRON["UPLOAD_OWNER"],filename);
 system(cmd);
 } else if (name != "") {
 if(name in query) {

 query[name]=query[name] "\r" value;
 } else {
 query[name]=value;
 }
 }


 counter=0;
 filename="";
 name="";
 value="";

 } else if (counter==1 && index($0,"Content-Disposition: form-data; name=")==1 ) {

 if (match($3,"name=\"[^\"]+\"")) {
 name=substr($3,RSTART+6,RLENGTH-7);
 value="";
 }
 format=crlf;
 filename="";

 if (match($0,"filename=\".*\"")) {

 filename=substr($0,RSTART+10,RLENGTH-11);
 if (filename != "") {
 filename=sprintf("%s/%s",ENVIRON["UPLOAD_DIR"],filename);
 printf "" > filename; #Clobber
 }
 }
 } else if (counter==2 && index($0,"Content-Type: application") == 1) {

 format=unix;


 } else if (counter>0 && match($0,"^\r$")) {


 counter=start_data; 

 } else if ( counter<0 ) {

 if (format==crlf ) {
 llen=length($0);
 if (substr($0,llen) == "\r") {
 $0=substr($0,1,llen-1);
 }
 }

 if (filename != "") {
 printf "%s\n",$0 >> filename;
 } else if (counter == start_data) {
 value=$0;
 } else {
 value=value "\n" $0;
 }
 counter=in_data;

 }
 }
}

function touch(f) {
 printf "" >> f;
 close(f);
 system("chown nmt:nmt "quoteFile(f));
}


function quoteFile(f,
 j,ch) {
 gsub(g_quote,g_quote "\\"g_quote g_quote,f);
 return g_quote f g_quote;
}




function h_form_start(\
url) {
 if (query["view"] == "admin") {
 url="?" # clear QUERY_STRING
 if (query["action"] == "ask" || query["action"] == "Cancel" )   {
 return;
 }
 } else {
 url = "" #keep QUERY_STRING- eg when marking or deleting maintain current view.
 }
 print "<form action=\""url"\" enctype=\"multipart/form-data\" method=" g_http_method ">";
 addHidden("cache,idlist,view,page,sort,order,"QTYPE_FILTER","QREG_FILTER","QWATCHED_FILTER);
}

function addHidden(nameList,\
 names,i) {
 split(nameList,names,",");
 for(i in names) {
 if (query[names[i]] != "" ) {
 print "<input type=hidden name=\""names[i]"\" value=\""query[names[i]]"\">";
 }
 }
}

function h_comment(msg) {

 if (DEBUG) {

 print "<!-- "systime()-startTime " " msg "-->"
 }
}





function heapsort (db,count, fieldName,fieldOrder,idx,\
 end,tmp) {
 heapify(db,count,fieldName,fieldOrder,idx);
 end=count-1;
 while (end > 0) {
 tmp=idx[0];idx[0]=idx[end];idx[end]=tmp;
 end--;
 siftdown(db,fieldName,fieldOrder,idx,0,end);
 }
}
function heapify (db,count, fieldName,fieldOrder,idx,\
 start) {
 start=int((count-2)/2)
 while (start >= 0) {
 siftdown(db,fieldName,fieldOrder,idx,start,count-1);
 start--;
 }
}
function siftdown (db,fieldName,fieldOrder,idx,start,end,\
 root,child,tmp) {
 root=start;
 while(root*2+1 <= end) {
 child=root*2+1
 if (child+1 <=end && compare(db,fieldName,fieldOrder,idx,child,idx,child+1) <= 0) {
 child++;
 }
 if (compare(db,fieldName,fieldOrder,idx,root,idx,child) > 0) {
 return
 }
 tmp=idx[root];idx[root]=idx[child];idx[child]=tmp;
 root=child;
 }
}

function compare(db,fieldName,fieldOrder,idxarr1,idx1,idxarr2,idx2) {

 if  (db[fieldName,idxarr1[idx1]] > db[fieldName,idxarr2[idx2]]) {
 return fieldOrder;
 } else {
 return -fieldOrder;
 }
}

function readFlash(\
i) {
 while((getline < "/tmp/setting.txt") > 0) {
 if ((i = index($0,"=")) > 0) {
 gSetting[substr($0,1,i-1)] = substr($0,i+1);
 }
 }
}

function admin_row(cell1,cell2,cell3,cell4) {
 return "<tr><td width=5%>"cell1"</td><td align=left width=45%>"cell2"</td><td width=5%>"cell3"</td><td align=left width=45%>"cell4"</td></tr>";
}

function show_admin(action,\
cfg,cancelText,backText) {

 cancelText = "<br>"selfLinkMulti("action=ask","","Cancel");
 backText = themeImageLink("action=ask","","back");
 h_comment("Action is ["action"]");
 h_comment("Action is ["query["action"]"]");
 if (!allow_admin) {
 print "admin disabled";
 } else if (action == "ask" || action == "Cancel" ) {

 print "<h1 class=admin>"themeImageLink("view=&idlist=&action=","","back")"Oversight Configuration</h1>";

 if (g_catalog_message != "" ) {
 print "<h3>Catalog status: "g_catalog_message"</h3>";
 } else if (g_catalog_pending == 1 ) {
 print "<h3>Catalog update requested...</h3>";
 }

 print "<table width=100% >";
 print admin_row(\
 "",\
 cfgLink("oversight.cfg","help","","Oversight Jukebox Settings General"),\
 themeImageTag("catalog"),\
 "Catalog Settings:"\
 "<br>"cfgLink("catalog.cfg","detect.help","","Scraping and Detecting")\
 "<br>" cfgLink("catalog.cfg","help","","Indexing and Renaming")\
 );


 print admin_row(\
 themeImageTag("display"),\
 "Display" \
 "<br><table >"\
 screenCfgRow("SD","sd","scanlines0")\
 "</table>",\
 themeImageTag("rescan"),\
 "<br>"selfLinkMulti("action=rescan_confirm","","Rescan internal HDD"));

 print admin_row(\
 themeImageTag("display"),\
 "<table >"\
 screenCfgRow("720","720","scanlines720")\
 "</table>",\
 themeImageTag("unpak"),\
 cfgLink("unpak.cfg","help","","Unpak: Unpacking and Repairing"));

 print admin_row(\
 themeImageTag("display"),\
 "<table >"\
 screenCfgRow("1080+","1080","scanlines1080")\
 "</table>",\
 themeImageTag("upgrade"),\
 selfLinkMulti("action=check_stable","","Check for new stable releases only")\
 "<br>"selfLinkMulti("action=check_stable_or_beta","","Check for stable or beta releases"));
 
 print admin_row(\
 themeImageTag("security"),\
 cfgLink("oversight.cfg","secure.help","","Internet Access"),\
 "",\
 selfLinkMulti("action=clearcache_confirm","","Delete Web Cache"));

 print "</table>";

 print "<hr>";

 print "<table width=100%><tr><td width=50%>";
 df_file="/tmp/df.out";
 system("df /share/. > "df_file);
 getline < df_file;
 getline < df_file;
 print "<br>Internal Disk: "  $5 " Used";
 close(df_file);
 system("rm -f -- "df_file);

 getline < "/proc/uptime";
 print "<br>Uptime : "uptime($1) ;

 getline < "/proc/loadavg";
 print "<br>Load Average : <b>"$1"</b>/1m | <b>"$2"</b>/5m | <b>"$3"</b>/15m";
 print "</td>";
 if (!g_local_browser && ovs_remove_donate_msg == 0) {
 print paypal();
 }

 print "</tr></table>";


 } else if (match(action,"^settings")) {
 cfg=query["file"];
 helpSuffix=query["help"];

 system("cd \""APPDIR"\" && ./options.sh TABLE2 \"help/"cfg"."helpSuffix"\" \""cfg"\" HIDE_VAR_PREFIX=1");
 addHidden("file");
 print confirm("action","Save Settings","save_settings","Cancel","cancel");

 } else if (match(action,"^check") || action == "showinstall" ) {






 betaInvolved = (index(tolower(gNewVersion g_version),"beta") > 0) ;


 if (gUpgradeResult) { 
 print "<br>Current version: "g_version;
 if (gNewVersion == g_version) {

 print "<br>You have the latest version";
 if (betaInvolved) {
 print "<br>"confirm("action","Re-Install","install","Cancel","cancel");
 } else {
 print backText;
 }

 } else if (index(gNewVersion,"ERROR")) {
 print "<br> Unable to access latest version";
 print "<br>"selfLinkMulti("action=ask","","Cancel");
 } else if (gNewVersion < g_version ) {
 print "<br>You appear to have a newer version. If you still want the public version use the normal application installation procedure";
 print backText;
 } else {
 print "<br>Upgrade version "gNewVersion" available" confirm("action","Install","install","Cancel","cancel");
 }
 } else {
 print "<br>An error occured looking for upgrades. Web site may be down or internet connectivity lost.";
 print backText;
 }
 
 } else if (action == "Install" || action == "Re-Install" ) {

 if (gUpgradeResult) { 
 print "<br>Upgrade operation succeed. Enjoy!!.";
 print "<br>"selfLinkMulti("action=ask","","OK");
 print "<p>if you find files are not being deleted. Please reinstall using the full installer."
 } else {
 print "<br>Upgrade may have failed.";
 print backText;
 }

 } else if (action == "undo") {

 if (gUpgradeResult) { 
 print "<br>Undo operation succeed. Please report any issue and version.";
 print "<br>"selfLinkMulti("action=ask","","OK");
 print "<p>if you find files are not being deleted. Please reinstall using the full installer."
 } else {
 print "<br>Undo operation may have failed.";
 print backText;
 }

 } else if (action == "clearcache_confirm" ) {
 print confirm("action","clearcache","clear_cache","Cancel","cancel");

 } else if (action == "rescan_confirm" ) {
 print "Scan paths: "catalog_scan_paths "<p>This will return immediately and start a background scan which will complete in 15-60 minutes (depending on number of videos).<br>Internet bandwidth (esp torrent upload) also affects overall scan speed." confirm("action","rescan","rescan","Cancel","cancel");

 } else {

 if (action == "rescan" ) print "A rescan has been scheduled";
 else if (action == "clearcache" ) print "The web cache has been cleared";
 else print action " completed";

 print backText;
 }
 print "</form></body>";
}

function paypal() {
return "<td><font size=2>Any contributions are gratefully received towards\
<font color=red>Oversight</font>,\
<font color=#FFFF00>TvNZB</font>,\
<font color=blue>Zebedee</font> and \
<font color=green>Unpak</font> scripts\
This message can be removed via Oversight Settings.</font></td>\
<td>\
<form action=\"https://www.paypal.com/cgi-bin/webscr\" method=\"post\">\
<input type=\"hidden\" name=\"cmd\" value=\"_s-xclick\">\
<input type=\"hidden\" name=\"hosted_button_id\" value=\"2496882\">\
<input type=\"image\" src=\"https://www.paypal.com/en_US/i/btn/btn_donateCC_LG.gif\" border=\"0\" name=\"submit\" alt=\"\">\
<img alt=\"\" border=\"0\" src=\"https://www.paypal.com/en_GB/i/scr/pixel.gif\" width=\"1\" height=\"1\">\
</form></td>"
}

function uptime(s,\
ut) {
 ut= (s % 60) "s " ; s=int(s/60);
 if (s) { ut = (s%60)"m "ut ; s = int(s/60); }
 if (s) { ut = (s%24)"h "ut ; s = int(s/24); }
 if (s) { ut = s"d "ut }
 return ut;
}


function cfgLink(cfg,hlpSuffix,attr,label) {
 return selfLinkMulti("action=settings&file="cfg"&help="hlpSuffix,attr,label);
}
function screenCfgRow(label,cfgLabel,class) {
 return "<tr>"\
 "<td width=25%>"label"</td><td width=25%>"cfgLink("oversight.cfg",cfgLabel".help","class="class,"text mode")"</td>" \
 "<td width=25%>"cfgLink("oversight.cfg",cfgLabel"-poster.help","class="class,"poster mode")"</td>" \
 "<td width=25%>"cfgLink("oversight.cfg",cfgLabel"-detail.help","class="class,"detail view")"</td>" \
 "</tr>";
}


function loadConfig() {
 '"`cat $APPDIR/oversight.cfg.example $APPDIR/oversight.cfg`"'
 '"`cat $APPDIR/catalog.cfg.example $APPDIR/catalog.cfg`"'
}


' </dev/null
}


use_cache() {




 case "$TEMP_FILE$DEBUG" in
 0) #No Post Parameters and DEBUG is off
 case "$QUERY_STRING" in
 *cache=0*|*=admin*|*remote=*)
 return 1 #Error code - Do not cache
 ;;
 *)
 egrep -ql 'ovs_enable_web_cache=(|")1' "$APPDIR/oversight.cfg" 
 return $?
 ;;
 esac
 ;;
 *)
 return 1 #Error code - Do not cache
 ;;
 esac
}




get_cached_page() {

 cacheId="$1"

 case "$cacheId" in 
 */*) cacheId=`echo "$cacheId" | sed 's,/,_,g'` ;;
 esac

 cachedPage="$CACHE_DIR/page-$cacheId" 
 cachedList="$CACHE_DIR/list-$cacheId" 


 PLAYLIST=/tmp/playlist.htm



 if [ ! -f "$cachedPage" ]; then
 if [ ! -d "$CACHE_DIR" ] ; then
 mkdir -p "$CACHE_DIR" 
 chown $OWNER "$CACHE_DIR"
 fi

 if MAIN_PAGE > "$cachedPage" ; then
 cp "$PLAYLIST" "$cachedList"
 chown $OWNER "$cachedPage" "$cachedList" 
 fi
 fi


 cat "$cachedPage"
 cp "$cachedList" "$PLAYLIST"
}

chown $OWNER "$APPDIR/index.db"* "$APPDIR/"*.cfg*

err_page=$TMPDIR/oversight.$$.err

if use_cache && [ "$CACHE_ENABLED" -eq 1 ] ; then
 get_cached_page "$REMOTE_ADDR-$HOSTNAME-$QUERY_STRING" 2>"$err_page"
else
 out=$APPDIR/logs/ovs.$$.html 
 MAIN_PAGE 2>$err_page 


fi

if [ -s $err_page ] ; then
 echo "</style></head><body>ERROR"
 cat $err_page
fi
rm -f -- "$err_page" 


