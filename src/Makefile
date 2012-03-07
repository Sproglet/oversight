CC=gcc


ARCH=200
VERFILE=verfile

REV='"`cat verfile`"'
#
# Toolchains:
# nmt200
# http://www.codesourcery.com/downloads/public/public/gnu_toolchain/
# https://sourcery.mentor.com/sgpp/lite/mips/portal/package4432/public/mips-linux-gnu/
# linux  : mips-4.3-154-mips-linux-gnu-i686-pc-linux-gnu.tar.bz2
# windows: mips-4.3-154-mips-linux-gnu-i686-mingw32.tar.bz2
#
# nmt100
# http://www.lundman.net/ftp/nmt/
# linux  : nmt-linux-intel-toolchain-gcc-4.0.4-linux-2.6.15.7-uclibc-0.9.28.3-lundman-P1.tgz
# windows: nmt-cygwin-toolchain-gcc-4.2.2-linux-2.6.15.7-uclibc-0.9.28.3.tar.bz2

ifdef WINDIR
ifeq ($(ARCH),200) 
	CROSS_DIR=/cygdrive/c/nmt/cross-gcc/nmt200/mips-4.3/
	CFLAGS_ARCH=-EL
	LDFLAGS_ARCH=-EL
else
	CROSS_DIR=/cygdrive/c/nmt/cross-gcc/nmt100/mipsel-linux-uclibc
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

#CFLAGS=-O3 -Wall -Wunused-parameter -DOUT=$(OUT) -DOVS_VERSION='"$(REV)"' $(CFLAGS_ARCH)
CFLAGS=-O3 -Wall -DOUT=$(OUT) -D__USE_LARGEFILE64 -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -DOVS_VERSION='"$(REV)"' $(CFLAGS_ARCH)
#-DNOLOG=$(NOLOG)

# Most stable last to speed compile-fail cycle
OBJS=initials.o utf8.o tree.o \
	 abet.o filter.o exp.o dbnames.o types.o dbitem.o list.o gaya.o \
	 macro.o template.o template_condition.o  variables.o \
	grid.o grid_display.o tv_detail.o movie_detail.o display.o oversight.o util.o \
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
	@echo [CC] $<
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


$(TARGET):  libutf8proc.a tags $(OBJS)
	$(CC) $(LDFLAGS) -o $(TARGET) $(OBJS) libutf8proc.a
	$(STRIP) $(TARGET)
	cp $(TARGET) $(EXE)
	sleep 1

tags: $(SRC) $(HEADERS)
	ctags *.[ch]

# BEGIN Rules adapted from original utf8proc makefile ====================
#

utf8proc.o: utf8proc.c

libutf8proc.a: utf8proc.o
	rm -f libutf8proc.a
	ar rs libutf8proc.a utf8proc.o


#utf8proc.o: utf8proc.h utf8proc.c utf8proc_data.c
#	echo DOIT
	

#	$(cc) -c -o utf8proc.o utf8proc.c


#cc -O2 -std=c99 -pedantic -Wall -fpic  -c -o utf8proc.o utf8proc.c
#utf8proc.c:1: warning: -fpic ignored for target (all code is position independent)
#ar: creating libutf8proc.a
#cc -O2 -std=c99 -pedantic -Wall -fpic  -shared -o libutf8proc.so utf8proc.o
#chmod a-x libutf8proc.so

# END Rules adapted from original utf8proc makefile ====================

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
