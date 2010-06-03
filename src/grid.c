// $Id:$
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

GridInfo *grid_info_init()
{
    GridInfo *gi = CALLOC(1,sizeof(GridInfo));
    gi->page_size = DEFAULT_PAGE_SIZE;
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
    return gs;
}

void grid_info_free(GridInfo *gi)
{
    if (gi) {
        array_free(gi->segments);
        FREE(gi);
    }
}
