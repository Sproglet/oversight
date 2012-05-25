#ifndef __OVS_MOUNT_H__
#define __OVS_MOUNT_H__
// Mounted and working
#define MOUNT_STATUS_OK "1"

// Unpingable or something else nasty
#define MOUNT_STATUS_BAD "0"

// In mtab but might be good or stale
#define MOUNT_STATUS_IN_MTAB "?"

// Not in mtab
#define MOUNT_STATUS_NOT_IN_MTAB "-"
int nmt_mount (char *file);
int nmt_mount_quick (char *file);
struct hashtable *mount_points_hash();
int is_share_setting(char *setting);
#endif
