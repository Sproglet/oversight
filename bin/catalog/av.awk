# Set audio video details.
# This will eventually use mediainfo, but for the time being it will guess based on filename , filesize and extension
# So this function should not try to be too clever as it can get thrown by very high or low bitrates.

#format will be cN=codec,wN=width,hN=height,fN=fps where N=stream number.

function set_videosource(minfo,
f,i,tag,src) {
    f=tolower(minfo["mi_media"]);
    if (hash_size(g_sources)  == 0 ) {
        g_source_num = split(g_settings["catalog_source_keywords"],g_sources,",");
    }
    for(i = 1 ; i<= g_source_num ; i++ ) { 
        tag ="\\<"tolower(g_sources[i])"\\>";
        if (f ~ tag ) {
            src = g_sources[i];
            break;
        }
        tag = tolower(g_settings["catalog_source_keywords_"g_sources[i]]);
        gsub(/,/,"|",tag);
        if (tag != "") {
            tag = glob2re(tag);
            if (f ~ "\\<"tag"\\>") {
                src = g_sources[i];
                break;
            }
        }

    }
    if (src) {
        minfo["mi_videosource"] = src;
        INF("Video Source = "src);
    }
}

function set_av_details(minfo,
f,video,audio,dim,hrs,i,out) {

    f=tolower(minfo["mi_media"]);

    # watch out for movies with pal in the title. Fix by using mediainfo 

    # set codec

    if (f ~ /[hx]\.?264\>/ ) {
        video["c0"] = "h264";
    } else if (f ~ /\<(xvid|divx)\>/ ) {
        video["c0"] = "mpeg4";
    } else if (f ~ /\<(ntsc|pal|dvdr?|dvd5)\>/ ) {
        video["c0"] = "mpeg2";
    }

    #guess codec from container !?!?
    else if (f ~ /\<avi$\>/ ) video["c0"] = "mpeg4"; 
    else if (f ~ /\<(mkv|m2ts)$\>/ ) video["c0"] = "h264"; 


    # set dimensions - pure guesswork

    if (f ~ /\<1080p?\>/ ) {
        dim=3;
    } else if (f ~ /\<720p?\>/ ) {
        dim=2;
    } else if (f ~ /\<ntsc\>/ ) {
        dim=0;
    } else if (f ~ /\<pal|r5\>/ ) {
        dim=1;
    } else {
        hrs = minfo["mi_runtime"] / 60.0 ;
        if (!hrs) hrs = 1.5; 

        if (f ~ /mkv$/) {
            # guess based on file size / length - assume > 4G/hr = 1080p 
            dim = 2;
            if (minfo["mi_mb"] / hrs  > 4000 ) {
                dim = 3;
            } 
        } else if (f ~ /iso$/) {
            # this could be bd iso or sd iso. Guess sd iso - assume > 4G hr is bd?
            if (video["c0"] == "h264") {
                dim = 2;
            } else if (video["c0"] == "mpeg2") {
                dim = 0;
            } else if (minfo["mi_mb"] / hrs  > 4000 ) {
                dim = 2;
                video["c0"]= "h264";
            }  else {
                dim = 0;
                video["c0"]= "mpeg2";
            }
        }
    }

    if (!video["c0"]) {
        video["c0"] = "mpeg2";
    }

    if (dim  == 3) {
        video["w0"] = 1920 ; video["h0"] = 1080; video["f0"] = 24;
    } else if (dim  == 2) {
       video["w0"] = 1280 ; video["h0"] = 720; video["f0"] = 24;
    } else if (dim  == 1) {
       video["w0"] = 768 ; video["h0"] = 576; video["f0"] = 25; # PAL
    } else {
       video["w0"] = 640 ; video["h0"] = 480; video["f0"] = 29.97; # NTSC
    }
    
    out="";
    for(i in video) {
        out=out","i"="video[i];
    }
    INF("Video info"out);

    minfo["mi_video"]=substr(out,2);
}
