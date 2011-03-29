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

function codepages() {

    # codepages mappings taken from http://www.unicode.org

    if (!(1 in g_cp1250)) {
        DEBUG("cp g_cp1250");
        map_codepage_to_utf8(g_cp1250,",80,20AC,82,201A,84,201E,85,2026,86,2020,87,2021,89,2030,8A,0160,8B,2039,8C,015A,8D,0164,8E,017D,8F,0179,91,2018,92,2019,93,201C,94,201D,95,2022,96,2013,97,2014,99,2122,9A,0161,9B,203A,9C,015B,9D,0165,9E,017E,9F,017A,A0,00A0,A1,02C7,A2,02D8,A3,0141,A4,00A4,A5,0104,A6,00A6,A7,00A7,A8,00A8,A9,00A9,AA,015E,AB,00AB,AC,00AC,AD,00AD,AE,00AE,AF,017B,B0,00B0,B1,00B1,B2,02DB,B3,0142,B4,00B4,B5,00B5,B6,00B6,B7,00B7,B8,00B8,B9,0105,BA,015F,BB,00BB,BC,013D,BD,02DD,BE,013E,BF,017C,C0,0154,C1,00C1,C2,00C2,C3,0102,C4,00C4,C5,0139,C6,0106,C7,00C7,C8,010C,C9,00C9,CA,0118,CB,00CB,CC,011A,CD,00CD,CE,00CE,CF,010E,D0,0110,D1,0143,D2,0147,D3,00D3,D4,00D4,D5,0150,D6,00D6,D7,00D7,D8,0158,D9,016E,DA,00DA,DB,0170,DC,00DC,DD,00DD,DE,0162,DF,00DF,E0,0155,E1,00E1,E2,00E2,E3,0103,E4,00E4,E5,013A,E6,0107,E7,00E7,E8,010D,E9,00E9,EA,0119,EB,00EB,EC,011B,ED,00ED,EE,00EE,EF,010F,F0,0111,F1,0144,F2,0148,F3,00F3,F4,00F4,F5,0151,F6,00F6,F7,00F7,F8,0159,F9,016F,FA,00FA,FB,0171,FC,00FC,FD,00FD,FE,0163,FF,02D9");
    }
    if (!(1 in g_cp1251)) {
        DEBUG("cp g_cp1251");
        map_codepage_to_utf8(g_cp1251,"80,0402,81,0403,82,201A,83,0453,84,201E,85,2026,86,2020,87,2021,88,20AC,89,2030,8A,0409,8B,2039,8C,040A,8D,040C,8E,040B,8F,040F,90,0452,91,2018,92,2019,93,201C,94,201D,95,2022,96,2013,97,2014,99,2122,9A,0459,9B,203A,9C,045A,9D,045C,9E,045B,9F,045F,A0,00A0,A1,040E,A2,045E,A3,0408,A4,00A4,A5,0490,A6,00A6,A7,00A7,A8,0401,A9,00A9,AA,0404,AB,00AB,AC,00AC,AD,00AD,AE,00AE,AF,0407,B0,00B0,B1,00B1,B2,0406,B3,0456,B4,0491,B5,00B5,B6,00B6,B7,00B7,B8,0451,B9,2116,BA,0454,BB,00BB,BC,0458,BD,0405,BE,0455,BF,0457,C0,0410,C1,0411,C2,0412,C3,0413,C4,0414,C5,0415,C6,0416,C7,0417,C8,0418,C9,0419,CA,041A,CB,041B,CC,041C,CD,041D,CE,041E,CF,041F,D0,0420,D1,0421,D2,0422,D3,0423,D4,0424,D5,0425,D6,0426,D7,0427,D8,0428,D9,0429,DA,042A,DB,042B,DC,042C,DD,042D,DE,042E,DF,042F,E0,0430,E1,0431,E2,0432,E3,0433,E4,0434,E5,0435,E6,0436,E7,0437,E8,0438,E9,0439,EA,043A,EB,043B,EC,043C,ED,043D,EE,043E,EF,043F,F0,0440,F1,0441,F2,0442,F3,0443,F4,0444,F5,0445,F6,0446,F7,0447,F8,0448,F9,0449,FA,044A,FB,044B,FC,044C,FD,044D,FE,044E,FF,044F");
    }
    if (!(1 in g_cp1252)) {
        DEBUG("cp g_cp1252");
        map_codepage_to_utf8(g_cp1252,"80,20AC,82,201A,83,0192,84,201E,85,2026,86,2020,87,2021,88,02C6,89,2030,8A,0160,8B,2039,8C,0152,8E,017D,91,2018,92,2019,93,201C,94,201D,95,2022,96,2013,97,2014,98,02DC,99,2122,9A,0161,9B,203A,9C,0153,9E,017E,9F,0178,A0,00A0,A1,00A1,A2,00A2,A3,00A3,A4,00A4,A5,00A5,A6,00A6,A7,00A7,A8,00A8,A9,00A9,AA,00AA,AB,00AB,AC,00AC,AD,00AD,AE,00AE,AF,00AF,B0,00B0,B1,00B1,B2,00B2,B3,00B3,B4,00B4,B5,00B5,B6,00B6,B7,00B7,B8,00B8,B9,00B9,BA,00BA,BB,00BB,BC,00BC,BD,00BD,BE,00BE,BF,00BF,C0,00C0,C1,00C1,C2,00C2,C3,00C3,C4,00C4,C5,00C5,C6,00C6,C7,00C7,C8,00C8,C9,00C9,CA,00CA,CB,00CB,CC,00CC,CD,00CD,CE,00CE,CF,00CF,D0,00D0,D1,00D1,D2,00D2,D3,00D3,D4,00D4,D5,00D5,D6,00D6,D7,00D7,D8,00D8,D9,00D9,DA,00DA,DB,00DB,DC,00DC,DD,00DD,DE,00DE,DF,00DF,E0,00E0,E1,00E1,E2,00E2,E3,00E3,E4,00E4,E5,00E5,E6,00E6,E7,00E7,E8,00E8,E9,00E9,EA,00EA,EB,00EB,EC,00EC,ED,00ED,EE,00EE,EF,00EF,F0,00F0,F1,00F1,F2,00F2,F3,00F3,F4,00F4,F5,00F5,F6,00F6,F7,00F7,F8,00F8,F9,00F9,FA,00FA,FB,00FB,FC,00FC,FD,00FD,FE,00FE,FF,00FF");
    }
    if (!(1 in g_cp1253)) {
        DEBUG("cp g_cp1253");
        map_codepage_to_utf8(g_cp1253,"80,20AC,82,201A,83,0192,84,201E,85,2026,86,2020,87,2021,89,2030,8B,2039,91,2018,92,2019,93,201C,94,201D,95,2022,96,2013,97,2014,99,2122,9B,203A,A0,00A0,A1,0385,A2,0386,A3,00A3,A4,00A4,A5,00A5,A6,00A6,A7,00A7,A8,00A8,A9,00A9,AB,00AB,AC,00AC,AD,00AD,AE,00AE,AF,2015,B0,00B0,B1,00B1,B2,00B2,B3,00B3,B4,0384,B5,00B5,B6,00B6,B7,00B7,B8,0388,B9,0389,BA,038A,BB,00BB,BC,038C,BD,00BD,BE,038E,BF,038F,C0,0390,C1,0391,C2,0392,C3,0393,C4,0394,C5,0395,C6,0396,C7,0397,C8,0398,C9,0399,CA,039A,CB,039B,CC,039C,CD,039D,CE,039E,CF,039F,D0,03A0,D1,03A1,D3,03A3,D4,03A4,D5,03A5,D6,03A6,D7,03A7,D8,03A8,D9,03A9,DA,03AA,DB,03AB,DC,03AC,DD,03AD,DE,03AE,DF,03AF,E0,03B0,E1,03B1,E2,03B2,E3,03B3,E4,03B4,E5,03B5,E6,03B6,E7,03B7,E8,03B8,E9,03B9,EA,03BA,EB,03BB,EC,03BC,ED,03BD,EE,03BE,EF,03BF,F0,03C0,F1,03C1,F2,03C2,F3,03C3,F4,03C4,F5,03C5,F6,03C6,F7,03C7,F8,03C8,F9,03C9,FA,03CA,FB,03CB,FC,03CC,FD,03CD,FE,03CE");
    }

    if (!(1 in g_cp1254)) {
        DEBUG("cp g_cp1254");
        map_codepage_to_utf8(g_cp1254,"80,20AC,82,201A,83,0192,84,201E,85,2026,86,2020,87,2021,88,02C6,89,2030,8A,0160,8B,2039,8C,0152,91,2018,92,2019,93,201C,94,201D,95,2022,96,2013,97,2014,98,02DC,99,2122,9A,0161,9B,203A,9C,0153,9F,0178,A0,00A0,A1,00A1,A2,00A2,A3,00A3,A4,00A4,A5,00A5,A6,00A6,A7,00A7,A8,00A8,A9,00A9,AA,00AA,AB,00AB,AC,00AC,AD,00AD,AE,00AE,AF,00AF,B0,00B0,B1,00B1,B2,00B2,B3,00B3,B4,00B4,B5,00B5,B6,00B6,B7,00B7,B8,00B8,B9,00B9,BA,00BA,BB,00BB,BC,00BC,BD,00BD,BE,00BE,BF,00BF,C0,00C0,C1,00C1,C2,00C2,C3,00C3,C4,00C4,C5,00C5,C6,00C6,C7,00C7,C8,00C8,C9,00C9,CA,00CA,CB,00CB,CC,00CC,CD,00CD,CE,00CE,CF,00CF,D0,011E,D1,00D1,D2,00D2,D3,00D3,D4,00D4,D5,00D5,D6,00D6,D7,00D7,D8,00D8,D9,00D9,DA,00DA,DB,00DB,DC,00DC,DD,0130,DE,015E,DF,00DF,E0,00E0,E1,00E1,E2,00E2,E3,00E3,E4,00E4,E5,00E5,E6,00E6,E7,00E7,E8,00E8,E9,00E9,EA,00EA,EB,00EB,EC,00EC,ED,00ED,EE,00EE,EF,00EF,F0,011F,F1,00F1,F2,00F2,F3,00F3,F4,00F4,F5,00F5,F6,00F6,F7,00F7,F8,00F8,F9,00F9,FA,00FA,FB,00FB,FC,00FC,FD,0131,FE,015F,FF,00FF");
    }

    if (!(1 in g_8859_2)) {
        DEBUG("cp g_8859_2");
        map_codepage_to_utf8(g_8859_2,",A0,00A0,A1,0104,A2,02D8,A3,0141,A4,00A4,A5,013D,A6,015A,A7,00A7,A8,00A8,A9,0160,AA,015E,AB,0164,AC,0179,AD,00AD,AE,017D,AF,017B,B0,00B0,B1,0105,B2,02DB,B3,0142,B4,00B4,B5,013E,B6,015B,B7,02C7,B8,00B8,B9,0161,BA,015F,BB,0165,BC,017A,BD,02DD,BE,017E,BF,017C,C0,0154,C1,00C1,C2,00C2,C3,0102,C4,00C4,C5,0139,C6,0106,C7,00C7,C8,010C,C9,00C9,CA,0118,CB,00CB,CC,011A,CD,00CD,CE,00CE,CF,010E,D0,0110,D1,0143,D2,0147,D3,00D3,D4,00D4,D5,0150,D6,00D6,D7,00D7,D8,0158,D9,016E,DA,00DA,DB,0170,DC,00DC,DD,00DD,DE,0162,DF,00DF,E0,0155,E1,00E1,E2,00E2,E3,0103,E4,00E4,E5,013A,E6,0107,E7,00E7,E8,010D,E9,00E9,EA,0119,EB,00EB,EC,011B,ED,00ED,EE,00EE,EF,010F,F0,0111,F1,0144,F2,0148,F3,00F3,F4,00F4,F5,0151,F6,00F6,F7,00F7,F8,0159,F9,016F,FA,00FA,FB,0171,FC,00FC,FD,00FD,FE,0163,FF,02D9");
    }


    if (!(1 in g_8859_7)) {
        DEBUG("cp g_8859_7");
        map_codepage_to_utf8(g_8859_7,"A0,00A0,A1,2018,A2,2019,A3,00A3,A4,20AC,A5,20AF,A6,00A6,A7,00A7,A8,00A8,A9,00A9,AA,037A,AB,00AB,AC,00AC,AD,00AD,AF,2015,B0,00B0,B1,00B1,B2,00B2,B3,00B3,B4,0384,B5,0385,B6,0386,B7,00B7,B8,0388,B9,0389,BA,038A,BB,00BB,BC,038C,BD,00BD,BE,038E,BF,038F,C0,0390,C1,0391,C2,0392,C3,0393,C4,0394,C5,0395,C6,0396,C7,0397,C8,0398,C9,0399,CA,039A,CB,039B,CC,039C,CD,039D,CE,039E,CF,039F,D0,03A0,D1,03A1,D3,03A3,D4,03A4,D5,03A5,D6,03A6,D7,03A7,D8,03A8,D9,03A9,DA,03AA,DB,03AB,DC,03AC,DD,03AD,DE,03AE,DF,03AF,E0,03B0,E1,03B1,E2,03B2,E3,03B3,E4,03B4,E5,03B5,E6,03B6,E7,03B7,E8,03B8,E9,03B9,EA,03BA,EB,03BB,EC,03BC,ED,03BD,EE,03BE,EF,03BF,F0,03C0,F1,03C1,F2,03C2,F3,03C3,F4,03C4,F5,03C5,F6,03C6,F7,03C7,F8,03C8,F9,03C9,FA,03CA,FB,03CB,FC,03CC,FD,03CD,FE,03CE");

    }

}

function iconvf(f) {
    return f".iconv";
}

#getline_encode
# read a line from html or xml and apply html_decoding and utf8_encoding
# based on encoding flags at the start of the content.
# TODO only check xml encoding for first line.
# returns getline code and line contents in line[1]
function enc_getline(f,line,\
code,t,enc) {

    if (g_encoding[f] == "" ) {

        # The code pages are only used if iconv is not available.
        # codepages can be removed at later date.
        decode_init();
        codepages();

        # check encoding
        enc = g_encoding[f] = get_encoding(f);

        if (enc != "iconv" && enc != "utf-8") {
            if (!g_skipiconv[enc] && exec("iconv -f "enc" -t utf-8 "qa(f)" > "qa(iconvf(f))) == 0) {
                g_encoding[f] = "iconv";
            } else {
                ERR("iconv "enc" to utf-8 failed - decode using awk - slower");
                g_skipiconv[enc] = 1;
            }
        }
    }

    enc = g_encoding[f];

    if (enc == "iconv") {
        #INF("iconv begin");
        code = ( getline t < iconvf(f) );
        #INF("iconv :"t);
    } else {
        code = ( getline t < f );
    }

    if (code > 0) {

        t = html_decode(t);

        if (enc != "utf-8" && enc != "iconv" ) {
            if (enc == "windows-1251") {
                t = utf8_encode(t,g_cp1251);
            } else if (enc == "windows-1250") {
                t = utf8_encode(t,g_cp1250);
            } else if (enc == "windows-1252" || enc == "iso-8859-1") {
                t = utf8_encode(t,g_cp1252);
            } else if (enc == "windows-1253") {
                t = utf8_encode(t,g_cp1253);
            } else if (enc == "windows-1254" ) {
                t = utf8_encode(t,g_cp1254);
            } else if (enc == "iso-8859-9") {
                INF("using windows-1254 for iso-8859-9");
                t = utf8_encode(t,g_cp1254);
            } else if (enc == "iso-8859-2") {
                t = utf8_encode(t,g_8859_2);
            } else if (enc == "iso-8859-7") {
                t = utf8_encode(t,g_8859_7);
            } else if (enc != "utf-8") {
                WARNING("unknown encoding ["enc"] changing to utf-8");
                t = utf8_encode(t,g_utf8);
                g_encoding[f] = "utf-8";
            }
        }
        line[1] = t;
    }
    return code;
}


function enc_close(f) {
    if (g_encoding[f] == "iconv") {
        if (is_file(iconvf(f))) {
            close(iconvf(f));
            rm(iconvf(f));
        }
    }
    delete g_encoding[f];
    close(f);
}

# TODO only check xml encoding for first line.
function get_encoding(f,\
enc,line,code,n) {


    if (is_file(iconvf(f))) {
        enc = "iconv";
    } else if (index(f,".json")) {
        enc = "utf-8";
    } else {
        while ( enc == "" && n < 20 &&  (code = ( getline line < f )) > 0) {

            line=tolower(line);

            if (index(line,"encoding") || index(line,"charset")) {

                enc=subexp(line,"(encoding|charset)=\"?([-_a-z0-9]+)[\"> ]",2);

                if (index(line,"<?xml")) break;


            } else if (index(line,"</head>") || index(line,"<body>")) break;

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
    if (enc == "") {
        #enc = "iso-8859-1";
        enc = "utf-8"; # google pages assumed to be utf-8 ?
    }

    if (enc) INF(code"Encoding:" enc);
    return enc;
}


#map bytes x80 to xFF to UTF8
function map_codepage_to_utf8(out,utf8_list,\
i,codes,num,u,ch) {

    num=split(utf8_list,codes,",");
    for(i = 0 ; i<= 127 ; i++ ) {
        ch=u=g_chr[i];
        out[ch] = u;
    }

    for(i = 1 ; i < num ; i+=2 ) {
        ch = g_chr[hex2dec(codes[i])];
        u = html_to_utf8("&#x"codes[i+1]";");
        out[ch] = u;
        if (codes[i] == "00F6" ) DEBUG("00F6 maps to char["ch"] = utf8 ["u"]");
    }
}

# Check engine 0=bad 1 or more = good
function engine_check(url,\
ret) {
    ret = scan_page_for_matches(url url_encode("\"The Spy Who Loved Me\" imdb"),"imdb","[\"']http://[^/]+imdb[/.a-z]+tt0076752/?[\"']",1);
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
# IN fixed_text, - fixed text to help speed up scan - use SUBSEP seperator for multiple items
# IN regex to scan for
# IN max = max number to match 0=all
# IN count_or_order = 0=count 1=order
# OUT matches = array of matches index by the match text value = number of occurences.
# return number of matches
function scan_page_for_matches(url,fixed_text,regex,max,cache,referer,count_or_order,matches,verbose,\
f,line,count,linecount,remain,is_imdb,matches2,i,text_num,text_arr,scan) {

#    if (index(url,"yahoo") && index(url,"2010") && index(url,"site:imdb.com")) {
#        verbose=1; # Debug line edit as required
#    } else {
#        DEBUG("disable me !!!!!!!!!!");
#    }

    delete matches;
    id1("scan_page_for_matches["url"]["fixed_text"]["regex"]");
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
            if (is_imdb && index(line[1],"/Title?") ) {
                gsub(/\/Title\?/,"/tt",line[1]);
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

                if (count_or_order) {
                    # Get all ordered matches. 1=>test1, 2=>text2 , etc.
                    linecount = get_regex_pos(line[1],regex,remain,matches2);
                    if (verbose) {
                        DEBUG("linecount = "linecount" remain="remain);
                        dump(0,"matches2",matches2);
                    }
                    # 
                    # Append the matches2 array of ordered regex matches. Index by order.
                    for(i = 1 ; i+0 <= linecount+0 ; i++) {
                        matches[count+i] = matches2[i];
                        if (verbose) DEBUG("xx match ["matches[count+i]"]");
                    }
                } else {
                    # Get all occurence counts text1=m , text2=n etc.
                    linecount = get_regex_counts(line[1],regex,remain,matches2);
                    if (verbose) {
                        DEBUG("linecount2 = "linecount" remain="remain);
                        dump(0,"matches2",matches2);
                    }
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
        enc_close(f);
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

    if (index(html,"<")) {

        if (index(html,"b>") || index(html,"em>") || index(html,"strong>") ) {

            gsub(/<\/?(b|em|strong)>/,"",html); #remove emphasis tags - assuming tag as no attributes. small risk here
        }

        if (index(html,"wbr")) {
            # Note yahoo will sometimes break an imdb tag with a space and wbr eg. tt1234 <wbr>567
            gsub(/ *<\/?wbr>/,"",html); #remove emphasis tags
        }

        if (index("/>",html)) {
            gsub(/<[a-z]+ ?\/>/,"",html); #remove single tags eg <wbr />
        }
    }
    return html;
}

function urladd(a,b) {
    return a (index(a,"?") ? "&" : "?" ) b;
}

# encode a string to utf8
function utf8_encode(text,codepage,\
text2,part,parts,count) {

    if (ascii8(text)) {
        count = chop(text,"["g_8bit"]+",parts);
        for(part=2 ; part-count <= 0 ; part += 2 ) {
            text2=text2 parts[part-1] utf8_encode2(parts[part],codepage);
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
function utf8_encode2(text,codepage,\
i,text2,ll) {

    ll=length(text);
    for(i = 1 ; i <= ll ; i++ ) {
        text2 = text2 codepage[substr(text,i,1)];
    }
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
        g_chr["amp"] = "&";
        g_chr["quot"] = "\"";
        g_chr["lt"] = "<";
        g_chr["gt"] = ">";
        g_chr["nbsp"] = " ";
        g_chr["szlig"] = code_to_utf8(0xdf); #g_chr[0xC3] g_chr[0x9F]; http://www.fileformat.info/format/w3c/htmlentity.htm

        # Regex to find utf8 trailing chars
        g_utf8_trail_re = "["g_chr[0x80]"-"g_chr[0xBF]"]+";

    }
}

function html_decode(text,\
parts,part,count,code,newcode,text2) {
    if (g_chr[32] == "" ) {
        decode_init();
    }

    # Change all numeric items
    text = html_to_utf8(text);

    if (index(text,"&") && index(text,";")) {

        count = chop(text,"[&][a-zA-Z]+;",parts);

        for(part=2 ; part-count < 0 ; part += 2 ) {

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
            text2=text2 parts[part-1] newcode;
        }
        text2 = text2 parts[count];
        if (text != text2 ) {
            text = text2;
        }
    }
    return text;
}

function html_to_utf8(text,\
ret,num,i,parts,code) {

    if (index(text,"&#")) {
        decode_init();
        num = chop(text,"[&](#[0-9]{1,4}|#[Xx][0-9a-fA-F]{1,4});",parts);
        for(i = 2 ; i < num ; i+=2) {
            if (tolower(substr(parts[i],1,3)) == "&#x" ) {
                # &#x123;
                code = hex2dec(substr(parts[i],4,length(parts[i])-4));
            } else {
                # &#123;
                code = substr(parts[i],3,length(parts[i])-3);
            }
            ret = ret parts[i-1] code_to_utf8(code+0);
        }
        ret = ret parts[num];
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
