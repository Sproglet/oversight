/*
 * Found at http://downloads.openmoko.org/developer/sources/svn/omgps.googlecode.com/svn/trunk/omgps/src/network.c
 * googling for ping function "int ping(char *host)"
 */
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netinet/in_systm.h>
#include <netinet/ip.h>
#include <netinet/ip_icmp.h>
#include <netdb.h>
#include <net/if.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <unistd.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <assert.h>

#if (HAVE_SYS_CAPABILITY_H)
#undef _POSIX_SOURCE
#include <sys/capability.h>
#endif

#include "gaya_cgi.h"

long ping_timeout();

/**
 * Ping: reference <Unix network programming>, volume 1, third edition.
 */
static uint16_t in_checkksum(uint16_t *addr, int len)
{
	int nleft = len;
	uint32_t sum = 0;
	uint16_t *w = addr;
	uint16_t answer = 0;

	while (nleft > 1) {
		sum += *w++;
		nleft -= 2;
	}
	if (nleft == 1) {
		*(unsigned char *) (&answer) = *(unsigned char *) w;
		sum += answer;
	}
	sum = (sum >> 16) + (sum & 0xffff);
	sum += (sum >> 16);
	answer = ~sum;
	return (answer);
}

/**
 * FIXME: resolve_timeout
 */
struct addrinfo * get_remote_addr(char *host, char * port, int family, int socktype,
	int protocol, int resolve_timeout)
{
	struct addrinfo hints, *info = NULL;
	memset(&hints, 0, sizeof(struct addrinfo));
	hints.ai_family = family;
	hints.ai_socktype = socktype;
	hints.ai_protocol = protocol;
	hints.ai_flags = AI_CANONNAME;

	int ret = getaddrinfo(host, port, &hints, &info);
	if (ret != 0) {
		if (info) {
			freeaddrinfo(info);
			info = NULL;
		}
	}
	return info;
}

/**
 * Need root privilege
 * @return:
 * > 0 -- ok,
 * < 0 -- failed.
 * Ping: reference <Unix network programming>, volume 1, third edition.
 */

#define USE_SELECT
// If USE_SELECT then select() is used for timeout rather than the original setsockopt/recvmsg
// This is because setsockopt SO_SNDTIMEO does not work on NMT.

int ping (char *host,long timeout_millis)
{
	#define BUF_SIZE	1500
	#define ICMP_REQUEST_DATA_LEN 56
    if (timeout_millis == 0) {
        timeout_millis = ping_timeout();
    }

	struct addrinfo *ai = get_remote_addr(host, NULL, AF_INET, SOCK_RAW, IPPROTO_ICMP, 5);
	if (ai == NULL)
		return -2;

	pid_t pid = getpid() & 0xffff; /* ICMP ID field is 16 bits */

	char send_buf[BUF_SIZE];

	int sockfd = socket(AF_INET, SOCK_RAW, IPPROTO_ICMP);

    long timeout_secs = timeout_millis / 1000;
    long timeout_usecs = (timeout_millis - timeout_secs * 1000) * 1000;

	struct timeval timeout = {timeout_secs, timeout_usecs };


#ifndef USE_SELECT
    int res;
	if ((res = setsockopt(sockfd, IPPROTO_ICMP, SO_SNDTIMEO, &timeout, sizeof(struct timeval))) != 0) {
        HTML_LOG(0,"Error %d/%d setting timeout",res,errno);
    }
	if ((res = setsockopt(sockfd, IPPROTO_ICMP, SO_RCVTIMEO, &timeout, sizeof(struct timeval))) != 0) {
        HTML_LOG(0,"Error %d/%d setting timeout",res,errno);
    }
#endif


	/* don't need special permissions any more */
	setuid(getuid());

	struct icmp *icmp;
	icmp = (struct icmp *) send_buf;
	icmp->icmp_type = ICMP_ECHO;
	icmp->icmp_code = 0;
	icmp->icmp_id = pid;
	icmp->icmp_seq = 0;
	memset(icmp->icmp_data, 0xa5, ICMP_REQUEST_DATA_LEN);
	gettimeofday((struct timeval *) icmp->icmp_data, NULL);
	int len = 8 + ICMP_REQUEST_DATA_LEN;
	icmp->icmp_cksum = 0;
	icmp->icmp_cksum = in_checkksum((u_short *) icmp, len);

	int ret = -1;

	if (sendto(sockfd, send_buf, len, 0, ai->ai_addr, ai->ai_addrlen) <= 0) {
		ret = -4;
	} else {
#ifdef USE_SELECT
        //Slight risk is that we are not looking at the return packet. But chances 
        //are anything that responds within the shot timeouts required for oversight
        //(100ms) is in working order.
        fd_set set;
        FD_ZERO(&set);
        FD_SET(sockfd,&set);
        ret = select(1+sockfd,&set,NULL,NULL,&timeout);
#else
#endif

	}

	free(ai);
	close(sockfd);

    HTML_LOG(0,"ping %s within %dms = %d",host,timeout_millis,ret);

	return ret;
}

long ping_timeout()
{
    static long ping_millis = -1;
    if (ping_millis == -1) {
        if (!config_check_long(g_oversight_config,"ovs_nas_timeout",&ping_millis)) {
            ping_millis=100;
            HTML_LOG(0,"ping timeout defaulting to %ldms",ping_millis);
        }
    }
    return ping_millis;
}

