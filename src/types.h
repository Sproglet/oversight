#ifndef __OVS_TYPES_H__
#define __OVS_TYPES_H__

// Types will be migrated here over time.

typedef struct EnumString_struct {
    int id ;
    const char *str;
} EnumString;

typedef enum GridDirection_enum {
    GRID_ORDER_DEFAULT,
    GRID_ORDER_HORIZONTAL ,
    GRID_ORDER_VERTICAL
} GridDirection;

#endif
