# Scan a page for matches to regular expression
# IN fixed_text, - fixed text to help speed up scan
# matches = array of matches index 1,2,...
# max = max number to match
# returns match or empty.
# if freqOrFirst=1 return first match else
# =0 return most common matches in best(index by match id, value = count)
function scanPageFirstMatch(url,fixed_text,regex,cache,referer,\
matches,ret) {
    id1("scanPageFirstMatch");
    scan_page_for_match_counts(url,fixed_text,regex,1,cache,referer,matches);
    ret = firstIndex(matches);
    id0(ret);
    return ret;
}

# Scan a page for given regex return the most frequently occuring matching text.
# fixed_text is used to quickly filter strings that may match the regex.
# result returned in matches as count index by matching text.
# return value is the number of matches.
function scanPageMostFreqMatch(url,fixed_text,regex,cache,referer,matches,\
normedt,ret) {
    id1("scanPageMostFreqMatch");
    scan_page_for_match_counts(url,fixed_text,regex,0,cache,referer,matches);
    if (regex == g_imdb_title_re) {
        normalise_title_matches(matches,normedt);
        hash_copy(matches,normedt);
    }
    ret=bestScores(matches,matches,0);
    id0(ret);
    return ret;
}
#getline_encode
# read a line from html or xml and apply html_decoding and utf8_encoding
# based on encoding flags at the start of the content.
# TODO only check xml encoding for first line.
# returns getline code and line contents in line[1]
function enc_getline(f,line,\
code,t) {

    code = ( getline t < f );

    if (code > 0) {
        #TODO - remove this debug code

        if (g_f_utf8[f] == "" ) {

            # check encoding

            g_f_utf8[f] = check_utf8(t);


        } else {

            t = html_decode(t);

            if (g_f_utf8[f] != 1) {
                t = utf8_encode(t);
            }
        }
        line[1] = t;
    }
    return code;
}

function enc_close(f) {
    delete g_f_utf8[f];
    close(f);
}

# TODO only check xml encoding for first line.
function check_utf8(line,\
utf8) {
    line=tolower(line);
    if (index(line,"<?xml") || index(line,"charset")) {

        utf8 = index(line,"utf-8")?1:-1;

    } else if (index(line,"</head>")) {
        utf8 = -1;
    }
    if (utf8) INF("UTF-8 Encoding:" utf8);
    return utf8;
}

# Scan a page for matches to regular expression
# IN url to scan
# IN fixed_text, - fixed text to help speed up scan
# IN regex to scan for
# IN max = max number to match 0=all
# OUT matches = array of matches index by the match text value = number of occurences.
# return number of matches
function scan_page_for_match_counts(url,fixed_text,regex,max,cache,referer,matches,verbose) {
    return scan_page_for_matches(url,fixed_text,regex,max,cache,referer,0,matches,verbose);
}
# Scan a page for matches to regular expression
# IN url to scan
# IN fixed_text, - fixed text to help speed up scan
# IN regex to scan for
# IN max = max number to match 0=all
# OUT matches = array of matches index by order of occurrence
# return number of matches
function scan_page_for_match_order(url,fixed_text,regex,max,cache,referer,matches,verbose) {
    return scan_page_for_matches(url,fixed_text,regex,max,cache,referer,1,matches,verbose);
}
# Scan a page for matches to regular expression
# IN url to scan
# IN fixed_text, - fixed text to help speed up scan
# IN regex to scan for
# IN max = max number to match 0=all
# IN count_or_order = 0=count 1=order
# OUT matches = array of matches index by the match text value = number of occurences.
# return number of matches
function scan_page_for_matches(url,fixed_text,regex,max,cache,referer,count_or_order,matches,verbose,\
f,line,count,linecount,remain,is_imdb,matches2,i) {

    delete matches;
    id1("scan_page_for_matches["url"]");
    INF("["fixed_text"]["\
        (regex == g_imdb_regex\
            ?"<imdbtag>"\
            :(regex==g_imdb_title_re\
                ?"<imdbtitle>"\
                :regex\
              )\
       )"]["max"]");

    if (index(url,"SEARCH") == 1) {
        f = search_url2file(url,cache,referer);
    } else {
        f=getUrl(url,"scan4match",cache,referer);
    }

    count=0;

    is_imdb = (regex == g_imdb_regex );

    if (f != "" ) {

        FS="\n";
        remain=max;

        while(enc_getline(f,line) > 0 ) {

            line[1] = de_emphasise(line[1]);

            # Quick hack to find Title?0012345 as tt0012345  because altering the regex
            # itself is more work - for example the results will come back as two different 
            # counts. 
            if (is_imdb && index(line[1],"/Title?") ) {
                gsub(/\/Title\?/,"/tt",line[1]);
            }

            if (verbose) DEBUG("scanindex = "index(line[1],fixed_text));
            if (verbose) DEBUG(line[1]);

            if (fixed_text == "" || index(line[1],fixed_text)) {

                if (count_or_order) {
                    # Get all ordered matches. 1=>test1, 2=>text2 , etc.
                    linecount = get_regex_pos(line[1],regex,remain,matches2);
                    # 
                    # Append the matches2 array of ordered regex matches. Index by order.
                    for(i = 1 ; i+0 <= linecount+0 ; i++) {
                        matches[count+i] = matches2[i];
                    }
                } else {
                    # Get all occurence counts text1=m , text2=n etc.
                    linecount = get_regex_counts(line[1],regex,remain,matches2);
                    # Add to the total occurences so far , index by pattern.
                    hash_add(matches,matches2);
                }

                count += linecount;
                if (max > 0) {
                    remain -= count;
                    if (remain <= 0) {
                        break;
                    }
                }
            }
        }
        close(f);
    }
    dump(2,count" matches",matches);
    id0(count);
    return 0+ count;
}

function extractAttribute(str,tag,attr,\
    tagPos,closeTag,endAttr,attrPos) {

    tagPos=index(str,"<"tag);
    closeTag=indexFrom(str,">",tagPos);
    attrPos=indexFrom(str,attr"=",tagPos);
    if (attrPos == 0 || attrPos-closeTag >= 0 ) {
        ERR("ATTR "tag"/"attr" not in "str);
        ERR("tagPos is "tagPos" at "substr(str,tagPos));
        ERR("closeTag is "closeTag" at "substr(str,closeTag));
        ERR("attrPos is "attrPos" at "substr(str,attrPos));
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
function de_emphasise(html) {
    if (index(html,"<b") || index(html,"</b") ||\
       index(html,"<em") || index(html,"</em") ||\
       index(html,"<strong") || index(html,"</strong") ) {
        gsub(/<\/?(b|em|strong)>/,"",html); #remove emphasis tags
    }
    if (index(html,"wbr")) {
        # Note yahoo will sometimes break an imdb tag with a space and wbr eg. tt1234 <wbr>567
        gsub(/ *<\/?wbr>/,"",html); #remove emphasis tags
    }
    if (index("/>",html)) {
        #gsub(/<[^\/][^<]+\/>/,"",html); #remove single tags eg <wbr />
        gsub(/<[a-z]+ ?\/>/,"",html); #remove single tags eg <wbr />
    }
    return html;
}

function urladd(a,b) {
    return a (index(a,"?") ? "&" : "?" ) b;
}

# encode a string to utf8
function utf8_encode(text,\
text2,part,parts,count) {
    if (g_chr[32] == "" ) {
        decode_init();
    }


    if (ascii8(text)) {
        count = chop(text,"["g_8bit"]+",parts);
        for(part=2 ; part-count <= 0 ; part += 2 ) {
            text2=text2 parts[part-1] utf8_encode2(parts[part]);
            #INF("utf8 [["substr(parts[part-1],length(parts[part-1])-20)"]]...[["substr(parts[part+1],1,20)"]]");
        }
        text2 = text2 parts[count];
        if (text != text2 ) {
            text = text2;
        }
    }
    return text;
}
# encode a string to utf8 that alread consists entirely of chr(128-255)
# called by utf8_encode
function utf8_encode2(text,\
i,text2,ll) {

    ll=length(text);
    for(i = 1 ; i - ll <= 0 ; i++ ) {
        text2 = text2 g_utf8[substr(text,i,1)];
    }
#    if (text != text2 ) {
#        DEBUG("utf8_encode2 ["text"]=["text2"]");
#    }
    return text2;
}


function url_encode(text,\
i,text2,ll,c) {

    if (g_chr[32] == "" ) {
        decode_init();
    }

    text2="";
    ll=length(text);
    for(i = 1 ; i - ll <= 0 ; i++ ) {
        c=substr(text,i,1);
        if (index("% =()[]+",c) || g_ascii[c] -128 >= 0 ) {
            text2= text2 "%" g_hex[g_ascii[c]];
        } else {
            text2=text2 c;
        }
    }
    if (text != text2 ) {
        DEBUG("url encode ["text"]=["text2"]");
    }

    return text2;
}

function decode_init(\
i,c,h,b1,b2) {
    DEBUG("create decode matrix");
    for(i=0 ; i - 256 < 0 ; i++ ) {
        c=sprintf("%c",i);
        h=sprintf("%02x",i);
        g_chr[i] = c;
        g_chr["x"h] = c;
        g_ascii[c] = i;
        g_hex[i]=h;

    }
    for(i=0 ; i - 128 < 0 ; i++ ) {
        c = g_chr[i];
        g_utf8[c]=c;
    }
    for(i=128 ; i - 256 < 0 ; i++ ) {
        c = g_chr[i];
        b1=192+rshift(i,6);
        b2=128+and(i,63);
        g_utf8[c]=g_chr[b1+0] g_chr[b2+0];
    }
    #special html - all sites return utf8 except for IMDB and epguides.
    # IMDB doesnt use symbolic names - mostly hexcodes. So we can probably 
    # not bother with anything except for amp. see what happens.
    #s="amp|38|gt|62|lt|60|divide|247|deg|176|copy|169|pound|163|quot|34|nbsp|32|cent|162|";
    g_chr["amp"] = "&";
    g_chr["quot"] = "\"";
    g_chr["lt"] = "<";
    g_chr["gt"] = ">";
    g_chr["nbsp"] = " ";
}

function html_decode(text,\
parts,part,count,code,newcode,text2) {
    if (g_chr[32] == "" ) {
        decode_init();
    }
    if (index(text,"&")) {

        count = chop(text,"[&][#0-9a-zA-Z]+;",parts);

        for(part=2 ; part-count < 0 ; part += 2 ) {

            newcode="";

            code=parts[part];
            if (code != "") {

                code=tolower(code); # "&#xff;" "&#255;" "&nbsp;"

                if (index(code,"&#") == 1) {
                    # &#xff; => xff   &#255; => 255
                    code = substr(code,3,length(code)-3);
                    if (index(code,"x") == 1) {
                        # xff;
                        newcode=g_chr[code];
                    } else {
                        # &#255;
                        newcode=g_chr[0+code];
                    }
                } else {
                    # "&nbsp;" => "nbsp"
                    newcode=g_chr[substr(code,2,length(code)-2)];
                }
            }
            if (newcode == "") {
                newcode=parts[part]; #unchanged
            }
            text2=text2 parts[part-1] newcode;
            #INF("utf8 [["substr(parts[part-1],length(parts[part-1])-20)"]]...[["substr(parts[part+1],1,20)"]]");
        }
        text2 = text2 parts[count];
        if (text != text2 ) {
            text = text2;
        }
    }
    return text;
}

