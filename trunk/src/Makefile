CC=gcc

CFLAGS=-g -Wall 

ifeq ($(OUT),nmt)
	CC=/cross-gcc/mipsel-linux-uclibc/bin/mipsel-linux-uclibc-gcc
	LD=/cross-gcc/mipsel-linux-uclibc/bin/mipsel-linux-uclibc-gcc
	CFLAGS=-g -Wall -O -DOUT=$(OUT)
endif

OVS_OBJS=oversight.o util.o hashtable.o hashtable_itr.o hashtable_utility.o gaya_cgi.o array.o \
	config.o hashtable_loop.o vasprintf.o db.o

SRC=$(OVS_OBJS:.o=.c)

HEADERS=$(SRC:.c=.h)

OBJECTS=hashtable.o hashtable_itr.o tester.o



LIBS=-lm

LDFLAGS=-g -Wall -O $(LIBS)


oversight:  $(OVS_OBJS)
	$(CC) $(LDFLAGS) -o oversight2.cgi $(OVS_OBJS)

tester: $(OBJECTS)
	$(CC) $(LDFLAGS) -o tester $(OBJECTS)

tidy:
	rm *.o

clean: tidy
	rm -f tester old_tester oversight
