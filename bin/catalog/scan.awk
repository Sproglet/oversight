# Folder and file scanning functions
function trigger_any_changed(\
f,ret,i) {
    ret = 1;
    if (split(g_settings["catalog_trigger_files"],f,",")) {
        ret = 0;
        for(i in f) {
            f[i] = replace_share_name(f[i]);
            if (f[i] != "") {
                if (trigger_file_changed(f[i])) {
                    INF("File changed: "f[i]);
                    ret =1;
                    break;
                } else {
                    INF("File unchanged: "f[i]);
                }
            }
        }
    }
    return ret;
}

function trigger_file_changed(f,\
ret,key,tmpf,txt) {

    ret = 0;
    key="file_state:"f;
    tmpf = new_capture_file("trigger");
    if (exec("ls -ld "qa(f)" > "qa(tmpf)) == 0) {
        if ((getline txt < tmpf) > 0) {
            if (g_state[key] != txt) {
                update_state(key,txt);
                ret = 1;
            }
        }
        close(tmpf);
    }
    return ret;
}

function free_kb(device,\
tmpf,txt,wrds,ret) {
    ret = -1;
    tmpf = new_capture_file("df");
    if (exec("df -k "qa(device)" > "qa(tmpf)) == 0) {
        while((getline txt < tmpf) > 0 ) {
            # do nothing
        }
        close(tmpf);
        # line may be
        # export total used free OR
        # <space> total used free (if export is long)
        sub(/^[^ ]* +/,"",txt); 
        split(txt,wrds," ");
        ret = wrds[3];
    }
    return ret;
    #system("df -k "qa(device)" | awk 'END { sub(/^[^ ]*/,\"\") ; print $3; }'");
}

function file_system_changed(dir,\
key,ret,free) {
    ret = 0;
    key="free_mb:"dir;

    free = int(free_kb(dir)/1024);
    INF("Free space "dir" = "free" was "g_state[key]);
    if (free >= 0 && g_state[key] != free) {
        update_state(key,free);
        ret = 1;
    } else {
        INF("Free space unchanged from last scan - skipping");
    }
    return ret;
}

function scan_folder_for_new_media(folderArray,scan_options,\
f,fcount,total,done,dir) {

    # If NEWSCAN is not present then force a full scan and ignore CHECK_FREE_SPACE & CHECK_TRIGGER_FILES
    if(!NEWSCAN || !CHECK_TRIGGER_FILES || trigger_any_changed()) {

        for(f in folderArray ) {

            dir = folderArray[f];

            if (dir && !(dir in done)) {
                report_status("folder "++fcount);

                if (!CHECK_FREE_SPACE || file_system_changed(dir)) {
                    total += scan_contents(dir,scan_options);
                }
                done[dir]=1;
            }
        }
    }

    return 0+total;

}

#  Do ls -l on a known file and check position of filename and time
function findLSFormat(\
tempFile,i,procfile) {

    DEBUG("Finding ls format");

    procfile="/proc/"PID"/fd"; #Fd always has a recent timestamp even on cygwin
    tempFile=new_capture_file("LS")


    exec("ls -ld "procfile" > "qa(tempFile) );
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
rootlen,ign_path,tempFile,currentFolder,skipFolder,i,folderNameNext,perms,w5,lsMonth,files_in_db,\
lsDate,lsTimeOrYear,f,d,extRe,pos,store,lc,nfo,quotedRoot,scan_line,scan_words,ts,total,minfo,person_extid2name,qfile) {

    INF("scan_contents "root);

    rootlen = length(root);

    qfile = new_capture_file("dbqueue");
    if (root == "") return;

    delete g_fldrCount;
    ign_path = g_settings["catalog_ignore_paths"];

    # Get all files already scanned at root level
    if (NEWSCAN && g_db) {
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
    exec("( ls "scan_options" "quotedRoot"/ || ls "scan_options" "quotedRoot" ) > "qa(tempFile) );
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
           total += identify_and_catalog(minfo,qfile,0,person_extid2name);

           clear_folder_info();

           delete files_in_db;

           currentFolder = scan_line;
           sub(/\/*:$/,"",currentFolder);
           DEBUG("/- "substr(currentFolder,rootlen+2)); #allow for ls index +2
           folderNameNext=0;
            if ( ign_path != "" && currentFolder ~ ign_path ) {

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
            if (g_db && NEWSCAN && !skipFolder) {
                get_files_in_db(currentFolder,INDEX_DB,files_in_db);
            }

        } else if (!skipFolder) {

            lc=tolower(scan_line);

            if ( lc ~ g_settings["catalog_ignore_names"] ) {
                INF("Ignore name "scan_line);
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

                    g_fldrCount[currentFolder]++;

                    #DEBUG("/- "scan_line);

                    if (is_videots_fldr(currentFolder"/"scan_line) || is_bdmv_fldr(currentFolder"/"scan_line) ) {

                        if (match(currentFolder,"/[^/]+$")) {
                            f = substr(currentFolder,RSTART+1);
                            d = substr(currentFolder,1,RSTART-1);
                        }

                        ts=calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW);

                        identify_and_catalog(minfo,qfile,0,person_extid2name);
                        storeMovie(minfo,f"/",d,ts,files_in_db);
                        setNfo(minfo,"/$",".nfo");
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
                                store = 0;
                                minfo["mi_mb"] += int(w5/1024/1024+0.5); 
                                if (!is_file(minfo["mi_nfo_default"])) {
                                    #replace xxx.cd1.ext with xxx.nfo (Internet convention)
                                    #otherwise leave xxx.cd1.yyy.ext with xxx.cd1.yyy.nfo (YAMJ convention)
                                    setNfo(minfo,".(|"g_multpart_tags")[1-9]" extRe,".nfo");
                                }
                            }
                       }
                   }


                } else if (match(scan_line,"unpak.???$")) {
                    
                    g_file_date[currentFolder"/"scan_line] = calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW);


                } else if (match(lc,"\\.i?nfo$")) {

                    nfo=currentFolder"/"scan_line;
                    g_fldrInfoCount[currentFolder]++;
                    g_fldrInfoName[currentFolder]=nfo;
                    g_file_date[nfo] = calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW);

                }

                if (store) {
                    ts=calcTimestamp(lsMonth,lsDate,lsTimeOrYear,NOW);

                    #Process previous details
                    identify_and_catalog(minfo,qfile,0,person_extid2name);

                    #start storing current details - may be updated by multipart info
                    storeMovie(minfo,scan_line,currentFolder,ts,files_in_db)
                    # calc size this will be wrong for folders.
                    minfo["mi_mb"] = int(w5/1024/1024+0.5); 
                    # set nfo according to first part.
                    setNfo(minfo,extRe,".nfo");
                }
            }
        }

    }

    close(tempFile);

    total += identify_and_catalog(minfo,qfile,1,person_extid2name);

    DEBUG("Finished Scanning "root);
    return 0+total;
}

function check_local_image(minfo,field,folder,file,name,suffix,\
ext,extno,i,j,is_dvd,path,imgname,ipath,n1,n2) {
    if (minfo[field] == "") {
        extno=split("jpg,png,JPG,PNG",ext,",");

        is_dvd = isDvdDir(file);
        path = clean_path(folder"/"file);

        for(i = 1 ; i<= extno ; i++ ) {

            n1 = name"."ext[i]; #eg cover.png
            n2 = suffix"."ext[i]; # eg movie-fanart.png

            if (is_dvd) {
                imgname[1]=file"/"n1;
                imgname[2]=file"/"substr(file,1,length(file)-1) n2;
            } else {
                imgname[1]=name"."ext[i]; #eg cover.png
                imgname[2]=gensub(/\.[[:alnum:]]{2,4}$/,n2,1,file); # eg movie-fanart.png
            }

            for(j in imgname) {
                ipath = clean_path(folder"/"imgname[j]);
                if (ipath != path) {
                    if (is_file(ipath)) {
                        minfo[field] = ipath;
                        minfo[field"_source"] = "local";
                        INF("got image path "ipath);
                        return 1;
                    #} else {
                    #    INF("no image path "ipath);
                    }
                }
            }
        }
    }
    return 0;
}

function check_local_images(minfo,folder,file) {
    check_local_image(minfo,"mi_poster",folder,file,"poster","");
    check_local_image(minfo,"mi_fanart",folder,file,"fanart",".fanart");
}

function storeMovie(minfo,file,folder,timeStamp,files_in_db,\
path) {

    path=clean_path(folder"/"file);

    g_fldrMediaCount[folder]++;

    minfo["mi_folder"]=folder;
    minfo["mi_media"] = file;
    minfo["mi_file_time"] = timeStamp;

    gMovieFileCount++;
    if (NEWSCAN && in_list(path,files_in_db) ) {
        DEBUG(" | \t" file);
    } else {
        minfo["mi_do_scrape"]=1;
          INF(" ++\t" file);
        check_local_images(minfo,folder,file);
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
        if (tolower(substr(lastNameSeen,1,i)) ~ "([0-9][.edx]|dvd|disc|ep|episode|vol(\\.?|ume)) *1$") {
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

    INF("Found multi part file - linked "name" with "lastNameSeen);
    minfo["mi_parts"] = (minfo["mi_parts"] =="" ? "" : minfo["mi_parts"]"/" ) name;
    minfo["mi_multipart_tag_pos"] = i;
    return 1;
}

# set the nfo file by replacing the pattern with the given text.
function setNfo(minfo,pattern,replace,\
nfo,lcNfo) {
    nfo = minfo["mi_media"];
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
            dump(0,"folder count",g_fldrCount);
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

function identify_and_catalog(minfo,qfile,force_merge,person_extid2name,\
file,fldr,bestUrl,scanNfo,thisTime,eta,\
total,local_search,\
cat,minfo2,locales,id) {

    if (("mi_do_scrape" in minfo) && minfo["mi_media"] != "" ) {
       
        DIV0("Start item "(g_item_count)": ["minfo["mi_media"]"]");

        if (verify(minfo)) {

            id1("identify_and_catalog "minfo["mi_folder"]"/"minfo["mi_media"]);

            if (!minfo["mi_title"]) {
                minfo["mi_title"] = clean_title(remove_format_tags(minfo["mi_media"]));
                minfo["mi_title_source"] = "filename";
            }

            eta="";
       
        #dep#        begin_search("");

            bestUrl="";

            scanNfo=0;

            file=minfo["mi_media"];
            fldr=minfo["mi_folder"];

            if (file) {

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
                        if (read_xbmc_nfo(minfo,minfo["mi_nfo_default"])) {
                            bestUrl = extractImdbLink(minfo["mi_id"]);
                        }
                        if (!bestUrl) {
                           bestUrl = scanNfoForImdbLink(minfo["mi_nfo_default"]);
                       }
                    }

                    if (minfo["mi_id"] == -1 ) {
                        # dont scrape
                        INF("using xbmc nfo only for "minfo["mi_media"]);

                    } else {

                        # scrape

                        if (bestUrl == "") {
                            # scan filename for imdb link
                            bestUrl = extractImdbLink(file,1);
                            if (bestUrl) {
                                INF("extract imdb id from "file);
                            }
                        }

                        cat="";

                        if (bestUrl) {
                            cat = get_imdb_info(bestUrl,minfo);
                        }

                        if (cat == "T" ) {

                            # Its definitely a series according to IMDB or NFO
                            # get the episode info
                            hash_copy(minfo2,minfo);
                            checkTvFilenameFormat(minfo2,"",0);
                            minfo["mi_season"] = minfo2["mi_season"];
                            minfo["mi_episode"] = minfo2["mi_episode"];
                            minfo["mi_additional_info"] = minfo2["mi_additional_info"];

                            cat = tv_search_simple(minfo,bestUrl,1);

                        } else if (cat != "M" ) {

                            # Not sure - try a TV search looking for various abbreviations.
                            cat = tv_search_complex(minfo,bestUrl,0);

                            if (cat != "T") {
                                # Could not find any hits using tv abbreviations, try heuristis for a movie search.
                                # This involves searching web for imdb id.
                                bestUrl = movie_search(minfo,bestUrl);
                                if (bestUrl) {
                                    cat = get_imdb_info(bestUrl,minfo);

                                    if (cat == "T") {
                                        # If we get here we found an IMDB id , but it looks like a TV show after all.
                                        # This may happen with mini-series that do not have normal naming conventions etc.
                                        # At this point we should have scraped a better title from IMDB so try a simple TV search again.
                                        cat = tv_search_simple(minfo,bestUrl,1);
                                    }
                                }
                            }
                        }

                        if (cat == "M") {
                            id = extractImdbId(bestUrl);
                            get_themoviedb_info(id,minfo);
                            # Only get IMDB connections if we havent got tmdb one and we have not visited tmdb
                            if (minfo["mi_set"] == "" && index(minfo["mi_idlist"],"themoviedb") == 0) {
                                imdb_movie_connections(minfo);
                            }
                            getNiceMoviePosters(minfo);

                           local_search=0;

                           if (main_lang() != "en") {
                               if ( lang(minfo["mi_plot"]) != main_lang()) {
                                   INF("Plot not in main language");
                                   if (g_settings["catalog_extended_local_plot_search"] == 1 ) {
                                       INF("Forcing local search for plot");
                                       local_search = 1;
                                   }
                               }
                               if (gPriority["mi_poster","local"] > minfo_field_priority(minfo,"mi_poster")) {
                                   if (g_settings["catalog_get_local_posters"] != "never") {
                                       INF("Checking local posters");
                                       local_search = 1;
                                   }
                               }
                           }

                           if (local_search) {
                                # We know it is a movie but still do not have good localised info
                                get_locales(locales);
                                find_movie_by_locale(locales[1],"",minfo["mi_title"],minfo["mi_year"],"",minfo["mi_poster"],minfo,id,minfo["mi_orig_title"]);
                            }
                        }


                        if (cat == "") {

                            WARNING("Unknown item "minfo["mi_media"]);

                        } else {

                            fixTitles(minfo);

                            relocate_files(minfo);

                            if (g_opt_dry_run) {
                                print "dryrun: "minfo["mi_file"]" -> "minfo["mi_title"];
                            }
                            #lang_test(minfo);
                        }
                    }
                    g_total ++;
                    g_batch_total++;

                    set_videosource(minfo);
                    set_av_details(minfo);

                    queue_minfo(minfo,qfile,person_extid2name);

                    thisTime = systime()-thisTime ;
                    if (g_total) {
                        DEBUG(sprintf("processed in "thisTime"s net av:%.1f gross av:%.1f [%s]",\
                                 (g_process_time/g_total),(g_elapsed_time/g_total),minfo["mi_media"]));
                    }
                    g_process_time += thisTime;
                    g_elapsed_time = systime() - g_start_time;

                }
            }

            id0();
        }
    }

    close(qfile);

    if ((force_merge && g_batch_total) ||  g_batch_total == g_batch_size ) {

            if (g_db) {
                total +=  merge_queue(qfile,person_extid2name);
            }
            g_batch_total = 0;
    }
    delete minfo;
    return total;

}
function plot_in_main_lang(minfo) {
    return lang(minfo["mi_plot"]) == main_lang();
}
function get_images(minfo) {
    #Only get posters if catalog is installed as part of oversight
    if (!scanner_only()) {

        if (GET_POSTERS) {
            minfo["mi_poster"] = download_image(POSTER,minfo,"mi_poster");
        }

        if (GET_FANART) {
            minfo["mi_fanart"] = download_image(FANART,minfo,"mi_fanart");
        }
    }
}

# INPUT minfo - scraped information
# INPUT qfile - name of queuefile
# OUTPUT person_extid2name - hash of domain:role:extid to name eg imdb:actor:nm000123 => Joe Blogs
function queue_minfo_old(minfo,qfile,person_extid2name,\
row,people) {

    people = person_add_db_queue(minfo,person_extid2name);

    row = createIndexRow(minfo,-1,0,0,"");

    row = row people;

    print row >> qfile;

    INF("queued ["row"] to ["qfile"]");
    queue_plots(minfo,g_plot_file_queue);


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

    scrape_cache_clear();

    clear_tv_folder_info();

    # unique by file - clean when changing folder.
    delete g_file_date; 

    gMovieFileCount = 0;
    #DEBUG("Reset scanned files store");
}


