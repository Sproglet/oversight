#include <stdio.h>
#include "time.h"

inline OVS_TIME time_ordinal(struct tm *t) {
// Return some long that represents time. mktime() is ideal but a bit slow on PCH
// we just need a number we can sort on and compare
#ifdef OVS_USE_FAST_TIME
    // maxint is 2147483647
    // Binary layout is YYYY YYYYYYMM MMdddddh hhhhmmmm mmssssss
    // Note the year pushes us to more than 32 bits as we need more than 6 bits for the year.
    return ((((((((((t->tm_year & 0x7F) << 4)+t->tm_mon) << 5)+t->tm_mday) << 5)+t->tm_hour)<<6)+t->tm_min)<<6)+t->tm_sec;
    //max 59 + 60*(59 + 60 * (23 + 24 * ( 30 + 31 * (11 + 12 * 5 ))));
    //  = 32140799
#else
    return mktime(t);
#endif
}

// Difference in days between two times
OVS_TIME epoc2internal_time(time_t t1) {
#ifdef OVS_USE_FAST_TIME
   
    struct tm *t=gmtime(&t1);
    return time_ordinal(t);
#else
    return t1;
#endif
}
time_t internal_time2epoc(OVS_TIME t1) {
#ifdef OVS_USE_FAST_TIME
    struct tm t;
    // Binary layout is YYYY YYYYYYMM MMdddddh hhhhmmmm mmssssss
    t.tm_sec = t1 & 0x3F;
    t.tm_min = ( t1 >> 6) & 0x3F;
    t.tm_hour = ( t1 >> (6+6)) & 0x1F;
    t.tm_mday = ( ( t1 >> (6+6+5)) & 0x1F  );
    t.tm_mon = ( t1 >> (6+6+5+5)) & 0xF  ;
    t.tm_year = ( t1 >> (6+6+5+5+4)) & 0x7F  ;
    return mktime(&t);
#else
    return t1;
#endif
}
struct tm *internal_time2tm(OVS_TIME t1,struct tm *t)
{
    static struct tm t_static;
    if (t == NULL) {
        t = &t_static;
    }
#ifdef OVS_USE_FAST_TIME
    // Binary layout is YYYY YYYYYYMM MMdddddh hhhhmmmm mmssssss
    t->tm_sec = t1 & 0x3F;
    t->tm_min = ( t1 >> 6) & 0x3F;
    t->tm_hour = ( t1 >> (6+6)) & 0x1F;
    t->tm_mday = ( ( t1 >> (6+6+5)) & 0x1F  );
    t->tm_mon = ( t1 >> (6+6+5+5)) & 0xF  ;
    t->tm_year = ( t1 >> (6+6+5+5+4)) & 0x7F  ;
#else
    localtime_r(&t1,t);
#endif
    return t;
}

char *fmt_timestamp_static(OVS_TIME t1)
{
    static char buf[20];
    struct tm t;
    internal_time2tm(t1,&t);
    sprintf(buf,"%4d%02d%02d%02d%02d%02d",
            t.tm_year+1900,
            t.tm_mon+1,
            t.tm_mday,
            t.tm_hour,
            t.tm_min,
            t.tm_sec);
    return buf;
}

char *fmt_date_static(OVS_TIME t1)
{
    static char buf[20];
    struct tm t;
    internal_time2tm(t1,&t);
    sprintf(buf,"%4d-%02d-%02d",
            t.tm_year+1900,
            t.tm_mon+1,
            t.tm_mday);
    return buf;
}

int year(OVS_TIME t1)
{
    struct tm t;
    internal_time2tm(t1,&t);
    return t.tm_year+1900;
}