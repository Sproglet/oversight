CC=gcc


ifdef WINDIR
CROSS=/cross-gcc/mipsel-linux-uclibc
REMOTE_TARGET=ftp
else
CROSS=/usr/local/mips
REMOTE_TARGET=ftp
endif

CC=$(CROSS)/bin/mipsel-linux-uclibc-gcc
LD=$(CROSS)/bin/mipsel-linux-uclibc-gcc
XXCFLAGS=-g -Wall -DOUT=$(OUT)
#CFLAGS=-g -Wall 
CFLAGS=-O2 -Wall -DOUT=$(OUT)

OVS_OBJS=oversight.o util.o hashtable.o hashtable_itr.o hashtable_utility.o gaya_cgi.o array.o \
	config.o hashtable_loop.o vasprintf.o db.o dbfield.o dboverview.o display.o actions.o macro.o \
	admin.o mount.o time.o network.o

SRC=$(OVS_OBJS:.o=.c)

HEADERS=$(SRC:.c=.h)

OBJECTS=hashtable.o hashtable_itr.o tester.o


EXE=oversight

LIBS=-lm

LDFLAGS=-g -Wall -O $(LIBS)

all: oversight $(REMOTE_TARGET)



oversight:  $(OVS_OBJS)
	ctags -R .
	$(CC) $(LDFLAGS) -o $(EXE) $(OVS_OBJS)
	cp $(EXE) ..

mount: /mnt/hdx/start_app.sh 
	cp -v $(EXE) /mnt/hdx/Apps/oversight/.

share: /cygdrive/a/start_app.sh 
	cp -v $(EXE) /cygdrive/a/Apps/oversight/.

ftp: oversight
	/bin/sh ../send /Apps/oversight $(EXE) 


/mnt/hdx/start_app.sh:
	sudo mount /mnt/hdx

/cygdrive/a/start_app.sh:
	net use a: '\\192.168.88.11\share' 1234  /user:nmt


tester: $(OBJECTS)
	$(CC) $(LDFLAGS) -o tester $(OBJECTS)

tidy:
	rm -f *.o

clean: tidy
	rm -f tester old_tester oversight
