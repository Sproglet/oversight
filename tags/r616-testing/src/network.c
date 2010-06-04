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

#if 0
#ifndef NI_MAXHOST
#define NI_MAXHOST 200
#endif
int dump_addr(struct addrinfo *i)
{
    for( ; i ; i=i->ai_next) {
        char hostname[NI_MAXHOST]="";
        int e = getnameinfo(i->ai_addr,i->ai_addrlen,hostname,NI_MAXHOST,NULL,0,0);
        if (e != 0 ) {
            HTML_LOG(0,"Error in getnameinfo: %s\n", gai_strerror(e));
        } else if (hostname[0]) {
            HTML_LOG(0," found hostname [%s]\n", hostname);
        }
    }
}
#endif

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
            HTML_LOG(0,"No address!!!!");
			freeaddrinfo(info);
			info = NULL;
		}
	}

#if 0
    dump_addr(info);
#endif
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
//
// TODO Implement version that creates a socket to portmap (NFS) or 445(Windows)
// http://www.developerweb.net/forum/showthread.php?p=13486
//

int ping (char *host,long timeout_millis)
{
	#define BUF_SIZE	1500
	#define ICMP_REQUEST_DATA_LEN 56
    if (timeout_millis == 0) {
        timeout_millis = ping_timeout();
    }
    HTML_LOG(0,"ping %s within %ldms...",host,timeout_millis);

	struct addrinfo *ai = get_remote_addr(host, NULL, AF_INET, SOCK_RAW, IPPROTO_ICMP, 5);
	if (ai == NULL)
		return -2;

	pid_t pid = getpid() & 0xffff; /* ICMP ID field is 16 bits */

	char send_buf[BUF_SIZE];

	int sockfd = socket(AF_INET, SOCK_RAW, IPPROTO_ICMP);

    long timeout_secs = timeout_millis / 1000;
    long timeout_usecs = (timeout_millis - timeout_secs * 1000) * 1000;

	struct timeval timeout = {timeout_secs, timeout_usecs };

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
        //Slight risk is that we are not looking at the return packet. But chances 
        //are anything that responds within the shot timeouts required for oversight
        //(100ms) is in working order.
        fd_set set;
        FD_ZERO(&set);
        FD_SET(sockfd,&set);

        if (select(1+sockfd,&set,NULL,NULL,&timeout) == 1) {
            ret = 0;
        }
	}

	free(ai);
	close(sockfd);

    HTML_LOG(0,"ping %s within %dms = %d = %s",host,timeout_millis,ret,(ret?"bad":"good"));

	return ret;
}

// connect to a port and disconnect
// 0 = success
int connect_service(char *host,long timeout_millis,int port)
{
    int ret = -1;
	#define BUF_SIZE	1500
	#define ICMP_REQUEST_DATA_LEN 56
    if (timeout_millis == 0) {
        timeout_millis = ping_timeout();
    }
    HTML_LOG(0,"connect_service %s:%d within %ldms...",host,port,timeout_millis);
    long timeout_secs = timeout_millis / 1000;
    long timeout_usecs = (timeout_millis - timeout_secs * 1000) * 1000;

	struct timeval timeout = {timeout_secs, timeout_usecs };


    // The Address ai->ai_addr
	struct addrinfo *ai = get_remote_addr(host, NULL, AF_INET, SOCK_STREAM, IPPROTO_TCP, 5);
	if (ai == NULL)
		return -2;



    // The socket
    //
    int sockfd = socket(PF_INET,SOCK_STREAM,0);
    if (sockfd < 0 ) {
        HTML_LOG(0,"Socket error %d at line %d",errno,__LINE__);
        return -2;
    }

    // Using http://www.developerweb.net/forum/showthread.php?t=3000
    //
    // Set socket non-blocking
#if 1
    int flags;
    if ((flags = fcntl(sockfd,F_GETFL)) < 0 ) {
        HTML_LOG(0,"Socket error %d at line %d",errno,__LINE__);
        return -2;
    }
    if (fcntl(sockfd,F_SETFL, flags | O_NONBLOCK) < 0 ) {
        HTML_LOG(0,"Socket error %d at line %d",errno,__LINE__);
        return -2;
    }
#endif

    // Connect to the socket
    //
    if (connect(sockfd,ai->ai_addr,ai->ai_addrlen) != 0) {
        HTML_LOG(0,"Connect error %d at line %d",errno,__LINE__);

    }

    fd_set set;
    FD_ZERO(&set);
    FD_SET(sockfd,&set);

    if (select(1+sockfd,&set,NULL,NULL,&timeout) == 1) {
        ret = 0;
    }

	free(ai);
	close(sockfd);

    HTML_LOG(0,"connect %s:%d within %dms = %d = %s",host,port,timeout_millis,ret,(ret?"bad":"good"));

	return ret;
}

int nfs_ping(char *host,long timeout_millis)
{
    // Just check the port mapper
    return connect_service(host,timeout_millis,111);
}

int cifs_ping(char *host,long timeout_millis)
{
    return connect_service(host,timeout_millis,445);
}

long ping_timeout()
{
    static long ping_millis = -1;
    if (ping_millis == -1) {
        if (!config_check_long(g_oversight_config,"ovs_nas_timeout",&ping_millis)) {
            ping_millis=500;
            HTML_LOG(0,"ping timeout defaulting to %ldms",ping_millis);
        }
    }
    return ping_millis;
}
