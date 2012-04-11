// $Id:$
#include <sys/types.h>
#include <sys/stat.h>
#include <pwd.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include "util.h"
#include "gaya_cgi.h"
#include "dirent.h"


void permissions(uid_t uid,gid_t gid,int mode,int recursive,char *path)
{
    char *full_path = path;

    if (*full_path != '/' ) {
        ovs_asprintf(&full_path,"%s/%s",appDir(),path);
    }

    struct STAT64 st;
    util_stat(full_path,&st);

    //HTML_LOG(0,"chown %d:%d chmod %o [%s]",uid,gid,mode,full_path);
    if (chown(full_path,uid,gid) != 0) {
        HTML_LOG(0,"chown [%s] error [%d]",full_path,errno);
    }
    if (chmod(full_path,mode) != 0) {
        HTML_LOG(0,"chmod [%s] error [%d]",full_path,errno);
    }
    if (recursive && S_ISDIR(st.st_mode)) {
        DIR *d = opendir(full_path);
        if (d) {
            struct dirent *sub ;

              while((sub = readdir(d)) != NULL) {
                  if (sub->d_type == DT_REG ||
                        (sub->d_type == DT_DIR && strcmp(sub->d_name,".") && strcmp(sub->d_name,".."))) {
                        char *tmp;
                        ovs_asprintf(&tmp,"%s/%s",full_path,sub->d_name);
                        permissions(uid,gid,mode,recursive,tmp);
                        FREE(tmp);
                  }
              }
            closedir(d);
        }
    } 
    if (full_path != path) {
        FREE(full_path);
    }
}
void setPermissions()
{

    HTML_LOG(0,"start permissions");

    chdir(appDir());
    permissions(nmt_uid(),nmt_gid(),0775,0,"tmp");
    permissions(nmt_uid(),nmt_gid(),0775,0,"cache");
    permissions(nmt_uid(),nmt_gid(),0775,0,"logs");
    permissions(nmt_uid(),nmt_gid(),0775,0,".");
    permissions(nmt_uid(),nmt_gid(),0775,0,"index.db");
    permissions(nmt_uid(),nmt_gid(),0775,0,"plot.db");
    permissions(nmt_uid(),nmt_gid(),0775,0,"db");
    permissions(nmt_uid(),nmt_gid(),0775,0,"db/global");
    permissions(nmt_uid(),nmt_gid(),0775,0,"db/global/_J");
    permissions(nmt_uid(),nmt_gid(),0775,0,"db/global/_fa");
    permissions(nmt_uid(),nmt_gid(),0775,0,"db/global/_A");
    HTML_LOG(0,"end permissions");
}
// vi:sw=4:et:ts=4
