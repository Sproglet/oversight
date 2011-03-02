#include "abet.h"
#include "oversight.h"
#include "util.h"
#include "gaya_cgi.h"
#include "utf8.h"

// Functions to track usage of Alphabet (for indexes)

Abet_Letter *abet_letter_create(
        char *bytes,
        int byte_len
        )
{
    Abet_Letter *letter = calloc(1,sizeof(Abet_Letter *));
    letter->letter = COPY_STRING(byte_len,bytes);
    letter->count = 0;
    HTML_LOG(0,"Created letter [%s]",letter->letter);
    return letter;
}

void abet_letter_free(Abet_Letter *letter)
{
    if (letter) {
        FREE(letter->letter);
        FREE(letter);
    }
}

/*
 * Add a letter to the alphabet
 */
Abet_Letter *abet_addletter(
        Abet *abet,        
        char **letter_ptr // address of ptr to letter - will be advanced to next letter
        )
{
   unsigned char *p,*endp;
   p = endp = (unsigned char *) (*letter_ptr);
   Abet_Letter *letter;

   if (IS_UTF8START(*endp)) {
       endp++;
       while(IS_UTF8CONT(*endp)) {
           endp++;
       }
   } else {
       endp++;
   }

   abet->len++;
   letter = abet_letter_create((char *)p,endp-p);
   abet->letters = realloc(abet->letters,abet->len * sizeof(Abet_Letter *));

   abet->letters[abet->len-1] = letter;


   // Advance to next letter
   *letter_ptr = (char *)endp;

   // Return pointer to letter
   return letter;

}

Abet *abet_create(char *list) 
{

   Abet *abet = (Abet *)calloc(1,sizeof(Abet));
   char *p=list;
   if (p) {
       while(*p) {

           abet_addletter(abet,&p);

       }
       abet->orig_len = abet->len;
   }
   return abet;
}

void abet_free(Abet *abet)
{
    if (abet) {
        int i;
        for (i = 0 ; i < abet->len ; i++ ) {
            abet_letter_free(abet->letters[i]);
        }
        FREE(abet->letters);
        FREE(abet);
    }
}

// Increment the occurence of a letter within an alphabet
// The letter string may not be null terminated so dont use strcmp
int abet_letter_inc(Abet *abet,char *letter)
{
    static int hit=0;
    static int miss=0;

    int ret = 0;
    Abet_Letter *letter_node = NULL;
    // quick hack to speed things up - look at last letter incremented - replace with tree structure if more speed needed.
    if (abet->last_letter && utf8cmp_char(abet->last_letter,letter) == 0) {
        letter_node = abet->last_letter_node;
        hit++;
    } else {

        int i;
        for(i=0 ; i< abet->len ; i++) {
            if (utf8cmp_char(letter,abet->letters[i]->letter) == 0) {
                letter_node = abet->letters[i];
                break;
            }
        }
        miss++;
    }
    if (letter_node) {
        ret = ++(letter_node->count);
        //HTML_LOG(0,"INC letter[%s] to %d (%d/%d)",letter,ret,hit,miss);
        abet->last_letter_node = letter_node;
        abet->last_letter = letter;
    }
    return ret;
}

// Increment a letter, if it doesnt occur then either add it under '*' or append it.
// Returns number of  occurences so far
int abet_letter_inc_or_add(Abet *abet,char *letter,int add_if_missing)
{
    int ret=-1;
    Abet_Letter *letter_node = NULL;

    if (abet && letter) {

        // do a full search for the letter.

        if ((ret = abet_letter_inc(abet,letter)) == 0) {
            if (add_if_missing) {
                letter_node = abet_addletter(abet,&letter);
            } else {
                char *other_letters = "*";
                if ((ret = abet_letter_inc(abet,other_letters)) == 0) {
                    letter_node = abet_addletter(abet,&other_letters);
                }
            }
        }
        if (letter_node) {
            ret = ++(letter_node->count);
            abet->last_letter_node = letter_node;
            abet->last_letter = letter;
        }
    }
    return ret;
}

void abet_dump(Abet *abet)
{
    if (abet) {
        int i;
        for(i = 0 ; i < abet->len ; i++ ) {
            if (i == abet->orig_len ) {
                HTML_LOG(0,"abet - added letters");
            }
            HTML_LOG(0,"abet [%s]=%d",abet->letters[i]->letter,abet->letters[i]->count);
        }
    }
}

/*
 * Sort all letters that were added after the initial list of letters.
 * eg if abet is UK English then it is already expected that the first 26 characters are in order,
 * but if some unicode characters are added afterwards then these will be added using simple ordering based on the byte values.
 * For most alphabets this will be OK with one or two characters out of place, but as this is not the users main locale
 * we can allow this for now.
 */
static int letter_cmp(const void *letter1,const void *letter2)
{
    Abet_Letter *l1 = *(Abet_Letter **)letter1;
    Abet_Letter *l2 = *(Abet_Letter **)letter2;
    return strcmp(l1->letter,l2->letter);
}
void abet_sort(Abet *abet) 
{
    if (abet) {
        Abet_Letter **added;
        int len;

        added = abet->letters + abet->orig_len;
        len = abet->len - abet->orig_len;
        if (len) {
            qsort(added,sizeof(Abet_Letter *),len,letter_cmp);
        }
    }
}
