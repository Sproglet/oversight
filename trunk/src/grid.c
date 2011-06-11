// $Id:$
//
// These functions support a list of GRIDs. Each Grid is a rectangle of cells. Each Cell represents a movie or tv season (or boxset).
// For rendering of the Grid to HTML see grid_display.c
//
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "grid.h"
#include "oversight.h"
#include "util.h"
#include "config.h"
#include "assert.h"
#include "hashtable_loop.h"
#include "gaya_cgi.h"
#include "vasprintf.h"

#define GRID_SIZE(gs) ((gs)->dimensions.rows * (gs)->dimensions.cols )
#define GRID_SEGMENT_END(gs) ((gs)->offset + GRID_SIZE(gs))

char *grid_check_one_segment(GridInfo *gi,GridSegment *gsToCheck);
char *grid_check_offsets(GridInfo *gi);
char *grid_set_offsets(GridInfo *gi);

GridInfo *get_grid_info()
{
    static GridInfo *gi = NULL;
    
    if (gi == NULL) {
        gi = CALLOC(1,sizeof(GridInfo));
        gi->page_size = DEFAULT_PAGE_SIZE;
        gi->grid_direction = g_dimension->grid_direction;
    }
    return gi;
}

GridSegment *grid_info_add_segment(GridInfo *gi)
{
    if (gi->segments == NULL) {
        gi->segments = array_new(free);
    }
    GridSegment *gs = CALLOC(1,sizeof(GridSegment));
    array_add(gi->segments,gs);
    gs->parent = gi;
    gs->grid_direction = gi->grid_direction;
    gs->offset = -1;
    return gs;
}

void grid_info_free(GridInfo *gi)
{
    if (gi) {
        array_free(gi->segments);
        FREE(gi);
    }
}

/*
 * Calculate or check all grid offsets.
 * Return : NULL=ok else error message (must be freed)
 */
char *grid_calculate_offsets(GridInfo *gi)
{
    char *error_text = NULL;

    if (gi->segments) {

        GridSegment *gs = gi->segments->array[0];

        if (gs->offset == -1) {
            error_text = grid_set_offsets(gi);
        } else {
            error_text = grid_check_offsets(gi);
        }
        gi->page_size = grid_size(gi);
    }
    return error_text;
}

/*
 * Comput all grid offsets based in thier size and order.
 * Return : NULL=ok else error message (must be freed)
 */
char *grid_set_offsets(GridInfo *gi)
{
    HTML_LOG(0,"grid_set_offsets");
    char *error_text = NULL;
    int i=0;
    int total = 0;
    if (gi->segments) {
        for(i = 0 ; error_text == NULL && i < gi->segments->size ; i++ ) {
           GridSegment *gs = gi->segments->array[i];
           if (gs->offset != -1 ) {
               ovs_asprintf(&error_text,"offset conflict beween segments 0 and %d",i);
           } else {
               gs->offset = total;
               total += GRID_SIZE(gs);
               HTML_LOG(0,"segment[%d %dx%d] - offset=%d",i,gs->dimensions.rows,gs->dimensions.cols,gs->offset);
           }
       }
   }
   return error_text;
}

/*
 * Ensure all grids have an offset and that there are no gaps or overlaps.
 * Return : NULL=ok else error message (must be freed)
 */
char *grid_check_offsets(GridInfo *gi)
{
    HTML_LOG(0,"grid_check_offsets");
    char *error_text = NULL;
    int i=0;
    if (gi->segments) {

        HTML_LOG(0,"number of grid segments =  %d",gi->segments->size );

        for(i = 0 ; error_text == NULL && i < gi->segments->size ; i++ ) {
           GridSegment *gs = gi->segments->array[i];
           if (gs->offset == -1 ) {
               ovs_asprintf(&error_text,"offset conflict beween segments 0 and %d",i);
           } else {
               error_text = grid_check_one_segment(gi,gs);
           }
        }
    }
    return error_text;
}

int grid_size(GridInfo *gi)
{
    char *error_text = NULL;
    int i=0;
    int last = 0;
    if (gi->segments) {
        for(i = 0 ; error_text == NULL && i < gi->segments->size ; i++ ) {
            GridSegment *gs = gi->segments->array[i];
            int end = GRID_SEGMENT_END(gs);
            if (end > last) {
                last = end;
            }
        }
    }
    return last;
}


/*
 * Count number of other segments touching the given segment number
 * NULL=ok else returns error message (must be freed)
 */
char *grid_check_one_segment(GridInfo *gi,GridSegment *gsToCheck)
{
    char *error_text = NULL;
    int i=0;
    int last = 0;
    int segno = -1;

    HTML_LOG(0,"check segment[%d:%dx%d]",
            gsToCheck->offset,gsToCheck->dimensions.rows,gsToCheck->dimensions.cols);
    
   
    int check_start = gsToCheck->offset;
    int check_end = GRID_SEGMENT_END(gsToCheck);

    int segment_after=0;
    int segment_before=0;

    last = check_end;

    if (gi->segments) {
        for(i = 0 ; i < gi->segments->size ; i++ ) {
           GridSegment *gs = gi->segments->array[i];
           if (gs != gsToCheck) {

              int end = GRID_SEGMENT_END(gs);

               if (gs->offset == end ) {
                   segment_after ++;
               } else if (check_start == GRID_SEGMENT_END(gs)) {
                   segment_before ++;
               }

               if (end > last) {
                   last = end;
               }
           } else {
               segno = i;
           }
        }
    }
    assert(segno != -1);

    if (check_start  == 0) segment_before++;
    HTML_LOG(0," check_end=%d , last=%d",check_end,last);
    if (check_end == last) segment_after++;

    if (segment_before > 1) {
        ovs_asprintf(&error_text,"Too many segments before segment %d",segno);
    } else if (segment_before == 0) {
        ovs_asprintf(&error_text,"No segments before segment %d",segno);
    } else if (segment_after > 1) {
        ovs_asprintf(&error_text,"Too many segments after segment %d",segno);
    } else if (segment_after == 0) {
        ovs_asprintf(&error_text,"No segments after segment %d",segno);
    }
    return error_text;
}
