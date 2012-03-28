# Some of these functions will eventually be replaced by plugin code.

#Return reference to an internal poster location. eg
# ovs:<field>"/"ovs_Terminator_1993.jpg
#
# ovs: indicates internal database path. 
# field is a sub folder. All internal posters are stored under "ovs:"POSTER"/"...
function internal_poster_reference(field_id,minfo,\
poster_ref,id) {

    #Tv show images are stored by season.
    if (minfo["mi_category"] == "T" ) {
        id = imdb(minfo);
        if (id) {
            poster_ref = "imdb_" id "_" minfo["mi_season"];
        }
    }
    if (poster_ref == "") {
        #images are now stored by index.db id - not imdbid - to allow different cuts of the same movie to have distinct images.
        poster_ref = minfo["mi_ovsid"];
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

            exec("jpg_fetch_and_scale "g_fetch_images_concurrently" "PID" "script_arg" "qa(url)" "qa(internal_path)" "wget_args" ");
            #exec(OVS_HOME"/bin/jpg_fetch_and_scale "g_fetch_images_concurrently" "PID" "script_arg" "qa(url)" "qa(internal_path)" "wget_args" &");
            g_image_inspected[internal_path]=1;
        }
    }

    id0(poster_ref);

    return poster_ref;
}

#ALL# for poster search use the iamge API bing or yahoo have one. To be implemented - maybe

#movie db - search direct for imdbid then extract picture
#id = imdbid
function defaultPosters(minfo) {

    #DEBUG("IGNORING POSTER INFORMATION !!! COMMENT OUT THIS LINE IF YOU SEE IT!!!"); minfo["mi_poster"] = minfo["mi_fanart"] = "";

    if (getting_poster(minfo,1)) {
       search_bing_image(minfo,"mi_poster","Tall");
    }
    if (getting_fanart(minfo,1)) {
       search_bing_image(minfo,"mi_fanart","Wide");
    }
}

function search_bing_image(minfo,fld,aspect,\
query,qnum,q) {

    if (minfo[fld] == "") {
        id1("search_bing_image "fld);

        #query[++qnum]=imdb(minfo); # tt searches find lots of screencaps - stick to title searches
        query[++qnum]="\""minfo["mi_title"]"\" +"minfo["mi_year"];
        query[++qnum]=minfo["mi_title"]" "minfo["mi_year"];


        for(q = 1 ; q<= qnum ; q++ ) {
            # For some reason Bing api does not let you specify both Large and Medium - you get 0 results,
            minfo[fld] = bing_image(minfo,aspect,query[q],"Large");
            if (minfo[fld] != "" ) break;
            minfo[fld] = bing_image(minfo,aspect,query[q],"Medium");
            if (minfo[fld] != "" ) break;
        }
        id0(minfo[fld]);
    }
}

function bing_image(minfo,aspect,query,size,\
json,url,imageUrl,i,prefix,sc,best,finalUrl) {
    aspect = capitalise(aspect);
    url=g_search_bing_api"Appid="g_api_bing;
    url = url "&sources=image";
    url = url "&Image.Count=20";
    url = url "&Image.Filters=Size:"capitalise(size); # Small Large Medium
    url = url "&Image:Filters=Aspect:"capitalise(aspect); # Wide , Tall
    url = url "&query="url_encode(query);

    id1("bing image "aspect" "query);

    if (fetch_json(url,"img",json)) {

        i = 0 ;
        prefix="SearchResponse:Image:Results#";
        do {
            i++;
            imageUrl = json[prefix i ":MediaUrl"];
            if (imageUrl == "") {
               INF("no image for "prefix i ":MediaUrl");
               break;
            }
            sc[imageUrl] = img_score(json,prefix i,aspect,minfo);
        } while(1);
    }
    if (bestScores(sc,best,0) > 0) {
        finalUrl = firstIndex(best);
    }

    id0(finalUrl);

    return finalUrl;
}

# only keep alnum.
function collapse(t) {
    return tolower(gensub(/[^[:alnum:]]+/,"","g",t));
}


function img_score(json,key,aspect,minfo,\
sc,imageUrl,w,h,imdbid,title,img_title,url_file_title) {

    title = collapse(minfo["mi_title"]);

    img_title = collapse(json[key ":Title"]);
    imageUrl = json[key ":MediaUrl"];

    url_file_title = collapse(gensub(/.*\//,"",1,imageUrl));

    w = json[key ":Width"];
    h = json[key ":Height"];
    imdbid = imdb(minfo);
    sc = 0;

    do { # break block

        if (aspect == "Tall" ) {

           if (!check_aspect(w,h,0.674)) break;
           sc = 1;
           if (w < 500) sc *= 0.8;

        } else if (aspect == "Wide" ) {

           if (check_aspect(w,h,1.7777)) { # common pc wallpaper size
               sc = 1;
           } else if (check_aspect(w,h,1.3333)) {
               sc = 0.9;
           } else if (check_aspect(w,h,1.25)) { # common pc wallpaper size
               sc = 0.8;
           } else {
               break;
           }
           if (w < 1000) sc *= 0.8;
            if ((imageUrl ~ "(cover)" )) sc *= 0.9; #cover sites usually have dvd covers in fanart sizes

        }  
        if (imageUrl ~ "png$") sc*=.7; 
        if (imageUrl ~ "gif$") sc*=.8;
        
        if (!url_online(imageUrl,1,1)) {
            INF("url is offline?");
            sc = 0;
            break;
        }

        if (imageUrl ~ "//[-.[:alnum:]]*(img|image|photo)[-.[:alnum:]]*.com" ) {
            sc *= 0.7;
        }
        #if (!(imageUrl ~ "impawards" )) sc *= 0.9;
        if (!(imageUrl ~ "(movie|film|guide|tv|poster)" )) sc *= 0.9;

        if (!index(img_title,title)) sc *=0.7;
        if (!index(url_file_title,title)) sc *=0.7;

        if (!index(img_title,imdbid)) sc *=0.7;
        if (!index(imageUrl,imdbid)) sc *=0.7;

    } while(0);

    INF("image score="sc" for "w"x"h" "imageUrl" "img_title" "url_file_title);
    return sc;
}

function check_aspect(w,h,ratio,\
ar) {
    ar = ratio * h / w - 1;
    ar = ar * ar;
    if (ar < 0.04) {
        #INF("good aspect "w","h" wrt. "ratio" = "ar);
        return 1;
    } 
    return 0;
}

