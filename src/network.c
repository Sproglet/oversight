// $Id:$
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
#include <ctype.h>

#if (HAVE_SYS_CAPABILITY_H)
#undef _POSIX_SOURCE
#include <sys/capability.h>
#endif

#include "gaya_cgi.h"
#include "network.h"

/*
 * Socket errors
 *
 * Connection closed appears to be 150 ?
 *
 * If host is IP address it is fast to build own struct sockaddr_in than to use getaddrinfo 
 * however this seems to result in an error 22 when connecting to an open port. so
 * we have following error codes:
 *
 *
 * getaddrinfo - slow - port open - no error
 * getaddrinfo - slow - port closed - error 150 on NMT
 *
 * manual struct - fast - port open - Error 22 on NMT100 EINPROGRESS
 * manual struct  - fast - port closed - Error 22 on NMT100 EINPROGRESS!!
 * When building own struct sockaddr_in from ip address a open port returns error 22.
 * Closed port returns ?
 */

long ping_timeout();
int connect_tcp_socket(struct sockaddr *addr,size_t addrlen,int port,long timeout_millis);

/**
 * FIXME: resolve_timeout
  getaddrinfo call can be slow. We only call it to compute ai->ai_addr and ai->ai_addrlen
 */
struct addrinfo * get_remote_addr(char *host, char * service, int family, int socktype,
	int protocol, int resolve_timeout)
{
    struct addrinfo hints, *info = NULL;

    if (util_strreg(host,"^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$",0)) {
        // Its an IP Address - get ai_addr and au_addrlen directly
        
        struct sockaddr_in *sock;
        sock = CALLOC(sizeof(struct sockaddr),1);
        //sock->sin_port = AF_INET;
        sock->sin_family = AF_INET;
        sock->sin_addr.s_addr = inet_addr(host);

        info = CALLOC(sizeof(struct addrinfo),1);
        info->ai_family=family;
        info->ai_socktype=socktype;
        hints.ai_protocol = protocol;
        //hints.ai_flags = AI_CANONNAME;
        info->ai_addrlen=sizeof(struct sockaddr);
        info->ai_addr=(struct sockaddr *)sock;
        //
    } else {
        HTML_LOG(0,"resolving [%s]",host);
        memset(&hints, 0, sizeof(struct addrinfo));
        hints.ai_family = family;
        hints.ai_socktype = socktype;
        hints.ai_protocol = protocol;
        hints.ai_flags = AI_CANONNAME;

        int ret = getaddrinfo(host, service, &hints, &info);
        if (ret != 0) {
            if (info) {
                HTML_LOG(0,"No address!!!!");
                freeaddrinfo(info);
                info = NULL;
            }
        }
    }

#if 0
    dump_addr(info);
    if (info) {
        int i;
        HTML_LOG(0,"info len = %d",info->ai_addrlen);

        for(i = 0 ; i < sizeof(struct sockaddr) ; i++ ) {
            HTML_LOG(0,"info %x",((char *)(info->ai_addr))[i]);
        }
    }
#endif
	return info;
}

int routable(struct sockaddr *addr,int addrlen) {

    int i;
#define NUM_NETS 8
    static unsigned long net[NUM_NETS] =  {
        0x00000000 /* 0.x.x.x */ ,
        0x0A000000 /* 10.x.x.x */ ,
        0x80000000 /* 128.x.x.x */ ,
        0xAC100000 /* 172.16 */ ,
        0xBFFF0000 /* 191.255.x.x */ ,
        0xC0000000 /* 192.0.0.x */,
        0xC0A80000 /* 192.168 */,
        0xDFFFFF00 /* 223.255.255.x */
    };
    static unsigned long mask[NUM_NETS] = {
        0xFF000000 /* 0.x.x.x */ ,
        0xFF000000 /* 10.x.x.x */ ,
        0xFF000000 /* 128.x.x.x */ ,
        0xFFF00000 /* 172.16 */ ,
        0xFFFF0000 /* 191.255.x.x */ ,
        0xFFFFFF00 /* 192.0.0.x */,
        0xFFFF0000 /* 192.168 */,
        0xFFFFFF00 /* 223.255.255.x */  
    };

    struct sockaddr_in *in4 = (void *)addr;
    if (in4->sin_family == AF_INET) {
        struct in_addr *ia = &(in4->sin_addr);
        unsigned long ip = ntohl(ia->s_addr);
        for ( i = 0 ; i < NUM_NETS ; i++ ) {
            if ( ( ip & mask[i] ) == net[i] ) {
                HTML_LOG(0,"Address %lx matches reserved %lx",ia->s_addr,net[i]);
                return 0;
            }
        }
        HTML_LOG(0,"Address %lx did not match any - assume routable",ia->s_addr);
        return 1;
    } else {
        HTML_LOG(0,"Not ip4 assume non routable for now");
        return 0;
    }

}

// connect to a port and disconnect
// 0 = success
int connect_service(char *host,long timeout_millis,...)
{
    va_list ap;

    int ret = -1;
    
	#define BUF_SIZE	1500
	#define ICMP_REQUEST_DATA_LEN 56

    // Assume success if timeout is zero
    if (timeout_millis == 0) {
        HTML_LOG(0,"port probe disabled");
        ret = 0;
    } else {


        // The Address ai->ai_addr
        struct addrinfo *ai = get_remote_addr(host, NULL, AF_INET, SOCK_STREAM, IPPROTO_TCP, 5);
        if (ai == NULL) {
            HTML_LOG(0,"Unable to get remote address for [%s]",host);
            ret = -2;
        } else {

            if (routable(ai->ai_addr,ai->ai_addrlen)) {

                // Open DNS map all unknown host lookups to an OpenDNS
                // ip address. We have to trap these bogus lookups. No such thing as a free lunch !!
                HTML_LOG(0,"[%s] appears to be outside your network. Ignoring.",host);
                ret  = -3;
            } else {

                va_start(ap,timeout_millis);
                // The socket
                int port;

                while (( port = va_arg(ap,int)) != 0) {

                    ret = connect_tcp_socket(ai->ai_addr,ai->ai_addrlen,port,timeout_millis);

                    if (ret == 0 ) {

                        break;

                    }

                }
                va_end(ap);


            }
            FREE(ai);
        }
    }

    return ret;
}

int connect_tcp_socket(struct sockaddr *addr,size_t addrlen,int port,long timeout_millis)
{
    int ret = 0;
    int sockfd = socket(AF_INET,SOCK_STREAM,0);

    if (timeout_millis == 0) {
        timeout_millis = ping_timeout();
    }
    long timeout_secs = timeout_millis / 1000;
    long timeout_usecs = (timeout_millis - timeout_secs * 1000) * 1000;

    struct timeval timeout = {timeout_secs, timeout_usecs };

    struct sockaddr_in *sin = (void *)addr;

    char *host = inet_ntoa(sin->sin_addr);
    long elapsed=-1;

    if (sockfd < 0 ) {

        HTML_LOG(0,"socket error: create %d",errno);
        ret  = errno;

    } else {

        // Using http://www.developerweb.net/forum/showthread.php?t=3000
        //
        // Set socket non-blocking
        int flags;
        if ((flags = fcntl(sockfd,F_GETFL)) < 0 ) {

            HTML_LOG(0,"socket error: get flags %d",errno);
            ret = errno;

        } else if (fcntl(sockfd,F_SETFL, flags | O_NONBLOCK) < 0 ) {

            HTML_LOG(0,"socket error: set blocking %d",errno);
            ret = errno;

        } else {

            sin->sin_family = AF_INET;
            sin->sin_port = htons(port);


            if (connect(sockfd,addr,addrlen) != 0) {


                if (errno != 150) {
                    // this seems to be OK for a non-blocking socket but the 
                    // cosde returned is not EINPROGRESS(119) or EALREADY(120)
                    HTML_LOG(0,"socket error: connect %d",errno);
                    ret = errno;
                }
            }

            if(ret == 0) {

                struct timeval t1,t2;

                int num_responses=0;
                fd_set read_set,write_set;
                FD_ZERO(&read_set);
                FD_SET(sockfd,&read_set);

                FD_ZERO(&write_set);
                FD_SET(sockfd,&write_set);

                gettimeofday(&t1,NULL);
                num_responses = select(1+sockfd,&read_set,&write_set,NULL,&timeout);
                switch(num_responses) {
                    case 0: //timeout
                        HTML_LOG(0,"timeout after %dms",timeout_millis);
                            ret = ETIMEDOUT;
                        break;
                    case 1: // success
                        ret = 0;
                        break;
                    default: // Error or more than one response!?!?!
                        ret = errno;
                        HTML_LOG(0,"error after %dms",timeout_millis);
                        break;
                }
                gettimeofday(&t2,NULL);
                if (ret == 0) {
                    elapsed = ( t2.tv_sec - t1.tv_sec ) * 1000;
                    elapsed += ( t2.tv_usec - t1.tv_usec ) / 1000;
                }
                close(sockfd);
            }
        }
    }
    HTML_LOG(0,"connect %s:%d %s : error %d : elapsed %ldms/%dms",
                host,port,
                (ret == 0 ? "ok" : "*FAILED*" ),
                ret,elapsed,timeout_millis);
    return ret;
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

// vi:sw=4:et:ts=4
