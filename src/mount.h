#ifndef __OVS_MOUNT_H__
#define __OVS_MOUNT_H__
int nmt_mount (char *file);
int nmt_mount_quick (char *file);
struct hashtable *mount_points_hash();
#endif
