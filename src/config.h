#ifndef __CONFIG_H_ALORD__
#define __CONFIG_H_ALORD__

#include "hashtable.h"

struct hashtable *config_load(char *filename);
struct hashtable *config_load_fp(FILE *fp);
void config_write(struct hashtable *cfg,char *filename);
void config_write_fp(struct hashtable *cfg,FILE *fp);
void config_unittest();
struct hashtable *config_load_wth_defaults(char *d,char *defaults_file,char *main_file);

#endif
