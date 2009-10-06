CC=gcc


ARCH=100
ifdef WINDIR
ifeq ($(ARCH),200) 
		CROSS=/mips-4.3/
		CC=$(CROSS)/bin/mips-linux-gnu-gcc
		LD=$(CROSS)/bin/mips-linux-gnu-gcc
		CFLAGS_ARCH=-EL
		LDFLAGS_ARCH=-EL
else
		CROSS=/cross-gcc/mipsel-linux-uclibc
		CC=$(CROSS)/bin/mipsel-linux-uclibc-gcc
		LD=$(CROSS)/bin/mipsel-linux-uclibc-gcc
endif
else
CROSS=/usr/local/mips
CC=$(CROSS)/bin/mipsel-linux-uclibc-gcc
LD=$(CROSS)/bin/mipsel-linux-uclibc-gcc
endif

CFLAGS=-O2 -Wall -DOUT=$(OUT) $(CFLAGS_ARCH)

OVS_OBJS=oversight.o util.o hashtable.o hashtable_itr.o hashtable_utility.o gaya_cgi.o array.o \
	config.o hashtable_loop.o vasprintf.o db.o dbfield.o dboverview.o display.o actions.o macro.o \
	admin.o mount.o time.o network.o

SRC=$(OVS_OBJS:.o=.c)

HEADERS=$(SRC:.c=.h)

OBJECTS=hashtable.o hashtable_itr.o tester.o


TARGET=oversight
TARGET_DIR=bin/nmt$(ARCH)
EXE=../$(TARGET_DIR)/$(TARGET)

LIBS=-lm

LDFLAGS=-g -Wall -O $(LIBS) $(LDFLAGS_ARCH)

all: $(TARGET) ftp



$(TARGET):  $(OVS_OBJS)
	ctags -R .
	$(CC) $(LDFLAGS) -o $(TARGET) $(OVS_OBJS)
	cp $(TARGET) $(EXE)

ftp: oversight.$(ARCH)
	cd .. && ./util/send $(ARCH) /Apps/oversight/$(TARGET_DIR) $(TARGET) 

tester: $(OBJECTS)
	$(CC) $(LDFLAGS) -o tester $(OBJECTS)

tidy:
	rm -f *.o

clean: tidy
	rm -f tester old_tester $(TARGET)
