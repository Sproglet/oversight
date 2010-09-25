# Folder and file scanning functions

function scan_folder_for_new_media(folderArray,scan_options,\
f,fcount,total,done) {

    for(f in folderArray ) {

        if (folderArray[f] && !(f in done)) {
            report_status("folder "++fcount);
            total += scan_contents(folderArray[f],scan_options);
            done[f]=1;
        }
    }

    return 0+total;

}

#  Do ls -l on a known file and check position of filename and time
function findLSFormat(\
tempFile,i,procfile) {

    DEBUG("Finding LS Format");

    procfile="/proc/"PID"/fd"; #Fd always has a recent timestamp even on cygwin
    tempFile=new_capture_file("LS")


    exec(LS" -ld "procfile" > "qa(tempFile) );
    FS=" ";
    
    while ((getline < tempFile) > 0 ) {
        for(i=1 ; i - NF <= 0 ; i++ ) {
            if ($i == procfile) gLS_FILE_POS=i;
            if (index($i,":")) gLS_TIME_POS=i;
        }
        break;
    }
    close(tempFile);
    INF("ls -l file position at "gLS_FILE_POS);
    INF("ls -l time position at "gLS_TIME_POS);

}
function is_hidden_fldr(d,\
ur) {
    ur = g_settings["unpak_nmt_pin_root"];
    return ur != "" && index(d,ur) == 1;
}

function is_movie_structure_fldr(d) {
    return is_videots_fldr(d) || is_bdmv_subfldr(d);
}

function is_bdmv_subfldr(d) {
    return tolower(d) ~ "/bdmv/(playlist|clipinf|stream|auxdata|backup|jar|meta|bdjo)\\>";
}
function is_bdmv_fldr(d) {
    return tolower(d) ~ "/bdmv$" && dir_contains(d"/STREAM","m2ts$");
}
function is_videots_fldr(d) {
    return tolower(d) ~ "/video_ts$" && dir_contains(d,"vob$");
}
function dir_contains(dir,pattern) {
    return exec("ls "qa(dir)" 2>/dev/null | egrep -iq "qa(pattern) ) ==0;
}

# Input is ls -lR or ls -l
function scan_contents(root,scan_options,\
tempFile,currentFolder,skipFolder,i,folderNameNext,perms,w5,lsMonth,files_in_db,\
lsDate,lsTimeOrYear,f,d,extRe,pos,store,lc,nfo,quotedRoot,scan_line,scan_words,ts,total,minfo) {

    DEBUG("Scanning "root);
    if (root == "") return;

    # Get all files already scanned at root level
    if (NEWSCAN) {
        get_files_in_db(root,INDEX_DB,files_in_db);
    }

    tempFile=new_capture_file("MOVIEFILES");

    #Remove trailing slash. This ensures all folder paths end without trailing slash
    if (root != "/" ) {
        gsub(/\/+$/,"",root); 
    }

    quotedRoot=qa(root);

    extRe="\\.[^.]+$";

    #We use ls -R instead of find to get a sorted list.
    #There may be some issue with this.

    # We want to list a file which may be a file, folder or symlink.
    # ls -Rl x/ will do symlink but not normal file.
    #so do  ls -Rl x/ || ls -Rl x  
    # note ls -L will follow symlinks at any depth - this is passed via catalog_follow_symlinks
    exec("( "LS" "scan_options" "quotedRoot"/ || "LS" "scan_options" "quotedRoot" ) > "qa(tempFile) );
    currentFolder = root;
    skipFolder=0;
    folderNameNext=1;

    while((getline scan_line < tempFile) > 0 ) {


        #DEBUG( "ls: ["scan_line"]"); 
        #INF("scan_line: length="length(scan_line)" "url_encode(scan_line));

        store=0;

        if (scan_line == "") continue;

        if (match(scan_line,"^total [0-9]+$")) continue;

        split(scan_line,scan_words," +");

        perms=scan_words[1];

        if (!match(substr(perms,2,9),"^[-rwxsSt]+$") ) {
            #Just entered a folder

           # If the folder has changed and we have more than n items then process them
           # this is to save memory. As this removes stored data we only do this if we 
           # change folder. This ensures we process multipart files together.
           total += identify_and_catalog(minfo,0);
           clear_folder_info();


           currentFolder = scan_line;
           sub(/\/*:$/,"",currentFolder);
           DEBUG("Folder = "currentFolder);
           if (NEWSCAN) {
               get_files_in_db(currentFolder,INDEX_DB,files_in_db);
           }
           folderNameNext=0;
            if ( currentFolder ~ g_settings["catalog_ignore_paths"] ) {

                skipFolder=1;
                INF("Ignore path "currentFolder);

            } else if ( is_movie_structure_fldr(currentFolder)) {

                INF("Ignore DVD/BDMV sub folder "currentFolder);
                skipFolder=1;

            } else if(is_hidden_fldr(currentFolder)) {

                skipFolder=1;
                INF("SKIPPING "currentFolder);

            } else if (currentFolder in g_fldrCount) {

                WARNING("Already visited "currentFolder);
                skipFolder=1;


            } else {
                skipFolder=0;
                g_fldrMediaCount[currentFolder]=0;
                g_fldrInfoCount[currentFolder]=0;
                g_fldrCount[currentFolder]=0;
            }

        } else if (!skipFolder) {

            lc=tolower(scan_line);

            if ( lc ~ g_settings["catalog_ignore_names"] ) {
                DEBUG("Ignore name "scan_line);
                continue;
            }

            w5=lsMonth=lsDate=lsTimeOrYear="";

            # ls -l format. Extract file time...
            w5=scan_words[5];

            if ( gLS_TIME_POS ) {
                lsMonth=tolower(scan_words[gLS_TIME_POS-2]);
                lsDate=scan_words[gLS_TIME_POS-1];
                lsTimeOrYear=scan_words[gLS_TIME_POS];
            }

            #Get Position of word at gLS_FILE_POS.
            #(not cannot change $n variables as they cause corruption of scan_line.eg 
            #double spaces collapsed.
            pos=index(scan_line,scan_words[2]);
            for(i=3 ; i - gLS_FILE_POS <= 0 ; i++ ) {
                pos=indexFrom(scan_line,scan_words[i],pos+length(scan_words[i-1]));
            }
            scan_line=substr(scan_line,pos);
            lc=tolower(scan_line);


            if (substr(perms,1,1) != "-") { # Not a file

                if (substr(perms,1,1) == "d") { #Directory

                    if (currentFolder in g_fldrCount) {
                        g_fldrCount[currentFolder]++;
                    }

                    DEBUG("Folder ["scan_line"]");

                    if (is_videots_fldr(currentFolder"/"scan_line) || is_bdmv_fldr(currentFolder"/"scan_line) ) {

                        if (match(currentFolder,"/[^/]+$")) {
                            f = substr(currentFolder,RSTART+1);
                            d = substr(currentFolder,1,RSTART-1);
                        }

                        ts=calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW);

                        storeMovie(minfo,f"/",d,ts,"/$",".nfo",files_in_db);
                    }
                }

            } else {
                

                # Its a regular file

                # because we use ls to scan we must check if the file path was passed directly to ls
                # rather than part of a recursive listing.
                # This is all a bit yucky and needs a rewrite - but here we are..

                # eg mkdir a ; touch a/b a/c
                # ls -Rl a gives
                # a:
                # -rw-r--r--    1 root     root            0 Nov 15 03:12 b
                # -rw-r--r--    1 root     root            0 Nov 15 03:12 c
                # but
                # ls -Rl a a/b gives
                # -rw-r--r--    1 root     root            0 Nov 15 03:12 a/b
                # 
                # a:
                # -rw-r--r--    1 root     root            0 Nov 15 03:12 b
                # -rw-r--r--    1 root     root            0 Nov 15 03:12 c

                # the following code intercepts the "a/b" and makes it look like the recursive form.
                # maybe the much simple altermative is to test each ls argument and process one way
                # if its a folder or another if its a file.


                if (match(scan_line,"[^/]/")) { 
                    # get the currentFolder from the file path
                    i = match(scan_line,".*[^/]/"); # use .*  to get the last path component
                    # Current folder should be root at this stage as ls -Rl will gather all file arguments first.
                    currentFolder = substr(scan_line,1,RLENGTH-1);
                    if ( index(currentFolder,"/") != 1 ) {
                        currentFolder =  root "/" currentFolder;
                    }
                    currentFolder = clean_path( currentFolder );

                    scan_line = substr(scan_line,RLENGTH+1);
                    lc = tolower(scan_line);
                    INF("Looking at direct file argument ["currentFolder"]["scan_line"]");
                }

                # Now continue to check the file 

                if (match(lc,gExtRegExAll)) {

                    store = 1;
                    if (match(lc,gExtRegexIso)) {
                        #ISO images.

                        # Check image size. Images should be very large or for testing only, very small.
                        if (length(w5) > 1 && length(w5) - 10 < 0) {
                            INF("Skipping image ["scan_line"] - too small");
                            store = 0;
                        }
                    }

                    if (store) {
                        #DEBUG("g_fldrMediaCount[currentFolder]="g_fldrMediaCount[currentFolder]);
                        #Only add it if previous one is not part of same file.
                        if (g_fldrMediaCount[currentFolder] > 0 && gMovieFileCount - 1 >= 0 ) {
                          if ( checkMultiPart(minfo,scan_line) ) {
                              #replace xxx.cd1.ext with xxx.nfo (Internet convention)
                              #otherwise leave xxx.cd1.yyy.ext with xxx.cd1.yyy.nfo (YAMJ convention)
                              if ( !setNfo(minfo,".(|"g_multpart_tags")[1-9]" extRe,".nfo") ) {
                                  setNfo(minfo,extRe,".nfo");
                              }
                              store = 0;
                           }
                       }
                   }


                } else if (match(scan_line,"unpak.???$")) {
                    
                    g_file_date[currentFolder"/"scan_line] = calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW);


                } else if (match(lc,"\\.nfo$")) {

                    nfo=currentFolder"/"scan_line;
                    g_fldrInfoCount[currentFolder]++;
                    g_fldrInfoName[currentFolder]=nfo;
                    g_file_date[nfo] = calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW);
                }

                if (store) {
                    ts=calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW);
                    storeMovie(minfo,scan_line,currentFolder,ts,"\\.[^.]+$",".nfo",files_in_db)
                }
            }
        }

    }

    close(tempFile);

    total += identify_and_catalog(minfo,1);

    DEBUG("Finished Scanning "root);
    return 0+total;
}

function storeMovie(minfo,file,folder,timeStamp,nfoReplace,nfoExt,files_in_db,\
path) {

    identify_and_catalog(minfo,0);
    path=clean_path(folder"/"file);
    if (!NEWSCAN || in_list(path,files_in_db) ) {


        INF("Storing " path);
        DEBUG("NEWSCAN = "NEWSCAN" in_list("path") = "in_list(path,files_in_db));


        g_fldrMediaCount[folder]++;

        minfo["mi_folder"]=folder;
        minfo["mi_media"] = file;
        minfo["mi_file_time"] = timeStamp;

        setNfo(minfo,nfoReplace,nfoExt);

        gMovieFileCount++;
    }
}

#Check if a filename is similar to the previous stored filename.
# lcName         : lower case file name
# count          : next index in array
# multiPartRegex : regex that matches the part tag of the file
function checkMultiPart(minfo,name,\
lastNameSeen,i,lastch,ch) {

    lastNameSeen = minfo["mi_media"];

    if (length(lastNameSeen) != length(name)) {
        return 0;
    }
    if (lastNameSeen == name) return 0;

    #DEBUG("Multipart check ["lastNameSeen"] vs ["name"]");
    for(i=1 ; i - length(lastNameSeen) <= 0 ; i++ ) {
        lastch = substr(lastNameSeen,i,1);
        ch = substr(name,i,1);
        if (lastch != ch) {
            break;
        }
    }

    # Check following characters...
    if (substr(lastNameSeen,i+1) != substr(name,i+1)) {
        #DEBUG("checkMultiPart: no match last bit ["substr(lastNameSeen,i+1)"] != ["substr(name,i+1)"]");
        return 0;
    }

    lastch = tolower(lastch);
    ch = tolower(ch);

    # i is the point at which the filenames differ.

    if (lastch == "1" ) {
        if (index("2345",ch) == 0) {
            #DEBUG("checkMultiPart : expected 2345 got "ch);
            return 0;
        }
        # Ignore double digit xxx01 xxx02 these are likely tv series.
        if (substr(lastNameSeen,i-1,2) ~ "[0-9]1" ) {
            #DEBUG("checkMultiPart : ignore double digit multiparts.");
            return 0;
        }
        # Avoid matching tv programs e0n x0n 11n
        # At this stage we have not done full filename analysis to determine if it matches a tv program
        # That is done during the scrape stage by "checkTvFilenameFormat". This is just a quick way.
        # reject 0e1 0x1 "ep 1" "dvd 1" etc.
        # we could change this to a white list instead. eg part01 cd1 etc.
        if (tolower(substr(lastNameSeen,1,i)) ~ "([0-9][.edx]|dvd|disc|ep|episode) *1$") {
            #DEBUG("checkMultiPart: rejected ["lastNameSeen"]");
            return 0;
        }

    } else if (lastch == "a") {

        if (index("bcdef",ch) == 0) {
            return 0;
        }
    } else {
        #DEBUG("checkMultiPart: exptected 1 or a");
        return 0;
    }

    INF("Found multi part file - linked with "lastNameSeen);
    minfo["mi_parts"] = (minfo["mi_parts"] =="" ? "" : minfo["mi_parts"]"/" ) name;
    minfo["mi_multipart_tag_pos"] = i;
    return 1;
}

# set the nfo file by replacing the pattern with the given text.
function setNfo(minfo,pattern,replace,\
nfo,lcNfo) {
    #Add a lookup to nfo file
    nfo=minfo["mi_media"];
    lcNfo = tolower(nfo);
    if (match(lcNfo,pattern)) {
        nfo=substr(nfo,1,RSTART-1) replace substr(nfo,RSTART+RLENGTH);
        minfo["mi_nfo_default"] = getPath(nfo,minfo["mi_folder"]);
        return 1;
    } else {
        return 0;
    }
}

#A folder is relevant if it is tightly associated with the media it contains.
#ie it was created just for that film or tv series.
# True is the folder was included as part of the scan and is specific to the current media file
function folderIsRelevant(dir) {

    DEBUG("Check parent folder relation to media ["dir"]");
        if ( !(dir in g_fldrCount) || g_fldrCount[dir] == "") { 
            DEBUG("unknown folder ["dir"]" );
            return 0;
        }
    #Ensure the folder was scanned and also it has 2 or fewer sub folders (VIDEO_TS,AUDIO_TS)
    if (g_fldrCount[dir] - 2 > 0 ) {
        DEBUG("Too many sub folders - general folder");
        return 0;
    }
   if (g_fldrMediaCount[dir] - 2 > 0 ) {
       DEBUG("Too much media  general folder");
       return 0;
   }
   return 1;
}

function setImplicitNfo(minfo,path,\
ret) {

    if (isDvdDir(path)) path = substr(path,1,length(path)-1);

    if (g_fldrMediaCount[path]+0 <= 1 ) { # if 1 or less media files (could be 0 for nfo inside a dvd structure)
       
        if ( g_fldrInfoCount[path] == 1 ) { # if only one nfo file in this folder
           
           if( is_file(g_fldrInfoName[path])) {

               DEBUG("Using single nfo "g_fldrInfoName[path]);

               minfo["mi_nfo_default"] = g_fldrInfoName[path];

               ret = 1;
           }
       }
   }
   return ret;
}

function identify_and_catalog(minfo,force_merge,\
file,fldr,bestUrl,scanNfo,thisTime,eta,\
total,\
cat,qfile) {

    id1("identify_and_catalog "minfo["mi_folder"]"/"minfo["mi_media"]);

    qfile = INDEX_DB ".queue." PID;

    if (verify(minfo)) {

        eta="";
       
    #dep#        begin_search("");

        bestUrl="";

        scanNfo=0;

        file=minfo["mi_media"];
        fldr=minfo["mi_folder"];

        if (file) {

            DIV0("Start item "(g_item_count)": ["file"]");

            report_status("item "(++g_item_count));

            DEBUG("folder :["fldr"]");

            if (isDvdDir(file) == 0 && !match(file,gExtRegExAll)) {

                WARNING("Skipping unknown file ["file"]");

            } else {

                thisTime = systime();


                if (g_settings["catalog_nfo_read"] != "no") {

                    if (is_file(minfo["mi_nfo_default"])) {

                       DEBUG("Using default info to find url");
                       scanNfo = 1;

                    # Look at other files in the same folder.
                    } else if  (setImplicitNfo(minfo,fldr) ) { #XX
                        scanNfo = 1;

                    # Look inside movie_structure
                    } else if ( isDvdDir(file) && setImplicitNfo(minfo,fldr"/"file) ) { #XX
                        scanNfo = 1;
                   }
                }

                if (scanNfo){
                   bestUrl = scanNfoForImdbLink(minfo["mi_nfo_default"]);
                }

                if (bestUrl == "") {
                    # scan filename for imdb link
                    bestUrl = extractImdbLink(file);
                    if (bestUrl) {
                        INF("extract imdb id from "file);
                    }
                }

                cat="";

                if (bestUrl) {
                    cat = scrapeIMDBTitlePage(minfo,bestUrl);
                }

                if (cat == "M" ) {

                    # Its definitely a movie according to IMDB or NFO
                    cat = movie_search(minfo,bestUrl);

                } else if (cat == "T" ) {

                    # Its definitely a series according to IMDB or NFO
                    cat = tv_search_simple(minfo,bestUrl);

                } else {

                    # Not sure - try a TV search looking for various abbreviations.
                    cat = tv_search_complex(minfo,bestUrl);

                    if (cat != "T") {
                        # Could not find any hits using tv abbreviations, try heuristis for a movie search.
                        # This involves searching web for imdb id.
                        cat = movie_search(minfo,bestUrl);
                        if (cat == "T") {
                            # If we get here we found an IMDB id , but it looks like a TV show after all.
                            # This may happen with mini-series that do not have normal naming conventions etc.
                            # At this point we should have scraped a better title from IMDB so try a simple TV search again.
                            cat = tv_search_simple(minfo,bestUrl);
                        }
                    }
                }


                if (cat != "") {

                    #If poster is blank fall back to imdb
                    if (minfo["mi_poster"] == "") {
                        minfo["mi_poster"] = minfo["mi_imdb_img"];
                    }
                    fixTitles(minfo);

                    #Only get posters if catalog is installed as part of oversight
                    if (index(APPDIR,"/oversight") ) {

                        if (GET_POSTERS) {
                            minfo["mi_poster"] = download_image(POSTER,minfo,"mi_poster");
                        }

                        if (GET_FANART) {
                            minfo["mi_fanart"] = download_image(FANART,minfo,"mi_fanart");
                        }
                    }

                    relocate_files(minfo);



                    if (g_opt_dry_run) {
                        print "dryrun: "minfo["mi_file"]" -> "minfo["mi_title"];
                    }
                    total++;

                } else {
                    INF("Skipping item "minfo["mi_media"]);
                }

                thisTime = systime()-thisTime ;
                g_process_time += thisTime;
                g_elapsed_time = systime() - g_start_time;
                g_total ++;
                #lang_test(minfo);

                DEBUG(sprintf("processed in "thisTime"s net av:%.1f gross av:%.1f" ,(g_process_time/g_total),(g_elapsed_time/g_total)));

                queue_minfo(minfo,qfile);
            }
        }

        delete minfo;

        if (force_merge || ( (g_total % g_batch_size) == g_batch_size - 1)) {

                merge_queue(qfile);
        }

    }

    id0(total);
}

function queue_minfo(minfo,qfile,\
row) {

    row = createIndexRow(minfo,-1,0,0,"");
    print row >> qfile;
    INF("queued ["row"]");

    # Plots are added to a seperate file.
    update_plots(g_plot_file,minfo);

    # If plots need to be written to nfo file then they should 
    # be added to the row at this point.
    row = row PLOT"\t"minfo["mi_plot"]"\t";
    generate_nfo_file(g_settings["catalog_nfo_format"],row);

    close(qfile);
}
function clear_folder_info() {

    # Clean when folder changed
    delete g_fldrMediaCount;
    delete g_fldrInfoCount;
    delete g_fldrInfoName;
    delete g_fldrCount;

    # unique by file - clean when changing folder.
    delete g_file_date; 

    gMovieFileCount = 0;
    INF("Reset scanned files store");
}

