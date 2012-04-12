#ifndef OVS_YAMJ_H
#define OVS_YAMJ_H

#include "db.h"


int yamj_xml(char *name);
int yamj_check_item(DbItem *item,Array *categories,YAMJSubCat *subcat);
#endif
