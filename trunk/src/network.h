#ifndef __OVS_NETWORK_H__
#define __OVS_NETWORK_H__

int ping (char *host,long timout_millis);
long ping_timeout();
int connect_service(char *host,long timeout_millis,...);
#endif
