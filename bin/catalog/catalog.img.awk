# Some of these functions will eventually be replaced by plugin code.

#Return reference to an internal poster location. eg
# ovs:<field>"/"ovs_Terminator_1993.jpg
#
# ovs: indicates internal database path. 
# field is a sub folder. All internal posters are stored under "ovs:"POSTER"/"...
function internal_poster_reference(field_id,minfo,\
poster_ref) {
    poster_ref = minfo["mi_title"]"_"minfo["mi_year"];
    gsub("[^-_&" g_alnum8 "]+","_",poster_ref);
    if (minfo["mi_category"] == "T" ) {
        poster_ref = poster_ref "_" minfo["mi_season"];
    } else {
        poster_ref = poster_ref "_" minfo["mi_imdb"];
    }
    #"ovs:" means store in local database. This abstract path is used because when using
    #crossview in oversight jukebox, different posters have different locations.
    #It also allows the install folder to be changed as it is not referenced within the database.
    return "ovs:" field_id "/" g_settings["catalog_poster_prefix"] poster_ref ".jpg";
}

function getting_fanart(minfo,verbose) {
    return 0+ getting_image(minfo,FANART,GET_FANART,UPDATE_FANART,verbose);
}

function getting_poster(minfo,verbose) {
    return 0+ getting_image(minfo,POSTER,GET_POSTERS,UPDATE_POSTERS,verbose);
}

function getting_image(minfo,image_field_id,get_image,update_image,verbose,\
poster_ref,internal_path) {

    poster_ref = internal_poster_reference(image_field_id,minfo);
    internal_path = getPath(poster_ref,minfo["mi_folder"]);

    if (internal_path in g_image_inspected) {
        if(verbose) INF("Already looked at "poster_ref);
        return 0;
    } else if (update_image) {
        if(verbose) INF("Force Update of "poster_ref);
        return 1;
    } else if (!get_image) {
        if(verbose) INF("Skipping "poster_ref);
        return 0;
    } else if (hasContent(internal_path)) {
        if(verbose) INF("Already have "poster_ref" ["internal_path"]");
        return 0;
    } else {
        if(verbose) INF("Getting "poster_ref);
        return 1;
    }
}
    
# Check for locally held poster otherwise fetch one. This may be held locally(with media)
# or internally in a common folder.
# Note if poster may be url<tab>referer_url
function download_image(field_id,minfo,mi_field,\
    url,poster_ref,internal_path,urls,referer,wget_args,get_it,script_arg,default_referer) {

    url = minfo[mi_field];
    id1("download_image["field_id"]["url"]");
    if (url != "") {

        #Posters are all held in the same folder so
        #need a name that is unique per movie or per season

        #Note for internal posters the reference contains a sub path.
        # (relative to database folder ovs: )
        poster_ref = internal_poster_reference(field_id,minfo);
        internal_path = getPath(poster_ref,minfo["mi_folder"]);

        #DEBUG("internal_path = ["internal_path"]");
        #DEBUG("poster_ref = ["poster_ref"]");
        #DEBUG("new poster url = "url);

        get_it = 0;
        if (field_id == POSTER) {
            get_it = getting_poster(minfo,1);
        } else if (field_id == FANART) {
            get_it = getting_fanart(minfo,0);
        }

        INF("getting image = "get_it);

        if (get_it ) {


            #create the folder.
            preparePath(internal_path);

            split(url,urls,"\t");
            url=urls[1];
            referer=urls[2];

            # -t retries - oversight runs the command twice so halve number of retries.
            # -w time between retries.
            # -T network timeouts
            wget_args=g_wget_opts g_art_timeout;

            DEBUG("Image url = "url);
            default_referer = get_referer(url);
            if (referer == "" ) {
                referer = default_referer;
            }
            if (referer != "" ) {
                DEBUG("Referer = "referer);
                wget_args = wget_args " --referer=\""referer"\" ";
            }
            wget_args = wget_args " -U \""g_user_agent"\" ";

            # Script to fetch poster and create sd and hd versions
            if (field_id == POSTER) {
                script_arg="poster";
            } else {
                script_arg="fanart";
            }


            rm(internal_path,1);
            exec(APPDIR"/bin/jpg_fetch_and_scale "g_fetch_images_concurrently" "PID" "script_arg" "qa(url)" "qa(internal_path)" "wget_args" &");
            g_image_inspected[internal_path]=1;
        }
    }

    id0(poster_ref);

    return poster_ref;
}

#ALL# To be implemented - maybe
#ALL# # q = query terms
#ALL# # wdivh = required width div height ratio (approx)
#ALL# # dimAfterLink is whether dimension occurs after link in the search results.
#ALL# # dimreg = regex that matches dimensions 
#ALL# function bingimg(q,minw,minh,wdivh,dimAfterLink,dimreg,\
#ALL# url,f,imgurl,txt,html,numhtml,i,w,h,zero,dim,href_regex,len) {
#ALL#     url="http://www.bing.com/images/search?q="q"&FORM=BIFD";
#ALL#     #href_regex="http:[-_%A-Za-z0-9.?&:=]+(jpg|png)";
#ALL#     href_regex="http://[^\"<>]+(jpg|png)";
#ALL# 
#ALL#     f = getUrl(url,"image",0);
#ALL#     if (f) {
#ALL#         FS="\n";
#ALL#         while((getline txt < f) > 0 && imgurl == "" ) {
#ALL#             numhtml = split(txt,html,dimreg);
#ALL#             if (numhtml -1 > 0 ) INF("Image search found "numhtml" images");
#ALL#             len=0;
#ALL#             #loop through html segments - looking at each dimension split.
#ALL#             #as we are looking at the splitsnote we dont need to loop on the last item
#ALL#             for(i = 1 ; i - numhtml < 0 && imgurl == "" ; i++ ) {
#ALL# 
#ALL#                 #track the length as we go along so we know how many chars matched each dimension regex from split
#ALL#                 len += length(html[i]);
#ALL# 
#ALL#                 #extract the dimension
#ALL#                 dim = substr(txt,len+1);
#ALL#                 if (match(dim,"^"dimreg)) {
#ALL#                     dim=substr(dim,1,RLENGTH);
#ALL#                     len += RLENGTH;
#ALL#                     INF("Got dimension ["dim"]");
#ALL#                 } else {
#ALL#                     ERR("Expected dimension here ["substr(text,len+1,10)"...]");
#ALL#                     continue;
#ALL#                 }
#ALL#                 # Check dimensions
#ALL#                 w = h = 0;
#ALL#                 if (match(dim,"^[0-9]+")) w=substr(dim,1,RLENGTH);
#ALL#                 if (match(dim,"[0-9]+$")) h=substr(dim,RSTART);
#ALL#                 if (w-minw < 0 || h-minh < 0 ) { INF("Skipping size "dim) ; break }
#ALL#                 zero = (h * wdivh / w) - 1 ;
#ALL#                 if (zero * zero > 0.1 ) { INF("Skipping a/r "dim) ; break ; }
#ALL# 
#ALL#                 #now try to extract the image
#ALL#                 if (dimAfterLink) {
#ALL#                     #get first image url in the next html segment
#ALL#                     if (match(html[i+1],href_regex) ) {
#ALL#                         imgurl=substr(html[i+1],RSTART,RLENGTH);
#ALL#                     }
#ALL#                 } else {
#ALL#                     #get the last image url in the current html segment
#ALL#                     if (match(html[i+1],".*"href_regex)) {
#ALL#                         if ( match(substr(html[i+1],RSTART,RLENGTH) , href_regex"$" )) {
#ALL#                             imgurl=substr(html[i+1],RSTART,RLENGTH);
#ALL#                         }
#ALL#                     }
#ALL#                 }
#ALL#                 INF("Found ["imgurl"] with dimension "dim);
#ALL#             }
#ALL#         }
#ALL#     }
#ALL# }
#ALL# 

#movie db - search direct for imdbid then extract picture
#id = imdbid
function getNiceMoviePosters(minfo,imdb_id,\
poster_url,backdrop_url) {


    if (getting_poster(minfo,1) || getting_fanart(minfo,1)) {

        DEBUG("Poster check imdb_id = "imdb_id);

        #poster_url = bingimg(minfo["mi_title"]" "minfo["mi_year"]"+site%3aimpawards.com",300,450,2/3,0,"[0-9]+ x [0-9]+");

            # Get posters from TMDB usiong the API. Unfortunately this doesnt expose poster rating.
        if (poster_url == "" && getting_poster(minfo,1) ) {
            poster_url = get_moviedb_img(imdb_id,"poster","mid");
        }

        if (getting_fanart(minfo,1) ) {
            backdrop_url = get_moviedb_img(imdb_id,"backdrop","original");
        }

        if (poster_url == "") {
            poster_url = get_motech_img(minfo);
        }
        INF("movie poster ["poster_url"]");
        minfo["mi_poster"]=poster_url;

        INF("movie backdrop ["backdrop_url"]");
        minfo["mi_fanart"]=backdrop_url;
    }
}

function get_motech_img(minfo,\
referer_url,url,url2) {
    #if (1) {
    referer_url = "http://www.motechposters.com/title/"minfo["mi_motech_title"]"/";
    #} else {
    #search_url="http://www.google.com/search?q=allintitle%3A+"minfo["mi_title"]"+("minfo["mi_year"]")+site%3Amotechposters.com";
    #referer_url=scanPageFirstMatch(search_url,"http://www.motechposters.com/title[^\"]+",0);
    #}
    DEBUG("Got motech referer "referer_url);
    if (referer_url != "" ) {
        url2=scanPageFirstMatch(referer_url,"/posters","/posters/[^\"]+jpg",0);
        if (url2 != ""  && index(url2,"thumb.jpg") == 0 ) {
            url="http://www.motechposters.com" url2;

            url=url"\t"referer_url;
            DEBUG("Got motech poster "url);
        } 
    }
    return url;
}

# search :
#
#<OpenSearchDescription xmlns:opensearch="http://a9.com/-/spec/opensearch/1.1/">
#  <opensearch:Query searchTerms="tt0418279"/>
#    <opensearch:totalResults>1</opensearch:totalResults>
#      <movies>
#        <movie>
#          <name>Transformers</name>
#            <images>
#              <poster id="30030">
#                <image url="http://images....org/posters/30030/Transformers_v3.jpg" size="original"/>
#                <image url="http://images....org/posters/30030/Transformers_v3_thumb.jpg" size="thumb"/>
#                <image url="http://images....org/posters/30030/Transformers_v3_mid.jpg" size="mid"/>
#                <image url="http://images....org/posters/30030/Transformers_v3_cover.jpg" size="cover"/>
#              </poster>
#
function get_moviedb_img(imdb_id,type,size,\
search_url,txt,xml,f,url,url2) {

    search_url="http://api.themoviedb.org/2.1/Movie.imdbLookup/en/xml/"g_api_tmdb"/"imdb_id;

# the first one is the one with the highest ratings. At present rating order is NOT returned using 
# getImages so using imdbLookup instead.

    id1("get_moviedb_img "imdb_id" "type" "size);
    f=getUrl(search_url,"moviedb",0);

    #scan_xml_single_child(f,"/OpenSearchDescription/movies/movie/images",tagfilters,xmlout,\
    if (f != "") {
        FS="\n";
        while((getline txt < f) > 0 ) {

            if (index(txt,"<image")) {

                delete xml;
                parseXML(txt,xml);
                if (xml["/image#type"] == type && xml["/image#size"] == size ) {
                    url2=url_encode(html_decode(xml["/image#url"]));
                    if (url_state(url2) == 0) {
                        url = url2;
                        break;
                    }
                }
            }

        }
        close(f);
    }
    id0(url);
    return url;
}

# Split a line at regex boundaries.
# used by get_regex_counts
# IN s - line to split
# IN regex - regular expression
# OUT parts - index 1,2,3.. values text,match1,text,match2,...
# RET number of parts.
function chop(s_in,regex,parts,\
flag,i,s) {
    #first find split text that doesnt occur in the string.
    #flag="=#z@~";
    flag=SUBSEP;

    # insert the split text around the regex boundaries

    s = s_in;

    if (gsub(regex,flag "&" flag , s )) {
        # now split at boundaries.
        i = split(s,parts,flag);
        if (i % 2 == 0) ERR("Even chop of ["s"] by ["flag"]");
    } else {
        i = 1;
        delete parts;
        parts[1] = s_in;
    }
    return i+0;
}




# Find all occurences of a regular expression within a string, and return in an array.
# IN Line to match against.
# IN regex to match with.
# IN max = max occurences (0 = all)
# OUT matches is updated with (text=>num occurrences)
# RET total number of occurences.
function get_regex_counts(line,regex,max,matches) {
    return 0+get_regex_count_or_pos("c",line,regex,max,matches);
}
# Find all occurences of a regular expression within a string, and return in an array.
# IN mode : c=count matches  p=return match positions.
# IN Line to match against.
# IN regex to match with.
# IN max = max occurences (0 = all)
# OUT rtext is updated with (order=>match text)
# OUT rstart  is updated with (order -> start pos)
# RET total number of occurences.
function get_regex_pos(line,regex,max,rtext,rstart) {
    return 0+get_regex_count_or_pos("p",line,regex,max,rtext,rstart);
}


# Find all occurences of a regular expression within a string, and return in an array.
# IN mode : c=count matches  p=return match positions.
# IN Line to match against.
# IN regex to match with.
# IN max = max occurences (0 = all)
# mode=c:
# OUT rtext is updated with (mode=c:text=>num occurrences mode=p:order=>match text)
# mode=p:
# OUT rtext is updated with (order=>match text)
# OUT rstart  is updated with (order -> start pos)
# OUT total number of occurences.
function get_regex_count_or_pos(mode,line,regex,max,rtext,rstart,\
count,fcount,i,parts,start) {
    count =0 ;

    delete rtext;
    delete rstart;

    fcount = chop(line,regex,parts);
    start=1;
    for(i=2 ; i-fcount <= 0 ; i += 2 ) {
        count++;
        if (mode == "c") {
            rtext[parts[i]]++;
        } else {
            rtext[count] = parts[i];

            start += length(parts[i-1]);
            rstart[count] = start;
            start += length(parts[i]);
        }
        if (max+0 > 0 ) {
            if (count - max >= 0) {
                break;
            }
        }
    }

    dump(3,"get_regex_count_or_pos:"mode,rtext);

    return 0+count;
}



