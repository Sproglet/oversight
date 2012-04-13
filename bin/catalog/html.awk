#Scan a page for first link to a given domain
function scan_page_for_first_link(url,domain,cache) {
    return scanPageFirstMatch(url,domain,"http://(|[^\"'/]+\\.)"domain "\\." g_nonquote_regex"+",cache);
}

# Scan a page for matches to regular expression
# IN fixed_text, - fixed text to help speed up scan
# matches = array of matches index 1,2,...
# max = max number to match
# returns match or empty.
# if freqOrFirst=1 return first match else
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
# Scan a page for given regex return the most frequently occuring matching text.
# fixed_text is used to quickly filter strings that may match the regex.
# result returned in matches as count index by matching text.
# return value is the number of matches.
function scanPageMostSignificantMatch(url,fixed_text,regex,cache,referer,matches,\
normedt,ret) {
    id1("scanPageMostSignificantMatch");
    scan_page_for_match_counts(url,fixed_text,regex,0,cache,referer,matches);
    if (regex == g_imdb_title_re) {
        normalise_title_matches(matches,normedt);
        hash_copy(matches,normedt);
    }
    ret=getMax(matches,1,1);
    id0(ret);
    return ret;
}

function ficonv(f) {

    return CAPTURE_PREFIX basename(f) ".iconv";
}

#getline_encode
# read a line from html or xml and apply html_decoding and utf8_encoding
# based on encoding flags at the start of the content.
# TODO only check xml encoding for first line.
# returns getline code and line contents in line[1]
function enc_getline(f,line,\
code,t,enc,f8bit) {

    if (g_encoding[f] == "" ) {

        decode_init();

        # check encoding
        enc = g_encoding[f] = get_encoding(f);

        if (enc == "utf-8") {

            html_decode_file(f,ficonv(f),1);

        } else {

            #This file will have all html codes replaced with binary 8 bit chars. If there is utf8 present it will break
            #due to subsequent call to iconv (double encode)
            f8bit = f".8bit";

            html_decode_file(f,f8bit,0);

            if (exec("iconv -f "enc" -t utf-8 "qa(f8bit)" > "qa(ficonv(f))) == 0) {
                g_encoding[f] = "utf-8";
            } else {
                ERR("iconv "enc" to utf-8 failed");
            }
            rm(f8bit,1);
        } 
    }

    enc = g_encoding[f];

    if (enc == "utf-8") {
        code = ( getline t < ficonv(f) );

        if (code > 0) {

            line[1] = t;
        }
    }
    return code;
}


function enc_close(f) {
    if (g_encoding[f] == "utf-8") {
        if (is_file(ficonv(f))) {
            close(ficonv(f));
            rm(ficonv(f),1);
        }
    }
    delete g_encoding[f];
    close(f);
}

# TODO only check xml encoding for first line.
function get_encoding(f,\
enc,line,code,n) {


    if (index(f,".json")) {
        enc = "utf-8";
    } else if (is_file(ficonv(f))) {
        enc = "utf-8";
    } else {
        while ( enc == "" && (code = ( getline line < f )) > 0) {

            enc = extract_encoding(line);

            # Track lack of markup
            if (index(line,"<") == 0) n++; else n = 0;
        }
        if (n >= 20) WARNING("Lack of markup");
        if (code >= 0) {
            if ((code = close(f)) != 0) {
               INF("Failed to close "f" code = "code) ; 
            }
        }
    }
    if (enc == "" ) {
        #enc = "iso-8859-1";
        enc = "utf-8"; # google pages assumed to be utf-8 ?
    }

    return enc;
}


#returns
# encoding eg utf-8 iso-8859-1 etcs
# OR "?"=unknown/giveup
# OR blank=keep checking
function extract_encoding(line,\
enc) {
    line=tolower(line);

    if (index(line,"encoding") || index(line,"charset")) {

        enc=subexp(line,"(encoding|charset)=\"?([-_a-z0-9]+)[\"> ]",2);

        if (index(line,"<?xml")) {
            if (!enc) enc="utf-8";
        }


    } else if (index(line,"</head>") || index(line,"<body>")) {
        if (!enc) enc = "utf-8" ; #assume utf8 if not specified.
    }
    if (enc && (enc != "utf-8") ) INF("Encoding:" enc);
    return enc;
}


# Check engine 0=bad 1 or more = good
function engine_check(url,\
ret,matches) {
    # function scan_page_for_matches(url,fixed_text,regex,max,cache,referer,count_or_order,matches,verbose,\
    ret = scan_page_for_match_order(url url_encode("\"The Spy Who Loved Me\" imdb"),"imdb","title/tt0076752",0,0,"",matches);
    dump(0,"match order",matches);
    ret = scan_page_for_match_counts(url url_encode("\"The Spy Who Loved Me\" imdb"),"imdb","title/tt0076752",0,0,"",matches);
    dump(0,"match counts",matches);
    ret = scan_page_for_matches(url url_encode("\"The Spy Who Loved Me\" imdb"),"imdb","tt0076752/",1);
    if (ret) {
        INF("search engine ready ["url"]\n");
    } else {
        ERR("!!!search engine error!!! ["url"]\n");
    }
    return ret;
}


# Scan a page for matches to regular expression
# IN url to scan
# IN fixed_text, - fixed text to help speed up scan
# IN regex to scan for
# IN max = max number to match 0=all
# OUT matches = array of matches index by the match text value = number of occurences.
# return number of matches
function scan_page_for_match_counts(url,fixed_text,regex,max,cache,referer,matches,verbose,label) {
    return scan_page_for_matches(url,fixed_text,regex,max,cache,referer,0,matches,verbose,label);
}
# Scan a page for matches to regular expression
# IN url to scan
# IN fixed_text, - fixed text to help speed up scan
# IN regex to scan for
# IN max = max number to match 0=all
# OUT matches = array of matches index by order of occurrence
# return number of matches
function scan_page_for_match_order(url,fixed_text,regex,max,cache,referer,matches,verbose,label) {
    return scan_page_for_matches(url,fixed_text,regex,max,cache,referer,1,matches,verbose,label);
}
# Scan a page for matches to regular expression
# IN url to scan
# IN fixed_text, - fixed text to help speed up scan - use SUBSEP seperator for multiple items
# IN regex to scan for
# IN max = max number to match 0=all
# IN count_or_order = 0=count 1=order
# OUT matches = array of matches index by the match text value = number of occurences.
# return number of matches
function scan_page_for_matches(url,fixed_text,regex,max,cache,referer,count_or_order,matches,verbose,label,\
f,line,count,remain,is_imdb,i,text_num,text_arr,scan) {

#    if (index(url,"yahoo") && index(url,"2010") && index(url,"site:imdb.com")) {
#        verbose=1; # Debug line edit as required
#    } else {
#        DEBUG("disable me !!!!!!!!!!");
#    }

    delete matches;
    id1("scan_page_for_matches["fixed_text"]["regex"]");
    INF("["fixed_text"]["\
        (regex == g_imdb_regex\
            ?"<imdbtag>"\
            :(regex==g_imdb_title_re\
                ?"<imdbtitle>"\
                :regex\
              )\
       )"]["max"]");

    if (g_fetch["force_awk"] && g_settings["catalog_awk_browser"] ) {

        # Use the inline browser - this is not as robust as external command line but should be faster.

        if (url_get(url,line,"",cache)) {
            #DEBUG("DELETE" gensub(/</,"\n<","g",line["body"]));
            count +=get_matches(count_or_order,line["body"],regex,max,count,matches,verbose);
        }

    } else {

        # Map obsolete this is things still work OK.

        if (index(url,"SEARCH") == 1) {
            f = search_url2file(url,cache,referer);
        } else {
            if (!label) label = "scan4match.html";
            f=getUrl(url,label,cache,referer);
        }

        text_num = 0;
        if (fixed_text != "") text_num = split(fixed_text,text_arr,SUBSEP);

        count=0;

        is_imdb = (regex == g_imdb_regex );

        if (f != "" ) {

            FS="\n";
            remain=max;

            while(enc_getline(f,line) > 0 ) {

                line[1] = de_emphasise(line[1]);

                if (verbose) DEBUG("["line[1]"]");

                # Quick hack to find Title?0012345 as tt0012345  because altering the regex
                # itself is more work - for example the results will come back as two different 
                # counts. 
                if (is_imdb) {
                    if (index(line[1],"/Title?") ) {
                        if (gsub(/\/Title\?/,"/tt",line[1])) {
                            INF("fixed imdb reference "line[1]);
                        }
                    }
                    # A few sites have IMDB ID 0123456 
                    if (index(line[1],"IMDB") || index(line[1],"imdb") ) {
                        line[1] = gensub(/[Ii][Mm][Dd][Bb][^0-9]{1,10}([0-9]{6})\>/,"tt\\1","g",line[1]);
                    }
                }


                scan = 1;
                if (text_num) {
                    scan = 0;
                    for(i = 1 ; i<= text_num ; i++ ) {
                        if ((scan = index(line[1],text_arr[i])) != 0) {
                            break;
                        }
                    }
                }

                if (verbose) DEBUG("scanindex = "scan":"line[1]);

                if (scan) {
                    count += get_matches(count_or_order,line[1],regex,remain,count,matches,verbose);
                    if (max > 0) {
                        remain -= count;
                        if (remain <= 0) {
                            break;
                        }
                    }
                }
            }
            enc_close(f);
        }
    }
    dump(2,count" matches",matches);
    id0(count);
    return 0+ count;
}

# Extract the text patterns
#
# IN regex to scan for
# IN max = max number to match 0=all
# IN count_or_order = 0=count 1=order
# OUT matches = array of matches index by the match text value = number of occurences.
# return number of matches
function get_matches(count_or_order,text,regex,max,count_so_far,matches,verbose,\
linecount,i,matches2) {

    if (count_or_order) {
        # Get all ordered matches. 1=>test1, 2=>text2 , etc.
        linecount = patsplitn(text,regex,max,matches2);
        if (verbose) {
            DEBUG("linecount = "linecount" max="max);
            dump(0,"matches2",matches2);
        }
        # 
        # Append the matches2 array of ordered regex matches. Index by order.
        for(i = 1 ; i+0 <= linecount+0 ; i++) {
            matches[count_so_far+i] = matches2[i];
            if (verbose) DEBUG("xx match ["matches[count_so_far+i]"]");
        }
    } else {
        # Get all occurence counts text1=m , text2=n etc.
        linecount = get_regex_counts(text,regex,max,matches2);
        if (verbose) {
            DEBUG("linecount2 = "linecount" max="max);
            dump(0,"matches2",matches2);
        }
        # Add to the total occurences so far , index by pattern.
        hash_add(matches,matches2);
    }
    return linecount;
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

    gsub(/(<\/?(b|em|strong)>|<br ?\/>)/,"",html); #remove emphasis tags - assuming tag as no attributes. small risk here

    if (index(html,"wbr")) {
        # Note yahoo will sometimes break an imdb tag with a space and wbr eg. tt1234 <wbr>567
        gsub(/ ?<\/?wbr>/,"",html); #remove emphasis tags
    }
    return html;
}

function urladd(a,b) {
    return a (index(a,"?") ? "&" : "?" ) b;
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
i,c,h) {
    if (g_chr[32] == "" ) {
        DEBUG("create decode matrix");
        for(i=0 ; i - 256 < 0 ; i++ ) {
            c=sprintf("%c",i);
            h=sprintf("%02x",i);
            g_chr[i] = c;
            g_chr["x"h] = c;
            g_ascii[c] = i;
            g_hex[i]=h;

        }
        for(i=0 ; i < 256 ; i++ ) {
            g_utf8[c]=code_to_utf8(i);
        }
        #special html - all sites return utf8 except for IMDB and epguides.
        # IMDB doesnt use symbolic names - mostly hexcodes. So we can probably 
        # not bother with anything except for amp. see what happens.
        #s="amp|38|gt|62|lt|60|divide|247|deg|176|copy|169|pound|163|quot|34|nbsp|32|cent|162|";

        # If any special codes added here they should be 8bit. As they will be later processed into utf8 by iconv.
        g_chr["amp"] = "&";
        g_chr["quot"] = "\"";
        g_chr["lt"] = "<";
        g_chr["gt"] = ">";
        g_chr["nbsp"] = " ";
        #  g_chr["szlig"] = code_to_utf8(0xdf); #g_chr[0xC3] g_chr[0x9F]; http://www.fileformat.info/format/w3c/htmlentity.htm
        g_chr["szlig"] = g_chr["0xdf"]; 
        g_chr["raquo"] = g_chr["0xbb"]; 

        # Regex to find utf8 trailing chars
        g_utf8_trail_re = "["g_chr[0x80]"-"g_chr[0xBF]"]+";

    }
}

function html_decode_file(file1,file2,utf8mode,\
err,l) {
    while ( ( err = (getline l < file1 )) > 0 ) {
        print html_decode(l,utf8mode) > file2;
    }
    if (err >= 0) {
        close(file1);
    }
    close(file2);
}

function html_decode(text,utf8mode,\
parts,seps,part,count,code,newcode,text2) {
    if (g_chr[32] == "" ) {
        decode_init();
    }

    # Change all numeric items
    text = html_convert_numbers(text,utf8mode);

    if (index(text,"&") && index(text,";")) {

        count = ovs_patsplit(text,parts,"[&][[:alpha:]]+;",seps);

        for(part=1 ; part <= count ; part++ ) {

            newcode="";

            code=parts[part];
            if (code != "") {

                code=tolower(code); # "&#xff;" "&#255;" "&nbsp;"

                # "&nbsp;" => "nbsp"
                newcode=g_chr[substr(code,2,length(code)-2)];
            }
            if (newcode == "") {
                newcode=parts[part]; #unchanged
            }
            text2=text2 seps[part-1] newcode;
        }
        text2 = text2 seps[count];
        if (text != text2 ) {
            text = text2;
        }
    }
    return text;
}

# Convert &#123; to the binary representation. Use utf8 for numbers > 127
function html_to_utf8(text) {
    return html_convert_numbers(text,1);
}

# Convert &#123; to the binary representation. 
function html_to_8bit(text) {
    return html_convert_numbers(text,0);
}


# Convert &#123; to the binary representation. If utf8mode use utf8 for numbers > 127
function html_convert_numbers(text,utf8mode,\
ret,num,i,parts,seps,code) {

    if (index(text,"&#")) {
        decode_init();
        num = ovs_patsplit(text,parts,"[&](#[0-9]{1,4}|#[Xx][0-9a-fA-F]{1,4});",seps);
        for(i = 1 ; i <= num ; i++) {
            if (tolower(substr(parts[i],1,3)) == "&#x" ) {
                # &#x123;
                code = hex2dec(substr(parts[i],4,length(parts[i])-4));
            } else {
                # &#123;
                code = substr(parts[i],3,length(parts[i])-3);
            }
            if (utf8mode) {
                ret = ret seps[i-1] code_to_utf8(code+0);
            } else if (code <= 255 ) {
                ret = ret seps[i-1] g_chr[code+0];
            } else {
                INF("Forced utf8 character "code" : might get corrupted by iconv");
                ret = ret seps[i-1] code_to_utf8(code+0);
            }
        }
        ret = ret seps[num];
        text = ret;
    }
    return text;
}

function code_to_utf8(code,\
new,b,i,bytes) {

    if (code > 0x3FFFFFF ) {
        bytes=6;
    } else if (code > 0x1FFFFF ) {
        bytes=5;
    } else if (code > 0xFFFF ) {
        bytes=4;
    } else if (code > 0x7FF ) {
        bytes=3;
    } else if (code > 0x7F ) {
        bytes=2;
    } else {
        bytes=1;
    }
    new = "";
    if (bytes == 1 ) {
        new = g_chr[code];
    } else {
        for(i = 1 ; i < bytes ; i++ ) {
            b = or(0x80,and(code,0x3F));
            new = g_chr[b] new;
            code = rshift(code,6);
        }
        # first byte
        b=or(and(lshift(0xFC,6-bytes),0xFF),code);
        new  = g_chr[b] new;
    }
    return new;
}

# return the number of logical characters in a string (utf-8 chars count as 1 char as does &nbsp; etc ) 
function utf8len(text) {
    if (g_chr[32] == "" ) {
        decode_init();
    }
    if (index(text,"&")) gsub("[&](#[0-9]{1,4}|#[Xx][0-9a-fA-F]{1,4}|[a-z]{1,6});","@",text);
    gsub(g_utf8_trail_re,"",text); # utf8 trailing chars
    return length(text);
}
