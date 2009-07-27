#ifndef __ARRAY_H_ALORD__
#define __ARRAY_H_ALORD__

struct array_str {
    void **array;
    int size;
    int mem_size;
    void (*free_fn)(void *);
};

typedef struct array_str Array;

void array_print(char *label,Array *a);
Array *array_new(void(*fr)(void *) );
void array_add(Array *a,void *ptr);
void array_set(Array *a,int idx,void *ptr);

void array_free(Array *a );


Array *split(char *s,char *pattern,int reg_opts);
Array *splitc(char *s,char c);

#endif
