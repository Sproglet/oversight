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

    if (getting_poster(minfo,1)) {
       search_bing_image(minfo,"mi_poster","Tall",700,300);
    }
    if (getting_fanart(minfo,1)) {
       search_bing_image(minfo,"mi_fanart","Wide",1280,600);
    }
}

function search_bing_image(minfo,fld,aspect,w1,w2,\
query,qnum,q) {

    if (minfo[fld] == "") {
        id1("search_bing_image "fld);

        query[++qnum]=imdb(minfo);
        query[++qnum]=minfo["mi_title"]" "minfo["mi_year"];


        for(q = 1 ; q<= qnum ; q++ ) {
            minfo[fld] = bing_image(aspect,query[q],"Large",w1,w2);
            if (minfo[fld] != "" ) break;
            minfo[fld] = bing_image(aspect,query[q],"Medium",w1,w2);
            if (minfo[fld] != "" ) break;
        }
        id0(minfo[fld]);
    }
}

function bing_image(aspect,query,size,w1,w2,\
json,url,imageUrl,i,prefix,w,h,finalUrl) {
    aspect = capitalise(aspect);
    url=g_search_bing_api"Appid="g_api_bing;
    url = url "&sources=image";
    url = url "&Image.Count=20";
    url = url "&Image.Filters=Size:"capitalise(size); # Small Large Medium
    url = url "&Image:Filters=Aspect:"capitalise(aspect); # Wide , Tall
    url = url "&query="url_encode(query);

    id1("bing image "aspect" "w1"-"w2" "query);

    if (fetch_json(url,"img",json)) {

        i = 0 ;
        prefix="SearchResponse:Image:Results#";
        do {
            i++;
            imageUrl = json[prefix i ":MediaUrl"];
            w = json[prefix i ":Width"];
            h = json[prefix i ":Height"];
            INF("image "w"x"h" "imageUrl);
            if (imageUrl == "") {
               INF("no image for "prefix i ":MediaUrl");
               break;
            }
            if (imageUrl !~ "jpg$" ) {
               DEBUG("Skipping non jpg");
            } else if (imageUrl ~ "//[-.[:alnum:]]*(img|image|photo)[-.[:alnum:]]*.com" && imageUrl !~ "(movie|film)" ) {
               DEBUG("Skipping image site");
            } else {
                if (w+0 > w2+0) {
                    if (aspect == "Tall" ) {
                       if (!check_aspect(w,h,500,740)) continue;
                    } else if (aspect == "Wide" ) {
                       if (!check_aspect(w,h,1920,1080) && !check_aspect(w,h,640,480)) continue;
                    }  

                    # Check url is online
                    if (w+0 > w1+0 || finalUrl == "") {
                        if (!url_online(imageUrl,1,1)) {
                            INF("url is offline?");
                            continue;
                        }
                    }

                    if ((w+0 >= w1+0) ) {
                        # Image is wider than w1 - return this result
                        finalUrl = imageUrl;
                        INF("found large image "finalUrl);
                        break;
                    } else if (finalUrl == ""  ) { 
                        # Image is wider than w2 - keep first result but keep looking
                        finalUrl = imageUrl;
                        INF("found first medium image "finalUrl);
#                    } else {
#                        DEBUG("found another medium image "imageUrl);
                    }
                }
            }
        } while(1);
        gsub(/\\/,"",finalUrl);
    }

    id0(finalUrl);

    return finalUrl;
}

function check_aspect(w,h,w1,h1,\
ar) {
    ar = ( w * h1 ) / ( h * w1 ) - 1;
    ar = ar * ar;
    if (ar < 0.1) {
        INF("good aspect "w","h" wrt. "w1","h1" = "ar);
        return 1;
    } 
    return 0;

}

