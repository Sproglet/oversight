
function get_mounts(mtab,\
line,parts,f) {
    if ("@ovs_fetched" in mtab) return;
    f="/etc/mtab";
    while((getline line < f ) > 0) {
        split(line,parts," ");
        mtab[parts[2]]=1;
        if(LG)DEBUG("mtab ["parts[2]"]");
    }
    mtab["@ovs_fetched"] = 1;
}

function get_settings(settings,\
line,f,n,v,n2,v2) {
    if ("@ovs_fetched" in settings) return;

    f="/tmp/setting.txt";
    while((getline line < f ) > 0) {
        n=index(line,"=");
        v=substr(line,n+1);
        n=substr(line,1,n-1);

        if ( index(n,"_BKMRK_") == 0) {

            settings[n] = v;
            if(LG)DEBUG("setting ["n"]=["v"]");

            # if servname2=nas then store servname_nas=2 - this makes it easier to
            # find the corresponding servlink2 using the share name.
            if (n ~ /^servname/ ) {

                n2="SHARE_"v;
                v2="servlink"substr(n,length(n));

                settings[n2] = v2;
                if(LG)DEBUG("setting *** ["n2"]=["v2"]");

            } else if (n ~ /^netfs_name/ ) {

                n2="SHARE_"v;
                v2="netfs_url"substr(n,length(n));

                settings[n2] = v2;
                if(LG)DEBUG("setting *** ["n2"]=["v2"]");
            }
        }
    }
    close(f);
#    for(line in settings) {
#        if (line ~ /^servname[0-9]+$/ ) {
#            g_share_name_to_folder[settings[line]] = "/opt/sybhttpd/localhost.drives/NETWORK_SHARE/"settings[line];
#        }
#    }
    settings["@ovs_fetched"] = 1;
}

# Extract user , password from link
function parse_link(link,details,\
parts,i,x,bits) {

    if (link == "") return 0;

    details["proto"] = gensub(/:.*/,"",1,link);
    if (index(link,"://[")) {
        # New style
        #link is smb://[user=pwd64enc]host/path
        #link is nfs://[user=pwd64enc]host/path
        if (match(link,"\\[([^*=]*)([*=])([^]]*)\\]",bits)) {
            details["link"]=substr(link,1,RSTART-1) substr(link,RSTART+RLENGTH);
            details["smb.user"]=bits[1];
            if (bits[2] == "*") {
                details["proto"] = "nfs-tcp";
            }
            details["smb.passwd"]=decode64(bits[3]);
        }
    } else {
        # Old style
        #link is smb:/host/path&smb.user=fred&smb.passwd=pwd
        #link is nfs:/host:/path/&smb.user=fred&smb.passwd=pwd

        split("link="link,parts,"&");
        # now have link=nfs:/..../ , smb.user=fred ,  smb.passwd=pwd


        if (!(3 in parts)) return 0;
        for(i in parts) {
            split(parts[i],x,"=");
            details[x[1]]=x[2];
        }
    }
    return 1;
}

function is_mounted(path,\
f,result,line) {
    result = 0;
    f = "/etc/mtab";
    while ((getline line < f) > 0) {
        if (index(line," "path" cifs ") || index(line," "path" nfs ")) {
           result=1;
           break;
       }
    }
    close(f);
    if(LG)DEBUG("is mounted "path" = "result);
    return 0+ result;
}

# We could use smbclient.cgi but this would unmount other drives.
function nmt_mount_share(s,settings,\
path,link_details,p,usr,pwd,lnk) {

    path = g_mount_root s;

    if (is_mounted(path)) {

        if(LG)DEBUG(s " already mounted at "path);
        return path;
    }

    get_settings(settings);

    if(LG)DEBUG("share "s" = "settings[settings["SHARE_"s]]);
    if (parse_link(settings[settings["SHARE_"s]],link_details) == 0) {
        if(LG)DEBUG("Could not find "s" in shares");
        return "";
    }

    lnk=link_details["link"];
    usr=link_details["smb.user"];
    pwd=link_details["smb.passwd"];

    if(LG)DEBUG("Link for "s" is "lnk);

    # Always try to resolve windows names first - to avoid OpenDNS ipaddress issues.
    if ( is_smb_host_link(lnk)) {
       if(LD)DETAIL("Trying to resolve windows name before mounting");
       lnk = wins_resolve(lnk);
    }

    p = mount_link(link_details["proto"],path,lnk,usr,pwd) ;

    return p;
}

function is_smb_host_link(lnk) {
   return ( index(lnk,"smb:") && match(lnk,"[0-9]\\.[0-9]") == 0);
}

function mount_link(proto,path,link,user,password,\
remote,cmd,result,t,opt) {

    remote=link;

    sub(/^(nfs(-tcp|):\/\/|smb:)/,"",remote);

    if (link ~ "^nfs") {

        # re-insert colon after hostname - needed for new-style links
        sub(/:?\//,":/",remote);

        opt="soft,nolock,timeo=10";
        if (proto == "nfs-tcp" ) {
            opt = opt",proto=tcp";
        }
        cmd = "mkdir -p "qa(path)" && mount -o "opt" "qa(remote)" "qa(path);

    } else if (link ~ "^smb:") {

        opt ="username="user",password="password;
        cmd = "mkdir -p "qa(path)" && mount -t cifs -o "opt" "qa(remote)" "qa(path);
        #cifs mount on nmt doesnt like blank passwords
        sub(/ username=,/," username=x,",cmd);

    } else {

        ERR("Dont know how to mount "link);
        path="";
    }
    t = systime();
    result = exec(cmd);
    if (result == 255 && systime() - t <= 1 ) {
        # if you try to double mount smb share you get error 255. Which is a meaningless error really.
        # Just assume it worked if it happened quickly.
        if(LD)DETAIL("Ignoring mount error");
        result=0;
    }
    if (result) {
        ERR("Unable to mount share "link);
        path="";
    }
    return path;
}

#Resolve wins name
function wins_resolve(link,\
line,host,ip,newlink,hostend,cmd) {

    cmd = "nbtscan "g_tmp_settings["eth_gateway"]"/24 > "qa(g_winsfile);
    if(LG)DEBUG(cmd);
    exec(cmd);;
    if(match(link,"smb://[^/]+")) {
        hostend=RSTART+RLENGTH;
        host=toupper(substr(link,7,RLENGTH-6));
        
        while (newlink == "" && (getline line < g_winsfile ) > 0 ) {
            if (index(line," "g_tmp_settings["workgroup"]"\\"host" ")) {
                if(LD)DETAIL("Found Wins name "line);
                if (match(line,"^[0-9.]+")) {
                    ip=substr(line,RSTART,RLENGTH);
                    newlink="smb://"ip substr(link,hostend);
                    break;
                }
            } else {
                if(LG)DEBUG("skip "line);
            }
        }
        close(g_winsfile);
    }
    if(LD)DETAIL("new link "newlink);
    return newlink;
}

# Given a path without a / find the mounted path
function nmt_get_share_path(f,\
share,share_path,rest) {
    if (f ~ "^/") {
        if(LG)DEBUG("nmt_get_share_path "f" unchanged");
        return f;
    } else {
        share=g_share_map[f];
        rest=f;
        sub(/^[^\/]+/,"",rest);
        share_path=g_share_name_to_folder[share] rest;

        if(LG)DEBUG("nmt_get_share_path "f" = "share_path);
        return share_path;
    }
}
