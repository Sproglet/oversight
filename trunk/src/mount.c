#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "util.h"
#include "vasprintf.h"
#include "gaya_cgi.h"
#include "hashtable.h"
#include "oversight.h"
#include "config.h"

/*
 * Attempt to quickly mount a file or if the file is not available fail quickly.
 */
static struct hashtable *mount_points = NULL;

void add_mount_point(char *p,char *val) {
    if (hashtable_search(mount_points,p) == NULL) {
        html_log(1,"Adding mount point [%s]",p);
        hashtable_insert(mount_points,STRDUP(p),val);
    } else {
        html_log(1,"Already added mount point [%s]",p);
    }
}

// Only look at the standard NMT NETWORK media mount points.
void get_mount_points() {
    if (mount_points == NULL) {
        mount_points = string_string_hashtable(16); //let the OS clean this up at the end
        FILE *fp = fopen("/etc/mtab","r");
        if (fp) {
#define BUFSIZE 200
            char buf[BUFSIZE];
            while(fgets(buf,BUFSIZE,fp) != NULL) {
                char *p = strstr(buf,NETWORK_SHARE);
                if (p) {

                    char *q = p+strlen(NETWORK_SHARE);

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
    }
}

int is_mounted(char *path) {

    char *mount_status;
    if (mount_points == NULL) {
        get_mount_points();
    }
    mount_status = hashtable_search(mount_points,path) ;

    if (mount_status == NULL) {
        html_log(1,"%s is not mounted",path);
        return 0;
    } else if (*mount_status == '0') {
        html_log(1,"already tried to mount %s",path);
        return 1;
    } else {
        html_log(3,"already mounted %s",path);
        return 1;
    }
}



void nmt_mount (char *file) {

html_log(1,"mount [%s]",file);
    if (util_starts_with(file,NETWORK_SHARE)) { 

        char *rest = strchr(file+strlen(NETWORK_SHARE)+1,'/');

TRACE ; html_log(1,"mount rest [%s]",rest);

        if (rest) {
            *rest = '\0';
            char *path = STRDUP(file);

TRACE ; html_log(1,"mount path [%s]",path);

            *rest = '/';

            if (!is_mounted(path)) {

                char *share_name = util_basename(path);
TRACE ; html_log(1,"mount share_name [%s]",share_name);

                char *key=STRDUP("servname?");
                char *last=key+strlen(key)-1;
                char index = 0;
                char c;

                for(c = '0' ; c <= '9' ; c++ ) {
                    *last = c;
                    if (strcmp(setting_val(key),share_name) == 0) {
                        index = c;
                        break;
                    }
                }
TRACE ; html_log(1,"mount index [%d=%c]",index,index);
                if (index) {
                    FREE(key);
                    ovs_asprintf(&key,"servlink%c",index);

                    char *serv_link = setting_val(key);
TRACE ; html_log(1,"mount servlink [%s]",serv_link);
                    FREE(key);

                    ovs_asprintf(&key,"link%c",index);
                    char *link = setting_val(key);
TRACE ; html_log(1,"mount link [%s]",link);

                    char *user=regextract1(serv_link,"smb.user=([^&]+)",1,0);
TRACE ; html_log(1,"mount user [%s]",user);

                    char *passwd=regextract1(serv_link,"smb.passwd=([^&]+)",1,0);
TRACE ; html_log(1,"mount passwd [%s]",passwd);

                    char *cmd = NULL;
                    if (util_starts_with(link,"nfs://")) {

                        ovs_asprintf(&cmd,"mkdir -p \"%s\" && mount -o soft,nolock,timeo=10 \"%s\" \"%s\"",
                                path,link+6,path);

                    } else if (util_starts_with(link,"cifs://")) {

                        ovs_asprintf(&cmd,"mkdir -p \"%s\" && mount -t cifs -o username=%s,password=%s \"%s\" \"%s\"",
                                path,user,passwd,link+5,path);
                    } else {
                        html_error("Dont know how to mount [%s]",serv_link);
                    }
                    if (cmd) {

                        if (util_system(cmd) == 0) {

                            add_mount_point(path,"1");

                        } else {
                            //even though mount failed - add it to the list to avoid repeat attempts.
                            add_mount_point(path,"0");

                        }

                        FREE(cmd);
                    }

                    FREE(user);
                    FREE(passwd);

                }
                    


                FREE(key);
                FREE(share_name);

                
            }
            FREE(path);
        }

    }

}
