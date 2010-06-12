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
	CROSS_DIR=~/nmt/packages/toolchain_200/mips-4.3
	CFLAGS_ARCH=-EL
	LDFLAGS_ARCH=-EL
else
	CROSS_DIR=~/nmt/packages/toolchain_100/usr/local/mips
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

# Most stable last to speed compile-fail cycle
OBJS=list.o gaya.o macro.o template.o template_condition.o  variables.o \
	grid.o display.o oversight.o util.o \
	config.o \
   	db.o dbfield.o dboverview.o actions.o \
	admin.o mount.o \
   	dbplot.o permissions.o dbread.o subtitles.o \
	gaya_cgi.o array.o \
   	time.o network.o \
   	hashtable_loop.o vasprintf.o \
   	hashtable.o hashtable_itr.o hashtable_utility.o \

SRC=$(OBJS:.o=.c)

HEADERS=$(SRC:.c=.h)

HASH_OBJECTS=hashtable.o hashtable_itr.o tester.o

.c.o:
	@echo [CC] $(CFLAGS) $<
	@$(CC) $(CFLAGS) -c $<

TARGET=oversight
TARGET_DIR=bin/nmt$(ARCH)
EXE=../$(TARGET_DIR)/$(TARGET)

LIBS=-lm

LDFLAGS=-g -Wall -O3 $(LIBS) $(LDFLAGS_ARCH)

all: $(ARCH) $(TARGET) daemon

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

daemon.o: daemon.c

daemon: daemon.o
	$(CC) $(LDFLAGS) -o daemon daemon.o
	cp daemon ../$(TARGET_DIR)/.

ftp: all
	cd ../$(TARGET_DIR) && ../../util/send $(ARCH) /Apps/oversight/$(TARGET_DIR) $(TARGET) 

tester: $(HASH_OBJECTS)
	$(CC) $(LDFLAGS) -o tester $(HASH_OBJECTS)

tidy:
	rm -f *.o $(ARCH) $(BADARCH) $(VERFILE)

clean: tidy
	rm -f tester old_tester $(TARGET) daemon
