#ifndef __OVS_TIME_H__
#define __OVS_TIME_H__
#include <time.h>

#include "types.h"

inline OVS_TIME time_ordinal(struct tm *t);
OVS_TIME epoc2internal_time(time_t t1);
time_t internal_time2epoc(OVS_TIME t1);
char *fmt_date_static(OVS_TIME t1);
char *fmt_timestamp_static(OVS_TIME t1);
int year(OVS_TIME t1);
struct tm *internal_time2tm(OVS_TIME t1,struct tm *t);
#endif
