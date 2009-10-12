CC=gcc


ARCH=100
ifdef WINDIR
ifeq ($(ARCH),200) 
		CROSS=/mips-4.3/
		CC=$(CROSS)/bin/mips-linux-gnu-gcc
		LD=$(CROSS)/bin/mips-linux-gnu-gcc
		CFLAGS_ARCH=-EL
		LDFLAGS_ARCH=-EL
		BADARCH=100
else
		CROSS=/cross-gcc/mipsel-linux-uclibc
		CC=$(CROSS)/bin/mipsel-linux-uclibc-gcc
		LD=$(CROSS)/bin/mipsel-linux-uclibc-gcc
		BADARCH=200
endif
else
CROSS=/usr/local/mips
CC=$(CROSS)/bin/mipsel-linux-uclibc-gcc
LD=$(CROSS)/bin/mipsel-linux-uclibc-gcc
endif

CFLAGS=-O2 -Wall -DOUT=$(OUT) $(CFLAGS_ARCH)

OBJS=oversight.o util.o hashtable.o hashtable_itr.o hashtable_utility.o gaya_cgi.o array.o \
	config.o hashtable_loop.o vasprintf.o db.o dbfield.o dboverview.o display.o actions.o macro.o \
	admin.o mount.o time.o network.o dbplot.o

SRC=$(OBJS:.o=.c)

HEADERS=$(SRC:.c=.h)

HASH_OBJECTS=hashtable.o hashtable_itr.o tester.o


TARGET=oversight
TARGET_DIR=bin/nmt$(ARCH)
EXE=../$(TARGET_DIR)/$(TARGET)

LIBS=-lm

LDFLAGS=-g -Wall -O $(LIBS) $(LDFLAGS_ARCH)

all: $(ARCH) $(TARGET) ftp

$(OBJS): $(HEADERS) Makefile

$(ARCH):
	@if [ -f $(BADARCH) ] ; then echo "Do make clean" ; false ; fi
	touch $(ARCH)


$(TARGET):  $(OBJS)
	ctags -R .
	$(CC) $(LDFLAGS) -o $(TARGET) $(OBJS)
	cp $(TARGET) $(EXE)
	sleep 1

ftp: $(EXE)
	cd ../$(TARGET_DIR) && ../../util/send $(ARCH) /Apps/oversight/$(TARGET_DIR) $(TARGET) 

tester: $(HASH_OBJECTS)
	$(CC) $(LDFLAGS) -o tester $(HASH_OBJECTS)

tidy:
	rm -f *.o $(ARCH) $(BADARCH)

clean: tidy
	rm -f tester old_tester $(TARGET)
