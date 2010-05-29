#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <assert.h>
#include <dirent.h>
#include <ctype.h>

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

    if (util_starts_with(p,NETWORK_SHARE)) {
        p += strlen(NETWORK_SHARE);
    }

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

        HTML_LOG(0,"getting mount points...");
        mount_points = string_string_hashtable(16); //let the OS clean this up at the end

        FILE *fp = fopen("/etc/mtab","r");
        if (fp) {
#define BUFSIZE 999
            char buf[BUFSIZE];

            PRE_CHECK_FGETS(buf,BUFSIZE);

            while(fgets(buf,BUFSIZE,fp) != NULL) {

                HTML_LOG(0,"mount[%s]",buf);

                CHECK_FGETS(buf,BUFSIZE);


                char *p = strstr(buf,NETWORK_SHARE);
                if (p) {

#define MAX_SHARE_NAME_LEN 100
                    char share_name[MAX_SHARE_NAME_LEN];
                    char *s = share_name;

                    char *q = p+strlen(NETWORK_SHARE);

                    //seek to end of path skipping escapes.
                    while(*q) {
                       if (*q == '\\' ) {
                          if (isdigit(q[1]) && isdigit(q[2]) && isdigit(q[3])) {
                              // octal
                              int c;
                              q++;
                              if (sscanf(q,"%03o",&c) ) {
                                  q += 3;
                                  *s++ = c;
                              } else {
                                  HTML_LOG(0,"Error parsing octal [%s]",q);
                              }
                          } else if (q[1] == 'x') {
                              // hex
                              int c;
                              q+=2;
                              if (sscanf(q,"%2x",&c) ) {
                                  q += 2;
                                  *s++ = c;
                              } else {
                                  HTML_LOG(0,"Error parsing hex [%s]",q);
                              }

                          } else {
                              // normal escape
                              q++;
                              *s++ = *q++;
                          }
                       } else if (*q == ' ') {
                           break;
                       } else {
                           *s++ = *q++;
                       }
                    }
                    assert(s < share_name + MAX_SHARE_NAME_LEN);
                    *s = '\0';


                    HTML_LOG(0,"mtab share name = [%s]",share_name);

                    set_mount_status(share_name,MOUNT_STATUS_IN_MTAB);
                }

            }
            fclose(fp);
        }
        html_hashtable_dump(0,"mount points",mount_points);
        HTML_LOG(0,"got mount points");
    }
}


// returns :
// MOUNT_STATUS_OK  : All working and verified files are accessible.
// MOUNT_STATUS_BAD : Tried to mount but takes too long to access. usually Stale nfs
// MOUNT_STATUS_IN_MTAB : Path is mounted but oversight has not tried to access it yet. NAS could be off.
// MOUNT_STATUS_NOT_IN_MTAB : Path is not in mtab.
//
char *get_mount_status(char *path) {

    char *result;
    if (mount_points == NULL) {

        get_mount_points();
    }

    if (util_starts_with(path,NETWORK_SHARE)) {
        path += strlen(NETWORK_SHARE);
    }

    result = hashtable_search(mount_points,path) ;
    if (result == NULL) {
        result = MOUNT_STATUS_NOT_IN_MTAB;
    }
    HTML_LOG(0,"mount status [%s]=[%s]",path,result);
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

            } else if (STRCMP(mount_status,MOUNT_STATUS_NOT_IN_MTAB) == 0) {

                result = nmt_mount_share(path,mount_status);

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

    if (!updated_wins_file && ( !exists(nbtscan_outfile) || file_age(nbtscan_outfile) > 60*60*24 ) ) {
        char *cmd;
        int c = cidr(setting_val("eth_netmask"));
        // Avoid scanning too many ips 
        // we can just scan a /21 subnet in about 25 secs.
        if (c < 21 ) c = 21; 
        ovs_asprintf(&cmd,"nbtscan -T 1 %s/%d > '%s/conf/wins.txt' && chown nmt:nmt '%s/conf/wins.txt'",
                setting_val("eth_gateway"),
                c,
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

        PRE_CHECK_FGETS(buf,WINS_BUFSIZE);

        while(fgets(buf,WINS_BUFSIZE,fp)) {

            CHECK_FGETS(buf,WINS_BUFSIZE);

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
                if (util_starts_with_ignore_case(p,host) && p[strlen(host)] == ' ' ) {
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
        //HTML_LOG(0,"Checking [%s](%s) = (%s)",key,setting_val(key),share_name);
        if (STRCMP(setting_val(key),share_name) == 0) {
            index = c;
            break;
        }
    }
    FREE(key);

    return index;

}


static char *get_link_option(char *servlink,char *option) {
    char *p;
    char *result=NULL;

    if ((p=delimited_substring(servlink,"&",option,"=",1,0)) != NULL ) {
        p += strlen(option) + 1;
        char *q = p ;
        while (*q != '&' && *q != '\0' )  q++;
        ovs_asprintf(&result,"%.*s",q-p,p);
    }
TRACE ;
    HTML_LOG(0,"mount %s=[%s]",option,result);
    return result;
}

// extract user from eg servlink2=smb://192.168.88.13:/space&smb.user=nmt&smb.passwd=;1234;
char *get_link_user(char *servlink) {
    return get_link_option(servlink,"smb.user");
}

// extract password from eg servlink2=smb://192.168.88.13:/space&smb.user=nmt&smb.passwd=;1234;
char *get_link_passwd(char *servlink) {
    return get_link_option(servlink,"smb.passwd");
}

// given servlink2=nfs://192.168.88.13:/space&smb.user=nmt&smb.passwd=;1234;
// extract 
char *get_pingable_link(char *servlink) {

    char *amp;

    char *result=NULL;
    char *link=NULL;

    HTML_LOG(1,"get pingable link for [%s]",servlink);

    amp = strchr(servlink,'&');
    if (amp) {

        ovs_asprintf(&link,"%.*s",amp-servlink,servlink);

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
    HTML_LOG(0,"pingable link = [%s]",result);
    return result;
}

char *get_mount_command(char *link,char *path,char *user,char *passwd) {

   char *cmd = NULL;
   char *log;
   char *host = strstr(link,"://");

   ovs_asprintf(&log,"%s/logs/mnterr.log",appDir());
   if (host) {

       host +=3;

       if (util_starts_with(link,"nfs://")) {

            // iplink = nfs://host:/share
            // mount -t -o soft,nolock,timeo=10 host:/share /path/to/network
            ovs_asprintf(&cmd,
                "mkdir -p \"%s\" 2> \"%s\" && mount -o soft,nolock,timeo=10 \"%s\" \"%s\" 2> \"%s\"",
                path,log,host,path,log);

        } else if (util_starts_with(link,"nfs-tcp://")) {

            // iplink = nfs://host:/share
            // mount -t -o soft,nolock,timeo=10 host:/share /path/to/network
            ovs_asprintf(&cmd,
                "mkdir -p \"%s\" 2> \"%s\" && mount -o soft,nolock,timeo=10,proto=tcp \"%s\" \"%s\" 2> \"%s\"",
                path,log,host,path,log);

        } else if (util_starts_with(link,"smb://")) {

            // link = smb://host/share
            // mount -t cifs -o username=,password= //host/share /path/to/network
            ovs_asprintf(&cmd,"mkdir -p \"%s\" 2> \"%s\" && mount -t cifs -o username=%s,password=%s \"//%s\" \"%s\" 2> \"%s\"",
                    path,log,user,passwd,host,path,log);
        } else {
            html_log(0,"Dont know how to mount [%s]",link);
        }
    } else {
        html_log(0,"Dont know how to mount host [%s]",link);
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
TRACE ; HTML_LOG(0,"mount path=[%s] share_name [%s] current status [%s]",path,share_name,current_mount_status);
    // eg "abc"

TRACE ;
    char index = get_link_index(share_name);

    if (index) {
        char *key;
        ovs_asprintf(&key,"servlink%c",index);

        char *serv_link = setting_val(key);
        // Look for corresponding variable servlinkN
TRACE ;
		
		HTML_LOG(1,"mount servlink [%s]",serv_link);
        FREE(key);

        char *link = get_pingable_link(serv_link);

        if (!link) {

            set_mount_status(path,MOUNT_STATUS_BAD);
TRACE;
        } else if (STRCMP(current_mount_status,MOUNT_STATUS_NOT_IN_MTAB) == 0) {
TRACE;

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
TRACE;
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
TRACE;
    int result = 0;
    time_t now = time(NULL);
    DIR *d = opendir(path);
    if (d) closedir(d);
    if (d && ( time(NULL) - now <= timeout_secs)) {
        HTML_LOG(0,"mount [%s] ok",path);
        result = 1;
    } else {
        HTML_LOG(0,"mount [%s] too slow to open folder",path);
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
    static long connect_millis=-1;
TRACE;

    if (connect_millis == -1 ) {
        connect_millis = 58;
        char *p = oversight_val("ovs_nas_timeout");
        if ( util_strreg(p,"^[0-9]+$",0) ) {
            connect_millis = atol(p);
        }
    }

    if (util_starts_with(link,"nfs") ) {
        link = strstr(link,"://");
        if (link) {
            link += 3;
            end = strchr(link,':');
            //
            // assume nfs host has portmapper
            ovs_asprintf(&host,"%.*s",end-link,link);
            int connect_code = connect_service(host,connect_millis,2049); //nfs

            if (connect_code == ECONNREFUSED) {
                // ok device is present so try 139.
                connect_code = connect_service(host,connect_millis,111); //portmapper
            }
            result  = (connect_code == 0);
        }

    } else if (util_starts_with(link,"smb")) {
        link = strstr(link,"://");
        if (link) {
            link += 3;
            end = strchr(link,'/');
            //assume SMB on port 445
            ovs_asprintf(&host,"%.*s",end-link,link);

            int connect_code = connect_service(host,connect_millis,445); //new SMB

            if (connect_code == ECONNREFUSED) {
                // ok device is present so try 139.
                connect_code = connect_service(host,connect_millis,139); //old SMB
            }
            result  = (connect_code == 0);
        }
    }
    if (end) {
        HTML_LOG(1,"ping link [%s] host[%s] = %d",link,host,result);
    }

    FREE(host);
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
// vi:sw=4:et:ts=4
