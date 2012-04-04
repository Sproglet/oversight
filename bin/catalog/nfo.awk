function read_xbmc_nfo(minfo,file,\
xml,empty_filter,minfo2,\
num,tags,i,tmp,ret,id) {

    ret = 0;
    if (readXML(file,xml,""))  {
        dumpxml("nfoxml",xml);
        if ("/movie" in xml) {
            if ("/movie/id" in xml ) {
                id = xml["/movie/id"];
                if ("X"id == "X0" ) id = -1;

                if (id ~ "^tt[0-9]+" ) {
                    minfo_set_id("imdb",id,minfo2);
                } else {
                    minfo_set_id("@nfo",id,minfo2);
                }
            }
            minfo2[TITLE] = xml["/movie/title"];
            minfo2[ORIG_TITLE] = xml["/movie/originaltitle"];
            minfo2[RATING] = xml["/movie/rating"];
            minfo2[YEAR] = xml["/movie/year"];
            minfo2[PLOT] = xml["/movie/plot"];
            minfo2[RUNTIME] = xml["/movie/runtime"];
            minfo2[POSTER] = xml["/movie/thumb"];
            minfo2[FANART] = xml["/movie/fanart"];
            minfo2[CATEGORY] = "M";
            num = find_elements(xml,"/movie/genre",empty_filter,0,tags);
            if (num) {
                for(i = 1 ; i <= num ; i++ ) {
                    tmp = tmp "|"xml[tags[i]];
                }
                minfo2[GENRE] = substr(tmp,2);
            }

            #TODO add writer , director and actor parsing.
            #TODO add codec parsing

            minfo_merge(minfo,minfo2,"@nfo");
            ret = 1;
        } else if ( "/xml/tvshow" in xml ) {
            INF("tvshow xbmc not supported yet...");
            minfo2[CATEGORY] = "T";
        } else if ( "/tvshow" in xml ) {
            INF("tvshow xbmc not supported yet...");
            minfo2[CATEGORY] = "T";
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
fields) {
    parseDbRow(dbrow,fields,1);
    return generate_nfo_file_from_fields(nfoFormat,fields,0,1);
}

#do_export - if set then all nfos are dumped into a single export file.
function generate_nfo_file_from_fields(nfoFormat,fields,do_export,write_tv_block,\
movie,tvshow,nfo,fieldName,fieldId,nfoAdded,episodedetails,nfofilename) {

    nfoAdded=0;
    get_name_dir_fields(fields);

    nfofilename=getPath(fields[NFO],fields[DIR]);
    if (do_export ) {
        nfo = gExportFile;
    } else {

        if (g_settings["catalog_nfo_write"] == "never" ) {
            return;
        }

        if (fields[NFO] == "" ) {
            INF("No NFO name - skip writing");
            return;
        }
        nfo=nfofilename;


        if (is_file(nfo) && g_settings["catalog_nfo_write"] != "overwrite" ) {
            INF("nfo already exists - skip writing");
            return;
        }
    }
    
    id1("generate_nfo_file_from_fields "nfofilename);
    if (nfoFormat == "xmbc" ) {
        split(TITLE","ORIG_TITLE","RATING","YEAR","DIRECTORS","PLOT","SET","POSTER","FANART","CERT","WATCHED","IMDBID","FILE","GENRE,movie,",");
        split(TITLE","IDLIST","RATING","PLOT","GENRE","POSTER","FANART,tvshow,",");
        split(EPTITLE","SEASON","EPISODE","AIRDATE","EPPLOT,episodedetails,",");
    }


    if (nfo != "" ) {

        #sub(/[nN][Ff][Oo]$/,g_settings["catalog_nfo_extension"],nfo);

        DEBUG("Creating ["nfoFormat"] "nfo);

        if (nfoFormat == "xmbc") {

            if (fields[IDLIST] != "") {
                fields[IMDBID] = extractImdbId(fields[IDLIST]);
            }

            startXmbcNfo(nfo,do_export,nfofilename);

            if (fields[CATEGORY] =="M") {

                writeXmbcTag(fields,"movie",movie,nfo);

            } else if (fields[CATEGORY] == "T") {

                if (write_tv_block) {
                    writeXmbcTag(fields,"tvshow",tvshow,nfo);
                }
                writeXmbcTag(fields,"episodedetails",episodedetails,nfo);
            }
            nfoAdded=1;
        } else {
            #Flat
            print "#Auto Generated NFO" >> nfo;
            for (fieldId in fields) {
                if (fields[fieldId] != "") {
                    fieldName=g_db_field_name[fieldId];
                    if (fieldName != "") {
                        print fieldName"\t: "fields[fieldId] >> nfo;
                    }
                }
            }
            nfoAdded=1;
        }
    }
    if(nfoAdded) {

        if (!do_export) {
            endXmbcNfo(nfo,do_export);
        }
        close(nfo);
        if (!do_export) {
            set_permissions(qa(nfo));
        }
    }
    id0();
}

function startExport(nfo) {
    print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > nfo;
    print "<!-- #Auto Generated NFO by catalog.sh -->" >> nfo;
    print "<catalog>" >> nfo;
}
function endExport(nfo) {
    print "</catalog>" >> nfo;
}
function startXmbcNfo(nfo,do_export,nfofilename) {
    if (do_export) {
        print "<entry>" >> nfo;
        print "<nfofile>"nfofilename"</nfofile>" >> nfo;
        print "<nfo>" >> nfo;
    } else {
        print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" >> nfo;
        print "<!-- #Auto Generated NFO by catalog.sh -->" >> nfo;
    }
}
function endXmbcNfo(nfo,do_export) {
    if (do_export) {
        print "</nfo>" >> nfo;
        print "</entry>" >> nfo;
    }
}

#dbOne = single row of index.db
function writeXmbcTag(dbOne,tag,children,nfo,\
fieldId,text,attr,childTag) {
    print "<"tag">" >> nfo;

    #Define any additional tag attributes here.
    attr["movie","id"]=" moviedb=\"imdb\"";

    for (fieldId in dbOne) {

        if (fieldId in children) {
            childTag=gDbFieldId2Tag[fieldId];
            if (childTag != "") {
                text=to_string(fieldId,dbOne[fieldId]);

                if (text != "") {
                    if (childTag == "watched" ) text=((text==1)?"true":"false");
                    print "\t<"childTag attr[tag,childTag]">"xmlEscape(text)"</"childTag">" >> nfo;
                }
            }
        }
    }
    print "</"tag">" >> nfo;
}

function export_xml(dbfile,\
    row,fields,write_tv_block,last_url,has_output,dbsorted) {

    gExportFile = "indexdb.xml";
    id1("export_xml");

    # put all tv shows together
    dbsorted = new_capture_file("export");
    sort_index_by_field(IDLIST,dbfile,dbsorted);


    # export.
    startExport(gExportFile);

    while((row=get_dbline(dbsorted)) != "") {
        has_output++;
        parseDbRow(row,fields,1);
	INF(has_output":"fields[IDLIST]);
        # end previous nfo tag if exporting.
        # this is to make sure all tv seasons are together.
	
        if (fields[IDLIST] != last_url ) {
            if (last_url != "" ) {
                endXmbcNfo(gExportFile,1);
            }
            last_url = fields[IDLIST];
            write_tv_block = 1;
        } else {
            write_tv_block = 0;
        }

        generate_nfo_file_from_fields("xmbc",fields,1,write_tv_block);
    }
    if (has_output) {
        endXmbcNfo(gExportFile,1);
    }
    endExport(gExportFile);
    close(gExportFile);
    id0("export_xml "gExportFile);
    system("ls");
}
