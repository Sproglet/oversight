CC=gcc


ARCH=
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

ifneq ($(ARCH),cygwin) 

ifeq ($(ARCH),200) 
		CFLAGS_ARCH=-EL -D__USE_LARGEFILE64 -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -DSTAT64=stat64
		LDFLAGS_ARCH=-EL
		CROSS_TYPE=mips-linux-gnu
else
ifeq ($(ARCH),100) 
			CFLAGS_ARCH=-D__USE_LARGEFILE64 -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -DSTAT64=stat64
			CROSS_TYPE=mipsel-linux-uclibc
endif
endif

ifdef WINDIR 
ifeq ($(ARCH),200) 
		CROSS_DIR=/cygdrive/c/nmt/cross-gcc/nmt200/mips-4.3/
else
ifeq ($(ARCH),100) 
			CROSS_DIR=/cygdrive/c/nmt/cross-gcc/nmt100/mipsel-linux-uclibc
endif
endif 

else # !WINDIR

ifeq ($(ARCH),200) 
		CROSS_DIR=~/nmt/packages/toolchain_200/mips-4.3
else
ifeq ($(ARCH),100) 
			CROSS_DIR=~/nmt/packages/toolchain_100/usr/local/mips
endif
endif

endif # WINDIR

	CC=$(CROSS_DIR)/bin/$(CROSS_TYPE)-gcc
	LD=$(CROSS_DIR)/bin/$(CROSS_TYPE)-gcc
	STRIP=$(CROSS_DIR)/bin/$(CROSS_TYPE)-strip
	TARGET_DIR=bin/nmt$(ARCH)
else #pc
	TARGET_DIR=bin/$(ARCH)
	CFLAGS_ARCH=-DSTAT64=stat
	STRIP=strip
endif

#CFLAGS=-O2 -Wall -Wunused-parameter -DOUT=$(OUT) -DOVS_VERSION='"$(REV)"' $(CFLAGS_ARCH)
CFLAGS=-O2 -Wall -DOUT=$(OUT) -DOVS_VERSION='"$(REV)"' $(CFLAGS_ARCH)
#-DNOLOG=$(NOLOG)

# Most stable last to speed compile-fail cycle
OBJS=b64.o initials.o utf8.o tree.o  \
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
	yamj.o utf8proc.o

SRC=$(OBJS:.o=.c)

HEADERS=$(SRC:.c=.h)

HASH_OBJECTS=hashtable.o hashtable_itr.o tester.o

.c.o:
	@echo [CC] [$(ARCH)] $<
	@$(CC) $(CFLAGS) -c $<

TARGET=oversight
EXE=../$(TARGET_DIR)/$(TARGET)

LIBS=-lm

LDFLAGS=-g -Wall -O2 $(LIBS) $(LDFLAGS_ARCH)

all: $(ARCH) $(TARGET) daemon

push: ftp

$(OBJS): $(HEADERS) Makefile 

$(HEADERS): $(VERFILE)

$(VERFILE):
	echo r`../util/svnv oversight 1` > $(VERFILE)


200:
	if [ -f 100 -o -f cygwin ] ; then echo "Do make clean" ; false ; fi
	touch 200

100:
	if [ -f 200 -o -f cygwin ] ; then echo "Do make clean" ; false ; fi
	touch 100

cygwin:
	if [ -f 100 -o -f 200 ] ; then echo "Do make clean" ; false ; fi
	touch cygwin


$(TARGET):  tags $(OBJS)
	$(CC) $(LDFLAGS) -o $(TARGET) $(OBJS)
	$(STRIP) $(TARGET)
	cp $(TARGET) $(EXE)
	sleep 1

tags: $(SRC) $(HEADERS)
	ctags *.[ch]

daemon.o: daemon.c

daemon: daemon.o
	$(CC) $(LDFLAGS) -o daemon daemon.o
	cp daemon ../$(TARGET_DIR)/.

ftp: all
	cd ../$(TARGET_DIR) && ../../util/send $(ARCH) /Apps/oversight/$(TARGET_DIR) $(TARGET) 

tester: $(HASH_OBJECTS)
	$(CC) $(LDFLAGS) -o tester $(HASH_OBJECTS)

tidy:
	rm -f *.o 100 200 cygwin $(VERFILE)

clean: tidy
	rm -f tester old_tester $(TARGET) daemon
