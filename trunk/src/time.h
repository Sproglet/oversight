#ifndef __OVS_TIME_H__
#define __OVS_TIME_H__
#include <time.h>

#define OVS_USE_FAST_TIME 1

#ifdef OVS_USE_FAST_TIME
#define OVS_TIME unsigned long long
#else
#define OVS_TIME time_t
#endif

inline OVS_TIME time_ordinal(struct tm *t);
OVS_TIME epoc2internal_time(time_t t1);
time_t internal_time2epoc(OVS_TIME t1);
#endif
