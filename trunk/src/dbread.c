// $Id:$
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <assert.h>

#include "gaya_cgi.h"
#include "dbread.h"
#include "util.h"

// present a line at a time (like fgets) but avoid inspecting each line.
#define BUF_SIZE (4*65536)
#define MAX_LINE 10000

void read_data(ReadBuf *b);
void move_and_read(ReadBuf *b);

// Provide a faster way of reading index.db. Instead of fgets()...
// Because fgets is NOT used, each line is NOT terminated by 'nul'
// but the calling function must look for runs of \n \r

// start = position last looked at by calling function (initially NULL)
// returns pointer to start of next item in the buffer.


ReadBuf *dbreader_open(char *name)
{
    assert(BUF_SIZE > 2 * MAX_LINE);

    ReadBuf *b=NULL;
    int fd;
   
    fd = open(name,O_RDONLY);
    if (fd != -1) {
        b = MALLOC(sizeof(struct ReadBufStruct));
        b->fd = fd;
        b->buf = MALLOC(BUF_SIZE+1);
        b->buf_size = BUF_SIZE;
        b->buf_end = b->buf + b->buf_size;

        b->data_start = b->data_end = b->buf;

        // Flag End of Data.
        b->data_start[0] = '\0';

        b->eof_internal = 0;
        b->eof_client = 0;

        read_data(b);
    }
    return b;
}

void dbreader_close(ReadBuf *b)
{
    close(b->fd);
    FREE(b->buf);
    FREE(b);
}

/*
 * Read more data. 
 * This should be called when the calling program has processed up to buf->data_end.
 * After calling buf->data_start,buf->data_end point to new data block.
 *
 * An calling example wpound be
 *
 * buf = dbreader_open(filename);
 * p = buf->data_start;
 *
 * while(1) {
 *
 *   if (p >= buf->data_end) {
 *     if ((p = dbreader_advance(buf)) == NULL) {
 *        END OF FILE
 *        break;
 *     }
 *   }
 *   ...
 *
 * }
 *
 * dbreader_close(buf);
 *
 */
#define EOL(c)  ((c) == '\n'  ||  (c) == '\r') 
char *dbreader_advance_line(ReadBuf *b,char *pos)
{

    if (!b->eof_client)  {

        char *next = pos;
        char *end = b->data_end;

        //HTML_LOG(0,"pre advance [%.20s] ",next);
        while (*next && !EOL(*next) ) next++;
        //HTML_LOG(0,"pre advance to eol [%.20s] ",next);
        while (*next && EOL(*next) ) next++;
        //HTML_LOG(0,"post advance past eol [%.20s] ",next);
        //

        // This is a lazy check. We should really check we are not overunning the 
        // buffer in the above while loops, but that would mean that MAX_LINE is
        // not big enough and the buffer holds a partial line (ie no \n nor \r )
        // This is a rare case, so for performance only (rather than correctness)
        // we check we have not overrun the buffer at the end.
        if (next > end) next = end;

        b->data_start = next;

        move_and_read(b);

        if (b->eof_internal) {
            if (b->data_start[0] == '\0' || b->data_start >= b->data_end ) {
                b->eof_client = 1;
                b->data_start = NULL;
            }
        }

    }

    return b->data_start;
}
void dbreader_set_position(ReadBuf *b,char *pos)
{
    b->data_start = pos;
}

void move_and_read(ReadBuf *b) {
    // move current data to start of buffer.
    if (!b->eof_client) {
        if (b->buf_end - b->data_start < MAX_LINE) {
            int data_size = b->data_end - b->data_start;
            memcpy(b->buf,b->data_start,data_size);
            HTML_LOG(0,"moved %d bytes",data_size);
            b->data_end = b->buf + data_size;
            b->data_end[0] = '\0';
            b->data_start = b->buf;
            read_data(b);
        }
    }
}

void read_data(ReadBuf *b)
{
    // read in as much data as possible.

    if (!b->eof_internal) {

        int buf_remain = b->buf_end - b->data_end;

        int bytes = read(b->fd,b->data_end,buf_remain);

        HTML_LOG(0,"read %d of %d bytes",bytes,buf_remain);

        if (bytes < buf_remain) {
            HTML_LOG(1,"eof0 ");
            b->eof_internal = 1;
        }
        b->data_end += bytes;
        // nul = end of read data NOT EOL
        b->data_end[0] = '\0';
    }
}
// vi:sw=4:et:ts=4
