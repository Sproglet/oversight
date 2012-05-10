// $Id$
#define _FILE_OFFSET_BITS 64
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <errno.h>

unsigned long long analizefileOSHahs(char *fileName){
 /*
  * Public Domain implementation by Kamil Dziobek. turbos11(at)gmail.com
  * This code implements Gibest hash algorithm first use in Media Player Classics
  * For more implementation(various languages and authors) see:
  * http://trac.opensubtitles.org/projects/opensubtitles/wiki/HashSourceCodes   
  *
  * -works only on little-endian procesor DEC, Intel and compatible
  * -sizeof(unsigned long long) must be 8
  */
 
  FILE        *file;
  unsigned int i;
  unsigned long long t1=0;


#define LONGSIZ 8
#define K64 65536L
#define NUMLONGS ( K64 / sizeof(unsigned long long))

  assert(sizeof(unsigned long long) == LONGSIZ);
  unsigned long long buffer1[ 2*NUMLONGS ];

  long unsigned int items;

  file = fopen(fileName, "rb");
  if (file) {


      printf("begin\n");
      fflush(stdout);
      if ((items = fread(buffer1, LONGSIZ , NUMLONGS , file)) !=  NUMLONGS) {

          fprintf(stderr,"failed to read [%s] start block (%lu != %lu)\n",fileName,items,NUMLONGS);

      } else if (fseek(file, -K64 , SEEK_END) != 0 ) {

          fprintf(stderr,"failed to seek [%s]  end \n",fileName);

      } else {
          
          printf("at end\n");
      fflush(stdout);

      /**
          if ( ( length = ftell(file) ) <= 0 ) {

              fprintf(stderr,"failed to get length of [%s]\n",fileName);

          } else {
              
              printf("at end\n");
      fflush(stdout);
              printf("length = %ld\n",length);
      fflush(stdout);

              if (fseek(file, length - K64, SEEK_SET) != 0 ) {

                  fprintf(stderr,"failed to seek [%s]  end block\n",fileName);

              } else {
      **/

                  printf("at end block\n");
                  fflush(stdout);

                  //printf("pos = %lld\n",ftell(file));
                  fflush(stdout);
                  
                  if ((items = fread(buffer1+NUMLONGS, LONGSIZ , NUMLONGS, file)) !=  NUMLONGS) {

                      fprintf(stderr,"failed to read [%s] end block (%lu != %lu)\n",fileName,items,NUMLONGS);

                  } else {
                      printf("read end block\n");
                      fflush(stdout);
                      //printf("finished at = %lld\n",ftell(file));
                      fflush(stdout);

                      for ( i=0 ; i< NUMLONGS*2 ; i++ ) {
                         t1 += buffer1[i];
                      }
                      t1 += ftell(file); //add filesize
                  }
  /***
              }
          }
  **/
      }
      fclose(file); 
  } else {
      fprintf(stderr," Failed to open [%s] errno=%d\n",fileName,errno);
  }
  return  t1;
};


int subtitle_main(int argc,char **argv) {
    int ret = 0;
    int i;
    for (i = 0 ;  i < argc ; i++ ) {
        printf("[%s]\n",argv[i]);
    }
    long long val =  analizefileOSHahs(argv[2]);
    printf("%0llx",val);


    char *p = (char *)&val;
    for(i = 0 ; i < sizeof(val) ; i++ ) {
        printf(" %x",*(p+i));
    }
    printf("\n");


    return ret;
}
// vi:sw=4:et:ts=4
