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
void array_dump(int level,char *label,Array *a);
Array *array_new(void(*fr)(void *) );
void array_add(Array *a,void *ptr);
void array_set(Array *a,int idx,void *ptr);

#define ARRAY_FREE(a) do { if (a) array_free(a); } while(0)
void array_free(Array *a );


Array *split(char *s,char *pattern,int reg_opts);
Array *splitstr(char *s_in,char *sep);
int array_strcasecmp(const void *a,const void *b);
void array_sort(Array *a,int (*fn)(const void *,const void *));
char *join(Array *a,char *sep);

#endif
