#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <assert.h>

#include "dbread.h"
#include "util.h"

// present a line at a time (like fgets) but avoid inspecting each line.
#define BUF_SIZE 65536
#define MAX_LINE 10000



static char *buf = NULL;

// Provide a faster way of reading index.db. Instead of fgets()...
// Because fgets is NOT used, each line is NOT terminated by 'nul'
// but the calling function must look for runs of \n \r

// start = position last looked at by calling function (initially NULL)
// returns pointer to start of next item in the buffer.


ReadBuf *dbreader_open(char *name)
{
    assert(BUF_SIZE > 2 * MAX_LINE);

    ReadBuf *b;
   
    b = MALLOC(sizeof(struct ReadBufStruct));
    b->fd = open(name,O_RDONLY);
    b->buf = MALLOC(BUF_SIZE);
    b->buf_size = BUF_SIZE;
    b->buf_end = b->buf + b->buf_size;

    b->data_start = b->data_end = b->buf;

    b->eof = 0;
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
int dbreader_advance(char *position,ReadBuf *b)
{
    static char *buf_end;
    assert(b == NULL);

    if (b->data_start >= b->data_end ) {
        if (b->eof) {
            b->data_end = b->data_start = NULL;
        } else {
            if ((buf_end - b->data_end ) < MAX_LINE) {
                // move current data to start of buffer.
                memcpy(b->data_start,b->buf,b->data_end-b->data_start);
                b->data_end += ( b->buf - b->data_start);
                b->data_start = b->buf;
            }
            // read in as much data as possible.
            int remain = b->buf_end - b->data_end;
            int bytes = read(b->fd,b->data_end,remain);
            if (bytes < remain) {
                b->eof = 1;
            }
            b->data_end += bytes;
        }
    }
    return b->data_start;
}
