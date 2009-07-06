#!/bin/sh --
# TODO Propogate timestamps up to group display.
# TODO Make sure playlist.htm is in order.
# TODO Option for main table to be by column or by row.
#TODO Readd code to use parent folder if title is blank?
#TODO Optimise link generation in main table
#TODO Add lock on database for both oversight.cgi and catalog.sh
# aquiring LOCK must time out quickly for oversight.cgi but block for catalog.sh

# Convert script from DOS
true                            #

if [ $? != 0 ]; then            #
    set -e                      #
    sed 's/.$//' "$0" > /tmp/$$ #
    cat /tmp/$$ > "$0"          #
    rm /tmp/$$                  #
    exec /bin/sh "$0" "$@"      #
    exit                        #
fi                              #

OWNER=nmt:nmt
CACHE_DIR=/tmp/catalog.cache

DECODE() {
    echo "$1" | sed 's/%20/ /g'
}

case "X$1" in
    X*jpg) echo "Content-Type: image/jpeg" ; echo ; x=`DECODE "$1"` ; exec cat "$x" ;;
    X*png) echo "Content-Type: image/png" ; echo ; x=`DECODE "$1"` ; exec cat "$x" ;;
esac

# REAL SCRIPT FOLLOWS
#--------------------------------------------------------------------------
#!/bin/sh
# 30/11/2008
# TV AWK INTERFACE
# This CGI script is horrendous. My comment!
# Pushing limits of awks usability. Next time I'll use the PHP Processor.

# (c) Andy Lord andy@lordy.org.uk
#License GPLv3


DEBUG=0
VERSION=20090111-1

CONST=/tmp/oversight.constants 
if [ ! -f $CONST ] ; then
    EXE=$0
    while [ -L "$EXE" ] ; do
        EXE=$( ls -l "$EXE" | sed 's/.*-> //' )
    done
    HOME=$( echo $EXE | sed -r 's|[^/]+$||' )
    HOME=$(cd "${HOME:-.}" ; pwd )
    TVMODE=`cat /tmp/tvmode`

    cat <<HERE > $CONST
#Oversight constants. This file can be deleted to reset oversight interface.
HOME="$HOME"
EXE="$EXE"
TVMODE="$TVMODE"
HERE
else
    . $CONST
fi


    
appname=oversight

cd "$HOME"

unpak_bin="$HOME/$appname.sh"


#METHOD=GET
METHOD=POST
UPLOAD_DIR=/share/

INDEX_DB="$HOME/index.db"

#Processes GET or POST parameters and also outputs them to stdout 
# <name>=<value>
#so display stage can use them.
MAIN_PAGE() {
    FORM_INPUT=${TEMP_FILE:-/dev/null}

    # We need to add a dummy input file to force the users 'run_commands()'
    # to run after then FORM_INPUT but before the END clause.
    # It must run before the END() so that new file arguments can be pushed
    # onto ARGV.
    DUMMY_ONE_LINE_FILE="$HOME/.do_not_delete"

    # Do this outside of awk so we can see script errors in the browser.
    echo "Content-Type: text/html"
    echo
    Q="'"

        awk '

# Keep this as the first rule
FNR == 1 { INPUT_CHANGE(); }
#{ print CAPTURE_LABEL"|"$0 }
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#%%%%%%%%%%%%%%%%%%%%%%%NO CHANGE ABOVE HERE %%%%%%%%%%%%%%%%%%%%%%%%%%%%
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#------------------------------------------------------------------------
#--------Add Calls to main application here - NO HTML Rendering ---------
#--------No backend application implementation. -------------------------
#--------The calls should communicate to the rendering functions by
#        1)Setting awk variables.
#        2)Writing output to a file and then adding the file to the awk arguments.
#          eg in run_commands() ...
#
#             f=NEW_CAPTURE_FILE("OUT1");
#             system("ls -l /tmp > " f);
#
#          Then in the html rendering section
#
#             FILENAME=f { .... }    or
#             CAPTURE_LABEL="OUT1" { .... }    or
#
#       3)   Or simply append the file directly 
#
#             ARGV[ARGC++] = filename;
#          
#------------------------------------------------------------------------
# This is read if query["view"] == ""
FILENAME == INDEX_DB".idx" {

    if ( FNR == 1  ) {
        gGrossIndexSize = 0;
        if ( FS != "\t" ) {
            FS="\t" ;
            $0 = $0 ;
        }
    }

    gGrossIndexSize++;

    if (match($0,gIndexFilter) == 0) next;
    if (index($0,"\t"ACTION"\t0\t") == 0 ) next;
    if (index($0,gWatchedFilter) == 0) next;


    load_index();

    next;
}

# This is read if query["view"] == movie or tv
FILENAME == INDEX_DB {

    if ( FNR == 1  && FS != "\t" ) { FS="\t" ; $0 = $0 };

    if (match($0,gIndexFilter) && index($0,"\t"ACTION"\t0\t")) {

        parse_index_merge(db,db_size++);

    }
    next;
}

function START_PRE_FORM() {

    db_size=0;

    ID="_id";

    OVERVIEW_DETAILIDLIST="_did" ;
    OVERVIEW_EXT_LIST = "_ext";

    WATCHED="_w";
    ACTION="_a"; # Tell catalog.sh to do something with this entry (ie delete)
    PARTS="_pt";
    #DB fields - must start with _ so grepping the index log for \tfield\tvalue will be (reasonably) safe. but must be URL safe too.
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
    0SEASON="_s0";
    0EPISODE="_e0";

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
    QREG_FILTER="_rf";
    CAPTURE_PREFIX = "/tmp/awk." PID ;

    NMT_PLAYLIST="/tmp/playlist.htm";
    printf "" > NMT_PLAYLIST;
    CHECKBOX_PREFIX="cb_";

}

function shellEscape(t) {
    gsub(/[][ *?"'"'"'()]/,"\\\\&",t);
    return t;
}

# Called after form parameters have been processed.
function START_POST_FORM() {

    if (DEBUG) {
        for (i in ENVIRON) { print "<!-- ENV:" i "=" ENVIRON[i] "-->"; }
        for (i in query) { print "<!-- QUERY:" i "=" query[i] "-->"; }
    }
    doFormActions();


    if (query["sort"] == "") { query["sort"] = INDEXTIME };

    if (query["order"] == "") {
        query["order"] = -1 ; #timestamps
        if (query["sort"] == TITLE ) query["order"] = 1 ;
    }

    h_comment("View = "query["view"]);
    if (query["view"] != "") {

        gIndexFilter="\t"ID"\t("query["idlist"]")\t";
        APPEND_CONTENT(INDEX_DB);

    } else {

        gIndexFilter="\t";
        if (query[QTYPE_FILTER] != "" ) {
            gIndexFilter="\t"CATEGORY"\t"query[QTYPE_FILTER]"{0,1}\t";
        }

        gWatchedFilter="\t";
        if (query[QWATCHED_FILTER] != "" ) {
            gWatchedFilter="\t"WATCHED"\t"(query[QWATCHED_FILTER] == "W")"\t";
        }

        APPEND_CONTENT(INDEX_DB".idx");

        gFilterRegex="";
        if (query[QREG_FILTER] != "" ) {
            #Filter must match adjacent characters. Leave as is.
            gFilterRegex = "\\<"query[QREG_FILTER]; # [abc][def][ghi]
        }
    }

    start_page();

}

function exec(cmd) {
    h_comment("SYSTEM : "cmd);
    return system(cmd);
}

function doFormActions(\
    idList,idStr) {
    if (query["select"] == "Cancel"  ) {
        clearSelection();
    }
    if (query["select"] != ""  ) {
        if (getSelectedIds(idList)) {

            idStr =join("|",idList);

            if (query["select"] == "Delete" ) { setSelectRecordFields(idStr,ACTION,"D",1); setMainPageIfAllDeleted(idStr); }
            else if (query["select"] == "Mark" ) setSelectRecordFields(idStr,WATCHED,1,0); 
            else if (query["select"] == "Unmark" ) setSelectRecordFields(idStr,WATCHED,0,0);
            else if (query["select"] == "Remove" ) { deleteSelectedRecords(idStr); setMainPageIfAllDeleted(idStr); }

            clearSelection();
        }
    }
}

function isCheckbox(i) {
    return (query[i]=="on" && substr(i,1,length(CHECKBOX_PREFIX)) == CHECKBOX_PREFIX && match(i,"^"CHECKBOX_PREFIX"[0-9|]+$"));
}

function clearSelection() {
    delete query["select"];
    for(i in query) {
        if (isCheckbox(i)) {
            delete query[i];
        }
    }
}

function setMainPageIfAllDeleted(idStr) {
    h_comment(idStr":idStr");
    h_comment(query["idlist"]":idlist");
    if (query["view"] != "" && idStr != "" ) {
        if (length(idStr) == length(query["idlist"])) {
            query["view"]="";
        }
    }
}

function deleteSelectedRecords(idStr) {
    if (idStr != "") {
        cmd=sprintf("sed -ir \"/\t%s\t(%s)\t/ d\" \"%s\" \"%s.idx\" && "CLEAR_CACHE_CMD,ID,idStr,INDEX_DB,INDEX_DB);
        exec(cmd);
    }
}
function setSelectRecordFields(idStr,field,value,runCatalog) {

    if (idStr != "") {
        if (updateFieldById(idStr,field,value) == 0) {
            if (runCatalog) runCatalog();
        }
    }
}

function runCatalog() {
    exec(RUN_CATALOG_CMD);
}

function updateFieldById(idStr,fieldName,fieldValue) {
    if (idStr != "") {
        cmd=sprintf("sed -ir \"/\t%s\t(%s)\t/ s/(\t%s\t)[^\t]+\t/\\1%s\t/\" \"%s\" \"%s.idx\" && "CLEAR_CACHE_CMD,ID,idStr,fieldName,fieldValue,INDEX_DB,INDEX_DB);
        return exec(cmd);
    }
    return 0;
}

function getSelectedIds(idList\
    i,c,ids,j) {
    delete idList;
    c=0;
    for(i in query) {
        if (isCheckbox(i)) {
            split(substr(i,length(CHECKBOX_PREFIX)+1),ids,"|");
            for(j in ids) {
                idList[c++] = ids[j];
            }
            delete query[i];
        }
    }
    return c;
}
function join(ch,arr,\
    i,out) {
    out="";
    for(i in arr) {
        out=out ch arr[i];
    }
    out=substr(out,1+length(ch));
    return out;
}

#------------------------------------------------------------------------
#----------------ADD HTML RENDERING BELOW -------------------------------
# start_page() is called after backend commands have been run.
# end_page() is called after all capture files have been processed.
#------------------------------------------------------------------------
#This is automatically called at the end of each capture block.
# CAPTURE_LABEL is the label of the block that has just finished.
# Alternatively use gLAST_FILENAME if a direct file was used.
function CAPTURE_END() {
    
    #Reset FS. INDEX_DB overrides this.
    if ( FNR == 1  && FS != " " ) { FS=" " ; $0 = $0 };

    if (gLAST_FILENAME == INDEX_DB) {

        h_comment("INDEX:" db_size );
    }
}

# Following example shows two different ways of processing captured input.

function start_movie_page(_f,_d) {
    print "body { color:white ; background-color:black; }"
    print "td { color:white }"
    print "td.filelist { text-align:center; background-color:#070707; }"
    print "td.list0 { background-color:#000044; }"
    print "font.plot { font-size:"(gFontSize-2)" ; font-weight:normal; }" 
    print "td.list1 { background-color:#000033; }"

    #Unwatched tv
    print "td.ep00 { background-color:#004400; }"
    print "td.ep01 { background-color:#003300; }"
    print ".eptitle { font-size:100% ; font-weight:bold; }"
    print ".proper { color: yellow; }";

    #watched tv
    print "td.ep10 { background-color:#222222; }"
    print "td.ep11 { background-color:#111111; }"

    print "a { color:#aaaaff; }"
    print "h1 { text-align:center; font-size:120%; font-weight:normal; text-decoration:underline; }"
    print "</style>";
    print "</head>";
    print "<body onloadset=\"up\" focuscolor=yellow focustext=black >";
}

#Add the code to start your page in the start_page() function.
function start_page() {

    print "<html><head><title>OverSight Index</title>"
    printDeleteControlsScript();
    print "<style type=\"text/css\">";

    print "font.pageArrow {color:yellow; font-weight:bold; font-size:"(gFontSize)"; }";
    print "font.newFlag {color:yellow; font-weight:bold; font-size:"(gFontSize)"; }";
    print "font.Delete {color:#FF9966; font-weight:normal; }";
    print "font.Ignore {color:#777;}";
    print "font.Mark {color:#AAA;}";
    print "font.Unmark {color:#DDF;}";
    print "font.Remove {color:orange;}";

    print ".iso { color:white ; }"
    print ".img { color:white ; }"
    print ".mkv { color:white ; }"
    print ".avi { color:white ; }"
    print ".mp4 { color:white ; }"
    print "font.watched { color:#999999 ; font-style:italic; }" 

          print "td.tv0 { background-color:#121255;text-align:left;color:yellow; }"
          print "td.tv1 { background-color:#121266;text-align:left;color:yellow;   }"
        print "td.film0 { background-color:#124412;text-align:left; color:yellow;  }"
        print "td.film1 { background-color:#125512;text-align:left; color:yellow;  }"
    print "td.unsorted0 { background-color:#442525;text-align:left;color:yellow;   }"
    print "td.unsorted1 { background-color:#552525;text-align:left;color:yellow;   }"
    print "table.header {	margin:0; border-spacing:1; padding:0 ; border-width:0 ; }"
    print "table.footer {	margin:0; border-spacing:1; padding:0 ; border-width:0 ; }"
    print ".header {background-color:#000005; }"
    print ".footer {background-color:#3333AA; }"

    print "td { font-size:"gFontSize"; font-family:\"arial\";  }"

    if (query["view"] == "movie" || query["view"] == "tv" ) {
        print "table.detail   { margin:0; border-spacing:1; padding:1 ; xborder-width:0 ;  xborder-collapse:collapse;}"
        print "table.listing {margin:0; border-spacing:1; padding:0 ; xborder-width:0 ; xborder-collapse:collapse; }"
        start_movie_page();
        return;
    }
    print ".overview { text-align:center; }"
    print "table.overview {	margin:0; border-spacing:1; padding:0 ; border-width:0 ; }"

    #bar inactive
    print ".filterbar0 {	margin:0; border-spacing:1; padding:0 ; border-width:0 ; }"
    print ".filterbarno0 {	color:#888800; };"
    print ".filterbartxt0 {	color:white; };"
    #bar active
    print ".filterbar1 {	margin:0; border-spacing:1; padding:0 ; border-width:0 ; }"
    print ".filterbarno1 {	color:yellow; font-weight:bold; };"
    print ".filterbartxt1 {	color:#FFFF44; };"
    print ".filterbar1 {	background-color:#3333AA; }"

    print ".match {color:#FF7777; font-weight:bold; }"

    print "body { color:white ; background-color:black; }"
    print "a { color:white ; }"
    print "td { color:white ; }"

    #print "td { font-size:100%; font-family:\"arial\"; }"
    print "td.endtable { background-color:blue; }"
    print ".yellowbutton { color:#FFFF55; background-color:black; font-weight:bold ; text-decoration:none; }";
    print "a.yellowbutton { color:black ; }"

    print ".bluebutton { color:#5555FF; background-color:black; font-weight:normal ; text-decoration:none; }";
    print "a.bluebutton { color:black ; }"

    print ".greenbutton { color:#55FF55; background-color:black; font-weight:normal ; text-decoration:none; }";
    print "a.greenbutton { color:black ; }"

    print ".redbutton { color:#FF5555; background-color:black; font-weight:normal ; text-decoration:none; }";
    print "a.redbutton { color:black ; text-decoration:none; }"

    print "</style>";

    print "</head>";
    #print "<body onloadset=\"filter5\" >";
    if (query[QREG_FILTER] == "") {
        #move cursor to middle of table
        startCell="centreCell";
    } else {
        #move cursor to 5jkl
        startCell="filter5";
    }
    print "<body onloadset=\""startCell"\" focuscolor=yellow focustext=black >";

    #print "ACT="query["action"];
    h_form_start();
    #print h_button("action","submit");
}

function copy_db(source,dest,idx,\
    _i) {
    for(_i in source) {
        dest[_i,idx] = source[_i];
    }
}

function printDeleteControlsScript() {
    print "<script type=\"text/javascript\">"

    print "\
j=0;\
function showDeleteControls(){  \
    if (j == 0 ) {  \
        document.styleSheets[0].cssRules[0].style.visibility=\"visible\";   \
    } else {    \
        document.styleSheets[0].cssRules[0].style.visibility=\"hidden\";    \
    }   \
    j=1-j;  \
}";
    print "</script>";
}
#Split line by tabs, then each tab has name=value so set
# output_arr[name]=value
#if index2 is defined then set
# output_arr[name,index2]=value

function parse_index(output_arr, _i) {

    #print "<br>"$0;
    for(_i = 2 ; _i <= NF ; _i+=2 ) { 
        if ($(_i) != "") output_arr[$(_i)] = $(_i+1);
        #print "<br>"$(_i)"="$(_i+1);
    }
}

function parse_index_merge(output_arr,index2, _i) {

    for(_i = 2 ; _i <= NF ; _i+=2 ) { 
        if ( $(_i) != "") output_arr[$(_i),index2] = $(_i+1);
    }
}

function load_index( _tmpdb,m,pt) {

    if (gFilterRegex == "" ) {

        parse_index_merge(db,db_size);

    } else {

        parse_index(_tmpdb);

        RLENGTH=-1;

        if (!match(tolower(_tmpdb[TITLE]),gFilterRegex) ) { next; }

        if (RLENGTH <= 0) { next; }

        #Allow for initial no word match
        db["rstart",db_size] = RSTART;
        db["rlength",db_size] = RLENGTH;
        copy_db(_tmpdb,db,db_size);
    }
    if (0 && DEBUG) {
        for(jj in db) {
            if (index(jj,SUBSEP db_size)) {
                split(jj,jjj,SUBSEP);
                h_comment("db "jjj[1] "," jjj[2] " = "db[jj]);
            }
        }
    }

    db_size++;
}

function vod_link(title,file,vod_name,vod_number,hrefAttr,class,\
    f,name,_VOD) {

    if (match(tolower(file),"\.(iso|img)$")) {
        _VOD=" file=c   ZCD=2 "hrefAttr;
    } else {
        _VOD=" vod file=c "hrefAttr;
    }
    gsub(/\|/,"<br>",title);
    gsub(/\./," ",title);


    name=file;
    gsub(/.*\//,"",name);
    if (playListStarted == 0 ) {
        printf name "%s|0|0|file://%s|" ,name,file > NMT_PLAYLIST;
        playListStarted = 1;
    } else {
        printf name "%s|0|0|file://%s|" ,name,file >> NMT_PLAYLIST;
    }


    f=url_encode(file);
    if (class != "") {
        return "<a href=\"file://"f"\" name=\""vod_name"\" "_VOD"><font class=\""class"\">"title"</font></a>";
    } else {
        return "<a href=\"file://"f"\" name=\""vod_name"\" "_VOD">"title"</a>";
    }
}

#Add the code to end your page in the end_page() function.
function end_page() {

    if (query["view"] == "" ) {

        end_table_page();

    } else {

        end_movie_page(0);
    }

}

function end_movie_page(idx,
    url) {

    #print "<body>";
    h_form_start();

    print "<table width=100% >";
    print "<tr valign=top>";

    if ( query["view"] == "movie" ) {
        print_poster(idx);
        print "<td>";
        print "<h1><center>"db[TITLE,idx]"</center></h1>";
        program_details(idx);
        print "<hr>";
        movie_listing(idx);
        print "</td>";
    } else {
        print_poster(idx);
        print "<td>";
        print "<h1><center>"db[TITLE,idx]"</center></h1>";
        program_details(idx);
        print "</td>";
        print "</tr>";
        print "<tr>";
        print "<td class=filelist align=center colspan=2>";
        tv_listing(idx);
        print "</td>"
    }
    print "</tr>";
    print "</table>";
    showSelectControls(0,0,0);

    print "</form>";
    print "</body>";

    # Play button - play the list built by the MOVIEFILES clause.
    printf "<a href=\"file:///tmp/playlist.htm?start_url=\" vod=playlist tvid=\"_PLAY\"></a>";
}

function print_poster(idx,\
    url) {
    # Get path to poster.
    if (db[POSTER,idx] != "") {
        if (substr(db[POSTER,idx],1,1) != "/" ) {
            #relative -> absolute
            url=db[FILE,idx];
            sub("[^/]+$",db[POSTER,idx],url);
        }
    }
    print "<td width=30%>";
    print localImageLink(url,db[TITLE,idx],"width="gPosterWidth);
    print "</td>";
}

function program_details(idx, plot) {
    print "<table class=detail width=100%>";
    print "<tr><td class=list0 width=20% align=right>Year:</td>";
    print "<td class=list0>"db[YEAR,idx]"</td></tr>";

    print "<tr><td class=list1 align=right>Cert:</td>";
    print "<td class=list1 >"db[CERT,idx]"</td></tr>";

    print "<tr><td class=list0 align=right>Genre:</td>";
    print "<td class=list0>"db[GENRE,idx]"</td></tr>";

    print "<tr><td class=list0 align=right>Rating:</td>";
    print "<td class=list1>"db[RATING,idx]"</td></tr>";

    plot=db[PLOT,idx];
    if (length(plot) > gPlotLength) plot=substr(plot,1,gPlotLength-3)"...";

    print "<tr><td class=list1 align=right>Plot:</td>";
    print "<td class=list0><font class=plot>"plot"</font></td></tr>";
    print "</table>";
}

function mediaFlag(f,\
    ext) {
    ext=tolower(substr(f,length(f)-2));
     if (index("iso|img|mkv",ext)) {
        return "&nbsp;"iconLink(ext);
    } else if (ext != "avi")  {
        return "<font size=\"-1\">["ext"]</font>";
    }
}

function iconLink(name) {
    return localImageLink(HOME"/images/"name".png","("name")","width=20 border=0 style=\"background-color:#AAAAAA\" ");
}

function localImageLink(path,alt,attrs)  {
    return "<img alt=\""alt"\" src=\""(LOCAL_BROWSER?"file://":SELF"?") path"\" "attrs" />";
}

function movie_listing(idx,\
    parts,style,p,d) {

    style=getFileStyle(idx);

    d=db[FILE,idx];
    sub(/\/[^\/]*$/,"",d);
    h_comment("DIR "d);

    f=substr(db[FILE,idx],length(d)+2);
    h_comment("FILE "f);

    if (query["select"] != "") {
        print selectCheckbox(idx,query["idlist"],db[FILE,idx]);
    } else {
        print vod_link(watchedStyle(idx,f),db[FILE,idx],0,0,"",style);
        split(db[PARTS,0],parts,"/");
        for(p in parts) {
            print "<br>"vod_link(watchedStyle(idx,parts[p]),d"/"parts[p],p,p,"",style);
        }
    }
}

#Loop through index files
function tv_listing(idx\
    _count,_episode,i,r,c,rowTxt,eptitle,vodTxt,actualIndex) {

    #Get the list of episodes and sort.
    #if we were filtering by anything else it would go here.
    _count = 0;

    for(i=0 ; i < db_size; i++) {
        _episode[_count++] = i;
    }
    h_comment("IN COUNT:"db_size);
    h_comment("Season:"query["season"]);
    h_comment("OUT COUNT:"_count);
    heapsort(_count,0EPISODE,1,_episode);

    cols=2
    rows=int((_count-1)/cols)+1;

    print "<table width=100% class=\"listing\" >";
    for(r=0 ; r < rows ; r++) {

        rowTxt = "<tr>";
        for(c=0 ; c < cols ; c++) {

            i = c*rows + r;

            if (i < _count) {

                actualIndex=_episode[i];

                if (query["select"] == "") {
                    width1="6%" ; width3="35%";
                } else {
                    width1="8%" ; width3="38%";
                }
                rowTxt=rowTxt "<td class=ep"db[WATCHED,actualIndex](i%2)" width="width1" >";
                #rowTxt=rowTxt "<td width=6% >";
                if (query["select"] == "") {
                    vodTxt=db[SEASON,actualIndex]"/"db[0EPISODE,actualIndex];
                    vodTxt=watchedStyle(actualIndex,vodTxt);
                    rowTxt=rowTxt vod_link(vodTxt,db[FILE,actualIndex], i,i,"",getFileStyle(actualIndex));
                } else {
                    vodTxt=db[0EPISODE,actualIndex];
                    rowTxt=rowTxt selectCheckbox(actualIndex,db[ID,actualIndex],vodTxt);
                }
                rowTxt=rowTxt "</td>";

                airdate=db[AIRDATE,actualIndex];
                if (airdate=="") {
                    airdate=db[AIRDATEIMDB,actualIndex];
                }

                airdate=shortenMonth(airdate);

                airdate=trim(airdate);

                #Remove the year
                sub(/ *[0-9]+$/,"",airdate);

                gsub(/ /,".",airdate);

                rowTxt=rowTxt "<td class=ep"(i%2)" width=8% >"tolower(airdate)"</td>";

                eptitle = db[EPTITLE,actualIndex];
                if (eptitle == "" ) {
                    eptitle = db[EPTITLEIMDB,actualIndex];
                    if (eptitle == "" ) {
                        eptitle = db[ADDITIONAL_INFO,actualIndex];
                    }
                }
                if (length(eptitle) > 37) {
                    eptitle=substr(eptitle,1,35)"..";
                }

                if (match(tolower(db[FILE,actualIndex]),"\\<proper\\>")) {
                    eptitle=eptitle"&nbsp;<font class=proper>[pr]</proper>";
                }
                eptitle = eptitle mediaFlag(db[FILE,actualIndex]);
                rowTxt=rowTxt "<td width="width3"><font class=eptitle>"eptitle"</font></td>";
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

#Returns style for file which is extension + 0=unwatched or 1=watched eg mkv1
function getFileStyle(idx,\
    style) {
    if (query["view"] == "" ) {
        style=substr(db[OVERVIEW_EXT_LIST,idx],1,3);
    } else {
        style=db[FILE,idx];
        style=tolower(substr(style,length(style)-2));
    }
    return style;
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

#If we have a sparse ordered array wit only some elements, collapse it down and return the size.
function collapseArray(order_arr,minPos,maxPos,\
    newCount,i) {
    newCount=0;
    for (i = minPos ; i <= maxPos ; i++ ) {
        if (i in order_arr ) {
            if (newCount != i ) {
                order_arr[newCount] = order_arr[i];
            }
            newCount++;
        }
    }
    return newCount;
}

function end_table_page(i,t,j,bestIndexSoFar,_P,f,o,maxPos,order_arr) {

    tt=systime();
    f="#"query["sort"]"#";
    o=query["order"];


    h_comment(f" PreSort "db_size" in "(systime()-tt)); tt=systime();
    #Reverse the order index created by catalog.sh add_overview_index()
    maxPos=0;
    if (o == 1) {
        for (i = 0 ; i < db_size ; i++ ) {
            pos=db[f,i];
            order_arr[pos]=i;
            if (pos > maxPos) maxPos=pos;
        }
    } else {
        #Reverse positions
        for (i = 0 ; i < db_size ; i++ ) {
            pos=gGrossIndexSize-db[f,i];
            order_arr[pos]=i;
            if (pos > maxPos) maxPos=pos;
        }
    }

    #TODO this is where we may need to collapse order_arr[] in case of deleted records.
    #TODO this may be unnecessary - not sure yet.
    db_size=collapseArray(order_arr,0,maxPos);

    h_comment("Sorted "db_size" max pos=" maxPos " in "(systime()-tt)); tt=systime();
    if (DEBUG) {
        for (i = 0 ; i < db_size ; i++ ) {
            h_comment(db[TITLE,order_arr[i]]);
        }
    }

    _P=query["page"];
    if (_P == "" ) { _P = 0 };

    showMainTable(db_size,order_arr,gRows,gCols,_P);

    print "</form>";
    print "<font size=-3>"VERSION"</font>";
    print "</body>";
}

function getLatestTimestampForAllSeries(idx,field) {
    return Timestamp[db[TITLE,idx]"\t"db[SEASON,idx]"\t"field];
}
        

# Return a url to same page but with one value changed.
function selfLink(name,value,attributes,title,) {
    return selfLinkMulti(name"="value,attributes,title);
}

# Return a url to same page but with two value changed.
function selfUrl(nameValuePairs, url,i) {
    url=SELF;
    if (nameValuePairs != "") {
        url=url "?"nameValuePairs ;
    }

    nameValuePairs="&"nameValuePairs;


    for(i in query) {
        #exclude colour because it represents an action not a state??
        #Double index for v slight opt.
        if (!index(nameValuePairs,i) && !index(nameValuePairs,"&"i"=") && i != "colour" ) {
            if (query[i] != "") {
                url=url (url == SELF ? "?":"&") i"="query[i];
            }
        } 
    }
    if (index(url,"BLANK")) {
        gsub(/[a-z]+=BLANK[&]?/,"",url);
    }
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

function showMainTable(db_size,idx,rows,cols,page) {


    if ( query["quickmode"] == "" ) { query["quickmode"] = "word"; };
    if ( query["quickmode"] == "word" ) { 
        switchMode = "initials";
    } else {
        switchMode = "word";
    }


    display_count = get_displayable_cells(db_size,idx,rows,cols,page,display_index);


    show_table_header();

    if (display_count < rows * cols ) {
        rows = int( (display_count-1) / cols)+1;
    }
    showTableContents(db_size,display_count,display_index,rows,cols,page);
    showSelectControls(page,page>0,display_count>rows*cols);
}


function selectCheckbox(idx,idList,text,\
    show) {
    if (query["select"] == "Mark") {
        show=(db[WATCHED,idx] == 0);
    } else if (query["select"] == "Unmark") {
        show=(db[WATCHED,idx] == 1);
    } else {
        show = (query["select"] != "") ;
    }
    if (show) {
        return "<input type=checkbox name=\""CHECKBOX_PREFIX idList"\" ><font class="query["select"]">"text"</font>";
    } else {
        return "<font class=Ignore>"text"</font>";
    }
}

function showSelectControls(page,prevPage,nextPage) {
    #print "<A href=\"#\" onclick=\"javascript:showDeleteControls();\">Select Files</a>";
    print "<table class=footer width=100%><tr>";
    if (prevPage) {
        print "<td width=10%>"previousPageControl(page)"</td>";
    } else {
        print "<td width=10%>&nbsp;</td>";
    }
    if (query["view"] != "" ) {
        print "<td>"selfLinkMulti("view=BLANK&idlist=BLANK","name=up","Up")"</td>";
    }
    print "<td><a href=\""SELF"?\" name=\"home\" TVID=\"HOME\">Home</a></td>";
    if (query["select"] == "") {
        if (query[QWATCHED_FILTER] != "W" ) {
            #print "<td>"selfLinkMultiJs("select=Mark","","Mark")"</td>";
            print "<td>"h_colour_button("yellow","select=Mark","Mark")"</td>";
        }
        if (query[QWATCHED_FILTER] != "U" ) {
            print "<td>"selfLinkMultiJs("select=Unmark","","Unmark")"</td>";
        }
        #print "</tr><tr>";
        print "<td>"selfLinkMultiJs("select=Remove","","Remove")"</td>";
        print "<td>"selfLinkMultiJs("select=Delete","","Delete")"</td>";
    } else {
        print "<td><input type=submit name=select value="query["select"]" ></td>"
        print "<td><input type=submit name=select value=Cancel ></td>"
    }
    if (nextPage) {
        print "<td align=right>"nextPageControl(page)"</td>";
    } else {
        print "<td>&nbsp;</td>";
    }
    print "</tr></table>";
}

function option(name,value,text) {
    return "<option value=\""value"\" "(query[name]==value?"selected":"")" >"text"</option>"
}

function showColourLegend() {
    print "<table><tr>";
    print "<td>Key:</td>";
    print "<td class=film0>Movie</td>";
    print "<td class=tv0>TV</td>";
    print "<td class=unsorted0>Unsorted</td>";
    print "</tr><tr>";
    print "<td><font class=i>iso</font></td>";
    print "<td><font class=m>mkv</font></td>";
    print "<td><font class=a>avi</font></td>";
    print "</tr></table>";
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

    sortField=query["sort"];

    if (sortField == TITLE ) {
       sortText="<b><u>Name</u></b><br>Date";
       sortField=INDEXTIME;
       order = -1;
    } else {
       sortText="Name<br><b><u>Date</u></b>";
       sortField=TITLE;
       order = 1;
    }


    print "<td class=redbutton>";
    print h_colour_button("red","page=0&"QTYPE_FILTER"="typeFilter,typeText);

    print "</td><td>";
    print h_colour_button("green","page=0&"QWATCHED_FILTER"="watchedFilter,watchedText);
    print "</td><td>";

    print h_colour_button("blue","page=0&sort="sortField"&order="order,sortText);
    print "</td>";
}

function h_colour_button(colour,nameValuePairs,text) {
    return selfLinkMulti(nameValuePairs"&colour="colour,"tvid=\""colour"\"", "<font class=\""colour"button\">"text"</font>");
}

function show_filter_bar(i,r,c,link,f) {
    filter[1]="([1])"
    filter[2]="([2abc])"
    filter[3]="([3def])"
    filter[4]="([4ghi])"
    filter[5]="([5jkl])"
    filter[6]="([6mno])"
    filter[7]="([7pqrs])"
    filter[8]="([8tuv])"
    filter[9]="([9wxyz])"
    filterBarOn=(query[QREG_FILTER]!="");
    print "<table class=filterbar"filterBarOn">"
    for (r=0 ; r < 3 ; r++ ) {
        print "<tr>";
        for (c=0 ; c < 4 ; c++ ) {
            print "<td>";

            if (c < 3 ) {
                i=r*3+c+1;
                if (i >= 1 && i <= 9 ) {
                    _link="<font class=filterbarno"filterBarOn">"i"</font><font class=filterbartxt"filterBarOn">"substr(filter[i],4,length(filter[i])-5)"</font>";
                    print selfLinkMulti("page=0&"QREG_FILTER"="query[QREG_FILTER]filter[i],"name=\"filter"i"\" tvid=\""i"\"",_link);
                }
            } else if ( c == 3 ) {
                if (r == 0 ) {
                    print selfLinkMulti("page=0&"QREG_FILTER"=","name=\"filter"i"\" tvid=\"0\"","clear");
                } else if (r == 1 ) {
                    f=query[QREG_FILTER];
                    sub(/\([^(]+$/,"",f);
                    print selfLinkMulti("page=0&"QREG_FILTER"="f,"name=\"filter"i"\" tvid=\"0\"","prev");
                }
            }
            print "</td>";
        }
        print "</tr>";
    }
    print "</table>";
}

function show_table_header() {
    #print "<center>";
    print "<table class=header width=100%><tr>"

    if (query[QTYPE_FILTER] == "M" ) {
        banner("Films");
    } else if (query[QTYPE_FILTER] == "T" ) {
        banner("TV Shows");
    } else {
        banner("All Video");
    }
    #printf "Page %d",page+1;
    showSortCells();
    print "<td>";
    show_filter_bar();
    print "</td>";
    print "</tr></table>"
    #print "</center>";
}
function banner(text) {
    print "<td align=left width=20%>";
    print "<font size=\"6\">"text"</font>";
    print "</td>";
}

#Returns array of incdices of displayable cells for the given page. (in output_idx)
#and array size (function result)
#If the array size > rows * cols then there is a next page.
function get_displayable_cells(count,idx,rows,cols,page,output_idx,\
    _P,_R,_C,_I,_DISPLAY_COUNT,_direct_index) {


    split("",output_idx,""); #Clear

    _I=0;
    # We loop through all pages until we get to the required page. This is necessary because the filters
    #will dynamically change the page contents.
    _DISPLAY_COUNT=0;
    #We also check the following page so we know when to display a [Next Page] link.
    for (_P=0 ; _P<=page+1 ; _P++ ) {
        for (_R=0 ; _R<rows ; _R++ ) {
                for (_C=0 ; _C<cols ; _C++ ) {


                    while(_I < count) {
                        _direct_index=idx[_I];
                        if (displayable(_direct_index)) break;
                        _I++;
                    }
                    if (_I < count) {
                        if (_P >= page ) {
                           output_idx[_DISPLAY_COUNT++] = _direct_index;
                           if (_P > page ) {
                               return _DISPLAY_COUNT;
                           }
                       }
                   }
                   _I++;
               }
           }
    }
    return _DISPLAY_COUNT;
}


function previousPageControl(page) {
   if (LOCAL_BROWSER) {
       return selfLinkMultiWithFont("page="(page-1),"tvid=pgup name=pgup1 onfocusload","&lt;=","pageArrow");
   } else {
       return selfLinkMultiWithFont("page="(page-1),"onfocusload","&lt;Prev","pageArrow");
   }
}
function nextPageControl(page) {
   if (LOCAL_BROWSER) {
       return selfLinkMultiWithFont("page="(page+1),"tvid=pgdn name=pgdn1 onfocusload","=&gt;","pageArrow");
   } else {
       return selfLinkMultiWithFont("page="(page+1),"onfocusload","Next&gt;","pageArrow");
   }
}

function showTableContents(db_size,count,idxArr,rows,cols,page, _R,_C,_I,centreRow,centreCell) {

    print "<table class=\"overview\" width=\"100%\" >";

    w=sprintf(" width=%d%%",100/cols);

    _I=0;
    # We loop through all pages until we get to the required page. This is necessary because the filters
    #will dynamically change the page contents.
    for (_R=0 ; _R<rows ; _R++ ) {
        centreRow = (_R == int(rows/2));
        print "<tr>";
        for (_C=0 ; _C<cols ; _C++ ) {

            _displayed=0;
            _I = _C * rows + _R;
            if (_I < count) {

               leftScroll=(page>0 && _C==0);
               rightScroll=(count > rows*cols && _C+1==cols);
               centreCell=centreRow && _C == int(cols/2);

               displayItem(db_size,idxArr,_I,w,(_R+_C)%2,leftScroll,rightScroll,centreCell);
           } else {
               # Draw empty cell
               printf "<td%s></td>",w;
           }
       }
       print "</tr>";
   }
   print "</table>";
}

# Additional filtering should be added here. Eg film only/tv only etc.
function displayable(direct_index,\
    t) {

    #Note Unsorted will display under both Movies and TV
    t=query[QTYPE_FILTER]db[CATEGORY,direct_index];
    return (t!="MT" && t != "TM" );
}

function displayItem(db_size,idxArr,i,widthAttr,chequeredSquareToggle,leftScroll,rightScroll,centreCell,\
    link,_CLASS,_title,_tmp,_url,attr,n,idList,j,s,t,rs,rl,idx) {

    idx = idxArr[i];

    _title=db[TITLE,idx];
    if (gFilterRegex != "") {
        
        rs=db["rstart",idx];
        rl=db["rlength",idx];
        _title = substr(_title,1,rs-1) "<font class=match>" substr(_title,rs,rl) "</font>" substr(_title,rs+rl);
    }

    # Add Certificate if available.
    cert=db[CERT,idx];
    if ( (_tmp=index(cert,":")) > 1  ) {
        _title = _title" ("substr(cert,_tmp+1)")";
    }
    #Get extension letter. .. i=iso / m=mkv / a=avi
    if (query["select"] == "" ) {
        ext=substr(db[OVERVIEW_EXT_LIST,idx],1,3);
        if (index("iso|img",ext)) {
            ext=iconLink(ext);
        } else {
            if (ext == "avi" ) ext="sd";
            ext="<font size=-2>["ext"]</font>";
        }
    }


    #ext="["substr(ext,1,3)"]";

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

    idList = db[ID,idx];

    if (db[CATEGORY,idx] == "T") {

        _CLASS="tv";
        t=url_encode(db[TITLE,idx]);
        s=db[SEASON,idx];
        if (s != "" ) {
            _title = _title " S" s;
        }
        _title = trimTitle(_title);
        _title = _title ext;
        _title=watchedStyle(idx,_title);

        idList=db[OVERVIEW_DETAILIDLIST,idx];
        link=selfLinkMultiWithFont("view=tv&idlist="idList,attr" class=\""_CLASS"\"",_title, getFileStyle(idx));


    } else if (db[CATEGORY,idx] == "M") {

        _CLASS="film";
        _title = trimTitle(_title);
        _title = _title ext;
        _title=watchedStyle(idx,_title);
        link=selfLinkMultiWithFont("view=movie&idlist="db[ID,idx], attr" class=\""_CLASS"\"", _title, getFileStyle(idx));

    } else {

        _CLASS="unsorted";

        #Move cursor to middle if no regex filtering
        if (centreCell && query[QREG_FILTER]=="") {
            n="centreCell";
        } else {
            n=i;
        }
        _title = trimTitle(_title);
        _title = _title ext;
        h_comment("FILE = "db[FILE,idx]);
        _title=watchedStyle(idx,_title);
        link = vod_link(_title,db[FILE,idx],n,i,attr,getFileStyle(idx));
    }

#    if (leftScroll || rightScroll ) { print "<td><table><tr>"; widthAttr=" width=99% "; }
#    if (leftScroll ) print "<td width=1% class=endtable>.</td>";

    printf "\t<td%s class=\"%s%s\">\n",widthAttr,_CLASS,chequeredSquareToggle;
    if (query["select"] != "") {
        print selectCheckbox(idx,idList,_title);
    } else {
        print link;
    }
    print "</td>";

#    if (rightScroll ) print "<td width=1 class=endtable>.</td>";
#    if (leftScroll || rightScroll ) print "</tr></table></td>";
}

function watchedStyle(idx,txt) {
    if (db[WATCHED,idx]) return "<font class=watched>"txt"</font>";
    if (NOW - db[INDEXTIME,idx] < 1000000 ) return "<font class=newFlag>"txt"</font>";
    #if (NOW - db[INDEXTIME,idx] < 1000000 ) return "<font class=newFlag>#</font>"txt;
    return txt;
}

function trimTitle(t) {
    if (length(t) > 50 ) {
        t=substr(t,1,48) " ..";
    }

#    while (match(t,"[a-zA-Z0-9]{15,}")) {
#        t=substr(t,1,RSTART+7)"-"substr(t,RSTART+8);
#    }
    return t;

}

#%%%%%%%%%%%% NO CHANGE TO ANY FUNTIONS BELOW HERE %%%%%%%%%%%%%%%%%%%%%%

# The FORM_INPUT is finished. Now we can run the application backend.
function INPUT_CHANGE() {

   h_comment("END PHASE elapsed=" systime()-gTime);
   gTime=systime();

    if (NR == 1) {
        # All initial command line variables have been loaded. We can start.
        START_PRE_FORM();
    }
    if (FORM_INPUT_END == 1 ) {

        FORM_INPUT_END=0;
        START_POST_FORM();
    }
    if ( FNR==1 && FS!=" " ) { FS=" " ; $0 = $0 ; }



    if (FILENAME == "'$FORM_INPUT'" ) {

        init_read_post_data();
    }

    CAPTURE_END();
    CAPTURE_LABEL="";

    if (gLAST_FILENAME != "") {
        gLAST_FILENAME="";
    }

    if (FILENAME != "'$DUMMY_ONE_LINE_FILE'" ) {
        if ( index(FILENAME,CAPTURE_PREFIX) == 1 ) {
            CAPTURE_LABEL=substr(FILENAME,length(CAPTURE_PREFIX));
            CAPTURE_LABEL=substr(CAPTURE_LABEL,index(CAPTURE_LABEL,"_")+1);
        } else {
            CAPTURE_LABEL=FILENAME;
        }
        gLAST_FILENAME = FILENAME;
    } else {
        nextfile;
    }
    h_comment("\t\t STARTING "FILENAME  );
    gTICKS = systime();
}


END {
    h_comment("\t\t FINISHED "FILENAME" in " (systime()-gTICKS)  ); gTICKS=systime();
    end_page();
    h_comment("\t\t FINISHED END in " (systime()-gTICKS)  ); gTICKS=systime();
    clean_capture_files();
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
    #if (index(text,"(")) { gsub(/\(/,"%40",text); }
    #if (index(text,")")) { gsub(/\)/,"%41",text); }
    if (index(text,"[")) { gsub(/\[/,"%5B",text); }
    if (index(text,"]")) { gsub(/\]/,"%5D",text); }
    if (index(text,"+")) { gsub(/[+]/,"%43",text); }

    return text;
}

function url_decode(str, _I,_START) {
  _START=1;
  #print "URLIN:" str;
if (0) {
  if (index(text,"%3F")) { gsub(/[?]/,"?",text); }
  if (index(text,"%26")) { gsub(/[&]/,"&",text); }
  if (index(text,"%20")) { gsub(/ /," ",text); }
  if (index(text,"%3A")) { gsub(/:/,":",text); }
  if (index(text,"%3D")) { gsub(/=/,"=",text); }
  if (index(text,"%40")) { gsub(/\(/,"(",text); }
  if (index(text,"%41")) { gsub(/\)/,")",text); }
  if (index(text,"%5B")) { gsub(/\[/,"[",text); }
  if (index(text,"%5D")) { gsub(/\]/,"]",text); }
  if (index(text,"%43")) { gsub(/[+]/,"+",text); }
}
  while ((_I=index(substr(str,_START),"%")) > 0) {
      _I  = (_START-1)+_I;
      c=substr(str,_I+1,2); # hex digits
      c=sprintf("%d",0+( "0x" c )) # Decimal
      c=sprintf("%c",0+c) # Char
      str = substr(str,1,_I-1) c substr(str,_I+3);
      _START = _I+1;
  }
  #print "URLOUT:" str; 
  return str;
}

function parse_query_string(str) {
    # Note that each nzb action has format annn=action 
    # and if there is a a_nnnn=Go then nnnn is the current action.
    # However this may be changed to a mult-action format.
    split(str,clauses,"&");
    for(i in clauses) {
        #TODO Slight bug - cant cope with multi - values.
        split(clauses[i],clause,"=");
        query[url_decode(clause[1])]=url_decode(clause[2]);
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

function SEND_COMMAND_TEXT(cmd) {
    return "\"'"$HOME"'/oversight.sh\" SAY "cmd;
}

# Note we dont call the real init code until after tcommand line variables are read.
BEGIN {
    TVMODE="'"$TVMODE"'";
    gTICKS=systime();
    LOCAL_BROWSER=(ENVIRON["REMOTE_ADDR"] == "127.0.0.1" )

    if (!LOCAL_BROWSER) TVMODE=7;

    if (TVMODE < 3 ) {
        gFontSize=18; gRows=9; gCols=2; gPosterWidth=250;   #SD
        gPlotLength=200;
    } else if (TVMODE % 3 == 1 ) {
        gFontSize=18; gRows=15 ; gCols=2; gPosterWidth=300; #720
        gPlotLength=500;
    } else {
        gFontSize=22; gRows=20 ; gCols=2; gPosterWidth=350; #1080
        gPlotLength=500;
    }

    METHOD=toupper(ENVIRON["HTTP_METHOD"])
    CAPTURE_COUNT=0;
    POSTER_FILE="_poster.jpg";

    CLEAR_CACHE_CMD = " rm -f -- /tmp/catalog.cache/* ";
    RUN_CATALOG_CMD = SEND_COMMAND_TEXT(" \"'"$HOME"'/catalog.sh\" FORCE ");

    INITIAL_ARGC=ARGC;

    if (METHOD == "GET" ) {
        parse_query_string(ENVIRON["QUERY_STRING"]);
    }
    #SELF=ENVIRON["SCRIPT_NAME"];
    SELF="'"$0"'";
    if (1||LOCAL_BROWSER) {

        #Get last bit of path    
        split(SELF,path,"/"); for(p in path ) { ; } ; SELF = path[p];

        SELF=HOME"/"SELF;
        SELF=replace(SELF,"/share/","http://localhost.drives:8883/HARD_DISK/");
        SELF=replace(SELF,"/opt/sybhttpd/localhost.drives","http://localhost.drives:8883");

    } else {
        sub(/.*\//,"./",SELF);
    }
}


# This is called after command line variables are read but before form processing.
function init_read_post_data() {


    boundary=ENVIRON["POST_BOUNDARY"]
    post_type=ENVIRON["POST_TYPE"]



    
    crlf=1
    unix=0
    in_data=-1;
    start_data=-2;
    filename="";
    name="";
}

# Process the POST data into query string. No need to change this block
FILENAME == "'$FORM_INPUT'" {
    if ( counter >= 0 ) {  counter++  ; }

    if ( METHOD=="POST" && post_type == "application/x-www-form-urlencoded" ) {
        gsub(/[^:]+:/,"");
        parse_query_string($0);

    } else if ( index($1,ENVIRON["POST_BOUNDARY"]) ) {

        #Process outging item
        if (filename != "" ) {
            close(filename);
            cmd=sprintf("chown %s \"%s\"",ENVIRON["UPLOAD_OWNER"],filename);
            system(cmd);
        } else if (name != "") {
            query[name]=value;
        }

        #Start next item
        counter=0;
        filename="";
        name="";
        value="";

    } else if (index($0,"Content-Disposition: form-data; name=")==1 && (counter ==1)) {

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
        #print "CONTENT: $0"
        next;
    } else if (counter>0 && match($0,"^\r$")) {
        #print "END OF HEADER";
        counter=start_data; 
        next;
    } else if ( counter<0 ) {
        if (format==crlf) {
          sub(/\r$/,"");
        }
      if (filename != "") {
          printf "%s\n",$0 >> filename;
      } else if (counter == start_data) {
          value=$0;
      } else {
          value=sprintf("%s\n%s",value,$0);
      }
      counter=in_data;
      #print "DATA";
      next;
    }
}

#--------------------------------------------------------------------
# Convinience function. Create a new file to capture some information.
# This is then added to awk arguments and should be picked up with a 
# new rule FILENAME == xxx { }
# At the end capture files are deleted.
#--------------------------------------------------------------------
function CAPTURE_FILE_NAME(label) {
    return CAPTURE_NAME[label];
}
function NEW_CAPTURE_FILE(label, CAPTURE_FILE) {
    CAPTURE_FILE = CAPTURE_PREFIX "." CAPTURE_COUNT "_" label;
    CAPTURE_COUNT++;
    CAPTURE_LIST=CAPTURE_LIST" "CAPTURE_FILE;
    CAPTURE_NAME[label]=CAPTURE_FILE;
    h_comment("############ NEW CAPTURE FILE "label" ############");
    APPEND_CONTENT(CAPTURE_FILE);
    return CAPTURE_FILE;
}

function APPEND_CONTENT(file) {

    #If last file is a dummy file then overwrite it (unless it is the current file!)
    if (ARGIND+1 < ARGC ) {
        if (ARGV[ARGC-1] == "'"$DUMMY_ONE_LINE_FILE"'" ) {
            ARGC--;
        }
    }

    h_comment("Queue content : "file);
    ARGV[ARGC++] = file;
    # We always add the dummy to prevent the END block firing too soon.
    # We can now add more functions during each block transition. CAPTURE_END()
    ARGV[ARGC++] = "'"$DUMMY_ONE_LINE_FILE"'"; 
}

function clean_capture_files() {
    if  (CAPTURE_LIST != "" ) {
        system("rm -- "CAPTURE_LIST);
    }
}


#---------------------------------------------------------------------
#-------------------------HTML FUNCTIONS -----------------------------
#---------------------------------------------------------------------
#Make button labels the same width
function h_button(name,value) {
    return sprintf("<input class=\"btn\" type=\"submit\" name=\"%s\" value=\"%s\">\n",name,value);
}

# create a link passing a get parameter
function h_link(name,value,label) {
    return sprintf("<a href=\"?%s=%s\">%s</a>",name,url_escape(value),label);
}

# create a link passing 2 get parameters
function h_link2(name,value,name2,value2,label) {
    return sprintf("<a href=\"?%s=%s&%s=%s\">%s</a>",name,url_escape(value),name2,url_escape(value2),label);
}
function url_escape(text) {
    gsub(/ /,"%20",text);
    return text;
}

function h_form_start() {
    #printf "<form action=\"%s\" enctype=\"multipart/form-data\" method=\"%s\">\n",SELF,METHOD;
    printf "<form action=\"%s\" enctype=\"multipart/form-data\" method=\"%s\">\n",selfUrl(""),METHOD;
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
    #print "<!-- " html_encode(msg) "-->"
    if (DEBUG) {
        print "<!-- " msg "-->"
    }
}

#---------------------------------------------------------------------
# HEAPSORT from wikipedia --------------------------------------------
#---------------------------------------------------------------------
# Adapted to sorts the data via the index array.
function heapsort (count, fieldName,fieldOrder,idx,\
    end,tmp) {
    heapify(count,fieldName,fieldOrder,idx);
    end=count-1;
    while (end > 0) {
        tmp=idx[0];idx[0]=idx[end];idx[end]=tmp;
        end--;
        siftdown(fieldName,fieldOrder,idx,0,end);
    }
}
function heapify (count, fieldName,fieldOrder,idx,\
    start) {
    start=int((count-2)/2)
    while (start >= 0) {
        siftdown(fieldName,fieldOrder,idx,start,count-1);
        start--;
    }
}
function siftdown (fieldName,fieldOrder,idx,start,end,\
    root,child,tmp) {
    root=start;
    while(root*2+1 <= end) {
        child=root*2+1
        if (child+1 <=end && compare(fieldName,fieldOrder,idx,child,child+1) <= 0) {
            child++;
        }
        if (compare(fieldName,fieldOrder,idx,root,child) > 0) {
            return
        }
        tmp=idx[root];idx[root]=idx[child];idx[child]=tmp;
        root=child;
    }
}
#Return true if idx1 < idx2 (if idx1 >= idx2 return 0)
function compare(fieldName,fieldOrder,idx,idx1,idx2) {

    if  (db[fieldName,idx[idx1]] > db[fieldName,idx[idx2]]) {
       return fieldOrder;
   } else {
       return -fieldOrder;
   }
}

' PID=$$ NOW=`date +%Y%m%d%H%M%S` HOME=$HOME METHOD=$METHOD DEBUG=$DEBUG "INDEX_DB=$INDEX_DB" "$FORM_INPUT" FORM_INPUT_END=1 "$DUMMY_ONE_LINE_FILE" "$DUMMY_ONE_LINE_FILE" 2>&1 
}




case "$TEMP_FILE$DEBUG" in
    0)
        case "$QUERY_STRING" in
            *cache=0*) CACHE_ENABLED=0 ;;
            *) CACHE_ENABLED=1 ;;
        esac
        ;;
    *) CACHE_ENABLED=0;
esac

CACHE_ENABLED=0 #until fixed

case "$REMOTE_ADDR" in
    127.0.0.1) LOCAL_BROWSER=1 ;;
    *) LOCAL_BROWSER=0 ;;
esac

PLAYLIST=/tmp/playlist.htm

if [ "$CACHE_ENABLED" -eq 1 ] ; then
    cacheId="$TVMODE$LOCAL_BROWSER-$QUERY_STRING" 
    case "$cacheId" in 
        */*) cacheId=`echo "$cacheId" | sed 's,/,_,g'` ;;
    esac
    cachedPage="$CACHE_DIR/page-$cacheId" 
    cachedList="$CACHE_DIR/list-$cacheId" 

    if [ ! -f "$cachedPage" ]; then
        if [ ! -d "$CACHE_DIR" ] ; then
            mkdir -p "$CACHE_DIR" 
            chown $OWNER "$CACHE_DIR"
        fi
        if MAIN_PAGE > "$cachedPage" 2>&1 ; then
            cp "$PLAYLIST" "$cachedList"
            chown $OWNER "$cachedPage" "$cachedList"
        else
            rm -f -- "$cachedPage"
        fi
    fi
    cat "$cachedPage"
    cp "$cachedList" "$PLAYLIST"
else
    MAIN_PAGE
fi


# vi:sw=4:et:ts=4
