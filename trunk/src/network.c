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
 * return sock fd, < 0: error.
 * unit of timeouts: second.
 */
int connect_remote_with_timeouts(char *host, char *port, int family, int socktype, int protocol,
	int resolve_timeout, int connect_timeout, int send_timeout, int recv_timeout)
{
	struct timeval c_timeout, s_timeout, r_timeout;
	int sock_fd = -1, flags, ret = 0;

	struct addrinfo *rp, *addr_info;

	addr_info = get_remote_addr(host, port, family, socktype, protocol, resolve_timeout);
	if (addr_info == NULL)
		return -1;

	c_timeout.tv_sec = connect_timeout;
	c_timeout.tv_usec = 0;

	s_timeout.tv_sec = send_timeout;
	s_timeout.tv_usec = 0;

	r_timeout.tv_sec = recv_timeout;
	r_timeout.tv_usec = 0;

	for (rp = addr_info; rp != NULL; rp = rp->ai_next) {

		sock_fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);

		if (sock_fd == -1) {
			ret = -2;
			goto END;
		}

		flags = fcntl(sock_fd, F_GETFL, 0);
		if (flags < 0) {
			ret = -3;
			goto END;
		}

		if (fcntl(sock_fd, F_SETFL, flags | O_NONBLOCK) < 0) {
			ret = -4;
			goto END;
		}

		/* Ignore setsockopt() failures -- use default */
		setsockopt(sock_fd, IPPROTO_TCP, SO_SNDTIMEO, &s_timeout, sizeof(struct timeval));
		setsockopt(sock_fd, IPPROTO_TCP, SO_RCVTIMEO, &r_timeout, sizeof(struct timeval));

		ret = connect(sock_fd, addr_info->ai_addr, addr_info->ai_addrlen);

		if (ret == 0) {
			if (fcntl(sock_fd, F_SETFL, flags) < 0) {
				ret = -5;
				goto END;
			}
		} else if (ret < 0 && errno != EINPROGRESS) {
			ret = -6;
			goto END;
		}

		/* non-blocking listen */
		fd_set rs, ws, es;
		FD_ZERO(&rs);
		FD_SET(sock_fd, &rs);
		ws = es = rs;

		ret = select(sock_fd + 1, &rs, &ws, &es, &c_timeout);
		if (ret < 0) {
			ret = -7;
			goto END;
		} else if (0 == ret) {
			ret = -8;
			goto END;
		}

		if (!FD_ISSET(sock_fd, &rs) && !FD_ISSET(sock_fd, &ws)) {
			ret = -9;
			goto END;
		}

		int err;
		socklen_t len = sizeof(int);
		if (getsockopt(sock_fd, SOL_SOCKET, SO_ERROR, &err, &len) < 0) {
			ret = -10;
			goto END;
		}

		if (err != 0) {
			ret = -11;
			goto END;
		}

		/* socket is ready for read/write, reset to blocking mode */
		if (fcntl(sock_fd, F_SETFL, flags) < 0) {
			ret = -12;
			goto END;
		}
	}

END:

	freeaddrinfo(addr_info);
	addr_info = NULL;

	if (ret < 0) {
		if (sock_fd > 0) {
			close(sock_fd);
			sock_fd = -1;
		}
		return ret;
	} else {
		return sock_fd;
	}
}


/**
 * Need root privilege
 * @return:
 * > 0 -- ok,
 * < 0 -- failed.
 * Ping: reference <Unix network programming>, volume 1, third edition.
 */
int ping (char *host)
{
	#define BUF_SIZE	1500
	#define ICMP_REQUEST_DATA_LEN 56

	struct addrinfo *ai = get_remote_addr(host, NULL, AF_INET, SOCK_RAW, IPPROTO_ICMP, 5);
	if (ai == NULL)
		return -2;

	pid_t pid = getpid() & 0xffff; /* ICMP ID field is 16 bits */

	char send_buf[BUF_SIZE];
	char recv_buf[BUF_SIZE];
	char control_buf[BUF_SIZE];

	int sockfd = socket(AF_INET, SOCK_RAW, IPPROTO_ICMP);

	struct timeval timeout = {5, 0};
	setsockopt(sockfd, IPPROTO_ICMP, SO_SNDTIMEO, &timeout, sizeof(struct timeval));
	setsockopt(sockfd, IPPROTO_ICMP, SO_RCVTIMEO, &timeout, sizeof(struct timeval));

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
	}

	free(ai);
	close(sockfd);

	return ret;
}
