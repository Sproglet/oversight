#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <assert.h>
#include <dirent.h>

#include "util.h"
#include "vasprintf.h"
#include "gaya_cgi.h"
#include "hashtable.h"
#include "oversight.h"
#include "config.h"
#include "network.h"

// Mounted and working
#define MOUNT_STATUS_OK "1"

// Unpingable or something else nasty
#define MOUNT_STATUS_BAD "0"

// In mtab but might be good or stale
#define MOUNT_STATUS_IN_MTAB "?"

// Not in mtab
#define MOUNT_STATUS_NOT_IN_MTAB "-"

int ping_link(char *link);
int check_accessible(char *path,int timeout_secs);
static int nmt_mount_share(char *path,char *current_mount_status);

/*
 * Attempt to quickly mount a file or if the file is not available fail quickly.
 */
static struct hashtable *mount_points = NULL;

struct hashtable *mount_points_hash()
{
    return mount_points;
}

void set_mount_status(char *p,char *val) {
    char *current = hashtable_search(mount_points,p);
    if (current == NULL) {
        HTML_LOG(1,"Adding mount point [%s] = %s",p,val);
        hashtable_insert(mount_points,STRDUP(p),val);
    } else if ( STRCMP(current,val) != 0) {
        hashtable_remove(mount_points,p,1);
        HTML_LOG(1,"mount point [%s] status changed from [%s] to [%s]",p,current,val);
        hashtable_insert(mount_points,STRDUP(p),val);
    }
}

char *network_mount_point(char *file) {

    char *path = NULL;
    if (!util_starts_with(file,NETWORK_SHARE)) { 
        return NULL;
    }
    // file =  "/opt/sybhttpd/localhost.drives/NETWORK_SHARE/abc/def.avi 

    char *rest = strchr(file+strlen(NETWORK_SHARE)+1,'/');
    // eg end of "/opt/sybhttpd/localhost.drives/NETWORK_SHARE/abc/<<<
    //
    if (rest ) {
        ovs_asprintf(&path,"%.*s",rest-file,file);
    }   
TRACE ; HTML_LOG(1,"network_mount_point [%s]=[%s]",file,path);

    return path;
}


// Only look at the standard NMT NETWORK media mount points.
void get_mount_points() {
    if (mount_points == NULL) {
        mount_points = string_string_hashtable(16); //let the OS clean this up at the end

#if 1
        FILE *fp = fopen("/etc/mtab","r");
        if (fp) {
#define BUFSIZE 200
            char buf[BUFSIZE];
            while(fgets(buf,BUFSIZE,fp) != NULL) {
                char *p = strstr(buf,NETWORK_SHARE);
                if (p) {

                    char *q = p+strlen(NETWORK_SHARE);

                    //seek to end of path skipping escapes.
                    while(*q) {
                       if (*q == '\\' && q[1] ) {
                           q += 2; 
                       } else if (*q == ' ') {
                           break;
                       } else {
                           q++;
                       }
                    }

                    *q = '\0';

                    set_mount_status(p,MOUNT_STATUS_IN_MTAB);
                }

            }
            fclose(fp);
        }
#endif
    }
}


// 1 if tried mounting before - status returned via mount_status
char *get_mount_status(char *path) {

    char *result;
    if (mount_points == NULL) {

        get_mount_points();
    }
    result = hashtable_search(mount_points,path) ;
    if (result == NULL) {
        result = MOUNT_STATUS_NOT_IN_MTAB;
    }
    HTML_LOG(3,"mount status [%s]=[%s]",path,result);
    return result;
}




// See also nmt_mount_quick()
int nmt_mount (char *file)
{

    int result = 0;

    if (!util_starts_with(file,NETWORK_SHARE)) { 

        // Assume anything not in NETWORK_SHARE is mounted.
        result = 1;

    } else {

TRACE;
        char *path = network_mount_point(file);

        if (path) {

TRACE;
            // check if weve tried mounting. result is set if we have.
            char *mount_status = get_mount_status(path);
TRACE;
            
            if (STRCMP(mount_status,MOUNT_STATUS_OK) == 0) {
TRACE;
                result = 1;
            } else if (STRCMP(mount_status,MOUNT_STATUS_BAD) == 0) {
TRACE;
                result = 0;
            } else {
TRACE;
                // MOUNT_STATUS_IN_MTAB or MOUNT_STATUS_NOT_IN_MTAB

                result = nmt_mount_share(path,mount_status);
            }

            FREE(path);
        }

    }
    if (result != 1) {
        HTML_LOG(0,"Error: mount [%s] = [%d]",file,result);
    }
    return result;
}

int cidr(char *mask) {
    unsigned int bytes[4];
    sscanf(mask,"%u.%u.%u.%u",bytes,bytes+1,bytes+2,bytes+3);
    int c = 0;
    int i = 0;
    for (i = 0 ; i < 4 ; i++ ) {
        switch(bytes[i]) {
            case 255: c += 8 ; break;
            case 254: c += 7 ; break;
            case 252: c += 6 ; break;
            case 248: c += 5 ; break;
            case 240: c += 4 ; break;
            case 224: c += 3 ; break;
            case 192: c += 2 ; break;
            case 128: c += 1 ; break;
        }
    }
    return c;
}

// input host based link
// output ip based link
char *wins_resolve(char *link) {
    char *iplink = NULL;
    static char *nbtscan_outfile = NULL;
    static char *workgroup = NULL;
    static int updated_wins_file=0;

    HTML_LOG(0,"wins_resolve[%s]",link);
    if (workgroup == NULL ) {
       workgroup = setting_val("workgroup");
    }
    HTML_LOG(0,"wins_resolve workgroup[%s]",workgroup);

    if (nbtscan_outfile  == NULL ) {
        ovs_asprintf(&nbtscan_outfile,"%s/conf/wins.txt",appDir());
    }
    HTML_LOG(0,"wins_resolve nbtscan_outfile[%s]",nbtscan_outfile);

    if (!updated_wins_file && ( !exists(nbtscan_outfile) || file_age(nbtscan_outfile) > 3600 ) ) {
        char *cmd;
        ovs_asprintf(&cmd,"nbtscan %s/%d > '%s/conf/wins.txt' && chown nmt:nmt '%s/conf/wins.txt'",
                setting_val("eth_gateway"),
                cidr(setting_val("eth_netmask")),
                appDir(),appDir());
        if (system(cmd) == 0) {
            updated_wins_file=1;
        } else {
            HTML_LOG(0,"ERROR wins_resolve running [%s]",cmd);
        }
    }

    char *host = link + 6;
    char *hostend = strchr(host,'/');
    *hostend = '\0';


    FILE *fp = fopen(nbtscan_outfile,"r");
    if (fp) {
#define WINS_BUFSIZE 200
        char buf[WINS_BUFSIZE];
        while(fgets(buf,WINS_BUFSIZE,fp)) {
            HTML_LOG(0,"Check wins %s",buf);
            char *p=NULL;

#define IGNORE_WORKGROUP 1
#ifdef IGNORE_WORKGROUP
            // Ignore the workgroup
            p = strchr(buf,'\\');
            if (p != NULL) {
                p++;
            }
#else
            // Look for host in output of nbtscan (which is run by the catalog process)
            // 1.1.1.1<space>WORKGROUP\host<space>
            if ((p=delimited_substring(buf," ",workgroup,"\\",0,0)) != NULL) {
                p += 1+strlen(workgroup);
            }
#endif
            if (p) {
                if (util_starts_with(p,host) && p[strlen(host)] == ' ' ) {
                    // found it - get ip address from the start.
                    char *sp = strchr(buf,' ');
                    if (sp) {
                        ovs_asprintf(&iplink,"smb://%.*s/%s",sp-buf,buf,hostend+1);
                        break;
                    }
                }
            }
        }
        fclose(fp);
    }

    *hostend = '/';
    HTML_LOG(0,"New ip based link = [%s]",iplink);
    return iplink;
}

// given share name find the name of the pflash setting that holds it
// eg servname3, servname6 and return the last character '3' or '6'
static char get_link_index(char *share_name) {

    char *key=STRDUP("servname?");
    char *last=key+strlen(key)-1;
    char index = 0;
    char c;

    // Look for variable servname1, servname2 etc.
    // for one that is called "abc"
    for(c = '0' ; c <= '9' ; c++ ) {
        *last = c;
        if (STRCMP(setting_val(key),share_name) == 0) {
            index = c;
            break;
        }
    }
    FREE(key);

HTML_LOG(0,"mount index [%d=%c]",index,index);

    return index;

}

// extract user from eg servlink2=nfs://192.168.88.13:/space&smb.user=nmt&smb.passwd=;1234;
char *get_link_user(char *servlink) {
    char *user=NULL;
    if (strstr(servlink,"smb.user")) {
        user = regextract1(servlink,"smb.user=([^&]+)",1,0);
    }
TRACE ;
    HTML_LOG(1,"mount user [%s]",user);
    return user;
}

// extract password from eg servlink2=nfs://192.168.88.13:/space&smb.user=nmt&smb.passwd=;1234;
char *get_link_passwd(char *servlink) {
    char *passwd=NULL;
    if (strstr(servlink,"smb.passwd")) {
        passwd = regextract1(servlink,"smb.passwd=([^&]+)",1,0);
    }
TRACE ;
    HTML_LOG(1,"mount passwd [%s]",passwd);
    return passwd;
}

// given servlink2=nfs://192.168.88.13:/space&smb.user=nmt&smb.passwd=;1234;
// extract 
char *get_pingable_link(char *servlink) {

    char *amp;

    char *result=NULL;
    char *link=NULL;

    HTML_LOG(0,"get pingable link for [%s]",servlink);

    amp = strchr(servlink,'&');
    if (amp) {

        ovs_asprintf(&link,"%.*s",amp-servlink,servlink);

TRACE ; HTML_LOG(0,"mount link [%s]",link);

        if (ping_link(link) ) {
            result = link;
        } else if (util_starts_with(link,"smb:") && strchr(link,'.') == NULL) {
            char  *iplink = wins_resolve(link);
            FREE(link);
            link = iplink;

            if (link != NULL) {
                if (ping_link(link) ) {
                    result = link;
                }
            }
        }
    }
    if (result != link ) {
        FREE(link);
    }
    HTML_LOG(0,"pingable link [%s]",result);
    return result;
}

char *get_mount_command(char *link,char *path,char *user,char *passwd) {

   char *cmd = NULL;
   char *log;

   ovs_asprintf(&log,"%s/logs/mnterr.log",appDir());

    if (util_starts_with(link,"nfs://")) {

        // iplink = nfs://host:/share
        // mount -t -o soft,nolock,timeo=10 host:/share /path/to/network
        ovs_asprintf(&cmd,"mkdir -p \"%s\" 2> \"%s\" && mount -o soft,nolock,timeo=10 \"%s\" \"%s\" 2> \"%s\"",
                path,log,link+6,path,log);

    } else if (util_starts_with(link,"smb://")) {

        // link = smb://host/share
        // mount -t cifs -o username=,password= //host/share /path/to/network
        ovs_asprintf(&cmd,"mkdir -p \"%s\" 2> \"%s\" && mount -t cifs -o username=%s,password=%s \"%s\" \"%s\" 2> \"%s\"",
                path,log,user,passwd,link+4,path,log);
    } else {
        html_log(0,"Dont know how to mount [%s]",link);
    }
    FREE(log);
    return cmd;
}
 
//
// Return 1 if path can be mounted.
// the share name is the folder after the NETWORK_SHARE sub folder.
// Then the nmt settings are inspected to get the full mount definition.
//
// First try to ping the host.
//
// If that doesnt work and using SMB/cifs then try to use nbtscan to
// resolve wins names.
//
// The current_mount_status is passed in case the share is alread present
// in /etc/mtab. If it is not - try to mount it, if it is, then check for timeouts.
static int nmt_mount_share(char *path,char *current_mount_status)
{
    int result = 0;

    char *share_name = util_basename(path);
TRACE ; HTML_LOG(0,"mount path=[%s] share_name [%s]",path,share_name);
    // eg "abc"

TRACE ;
    char index = get_link_index(share_name);

    if (index) {
        char *key;
        ovs_asprintf(&key,"servlink%c",index);

        char *serv_link = setting_val(key);
        // Look for corresponding variable servlinkN
TRACE ; HTML_LOG(0,"mount servlink [%s]",serv_link);
        FREE(key);

        char *link = get_pingable_link(serv_link);

        if (!link) {

            set_mount_status(path,MOUNT_STATUS_BAD);
TRACE;
        } else if (STRCMP(current_mount_status,MOUNT_STATUS_NOT_IN_MTAB) == 0) {

            char *user = get_link_user(serv_link);
            char *passwd = get_link_passwd(serv_link);

            char *cmd = get_mount_command(link,path,user,passwd);

            FREE(user);
            FREE(passwd);

            if (cmd ) {
                long t = time(NULL);
                int mount_result = util_system(cmd);

                // Mount prints detailed error to stdout but just returns exit codes
                // 0(OK) , 1(Bad args?) OR  0xFF00 (Something else).
                // So we cant tell exactly why it failed without scraping
                // stdout.
                // Eg if mount display 'Device or resource Busy' it doesnt return EBUSY(16)
                //
                // Also trying to use native mount() function is hard work
                // (it does kernel space work but not other stuff - update /etc/mtab etc?)
                //
                // So I've taken a big liberty here and assumed that if the mount returns
                // immediately that it worked.
                // This obviously is risky of the mount failed due to bad parameters.
                switch(mount_result) {
                case 0:
                    result = 1;
                    break;
                case 0xFF00:
                    // some mount error occured. If it occured in less than 1 second
                    // just assume its a device busy and continue happily assuming it
                    // is already mounted.
                    if (time(NULL) - t <= 5) {
                        HTML_LOG(0,"mount [%s] failed quickly - assume all is ok",cmd);
                        result = 1;
                    } else {
                        HTML_LOG(0,"mount [%s] failed slowly - assume the worst ",cmd);
                        result = 0;
                    }
                    break;
                default:
                    HTML_LOG(0,"mount [%s] unknown error - assume the worst ",cmd);
                    //even though mount failed - add it to the list to avoid repeat attempts.
                    result = 0;
                }
                set_mount_status(path,(result ? MOUNT_STATUS_OK : MOUNT_STATUS_BAD));

                FREE(cmd);
            }

        } else if (STRCMP(current_mount_status,MOUNT_STATUS_IN_MTAB) == 0) {
            // Its pingable but now we check it is accessible.
            result = check_accessible(path,5);
        } else {
            // shouldnt get here
            assert(0);
        }
        FREE(link);
    }
    FREE(share_name);
    return result;
}

// Now we have done a ping check and the device should be mounted.
// It is still possible it is a stale mtab entry - eg nfs server is stopped.
int check_accessible(char *path,int timeout_secs)
{
    int result = 0;
    time_t now = time(NULL);
    DIR *d = opendir(path);
    closedir(d);
    if (time(NULL) - now > timeout_secs) {
        HTML_LOG(0,"mount [%s] too slow to open folder",path);
    } else {
        HTML_LOG(0,"mount [%s] ok",path);
        result = 1;
    }
    set_mount_status(path,(result ? MOUNT_STATUS_OK : MOUNT_STATUS_BAD));
    return result;
}

// link = smb://host/... or nfs://host:/...
int ping_link(char *link)
{
    char *host=NULL;
    char *end=NULL;
    int result = 0;
    int port;
    static long connect_millis=-1;
TRACE;

    if (connect_millis == -1 ) {
        connect_millis = 58;
        char *p = oversight_val("ovs_nas_timeout");
        if ( util_strreg(p,"^[0-9]+$",0) ) {
            connect_millis = atol(p);
        }
    }

    if (util_starts_with(link,"nfs://") ) {
        link += 6;
        end = strchr(link,':');
        port=111; // assume nfs host has portmapper

    } else if (util_starts_with(link,"smb://")) {
        link += 6;
        end = strchr(link,'/');
        port=445; //assume SMB on port 445
    }
    if (end) {
        ovs_asprintf(&host,"%.*s",end-link,link);

        result = (connect_service(host,connect_millis,port) == 0);

        HTML_LOG(0,"ping link [%s] host[%s] = %d",link,host,result);
        FREE(host);

    }
    return result;
}

// Return true if the file is mounted. This also caches the last 
// network path checked to avoid the hash lookup in nmt_mount()->get_mount_status() .
int nmt_mount_quick (char *file)
{
    static int last_result = -1;
    static char *last_mount_point = NULL;

    // always assume local and USB devices are auto-mounted by the system
    if (!util_starts_with(file,NETWORK_SHARE) ) {
        return 1;
    } 

    // Check if the file has the same mount point as previous file if so - same result
    if (last_mount_point) {
        if (util_starts_with(file,last_mount_point) ) {
            return last_result;
        } else {
            //if the mount point is different - clear previous results to force mount attempt.
            FREE(last_mount_point);
            last_mount_point = NULL;
        }
    }
    if (last_mount_point == NULL) {

        // Try to mount the file - this will first ping the device to avoid timeouts.
        last_result = nmt_mount(file);
        last_mount_point = STRDUP(file);

        char *p = network_mount_point(file);
        if (p) {
            // Terminate at mount path but include trailing '/' to avoid shares matching substrings of other shares
            last_mount_point[strlen(p)+1] = '\0';
            FREE(p);
        }
    }
    return last_result;
}
