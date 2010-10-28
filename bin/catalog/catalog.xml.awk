
#Load an xml file into array - note duplicate elements are clobbered.
#To parse xml with duplicate lements call parseXML in a loop and trigger on index(line,"</tag>")
function fetchXML(url,label,xml,ignorePaths,\
f,line,result) {
    result = 0;
    f=getUrl(url,label,1);
    if (f != "" ) {
        FS="\n";
        while((getline line < f) > 0 ) {
            parseXML(line,xml,ignorePaths);
        }
        close(f);
        result = 1;
    }
    return 0+ result;
}

#Parse flat XML into an array - does NOT clear xml array as it is used in fetchXML
# @ignorePaths = csv of paths to ignore
#sep is used if merging repeated element values together
function parseXML(line,info,ignorePaths,\
sep,\
currentTag,oldTag,i,j,tag,text,parts,sp,slash,tag_data_count,\
attr,attrnum,attrname,attr_parts,single_tag,taglen) {

    if (index(line,"<?")) return;

    sep = "<";

    if (ignorePaths != "") {
        gsub(/,/,"|",ignorePaths);
        ignorePaths = "^("ignorePaths")\\>";
    }

    if (index(line,g_sigma) ) { 
        INF("Sigma:"line);
        gsub(g_sigma,"e",line);
        INF("Sigma:"line);
    }

    #break at each tag/endtag
    # <tag1>text1</tag1>midtext<tag2>text2</tag2> becomes
    # BLANK
    # tag1>text1
    # /tag1>midtext
    # tag2>text2
    # /tag2>
    #
    # <tag1><tag2 /></tag1> becomes
    # tag1>
    # tag2 />
    # /tag1> 


    tag_data_count = split(line,parts,"[<>]");

    currentTag = info["@CURRENT"];

    for(i = 1 ; i <= tag_data_count ; i++ ) {

        if (i == tag_data_count) {
            if (index(parts[i],"\r") || index(parts[i],"\n")) {
                sub(/[\r\n]+$/,"",parts[i]);
            }
        }

        # process the text node ---------------

        text = parts[i];
        if (currentTag ) {
            if (ignorePaths == "" || currentTag !~ ignorePaths) {
                #If merging element values add a sepearator
                if (currentTag in info) {
                    text = sep text;
                }
                info[currentTag] = info[currentTag] text;
            }
        }

        # Move on to process the tag ---------------

        i++;
        tag = parts[i];
        taglen = length(tag);

        # part[1] = tag 
        # part[1] = tag attr1
        # part[1] = tag attr1 /
        # part[1] = /tag
        # part[2] = text


        single_tag = 0;

        slash = index(tag,"/");
        if (slash == 1 )  {

            # /tag

            #currentTag = substr(currentTag,1,length(currentTag)-taglen);
            sub("/[^/]+$","",currentTag);

        } else {

            # part[1] = tag 
            # part[1] = tag attr1
            # part[1] = tag attr1 /

            # check for empty tag.
            if ( slash == taglen || substr(tag,taglen) == "/") {
                #tag has no data element.
                # Check appears more complex in case attribute contains slash.
                single_tag = 1;

            }

            if ((sp=index(tag," ")) != 0) {
                #Remove attributes Possible bug if space before element name
                tag=substr(tag,1,sp-1);
            }

            oldTag = currentTag;
            currentTag = currentTag "/" tag;
            if (currentTag in info) {
                for(j=2; ( (currentTag"@"j) in info ) ; j++ ) ;
                currentTag = currentTag "@" j;
            }
        }

        #parse attributes.
        
        if (index(parts[i],"=")) {
            attr=gensub(/([:A-Za-z_][-_:A-Za-z0-9.]+)=("([^"]*)"|([^"][^ "'>=]*))/,SUBSEP"\\1"SUBSEP"\\3\\4"SUBSEP,"g",parts[i]);
            attrnum = split(attr,attr_parts,SUBSEP);
            for(attr = 2 ; attr <= attrnum ; attr += 3 ) {
                attrname=currentTag"#"attr_parts[attr];
                if (attrname in info) {
                    info[attrname]=info[attrname] sep attr_parts[attr+1];
                } else {
                    info[attrname]=attr_parts[attr+1];
                }
            }
        }
        if (single_tag) {
            currentTag = oldTag;
        }
    }

    info["@CURRENT"] = currentTag;
}
function clean_xml_path(xmlpath,xml,\
t,xmlpathSlash,xmlpathHash) {

    #This is the proper way to remove the element
    #delete the current child - its slow
    xmlpathSlash=xmlpath"/";
    xmlpathHash=xmlpath"#";

#DEBUG("@@ clean_xml_path ["xmlpath"]");

    #index function is faster than substr
    for(t in xml) {
        if (index(t,xmlpath) == 1) {
            if (t == xmlpath || index(t,xmlpathSlash) == 1 || index(t,xmlpathHash) == 1) {
                delete xml[t];
            }
        }
    }
}

# certain paths can be ignored to reduce memory footprint.
function fetch_xml_single_child(url,filelabel,xmlpath,tagfilters,xmlout,ignorePaths,\
f,found) {

   f = getUrl(url,filelabel,1);
   id1("fetch_xml_single_child ["url"] path = "xmlpath);
   found =  scan_xml_single_child(f,xmlpath,tagfilters,xmlout,ignorePaths);
   id0(found);
   return 0+ found;
}

# split the filter list into numbers , strings and regexs
function reset_filters(tagfilters,numbers,strings,regexs,\
t) {
   for(t in tagfilters) {
       DEBUG("filter ["t"]=["tagfilters[t]"]");

       if (tagfilters[t] ~ "^[0-9]+$" ) {
           numbers[t] = tagfilters[t];

       } else if (substr(tagfilters[t],1,2) == "~:") {

           regexs[t] = tolower(substr(tagfilters[t],3));

       } else {

           strings[t] = tagfilters[t];

       }
   }
}

# certain paths can be ignored to reduce memory footprint.
function scan_xml_single_child(f,xmlpath,tagfilters,xmlout,ignorePaths,\
numbers,strings,regexs,\
line,start_tag,end_tag,found,t,last_tag,number_type,regex_type,string_type) {

   delete xmlout;
   found=0;

   number_type=1;
   regex_type=2;
   string_type=3;

   last_tag = xmlpath;
   sub(/.*\//,"",last_tag);

   start_tag="<"last_tag">";
   end_tag="</"last_tag">";

   reset_filters(tagfilters,numbers,strings,regexs);

   dump(0,"numbers",numbers);
   dump(0,"strings",strings);
   dump(0,"regexs",regexs);


    if (f != "") {
        FS="\n";

        while((getline line < f) > 0 ) {


            if (index(line,start_tag) > 0) {
                # start of new child we are interested in. Clear all existing
                # child info. But keep parent info.
                clean_xml_path(xmlpath,xmlout);
            }


            parseXML(line,xmlout,ignorePaths);

            if (index(line,end_tag) > 0) {

                found=1;

                for(t in numbers) {
                    if (!(t in xmlout) || (xmlout[t] - numbers[t] != 0) ) {
                        found =0 ; break;
                    }
                }
                for(t in strings) {
                    if (!(t in xmlout) || (xmlout[t]"" != strings[t] ) ) {
                        found =0 ; break;
                    }
                }
                for(t in regexs) {
                    if (!(t in xmlout) || (tolower(xmlout[t]) !~ regexs[t] ) ) {
                        found =0 ; break;
                    }
                }

                if (found) {
                    DEBUG("Filter matched.");
                    break;
                }

            }

        }
        close(f);
    }
    if (!found) {
        clean_xml_path(xmlpath,xmlout);
    }
    return 0+ found;
}
