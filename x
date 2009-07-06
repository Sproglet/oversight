 #catalog.awk
 
 #Pad episode but dont assume its a number .eg 03a for Big Brother
 function padEpisode(e) {
     if (match(e,"^[0-9][0-9]")) {
         return e;
     } else {
         return "0"e;
     }
 }
 
 function DEBUG(x) {
         
     if ( DBG ) {
         print "[DEBUG]  " (systime()-ELAPSED_TIME)" : " x;
     }
 
 }
 
 # Load configuration file
 function loadSettings(file_name,\
 i,n,v) {
 
     INFO("load "file_name);
     FS="\n";
     while((getline option < file_name ) > 0 ) {
 
         #remove comment - hash without a preceeding blackslash
         if ((i=match(option,"[^\\\\]#")) > 0) {
             option = substr(option,1,i);
         }
 
         #remove spaces around =
         sub(/ *= */,"=",option);
         option=trim(option);
         # remove outer quotes
         sub("=[\""gQuote"]","=",option);
         sub("[\""gQuote"]$","",option);
         if (match(option,"^[A-Za-z0-9_]+=")) {
             n=substr(option,1,RLENGTH-1);
             v=substr(option,RLENGTH+1);
             gsub(/ *[,|] */,"|",v);
 
             if (n in gSettings) {
                 WARNING("Duplicate setting "n"=["v"]");
             }
             gSettings[n] = v;
             gSettingsOrig[n]=v;
             INFO(n"=["v"]");
         }
     }
     close(file_name);
 }
 
 # Note we dont call the real init code until after the command line variables are read.
 BEGIN {
     g_opt_dry_run=0;
     yes="yes";
     no="no";
     gQuote="'\''";
 
     gImdbIdRegex="\\<tt[0-9]+\\>";
 
     gTime=ELAPSED_TIME=systime();
     if (gunzip != "") {
         INFO("using gunzip="gunzip);
     }
     get_folders_from_args(FOLDER_ARR);
 }
 
 END{
     apikey="A110A5718F912DAF";
 
     load_catalog_settings(APPDIR"/catalog.cfg");
 
     INDEX_DB_NEW = INDEX_DB "." PID ".new";
     INDEX_DB_OLD = INDEX_DB ".old";
 
     INDEX_DB_OVW = INDEX_DB ".idx";
     INDEX_DB_OVW_NEW = INDEX_DB_OVW "." PID ".new";
 
 
     DEBUG("RENAME_TV="RENAME_TV);
     DEBUG("RENAME_FILM="RENAME_FILM);
 
     setDbFields();
 
     #Values for action field
     ACTION_NONE="0";
     ACTION_REMOVE="r";
     ACTION_DELETE_MEDIA="d";
     ACTION_DELETE_ALL="D";
 
     poster_prefix = gSettings["catalog_poster_prefix"];
     if (gSettings["catalog_poster_location"] == "internal" ) {
         poster_prefix = "ovs:" POSTER "/" poster_prefix;
     }
 
     gSettings["catalog_format_tags"]="\\<("tolower(gSettings["catalog_format_tags"])")\\>";
 
     gsub(/ /,"%20",gSettings["catalog_cert_country_list"]);
     split(gSettings["catalog_cert_country_list"],gCertificateCountries,"|");
 
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
 
     split(gSettings["catalog_title_country_list"],gTitleCountries,"|");
 
     monthHash("Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec",gMonthToNum);
     monthHash("January,February,March,April,May,June,July,August,September,October,November,December",gMonthToNum);
 
     #For caps function
     ABC_STR="ABCDEFGHIJKLMNOPQRSTUVWXYZ";
     abc_str=tolower(ABC_STR);
     split(ABC_STR,ABC,"");
     split(abc_str,abc,"");
     
     if ( gSettings["catalog_tv_file_fmt"] == "" ) RENAME_TV=0;
     if  ( gSettings["catalog_film_folder_fmt"] == "") RENAME_FILM=0;
 
     CAPTURE_PREFIX="/tmp/catalog."
 
     ov_count=0;
 
     THIS_YEAR=substr(NOW,1,4);
 
     if (RESCAN == 1) {
         INFO("Scanning default paths");
         split(gSettings["catalog_scan_paths"],FOLDER_ARR,"[,|]");
     }
 
     for(f in FOLDER_ARR) {
        DEBUG("Folder:\t"FOLDER_ARR[f]);
     }
     gMovieFileCount = 0;
     gMaxDatabaseId = 0;
     DB_SIZE = loadDatabase(DB_ARR,file_to_db);
     
     if (!g_opt_no_actions) {
         loadSettings("/home/alord/devel/oversight/unpak.cfg");
         unpak_nmt_pin_root=unpak_option["unpak_nmt_pin_root"];
     }
 
     if (1 in FOLDER_ARR) {
 
         scan_folder_for_new_media(FOLDER_ARR);
 
         process_scanned_files();
     }
 
 
     if (g_opt_dry_run) {
 
         INFO( "End dry_run");
 
     } else {
 
         remove_absent_files_from_new_db(DB_SIZE,DB_ARR,INDEX_DB_NEW); 
 
         remove_files_with_delete_actions(DB_ARR,DB_SIZE);
 
         add_new_scanned_files_to_database(INDEX_DB_NEW,DB_SIZE,DB_ARR,file_to_db);
 
         ov_count = build_overview_array(INDEX_DB_NEW,overview_db);
 
         add_overview_indices(overview_db,ov_count);
 
         write_overview(overview_db,ov_count,INDEX_DB_OVW_NEW);
 
         replace_database_with_new();
     }
 
     clean_capture_files();
 
     et=systime()-ELAPSED_TIME;
 
     for(dm in g_search_count) {
         DEBUG(dm" : "g_search_count[dm]" searches"); 
     }
     DEBUG("Direct search hits/misses = "g_direct_search_hit"/"g_direct_search_miss);
     DEBUG("Deep search hits/misses = "g_deep_search_hit"/"g_deep_search_miss);
     DEBUG(sprintf("Finished: Elapsed time %dm %ds",int(et/60),(et%60)));
 
     #Check script
     for(i in gSettings) {
         if (!(i in gSettingsOrig)) {
             WARNING("Undefined setting "i" referenced");
         }
     }
 }
 
 function monthHash(nameList,hash,\
 names) {
     split(nameList,names,",");
     for(i in names) {
         hash[tolower(names[i])] = i+0;
     }
 } 
 
 function replace_database_with_new() {
 
     INFO("Replace Database");
 
     system("cp -f \""INDEX_DB"\" \""INDEX_DB_OLD"\"");
 
     touchAndMove(INDEX_DB_NEW,INDEX_DB);
     touchAndMove(INDEX_DB_OVW_NEW,INDEX_DB_OVW);
 
     setPermissions(quoteFile(INDEX_DB)"*");
 }
 
 function setPermissions(shellArg) {
     if (ENVIRON["USER"] != alord ) {
         system("chown alord:None "shellArg);
     }
 }
 
 function caps(text,\
 i,j) {
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
 
 function setDbFields() {
     #DB fields should start with underscore to speed grepping etc.
     ID=dbField("_id","ID","",0);
 
     #List of all related detail items. ie tv shows in same season
     OVERVIEW_DETAILIDLIST=dbField("_did" ,"Ids","",0);
     OVERVIEW_EXT_LIST = dbField("_ext","Extensions","",0);
 
     WATCHED=dbField("_w","Watched","watched",0) ;
     ACTION=dbField("_a","Next Operation","",0); # ACTION Tell catalog.sh to do something with this entry (ie delete)
     PARTS=dbField("_pt","PARTS","","");
     FILE=dbField("_F","FILE","filenameandpath","");
     NAME=dbField("_N","NAME","","");
     DIR=dbField("_D","DIR","","");
 
 
     ORIG_TITLE=dbField("_ot","ORIG_TITLE","originaltitle","");
     TITLE=dbField("_T","Title","title",".titleseason") ;
     AKA=dbField("_K","AKA","","");
 
     CATEGORY=dbField("_C","Category","",0);
     ADDITIONAL_INFO=dbField("_ai","Additional Info","","");
     YEAR=dbField("_Y","Year","year",0) ;
 
     SEASON=dbField("_s","Season","season",0) ;
     EPISODE=dbField("_e","Episode","episode","");
     SEASON0=dbField("0_s","0SEASON","","");
     EPISODE0=dbField("0_e","0EPISODE","","");
 
     GENRE=dbField("_G","Genre","genre",0) ;
     RATING=dbField("_r","Rating","rating","");
     CERT=dbField("_R","CERT","mpaa",0); #Not standard?
     PLOT=dbField("_P","Plot","plot","");
     URL=dbField("_U","URL","url","");
     POSTER=dbField("_J","Poster","thumb",0);
 
     DOWNLOADTIME=dbField("_DT","Downloaded","",0);
     INDEXTIME=dbField("_IT","Indexed","",1);
     FILETIME=dbField("_FT","Modified","",0);
 
     SEARCH=dbField("_SRCH","Search URL","search","");
     PROD=dbField("_p","ProdId.","","");
     AIRDATE=dbField("_ad","Air Date","aired","");
     TVCOM=dbField("_tc","TvCom","","");
     EPTITLE=dbField("_et","Episode Title","title","");
     EPTITLEIMDB=dbField("_eti","Episode Title(imdb)","","");
     AIRDATEIMDB=dbField("_adi","Air Date(imdb)","","");
     NFO=dbField("_nfo","NFO","nfo","");
 
     IMDBID=dbField("_imdb","IMDBID","id","");
 }
 
 
 #Setup dbField identifier, pretty name , and overview field.
 #overview == "" : dont add to overview
 #overview == 0 : add to overview
 #overview == 1 : add to overview and create index using field "key"
 #overview == field2 : add to overview and create index using field "field2"
 function dbField(key,name,tag,overview) {
     gDbFieldName[key]=name;
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
 
     #Need to make sure the ls format is as "standard"
     gLS_FILE_POS=0;
     gLS_TIME_POS=0; 
 
     temp=NEW_CAPTURE_FILE("MOVIEFILES")
 
     findLSFormat(temp);
 
     for(f in folderArray) {
         scan_contents(folderArray[f],temp);
     }
 }
 
 function findLSFormat(temp,\
 folderNameNext,i) {
     DEBUG("Finding LS Format");
     exec(LS" -Rl /proc/"PID" > "temp );
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
                     for(i=1 ; i <= NF ; i++ ) {
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
 
 # Input is ls -lR or ls -l
 function scan_contents(root,temp,
 currentFolder,skipFolder,i,j,folderNameNext,perms,w5,lsMonth,lsDate,lsTimeOrYear,f,d,extRe) {
 
     DEBUG("PreScanning "root);
     if (root == "") return;
 
     #Remove trailing slash. This ensures all folder paths end without trailing slash
     if (root != "/" ) {
         gsub(/\/+$/,"",root); 
     }
 
     quotedRoot=quoteFile(root);
 
     extRe="\\.[^.]+$";
 
     #We use ls -R instead of find to get a sorted list.
     #There may be some issue with this.
 
     #First file /proc/$$ is to check ls format
     DEBUG("Scanning "quotedRoot);
     # We want to list a file which may be a file, folder or symlink.
     # ls -Rl x/ will do symlink but not normal file.
     #so do  ls -Rl x/ || ls -Rl x  
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
             #Just entered a folder
            currentFolder = $0;
            sub(/\/*:/,"",currentFolder);
            DEBUG("Folder = "currentFolder);
            folderNameNext=0;
             if ( currentFolder ~ gSettings["catalog_ignore_paths"] ) {
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
 
             if ( lc ~ gSettings["catalog_ignore_names"] ) {
                 INFO("Ignore name "$0);
                 continue;
             }
 
             w5=lsMonth=lsDate=lsTimeOrYear="";
 
             # ls -l format. Extract file time...
             w5=$5;
 
             if ( gLS_TIME_POS ) {
                 lsMonth=$(gLS_TIME_POS-2);
                 lsDate=$(gLS_TIME_POS-1);
                 lsTimeOrYear=$(gLS_TIME_POS);
             }
 
             #Get Position of word at gLS_FILE_POS.
             #(not cannot change $n variables as they cause corruption of $0.eg 
             #double spaces collapsed.
             pos=index($0,$2);
             for(i=3 ; i <= gLS_FILE_POS ; i++ ) {
                 pos=indexFrom($0,$i,pos+length($(i-1)));
             }
             $0=substr($0,pos);
             lc=tolower($0);
 
             #Check for VIDEO_TS
             if (substr(perms,1,1) != "-") {
                 if (substr(perms,1,1) == "d") {
                     #Directory
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
                 #ISO images.
 
                 if (length(w5) < 10) {
                     INFO("Skipping image - too small");
                 } else {
                     store=1;
                 }
 
             } else if (match($0,"unpak.???$")) {
                 
                 gDate[currentFolder"/"$0] = calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW);
 
             } else if (match(lc,gExtRegEx1)) {
 
                 DEBUG("gFolderMediaCount[currentFolder]="gFolderMediaCount[currentFolder]);
                 #Only add it if previous one is not part of same file.
                 if (gFolderMediaCount[currentFolder] > 0 && gMovieFileCount >= 1 ) {
                   if ( checkMultiPart($0,gMovieFileCount) ) {
                       #replace xxx.cd1.ext with xxx.nfo (Internet convention)
                       #otherwise leave xxx.cd1.yyy.ext with xxx.cd1.yyy.nfo (YAMJ convention)
                       setNfo(gMovieFileCount-1,".(|cd|disk|disc|part)[1-9]" extRe,".nfo");
                   } else {
                       store=2;
                   }
                } else {
                    #This is the first/only avi for this film/show
                    store=2;
                }
 
             } else if (match(lc,"\\.nfo$")) {
 
                 nfo=currentFolder"/"$0;
                 gNfoExists[nfo]=1;
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
 
 # Convert a glob pattern to a regular exp.
 # *=anything,?=single char, <=start of word , >=end of word |=OR
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
 
     #used when pruning the old index.
     gMovieFilePresent[folder"/"file] = 1;
     gFileTime[idx] = timeStamp;
 }
 
 #Check if a filename is similar to the previous stored filename.
 # lcName         : lower case file name
 # count          : next index in array
 # multiPartRegex : regex that matches the part tag of the file
 function checkMultiPart(name,count,\
 i,firstName) {
     firstName=gMovieFiles[count-1];
 
     DEBUG("Multipart check ["firstName"] vs ["name"]");
     if (length(firstName) != length(name)) {
         DEBUG("length ["firstName"] != ["name"]");
         return 0;
     }
     if (firstName == name) return 0;
 
     for(i=1 ; i <= length(firstName) ; i++ ) {
         if (substr(firstName,i,1) != substr(name,i,1)) {
             break;
         }
     }
     DEBUG("difference at "i);
 
     if (substr(firstName,i+1) != substr(name,i+1)) {
         DEBUG("no match last bit ["substr(firstName,i+1)"] != ["substr(name,i+1)"]");
         return 0;
     }
 
     if (substr(firstName,i-1,2) ~ "[^0-9]1" || substr(firstName,i-2,3) ~ "[^EeXx0-9][0-9]1" ) {
         # Avoid matching tv programs e0n x0n 11n
         # At this stage we have not done full filename analysis to determine if it matches a tv program
         # That is done during the scrape stage by "checkTvFilenameFormat". This is just a quick way.
         # It makes sure the character 2 digits before is not E,X or 0-9. It will fail the name is cd001 
         if (!(substr(name,i,1) ~ "[2-9]")) {
             DEBUG("no match on [2-9]"substr(name,i,1));
             return 0;
         }
         #continue 
     } else if (substr(firstName,i,1) ~ "[Aa]") {
         if (!(substr(name,i,1) ~ "[A-Fa-f]")) {
             DEBUG("no match on [A-Fa-f]"substr(name,i,1));
             return 0;
         }
         #continue 
     } else {
         DEBUG("no match on [^0-9][Aa1]");
         return 0;
     }
 
     INFO("Found multi part file - linked with "firstName);
     gParts[count-1] = (gParts[count-1] =="" ? "" : gParts[count-1]"/" ) name;
     gMultiPartTagPos[count-1] = i;
     return 1;
 }
 
 # set the nfo file by replacing the pattern with the given text.
 function setNfo(idx,pattern,replace,\
 nfo,lcNfo) {
     #Add a lookup to nfo file
     nfo=gMovieFiles[idx];
     lcNfo = tolower(nfo);
     if (match(lcNfo,pattern)) {
         nfo=substr(nfo,1,RSTART-1) replace substr(nfo,RSTART+RLENGTH);
         gNfoDefault[idx] = getPath(nfo,gFolder[idx]);
         DEBUG("Storing default nfo path ["gNfoDefault[idx]"]");
     }
 }
 
 function exec(cmd, err) {
    DEBUG("SYSTEM : "substr(cmd,1,100)"...");
    if ((err=system(cmd)) != 0) {
       ERROR("Return code "err" executing "cmd) ;
   }
   return err;
 }
 
 #The new index is read again to create the overview index
 function build_overview_array(databaseIndex,overview_db,\
 i,ext,seriesId,fields,ep1,ov_count,firstTvSeriesEntry) {
 
     DEBUG("build_overview_array");
     FS="\t";
     ov_count=0;
     while((getline < databaseIndex ) > 0 ) {
 
         if (substr($0,1,1) == "\t") {
 
             delete fields;
             for(i=2 ; i < NF ; i+= 2 ) {
                 fields[$i] = $(i+1);
             }
 
             #If there is some kind of pending action, but actions are disabled, then we dont
             #want to add this record to the overview 
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
 
             if (fields[CATEGORY] != "T" || !( seriesId in firstTvSeriesEntry )) {
 
                 #Just add this item if its not a tv show or the first occurence of tv show.
                 fields[OVERVIEW_EXT_LIST]=ext;
                 fields[OVERVIEW_DETAILIDLIST]=fields[ID];
 
                 #DEBUG("Overview idlist ["seriesId"] = "fields[OVERVIEW_DETAILIDLIST]"]");
                 if (fields[CATEGORY] == "T") {
                     firstTvSeriesEntry[seriesId] = ov_count;
                 }
 
                 sub(/^[Tt]he /,"",seriesId);
                 overview_db[".titleseason",ov_count] = seriesId;
 
                 for(i in OVERVIEW_FIELDS) {
                     if(i in fields) {
                         overview_db[i,ov_count] = fields[i];
                     }
                 }
                 #Add the full file for uncategorised items
                 if (fields[CATEGORY] == "") {
                     overview_db[FILE,ov_count] = fields[FILE];
                 }
                 ov_count++;
 
             } else {
 
                 #Seen this tv show already, update the existing tv entry (id,ext and timestamps)
                 ep1 = firstTvSeriesEntry[seriesId];
 
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
     return ov_count;
 }
 
 function add_overview_indices(overview_db,ov_count,\
     f) {
 
     DEBUG("add_overview_indices");
 
     # Now add the sorted indices..
 
     for(f in OVERVIEW_FIELDS) {
         if (OVERVIEW_FIELDS[f] != 0) {
             add_overview_index(overview_db,ov_count,f);
         }
     }
 }
 
 # Add a sorted index to the data
 function add_overview_index(overview_db,ov_count,name,
   row,ord) {
     for(row = 0 ; row < ov_count ; row++ ) {
         ord[row]=row;
     }
 
     sortField=OVERVIEW_FIELDS[name];
     if (substr(sortField,1,1) == ".") {
         sortField = substr(sortField,2);
     }
     DEBUG("Creating index for "name" using "sortField" on "ov_count" items");
     heapsort(ov_count, OVERVIEW_FIELDS[name],1,ord,overview_db);
 
     #Note ord[] maps a sort position to a record index
     #When storing against a record we need to store the sort position
     #so store row(position) in record ord[row](index)
     for(row = 0 ; row < ov_count ; row++ ) {
         overview_db["#"name"#",ord[row]] = row;
     }
 }
 
 #Write the new array - except for hidden fields.
 function write_overview(arr,arrSize,outFile,\
     line,r,f,dim,sep,fld,idx) {
 
     INFO("write_overview");
     for(f in arr) {
 #        split(f,dim,SUBSEP);
 #        if (substr(dim[1],1,1) != ".") {
 #            line[dim[2]] = line[dim[2]]  dim[1] "\t" arr[f] "\t";
 #        }
         if (substr(f,1,1) == ".") continue;
         sep = index(f,SUBSEP);
         fld=substr(f,1,sep-1);
         idx = substr(f,sep+1);
         line[idx] = line[idx] fld "\t" arr[f] "\t" ;       
     }
     for(r in line) {
         print "\t"line[r] > outFile;
     }
     delete line;
 }
 
 #A folder is relevant if it is tightly associated with the media it contains.
 #ie it was created just for that film or tv series.
 # True is the folder was included as part of the scan and is specific to the current media file
 function folderIsRelevant(dir) {
 
     DEBUG("Check parent folder relation to media ["dir"]");
         if ( !(dir in gFolderCount) || gFolderCount[dir] == "") { 
             DEBUG("unknown folder ["dir"]" );
             return 0;
         }
     #Ensure the folder was scanned and also it has 2 or fewer sub folders (VIDEO_TS,AUDIO_TS)
     if (gFolderCount[dir] > 2 ) {
         DEBUG("Too many sub folders - general folder");
         return 0;
     }
    if (gFolderMediaCount[dir] > 2 ) {
        DEBUG("Too much media  general folder");
        return 0;
    }
    return 1;
 }
 # If no direct urls found. Search using file names.
 function searchInternetForImdbLink(idx,\
 url,triedTitles,txt,titlesRequired,linksRequired) {
 
     titlesRequired = 0+gSettings["catalog_imdb_titles_required"];
     linksRequired = 0+gSettings["catalog_imdb_links_required"];
     
     txt = basename(gMovieFiles[idx]);
     if (tolower(txt) != "dvd_volume" ) {
         url=searchHeuristicsForImdbLink(idx,txt,triedTitles,titlesRequired,linksRequired);
     }
 
     if ( url == "" ) {
         txt2 = remove_scene_name_and_parts(idx);
         if (txt2 != txt ) {
             #Because we have lost some info (the release group is removed) the required threshold is increased.
             url=searchHeuristicsForImdbLink(idx,txt2,triedTitles,titlesRequired+1,linksRequired+1);
         }
     }
 
     if (url == "" && match(gMovieFiles[idx],gExtRegexIso)) {
         txt = getIsoTitle(gFolder[idx]"/"gMovieFiles[idx]);
         if (length(txt) > 3 ) {
             url=searchHeuristicsForImdbLink(idx,txt,triedTitles,titlesRequired,linksRequired);
         }
     }
 
     if (url == "" && folderIsRelevant(gFolder[idx])) {
         url=searchHeuristicsForImdbLink(idx,basename(gFolder[idx]),triedTitles,titlesRequired,linksRequired);
     }
 
     return url;
 }
 
 function remove_scene_name_and_parts(idx,\
 txt) {
     # Remove first word - which is often a scene tag
     #This could affect the search adversely, esp if the film name is abbreviated.
     # Too much information is lost. eg coa-v-xvid will eventually become just v
     #so we do this last. 
     txt = tolower(basename(gMovieFiles[idx]));
 
     #Remove the cd1 partb bit.
     if (idx in gMultiPartTagPos) {
         txt = substr(txt,1,gMultiPartTagPos[idx]-1);
     }
 
     #remove scene name - hopefully
     sub(/^[a-z]{1,4}-/,"",txt);
 
     return txt;
 }
 
 function mergeSearchKeywords(text,keywordArray,\
 heuristicId) {
     # Build array of different styles of keyword search. eg [a b] [+a +b] ["a b"]
     for(heuristicId =  0 ; heuristicId <= 1 ; heuristicId++ ) {
         keywords =fileNameToSearchKeywords(text,heuristicId);
         keywordArray[keywords]=1;
     }
 }
 
 
 function searchHeuristicsForImdbLink(idx,text,triedTitles,titlesRequired,linksRequired,\
 heuristicId,bestUrl,k,k2,x,keywords,text_no_underscore) {
 
     mergeSearchKeywords(text,k);
 
     text_no_underscore = text;
     gsub(/_/," ",text_no_underscore);
     gsub("[[][^]]+[]]","",text_no_underscore);
     if (text_no_underscore != text) {
         mergeSearchKeywords(text_no_underscore,k);
     }
 
     bestUrl = searchArrayForIMDB(k,linksRequired,triedTitles);
 
     if (bestUrl == "" ) {
         bestUrl = deepSearchArrayForIMDB(idx,k,titlesRequired,linksRequired,triedTitles);
     }
 
     return bestUrl;
 }
 
 # Try all of the array indexs(not values) in web search for imdb link.
 # Try with and without tv tags
 function searchArrayForIMDB(k,linkThreshold,triedTitles,\
 bestUrl,keywords,keywordsSansEpisode) {
 
     DEBUG("direct search...");
     bestUrl = searchArrayForIMDB2(k,linkThreshold,triedTitles);
 
     if (bestUrl == "") {
         # Remove episode tags and try again
         for(keywords in k) {
             if (sub(/ *s[0-9][0-9]e[0-9][0-9].*/,"",keywords)) {
                 keywordsSansEpisode[keywords]=1;
             }
         }
         bestUrl = searchArrayForIMDB2(keywordsSansEpisode,linkThreshold,triedTitles);
     }
 
     DEBUG("direct search : nothing found");
     g_direct_search_miss++;
     return bestUrl;
 }
 
 function searchArrayForIMDB2(k,linkThreshold,triedTitles,\
 bestUrl,keywords) {
     # Try simple keyword searches with imdb keywords added.
     for(keywords in k) {
         DEBUG("direct search ["keywords"]...");
         if (keywords in triedTitles) {
             INFO("Already tried ["keywords"]");
         } else {
             INFO("direct search ["keywords"]");
             bestUrl = searchForIMDB(keywords,linkThreshold);
             if (bestUrl != "") {
                 INFO("direct search : Found ["bestUrl"]with direct search ["keywords"]");
                 g_direct_search_hit++;
                 return bestUrl;
             }
         }
     }
     return "";
 }
 
 # Try all of the array indexs(not values) in deep web search for imdb link.
 # Deep search = just search without imdb to get titles from results then find common substring and 
 # use this substring for imdb search.
 function deepSearchArrayForIMDB(idx,k,titleThreshold,linkThreshold,triedTitles,\
 bestUrl,keywords,text) {
     #Try deep searches.
     for(keywords in k) {
         #text=searchForBestTitleSubstring(keywords "+nfo+download" ,titleThreshold);
         text=searchForBestTitleSubstring(keywords ,titleThreshold);
         bestUrl = deepSearchStep2(idx,keywords,text,linkThreshold,triedTitles);
         if (bestUrl == "" ) {
             # search without episode tag
             if (sub(/ *s[0-9][0-9]e[0-9][0-9].*/,"",text)) {
                 bestUrl = deepSearchStep2(idx,keywords,text,linkThreshold,triedTitles);
             }
         }  
         if (bestUrl != "" ) {
             return bestUrl;
         }
    }
    return "";
 }
 function deepSearchStep2(idx,keywords,text,linkThreshold,triedTitles,\
 bestUrl) {
     if (text != "" ) {
 
         if (text in triedTitles) {
             INFO("Already tried ["text"]");
         } else {
             DEBUG("deep search ["keywords"] => ["text"]");
             triedTitles[text]++;
 
             if (0 && gCategory[idx] == "T") {
                 ##bestUrl=getAllInfoFromEpguidesAndImdbLink(idx,text);
                 bestUrl=getAllTvInfoAndImdbLink(idx,text);
             }
             if (bestUrl == "") {
 
                 #Now search this common title string together with imdb links.
                 bestUrl = searchForIMDB(text,linkThreshold);
             }
             if (bestUrl != "") {
                 INFO("Found with deep search ["keywords"]=>["text"]");
                 g_deep_search_hit++;
                 return bestUrl;
             }
         }
     }
     g_deep_search_miss++;
     return "";
 }
 
 # Extract the filename from the path. Note if the file ends in / then the folder is the filename
 function basename(f) {
     if (match(f,"/[^/]+$")) {
         f=substr(f,RSTART+1);
     } else if (match(f,"/[^/]+/$")) {
         f=substr(f,RSTART+1,RLENGTH-2);
     }
     #DEBUG("Before ext ["f"]");
     sub(gExtRegExAll,"",f); #remove extension
     #DEBUG("After ext ["f"]");
     return tolower(f);
 }
 
 #Given a list of page titles determine the most frquently occuring substring
 function get_frequent_substring(titles,threshold,\
 cleaned_titles,i,j,k,substring_count,substring_words,txt) {
     for(i in titles) {
         cleaned_titles[i]=tolower(cleanTitle(titles[i]));
     }
 
     dump("cleaned",cleaned_titles);
 
     #count substrings and add to totals substring_count=count substring_words = number of words
     for(i in cleaned_titles) {
         #gsub(/\<dr\>/,"doctor",cleaned_titles[i]);
         merge_substring_count(cleaned_titles[i],substring_count,substring_words);
     }
 
     #The number of occurences is more important than the number of words.
     for(i in substring_count) {
         j = substring_count[i]-1 ;
         k = substring_words[i]-1 ;
         #Increase weighting if it ends in a year.
         if ( i ~ "\\<(19|20)[0-9][0-9]$" || i ~ "\\((19|20)[0-9][0-9]\\)$") {
             j *= 10 ; 
         }
         # This is a weighting based on words + number of occurences. Not exact science
         # A one word file wont be found (due to -1) but then other rules should find it directly before this.
         #substring_count[i] = (j-1) * j * (k-1)*k;
         substring_count[i] = j * j * k;
         if (substring_count[i] >= threshold+0 ) {
             DEBUG("count = "j"\twords="substring_words[i]"\tfinal = "substring_count[i] "\t["i"]");
         } else {
             delete substring_count[i];
         }
     }
     txt = getMax(substring_count,threshold,1,1);
     DEBUG("FOUND["txt"]");
     return txt;
 }
 
 # Count all substrings in text. eg.
 # "And So say all of us" gives "and" "and so" and so say" ... "so" "so say" etc.
 function merge_substring_count(title,substring_count,substring_words,\
 word_count,txt,first_word_pos,e,s,w,start,i,j,sep,current_title_substrings) {
 
     start = 0 ;
     first_word_pos=0;
 
     DEBUG("Extracting from ["title"]");
     #DEBUG("Check against ["catalog_format_tags"]");
 
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
 
             #only count strings we havent already seen in this title.
             if (!(txt in current_title_substrings)) {
                 #DEBUG("Substring = "i"/"s[i]" to "j"/"e[j]" = ["txt"]");
                 substring_count[txt] += 1; # (10-s[i]);
                 substring_words[txt]=j-i+1;
                 current_title_substrings[txt]=1;
             }
         }
     }
 }
 
 #If stripFormatTags set then only portion before recognised format tags (eg 720p etc) is search.
 #This helps broaden results and get better consensus from google.
 function fileNameToSearchKeywords(f,heuristic\
 ) {
 
     #heuristic 0 - All words optional (+) and strip format tags strip episode s0ne0n
     #heuristic 1 - All words mandatory (+%2B) and strip format tags strip episode s0ne0n
     #heuristic 2 - Quoted file search 
     f=tolower(f);
 
     if (heuristic == 0 || heuristic == 1) {
 
         gsub(/[^-_A-Za-z0-9]+/,"+",f);
 
         #remove words ending with numbers
         #gsub(/\<[A-Za-z]+[0-9]+\>/,"",f);
 
         #remove everything after a year
         if (match(f,"\\<(19|20)[0-9][0-9]\\>")) {
             f = substr(f,1,RSTART+RLENGTH);
         }
         #remove everything after episode
         if (match(f,"\\<s[0-9][0-9]e[0-9][0-9]")) {
             f = substr(f,1,RSTART+RLENGTH);
         }
 
 
         f = remove_format_tags(f);
 
         #Make words mandatory
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
     INFO("Using search method "heuristic" = ["f"]");
     return f;
 }
 
 function remove_format_tags(text,\
 tag,t) {
     gsub(gSettings["catalog_format_tags"]".*","",text);
     return text;
 }
 
 function scrapeIMDBTitlePage(idx,url,\
 f) {
 
     if (url ~ "IGNORE" ) return;
 
     #Remove /combined/episodes from urls given by epguides.
     url=extractImdbLink(url);
     DEBUG("Setting external url to ["url"]");
     gExternalSourceUrl[idx] = url;
     
     f=getUrl(url,"imdb_main",1);
 
     if (f != "" ) {
 
         imdbContentPosition="header";
 
         DEBUG("START IMDB: title:"gTitle[idx]" poster "gPoster[idx]" genre "gGenre[idx]" cert "gCertRating[idx]" year "gYear[idx]);
 
         FS="\n";
         while(imdbContentPosition != "footer" && (getline < f) > 0  ) {
             imdbContentPosition=scrapeIMDBLine(imdbContentPosition,idx,f);
         }
         close(f);
     }
 }
 
 
 ##### LOADING INDEX INTO DB_ARR[] ###############################
 
 #Used by generate nfo
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
 
 function loadDatabase(db,file_to_db,\
 arr_size,f) {
 
     arr_size=0;
     delete file_to_db;
 
     INFO("read_database");
 
     FS="\n";
     while((getline < INDEX_DB) > 0 ) {
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
             #DEBUG("Got file ["f"]");
             if (g_opt_no_actions && record_action != ACTION_NONE) {
                 INFO("noactions:Temporarily including item "db[ID,arr_size]" with action "record_action);
             }
             file_to_db[f]=arr_size;
 
             #TODO We could just store the index rather than the original line
             index_line[db[FILE,arr_size]] = $0;
 
             if ( db[FILE,arr_size] == "" ) {
                 ERROR("Blank file for ["$0"]");
             }
             if (db[ID,arr_size] > gMaxDatabaseId) {
                 gMaxDatabaseId = db[ID,arr_size];
             }
 
             #DEBUG("Loaded ["f"]");
             arr_size++;
         }
     }
     close(INDEX_DB);
     return arr_size;
 }
 
 function deleteCurrentEntry(db,idx, i) {
 #First field is intentionally blank - lines start with TAB to make field grepping simpler.
     for(i=2 ; i < NF ; i+= 2 ) {
         delete db[$i,idx];
     }
 }
 
 function getPath(name,localPath) {
     if (substr(name,1,1) == "/" ) {
         #absolute
         return name;
     } else if (substr(name,1,4) == "ovs:" ) {
         #Paths with ovs:  are relative to oversight folder and are shared between items.(global)
         return APPDIR"/db/global/"substr(name,5);
     } else {
         #Other paths are relative to video folder.
         return localPath"/"name;
     }
 }
 
 #Add files to the delete queue
 function queueFileForDeletion(name,field) {
     gFileToDelete[name]=field;
 }
 
 function remove_files_with_delete_actions(db,file_count,\
     f,field,i,deleteFile) {
 
     INFO("remove_files_with_delete_actions");
 
     for(f in gFileToDelete) {
         field=gFileToDelete[f];
         if (field != "" && field != DIR ) {
             deleteFile=1;
             #check file has no other references 
             for(i = 0 ; i < file_count ; i++ ) {
                 if (getPath(db[field,i],db[DIR,i]) == f) {
                     INFO(f" still in use by item "db[ID,i]);
                     deleteFile=0;
                     break;
                 }
             }
             if (deleteFile) {
                 exec(rm(f,"",1));
             }
         }
     }
 
     INFO("Deleting folders");
     for(f in gFileToDelete) {
         field=gFileToDelete[f];
         if (field == DIR ) {
             # We are expecting rmdir to fail if the is other content!!
             INFO("Deleting "f" only if empty");
             exec(rmdir(f,"",1));
         }
     }
 }
 
 # mode=d delete media only, D=delete all related files.
 function deleteFiles(db,idx,mode,\
     parts,i,d,rmList) {
     INFO("Deleting "db[FILE,idx]);
     split(db[PARTS,idx],parts,"/");
     d=db[DIR,idx];
 
     #If mode d or D then delete media files
 
     rmList = quoteFile(db[FILE,idx]);
     for (i in parts) {
         rmList = rmList " " quoteFile(d"/"parts[i]);
     }
 
     if (mode == ACTION_DELETE_ALL) {
         #Also delete any other files with the same basename
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
 
 ##### PRUNING DELETED ENTRIES FROM INDEX ###############################
 
 #Check all the links
 #To quickly find out if a set of files exist use ls
 function remove_absent_files_from_new_db(dbSize,db,newDbFile,   i,\
     list,f,q,maxCommandLength) {
     list="";
     maxCommandLength=3999;
 
     DEBUG("remove_absent_files_from_new_db size="dbSize);
 
     if (g_opt_no_actions) {
         #Just copy the file if no actions requested. In this case
         #all we want to do are minimal updates so the gui can re-read the
         #database index quickly. Eg when marking a file.
         system("cp "INDEX_DB" "INDEX_DB_NEW);
         return;
     }
 
 
     print "#Index" > newDbFile;
 
     kept_file_count=0;
     absent_file_count=0;
     updated_file_count=0;
     f=NEW_CAPTURE_FILE("PROBEMISSING");
 
     for(i=0 ; i < dbSize ; i++ ) {
 
         if (db[FILE,i] == "" ) {
 
             WARNING("Empty file for index " i);
 
         } else {
 
             q=quoteFile(db[FILE,i]);
             list2=list " "q;
 
             if (length(list)+length(q) < maxCommandLength ) {
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
     INFO("UNCHANGED:"kept_file_count);
     INFO("NOT FOUND:"absent_file_count);
     INFO("UPDATING :"updated_file_count);
     INFO("NEW      :"(gMovieFileCount-updated_file_count));
 }
 
 #Return single quoted file name. Inner quotes are backslash escaped.
 function quoteFile(f,
     j,ch) {
     gsub(gQuote,gQuote "\\"gQuote gQuote,f);
     return gQuote f gQuote;
 }
 
 function determineFileStatus(f,list,newDbFile,\
 cmd,i,line) {
     INFO("Checking batch");
     cmd="ls -d -- " list " > " f " 2>&1" 
    #DEBUG("######### "cmd" #############");
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
 
            #DEBUG("KEEPING ["$0"]");
            if (line in index_line) {
                print index_line[line] > newDbFile;
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
     val) {
     # Calculate file time...
     if (lsMonth == "" ) {
         return _default;
     } else {
         m=gMonthToNum[lsMonth];
         d=lsDate;
         if (index(lsTimeOrYear,":")) {
             #MON dd hh:mm
             y=THIS_YEAR;
             h=substr(lsTimeOrYear,1,2);
             min=substr(lsTimeOrYear,4,2);
         } else {
             #MON dd yyyy
             y=lsTimeOrYear;
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
 
     gSeason[idx]=details[SEASON];
     gEpisode[idx]=details[EPISODE];
     gCategory[idx] = "T";
     gAdditionalInfo[idx] = details[ADDITIONAL_INFO];
 
     # Now check the title.
     #TODO
     return 1;
 }
 
 function extractEpisodeByPatterns(line,details,idx) {
 
     #Note if looking at entire path name folders are seperated by /
 
     line = tolower(line);
     if (!extractEpisodeByPattern(line,0,"\\<","[s][0-9][0-9]?","[/ .]?[de][0-9]+[a-e]?",details,idx)) {  #s00e00 (allow d00a for BigBrother)
         if (!extractEpisodeByPattern(line,0,"\\<","[0-9][0-9]?","[/ .]?x[0-9][0-9]?",details,idx)) { #00x00
             if (!extractEpisodeByPattern(line,0,"\\<","(series|season|saison|s)[^a-z0-9]*[0-9][0-9]?","[/ .]?(e|ep.?|episode)[^a-z0-9]*[0-9][0-9]?",details,idx)) { #00x00 
 
                 #remove 264 before trying pure numeric detection
                 if (index(line,"x264")) {
                     gsub(/\<x264\>/,"x-264",line);
                 }
                 if (!extractEpisodeByPattern(line,1,"[^-0-9]","[03-9]?[0-9]","/?[0-9][0-9]",details,idx)) { # ...name101...
 
                     return 0;
                 }
             }
         }
     }
 
    #Note 4 digit season/episode matcing [12]\d\d\d will fail because of confusion with years.
     return 1;
 }
 
 function formatDate(line,\
 date,nonDate) {
     line = shortenMonth(line);
     if (!extractDate(line,date,nonDate)) {
         return line;
     }
     line=sprintf("%04d-%02d-%02d",date[3],date[2],date[1]);
     return line;
 }
 
 
 # Input date text
 # Output array[1]=y [2]=m [3]=d 
 #nonDate[1]=bit before date, nonDate[2]=bit after date
 # or empty array
 function extractDate(line,date,nonDate,\
 y4,d1,d2,d1or2,m1,m2,m1or2,d13up,d,m,y,datePart,textMonth) {
 
     textMonth = 0;
     delete date;
     delete nonDate;
     #Extract the date.
     #because awk doesnt capture submatches we have to do this a slightly painful way.
     y4="20[01][0-9]";
     m2="(0[1-9]|1[012])";
     m1=d1="[1-9]";
     d2="([012][0-9]|3[01])";
     #d13up="(1[3-9]|2[0-9]|3[01])";
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
         if (date[2] in gMonthToNum ) {
             date[2] = gMonthToNum[date[2]];
         } else {
             return 0;
         }
 
     }
     return 1;
 }
 
 # If a line looks like show.name.2009-06-16 then look for episode by date. It requires that
 # show.name results in good unique match at thetvdb.com. otherwise the show.name is left 
 # unchanged and the episode number is set to mmdd
 function extractEpisodeByDates(line,details,\
 tvdbid,episodeInfo,d,m,y,date,nonDate,title) {
 
     if (!extractDate(line,date,nonDate)) {
         return 0;
     }
 
     rest=nonDate[2];
     title = cleanTitle(nonDate[1]);
 
     y = date[1];
     m = date[2];
     d = date[3];
 
     INFO("Found Date y="y" m="m" d="d);
 
     #search for the showname 
     tvdbid = search1TvDbId(title);
     if (tvdbid != "") {
         fetchXML("http://thetvdb.com/api/GetEpisodeByAirDate.php?apikey="apikey"&seriesid="tvdbid"&airdate="y"-"m"-"d,episodeInfo);
         details[TITLE]=title;
         details[SEASON]=episodeInfo["/Data/Episode/SeasonNumber"];
         details[EPISODE]=episodeInfo["/Data/Episode/EpisodeNumber"];
         details[ADDITIONAL_INFO]=episodeInfo["/Data/Episode/EpisodeName"];
         #TODO We can cache the above url for later use instead of fetching episode explicitly.
     } else {
         details[TITLE]=title;
         details[SEASON]=y;
         details[EPISODE]=sprintf("%02d%02d",m,d);
         sub(/\....$/,"",rest);
         details[ADDITIONAL_INFO]=cleanTitle(rest);
     }
     return 1;
 }
 
 function extractEpisode(line,idx,details,        d,dir) {
 
     if (!extractEpisodeByPatterns(line,details,"")) {
         if (!extractEpisodeByDates(line,details)) {
             return 0;
         }
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
 
     if (match(tmpDetails[ADDITIONAL_INFO],gExtRegExAll) ) {
         tmpDetails[EXT]=tmpDetails[ADDITIONAL_INFO];
         gsub(/\.[^.]*$/,"",tmpDetails[ADDITIONAL_INFO]);
         tmpDetails[EXT]=substr(tmpDetails[EXT],length(tmpDetails[ADDITIONAL_INFO])+2);
     }
 
     #Match the episode first to handle 3453 and 456
     match(line,episodeRe "$" );
     tmpDetails[EPISODE] = substr(line,RSTART,RLENGTH); 
     tmpDetails[SEASON] = substr(line,1,RSTART-1);
 
     #gsub(/[^0-9]+/,"",tmpDetails[EPISODE]); #BB
     gsub(/^[^0-9]+/,"",tmpDetails[EPISODE]); #BB
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
        DEBUG("tv details "gDbFieldName[ee]"."idx" = "tmpDetails[ee]);
     }
     return 1;
 }
 
 ############### GET IMDB URL FROM NFO ########################################
 
 function process_scanned_files(\
 mNo,file,bestUrl,bestUrlViaEpguide,scanNfo,startTime,elapsedTime,thisTime) {
 
 INFO("process_scanned_files");
 
     startTime = systime();
 
     for ( mNo = 0 ; (mNo in gMovieFiles ) ; mNo++ ) {
 
         itemStartTime = systime();
 
         bestUrl="";
 
         scanNfo=0;
 
         file=gMovieFiles[mNo];
         if (file == "" ) continue;
 
         INFO("\n\t==\t==\t==\t==\t==\t==\t==\t==\t==\t==\t==\t==\t==\t==\t==\t==\t==\n");
         INFO(mNo":"file);
 
         DEBUG("nfo check :"file);
         if (!isDvdDir(file) && !match(file,gExtRegExAll)) {
             WARNING("Skipping unknown file ["file"]");
             continue;
         }
 
 
         if (gSettings["catalog_nfo_read"] != "no") {
 
             if (gNfoExists[gNfoDefault[mNo]]) {
 
                DEBUG("Using default info to find url");
                scanNfo = 1;
 
             } else if (gFolderMediaCount[gFolder[mNo]] == 1 && gFolderInfoCount[gFolder[mNo]] == 1 && gNfoExists[gFolderInfoName[gFolder[mNo]]]) {
 
                DEBUG("Using single nfo "gFolderInfoName[gFolder[mNo]]" to find url in folder ["gFolder[mNo]"] for item "mNo);
 
                gNfoDefault[mNo] = gFolderInfoName[gFolder[mNo]];
                scanNfo = 1;
            }
         }
 
         if (scanNfo){
            bestUrl = scanNfoForImdbLink(mNo,gNfoDefault[mNo]);
         }
 
         # This bit needs review.
         # Esp if we have an IMDB - use that to determine category first.
         #This will help for TV shows that have odd formatting.
 
         if (checkTvFilenameFormat(mNo)) {
             # TV
             # There are different ways to get imdburl for tv show.
             # via nfo or determine via epguides search
             # If imdb url is provided via nfo we should use that to get epguides link
             # rather than using epguides link to get imdb link
             if (bestUrl != "") {
 
                 #Get a better title using link from nfo to scrape epguides  with.
                 scrapeIMDBTitlePage(mNo,bestUrl);
                 #TODO Need a solid route from imdb link to epguides page.
                 bestUrlViaEpguide = getAllTvInfoAndImdbLink(mNo);
 
             } else {
 
                 #Get imdb url from eguide first.
                 bestUrl = getAllTvInfoAndImdbLink(mNo);
                 if (bestUrl == "") {
                     bestUrl=searchInternetForImdbLink(mNo);
                     scrapeIMDBTitlePage(mNo,bestUrl);
                     bestUrl2 = getAllTvInfoAndImdbLink(mNo);
                 } else {
                     scrapeIMDBTitlePage(mNo,bestUrl);
                 }
         #epguideSeriesPage="http://google.com/search?q=allintitle%3A+"t2"+site%3Aepguides.com&btnI=Search";
 
             }
 
         } else {
 
             # Film
             if (bestUrl == "") {
 
                 bestUrl=searchInternetForImdbLink(mNo);
             }
 
             if (bestUrl != "") {
 
                 scrapeIMDBTitlePage(mNo,bestUrl);
 
             }
         }
 
         fixTitles(mNo);
         get_best_episode_title(mNo);
         relocate_files(mNo);
 
         thisTime = systime() - itemStartTime;
         elapsedTime = systime() - startTime;
 
         if (g_opt_dry_run) {
             print "dryrun: "gFile[mNo]" -> "gTitle[mNo];
         }
         DEBUG("processed in "thisTime"s | processed "(mNo+1)" items in "(elapsedTime)"s av time per item " (elapsedTime/(mNo+1)) "s");
     }
 }
 
 #returns imdb url
 function scanNfoForImdbLink(idx,nfoFile,\
 foundId) {
 
     foundId="";
     INFO("scanNfoForImdbLink ["nfoFile"]");
 
     FS="\n";
     while(foundId=="" && (getline < nfoFile) > 0 ) {
 
         foundId = extractImdbLink($0);
 
     }
     close(nfoFile);
     INFO("scanNfoForImdbLink = ["foundId"]");
     return foundId;
 }
 
 ############### GET IMDB PAGE FROM URL ########################################
 
 function getAllInfoFromTvDbAndImdbLink(idx,title,\
 tvDbSeriesPage,url,i) {
 
     if (title == "") {
         title=gTitle[idx];
     }
     DEBUG("Checking existing mapping for ["title"]");
     tvDbSeriesPage = tvDbIndex[title];
 
     if (tvDbSeriesPage == "" ) {
         DEBUG("Checking TvDvTitles for ["title"]");
 
         tvDbSeriesPage = searchTvDbTitles(title);
     }
 
     if (tvDbSeriesPage == "" ) {
         searchAbbreviationAgainstTitles(title,alternateTitles);
 
         for(i = 1 ; tvDbSeriesPage == "" && (i in alternateTitles) ; i++ ) {
             DEBUG("Checking possible abbreviation "alternateTitles[i]);
             tvDbSeriesPage = searchTvDbTitles(alternateTitles[i]);
         }
     }
 
     if (tvDbSeriesPage == "" ) {
         WARNING("getAllInfoFromTvDbAndImdbLink could not find series page");
         return "";
     } else {
         DEBUG("getAllInfoFromTvDbAndImdbLink Search looking at "tvDbSeriesPage);
         return getTvDbInfo(idx,tvDbSeriesPage);
     }
 }
 
 # Search the epguides menus for names that could be represented by the abbreviation 
 function searchAbbreviationAgainstTitles(abbrev,alternateTitles,\
 initial,title2,count) {
 
     delete alternateTitles;
 
     count=0;
 
     if (index(abbrev," ") == 0) {
         initial = epguideInitial(abbrev);
         DEBUG("Checking "abbrev" for abbreviations on menu page - "initial);
         title2 = searchAbbreviation(initial,abbrev);
         if (title2 != "" ) {
             DEBUG(abbrev" possible abbreviation for "title2);
             alternateTitles[++count] = title2;
         }
 
         #if the abbreviation begins with t it may stand for "the" so we need to 
         #check the index against the next letter. eg The Ultimate Fighter - tuf on the u page!
         if (initial == "t" ) {
             initial = epguideInitial(substr(abbrev,2));
             if (initial != "t" ) {
                 DEBUG("Checking "abbrev" for abbeviations on menu page - "initial);
                 title2 = searchAbbreviation(initial,abbrev);
                 if (title2 != "" ) {
                     DEBUG(abbrev" possible abbreviation for "title2);
                     alternateTitles[++count] = title2;
                 }
             }
         }
     }
     return count;
 }
 
 function search1TvDbId(title,\
 allTitles,closeTitles,best) {
 
     searchTvDb(title,allTitles);
 
     dump("ALL",allTitles);
 
     filterSimilarTitles(title,allTitles,closeTitles);
 
     dump("FILTERED",closeTitles);
 
     best = selectBestOfBestTitle(closeTitles,idx);
     return best;
 }
 
 # TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO TODO 
 # This is the function which will eventually discern between two very closely matched titles.
 # Eg given conan.obrien.2009.06.24 how do we select between The Late Show with Conan OBrien or the tonight show with Conan OBrien
 # It is called when there is not enough information in the titles alone to make the call.
 # it will do things like the following:
 # IF its a Season 5 DVDRIP then it cant match a show that doesnt have a Season 5 or one
 # where season 5 is currently airing (watch out for long split season programs like LOST )
 # Also vice versa if its a TV rip then its probably a show which is currently airing THAT season.
 # The above rules are also dependent on time of scan so have to be careful.
 # Another one, for conan obrien use thetvdb get episode by date api call to differentiate between shows.
 # This is all yucky edge case stuff. And its not coded. In the mean time I will just return the first element :)
 function selectBestOfBestTitle(titles,idx,\
 i) {
     dump("TODO:Even match",titles);
     for(i in titles) {
         INFO("Selected:"titles[i]);
         return i;
     }
 }
 
 # Search tvDb and return titles hashed by seriesId
 function searchTvDb(title,allTitles,\
 f,line,info,bestId,currentId,currentName) {
 
     delete allTitles;
 
     bestMatchLevel = 0;
     DEBUG("Checking ["title"] against list "menuUrl);
     f = getUrl("http://thetvdb.com//api/GetSeries.php?seriesname="title,"tvdb_idx",1);
     if (f != "") {
         FS="\n";
         while((getline line < f) > 0 ) {
 
             #DEBUG("IN:"line);
 
             if (index(line,"<Series>") > 0) {
                 #This also removes the top level /Data tag in the XML reference
                 delete info;
             }
 
             parseXML(line,info);
 
             if (index(line,"</Series>") > 0) {
 
                 dump("INFO",info);
 
                 currentName = info["/Series/SeriesName"];
 
                 currentId = info["/Series/seriesid"];
 
                 allTitles[currentId] = currentName;
                 delete info;
 
             }
         }
         close(f);
     }
 }
 
 function dump(label,array,\
 i) {
     for(i in array) DEBUG(label":"i"=["array[i]"]");
 }
 
 function searchTvDbTitles(title,\
 tvdbid,tvDbSeriesUrl) {
 
     tvdbid = search1TvDbId(title);
     if (tvdbid != "") {
         tvDbSeriesUrl="http://thetvdb.com/api/"apikey"/series/"tvdbid"/en.xml";
     }
 
     DEBUG("Endpage with url = ["tvDbSeriesUrl"]");
     return tvDbSeriesUrl;
 }
 
 
 #Load an xnl file into array - note duplicate elements are clobbered.
 #To parse xml with duplicate lements call parseXML in a loop and trigger on index(line,"</tag>")
 function fetchXML(url,urlLabel,xml,\
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
 
 #Parse flat XML into an array
 function parseXML(line,info,\
 currentTag,start,i,tag,text,lines,parts) {
 
     # Carriage returns mess up parsing
     gsub(/\r/,"",line);
     gsub(/\n/,"",line);
 
 
     #break at each tag/endtag
     split(line,lines,"<");
 
     previousTag = info["@LAST"];
     currentTag = info["@CURRENT"];
 
     start=1;
     if (substr(line,1,1) != "<") {
         #If the line starts with text then add it to the current tag.
         info[currentTag] = info[currentTag] lines[1];
         start = 2;
     }
 
     for(i = start ; i in lines ; i++ ) {
 
         previousTag = "";
         #split <tag>text  [ or </tag>parenttext ]
         split(lines[i],parts,">");
         tag = parts[1];
         sub(/ .*/,"",tag); #Remove attributes Possible bug if space before element name
         text = parts[2];
 
         if (tag ~ /^\/?[A-Za-z0-9_]+$/ ) {
 
             if ( substr(tag,1,1) == "/" ) {
                 #if end tag, remove it from currentTag
                 previousTag = currentTag;
                 sub(tag"$","",currentTag);
 
             } else {
                 previousTag = currentTag;
                 currentTag = currentTag "/" tag;
             }
         } else {
 
             #dont recognise tag - add to text
             info[currentTag] = info[currentTag] tag;
         }
 
         info[currentTag] = info[currentTag] text;
         if (tag != "" && text != "" ) {
             DEBUG("<"currentTag">["info[currentTag]"]");
         }
 
     }
     info["@CURRENT"] = currentTag;
     info["@LAST"] = previousTag;
 }
 
 # Return 3 if a possible Title is a very good match for titleIn
 # Return 2 if it is a likely match
 # Return 1 if it is an initial or abbreviated type of match.
 # else return 0
 function similarTitles(titleIn,possibleTitle,\
 bPos,cPos,yearOrCountry,matchLevel,shortName,tmp) {
 
     matchLevel = 0;
     yearOrCountry="";
 
     if ((bPos=index(possibleTitle," (")) > 0) {
         yearOrCountry=cleanTitle(substr(possibleTitle,bPos+2));
     }
 
     if ((cPos=index(possibleTitle,",")) > 0) {
         shortName=cleanTitle(substr(possibleTitle,1,cPos-1));
     }
 
     possibleTitle=cleanTitle(possibleTitle);
 
     sub(/^[Tt]he /,"",possibleTitle);
     sub(/^[Tt]he /,"",titleIn);
 
     if (substr(titleIn,2) == substr(possibleTitle,2)) {
         DEBUG("Checking ["titleIn"] against ["possibleTitle"]");
     }
     if (index(possibleTitle,titleIn) == 1) {
 
         #This will match exact name OR if BOTH contain original year or country
         if (possibleTitle == titleIn) {
             matchLevel=3;
 
         } else  if (titleIn == shortName) {
             #Check for comma. eg maych House to House,M D
             matchLevel=3;
 
         #This will match if difference is year or country. In this case just pick the 
         # last one and user can fix up
         } else if ( possibleTitle == titleIn " " yearOrCountry ) {
             INFO("match for ["titleIn"+"yearOrCountry"] against ["possibleTitle"]");
             matchLevel = 2;
         } else {
             DEBUG("No match for ["titleIn"+"yearOrCountry"] against ["possibleTitle"]");
         }
     } else if (index(titleIn,possibleTitle) == 1) {
         #Check our title just has a country added
         diff=substr(titleIn,length(possibleTitle)+1);
         if (substr(diff,1,1) == " ") {
             matchLevel = 2;
             INFO("match for ["titleIn"] containing ["possibleTitle"]");
         }
     }
     DEBUG("["titleIn"] vs ["possibleTitle"] = "matchLevel);
     return matchLevel;
 }
 
 #Given a title - scan an array or potential titles and return the best matches along with a score
 #The indexs are carried over to new hash
 function filterSimilarTitles(title,titleHashIn,titleHashOut,\
 i,score,bestScore,count) {
 
     bestScore = -1;
     count=0;
 
     delete titleHashOut;
 
     for(i in titleHashIn) {
 
         score = similarTitles(title,titleHashIn[i]);
         if (score > bestScore) {
             delete titleHashOut;
             count=1;
             bestScore = score;
             titleHashOut[i] = titleHashIn[i];
         } else if (score == bestScore) {
             titleHashOut[i] = titleHashIn[i];
         }
     }
     DEBUG("Filtered titles with score = "bestScore);
 
     dump("\t",titleHashOut);
     return bestScore;
 }
 
 # Return the list of names in the epguide menu indexed by link
  function getEpguideNames(letter,names,\
  url,count,title,link,links,i,count2) {
      url = "http://epguides.com/menu"letter;
 
      count = scanPageForMatches(url,"<li>(|<b>)",links,0);
  
      count2 = 0;
      for(i = 1 ; i <= count ; i++ ) {
  
          if (index(links[i],"[radio]") == 0) {
  
              title = extractTagText(links[i],"a");
  
              if (title != "") {
                  link = extractAttribute(links[i],"a","href");
                  sub(/\.\./,"http://epguides.com",link);
                  gsub(/\&amp;/,"And",title);
                  names[link] = title;
                  count2++;
  
                  DEBUG("name list "title);
              }
          }
      }
      DEBUG("Loaded "count2" names");
      return count2;
 }
 
 function searchAbbreviation(letter,titleIn,\
 tmp,possibleTitle,f,names,links,i,ltitle) {
 
 
     ltitle = tolower(titleIn);
 
     DEBUG("Checking abbreviations ["titleIn"] ");
 
     getEpguideNames(letter,names);
 
     for(i in names) {
 
         possibleTitle = names[i];
 
         sub(/\(.*/,"",possibleTitle);
 
         possibleTitle = trim(possibleTitle);
 
         tmp = threeWordInitials(possibleTitle);
         if (tmp != "" && ltitle == tmp) {
             break;
         }
 
         # echo Family Guy = fguy only true if 1st word longer?
         tmp =initialWord(possibleTitle); 
         if (tmp != "" && ltitle == tmp) {
             break;
         }
 
         # echo Desperate Housewives = desperateh only true if 1st word shorter?
         tmp =wordInitial(possibleTitle); 
         if (tmp != "" && ltitle == tmp) {
             break;
         }
 
         # Eg greek = grk 
         tmp =removeDoubleVowel(possibleTitle); 
         if (tmp != "" && ltitle == tmp) {
             break;
         }
         possibleTitle="";
     }
 
     DEBUG("abbreviations = ["possibleTitle"] "tmp);
     return possibleTitle;
 }
 
 #If a title has exactly two words and the first word is longest return initial of word1 followed by word2
 # eg fguy for family guy
 function initialWord(text,\
 spacePos,abbr) {
     spacePos = index(text," ");
     # Reject no spaces
     if (spacePos == 0) {
         return "";
     }
     # Two spaces
     if (text ~ / [^ ]+ /) {
         return "";
     }
     if (spacePos*2 < length(text)) {
         #first word is short - unlikely to abbreviate this way?
         return "";
     }
     abbr = tolower(substr(text,1,1) substr(text,spacePos+1));
     DEBUG(text"|"abbr);
     return abbr;
 }
 
 #If a title has exactly two words and the first word is shortest return word1 followed by initial of word2
 # eg desperateh for Desperate Housewives
 function wordInitial(text,\
 spacePos,abbr) {
     text = tolower(text);
     spacePos = index(text," ");
     # Reject no spaces
     if (spacePos == 0) {
         return "";
     }
     #If first word is "the" then unlikely to keep this and abbreviate 2nd word.
     if (substr(text,1,4) == "the ") {
         return "";
     }
     # Two spaces
     if (text ~ / [^ ]+ /) {
         return "";
     }
     if (spacePos*2 >= length(text)) {
         #first word is longer - unlikely to abbreviate this way?
         return "";
     }
     abbr = substr(text,1,spacePos-1) substr(text,spacePos+1,1);
     DEBUG(text"|"abbr);
     return abbr;
 }
 
 # If there are 3 or more words then try initials
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
     DEBUG(text"|"abbr);
     return abbr;
 }
 
 # if there is one word with a double vowel remove it
 function removeDoubleVowel(text,\
 abbr) {
     if (index(text," ")) {
         return "";
     }
     sub(/[aeiouAEIOU][aeiouAEIOU]/,"",text);
     abbr = tolower(text);
     DEBUG(text"|"abbr);
     return tolower(abbr);
 }
 
 
 
 function getAllTvInfoAndImdbLink(idx,title) {
     #return getAllInfoFromEpguidesAndImdbLink(idx,title);
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
         }
     }
 
     if (epguideSeriesPage == "" ) {
         WARNING("getAllInfoFromEpguidesAndImdbLink could not find series page");
         return "";
     } else {
         return getEpguideInfo(idx,epguideSeriesPage);
     }
 }
 
 function epguideInitial(title,\
 letter) {
 
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
     return letter;
 }
 
 # Returns url to epguides series page
 function searchEpguideTitles(idx,title,attempt,\
     letter,names,namess2,epguideSeriesUrl) {
 
 
     DEBUG("Search of epGuide titles for ["title"]");
 
     # TV SEARCH
 
     letter = epguideInitial(title);
 
     if (match(letter,"[a-z]")) {
         #Use epguides menu
         DEBUG("Checking ["title"] against list "letter);
         getEpguideNames(letter,names);
 
         filterSimilarTitles(title,names,names2);
 
         # If more than one title is a good match we need to refine further
         # TODO: this needs to be fixed
         epguideSeriesUrl = selectBestOfBestTitle(names2,idx);
 
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
     gsub(/['\'']/,"",t);
 
     #Collapse abbreviations. Only if dot is sandwiched between single letters.
     #c.s.i.miami => csi.miami
     #this has to be done in two stages otherwise the collapsing prevents the next match.
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
 
 # Search google for a filename and examine titles of search results.
 #Both google and yahoo have the main title inside <h3><a..>Title</a></h3>
 function getTitlesFromGoogle(query,titles,\
 f,h3pos,i,pos,html ) {
     i=0;
     split("",titles,""); #clear
 
     f = web_search_to_file(title_search_engines,query,"","search4words",1);
     if (f != "") {
 
         FS="\n";
         while((getline html < f) > 0 ) {
 
             html = de_emphasise(html);
 
 
             #if "Results for:" occurs then ignore everything processed so far. 
             #This was output of "Did you mean"
             if ((pos=index(html,">Results for:")) > 0 ) {
                 delete titles;
                 html = substr(html,pos);
             }
 
             #INFO("check h3");
 
             while((pos=index(html,"<h3")) > 0) {
                 html=substr(html,pos);
                 h3pos=index(html,"</h3>");
                 h3txt=substr(html,1,h3pos);
                 html=substr(html,h3pos+4);
 
                 #INFO("1.h3txt=["h3txt"] pos="pos);
                 h3txt = tolower(extractTagText(h3txt,"a"));
                 #INFO("2.h3txt=["h3txt"]");
                 h3txt = remove_format_tags(h3txt);
                 #INFO("h3txt=["h3txt"]");
                 if (h3txt != "" ) {
                     titles[i++] = h3txt;
                 }
             }
         }
         close(f);
         rm(f,1);
     }
 }
 
 # This finds the item with the most votes and returns it if it is > threshold.
 # Special case: If threshold = -1 then the votes must exceed the square of the 
 # difference between next largest amount.
 function getMax(arr,requiredThreshold,requireDifferenceSquared,dontRejectCloseSubstrings,\
 maxValue,maxName,best,nextBest,nextBestName,diff,i,threshold,msg) {
     nextBest=0;
     maxName="";
     best=0;
     for(i in arr) {
         msg="Score: "arr[i]" for ["i"]";
         if (arr[i]+0 >= best+0 ) {
             if (maxName == "") {
                 INFO(msg": first value ");
             } else {
                 INFO(msg":"(arr[i]>best?"beats":"matches")" current best of " best " held by ["maxName"]");
             }
             nextBest = best;
             nextBestName = maxName;
             best = threshold = arr[i];
             maxName = i;
 
         } else if (arr[i]+0 >= nextBest+0 ) {
 
             INFO(msg":"(arr[i]>nextBest?"beats":"matches")" current next best of " nextBest " held by ["nextBestName"]");
             nextBest = arr[i];
             nextBestName = i;
             INFO(msg": set as next best");
 
         } else {
             INFO(msg);
         }
     }
     INFO("Best "best"*"arr[i]". Required="requiredThreshold);
 
     if (0+best < 0+requiredThreshold ) {
         INFO("Rejected as "best" does not meet requiredThreshold of "requiredThreshold);
         return "";
     }
     if (requireDifferenceSquared ) {
         diff=best-nextBest;
         INFO("Next best count = "nextBest" diff^2 = "(diff*diff));
         if (diff * diff >= best ) {
 
             return maxName;
 
         } else if (dontRejectCloseSubstrings && (index(maxName,nextBestName) || index(nextBestName,maxName))) {
 
             INFO("Match permitted as next best is a substring");
             return maxName;
 
         } else {
 
             INFO("But rejected as "best" too close to next best "nextBest" to be certain");
             return "";
 
         }
     } else {
         return maxName;
     }
 }
 
 #Note the seach is assumed to have the format <h3><a= ...>Result title</a></h3>....
 #which works for google,yahoo and msn for now.
 #Searching is more intensive now and it is easy to get google rejecting searches based on traffic.
 #So we apply round-robin (google,yahoo,msn) to avoid getting blacklisted.
 # msn search results are similar to google for this purpose.
 # Both yahoo and msn have uk servers that are different to generic server.
 # Google is using load balancing (from my UK perspective)
 #Also the wget function will also sleep based on domain of url
 function search_url(search_engines,q,num) {
     #return "http://www.scroogle.org/cgi-bin/nbbw.cgi?Gw="q;
     ++web_search_count;
     if (!(web_search_count in search_engines )) web_search_count=1;
     if (search_engines[web_search_count] == "google") {
         return "http://www.google.com/search?q="q; # (num==""?"":"&num="num);
     } else if (search_engines[web_search_count] == "googleie") {
         return "http://www.google.ie/search?q="q; # (num==""?"":"&num="num);
     } else if (search_engines[web_search_count] == "yahoouk") {
         return "http://uk.search.yahoo.com/search?p="q; # (num==""?"":"&n="num);
     } else if (search_engines[web_search_count] == "yahoo") {
         return "http://search.yahoo.com/search?p="q; # (num==""?"":"&n="num);
     } else if (search_engines[web_search_count] == "msn") {
         gsub(/inurl%/,"site%",q);
         return "http://search.msn.com/results.aspx?q="q;
     } else if (search_engines[web_search_count] == "msnuk") {
         gsub(/inurl%/,"site%",q);
         return "http://search.msn.co.uk/results.aspx?q="q;
     } else {
         ERROR("Unknown search engine "web_search_count" ["search_engines[web_search_count]"]");
         exit;
     }
 }
 
 # Seach a google page for most frequently occuring imdb link
 function searchForIMDB(keywords,linkThreshold,\
 url) {
     #We want imdb links but not from imdb themselves as this skews the results.
     #Also keeping the number of results down helps focus on early matches.
     return scanGoogleForBestMatch(link_search_engines,keywords"+%2Bimdb+%2Btitle+-inurl%3Aimdb.com+-inurl%3Aimdb.de",gImdbIdRegex,"search4imdb",linkThreshold,1);
 }
 
 # This will try each of the search engines in turn. Google has a habit of locking out IP with lots of searches.
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
 
 
 #Search google page extracting all occurences that match a regex, and return the most
 #popular match.
 #url = google url
 #pattern = regular expression to search for
 #captureLabel = label for temporary file
 #threshold = minimum required occurences of matching text.
 #diffSquaredCheck = set to 1 to ensure the match is significantly more prevalent than other matches, (#best - #nextBest)^2 > best
 
 function scanGoogleForBestMatch(search_engines,keywords,pattern,captureLabel,threshold,diffSquaredCheck,\
 url,f,iurl,start,nextStart,matchList,bestUrl,x,html) {
 
     f = web_search_to_file(search_engines,keywords,20,captureLabel,0);
     if (f != "") {
         FS="\n";
 
         DEBUG("Looking for "pattern" in "f);
 
         while((getline html < f) > 0 ) {
 
             #print("GOOGLE:["html"]");
             html = de_emphasise(html);
 
 
             #x=html;gsub(/</,"\n| <",x);DEBUG(x);
 
 
 #            split(html,x,"<");
 #            l=1;
 #            for(i=1 ; i in x ; i++ ) {
 #                DEBUG(l" "match(x[i],pattern)" <"x[i]);
 #                l+=length(x[i])+1;
 #            }
 
             start=0;
 
             # TODO REplace with split loop
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
     # Find the url with the highest count for each index.
     #To help stop false matches we requre at least two occurences.
     bestUrl=getMax(matchList,threshold,1,0);
     if (bestUrl != "") {
         return extractImdbLink(bestUrl);
     } else  {
         return "";
     }
 }
 
 
 # Scrape theTvDb series page, populate arrays and return imdb link
 # http://thetvdb.com/api/key/series/73141/default/1/2/en.xml
 # http://thetvdb.com/api/key/series/73141/1/en.xml
 function getTvDbInfo(idx,tvDbSeriesUrl,\
 f,line,seriesInfo,episodeUrl,episodeInfo,imdbLink,sep,tvdbid) {
 
     #The url for this link
     gEpGuides[idx]=tvDbSeriesUrl;
 
 
     fetchXML(tvDbSeriesUrl,"thetvdb-series",seriesInfo);
 
     episodeUrl = tvDbSeriesUrl;
     sub(/en.xml/,"default/"gSeason[idx]"/"gEpisode[idx]"/en.xml",episodeUrl);
 
     fetchXML(episodeUrl,"thetvdb-episode",episodeInfo);
 
     if (gExternalSourceUrl[idx]=="" ) {
 
         imdbLink = extractImdbLink(seriesInfo["/Data/Series/IMDB_ID"]);
 
         #Refine the title.
         adjustTitle(idx,seriesInfo["/Data/Series/SeriesName"],"thetvdb");
 
     }
 
     gYear[idx] = substr(seriesInfo["/Data/Series/FirstAired"],1,4);
 
     gAirDate[idx]=formatDate(episodeInfo["/Data/Episode/FirstAired"]);
 
     if (gEpTitle[idx] == "" ) {
         sep="";
     } else {
         sep = "\t";
     }
     gEpTitle[idx]=gEpTitle[idx] sep episodeInfo["/Data/Episode/EpisodeName"];
 
     gPlot[idx] = seriesInfo["/Data/Series/Overview"];
     gGenre[idx] = seriesInfo["/Data/Series/Genre"];
     gCertRating[idx] = seriesInfo["/Data/Series/ContentRating"];
     gRating[idx] = seriesInfo["/Data/Series/Rating"];
 
     if ( gPoster[idx] == "" ) {
        poster = seriesInfo["/Data/Series/poster"];
        banner = seriesInfo["/Data/Series/banner"];
        if (poster != "" ) {
            poster = "http://images.thetvdb.com/banners/_cache/" poster;
        } else if (banner != "" ) {
            poster = "http://images.thetvdb.com/banners/_cache/" banner;
        }
        getPoster(poster,idx);
     }
     if (imdbLink == "" ) {
         WARNING("getTvDbInfo returns blank imdb url");
         return "IGNORE";
     } else {
         DEBUG("getTvDbInfo returns imdb url ["imdbLink"]");
     }
     return imdbLink;
 }
 
 # Scrape epguides series page, populate arrays and return imdb link
 function getEpguideInfo(idx,epguideSeriesUrl,\
 f,h1,newTitle,imdbLink,imdbLinkAndText,i,j) {
 
     #The url for this link
     gEpGuides[idx]=epguideSeriesUrl;
 
     episodeText=sprintf(" %d-%2d ",gSeason[idx],gEpisode[idx]);
     episodeTextHyphen=index(episodeText,"-");
 
     f=getUrl(epguideSeriesUrl,"epguide_nfo",1);
 
     if (f != "" ) {
 
         FS="\n";
         while((getline < f) > 0 ) {
 
             #DEBUG("epguide:" $0);
 
             if (gExternalSourceUrl[idx]=="" ) {
 
                 if (imdbLinkAndText=="" && index($0,"imdb") && match($0,"<a[^<]+imdb[^<]+</a>")) {
 
                     imdbLinkAndText=substr($0,RSTART,RLENGTH);
 
                     imdbLink=extractImdbLink(imdbLinkAndText);
 
                     #Refine the title.
                     newTitle=trim(caps(extractTagText(imdbLinkAndText,"a")));
                     adjustTitle(idx,newTitle,"epguides");
 
 
                     #Also get episode info from IMDB. This is to help decide when episode titles in epguides.com are wrong.
                     #It may change the link if the original was to the pilot episode rather than the series.
                     imdbLink = extractImdbEpisode(idx,imdbLink,0);
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
 
                     gAirDate[idx]=formatDate(substr($0,28,9));
 
                     if (gEpTitle[idx] == "" ) {
                         sep="";
                     } else {
                         sep = "\t";
                     }
                     gTvCom[idx]=gTvCom[idx] sep extractAttribute($0,"a","href");
 
                     gEpTitle[idx]=gEpTitle[idx] sep extractTagText($0,"a");
 
                     DEBUG("Found Episode title ["gEpTitle[idx]"]");
                 }
             }
 
             #We may have ariived by Google Feeling Lucky so get the real url name
 
             ## TODO review
 
             if (index(gEpGuides[idx],".search.") && (i=index($0,"DirName"))>0) {
 
                 i += 8;
                 $0 = substr($0,i);
                 j=index($0,"\"");
                 dirName=substr($0,1,j-1);
 
                 gEpGuides[idx]="http://epguides.com/"dirName;
 
             }
             if ( gPoster[idx] == "" && gSettings["catalog_tv_poster_source"] == "epguides" ) {
                 if (match($0,"<img[^<]+([Cc]ast|[Ss]how)[^<]+>")) {
                     getPoster(gEpGuides[idx]"/"extractAttribute(substr($0,RSTART,RLENGTH),"img","src"),idx);
                 }
             }
             if (index($0,"botnavbar")) {
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
 
 # returns 1 if title adjusted or is the same.
 # returns 0 if title ignored.
 function adjustTitle(idx,newTitle,source) {
 
     if (!("filename" in gTitlePriority)) {
         #initialise
         gTitlePriority[""]=-1;
         gTitlePriority["filename"]=0;
         gTitlePriority["search"]=1;
         gTitlePriority["imdb"]=2;
         gTitlePriority["epguides"]=2;
         gTitlePriority["thetvdb"]=3;
         gTitlePriority["imdb_aka"]=3;
     }
 
     if (!(source in gTitlePriority)) {
         ERROR("Bad value ["source"] passed to adjustTitle");
         return;
     }
 
     if (gTitlePriority[source] > gTitlePriority[gTitleSource[idx]]) {
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
     if (match(text,gImdbIdRegex)) {
         id = substr(text,RSTART,RLENGTH);
         DEBUG("Extracted IMDB Id ["id"]");
     } else if (match(text,"Title.[0-9]+\\>")) {
         id = "tt" substr(text,RSTART+8,RLENGTH-8);
         DEBUG("Extracted IMDB Id ["id"]");
     }
     return id;
 }
 
 # Try to read the title embedded in the iso.
 # This is stored after the first 32K of undefined data.
 # Normally strings would work but this is not on all platforms!
 # returns number of strings found and array of strings in outputText
 
 function getIsoTitle(isoPath,\
 sep,tmpFile,f) {
     FS="\\n";
     sep="~";
     outputWords=0;
     tmpFile="/tmp/bytes."PID;
     isoPart="/tmp/bytes."PID".2";
     delete outputText;
 
     if (exec("dd if="quoteFile(isoPath)" of="isoPart" bs=1024 count=10 skip=32") != 0) {
         return 0;
     }
 
     DEBUG("Get strings "isoPath);
 
     DEBUG("tmp file "tmpFile);
 
     system("awk '\''BEGIN { FS=\"_\" } { gsub(/[^ -~]+/,\"~\"); gsub(\"~+\",\"~\") ; split($0,w,\"~\"); for (i in w)  if (w[i]) print w[i] ; }'\'' "isoPart" > "tmpFile);
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
 
 # Extracts Episode title and air date from imdb. 
 # In some cases epguides may incorrectly pass the imdb link for the pilot rather than the series.
 # In these cases it will switch to the series link and return that.
 # @idx = scan item
 # @imdbLink = base imdb link from which to derive episode link
 # @attempts = number of times a different base imdb link is tried. Only one attempt supported to 
 #   jump from pilot episode link to series link.
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
             s=gSeason[idx];
             e=gEpisode[idx];
 
             while((getline txt < f) > 0 ) {
 
                 #DEBUG("imdb episode:"txt);
 
                 if (index(txt,"Season "s", Episode "e":")) {
                     gEpTitleImdb[idx]=extractTagText(txt,"a");
                     gAirDateImdb[idx]=formatDate(extractTagText(txt,"strong"));
                     DEBUG("imdb episode title = ["gEpTitleImdb[idx]"]");
                     DEBUG("imdb air date = ["gAirDateImdb[idx]"]");
                     break;
                 }
 
                 # Check all episode links refer back to the same URL. If not then
                 #We may have been passed a URL to an episode rather than to the series.
                 #In this case we start again with the series link.
                 if (match(txt,gImdbIdRegex "/episodes")) {
                     referencedLink=substr(txt,RSTART,RLENGTH-9);
                     INFO("ID = "extractImdbId(referencedLink));
                     referencedId = substr(extractImdbId(referencedLink),3)+0;  #Get Id as a number.
 
                     if (match(imdbEpisodeUrl,"\\<tt0*"referencedId"\\>")) {
                         #All OK - reference matches main URL
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
     if (attrPos == 0 || attrPos >= closeTag ) {
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
     #DEBUG("Extracted attribute value ["substr(str,attrPos,endAttr-attrPos)"] from tag ["substr(str,tagPos,closeTag-tagPos+1)"]");
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
     for(i=0 ; i < 256 ; i++ ) {
         c=sprintf("%c",i);
         h=sprintf("x%02x",i);
         atoi[i] = c;
         atoi[h] = c;
     }
 }
 function html_decode(text,\
 i,j,code,newcode) {
     if (atoi[32] == "" ) {
         decode_init(atoi);
     }
     i=0;
     while((i=indexFrom(text,"&#",i)) > 0) {
         DEBUG("i="i);
         j=indexFrom(text,";",i);
         code=tolower(substr(text,i+2,j-(i+2)));
 
         if (substr(code,1,1) == "x") {
             newcode=atoi[code];
         } else {
             newcode=atoi[0+code];
         }
         text=substr(text,1,i-1) newcode substr(text,j+1);
     }
     #DEBUG("decode out =["text"]");
     return text;
 }
 
 function getUrl(url,capture_label,cache,\
     f,label) {
     
     label="getUrl:"capture_label": ";
 
     DEBUG(label url);
 
     if (url == "" ) {
         WARNING(label"Ignoring empty URL");
         return;
     }
 
     if(cache && (url in gUrlCache)) {
 
         INFO(label" fetched ["url"] from cache");
         f = gUrlCache[url];
 
     } else {
 
         f=NEW_CAPTURE_FILE(capture_label);
         if (wget(url,f) ==0) {
             if (cache) {
                 gUrlCache[url]=f;
                 DEBUG(label" Cached url ["url"] to ["f"]");
             } else {
                 DEBUG(label" Fetched ["url"] into ["f"]"); 
             }
         } else {
             ERROR(label" wget of ["url"] into ["f"] failed");
             f = "";
         }
     }
     return f;
 }
 
 function wget(url,file,\
 args,ua,unzip_cmd,preCmd,postCmd,cmd,htmlFile,downloadedFile) {
     ua="Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20040613 Firefox/0.8.0+";
     #ua="nmt-catalog";
 
     args=" -q -U \""ua"\" --waitretry=5 -t 4 ";
 
     targetFile=quoteFile(file);
     htmlFile=targetFile;
 
     if(gunzip == "") {
         downloadedFile=htmlFile;
         unzip_cmd="";
     } else {
         args=" --header=\"Accept-Encoding: gzip,deflate\" "
         downloadedFile=quoteFile(file".gz");
         if (index(gunzip,"/home/alord/devel/oversight/gunzip.php")) {
             unzip_cmd="&& \""gunzip"\" "downloadedFile" "htmlFile;
         } else { 
             unzip_cmd=" && ( gunzip "downloadedFile" || mv "downloadedFile" "htmlFile" ) ";
         }
     }
 
     gsub(/ /,"+",url);
 
     # nmt wget has a bug that causes a segfault if the url basename already exists and has no extension.
     # To fix either make sure action url basename doesnt already exist (not easy with html redirects)
     # or delete the -O target file and use the -c option together.
     rm(downloadedFile,1);
     args = args "  -c ";
 
     #d=tmp_dir"/wget."PID;
     cmd = WGET" \""url"\" -O "downloadedFile" "args" "unzip_cmd  ;
     #cmd="( mkdir "d" ; cd "d" ; "cmd" ; rm -fr -- "d" ) ";
     # Get url if we havent got it before or it has zero size. --no-clobber switch doesnt work on NMT
 
     cmd = getSleepCommand(url,4) cmd;
 
     return exec(cmd);
 }
 
 # Slow down queries to avoid blacklist.
 function getSleepCommand(url,required_gap,\
 slash,domain,remaining_gap) {
     slash=indexFrom(url,"/",10); #http://x.com/xxxx 
     domain=substr(url,1,slash);
     #DEBUG("Domain = "domain);
 
     g_search_count[domain]++;
     if (index(domain,"epguide") || index(domain,"imdb")) {
         return "";
     }
     remaining_gap=required_gap - (systime()-last_search_time[domain]);
     if ( last_search_time[domain] > 0 && remaining_gap > 0 ) {
 
         last_search_time[domain] = systime()+remaining_gap;
         return "sleep "remaining_gap" ; ";
     } else {
         last_search_time[domain] = systime();
         return "";
     }
 }
 
 function getPoster(url,idx,\
     localPosterPath,localPosterName) {
 
     if (gSettings["catalog_fetch_posters"] == no) {
         return;
     }
     localPosterName = gTitle[idx];
     gsub(/[^a-zA-Z0-9]/,"",localPosterName);
 
     localPosterName = poster_prefix localPosterName ".jpg";
     #DEBUG("poster _prefix = "poster_prefix);
     #DEBUG("localPosterName = "localPosterName);
     #DEBUG("gFolder[idx] = "gFolder[idx]);
     url = getNicePosters(idx,url);
     DEBUG("new poster url = "url);
 
     localPosterPath = getPath(localPosterName,gFolder[idx]);
     DEBUG("localPosterPath = ["localPosterPath"]");
 
     #Get the poster if we havent fetched it already.
     if (UPDATE_POSTERS == 1 || gPosterList[localPosterPath] == "" ) {
 
         #create the folder.
         system(sprintf(" mkdir -p \"%s\" 2>/dev/null && rmdir \"%s\" ",localPosterPath,localPosterPath));
 
         if (exec(sprintf(WGET" -q -O %s %s",quoteFile(localPosterPath),quoteFile(url))) == 0 ) {
 
             gPosterList[localPosterPath] = 1;
 
             setPermissions(quoteFile(localPosterPath));
         }
     }
 
     gPoster[idx]=localPosterName;
     DEBUG("Got poster="gPoster[idx]);
 }
 
 function getNicePosters(idx,url,\
 id) {
     #Remove /combined/episodes from urls given by epguides.
     id = extractImdbId(gExternalSourceUrl[idx]);
 
     DEBUG("Poster check id = "id);
     if (id != "" && gCategory[idx] == "M"  && index(gPoster[idx],"moviedb") ==  0 ) {
         return getNiceMoviePosters(idx,url,id);
     } else {
         return url;
     }
 }
 
  #movie db - search direct for imdbid then extract picture
  function getNiceMoviePosters(idx,url,id,\
  f,line,url2) {
      DEBUG("Poster check id = "url2);
  
      url2="http://www.themoviedb.org/search?search[text]="id;
  
      #Look for 
      #  /image/posters/12457/Fast_and_Furious_thumb.jpg
      #and replace with
      #  http://images.themoviedb.org/posters/12457/Fast_and_Furious_cover.jpg
      #  http://images.themoviedb.org/posters/12457/Fast_and_Furious.jpg
      url2=scanPageForMatch(url2,"[a-zA-Z0-9/:]+_thumb.jpg");
  
      if (url2 != "" ) {
          DEBUG("url = "url2);
          if (sub(/_thumb/,"_cover",url2) == 1) {
              DEBUG("url = "url2);
              if (sub(/.*\/image\//,"http://images.themoviedb.org/",url2) == 1) {
                  DEBUG("url = "url2);
              }
          }
      }
      return url2;
  }
 
 # Scan a page for matches to regular expression
 # matches = array of matches index 1,2,...
 # max = max number to match
 # returns match or empty.
  function scanPageForMatch(url,regex,\
  matches) {
      scanPageForMatches(url,regex,matches,1);
      return matches[1];
  }
 
 # Scan a page for matches to regular expression
 # matches = array of matches index 1,2,...
 # max = max number to match
 # return number of matches
  function scanPageForMatches(url,regex,matches,max,\
  f,line,count) {
      f=getUrl(url,"scan",1);
  
      count=0;
      if (f != "" ) {
  
          FS="\n";
          while((getline line < f) > 0  ) {
              if (match(line,regex)) {
                  matches[++count] = substr(line,RSTART,RLENGTH);
                  if (max > 0 && count-max >= 0) {
                      break;
                  }
              }
          }
          close(f);
      }
      return count;
  }
 
 
 function scrapeIMDBLine(imdbContentPosition,idx,f,\
 l,i,p,r,title) {
 
     if (imdbContentPosition == "footer" ) {
         return imdbContentPosition;
     } else if (imdbContentPosition == "header" ) {
 
         #Only look for title at this stage
         #First get the HTML Title
         if (index($0,"<title>")) {
             title = extractTagText($0,"title");
             DEBUG("Title found ["title "] current title ["gTitle[idx]"]");
 
             title=checkIMDBTvTitle(idx,title);
         }
         if (index($0,"pagecontent")) {
             imdbContentPosition="body";
         }
 
     } else if (imdbContentPosition == "body") {
 
         if (index($0,">Company:")) {
             DEBUG("Found company details - ending");
             imdbContentPosition="footer";
         } else {
 
             #This is the main information section
 
             if (gYear[idx] == "" && (y=index($0,"/Sections/Years/")) > 0) {
                 gYear[idx] = substr($0,y+16,4);
                 DEBUG("IMDB: Got year ["gYear[idx]"]");
             }
             if (gPoster[idx] == "" && index($0,"a name=\"poster\"")) {
                 if (gCategory[idx] == "M" || gSettings["catalog_tv_poster_source"] == "imdb" ) {
                     if (match($0,"src=\"[^\"]+\"")) {
 
                         poster_imdb_url = substr($0,RSTART+5,RLENGTH-5-1);
 
                         #Get high quality one
                         sub(/SX[0-9]{2,3}_/,"SX400_",poster_imdb_url);
                         sub(/SY[0-9]{2,3}_/,"SY400_",poster_imdb_url);
 
                         getPoster(poster_imdb_url,idx);
                     }
                 }
             }
             if (gPlot[idx] == "" && index($0,"Plot:")) {
                 gPlot[idx] = scrapeIMDBPlot($0,f);
             }
             if (gGenre[idx] == "" && index($0,"Genre:")) {
                 gGenre[idx]=scrapeIMDBGenre($0,f);
             }
             if (gRating[idx] == "" && index($0,"/10</b>") ) {
                 gRating[idx]=0+extractTagText($0,"b");
                DEBUG("IMDB: Got Rating = ["gRating[idx]"]");
             }
             if (index($0,"certificates")) {
 
                 scrapeIMDBCertificate(idx,$0);
 
             }
             # Title is the hardest due to original language titling policy.
             # Good Bad Ugly, Crouching Tiger, Two Brothers, Leon lots of fun!! 
 
             if (gOriginalTitle[idx] == gTitle[idx] && index($0,"Also Known As:")) {
 
                 scrapeIMDBAka(idx,$0);
 
             }
         }
     } else {
         DEBUG("Unknown imdbContentPosition ["imdbContentPosition"]");
     }
     return imdbContentPosition;
 }
 
 function checkIMDBTvTitle(idx,title,\
 semicolon,quote,quotePos,title2) {
     #If title starts and ends with some hex code ( &xx;Name&xx; (2005) ) extract it and set tv type.
     gCategory[idx]="M";
     if (substr(title,1,1) == "&" ) {
         semicolon=index(title,";");
         if (semicolon > 0 ) { 
             quote=substr(title,1,semicolon);
             DEBUG("Imdb tv quote = <"quote">");
             title2=substr(title,semicolon+1);
             DEBUG("Imdb tv title = <"title2">");
             quotePos = index(title2,quote);
             if (quotePos > 0 ) {
                 #rest=substr(title2,quotePos+length(quote));
                 #if (match(/^ \([0-9]{4}\)$/,rest)) {
                     title=substr(title2,1,quotePos-1);
                     gCategory[idx]="T";
                 #}
             }
         }
     }
 
     #Remove the year
     gsub(/ \((19|20)[0-9][0-9](\/I|)\) *(\([A-Z]+\)|)$/,"",title);
 
     title=cleanTitle(title);
     if (adjustTitle(idx,title,"imdb")) {
         gOriginalTitle[idx] = gTitle[idx];
     }
     return title;
 }
 
 # Looks for matching country in AKA section. The first match must simply contain (country)
 # If it contains any qualifications then we stop looking at any more matches and reject the 
 # entire section.
 # This is because IMDB lists AKA in order of importance. So this helps weed out false matches
 # against alternative titles that are further down the list.
 
 function scrapeIMDBAka(idx,line,\
 l,akas,a,c,exclude,e) {
 
     if (gOriginalTitle[idx] != gTitle[idx] ) return ;
 
     l=substr(line,index(line,"</h")+5);
     split(l,akas,"<br>");
     for(a in akas) {
         DEBUG("Checking aka ["akas[a]"]");
         for(c in gTitleCountries ) {
             if (index(akas[a],"("gTitleCountries[c]":")) {
                 #We hit a matching AKA country but it has some kind of qualification
                 #which suggest that weve already passed a better match - ignore rest of section.
                 DEBUG("Ignoring aka section");
                 return;
                 eEeE=")"; #Balance brakets in editor!
             }
             if (index(akas[a],"("gTitleCountries[c]")")) {
                 #We hit a matching AKA country ...
                 split("poster|working|literal|IMAX|promotional|long title|script title|closing credits|informal alternative",exclude,"|");
                 for(e in exclude) {
                     if (index(akas[a],exclude[e])) {
                         #the qualifications again suggest that weve already passed a better match
                         # ignore rest of section.
                         DEBUG("Ignoring aka section");
                         return;
                     }
                 }
 			    #Use first match from AKA section 
 			    adjustTitle(idx,substr(akas[a],1,index(akas[a]," (")-1),"imdb_aka"); 
 			    return;
                     
             }
         }
     }
 }
 
 function scrapeIMDBCertificate(idx,line,\
 l,cert,c) {
     if ( match(line,"List[?]certificates=[^&]+")) {
         #<a href="/List?certificates=UK:15&&heading=14;UK:15">
         #<a href="/List?certificates=USA:R&&heading=14;USA:R">
 
         l=substr(line,RSTART,RLENGTH);
         l=substr(l,index(l,"=")+1); # eg UK:15
         split(l,cert,":");
         DEBUG("IMDB: found certificate ["cert[1]"]["cert[2]"]");
         
         #Now we only want to assign the certificate if it is in our desired list of countries.
         for(c = 1 ; (c in gCertificateCountries ) ; c++ ) {
             if (gCertCountry[idx] == gCertificateCountries[c]) {
                 #Keep certificate as this country is early in the list.
                 return;
             }
             if (cert[1] == gCertificateCountries[c]) {
                 #Update certificate
                 gCertCountry[idx] = cert[1];
                 gCertRating[idx] = cert[2];
                 DEBUG("IMDB: set certificate ["gCertCountry[idx]"]["gCertRating[idx]"]");
                 return;
             }
         }
     }
 }
 function scrapeIMDBPlot(line,f,\
 p,i) {
     getline p <f;
 
     #Full plot . keep it for next time
     if ((i=index(p," <a")) > 0) {
         p=substr(p,1,i-1);
     }
     if ((i=index(p,"|")) > 0) {
         p=substr(p,1,i-1);
     }
     DEBUG("IMDB: Got plot = ["p"]");
     return p;
 }
 function scrapeIMDBGenre(line,f,\
 l) {
     getline l <f;
     gsub(/<[^<>]+>/,"",l);
     sub(/ +more */,"",l);
     DEBUG("IMDB: Got genre = ["l"]");
     return l;
 }
 
 function relocate_files(i,\
     newName,oldName) {
 
    DEBUG("relocate_files");
 
     newName="";
     oldName="";
     fileType="";
     if (RENAME_TV == 1 && gCategory[i] == "T") {
 
         oldName=gFolder[i]"/"gMovieFiles[i];
         newName=gSettings["catalog_tv_file_fmt"];
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
         newName = substitute("0EPISODE",padEpisode(gEpisode[i]),newName);
 
         fileType="file";
 
     } else if (RENAME_FILM==1 && gCategory[i] == "M") {
 
         oldName=gFolder[i];
         newName=gSettings["catalog_film_folder_fmt"];
         fileType="folder";
 
     } else {
         return;
     }
     if (newName != "" && newName != oldName) {
 
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
         newName = substitute("TITLE",gTitle[i],newName);
         newName = substitute("YEAR",gYear[i],newName);
         newName = substitute("CERT",gCertRating[i],newName);
         newName = substitute("GENRE",gGenre[i],newName);
 
         #Remove characters windows doesnt like
         gsub(/[\\:*\"<>|]/,"_",newName); #"
         #Remove double slahses
         gsub(/\/\/+/,"/",newName);
 
         if (newName != oldName) {
            if (fileType == "folder") {
                if (moveFolder(i,oldName,newName) != 0) {
                    return;
                }
                gFile[i]="";
                gFolder[i]=newName;
            } else {
 
                # Move media file
                if (moveFile(oldName,newName) != 0 ) {
                    return;
                }
                gFolderMediaCount[gFolder[i]]--;
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
 
                    sub(/\.[^.]+$/,"",newName);
                    newName = newName ".nfo";
 
                    if (moveFile(gNfoDefault[i],newName) != 0) {
                        return;
                    }
                    if (!g_opt_dry_run) {
                        delete gNfoExists[gNfoDefault[i]] ;
 
                        gDate[newName]=gDate[gNfoDefault[i]];
                        delete gDate[gNfoDefault[i]];
 
                        gNfoDefault[i] = newName;
                        gNfoExists[gNfoDefault[i]] = 1;
                    }
                }
 
                if(gPoster[i] != "" && substr(gPoster[i],1,1)!= "/" && substr(gPoster[i],1,4) != "ovs:" ) {
                    oldName=oldFolder"/"gPoster[i];
                    newName=newFolder"/"gPoster[i];
                    if (moveFile(oldName,newName) != 0 ) {
                        return;
                    }
                }
 
                #Rename any other associated files (sub,idx etc) etc.
                rename_related(i,oldName,newName);
 
                #Move everything else from old to new.
                moveFolder(i,oldFolder,newFolder);
            }
         }
     } else {
         # Name unchanged
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
         DEBUG("Old path ["oldStr"]");
         DEBUG("New path ["str"]");
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
         moveFile(oldBase extensions[ext],newBase extensions[ext]);
     }
 
 }
 
 function preparePath(quotedFile,\
 ret) {
     if ((ret=system("mkdir -p "quotedFile)) != 0) {
         ERROR("Failed to prepare "quotedFile" :file exists?");
         return ret;
     }
     if ((ret=system("rmdir "quotedFile)) != 0) {
         ERROR("Failed to prepare "quotedFile" :rm error "ret);
         return ret;
     }
     return 0;
 }
 
 #This is used to double check we are only manipulating files that meet certain criteria.
 #More checks can be added over time. This is to prevent accidental moving of high level files etc.
 #esp if the process has to run as root.
 function changeable(f) {
     #TODO Expand to include only paths listed in scan list.
 
     #Check folder depth to avoid nasty accidents.
     if (substr(f,1,5) == "/tmp/") return 1;
 
     if (!match(f,"/[^/]+/[^/]+/")) {
         WARNING("Changing ["f"] might be risky. please make manual changes");
         return 0;
     }
     return 1;
 }
 
 function moveFile(oldName,newName,\
     cmd,new,old,ret) {
 
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
     # INFO("move file:\t"old" --> "new);
         if ((ret=preparePath(new)) == 0) {
             ret = exec("mv "old" "new);
         }
        return ret;
    }
 }
 
 function isDvdDir(f) {
     return substr(f,length(f)) == "/";
 }
 
 #Moves folder contents.
 function moveFolder(i,oldName,newName,\
     cmd,new,old,ret,isDvdDir) {
 
    if (!(folderIsRelevant(oldName))) {
        WARNING("["oldName"] not renamed as it was not listed in the arguments");
        return 1;
    } else if ( gFolderCount[oldName] > 2*(isDvdDir(gMovieFiles[i])) ) {
        WARNING("["oldName"] not renamed to ["newName"] due to "gFolderCount[oldName]" sub folders");
        return 1;
    } else if (gFolderMediaCount[oldName] > 1) {
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
 
 #Write a .nfo file if one didnt exist. This will make it easier 
 #to rebuild the DB_ARR at a later date. Esp if the file names are no
 #longer appearing in searches.
 function generate_nfo_file(nfoFormat,dbrow,\
 movie,tvshow,episodeguideurl,s,nfo,dbOne,fieldName,fieldId,i,nfoAdded) {
 
     nfoAdded=0;
     if (gSettings["catalog_nfo_write"] == "never" ) {
         return;
     }
     parseDbRow(dbrow,dbOne,1);
 
     DEBUG("NFO = "dbOne[NFO,1]);
     DEBUG("DIR = "dbOne[DIR,1]);
     nfo=getPath(dbOne[NFO,1],dbOne[DIR,1]);
 
     DEBUG("nfo = "nfo);
 
     if (gNfoExists[nfo] && gSettings["catalog_nfo_write"] != "always" ) {
         DEBUG("nfo already exists - skip writing");
         return;
     }
     DEBUG("nfo exists = "gNfoExists[nfo]);
 
     DEBUG("nfo style = "nfoFormat);
     
     if (nfoFormat == "xmbc" ) {
         movie=","TITLE","ORIG_TITLE","RATING","YEAR","PLOT","POSTER","CERT","WATCHED","IMDBID","FILE","GENRE",";
         tvshow=","TITLE","URL","RATING","PLOT","GENRE",";
         episodedetails=","EPTITLE","SEASON","EPISODE","AIRDATE",";
     }
 
 
     if (nfo != "" && !gNfoExists[nfo]) {
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
             #Flat
             print "#Auto Generated NFO" > nfo;
             for (i in dbOne) {
                 if (dbOne[i] != "") {
                     fieldId = substr(i,1,length(i)-2);
                     fieldName=gDbFieldName[fieldId];
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
         gNfoExists[nfo]=1;
         setPermissions(quoteFile(nfo));
     }
 }
 
 function startXmbcNfo(nfo) {
     print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > nfo;
     print "<!-- #Auto Generated NFO by catalog.sh -->" > nfo;
 }
 #dbOne = single row of index.db
 function writeXmbcTag(dbOne,tag,children,nfo,\
 idxPair,fieldId,fieldName,text) {
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
                        if (gSettings["catalog_poster_location"] == "with_media" ) {
                             #print "\t<"childTag">file://"dbOne[DIR,1]"/"text"</"childTag">" > nfo;
                             print "\t<"childTag">file://./"text"</"childTag">" > nfo;
                         } else {
                             print "\t<!-- Poster location not exported catalog_poster_location="gSettings["catalog_poster_location"]" -->" > nfo;
                             print "\t<"childTag">"text"</"childTag">" > nfo;
                         }
                     } else {
                         if (childTag == "watched" ) text=((text==1)?"true":"false");
                         print "\t<"childTag" "attr[tag,childTag]">"text"</"childTag">" > nfo;
                     }
                 }
             }
         }
     }
     print "</"tag">" > nfo;
 }
 
 # Some times epguides and imdb disagree. We only give a title if both are the same.
 #
 function fixTitles(idx) {
 
     # If no title set - just use the filename
     if (gTitle[idx] == "") {
         gTitle[idx] = gMovieFiles[idx];
         sub(/.*\//,"",gTitle[idx]); #remove path
         gsub(/[^A-Za-z0-9]/," ",gTitle[idx]); #remove odd chars
         DEBUG("Setting title to file["gTitle[idx]"]");
     }
 
     # If catalog_folder_titles set use the folder name
     if ( gSettings["catalog_folder_titles"] == 1 ) {
         gTitle[idx] = gFolder[idx];
         gsub(/.*\//,"",gTitle[idx]); #Remove path
         DEBUG("Setting title to folder["gTitle[idx]"]");
     }
     gTitle[idx]=cleanTitle(gTitle[idx]);
 }
 
 function get_best_episode_title(idx,\
     j,tvcom,epguideTitles,imdbTitle,egTitle) {
 
     if (gCategory[idx] != "T") return;
 
     DEBUG("gTvCom["idx"]=["gTvCom[idx]"]");
     DEBUG("gEpTitle["idx"]=["EpTitle[idx]"]");
 
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
             DEBUG("Title for epguides "epguideTitles[j]);
             #Use the EpGuides title as this has part numbers.
             gEpTitle[idx] = epguideTitles[j];
             gTvCom[idx] = tvcom[j];
             break;
           } else {
             DEBUG("Ignoring Title for epguides "epguideTitles[j]);
           }
         }
     }
 }
 
 function createIndexRow(i,dbSize,dbArr,file_to_db,\
 row) {
     # Estimated download date. cant use nfo time as these may get overwritten.
     estimate=gDate[gFolder[i]"/unpak.log"];
     if (estimate == "") {
         estimate=gDate[gFolder[i]"/unpak.txt"];
     }
     if (estimate == "") {
         estimate = gFileTime[i];
     }
 
     if (gFile[i] == "" ) {
         gFile[i]=getPath(gMovieFiles[i],gFolder[i]);
     }
     gsub(/\/\/+/,"/",gFile[i]);
 
     if ((gFile[i] in gFolderCount ) && gFolderCount[gFile[i]]) {
         DEBUG("Adjusting file for video_ts");
         gFile[i] = gFile[i] "/";
     }
 
     row="\t"ID"\t"(gMaxDatabaseId++);
 
     if (gFile[i] in file_to_db) {
         dbIdx = file_to_db[gFile[i]];
         row=row"\t"WATCHED"\t"dbArr[WATCHED,dbIdx];
         row=row"\t"ACTION"\t"dbArr[ACTION,dbIdx];
     } else {
         row=row"\t"WATCHED"\t0";
         row=row"\t"ACTION"\t0";
     }
 
     #Title and Season must be kept next to one another to aid grepping.
     row=row"\t"TITLE"\t"gTitle[i];
     if (gOriginalTitle[i] != "" && gOriginalTitle[i] != gTitle[i] ) {
         row=row"\t"ORIG_TITLE"\t"gOriginalTitle[i];
     }
     row=row"\t"SEASON"\t"gSeason[i];
 
     row=row"\t"EPISODE"\t"gEpisode[i];
 
     row=row"\t"SEASON0"\t"sprintf("%02d",gSeason[i]);
     row=row"\t"EPISODE0"\t"padEpisode(gEpisode[i]);
 
     row=row"\t"YEAR"\t"gYear[i];
     row=row"\t"FILE"\t"gFile[i];
     row=row"\t"ADDITIONAL_INFO"\t"gAdditionalInfo[i];
     row=row"\t"PARTS"\t"gParts[i];
     row=row"\t"URL"\t"gExternalSourceUrl[i];
     row=row"\t"CERT"\t"gCertCountry[i]":"gCertRating[i];
     row=row"\t"GENRE"\t"gGenre[i];
     row=row"\t"RATING"\t"gRating[i];
     row=row"\t"PLOT"\t"gPlot[i];
     row=row"\t"CATEGORY"\t"gCategory[i];
     row=row"\t"POSTER"\t"gPoster[i];
     row=row"\t"FILETIME"\t"gFileTime[i];
     if (gMovieFileCount > 4) {
         #bulk add - use the estimate download date as the index date.
         #this helps the index to appear to have some chronological order
         #on first build
         row=row"\t"INDEXTIME"\t"estimate;
     } else {
         row=row"\t"INDEXTIME"\t"NOW;
     }
     row=row"\t"DOWNLOADTIME"\t"estimate;
     #row=row"\t"SEARCH"\t"gSearch[i];
     row=row"\t"PROD"\t"gProdCode[i];
     row=row"\t"AIRDATE"\t"gAirDate[i];
     row=row"\t"EPTITLEIMDB"\t"gEpTitleImdb[i];
     row=row"\t"AIRDATEIMDB"\t"gAirDateImdb[i];
 
     row=row"\t"TVCOM"\t"gTvCom[i];
     row=row"\t"EPTITLE"\t"gEpTitle[i];
     nfo="";
     print "NFO:"gNfoDefault[i];
     print "NFOExists:"gNfoExists[gNfoDefault[i]];
 
     if (gNfoExists[gNfoDefault[i]] || gSettings["catalog_nfo_write"] != "never" ) {
         nfo=gNfoDefault[i];
         gsub(/.*\//,"",nfo);
     }
     row=row"\t"NFO"\t"nfo;
     return row;
 }
 
 function add_new_scanned_files_to_database(outputFile,db_size,db_arr,file_to_db,\
 i,row,fields,f) {
 
     DEBUG("add_new_scanned_files_to_database");
     gMaxDatabaseId++;
 
     for(i in gMovieFiles) {
 
         if (gMovieFiles[i] == "") continue;
 
         row=createIndexRow(i,db_size,db_arr,file_to_db);
 
         DEBUG("Adding to db:"gMovieFiles[i]);
         print row"\t" > outputFile;
 
         generate_nfo_file(gSettings["catalog_nfo_format"],row);
 
         split(row,fields,"\t");
         for(f=1; (f in fields) ; f++) {
             if (f%2) {
                 if(fields[f] != "" ) INFO(inf"=["fields[f]"]");
             } else {
                 inf=gDbFieldName[fields[f]]; 
             }
         }
 
     }
     close(outputFile);
 }
 function touchAndMove(x,y) {
     system("touch \""x"\" ; mv \""x"\" \""y"\"");
 }
 
 #--------------------------------------------------------------------
 # Convinience function. Create a new file to capture some information.
 # At the end capture files are deleted.
 #--------------------------------------------------------------------
 function NEW_CAPTURE_FILE(label,\
     CAPTURE_FILE,suffix) {
     suffix= "." CAPTURE_COUNT "__" label;
     CAPTURE_FILE = CAPTURE_PREFIX PID suffix;
     CAPTURE_COUNT++;
    #DEBUG("New capture file "label" ["CAPTURE_FILE "]");
     return CAPTURE_FILE;
 }
 
 function clean_capture_files(\
 cmd,file) {
     INFO("Clean up");
     exec("rm -f -- \""CAPTURE_PREFIX PID "\".* ");
 }
 function INFO(x) {
     print "[INFO]   "(systime()-ELAPSED_TIME)" : " x;
 }
 function WARNING(x) {
     print "[WARNING] "x;
 }
 function ERROR(x) {
     print "[ERROR] "x;
 }
 function DETAIL(x) {
     print "[DETAIL] "x;
 }
 
 function trim(str) {
     gsub(/^ +/,"",str);
     gsub(/ +$/,"",str);
     return str;
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
 
 #Move folder names from argument list
 function get_folders_from_args(folder_arr,\
 i,folderCount,moveDown) {
     folderCount=0;
     moveDown=0;
     for(i = 1 ; i < ARGC ; i++ ) {
             INFO("Arg:["ARGV[i]"]");
         if (ARGV[i] == "IGNORE_NFO" ) {
             g_opt_catalog_nfo_read="no";
             moveDown++;
         } else if (ARGV[i] == "REBUILD" ) {
             REBUILD=1;
             moveDown++;
         } else if (ARGV[i] == "DEBUG" ) {
             DBG=1;
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
             #variable assignment - keep for awk to process
         } else {
             # A folder or file
             INFO("Scan Path:["ARGV[i]"]");
             folder_arr[++folderCount] = ARGV[i];
             moveDown++;
         }
     }
     ARGC -= moveDown;
     # Add dev null as dummy input
     ARGV[ARGC++] = "/dev/null";
     return folderCount;
 }
 
 
 function load_catalog_settings(file_name) {
 
     loadSettings(file_name);
 
     gSettings["catalog_ignore_paths"]=glob2re(gSettings["catalog_ignore_paths"]);
 
     #Replace dir1|dir2|dir3 with dir1.*|dir2.*|dir3.*
     gsub(/[|]/,".*|",gSettings["catalog_ignore_paths"]);
     gSettings["catalog_ignore_paths"]=gSettings["catalog_ignore_paths"]".*";
 
     gSettings["catalog_ignore_names"]=glob2re(gSettings["catalog_ignore_names"]);
 
     #catalog_scene_tags = csv2re(tolower(catalog_scene_tags));
 
     #Search engines used for simple keywords+"imdb" searches.
     #google,msn and yahoo all about the same.
     split(tolower(gSettings["catalog_search_engines"]),link_search_engines,"|");
 
     #Search engines used for for deep searches (when mapping obsucre filename to a title).
     #Google seems much better at this compared to others.
     #Could use Google for everything but it may think your network is infected
     #when doing big scans.
     split(tolower(gSettings["catalog_deep_search_engines"]),title_search_engines,"|");
     web_search_count=0;
 
     #Override with command line setting
     if (g_opt_catalog_nfo_read != "" ) {
         gSettings["catalog_nfo_read"] = g_opt_catalog_nfo_read;
     }
 }
 
