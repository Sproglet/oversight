CC=gcc


ARCH=200
VERFILE=verfile

REV='"`cat verfile`"'

ifdef WINDIR
ifeq ($(ARCH),200) 
	CROSS_DIR=/mips-4.3/
	CFLAGS_ARCH=-EL
	LDFLAGS_ARCH=-EL
else
	CROSS_DIR=/cross-gcc/mipsel-linux-uclibc
endif
else
ifeq ($(ARCH),200) 
	CROSS_DIR=/usr/local/mips-4.3
	CFLAGS_ARCH=-EL
	LDFLAGS_ARCH=-EL
else
	CROSS_DIR=/usr/local/mips
endif
endif

ifeq ($(ARCH),200) 
	BADARCH=100
	CROSS_TYPE=mips-linux-gnu
else
	BADARCH=200
	CROSS_TYPE=mipsel-linux-uclibc
endif

CC=$(CROSS_DIR)/bin/$(CROSS_TYPE)-gcc
LD=$(CROSS_DIR)/bin/$(CROSS_TYPE)-gcc
STRIP=$(CROSS_DIR)/bin/$(CROSS_TYPE)-strip

CFLAGS=-O3 -Wall -DOUT=$(OUT) -DOVS_VERSION='"$(REV)"' $(CFLAGS_ARCH)

OBJS=gaya.o macro.o \
	 oversight.o util.o hashtable.o hashtable_itr.o hashtable_utility.o gaya_cgi.o array.o \
	config.o hashtable_loop.o vasprintf.o db.o dbfield.o dboverview.o display.o actions.o \
	admin.o mount.o time.o network.o dbplot.o permissions.o subtitles.o

SRC=$(OBJS:.o=.c)

HEADERS=$(SRC:.c=.h)

HASH_OBJECTS=hashtable.o hashtable_itr.o tester.o


TARGET=oversight
TARGET_DIR=bin/nmt$(ARCH)
EXE=../$(TARGET_DIR)/$(TARGET)

LIBS=-lm

LDFLAGS=-g -Wall -O $(LIBS) $(LDFLAGS_ARCH)

all: $(ARCH) $(TARGET) 

push: ftp


$(OBJS): $(HEADERS) Makefile

$(HEADERS): $(VERFILE)

$(VERFILE):
	echo r`../util/svnv oversight 1` > $(VERFILE)


$(ARCH):
	if [ -f $(BADARCH) ] ; then echo "Do make clean" ; false ; fi
	touch $(ARCH)


$(TARGET):  $(OBJS)
	ctags -R .
	$(CC) $(LDFLAGS) -o $(TARGET) $(OBJS)
	$(STRIP) $(TARGET)
	cp $(TARGET) $(EXE)
	sleep 1

ftp: all
	cd ../$(TARGET_DIR) && ../../util/send $(ARCH) /Apps/oversight/$(TARGET_DIR) $(TARGET) 

tester: $(HASH_OBJECTS)
	$(CC) $(LDFLAGS) -o tester $(HASH_OBJECTS)

tidy:
	rm -f *.o $(ARCH) $(BADARCH) $(VERFILE)

clean: tidy
	rm -f tester old_tester $(TARGET)
