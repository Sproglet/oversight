#!/bin/sh
#! $Id$
#!This is a compacted file. If looking for the source see catalog.sh.full
#!If not compressed then awk will report "bad address" error on some platforms.
#!
#!blank lines kept to preserve line numbers reported in errors.
#!All leading white space trimmed so make sure lines ending in \ have any mandatory white space included.
#!
#! See end of file for Compress command.

#






set -u  #Abort with unset variables
set -e  #Abort with any error can be suppressed locally using EITHER cmd||true OR set -e;cmd;set +e
VERSION=20091028-1BETA


NMT_APP_DIR=
nmt_version=unknown

for d in /mnt/syb8634 /nmt/apps ; do
if [ -f $d/MIN_FIRMWARE_VER ] ; then
NMT_APP_DIR=$d
nmt_version=`cat $NMT_APP_DIR/VERSION`
fi
done









#




DEBUG=1

EXE=$0
while [ -L "$EXE" ] ; do
EXE=$( ls -l "$EXE" | sed 's/.*-> //' )
done
APPDIR=$( echo $EXE | sed -r 's|[^/]+$||' )
APPDIR=$(cd "${APPDIR:-.}" ; pwd )

is_nmt() {
[ -n "$NMT_APP_DIR" ]
}

NMT=0
if is_nmt ; then
uid=nmt
gid=nmt
if [ -d /share/bin ] ; then
PATH="/share/bin:$PATH" && export PATH
fi
else
uid=root
gid=None
fi


export OVERSIGHT_ID="$uid:$gid"


AWK="/share/Apps/gawk/bin/gawk"
if [ ! -x "$AWK" ] ; then
AWK=awk
fi
AWK=awk





if [ -d "$APPDIR/bin" ] ; then

export PATH="$APPDIR/bin:$PATH"

case "$nmt_version" in
*-408) export PATH="$APPDIR/bin/nmt200:$PATH" ;;
*-40[23]) export PATH="$APPDIR/bin/nmt100:$PATH" ;;
esac
fi



set +e

PERMS() {
chown -R $OVERSIGHT_ID "$@" || true
}

tmp_root=/tmp/oversight
if is_nmt ; then

tmp_root=/share/tmp/oversight
fi

tmp_dir=$tmp_root/$$
rm -fr "$tmp_dir"
mkdir -p $tmp_dir
PERMS $tmp_dir

INDEX_DB="$APPDIR/index.db"
if [ ! -s "$INDEX_DB" ] ; then
echo "#Index" > "$INDEX_DB"
PERMS "$INDEX_DB"
fi

PLOT_DB="$APPDIR/plot.db"
if [ ! -s "$PLOT_DB" ] ; then
touch "$PLOT_DB"
PERMS "$PLOT_DB"
fi

CONF_FILE="$APPDIR/conf/catalog.cfg"
DEFAULTS_FILE="$APPDIR/conf/.catalog.cfg.defaults"

if [ ! -f "$CONF_FILE" ] ; then
cp "$CONF_FILE.example" "$CONF_FILE"
fi





if grep -q '[-]' "$CONF_FILE" ; then
tmpFile="$tmp_dir/catalog.cfg.$$"
sed 's/[-]$//' "$CONF_FILE" > "$tmpFile"
cat "$tmpFile" > "$CONF_FILE"
rm -f "$tmpFile"
fi
. "$CONF_FILE"

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

START_DIR="$PWD"

check_missing_settings

if [ -z "$*" ] ; then
cat<<USAGE
usage $0 [STDOUT] [IGNORE_NFO] [WRITE_NFO] [DEBUG] [REBUILD] [NOACTIONS] [RESCAN] [NEWSCAN]
[RENAME] [RENAME_TV] [RENAME_FILM] [DRYRUN]
[GET_POSTERS] [UPDATE_POSTERS]
[GET_FANART] [UPDATE_FANART]
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
NEWSCAN        - Rescan default paths - new media only
PARALLEL_SCAN  - Allow multiple scans with RESCAN or NEWSCAN keyword
NOACTIONS      - Do not run any actions and hide Delete actions from overview.
STDOUT         - Write to stdout (if not present output goes to log file)
GET_POSTERS    - Download posters
UPDATE_POSTERS- Fetch new posters for each scanned item.
GET_FANART     - Download fanart
UPDATE_FANART - Fetch new fanart for each scanned item.
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
shift
echo "[$USER] != [$u]"

a="$0 $(quoted_arg_list "$@")"
echo "CMD=$a"
exec su $u -s /bin/sh -c "$a"
fi
}

get_unpak_cfg() {
for ext in cfg cfg.example ; do
for nzd in "$APPDIR/conf" /share/Apps/NZBGet/.nzbget /share/.nzbget ; do
if [ -f "$nzd/unpak.$ext" ] ; then 
echo "$nzd/unpak.$ext"
return
fi
done
done
}

catalog() {


UNPAK_CFG=`get_unpak_cfg`
echo UNPAK="[$UNPAK_CFG]"

Q="'"




LS=ls
if [ -f /share/bin/ls ] ; then
LS=/share/bin/ls
fi




$AWK '




function pad_episode(e) {
if (match(e,"^[0-9][0-9]")) {
return e
} else {
return "0"e
}
}

function timestamp(label,x) {

if (index(x,g_tk) ) gsub(g_tk,"",x)
if (index(x,g_tk2) ) gsub(g_tk2,"",x)

if (index(x,"d=") ) {
sub("password.?=([^,]+)","password=xxx",x)
sub("pwd=([^,]+)","pwd=xxx",x)
sub("passwd=([^,]+)","passwd=xxx",x)
}

if (systime() != g_last_ts) {
g_last_ts=systime()
g_last_ts_str=strftime("%H:%M:%S : ",g_last_ts)
}
print label" '$LOG_TAG' "g_last_ts_str x
}

function DEBUG(x) {

if ( DBG ) {
timestamp("[DEBUG]",x)
}

}


function DEBUG2(x) {

if ( DBG-1 > 0 ) {
timestamp("[DEBUG]",x)
}

}


function load_settings(file_name,\
i,n,v,option) {

INF("load "file_name)
FS="\n"
while((getline option < file_name ) > 0 ) {


if ((i=match(option,"[^\\\\]#")) > 0) {
option = substr(option,1,i)
}


sub(/ *= */,"=",option)
option=trim(option)

sub("=[\""g_quote"]","=",option)
sub("[\""g_quote"]$","",option)
if (match(option,"^[A-Za-z0-9_]+=")) {
n=substr(option,1,RLENGTH-1)
v=substr(option,RLENGTH+1)


if (n in g_settings) {

if (index(n,"catalog_movie_search") == 1 || n="catalog_format_tags" ) {

INF("Ignoring user setings for "n)

} else {
if (g_settings[n] != v ) {
INF("Overriding "n": "g_settings[n]" -> "v)
}
g_settings[n] = v
}
} else {
g_settings_orig[n]=v
g_settings[n] = v
INF(n"=["g_settings[n]"]")
}
}
}
close(file_name)
}

function plugin_error(p) {
ERR("Unknown plugin "p)
}

function get_alt_website(testurl,newurlregex,\
i,links) {
scanPageForMatches(testurl,newurlregex,0,0,"",links)
bestScores(links,links,0)
for(i in links) {
return i
}
}


BEGIN {
g_start_time = systime()

g_batch_size=30
g_tvdb_user_per_episode_api=1
g_cvs_sep=" *, *"
g_opt_dry_run=0
yes="yes"
no="no"
g_quote="'"'"'"


g_imdb_regex="tt[0-9][0-9][0-9][0-9][0-9]+\\>"

ELAPSED_TIME=systime()
UPDATE_TV=1
UPDATE_MOVIES=1
GET_POSTERS=0
GET_FANART=0
UPDATE_POSTERS=0
UPDATE_FANART=0
get_folders_from_args(FOLDER_ARR)
}

function report_status(msg) {
if (msg == "") {
rm(g_status_file,1)
} else {
print msg > g_status_file
close(g_status_file)
INF("status:"msg)
set_permissions(g_status_file)
}
}

function get_new_folders(folder_list,timestamp_file,\
new_list,f,i,j,dir,newfile,newdir) {
if (!is_file(timestamp_file)) {
return
}
DEBUG("Checking for changed content")
for( i in folder_list ) {
dir=folder_list[i]
if (dir) {
DEBUG("Checking "dir" for changed content")
f=NEW_CAPTURE_FILE("NEWFOLDERS")
exec("touch "quoteArg(f)" ; cd "quoteArg(dir)" && find . -newer "quoteArg(timestamp_file)" > "quoteArg(f))
DEBUG("end find")
while((getline newfile < f) > 0) {
DEBUG("find line "newfile)



#

newdir=dir"/"newfile

gsub(/\/\.\//,"/",newdir)

if (is_dir(newdir) ) {
DEBUG("Changed content - "newdir)
} else {
newdir=dirname(newdir)
DEBUG("Changed content - "dir"/"newfile" > "newdir)
}
new_list[newdir]=1
}
DEBUG("close find "f)
close(f)
} else {
DEBUG("Ignoring blank "dir)
}
}


delete folder_list
i=1
for(j in new_list) {
folder_list[i++] = j
}

}

function get_mounts(mtab,\
line,parts,f) {
if ("@ovs_fetched" in mtab) return
f="/etc/mtab"
while((getline line < f ) > 0) {
split(line,parts," ")
mtab[parts[2]]=1
DEBUG("mtab ["parts[2]"]")
}
mtab["@ovs_fetched"] = 1
}

function get_settings(settings,\
line,f,n,v,n2,v2) {
if ("@ovs_fetched" in settings) return

f="/tmp/setting.txt"
while((getline line < f ) > 0) {
n=index(line,"=")
v=substr(line,n+1)
n=substr(line,1,n-1)
settings[n] = v
DEBUG("setting ["n"]=["v"]")



if (n ~ /^servname/ ) {

n2="servname_"v
v2="servlink"substr(n,length(n))

settings[n2] = v2
DEBUG("setting *** ["n2"]=["v2"]")
}
}
close(f)
settings["@ovs_fetched"] = 1
}

function parse_link(link,details,\
parts,i,x) {

if (link == "") return 0

split("link="link,parts,"&")


if (!(3 in parts)) return 0
for(i in parts) {
split(parts[i],x,"=")
details[x[1]]=x[2]
}
return 1
}

function is_mounted(path,\
f,result,line) {
result = 0
f = "/etc/mtab"
while ((getline line < f) > 0) {
if (index(line," "path" cifs ") || index(line," "path" nfs ")) {
result=1
break
}
}
close(f)
DEBUG("is mounted "path" = "result)
return result
}


function nmt_mount_share(s,settings,\
path,link_details,p,newlink,usr,pwd,lnk) {

path = g_mount_root s

if (is_mounted(path)) {

DEBUG(s " already mounted at "path)
return path
}

get_settings(settings)

DEBUG("servname_"s" = "settings[settings["servname_"s]])
if (parse_link(settings[settings["servname_"s]],link_details) == 0) {
DEBUG("Could not find "s" in shares")
return ""
}

lnk=link_details["link"]
usr=link_details["smb.user"]
pwd=link_details["smb.passwd"]

DEBUG("Link for "s" is "lnk)

p = mount_link(path,lnk,usr,pwd) 


if ( p == "" ) {
if ( index(lnk,"smb:") ) {
if ( match(lnk,"[0-9]\\.[0-9]") == 0) {
INF("Trying to resolve windows name")
newlink = wins_resolve(lnk)
if (newlink != "" && newlink != lnk ) {
p = mount_link(path,newlink,usr,pwd) 
}
}
}
}
return p
}

function mount_link(path,link,user,password,\
remote,cmd,result,t) {

remote=link

sub(/^(nfs:\/\/|smb:)/,"",remote)

if (link ~ "nfs:") {

cmd = "mkdir -p "path" && mount -o soft,nolock,timeo=10 "remote" "path

} else if (link ~ "smb:") {

cmd = "mkdir -p "path" && mount -t cifs -o username="user",password="password" "remote" "path

sub(/ username=,/," username=x,",cmd)

} else {

ERR("Dont know how to mount "link)
path=""
}
t = systime()
result = exec(cmd)
if (result == 255 && systime() - t <= 1 ) {


INF("Ignoring mount error")
result=0
}
if (result) {
ERR("Unable to mount share "link)
path=""
}
return path
}


function wins_resolve(link,\
line,host,ip,newlink,hostend,cmd) {
cmd = "nbtscan "g_tmp_settings["eth_gateway"]"/24 > "quoteArg(g_winsfile)
DEBUG(cmd)
exec(cmd);;
if(match(link,"smb://[^/]+")) {
hostend=RSTART+RLENGTH
host=substr(link,7,RLENGTH-6)

while (newlink == "" && (getline line < g_winsfile ) > 0 ) {
if (index(line," "g_tmp_settings["workgroup"]"\\"host" ")) {
INF("Found Wins name "line)
if (match(line,"^[0-9.]+")) {
ip=substr(line,RSTART,RLENGTH)
newlink="smb://"ip substr(link,hostend)
break
}
} else {
DEBUG("skip "line)
}
}
close(g_winsfile)
}
INF("new link "newlink)
return newlink
}


function nmt_get_share_path(f,\
share,share_path,rest) {
if (f ~ "^/") {
DEBUG("nmt_get_share_path "f" unchanged")
return f
} else {
share=g_share_map[f]
rest=f
sub(/^[^\/]+/,"",rest)
share_path=g_share_name_to_folder[share] rest

DEBUG("nmt_get_share_path "f" = "share_path)
return share_path
}
}


END{
g_user_agent="Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20040613 Firefox/0.8.0+"
g_wget_opts="-T 20 -t 2 -w 2 -q --no-check-certificate "


g_mount_root="/opt/sybhttpd/localhost.drives/NETWORK_SHARE/"
g_winsfile = APPDIR"/conf/wins.txt"
g_item_count = 0

g_plot_file="'"$PLOT_DB"'"
g_plot_app=quoteArg(APPDIR"/bin/plot.sh")

for(i in g_settings) {
g_settings_orig[i] = g_settings[i]
}

g_db_lock_file=APPDIR"/catalog.lck"
g_scan_lock_file=APPDIR"/catalog.scan.lck"
g_status_file=APPDIR"/catalog.status"
g_abc="abcdefghijklmnopqrstuvwxyz"
g_ABC=toupper(g_abc)
g_tagstartchar=g_ABC g_abc":_"

load_catalog_settings()

split(g_settings["catalog_tv_plugins"],g_tv_plugin,g_cvs_sep)

if (g_settings["catalog_fetch_posters"] == "yes") {
GET_POSTERS=1
}

if (g_settings["catalog_fetch_fanart"] == "yes") {
GET_FANART=1
}








INDEX_DB_NEW = INDEX_DB "." JOBID ".new"
INDEX_DB_OLD = INDEX_DB "." DAY

DEBUG("RENAME_TV="RENAME_TV)
DEBUG("RENAME_FILM="RENAME_FILM)

set_db_fields()


ACTION_NONE="0"
ACTION_REMOVE="r"
ACTION_DELETE_MEDIA="d"
ACTION_DELETE_ALL="D"

g_settings["catalog_format_tags"]="\\<("tolower(g_settings["catalog_format_tags"])")"

gsub(/ /,"%20",g_settings["catalog_cert_country_list"])
split(g_settings["catalog_cert_country_list"],gCertificateCountries,",")

gExtList1="avi|divx|mkv|mp4|ts|m2ts|xmv|mpg|mpeg|mov|m4v|wmv"
gExtList2="img|iso"

gExtList1=tolower(gExtList1) "|" toupper(gExtList1)
gExtList2=tolower(gExtList2) "|" toupper(gExtList2)

gExtRegexIso="\\.("gExtList2")$"


gExtRegEx1="\\.("gExtList1")$"


gExtRegExAll="\\.("gExtList1"|"gExtList2")$"


split(g_settings["catalog_title_country_list"],gTitleCountries,g_cvs_sep)

g_months_short="Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec"
monthHash(g_months_short,"|",gMonthConvert)
g_tk="AQ1W1R0GAY5H7K1L8MFN9P1T2YDUAJF"
g_tk2="2qdr5t1vexeyep0k5l7m9nchdjfs4zz10xbv3s3w7qsehndjmckldplagscql1wnarkepv14"

g_months_long="January|February|March|April|May|June|July|August|September|October|November|December"
monthHash(g_months_long,"|",gMonthConvert)
split(g_months_long,g_month_en,"|")


if ( g_settings["catalog_tv_file_fmt"] == "" ) RENAME_TV=0
if  ( g_settings["catalog_film_folder_fmt"] == "") RENAME_FILM=0

CAPTURE_PREFIX=tmp_dir"/catalog."

g_search_yahoo = "http://search.yahoo.com/search?p="
g_search_bing = "http://www.bing.com/search?q="


g_search_yahoo2 = get_alt_website(g_search_yahoo"test","http://[^.]*.?search.yahoo.com/search")
if (g_search_yahoo2) {
g_search_yahoo = g_search_yahoo2"?p="
INF("local yahoo search = "g_search_yahoo)
}

THIS_YEAR=substr(NOW,1,4)

scan_options="-Rl"

if (RESCAN == 1 || NEWSCAN == 1) {
if (!(1 in FOLDER_ARR)) {

if (NEWSCAN == 1) {
INF("Scanning watch paths")
folder_list=g_settings["catalog_watch_paths"]
} else {
INF("Scanning default and watch paths")
folder_list=g_settings["catalog_scan_paths"]
if (g_settings["catalog_watch_paths"] != "") {
folder_list = folder_list "," g_settings["catalog_watch_paths"]
}
}
trim(folder_list)
sub(/^,+/,"",folder_list)
sub(/,+$/,"",folder_list)

split(folder_list,FOLDER_ARR,g_cvs_sep)
}
if (PARALLEL_SCAN != 1 ) {
if (!lock(g_scan_lock_file) ) {
INF("Scan already in progress")
exit
}
}
}

g_timestamp_file=APPDIR"/.lastscan"


if (isnmt()) {
for(f in FOLDER_ARR) {
if (FOLDER_ARR[f] ~ /^[^\/.]/  ) {

share_name=FOLDER_ARR[f]
sub(/\/.*/,"",share_name)

if (!(share_name in g_share_name_to_folder)) {
g_share_name_to_folder[share_name] = nmt_mount_share(share_name,g_tmp_settings)
DEBUG("share name "share_name" = "g_share_name_to_folder[share_name])
}
if (g_share_name_to_folder[share_name]) {
g_share_map[FOLDER_ARR[f]] = share_name
FOLDER_ARR[f] = nmt_get_share_path(FOLDER_ARR[f])
} else {

FOLDER_ARR[f] = "'"$START_DIR"'/"FOLDER_ARR[f]
if (!is_file_or_folder(FOLDER_ARR[f])) {
INF(FOLDER_ARR[f]" not a share or file")
delete FOLDER_ARR[f]
}
}
}
}
}


if (NEWSCAN) {
get_new_folders(FOLDER_ARR,g_timestamp_file)
scan_options="-l"
}

for(f in FOLDER_ARR) {
INF("Folder "f"="FOLDER_ARR[f])
}


if (hash_size(FOLDER_ARR)) {

gMovieFileCount = 0
gMaxDatabaseId = 0

load_settings("'$UNPAK_CFG'")
unpak_nmt_pin_root=unpak_option["unpak_nmt_pin_root"]

g_tk = apply(g_tk)
g_tk2 = apply(g_tk2)
scan_folder_for_new_media(FOLDER_ARR,scan_options)


clean_capture_files()

et=systime()-ELAPSED_TIME

for(dm in g_search_count) {
DEBUG(dm" : "g_search_count[dm]" searches"); 
}
for(method in g_search_total) {

DEBUG(method" Search hits/total = "g_search_hits[method]"/"g_search_total[method]"="(100.0*g_search_hits[method]/g_search_total[method])"%")
}
DEBUG(sprintf("Finished: Elapsed time %dm %ds",int(et/60),(et%60)))


for(i in g_settings) {
if (!(i in g_settings_orig)) {
WARNING("Undefined setting "i" referenced")
}
}

}

rm(g_status_file)

if (RESCAN == 1 || NEWSCAN == 1) {
print "last scan at " strftime(systime()) > g_timestamp_file
close(g_timestamp_file)
unlock(g_scan_lock_file)
}
if (hash_size(FOLDER_ARR)) {
if (lock(g_db_lock_file)) {
remove_absent_files_from_new_db(INDEX_DB)
system(g_plot_app" compact "quoteArg(g_plot_file)" "quoteArg(INDEX_DB))
unlock(g_db_lock_file)
}
}
}


function merge_into_index(indexToMergeHash,\
doit) {

for(doit in indexToMergeHash) {
break
}

if (doit == "" ) {
INF("Nothing to merge")

} else if (g_opt_dry_run) {

INF("Database update skipped - dry run")

} else if (lock(g_db_lock_file)) {


print > INDEX_DB_NEW
close(INDEX_DB_NEW)

copyUntouchedToNewDatabase(INDEX_DB,INDEX_DB_NEW,indexToMergeHash)


add_new_scanned_files_to_database(indexToMergeHash,INDEX_DB_NEW)

replace_database_with_new(INDEX_DB_NEW,INDEX_DB,INDEX_DB_OLD)

unlock(g_db_lock_file)

delete indexToMergeHash
}

}

function is_locked(lock_file,\
pid) {
if (!is_file(lock_file)) return 0

pid=""
if ((getline pid < lock_file) >= 0) {
close(lock_file)
}
if (pid == "" ) {
DEBUG("Not Locked = "pid)
return 0
} else if (is_dir("/proc/"pid)) {
if (pid == PID ) {
DEBUG("Locked by this process "pid)
return 0
} else {
DEBUG("Locked by another process "pid " not "PID)
return 1
}
} else {
DEBUG("Was locked by dead process "pid " not "PID)
return 0
}
}

function lock(lock_file,\
attempts,sleep,backoff) {
attempts=0
sleep=10
split("10,10,20,30,60,120,300,600,600,600,600,600,600,600,600,600,600,1200",backoff,",")
for(attempts=1 ; (attempts in backoff) ; attempts++) {
if (!is_locked(lock_file)) {
print PID > lock_file
close(lock_file)
INF("Locked "lock_file)
set_permissions(quoteArg(lock_file))
return 1
}
sleep=backoff[attempts]
WARNING("Failed to get exclusive lock. Retry in "sleep" seconds.")
system("sleep "sleep)
}
ERR("Failed to get exclusive lock")
return 0
}

function unlock(lock_file) {
INF("Unlocked "lock_file)
system("rm -f -- "quoteArg(lock_file))
report_status("")
}

function monthHash(nameList,sep,hash,\
names,i) {
split(nameList,names,sep)
for(i in names) {
hash[tolower(names[i])] = i+0
}
} 

function replace_database_with_new(newdb,currentdb,olddb) {

INF("Replace Database")

system("cp -f "quoteArg(currentdb)" "quoteArg(olddb))

touch_and_move(newdb,currentdb)

set_permissions(quoteArg(currentdb)" "quoteArg(olddb))
}

function set_permissions(shellArg) {
if (ENVIRON["USER"] != '$uid' ) {
return system("chown '$OVERSIGHT_ID' "shellArg)
}
return 0
}

function capitalise(text) {
text=" "text
while (match(text," [a-z]") > 0) {
text=substr(text,1,RSTART) toupper(substr(text,RSTART+1,1)) substr(text,RSTART+2)
}
gsub(/\<Ii\>/,"II",text)
return substr(text,2)
}

function set_db_fields() {

ID=db_field("_id","ID","",0)

WATCHED=db_field("_w","Watched","watched") 
PARTS=db_field("_pt","PARTS","")
FILE=db_field("_F","FILE","filenameandpath")
NAME=db_field("_N","NAME","")
DIR=db_field("_D","DIR","")


ORIG_TITLE=db_field("_ot","ORIG_TITLE","originaltitle")
TITLE=db_field("_T","Title","title") 
DIRECTOR=db_field("_d","Director","director") 
CREATOR=db_field("_c","Creator","creator") 
AKA=db_field("_K","AKA","")

CATEGORY=db_field("_C","Category","")
ADDITIONAL_INF=db_field("_ai","Additional Info","")
YEAR=db_field("_Y","Year","year") 

SEASON=db_field("_s","Season","season") 
EPISODE=db_field("_e","Episode","episode")

GENRE=db_field("_G","Genre","genre") 
RATING=db_field("_r","Rating","rating")
CERT=db_field("_R","CERT","mpaa")
PLOT=db_field("_P","Plot","plot")
EPPLOT=db_field("_ep","Plot","plot")
URL=db_field("_U","URL","url")
POSTER=db_field("_J","Poster","thumb")
FANART=db_field("_fa","Fanart","fanart")

DOWNLOADTIME=db_field("_DT","Downloaded","")
INDEXTIME=db_field("_IT","Indexed","")
FILETIME=db_field("_FT","Modified","")

SEARCH=db_field("_SRCH","Search URL","search")
PROD=db_field("_p","ProdId.","")
AIRDATE=db_field("_ad","Air Date","aired")
TVCOM=db_field("_tc","TvCom","")
EPTITLE=db_field("_et","Episode Title","title")
EPTITLEIMDB=db_field("_eti","Episode Title(imdb)","")
AIRDATEIMDB=db_field("_adi","Air Date(imdb)","")
NFO=db_field("_nfo","NFO","nfo")

IMDBID=db_field("_imdb","IMDBID","id")
}



function db_field(key,name,tag) {
g_db_field_name[key]=name
gDbTag2FieldId[tag]=key
gDbFieldId2Tag[key]=tag
return key
}

function scan_folder_for_new_media(folderArray,scan_options,\
f,fcount) {


gLS_FILE_POS=0
gLS_TIME_POS=0; 


findLSFormat()

for(f in folderArray ) {

fcount++

if (folderArray[f]) {
report_status("folder "fcount)
scan_contents(folderArray[f],scan_options)
}
}

}

function findLSFormat(\
tempFile,folderNameNext,i,currentFolder) {

DEBUG("Finding LS Format")

tempFile=NEW_CAPTURE_FILE("LS")
exec(LS" -Rl /proc/"JOBID" > "tempFile )
FS=" "
folderNameNext=1

while((getline < tempFile) > 0 ) {
if (folderNameNext) {
currentFolder = $0
sub(/\/*:/,"",currentFolder)
DEBUG("Folder = "currentFolder)
folderNameNext=0
} else if ($0 == "" ) {
folderNameNext=1
}  else {
if (substr(currentFolder,1,5) == "/proc" ) {
if (index($0,"fd") && match($0,"\\<fd\\>")) {
INF("LS Format "$0)
for(i=1 ; i - NF <= 0 ; i++ ) {
if ($i == "fd") gLS_FILE_POS=i
if (index($i,":")) gLS_TIME_POS=i
}
DEBUG("File position at "gLS_FILE_POS)
DEBUG("Time position at "gLS_TIME_POS)
break
} 
}
}
}
close(tempFile)

}


function scan_contents(root,scan_options,\
tempFile,currentFolder,skipFolder,i,folderNameNext,perms,w5,lsMonth,\
lsDate,lsTimeOrYear,f,d,extRe,pos,store,lc,nfo,quotedRoot,scan_line,scan_words) {

DEBUG("PreScanning "root)
if (root == "") return

tempFile=NEW_CAPTURE_FILE("MOVIEFILES")


if (root != "/" ) {
gsub(/\/+$/,"",root); 
}

quotedRoot=quoteArg(root)

extRe="\\.[^.]+$"





DEBUG("Scanning "quotedRoot)



exec("( "LS" "scan_options" "quotedRoot"/ || "LS" "scan_options" "quotedRoot" ) > "tempFile )
exec("ls -l "tempFile)
currentFolder = root
skipFolder=0
folderNameNext=1

while((getline scan_line < tempFile) > 0 ) {




store=0

if (scan_line == "") continue

if (match(scan_line,"^total [0-9]+$")) continue

split(scan_line,scan_words," +")

perms=scan_words[1]

if (!match(substr(perms,2,9),"^[-rwxsSt]+$") ) {





if (gMovieFileCount > g_batch_size ) {
identify_and_catalog_scanned_files()
}


currentFolder = scan_line
sub(/\/*:$/,"",currentFolder)
DEBUG("Folder = "currentFolder)
folderNameNext=0
if ( currentFolder ~ g_settings["catalog_ignore_paths"] ) {
skipFolder=1
INF("Ignore path "currentFolder)
} else if(unpak_nmt_pin_root != "" && index(currentFolder,unpak_nmt_pin_root) == 1) {
skipFolder=1
INF("SKIPPING "currentFolder)
} else if (currentFolder in g_fldrCount) {

WARNING("Already visited "currentFolder)
skipFolder=1


} else {
skipFolder=0
g_fldrMediaCount[currentFolder]=0
g_fldrInfoCount[currentFolder]=0
g_fldrCount[currentFolder]=0
}

} else if (!skipFolder) {

lc=tolower(scan_line)

if ( lc ~ g_settings["catalog_ignore_names"] ) {
INF("Ignore name "scan_line)
continue
}

w5=lsMonth=lsDate=lsTimeOrYear=""


w5=scan_words[5]

if ( gLS_TIME_POS ) {
lsMonth=tolower(scan_words[gLS_TIME_POS-2])
lsDate=scan_words[gLS_TIME_POS-1]
lsTimeOrYear=scan_words[gLS_TIME_POS]
}




pos=index(scan_line,scan_words[2])
for(i=3 ; i - gLS_FILE_POS <= 0 ; i++ ) {
pos=indexFrom(scan_line,scan_words[i],pos+length(scan_words[i-1]))
}
scan_line=substr(scan_line,pos)
lc=tolower(scan_line)


if (substr(perms,1,1) != "-") {
if (substr(perms,1,1) == "d") {

if (currentFolder in g_fldrCount) {
g_fldrCount[currentFolder]++
}

DEBUG("Folder ["scan_line"]")

if (scan_line == "VIDEO_TS" && is_file(currentFolder"/VIDEO_TS/VTS_01_0.VOB") ) {

if (match(currentFolder,"/[^/]+$")) {
f = substr(currentFolder,RSTART+1)
d = substr(currentFolder,1,RSTART-1)
}

storeMovie(gMovieFileCount,f"/",d,calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW))
setNfo(gMovieFileCount,"/$",".nfo")
gMovieFileCount++
skipFolder=1
}
}
continue
}


if (match(lc,gExtRegexIso)) {


if (length(w5) - 10 < 0) {
INF("Skipping image - too small")
} else {
store=1
}

} else if (match(scan_line,"unpak.???$")) {

gDate[currentFolder"/"scan_line] = calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW)

} else if (match(lc,gExtRegEx1)) {



if (g_fldrMediaCount[currentFolder] > 0 && gMovieFileCount - 1 >= 0 ) {
if ( checkMultiPart(scan_line,gMovieFileCount) ) {


if ( !setNfo(gMovieFileCount-1,".(|cd|disk|disc|part)[1-9]" extRe,".nfo") ) {
setNfo(gMovieFileCount-1, extRe,".nfo")
}
} else {
store=2
}
} else {

store=2
}

} else if (match(lc,"\\.nfo$")) {

nfo=currentFolder"/"scan_line
g_fldrInfoCount[currentFolder]++
g_fldrInfoName[currentFolder]=nfo
gDate[nfo] = calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW)
}

if (store) {

storeMovie(gMovieFileCount,scan_line,currentFolder,calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW))
setNfo(gMovieFileCount,"\\.[^.]+$",".nfo")
gMovieFileCount++
}
}

}

close(tempFile)

identify_and_catalog_scanned_files()

DEBUG("Finished Scanning "root)
}



function glob2re(glob) {
gsub(/[.]/,"\\.",glob)
gsub(/[*]/,".*",glob)
gsub(/[?]/,".",glob)
gsub(/[<]/,"\\<",glob)
gsub(/ *, */,"|",glob)
gsub(/[>]/,"\\>",glob)
return "("glob")"
}

function csv2re(text) {
gsub(/ *, */,"|",text)
return "("text")"
}

function storeMovie(idx,file,folder,timeStamp) {

g_fldrMediaCount[folder]++

g_fldr[idx]=folder
g_media[idx] = file
DEBUG("Storing ["g_fldr[idx]"]["g_media[idx]"]")


gMovieFilePresent[clean_path(folder"/"file)] = idx
g_file_time[idx] = timeStamp
}





function checkMultiPart(name,count,\
i,firstName) {
firstName=g_media[count-1]


if (length(firstName) != length(name)) {

return 0
}
if (firstName == name) return 0

for(i=1 ; i - length(firstName) <= 0 ; i++ ) {
if (substr(firstName,i,1) != substr(name,i,1)) {
break
}
}
DEBUG2("difference at character "i)

if (substr(firstName,i+1) != substr(name,i+1)) {
DEBUG("no match last bit ["substr(firstName,i+1)"] != ["substr(name,i+1)"]")
return 0
}

if (substr(firstName,i-1,2) ~ "[^0-9]1" || substr(firstName,i-2,3) ~ "[^EeXx0-9][0-9]1" ) {




if (!(substr(name,i,1) ~ "[2-9]")) {
DEBUG2("no match on [2-9]"substr(name,i,1))
return 0
}

} else if (substr(firstName,i,1) ~ "[Aa]") {
if (!(substr(name,i,1) ~ "[A-Fa-f]")) {
DEBUG2("no match on [A-Fa-f]"substr(name,i,1))
return 0
}

} else {
DEBUG2("no match on [^0-9][Aa1]")
return 0
}

INF("Found multi part file - linked with "firstName)
gParts[count-1] = (gParts[count-1] =="" ? "" : gParts[count-1]"/" ) name
gMultiPartTagPos[count-1] = i
return 1
}


function setNfo(idx,pattern,replace,\
nfo,lcNfo) {

nfo=g_media[idx]
lcNfo = tolower(nfo)
if (match(lcNfo,pattern)) {
nfo=substr(nfo,1,RSTART-1) replace substr(nfo,RSTART+RLENGTH)
gNfoDefault[idx] = getPath(nfo,g_fldr[idx])
DEBUG2("Storing default nfo path ["gNfoDefault[idx]"]")
return 1
} else {
return 0
}
}

function exec(cmd, err) {


if ((err=system(cmd)) != 0) {
ERR("Return code "err" executing "cmd) 
}
return err
}




function folderIsRelevant(dir) {

DEBUG("Check parent folder relation to media ["dir"]")
if ( !(dir in g_fldrCount) || g_fldrCount[dir] == "") { 
DEBUG("unknown folder ["dir"]" )
return 0
}

if (g_fldrCount[dir] - 2 > 0 ) {
DEBUG("Too many sub folders - general folder")
return 0
}
if (g_fldrMediaCount[dir] - 2 > 0 ) {
DEBUG("Too much media  general folder")
return 0
}
return 1
}

function searchInternetForFirstImdbPage(name_no_tags,qualifier,\
keywords,i1,i2) {

keywords = textToSearchKeywords(name_no_tags,0)

i1=scanPageForMatch(g_search_bing keywords"+"qualifier,g_imdb_regex,0)
if (i1 != "" ) {
i2=scanPageForMatch(g_search_yahoo keywords"+"qualifier,g_imdb_regex,0)
}
return check_same("firstimdb",i1,i2)
}

function check_same(label,a,b) {
if ( a != b ) {
INF(label": No Consensus on search ["a"] != ["b"]")
} else if (a == "") {
INF(label": No results")
} else {
return a
}
return ""
}


function searchInternetForImdbLink(idx,\
url,txt,linksRequired) {

linksRequired = 0+g_settings["catalog_imdb_links_required"]

txt = basename(g_media[idx])
if (tolower(txt) != "dvd_volume" ) {
url=searchHeuristicsForImdbLink(txt,linksRequired)
}

if (url == "" && match(g_media[idx],gExtRegexIso)) {
txt = getIsoTitle(g_fldr[idx]"/"g_media[idx])
if (length(txt) - 3 > 0 ) {
url=searchHeuristicsForImdbLink(txt,linksRequired)
}
}

if (url == "" && folderIsRelevant(g_fldr[idx])) {
url=searchHeuristicsForImdbLink(tolower(basename(g_fldr[idx])),linksRequired)
}

DEBUG("searchInternetForImdbLink=["url"]")
return url
}

function remove_part_suffix(idx,\
txt) {




txt = tolower(basename(g_media[idx]))


if (idx in gMultiPartTagPos) {
txt = substr(txt,1,gMultiPartTagPos[idx])
sub(/(part|cd|)[1a]$/,"",txt)
DEBUG("MultiPart Suffix removed = ["txt"]")
}

return txt
}

function mergeSearchKeywords(text,keywordArray,\
heuristicId,keywords) {

for(heuristicId =  0 ; heuristicId -1  <= 0 ; heuristicId++ ) {
keywords =textToSearchKeywords(text,heuristicId)
keywordArray[keywords]=1
}
}


function searchHeuristicsForImdbLink(text,linksRequired,\
bestUrl,k,text_no_underscore) {

mergeSearchKeywords(text,k)

text_no_underscore = text
gsub(/_/," ",text_no_underscore)
gsub("[[][^]]+[]]","",text_no_underscore)
if (text_no_underscore != text) {
mergeSearchKeywords(text_no_underscore,k)
}

bestUrl = searchArrayForIMDB(k,linksRequired)

return bestUrl
}



function searchArrayForIMDB(k,linkThreshold,\
bestUrl,keywords,keywordsSansEpisode) {

g_search_total["direct"]++

DEBUG("direct search...")
bestUrl = searchArrayForIMDB2(k,linkThreshold)

if (bestUrl == "") {

for(keywords in k) {
if (sub(/ *s[0-9][0-9]e[0-9][0-9].*/,"",keywords)) {
keywordsSansEpisode[keywords]=1
}
}
bestUrl = searchArrayForIMDB2(keywordsSansEpisode,linkThreshold)
}
if (bestUrl != "") {
g_search_hits["direct"]++
}
DEBUG("direct search : result ["bestUrl"]")

return bestUrl
}

function searchArrayForIMDB2(k,linkThreshold,\
bestUrl,keywords) {

for(keywords in k) {
DEBUG("direct search ["keywords"]...")
INF("direct search ["keywords"]")
bestUrl = searchForIMDB(keywords,linkThreshold)
if (bestUrl != "") {
INF("direct search : Found ["bestUrl"]with direct search ["keywords"]")
return bestUrl
}
}
return ""
}


function dirname(f) {


sub(/\/$/,"",f)


if (f !~ "^[/$]" ) {
f = "./"f
}


sub(/\/[^\/]+$/,"",f)
return f
}


function basename(f) {
if (match(f,"/[^/]+$")) {

f=substr(f,RSTART+1)
} else if (match(f,"/[^/]+/$")) {

f=substr(f,RSTART+1,RLENGTH-2)
}

sub(gExtRegExAll,"",f)

return f
}



function textToSearchKeywords(f,heuristic\
) {




f=tolower(f)

if (heuristic == 0 || heuristic == 1) {


gsub(/[^A-Za-z0-9]+/,"+",f)





if (match(f,"\\<(19|20)[0-9][0-9]\\>")) {
f = substr(f,1,RSTART+RLENGTH)
}

if (match(f,"\\<s[0-9][0-9]e[0-9][0-9]")) {
f = substr(f,1,RSTART+RLENGTH)
}


f = remove_format_tags(f)


if (heuristic == 1) {
DEBUG("Base query = "f)
gsub(/[-+.]/,"+%2B",f)
f="%2B"f
}

gsub(/^\+/,"",f)
gsub(/\+$/,"",f)

} else if (heuristic == 2) {

f = "%22"f"%22"
}
DEBUG("Using search method "heuristic" = ["f"]")
return f
}

function remove_format_tags(text,\
t) {
if ((t = match(tolower(text),g_settings["catalog_format_tags"])) > 0) {
text = substr(text,1,RSTART-1)
}

return trimAll(text)
}

function scrapeIMDBTitlePage(idx,url,\
f,line,imdbContentPosition) {

if (url == "" ) return


url=extractImdbLink(url)

if (url == "" ) return

DEBUG("Setting external url to ["url"]")
if (g_imdb[idx] == "") {
g_imdb[idx] = url
}

f=getUrl(url,"imdb_main",1)

if (f != "" ) {

imdbContentPosition="header"

DEBUG("START IMDB: title:"gTitle[idx]" poster "g_poster[idx]" genre "g_genre[idx]" cert "gCertRating[idx]" year "g_year[idx])

FS="\n"
while(imdbContentPosition != "footer" && (getline line < f) > 0  ) {
imdbContentPosition=scrapeIMDBLine(line,imdbContentPosition,idx,f)
}
close(f)

}






DEBUG("IMDB Category = "g_category[idx] )
}





function parseDbRow(row,arr,\
fields,i,fnum) {
fnum = split(row,fields,"\t")
for(i = 2 ; i-fnum <= 0 ; i+=2 ) {
arr[fields[i]] = fields[i+1]
}
arr[FILE] = clean_path(arr[FILE])
}

function clean_path(f) {
while (index(f,"/./")) {
gsub(/\/\.\//,"/",f)
}
while (index(f,"//")) {
gsub(/\/\/+/,"/",f)
}
return f
}

function get_name_dir_fields(arr,\
f,fileRe) {

f =  arr[FILE]

if (isDvdDir(f)) {
fileRe="/[^/]+/$"
} else {
fileRe="/[^/]+$";  # /path/to/name.avi
}

if (match(f,fileRe)) {
arr[NAME] = substr(f,RSTART+1)
arr[DIR] = substr(f,1,RSTART-1)
}
}

function copyUntouchedToNewDatabase(db_file,new_db_file,indexToMergeHash,\
kept_count,updated_count,total_lines,f,dbline,dbline2,dbfields,idx) {

kept_count=0
updated_count=0

INF("read_database")


FS="\n"
close(db_file)
while((getline dbline < db_file) > 0 ) {

total_lines++

if ( index(dbline,"\t") != 1 ) { continue; }

parseDbRow(dbline,dbfields)
get_name_dir_fields(dbfields)

f = dbfields[FILE]


if (f in gMovieFilePresent) {

idx=gMovieFilePresent[f]
if (idx != -1 ) {
INF("update ["f"]")

dbline2 = createIndexRow(idx,dbfields[ID],dbfields[WATCHED],dbfields[INDEXTIME])
updated_count++
print dbline2"\t" >> new_db_file
update_plots(g_plot_file,idx)
delete indexToMergeHash[idx]

gMovieFilePresent[f] = -1
} else {
INF("Duplicate ["dbfields[FILE]"]")
}

} else if ( dbfields[DIR] ~ g_settings["catalog_ignore_paths"] ) {

INF("Removing Ignored Path ["dbfields[FILE]"]")

} else if ( dbfields[NAME] ~ g_settings["catalog_ignore_names"] ) {

INF("Removing Ignored Name "dbfields[FILE]"]")

} else {

kept_count++
print dbline >> new_db_file
}

if ( dbfields[FILE] == "" ) {
ERR("Blank file for ["dbline"]")
}
if (dbfields[ID] - gMaxDatabaseId > 0) {
gMaxDatabaseId = dbfields[ID]
}
}
close(db_file)

close(new_db_file)

delete gMovieFilePresent

INF("Existing database: size:"total_lines" untouched "kept_count" updated "updated_count)
return kept_count+updated_count
}

function next_folder(path,base,\
path_parts,base_parts,bpcount,pcount) {
if (index(path,base) == 1) {

bpcount = split(base,base_parts,"/")
if (base_parts[bpcount] == "" ) bpcount--

pcount = split(path,path_parts,"/")





if (path_parts[bpcount] == base_parts[bpcount] ) {
return base "/" path_parts[bpcount+1]
} else {
sub(/\/[^\/]+$/,"",base)
return base "/" path_parts[bpcount]
}
}
return ""
}


function mount_point(d) {
if (index(d,"/share/") == 1) return "/share"
if ( index(d,g_mount_root) == 1 || index(d,"/USB_DRIVE_") == 1 || index(d,"/opt/sybhttpd/localhost.drives/USB_DRIVE_") == 1 ) {
return next_folder(d,g_mount_root)
}
}






function remove_absent_files_from_new_db(db,\
tmp_db,dbfields,\
list,f,maxCommandLength,dbline,keep,\
gp,blacklist_re,blacklist_dir,timer) {
list=""
maxCommandLength=3999

INF("Pruning...")
tmp_db = db "." JOBID ".tmp"

if (lock(g_db_lock_file)) {
g_kept_file_count=0
g_absent_file_count=0

close(db)
while((getline dbline < db ) > 0) {

if ( index(dbline,"\t") != 1 ) { continue; }

parseDbRow(dbline,dbfields)

f = dbfields[FILE]


keep=1

if (blacklist_re != "" && f ~ "NETWORK_SHARE/("blacklist_re")" ) {
WARNING("Skipping "f" - blacklisted device")
} else {

timer = systime()
if (!is_file_or_folder(f) ) {
if (systime()-timer > 10) {

blacklist_dir = f
if (match(f,"NETWORK_SHARE/[^\/]+/")) {
blacklist_dir = substr(f,RSTART,RLENGTH)
sub(/.*NETWORK_SHARE/,"",blacklist_dir)
ERR("Unresponsive device : Blacklisting access to NETWORK_SHARE"blacklist_dir)
blacklist_re = blacklist_re "|" blacklist_dir
DEBUG("re = "blacklist_re)
}
} else {
gp = mount_point(f)
if (gp != "/share" ) {

if (is_dir(gp) && !is_empty(gp)) {
keep=0
} else {
INF("Not mounted?")
}
} else {

keep=0
}
}
}
}


if (keep) {
print dbline > tmp_db
g_kept_file_count++
} else {
INF("Removing "f)
g_absent_file_count++

}
}
close(tmp_db)
close(db)
INF("unchanged:"g_kept_file_count)
INF("removed:"g_absent_file_count)
replace_database_with_new(tmp_db,db,INDEX_DB_OLD)
}
}

function getPath(name,localPath) {
if (substr(name,1,1) == "/" ) {

return name
} else if (substr(name,1,4) == "ovs:" ) {

return APPDIR"/db/global/"substr(name,5)
} else {

return localPath"/"name
}
}




function quoteArg(f) {
gsub(g_quote,g_quote "\\"g_quote g_quote,f)
return g_quote f g_quote
}

function grandparent_folder_exists(line) {

sub(/\/[^\/]+\/[^\/]+$/,"/",line)

gsub(/\/+/,"/",line)

if (!(line in g_folder_exists) ) {
g_folder_exists[line] = is_dir(line)
}

return g_folder_exists[line]
}


function calcTimestamp(lsMonth,lsDate,lsTimeOrYear,_default,\
val,y,m,d,h,min) {

if (lsMonth == "" ) {
return _default
} else {
m=gMonthConvert[lsMonth]
d=lsDate
if (index(lsTimeOrYear,":")) {

y=THIS_YEAR
h=substr(lsTimeOrYear,1,2)
min=substr(lsTimeOrYear,4,2)
} else {

y=lsTimeOrYear
h=7
min=0
}
val = sprintf("%04d%02d%02d%02d%02d00",y,m,d,h,min); 
if (val - NOW > 0 ) {
y--
val = sprintf("%04d%02d%02d%02d%02d00",y,m,d,h,min); 
}
return val; 
}
}

function checkTvFilenameFormat(plugin,idx,\
details,line,dirs,d,dirCount,ePos,dirLevels) {

line = g_media[idx]




line = remove_format_tags(line)

split(g_fldr[idx],dirs,"/")
dirCount=hash_size(dirs)
dirLevels=2




g_search_abbreviations=1

for(d=0 ; d-dirLevels <= 0  ; d++ ) {

if (extractEpisode(plugin,line,idx,details)) {
break
}
if (d == dirLevels) {
INF("No tv series-episode format in ["line"]")
return 0
}
line=dirs[dirCount-d]"/"line
g_search_abbreviations = 0
}

adjustTitle(idx,details[TITLE],"filename")


g_season[idx]=details[SEASON]
g_episode[idx]=details[EPISODE]

INF("Found tv info in file name:"line" title:["gTitle[idx]"] ["g_season[idx]"] x ["g_episode[idx]"]")




ePos = index(g_episode[idx],"e")
if (ePos -1 >= 0 && ( ePos - length(g_episode[idx]) < 0 )) {
gsub(/e/,",",g_episode[idx])
DEBUG("Double Episode : "g_episode[idx])

}


g_category[idx] = "T"
gAdditionalInfo[idx] = details[ADDITIONAL_INF]



return 1
}

function extractEpisodeByPatterns(plugin,line,details,idx) {



line = tolower(line)
if (!extractEpisodeByPattern(line,0,"","s[0-9][0-9]?","[/ .]?e[0-9]+e[0-9]+",details,idx)) {  # s00e00e01
if (!extractEpisodeByPattern(line,0,"","s?[0-9][0-9]?","[/ .]?[de][0-9]+[a-e]?",details,idx)) {  #s00e00 (allow d00a for BigBrother)
if (!extractEpisodeByPattern(line,1,"[^a-z0-9]","[0-9][0-9]?","[/ .]?x[0-9][0-9]?",details,idx)) {
if (!extractEpisodeByPattern(line,0,"\\<","(series|season|saison|s)[^a-z0-9]*[0-9][0-9]?","[/ .]?(e|ep.?|episode)[^a-z0-9]*[0-9][0-9]?",details,idx)) {


if (!extractEpisodeByDates(plugin,idx,line,details)) {





if (!extractEpisodeByPattern(line,1,"[^-0-9]","([1-9]|2[1-9]|1[0-8]|[03-9][0-9])","/?[0-9][0-9]",details,idx)) {

return 0
}
}
}
}
}
}


return 1
}

function formatDate(line,\
date,nonDate) {
if (!extractDate(line,date,nonDate)) {
return line
}
line=sprintf("%04d-%02d-%02d",date[1],date[2],date[3])
return line
}






function extractDate(line,date,nonDate,\
y4,d1,d2,d1or2,m1,m2,m1or2,d,m,y,datePart,textMonth,s,mword) {

line = tolower(line)
textMonth = 0
delete date
delete nonDate


y4="(20[01][0-9]|19[5-9][0-9])"
m2="(0[1-9]|1[012])"
m1=d1="[1-9]"
d2="([012][0-9]|3[01])"
s="[-_. /]"
m1or2 = "(" m1 "|" m2 ")"
d1or2 = "(" d1 "|" d2 ")"

mword=tolower("("g_months_short"|"g_months_long")")

d = m = y = 0
if  (match(line,y4 s m1or2 s d1or2)) {

y=1 ; m = 2 ; d=3

} else if(match(line,m1or2 s d1or2 s y4)) {

m=1 ; d = 2 ; y=3

} else if(match(line,d1or2 s m1or2 s y4)) {

d=1 ; m = 2 ; y=3

} else if(match(line,d1or2 s mword s y4)) { 

d=1 ; m = 2 ; y=3
textMonth = 1

} else if(match(line,mword s d1or2 s y4)) {
m=1 ; d = 2 ; y=3
textMonth = 1

} else {

DEBUG2("No date format found for ["line"]")
return 0
}
datePart = substr(line,RSTART,RLENGTH)

nonDate[1]=substr(line,1,RSTART-1)
nonDate[2]=substr(line,RSTART+RLENGTH)

split(datePart,date,s)
d = date[d]
m = date[m]
y = date[y]

date[1]=y
date[2]=tolower(trim(m))
date[3]=d

if ( textMonth == 1 ) {
DEBUG("date[2]="date[2])
if (date[2] in gMonthConvert ) {
date[2] = gMonthConvert[date[2]]
DEBUG(m"="date[2])
} else {
return 0
}
}
date[1] += 0
date[2] += 0
date[3] += 0
DEBUG("Found "date[1]"/"date[2]"/"date[3]" in "line)
return 1
}

function extractEpisodeByDates(plugin,idx,line,details,\
date,nonDate,title,rest,y,m,d,tvdbid,result,closeTitles) {

result=0
DEBUG2("extractEpisodeByDates "plugin" "line)
if (extractDate(line,date,nonDate)) {
rest=nonDate[2]
title = clean_title(nonDate[1])

details[TITLE]=title
y = date[1]
m = date[2]
d = date[3]


possible_tv_titles(plugin,title,closeTitles)

DEBUG("Checking the following series for "title" "y"/"m"/"d)
dump(0,"date check",closeTitles)

for (tvdbid in closeTitles) {

if (get_tv_series_info(plugin,idx,get_tv_series_api_url(plugin,tvdbid)) > 0) {

if (plugin == "THETVDB" ) {


result = extractEpisodeByDates_TvDb(idx,tvdbid,y,m,d,details)

} else if (plugin == "TVRAGE" ) {

result = extractEpisodeByDates_rage(idx,tvdbid,y,m,d,details)

} else {
plugin_error(plugin)
}
if (result) {
INF(":) Found episode of "closeTitles[tvdbid]" on "y"-"m"-"d)
break
}
}
}
if (result == 0) {
INF(":( Couldnt find episode "y"/"m"/"d" - using file information")
details[SEASON]=y
details[EPISODE]=sprintf("%02d%02d",m,d)
sub(/\....$/,"",rest)
details[ADDITIONAL_INF]=clean_title(rest)
}
}
if (result) {
INF("end extractEpisodeByDates "plugin" = "result)
}
return result
}




function extractEpisodeByDates_TvDb(idx,tvdbid,y,m,d,details,\
episodeInfo,url) {


url="http://thetvdb.com/api/GetEpisodeByAirDate.php?apikey="g_tk"&seriesid="tvdbid"&airdate="y"-"m"-"d,"ep-by-date-"
fetchXML(url,"epbydate",episodeInfo)

if ( "/Data/Error" in episodeInfo ) {
ERR(episodeInfo["/Data/Error"])
tvdbid=""
}
if (tvdbid != "") {
dump(0,"ep by date",episodeInfo)

gAirDate[idx]=formatDate(episodeInfo["/Data/Episode/FirstAired"])
details[SEASON]=episodeInfo["/Data/Episode/SeasonNumber"]
details[EPISODE]=episodeInfo["/Data/Episode/EpisodeNumber"]
details[ADDITIONAL_INF]=episodeInfo["/Data/Episode/EpisodeName"]


equate_urls(url,"http://thetvdb.com/api/"g_tk"/series/"tvdbid"/default/"details[SEASON]"/"details[EPISODE]"/en.xml")



return 1
}
return 0
}
function extractEpisodeByDates_rage(idx,tvdbid,y,m,d,details,\
episodeInfo,match_date,result,filter) {

result=0
match_date=sprintf("%4d-%02d-%02d",y,m,d)


filter["/Show/Episodelist/Season/episode/airdate"] = match_date
if (fetch_xml_single_child(get_tv_series_api_url("TVRAGE",tvdbid),"bydate","/Show/Episodelist/Season/episode",filter,episodeInfo)) {
gAirDate[idx]=formatDate(match_date)
details[SEASON]=episodeInfo["/Show/Episodelist/Season/episode/seasonnum"]
details[EPISODE]=episodeInfo["/Show/Episodelist/Season/episode/epnum"]
details[ADDITIONAL_INF]=episodeInfo["/Show/Episodelist/Season/episode/title"]
result=1
}
return result
}

function extractEpisode(plugin,line,idx,details,\
d,dir) {


if (!extractEpisodeByPatterns(plugin,line,details,"")) {
return 0
}

DEBUG("Extracted title ["details[TITLE] "]")
if (details[TITLE] == "" ) {



split(g_fldr[idx],dir,"/")
d=hash_size(dir)
details[TITLE] = remove_season(clean_title(dir[d]))
if (details[TITLE] == "" ) {

details[TITLE] = clean_title(dir[d-1])
DEBUG("Using grandparent folder for title ["details[TITLE] "]")
} else {
DEBUG("Using parent folder for title ["details[TITLE] "]")
}
}

return 1
}

function remove_season(t) {
sub(/(S|Series *|Season *)[0-9]+.*/,"",t)
return clean_title(t)
}



function extractEpisodeByPattern(line,prefixReLen,prefixRe,seasonRe,episodeRe,details,idx,  \
tmpDetails,tmpTitle,ee) {
if (!match(line,prefixRe seasonRe episodeRe "\\>" )) {
return 0
}

DEBUG("ExtractEpisode: line["line"] re["prefixRe seasonRe episodeRe "\\>] match["substr(line,RSTART,RLENGTH)"]" )

RSTART += prefixReLen
RLENGTH -= prefixReLen

tmpDetails[TITLE] = substr(line,1,RSTART-1)
tmpDetails[ADDITIONAL_INF]=substr(line,RSTART+RLENGTH)

line=substr(line,RSTART,RLENGTH)

if (index(tmpDetails[TITLE],":") && match(tmpDetails[TITLE],": *")) {
tmpDetails[TITLE] = substr(tmpDetails[TITLE],RSTART+RLENGTH)
}

if (index(tmpDetails[TITLE],"-") && match(tmpDetails[TITLE],"^[a-z][a-z0-9]+[-]")) {
tmpTitle=substr(tmpDetails[TITLE],RSTART+RLENGTH)
if (tmpTitle != "" ) {
INF("Removed group was ["tmpDetails[TITLE]"] now ["tmpTitle"]")
tmpDetails[TITLE]=tmpTitle
}
}

tmpDetails[TITLE] = clean_title(tmpDetails[TITLE])

DEBUG("ExtractEpisode: Title= ["tmpDetails[TITLE]"]")

if (match(tmpDetails[ADDITIONAL_INF],gExtRegExAll) ) {
tmpDetails[EXT]=tmpDetails[ADDITIONAL_INF]
gsub(/\.[^.]*$/,"",tmpDetails[ADDITIONAL_INF])
tmpDetails[EXT]=substr(tmpDetails[EXT],length(tmpDetails[ADDITIONAL_INF])+2)
}


match(line,episodeRe "$" )
tmpDetails[EPISODE] = substr(line,RSTART,RLENGTH); 

if (tmpDetails[EPISODE] - 40 > 0 ) {

return 0
}

tmpDetails[SEASON] = substr(line,1,RSTART-1)


gsub(/^[^0-9]+/,"",tmpDetails[EPISODE])
sub(/^0+/,"",tmpDetails[EPISODE])

gsub(/^[^0-9]+/,"",tmpDetails[SEASON])
sub(/^0+/,"",tmpDetails[SEASON])


for(ee in tmpDetails) {
if (idx != "") {
details[ee,idx]=tmpDetails[ee]
} else {
details[ee]=tmpDetails[ee]
}
DEBUG("tv details "g_db_field_name[ee]"."idx" = "tmpDetails[ee])
}
return 1
}



function identify_and_catalog_scanned_files(\
idx,file,bestUrl,scanNfo,thisTime,numFiles,eta,\
ready_to_merge,ready_to_merge_count,scanned,tv_status,p,plugin) {

numFiles=hash_size(g_media)

INF("Processing "numFiles" items")

eta=""

for ( idx = 0 ; idx - numFiles < 0 ; idx++ ) {

begin_search("")

thisTime = -systime()

report_status("item "(g_item_count++))

bestUrl=""

scanNfo=0

file=g_media[idx]
if (file == "" ) continue

DIV0("Start item "(g_item_count)": ["file"]")

DEBUG("folder :["g_fldr[idx]"]")
if (!isDvdDir(file) && !match(file,gExtRegExAll)) {
WARNING("Skipping unknown file ["file"]")
continue
}


if (g_settings["catalog_nfo_read"] != "no") {

if (is_file(gNfoDefault[idx])) {

DEBUG("Using default info to find url")
scanNfo = 1

} else if (g_fldrMediaCount[g_fldr[idx]] == 1 && g_fldrInfoCount[g_fldr[idx]] == 1 && is_file(g_fldrInfoName[g_fldr[idx]])) {

DEBUG("Using single nfo "g_fldrInfoName[g_fldr[idx]]" to find url in folder ["g_fldr[idx]"] for item "idx)

gNfoDefault[idx] = g_fldrInfoName[g_fldr[idx]]
scanNfo = 1
}
}

if (scanNfo){
bestUrl = scanNfoForImdbLink(gNfoDefault[idx])
}





scanned = 0
tv_status = 0

for (p in g_tv_plugin) {
plugin = g_tv_plugin[p]



DIV("checkTvFilenameFormat "plugin)
if (checkTvFilenameFormat(plugin,idx)) {

if (UPDATE_TV)  {
tv_status = tv_search(plugin,idx,bestUrl)
scanned= (tv_status != 0)

if (g_episode[idx] !~ "^[0-9]+$" ) {

break
}
if (tv_status == 2 ) break
}
}
}
DEBUG("premovie tv_status "tv_status)
if (tv_status == 0 && UPDATE_MOVIES) {
movie_search(idx,bestUrl)
scanned=1
}

if (scanned) {

if (g_poster[idx] == "") {
g_poster[idx] = g_imdb_poster_url[idx]
}
fixTitles(idx)


if (index(APPDIR,"/oversight") ) {

if (g_poster[idx] != "" && GET_POSTERS) {
g_poster[idx] = download_image(POSTER,g_poster[idx],idx)
}

if (g_fanart[idx] != "" && GET_FANART) {
g_fanart[idx] = download_image(FANART,g_fanart[idx],idx)
}
}

relocate_files(idx)

thisTime += systime() 
g_process_time += thisTime
g_elapsed_time = systime() - g_start_time

g_total ++

if (g_opt_dry_run) {
print "dryrun: "g_file[idx]" -> "gTitle[idx]
}



DEBUG("processed in "thisTime"s")
DEBUG(sprintf("CORE: %d items in %ds = %.1fs per item",g_total,g_process_time,(g_process_time/g_total)))
DEBUG(sprintf("ELAPSED:          %ds = %.1fs per item",g_elapsed_time,(g_elapsed_time/g_total)))


ready_to_merge[idx]=1
ready_to_merge_count++

} else {
INF("Skipping item "g_media[idx])
}
}


if (ready_to_merge_count) {
DIV("merge")
merge_into_index(ready_to_merge)
}

clean_globals()
}

function DIV0(x) {
INF("\n\t===\n\t"x"\n\t===\n")
}
function DIV(x) {
INF("\t===\t"x"\t===")
}

function begin_search(method) {
if (method == "" ) {

g_search_types_tried = ""

} else {

if (index(g_search_types_tried,method)) {
return 0
}
g_search_types_tried = g_search_types_tried " " method
DIV("Search method = "method)
return 1
}
}


function tv_search(plugin,idx,bestUrl,\
tvDbSeriesPage,result) {

result=0

if (!begin_search(plugin)) {
return 0
}
DIV("tv_search "plugin)

if (bestUrl == "" && g_imdb[idx] != "" ) {
bestUrl = g_imdb[idx]
}





if (bestUrl != "") {




scrapeIMDBTitlePage(idx,bestUrl)
if (g_category[idx] != "M" ) {
tvDbSeriesPage = get_tv_series_api_url(plugin,find_tvid(plugin,idx,extractImdbId(bestUrl)))
result = get_tv_series_info(plugin,idx,tvDbSeriesPage)
}


} else {



tvDbSeriesPage = search_tv_series_names(plugin,idx,gTitle[idx])
if (tvDbSeriesPage != "") {
result = get_tv_series_info(plugin,idx,tvDbSeriesPage)
if (result) {
bestUrl = tv2imdb(idx)
scrapeIMDBTitlePage(idx,bestUrl)
if (g_category[idx] == "M" ) {
DEBUG("Error getting IMDB ID from tv - looks like a movie??")
result = 0
}
}
} else {



bestUrl=searchInternetForImdbLink(idx)
if (bestUrl != "") {
scrapeIMDBTitlePage(idx,bestUrl)
if (g_category[idx] != "M" ) {
tvDbSeriesPage = get_tv_series_api_url(plugin,find_tvid(plugin,idx,extractImdbId(bestUrl)))
result = get_tv_series_info(plugin,idx,tvDbSeriesPage)
}
}   
}
}
INF("tv_search "plugin" = "result)
return result
}

function movie_search(idx,bestUrl,\
name,name_no_tags,name_no_parts,i,\
search_regex_key,search_order_key,search_order,s) {

if (!begin_search("movie_search")) {
return
}




name=cleanSuffix(idx)
name_no_parts = remove_part_suffix(idx)
name_no_tags=remove_format_tags(name)


for(i = 1 ; i < 5 ; i++ ) {
search_regex_key="catalog_movie_search_regex"i


if (name ~ g_settings[search_regex_key]) {

search_order_key="catalog_movie_search_order"i
if (!(search_order_key in g_settings)) {
ERR("Missing setting "search_order_key)
} else {
split(g_settings[search_order_key],search_order," *, *")
break
}
}
delete search_order
}

for(s in search_order) {
if (bestUrl == "") {

DIV("Search Phase: "search_order[s])

if (search_order[s] == "ONLINE_NFO") {

bestUrl = searchOnlineNfoLinksForImdbAlternate(name)

if (bestUrl == "" && gParts[idx] != "" && name != name_no_parts ) {
bestUrl = searchOnlineNfoLinksForImdbAlternate(name_no_parts)
}

if (bestUrl == "" && name_no_tags != name) {



bestUrl = searchOnlineNfoLinksForImdbAlternate(name_no_tags".")
}

} else if (search_order[s] == "IMDB") {



bestUrl=searchInternetForFirstImdbPage(name_no_tags,url_encode("site:imdb.com"))

} else if (search_order[s] == "IMDBFIRST") {

bestUrl=searchInternetForFirstImdbPage(name_no_tags,url_encode("+imdb"))

} else if (search_order[s] == "IMDBLINKS") {

bestUrl=searchInternetForImdbLink(idx)

} else {
ERR("Unknown search method "search_order[s])
}
}
}


if (bestUrl != "") {

scrapeIMDBTitlePage(idx,bestUrl)

if (g_category[idx] == "T" ) {
WARNING("Unidentifed TV show ???")
} else {
getNiceMoviePosters(idx,extractImdbId(bestUrl))
}

}
}

function tv2imdb(idx,\
date,nonDate,premier,url,key) {

DEBUG("tv2imdb start=["g_imdb[idx]"]")
if (g_imdb[idx] == "") {

key=gTitle[idx]"+"g_year[idx]
DEBUG("tv2imdb key=["key"]")
if (!(key in g_tv2imdb)) {

url=gTitle[idx] " +site:imdb.com \"TV Series\" \"User Rating\" "g_year[idx]


g_tv2imdb[key] = scanPageForMatch(g_search_bing url,g_imdb_regex,0)
}
g_imdb[idx] = g_tv2imdb[key]
}
DEBUG("tv2imdb end=["g_imdb[idx]"]")
return extractImdbLink(g_imdb[idx])
}








function clean_globals() {
delete g_media
delete g_scraped
delete g_imdb_title
delete g_motech_title
delete gNfoDefault
delete g_fldrMediaCount
delete g_fldrInfoCount
delete g_fldrInfoName
delete g_fldrCount
delete g_fldr
delete gParts
delete gMultiPartTagPos
delete gCertRating
delete gCertCountry
delete g_director
delete g_poster
delete g_genre
delete gProdCode
delete gTitle
delete gOriginalTitle
delete gAdditionalInfo
delete g_imdb_poster_url
delete g_file
delete g_file_time
delete g_episode
delete g_seasion
delete g_imdb
delete g_year
delete g_premier
delete gAirDate
delete gTvCom
delete gEpTitle
delete g_epplot
delete g_plot
delete g_fanart
delete gCertRating
delete g_rating
delete g_category
delete gDate
delete g_title_source

gMovieFileCount = 0
INF("Reset scanned files store")
}

function cleanSuffix(idx,\
name) {
name=g_media[idx]

sub(/\.[^.]+$/,"",name)








name=trimAll(name)
return name
}





function searchOnlineNfoLinksForImdbAlternate(name,\
url) {
url=searchOnlineNfoLinksForImdbAlternateFilter(name,"",150)
if (url == "") {
url=searchOnlineNfoLinksForImdbAlternateFilter(name,"+nfo","")
}
return url
}

function searchOnlineNfoLinksForImdbAlternateFilter(name,additionalKeywords,minSize,\
choice,i,url) {
g_nfo_search_choices = 2

for(i = 0 ; i - g_nfo_search_choices < 0 ; i++ ) {

g_search_total["online_nfo"]++
g_nfo_search_engine_sequence++
choice = g_nfo_search_engine_sequence % g_nfo_search_choices 



if (choice == 0 ) {


url = searchOnlineNfoLinksForImdb(name,\
"http://www.bintube.com",\
"/?b="minSize"&q=\"QUERY\"" additionalKeywords,\
"/nfo/pid/[^\"]+",20,"nfo/","nfo/display/text/")

} else if (choice == 1 ) {


url = searchOnlineNfoLinksForImdb(name,\
"https://www.binsearch.info",\
"/index.php?q=\"QUERY\""additionalKeywords"&minsize="minSize"&max=20&adv_age=999&adv_sort=date&adv_nfo=on&postdate=on&hideposter=on&hidegroup=on",\
"/viewNFO[^\"]+",20,"","")



#





}
if (url != "") {
g_search_hits["online_nfo"]++
break
}
}
return url
}






function searchOnlineNfoLinksForImdb(name,domain,queryPath,nfoPathRegex,maxNfosToScan,inurlFind,inurlReplace,
nfo,nfo2,nfoPaths,imdbIds,totalImdbIds,bestId,wgetWorksWithMultipleUrlRedirects,id,count,result) {

INF("Online nfo search for "name)

if (length(name) <= 4) {
INF("name too short ")
return ""
}

sub(/QUERY/,name,queryPath)


scanPageForMatches(domain queryPath,nfoPathRegex,maxNfosToScan,1,"",nfoPaths)




wgetWorksWithMultipleUrlRedirects=0
















for(nfo in nfoPaths) {
nfo2 = domain nfo
if (inurlFind != "") {
sub(inurlFind,inurlReplace,nfo2)
}
sub(/[&]amp;/,"\\&",nfo2)

if (scanPageForMatches(nfo2, g_imdb_regex ,0,1,"", imdbIds) == 0) {
scanPageForIMDBviaLinksInNfo(nfo2,imdbIds)
}

for(id in imdbIds) {
totalImdbIds[id] += imdbIds[id]
}
}


if (hash_size(totalImdbIds) > 3 ) {
INF("Too many nfo results from online search")
} else {


count = bestScores(totalImdbIds,totalImdbIds,0)+0
if (count == 1) {

bestId = firstIndex(totalImdbIds)
INF("best imdb link ["domain"] = "bestId)
result = extractImdbLink(bestId)

} else if (count == 0) {

INF("No matches")

} else {

INF("To many matches with the same number of occurrences. Discarding results")
}
}
DEBUG("searchOnlineNfoLinksForImdb ["queryPath"] = ["result"]")
return result
}



function scanPageForIMDBviaLinksInNfo(url,imdbIds,\
amzurl,amazon_urls,imdb_per_page,imdb_id) {
if (scanPageForMatches(url,"http://(www.|)amazon[ !#-;=?-~]+",0,1,"",amazon_urls)) {
for(amzurl in amazon_urls) {
if (scanPageForMatches(amzurl, g_imdb_regex ,0,1,"", imdb_per_page)) {
for(imdb_id in imdb_per_page) {
INF("Found "imdb_id" via amazon link")
imdbIds[imdb_id] += imdb_per_page[imdb_id]
}
}
}
}
}


function firstIndex(inHash,i) {
for (i in inHash) return i
}

function firstDatum(inHash,i) {
for (i in inHash) return inHash[i]
}



function bestScores(inHash,outHash,textMode,\
i,bestScore,count,tmp,isHigher) {

dump(1,"pre best",inHash)
count = 0
for(i in inHash) {
if (textMode) {
isHigher= ""inHash[i] > ""bestScore
} else {
isHigher= 0+inHash[i] > 0+bestScore
}
if (bestScore=="" || isHigher) {
delete tmp
tmp[i]=bestScore=inHash[i]
} else if (inHash[i] == bestScore) {
tmp[i]=inHash[i]
}
}

delete outHash
for(i in tmp) {
outHash[i] = tmp[i]
count++
}
dump(0,"post best",outHash)
INF("count = "count)
return count
}


function scanNfoForImdbLink(nfoFile,\
foundId,line) {

foundId=""
INF("scanNfoForImdbLink ["nfoFile"]")
g_search_total["nfo"]++

if (system("test -f "quoteArg(nfoFile)) == 0) {
FS="\n"
while(foundId=="" && (getline line < nfoFile) > 0 ) {

foundId = extractImdbLink(line,1)

}
close(nfoFile)
}
if (foundId) g_search_hits["nfo"]++
INF("scanNfoForImdbLink = ["foundId"]")
return foundId
}



function search_tv_series_names(plugin,idx,title,\
tvDbSeriesPage,alternateTitles,title_key,cache_key) {

title_key = plugin"/"g_fldr[idx]"/"title
if (title_key in g_tvDbIndex) {
DEBUG(plugin" use previous mapping "title_key" -> ["g_tvDbIndex[title_key]"]")
return g_tvDbIndex[title_key]; 
}
DEBUG("Checking ["title_key"]")

g_search_total[plugin]++

tvDbSeriesPage = searchTvDbTitles(plugin,idx,title)
DEBUG("search_tv_series_names: bytitles="tvDbSeriesPage)
if (tvDbSeriesPage) {
g_search_hits[plugin]++

} else if ( g_search_abbreviations ) {


g_search_total[plugin".tvabbrev"]++

cache_key=g_fldr[idx]"@"title

if(cache_key in g_abbrev_cache) {

tvDbSeriesPage = g_abbrev_cache[cache_key]
INF("Fetched abbreviation "cache_key" = "tvDbSeriesPage)

} else {

searchAbbreviationAgainstTitles(title,alternateTitles)

if (filterTitlesByTvDbPresence(plugin,alternateTitles,"FirstAired,Overview",alternateTitles) - 1 > 0 ) {

filterTitlesFoundOnUsenetWithSpecificText(alternateTitles,cleanSuffix(idx),alternateTitles)

}

title = selectBestOfBestTitle(plugin,idx,alternateTitles)

tvDbSeriesPage = searchTvDbTitles(plugin,idx,title)

if (tvDbSeriesPage) {
g_search_hits[plugin".tvabbrev"]++
g_abbrev_cache[cache_key] = tvDbSeriesPage
INF("Caching abbreviation "cache_key" = "tvDbSeriesPage)
}
}
}

if (tvDbSeriesPage == "" ) {
WARNING("search_tv_series_names could not find series page")
} else {
DEBUG("search_tv_series_names Search looking at "tvDbSeriesPage)
g_tvDbIndex[title_key] = tvDbSeriesPage
}
return tvDbSeriesPage
}




function searchAbbreviationAgainstTitles(abbrev,alternateTitles,\
initial) {

delete alternateTitles

INF("Search Phase: epguid abbreviations")

initial = epguideInitial(abbrev)
searchAbbreviation(initial,abbrev,alternateTitles)



if (initial == "t" ) {
initial = epguideInitial(substr(abbrev,2))
if (initial != "t" ) {
searchAbbreviation(initial,abbrev,alternateTitles)
}
}
dump(0,"abbrev["abbrev"]",alternateTitles)
}

function hash_copy(a1,a2) {
delete a1 ; hash_merge(a1,a2) 
}
function hash_merge(a1,a2,\
i) {
for(i in a2) a1[i] = a2[i]
}




function hash_size(h,\
s,i){
s = 0 ; 
for(i in h) s++
return s
}

function possible_tv_titles(plugin,title,closeTitles) {

if (plugin == "THETVDB" ) {
searchTv(plugin,title,"FirstAired,Overview",closeTitles)
} else if (plugin == "TVRAGE" ) {
searchTv(plugin,title,"started,origin_country",closeTitles)
} else {
plugin_error(plugin)
} 
dump(0,"searchTv out",closeTitles)

}





#



function filterTitlesFoundOnUsenetWithSpecificText(titles,filterText,filteredTitles,\
result) {
result = filterTitlesFoundOnUsenetEngineWithSpecificText(titles,"http://binsearch.info/?max=25&adv_age=&q=\""filterText"\" QUERY",filteredTitles)
if (result == 0 ) {
result = filterTitlesFoundOnUsenetEngineWithSpecificText(titles,"http://bintube.com/?q=\""filterText"\" QUERY",filteredTitles)
}
return result
}





function filterTitlesFoundOnUsenetEngineWithSpecificText(titles,usenet_query_url,filteredTitles,\
t,count,tmpTitles,origTitles,dummy,found,query,baseline,link_count) {

found = 0
dump(2,"pre-usenet",titles)


hash_copy(origTitles,titles)


dummy=rand()systime()rand()
query = usenet_query_url
sub(/QUERY/,dummy,query)
baseline = scanPageForMatches(query,"</[Aa]>",0,1,"",tmpTitles)

DEBUG("number of links for no match "baseline)

for(t in titles) {

query = usenet_query_url
sub(/QUERY/,t,query)
link_count = scanPageForMatches(query,"</[Aa]>",0,1,"",tmpTitles)
DEBUG("number of links "link_count)
if (link_count-baseline > 0) {
count[t] = link_count
found=1
}
}

if (found) {

bestScores(count,count,0)


delete filteredTitles
for(t in count) {
filteredTitles[t] = origTitles[t]
}
INF("best titles on usenet using "usenet_query_url)
dump(0,"post-usenet",filteredTitles)
} else {
INF("No results found using "usenet_query_url)
}
return found
}













function getRelativeAge(plugin,idx,titleHash,ageHash,\
id,xml) {
for(id in titleHash) {
get_episode_xml(plugin,get_tv_series_api_url(plugin,id),g_season[idx],g_episode[idx],xml)
if (plugin == "THETVDB") {
ageHash[id] = xml["/Data/Episode/FirstAired"]
} else if (plugin == "TVRAGE" ) {
ageHash[id] = xml["/Show/Episodelist/Season/episode/airdate"]
} else {
plugin_error(plugin)
}
}
dump(1,"Age indicators",ageHash)
}












function selectBestOfBestTitle(plugin,idx,titles,\
bestId,bestFirstAired,ages,count) {
INF("TODO:Refine selection rules here. May user should choose")
dump(0,"closely matched titles",titles)
count=hash_size(titles)

if (count == 0) {
bestId = ""
} else if (count == 1) {
bestId = firstIndex(titles)
} else {

INF("Getting the most recent first aired for s"g_season[idx]"e"g_episode[idx])
bestFirstAired=""

getRelativeAge(plugin,idx,titles,ages)

bestScores(ages,ages,1)

bestId = firstIndex(ages)

}
INF("Selected:"bestId" = "titles[bestId])
return bestId
}









function filterTitlesByTvDbPresence(plugin,titleInHash,requiredTags,titleOutHash,\
bestScore,potentialTitle,potentialMatches,origTitles,titleScore,count) {
bestScore=-1
count=0

dump(0,"pre tvdb check",titleInHash)


hash_copy(origTitles,titleInHash)

for(potentialTitle in titleInHash) {
titleScore[potentialTitle] = searchTv(plugin,potentialTitle,requiredTags,potentialMatches)
}
bestScores(titleScore,titleScore,0)


delete titleOutHash
for(potentialTitle in titleScore) {
titleOutHash[potentialTitle] = origTitles[potentialTitle]
count++
}
dump(0,"post tvdb check",titleOutHash)
return count
}







function searchTv(plugin,title,requiredTagList,closeTitles,\
score) {
if (title != "") {
DEBUG("searchTv Checking ["title"]" )
score=searchTv2(plugin,title,requiredTagList,closeTitles)
DEBUG("searchTv Checked ["title"] score = " score )
if (score+0 <= 0 ) {
DEBUG("searchTv removing countries from ["title"]" )
if (match(tolower(title)," (au|uk|us)( |$)")) {
DEBUG("Removing "substr(title,RSTART+1,RLENGTH-1))
title=substr(title,1,RSTART-1) substr(title,RSTART+RLENGTH)
DEBUG("Trying generic title "title)
score=searchTv2(plugin,title,requiredTagList,closeTitles)
}
}
}
return score
}


function searchTv2(plugin,title,requiredTagList,closeTitles,\
requiredTagNames,allTitles,url) {

DEBUG("searchTv2 Checking ["title"]" )
split(requiredTagList,requiredTagNames,",")
delete closeTitles

if (plugin == "THETVDB") {

url=expand_url("http://thetvdb.com//api/GetSeries.php?seriesname=",title)
filter_search_results(url,title,"/Data/Series","SeriesName","seriesid",requiredTagList,allTitles)

} else if (plugin == "TVRAGE") {

url="http://www.tvrage.com/feeds/search.php?show="title
filter_search_results(url,title,"/Results/show","name","showid",requiredTagList,allTitles)

} else {
plugin_error(plugin)
}
return filterSimilarTitles(title,allTitles,closeTitles)
}



function expand_url(baseurl,title,\
url) {
url = baseurl title
if (match(title," [Aa]nd ")) {

url=url"\t"url
sub(/ [Aa]nd /," \\& ",url); 
}
if (match(title," O ")) {

url=url"\t"url
sub(/ O /," O",url); 
}
return url
}






function filter_search_results(url,title,seriesPath,nameTag,idTag,requiredTagNames,allTitles,\
f,line,info,currentId,currentName,add,i,seriesTag,seriesStart,seriesEnd,count,filter_count) {

f = getUrl(url,"tvdb_search",1)
count = 0
filter_count = 0

if (f != "") {
seriesTag = seriesPath
sub(/.*\//,"",seriesTag)
seriesStart="<"seriesTag">"
seriesEnd="</"seriesTag">"
FS="\n"
while((getline line < f) > 0 ) {



if (index(line,seriesStart) > 0) {
clean_xml_path(seriesPath,info)
}

parseXML(line,info)

if (index(line,seriesEnd) > 0) {



currentName = info[seriesPath"/"nameTag]

currentId = info[seriesPath"/"idTag]
count ++

add=1
for( i in requiredTagNames ) {
if (! ( "/"seriesTag"/"requiredTagNames[i] in info ) ) {
DEBUG("["currentName"] rejected due to missing "requiredTagNames[i]" tag")
add=0
filter_count++
break
}
}

if (add) {
allTitles[currentId] = currentName
}
clean_xml_path(seriesPath,info)

}
}
close(f)
}
dump(0,"search["title"]",allTitles)

INF("Search results : Found "count" removed "filter_count)
}

function dump(lvl,label,array,\
i,c) {
if (DBG-lvl >= 0)   {
for(i in array) {
DEBUG(label":"i"=["array[i]"]")
c++
}
if (c == 0 ) {
DEBUG(label":<empty>")
}
}
}
















function find_tvid(plugin,idx,imdbid,\
url,id2,premier_mdy,date,nondate,regex,key,filter,showInfo,year_range) {

if (imdbid) {

key = plugin"/"imdbid
if (key in g_imdb2tv) {

id2 = g_imdb2tv[key]

} else {


if(plugin == "THETVDB") {
regex="[&?;]id=[0-9]+"

url = "http://thetvdb.com/index.php?imdb_id="imdbid"&order=translation&searching=Search&tab=advancedsearch"
id2 = scanPageForMatch(url,regex,0)
if (id2 != "" ) {
id2=substr(id2,5)
}
}

if (id2 == "" ) {


extractDate(g_premier[idx],date,nondate)


#


year_range="("(g_year[idx]-1)"|"g_year[idx]"|"(g_year[idx]+1)")"

if(plugin == "THETVDB") {



filter["/Data/Series/SeriesName"] = "~:^"gTitle[idx]"(| \\([A-Za-z0-9]\\))$"
filter["/Data/Series/FirstAired"] = "~:^"year_range"-"

url=expand_url("http://thetvdb.com//api/GetSeries.php?seriesname=",gTitle[idx])
if (fetch_xml_single_child(url,"imdb2tvdb","/Data/Series",filter,showInfo)) {
INF("Looking at tvdb "showInfo["/Data/Series/SeriesName"])
id2 = showInfo["/Data/Series/seriesid"]
}


#

#





} else if(plugin == "TVRAGE") {



filter["/Results/show/name"] = "~:^"gTitle[idx]"(| \\([A-Za-z0-9]\\))$"
filter["/Results/show/started"] = "~:"year_range

if (fetch_xml_single_child("http://www.tvrage.com/feeds/search.php?show="gTitle[idx],"imdb2rage","/Results/show",filter,showInfo)) {
INF("Looking at tv rage "showInfo["/Results/show/name"])
id2 = showInfo["/Results/show/showid"]
}

} else {
plugin_error(plugin)
}
}
if (id2) g_imdb2tv[key] = id2
}

DEBUG("imdb id "imdbid" =>  "plugin"["id2"]")
}
return id2
}

function searchTvDbTitles(plugin,idx,title,\
tvdbid,tvDbSeriesUrl,imdb_id,closeTitles) {

if (g_imdb[idx]) {
imdb_id = extractImdbId(g_imdb[idx])
tvdbid = find_tvid(plugin,idx,imdb_id)
}
if (tvdbid == "") {
possible_tv_titles(plugin,title,closeTitles)
tvdbid = selectBestOfBestTitle(plugin,idx,closeTitles)
}
if (tvdbid != "") {
tvDbSeriesUrl=get_tv_series_api_url(plugin,tvdbid)
}

DEBUG("Endpage with url = ["tvDbSeriesUrl"]")
return tvDbSeriesUrl
}

function get_tv_series_api_url(plugin,tvdbid) {
if (tvdbid != "") {
if (plugin == "THETVDB") {
if (g_tvdb_user_per_episode_api) {
return "http://thetvdb.com/api/"g_tk"/series/"tvdbid"/en.xml"
} else {
return "http://thetvdb.com/api/"g_tk"/series/"tvdbid"/all/en.xml"
}
} else if (plugin == "TVRAGE") {
return "http://services.tvrage.com/feeds/full_show_info.php?sid="tvdbid
}
}
return ""
}



function fetchXML(url,label,xml,\
f,line,result) {
result = 0
f=getUrl(url,label,1)
if (f != "" ) {
FS="\n"
while((getline line < f) > 0 ) {
parseXML(line,xml)
}
close(f)
result = 1
}
return result
}



function parseXML(line,info,sep,\
currentTag,i,j,tag,text,lines,parts,sp,slash,tag_data_count,prevTag,\
attr,a_name,a_val,eq,attr_pairs) {

if (index(line,"<?")) return

if (sep == "") sep = "<"











tag_data_count = split(line,lines,"<")

currentTag = info["@CURRENT"]


if (tag_data_count  && currentTag ) {

info[currentTag] = info[currentTag] lines[1]

}



for(i = 2 ; i <= tag_data_count ; i++ ) {






split(lines[i],parts,">")






tag = parts[1]
text = parts[2]

if (i == tag_data_count) {

j = index(text,"\r")
if (j) text = substr(text,1,j-1)

j = index(text,"\n")
if (j) text = substr(text,1,j-1)
}

if ((sp=index(tag," ")) != 0) {

tag=substr(tag,1,sp-1)
}

slash = index(tag,"/")
if (slash == 1 )  {






if (prevTag) {
currentTag=prevTag
prevTag=""
} else {
currentTag = substr(currentTag,1,length(currentTag)-length(tag))
}



} else if (slash == 0 ) {

prevTag=currentTag

currentTag = currentTag "/" tag



if (currentTag in info) {
text = sep text
}
} else {


}

if (text) {

info[currentTag] = info[currentTag] text
}



if (index(parts[1],"=")) {

capture_regex(parts[1],"[:A-Za-z_][-_A-Za-z0-9.]+=(\"[^\"]+\"|[^ ]+)",0,attr_pairs)
for(attr in attr_pairs) {

eq=index(attr,"=")
a_name=substr(attr,1,eq-1)
a_val=substr(attr,eq+1)
if (index(a_val,"\"")) {
sub(/^"/,"",a_val)
sub(/"$/,"",a_val)
}
info[currentTag"#"a_name]=a_val

}

}


}

info["@CURRENT"] = currentTag
}





function similarTitles(titleIn,possible_title,\
bPos,cPos,yearOrCountry,matchLevel,diff,shortName) {

matchLevel = 0
yearOrCountry=""

DEBUG("Checking ["titleIn"] against ["possible_title"]")






if (sub(/ [Oo] /," O",possible_title)) {
possible_title=clean_title(possible_title)
}
if (sub(/ [Oo] /," O",titleIn)) {
titleIn=clean_title(titleIn)
}

if ((bPos=index(possible_title," (")) > 0) {
yearOrCountry=clean_title(substr(possible_title,bPos+2))
DEBUG("Qualifier "yearOrCountry)
}

if ((cPos=index(possible_title,",")) > 0) {
shortName=clean_title(substr(possible_title,1,cPos-1))
}

possible_title=clean_title(possible_title)

sub(/^[Tt]he /,"",possible_title)
sub(/^[Tt]he /,"",titleIn)

sub(/ [Tt]he$/,"",possible_title)
sub(/ [Tt]he$/,"",titleIn)




if (yearOrCountry != "") {
DEBUG("Qualified title "possible_title)
}
if (index(possible_title,titleIn) == 1) {






if (possible_title == titleIn) {

matchLevel=5




if (yearOrCountry != "") {
matchLevel=10
}

} else  if (titleIn == shortName) {

matchLevel=5



} else if ( possible_title == titleIn " " yearOrCountry ) {
INF("match for ["titleIn"+"yearOrCountry"] against ["possible_title"]")



matchLevel = 5

} else if ( index(possible_title,titleIn" Show")) {


matchLevel = 4

} else {
DEBUG("No match for ["titleIn"+"yearOrCountry"] against ["possible_title"]")
}
} else if (index(titleIn,possible_title) == 1) {







diff=substr(titleIn,length(possible_title)+1)
if ( diff ~ " (19|20)[0-9][0-9]$" || diff ~ " (uk|us|au|nz|de|fr)" ) {

matchLevel = 5
INF("match for ["titleIn"] containing ["possible_title"]")
}
} else if ( index(possible_title,"Late Night With "titleIn)) {


matchLevel = 4

} else if ( index(possible_title,"Show With "titleIn)) {



matchLevel = 4

}
DEBUG("["titleIn"] vs ["possible_title"] = "matchLevel)
return matchLevel
}







function filterSimilarTitles(title,titleHashIn,titleHashOut,\
i,score,bestScore,tmpTitles) {


hash_copy(tmpTitles,titleHashIn)


for(i in titleHashIn) {
score[i] = similarTitles(title,titleHashIn[i])
}


bestScores(score,titleHashOut,0)


for(i in titleHashOut) {
titleHashOut[i] = tmpTitles[i]
}
bestScore = score[firstIndex(titleHashOut)]
if (bestScore == "" ) bestScore = -1

INF("Filtered titles with score = "bestScore)
dump(0,"filtered["title"]=",titleHashOut)

if (bestScore == 0 ) {
DEBUG("all zero score - discard them all to trigger another match method")
delete titleHashOut
}

return bestScore
}


function getEpguideNames(letter,names,\
url,title,link,links,i,count2) {
url = "http://epguides.com/menu"letter

scanPageForMatches(url,"<li>(|<b>)<a.*</li>",0,1,"",links)
count2 = 0

for(i in links) {

if (index(i,"[radio]") == 0) {

title = extractTagText(i,"a")



if (title != "") {
link = extractAttribute(i,"a","href")
sub(/\.\./,"http://epguides.com",link)
gsub(/\&amp;/,"And",title)
names[link] = title
count2++


}
}
}
DEBUG("Loaded "count2" names")
return count2
}






function searchAbbreviation(letter,titleIn,alternateTitles,\
possible_title,names,i,ltitle) {

ltitle = tolower(titleIn)

DEBUG("Checking "titleIn" for abbeviations on menu page - "letter)

if (ltitle == "" ) return 

getEpguideNames(letter,names)

for(i in names) {

possible_title = names[i]

sub(/\(.*/,"",possible_title)

possible_title = clean_title(possible_title)

if (abbrevMatch(ltitle,possible_title)) {
alternateTitles[possible_title]="abbreviation-initials"
} else if (abbrevMatch(ltitle ltitle,possible_title)) {
alternateTitles[possible_title]="abbreviation-double"
} else if (abbrevContraction(ltitle,possible_title)) {
alternateTitles[possible_title]="abbreviation-contraction"
}
}
}






#

function abbrevMatch(abbrev , possible_title,\
wrd,a,words,rest_of_abbrev,found,abbrev_len,short_words) {
split(tolower(possible_title),words," ")
a=1
wrd=1
abbrev_len = length(abbrev)

short_words["and"] = short_words["in"] = short_words["it"] = short_words["of"] = 1

while(abbrev_len-a  >= 0 && (wrd in words)) {
rest_of_abbrev = substr(abbrev,a)

if (index(   rest_of_abbrev  ,   words[wrd]  ) == 1) {

a += length(words[wrd])
wrd++
} else if (substr(words[wrd],1,1) == substr(rest_of_abbrev,1,1)) {
a ++
wrd++
} else if (substr(rest_of_abbrev,1,1) == " ") {
a ++
} else if (words[wrd] in short_words ) {
wrd++
} else {

break
}
}
found = ((a -abbrev_len ) > 0 ) && !(wrd in words)
if (found) {
INF(possible_title " abbreviated by ["abbrev"]")
}
return found
}









function contractionPrerequisite(abbrev,possible_title,\
spaces) {
spaces = possible_title 
gsub(/[^ ]+/,"",spaces)
if (length(abbrev) - (length(spaces)+1) <= 0 ) {
return 0
}
return 1
}

function get_initials(title,\
initials) {
initials = tolower(title)
while(match(initials,"[^ ][^ ]+ ")) {
initials = substr(initials,1,RSTART) " " substr(initials,RLENGTH+RSTART)
}
while(match(initials,"[^ ][^ ]+$")) {
initials = substr(initials,1,RSTART)
}
gsub(/ /,"",initials)
return initials
}


function abbrevContraction(abbrev,possible_title,\
found,regex,initials,initial_regex) {




regex=tolower(abbrev)
gsub(//,".*",regex)
regex= "^" substr(regex,3,length(regex)-4) "$"

found = match(tolower(possible_title),regex)

if (found) {


if (!contractionPrerequisite(abbrev,possible_title)) {
INF(possible_title " rejected for abbrev ["abbrev"]")
found = 0
} else {
INF(possible_title " abbreviated by ["abbrev"]")
}
}
if (found) {

initials = initial_regex = get_initials(possible_title)
gsub(//,".*",initial_regex)
if (abbrev !~ initial_regex ) {
INF("Contraction ["abbrev"] does not contain show ["possible_title"] initials ["initials"] so reject")
found = 0
}
}


return found
}

function epguideInitial(title,\
letter) {

sub(/^[Tt]he /,"",title)
letter=tolower(substr(title,1,1))


if (match(title,"^10") ) {
letter = "t"
} else if (match(title,"^11") ) {
letter = "e"
} else if (match(title,"^1[2-9]") ) {
letter = substr(title,2,1)
}

if ( letter == "1" ) {
letter = "o"
}else if (match(letter,"^[23]")  ) {
letter = "t"
}else if (match(letter,"^[45]") ) {
letter = "f"
}else if (match(letter,"^[67]") ) {
letter = "s"
}else if ( letter == "8" ) {
letter = "e"
}else if ( letter == "9" ) {
letter = "n"
}
return letter
}



function clean_title(t) {
if (index(t,"&") && index(t,";")) {
gsub(/[&]amp;/,"and",t)
t = html_decode(t)
gsub(/[&][a-z0-9]+;/,"",t)
}
gsub(/[&]/," and ",t)
gsub(/['"'"']/,"",t)





while (match(t,"\\<[A-Za-z]\\>\.\\<[A-Za-z]\\>")) {
t = substr(t,1,RSTART) "@@" substr(t,RSTART+2)
}
gsub(/@@/,"",t)

gsub(/[^A-Za-z0-9]+/," ",t)
gsub(/ +/," ",t)
t=trim(capitalise(tolower(t)))
return t
}

function remove_tags(line) {
gsub(/<[^>]+>/," ",line)
gsub(/ +/," ",line)
gsub(/\&amp;/," and ",line)
gsub(/[&][a-z]+;?/,"",line)
line=de_emphasise(line)
return line
}

function de_emphasise(html) {
gsub(/<(\/|)(b|em|strong)>/,"",html)
if (index(html,"wbr")) {

gsub(/ *<(\/|)wbr>/,"",html)
}
gsub(/<[^\/][^<]+[\/]>/,"",html)
return html
}




function getMax(arr,requiredThreshold,requireDifferenceSquared,dontRejectCloseSubstrings,\
maxName,best,nextBest,nextBestName,diff,i,threshold,msg) {
nextBest=0
maxName=""
best=0
for(i in arr) {
msg="Score: "arr[i]" for ["i"]"
if (arr[i]-best >= 0 ) {
if (maxName == "") {
INF(msg": first value ")
} else {
INF(msg":"(arr[i]>best?"beats":"matches")" current best of " best " held by ["maxName"]")
}
nextBest = best
nextBestName = maxName
best = threshold = arr[i]
maxName = i

} else if (arr[i]-nextBest >= 0 ) {

INF(msg":"(arr[i]>nextBest?"beats":"matches")" current next best of " nextBest " held by ["nextBestName"]")
nextBest = arr[i]
nextBestName = i
INF(msg": set as next best")

} else {
INF(msg)
}
}
DEBUG("Best "best"*"arr[i]". Required="requiredThreshold)

if (0+best < 0+requiredThreshold ) {
DEBUG("Rejected as "best" does not meet requiredThreshold of "requiredThreshold)
return ""
}
if (requireDifferenceSquared ) {
diff=best-nextBest
DEBUG("Next best count = "nextBest" diff^2 = "(diff*diff))
if (diff * diff - best  >= 0 ) {

return maxName

} else if (dontRejectCloseSubstrings && (index(maxName,nextBestName) || index(nextBestName,maxName))) {

DEBUG("Match permitted as next best is a substring")
return maxName

} else {

DEBUG("But rejected as "best" too close to next best "nextBest" to be certain")
return ""

}
} else {
return maxName
}
}



































































function searchForIMDB(keywords,linkThreshold,\
i1,result) {
if (!(keywords in g_imdb_link_search)) {

INF("Begin IMDBLink Search ["keywords"]")


keywords = keywords"+%2Bimdb+%2Btitle+-inurl%3Aimdb.com+-inurl%3Aimdb.de"


i1 = scanUrlForBestMatch(g_search_yahoo keywords,g_imdb_regex,"search4imdb",linkThreshold)
g_imdb_link_search[keywords] = i1

}
result = g_imdb_link_search[keywords]

INF("IMDBLink Search ["keywords"] => ["result"]")
return result
}








function scanUrlForBestMatch(url,pattern,captureLabel,threshold,\
f,start,matchList,bestUrl,x,html) {

f = getUrl(url,captureLabel,0)
if (f != "") {
FS="\n"

DEBUG2("Looking for "pattern" in "f)

while((getline html < f) > 0 ) {


html = de_emphasise(html)











capture_regex(html,pattern,0,matchList)
}
close(f)
}


bestUrl=getMax(matchList,threshold,1,0)
if (bestUrl != "") {
return extractImdbLink(bestUrl)
} else  {
return ""
}
}

function get_episode_url(plugin,seriesUrl,season,episode,\
episodeUrl ) {
episodeUrl = seriesUrl
if (plugin == "THETVDB") {
if (g_tvdb_user_per_episode_api) {

if (sub(/en.xml$/,"default/"season"/"(episode+0)"/en.xml",episodeUrl)) {
return episodeUrl
}
} else {

return episodeUrl
}
} else if (plugin == "TVRAGE") {

return episodeUrl
}
return ""
}



function get_episode_xml(plugin,seriesUrl,season,episode,episodeInfo,\
episodeUrl,filter,result) {
delete episodeInfo
episodeUrl = get_episode_url(plugin,seriesUrl,season,episode)
if (episodeUrl != "") {
if (plugin == "THETVDB") {

if (g_tvdb_user_per_episode_api) {
result = fetchXML(episodeUrl,plugin"-episode",episodeInfo)
} else {
filter["/Data/Episode/SeasonNumber"] = season
filter["/Data/Episode/EpisodeNumber"] = episode
result = fetch_xml_single_child(episodeUrl,plugin"-episode","/Data/Episode",filter,episodeInfo)
}

} else if (plugin == "TVRAGE" ) {
filter["/Show/Episodelist/Season#no"] = season
filter["/Show/Episodelist/Season/episode/seasonnum"] = episode
result = fetch_xml_single_child(episodeUrl,plugin"-episode","/Show/Episodelist/Season/episode",filter,episodeInfo)
} else {
plugin_error(plugin)
}
dump(0,"episode-xml",episodeInfo)
} else {
INF("cant determine episode url from "seriesUrl)
}
DEBUG("get_episode_xml="result)
return result
}

function scrape_check(idx,site) {
return (index(g_scraped[idx],site))
}

function scrape_set(idx,site) {
g_scraped[idx] = g_scraped[idx] "," site
}


function get_tv_series_info(plugin,idx,tvDbSeriesUrl,\
result) {

DEBUG("get_tv_series_info "plugin" [" tvDbSeriesUrl "]")

if (plugin == "THETVDB") {
result = get_tv_series_info_tvdb(idx,tvDbSeriesUrl)
} else if (plugin == "TVRAGE") {
result = get_tv_series_info_rage(idx,tvDbSeriesUrl)
} else {
plugin_error(plugin)
}
DEBUG("Title:["gTitle[idx]"] "g_season[idx]"x"g_episode[idx]" date:"gAirDate[idx])
DEBUG("Episode:["gEpTitle[idx]"]")
DEBUG("end get_tv_series_info "plugin" = "result"="(result==2?"Full Episode Info":(result?"Series Only":"Not Found")))
return result
}

function setFirst(array,field,value) {
if (array[field] == "") {
array[field] = value
print "["field"] set to ["value"]"
} else {
print "["field"] already set to ["array[field]"] ignoring ["value"]"
}
}

function remove_year(t) {
sub(/ *\([12][0-9][0-9][0-9]\)/,"",t)
return t
}




function get_tv_series_info_tvdb(idx,tvDbSeriesUrl,\
seriesInfo,episodeInfo,bannerApiUrl,result,empty_filter) {


result=0


fetch_xml_single_child(tvDbSeriesUrl,"thetvdb-series","/Data/Series",empty_filter,seriesInfo)
if ("/Data/Series/id" in seriesInfo) {

setFirst(g_imdb,idx,extractImdbLink(seriesInfo["/Data/Series/IMDB_ID"]))

adjustTitle(idx,remove_year(seriesInfo["/Data/Series/SeriesName"]),"thetvdb")

g_year[idx] = substr(seriesInfo["/Data/Series/FirstAired"],1,4)
setFirst(g_premier,idx,formatDate(seriesInfo["/Data/Series/FirstAired"]))
g_plot[idx] = seriesInfo["/Data/Series/Overview"]
DEBUG("tvdb plot "g_plot[idx])




gCertRating[idx] = seriesInfo["/Data/Series/ContentRating"]
g_rating[idx] = seriesInfo["/Data/Series/Rating"]
setFirst(g_poster,idx,tvDbImageUrl(seriesInfo["/Data/Series/poster"]))
result ++


bannerApiUrl = tvDbSeriesUrl
sub(/(all.|)en.xml$/,"banners.xml",bannerApiUrl)

getTvDbSeasonBanner(idx,bannerApiUrl,"en")



if (g_episode[idx] ~ "^[0-9,]+$" ) {

get_episode_xml("THETVDB",tvDbSeriesUrl,g_season[idx],g_episode[idx],episodeInfo)

if ("/Data/Episode/id" in episodeInfo) {
setFirst(gAirDate,idx,formatDate(episodeInfo["/Data/Episode/FirstAired"]))

set_eptitle(idx,episodeInfo["/Data/Episode/EpisodeName"])

DEBUG("tvdb epplot :["g_epplot[idx]"]")
setFirst(g_epplot,idx,episodeInfo["/Data/Episode/Overview"])
DEBUG("tvdb epplot :["g_epplot[idx]"]")

if (gEpTitle[idx] != "" ) {
if ( gEpTitle[idx] ~ /^Episode [0-9]+$/ && g_plot[idx] == "" ) {
INF("Due to Episode title of ["gEpTitle[idx]"] Demoting result to force another TV plugin search")
} else {
result ++
}
}
}
}
} else {
WARNING("Failed to find ID in XML")
}


if (g_imdb[idx] == "" ) {
WARNING("get_tv_series_info returns blank imdb url. Consider updating the imdb field for this series at www.thetvdb.com")
} else {
DEBUG("get_tv_series_info returns imdb url ["g_imdb[idx]"]")
}
return result
}

function tvDbImageUrl(path) {
if(path != "") {


return "http://thetvdb.com/banners/" url_encode(html_decode(path))
} else {
return ""
}
}

function getTvDbSeasonBanner(idx,bannerApiUrl,language,\
xml,filter,r) {

if (getting_poster(idx,1) || getting_fanart(idx,1)) {
r="/Banners/Banner"
delete filter
filter[r"/Language"] = language
filter[r"/BannerType"] = "season"
filter[r"/Season"] = g_season[idx]
if (fetch_xml_single_child(bannerApiUrl,"banners","/Banners/Banner",filter,xml) ) {
g_poster[idx] = tvDbImageUrl(xml[r"/BannerPath"])
DEBUG("Season Poster URL = "g_poster[idx])
}

delete filter
filter[r"/Language"] = language
filter[r"/BannerType"] = "fanart"
if (fetch_xml_single_child(bannerApiUrl,"banners","/Banners/Banner",filter,xml) ) {
g_fanart[idx] = tvDbImageUrl(xml[r"/BannerPath"])
DEBUG("Fanart URL = "g_fanart[idx])
}
}
}

function set_eptitle(idx,title) {
if (gEpTitle[idx] == "" ) {

gEpTitle[idx] = title
INF("Setting episode title ["title"]")

} else if (title != "" && title !~ /^Episode [0-9]+$/ && gEpTitle[idx] ~ /^Episode [0-9]+$/ ) {

INF("Overiding episode title ["gEpTitle[idx]"] with ["title"]")
gEpTitle[idx] = title
} else {
INF("Keeping episode title ["gEpTitle[idx]"] ignoring ["title"]")
}
}


function get_tv_series_info_rage(idx,tvDbSeriesUrl,\
seriesInfo,episodeInfo,filter,sid,url,e,result,pi,p) {

pi="TVRAGE"
result = 0
delete filter

if (fetch_xml_single_child(tvDbSeriesUrl,"tvinfo-show","/Show",filter,seriesInfo)) {
adjustTitle(idx,remove_year(seriesInfo["/Show/name"]),pi)
g_year[idx] = substr(seriesInfo["/Show/started"],8,4)
sid=seriesInfo["/Show/showid"]
setFirst(g_premier,idx,formatDate(seriesInfo["/Show/started"]))
url=seriesInfo["/Show/showlink"]
g_plot[idx] = scrape_one_item("tvrage_plot",url,"id='"'"'iconn1",0,"iconn2",0)
result ++

e="/Show/Episodelist/Season/episode"
if (g_episode[idx] ~ "^[0-9,]+$" ) {

if (get_episode_xml(pi,tvDbSeriesUrl,g_season[idx],g_episode[idx],episodeInfo)) {

set_eptitle(idx,episodeInfo[e"/title"])

gAirDate[idx]=formatDate(episodeInfo[e"/airdate"])
url=episodeInfo[e"/link"]

if (g_epplot[idx] == "" ) {
p = scrape_one_item("tvrage_epplot",url,">Episode Summary</h",0,"<a ",0)
if (p != "" && index(p,"There is no summary") == 0) {
g_epplot[idx] = p
DEBUG("rage epplot :"g_epplot[idx])
}
}
result ++
} else {
WARNING("Error getting episode xml")
}
}

} else {
WARNING("Error getting series xml")
}

return result
}

function clean_xml_path(xmlpath,xml,\
t,xmlpathSlash,xmlpathHash) {



xmlpathSlash=xmlpath"/"
xmlpathHash=xmlpath"#"




for(t in xml) {
if (index(t,xmlpath) == 1) {
if (t == xmlpath || index(t,xmlpathSlash) == 1 || index(t,xmlpathHash) == 1) {
delete xml[t]
}
}
}
}

function fetch_xml_single_child(url,filelabel,xmlpath,tagfilters,xmlout,\
f,found) {

f = getUrl(url,filelabel,1)
DEBUG("fetch_xml_single_child ["url"] path = "xmlpath)
found =  scan_xml_single_child(f,xmlpath,tagfilters,xmlout)
DEBUG("fetch_xml_single_child ["url"]="found)
return found
}
function scan_xml_single_child(f,xmlpath,tagfilters,xmlout,\
line,start_tag,end_tag,found,t,last_tag,filter_type,regex,number_type,regex_type,string_type,this_type) {

delete xmlout
found=0

number_type=1
regex_type=2
string_type=3

last_tag = xmlpath
sub(/.*\//,"",last_tag)

start_tag="<"last_tag">"
end_tag="</"last_tag">"

for(t in tagfilters) {
DEBUG("filter ["t"]=["tagfilters[t]"]")
if (tagfilters[t] ~ "^[0-9]+$" ) {
filter_type[t] = number_type
} else if (substr(tagfilters[t],1,2) == "~:") {
regex[t] = substr(tagfilters[t],3)
filter_type[t] = regex_type
} else {
filter_type[t] = string_type
}
}

if (f != "") {
FS="\n"

while((getline line < f) > 0 ) {
if (index(line,start_tag) > 0) {
clean_xml_path(xmlpath,xmlout)
}

parseXML(line,xmlout)

if (index(line,end_tag) > 0) {


found=1
for(t in tagfilters) {
this_type = filter_type[t]

if (!(t in xmlout) ) {


found =0 ; break

} else if (this_type == string_type) {
if (xmlout[t] != tagfilters[t] ) {

found=0;break
}

} else if (this_type == number_type) {

if (xmlout[t] - tagfilters[t] != 0) {

found=0;break
}
} else if (this_type == regex_type) {

if ( xmlout[t] !~ regex[t] ) {

found=0;break
}
} else {
ERR("Bad type "this_type)
exit
}
}

if (found) {
DEBUG("Filter matched.")
break
}

}

}
close(f)
}
if (!found) {
clean_xml_path(xmlpath,xmlout)


}
return found
}



function adjustTitle(idx,newTitle,source) {

if (!("filename" in gTitlePriority)) {

gTitlePriority[""]=-1
gTitlePriority["filename"]=0
gTitlePriority["search"]=1
gTitlePriority["imdb"]=2
gTitlePriority["epguides"]=2
gTitlePriority["imdb_aka"]=3
gTitlePriority["thetvdb"]=4
gTitlePriority["THETVDB"]=4
gTitlePriority["TVRAGE"]=4
}
newTitle = clean_title(newTitle)

if (!(source in gTitlePriority)) {

ERR("Bad value ["source"] passed to adjustTitle")

} else if (gTitle[idx] == "" || gTitlePriority[source] - gTitlePriority[g_title_source[idx]] > 0) {
if (newTitle != gTitle[idx] ) {
DEBUG("title changed from "g_title_source[idx]":["gTitle[idx]"] to "source":["newTitle"]")
} else {
DEBUG("title "g_title_source[idx]":["gTitle[idx]"] matches "source":["newTitle"]")
}
gTitle[idx] = newTitle
g_title_source[idx] = source
return 1
} else {
DEBUG("title kept as "g_title_source[idx]":["gTitle[idx]"] instead of "source":["newTitle"]")
return 0
}
}

function extractImdbId(text,quiet,\
id) {
if (match(text,g_imdb_regex)) {
id = substr(text,RSTART,RLENGTH)

} else if (match(text,"Title.[0-9]+\\>")) {
id = "tt" substr(text,RSTART+8,RLENGTH-8)

} else if (!quiet) {
WARNING("Failed to extract imdb id from ["text"]")
}
if (id != "" && length(id) != 9) {
id = sprintf("tt%07d",substr(id,3))
}
return id
}






function getIsoTitle(isoPath,\
sep,tmpFile,f,outputWords,isoPart,outputText) {
FS="\\n"
sep="~"
outputWords=0
tmpFile=tmp_dir"/bytes."JOBID
isoPart=tmp_dir"/bytes."JOBID".2"
delete outputText

if (exec("dd if="quoteArg(isoPath)" of="isoPart" bs=1024 count=10 skip=32") != 0) {
return 0
}

DEBUG("Get strings "isoPath)

DEBUG("tmp file "tmpFile)

system("awk '"'"'BEGIN { FS=\"_\" } { gsub(/[^ -~]+/,\"~\"); gsub(\"~+\",\"~\") ; split($0,w,\"~\"); for (i in w)  if (w[i]) print w[i] ; }'"'"' "isoPart" > "tmpFile)
getline f < tmpFile
getline f < tmpFile
system("rm -f -- "tmpFile" "isoPart)
INF("iso title for "isoPath" = ["f"]")
gsub(/[Ww]in32/,"",f)
return clean_title(f)
close(tmpFile)
}

function extractImdbLink(text,quiet,\
t) {
t = extractImdbId(text,quiet)
if (t != "") {
t = "http://www.imdb.com/title/"t"/"
}
return t
}

function extractAttribute(str,tag,attr,\
tagPos,closeTag,endAttr,attrPos) {

tagPos=index(str,"<"tag)
closeTag=indexFrom(str,">",tagPos)
attrPos=indexFrom(str,attr"=",tagPos)
if (attrPos == 0 || attrPos-closeTag >= 0 ) {
ERR("ATTR "tag"/"attr" not in "str)
ERR("tagPos is "tagPos" at "substr(str,tagPos))
ERR("closeTag is "closeTag" at "substr(str,closeTag))
ERR("attrPos is "attrPos" at "substr(str,attrPos))
return ""
}
attrPos += length(attr)+1
if (substr(str,attrPos,1) == "\"" ) {
attrPos++
endAttr=indexFrom(str,"\"",attrPos)
}  else  {
endAttr=indexFrom(str," ",attrPos)
}

return substr(str,attrPos,endAttr-attrPos)
}

function extractTagText(str,startText,\
i,j) {
i=index(str,"<"startText)
i=indexFrom(str,">",i) + 1
j=indexFrom(str,"<",i)
return trim(substr(str,i,j-i))
}

function indexFrom(str,x,startPos,\
j) {
if (startPos<1) startPos=1
j=index(substr(str,startPos),x)
if (j == 0) return 0
return j+startPos-1
}

function utf8_encode(text,\
i,text2,ll,c) {
if (g_chr[32] == "" ) {
decode_init()
}
text2=""
ll=length(text)
for(i = 1 ; i - ll <= 0 ; i++ ) {
c=substr(text,i,1)
text2 = text2 g_utf8[c]
}
if (text != text2 ) {
DEBUG("utf8 encode ["text"]=["text2"]")
}

return text2
}


function url_encode(text,\
i,text2,ll,c) {

if (g_chr[32] == "" ) {
decode_init()
}

text=utf8_encode(text)

text2=""
ll=length(text)
for(i = 1 ; i - ll <= 0 ; i++ ) {
c=substr(text,i,1)
if (index("% =()[]+",c) || g_ascii[c] -128 >= 0 ) {
text2= text2 "%" g_hex[g_ascii[c]]
} else {
text2=text2 c
}
}
if (text != text2 ) {
DEBUG("url encode ["text"]=["text2"]")
}

return text2
}

function decode_init(\
i,c,h,b1,b2) {
DEBUG("create decode matrix")
for(i=0 ; i - 256 < 0 ; i++ ) {
c=sprintf("%c",i)
h=sprintf("%02x",i)
g_chr[i] = c
g_chr["x"h] = c
g_ascii[c] = i
g_hex[i]=h

}
for(i=0 ; i - 128 < 0 ; i++ ) {
c = g_chr[i]
g_utf8[c]=c
}
for(i=128 ; i - 256 < 0 ; i++ ) {
c = g_chr[i]
b1=192+rshift(i,6)
b2=128+and(i,63)
g_utf8[c]=g_chr[b1+0] g_chr[b2+0]
}
}

function html_decode(text,\
i,j,code,newcode) {
if (g_chr[32] == "" ) {
decode_init()
}
i=0
while((i=indexFrom(text,"&#",i)) > 0) {
DEBUG("i="i)
j=indexFrom(text,";",i)
code=tolower(substr(text,i+2,j-(i+2)))

if (substr(code,1,1) == "x") {
newcode=g_chr[code]
} else {
newcode=g_chr[0+code]
}
text=substr(text,1,i-1) newcode substr(text,j+1)
}

return text
}


function equate_urls(u1,u2) {

INF("equate ["u1"] =\n\t ["u2"]")

if (u1 in gUrlCache) {

gUrlCache[u2]=gUrlCache[u1]

} else if (u2 in gUrlCache) {

gUrlCache[u1]=gUrlCache[u2]
}
}




function persistent_cache(fname,\
dir) {
dir=APPDIR"/cache"
if (g_cache_ok == 0) {
g_cache_ok=2
system("mkdir -p "quoteArg(dir))
if (set_permissions(quoteArg(dir)"/.") == 0) {
g_cache_ok=1
}
}

if (g_cache_ok == 1) {
INF("Using persistent cache")
return dir"/"fname
} else if (g_cache_ok == 2) {
return ""
}
}

function getUrl(url,capture_label,cache,referer,\
f,label) {

label="getUrl:"capture_label": "



if (url == "" ) {
WARNING(label"Ignoring empty URL")
return
}

if(cache && (url in gUrlCache) ) {

DEBUG(label" fetched ["url"] from cache")
f = gUrlCache[url]
}

if (g_settings["catalog_cache_film_info"] == "yes") {
if (url ~ ".imdb.com/title/tt[0-9]+/?$" ) {
f = persistent_cache(extractImdbId(url))
cache=1
}
}

if (f =="" ) {
f=NEW_CAPTURE_FILE(capture_label)
}
if (!is_file(f)) {

if (wget(url,f,referer) ==0) {
if (cache) {
gUrlCache[url]=f

} else {

}
} else {
ERR(label" Failed getting ["url"] into ["f"]")
f = ""
}
}
return f
}

function get_referer(url,\
i,referer) {

i = index(substr(url,10),"/")
if (i) {
referer=substr(url,1,9+i)
}
return referer
}


function wget(url,file,referer,\
i,urls,tmpf,qf,r) {
split(url,urls,"\t")
tmpf = file ".tmp"
qf = quoteArg(tmpf)

r=1
for(i in urls) {
if (urls[i] != "") {
if (wget2(urls[i],tmpf,referer) == 0) {
exec("cat "qf" >> "quoteArg(file))
r=0
}
}
system("rm -f "qf)
}
return r
}



function wget2(url,file,referer,\
args,unzip_cmd,cmd,htmlFile,downloadedFile,same_domain_delay,targetFile,result,default_referer) {

args=" -U \""g_user_agent"\" "g_wget_opts
default_referer = get_referer(url)



if (referer == "") {
referer = default_referer
}

if (referer != "") {
DEBUG2("Referer = "referer)
args=args" --referer=\""referer"\" "
}

targetFile=quoteArg(file)
htmlFile=targetFile

args=args" --header=\"Accept-Encoding: gzip,deflate\" "
downloadedFile=quoteArg(file".gz")

unzip_cmd=" && ( gunzip -c "downloadedFile" || gzip -c -d "downloadedFile" || cat "downloadedFile") > "htmlFile" 2>/dev/null && rm "downloadedFile

gsub(/ /,"+",url)




rm(downloadedFile,1)
args = args " -c "



url=quoteArg(url)








cmd = "wget -O "downloadedFile" "args" "url" "unzip_cmd  





same_domain_delay=0


DEBUG("WGET ["url"]")
result = exec(cmd)
if (result != 0) {


rm(downloadedFile,1)
}

return result
}


function get_sleep_command(url,required_gap,\
domain,remaining_gap) {

if (match(url,"https?://[a-z0-9A-Z.]+")) {
domain=substr(url,RSTART,RLENGTH)
}

g_search_count[domain]++
if (index(domain,"epguide") || index(domain,"imdb")) {
return ""
}
remaining_gap=required_gap - (systime()-g_last_search_time[domain])
if ( g_last_search_time[domain] > 0 && remaining_gap > 0 ) {

g_last_search_time[domain] = systime()+remaining_gap
return "sleep "remaining_gap" ; "
} else {
g_last_search_time[domain] = systime()
return ""
}
}


function local_poster_path(idx,must_exist,\
p,ext,e) {
split(".jpg,.JPG",ext,",")
p = g_fldr[idx] "/" g_media[idx]
if (g_media[idx] ~ "/$") {

p = g_fldr[idx] "/" g_media[idx] g_media[idx]
sub(/\/$/,"",p)
} else {

sub(/\.[^.]+$/,"",p)
}

for(e in ext) {
if (is_file(p ext[e] )) {
INF("Found local poster path "p ext[e])
return p ext[e]
}
}
if (must_exist) {
INF("No local poster path for "".jpg/.png/...")
return ""
} else {
INF("Setting default local poster path = "p)
return p ".jpg"
}
}



#


function internal_poster_reference(field_id,idx,\
poster_ref) {
poster_ref = gTitle[idx]"_"g_year[idx]
gsub(/[^-_a-zA-Z0-9]+/,"_",poster_ref)
if (g_category[idx] == "T" ) {
poster_ref = poster_ref "_" g_season[idx]
} else {
poster_ref = poster_ref "_" extractImdbId(g_imdb[idx])
}



return "ovs:" field_id "/" g_settings["catalog_poster_prefix"] poster_ref ".jpg"
}

function getting_fanart(idx,lg) {
return getting_image(idx,FANART,GET_FANART,UPDATE_FANART,lg)
}

function getting_poster(idx,lg) {
return getting_image(idx,POSTER,GET_POSTERS,UPDATE_POSTERS,lg)
}

function getting_image(idx,image_field_id,get_image,update_image,lg,\
poster_ref,internal_path) {

poster_ref = internal_poster_reference(image_field_id,idx)
internal_path = getPath(poster_ref,g_fldr[idx])

if (internal_path in g_image_inspected) {
if(lg) INF("Already looked at "poster_ref)
return 0
} else if (update_image) {
if(lg) INF("Force Update of "poster_ref)
return 1
} else if (!get_image) {
if(lg) INF("Skipping "poster_ref)
return 0
} else if (hasContent(internal_path)) {
if(lg) INF("Already have "poster_ref)
return 0
} else {
if(lg) INF("Getting "poster_ref)
return 1
}
}




function download_image(field_id,url,idx,\
poster_ref,internal_path,urls,referer,wget_args,get_it,script_arg,default_referer) {

if (url == "") return ""

DEBUG("Looking for new poster...")






poster_ref = internal_poster_reference(field_id,idx)
internal_path = getPath(poster_ref,g_fldr[idx])





get_it = 0
if (field_id == POSTER) {
get_it = getting_poster(idx,0)
} else if (field_id == FANART) {
get_it = getting_fanart(idx,0)
}

if (get_it ) {



preparePath(internal_path)

split(url,urls,"\t")
url=urls[1]
referer=urls[2]




wget_args=g_wget_opts

DEBUG("Image url = "url)
default_referer = get_referer(url)
if (referer == "" ) {
referer = default_referer
}
if (referer != "" ) {
DEBUG("Referer = "referer)
wget_args = wget_args " --referer=\""referer"\" "
}
wget_args = wget_args " -U \""g_user_agent"\" "


if (field_id == POSTER) {
script_arg="poster"
} else {
script_arg="fanart"
}


rm(internal_path,1)
exec(APPDIR"/bin/jpg_fetch_and_scale "PID" "script_arg" "quoteArg(url)" "quoteArg(internal_path)" "wget_args" &")
g_image_inspected[internal_path]=1
}

return poster_ref
}





















































































function getNiceMoviePosters(idx,imdb_id,\
search_url,poster_url,backdrop_url,referer_url,txt,xml,f,tmp_url) {


if (getting_poster(idx,1) || getting_fanart(idx,1)) {

DEBUG("Poster check imdb_id = "imdb_id)



search_url="http://api.themoviedb.org/2.1/Movie.imdbLookup/en/xml/"g_tk2"/"imdb_id







#
f=getUrl(search_url,"moviedb",0)


if (f != "") {
FS="\n"
while((getline txt < f) > 0 && (poster_url == "" || backdrop_url == "") ) {
delete xml
parseXML(txt,xml)

if (poster_url == "") {
if (xml["/image#type"] == "poster") {
if (xml["/image#size"] == "mid") {
poster_url=url_encode(html_decode(xml["/image#url"]))
if (exec("wget "g_wget_opts" --spider "poster_url) != 0 ) {
poster_url=""
}
}
}
}

if (backdrop_url == "") {
if (xml["/image#type"] == "backdrop") {
if (xml["/image#size"] == "original") {
backdrop_url=url_encode(html_decode(xml["/image#url"]))
if (exec("wget "g_wget_opts" --spider "backdrop_url) != 0 ) {
backdrop_url=""
}
}
}
}

}
close(f)
}

if (poster_url == "") {

referer_url = "http://www.motechposters.com/title/"g_motech_title[idx]"/"




DEBUG("Got motech referer "referer_url)
if (referer_url != "" ) {
tmp_url=scanPageForMatch(referer_url,"/posters/[^\"]+jpg",0)
if (tmp_url != ""  && index(tmp_url,"thumb.jpg") == 0 ) {
poster_url="http://www.motechposters.com" tmp_url

poster_url=poster_url"\t"referer_url
DEBUG("Got motech poster "poster_url)
} 
}

}
INF("movie poster ["poster_url"]")
g_poster[idx]=poster_url

INF("movie backdrop ["backdrop_url"]")
g_fanart[idx]=backdrop_url
}
}





function scanPageForMatch(url,regex,cache,referer,\
matches,i) {
scanPageForMatches(url,regex,1,cache,referer,matches)


for(i in matches) {
return i
}
}





function scanPageForMatches(url,regex,max,cache,referer,matches,\
f,line,count,linecount,regex_text,remain,is_imdb) {

delete matches

DEBUG("scan "url" for "regex)
f=getUrl(url,"scan4match",cache,referer)


regex_text=regex






sub(/[][?\\*(|.].*/,"",regex_text)
INF("Looking for fixed text ["regex_text"] before regex ["regex"]")

count=0

is_imdb = (regex == g_imdb_regex )

if (f != "" ) {

FS="\n"
remain=max

while(((getline line < f) > 0)  ) {




if (is_imdb && index(line,"/Title?") ) {
gsub(/\/Title\?/,"/tt",line)
}

if (regex_text == "" || index(line,regex_text)) {

linecount = capture_regex(line,regex,remain,matches)

count += linecount
if (max > 0) {
remain -= count
if (remain <= 0) {
break
}
}
}
}
close(f)
}
dump(2,count" matches",matches)
return count
}


function capture_regex(line,regex,max,matches,\
count,flag,fcount,i,parts) {
count =0 


flag="@%-�~"


while (index(line,flag) ) {
WARNING("Regex flag clash "flag)
flag = flag "@"
}

gsub(regex,flag "&" flag , line )
fcount = split(line,parts,flag)
for(i=2 ; i-fcount < 0 ; i += 2 ) {
matches[parts[i]]++
count++
if (max+0 > 0 ) {
if (count - max >= 0) {
break
}
}
}

if (index(regex,"motech")) {
dump(0,count " linematches",matches)
}  else 
dump(3,count " linematches",matches)

return count
}


function scrapeIMDBLine(line,imdbContentPosition,idx,f,\
title,y,poster_imdb_url) {

if (imdbContentPosition == "footer" ) {
return imdbContentPosition
} else if (imdbContentPosition == "header" ) {



if (index(line,"<title>")) {
title = extractTagText(line,"title")
DEBUG("Title found ["title "] current title ["gTitle[idx]"]")





#


g_motech_title[idx]=tolower(title)
gsub(/[^a-z0-9]+/,"-",g_motech_title[idx])
gsub(/-$/,"",g_motech_title[idx])

g_imdb_title[idx]=extract_imdb_title_category(idx,title)

title=clean_title(g_imdb_title[idx])
if (adjustTitle(idx,title,"imdb")) {
gOriginalTitle[idx] = gTitle[idx]
}
}
if (index(line,"pagecontent")) {
imdbContentPosition="body"
}

} else if (imdbContentPosition == "body") {

if (index(line,">Company:")) {

DEBUG("Found company details - ending")
imdbContentPosition="footer"

} else {



if (g_year[idx] == "" && (y=index(line,"/Sections/Years/")) > 0) {
g_year[idx] = substr(line,y+16,4)
DEBUG("IMDB: Got year ["g_year[idx]"]")
}
if (index(line,"a name=\"poster\"")) {
if (match(line,"src=\"[^\"]+\"")) {

poster_imdb_url = substr(line,RSTART+5,RLENGTH-5-1)


sub(/SX[0-9]{2,3}_/,"SX400_",poster_imdb_url)
sub(/SY[0-9]{2,3}_/,"SY400_",poster_imdb_url)


g_imdb_poster_url[idx]=poster_imdb_url
DEBUG("IMDB: Got imdb poster ["g_imdb_poster_url[idx]"]")
}
}
if (g_director[idx] == "" && index(line,"Director:")) {
g_director[idx] = scrape_until("idirector",f,"/name/",1)
}

if (g_plot[idx] == "" && index(line,"Plot:")) {
g_plot[idx] = scrape_until("iplot",f,"</div>",0)
sub(/\|.*/,"",g_plot[idx])
sub(/full (summary|synopsis).*/,"",g_plot[idx])

}


if (g_genre[idx] == "" && index(line,"Genre:")) {
g_genre[idx]=trimAll(scrape_until("igenre",f,"</div>",0))
sub(/ +more */,"",g_genre[idx])
}
if (g_rating[idx] == "" && index(line,"/10</b>") ) {
g_rating[idx]=0+extractTagText(line,"b")
DEBUG("IMDB: Got Rating = ["g_rating[idx]"]")
}
if (index(line,"certificates")) {

scrapeIMDBCertificate(idx,line)

}



if (gOriginalTitle[idx] == gTitle[idx] && index(line,"Also Known As:")) {

scrapeIMDBAka(idx,line)

}
}
} else {
DEBUG("Unknown imdbContentPosition ["imdbContentPosition"]")
}
return imdbContentPosition
}

function extract_imdb_title_category(idx,title,\
semicolon,quote) {


g_category[idx]="M"
if (substr(title,1,1) == "&" ) {
semicolon=index(title,";")
if (semicolon > 0 ) { 

quote=substr(title,2,semicolon-1)
gsub("."quote,"",title)
g_category[idx]="T"











}
}


gsub(/ \((19|20)[0-9][0-9](\/I|)\) *(\([A-Z]+\)|)$/,"",title)

DEBUG("Imdb title = ["title"]")
return title
}







function scrapeIMDBAka(idx,line,\
l,akas,a,c,exclude,e,eEeE) {

if (gOriginalTitle[idx] != gTitle[idx] ) return 

l=substr(line,index(line,"</h")+5)
split(l,akas,"<br>")
for(a in akas) {
DEBUG("Checking aka ["akas[a]"]")
for(c in gTitleCountries ) {
if (index(akas[a],"("gTitleCountries[c]":")) {


DEBUG("Ignoring aka section")
return
eEeE=")"
}
if (index(akas[a],"("gTitleCountries[c]")")) {

split("longer version|season title|poster|working|literal|IMAX|promotional|long title|script title|closing credits|informal alternative",exclude,"|")
for(e in exclude) {
if (index(akas[a],exclude[e])) {


DEBUG("Ignoring aka section")
return
}
}

akas[a]=substr(akas[a],1,index(akas[a]," (")-1)
akas[a]=clean_title(akas[a])
sub(/ \(.*/,"",akas[a])
adjustTitle(idx,akas[a],"imdb_aka"); 
return

}
}
}
}

function scrapeIMDBCertificate(idx,line,\
l,cert,c) {
if ( match(line,"List[?]certificates=[^&]+")) {



l=substr(line,RSTART,RLENGTH)
l=substr(l,index(l,"=")+1)
split(l,cert,":")



for(c = 1 ; (c in gCertificateCountries ) ; c++ ) {
if (gCertCountry[idx] == gCertificateCountries[c]) {

return
}
if (cert[1] == gCertificateCountries[c]) {

gCertCountry[idx] = cert[1]
gCertRating[idx] = cert[2]
gsub(/%20/," ",gCertRating[idx])
DEBUG("IMDB: set certificate ["gCertCountry[idx]"]["gCertRating[idx]"]")
return
}
}
}
}


function scrape_one_item(label,url,start_text,start_include,end_text,end_include,\
f,line,out,found) {

f=getUrl(url,label,0)
if (f) {
while((getline line < f) > 0 ) {
if (index(line,start_text)) {

out = scrape_until(label,f,end_text,end_include)
if (start_include) {

out = remove_tags(line) out

}
found = 1
break
}
}
close(f)
}
if (found != 1) {
ERR("Cant find ["start_text"] in "label":"url)
}

return out
}
function scrape_until(label,f,end_text,inclusive,\
line,out,ending) {
ending = 0
while(!ending && (getline line< f) > 0) {
if (index(line,end_text)) {
ending=1
if (!inclusive) {
break
}
}
line = remove_tags(line)
out = out " " line
}
gsub(/ +/," ",out)
INF("scrape_until "label"/"end_text":=["out"]")
return trim(out)
}

function relocating_files(i) {
return (RENAME_TV == 1 && g_category[i] == "T") ||(RENAME_FILM==1 && g_category[i] == "M")
}

function relocate_files(i,\
newName,oldName,nfoName,oldFolder,newFolder,fileType,epTitle) {

DEBUG("relocate_files")

newName=""
oldName=""
fileType=""
if (RENAME_TV == 1 && g_category[i] == "T") {

oldName=g_fldr[i]"/"g_media[i]
newName=g_settings["catalog_tv_file_fmt"]
newName = substitute("SEASON",g_season[i],newName)
newName = substitute("EPISODE",g_episode[i],newName)
newName = substitute("INF",gAdditionalInfo[i],newName)

epTitle=gEpTitle[i]
gsub(/[^-A-Za-z0-9,. ]/,"",epTitle)
gsub(/[{]EPTITLE[}]/,epTitle,newName)

newName = substitute("EPTITLE",epTitle,newName)
newName = substitute("0SEASON",sprintf("%02d",g_season[i]),newName)
newName = substitute("0EPISODE",pad_episode(g_episode[i]),newName)

fileType="file"

} else if (RENAME_FILM==1 && g_category[i] == "M") {

oldName=g_fldr[i]
newName=g_settings["catalog_film_folder_fmt"]
fileType="folder"

} else {
return
}
if (newName != "" && newName != oldName) {

oldFolder=g_fldr[i]

if (fileType == "file") {
newName = substitute("NAME",g_media[i],newName)
if (match(g_media[i],"\.[^.]+$")) {

newName = substitute("BASE",substr(g_media[i],1,RSTART-1),newName)
newName = substitute("EXT",substr(g_media[i],RSTART),newName)
} else {

newName = substitute("BASE",g_media[i],newName)
newName = substitute("EXT","",newName)
}
}
newName = substitute("DIR",g_fldr[i],newName)
newName = substitute("TITLE",gTitle[i],newName)
newName = substitute("YEAR",g_year[i],newName)
newName = substitute("CERT",gCertRating[i],newName)
newName = substitute("GENRE",g_genre[i],newName)


gsub(/[\\:*\"<>|]/,"_",newName)

newName = clean_path(newName)

if (newName != oldName) {
if (fileType == "folder") {
if (moveFolder(i,oldName,newName) != 0) {
return
}

delete gMovieFilePresent[oldName]
gMovieFilePresent[newName]=i

g_file[i]=""
g_fldr[i]=newName
} else {


if (moveFile(oldName,newName) != 0 ) {
return
}

delete gMovieFilePresent[oldName]
gMovieFilePresent[newName]=i

g_fldrMediaCount[g_fldr[i]]--
g_file[i]=newName


newFolder=newName
sub(/\/[^\/]+$/,"",newFolder)


g_fldr[i]=newFolder

g_media[i]=newName
sub(/.*\//,"",g_media[i])


if(is_file(gNfoDefault[i])) {

nfoName = newName
sub(/\.[^.]+$/,"",nfoName)
nfoName = nfoName ".nfo"

if (nfoName == newName ) {
return
}

if (moveFile(gNfoDefault[i],nfoName) != 0) {
return
}
if (!g_opt_dry_run) {

gDate[nfoName]=gDate[gNfoDefault[i]]
delete gDate[gNfoDefault[i]]

gNfoDefault[i] = nfoName
}
}


if(g_poster[i] != "" && substr(g_poster[i],1,1)!= "/" && substr(g_poster[i],1,4) != "ovs:" ) {
oldName=oldFolder"/"g_poster[i]
newName=newFolder"/"g_poster[i]
if (moveFile(oldName,newName) != 0 ) {
return
}
}


rename_related(oldName,newName)


moveFolder(i,oldFolder,newFolder)
}
}

if (is_dir(oldFolder) && is_empty(oldFolder)) {
system("rmdir "quoteArg(oldFolder))
}

} else {

if (g_opt_dry_run) {
print "dryrun:\t"newName" unchanged."
print "dryrun:"
} else {
INF("rename:\t"newName" unchanged.")
}
}
}

function rm(x,quiet,quick) {
removeContent("rm -f -- ",x,quiet,quick)
}
function rmdir(x,quiet,quick) {
removeContent("rmdir -- ",x,quiet,quick)
}
function removeContent(cmd,x,quiet,quick) {

if (!changeable(x)) return 1

if (!quiet) {
INF("Deleting "x)
}
cmd=cmd quoteArg(x)" 2>/dev/null "
if (quick) {
return "(" cmd ") & "
} else {
return "(" cmd " || true ) "
} 
}

function substitute(keyword,value,str,\
oldStr,hold) {

oldStr=str
if (index(value,"&")) {
gsub(/[&]/,"\\\\&",value)
}
if (index(str,keyword)) {
while(match(str,"[{][^{}]*:"keyword":[^{}]*[}]")) {
hold=substr(str,RSTART,RLENGTH)
if (value=="") {
hold=""
} else {
sub(":"keyword":",value,hold)
hold=substr(hold,2,length(hold)-2)
}
str=substr(str,1,RSTART-1) hold substr(str,RSTART+RLENGTH)
}
}

if ( oldStr != str ) {
DEBUG("Keyword ["keyword"]=["value"]")
DEBUG("Old path ["oldStr"]")
DEBUG("New path ["str"]")
}

return str
}

function rename_related(oldName,newName,\
extensions,ext,oldBase,newBase) {
split("srt idx sub",extensions," ")

oldBase = oldName
sub(/\....$/,".",oldBase)

newBase = newName
sub(/\....$/,".",newBase)

for(ext in extensions) {
moveFile(oldBase extensions[ext],newBase extensions[ext])
}

}

function preparePath(f) {
f = quoteArg(f)
return system("if [ ! -e "f" ] ; then mkdir -p "f" && chown '$OVERSIGHT_ID' "f"/.. &&  rmdir -- "f" ; fi")
}




function changeable(f) {



if (index(f,"/tmp/") == 1) return 1
if (index(f,"/share/tmp/") == 1) return 1

if (!match(f,"/[^/]+/[^/]+/")) {
WARNING("Changing ["f"] might be risky. please make manual changes")
return 0
}
return 1
}

function moveFile(oldName,newName,\
new,old,ret) {

if (!changeable(oldName) ) {
return 1
}
new=quoteArg(newName)
old=quoteArg(oldName)
if (g_opt_dry_run) {
if (match(oldName,gExtRegExAll) && system("test -f "old) == 0) {
print "dryrun: from "old
print "dryrun: to\t"new
print "dryrun:"
}
return 0
} else {

if ((ret=preparePath(newName)) == 0) {
ret = exec("mv "old" "new)
}
return ret
}
}

function isDvdDir(f) {
return substr(f,length(f)) == "/"
}


function moveFolder(i,oldName,newName,\
cmd,new,old,ret,isDvdDir) {

if (!(folderIsRelevant(oldName))) {
WARNING("["oldName"] not renamed as it was not listed in the arguments")
return 1
} else if ( g_fldrCount[oldName] - 2*(isDvdDir(g_media[i])) > 0 ) {
WARNING("["oldName"] not renamed to ["newName"] due to "g_fldrCount[oldName]" sub folders")
return 1
} else if (g_fldrMediaCount[oldName] - 1 > 0) {
WARNING("["oldName"] not renamed to ["newName"] due to "g_fldrMediaCount[oldName]" media files")
return 1
} else if (!changeable(oldName) ) {
return 1
} else {
new=quoteArg(newName)
old=quoteArg(oldName)
if (g_opt_dry_run) { 
print "dryrun: from "old"/* to "new"/"
return 0
} else {
INF("move folder:"old"/* --> "new"/")
cmd="mkdir -p "new" ;  mv "old"/* "new" ; mv "old"/.[^.]* "new" 2>/dev/null ; rmdir "old
ret = exec(cmd)
system("rmdir "old" 2>/dev/null")
}
return ret
}
}

function hasContent(f,\
tmp,err) {
err = (getline tmp < f )
if (err != -1) close(f)
return (err == 1 )
}

function isnmt() {
return is_file("'"$NMT_APP_DIR"'/MIN_FIRMWARE_VER")
}
function is_file(f,\
tmp,err) {
err = (getline tmp < f )
if (err == -1) {

} else {
close(f)
}
return (err != -1 )
}
function is_empty(d) {
return system("ls -a "quoteArg(d)" | egrep -v '^\.\.?$'") != 0
}
function is_dir(f) {
return test("-d",f"/.")
}
function is_file_or_folder(f,\
r) {
r = (is_file(f) || is_dir(f))
if (!r) INF(f" is neither file or folder")
return r
}

function test(t,f) {
return system("test "t" "quoteArg(f)) == 0
}




function generate_nfo_file(nfoFormat,dbrow,\
movie,tvshow,nfo,dbOne,fieldName,fieldId,nfoAdded,episodedetails) {

nfoAdded=0
if (g_settings["catalog_nfo_write"] == "never" ) {
return
}
parseDbRow(dbrow,dbOne)
get_name_dir_fields(dbOne)

DEBUG("NFO = "dbOne[NFO])

if (dbOne[NFO] == "" ) return

DEBUG("DIR = "dbOne[DIR])
nfo=getPath(dbOne[NFO],dbOne[DIR])

DEBUG("nfo = "nfo)

if (is_file(nfo) && g_settings["catalog_nfo_write"] != "overwrite" ) {
DEBUG("nfo already exists - skip writing")
return
}
DEBUG("nfo exists = "is_file(nfo))

DEBUG("nfo style = "nfoFormat)

if (nfoFormat == "xmbc" ) {
movie=","TITLE","ORIG_TITLE","RATING","YEAR","DIRECTOR","PLOT","POSTER","FANART","CERT","WATCHED","IMDBID","FILE","GENRE","
tvshow=","TITLE","URL","RATING","PLOT","GENRE","POSTER","FANART","
episodedetails=","EPTITLE","SEASON","EPISODE","AIRDATE","
}


if (nfo != "" && !is_file(nfo)) {



DEBUG("Creating ["nfoFormat"] "nfo)

if (nfoFormat == "xmbc") {
if (dbOne[CATEGORY] =="M") {

if (dbOne[URL] != "") {
dbOne[IMDBID] = extractImdbId(dbOne[URL])
}

startXmbcNfo(nfo)
writeXmbcTag(dbOne,"movie",movie,nfo)
nfoAdded=1

} else if (dbOne[CATEGORY] == "T") {

startXmbcNfo(nfo)
writeXmbcTag(dbOne,"tvshow",tvshow,nfo)
writeXmbcTag(dbOne,"episodedetails",episodedetails,nfo)
nfoAdded=1
}
} else {

print "#Auto Generated NFO" > nfo
for (fieldId in dbOne) {
if (dbOne[fieldId] != "") {
fieldName=g_db_field_name[fieldId]
if (fieldName != "") {
print fieldName"\t: "dbOne[fieldId] > nfo
}
}
}
nfoAdded=1
}
}
if(nfoAdded) {
close(nfo)
set_permissions(quoteArg(nfo))
}
}

function startXmbcNfo(nfo) {
print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > nfo
print "<!-- #Auto Generated NFO by catalog.sh -->" > nfo
}

function writeXmbcTag(dbOne,tag,children,nfo,\
fieldId,text,attr,childTag) {
print "<"tag">" > nfo


attr["movie","id"]="moviedb=\"imdb\""

for (fieldId in dbOne) {

text=dbOne[fieldId]

if (text != "") {
if (index(children,fieldId)) {
childTag=gDbFieldId2Tag[fieldId]
if (childTag != "") {
if (childTag == "thumb") {




print "\t<!-- Poster location not exported catalog_poster_location="g_settings["catalog_poster_location"]" -->" > nfo
print "\t<"childTag">"xmlEscape(text)"</"childTag">" > nfo

} else {
if (childTag == "watched" ) text=((text==1)?"true":"false")
print "\t<"childTag" "attr[tag,childTag]">"xmlEscape(text)"</"childTag">" > nfo
}
}
}
}
}
print "</"tag">" > nfo
}

function xmlEscape(text) {
gsub(/[&]/,"\\&amp;",text)
gsub(/</,"\\&lt;",text)
gsub(/>/,"\\&gt;",text)
return text
}


#
function fixTitles(idx,\
t) {

t = gTitle[idx]

if (t == "") {
t = g_media[idx]
sub(/\/$/,"",t)
sub(/.*\//,"",t)
t = remove_format_tags(t)
gsub(/[^A-Za-z0-9]/," ",t)
DEBUG("Setting title to file["t"]")
}

gTitle[idx]=clean_title(t)
}

function file_time(f) {
if (f in gDate) {
return gDate[f]
} else {
return ""
}
}

function createIndexRow(i,db_index,watched,index_time,\
row,est,nfo) {


est=file_time(g_fldr[i]"/unpak.log")
if (est == "") {
est=file_time(g_fldr[i]"/unpak.txt")
}
if (est == "") {
est = g_file_time[i]
}

if (g_file[i] == "" ) {
g_file[i]=getPath(g_media[i],g_fldr[i])
}




while (gsub("/\\./","/",g_file[i]) ) 
continue; 





gsub("//+","/",g_file[i])



if ((g_file[i] in g_fldrCount ) && g_fldrCount[g_file[i]]) {
DEBUG("Adjusting file for video_ts")
g_file[i] = g_file[i] "/"
}


if (db_index == -1 ) {
row="\t"ID"\t"(++gMaxDatabaseId)
} else {
row="\t"ID"\t"db_index
}

row=row"\t"CATEGORY"\t"g_category[i]

if (index_time == "") {
if (gMovieFileCount - 4 > 0) {



index_time = est
} else {
index_time = NOW
}
}

row=row"\t"INDEXTIME"\t"index_time

row=row"\t"WATCHED"\t"watched



row=row"\t"TITLE"\t"gTitle[i]
if (gOriginalTitle[i] != "" && gOriginalTitle[i] != gTitle[i] ) {
row=row"\t"ORIG_TITLE"\t"gOriginalTitle[i]
}
if (g_season[i] != "") row=row"\t"SEASON"\t"g_season[i]
if (g_episode[i] != "") row=row"\t"EPISODE"\t"g_episode[i]

row=row"\t"GENRE"\t"g_genre[i]
row=row"\t"RATING"\t"g_rating[i]


row=row"\t"YEAR"\t"g_year[i]
row=row"\t"FILE"\t"g_file[i]

if (gAdditionalInfo[i]) row=row"\t"ADDITIONAL_INF"\t"gAdditionalInfo[i]

if (gParts[i]) row=row"\t"PARTS"\t"gParts[i]

if (g_imdb[i]) row=row"\t"URL"\t"g_imdb[i]

row=row"\t"CERT"\t"gCertCountry[i]":"gCertRating[i]
if (g_director[i]) row=row"\t"DIRECTOR"\t"g_director[i]

row=row"\t"FILETIME"\t"g_file_time[i]
row=row"\t"DOWNLOADTIME"\t"est




if (gAirDate[i]) row=row"\t"AIRDATE"\t"gAirDate[i]


if (gEpTitle[i]) row=row"\t"EPTITLE"\t"gEpTitle[i]
nfo=""
DEBUG2("NFO:"gNfoDefault[i])

if (g_settings["catalog_nfo_write"] != "never" || is_file(gNfoDefault[i]) ) {
nfo=gNfoDefault[i]
gsub(/.*\//,"",nfo)
}
if (is_file(g_fldr[i]"/"nfo)) {
row=row"\t"NFO"\t"nfo
}
row=row"\t"PLOT"\t"plot_tag(i)
row=row"\t"EPPLOT"\t"epplot_tag(i)
return row
}

function epplot_tag(idx) {

if (g_category[idx] ==  "T" ) {
return "_@"extractImdbId(g_imdb[idx])"@"g_season[idx]"@"g_episode[idx]"@_"
} else {
return ""
}
}

function plot_tag(idx) {
return "_@"extractImdbId(g_imdb[idx])"@"g_season[idx]"@@_"
}





function add_new_scanned_files_to_database(indexToMergeHash,output_file,\
i,row,fields,f,inf) {

report_status("New Records: " hash_size(indexToMergeHash))

gMaxDatabaseId++

for(i in indexToMergeHash) {

f=g_media[i]

DEBUG("Adding to db:"i"["gTitle[i]"]["g_media[i]"]")
if (g_media[i] == "") continue

row=createIndexRow(i,-1,0,"")

print row"\t" >> output_file

update_plots(g_plot_file,i)

generate_nfo_file(g_settings["catalog_nfo_format"],row)

if(DBG-2 >= 0) {
split(row,fields,"\t")
for(f=1; (f in fields) ; f++) {
if (f%2) {
if(fields[f] != "" ) {
DEBUG2(inf"=["fields[f]"]")
}
} else {
inf=g_db_field_name[fields[f]]; 
}
}
}
}
close(output_file)
}

function update_plots(pfile,idx,\
id,cmd) {
id=extractImdbId(g_imdb[idx])
if (id != "") {
INF("updating plots for "id)

cmd=g_plot_app" update "quoteArg(pfile)" "quoteArg(id)" "quoteArg(g_season[idx])

if (g_plot[idx] != "" ) {
cmd = cmd" \"\" "quoteArg(g_plot[idx])
INF("updating main plot :"cmd)
exec(cmd)
}

if (g_category[idx] == "T" && g_epplot[idx] != "" ) {
cmd = cmd" "quoteArg(g_episode[idx])" "quoteArg(g_epplot[idx])
INF("updating episode plot :"cmd)
exec(cmd)
}
}
}

function touch_and_move(x,y) {
system("touch "quoteArg(x)" ; mv "quoteArg(x)" "quoteArg(y))
}





function NEW_CAPTURE_FILE(label,\
CAPTURE_FILE,suffix) {
suffix= "." CAPTURE_COUNT "__" label
CAPTURE_FILE = CAPTURE_PREFIX JOBID suffix
CAPTURE_COUNT++

return CAPTURE_FILE
}

function clean_capture_files() {
INF("Clean up")
exec("rm -f -- \""CAPTURE_PREFIX JOBID "\".* ")
}
function INF(x) {
timestamp("[INFO]",x)
}
function WARNING(x) {
timestamp("[WARNING]",x)
}
function ERR(x) {
timestamp("[ERR]",x)
}
function DETAIL(x) {
timestamp("[DETAIL]",x)
}


function trimAll(str) {
sub(/([^a-zA-Z0-9()]|[ ])+$/,"",str)
sub(/^([^a-zA-Z0-9()]|[ ])+/,"",str)
return str
}

function trim(str) {
gsub(/^ +/,"",str)
gsub(/ +$/,"",str)
return str
}

function apply(text) {
gsub(/[^A-Fa-f0-9]/,"",text)
return text
}


function get_folders_from_args(folder_arr,\
i,folderCount,moveDown) {
folderCount=0
moveDown=0
for(i = 1 ; i - ARGC < 0 ; i++ ) {
INF("Arg:["ARGV[i]"]")
if (ARGV[i] == "IGNORE_NFO" ) {
g_settings["catalog_nfo_read"] = "no"
moveDown++

} else if (ARGV[i] == "WRITE_NFO" ) {

g_settings["catalog_nfo_write"] = "if_none_exists"
moveDown++

} else if (ARGV[i] == "NOWRITE_NFO" ) {

g_settings["catalog_nfo_write"] = "never"
moveDown++

} else if (ARGV[i] == "REBUILD" ) {
REBUILD=1
moveDown++
} else if (ARGV[i] ~ "^DEBUG[0-9]$" ) {
DBG=substr(ARGV[i],length(ARGV[i])) + 0
print("DBG = "DBG)
DBG=1
print("DBG = "DBG)
moveDown++
} else if (ARGV[i] == "STDOUT" ) {
STDOUT=1
moveDown++
} else if (ARGV[i] == "DRYRUN" ) {
RENAME_TV=1
RENAME_FILM=1
g_opt_dry_run=1
moveDown++
} else if (ARGV[i] == "RENAME" ) {
RENAME_TV=1
RENAME_FILM=1
moveDown++
} else if (ARGV[i] == "RENAME_TV" ) {
RENAME_TV=1
moveDown++
} else if (ARGV[i] == "RENAME_FILM" ) {
RENAME_FILM=1
moveDown++
} else if (ARGV[i] == "GET_POSTERS" )  {
GET_POSTERS=1
moveDown++
} else if (ARGV[i] == "UPDATE_POSTERS" )  {
UPDATE_POSTERS=1
GET_POSTERS=1
moveDown++
} else if (ARGV[i] == "GET_FANART" )  {
GET_FANART=1
moveDown++
} else if (ARGV[i] == "UPDATE_FANART" )  {
UPDATE_FANART=1
GET_FANART=1
moveDown++
} else if (ARGV[i] == "NEWSCAN" )  {
NEWSCAN=1
moveDown++
} else if (ARGV[i] == "RESCAN" )  {
RESCAN=1
moveDown++
} else if (ARGV[i] == "PARALLEL_SCAN" )  {
PARALLEL_SCAN=1
moveDown++
} else if (match(ARGV[i],"^[a-zA-Z_]+=")) {

} else {

INF("Scan Path:["ARGV[i]"]")
folder_arr[++folderCount] = ARGV[i]
moveDown++
}
}
ARGC -= moveDown

ARGV[ARGC++] = "/dev/null"
return folderCount
}


function load_catalog_settings() {

load_settings(DEFAULTS_FILE)
load_settings(CONF_FILE)

gsub(/,/,"|",g_settings["catalog_format_tags"])
gsub(/,/,"|",g_settings["catalog_ignore_paths"])
gsub(/,/,"|",g_settings["catalog_ignore_names"])

g_settings["catalog_ignore_paths"]="^"glob2re(g_settings["catalog_ignore_paths"])
g_settings["catalog_ignore_names"]="^"glob2re(g_settings["catalog_ignore_names"])"$"




split(tolower(g_settings["catalog_search_engines"]),g_link_search_engines,g_cvs_sep)

g_web_search_count=0
}

function lang_test(idx) {
scrape_es(idx)
scrape_fr(idx)
scrape_it(idx)
}

function scrape_es(idx,details,\
url) {
delete details
url=first_result(url_encode("intitle:"gTitle[idx]" ("g_year[idx]")")"+"g_director[idx]"+"url_encode("inurl:http://www.filmaffinity.com/en"))
if (sub("/en/","/es/",url)) {
HTML_LOG(0,"es "url)
}
}
function scrape_fr(idx,details,\
url) {
delete details
url=first_result(url_encode("intitle:"gTitle[idx]" ("g_year[idx]")")"+"g_director[idx]"+"\
url_encode("inurl:http://www.screenrush.co.uk")"+"\
url_encode("inurlfichefilm_gen_cfilm"))
if (sub("/screenrush.co.uk/","/allocine.fr/",url)) {
HTML_LOG(0,"fr "url)
}
}
function scrape_it(idx,details,\
url) {
delete details
url=first_result(gTitle[idx]" "g_director[idx]" "url_encode("intitle:Scheda")"+"\
url_encode("site:filmup.leonardo.it"))
HTML_LOG(0,"it "url)
}




' JOBID=$JOBID PID=$$ NOW=`date +%Y%m%d%H%M%S` \
DAY=`date +%a.%P` \
"LS=$LS" \
"APPDIR=$APPDIR" \
"CONF_FILE=$CONF_FILE" \
"DEFAULTS_FILE=$DEFAULTS_FILE" \
tmp_dir="$tmp_dir" \
"INDEX_DB=$INDEX_DB" "$@"

rm -f "$APPDIR/catalog.lck" "$APPDIR/catalog.status"
}

tidy() {
rm -f "$APPDIR/catalog.status"
clean_old_tmp
}

trap tidy 1 2 3 6

main() {

clean_old_tmp
set +e
echo '[INF] catalog version '$VERSION' $Id$'
sed 's/^/\[INF\] os version /' /proc/version
if is_nmt ; then
sed -rn '/./ s/^/\[INF\] nmt version /p' /???/*/VERSION
fi
catalog DEBUG$DEBUG "$@" 
x=$?
set -e

rm -fr -- "$tmp_dir"
chown -R $OVERSIGHT_ID $INDEX_DB* "$APPDIR/tmp" || true
return $x
}




clean_old_tmp() {
find "$tmp_root" -mtime +2 | while IFS= read f ; do
rm -fr -- "$f"
done
}


clean_logs() {
find "$APPDIR/logs" -name \*.log -mtime +2 | while IFS= read f ; do
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
#!#- awk script is compressed using the following: (this file is called util/squeeze)
#!#- sed -r '
#!#- 
#!#- #collapse all leading space [ ] is [<space><tab>]
#!#- s/^[ 	]+//
#!#- 
#!#- #collapse indented comments
#!#- /^ +#/ {s/.*//}
#!#- 
#!#- #remove trailing comments after ; or {
#!#- s/[;{] #.*//
#!#- 
#!#- #collapse comment lines - except shebangs
#!#- /^#[^!]/ {s/.*//}
#!#- 
#!#- #collapse blank lines - keep them for line number reporting
#!#- /^$/ {s/.*//}
#!#- 
#!#- #remove trailing semi-colon  except for bash case ;;
#!#- /; *$/ {s/([^;]);$/\1/}
#!#- 
#!#- ' catalog.sh.full > catalog.sh
