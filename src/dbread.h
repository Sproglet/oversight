#ifndef __OVS_DBREAD_H__
#define __OVS_DBREAD_H__

typedef struct ReadBufStruct {
    char *data_start;
    char *data_end;
    int fd;
    char *buf;
    char *buf_end;
    int buf_size;
    int max_line;
    int eof;
} ReadBuf;


ReadBuf *dbreader_open(char *name);
void dbreader_close(ReadBuf *b);
int dbreader_advance(char *position,ReadBuf *buf);
#endif
