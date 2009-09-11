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
        FD_SET(sockfd,&set);
        ret = select(1,&set,NULL,NULL,&timeout);
#else
        char recv_buf[BUF_SIZE];
        char control_buf[BUF_SIZE];
        //The proper way - except setsockopt timeout doesnt work on NMT
		struct msghdr msg;
		struct iovec iov;
		iov.iov_base = recv_buf;
		iov.iov_len = sizeof(recv_buf);
		msg.msg_name = (char *)calloc(1, ai->ai_addrlen);
		msg.msg_iov = &iov;
		msg.msg_iovlen = 1;
		msg.msg_control = control_buf;
		msg.msg_namelen = ai->ai_addrlen;
		msg.msg_controllen = sizeof(control_buf);

        
        if (sel_val == 1) {
            return -5; // timeout
        } else if (sel_val == 1

		if ((len = recvmsg(sockfd, &msg, 0)) <= 0) {
			ret = -5;
		} else {
			struct ip *ip = (struct ip *) recv_buf;
			int header_len = ip->ip_hl << 2;

			struct icmp *icmp = (struct icmp *) (recv_buf + header_len);
			int icmp_payload_len = len - header_len;
			if ((ip->ip_p == IPPROTO_ICMP) && (icmp_payload_len >= 16) &&
				(icmp->icmp_type == ICMP_ECHOREPLY) && (icmp->icmp_id == pid)) {
				ret = 1;
			} else {
				ret = -6;
			}
		}
		free(msg.msg_name);
#endif

	}

	free(ai);
	close(sockfd);

	return ret;
}
