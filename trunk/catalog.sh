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







#







#










#



#



#

#











#


#


#


#

#



#



#

set -u  #Abort with unset variables
set -e  #Abort with any error can be suppressed locally using EITHER cmd||true OR set -e;cmd;set +e
VERSION=20100228-1BETA

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
AWK="/usr/bin/awk"





if [ -d "$APPDIR/bin" ] ; then

export PATH="$APPDIR/bin:$PATH"

if grep -q "MIPS 74K" /proc/cpuinfo ; then
export PATH="$APPDIR/bin/nmt200:$PATH"
else
export PATH="$APPDIR/bin/nmt100:$PATH"
fi
fi



set +e

PERMS() {
chown -R $OVERSIGHT_ID "$@" || true
}

tmp_root=/tmp/oversight
if is_nmt ; then

tmp_root="$APPDIR/tmp"
fi



if [ -z "${JOBID:-}" ] ; then
JOBID=$$
fi

tmp_dir="$tmp_root/$JOBID"
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

COUNTRY_FILE="$APPDIR/conf/country.txt"
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
. "$DEFAULTS_FILE"
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






set +e
/bin/busybox 2>/dev/null 
ls -l /bin/busybox 
set -e


$AWK '




#!catalog
function pad_episode(e) {
if (match(e,"^[0-9][0-9]")) {
return e
} else {
return "0"e
}
}

function timestamp(label,x) {

if (index(x,g_tk) ) gsub(g_tk,".",x)
if (index(x,g_tk2) ) gsub(g_tk2,".",x)

if (index(x,"d=") ) {
sub("password.?=([^,]+)","password=***",x)
sub("pwd=([^,]+)","pwd=xxx",x)
sub("passwd=([^,]+)","passwd=***",x)
}

if (systime() != g_last_ts) {
g_last_ts=systime()
g_last_ts_str=strftime("%H:%M:%S : ",g_last_ts)
}
print label" '$LOG_TAG' "g_last_ts_str g_indent x
}

function TODO(x) {
DEBUG("TODO:"x)
}



function load_settings(prefix,file_name,\
i,n,v,option) {

INF("load "file_name)
FS="\n"
while((getline option < file_name ) > 0 ) {


if ((i=match(option,"[^\\\\]#")) > 0) {
option = substr(option,1,i)
}


sub(/ *= */,"=",option)
option=trim(option)

sub("=["g_quote2"]","=",option)
sub("["g_quote2"]$","",option)
if (match(option,"^[A-Za-z0-9_]+=")) {
n=prefix substr(option,1,RLENGTH-1)
v=substr(option,RLENGTH+1)


if (n in g_settings) {

if (n ~ "movie_search") DEBUG("index check "n"="index(n,"catalog_movie_search"))

if (index(n,"catalog_movie_search") != 0 || n == "catalog_format_tags" ) {

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




function get_local_search_engine(domain,context,param,\
i,links,best_url) {







best_url = domain context param
scanPageForMatches(best_url "test",context,"http://[-_.a-z0-9/]+"context "\\>",0,0,"",links)
bestScores(links,links,0)
for(i in links) {
best_url = i param
break
}
gsub(/\&/,";",best_url)
INF("remapping "domain context param "=>" best_url)
return best_url
}


BEGIN {
g_max_plot_len=3000
g_max_db_len=4000
g_country_prefix="country_"
g_indent=""
g_sigma="Î£"
g_start_time = systime()
g_thetvdb_web="http://www.thetvdb.com"
g_tvrage_web="http://www.tvrage.com"

g_tv_check_urls["TVRAGE"]=g_tvrage_web
g_tv_check_urls["THETVDB"]=g_thetvdb_web

g_batch_size=30
g_tvdb_user_per_episode_api=1
g_cvs_sep=" *, *"
g_opt_dry_run=0
yes="yes"
no="no"
g_quote="'"'"'"
g_quote2="\"'"'"'"

g_8bit="€-ÿ"; // range 0x80 - 0xff

g_alnum8 = "a-zA-Z0-9" g_8bit


g_punc[0]="[^][}{&()" g_quote g_alnum8 "]+"

g_punc[1]="[^&()"g_quote g_alnum8"]+"

g_punc[2]="[^&"g_quote g_alnum8"]+"

g_nonquote_regex = "[^"g_quote2"]"


g_imdb_regex="\\<tt[0-9][0-9][0-9][0-9][0-9]+\\>"

g_year_re="(20[01][0-9]|19[5-9][0-9])"
g_imdb_title_re="[A-Z0-9"g_8bit"]["g_alnum8"& "g_quote "]* \\(?"g_year_re"\\)?"

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
return 0+ result
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

cmd = "mkdir -p "qa(path)" && mount -o soft,nolock,timeo=10 "qa(remote)" "qa(path)

} else if (link ~ "smb:") {

cmd = "mkdir -p "qa(path)" && mount -t cifs -o username="user",password="password" "qa(remote)" "qa(path)

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

cmd = "nbtscan "g_tmp_settings["eth_gateway"]"/24 > "qa(g_winsfile)
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
g_wget_opts="-T 30 -t 2 -w 2 -q --no-check-certificate --ignore-length "
g_art_timeout=" -T 60"


g_mount_root="/opt/sybhttpd/localhost.drives/NETWORK_SHARE/"
g_winsfile = APPDIR"/conf/wins.txt"
g_item_count = 0

g_plot_file="'"$PLOT_DB"'"
g_plot_app=qa(APPDIR"/bin/plot.sh")

for(i in g_settings) {
g_settings_orig[i] = g_settings[i]
}












g_tmp_idx_prefix="tmp_"
g_tmp_idx_count=0

g_db_lock_file=APPDIR"/catalog.lck"
g_scan_lock_file=APPDIR"/catalog.scan.lck"
g_status_file=APPDIR"/catalog.status"
g_abc="abcdefghijklmnopqrstuvwxyz"
g_ABC=toupper(g_abc)
g_tagstartchar=g_ABC g_abc":_"

load_catalog_settings()

split(g_settings["catalog_tv_plugins"],g_tv_plugin_list,g_cvs_sep)

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

gsub(/\<UK\>/,"UK,gb",g_settings["catalog_cert_country_list"])
gsub(/\<USA\>/,"USA,us",g_settings["catalog_cert_country_list"])
gsub(/\<Ireland\>/,"Ireland,ie",g_settings["catalog_cert_country_list"])

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










g_search_yahoo = get_local_search_engine("http://search.yahoo.com","/search","?ei=UTF-8;eo=UTF-8;p=")
g_search_ask = get_local_search_engine("http://ask.com","/web","?q=")
g_search_bing = "http://www.bing.com/search?q="
g_search_bing2 = "http://www.bing.com/search?q=subtitles+"

g_search_google = "http://www.google.com/search?ie=utf-8&oe=utf-8&q="


g_search_engine[0]=g_search_yahoo
g_search_engine[1]=g_search_bing

g_search_engine_count=2
g_search_engine_current=0

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
if (lock(g_scan_lock_file) == 0 ) {
INF("Scan already in progress")
exit
}
}
}

g_timestamp_file=APPDIR"/.lastscan"


replace_share_names(FOLDER_ARR)

make_paths_absolute(FOLDER_ARR)

for(f in FOLDER_ARR) {
INF("Folder "f"="FOLDER_ARR[f])
}

gLS_FILE_POS=0
gLS_TIME_POS=0
findLSFormat()

plugin_check()



if (hash_size(FOLDER_ARR)) {

gMovieFileCount = 0
gMaxDatabaseId = 0

load_settings("","'$UNPAK_CFG'")

g_tk = apply(g_tk)
g_tk2 = apply(g_tk2)
g_grand_total = scan_folder_for_new_media(FOLDER_ARR,scan_options)

delete g_occurs
delete g_updated_plots


clean_capture_files()

et=systime()-ELAPSED_TIME

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
if (g_grand_total) {
if (lock(g_db_lock_file,1)) {

remove_absent_files_from_new_db(INDEX_DB)
system(g_plot_app" compact "qa(g_plot_file)" "qa(INDEX_DB))
unlock(g_db_lock_file)
}
}
}


















function replace_share_names(folders,\
f,share_name) {
if (isnmt()) {


for(f in folders) {
if (folders[f] ~ /^[^\/.]/  ) {

share_name=folders[f]
sub(/\/.*/,"",share_name)

if (!(share_name in g_share_name_to_folder)) {
g_share_name_to_folder[share_name] = nmt_mount_share(share_name,g_tmp_settings)
DEBUG("share name "share_name" = "g_share_name_to_folder[share_name])
}
if (g_share_name_to_folder[share_name]) {

g_share_map[folders[f]] = share_name
folders[f] = nmt_get_share_path(folders[f])

} else if (START_DIR != "/share/Apps/oversight" && is_file_or_folder(START_DIR"/"folders[f])) {
folders[f] = START_DIR"/"folders[f]
} else {
WARNING(folders[f]" not a share or file")
delete folders[f]
}
}
}
}
}

function make_paths_absolute(folders,\
f) {

for(f in folders) {

if (index(folders[f],".") == 1) {
folders[f] = START_DIR"/"folders[f]
}
folders[f] = clean_path(folders[f])
}
}

function plugin_check(\
p,plugin) {
for (p in g_tv_plugin_list) {
plugin = g_tv_plugin_list[p]
if (getUrl(g_tv_check_urls[plugin],"test",0) == "" ) {
WARNING("Removing plugin "plugin)
delete g_tv_plugin_list[p]
}
}
}



function update_db(indexToMergeHash) {

if (hash_size(indexToMergeHash) == 0 ) {
INF("Nothing to merge")

} else if (g_opt_dry_run) {

INF("Database update skipped - dry run")

} else if (lock(g_db_lock_file)) {


printf "" > INDEX_DB_NEW
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
if (is_file(lock_file) == 0) return 0

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

function lock(lock_file,fastfail,\
attempts,sleep,backoff) {
attempts=0
sleep=10
split("10,10,20,30,60,120,300,600,600,600,600,1200",backoff,",")
for(attempts=1 ; (attempts in backoff) ; attempts++) {
if (is_locked(lock_file) == 0) {
print PID > lock_file
close(lock_file)
INF("Locked "lock_file)
set_permissions(qa(lock_file))
return 1
}
if (fastfail != 0) break
sleep=backoff[attempts]
WARNING("Failed to get exclusive lock. Retry in "sleep" seconds.")
system("sleep "sleep)
}
ERR("Failed to get exclusive lock")
return 0
}

function unlock(lock_file) {
INF("Unlocked "lock_file)
system("rm -f -- "qa(lock_file))
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

system("cp -f "qa(currentdb)" "qa(olddb))

touch_and_move(newdb,currentdb)

set_permissions(qa(currentdb)" "qa(olddb))
}

function set_permissions(shellArg) {
if (ENVIRON["USER"] != '$uid' ) {
return system("chown '$OVERSIGHT_ID' "shellArg)
}
return 0
}

function capitalise(text,\
i,rtext,rstart) {
text=" "text
while (match(text,"[^" g_alnum8 g_quote"][a-z]") > 0) {
text=substr(text,1,RSTART) toupper(substr(text,RSTART+1,1)) substr(text,RSTART+2)
}

if (get_regex_pos(text,"\\<[IVX][ivx]+\\>",0,rtext,rstart)) {
for(i in rtext) {
text = substr(text,1,rstart[i]-1) toupper(rtext[i]) substr(text,rstart[i]+length(rtext[i]))
}
}
return substr(text,2)
}

function set_db_fields() {

ID=db_field("_id","ID","",0)

WATCHED=db_field("_w","Watched","watched") 
PARTS=db_field("_pt","PARTS","")
FILE=db_field("_F","FILE","filenameandpath")
NAME=db_field("_N","NAME","")
DIR=db_field("_D","DIR","")
EXT=db_field("_ext","EXT","")


ORIG_TITLE=db_field("_ot","ORIG_TITLE","originaltitle")
TITLE=db_field("_T","Title","title",1) 
DIRECTOR=db_field("_d","Director","director",1) 
CREATOR=db_field("_c","Creator","creator") 
AKA=db_field("_K","AKA","",1)

CATEGORY=db_field("_C","Category","")
ADDITIONAL_INF=db_field("_ai","Additional Info","")
YEAR=db_field("_Y","Year","year",1) 

SEASON=db_field("_s","Season","season") 
EPISODE=db_field("_e","Episode","episode")

GENRE=db_field("_G","Genre","genre",1) 
RUNTIME=db_field("_rt","Runtime","runtime",1) 
RATING=db_field("_r","Rating","rating",1)
CERT=db_field("_R","CERT","mpaa")

PLOT=db_field("_P","Plot","plot",1)


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
TVID=db_field("_tvid","TVID","id")
}





function db_field(key,name,tag,imdbsrc) {
g_db_field_name[key]=name
gDbTag2FieldId[tag]=key
gDbFieldId2Tag[key]=tag
if (imdbsrc) {
g_imdb_sections[key]=name
}
return key
}

function scan_folder_for_new_media(folderArray,scan_options,\
f,fcount,total,done) {

for(f in folderArray ) {

if (folderArray[f] && !(f in done)) {
report_status("folder "++fcount)
total += scan_contents(folderArray[f],scan_options)
done[f]=1
}
}

return 0+total

}


function findLSFormat(\
tempFile,i,procfile) {

DEBUG("Finding LS Format")

procfile="/proc/"PID"/fd"
tempFile=new_capture_file("LS")


exec(LS" -ld "procfile" > "qa(tempFile) )
FS=" "

while ((getline < tempFile) > 0 ) {
for(i=1 ; i - NF <= 0 ; i++ ) {
if ($i == procfile) gLS_FILE_POS=i
if (index($i,":")) gLS_TIME_POS=i
}
break
}
close(tempFile)
INF("ls -l file position at "gLS_FILE_POS)
INF("ls -l time position at "gLS_TIME_POS)

}
function is_hidden_fldr(d,\
ur) {
ur = g_settings["unpak_nmt_pin_root"]
return ur != "" && index(d,ur) == 1
}
function is_bdmv_subfldr(d) {
return tolower(d) ~ "/bdmv/(playlist|clipinf|stream|auxdata|backup|jar|meta|bdjo)\\>"
}
function is_bdmv_fldr(d) {
return tolower(d) ~ "/bdmv$" && dir_contains(d"/STREAM","[Mm]2[Tt][Ss]$")
}
function is_videots_fldr(d) {
return tolower(d) ~ "/video_ts$" && dir_contains(d,"[Vv][Oo][Bb]$")
}
function dir_contains(dir,pattern) {
return exec("ls "qa(dir)" 2>/dev/null | egrep -q "qa(pattern) ) ==0
}


function scan_contents(root,scan_options,\
tempFile,currentFolder,skipFolder,i,folderNameNext,perms,w5,lsMonth,\
lsDate,lsTimeOrYear,f,d,extRe,pos,store,lc,nfo,quotedRoot,scan_line,scan_words,ts,total) {

DEBUG("Scanning "root)
if (root == "") return

if (NEWSCAN) {
get_files(root,INDEX_DB)
}

tempFile=new_capture_file("MOVIEFILES")


if (root != "/" ) {
gsub(/\/+$/,"",root); 
}

quotedRoot=qa(root)

extRe="\\.[^.]+$"







exec("( "LS" "scan_options" "quotedRoot"/ || "LS" "scan_options" "quotedRoot" ) > "qa(tempFile) )
exec("ls -l "qa(tempFile))
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
total += identify_and_catalog_scanned_files()
}


currentFolder = scan_line
sub(/\/*:$/,"",currentFolder)
DEBUG("Folder = "currentFolder)
folderNameNext=0
if ( currentFolder ~ g_settings["catalog_ignore_paths"] ) {

skipFolder=1
INF("Ignore path "currentFolder)

} else if ( is_bdmv_subfldr(currentFolder)) {

INF("Ignore BDMV sub folder "currentFolder)
skipFolder=1

} else if(is_hidden_fldr(currentFolder)) {

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
DEBUG("Ignore name "scan_line)
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

if (is_videots_fldr(currentFolder"/"scan_line) || is_bdmv_fldr(currentFolder"/"scan_line) ) {

if (match(currentFolder,"/[^/]+$")) {
f = substr(currentFolder,RSTART+1)
d = substr(currentFolder,1,RSTART-1)
}

ts=calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW)

storeMovie(gMovieFileCount,f"/",d,ts,"/$",".nfo")
skipFolder=1
}
}

} else {


























if (match(scan_line,"[^/]/")) { 

i = match(scan_line,".*[^/]/")

currentFolder = substr(scan_line,1,RLENGTH-1)
if ( index(currentFolder,"/") != 1 ) {
currentFolder =  root "/" currentFolder
}
currentFolder = clean_path( currentFolder )

scan_line = substr(scan_line,RLENGTH+1)
lc = tolower(scan_line)
INF("Looking at direct file argument ["currentFolder"]["scan_line"]")
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
ts=calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW)
storeMovie(gMovieFileCount,scan_line,currentFolder,ts,"\\.[^.]+$",".nfo")
}
}
}

}

close(tempFile)

total += identify_and_catalog_scanned_files()

DEBUG("Finished Scanning "root)
return 0+total
}



function glob2re(glob) {
gsub(/[.]/,"\\.",glob)
gsub(/[*]/,".*",glob)
gsub(/[?]/,".",glob)
gsub(/[<]/,"\\<",glob)
gsub(/ *, */,"|",glob)
gsub(/[>]/,"\\>",glob)


gsub("^\\|","",glob)
gsub("\\|$","",glob)
gsub("\\|\\|","",glob)

return "("glob")"
}

function csv2re(text) {
gsub(/ *, */,"|",text)
return "("text")"
}

function storeMovie(idx,file,folder,timeStamp,nfoReplace,nfoExt,\
path) {

path=clean_path(folder"/"file)

DEBUG("Storing " path)

g_fldrMediaCount[folder]++

g_fldr[idx]=folder
g_media[idx] = file



#



if (! (NEWSCAN == 1  &&  in_db(path))) {
gMovieFilePresent[path] = idx
}

g_file_time[idx] = timeStamp

setNfo(gMovieFileCount,nfoReplace,nfoExt)

gMovieFileCount++
}





function checkMultiPart(name,count,\
lastNameSeen,i) {

lastNameSeen = g_media[count-1]


if (length(lastNameSeen) != length(name)) {

return 0
}
if (lastNameSeen == name) return 0

for(i=1 ; i - length(lastNameSeen) <= 0 ; i++ ) {
if (substr(lastNameSeen,i,1) != substr(name,i,1)) {
break
}
}

if (substr(lastNameSeen,i+1) != substr(name,i+1)) {

return 0
}

if (substr(lastNameSeen,i-1,2) ~ "[^0-9]1" || substr(lastNameSeen,i-2,3) ~ "[^EeXx0-9][0-9]1" ) {




if (!(substr(name,i,1) ~ "[2-9]")) {
return 0
}

} else if (substr(lastNameSeen,i,1) ~ "[Aa]") {
if (!(substr(name,i,1) ~ "[A-Fa-f]")) {
return 0
}

} else {
return 0
}

INF("Found multi part file - linked with "lastNameSeen)
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
return 1
} else {
return 0
}
}

function exec(cmd,\
err) {


if ((err=system(cmd)) != 0) {
ERR("Return code "err" executing "cmd) 
}
return 0+ err
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




function web_search_first_imdb_link(qualifier) {
return web_search_first(qualifier,1,"imdbid","/tt",g_imdb_regex)
}
function web_search_first_imdb_title(qualifier,\
) {
return web_search_first(qualifier,0,"imdbtitle","",g_imdb_title_re)
}






function scrapeMatches(url,freqOrFirst,helptxt,regex,matches,src,\
match1,submatch) {

delete submatch
if (freqOrFirst == 1) {

match1=scanPageFirstMatch(url,helptxt,regex,1)
if (match1) {
submatch[match1] = 1
}
} else {

scanPageMostFreqMatch(url,helptxt,regex,1,"",submatch)
}


for(match1 in submatch) {
matches[match1] ++; 
if (index(src[match1],":" url ":") == 0) {
src[match1]=src[match1] ":" url ":"
}
}
}









function normalise_title_matches(matches,normed,\
t,t2) {

delete normed
for(t in matches) {
t2=t
gsub("[^"g_alnum8"]"," ",t2)
gsub(/  +/," ",t2)
t2 = capitalise(trim(t2))


if (t2 !~ "(©|GMT|PDT|"g_months_short") "g_year_re"$" ) {
normed[t2] += matches[t]
}
}


for(t in normed) {
for(t2 in normed) {
if (t != t2 && index(t2,t)) {
normed[t] += normed[t2]
}
}
}
dump(0,"normalise title matches out",normed)
}



#

function web_search_first(qualifier,freqOrFirst,mode,helptxt,regex,\
u,s,pages,subtotal,ret,i,matches,m,src) {


set_cache_prefix("@")
id1("web_search_first "mode" ["qualifier"]")
u[1] = search_url("SEARCH" qualifier)
u[2] = search_url("SEARCH" qualifier)
u[3] = g_search_google qualifier





for(i = 1 ; i-2 <= 0 ; i++ ) {
sub("\\<"g_year_re"\\>","+%2B+&",u[i])
}


for(i = 1 ; i-2 <= 0 ; i++ ) {
scrapeMatches(u[i],freqOrFirst,helptxt,regex,matches,src)
}
i = bestScores(matches,matches,0)
if (i == 2 ) {

ret = firstIndex(matches)

} else if ( i == 1 ) {



#
scrapeMatches(u[3],freqOrFirst,helptxt,regex,matches,src)
if (bestScores(matches,matches,0) == 2 ) {

ret = firstIndex(matches)

} else {




for(m in matches) {
id1("cross_page_rank "m"|")
pages=0
subtotal=0
for(i = 1 ; i-3 <= 0 ; i++ ) {
if (index(src[m],":"u[i]":") == 0) {
s = scanPageForMatches(u[i],m,title_to_re(m),0,1,"")
if (s != 0) pages++
subtotal += s
}
}
matches[m] += pages * subtotal
id0(pages*subtotal)
}
ret = getMax(matches,4,1)
}
}

clear_cache_prefix("@")
id0(ret)
return ret
}


function web_search_frequent_imdb_link(idx,\
url,txt,linksRequired) {

id1("web_search_frequent_imdb_link")
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

id0(url)
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

id1("direct search...")
bestUrl = searchArrayForIMDB2(k,linkThreshold)

if (bestUrl == "") {

for(keywords in k) {
if (sub(/ *[sS][0-9][0-9][eE][0-9][0-9].*/,"",keywords)) {
keywordsSansEpisode[keywords]=1
}
}
bestUrl = searchArrayForIMDB2(keywordsSansEpisode,linkThreshold)
}
id0(bestUrl)

return bestUrl
}

function searchArrayForIMDB2(k,linkThreshold,\
bestUrl,keywords) {

for(keywords in k) {
bestUrl = searchForIMDB(keywords,linkThreshold)
if (bestUrl != "") {
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


gsub("[^" g_alnum8"]+","+",f)





if (match(f,"\\<"g_year_re"\\>")) {
f = substr(f,1,RSTART+RLENGTH-1)
}

if (match(f,"\\<[sS][0-9][0-9][eE][0-9][0-9]")) {
f = substr(f,1,RSTART+RLENGTH-1)
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
f,line,imdbContentPosition,isection) {

if (url == "" ) return


url=extractImdbLink(url)

if (url == "" ) return

id1("scrape imdb ["url"]")

if (g_imdb[idx] == "") {
g_imdb[idx] = extractImdbId(url)
}

f=getUrl(url,"imdb_main",1)
hash_copy(isection,g_imdb_sections)

if (f != "" ) {

imdbContentPosition="header"

DEBUG("START IMDB: title:"gTitle[idx]" poster "g_poster[idx]" genre "g_genre[idx]" cert "gCertRating[idx]" year "g_year[idx])

FS="\n"
while(imdbContentPosition != "footer" && enc_getline(f,line) > 0  ) {
imdbContentPosition=scrapeIMDBLine(line[1],imdbContentPosition,idx,f,isection)
}
enc_close(f)

if (hash_size(isection) > 0 ) {
ERR("Missing imdb sections ")
dump(0,"missing",isection)
}


if (gCertCountry[idx] != "" && g_settings[g_country_prefix gCertCountry[idx]] != "") {
gCertCountry[idx] = g_settings[g_country_prefix gCertCountry[idx]]
}

}






id0("category = "g_category[idx] )
}





function parseDbRow(row,arr,\
fields,i,fnum) {
fnum = split(row,fields,"\t")
for(i = 2 ; i-fnum <= 0 ; i+=2 ) {
arr[fields[i]] = fields[i+1]
}
if (index(arr[FILE],"/") != 1 ) {
arr[FILE] = g_mount_root arr[FILE]
}
arr[FILE] = clean_path(arr[FILE])
}

function clean_path(f) {
if (index(f,"../")) {
while (gsub(/\/[^\/]+\/\.\.\//,"/",f) ) {
continue
}
}
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

dbline2 = createIndexRow(idx,dbfields[ID],dbfields[WATCHED],"")
if (length(dbline2) - g_max_db_len < 0) {
print dbline2"\t" >> new_db_file
updated_count++
update_plots(g_plot_file,idx)
}
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

function short_path(path) {
if (index(path,g_mount_root) == 1) {
path = substr(path,length(g_mount_root)+1)
}
return path
}

function in_db(path,verbose,\
) {
path = short_path(path)
if (index(path,g_occurs_prefix) != 1) {
ERR("Cannot check ["path"] occurs agains current prefix ["g_occurs_prefix"]")
exit
}
if (path in g_occurs) {
if (verbose) INF("["path"] already scanned")
return 1
} else {
INF("["path"] not in db")
return 0
}
}

function add_file(path) {
if (NEWSCAN == 1) g_occurs[short_path(path)]++
}



function get_files(prefix,db,\
dbline,dbfields,err,count,filter) {

id1("get_files ["prefix"]")
delete g_occurs
g_occurs_prefix = short_path(prefix)

filter = "\t" FILE "\t" g_occurs_prefix
INF("get_files filter = "filter)

while((err = (getline dbline < db )) > 0) {

if ( index(dbline,filter) ) {

parseDbRow(dbline,dbfields)

add_file(dbfields[FILE])





count++
}
}
if (err == 0 ) close(db)

id0(count" files")
}

function remove_brackets(s) {


while (gsub(/\[[^][]*\]/,"",s) || gsub(/\{[^}{]*\}/,"",s)) continue


while (gsub(/\([^()]*[^0-9 ][^()]*\)/,"",s)) continue

return s
}






function remove_absent_files_from_new_db(db,\
tmp_db,dbfields,\
list,f,shortf,maxCommandLength,dbline,keep,\
gp,blacklist_re,blacklist_dir,timer,in_scanned_list) {
list=""
maxCommandLength=3999

INF("Pruning...")
tmp_db = db "." JOBID ".tmp"

get_files("",db)

if (lock(g_db_lock_file)) {
g_kept_file_count=0
g_absent_file_count=0

close(db)
while((getline dbline < db ) > 0) {

if ( index(dbline,"\t") != 1 ) { continue; }

parseDbRow(dbline,dbfields)

f = dbfields[FILE]
shortf = short_path(f)


keep=1

in_scanned_list = (shortf in g_occurs)

if (in_scanned_list == 1 && NEWSCAN == 1 && g_occurs[shortf] == 0 ) {






keep = 0
WARNING("Skipping "f" - duplicate")


} else if (blacklist_re != "" && f ~ "NETWORK_SHARE/("blacklist_re")" ) {

WARNING("Skipping "f" - blacklisted device")
} else {

timer = systime()
if (is_file_or_folder(f) == 0 ) {
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
if (in_scanned_list == 1 && NEWSCAN == 1 && g_occurs[shortf] - 1 > 0) {



g_occurs[shortf] = 0
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




function qa(f) {
gsub(g_quote,g_quote "\\"g_quote g_quote,f)
return g_quote f g_quote
}




function title_to_re(s,\
i,words,count,s2,ch) {


sub(g_year_re"$","\\(?&\\)?",s); 




count = chop(s,"\\<[a-zA-z]",words)
s2=""
for(i = 1 ; i - length(s) <= 0 ; i++ ) {
ch = substr(s,i,1)
if (tolower(ch) != toupper(ch) ) {
s2 = s2 "[" tolower(ch) toupper(ch) "]"
} else {
s2 = s2 ch
}
}


sub(/ /,"[. ]",s2); 

return "\\<"s2"\\>"
}







function calcTimestamp(lsMonth,lsDate,lsTimeOrYear,_default,\
val,y,m,d,h,min,checkFuture) {

if (lsMonth == "" ) {
return _default
} else {
m=gMonthConvert[lsMonth]
d=lsDate
if (index(lsTimeOrYear,":")) {

y=THIS_YEAR
h=substr(lsTimeOrYear,1,2)
min=substr(lsTimeOrYear,4,2)
checkFuture=1
} else {

y=lsTimeOrYear
h=7
min=0
checkFuture=0
}
val = sprintf("%04d%02d%02d%02d%02d00",y,m,d,h,min); 
if (checkFuture && (val - NOW) > 0 ) {
y--
val = sprintf("%04d%02d%02d%02d%02d00",y,m,d,h,min); 
}
return val; 
}
}







#
function checkTvFilenameFormat(plugin,idx,more_info,\
details,line,dirs,d,dirCount,ePos,dirLevels,ret) {

delete more_info


id1("checkTvFilenameFormat "plugin)

line = remove_format_tags(g_media[idx])
DEBUG("CHECK TV ["line"] vs ["g_media[idx]"]")

dirCount = split(g_fldr[idx],dirs,"/")
dirLevels=2




more_info[1]=1

for(d=0 ; d-dirLevels <= 0  ; d++ ) {

if (extractEpisodeByPatterns(plugin,line,details)==1) {
ret = 1
break
}
if (episodeExtract(tolower(line),0,"\\<","","[/ .]?(ep?[^a-z0-9]?|episode)[^a-z0-9]*[0-9][0-9]?",details)) {
dump(0,"details",details)
ret = 1
break
}
if (d == dirLevels) {
INF("No tv series-episode format in ["line"]")
break
}
line=dirs[dirCount-d]"/"line
more_info[1]=0
}






















if (ret == 1) {

if (details[TITLE] == "" ) {


searchByEpisodeName(plugin,details)
}
adjustTitle(idx,details[TITLE],"filename")


g_season[idx]=details[SEASON]
g_episode[idx]=details[EPISODE]

INF("Found tv info in file name:"line" title:["gTitle[idx]"] ["g_season[idx]"] x ["g_episode[idx]"]")














g_tvid[idx] = details[TVID]
g_tvid_plugin[idx] = plugin
g_category[idx] = "T"
gAdditionalInfo[idx] = details[ADDITIONAL_INF]


}
id0(ret)
return ret
}

function searchByEpisodeName(plugin,details,\
terms,results,id,url,parts) {


id1("searchByEpisodeName "plugin)
dump(0,"searchByEpisodeName",details)
if (plugin == "THETVDB") {
terms="\"season "details[SEASON]"\" \""details[EPISODE]" : "clean_title(details[ADDITIONAL_INF])"\" site:thetvdb.com"

results = scanPageFirstMatch(g_search_bing terms,"seriesid","seriesid=[0-9]+",0)

if (split(results,parts,"=") == 2) {
id = parts[2]
}
} else if (plugin == "TVRAGE") {
terms="\"season "details[SEASON]"\" "details[SEASON]"x"sprintf("%02d",details[EPISODE])" \""clean_title(details[ADDITIONAL_INF])"\" site:tvrage.com"
url = scanPageFirstMatch(g_search_google terms,"tvrage","http"g_nonquote_regex"+.tvrage"g_nonquote_regex"+",0)
if (url != "") {
results = scanPageForMatches(url,"show/","show/[0-9]+",0)
results=getMax(results,1,1)
if (split(results,parts,"/") == 2) {
id = parts[2]
}
}
} 
id0(id)
details[TVID]=id
return id
}

function extractEpisodeByPatterns(plugin,line,details,\
ret,p,pat,i,parts,sreg,ereg) {




line = tolower(line)



ret=0

sreg="([0-5][0-9]|[0-9])"

ereg="[0-9][0-9]?"



p=0

pat[++p]="0@@s"sreg"@[/ .]?[e/][0-9]+[-e0-9]+@"

pat[++p]="0@\\<@(series|season|saison|s)[^a-z0-9]*"sreg"@[/ .]?(e|ep.?|episode|/)[^a-z0-9]*"ereg"@"


pat[++p]="0@\\<@(series|season|saison|seizoen|s)[^a-z0-9]*"sreg"@[/ .]?(disc|dvd|d)[^a-z0-9]*"ereg"@DVD"


pat[++p]="0@@s?"sreg"@[-/ .]?[e/][0-9]+[a-e]?@"


pat[++p]="1@[^a-z0-9]@"sreg"@[/ .]?x"ereg"@"




pat[++p]="DATE"

pat[++p]="1@[^-0-9]@([1-9]|2[1-9]|1[0-8]|[03-9][0-9])@/?[0-9][0-9]@"

for(i = 1 ; ret+0 == 0 && p-i >= 0 ; i++ ) {
if (pat[i] == "DATE" ) {
ret = extractEpisodeByDates(plugin,line,details)
} else {
split(pat[i],parts,"@")

ret = episodeExtract(line,parts[1]+0,parts[2],parts[3],parts[4],details)
if (ret+0) {
details[EPISODE] = parts[5] details[EPISODE]
}
}
}

if (ret+0 != 0) {
id1("extractEpisodeByPatterns: line["line"]")
dump(0,"details",details)
id0(ret)
}


return 0+ret
}

function formatDate(line,\
date,nonDate) {
if (extractDate(line,date,nonDate) == 0) {
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


y4=g_year_re
m2="(0[1-9]|1[012])"
m1=d1="[1-9]"
d2="([012][0-9]|3[01])"
s="[-_. /]0*"
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
date[2] = 0 + date[2]
date[3] += 0
DEBUG("Found ["date[1]"/"date[2]"/"date[3]"] in "line)
return 1
}

function extractEpisodeByDates(plugin,line,details,\
date,nonDate,title,rest,y,m,d,tvdbid,result,closeTitles,tmpIdx) {

result=0

if (extractDate(line,date,nonDate)) {
rest=nonDate[2]

details[TITLE]= title = clean_title(nonDate[1])

y = date[1]
m = date[2]
d = date[3]


possible_tv_titles(plugin,title,closeTitles)

DEBUG("Checking the following series for "title" "y"/"m"/"d)
dump(0,"date check",closeTitles)

for (tvdbid in closeTitles) {

id1("Checking "tvdbid)



#










tmpIdx = g_tmp_idx_prefix (++g_tmp_idx_count)
if (get_tv_series_info(plugin,tmpIdx,get_tv_series_api_url(plugin,tvdbid)) > 0) {

if (plugin == "THETVDB" ) {


result = extractEpisodeByDates_TvDb(tmpIdx,tvdbid,y,m,d,details)

} else if (plugin == "TVRAGE" ) {

result = extractEpisodeByDates_rage(tmpIdx,tvdbid,y,m,d,details)

} else {
plugin_error(plugin)
}
if (result) {
INF(":) Found episode of "closeTitles[tvdbid]" on "y"-"m"-"d)
details[TVID]=tvdbid
id0(result)
break
}
}
id0(result)
}
if (result == 0) {
INF(":( Couldnt find episode "y"/"m"/"d" - using file information")
details[SEASON]=y
details[EPISODE]=sprintf("%02d%02d",m,d)
sub(/\....$/,"",rest)
details[ADDITIONAL_INF]=clean_title(rest)
}
}

return 0+ result
}




function extractEpisodeByDates_TvDb(idx,tvdbid,y,m,d,details,\
episodeInfo,url) {


url=g_thetvdb_web"/api/GetEpisodeByAirDate.php?apikey="g_tk"&seriesid="tvdbid"&airdate="y"-"m"-"d,"ep-by-date-"
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


equate_urls(url,g_thetvdb_web"/api/"g_tk"/series/"tvdbid"/default/"details[SEASON]"/"details[EPISODE]"/en.xml")



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
details[SEASON] = episodeInfo["/Show/Episodelist/Season#no"] 
details[EPISODE] = episodeInfo["/Show/Episodelist/Season/episode/seasonnum"] 



details[ADDITIONAL_INF]=episodeInfo["/Show/Episodelist/Season/episode/title"]
result=1
}
return 0+ result
}

function remove_season(t) {
sub(/(S|Series *|Season *)[0-9]+.*/,"",t)
return clean_title(t)
}

function episodeExtract(line,prefixReLen,prefixRe,seasonRe,episodeRe,details,\
rtext,rstart,count,i,ret) {



count = 0+get_regex_pos(line,prefixRe seasonRe episodeRe "\\>",0,rtext,rstart)



for(i = 1 ; i+0 <= count ; i++ ) {
if ((ret = extractEpisodeByPatternSingle(line,prefixReLen,seasonRe,episodeRe,rstart[i],rtext[i],details)) != 0) {
INF("episodeExtract:["prefixRe "] [" seasonRe "] [" episodeRe"]")
break
}
}

return 0+ret
}



function extractEpisodeByPatternSingle(line,prefixReLen,seasonRe,episodeRe,reg_pos,reg_match,details,\
tmpTitle,ret,reg_len,ep,season,title,inf) {

ret = 0
id1("extractEpisodeByPatternSingle:"reg_match)

delete details

if (reg_match ~ "([XxHh.]?264|1080)$" ) {

DEBUG("ignoring ["reg_match"]")

} else {


reg_pos += prefixReLen
reg_len = length(reg_match)-prefixReLen

DEBUG("ExtractEpisode:0 Title= ["line"]")
title = substr(line,1,reg_pos-1)
DEBUG("ExtractEpisode:1 Title= ["title"]")

inf=substr(line,reg_pos+reg_len)

if (match(inf,gExtRegExAll) ) {
details[EXT]=inf
gsub(/\.[^.]*$/,"",inf)
details[EXT]=substr(details[EXT],length(inf)+2)
}

inf=clean_title(inf,2)

line=substr(reg_match,prefixReLen+1)

if (match(title,": *")) {
title = substr(title,RSTART+RLENGTH)
}
DEBUG("ExtractEpisode:2 Title= ["title"]")

if (match(title,"^[a-z][a-z0-9]+[-]")) {
tmpTitle=substr(title,RSTART+RLENGTH)
if (tmpTitle != "" ) {
INF("Removed group was ["title"] now ["tmpTitle"]")
title=tmpTitle
}
}

DEBUG("ExtractEpisode: Title= ["title"]")
title = clean_title(title,2)

DEBUG("ExtractEpisode: Title= ["title"]")





match(line,episodeRe "$" )
ep = substr(line,RSTART,RLENGTH); 
if (seasonRe == "") {
season = 1
} else {
season = substr(line,1,RSTART-1)
}


gsub(/[-.eExX]+/,",",ep)
DEBUG("Episode : "ep)
gsub(/\<0+/,"",ep)
gsub(/,,+/,",",ep)
sub(/^,+/,"",ep)

details[EPISODE] = ep
details[SEASON] = n(season)
details[TITLE] = title
details[ADDITIONAL_INF]=inf
ret=1
}


if (ret != 1 ) delete details
id0(ret)
return ret
}



function identify_and_catalog_scanned_files(\
idx,file,fldr,bestUrl,scanNfo,thisTime,numFiles,eta,\
ready_to_merge,ready_to_merge_count,scanned,tv_status,p,plugin,total,more_info,search_abbreviations,\
tvid,tvDbSeriesPage) {

numFiles=hash_size(g_media)

INF("Processing "numFiles" items")

eta=""

for ( idx = 0 ; idx - numFiles < 0 ; idx++ ) {




bestUrl=""

scanNfo=0

file=g_media[idx]
fldr=g_fldr[idx]

if (file == "" ) continue

if (NEWSCAN==1 && in_db(fldr"/"file)) {
continue
}

DIV0("Start item "(g_item_count)": ["file"]")

report_status("item "(++g_item_count))

DEBUG("folder :["fldr"]")

if (isDvdDir(file) == 0 && !match(file,gExtRegExAll)) {
WARNING("Skipping unknown file ["file"]")
continue
}

thisTime = systime()


if (g_settings["catalog_nfo_read"] != "no") {

if (is_file(gNfoDefault[idx])) {

DEBUG("Using default info to find url")
scanNfo = 1

} else if (g_fldrMediaCount[fldr] == 1 && g_fldrInfoCount[fldr] == 1 && is_file(g_fldrInfoName[fldr])) {

DEBUG("Using single nfo "g_fldrInfoName[fldr])

gNfoDefault[idx] = g_fldrInfoName[fldr]
scanNfo = 1
}
}

if (scanNfo){
bestUrl = scanNfoForImdbLink(gNfoDefault[idx])
}





scanned = 0
tv_status = 0

for (p in g_tv_plugin_list) {
plugin = g_tv_plugin_list[p]



DIV("checkTvFilenameFormat "plugin)
g_tvid_plugin[idx] = g_tvid[idx]=""

if (checkTvFilenameFormat(plugin,idx,more_info)) {
search_abbreviations = more_info[1]

if (UPDATE_TV)  {

if (bestUrl == "" && g_imdb[idx] != "" ) {
bestUrl = extractImdbLink(g_imdb[idx])
}
tv_status = tv_search(plugin,idx,bestUrl,search_abbreviations)
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
g_tvid_plugin[idx] = g_tvid[idx]=""





if (movie_search(idx,bestUrl) == 2) {

if (UPDATE_TV) {
INF("Going back to TV search")
for (p in g_tv_plugin_list) {
plugin = g_tv_plugin_list[p]
tvid = find_tvid(plugin,idx,extractImdbId(g_imdb[idx]))
if(tvid != "") {
tvDbSeriesPage = get_tv_series_api_url(plugin,tvid)
if (get_tv_series_info(plugin,idx,tvDbSeriesPage) != 0) {
break
}
}
}
}
}

scanned=1
}

if (scanned) {


if (g_poster[idx] == "") {
g_poster[idx] = g_imdb_img[idx]
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



if (g_opt_dry_run) {
print "dryrun: "g_file[idx]" -> "gTitle[idx]
}

ready_to_merge[idx]=1
ready_to_merge_count++

} else {
INF("Skipping item "g_media[idx])
}

thisTime = systime()-thisTime 
g_process_time += thisTime
g_elapsed_time = systime() - g_start_time
g_total ++


DEBUG(sprintf("processed in "thisTime"s net av:%.1f gross av:%.1f" ,(g_process_time/g_total),(g_elapsed_time/g_total)))

}


if (ready_to_merge_count) {
DIV("merge")
update_db(ready_to_merge)
}

clean_globals()
return 0+total
}

function DIV0(x) {
INF("\n\t===\n\t"x"\n\t===\n")
}
function DIV(x) {
INF("\t===\t"x"\t===")
}


function tv_search(plugin,idx,imdbUrl,search_abbreviations,\
tvDbSeriesPage,result,tvid) {

result=0

id1("tv_search ("plugin","idx","imdbUrl","search_abbreviations")")



tvDbSeriesPage = get_tv_series_api_url(plugin,g_tvid[idx])

if (tvDbSeriesPage == "" && imdbUrl == "" ) { 

tvDbSeriesPage = search_tv_series_names(plugin,idx,gTitle[idx],search_abbreviations)
}

if (tvDbSeriesPage != "" ) { 

result = get_tv_series_info(plugin,idx,tvDbSeriesPage)
if (result) {
if (g_imdb[idx] != "") {

scrapeIMDBTitlePage(idx,g_imdb[idx])
} else {

scrapeIMDBTitlePage(idx,tv2imdb(idx))
}
}
} else {

if (imdbUrl == "") {



imdbUrl=web_search_frequent_imdb_link(idx)
}
if (imdbUrl != "") {

scrapeIMDBTitlePage(idx,imdbUrl)
if (g_category[idx] != "M" ) {

tvid = find_tvid(plugin,idx,extractImdbId(imdbUrl))
tvDbSeriesPage = get_tv_series_api_url(plugin,tvid)
result = get_tv_series_info(plugin,idx,tvDbSeriesPage)
}
}
}

if (g_category[idx] == "M" ) {
WARNING("Error getting IMDB ID from tv - looks like a movie??")
if (plugin == "TVRAGE") {
WARNING("Please update the IMDB ID for this series at the TVRAGE website for improved scanning")
}

result = 0
}
id0(result)
return 0+ result
}


function movie_search(idx,bestUrl,\
name,i,\
n,name_seen,name_list,name_id,name_try,\
search_regex_key,search_order_key,search_order,s,search_order_size,ret,title,\
imdb_title_q,imdb_id_q) {

id1("movie search")



name_id=0


if (gParts[idx] != "") {
name_list[++name_id]=remove_part_suffix(idx)
}

name=cleanSuffix(idx)



if (match(name,"\\(?"g_year_re"\\)?")) {
name_list[++name_id] = substr(name,1,RSTART+RLENGTH-1)
}

name_list[++name_id] = name

name_list[++name_id] = remove_format_tags(remove_brackets(basename(g_media[idx])))


dump(0,"name_tries",name_list)



for(i = 1 ; i < 5 ; i++ ) {
search_regex_key="catalog_movie_search_regex"i


if (name ~ g_settings[search_regex_key]) {

search_order_key="catalog_movie_search_order"i
if (!(search_order_key in g_settings)) {
ERR("Missing setting "search_order_key)
} else {
search_order_size = split(g_settings[search_order_key],search_order," *, *")
break
}
}
delete search_order
}

dump(0,"search order",search_order)

for( s = 1 ; bestUrl=="" && s-search_order_size <= 0 ; s++ ) {

if (search_order[s] == "IMDBLINKS") {


id1("Search Phase: "search_order[s])
bestUrl=web_search_frequent_imdb_link(idx)
id0(bestUrl)

} else {

delete name_seen
for(n = 1 ; bestUrl=="" && n-name_id <= 0 ; n++) {

name_try = name_list[n]

if (!(name_try in name_seen)) {

name_seen[name_try]=n

id1("Search Phase: "search_order[s]"["name_try"]")

if (search_order[s] == "ONLINE_NFO") {





bestUrl = searchOnlineNfoImdbLinks(name_try".")

} else if (search_order[s] == "IMDB") {



bestUrl=web_search_first_imdb_link(name_try"+"url_encode("site:imdb.com"))

} else if (search_order[s] == "IMDBFIRST") {

if (name_try ~ "^[a-zA-Z0-9]+-[a-zA-Z0-9]+$" ) {

name_try = "\""name_try"\""
} else {

gsub("[^()"g_alnum8" ]+"," ",name_try)
name_try = trim(name_try)
}


imdb_title_q=url_encode("imdb")
imdb_id_q = url_encode("imdb")



bestUrl=web_search_first_imdb_link(name_try"+"imdb_id_q)
if (bestUrl == "" ) {


title = web_search_first_imdb_title(name_try)
if (title != "" && title != name_try) {
bestUrl=web_search_first_imdb_link(title"+"imdb_title_q)
if (bestUrl == "") {
bestUrl=web_search_first_imdb_link(title"+"imdb_id_q)
}
}
}

} else {
ERR("Unknown search method "search_order[s])
}

id0(bestUrl)
}
}
}
}


ret=0
if (bestUrl != "") {

scrapeIMDBTitlePage(idx,bestUrl)

if (g_category[idx] == "T" ) {
WARNING("Unidentifed TV show ???")
ret=2
} else {
ret=1
getNiceMoviePosters(idx,extractImdbId(bestUrl))
}

} 
id0(bestUrl)
return ret
}

function tv2imdb(idx,\
url,key) {

if (g_imdb[idx] == "") {

key=gTitle[idx]"+"g_year[idx]
DEBUG("tv2imdb key=["key"]")
if (!(key in g_tv2imdb)) {

url=gTitle[idx]" "g_year[idx]" +site:imdb.com \"TV Series\" \"User Rating\" Moviemeter Seasons "

g_tv2imdb[key] = web_search_first_imdb_link(url); 
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
delete g_runtime
delete gProdCode
delete gTitle
delete gOriginalTitle
delete gAdditionalInfo
delete g_tvid_plugin
delete g_tvid
delete g_imdb_img
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
delete g_title_rank
delete g_title_source

gMovieFileCount = 0
INF("Reset scanned files store")
}

function cleanSuffix(idx,\
name) {
name=g_media[idx]
if(name !~ "/$") {

sub(/\.[^.\/]+$/,"",name)








}
name=trimAll(name)
return name
}





function searchOnlineNfoImdbLinks(name,\
url) {
url=searchOnlineNfoImdbLinksFilter(name,"",150)
if (url == "") {
url=searchOnlineNfoImdbLinksFilter(name,"+nfo","")
}
return url
}

function searchOnlineNfoImdbLinksFilter(name,additionalKeywords,minSize,\
choice,i,url) {
g_nfo_search_choices =1

for(i = 0 ; i - g_nfo_search_choices < 0 ; i++ ) {

g_nfo_search_engine_sequence++
choice = g_nfo_search_engine_sequence % g_nfo_search_choices 



if (choice == 0 ) {






#



url = searchOnlineNfoLinksForImdb(name,\
"https://www.binsearch.info",\
"/index.php?q=\"QUERY\""additionalKeywords"&minsize="minSize"&max=20&adv_age=999&adv_sort=date&adv_nfo=on&postdate=on&hideposter=on&hidegroup=on",\
"/viewNFO[^\"]+",20,"","")



#





}
if (url != "") {
break
}
}
return url
}






function searchOnlineNfoLinksForImdb(name,domain,queryPath,nfoPathRegex,maxNfosToScan,inurlFind,inurlReplace,
nfo,nfo2,nfoPaths,imdbIds,totalImdbIds,wgetWorksWithMultipleUrlRedirects,id,count,result) {


if (length(name) <= 4 || name !~ "^[-.a-zA-Z0-9]+$" ) {
INF("onlinenfo: ["name"] ignored")
} else {

id1("Online nfo search for ["name"]")

sub(/QUERY/,name,queryPath)
INF("query["queryPath"]")


scanPageForMatches(domain queryPath,"",nfoPathRegex,maxNfosToScan,1,"",nfoPaths)




wgetWorksWithMultipleUrlRedirects=0
















for(nfo in nfoPaths) {
nfo2 = domain nfo
if (inurlFind != "") {
sub(inurlFind,inurlReplace,nfo2)
}
sub(/[&]amp;/,"\\&",nfo2)

if (scanPageForMatches(nfo2,"tt", g_imdb_regex ,0,1,"", imdbIds) == 0) {
scanPageForIMDBviaLinksInNfo(nfo2,imdbIds)
}

for(id in imdbIds) {
totalImdbIds[id] += imdbIds[id]
}
}


if (hash_size(totalImdbIds) > 3 ) {
INF("Too many nfo results from online search")
} else {


bestScores(totalImdbIds,totalImdbIds,0)
count = hash_size(totalImdbIds)
if (count == 1) {

result = extractImdbLink(firstIndex(totalImdbIds))

} else if (count == 0) {

INF("No matches")

} else {

INF("To many equal matches. Discarding results")
}
}
id0(result)
}
return result
}



function scanPageForIMDBviaLinksInNfo(url,imdbIds,\
amzurl,amazon_urls,imdb_per_page,imdb_id) {
if (scanPageForMatches(url, "amazon","http://(www.|)amazon[ !#-;=?-~]+",0,1,"",amazon_urls)) {
for(amzurl in amazon_urls) {
if (scanPageForMatches(amzurl, "/tt", g_imdb_regex ,0,1,"", imdb_per_page)) {
for(imdb_id in imdb_per_page) {
INF("Found "imdb_id" via amazon link")
imdbIds[imdb_id] += imdb_per_page[imdb_id]
}
}
}
}
}


function firstIndex(inHash,\
i) {
for (i in inHash) return i
}

function firstDatum(inHash,\
i) {
for (i in inHash) return inHash[i]
}



function bestScores(inHash,outHash,textMode,\
i,bestScore,count,tmp,isHigher) {


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
INF("bestScore = "bestScore)
return bestScore
}


function scanNfoForImdbLink(nfoFile,\
foundId,line) {

foundId=""
INF("scanNfoForImdbLink ["nfoFile"]")

if (system("test -f "qa(nfoFile)) == 0) {
FS="\n"
while(foundId=="" && (getline line < nfoFile) > 0 ) {

foundId = extractImdbLink(line,1)

}
close(nfoFile)
}
INF("scanNfoForImdbLink = ["foundId"]")
return foundId
}



function search_tv_series_names(plugin,idx,title,search_abbreviations,\
tnum,t,i,url) {

tnum = alternate_titles(title,t)

for(i = 0 ; i-tnum < 0 ; i++ ) {
url = search_tv_series_names2(plugin,idx,t[i],search_abbreviations)
if (url != "") break
} 
return url
}

function search_tv_series_names2(plugin,idx,title,search_abbreviations,\
tvDbSeriesPage,alternateTitles,title_key,cache_key,showIds,tvdbid) {

title_key = plugin"/"g_fldr[idx]"/"title
id1("search_tv_series_names "title_key)

if (title_key in g_tvDbIndex) {
DEBUG(plugin" use previous mapping "title_key" -> ["g_tvDbIndex[title_key]"]")
tvDbSeriesPage =  g_tvDbIndex[title_key]; 
} else {

tvDbSeriesPage = searchTvDbTitles(plugin,idx,title)

DEBUG("search_tv_series_names: bytitles="tvDbSeriesPage)
if (tvDbSeriesPage) {



} else if ( search_abbreviations ) {



cache_key=g_fldr[idx]"@"title

if(cache_key in g_abbrev_cache) {

tvDbSeriesPage = g_abbrev_cache[cache_key]
INF("Fetched abbreviation "cache_key" = "tvDbSeriesPage)

} else {

searchAbbreviationAgainstTitles(title,alternateTitles)

filterTitlesByTvDbPresence(plugin,alternateTitles,showIds)
if (hash_size(showIds)+0 > 1) {

filterUsenetTitles(showIds,cleanSuffix(idx),showIds)
}

tvdbid = selectBestOfBestTitle(plugin,idx,showIds)

tvDbSeriesPage=get_tv_series_api_url(plugin,tvdbid)

if (tvDbSeriesPage) {
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
}
id0(tvDbSeriesPage)

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
function hash_add(a1,a2,\
i) {
for(i in a2) a1[i] += a2[i]
}
function hash_size(h,\
s,i){
s = 0 ; 
for(i in h) s++
return 0+ s
}

function id1(x) {
g_idstack[g_idtos++] = x
INF(">Begin " x)
g_indent="\t"g_indent
}

function id0(x) {
g_indent=substr(g_indent,2)

INF("<End "g_idstack[--g_idtos]"=[" ( (x!="") ? "=["x"]" : "") "]")
}

function possible_tv_titles(plugin,title,closeTitles,\
ret) {

if (plugin == "THETVDB" ) {

ret = searchTv(plugin,title,"FirstAired,Overview",closeTitles)

} else if (plugin == "TVRAGE" ) {

ret = searchTv(plugin,title,"started,origin_country",closeTitles)

} else {

plugin_error(plugin)

} 
g_indent=substr(g_indent,2)
dump(0,"searchTv out",closeTitles)
return ret

}





#



function filterUsenetTitles(titles,filterText,filteredTitles,\
result) {
result = filterUsenetTitles1(titles,"http://binsearch.info/?max=25&adv_age=&q=\""filterText"\" QUERY",filteredTitles)



return 0+ result
}





function filterUsenetTitles1(titles,usenet_query_url,filteredTitles,\
t,count,tmpTitles,origTitles,dummy,found,query,baseline,link_count) {

found = 0
dump(2,"pre-usenet",titles)


hash_copy(origTitles,titles)


dummy=rand()systime()rand()
query = usenet_query_url
sub(/QUERY/,dummy,query)
baseline = scanPageForMatches(query,"</","</[Aa]>",0,1,"",tmpTitles)

DEBUG("number of links for no match "baseline)

for(t in titles) {

query = usenet_query_url
sub(/QUERY/,norm_title(clean_title(titles[t])),query)
link_count = scanPageForMatches(query,"</","</[Aa]>",0,1,"",tmpTitles)
DEBUG("number of links "link_count)
if (link_count-baseline > 0) {
count[t] = link_count
found=1
}
if (link_count == 0 ) {
scanPageForMatches(query,"</","</[Aa]>",0,1,"",tmpTitles,1)
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
return 0+ found
}













function getRelativeAge(plugin,idx,titleHash,ageHash,\
id,xml) {
for(id in titleHash) {
if (get_episode_xml(plugin,get_tv_series_api_url(plugin,id),g_season[idx],g_episode[idx],xml)) {
if (plugin == "THETVDB") {
ageHash[id] = xml["/Data/Episode/FirstAired"]
} else if (plugin == "TVRAGE" ) {
ageHash[id] = xml["/Show/Episodelist/Season/episode/airdate"]
} else {
plugin_error(plugin)
}
}
}
dump(1,"Age indicators",ageHash)
}















function selectBestOfBestTitle(plugin,idx,titles,\
bestId,bestFirstAired,ages,count) {
dump(0,"closely matched titles",titles)
count=hash_size(titles)

if (count == 0) {
bestId = ""
} else if (count == 1) {
bestId = firstIndex(titles)
} else {
TODO("Refine selection rules here.")

INF("Getting the most recent first aired for s"g_season[idx]"e"g_episode[idx])
bestFirstAired=""

getRelativeAge(plugin,idx,titles,ages)

bestScores(ages,ages,1)

bestId = firstIndex(ages)

}
INF("Selected:"bestId" = "titles[bestId])
return bestId
}









function filterTitlesByTvDbPresence(plugin,titleInHash,showIdHash,\
bestScore,potentialTitle,potentialMatches,origTitles,score) {
bestScore=-1

dump(0,"pre tvdb check",titleInHash)


hash_copy(origTitles,titleInHash)

delete showIdHash

for(potentialTitle in origTitles) {
id1("Checking potential title "potentialTitle)
score = possible_tv_titles(plugin,potentialTitle,potentialMatches)
if (score - bestScore >= 0 ) {
if (score - bestScore > 0 ) delete showIdHash
hash_merge(showIdHash,potentialMatches)
bestScore = score
}
id0(score)
}


dump(0,"post filterTitle",showIdHash)
}

function remove_country(t) {
if (match(tolower(t)," (au|uk|us)( |$)")) {
t=substr(t,1,RSTART-1) substr(t,RSTART+RLENGTH)
}
return t
}


function alternate_titles(title,t,\
tnum,tried,tmp) {

tnum = 0
tmp = clean_title(title,1)
tried[tmp]=1
t[tnum++] = tmp

tmp = clean_title(remove_brackets(title),1)
if (!(tmp in tried)) {
tried[tmp]=1
t[tnum++] = tmp
}

tmp = clean_title(remove_country(title),1)
if (!(tmp in tried)) {
tried[tmp]=1
t[tnum++] = tmp
}

tmp = clean_title(remove_country(remove_brackets(title)),1)
if (!(tmp in tried)) {
tried[tmp]=1
t[tnum++] = tmp
}

dump(0,"alternate_titles",t)

return tnum+0

}








function searchTv(plugin,title,requiredTagList,closeTitles,\
requiredTagNames,allTitles,url,ret) {

id1("searchTv Checking ["plugin"/"title"]" )
split(requiredTagList,requiredTagNames,",")
delete closeTitles

if (plugin == "THETVDB") {

url=expand_url(g_thetvdb_web"//api/GetSeries.php?seriesname=",title)
filter_search_results(url,title,"/Data/Series","SeriesName","seriesid",requiredTagList,allTitles)

} else if (plugin == "TVRAGE") {

url=g_tvrage_web"/feeds/search.php?show="title
filter_search_results(url,title,"/Results/show","name","showid",requiredTagList,allTitles)

} else {
plugin_error(plugin)
}

ret = filterSimilarTitles(title,allTitles,closeTitles)
id0(ret)
return 0+ret
}



function expand_url(baseurl,title,\
url) {
url = baseurl title
if (match(title," [Aa]nd ")) {

url=url"\t"url
sub(/ [Aa]nd /," %26 ",url); 

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
while(enc_getline(f,line) > 0 ) {



if (index(line[1],seriesStart) > 0) {
clean_xml_path(seriesPath,info)
}

parseXML(line[1],info)

if (index(line[1],seriesEnd) > 0) {



currentName = clean_title(info[seriesPath"/"nameTag])

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
enc_close(f)
}
dump(0,"search["title"]",allTitles)

INF("Search results : Found "count" removed "filter_count)
}

function dump(lvl,label,array,\
i,c) {
if (DBG-lvl >= 0)   {
for(i in array) {
DEBUG("  "label":"i"=["array[i]"]")
c++
}
if (c == 0 ) {
DEBUG("  "label":<empty>")
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

url = g_thetvdb_web"/index.php?imdb_id="imdbid"&order=translation&searching=Search&tab=advancedsearch"
id2 = scanPageFirstMatch(url,"",regex,0)
if (id2 != "" ) {
id2=substr(id2,5)
}
}

if (id2 == "" ) {


extractDate(g_premier[idx],date,nondate)


#


year_range="("(g_year[idx]-1)"|"g_year[idx]"|"(g_year[idx]+1)")"

if(plugin == "THETVDB") {



filter["/Data/Series/SeriesName"] = "~:^"gTitle[idx]"(| \\([a-z0-9]\\))$"
filter["/Data/Series/FirstAired"] = "~:^"year_range"-"

url=expand_url(g_thetvdb_web"//api/GetSeries.php?seriesname=",gTitle[idx])
if (fetch_xml_single_child(url,"imdb2tvdb","/Data/Series",filter,showInfo)) {
INF("Looking at tvdb "showInfo["/Data/Series/SeriesName"])
id2 = showInfo["/Data/Series/seriesid"]
}


#

#





} else if(plugin == "TVRAGE") {



filter["/Results/show/name"] = "~:^"gTitle[idx]"(| \\(a-z0-9]\\))$"
filter["/Results/show/started"] = "~:"year_range

if (fetch_xml_single_child(g_tvrage_web"/feeds/search.php?show="gTitle[idx],"imdb2rage","/Results/show",filter,showInfo)) {
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
tvdbid,tvDbSeriesUrl,imdb_id,closeTitles,noyr) {

id1("searchTvDbTitles")
if (g_imdb[idx]) {
imdb_id = g_imdb[idx]
tvdbid = find_tvid(plugin,idx,imdb_id)
}
if (tvdbid == "") {
possible_tv_titles(plugin,title,closeTitles)
tvdbid = selectBestOfBestTitle(plugin,idx,closeTitles)
}
if (tvdbid == "") {
noyr  = remove_tv_year(title)
if(title != noyr) {
INF("Try Again Without A Year If Nothing Found Thus Far")




#



possible_tv_titles(plugin,noyr,closeTitles)
tvdbid = selectBestOfBestTitle(plugin,idx,closeTitles)
}
}
if (tvdbid != "") {
tvDbSeriesUrl=get_tv_series_api_url(plugin,tvdbid)
}

id0(tvDbSeriesUrl)
return tvDbSeriesUrl
}

function get_tv_series_api_url(plugin,tvdbid) {
if (tvdbid != "") {
if (plugin == "THETVDB") {
if (g_tvdb_user_per_episode_api) {
return g_thetvdb_web"/api/"g_tk"/series/"tvdbid"/en.xml"
} else {
return g_thetvdb_web"/api/"g_tk"/series/"tvdbid"/all/en.xml"
}
} else if (plugin == "TVRAGE") {
return "http://services.tvrage.com/feeds/full_show_info.php?sid="tvdbid
}
}
return ""
}



function fetchXML(url,label,xml,ignorePaths,\
f,line,result) {
result = 0
f=getUrl(url,label,1)
if (f != "" ) {
FS="\n"
while((getline line < f) > 0 ) {
parseXML(line,xml,ignorePaths)
}
close(f)
result = 1
}
return 0+ result
}




function parseXML(line,info,ignorePaths,\
sep,\
currentTag,i,j,tag,text,lines,parts,sp,slash,tag_data_count,\
attr,a_name,a_val,eq,attr_pairs) {

if (index(line,"<?")) return

if (sep == "") sep = "<"

if (ignorePaths != "") {
gsub(/,/,"|",ignorePaths)
ignorePaths = "^("ignorePaths")\\>"
}

if (index(line,g_sigma) ) { 
INF("Sigma:"line)
gsub(g_sigma,"e",line)
INF("Sigma:"line)
}











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



currentTag = substr(currentTag,1,length(currentTag)-length(tag))

} else if (slash == 0 ) {

currentTag = currentTag "/" tag



if (currentTag in info) {
text = sep text
}

} else {


}

if (text) {
if (ignorePaths == "" || currentTag !~ ignorePaths) {
info[currentTag] = info[currentTag] text
}
}



if (slash == 0 && index(parts[1],"=")) {
get_regex_counts(parts[1],"[:A-Za-z_][-_A-Za-z0-9.]+=((\"[^\"]*\")|([^\"][^ "g_quote2">=]*))",0,attr_pairs)
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


function norm_title(t) {
sub(/^[Tt]he /,"",t)
sub(/ [Tt]he$/,"",t)
gsub(/[&]/,"and",t)
gsub(g_quote,"",t)
return tolower(t)
}





function similarTitles(titleIn,possible_title,\
cPos,yearOrCountry,matchLevel,diff,shortName) {

matchLevel = 0
yearOrCountry=""








if (sub(/ [Oo] /," O",possible_title)) {
possible_title=clean_title(possible_title)
}
if (sub(/ [Oo] /," O",titleIn)) {
titleIn=clean_title(titleIn)
}

if (match(possible_title," \\([^)]+")) {
yearOrCountry=tolower(clean_title(substr(possible_title,RSTART+2,RLENGTH-2),1))
DEBUG("Qualifier ["yearOrCountry"]")
}



sub(/\<2[0-9][0-9][0-9]$/,"(&)",titleIn)

if ((cPos=index(possible_title,",")) > 0) {
shortName=clean_title(substr(possible_title,1,cPos-1),1)
}

possible_title=clean_title(possible_title)

possible_title=norm_title(possible_title)
titleIn=norm_title(titleIn)




if (yearOrCountry != "") {
DEBUG("Qualified title ["possible_title"]")
}





if (index(possible_title,titleIn) == 1) {






if (possible_title == titleIn) {

matchLevel=5




if (yearOrCountry != "") {
matchLevel=10
}

} else  if (titleIn == shortName) {

matchLevel=5



} else if ( possible_title == titleIn " (" yearOrCountry ")" ) {
INF("match for ["titleIn"+"yearOrCountry"] against ["possible_title"]")



matchLevel = 5

} else if ( index(possible_title,titleIn" Show")) {


matchLevel = 4

} else {
DEBUG("No match for ["titleIn"+"yearOrCountry"] against ["possible_title"]")
}
} else if (index(titleIn,possible_title) == 1) {







diff=substr(titleIn,length(possible_title)+1)
if ( diff ~ " "g_year_re"$" || diff ~ " (uk|us|au|nz|de|fr)" ) {

matchLevel = 5
INF("match for ["titleIn"] containing ["possible_title"]")
}
} else if ( index(possible_title,"Late Night With "titleIn)) {


matchLevel = 4

} else if ( index(possible_title,"Show With "titleIn)) {



matchLevel = 4

}
return 0+ matchLevel
}







function filterSimilarTitles(title,titleHashIn,titleHashOut,\
i,score,bestScore,tmpTitles) {

id1("Find similar "title)

hash_copy(tmpTitles,titleHashIn)


for(i in titleHashIn) {
score[i] = similarTitles(title,titleHashIn[i])
DEBUG("["title"] vs ["i":"titleHashIn[i]"] = "score[i])
}


bestScores(score,titleHashOut,0)


for(i in titleHashOut) {
titleHashOut[clean_title(i)] = tmpTitles[i]
}

dump(0,"matches",titleHashOut)
bestScore = score[firstIndex(titleHashOut)]
if (bestScore == "" ) bestScore = -1

INF("Filtered titles with score = "bestScore)
dump(0,"filtered = ["title"]=",titleHashOut)

if (bestScore == 0 ) {
DEBUG("all zero score - discard them all to trigger another match method")
delete titleHashOut
}

id0(bestScore)

return 0+ bestScore
}


function getEpguideNames(letter,names,\
url,title,link,links,i,count2) {
url = "http://epguides.com/menu"letter

scanPageForMatches(url,"<li>","<li>(|<b>)<a.*</li>",0,1,"",links)
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
return 0+ count2
}






function searchAbbreviation(letter,titleIn,alternateTitles,\
possible_title,names,i,ltitle) {

ltitle = tolower(titleIn)

id1("Checking "titleIn" for abbeviations on menu page - "letter)

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
id0()
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
return 0+ found
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


if (contractionPrerequisite(abbrev,possible_title) == 0) {
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


return 0+ found
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




function clean_title(t,deep) {


gsub(/[&]amp;/,"\\&",t)




while (match(t,"\\<[A-Za-z]\\>\.\\<[A-Za-z]\\>")) {
t = substr(t,1,RSTART) "@@" substr(t,RSTART+2)
}

gsub(/@@/,"",t)

gsub(g_punc[deep+0]," ",t)

gsub(/ +/," ",t)
t=trim(capitalise(tolower(t)))

return t
}

function remove_tags(line) {

gsub(/<[^>]+>/," ",line)

if (index(line,"  ")) {
gsub(/ +/," ",line)
}

if (index(line,"amp")) {
gsub(/\&amp;/," \\& ",line)
}

gsub(/[&][a-z]+;?/,"",line)

line=de_emphasise(line)

return line
}

function de_emphasise(html) {
if (index(html,"<b") || index(html,"</b") ||\
index(html,"<em") || index(html,"</em") ||\
index(html,"<strong") || index(html,"</strong") ) {
gsub(/<\/?(b|em|strong)>/,"",html)
}
if (index(html,"wbr")) {

gsub(/ *<\/?wbr>/,"",html)
}
if (index("/>",html)) {

gsub(/<[a-z]+ ?\/>/,"",html)
}
return html
}




function getMax(arr,requiredThreshold,requireDifferenceSquared,\
maxName,best,nextBest,nextBestName,diff,i,threshold,msg) {
nextBest=0
maxName=""
best=0
dump(0,"getMax",arr)
for(i in arr) {
if (arr[i]-best >= 0 ) {
nextBest = best
nextBestName = maxName
best = threshold = arr[i]
maxName = i

} else if (arr[i]-nextBest >= 0 ) {

nextBest = arr[i]
nextBestName = i
}
}
DEBUG("Best "best"*"arr[i]". Required="requiredThreshold)

if (0+best < 0+requiredThreshold ) {
DEBUG("Rejected as "best" does not meet requiredThreshold of "requiredThreshold)
maxName = ""

} else if (requireDifferenceSquared ) {

diff=best-nextBest
DEBUG("Next best count = "nextBest" diff^2 = "(diff*diff))
if (diff * diff - best  < 0 ) {

DEBUG("But rejected as "best" too close to next best "nextBest" to be certain")
maxName = ""

}
}
DEBUG("getMax: best index = ["maxName"]")
return maxName
}



function searchForIMDB(keywords,linkThreshold,\
i1,result,matchList,bestUrl) {
id1("Search ["keywords"]")
if (!(keywords in g_imdb_link_search)) {




keywords = keywords"+%2Bimdb+%2Btitle+-inurl%3Aimdb"


scanPageForMatches(g_search_yahoo keywords,"tt",g_imdb_regex,0,0,"",matchList)


bestUrl=getMax(matchList,linkThreshold,1)
if (bestUrl != "") {
i1 = extractImdbLink(bestUrl)
}
g_imdb_link_search[keywords] = i1

}
result = g_imdb_link_search[keywords]

id0(result)
return result
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

id1("get_episode_xml")

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
id0(result)
return 0+ result
}


function get_tv_series_info(plugin,idx,tvDbSeriesUrl,\
result) {

id1("get_tv_series_info("plugin","idx"," tvDbSeriesUrl")")

if (plugin == "THETVDB") {
result = get_tv_series_info_tvdb(idx,tvDbSeriesUrl)
} else if (plugin == "TVRAGE") {
result = get_tv_series_info_rage(idx,tvDbSeriesUrl)
} else {
plugin_error(plugin)
}

if (g_episode[idx] ~ "^DVD[0-9]+$" ) {
result++
}


DEBUG("Title:["gTitle[idx]"] "g_season[idx]"x"g_episode[idx]" date:"gAirDate[idx])
DEBUG("Episode:["gEpTitle[idx]"]")

id0(result"="(result==2?"Full Episode Info":(result?"Series Only":"Not Found")))
return 0+ result
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
sub(" *\\("g_year_re"\\)","",t)
return t
}

function remove_tv_year(t) {
if(length(t) > 4) {
sub(" *"g_year_re,"",t)
}
return t
}
function set_plot(idx,plotv,txt) {
plotv[idx] = substr(txt,1,g_max_plot_len)
}




function get_tv_series_info_tvdb(idx,tvDbSeriesUrl,\
seriesInfo,episodeInfo,bannerApiUrl,result,empty_filter) {


result=0


fetch_xml_single_child(tvDbSeriesUrl,"thetvdb-series","/Data/Series",empty_filter,seriesInfo)
if ("/Data/Series/id" in seriesInfo) {

dump(0,"tvdb series",seriesInfo)

setFirst(g_imdb,idx,extractImdbId(seriesInfo["/Data/Series/IMDB_ID"]))

adjustTitle(idx,remove_year(seriesInfo["/Data/Series/SeriesName"]),"thetvdb")

g_year[idx] = substr(seriesInfo["/Data/Series/FirstAired"],1,4)
setFirst(g_premier,idx,formatDate(seriesInfo["/Data/Series/FirstAired"]))
set_plot(idx,g_plot,seriesInfo["/Data/Series/Overview"])




gCertRating[idx] = seriesInfo["/Data/Series/ContentRating"]




setFirst(g_poster,idx,tvDbImageUrl(seriesInfo["/Data/Series/poster"]))
g_tvid_plugin[idx]="THETVDB"
g_tvid[idx]=seriesInfo["/Data/Series/id"]
result ++


bannerApiUrl = tvDbSeriesUrl
sub(/(all.|)en.xml$/,"banners.xml",bannerApiUrl)

getTvDbSeasonBanner(idx,bannerApiUrl,"en")



if (g_episode[idx] ~ "^[0-9,]+$" ) {

if (get_episode_xml("THETVDB",tvDbSeriesUrl,g_season[idx],g_episode[idx],episodeInfo)) {

if ("/Data/Episode/id" in episodeInfo) {
setFirst(gAirDate,idx,formatDate(episodeInfo["/Data/Episode/FirstAired"]))

set_eptitle(idx,episodeInfo["/Data/Episode/EpisodeName"])

if (g_epplot[idx] == "") {
set_plot(idx,g_epplot,episodeInfo["/Data/Episode/Overview"])
}

if (gEpTitle[idx] != "" ) {
if ( gEpTitle[idx] ~ /^Episode [0-9]+$/ && g_plot[idx] == "" ) {
INF("Due to Episode title of ["gEpTitle[idx]"] Demoting result to force another TV plugin search")
} else {
result ++
}
}
}
}
}
} else {
WARNING("Failed to find ID in XML")
}


if (g_imdb[idx] == "" ) {
WARNING("get_tv_series_info returns blank imdb url. Consider updating the imdb field for this series at "g_thetvdb_web)
} else {
DEBUG("get_tv_series_info returns imdb url ["g_imdb[idx]"]")
}
return 0+ result
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
seriesInfo,episodeInfo,filter,url,e,result,pi,p,ignore,flag) {

pi="TVRAGE"
result = 0
delete filter

ignore="/Show/Episodelist"
if (fetch_xml_single_child(tvDbSeriesUrl,"tvinfo-show","/Show",filter,seriesInfo,ignore)) {
dump(0,"tvrage series",seriesInfo)
adjustTitle(idx,remove_year(seriesInfo["/Show/name"]),pi)
g_year[idx] = substr(seriesInfo["/Show/started"],8,4)
setFirst(g_premier,idx,formatDate(seriesInfo["/Show/started"]))


url=urladd(seriesInfo["/Show/showlink"],"remove_add=1&bremove_add=1")
set_plot(idx,g_plot,scrape_one_item("tvrage_plot",url,"id=.iconn1",0,"iconn2|<center>|^<br>$",0,1))

g_tvid_plugin[idx]="TVRAGE"
g_tvid[idx]=seriesInfo["/Show/showid"]
result ++


if(g_imdb[idx] == "") {
url = scanPageFirstMatch(url,"/links/",g_nonquote_regex"+/links/",1)
if (url != "" ) {
url = scanPageFirstMatch(g_tvrage_web url,"epguides", "http"g_nonquote_regex "+.epguides." g_nonquote_regex"+",1)
if (url != "" ) {
g_imdb[idx] = scanPageFirstMatch(url,"tt",g_imdb_regex,1)
}
}
}


e="/Show/Episodelist/Season/episode"
if (g_episode[idx] ~ "^[0-9,]+$" ) {
if (get_episode_xml(pi,tvDbSeriesUrl,g_season[idx],g_episode[idx],episodeInfo)) {

set_eptitle(idx,episodeInfo[e"/title"])

gAirDate[idx]=formatDate(episodeInfo[e"/airdate"])
url=seriesInfo["/Show/showlink"] "/printable?nocrew=1&season=" g_season[idx]


if (g_epplot[idx] == "" ) {



flag=sprintf(":%02dx%02d",g_season[idx],g_episode[idx])
p = scrape_one_item("tvrage_epplot", url, flag",<p>", 1, "</div>", 0, 1)






sub(/ *There are no foreign summaries.*/,"",p)
if (p != "" && index(p,"There is no summary") == 0) {
set_plot(idx,g_epplot,p)
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

return 0+ result
}

function urladd(a,b) {
return a (index(a,"?") ? "&" : "?" ) b
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


function fetch_xml_single_child(url,filelabel,xmlpath,tagfilters,xmlout,ignorePaths,\
f,found) {

f = getUrl(url,filelabel,1)
id1("fetch_xml_single_child ["url"] path = "xmlpath)
found =  scan_xml_single_child(f,xmlpath,tagfilters,xmlout,ignorePaths)
id0(found)
return 0+ found
}


function reset_filters(tagfilters,numbers,strings,regexs,\
t) {
for(t in tagfilters) {
DEBUG("filter ["t"]=["tagfilters[t]"]")

if (tagfilters[t] ~ "^[0-9]+$" ) {
numbers[t] = tagfilters[t]

} else if (substr(tagfilters[t],1,2) == "~:") {

regexs[t] = tolower(substr(tagfilters[t],3))

} else {

strings[t] = tagfilters[t]

}
}
}


function scan_xml_single_child(f,xmlpath,tagfilters,xmlout,ignorePaths,\
numbers,strings,regexs,\
line,start_tag,end_tag,found,t,last_tag,number_type,regex_type,string_type) {

delete xmlout
found=0

number_type=1
regex_type=2
string_type=3

last_tag = xmlpath
sub(/.*\//,"",last_tag)

start_tag="<"last_tag">"
end_tag="</"last_tag">"

reset_filters(tagfilters,numbers,strings,regexs)

dump(0,"numbers",numbers)
dump(0,"strings",strings)
dump(0,"regexs",regexs)


if (f != "") {
FS="\n"

while((getline line < f) > 0 ) {


if (index(line,start_tag) > 0) {


clean_xml_path(xmlpath,xmlout)
}


parseXML(line,xmlout,ignorePaths)

if (index(line,end_tag) > 0) {

found=1

for(t in numbers) {
if (!(t in xmlout) || (xmlout[t] - numbers[t] != 0) ) {
found =0 ; break
}
}
for(t in strings) {
if (!(t in xmlout) || (xmlout[t]"" != strings[t] ) ) {
found =0 ; break
}
}
for(t in regexs) {
if (!(t in xmlout) || (tolower(xmlout[t]) !~ regexs[t] ) ) {
found =0 ; break
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
return 0+ found
}



function adjustTitle(idx,newTitle,source,\
oldSrc,newSrc,newRank) {

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

oldSrc=g_title_source[idx]":["gTitle[idx]"] "
newSrc=source":["newTitle"] "

if (!(source in gTitlePriority)) {

ERR("Bad value ["source"] passed to adjustTitle")

} else {
newRank = gTitlePriority[source]
if  (ascii8(newTitle)) newRank += 10
if (gTitle[idx] == "" || newRank - g_title_rank[idx] > 0) {
DEBUG(oldSrc" promoted to "newSrc)
gTitle[idx] = newTitle
g_title_source[idx] = source
g_title_rank[idx] = newRank;;
return 1
} else {
DEBUG("current title "oldSrc "outranks " newSrc)
return 0
}
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

if (exec("dd if="qa(isoPath)" of="isoPart" bs=1024 count=10 skip=32") != 0) {
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
text2,part,parts,count) {
if (g_chr[32] == "" ) {
decode_init()
}


if (ascii8(text)) {

count = chop(text,"["g_8bit"]+",parts)
for(part=2 ; part-count <= 0 ; part += 2 ) {
text2=text2 parts[part-1] utf8_encode2(parts[part])

}
text2 = text2 parts[count]
if (text != text2 ) {
text = text2
}
}
return text
}


function utf8_encode2(text,\
i,text2,ll) {

ll=length(text)
for(i = 1 ; i - ll <= 0 ; i++ ) {
text2 = text2 g_utf8[substr(text,i,1)]
}



return text2
}


function url_encode(text,\
i,text2,ll,c) {

if (g_chr[32] == "" ) {
decode_init()
}

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




g_chr["amp"] = "&"
g_chr["quot"] = "\""
g_chr["lt"] = "<"
g_chr["gt"] = ">"
g_chr["nbsp"] = " "
}

function html_decode(text,\
parts,part,count,code,newcode,text2) {
if (g_chr[32] == "" ) {
decode_init()
}
if (index(text,"&") && index(text,";") ) {

count = chop(text,"[&][#0-9a-zA-Z]+;",parts)
for(part=2 ; part-count < 0 ; part += 2 ) {

newcode=""

code=parts[part]
if (code != "") {

code=tolower(code)

if (index(code,"&#") == 1) {

code = substr(code,3,length(code)-3)
if (index(code,"x") == 1) {

newcode=g_chr[code]
} else {

newcode=g_chr[0+code]
}
} else {

newcode=g_chr[substr(code,2,length(code)-2)]
}
}
if (newcode == "") {
newcode=parts[part]
}
text2=text2 parts[part-1] newcode

}
text2 = text2 parts[count]
if (text != text2 ) {
text = text2
}
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
system("mkdir -p "qa(dir))
if (set_permissions(qa(dir)"/.") == 0) {
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

function set_cache_prefix(p) { 
g_cache_prefix=p
}
function clear_cache_prefix(p,\
u) { 
for(u in gUrlCache) {
if (index(u,p) == 1) {
DEBUG("Deleting cache entry "u)
delete gUrlCache[u]
}
}
g_cache_prefix=""
}

function getUrl(url,capture_label,cache,referer,\
f,label,url2) {

label="getUrl:"capture_label": "



if (url == "" ) {
WARNING(label"Ignoring empty URL")
return
}

url2 = g_cache_prefix url

if(cache && (url2 in gUrlCache) ) {

DEBUG(label" fetched ["url2"] from cache")
f = gUrlCache[url2]
}

if (g_settings["catalog_cache_film_info"] == "yes") {
if (url ~ ".imdb.com/title/tt[0-9]+/?$" ) {
f = persistent_cache(extractImdbId(url))
cache=1
}
}

if (f =="" ) {
f=new_capture_file(capture_label)
}
if (is_file(f) == 0) {

if (wget(url,f,referer) ==0) {
if (cache) {
gUrlCache[url2]=f

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
qf = qa(tmpf)

r=1
for(i in urls) {
if (urls[i] != "") {
if (wget2(urls[i],tmpf,referer) == 0) {



exec("\"'"$AWK"'\" "g_quote"{ gsub(/<(h[1-5]|div|td|tr|p)[ >]/,\"\\n&\") ; print ; }"g_quote" "qf" >> "qa(file))
r=0
}
}
system("rm -f "qf)
}
return r
}



function wget2(url,file,referer,\
args,unzip_cmd,cmd,htmlFile,downloadedFile,targetFile,result,default_referer) {

args=" -U \""g_user_agent"\" "g_wget_opts
default_referer = get_referer(url)
if (check_domain_ok(default_referer) == 0) {
return 1
}
if (referer == "") {
referer = default_referer
}

if (referer != "") {
args=args" --referer=\""referer"\" "
}

targetFile=qa(file)
htmlFile=targetFile

args=args" --header=\"Accept-Encoding: gzip\" "
downloadedFile=qa(file".gz")

unzip_cmd=" && ( gunzip -c "downloadedFile" || gzip -c -d "downloadedFile" || cat "downloadedFile") > "htmlFile" 2>/dev/null && rm "downloadedFile

gsub(/ /,"+",url)




rm(downloadedFile,1)
args = args " -c "



url=qa(url)








cmd = "wget -O "downloadedFile" "args" "url" "unzip_cmd  





DEBUG("WGET ["url"]")
result = exec(cmd)
if (result != 0) {


rm(downloadedFile,1)
}

return 0+ result
}



#


function internal_poster_reference(field_id,idx,\
poster_ref) {
poster_ref = gTitle[idx]"_"g_year[idx]
gsub("[^-_&" g_alnum8 "]+","_",poster_ref)
if (g_category[idx] == "T" ) {
poster_ref = poster_ref "_" g_season[idx]
} else {
poster_ref = poster_ref "_" g_imdb[idx]
}



return "ovs:" field_id "/" g_settings["catalog_poster_prefix"] poster_ref ".jpg"
}

function getting_fanart(idx,lg) {
return 0+ getting_image(idx,FANART,GET_FANART,UPDATE_FANART,lg)
}

function getting_poster(idx,lg) {
return 0+ getting_image(idx,POSTER,GET_POSTERS,UPDATE_POSTERS,lg)
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
if(lg) INF("Already have "poster_ref" ["internal_path"]")
return 0
} else {
if(lg) INF("Getting "poster_ref)
return 1
}
}




function download_image(field_id,url,idx,\
poster_ref,internal_path,urls,referer,wget_args,get_it,script_arg,default_referer) {

id1("download_image["field_id"]["url"]")
if (url != "") {






poster_ref = internal_poster_reference(field_id,idx)
internal_path = getPath(poster_ref,g_fldr[idx])





get_it = 0
if (field_id == POSTER) {
get_it = getting_poster(idx,0)
} else if (field_id == FANART) {
get_it = getting_fanart(idx,0)
}

INF("getting image = "get_it)

if (get_it ) {



preparePath(internal_path)

split(url,urls,"\t")
url=urls[1]
referer=urls[2]




wget_args=g_wget_opts g_art_timeout

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
exec(APPDIR"/bin/jpg_fetch_and_scale "PID" "script_arg" "qa(url)" "qa(internal_path)" "wget_args" &")
g_image_inspected[internal_path]=1
}
}

id0(poster_ref)

return poster_ref
}


function check_domain_ok(url,\
start,tries,timeout) {

if (!(url in g_domain_status)) {
start=systime()
tries=2
timeout=5
if (system("wget --spider --no-check-certificate -t "tries" -T "timeout" -q -O /dev/null "qa(url)"/favicon.ico") ) {
g_domain_status[url]=1
} else if (systime() - start  >= tries * timeout ) {
WARNING("Error with domain ["url"]")
g_domain_status[url]=0
} else {

g_domain_status[url]=1
}
}
return g_domain_status[url]
}



































































function getNiceMoviePosters(idx,imdb_id,\
poster_url,backdrop_url) {


if (getting_poster(idx,1) || getting_fanart(idx,1)) {

DEBUG("Poster check imdb_id = "imdb_id)



if (poster_url == "" && getting_poster(idx,1) ) {
poster_url = get_moviedb_img(imdb_id,"poster","mid")
}

if (getting_fanart(idx,1) ) {
backdrop_url = get_moviedb_img(imdb_id,"backdrop","original")
}

if (poster_url == "") {
poster_url = get_motech_img(idx)
}
INF("movie poster ["poster_url"]")
g_poster[idx]=poster_url

INF("movie backdrop ["backdrop_url"]")
g_fanart[idx]=backdrop_url
}
}

function get_motech_img(idx,\
referer_url,url,url2) {

referer_url = "http://www.motechposters.com/title/"g_motech_title[idx]"/"




DEBUG("Got motech referer "referer_url)
if (referer_url != "" ) {
url2=scanPageFirstMatch(referer_url,"/posters","/posters/[^\"]+jpg",0)
if (url2 != ""  && index(url2,"thumb.jpg") == 0 ) {
url="http://www.motechposters.com" url2

url=url"\t"referer_url
DEBUG("Got motech poster "url)
} 
}
return url
}


#













#
function get_moviedb_img(imdb_id,type,size,\
search_url,txt,xml,f,bestId,url,url2,parse,id) {

search_url="http://api.themoviedb.org/2.1/Movie.getImages/en/xml/"g_tk2"/"imdb_id



id1("get_moviedb_img "imdb_id" "type" "size)
f=getUrl(search_url,"moviedb",0)


bestId=0
if (f != "") {
FS="\n"
parse=0
while((getline txt < f) > 0 ) {
if (match(txt,"<(poster|backdrop)") ) {

parse = 0
if (index(txt,"<"type)) {
delete xml
parseXML(txt,xml)
id=xml["/"type"#id"]
parse=(bestId == 0 || id+0 < bestId)
}

} else if (parse && index(txt,"<image") ) {

delete xml
parseXML(txt,xml)
if (xml["/image#size"] == size ) {
url2=url_encode(html_decode(xml["/image#url"]))
if (exec("wget "g_wget_opts" --spider "url2) == 0 ) {
url = url2
bestId = id
}
}
}

}
close(f)
}
id0(url)
return url
}








function scanPageFirstMatch(url,fixed_text,regex,cache,referer,\
matches,ret) {
id1("scanPageFirstMatch")
scanPageForMatches(url,fixed_text,regex,1,cache,referer,matches)
ret = firstIndex(matches)
id0(ret)
return ret
}





function scanPageMostFreqMatch(url,fixed_text,regex,cache,referer,matches,\
normedt,ret) {
id1("scanPageMostFreqMatch")
scanPageForMatches(url,fixed_text,regex,0,cache,referer,matches)
if (regex == g_imdb_title_re) {
normalise_title_matches(matches,normedt)
hash_copy(matches,normedt)
}
ret=bestScores(matches,matches,0)
id0(ret)
return ret
}




#
function search_url(url) {
sub(/^SEARCH/,g_search_engine[(g_search_engine_current++) % g_search_engine_count],url)
return url
}

function search_url2file(url,cache,referer,\
i,url2,f) {
for(i = 0 ; i < 0+g_search_engine_count ; i++ ) {

url2 = search_url(url)

f=getUrl(url2,"scan4match",cache,referer)

if (f != "") break
}
return f
}






function enc_getline(f,line,\
code,t,t2) {

code = ( getline t < f )

if (code > 0) {

if (genre_debug) {
DEBUG("REMOVE LATER: from file["t"]")
}

if (g_f_utf8[f] == "" ) {



g_f_utf8[f] = check_utf8(t)


} else {

t2 = html_decode(t)
if (genre_debug && t2 != t) {
DEBUG("REMOVE LATER: post decode["t2"]")
}
t = t2

if (g_f_utf8[f] != 1) {
t2 = utf8_encode(t)
if (genre_debug && t2 != t) {
DEBUG("REMOVE LATER: post utf8["t2"]")
}
t = t2
}
}
line[1] = t
}
return code
}

function enc_close(f) {
delete g_f_utf8[f]
close(f)
}


function check_utf8(line,\
utf8) {
line=tolower(line)
if (index(line,"<?xml") || index(line,"charset")) {

utf8 = index(line,"utf-8")?1:-1

} else if (index(line,"</head>")) {
utf8 = -1
}
if (utf8) INF("UTF-8 Encoding:" utf8)
return utf8
}








function scanPageForMatches(url,fixed_text,regex,max,cache,referer,matches,verbose,\
f,line,count,linecount,remain,is_imdb,matches2) {

delete matches
id1("scanPageForMatches["url"]")
INF("["fixed_text"]["\
(regex == g_imdb_regex\
?"<imdbtag>"\
:(regex==g_imdb_title_re\
?"<imdbtitle>"\
:regex\
)\
)"]["max"]")

if (index(url,"SEARCH") == 1) {
f = search_url2file(url,cache,referer)
} else {
f=getUrl(url,"scan4match",cache,referer)
}

count=0

is_imdb = (regex == g_imdb_regex )

if (f != "" ) {

FS="\n"
remain=max

while(enc_getline(f,line) > 0 ) {

line[1] = de_emphasise(line[1])





if (is_imdb && index(line[1],"/Title?") ) {
gsub(/\/Title\?/,"/tt",line[1])
}

if (verbose) DEBUG("scanindex = "index(line[1],fixed_text))
if (verbose) DEBUG(line[1])

if (fixed_text == "" || index(line[1],fixed_text)) {

linecount = get_regex_counts(line[1],regex,remain,matches2)
hash_add(matches,matches2)

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
id0(count)
return 0+ count
}







function chop(s,regex,parts,\
flag,i) {

flag="@~"
while (index(s,flag) ) {
WARNING("Regex flag clash "flag)
flag = flag "£" flag
}


gsub(regex,flag "&" flag , s )


i = split(s,parts,flag)
if (i % 2 == 0) ERR("Even chop of ["s"] by ["flag"]")
return i+0
}










function get_regex_counts(line,regex,max,matches) {
return 0+get_regex_count_or_pos("c",line,regex,max,matches)
}








function get_regex_pos(line,regex,max,rtext,rstart) {
return 0+get_regex_count_or_pos("p",line,regex,max,rtext,rstart)
}













function get_regex_count_or_pos(mode,line,regex,max,rtext,rstart,\
count,fcount,i,parts,start) {
count =0 

delete rtext
delete rstart

fcount = chop(line,regex,parts)
start=1
for(i=2 ; i-fcount <= 0 ; i += 2 ) {
count++
if (mode == "c") {
rtext[parts[i]]++
} else {
rtext[count] = parts[i]

start += length(parts[i-1])
rstart[count] = start
start += length(parts[i])
}
if (max+0 > 0 ) {
if (count - max >= 0) {
break
}
}
}

dump(3,"get_regex_count_or_pos:"mode,rtext)

return 0+count
}


function scrapeIMDBLine(line,imdbContentPosition,idx,f,isection,\
title,poster_imdb_url,i,sec) {


if (imdbContentPosition == "footer" ) {
return imdbContentPosition
} else if (imdbContentPosition == "header" ) {



if (index(line,"<title>")) {
title = extractTagText(line,"title")
DEBUG("Title found ["title "] current title ["gTitle[idx]"]")


if (g_year[idx] == "" && match(title,".*\\("g_year_re)) {
g_year[idx] = substr(title,RSTART+RLENGTH-4,4)
DEBUG("IMDB: Got year ["g_year[idx]"]")
delete isection[YEAR]
}





#


g_motech_title[idx]=tolower(title)
gsub(/[^a-z0-9]+/,"-",g_motech_title[idx])
gsub(/-$/,"",g_motech_title[idx])

g_imdb_title[idx]=extract_imdb_title_category(idx,title)

if (adjustTitle(idx,g_imdb_title[idx],"imdb")) {
gOriginalTitle[idx] = gTitle[idx]
}
sec=TITLE
}
if (index(line,"pagecontent")) {
imdbContentPosition="body"
}

} else if (imdbContentPosition == "body") {

if (index(line,">Company:")) {

DEBUG("Found company details - ending")
imdbContentPosition="footer"

} else {



if ((i=index(line,"a name=\"poster\"")) > 0) {
poster_imdb_url = extractAttribute(substr(line,i-1),"img","src")
if (poster_imdb_url != "") {

sub(/SX[0-9]{2,3}_/,"SX400_",poster_imdb_url)
sub(/SY[0-9]{2,3}_/,"SY400_",poster_imdb_url)


g_imdb_img[idx]=poster_imdb_url
DEBUG("IMDB: Got imdb poster ["g_imdb_img[idx]"]")
}
sec=POSTER
}
if (g_director[idx] == "" && index(line,"Director:")) {
g_director[idx] = scrape_until("idirector",f,"/name/",1)
sec=DIRECTOR
}

if (g_plot[idx] == "" && index(line,"Plot:")) {
set_plot(idx,g_plot,scrape_until("iplot",f,"</div>",0))
sub(/\|.*/,"",g_plot[idx])
sub(/[Ff]ull ([Ss]ummary|[Ss]ynopsis).*/,"",g_plot[idx])

sec=PLOT
}


if (g_genre[idx] == "" && index(line,"Genre:")) {
genre_debug = 1
g_genre[idx]=trimAll(scrape_until("igenre",f,"</div>",0))
genre_debug = 0
DEBUG("Genre=["g_genre[idx]"]")
sub(/ +[Ss]ee /," ",g_genre[idx])
sub(/ +[Mm]ore */,"",g_genre[idx])
sec=GENRE
}
if (g_runtime[idx] == "" && index(line,"Runtime:")) {
g_runtime[idx]=trimAll(scrape_until("irtime",f,"</div>",0))
if (match(g_runtime[idx],"[0-9]+")) {
g_runtime[idx] = substr(g_runtime[idx],RSTART,RLENGTH)
}
sec=RUNTIME
}


if (index(line,"/10</b>") && match(line,"[0-9.]+/10") ) {
g_rating[idx]=0+substr(line,RSTART,RLENGTH-3)
DEBUG("IMDB: Got Rating = ["g_rating[idx]"]")
sec=RATING
}
if (index(line,"certificates")) {

scrapeIMDBCertificate(idx,line)
sec=CERT

}



if (index(line,"Also Known")) DEBUG("AKA "gOriginalTitle[idx]" vs "gTitle[idx])

if (gOriginalTitle[idx] == gTitle[idx] && index(line,"Also Known As:")) {
line = raw_scrape_until("aka",f,"</div>",1)

DEBUG("AKA:"line)

scrapeIMDBAka(idx,line)
sec=AKA

}
}
} else {
DEBUG("Unknown imdbContentPosition ["imdbContentPosition"]")
}
if (sec) delete isection[sec]
return imdbContentPosition
}

function extract_imdb_title_category(idx,title,\
) {


g_category[idx]="M"
DEBUG("imdb title=["title"]")
if (match(title,"^\".*\"") ) {
title=substr(title,RSTART+1,RLENGTH-2)
g_category[idx]="T"
}


gsub(/ \((19|20)[0-9][0-9](\/I|)\) *(\([A-Z]+\)|)$/,"",title)

DEBUG("Imdb title = ["title"]")
return title
}







function scrapeIMDBAka(idx,line,\
akas,a,c,bro,brc) {

if (gOriginalTitle[idx] != gTitle[idx] ) return 

bro="("
brc=")"
split(de_emphasise(line),akas,"<br>")
dump(0,"AKA array",akas)
for(a in akas) {
akas[a] = remove_tags(akas[a])
DEBUG("Checking aka ["akas[a]"]")
for(c in gTitleCountries ) {
if (index(akas[a], gTitleCountries[c])) {
if (match(akas[a], "- .*\\<"gTitleCountries[c]":")) {



DEBUG("Ignoring aka section")
return
}
if (match(akas[a],"- .*\\<" gTitleCountries[c] "\\>")) {

if (match(akas[a],"longer version|season title|poster|working|literal|IMAX|promotional|long title|short title|rerun title|script title|closing credits|informal alternative")) {


DEBUG("Ignoring aka section")
return
}

if (match(akas[a],"\".*\" -")) {
adjustTitle(idx,clean_title(substr(akas[a],RSTART+1,RLENGTH-2)),"imdb_aka"); 
}
return
}
}
}
}
}

function scrapeIMDBCertificate(idx,line,\
l,cert_list,certpos,cert,c,total,i,flag) {

flag="certificates="


total = get_regex_pos(line, flag"[^&\"]+",0,cert_list,certpos)

for(i = 1 ; i - total <= 0 ; i++ ){

l = substr(cert_list[i],index(cert_list[i],flag)+length(flag))

split(l,cert,"[:|]")


for(c = 1 ; (c in gCertificateCountries ) ; c++ ) {
if (gCertCountry[idx] == gCertificateCountries[c]) {

return
}
if (cert[1] == gCertificateCountries[c]) {

gCertCountry[idx] = cert[1]

gCertRating[idx] = toupper(cert[2])
gsub(/%20/," ",gCertRating[idx])
DEBUG("IMDB: set certificate ["gCertCountry[idx]"]["gCertRating[idx]"]")
return
}
}
}
}








function scrape_one_item(label,url,start_text,start_include,end_text,end_include,cache,\
f,line,out,found,tokens,token_count,token_i) {

f=getUrl(url,label,cache)

token_count = split(start_text,tokens,",")
if (f) {
token_i = 1
while(enc_getline(f,line) > 0 ) {

if (token_i - token_count <= 0 ) {
if (match(line[1],tokens[token_i])) {
INF("matched token ["tokens[token_i]"]")
token_i++
}
}
if (token_i - token_count > 0 ) {

out = scrape_until(label,f,end_text,end_include)
if (start_include) {

out = remove_tags(line[1]) out

}
found = 1
break
}
}
enc_close(f)
}
if (found != 1) {
ERR("Cant find ["start_text"] in "label":"url)
}

return out
}

function isreg(t) {
if (index(t,"\\<")) return 1
gsub(/\\./,"",t)
return match(t,"[][().|$^+*]")
}
function scrape_until(label,f,end_text,inclusive) {

return trim(remove_tags(raw_scrape_until(label,f,end_text,inclusive)))
}
function raw_scrape_until(label,f,end_text,inclusive,\
line,out,ending,isre) {
ending = 0
isre = isreg(end_text)



while(!ending && enc_getline(f,line) > 0) {
if (isre) {
ending =match(line[1],end_text)
} else {
ending =index(line[1],end_text)
}
if (!ending || inclusive) {
out = out " " line[1]
}
}
gsub(/ +/," ",out)
out =remove_html_section(out,"script")
out =remove_html_section(out,"style")

return out
}


function remove_html_section(input,tag,\
out,tag_start,tag_end,start_pos,end_pos,tail) {

out=input 

tag_start="<"tag

tag_end="</"tag">"

while((start_pos=index(out,tag_start)) > 0) {
tail=""
end_pos=index(out,tag_end)
if (end_pos > 0 ) {
tail = substr(out,end_pos+length(tag)+3)
}

out = substr(out,1,start_pos-1) tail
}
return out
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
gsub("[^-" g_alnum8 ",. ]","",epTitle)
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


if (moveFileIfPresent(oldName,newName) != 0 ) {
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


DEBUG("Checking nfo file ["gNfoDefault[i]"]")
if(is_file(gNfoDefault[i])) {

nfoName = newName
sub(/\.[^.]+$/,"",nfoName)
nfoName = nfoName ".nfo"

if (nfoName == newName ) {
return
}

DEBUG("Moving nfo file ["gNfoDefault[i]"] to ["nfoName"]")
if (moveFileIfPresent(gNfoDefault[i],nfoName) != 0) {
return
}
if (!g_opt_dry_run) {

gDate[nfoName]=gDate[gNfoDefault[i]]
delete gDate[gNfoDefault[i]]

gNfoDefault[i] = nfoName
DEBUG("Moved nfo file ["gNfoDefault[i]"]")
}
}


rename_related(oldName,newName)


moveFolder(i,oldFolder,newFolder)
}
}

INF("checking "qa(oldFolder))
if (is_dir(oldFolder) && is_empty(oldFolder)) {

INF("removing "qa(oldFolder))
system("rmdir "qa(oldFolder))
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

if (changeable(x) == 0) return 1

if (!quiet) {
INF("Deleting "x)
}
cmd=cmd qa(x)" 2>/dev/null "
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
split("jpg png srt idx sub nfo",extensions," ")

oldBase = oldName
sub(/\....$/,".",oldBase)

newBase = newName
sub(/\....$/,".",newBase)

for(ext in extensions) {
moveFileIfPresent(oldBase extensions[ext],newBase extensions[ext])
}

}

function preparePath(f) {
f = qa(f)
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


function moveFileIfPresent(oldName,newName) {

if (is_file(oldName)) {
return moveFile(oldName,newName)
} else {
return 0
}
}


function moveFile(oldName,newName,\
new,old,ret) {

if (changeable(oldName) == 0 ) {
return 1
}
new=qa(newName)
old=qa(oldName)
if (g_opt_dry_run) {
if (match(oldName,gExtRegExAll) && is_file(oldName)) {
print "dryrun: from "old" to "new
}
return 0
} else {

if ((ret=preparePath(newName)) == 0) {
ret = exec("mv "old" "new)
}
return 0+ ret
}
}

function isDvdDir(f) {
return substr(f,length(f)) == "/"
}


function moveFolder(i,oldName,newName,\
cmd,new,old,ret,isDvdDir,err) {

ret=1
err=""

if (folderIsRelevant(oldName) == 0) {

err="not listed in the arguments"

} else if ( g_fldrCount[oldName] - 2*(isDvdDir(g_media[i])) > 0 ) {

err= g_fldrCount[oldName]" sub folders"

} else if (g_fldrMediaCount[oldName] - 1 > 0) {

err = g_fldrMediaCount[oldName]" media files"

} else if (changeable(oldName) == 0 ) {

err="un changable folder"

} else {
new=qa(newName)
old=qa(oldName)
if (g_opt_dry_run) { 
print "dryrun: from "old"/* to "new"/"
ret = 0
} else if (is_empty(oldName) == 0) {
INF("move folder:"old"/* --> "new"/")
cmd="mkdir -p "new" ;  mv "old"/* "new" ; mv "old"/.[^.]* "new" ; rmdir "old
err = "unknown error"
ret = exec(cmd)
system("rmdir "old" 2>/dev/null" )
}
}
if (ret != 0) {
WARNING("folder contents ["oldName"] not renamed to ["newName"] : "err)
}
return 0+ ret
}

function hasContent(f,\
tmp,err) {
err = (getline tmp < f )
if (err != -1) close(f)
return (err == 1 )
}

function isnmt() {
return 0+ is_file("'"$NMT_APP_DIR"'/MIN_FIRMWARE_VER")
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
return system("ls -a "qa(d)" | egrep -v \"^\.\.?$\"") != 0
}
function is_dir(f) {
return 0+ test("-d",f"/.")
}
function is_file_or_folder(f,\
r) {
r = (is_file(f) || is_dir(f))
if (r == 0) WARNING(f" is neither file or folder")
return r
}

function test(t,f) {
return system("test "t" "qa(f)) == 0
}




function generate_nfo_file(nfoFormat,dbrow,\
movie,tvshow,nfo,dbOne,fieldName,fieldId,nfoAdded,episodedetails) {

nfoAdded=0
if (g_settings["catalog_nfo_write"] == "never" ) {
return
}
parseDbRow(dbrow,dbOne)
get_name_dir_fields(dbOne)

if (dbOne[NFO] == "" ) return

nfo=getPath(dbOne[NFO],dbOne[DIR])


if (is_file(nfo) && g_settings["catalog_nfo_write"] != "overwrite" ) {
DEBUG("nfo already exists - skip writing")
return
}

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
set_permissions(qa(nfo))
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
gsub("[^" g_alnum8 "]"," ",t)
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
row,est,nfo,op,start) {


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
g_file[i] = clean_path(g_file[i])

if ((g_file[i] in g_fldrCount ) && g_fldrCount[g_file[i]]) {
DEBUG("Adjusting file for video_ts")
g_file[i] = g_file[i] "/"
}

op="update"
if (db_index == -1 ) {
db_index = ++gMaxDatabaseId
op="add"
}
row="\t"ID"\t"db_index
INF("dbrow "op" ["db_index":"g_file[i]"]")

row=row"\t"CATEGORY"\t"g_category[i]

if (index_time == "") {
if (RESCAN == 1 ) {
index_time = est
} else {
index_time = NOW
}
}

row=row"\t"INDEXTIME"\t"shorttime(index_time)

row=row"\t"WATCHED"\t"watched



row=row"\t"TITLE"\t"gTitle[i]
if (gOriginalTitle[i] != "" && gOriginalTitle[i] != gTitle[i] ) {
row=row"\t"ORIG_TITLE"\t"gOriginalTitle[i]
}
if (g_season[i] != "") row=row"\t"SEASON"\t"g_season[i]

row=row"\t"RATING"\t"g_rating[i]

if (g_episode[i] != "") row=row"\t"EPISODE"\t"g_episode[i]

row=row"\t"GENRE"\t"short_genre(g_genre[i])
row=row"\t"RUNTIME"\t"g_runtime[i]

if (gParts[i]) row=row"\t"PARTS"\t"gParts[i]

row=row"\t"YEAR"\t"short_year(g_year[i])

start=1
if (index(g_file[i],g_mount_root) == 1) {
start += length(g_mount_root)
}
row=row"\t"FILE"\t"substr(g_file[i],start)

if (gAdditionalInfo[i]) row=row"\t"ADDITIONAL_INF"\t"gAdditionalInfo[i]


if (g_imdb[i] == "") {

g_imdb[i]=g_tvid_plugin[i]"_"g_tvid[i]
if (g_imdb[i] == "") {

g_imdb[i]="ovs"PID"_"systime()
}
}
row=row"\t"URL"\t"g_imdb[i]

row=row"\t"CERT"\t"gCertCountry[i]":"gCertRating[i]
if (g_director[i]) row=row"\t"DIRECTOR"\t"g_director[i]

row=row"\t"FILETIME"\t"shorttime(g_file_time[i])
row=row"\t"DOWNLOADTIME"\t"shorttime(est)




if (gAirDate[i]) row=row"\t"AIRDATE"\t"gAirDate[i]


if (gEpTitle[i]) row=row"\t"EPTITLE"\t"gEpTitle[i]
nfo=""

if (g_settings["catalog_nfo_write"] != "never" || is_file(gNfoDefault[i]) ) {
nfo=gNfoDefault[i]
gsub(/.*\//,"",nfo)
}
if (is_file(g_fldr[i]"/"nfo)) {
row=row"\t"NFO"\t"nfo
}
return row
}
function short_year(y) {
return sprintf("%x",y-1900)
}
function short_genre(g,\
i,gnames,gcount) {
gcount = split(g_settings["catalog_genre"],gnames,",")
for(i = 1 ; i <= gcount ; i += 2) {
if (match(g,"\\<"gnames[i]"o?\\>") ) {
g = substr(g,1,RSTART-1) gnames[i+1] substr(g,RSTART+RLENGTH); 
}
}
gsub(/[^-A-Za-z]+/,"|",g)
return g
}



function n(x) \
{
sub(/^[^-0-9]*0*/,"",x)



return 0+x
}


function shorttime(t,\
y,m,d,hr,mn,r) {
r = t
if (length(t) > 8 ) {

y = n(substr(t,1,4))-1900
m = n(substr(t,5,2))
d = n(substr(t,7,2))
hr = n(substr(t,9,2))
mn = n(substr(t,11,2))

r = lshift(lshift(lshift(lshift(and(y,1023),4)+m,5)+d,5)+hr,6)+mn
r= sprintf("%x",r)
}

return r
}





function add_new_scanned_files_to_database(indexToMergeHash,output_file,\
i,row,f) {

report_status("New Records: " hash_size(indexToMergeHash))

gMaxDatabaseId++

for(i in indexToMergeHash) {

f=g_media[i]

if (g_media[i] == "") continue

add_file(g_fldr[i]"/"g_media[i])

row=createIndexRow(i,-1,0,"")
if (length(row) - g_max_db_len < 0) {

print row"\t" >> output_file


update_plots(g_plot_file,i)
}



row = row "\t"PLOT"\t"g_plot[i]
generate_nfo_file(g_settings["catalog_nfo_format"],row)
}
close(output_file)
}

function ascii8(s) {
return s ~ "["g_8bit"]"
}











































function update_plots(pfile,idx,\
id,key,cmd,cmd2,ep) {
id=g_imdb[idx]

if (id != "") {
ep = g_episode[idx]
INF("updating plots for "id"/"ep)

key=qa(id)" "(g_category[idx]=="T"?qa(g_season[idx]):qa(""))

cmd=g_plot_app" update "qa(pfile)" "key

if (g_plot[idx] != "" && !(key in g_updated_plots) ) {
cmd2 = cmd" "qa("")

exec(cmd2" "qa(g_plot[idx]))
g_updated_plots[key]=1
}

key=key" "qa(ep)
if (g_category[idx] == "T" && g_epplot[idx] != "" && !(key in g_updated_plots) ) {
cmd2 = cmd" "qa(ep)

exec(cmd2" "qa(g_epplot[idx]))
g_updated_plots[key]=1
}
}
}

function touch_and_move(x,y) {
system("touch "qa(x)" ; mv "qa(x)" "qa(y))
}





function new_capture_file(label,\
fname) {
fname = CAPTURE_PREFIX JOBID  "." CAPTURE_COUNT "__" label
CAPTURE_COUNT++
return fname
}

function clean_capture_files() {
INF("Clean up")
exec("rm -f -- "qa(CAPTURE_PREFIX JOBID) ".* 2>/dev/null")
}
function DEBUG(x) {

if ( DBG ) {
timestamp("[DEBUG]  ",x)
}

}
function INF(x) {
timestamp("[INFO]   ",x)
}
function WARNING(x) {
timestamp("[WARNING]",x)
}
function ERR(x) {
timestamp("[ERR]    ",x)
}
function DETAIL(x) {
timestamp("[DETAIL] ",x)
}


function trimAll(str) {
sub(g_punc[0]"$","",str)
sub("^"g_punc[0],"",str)
return str
}

function trim(str) {
sub(/^ +/,"",str)
sub(/ +$/,"",str)
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

load_settings("",DEFAULTS_FILE)
load_settings("",CONF_FILE)

load_settings(g_country_prefix , COUNTRY_FILE)

gsub(/,/,"|",g_settings["catalog_format_tags"])
gsub(/,/,"|",g_settings["catalog_ignore_paths"])
gsub(/,/,"|",g_settings["catalog_ignore_names"])

g_settings["catalog_ignore_names"]="^"glob2re(g_settings["catalog_ignore_names"])"$"

g_settings["catalog_ignore_paths"]="^"glob2re(g_settings["catalog_ignore_paths"])
if (g_settings["catalog_ignore_paths"] == "^" ) {
g_settings["catalog_ignore_paths"] = "^$"
}




split(tolower(g_settings["catalog_search_engines"]),g_link_search_engines,g_cvs_sep)
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




' JOBID="$JOBID" PID=$$ NOW=`date +%Y%m%d%H%M%S` \
DAY=`date +%a.%P` \
"START_DIR=$START_DIR" \
"LS=$LS" \
"APPDIR=$APPDIR" \
"CONF_FILE=$CONF_FILE" \
"COUNTRY_FILE=$COUNTRY_FILE" \
"DEFAULTS_FILE=$DEFAULTS_FILE" \
tmp_dir="$tmp_dir" \
"INDEX_DB=$INDEX_DB" "$@"

rm -f "$APPDIR/catalog.lck" "$APPDIR/catalog.status"
}

tidy() {
rm -f "$APPDIR/catalog.status"
clean_all_files
}

trap "rm -f $APPDIR/catalog.status" INT TERM EXIT

main() {

clean_all_files

set +e
echo '[INFO] catalog version '$VERSION' $Id$'
sed 's/^/\[INFO\] os version /' /proc/version
if is_nmt ; then
sed -rn '/./ s/^/\[INFO\] nmt version /p' /???/*/VERSION
fi

catalog DEBUG$DEBUG "$@" 
x=$?
set -e

rm -fr -- "$tmp_dir"
chown -R $OVERSIGHT_ID $INDEX_DB* "$PLOT_DB" "$APPDIR/tmp" || true
return $x
}









clean_files() {
find "$1" -name "$2" -mtime "+$3" | while IFS= read f ; do
rm -f -- "$f"
done
}

clean_all_files() {
clean_files "$tmp_root" "." 2
clean_files "$APPDIR/logs" "catalog.*.log" 5 
clean_files "$APPDIR/cache" "tt*" 30
}




if [ "$STDOUT" -eq 1 ] ; then
LOG_TAG="catalog:"
main "$@"
else
LOG_TAG=

LOG_DIR="$APPDIR/logs"
mkdir -p "$LOG_DIR"
LOG_NAME="catalog.$JOBID.log"
LOG_FILE="$LOG_DIR/$LOG_NAME"

(cd "$LOG_DIR" && ( mv "last.log" "prev.log" || true ) && ln -sf "$LOG_NAME" "last.log" )

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

