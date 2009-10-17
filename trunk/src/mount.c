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
int nmt_mount_share(char *path,char *current_mount_status);

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
    } else if ( strcmp(current,val) != 0) {
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




int nmt_mount (char *file)
{

    int result = 0;

HTML_LOG(0,"mount [%s]",file);

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
            
            if (strcmp(mount_status,MOUNT_STATUS_OK) == 0) {
                result = 1;
            } else if (strcmp(mount_status,MOUNT_STATUS_BAD) == 0) {
                result = 0;
            } else {
                // MOUNT_STATUS_IN_MTAB or MOUNT_STATUS_NOT_IN_MTAB

                result = nmt_mount_share(path,mount_status);
            }

            FREE(path);
        }

    }
    HTML_LOG(0,"mount [%s] = [%d]",file,result);
    return result;
}

// link = smb://host/share
//
char *wins_resolve(char *link) {
    char *iplink = NULL;
    static char *nbtscan_outfile = NULL;
    static char *workgroup = NULL;

    if (workgroup == NULL ) {
       workgroup = setting_val("workgroup");
    }
    if (nbtscan_outfile  == NULL ) {
        ovs_asprintf(&nbtscan_outfile,"%s/conf/wins.txt",appDir());
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
            char *p;
            // Look for host in output of nbtscan (which is run by the catalog process)
            // 1.1.1.1<space>WORKGROUP\host<space>
            if ((p=strstr(buf,workgroup)) != NULL && p[-1] == ' ') {
                p += strlen(workgroup);
                if (*p == '\\' && util_starts_with(p+1,host) ) {
                    p += strlen(host)+1;
                    if (*p == ' ' ) {
                        // found it - get ip address from the start.
                        char *sp = strchr(buf,' ');
                        if (sp) {
                            *sp = '\0';
                            ovs_asprintf(&iplink,"smb://%s/%s",buf,hostend+1);
                            break;
                        }
                    }
                }
            }
        }
    }
    fclose(fp);

    *hostend = '/';
    HTML_LOG(0,"New ip based link = [%s]",iplink);
    return iplink;
}

int nmt_mount_share(char *path,char *current_mount_status)
{
    int result = 0;

    char *share_name = util_basename(path);
TRACE ; HTML_LOG(0,"mount path=[%s] share_name [%s]",path,share_name);
    // eg "abc"

    char *key=STRDUP("servname?");
    char *last=key+strlen(key)-1;
    char index = 0;
    char c;

    // Look for variable servname1, servname2 etc.
    // for one that is called "abc"
    for(c = '0' ; c <= '9' ; c++ ) {
        *last = c;
        if (strcmp(setting_val(key),share_name) == 0) {
            index = c;
            break;
        }
    }
TRACE ; HTML_LOG(1,"mount index [%d=%c]",index,index);
    if (index) {
        FREE(key);
        ovs_asprintf(&key,"servlink%c",index);

        char *serv_link = setting_val(key);
        // Look for corresponding variable servlinkN
TRACE ; HTML_LOG(1,"mount servlink [%s]",serv_link);
        FREE(key);

        ovs_asprintf(&key,"link%c",index);
        char *link = setting_val(key);
        char *iplink = link;
TRACE ; HTML_LOG(1,"mount link [%s]",link);

        int reachable = 0;
        if (ping_link(link) ) {
            reachable = 1;
        } else {
            if (util_starts_with(link,"smb:") && strchr(link,'.') == NULL) {
                iplink = wins_resolve(link);
                if (ping_link(iplink) ) {
                    reachable = 1;
                }
            }
        }


        if (!reachable) {

            set_mount_status(path,MOUNT_STATUS_BAD);

        } else if (strcmp(current_mount_status,MOUNT_STATUS_NOT_IN_MTAB) == 0) {

            char *user=regextract1(serv_link,"smb.user=([^&]+)",1,0);
TRACE ; HTML_LOG(1,"mount user [%s]",user);

            char *passwd=regextract1(serv_link,"smb.passwd=([^&]+)",1,0);
TRACE ; HTML_LOG(1,"mount passwd [%s]",passwd);

            char *cmd = NULL;
            if (util_starts_with(iplink,"nfs://")) {

                // iplink = nfs://host:/share
                // mount -t -o soft,nolock,timeo=10 host:/share /path/to/network
                ovs_asprintf(&cmd,"mkdir -p \"%s\" && mount -o soft,nolock,timeo=10 \"%s\" \"%s\"",
                        path,iplink+6,path);

            } else if (util_starts_with(iplink,"smb://")) {

                // link = smb://host/share
                // mount -t cifs -o username=,password= //host/share /path/to/network
                ovs_asprintf(&cmd,"mkdir -p \"%s\" && mount -t cifs -o username=%s,password=%s \"%s\" \"%s\"",
                        path,user,passwd,iplink+4,path);
            } else {
                html_error("Dont know how to mount [%s]",serv_link);
            }
            if (cmd) {

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
                //


                switch(mount_result) {
                case 0:
                    result = 1;
                    break;
                case 0xFF00:
                    // some mount error occured. If it occured in less than 1 second
                    // just assume its a device busy and continue happily assuming it
                    // is already mounted.
                    if (time(NULL) - t <= 5) {
                        HTML_LOG(0,"mount [%s] failed quickly - assume all is ok",serv_link);
                        result = 1;
                    } else {
                        HTML_LOG(0,"mount [%s] failed slowly - assume the worst ",serv_link);
                        result = 0;
                    }
                    break;
                default:
                    HTML_LOG(0,"mount [%s] unknown error - assume the worst ",serv_link);
                    //even though mount failed - add it to the list to avoid repeat attempts.
                    result = 0;
                }
                set_mount_status(path,(result ? MOUNT_STATUS_OK : MOUNT_STATUS_BAD));

                FREE(cmd);
            }

            FREE(user);
            FREE(passwd);

        } else if (strcmp(current_mount_status,MOUNT_STATUS_IN_MTAB) == 0) {
            // Its pingable but now we check it is accessible.
            result = check_accessible(path,5);
        } else {
            // shouldnt get here
            assert(0);
        }
        if (iplink != link ) {
            FREE(iplink);
        }

    }
    FREE(key);
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
    char *host;
    char *end=NULL;
    int result = 0;
TRACE;
    if (util_starts_with(link,"nfs://") ) {
        link += 6;
        end = strchr(link,':');

    } else if (util_starts_with(link,"smb://")) {
        link += 6;
        end = strchr(link,'/');
    }
    if (end) {
        ovs_asprintf(&host,"%.*s",end-link,link);

        result = (ping(host,0) == 0);

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

    // Check if the file has the same mount point as previous file if so - smae result
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
