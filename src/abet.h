#ifndef __ABET_OVERSIGHT__
#define __ABET_OVERSIGHT__

#include "util.h"
#include "vasprintf.h"

// Functions to track usage of Alphabet (for indexes)

// If anything needs freeing then the hash free function needs to be changed.
typedef struct Abet_LetterCount_str {
    int visited;
    int count;
} AbetLetterCount;

typedef struct Abet_str {
    char *list; // List of letters in the alphabet
} Abet;

typedef struct AbetIndex_str {
    struct hashtable *index;
    Abet *abet;
} AbetIndex;

Abet *abet_create(char *list);
void abet_free(Abet *abet);

AbetIndex *abet_index_create(char *list);
void abet_index_free(AbetIndex *ai);

int abet_letter_inc(Abet *abet,char *letter);
int abet_letter_inc_or_add(AbetIndex *ai,char *letter,int add_if_missing);
void abet_index_dump(AbetIndex *ai,char *label);

int abet_strcmp(char *s1,char *s2,Abet *a);
int array_abetcmp(const void *a,const void *b);
int abet_pos(char *unterminated_char,Abet *a);
#endif
