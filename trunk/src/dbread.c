#include <string.h>
#include <stdio.h>
#include <assert.h>

#include "util.h"

// present a line at a time (like fgets) but avoid inspecting each line.
#define BUF_SIZE 65536
#define MAX_LINE 10000



static char *buf = NULL;

// Provide a faster way of reading index.db. Instead of fgets()...
// the calling function uses dbget(fp,&p).
// Because fgets is NOT used, each line is NOT terminated by 'nul'
// but the calling function must look for runs of \n \r

// start = position last looked at by calling function (initially NULL)
// returns pointer to start of next item in the buffer.
char *dbget(FILE *fp,char **start,char **data_end)
{
    static char *buf_end;
    static int eof=0;
    if (buf == NULL) {
        // BUF_SIZE must be greater than 2 * MAX_LINE to allow memcpy
        assert(BUF_SIZE > 2 * MAX_LINE);
        assert(*start == NULL);
        buf = MALLOC(BUF_SIZE);
        buf_end = buf + BUF_SIZE;
        *start = buf;
        *data_end = buf;
    }

    if (*start >= *data_end ) {
        if (eof) {
            *data_end = *start = NULL;
        } else {
            if ((buf_end - *data_end ) < MAX_LINE) {
                // move current data to start of buffer.
                memcpy(*start,buf,*data_end-*start);
                *data_end += ( buf - *start);
                *start = buf;
            }
            // read in as much data as possible.
            int remain = buf_end-*data_end;
            int bytes = fread(*data_end,1,remain,fp);
            if (bytes < remain) {
                eof = 1;
            }
            *data_end += bytes;
        }
    }
    return *start;
}
