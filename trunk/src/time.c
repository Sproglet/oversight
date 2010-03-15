#include <stdio.h>
#include "time.h"

static void copy_internal_time2tm(OVS_TIME t1,struct tm *t);

inline OVS_TIME time_ordinal(struct tm *t) {
// Return some long that represents time. mktime() is ideal but a bit slow on PCH
// we just need a number we can sort on and compare
    // Remove seconds from timestamp format. must fit 32 otherwise high bits lost.
    // Binary layout is YYYYYY YYYYMMMM dddddhhh hhmmmmmm
    return ((((((((t->tm_year & 0x3FF) << 4)+t->tm_mon) << 5)+t->tm_mday) << 5)+t->tm_hour)<<6)+t->tm_min;
}

OVS_TIME epoc2internal_time(time_t t1) {
    struct tm *t=gmtime(&t1);
    return time_ordinal(t);
}

time_t internal_time2epoc(OVS_TIME t1) {
    struct tm t;

    copy_internal_time2tm(t1,&t);
    return mktime(&t);
}
struct tm *internal_time2tm(OVS_TIME t1,struct tm *t)
{
    static struct tm t_static;
    if (t == NULL) {
        t = &t_static;
    }
    copy_internal_time2tm(t1,t);
    return t;
}
static void copy_internal_time2tm(OVS_TIME t1,struct tm *t) {
    // Binary layout is YYYYYY YYYYMMMM dddddhhh hhmmmmmm
    // Remove seconds from timestamp format. must fit 32 otherwise high bits lost.
    t->tm_sec = 0;
    t->tm_min = t1  & 0x3F;
    t->tm_hour = ( t1 >> (6)) & 0x1F;
    t->tm_mday = ( ( t1 >> (6+5)) & 0x1F  );
    t->tm_mon = ( t1 >> (6+5+5)) & 0xF  ;
    t->tm_year = ( t1 >> (6+5+5+4)) & 0x3FF  ;
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
