// $Id:$
#ifndef __OVS_GRID_H__
#define __OVS_GRID_H__

#include "types.h"
#include "array.h"

#define DEFAULT_PAGE_SIZE -1

typedef struct grid_dimension_str {
    long rows;
    long cols;
    long img_height;
    long img_width;
} GridDimensions ;

typedef struct grid_segment_str {
    GridDimensions dimensions;
    int offset;   // Offset from first element on page. 0= first.
    struct grid_info_str *parent;
    GridDirection grid_direction;
} GridSegment ;

typedef struct grid_info_str {

    Array *segments;
    int page_size;
    GridDirection grid_direction;
} GridInfo;

GridInfo *get_grid_info();
GridSegment *grid_info_add_segment(GridInfo *gi);
void grid_info_free(GridInfo *gi);
char *grid_calculate_offsets(GridInfo *gi);
int grid_size(GridInfo *gi);

#endif
