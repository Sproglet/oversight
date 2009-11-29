CC=gcc


ARCH=100
VERFILE=verfile

REV='"`cat verfile`"'
ifdef WINDIR
ifeq ($(ARCH),200) 
		CROSS=/mips-4.3/
		CC=$(CROSS)/bin/mips-linux-gnu-gcc
		LD=$(CROSS)/bin/mips-linux-gnu-gcc
		STRIP=$(CROSS)/bin/mips-linux-gnu-strip
		CFLAGS_ARCH=-EL
		LDFLAGS_ARCH=-EL
		BADARCH=100
else
		CROSS=/cross-gcc/mipsel-linux-uclibc
		CC=$(CROSS)/bin/mipsel-linux-uclibc-gcc
		LD=$(CROSS)/bin/mipsel-linux-uclibc-gcc
		STRIP=$(CROSS)/bin/mipsel-linux-uclibc-strip
		BADARCH=200
endif
else
CROSS=/usr/local/mips
CC=$(CROSS)/bin/mipsel-linux-uclibc-gcc
LD=$(CROSS)/bin/mipsel-linux-uclibc-gcc
endif

CFLAGS=-O2 -Wall -DOUT=$(OUT) -DOVS_VERSION='"$(REV)"' $(CFLAGS_ARCH)

OBJS=oversight.o util.o hashtable.o hashtable_itr.o hashtable_utility.o gaya_cgi.o array.o \
	config.o hashtable_loop.o vasprintf.o db.o dbfield.o dboverview.o display.o actions.o macro.o \
	admin.o mount.o time.o network.o dbplot.o permissions.o

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
	@if [ -f $(BADARCH) ] ; then echo "Do make clean" ; false ; fi
	touch $(ARCH)


$(TARGET):  $(OBJS)
	ctags -R .
	$(CC) $(LDFLAGS) -o $(TARGET) $(OBJS)
	$(STRIP) $(TARGET)
	cp $(TARGET) $(EXE)
	sleep 1

ftp: all
	cd ../$(TARGET_DIR) && ../../util/send $(ARCH) /Apps/oversight/$(TARGET_DIR) $(TARGET) 
	# Replace original CGI file
	cd .. && ./util/send $(ARCH) /Apps/oversight/ $(TARGET).cgi

tester: $(HASH_OBJECTS)
	$(CC) $(LDFLAGS) -o tester $(HASH_OBJECTS)

tidy:
	rm -f *.o $(ARCH) $(BADARCH) $(VERFILE)

clean: tidy
	rm -f tester old_tester $(TARGET)
