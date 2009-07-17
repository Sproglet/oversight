#ifndef __ARRAY_H_ALORD__
#define __ARRAY_H_ALORD__

struct array_str {
    void **array;
    int size;
    int mem_size;
    void (*free_fn)(void *);
};

typedef struct array_str array;

void array_print(char *label,array *a);
array *array_new(void(*fr)(void *) );
void array_add(array *a,void *ptr);
void array_set(array *a,int idx,void *ptr);

void array_free(array *a );


array *split(char *s,char *pattern);
array *splitc(char *s,char c);

#endif
