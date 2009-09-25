#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include "util.h"
#include "vasprintf.h"
#include "gaya_cgi.h"
#include "hashtable.h"
#include "oversight.h"
#include "config.h"
#include "network.h"

int ping_link(char *link);

/*
 * Attempt to quickly mount a file or if the file is not available fail quickly.
 */
static struct hashtable *mount_points = NULL;

struct hashtable *mount_points_hash()
{
    return mount_points;
}

void add_mount_point(char *p,char *val) {
    if (hashtable_search(mount_points,p) == NULL) {
        HTML_LOG(1,"Adding mount point [%s] = %s",p,val);
        hashtable_insert(mount_points,STRDUP(p),val);
    } else {
        HTML_LOG(1,"Already added mount point [%s]",p);
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

// No need to actually read mtab here - we will try to mount items as we read the database file.
#if 0
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

                    add_mount_point(p,"1");
                }

            }
            fclose(fp);
        }
#endif
    }
}

// 1 if tried mounting before - status returned via mount_status
int tried_mounting(char *path,int *mount_status) {

    char *mount_status_str;
    if (mount_points == NULL) {
        get_mount_points();
    }
    mount_status_str = hashtable_search(mount_points,path) ;

    if (mount_status_str == NULL) {
        HTML_LOG(1,"%s is not mounted",path);
        return 0;
    } else if (*mount_status_str == '0') {
        HTML_LOG(1,"already tried to mount %s",path);
        *mount_status = 0;
        return 1;
    } else {
        HTML_LOG(3,"already mounted %s",path);
        *mount_status = 1;
        return 1;
    }
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
            if (tried_mounting(path,&result)) {

                // Nothing here - just for breakpoints / trace
TRACE;

            } else {

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
TRACE ; HTML_LOG(1,"mount link [%s]",link);

                    if (!ping_link(link)) {

                        add_mount_point(path,"0");

                    } else {

                        char *user=regextract1(serv_link,"smb.user=([^&]+)",1,0);
    TRACE ; HTML_LOG(1,"mount user [%s]",user);

                        char *passwd=regextract1(serv_link,"smb.passwd=([^&]+)",1,0);
    TRACE ; HTML_LOG(1,"mount passwd [%s]",passwd);

                        char *cmd = NULL;
                        if (util_starts_with(link,"nfs://")) {

                            // link = nfs://host:/share
                            // mount -t -o soft,nolock,timeo=10 host:/share /path/to/network
                            ovs_asprintf(&cmd,"mkdir -p \"%s\" && mount -o soft,nolock,timeo=10 \"%s\" \"%s\"",
                                    path,link+6,path);

                        } else if (util_starts_with(link,"smb://")) {

                            // link = smb://host/share
                            // mount -t cifs -o username=,password= //host/share /path/to/network
                            ovs_asprintf(&cmd,"mkdir -p \"%s\" && mount -t cifs -o username=%s,password=%s \"%s\" \"%s\"",
                                    path,user,passwd,link+4,path);
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
                            add_mount_point(path,(result?"1":"0"));

                            FREE(cmd);
                        }

                        FREE(user);
                        FREE(passwd);
                    }

                }
                FREE(key);
                FREE(share_name);
            }
            FREE(path);
        }

    }
    HTML_LOG(0,"mount [%s] = [%d]",file,result);
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

        result = ping(host,0);

        FREE(host);

    }
    return result;
}

// Return true if the file is mounted. This also caches the last 
// network path checked to avoid the hash lookup in nmt_mount()->tried_mounting() .
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
