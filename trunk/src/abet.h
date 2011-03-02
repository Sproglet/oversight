#ifndef __ABET_OVERSIGHT__
#define __ABET_OVERSIGHT__

#include "util.h"
#include "vasprintf.h"

// Functions to track usage of Alphabet (for indexes)

typedef struct Abet_Letter_str {
    char *letter;
    int count;
} Abet_Letter;

typedef struct Abet_str {
    int len;
    int orig_len;
    Abet_Letter **letters;

    // These members are just to speed up indexing - the last letter indexed is stored along with its node position
    // If this is problematic replace letter list with a binary tree
    // (could use straight array for latin A-Z but other alphabets make this awkward)
    Abet_Letter *last_letter_node;
    char *last_letter;
} Abet;

Abet *abet_create(char *list);
void abet_free(Abet *abet);
int abet_letter_inc(Abet *abet,char *letter);
int abet_letter_inc_or_add(Abet *abet,char *letter,int add_if_missing);
void abet_dump(Abet *abet);
void abet_sort(Abet *abet);

#endif
