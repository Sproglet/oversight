BEGIN {
    g_nfo_comment = "<!-- #Auto Generated NFO by catalog.sh -->";
    g_nfo_encoding = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>";
}

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

function nfo_xml_define() {
    if (!(1 in g_tag_movie)) {

        split(TITLE","ORIG_TITLE","RATING","YEAR","DIRECTORS","PLOT","SET","POSTER","FANART","CERT","WATCHED","IMDBID","FILE","GENRE,g_tag_movie,",");
        hash_invert(g_tag_movie,g_tag_movie);

        split(TITLE","IDLIST","RATING","PLOT","GENRE","POSTER","FANART,g_tag_tvshow,",");
        hash_invert(g_tag_tvshow,g_tag_tvshow);

        split(EPTITLE","SEASON","EPISODE","AIRDATE","EPPLOT,g_tag_episodes,",");
        hash_invert(g_tag_episodes,g_tag_episodes);
    }
}

#do_export - if set then all nfos are dumped into a single export file.
function generate_nfo_file_from_fields(nfoFormat,fields,do_export,write_tv_block,\
nfo,fieldName,fieldId,nfoAdded,nfofilename,tvnfo) {

    nfoAdded=0;
    get_name_dir_fields(fields);

    nfofilename=getPath(fields[NFO],fields[DIR]);
    if (do_export ) {
        nfo = gExportFile;
        tvnfo = gExportFile;
    } else {

        if (fields[NFO] == "" ) {
            INF("No NFO name - skip writing");
            return;
        }

        nfo=nfofilename;


        if (!overwrite_nfo(nfo)) {
            return;
        }
        tvnfo=getPath("tvshow.nfo",fields[DIR]);
        if (write_tv_block) {
            write_tv_block = overwrite_nfo(tvnfo);
        }
    }
    
    id1("generate_nfo_file_from_fields "nfofilename);
    if (nfoFormat == "xmbc" ) {
        nfo_xml_define();
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

                writeXmbcTag(fields,"movie",g_tag_movie,nfo);

            } else if (fields[CATEGORY] == "T") {

                if (write_tv_block) {
                    writeXmbcTag(fields,"tvshow",g_tag_tvshow,tvnfo);
                }
                writeXmbcTag(fields,"episodedetails",g_tag_episodes,nfo);
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

function overwrite_nfo(nfo,\
line,set,code,ret,i,is_xml,is_generated) {

    set = g_settings["catalog_nfo_write"] ;
    if (set == "always" ) {
        ret = 1;
    } else if (set == "never" ) {
        ret = 0;
    } else {
        if (!is_file(nfo)) {
            ret = 1;
        } else {
            # check if file is XML or was generated by catalog.sh
            for(i = 1 ; i <= 2 ; i++ ) {
                code = ( getline line < nfo );
                if (line ~ /(<\?xml|<[a-z]+>)/ ) is_xml=1;
                if (index(line,g_nfo_comment)) is_generated = 1;
            }
            if (code >= 0) close(nfo);
            ret = is_generated;
            # could also overwrite non-xml nfos | !is_xml?
        }
        INF("overwrite nfo = "ret" - "nfo);
    }
    return ret;
}

function start_xml(f) {
    print g_nfo_encoding >> f;
    print g_nfo_comment >> f
}

function startExport(nfo) {
    start_xml(nfo);
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
        start_xml(nfo);
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
fieldId,text,attr,childTag,lang) {
    print "<"tag">" >> nfo;

    #Define any additional tag attributes here.
    attr["movie","id"]=" moviedb=\"imdb\"";

    for (fieldId in dbOne) {

        if (fieldId in children) {
            childTag=gDbFieldId2Tag[fieldId];
            if (childTag != "") {
                text=to_string(fieldId,dbOne[fieldId]);

                if (text != "") {
                    if (childTag == "watched" ) {

                        text=((text==1)?"true":"false");

                    } else if (childTag == "plot" && text ~ /^[a-z]{2}:/ ) {
                       lang=substr(text,1,2);
                       text=substr(text,4);
                       # uncomment following line to add langage attribute to plot.
                       #attr[tag,childTag] = attr[tag,childTag]" language=\""lang"\"";
                    }

                    print "\t<"childTag attr[tag,childTag]">"xmlEscape(text)"</"childTag">" >> nfo;
                }
            } else {
                ERR("undefined tag for field "fieldId);
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
