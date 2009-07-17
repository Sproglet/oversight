#ifndef ARRAY_H_ALORD
#define ARRAY_H_ALORD

struct array_str {
    void **array;
    int size;
    int mem_size;
};

typedef struct array_str array;

void array_print(char *label,array *a);
array *array_new();
void array_add(array *a,void *ptr);
void array_set(array *a,int idx,void *ptr);

void array_FREE(array **a_ptr, void(*fr)(void *) , int free_by_address );
void array_free(array *a, void(*fr)(void *) , int free_by_address );


array *split(char *s,char *pattern);
array *splitc(char *s,char c);

#endif
