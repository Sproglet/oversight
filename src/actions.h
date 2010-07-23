// $Id:$
#ifndef __OVS_ACTIONS_H__
#define __OVS_ACTIONS_H__

#include "db.h"

void do_actions();
void delete_queue_delete();
void delete_queue_unqueue(DbItem *item,char *path);
void delete_queue_add(DbItem *item,int force,char *path);
void delete_media(DbItem *item,int delete_related);

void add_internal_images_to_delete_queue(DbItem *item);
void remove_internal_images_from_delete_queue(DbItem *item);
void set_start_cell();
char *get_start_cell();

#define DELETE_MODE_NONE 0
#define DELETE_MODE_REMOVE 1      // user initiated delist - pass 1
#define DELETE_MODE_DELETE 2      // user initiated delete - pass 1
#define DELETE_MODE_AUTO_REMOVE 3 // automatic delist during pass 2

#endif
