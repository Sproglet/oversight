// $Id:$
#ifndef __OVS_ACTIONS_H__
#define __OVS_ACTIONS_H__

#include "db.h"

void do_actions();
void delete_queue_delete();
void delete_queue_unqueue(DbRowId *rid,char *path);
void delete_queue_add(DbRowId *rid,char *path);
void delete_media(DbRowId *rid,int delete_related);

void add_internal_images_to_delete_queue(DbRowId *rid);
void remove_internal_images_from_delete_queue(DbRowId *rid);

#define DELETE_MODE_NONE 0
#define DELETE_MODE_REMOVE 1
#define DELETE_MODE_DELETE 2

#endif
