#!/bin/sh --
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

# REAL SCRIPT FOLLOWS
#--------------------------------------------------------------------------
#!/bin/sh
# 30/11/2008
# TV AWK INTERFACE
# This script is horrendous. My comment!
# Pushing limits of awks usability. Next time I'll use <insert any other scripting language here>
#
# TODO PLOT INFO FROM TV.COM via EPGUIDE LINK
#
#TODO Preserve WATCHED and INDEXTIME fields when updating.
#TODO When parsing file time if month is later, or month same and date later,  then current then year--
#TODO should check write permissions to nfo file - not urgent

# (c) Andy Lord andy@lordy.org.uk #License GPLv3

DEBUG=0
VERSION=20090112-1
EXE=$0
while [ -L "$EXE" ] ; do
    EXE=$( ls -l "$EXE" | sed 's/.*-> //' )
done
HOME=$( echo $EXE | sed -r 's|[^/]+$||' )
HOME=$(cd "${HOME:-.}" ; pwd )

OWNER=nmt
GROUP=nmt

INDEX_DB="$HOME/index.db"
if [ ! -s "$INDEX_DB" ] ; then
    echo "#Index" > "$INDEX_DB"; #There must always be one line!
    chown $OWNER:$GROUP "$INDEX_DB"
fi

#List of Countries to use for certification.
CERTIFICATE_COUNTRY_LIST="UK:USA:Ireland";
#List of Countries to use for title in order of preference. (Only main page is searched)
TITLE_COUNTRY_LIST="USA:UK";

#DEFAULT_TV_FILE_FMT="/share/Tv/{:TITLE:}{ - Season :SEASON:}/{:TITLE:}{.s:0SEASON:}{e:0EPISODE:}{.:EPTITLE:}{:EXT:}"
DEFAULT_TV_FILE_FMT="/share/Tv/{:TITLE:}{ - Season :SEASON:}/{:NAME:}"
DEFAULT_FILM_FOLDER_FMT="/share/Movies/{:TITLE:}{ - :CERT:}"

IGNORENFO=0
WRITENFO=0
FOLDERTITLES=0
FORCE=0
FOLDER_COUNT=0
FOLDER_LIST=""

if [ -f "$HOME/catalog.cfg" ] ; then
    . "$HOME/catalog.cfg"
fi


for ARG in "$@" ; do
    echo "[INFO] ARG [$ARG]"
    case "$ARG" in 
        #Ignore existing nfos.
        WRITENFO) WRITENFO=1 ;;
        IGNORENFO) IGNORENFO=1 ;;
        FOLDERTITLES) FOLDERTITLES=1 ;;
        DEBUG) DEBUG=1 ;;
        FORCE) FORCE=1 ;;
        RENAME)
            TV_FILE_FMT="$DEFAULT_TV_FILE_FMT"
            FILM_FOLDER_FMT="$DEFAULT_FILM_FOLDER_FMT"
            ;;
        TV_FILE_FMT=*)
            TV_FILE_FMT="$ARG" 
            ;;
        FILM_FOLDER_FMT=*)
            FILM_FOLDER_FMT="$ARG" ;;
        *)
            if [ -d "$ARG" ] ; then
                ARG=$( cd "$ARG" ; pwd )
                FOLDER_LIST="$FOLDER_LIST	$ARG";
                FOLDER_COUNT=$(($FOLDER_COUNT + 1))
            else
                echo "[WARNING] Missing $ARG"
                exit
            fi
            ;;
        esac
done
if [ "$FORCE" = "0" -a "$FOLDER_LIST" = "" ] ; then  
    cat<<USAGE
____________________________________________________________________________________________________________________    
To simply index all files in a folder:

        $0 Folder

        This is usually all that is needed. The new oversight viewer will take care of showing nice names to the user.
____________________________________________________________________________________________________________________    
Other options 
    IGNORENFO - dont look in NFO for any infomation
    WRITENFO  - create an nfo file if there wasnt one - useful if you are going to rename files.
    DEBUG     - lots of logging
    FORCE     - Run even if no folders. Usually to tidy database.
    FOLDERTITLES - Use the Folder title as the title.
____________________________________________________________________________________________________________________    
To index all files in a folder and rename the TV files using a custom naming scheme, use the fields
    {TITLE} {SEASON} {EPISODE} {0SEASON} {0EPISODE} {EPTITLE} {INFO} {NAME} {BASE} {EXT}
    {INFO} is any additional info from the file name.
    {NAME} is original file name.
    {BASE} is original file name without extension.

        Eg.
        $0 Folder "TV_FILE_FMT=/share/Tv/{TITLE} - Season {SEASON}/{NAME}"
        $0 Folder "TV_FILE_FMT=/share/Tv/{TITLE} - Season {SEASON}/{TITLE}.s{0SEASON}e{0EPISODE}.{EPTITLE}{EXT}"
____________________________________________________________________________________________________________________    
To index all files in a folder and rename the TV files using the default naming scheme:(which happens to be
the same as the first example)
        $0 Folder "TV_FILE_FMT=DEFAULT
____________________________________________________________________________________________________________________    
To index all files in a folder and rename the films' FOLDER using a custom naming scheme, use the fields
    {TITLE} {CERT} {GENRE} {YEAR} {NAME} {BASE} {EXT}
    {NAME} is original file name.
    {BASE} is original file name without extension.

        $0 Folder "FILM_FOLDER_FMT=/share/Movies/{TITLE} - {CERT}"
____________________________________________________________________________________________________________________    
To index all files in a folder and rename the TV files using the default naming scheme: (which happens to be
the same as the above example)

        $0 Folder TV_FILE_FMT=DEFAULT
____________________________________________________________________________________________________________________    
If renaming files its good practice to just change the folder name but leave the filename unchanged.
-This makes it easier to retrieve file information from the internet if you have to rebuild the index.

USAGE
    exit 0
fi

if [ "$FOLDER_LIST" = "FORCE" ] ; then
    FOLDER_LIST=
fi


#NZB="$2" #Nzb name

MAIN() {

    CLEAN_TMP

    # We need to add a dummy input file to force the users 'START()'
    # to run after then FORM_INPUT but before the END clause.
    # It must run before the END() so that new file arguments can be pushed
    # onto ARGV.
    DUMMY_ONE_LINE_FILE=/tmp/awk.$$.0_DUMMY
    echo "#DUMMY" > "$DUMMY_ONE_LINE_FILE"
    UNPAK_CFG="$HOME/unpak.cfg"
    if [ ! -f "$UNPAK_CFG" ] ; then 
            #Look at the old unpak file - to make sure we dont index pin folder.
            UNPAK_CFG="/share/.nzbget/unpak.cfg"
            if [ ! -f "$UNPAK_CFG" ] ; then 
                #Get example file - in case oversight installed before unpak.sh
                UNPAK_CFG="$UNPAK_CFG.example"
            fi
    fi

    Q="'"
    #This awk script will add files to its input as it is processing.
    # see APPEND_CONTENT and NEW_CAPTURE_FILE functions.

    # Some awk "features" to elaborate upon one day:
    # There is no EOF callback.. instead add
    # FNR==1 { callback() ; }
    #
    # END { callback() ; }

    # However a) this fails with empty files.
    # b) If in the 'END' block, no more files can be appended.
    #
    # Cue lots of 'logic' to deal with above two issues.
    # Mainly in functions call CAPTURE_xxx etc.
    #
    # Also command line vars are not set in the BEGIN block.
    # I have a 'START() function called when NR=FNR=1
    #
    # Other tips:
    # use index before match
    # clear arrays using split("",array,"")
        awk '
#catalog.awk

function DEBUG(x) {
    if ( DEBUG ) {
        print "[DEBUG] '$LOG_TAG' "x;
    }
}

# Keep this as the first rule
FNR == 1 { FINISHED_FILE(); }
#{ print CAPTURE_LABEL"|"$0 }
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#%%%%%%%%%%%%%%%%%%%%%%%NO CHANGE ABOVE HERE %%%%%%%%%%%%%%%%%%%%%%%%%%%%
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

CAPTURE_LABEL=="IMDBPAGE" {
    processImdbLine();
    next;
}

# Load UNPAK configuration
FILENAME == "'"$UNPAK_CFG"'" {
    if ((i=index($0,"#")) > 0) {
        $0 = substr($0,1,i-1);
    }
    sub(/ *= */,"=",$0);
    sub(/^ +/,"",$0);
    sub(/ +$/,"",$0);
    sub(/=\"/,"=",$0);
    sub(/\"$/,"",$0);
    if (match($0,"^[A-Za-z0-9_]+=")) {
        n=substr($0,1,RLENGTH-1);
        v=substr($0,RLENGTH+1);
        unpak_option[n] = v;
        ##DEBUG(sprintf("%s = [%s]",n,v));
        if (n == "unpak_nmt_pin_root" ) {
            unpak_nmt_pin_root=v;
        }
        next;
    }
    next;
}

# Note we dont call the real init code until after the command line variables are read.
BEGIN {
    gTime=ELAPSED_TIME=systime();
    NO_CAPTURE_LABEL="*\t@\t@\t*"; #Some unlikely value
    CAPTURE_LABEL=NO_CAPTURE_LABEL;
    gCertificateCountryString="'"$CERTIFICATE_COUNTRY_LIST"'";
    gsub(/ /,"%20",gCertificateCountryString);
    split(gCertificateCountryString,gCertificateCountries,":");

    EXTENSIONS1_RE="\.(avi|mkv|mp4|ts|m2ts|xmv|mpg|mpeg)$";
    EXTENSIONS2_RE="\.(img|iso)$";

    ENDPAGE_MARKER="E_N_D_P6_A_G_E_5344223";

    gTitleCountryString="'"$TITLE_COUNTRY_LIST"'";
    split(gTitleCountryString,gTitleCountries,":");

    #Min number of IMDB links required in search results.
    MIN_IMDB_LINK_REPETITIONS=2;

    getMonth["Jan"]=1; getMonth["Feb"]= 2; getMonth["Mar"]= 3; getMonth["Apr"]= 4;
    getMonth["May"]=5; getMonth["Jun"]= 6; getMonth["Jul"]= 7; getMonth["Aug"]= 8;
    getMonth["Sep"]=9; getMonth["Oct"]=10; getMonth["Nov"]=11; getMonth["Dec"]=12;

    #For caps function
    ABC_STR="ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    abc_str=tolower(ABC_STR);
    split(ABC_STR,ABC,"");
    split(abc_str,abc,"");

    TV_FILE_FMT="'"$TV_FILE_FMT"'";
    FILM_FOLDER_FMT="'"$FILM_FOLDER_FMT"'";

    DEBUG("TV_FILE_FMT="TV_FILE_FMT);
    DEBUG("FILM_FOLDER_FMT="FILM_FOLDER_FMT);

    sub(/^TV_FILE_FMT=/,"",TV_FILE_FMT);
    sub(/^FILM_FOLDER_FMT=/,"",FILM_FOLDER_FMT);
    if (TV_FILE_FMT == "DEFAULT" ) {
        TV_FILE_FMT = "'"$DEFAULT_TV_FILE_FMT"'";
    }
    if (FILM_FOLDER_FMT == "DEFAULT" ) {
        FILM_FOLDER_FMT = "'"$DEFAULT_FILM_FOLDER_FMT"'";
    }
    
}

function caps(text) {
    #First letter
    if ((j=index(abc_str,substr(text,1,1))) > 0) {
        text = ABC[j] substr(text,2);
    }
    #Other letters.
    for(i in ABC) {
        while ((j=index(text," " abc[i] )) > 0) {
            text=substr(text,1,j) ABC[i] substr(text,j+2);
        }
    }
    return text;
}

function START() {

   DEBUG("START");
    file_count=0;
    CAPTURE_PREFIX="/tmp/catalog."

    overview_count=0;

    #DB fields should start with underscore to speed grepping etc.
    ID=dbField("_id","ID",0);

    #List of all related detail items. ie tv shows in same season
    OVERVIEW_DETAILIDLIST=dbField("_did" ,"Ids",0);
    OVERVIEW_EXT_LIST = dbField("_ext","Extensions",0);

    WATCHED=dbField("_w","Watched",0) ;
    ACTION=dbField("_a","Next Operation",0); # ACTION Tell catalog.sh to do something with this entry (ie delete)
    PARTS=dbField("_pt","PARTS","");
    FILE=dbField("_F","FILE","");
    NAME=dbField("_N","NAME","");
    DIR=dbField("_D","DIR","");
    AKA=dbField("_K","AKA","");
    CATEGORY=dbField("_C","Category",0);
    ADDITIONAL_INFO=dbField("_ai","Additional Info","");
    YEAR=dbField("_Y","Year",0) ;
    TITLE=dbField("_T","Title",".titleseason") ;

    SEASON=dbField("_s","Season",0) ;
    EPISODE=dbField("_e","Episode","");
    0SEASON=dbField("_s0","0SEASON","");
    0EPISODE=dbField("_e0","0EPISODE","");

    GENRE=dbField("_G","Genre",1) ;
    RATING=dbField("_r","Rating","");
    CERT=dbField("_R","CERT",1);
    PLOT=dbField("_P","Plot","");
    URL=dbField("_U","URL","");
    POSTER=dbField("_J","Poster","");

    DOWNLOADTIME=dbField("_DT","Downloaded",1);
    INDEXTIME=dbField("_IT","Indexed",1);
    FILETIME=dbField("_FT","Modified",1);

    SEARCH=dbField("_SRCH","Search URL","");
    PROD=dbField("_p","ProdId.","");
    AIRDATE=dbField("_ad","Air Date","");
    TVCOM=dbField("_tc","TvCom","");
    EPTITLE=dbField("_et","Episode Title","");
    EPTITLEIMDB=dbField("_eti","Episode Title(imdb)","");
    AIRDATEIMDB=dbField("_adi","Air Date(imdb)","");
    NFO=dbField("_nfo","NFO","");

    


    THIS_YEAR=substr(NOW,1,4);

    FOLDER_LIST="'"$FOLDER_LIST"'";

    sub(/^\t/,"",FOLDER_LIST);
    sub(/\t$/,"",FOLDER_LIST);

    FOLDER_POINTER=1;
    split(FOLDER_LIST,FOLDER_ARR,"\t");

    for(f in FOLDER_ARR) {
       DEBUG("Folder:\t"FOLDER_ARR[f]);
    }
    gMovieFileCount = 0;
    gMaxDatabaseId = 0;

#    for(f in FOLDER_ARR) {
#        indexFolder(FOLDER_ARR[f]);
#    }

}

#Setup dbField identifier, pretty name , and overview field.
#overview == "" : dont add to overview
#overview == 0 : add to overview
#overview == 1 : add to overview and create index using field "key"
#overview == field2 : add to overview and create index using field "field2"
function dbField(key,name,overview) {
    gDbFieldName[key]=name;
    if (overview != "" ) {
        if (overview == 1 ) {
            OVERVIEW_FIELDS[key] = key;
        } else {
            OVERVIEW_FIELDS[key] = overview;
        }
    }
    return key;
}

function indexFolder(folder) {
    if (folder != "") {

        #Remove trailing slash. This ensures all folder paths end without trailing slash
        if (folder != "/" ) {
            gsub(/\/+$/,"",folder); 
        }
        gCurrentFolder=folder;
       DEBUG("LISTING "folder);

        #We use ls -R instead of find to get a sorted list.
        #There may be some issue with this.

        #First file /proc/$$ is to check ls format
        #The slash is appended again to get past any initial sym link
        exec("ls -Rl /proc/"PID" \""folder"/\" > "NEW_CAPTURE_FILE("MOVIEFILES"));
    }
}

function exec(cmd, err) {
   DEBUG("SYSTEM : "cmd);
   if ((err=system(cmd)) != 0) {
      ERROR("Return code "err" executing "cmd) ;
  }
  return err;
}

#------------------------------------------------------------------------
#This is automatically called at the end of each capture block.
# CAPTURE_LABEL is the label of the block that has just finished.
# Alternatively use gLAST_FILENAME if a direct file was used.
function CAPTURE_END() {

   #DEBUG("CAPTURE_LABEL = "CAPTURE_LABEL);

    if (CAPTURE_LABEL == "MOVIEFILES" ) {

        get_imdb_urls_from_nfos();

    }

    DEBUG("ARGIND = "ARGIND" ARGC="ARGC);
    if (match(CAPTURE_LABEL,"[Nn][Ff][Oo]$")) {
        # Still not found imdb link. Now search internet.
        searchInternet(idx);
    }


    if (isLastFile()) {

       DEBUG("No captures pending");
       delete FILE_HASH;

       #Probe for missing files before doing relocations.
       #as this uses the gMovieFilePresent[] array.
       if (isLastFile() && FOLDER_ARR[FOLDER_POINTER] != "" ) {

            DEBUG("Moving to next folder");
            indexFolder(FOLDER_ARR[FOLDER_POINTER++]);

       }
       if (isLastFile() && gStep["PROBE"]++ == 0)  {

            DEBUG("Probing for missing files");
            probe_missing_files(); #This will start new captures.

       }
       if (isLastFile() && gStep["RELOCATE"]++ == 0)  {

            DEBUG("final");
            time("fixTitles");
            fixTitles();
            time("get_best_episode_title");
            get_best_episode_title();
            if ( "'$WRITENFO'" == 1 ) {
                time("generate_nfo_files");
                generate_nfo_files();
            }
            time("relocate_files");
            relocate_files();

            deleteQueuedFiles(DATABASE_ARRAY,file_count);

            append_new_index(INDEX_DB".new");
            DEBUG("START OVERVIEW");
            APPEND_CONTENT(INDEX_DB".new");

        }
        if (isLastFile() && gStep["FINISH"]++ == 0)  {

            time("add_overview_indices");
            add_overview_indices(overview_db,overview_count);
            time("write_overview");

            write_overview(overview_db,overview_count,INDEX_DB".idx.new");
            time("copy");

        }
    }
}

FILENAME == INDEX_DB".new" {

    if ( FNR==1 ) {
        if (FS != "\t") {
            FS="\t" ; $0 = $0 ;
        }
        overview_count=0;
    }

    if (substr($0,1,1) == "\t") {

        # Read the fields -------------

        split("",fields,"");
        for(i=2 ; i < NF ; i+= 2 ) {
            fields[$i] = $(i+1);
        }

        keep=0;
        id=tolower(fields[TITLE]"\t"fields[SEASON]);

        ext=fields[FILE];
        ext=tolower(ext);
        sub(/.*\./,"",ext);

        if (fields[CATEGORY] != "T" ) {
            keep=1;
            fields[OVERVIEW_EXT_LIST]=ext;
        } else {
            if (( id in TvSeasionIdList )) {
                TvSeasionIdList[id]=TvSeasionIdList[id] "|" fields[ID];
                if (index(TvSeasionExtList[id],ext) == 0) {
                    TvSeasionExtList[id]=TvSeasionExtList[id] "|" ext;
                }

                checkTimestamp(FILETIME,fields,TvSeasonTimestamp,id);
                checkTimestamp(INDEXTIME,fields,TvSeasonTimestamp,id);
                checkTimestamp(DOWNLOADTIME,fields,TvSeasonTimestamp,id);

                if (!fields[WATCHED]) {
                    TvSeasionWatched[id]=0;
                }
            } else {
                keep=1;
                TvSeasionIdList[id]=fields[ID];
                TvSeasionExtList[id]=ext;
                TvSeasionWatched[id]=fields[WATCHED];

                TvSeasonTimestamp[FILETIME,id]=fields[FILETIME];
                TvSeasonTimestamp[INDEXTIME,id]=fields[INDEXTIME];
                TvSeasonTimestamp[DOWNLOADTIME,id]=fields[DOWNLOADTIME];
            }
        }

        if (keep) {

            sub(/^[Tt]he /,"",id);
            overview_db[".titleseason",overview_count] = id;
            for(i in fields) {
                if(i in OVERVIEW_FIELDS) {
                    overview_db[i,overview_count] = fields[i];
                }
            }
            #Add the full file for uncategorised items
            if (fields[CATEGORY] == "") {
                overview_db[FILE,overview_count] = fields[FILE];
            }
            gId2Index[fields[ID]]=overview_count;
            overview_count++;
        }
    }
}
function checkTimestamp(fieldName,fields,TvSeasonTimestamp,idx) {
    if (fields[fieldName] > TvSeasonTimestamp[fieldName,idx]) TvSeasonTimestamp[fieldName,id]=fields[fieldName];
}

function add_overview_indices(overview_db,overview_count,\
    f,i,j,idx) {

    #First create any temporary fields used for sorting...
    for(tvSeason in TvSeasionIdList) {
        split(TvSeasionIdList[tvSeason],j,"|");
        idx=gId2Index[j[1]];
        overview_db[OVERVIEW_DETAILIDLIST,idx] = TvSeasionIdList[tvSeason];
        overview_db[OVERVIEW_EXT_LIST,idx] = TvSeasionExtList[tvSeason];

        overview_db[DOWNLOADTIME,idx] = TvSeasonTimestamp[DOWNLOADTIME,tvSeason];
        overview_db[INDEXTIME,idx] = TvSeasonTimestamp[INDEXTIME,tvSeason];
        overview_db[FILETIME,idx] = TvSeasonTimestamp[FILETIME,tvSeason];

        DEBUG("Details for "idx" = " overview_db[TITLE,idx]" = "TvSeasionIdList[tvSeason]);
        overview_db[WATCHED,idx] = TvSeasionWatched[tvSeason];
    }

    # Now add the sorted indices..

    for(f in OVERVIEW_FIELDS) {
        if (OVERVIEW_FIELDS[f] != 0) {
            add_overview_index(overview_db,overview_count,f);
        }
    }
}

# Add a sorted index to the data
function add_overview_index(overview_db,overview_count,name,
  row,ord) {
    for(row = 0 ; row < overview_count ; row++ ) {
        ord[row]=row;
    }

    sortField=OVERVIEW_FIELDS[name];
    if (substr(sortField,1,1) == ".") {
        sortField = substr(sortField,2);
    }
    DEBUG("Creating index for "name" using "sortField" on "overview_count" items");
    heapsort(overview_count, OVERVIEW_FIELDS[name],1,ord,overview_db);

    #Note ord[] maps a sort position to a record index
    #When storing against a record we need to store the sort position
    #so store row(position) in record ord[row](index)
    for(row = 0 ; row < overview_count ; row++ ) {
        overview_db["#"name"#",ord[row]] = row;
    }
}

#Write the new array - except for hidden fields.
function write_overview(arr,arrSize,outFile,\
    line,r,f,dim ) {

    for(f in arr) {
        split(f,dim,SUBSEP);
        if (substr(dim[1],1,1) != ".") {
            line[dim[2]] = line[dim[2]]  dim[1] "\t" arr[f] "\t";
        }
    }
    for(r in line) {
        print "\t"line[r] > outFile;
    }
    delete line;
}

# If no direct urls found. Search using file names.
function searchInternet(idx,\
    url) {

    if (gSearch[idx] == "" && gExternalSourceUrl[idx] == "") {


        checkTvFilenameFormat(idx);

        if (gCategory[idx] == "T") {
            DEBUG("Search Internet - Episode guides");

            searchEpguideTitles(idx,gTitle[idx],1);

        } else {

            DEBUG("Search Internet - General search");
            # GENERAL SEARCH

            url=fileNameToSearchKeywords(gMovieFiles[idx]);
            #url="http://www.google.com/search?q="url"+imdb+title+-series";
            url="http://www.google.com/search?q="url"+imdb+title&num=20";
            getUrl(url,"GOOGLE",idx);
        }
        gSearch[idx]=url;
    } else {
        DEBUG("Search Internet skipped gSearch="gSearch[idx]" and gExternalSourceUrl="gExternalSourceUrl[idx]);
    }
}

function fileNameToSearchKeywords(f) {
    sub(/.*\//,"",f); #remove path
    sub(/\....$/,"",f); #remove extension
    gsub(/[^A-Za-z0-9]+/,"+",f);
    gsub(/^\+/,"",f);
    gsub(/\+$/,"",f);
    return f;
}


function setAndQueueExternalLink(idx,url,cat) {
    #if (gExternalSourceUrl[idx] == "") {
        DEBUG("SETTING EXTERNAL URL FOR "idx" to "url);
        gExternalSourceUrl[idx] = url;
        getUrl(gExternalSourceUrl[idx],"IMDBPAGE",idx);
        if (gCategory[idx] == "") {
            gCategory[idx] = "M";
        }
    #}
}


##### LOADING INDEX INTO DATABASE_ARRAY[] ###############################

FILENAME == INDEX_DB {
    if ( FNR==1 && FS!="\t" ) { FS="\t" ; $0 = $0 ; }

    if ( substr($0,1,1) != "\t" ) { next; }

    for(i=2 ; i < NF ; i+= 2 ) {
        DATABASE_ARRAY[$i,file_count] = $(i+1);
    }

    f=DATABASE_ARRAY[FILE,file_count];
    if (index(f,"//")) {
        gsub(/\/\/+/,"/",f);
        DATABASE_ARRAY[FILE,file_count] = f;
    }

    if (match(f,"/[^/]+$")) {
        DATABASE_ARRAY[NAME,file_count] = substr(f,RSTART+1);
        DATABASE_ARRAY[DIR,file_count] = substr(f,1,RSTART-1);
    }

    record_action=DATABASE_ARRAY[ACTION,file_count];
    if (record_action == "r") {
        #Remove from index
        for(i=2 ; i < NF ; i+= 2 ) {
            delete DATABASE_ARRAY[$i,file_count];
        }
    } else if (tolower(record_action) == "d") {

        deleteEntry(file_count,DATABASE_ARRAY[ACTION,file_count]);

        for(i=2 ; i < NF ; i+= 2 ) {
            delete DATABASE_ARRAY[$i,file_count];
        }
    } else if (f in FILE_HASH ) {
        WARNING("Duplicate detected for "f". Ignoring");
        for(i=2 ; i < NF ; i+= 2 ) {
            delete DATABASE_ARRAY[$i,file_count];
        }
    } else {
        #DEBUG("Got file ["f"]");
        FILE_HASH[f]=1;

        #TODO We could just store the index rather than the original line
        index_line[DATABASE_ARRAY[FILE,file_count]] = $0;

        if ( DATABASE_ARRAY[FILE,file_count] == "" ) {
            ERROR("Blank file for ["$0"]");
        }
        if (DATABASE_ARRAY[ID,file_count] > gMaxDatabaseId) {
            gMaxDatabaseId = DATABASE_ARRAY[ID,file_count];
        }

        file_count++;
    }
}

#Add files to the delete queue
function queueFileForDeletion(name,field) {
    gFileToDelete[name]=field;
}

function deleteQueuedFiles(db,file_count,\
    f,field,i,deleteFile) {

    INFO("Deleting queued files");
    for(f in gFileToDelete) {
        field=gFileToDelete[f];
        if (field != "" && field != DIR ) {
            deleteFile=1;
            #check file has no other references 
            for(i = 0 ; i < file_count ; i++ ) {
                if (db[field,i] == f) {
                    INFO(f" still in use");
                    deleteFile=0;
                    break;
                }
            }
            if (deleteFile) {
                INFO("Deleting "f);
                exec("rm -f -- \""f"\"");
            }
        }
    }

    INFO("Deleting folders");
    for(f in gFileToDelete) {
        field=gFileToDelete[f];
        if (field == DIR ) {
            # We are expecting rmdir to fail if the is other content!!
            exec("rmdir -- \""f"\" 2>/dev/null || true");
        }
    }
}

# mode=d delete media only, D=delete all related files.
function deleteEntry(idx,mode,\
    parts,i,d) {
    INFO("Deleting "DATABASE_ARRAY[FILE,idx]);
    parts=split(DATABASE_ARRAY[PARTS,idx],parts,"/");
    d=DATABASE_ARRAY[DIR,idx];

    #If mode d or D then delete media files

    rmList = quoteFile(DATABASE_ARRAY[FILE,idx]);
    for (i in parts) {
        rmList = rmList " " quoteFile(d"/"parts[i]);
    }
    if (DATABASE_ARRAY[NFO,idx] != "") {
        rmList = rmList " " quoteFile(d"/"DATABASE_ARRAY[NFO,idx]);
    }

    if (mode == "D") {
        #Also delete any other files with the same basename
        p=DATABASE_ARRAY[FILE,idx];
        sub(/.[^.]+$/,"",p);
        rmList = rmList " " quoteFile(p) ".???" ;
        for(i in parts) {
            p=parts[i];
            sub(/.[^.]+$/,"",p);
            rmList = rmList " " quoteFile(p) ".???" ;
        }
        rmList = rmList " unpak.txt unpak.log unpak.state.db" ;
        rmList = rmList " *[^A-Za-z0-9]sample[^A-Za-z0-9]*.???" ;
        rmList = rmList " *[^A-Za-z0-9]samp[^A-Za-z0-9]*.???" ;
        rmList = rmList " *[^A-Za-z0-9]SAMPLE[^A-Za-z0-9]*.???" ;
        rmList = rmList " *[^A-Za-z0-9]SAMP[^A-Za-z0-9]*.???" ;
        exec(" cd "quoteFile(d)" && rm -f -- "rmList);

        queueFileForDeletion(DATABASE_ARRAY[NFO,idx],NFO);
        queueFileForDeletion(DATABASE_ARRAY[POSTER,idx],POSTER);
        queueFileForDeletion(DATABASE_ARRAY[DIR,idx],DIR);
    }
}

##### PRUNING DELETED ENTRIES FROM INDEX ###############################

#Check all the links
#To quickly find out if a set of files exist use ls
function probe_missing_files(   i,\
    list) {
    list="";

    print "#Index" > INDEX_DB".new"; #Must always be one line

    for(i=0 ; i < file_count ; i++ ) {

        if (DATABASE_ARRAY[FILE,i] == "" ) {

            WARNING("Empty file for index " i);

        } else {

            q=quoteFile(DATABASE_ARRAY[FILE,i]);
            if (length(list " " q) < 4000) {
                list=list " "q;
            } else {
                checkCommand(list);
                list=q
            }
        }
    }
    if ( list != "" ) {
        checkCommand(list);
    }
    kept_file_count=0;
    absent_file_count=0;
    updated_file_count=0;
}

#Return file name with shell meta-chars escaped.
function quoteFile(f,
    j,ch) {
    if (index(f,"\"") == 0) {
        return "\""f"\"";
    } else if (index(f,"'"'"'") == 0) {
        return "'"'"'"f"'"'"'";
    } else {
        meta=" !&[]*()\"'"'"'";
        for(j= 1 ; j <= length(meta) ; j++ ) {
            ch=substr(meta,j,1);
            if (index(f,ch)) {
                #DEBUG("Escaping ["ch"] from "f);
                gsub("["ch"]","\\"ch,f);
                #DEBUG("= "f);
                }
        }
        return f;
    }
}

function checkCommand(list) {
    cmd="ls -- " list " >> " NEW_CAPTURE_FILE("PROBEMISSING") " 2>&1" 
   #DEBUG("######### "cmd" #############");
    system(cmd);
}

CAPTURE_LABEL == "PROBEMISSING" {

    if ($0 == "" ) next;

    if ((i=index($0,": No such file or directory")) > 0 || (i=index($0,": Not a directory")) > 0) {
       $0 = substr($0,1,i-1);
       i = index($0,"/");
       $0 = substr($0,i);

        WARNING("DELETED ["$0"]");
        absent_file_count++;

    } else if (gMovieFilePresent[$0] == 0) {

       #DEBUG("KEEPING ["$0"]");
       print index_line[$0] >> INDEX_DB".new";
       kept_file_count++;

    } else {

       INFO("UPDATING ["$0"] later.");
        updated_file_count++;
    }
    next;
}

##################### STORE LIST OF MOVIE FILES #########################

# Input is ls -lR or ls -l
CAPTURE_LABEL == "MOVIEFILES" {

    if(DEBUG) { print "LS"$0; }

    store=0;

    if (FNR== 1) {
        #Need to make sure the ls format is as "standard"
        gotLsFormat=0;
        LS_FILE_POS=0;
        LS_TIME_POS=0; 
    }
    if ($0 == "" || FNR== 1) {
        if (FNR==1) {
            gCurrentFolder=$0;
        } else {
            getline gCurrentFolder;
        }
        sub(/\/*:$/,"",gCurrentFolder);

        if (gotLsFormat==0 && index(gCurrentFolder,"/proc/"PID) ) {
            gotLsFormat++;
        }

        if(unpak_nmt_pin_root != "" && left(gCurrentFolder,length(unpak_nmt_pin_root)) == unpak_nmt_pin_root) {
            gSkipFolder=1;
            INFO("SKIPPING "gCurrentFolder);
        } else if (gCurrentFolder in gFolderCount) {
            WARNING("Already visited "gCurrentFolder);
            gSkipFolder=1;
        } else {
            INFO("Scanning folder "gCurrentFolder);
            gSkipFolder=0;
            gFolderMediaCount[gCurrentFolder]=0;
            gFolderInfoCount[gCurrentFolder]=0;
            gFolderCount[gCurrentFolder]=0;
        }
        next;
    }

    #Initial we add /proc/$$ but we are only interested in fd as this
    #is the only one that has the current timestamp on cygwin. 
    if (substr(gCurrentFolder,1,5) == "/proc" ) {
        if (gotLsFormat==1 ) {
           if (index($0,"fd") && match($0,"\\<fd\\>")) {
                INFO("LS Format "$0);
                for(i=1 ; i <= NF ; i++ ) {
                    if ($i == "fd") LS_FILE_POS=i;
                    if (index($i,":")) LS_TIME_POS=i;
                }
                INFO("File Position at "LS_FILE_POS);
                INFO("Time Position at "LS_TIME_POS);
                gotLsFormat++;
            } 
        } 
        next;
    }

    if (gSkipFolder) next;

    lc=tolower($0);

    if (index(lc,"samp") ) {
       if ( match(lc,"\\<sample\\>")) next;
       if ( match(lc,"\\<samp\\>")) next;
    }
    if (substr($0,1,1) != "-") {
        if (substr($0,1,1) == "d") {
            #Directory
            gFolderCount[gCurrentFolder]++;
        }
        next;
    }
    
    lc=tolower($0);

    w5=w6=w7=w8="";

    # Check if ls -l format
    if (length($1) == 10) {
        # ls -l format. Extract file time...
        w5=$5;

        if ( LS_TIME_POS ) {
            w6=$(LS_TIME_POS-2);
            w7=$(LS_TIME_POS-1);
            w8=$(LS_TIME_POS);
        }

        #Get Position of 9th word.
        #(not cannot change $n variables as they cause corruption of $0.eg 
        #double spaces collapsed.
        pos=index($0,$2);
        for(i=3 ; i <= LS_FILE_POS ; i++ ) {
            pos=indexFrom($0,$i,pos+length($(i-1)));
        }
        $0=substr($0,pos);
    }

    if (match(lc,EXTENSIONS2_RE)) {

        if (length(w5) < 10) {
            INFO("Skipping image - too small");
        } else {
            store=1;
        }

    } else if (match($0,"unpak.???$")) {
        
        gDate[gCurrentFolder"/"$0] = calcTimestamp(w6,w7,w8,NOW);

    } else if (match(lc,EXTENSIONS1_RE)) {

        #Only add it if previous one is not part of same file.
        multipart=0;

        preDot=length($0) - 4;

        if (gMovieFileCount > 0) {
            if ((j=index("bcd",substr($0,preDot,1))) > 0) {

                # Check for xxxxxxxa.avi , xxxxxxb.avi

                if (gMovieFiles[gMovieFileCount-1] == substr($0,1,preDot-1)"a"substr($0,preDot+1)) {

                   INFO("skipping alpha multipart eg xxxxxb.avi");
                    multipart=1;

                }

            } else if ((j=index("234",substr($0,preDot,1))) > 0) {

                # Check for xxxxxxx1.avi , xxxxxx2.avi
                #make sure not a series xxxx23.avi
                if (index("0123456789",substr($0,preDot-1,1))==0) {
                    if (gMovieFiles[gMovieFileCount-1] == substr($0,1,preDot-1)"1"substr($0,preDot+1)) {
                       INFO("skipping numeric multipart eg xxxxx2.avi");
                        multipart=1;
                    }
                }
            } else if (match($0,"[^a-zA-Z][Cc][Dd][234][^A-Za-z0-9]")) {

                # Check for xxxxxxx.cd1.xxxx.avi  xxxxxxx.cd2.xxxx.avi 
                previousBit = substr(gMovieFiles[gMovieFileCount-1],RSTART,RLENGTH);
                if (match(previousBit,"[^a-zA-Z][Cc][Dd]1[^A-Za-z0-9]")) {
                   INFO("skipping numeric multipart (eg xxxx.cd2.xxx.avi ) ");
                   multipart=1;
                }
            }
        }
        if (multipart) {

            #This is just another part, so dont add to index but adjust default info to ommit sequence letter.
            sub(/(CD|cd|Cd|).\.nfo$/,".nfo",gNfoDefault[gMovieFileCount-1]);
           DEBUG("Storing Default Multipart NFO "(gMovieFileCount-1)" = "gNfoDefault[gMovieFileCount-1]);

           # Add part name to '/' seperated list.
           gParts[gMovieFileCount-1] = (gParts[gMovieFileCount-1] =="" ? "" : gParts[gMovieFileCount-1]"/" ) $0;

        } else {

            #This is the first/only avi for this film/show
            store=1;
        }
    } else if (match(lc,"\.nfo$")) {

        nfo=gCurrentFolder"/"$0;
        gNfoExists[nfo]=1;
        gFolderInfoCount[gCurrentFolder]++;
        gFolderInfoName[gCurrentFolder]=nfo;
        gDate[nfo] = calcTimestamp(w6,w7,w8,NOW);

    }

    if (store) {


        gFolderMediaCount[gCurrentFolder]++;

        gFolder[gMovieFileCount]=gCurrentFolder;
        gMovieFiles[gMovieFileCount] = $0;
        DEBUG("Storing "gMovieFiles[gMovieFileCount]);

        #used when pruning the old index.
        gMovieFilePresent[gCurrentFolder"/"$0] = 1;

        #Add a lookup to nfo file
        nfo=gMovieFiles[gMovieFileCount];
        sub(/\....$/,".nfo",nfo);
        gNfoDefault[gMovieFileCount] = gCurrentFolder"/"nfo;
        DEBUG("Storing Default NFO "gMovieFileCount" = "gNfoDefault[gMovieFileCount]);


        gFileTime[gMovieFileCount] = calcTimestamp(w6,w7,w8,NOW);

        gMovieFileCount++;
    }
    next;
}

function calcTimestamp(w6,w7,w8,_default,\
    val) {
    # Calculate file time...
    if (w6 == "" ) {
        return _default;
    } else {
        m=getMonth[w6];
        d=w7;
        if (index(w8,":")) {
            #MON dd hh:mm
            y=THIS_YEAR;
            h=substr(w8,1,2);
            min=substr(w8,4,2);
        } else {
            #MON dd yyyy
            y=w8;
            h=7;
            min=0;
        }
        val = sprintf("%04d%02d%02d%02d%02d00",y,m,d,h,min); 
        if (val > NOW ) {
            y--;
            val = sprintf("%04d%02d%02d%02d%02d00",y,m,d,h,min); 
        }
        return val; 
    }
}

function checkTvFilenameFormat(idx,    details,line,dirs,d,dirCount) {

    line = gMovieFiles[idx];

    #First get season and episode information

   #DEBUG("CHECK TV "line);

    if (extractEpisode(line,idx,details)) {
       INFO("Found TV Info in file:"line);
    } else {
       DEBUG("FAILED LEVEL 0 CHECK TV "line);

       split(gFolder[idx],dirs,"/");
       dirCount=0;
       for(d in dirs) dirCount++;

       if (dirCount == 0 ) return 0;

       line=dirs[dirCount]"/"line;

       if (extractEpisode(line,idx,details)) {
           INFO("Found TV Info in dir/file:"line);
        } else {
           DEBUG("FAILED LEVEL 1 CHECK TV:"line);
           if (dirCount == 1 ) return 0;
           line=dirs[dirCount-1]"/"line;
           if (extractEpisode(line,idx,details)) {
               INFO("Found TV Info in dir1/dir2/file:"line);
           } else {
               DEBUG("FAILED LEVEL 2 CHECK TV:"line);
               return 0;
           }
       }
    }
    DEBUG("CONTINUE CHECK TV "line);

    gTitle[idx]=details[TITLE];
   DEBUG(" SET TITLE =============> "idx"="gTitle[idx]);

    gSeason[idx]=details[SEASON];
    gEpisode[idx]=details[EPISODE];
    gCategory[idx] = "T";
    gAdditionalInfo[idx] = details[ADDITIONAL_INFO];

    # Now check the title.
    #TODO
}

function extractEpisodeByPatterns(line,details,idx) {

    #Note if looking at entire path name folders are seperated by /

    line = tolower(line);
    if (!extractEpisodeByPattern(line,0,"\\<","[s][0-9]{1,2}","/?[de][0-9]{1,2}",details,idx))  #s00e00

    if (!extractEpisodeByPattern(line,0,"\\<","[0-9]{1,2}","/?x[0-9]{1,2}",details,idx)) #00x00
    if (!extractEpisodeByPattern(line,0,"\\<","(series|season|saison|s)[^a-z0-9]*[0-9]{1,2}","/?(e|ep\.?|episode|)[^a-z0-9]*[0-9]{1,2}",details,idx)) #00x00 
    {

        if (index(line,"x264")) {
            gsub(/\<x264\>/,"x-264",line);
        }
        if (!extractEpisodeByPattern(line,1,"[^-0-9]","[03-9]?[0-9]","/?[0-9][0-9]",details,idx)) # ...name101...

                return 0;
    }

   #Note 4 digit season/episode matcing [12]\d\d\d will fail because of confusion with years.
    return 1;
}

function extractEpisode(line,idx,details,        d,dir) {

    if (!extractEpisodeByPatterns(line,details,"")) {
        return 0;
    }

   DEBUG("Extracted title ["details[TITLE] "]");
    if (details[TITLE] == "" ) {

        #File starts with season number eg. ^<season><episode>..." so title must be in folder name.

        split(gFolder[idx],dir,"/"); # split folder
        for(d in dir ) { ; } # Count

        details[TITLE] = cleanTitle(dir[d]);
        DEBUG("Using parent folder for title ["details[TITLE] "]");
        sub(/(S[0-9]|Series|Season) *[0-9]+.*/,"",details[TITLE]);
        if (details[TITLE] == "" ) {
            # Looks like an intermediate Season folder. Get the parent folder.
            details[TITLE] = cleanTitle(dir[d-1]);
            DEBUG("Using grandparent folder for title ["details[TITLE] "]");
        }
    }

    return 1;
}

#This would be easier using sed submatches.
#More complex approach will fail on backtracking
function extractEpisodeByPattern(line,prefixReLen,prefixRe,seasonRe,episodeRe,details,idx,  \
    start,tmpDetails) {
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
   #Remove release group info
   if (index(tmpDetails[TITLE],"-") && match(tmpDetails[TITLE],"^[a-z][a-z0-9]+[-]")) {
       tmpTitle=substr(tmpDetails[TITLE],RSTART+RLENGTH);
       if (tmpTitle != "" ) {
           INFO("Removed group was ["tmpDetails[TITLE]"] now ["tmpTitle"]");
           tmpDetails[TITLE]=tmpTitle;
       }
   }

    tmpDetails[TITLE] = cleanTitle(tmpDetails[TITLE]);
    
    DEBUG("ExtractEpisode: Title= ["tmpDetails[TITLE]"]");

    if (match(tmpDetails[ADDITIONAL_INFO],"("EXTENSIONS1_RE"|"EXTENSIONS2_RE")") ) {
        tmpDetails[EXT]=tmpDetails[ADDITIONAL_INFO];
        gsub(/\.[^.]*$/,"",tmpDetails[ADDITIONAL_INFO]);
        tmpDetails[EXT]=substr(tmpDetails[EXT],length(tmpDetails[ADDITIONAL_INFO])+2);
    }

    #Match the episode first to handle 3453 and 456
    match(line,episodeRe "$" );
    tmpDetails[EPISODE] = substr(line,RSTART,RLENGTH); 
    tmpDetails[SEASON] = substr(line,1,RSTART-1);

    gsub(/[^0-9]+/,"",tmpDetails[EPISODE]);
    sub(/^0+/,"",tmpDetails[EPISODE]);

    gsub(/^[^0-9]+/,"",tmpDetails[SEASON]);
    sub(/^0+/,"",tmpDetails[SEASON]);

    #Return results
    for(ee in tmpDetails) {
        if (idx != "") {
            details[ee,idx]=tmpDetails[ee];
        } else {
            details[ee]=tmpDetails[ee];
        }
       DEBUG("tv details "ee"."idx" = "tmpDetails[ee]);
    }
    return 1;
}

############### GET IMDB URL FROM NFO ########################################

function get_imdb_urls_from_nfos(i,file) {

    for (i in gMovieFiles ) {

        file=gMovieFiles[i];


        if (IGNORENFO) {

            searchInternet(i);

        } else if (gNfoExists[gNfoDefault[i]]) {

           DEBUG("Using default info to find url");
            APPEND_CONTENT(gNfoDefault[i],i);

        } else if (gFolderMediaCount[gFolder[i]] == 1 && gFolderInfoCount[gFolder[i]] == 1 && gNfoExists[gFolderInfoName[gFolder[i]]]) {

           DEBUG("Using single nfo "gFolderInfoName[gFolder[i]]" to find url in folder ["gFolder[i]"] for item "i);

            gNfoDefault[i] = gFolderInfoName[gFolder[i]];
            APPEND_CONTENT(gFolderInfoName[gFolder[i]],i);

        } else {

            searchInternet(i);

        }
    }
}

match(FILENAME,"[Nn][Ff][Oo]$") {

    idx=CARGV[1];

    if (FNR == 1 ) {
        iurl=""; 
    } #Init

    if (substr($0,1,1) == ":" ) {

        read_generated_nfo($0,idx);


    } else {

    #print "NFO:"$0;

        if (iurl != "" ) { next; } #Already found iurl

        #This is a bit too risky to use. as some nfo have weird layout.
        #extractEpisodeByPatterns($0,gNfoDetails,idx);

        if (index($0,"imdb")) {
            DEBUG( "IMDB:"$0);
            if (match($0,"http://[a-z.]*imdb.[a-z.]+/title/[a-z0-9]+")) {
                iurl=substr($0,RSTART,RLENGTH);
                DEBUG( "IMDBURL:"iurl);
                setAndQueueExternalLink(idx,iurl,"M");
            }
        }
    }
    next;
}

############### GET IMDB PAGE FROM URL ########################################

function searchEpguideTitles(idx,title,attempt,\
    p,url,letter,t2) {
    DEBUG("Queue Search of epGuide titles for ["title"]");

    # Check we havnt seen this already.
    #(this check is also repeated inside the EPGUIDE_INDEX clause because
    #some searches may alread be queued, due to the order in which awk is processing
    #files. - almost OO like - but not quite ;)
    # That is two searches may be queued against the same series, but gEpguideIndex
    #is set only after the first search is completed 
    #Alternative is to load the full epGuide index first. but memory is at a premium

    if (gEpguideIndex[title] != "" ) {
        getEpisodeDetails(idx,title,gEpguideIndex[title]);
        return;
    }

    # TV SEARCH
    sub(/^[Tt]he /,"",title);
    letter=tolower(substr(title,1,1));

    #Thank you epguides for silly numeric-alpha index eg 24 on page t, 90210 page n but 1990 page n too!
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

    if (match(letter,"[a-z]")) {
        #Use epguides menu
        getUrl("http://epguides.com/menu"letter,"EPGUIDE_INDEX",idx"|"title"|"attempt);
    } else {
        #go direct. Fingers crossed.
        t2=fileNameToSearchKeywords(title);
        url="http://google.com/search?q=allintitle%3A+"t2"+site%3Aepguides.com&btnI=Search";
        getEpisodeDetails(idx,title,url);
    }
}


# Seach a google page for most frequently occuring title with tv SnnEnn format.
CAPTURE_LABEL == "EPGUIDE_INDEX" {
    idx=CARGV[1];
    title=CARGV[2];
    attempt=CARGV[3];

    # Called at start of this file
    if (FNR == 1) {
        gEpguideSeriesUrl="";
        DEBUG("Checking ["title"] against epguide series list ");
        # Check we havnt seen this already.
        #(this check is also performed before queuing this job, however
        # two searches may be queued against the same series, but gEpguideIndex
        #is set only after the first search is completed 
        #Alternative is to load the full epGuide index first. but memory is at a premium
        if (gEpguideIndex[title] != "" ) {
            getEpisodeDetails(idx,title,gEpguideIndex[title]);
            nextfile;
        }

    }

    # Called at end of this file
    if (index($0,ENDPAGE_MARKER )) {
        DEBUG("ENDPAGE with uRL = ["gEpguideSeriesUrl"]");
        if (gEpguideSeriesUrl != "") {
            getEpisodeDetails(idx,title,gEpguideSeriesUrl);
        } else if (attempt == 1) {
            #Try to get a better series title by searching for the filename
            url=fileNameToSearchKeywords(gMovieFiles[idx]);
            url="http://www.google.com/search?q="url"&num=20";
            getUrl(url,"GOOGLETV",idx);
        } else {
            WARNING("Could not resolve title [" title "]");
        }
    }
    if (index($0,"<li>") == 0 ) next;
    if (index($0,"[radio]")) next;

    seriesNamePlusInfo=extractTagText($0,"a");
    yearOrCountry="";
    if ((bPos=index(seriesNamePlusInfo," (")) > 0) {
        yearOrCountry=cleanTitle(substr(seriesNamePlusInfo,bPos+2));
    }
    seriesNamePlusInfo=cleanTitle(seriesNamePlusInfo);
    sub(/^[Tt]he /,"",seriesNamePlusInfo);


    submatch=0;
    DEBUG("Checking ["title"] against ["seriesNamePlusInfo"]");
    if (index(seriesNamePlusInfo,title) == 1) {

        #This will match exact name OR if BOTH contain original year or country
        if (seriesNamePlusInfo == title) {
            submatch=2;

        #This will match if difference is year or country. In this case just pick the 
        # last one and user can fix up
        } else if ( seriesNamePlusInfo == title " " yearOrCountry ) {
            INFO("match for ["title"+"yearOrCountry"] against ["seriesNamePlusInfo"]");
            submatch = 1;
        } else {
            DEBUG("No match for ["title"+"yearOrCountry"] against ["seriesNamePlusInfo"]");
        }
    } else if (index(title,seriesNamePlusInfo) == 1) {
        #Check our title just has a country added
        diff=substr(title,length(seriesNamePlusInfo)+1);
        if (substr(diff,1,1) == " ") {
            submatch = 1;
            INFO("match for ["title"] containing ["seriesNamePlusInfo"]");
        }
    }

    if (submatch) {
        gEpguideSeriesUrl=extractAttribute($0,"a","href");
        sub(/\.\./,"http://epguides.com",gEpguideSeriesUrl);
        if (submatch == 2) {
            getEpisodeDetails(idx,title,gEpguideSeriesUrl);
            nextfile;
        }
    }

    next;
}

function cleanTitle(t) {
    if (index(t,"&") && index(t,";")) {
        gsub(/[&]amp;/,"and",t);
        gsub(/[&][a-z0-9]+;/,"",t);
    }
    gsub(/['"'"']/,"",t);
    gsub(/[^A-Za-z0-9]+/," ",t);
    t=trim(caps(tolower(t)));
    return t;
}

#Goggle a filename and examine search results of form "some text S0n ...."
CAPTURE_LABEL == "GOOGLETV" {

    idx=CARGV[1];
    if (FNR == 1) {
        split("",gTitleCount,""); #clear
        seasonPattern=sprintf("([Ss](eason |)0*%d|0*%dx?%02d)",gSeason[idx],gSeason[idx],gEpisode[idx]);
        #Todo may have issue with series with special chars. eg "terminator: sarah connor"
        #Allow &xx; for html escapes in titles.
        #Allow () for country and year eg (US) or (2008)
        titlePattern="[&;()A-Za-z0-9 .:]+[- ]*$";
    }

    gsub(/<em>/,"");
    gsub(/<\/em>/,"");

    while((i=index($0,"<h3 class=")) > 0) {
        $0=substr($0,i);
        h3pos=index($0,"</h3>");
        h3txt=substr($0,1,h3pos);
        $0=substr($0,h3pos+4);

        h3txt=extractTagText(h3txt,"a");
        DEBUG("Examing search results page title? " h3txt);
        if ((j=match(h3txt,seasonPattern) ) != 0 ) {
            if (match(substr(h3txt,1,j-1),titlePattern)) {
                t=cleanTitle(substr(h3txt,RSTART,RLENGTH));
                DEBUG("Save possible title "t);
                if (t in gTitleCount) {
                        gTitleCount[t]++;
                } else {
                    gTitleCount[t] = 1;
                }
            }
        }
    }

    if (index($0,ENDPAGE_MARKER)) {
        
        bestTitle=getMax(gTitleCount,1);
        if (bestTitle != "") {
            if (tolower(bestTitle) != tolower(gTitle[idx])) {
                #TODO this really should be inserted immediately into the queue so that
                #subsequent episodes benefit from the additional info rather than all
                #working in parallel. However due to caching this duplication of effort 
                #only adds about 1sec per episode on NMT platform.
                searchEpguideTitles(idx,bestTitle,2);
            }
        }
    }
    next;
}

function getMax(arr,threshold) {
    maxValue=threshold;
    maxName="";
    for(i in arr) {
        DEBUG(arr[i] "votes for "i);
        if (arr[i] > maxValue ) {
            maxValue = arr[i];
            maxName = i;
        }
    }
    return maxName;
}



# Seach a google page for most frequently occuring imdb link
CAPTURE_LABEL == "GOOGLE" {

    if (FNR == 1) {
        split("",gImdbUrlCount,""); #Clear
    }

    gsub(/<em>/,"");
    gsub(/<\/em>/,"");

    x=$0;
    #gsub(/</,"\n<",x);DEBUG(x);

    if (index($0,".imdb.")) {
        start=0;

        # TODO REplace with split loop
        #Results may come from country.imdb.xxx/title/dddddd so just keep /title/dddddd
        while ((j=match(substr($0,start+1),"imdb.[.a-z]+/title/[a-z0-9]+")) > 0) {


            
            nextStart=start+j+RLENGTH;
            iurl=substr($0,j+start,RLENGTH);
            iurl=substr(iurl,index(iurl,"/"));

           DEBUG("IMDB match at "iurl);

            if ( gImdbUrlCount[iurl] == "" ) {
                gImdbUrlCount[iurl]=0;
            }
            gImdbUrlCount[iurl]++;

            start = nextStart;

        }
    }
    if (index($0,ENDPAGE_MARKER)) {
        # Find the url with the highest count for each index.
        #To help stop false matches we requre at least two occurences.



        bestUrl=getMax(gImdbUrlCount,MIN_IMDB_LINK_REPETITIONS-1);
        if (bestUrl != "") {
            setAndQueueExternalLink(CARGV[1],"http://www.imdb.com"bestUrl,"M");
        } else {
            DEBUG("TODO widen search?");
        }
        split("",gImdbUrlCount,""); #Clear
    }
    next;
}

#This function is called after the epguides link has been determined.
#Before queuing the epguides page it stores the url against the original guess at the title
#(extracted from filename or nfo) and also for the better guess (which was dscovered from a
# google search - see GOOGLETV )
# title is the title that matched epguides.
# if gTitle[idx] != title then it was a Google guess.
function getEpisodeDetails(idx,title,url) {

    #If its a direct link to epguides and not a google search then store it.
    if (index(url,"epguides.com/") && gEpguideIndex[url] == "") {

        if (gEpguideIndex[title] != url) {
            #Add a quick lookup for the epGuides series name to epGuides url
            INFO("Adding series title lookup ["title"] to "url);
            gEpguideIndex[title] = url;
        }


        if (title != gTitle[idx] && gTitle[idx] != "" ) {
            #Add a quick lookup for the initial title name to epGuides url
            INFO("Adding series title lookup ["gTitle[idx]"] to "url);
            gEpguideIndex[gTitle[idx]] = url;
        }
    }

    if (gTitle[idx] != title ) {
        INFO("CHANGING TITLE from ["gTitle[idx]"] to ["title"]");
    }
    gTitle[idx]=title;
    DEBUG("Queue episode details for ["title"]");
    getUrl(url,"EPGUIDE",idx);
}

CAPTURE_LABEL == "EPGUIDE" {

    idx=CARGV[1];
    if (FNR == 1) {
        episodeText=sprintf(" %d-%2d ",gSeason[idx],gEpisode[idx]);
        episodeTextHyphen=index(episodeText,"-");
    }

    #print idx ":" $0;

    if (gExternalSourceUrl[idx]=="" ) {
        if (index($0,"<h1>") && index($0,"imdb")) {
            link=extractAttribute($0,"a","href");
            i=index($0,"http");
            j=index(substr($0,i),"\"")-1;
            setAndQueueExternalLink(idx,link,"T");

            #Refine the title.
            newTitle=trim(caps(extractTagText($0,"a")));
            if (newTitle != gTitle[idx] ) {
                DEBUG("epguides: Title changed from "gTitle[idx]" to "newTitle);
                gTitle[idx] = newTitle;
            }

            #Also get episode info from IMDB. This is to help decide when episode titles in epguides.com are wrong.
            getUrl(link"/episodes","IMDBEPISODE",idx);
        }

    }


    #Sometimes there is more than one entry per episode. So store the links in an array.
    #The correct one will be chosen via IMDB episode title.
    hyp2=index($0,"-");
    if (hyp2 < 20 && hyp2 >= episodeTextHyphen) {
        text2=substr($0,hyp2-episodeTextHyphen+1,length(episodeText));
        #DEBUG("episodeText["episodeText"] text2["text2"] all=["$0"]");

        if (episodeText == text2) {

            gProdCode[idx]=trim(substr($0,14,9));

            gYear[idx]=1900+substr($0,35,2);
            if (gYear[idx] < 1920 ) { gYear[idx] += 100; } 

            gAirDate[idx]=substr($0,28,9);

            if (gEpTitle[idx] == "" ) {
                sep="";
            } else {
                sep = "\t";
            }
            gTvCom[idx]=gTvCom[idx] sep extractAttribute($0,"a","href");

            gEpTitle[idx]=gEpTitle[idx] sep extractTagText($0,"a");

            DEBUG("Found Episode title "gEpTitle[idx]);
        }
    }

    #We may have ariived by Google Feeling Lucky so get the real url name
    if ((i=index($0,"DirName"))>0) {

        i += 8;
        $0 = substr($0,i);
        j=index($0,"\"");
        dirName=substr($0,1,j-1);

        gEpGuides[idx]="http://epguides.com/"dirName;

    }
    if ( gPoster[idx] == "" && index($0,"CasLogPic") ) {
           
           getPoster(gEpGuides[idx]"/"extractAttribute($0,"img","src"),idx);
    }
    if (index($0,"botnavbar")) {
        nextfile;
    }
    next;
}

CAPTURE_LABEL == "IMDBEPISODE" {
    idx=CARGV[1];

    if (gEpTitleImdb[idx] != "" ) next;

    s=gSeason[idx];
    e=gEpisode[idx];

    if (index($0,"Season "s", Episode "e":")) {
        gEpTitleImdb[idx]=extractTagText($0,"a");
        gAirDateImdb[idx]=extractTagText($0,"strong");
        DEBUG("IMDB EPISODE TITLE = "gEpTitleImdb[idx]);
        DEBUG("IMDB AIR DATE = "gAirDateImdb[idx]);
    }
    next;
}

function extractAttribute(str,tag,attr,\
    i,closeTag,endAttr,attrPos) {

    i=index(str,"<"tag);
    closeTag=indexFrom(str,">",i);
    attrPos=indexFrom(str,attr"=",i);
    if (attrPos == 0 || attrPos >= closeTag ) {
        ERROR("ATTR "tag"/"attr" not in "str);
        ERROR("i is "i" at "substr(str,i));
        ERROR("closeTag is "closeTag" at "substr(str,closeTag));
        ERROR("attrPos is "attrPos" at "substr(str,attrPos));
        return "";
    }
    attrPos += length(attr)+1;
    DEBUG("EXTRACTING FROM "substr(str,attrPos));
    if (substr(str,attrPos,1) == "\"" ) {
        attrPos++;
        endAttr=indexFrom(str,"\"",attrPos);
    }  else  {
        endAttr=indexFrom(str," ",attrPos);
    }
    DEBUG("EXTRACTED "substr(str,attrPos,endAttr-attrPos));
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

function getUrl(url,capture_label,arglist,argsep,\
    f) {
    
    if (url == "" ) {
        WARNING("Ignoring empty URL");
        return;
    }


    ua="Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20040613 Firefox/0.8.0+";
    ua="nmt-catalog";

    #Due to memory issues stop using the cache.. if we need it again try a hash or turn url into a filename
    urlFile=url;
    gsub(/\//,"_",urlFile);
    urlFile=CAPTURE_PREFIX PID ".url-" urlFile;

    #Get url if we havent got it before.
    cmd = "if [ ! -f \""urlFile"\" ] ; then wget -q -U \""ua"\" -O \""urlFile"\" \""url"\" ; echo \""ENDPAGE_MARKER"\" >> \""urlFile"\" ; fi"
    exec(cmd);

    f=NEW_CAPTURE_FILE(capture_label,arglist,argsep);
    cmd = sprintf("ln -f \"%s\" \"%s\"",urlFile,f);
    return exec(cmd);
}

function getPoster(url,idx,\
    localPosterPath,localPosterName) {

    localPosterName = gTitle[idx];
    gsub(/[^a-zA-Z0-9]/,"",localPosterName);

    localPosterName = localPosterName ".jpg";
    localPosterPath = gFolder[idx] "/" localPosterName ;

    #Get the poster if we havent fetched it already.
    if (gPosterList[localPosterPath] == "" ) {

        exec(sprintf("wget -q -O \"%s\" \"%s\" && chown nmt:nmt \"%s\"",localPosterPath,url,localPosterPath));
        gPosterList[localPosterPath] = 1;

    }

    gPoster[idx]=localPosterName;
    DEBUG("GOT POSTER="gPoster[idx]);
}


function processImdbLine() {

    idx=CARGV[1];

    if (FNR == 1) {
        if (gCategory[idx] == "" ) { gCategory[idx]="M"; }
        contentPos=0;

        DEBUG("START IMDB: title:"gTitle[idx]" poster "gPoster[idx]" genre "gGenre[idx]" cert "gCertRating[idx]);
    }
    if (contentPos > 1 ) {
        #Gone past usable content
        next;
    } else if (contentPos == 0 ) {

        #Only look for title at this stage
        #First get the HTML Title
        if (index($0,"<title>") && match($0,"<title>[^(<]+")) {
            l=substr($0,RSTART+7,RLENGTH-7);
            DEBUG("TITLE "l);
            if ( gTitle[idx] == "" ) {
                gsub(/[&][^;]+;/,l);
                sub(/ +$/,"",l);
                gTitle[idx] = l;
            }
        }
        if (index($0,"pagecontent")) contentPos=1;
        next;
    }
    if (index($0,"Company:")) {
        contentPos=2;
        nextfile;
        next; #just in case nextfile not supported.
    }

    #This is the main information section

    if (gCategory[idx] != "T" && index($0,"episodes#season") ) {
        DEBUG("IMDB: Got category");
        gCategory[idx] = "T";
    }
    if (gYear[idx] == "" && (y=index($0,"/Sections/Years/")) > 0) {
        gYear[idx] = substr($0,y+16,4);
        DEBUG("IMDB: Got year "gYear[idx]);
    }
    if (gPoster[idx] == "" && index($0,"a name=\"poster\"")) {
        if (match($0,"src=\"[^\"]+\"")) {

            poster_imdb_url = substr($0,RSTART+5,RLENGTH-5-1);

            #Get high quality one
            sub(/SX[0-9]{2,3}_/,"SX400_",poster_imdb_url);
            sub(/SY[0-9]{2,3}_/,"SY400_",poster_imdb_url);

            getPoster(poster_imdb_url,idx);
            DEBUG("IMDB: Got poster");
        }
    }
    if (gPlot[idx] == "" && index($0,"Plot:")) {
        getline p;

        #Full plot . keep it for next time
        if ((i=index(p," <a")) > 0) {
            p=substr(p,1,i-1);
        }
        if ((i=index(p,"|")) > 0) {
            p=substr(p,1,i-1);
        }
        gPlot[idx]=p;
        DEBUG("IMDB: Got plot");
    }
    if (gGenre[idx] == "" && index($0,"Genre:")) {
        getline l;
        gsub(/<[^<>]+>/,"",l);
        sub(/ +more */,"",l);
        gGenre[idx]=l;
        DEBUG("IMDB: Got genre="l);
    }
    if (gRating[idx] == "" && index($0,"/10</b>")) {
        r=extractTagText($0,"b");
        gRating[idx]=r;
       DEBUG("IMDB: Got Rating="r);
    }
    if (index($0,"certificates") && match($0,"List[?]certificates=[^&]+")) {
        #<a href="/List?certificates=UK:15&&heading=14;UK:15">
        #<a href="/List?certificates=USA:R&&heading=14;USA:R">


        l=substr($0,RSTART,RLENGTH);
        l=substr(l,index(l,"=")+1);
        split(l,cert,":");
        
        #Now we only want to assign the certificate if it is in our desired list of countries.
        for(c in gCertificateCountries ) {
            if (gCertCountry[idx] == gCertificateCountries[c]) {
                #Keep certificate as this country is early in the list.
                break;
            }
            if (cert[1] == gCertificateCountries[c]) {
                #Update certificate
                gCertCountry[idx] = cert[1];
                gCertRating[idx] = cert[2];
                break;
            }
        }
    }
    # Title is the hardest due to original language titling policy.
    # Good Bad Ugly, Crouching Tiger, Two Brothers, Leon lots of fun!! 

    if (gAkaTitle[idx] == "" && index($0,"Also Known As:")) {
        l=substr($0,index($0,"</h")+5);
        split(l,akas,"<br>");
        for(a in akas) {
            for(c in gTitleCountries ) {
                if (index(akas[a],"("gTitleCountries[c]":")) {
                    #Ignore AKA section 
                    gAkaTitle[idx] = gTitle[idx];
                    next;
                    eEeE=")"; #Balance brakets in editor!
                }
                if (index(akas[a],"("gTitleCountries[c]")")) {
                    if (index(akas[a],"working") ||index(akas[a],"IMAX")||index(akas[a],"promotional")) {
                        #Ignore AKA section 
                        gAkaTitle[idx] = gTitle[idx];
                        next;
                    } else {
                        #Use first match from AKA section 
                        gAkaTitle[idx] = substr(akas[a],1,index(akas[a]," (")-1); 
                        next;
                    }
                        
                }
            }
        }
    }
    next;
}
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#%%%%%%%%%%%% NO CHANGE TO ANY FUNTIONS BELOW HERE %%%%%%%%%%%%%%%%%%%%%%
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function time(msg) {
    if (gLastTimeMsg != "") {
        DEBUG(gLastTimeMsg" completed in "systime()-gLastTime);
    }
    gLastTime=systime();
    gLastTimeMsg=msg;
    DEBUG("timing "msg);
}

function FINISHED_FILE() {

#    DEBUG("FILENAME="FILENAME "ARGIND="ARGIND" ARGC="ARGC);
#    for(i = ARGIND ; i <= ARGC ; i++ ) {
#        DEBUG("ARG["i"] = "ARGV[i]);
#    }

   DEBUG("END PHASE elapsed=" systime()-gTime);
   gTime=systime();

    if (NR==1) { START(); }
    if ( FNR==1 && FS!=" " ) { FS=" " ; $0 = $0 ; }

    CAPTURE_END();
    CAPTURE_LABEL="";

    if (gLAST_FILENAME != "") {
        CAPTURE_CLEAR(gLAST_FILENAME);
        gLAST_FILENAME="";
    }

    if (FILENAME != "'"$DUMMY_ONE_LINE_FILE"'" ) {
        if ( index(FILENAME,CAPTURE_PREFIX PID) == 1 ) {
            CAPTURE_LABEL=substr(FILENAME,length(CAPTURE_PREFIX));
            CAPTURE_LABEL=substr(CAPTURE_LABEL,index(CAPTURE_LABEL,"__")+2);
        } else {
            CAPTURE_LABEL=FILENAME;
        }
        gLAST_FILENAME = FILENAME;
        split(substr(CARGV_LIST[FILENAME],2),CARGV,substr(CARGV_LIST[FILENAME],1,1));
    }

    #Set the arg array for this capture.

   DEBUG("\n----------- START PHASE " FILENAME " ( "CARGV_LIST[FILENAME] " )   elapsed=" systime()-gTime);
   gTime=systime();

}

function relocate_files(\
    moveContentsQueue) {

   DEBUG("TV_FILE_FMT="TV_FILE_FMT);
   DEBUG("FILM_FOLDER_FMT="FILM_FOLDER_FMT);

    if ( TV_FILE_FMT FILM_FOLDER_FMT == "" ) return;

    split("",moveContentsQueue,"");
    for(i in gMovieFiles) {

        newName="";
        fileType="";
        if (TV_FILE_FMT != "" && gCategory[i] == "T") {
            oldName=gFolder[i]"/"gMovieFiles[i];
            newName=TV_FILE_FMT;
            newName = substitute("SEASON",gSeason[i],newName);
            newName = substitute("EPISODE",gEpisode[i],newName);
            newName = substitute("INFO",gAdditionalInfo[i],newName);

            epTitle=gEpTitle[i];
            if (epTitle == "") {
                epTitle = gEpTitleImdb[i];
            }
            gsub(/[^-A-Za-z0-9,. ]/,"",epTitle);
            gsub(/[{]EPTITLE[}]/,epTitle,newName);

            newName = substitute("EPTITLE",epTitle,newName);
            newName = substitute("0SEASON",sprintf("%02d",gSeason[i]),newName);
            newName = substitute("0EPISODE",sprintf("%02d",gEpisode[i]),newName);

            fileType="file";
        }

        if (FILM_FOLDER_FMT != "" && gCategory[i] == "M") {
            oldName=gFolder[i];
            newName=FILM_FOLDER_FMT;
            fileType="folder";
        }
        if (newName != "") {

            if (fileType == "file") {
                newName = substitute("NAME",gMovieFiles[i],newName);
                if (match(gMovieFiles[i],"\.[^.]+$")) {
                    #DEBUG("BASE EXT="gMovieFiles[i] " AT "RSTART);
                    newName = substitute("BASE",substr(gMovieFiles[i],1,RSTART-1),newName);
                    newName = substitute("EXT",substr(gMovieFiles[i],RSTART),newName);
                } else {
                    #DEBUG("BASE EXT="gMovieFiles[i] "]");
                    newName = substitute("BASE",gMovieFiles[i],newName);
                    newName = substitute("EXT","",newName);
                }
            }
            newName = substitute("DIR",gFolder[i],newName);
            
            if (gAkaTitle[i] != "" && gAkaTitle[i] != gTitle[i]) {
                newName = substitute("TITLE",gAkaTitle[i],newName);
            } else {
                newName = substitute("TITLE",gTitle[i],newName);
            }
            newName = substitute("YEAR",gYear[i],newName);
            newName = substitute("CERT",gCertRating[i],newName);
            newName = substitute("GENRE",gGenre[i],newName);

            #Remove characters windows doesnt like
            gsub(/[\\:*\"<>|]/,"_",newName); #"
            #Remove double slahses
            gsub(/\/\/+/,"/",newName);

            if (newName != oldName) {
               if (fileType == "folder") {
                   if (moveFolder(oldName,newName) != 0) {
                       continue;
                   }
                   gFile[i]="";
                   gFolder[i]=newName;
               } else {

                   # Move media file
                   if (moveFile(oldName,newName) != 0 ) {
                       continue;
                   }
                   gMediaCount[gFolder[i]]--;
                   gFile[i]=newName;
                   
                   oldFolder=gFolder[i];

                   newFolder=newName;
                   sub(/\/[^\/]+$/,"",newFolder);

                   #Update new folder location
                   gFolder[i]=newFolder;

                   gMovieFiles[i]=newName;
                   sub(/.*\//,"",gMovieFiles[i]);

                   # Move nfo file
                   if(gNfoExists[gNfoDefault[i]]) {
                       sub(/\....$/,".nfo",newName);
                       if (moveFile(gNfoDefault[i],newName) != 0) {
                           continue;
                       }
                       delete gNfoExists[gNfoDefault[i]] ;

                       gDate[newName]=gDate[gNfoDefault[i]];
                       delete gDate[gNfoDefault[i]];

                       gNfoDefault[i] = newName;
                       gNfoExists[gNfoDefault[i]] = 1;
                   }

                   if(gPoster[i] != "" && substr(gPoster[i],1,1)!= "/") {
                       oldName=oldFolder"/"gPoster[i];
                       newName=newFolder"/"gPoster[i];
                       if (moveFile(oldName,newName) != 0 ) {
                           continue;
                       }
                   }

                   #Rename any other associated files (sub,idx etc) etc.
                   rename_related(i,oldName,newName);

                   #Move everything else from old to new.
                   moveContentsQueue[oldFolder] = newFolder;

               }
            }
        }
    }
    for(i in moveContentsQueue) {
       cmd="mv \""i"\"/* \""moveContentsQueue[i]"\"";
       cmd=cmd" ; rmdir \""i"\"";
       exec(cmd);
   }
}

function substitute(keyword,value,str,\
    oldStr) {

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
        DEBUG("OLD PATH ["oldStr"]");
        DEBUG("NEW PATH ["str"]");
    }

    return str;
}

function rename_related(idx,oldName,newName,\
    f,extensions,ext,oldBase,newBase) {
    split("srt idx sub",extensions," ");

    oldBase = oldName;
    sub(/\....$/,".",oldBase);

    newBase = newName;
    sub(/\....$/,".",newBase);

    for(ext in extensions) {

        cmd = "mv \""oldBase extensions[ext]"\" \""newBase extensions[ext]"\"";
        DEBUG("RENAME RELATED "cmd);
        #system(cmd);
    }

}

function moveFile(oldName,newName,\
    cmd) {
   cmd="mkdir -p \""newName"\"";
   cmd=cmd " ; rmdir \""newName"\"";
   cmd=cmd " ; mv \""oldName (contents?"\*":"") "\" \""newName"\"";
   DEBUG("MV FILE "cmd);
   return exec(cmd);
}
function moveFolder(oldName,newName,\
    cmd) {
   if (gFolderCount[oldName] > 0) {
       WARNING(oldName" not renamed to "newName" due to "gFolderCount[oldName]" sub folders");
       return 1;
   } else if (gFolderMediaCount[oldName] > 1) {
       WARNING(oldName" not renamed to "newName" due to "gFolderMediaCount[oldName]" media files");
       return 1;
   } else {
       cmd="mkdir -p \""newName"\"";
       cmd=cmd " ; mv \""oldName"\"/* \""newName"\"";
       cmd=cmd " ; mv \""oldName"\"/.[^.]* \""newName"\""; #hidden files.
       cmd=cmd " ; rmdir \""oldName"\"";
       DEBUG("MV FOLDER "cmd);
       return exec(cmd);
   }
}

#Write a .nfo file if one didnt exist. This will make it easier 
#to rebuild the DATABASE_ARRAY at a later date. Esp if the file names are no
#longer appearing in searches.
function generate_nfo_files(\
    i,s,nfo) {
    for(i in gMovieFiles) {

        nfo=gNfoDefault[i];

        if (nfo != "" && !gNfoExists[nfo]) {
            DEBUG("Creating "nfo);
            s="";
            s=s"#Auto Generated NFO";
            s=s "\n:TITLE\t"gTitle[i];
            s=s "\n:URL\t"gExternalSourceUrl[i];
            if (gEpTitle[i] != "" ) { s=s "\n:EPTITLE\t"gEpTitle[i]; }
            if (gTvCom[i] != "" ) { s=s "\n:TVCOM\t"gTvCom[i]; }
            if (gSeason[i] != "" ) { s=s "\n:SEASON\t"gSeason[i]; }
            if (gEpisode[i] != "" ) { s=s "\n:EPISODE\t"gEpisode[i]; }
            if (gEpGuides[i] != "" ) { s=s "\n:EPGUIDES\t"gEpGuides[i]; }
            if (gProdCode[i] != "" ) { s=s "\n:PRODCODE\t"gProdCode[i]; }
            if (gEpTitleImdb[i] != "" ) { s=s "\n:EPTITLEIMDB\t"gEpTitleImdb[i]; }
            if (gAirDate[i] != "" ) { s=s "\n:AIRDATE\t"gAirDate[i]; }
            if (gAirDateImdb[i] != "" ) { s=s "\n:AIRDATEIMDB\t"gAirDateImdb[i]; }
            if (gPlot[i] != "" ) { s=s "\n:PLOT\t"gPlot[i]; }
            if (gPoster[i] != "" ) { s=s "\n:POSTER\t"gPoster[i]; }
            print s > nfo;
            close(nfo);
            gNfoExists[nfo]=1;
        }
    }
}
function read_generated_nfo(line,idx,\
    f) {
    #May be an info generated by generate_nfo_files()
    split($0,f,"\t");
    if (f[1] == ":EPTITLE") gEpTitle[idx]=f[2];
    else if (f[1] == ":TITLE") gTitle[idx]=f[2];
    else if (f[1] == ":URL") {
        gExternalSourceUrl[idx]=f[2];
        if (gCategory[idx] != "T") gCategory[idx]="M";
    } else if (f[1] == ":TVCOM") gTvCom[idx]=f[2];
    else if (f[1] == ":EPGUIDES") gEpGuides[idx]=f[2];
    else if (f[1] == ":PRODCODE") gProdCode[idx]=f[2];
    else if (f[1] == ":SEASON") { gSeason[idx]=f[2]; gCategory[idx]="T"; }
    else if (f[1] == ":EPISODE") { gEpisode[idx]=f[2]; gCategory[idx]="T"; }
    else if (f[1] == ":EPTITLEIMDB") gEpTitleImdb[idx]=f[2];
    else if (f[1] == ":AIRDATE") gAirDate[idx]=f[2];
    else if (f[1] == ":AIRDATEIMDB") gAirDateImdb[idx]=f[2];
    else if (f[1] == ":PLOT") gPlot[idx]=f[2];
    else if (f[1] == ":POSTER") gPoster[idx]=f[2];


}

# Some times epguide and imdb disagree. We only give a title if both are the same.
#
function fixTitles(\
    idx) {
    for(idx in gMovieFiles) {
        if (gTitle[idx] == "") {
            gTitle[idx] = gMovieFiles[idx];
            sub(/.*\//,"",gTitle[idx]); #remove path
            gsub(/[^A-Za-z0-9]/," ",gTitle[idx]); #remove odd chars
        }
        if ( '$FOLDERTITLES' == 1 ) {
            gTitle[i] = gFolder[i];
            gsub(/.*\//,"",gTitle[i]); #Remove path
        }
        gTitle[idx]=cleanTitle(gTitle[idx]);
    }
}

function get_best_episode_title(\
    idx,j,tvcom,epguideTitles,imdbTitle,egTitle) {

    for(idx in gMovieFiles) {
        if (gCategory[idx] == "T") {
            split(gTvCom[idx],tvcom,"\t");
            split(gEpTitle[idx],epguideTitles,"\t");
            imdbTitle=tolower(gEpTitleImdb[idx]);
            if (epguideTitles[2] != "") {
                DEBUG("Getting best episode title for "gTitle[idx]" s"gSeason[idx]"e"gEpisode[idx]" imdb"imdbTitle);
            }
            for(j in epguideTitles) {
                DEBUG("Checking episode titles "epguideTitles[j]);
                if (epguideTitles[j] != "" ) {
                  egTitle=tolower(epguideTitles[j]);
                  if (index(egTitle,imdbTitle ) == 1 || index(imdbTitle,egTitle) ==1 || index(imdbTitle,"Episode #") == 1) {
                    DEBUG("Title for epguide "epguideTitles[j]);
                    #Use the EpGuides title as this has part numbers.
                    gEpTitle[idx] = epguideTitles[j];
                    gTvCom[idx] = tvcom[j];
                    break;
                  } else {
                    DEBUG("Ignoring Title for epguide "epguideTitles[j]);
                  }
                }
            }
        }
    }
}
function append_new_index(outputFile,\
i,row,fields,f) {
    # Find the TVcom entry that best matches the IMDB entry.
    gMaxDatabaseId++;
    for(i in gMovieFiles) {

        # Estimated download date. cant use nfo time as these may get overwritten.
        estimate=gDate[gFolder[i]"/unpak.log"];
        if (estimate == "") {
            estimate=gDate[gFolder[i]"/unpak.txt"];
        }
        if (estimate == "") {
            estimate = gFileTime[i];
        }

        if (gFile[i] == "" ) {
            gFile[i]=gFolder[i]"/"gMovieFiles[i];
        }
        gsub(/\/\/+/,"/",gFile[i]);

        row="\t"ID"\t"(gMaxDatabaseId++);
        row=row"\t"WATCHED"\t0";
        row=row"\t"ACTION"\t0";

        #Title and Season must be kept next to one another to aid grepping.
        row=row"\t"TITLE"\t"gTitle[i];
        row=row"\t"SEASON"\t"gSeason[i];

        row=row"\t"EPISODE"\t"gEpisode[i];

        row=row"\t"0SEASON"\t"sprintf("%02d",gSeason[i]);
        row=row"\t"0EPISODE"\t"sprintf("%02d",gEpisode[i]);

        row=row"\t"AKA"\t"gAkaTitle[i];
        row=row"\t"YEAR"\t"gYear[i];
        row=row"\t"FILE"\t"gFile[i];
        row=row"\t"PARTS"\t"gParts[i];
        row=row"\t"URL"\t"gExternalSourceUrl[i];
        row=row"\t"CERT"\t"gCertCountry[i]":"gCertRating[i];
        row=row"\t"GENRE"\t"gGenre[i];
        row=row"\t"RATING"\t"gRating[i];
        row=row"\t"PLOT"\t"gPlot[i];
        row=row"\t"CATEGORY"\t"gCategory[i];
        row=row"\t"POSTER"\t"gPoster[i];
        row=row"\t"FILETIME"\t"gFileTime[i];
        if (gMovieFileCount > 10) {
            #bulk add - use the estimate download date as the index date.
            #this helps the index to appear to have some chronological order
            #on first build
            row=row"\t"INDEXTIME"\t"estimate;
        } else {
            row=row"\t"INDEXTIME"\t"NOW;
        }
        row=row"\t"DOWNLOADTIME"\t"estimate;
        row=row"\t"SEARCH"\t"gSearch[i];
        row=row"\t"PROD"\t"gProdCode[i];
        row=row"\t"AIRDATE"\t"gAirDate[i];
        row=row"\t"EPTITLEIMDB"\t"gEpTitleImdb[i];
        row=row"\t"AIRDATEIMDB"\t"gAirDateImdb[i];

        row=row"\t"TVCOM"\t"gTvCom[i];
        row=row"\t"EPTITLE"\t"gEpTitle[i];
        nfo="";
        if (gNfoExists[gNfoDefault[i]]) {
            nfo=gNfoDefault[i];
            gsub(/.*\//,"",nfo);
        }
        row=row"\t"NFO"\t"nfo;

        print row"\t" >> outputFile;

        INFO("------------------------------");
        split(row,fields,"\t");
        fcount=0;
        for(f in fields) fcount++;
        for(f=1; f<=fcount; f++) {
            if (f%2) {
                if(fields[f] != "" ) INFO(inf"=["fields[f]"]");
            } else {
                inf=gDbFieldName[fields[f]]; 
            }
        }

    }
    close(outputFile);
}

END {
    ELAPSED_TIME=systime()-ELAPSED_TIME;
    DEBUG(sprintf("Finished: Elapsed time %dm %ds",int(ELAPSED_TIME/60),(ELAPSED_TIME%60)));
    system("cp -f \""INDEX_DB"\" \""INDEX_DB".old\" ; mv -f \""INDEX_DB".new\" \""INDEX_DB"\" && mv -f \""INDEX_DB"\".idx.new \""INDEX_DB"\".idx ");
    system("chown nmt:nmt \""INDEX_DB"\"*");
    clean_capture_files();
}


#--------------------------------------------------------------------
# Convinience function. Create a new file to capture some information.
# This is then added to awk arguments and should be picked up with a 
# new rule FILENAME == xxx { }
# At the end capture files are deleted.
#--------------------------------------------------------------------
function NEW_CAPTURE_FILE(label,CAPTURE_ARGS,ARG_SEP,\
    CAPTURE_FILE,suffix) {
    suffix= "." CAPTURE_COUNT "__" label;
    CAPTURE_FILE = CAPTURE_PREFIX PID suffix;
    CAPTURE_COUNT++;
   #DEBUG("New capture file "label" ["CAPTURE_FILE "]");
    print "" >> CAPTURE_FILE;
    close(CAPTURE_FILE);
    APPEND_CONTENT(CAPTURE_FILE,CAPTURE_ARGS,ARG_SEP);
    return CAPTURE_FILE;
}

function CAPTURE_CLEAR(lastFile) {
    if (index(lastFile,CAPTURE_PREFIX) == 1) {
        #DEBUG("Cleaning "lastFile);
        delete CARGV_LIST[lastFile];
        system("rm -f -- "lastFile); 
    }
}

#Add a file to the list of arguments. 
function APPEND_CONTENT(file,CAPTURE_ARGS,ARG_SEP) {

    #If last file is a dummy file then overwrite it (unless it is the current file!)
    if (ARGIND+1 < ARGC ) {
        if (ARGV[ARGC-1] == "'"$DUMMY_ONE_LINE_FILE"'" ) {
            ARGC--;
        }
    }

   DEBUG("Queue content : "file);
    ARGV[ARGC++] = file;

    #Store any extra info to pass to this capture.
    if (ARG_SEP == "") { ARG_SEP="|"; }
    CARGV_LIST[file]=ARG_SEP CAPTURE_ARGS;

    # We always add the dummy to prevent the END block firing too soon, once 
    #the END fires , no more inputs can be added. By using a dummy file we can
    # insert additional processing when each file is finished. See CAPTURE_END()
    ARGV[ARGC++] = "'"$DUMMY_ONE_LINE_FILE"'"; 
}

function isLastFile() {
    return ARGIND+1 == ARGC;
}

# Return 1 if captures are pending. 
function CAPTURES_PENDING_OLD(\
    i,pending) {
    pending=0;
    for(i = ARGIND+1 ; i < ARGC ; i++ ) {
        if (ARGV[i] != "'$DUMMY_ONE_LINE_FILE'" && !index(ARGV[i],"=") ) {
            return 1;
        }
    }
    return 0;
}

function clean_capture_files(\
cmd,file) {
    exec("rm -f -- \""CAPTURE_PREFIX PID "\".* '$DUMMY_ONE_LINE_FILE'");
    delete CARGV_LIST;
}
function INFO(x) {
    print "[INFO] '$LOG_TAG'"x;
}
function WARNING(x) {
    print "[WARNING] '$LOG_TAG'"x;
}
function ERROR(x) {
    print "[ERROR] '$LOG_TAG'"x;
}
function DETAIL(x) {
    print "[DETAIL] '$LOG_TAG'"x;
}

function right(str,x) {
    if (x >= 0) {
        return substr(str,length(str)-x+1);
    } else {
        return substr(str,-x+1);
    }
}

function left(str,x) {
    if (x >= 0) {
        return substr(str,1,x);
    } else {
        return substr(str,1,length(str)+x);
    }
}
function trim(str) {
    gsub(/^ +/,"",str);
    gsub(/ +$/,"",str);
    return str;
}

function startsWith(str,x) {
    return index(str,x) == 1;
}

#---------------------------------------------------------------------
# HEAPSORT from wikipedia --------------------------------------------
#---------------------------------------------------------------------
# Adapted to sorts the data via the index array.
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
    while(root*2+1 <= end) {
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
#Return true if idx1 < idx2 (if idx1 >= idx2 return 0)
function compare(fieldName,fieldOrder,idx,arr,idx1,idx2,
    a,b) {

   a=arr[fieldName,idx[idx1]];
   b=arr[fieldName,idx[idx2]];
   if  (a > b) {
       return fieldOrder;
   } else {
       return -fieldOrder;
   }
}


' PID=$$ NOW=`date +%Y%m%d%H%M%S` IGNORENFO=$IGNORENFO HOME=$HOME DEBUG=$DEBUG "NZB=$NZB" "INDEX_DB=$INDEX_DB" "$UNPAK_CFG" "$INDEX_DB" "$DUMMY_ONE_LINE_FILE" 2>&1 

    CLEAN_TMP
    chown $OWNER:$GROUP $INDEX_DB*
}

# no flock command
GET_LOCK() {

    try=1
    while [ $try = 1 ] ; do
        if [ ! -f "$1" ] ; then 
            try=0
        else
            if [ ! -d /proc/`cat "$1"` ] ; then
                try=0
            else
                sleep 5
            fi
        fi
    done
    echo $$ > "$1"
}

#-------------------------------------------------------------------------

LOCK="$HOME/catalog.lck"

CLEAN_TMP() {
    rm -f /tmp/catalog.[0-9]*__* /tmp/awk.[0-9]*.0_DUMMY 2>/dev/null || true
}

CLEAN_LOGS() {
    find "$HOME/logs" -name \*log -mtime +1 | while IFS= read f ; do
        rm -f -- "$f"
    done
}

CLEAN_LOGS
if [ $FORCE = 1 -o $FOLDER_COUNT -gt 1 ] ; then
    LOG_TAG=
    LOG_FILE="$HOME/logs/catalog.`date +%d%H%M`.$$.log"
    GET_LOCK $LOCK > $LOG_FILE
    MAIN >> $LOG_FILE
    echo $LOG_FILE
else
    LOG_TAG="ctlg:"
    GET_LOCK $LOCK
    MAIN
fi

rm -f -- "$LOCK"

# vi:sw=4:et:ts=4
