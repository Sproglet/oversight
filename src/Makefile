CC=gcc

CFLAGS=-g -Wall 

#ifeq ($(OUT),nmt)
#endif
CC=/cross-gcc/mipsel-linux-uclibc/bin/mipsel-linux-uclibc-gcc
LD=/cross-gcc/mipsel-linux-uclibc/bin/mipsel-linux-uclibc-gcc
CFLAGS=-g -Wall -DOUT=$(OUT)

OVS_OBJS=oversight.o util.o hashtable.o hashtable_itr.o hashtable_utility.o gaya_cgi.o array.o \
	config.o hashtable_loop.o vasprintf.o db.o dbfield.o dboverview.o display.o actions.o macro.o \
	admin.o

SRC=$(OVS_OBJS:.o=.c)

HEADERS=$(SRC:.c=.h)

OBJECTS=hashtable.o hashtable_itr.o tester.o



LIBS=-lm

LDFLAGS=-g -Wall -O $(LIBS)

all: oversight share


oversight:  $(OVS_OBJS)
	ctags -R .
	$(CC) $(LDFLAGS) -o oversight2.cgi $(OVS_OBJS)

share: /cygdrive/a/start_app.sh 
	cp -v oversight2.cgi /cygdrive/a/Apps/oversight/.

/cygdrive/a/start_app.sh:
	net use a: '\\192.168.88.11\share' 1234  /user:nmt


tester: $(OBJECTS)
	$(CC) $(LDFLAGS) -o tester $(OBJECTS)

tidy:
	rm -f *.o

clean: tidy
	rm -f tester old_tester oversight
