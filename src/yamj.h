#ifndef OVS_YAMJ_H
#define OVS_YAMJ_H

#include "db.h"

// YAMJ Compatibility types
//
typedef struct {
    char *name;
    char *query;

    // Sort order - if null use owning YAMJCat sort order.
    char *sort_order;
    int page; // page requested
    // For the current category this will be populated with rows from the database.
    DbItem **items;
    int item_total;
    int evaluated;

    struct YAMJCat_str *owner_cat;

} YAMJSubCat;

typedef struct YAMJCat_str {
    char *name;
    char *expr;
    // Sort order - if null use Title.
    char *sort_order;
    int evaluated;
    Array *subcats;
    int page_size;
} YAMJCat;

int yamj_xml(char *name);
#endif
