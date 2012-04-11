#ifndef OVS_YAMJ_H
#define OVS_YAMJ_H

#include "db.h"

// YAMJ Compatibility types
//
typedef struct {
    char *name;

    // URL representation of expression that must evaluate to true for items to be included . see parse_url_expression()
    char *filter_expr_url;
    Exp *filter_expr;

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

    // Name is defined directly from config file OR is derived from parent category auto_subcat_expr
    char *name;
    // URL representation of query used to auto build sub categoroes. see parse_url_expression()
    char *auto_subcat_expr_url;
    Exp *auto_subcat_expr;
    // Sort order - if null use Title.
    char *sort_order;
    int evaluated;
    Array *subcats;
    int page_size;
} YAMJCat;

int yamj_xml(char *name);
#endif
