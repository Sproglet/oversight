#include <sys/types.h>
#include <sys/stat.h>
#include <pwd.h>
#include <unistd.h>

#include "util.h"
#include "gaya_cgi.h"

#define NMT_USER "nmt"

void permissions(uid_t uid,gid_t gid,char *path)
{
    chown(path,uid,gid);
    chmod(path,0775);
}
void setPermissions()
{

    HTML_LOG(0,"start permissions");
    struct passwd *pwd = getpwnam(NMT_USER);

    if (pwd != NULL) {
        chdir(appDir());
        permissions(pwd->pw_uid,pwd->pw_gid,"tmp");
        permissions(pwd->pw_uid,pwd->pw_gid,".");
        permissions(pwd->pw_uid,pwd->pw_gid,"index.db");
        permissions(pwd->pw_uid,pwd->pw_gid,"plot.db");
        permissions(pwd->pw_uid,pwd->pw_gid,"db");
        permissions(pwd->pw_uid,pwd->pw_gid,"db/global");
        permissions(pwd->pw_uid,pwd->pw_gid,"db/global/_J"); //posters
        permissions(pwd->pw_uid,pwd->pw_gid,"db/global/_fa"); //fanart
        HTML_LOG(0,"end permissions");
    } else {
        HTML_LOG(0,"user [%s] not found",NMT_USER);
    }
}
