// $Id:$
#include <sys/types.h>
#include <sys/stat.h>
#include <pwd.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "util.h"
#include "gaya_cgi.h"
#include "dirent.h"


void permissions(uid_t uid,gid_t gid,int mode,int recursive,char *path)
{
    int result = 0;
    struct stat st;
    stat(path,&st);

    chown(path,uid,gid);
    result = chmod(path,mode);
    if (recursive && S_ISDIR(st.st_mode)) {
        DIR *d = opendir(path);
        if (d) {
            struct dirent *sub ;

              while((sub = readdir(d)) != NULL) {
                  if (sub->d_type == DT_REG ||
                        (sub->d_type == DT_DIR && strcmp(sub->d_name,".") && strcmp(sub->d_name,".."))) {
                        char *tmp;
                        ovs_asprintf(&tmp,"%s/%s",path,sub->d_name);
                        permissions(uid,gid,mode,recursive,tmp);
                        FREE(tmp);
                  }
              }
            closedir(d);
        }
    } 
}
void setPermissions()
{

    HTML_LOG(0,"start permissions");

    chdir(appDir());
    permissions(nmt_uid(),nmt_gid(),0775,0,"tmp");
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
