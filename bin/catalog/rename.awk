
## UNUSED
function relocating_files(minfo) {
    return (RENAME_TV == 1 && minfo[CATEGORY] == "T") ||(RENAME_FILM==1 && minfo[CATEGORY] == "M");
}

# Pad episode required for multiple episodes.
# re-instated. Escape was required to resolve.

function pad_episode(e) {
    gsub(/\<[0-9][a-d]?\>/,"0&",e);
    return e;
}

function relocate_files(minfo,\
newName,oldName,oldFolder,newFolder,fileType,epTitle) {

   if(LG)DEBUG("relocate_files");

    newName="";
    oldName="";
    fileType="";
    if (RENAME_TV == 1 && minfo[CATEGORY] == "T") {

        oldName=minfo[DIR]"/"minfo[NAME];
        newName=g_settings["catalog_tv_file_fmt"];
        newName = substitute("SEASON",minfo[SEASON],newName);
        newName = substitute("EPISODE",minfo[EPISODE],newName);
        newName = substitute("DETAIL",minfo[ADDITIONAL_INF],newName);

        epTitle=minfo[EPTITLE];
        gsub("[^-" g_alnum8 ",. ]","",epTitle);
        gsub(/[{]EPTITLE[}]/,epTitle,newName);

        newName = substitute("EPTITLE",epTitle,newName);
        newName = substitute("0SEASON",sprintf("%02d",minfo[SEASON]),newName);
        newName = substitute("0EPISODE",pad_episode(minfo[EPISODE]),newName);


        fileType="file";

    } else if (RENAME_FILM==1 && minfo[CATEGORY] == "M") {

        oldName=minfo[DIR];
        newName=g_settings["catalog_film_folder_fmt"];
        fileType="folder";

    } else {
        return;
    }
    # TODO there seems to be a bug here. Why are following settings only applied
    # if name has changed at this point ?
    if (newName != "" && newName != oldName) {

        oldFolder=minfo[DIR];

        if (fileType == "file") {
            newName = substitute("NAME",minfo[NAME],newName);
            if (match(minfo[NAME],"[.][^.]+$")) {
                #if(LG)DEBUG("BASE EXT="minfo[NAME] " AT "RSTART);
                newName = substitute("BASE",substr(minfo[NAME],1,RSTART-1),newName);
                newName = substitute("EXT",substr(minfo[NAME],RSTART),newName);
            } else {
                #if(LG)DEBUG("BASE EXT="minfo[NAME] "]");
                newName = substitute("BASE",minfo[NAME],newName);
                newName = substitute("EXT","",newName);
            }
        }
        newName = substitute("DIR",minfo[DIR],newName);


        if (minfo[ORIG_TITLE]) {
            newName = substitute("ORIG_TITLE",minfo[ORIG_TITLE],newName);
        } else {
            newName = substitute("ORIG_TITLE",minfo[TITLE],newName);
        }
        newName = substitute("TITLE",minfo[TITLE],newName);
        newName = substitute("YEAR",minfo[YEAR],newName);
        newName = substitute("CERT",minfo["mi_certrating"],newName);
        newName = substitute("GENRE",minfo[GENRE],newName);

        #Remove characters windows doesnt like
        gsub(/[\\:*\"<>|]/,"_",newName); #"

        newName = clean_path(newName);

        if (newName != oldName) {
           if (fileType == "folder") {
               if (moveFolder(minfo,oldName,newName) != 0) {
                   return;
               }

               minfo[FILE]="";
               minfo[DIR]=newName;
               relocate_nfo(minfo,newName,0);
           } else {

               # Move media file
               if (moveFileIfPresent(oldName,newName) != 0 ) {
                   return;
               }

               g_fldrMediaCount[minfo[DIR]]--;
               minfo[FILE]=newName;

               newFolder=newName;
               sub(/\/[^\/]+$/,"",newFolder);

               #Update new folder location
               minfo[DIR]=newFolder;

               minfo[NAME]=newName;
               sub(/.*\//,"",minfo[NAME]);

               # Move nfo file
               if(LG)DEBUG("Checking nfo file ["minfo[NFO]"]");
               relocate_nfo(minfo,newName,1);


               #Rename any other associated files (sub,idx etc) etc.
               rename_related(oldName,newName);

               #Move everything else from old to new.
               moveFolder(minfo,oldFolder,newFolder);
           }
        }

        if(LD)DETAIL("checking "qa(oldFolder));
        if (is_dir(oldFolder) ) {

            system("rmdir -- "qa(oldFolder)" 2>/dev/null" ); # only remove if empty
        }
        if (g_settings["catalog_touch_parent_folders"]) {
            touch_parents(newFolder);
        }

    } else {
        # Name unchanged
        if (g_opt_dry_run) {
            print "dryrun:\t"newName" unchanged.";
            print "dryrun:";
        } else {
            if(LD)DETAIL("rename:\t"newName" unchanged.");
        }
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
        if(LG)DEBUG("Keyword ["keyword"]=["value"]");
        if(LG)DEBUG("Old path ["oldStr"]");
        if(LG)DEBUG("New path ["str"]");
    }

    return str;
}

function rename_related(oldName,newName,\
    extensions,ext,oldBase,newBase) {
    split(".jpg .png .srt .idx .sub .nfo -fanart.jpg",extensions," ");

    oldBase = oldName;
    sub(/\....?$/,"",oldBase);

    newBase = newName;
    sub(/\....?$/,"",newBase);

    for(ext in extensions) {
        moveFileIfPresent(oldBase extensions[ext],newBase extensions[ext]);
    }

}
function relocate_nfo(minfo,newName,moveit,\
nfoName) {
   if(minfo[NFO] != "") {

       nfoName = newName;
       sub(/\.[^.]+$/,"",nfoName);
       nfoName = nfoName ".nfo";

       if (nfoName != newName ) {

           if (moveit) {
               if (moveFileIfPresent(minfo[NFO],nfoName) != 0) {
                   return;
               }
           }

           g_file_date[nfoName]=g_file_date[minfo[NFO]];
           delete g_file_date[minfo[NFO]];

           minfo[NFO] = nfoName;
           if(LG)DEBUG("new nfo location ["minfo[NFO]"]");
       }
   }
}

function preparePath(f) {
    f = qa(f);
    return system("set +e ; if [ ! -e "f" ] ; then mkdir -p "f" && chown "OVERSIGHT_ID" "f"/.. ;  rmdir -- "f" ; fi");
}

#This is used to double check we are only manipulating files that meet certain criteria.
#More checks can be added over time. This is to prevent accidental moving of high level files etc.
#esp if the process has to run as root.
function changeable(f) {
    #TODO Expand to include only paths listed in scan list.

    #Check folder depth to avoid nasty accidents.
    if (index(f,"/tmp/") == 1) return 1;
    if (index(f,"/share/tmp/") == 1) return 1;

    if (!match(f,"/[^/]+/[^/]+/")) {
        WARNING("Changing ["f"] might be risky. please make manual changes");
        return 0;
    }
    return 1;
}

# 0 = OK or absent 1=BAD
function moveFileIfPresent(oldName,newName) {

    if (is_file(oldName)) {
        return moveFile(oldName,newName);
    } else {
        return 0;
    }
}

# 0 = OK 1=BAD or missing
function moveFile(oldName,newName,\
    new,old,ret) {

    if (changeable(oldName) == 0 ) {
        return 1;
    }
    new=qa(newName);
    old=qa(oldName);
    if (g_opt_dry_run) {
        if (match(oldName,gExtRegExAll) && is_file(oldName)) {
            print "dryrun: from "old" to "new;
        }
        return 0;
    } else {
    # if(LD)DETAIL("move file:\t"old" --> "new);
        if ((ret=preparePath(newName)) == 0) {
            ret = exec("mv "old" "new);
        }
       return 0+ ret;
   }
}

#Moves folder contents.
function moveFolder(minfo,oldName,newName,\
    ret,err) {

   ret=1;
   err = "unknown error";

   if (folderIsRelevant(oldName) == 0) {

       err="not listed in the arguments";

   } else if ((!isDvdDir(minfo[NAME]) &&  g_fldrCount[oldName] > 1) || g_fldrCount[oldName] > 2 ) {

       err= g_fldrCount[oldName]" sub folders";

   } else if (g_fldrMediaCount[oldName] - 1 > 0) {

       err = g_fldrMediaCount[oldName]" media files";

   } else if (changeable(oldName) == 0 ) {

       err="un changable folder";

   } else {

       ret = movFolder2(oldName,newName);

   }
   if (ret != 0) {
       WARNING("folder contents ["oldName"] not renamed to ["newName"] : "err);
   }
   return 0+ ret;
}

function movFolder2(oldName,newName,\
old,new,cmd,ret) {
       new=qa(newName);
       old=qa(oldName);
       if (g_opt_dry_run) { 
           print "dryrun: from "old"/* to "new"/";
           ret = 0;
       } else if (is_empty(oldName) == 0) {
            if(LD)DETAIL("move folder:"old"/* --> "new"/");
           # Seems to be a bug on dns323 where globbing fails of the path is too long. 
           # Havent fully isolated but resolved by replacing "mv /path/* " with "( cd /path ; mv * )"
           cmd= " mkdir -p "new" ; ( cd "old" ; mv * .?* "new" || true ) ; rmdir "old" 2>/dev/null";
           ret = exec(cmd);
       }
       return ret;
}
