// $Id:$
#ifndef __OVS_PERMISSIONS_H_
#define __OVS_PERMISSIONS_H_
void permissions(uid_t uid,gid_t gid,int mode,int recursive,char *path);
void setPermissions();
#endif
