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
    int found=0;
    int i;
    for(i=0 ; i< abet->len ; i++) {
        if (utf8cmp_char(letter,abet->letters[i]->letter) == 0) {
            found = ++(abet->letters[i]->count);
            HTML_LOG(0,"INC letter[%d]=[%s] to %d",i,letter,found);
            break;
        }
    }
    return found;
}

// Increment a letter, if it doesnt occur then either add it under '*' or append it.
// Returns number of  occurences so far
int abet_letter_inc_or_add(Abet *abet,char *letter,int add_if_missing)
{
    int ret=-1;
    Abet_Letter *letter_node;
    if ((ret = abet_letter_inc(abet,letter)) == 0) {
        if (add_if_missing) {
            letter_node = abet_addletter(abet,&letter);
            if (letter_node) {
                ret = ++(letter_node->count);
            }
        } else {
TRACE1;
            char *other_letters = "*";
            if ((ret = abet_letter_inc(abet,other_letters)) == 0) {
TRACE1;
                letter_node = abet_addletter(abet,&other_letters);
                if (letter_node) {
                    ret = ++(letter_node->count);
                }
            }
        }
    }
    return ret;
}
