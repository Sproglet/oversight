function read_xbmc_nfo(minfo,file,\
xml,empty_filter,minfo2,\
num,tags,i,tmp,ret) {

    ret = 0;
    if (readXML(file,xml,""))  {
        dumpxml("nfoxml",xml);
        if ("/movie" in xml) {
            if ("/movie/id" in xml ) {
                minfo2["mi_id"] = xml["/movie/id"];
                if ("X"minfo["mi_id"] == "X0" ) minfo["mi_id"] = -1;

                if (minfo2["mi_id"] ~ "^tt[0-9]+" ) {

                    minfo_set_id("imdb",minfo2["mi_id"],minfo2);
                }
            }
            minfo2["mi_title"] = xml["/movie/title"];
            minfo2["mi_orig_title"] = xml["/movie/originaltitle"];
            minfo2["mi_rating"] = xml["/movie/rating"];
            minfo2["mi_year"] = xml["/movie/year"];
            minfo2["mi_plot"] = xml["/movie/plot"];
            minfo2["mi_runtime"] = xml["/movie/runtime"];
            minfo2["mi_poster"] = xml["/movie/thumb"];
            minfo2["mi_fanart"] = xml["/movie/fanart"];
            minfo2["mi_category"] = "M";
            num = find_elements(xml,"/movie/genre",empty_filter,0,tags);
            if (num) {
                for(i = 1 ; i <= num ; i++ ) {
                    tmp = tmp "|"tags[i];
                }
                minfo2["mi_genre"] = substr(tmp,2);
            }

            #TODO add writer , director and actor parsing.
            #TODO add codec parsing

            minfo_merge(minfo,minfo2,"@nfo");
            ret = 1;
        } else if ( "/xml/tvshow" in xml ) {
            INF("tvshow xbmc not supported yet...");
            minfo2["mi_category"] = "T";
        } else if ( "/tvshow" in xml ) {
            INF("tvshow xbmc not supported yet...");
            minfo2["mi_category"] = "T";
        }

        # next load into minfo2 then minfo_merge with source = @nfo then set best_score to prioritise nfo and short circuit searching.

    } else {
        INF("Non XML nfo - "file);
    }
    return ret;
}

#returns imdb url
function scanNfoForImdbLink(nfoFile,\
foundId,line) {

    foundId="";
    INF("scanNfoForImdbLink ["nfoFile"]");

    if (system("test -f "qa(nfoFile)) == 0) {
        FS="\n";
        while(foundId=="" && (getline line < nfoFile) > 0 ) {

            foundId = extractImdbLink(line,1);

        }
        close(nfoFile);
    }
    INF("scanNfoForImdbLink = ["foundId"]");
    return foundId;
}
#Write a .nfo file if one didnt exist. This will make it easier 
#to rebuild the DB_ARR at a later date. Esp if the file names are no
#longer appearing in searches.
function generate_nfo_file(nfoFormat,dbrow,\
movie,tvshow,nfo,dbOne,fieldName,fieldId,nfoAdded,episodedetails) {

    nfoAdded=0;
    if (g_settings["catalog_nfo_write"] == "never" ) {
        return;
    }
    parseDbRow(dbrow,dbOne,1);
    get_name_dir_fields(dbOne);

    if (dbOne[NFO] == "" ) return;

    nfo=getPath(dbOne[NFO],dbOne[DIR]);


    if (is_file(nfo) && g_settings["catalog_nfo_write"] != "overwrite" ) {
        DEBUG("nfo already exists - skip writing");
        return;
    }
    
    if (nfoFormat == "xmbc" ) {
        movie=","TITLE","ORIG_TITLE","RATING","YEAR","DIRECTORS","PLOT","POSTER","FANART","CERT","WATCHED","IMDBID","FILE","GENRE",";
        tvshow=","TITLE","URL","RATING","PLOT","GENRE","POSTER","FANART",";
        episodedetails=","EPTITLE","SEASON","EPISODE","AIRDATE",";
    }


    if (nfo != "" && !is_file(nfo)) {

        #sub(/[nN][Ff][Oo]$/,g_settings["catalog_nfo_extension"],nfo);

        DEBUG("Creating ["nfoFormat"] "nfo);

        if (nfoFormat == "xmbc") {
            if (dbOne[CATEGORY] =="M") {

                if (dbOne[URL] != "") {
                    dbOne[IMDBID] = extractImdbId(dbOne[URL]);
                }

                startXmbcNfo(nfo);
                writeXmbcTag(dbOne,"movie",movie,nfo);
                nfoAdded=1;

            } else if (dbOne[CATEGORY] == "T") {

                startXmbcNfo(nfo);
                writeXmbcTag(dbOne,"tvshow",tvshow,nfo);
                writeXmbcTag(dbOne,"episodedetails",episodedetails,nfo);
                nfoAdded=1;
            }
        } else {
            #Flat
            print "#Auto Generated NFO" > nfo;
            for (fieldId in dbOne) {
                if (dbOne[fieldId] != "") {
                    fieldName=g_db_field_name[fieldId];
                    if (fieldName != "") {
                        print fieldName"\t: "dbOne[fieldId] > nfo;
                    }
                }
            }
            nfoAdded=1;
        }
    }
    if(nfoAdded) {
        close(nfo);
        set_permissions(qa(nfo));
    }
}

function startXmbcNfo(nfo) {
    print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > nfo;
    print "<!-- #Auto Generated NFO by catalog.sh -->" > nfo;
}
#dbOne = single row of index.db
function writeXmbcTag(dbOne,tag,children,nfo,\
fieldId,text,attr,childTag) {
    print "<"tag">" > nfo;

    #Define any additional tag attributes here.
    attr["movie","id"]="moviedb=\"imdb\"";

    for (fieldId in dbOne) {

        text=dbOne[fieldId];

        if (text != "") {
            if (index(children,fieldId)) {
                childTag=gDbFieldId2Tag[fieldId];
                if (childTag != "") {
                    if (childTag == "thumb") {
#                       if (g_settings["catalog_poster_location"] == "with_media" ) {
#                            #print "\t<"childTag">file://"dbOne[DIR]"/"text"</"childTag">" > nfo;
#                            print "\t<"childTag">file://./"xmlEscape(text)"</"childTag">" > nfo;
#                        } else {
                            print "\t<!-- Poster location not exported catalog_poster_location="g_settings["catalog_poster_location"]" -->" > nfo;
                            print "\t<"childTag">"xmlEscape(text)"</"childTag">" > nfo;
#                        }
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

