#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "util.h"


typedef struct {

	char *id;
	char *value;

} DbField;

DbField *newDbField(char *id,char *v) {

	DbField *f = (DbField *) MALLOC(sizeof(DbField));
	assert(f);

	f->id = strdup(id);
	f->value = strdup(v);

	return f;
}


void freeDbField(DbField **f) {

	free((*f)->id); (*f)->id = NULL;
	free((*f)->value); (*f)->value = NULL;

	free(*f); *f = NULL;

}

/*
int main(int argc, char ** argv) {

	DbField *f = newDbField("a","b");

	printf("<%s>\n",f->id);

	freeDbField(&f);
}
*/

