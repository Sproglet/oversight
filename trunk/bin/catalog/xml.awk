
#Load an xml file into array - note duplicate elements are clobbered.
#To parse xml with duplicate lements call parseXML in a loop and trigger on index(line,"</tag>")
# RETURN ok=1 failed=0
function fetchXML(url,label,xml,ignorePaths,quiet_fail,\
f,ret,response) {
    if(g_settings["catalog_awk_browser"]) {
        if (url_get(url,response)) {
            ret = parseXML(response["body"],xml,ignorePaths);
        }
    } else {
        f=getUrl(url,label".xml",1,"",quiet_fail);
        ret = readXML(f,xml,ignorePaths);
    }
    DEBUG("fetchXML["url"] = "ret);
    return ret;
}

# RETURN ok=1 failed=0
function readXML(f,xml,ignorePaths,\
line,ret,code) {
    id1("readXML");
    ret = 0;
    delete xml;
    if (f != "" ) {

        FS="\n";
        while((code = enc_getline(f,line)) > 0 )  {
            ret++;
            if (!parseXML(line[1],xml,ignorePaths)) {
                ret = 0;
                break;
            }
        }
        enc_close(f);
    }
    id0(ret);
    return ret;
}

function dumpxml(label,xml,\
i,n,tag,ids,t,val) {
    ids["name"] = ids["id"] = 1;
    n = xml["@count"];
    DEBUG(label":xml");
    for(i = 1 ; i <= n ; i++ ) {
        tag = xml[i];

        val = xml[tag];

        # display all non empty values that either do not have cr or are not blank
        if (val != "" && (!index(val,"\n") || val !~ /^[[:space:]]*/ )) {
            INF(tag" = "xml[tag]);
        }

        for (t in ids) {
            if (tag"#"t in xml) INF(tag"#"t" = "xml[tag"#"t]);
        }
    }
    DEBUG("end:"label":xml");
}

# PArse XML - remove comments before passing to real parser
function parseXML(line,xml,ignorePaths,\
beg,end,ret) {

    if (xml["!"]) {

        # in a comment

        if (match(line,"-->")) line = substr(line,RSTART+3);
        delete xml["!"];

    }

    # TODO hope DOCTYPE is on one line!!
    if ((beg = index(line,"<!DOCTYPE")) > 0) {
       if ((end=index(line,">")) > 0) {
          line = substr(line,1,beg-1) substr(line,end+1);
          beg = end = 0;
      }
    }

    # remove single line comments
    while ((beg=index(line,"<!--")) > 0) {
       if ((end=index(line,"-->")) > 0) {
          line = substr(line,1,beg-1) substr(line,end+3);
          beg = end = 0;
       } else {
          break;
       }
    }

    if (beg) {

        #parse bit before start of comment.
        line = substr(line,1,beg-1);
        ret = parseXML2(line,xml,ignorePaths);
        xml["!"] = 1;

    } else if (!xml["!"]) {

        # not in a comment - parse
        ret = parseXML2(line,xml,ignorePaths);

    } else {
        # line is within a comment
        ret = 1;
    }
    return ret;
}



#Parse flat XML into an array - does NOT clear xml array as it is used in fetchXML
# @ignorePaths = csv of paths to ignore
#sep is used if merging repeated element values together
# ret 1=parsed ok 0=error
function parseXML2(line,xml,ignorePaths,\
sep,\
currentTag,oldTag,i,tag,text,parts,sp,slash,tag_data_count,\
attr,attrnum,attrname,attr_parts,single_tag,taglen,countTag,numtags,ret,dbg,tag_ok) {

    if (line == "") return 1;

    if (index(line,"<?")) {
        line = substr(line,index(line,"?>")+2);
    }

    ret = 1;

    sep = "<";

    if (ignorePaths != "") {
        gsub(/,/,"|",ignorePaths);
        ignorePaths = "^("ignorePaths")\\>";
    }

    if (index(line,g_sigma) ) { 
        gsub(g_sigma,"e",line);
        INF("Sigma replaced");
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

    currentTag = xml["@CURRENT"];
    numtags = xml["@count"];

    if (dbg) DEBUG("xml: start currentTag=["currentTag"] numtags=["numtags"]");
    if (dbg) DEBUG("xml: start tag_data_count=["tag_data_count"] line=["line"]");

    i = 0 ;
    while ( i <= tag_data_count ) {

        if (++i > tag_data_count) break;

        if (i == tag_data_count) {
            # chomp - remove cr/lf
            if (index(parts[i],"\r") || index(parts[i],"\n")) {
                sub(/[\r\n]+$/,"",parts[i]);
            }
        }

        # process the text node ---------------

        text = parts[i];

        if (dbg) DEBUG("xml: XMLtext "i"["text"]");

        if (i == tag_data_count && ( text == "" || (index(text," ") == 1 && trim(text) == "")) ) {
            # ignore trailing blank space
            break;
        }

        if (currentTag ) {
            if (ignorePaths == "" || currentTag !~ ignorePaths) {
                #If merging element values add a seperator
                if (currentTag in xml) {
                    text = " " text;
                }
                xml[currentTag] = xml[currentTag] text;
            }
        } else {
            # No tag yet - check only white space
            if (text !~ "^[[:space:]]*$" ) {
                if (text == "﻿" ) { #XML UTF8 BOM
                    text="";
                } else {
                    ("encountered text outside of xml ["text"]");
                    ret = 0;
                    break;
                }
            }
        }


        # Move on to process the tag ---------------

        if (++i >= tag_data_count) break;

        tag = parts[i];

        if (dbg) DEBUG("xml: XMLtag "i"["tag"]");

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

            if (!(tag in tag_ok)) {
               if (tag !~ /^(|[[:alnum:]]:)[[:alpha:]][_[:alnum:]]*$/ && tag !~ /!/ ) {
                   ERR("XML Parse error: Invalid tag ["tag"]");
                   ret = 0;
                   break;
               } else {
                   tag_ok[tag] = 1;
               }
            }

            oldTag = currentTag;
            currentTag = currentTag "/" tag;


            # If a tag occurs more than once for the same parent we need to keep all values.
            # eg
            # <parent><child>a</child><child b="c"/><parent>
            # should become
            #
            # [parent/child]=ArrayFlag
            # [parent/child>1]a
            # [parent/child>2#b]c
            #
            # Also consider
            # <parent><child><name>n1</name></child><child b="c"/><name>n2</name><parent>
            # in this case <name> should not be an array even though the path /parent/child/name appears twice.
            #
            # [parent/child]=ArrayFlag
            # [parent/child>1/name]n1
            # [parent/child>2#b]c
            # [parent/child>2/name]n2
            #
            countTag = "@count:"currentTag;
            if (countTag in xml) {
               xml[countTag] ++;
               currentTag = currentTag ">" xml[countTag];
                if (dbg) INF("xml: changed currentTag ["currentTag"] tag=["tag"]");
            } else {
                xml[countTag] = 1;
            }
            xml[++numtags] = currentTag;
        }

        #parse attributes.
        
        if (index(parts[i],"=")) {
            #first split a=b c=d into name value array
            attr=gensub(/([:[:alpha:]_][-_:[:alnum:].]+)=("([^"]*)"|([^"][^ "'>=]*))/,SUBSEP"\\1"SUBSEP"\\3\\4"SUBSEP,"g",parts[i]);
            attrnum = split(attr,attr_parts,SUBSEP);
            for(attr = 2 ; attr <= attrnum ; attr += 3 ) {
                attrname=currentTag"#"attr_parts[attr];
                if (attrname in xml) {
                    xml[attrname]=xml[attrname] sep attr_parts[attr+1];
                } else {
                    xml[attrname]=attr_parts[attr+1];
                }
            }
        }

        if (single_tag) {
            # Add tag entry
            xml[currentTag]="";
            currentTag = oldTag;
        }
    }

    if (ret == 0) {
        delete xml;
    }

    xml["@CURRENT"] = currentTag;
    xml["@count"] = numtags;

    if (dbg) DEBUG("xml: end currentTag=["currentTag"] numtags=["numtags"]");

    return ret;
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

   f = getUrl(url,filelabel".xml",1);
   id1("fetch_xml_single_child ["url"] path = "xmlpath);
   found =  scan_xml_single_child(f,xmlpath,tagfilters,xmlout,ignorePaths);
   id0(found);
   return 0+ found;
}

# split the filter list into numbers , strings and regexs
# return number of filters
function reset_filters(tagfilters,numbers,strings,regexs,\
t,ret) {
    ret = 0;
   for(t in tagfilters) {
       DEBUG("filter ["t"]=["tagfilters[t]"]");

       if (tagfilters[t] ~ "^[0-9]+$" ) {
           numbers[t] = tagfilters[t];
           ret++;

       } else if (substr(tagfilters[t],1,2) == "~:") {

           regexs[t] = tolower(substr(tagfilters[t],3));
           ret++;

       } else {

           strings[t] = tagfilters[t];
           ret++;

       }
   }
   dump(0,"numbers",numbers);
   dump(0,"strings",strings);
   dump(0,"regexs",regexs);
   return ret;
}

# certain paths can be ignored to reduce memory footprint.
function scan_xml_single_child(f,xmlpath,tagfilters,xmlout,ignorePaths,\
numbers,strings,regexs,found,\
line,start_tag,end_tag,last_tag,number_type,regex_type,string_type,do_filter) {

   delete xmlout;
   found=0;

   number_type=1;
   regex_type=2;
   string_type=3;

   last_tag = xmlpath;
   sub(/.*\//,"",last_tag);

   start_tag="<"last_tag">";
   end_tag="</"last_tag">";

   do_filter = reset_filters(tagfilters,numbers,strings,regexs);


    if (f != "") {
        FS="\n";

        while(enc_getline(f,line) > 0 ) {

            if (index(line[1],start_tag) > 0) {
                # start of new child we are interested in. Clear all existing
                # child info. But keep parent info.
                clean_xml_path(xmlpath,xmlout);
            }

            if (!parseXML(line[1],xmlout,ignorePaths)) {
                break;
            }

            if (index(line[1],end_tag) > 0) {

                if (do_filter == 0 || check_filtered_element(xmlout,"",numbers,strings,regexs)) {
                    found = 1;
                    DEBUG("Filter matched.");
                    break;
                }

            }

        }
        enc_close(f);
    }
    if (!found) {
        clean_xml_path(xmlpath,xmlout);
    }
    return 0+ found;
}

# Check if an xml element matches a set of filters.
# IN xml - xml data
# IN root - first part of tag path
# IN numbers - hash of tag_suffix => numbers to match. eg #id = 1234 or /id=1234
# IN strings - hash of tag_suffix => strings to match. eg #name = Fred (for attribute) /name = Fred (for text)
# IN strings - hash of tag_suffix => regex to match. 
function check_filtered_element(xml,root,numbers,strings,regexs,\
found,t,tag) {
    found=1;

    for(t in numbers) {
        tag = root t;
        if (!(tag in xml) || (xml[tag] - numbers[t] != 0) ) {
            found =0 ; break;
        }
    }
    for(t in strings) {
        tag = root t;
        if (!(tag in xml) || (xml[tag]"" != strings[t] ) ) {
            found =0 ; break;
        }
    }
    for(t in regexs) {
        tag = root t;
        if (!(tag in xml) || (tolower(xml[tag]) !~ regexs[t] ) ) {
            found =0 ; break;
        }
    }
    return found;
}

# Get array element. eg if xml =
# xml[/parent/child#name]=John
# xml[/parent/child>2#name]=Sue
#
# filters=
# /name=Sue
#
# Filter names are currently just attributes #name but this can be extended to support paths eg /name if needed.
# returns modified root element eg /parent/child>2

#IN xml array
#IN root  - element we are looking for
#IN fliters array of filters, numeric, text or ~:regex
#IN number of items to match 0=all
#OUT array of items. - index=order value=tag path
#RETURN number of matches.
function find_elements(xml,root,filters,maxtags,tagsout,\
root_re,numbers,strings,regexs,found,num,tag,child,numtags,do_filter) {

    id1("find_elements["root"]");
    delete tagsout;
    num=0;
    found = 0;
    do_filter = reset_filters(filters,numbers,strings,regexs);

    #Create re to match on array elements.
    # Convert /parent/child to /parent(>[0-9]+|)/child(>[0-9]+|)
    root_re="^"gensub("(.)(/|$)","\\1(>[0-9]+|)\\2","g",root)"$";
    #DEBUG("XX regex["root_re"]");

    numtags = xml["@count"];
    for(tag = 1 ; tag <= numtags ; tag++) {
        # Need to make sure tag  always appears even if epty text element
        if ( match(xml[tag],root_re)) {
            child = substr(xml[tag],RSTART,RLENGTH);
            #DEBUG("XX possible ["child"] from tag ["xml[tag]"]");

            if (do_filter == 0 || check_filtered_element(xml,child,numbers,strings,regexs)) {

                DEBUG("Filter matched ["child"]");
                tagsout[++num] = child;
                if (maxtags && num >= maxtags) {
                    break;
                }
            }
        }
    }
    id0(num);
    return num;
}

# look for /parentTag>?/tag = value
#assumes that tag is not an array , and if parentTag itself is within an array - only that item is looked at
# ie parent=/level1/level2 tag=3
# will find /level1/level2>4/tag=3 but not /level1>2/level2/tag=3
function find_tag(xml,parent,tag,value,tag2,value2,\
i,n,p2,ret) {
    n = xml["@count:"parent];
    for(i = 1 ; i<= n ; i++ ) {
        p2 = parent (i>1?">"i:"");
        if (xml[p2 tag] == value) {
            if (!tag2 || xml[p2 tag2] == value2) {
                ret = p2;
                break;
            }
        }
    }
    INF("xml: "parent "tag = ["tag"="value"] ["tag2"="value2"] = ["ret"]");
    return ret;
}
