#include <assert.h>

#include "abet.h"
#include "util.h"
#include "gaya_cgi.h"
#include "utf8.h"
#include "hashtable_loop.h"

// Functions to track usage of Alphabet (for indexes)

Abet *abet_create(char *list) 
{

   Abet *abet = (Abet *)calloc(1,sizeof(Abet));
   abet->list = STRDUP(list);
   return abet;
}

void abet_free(Abet *abet)
{
    if (abet) {
        FREE(abet->list);
        FREE(abet);
    }
}

// Create an index using an alphabet.
AbetIndex *abet_index_create(char *list)
{
    Abet *abet = abet_create(list);
    
   AbetIndex *ai = NEW(AbetIndex);
   ai->abet = abet;
   ai->index = string_string_hashtable("index",40);
   return ai;
}

void abet_index_free(AbetIndex *ai)
{
    if (ai) {
        hashtable_destroy(ai->index,1,free);
        abet_free(ai->abet);
        FREE(ai);
    }
}

// Increment a letter, if it doesnt occur then either add it under '*' or append it.
// Returns number of  occurences so far
#define MAX_UTF_LEN 10
int abet_letter_inc_or_add(AbetIndex *ai,char *letter_ptr,int add_if_missing)
{
    int ret = 0;
    assert(ai);
    if (letter_ptr) {
        AbetLetterCount *val;

        char letter[MAX_UTF_LEN];

        if (utf8_initial(letter_ptr,letter) > MAX_UTF_LEN) {
            assert(0);
        }

        if ((val = hashtable_search(ai->index,letter)) == NULL) {

            val = NEW(AbetLetterCount);
            hashtable_insert(ai->index,STRDUP(letter),val);

        }
        ret = ++(val->count);
    }
    return ret;
}


void abet_index_dump(AbetIndex *ai,char *label)
{
    if (ai) {

        if (ai->index && hashtable_count(ai->index)) {

           char *k;
           AbetLetterCount *v;
           struct hashtable_itr *itr ;

           for(itr = hashtable_loop_init(ai->index); hashtable_loop_more(itr,&k,&v) ; ) {

                HTML_LOG(0,"%s : [ %s ] = [ %d %d ]",label,k,v->count,v->visited);
            }

        } else {
            HTML_LOG(0,"%s : EMPTY INDEX",label);
        }
    }
}


// find position of unterminated character in abet.
// Result = position in alpabet eg 1,2,3 etc. OR
// 1000+utf16 value.
int abet_pos(char *unterminated_char,Abet *a) 
{
    assert(a);
    char *p = unterminated_char;
    char *list = a->list;
    char *pos;
    int ret = -1;

    if(unterminated_char) {
        //HTML_LOG(0,"abet_pos[%s]in[%s]",unterminated_char,list);
        //HTML_LOG(0,"char pos[%s]",strchr(list,*unterminated_char));

        while(list) {
            char *q;
            pos = q = strchr(list,*p);

            if (pos == NULL) {
                break;
            }

            if (!IS_UTF8STARTP(p)) {
                // Simple character.
                ret = pos - list;
                break;
            }
            // Check rest of utf8 characters
            do {
                p++;
                q++;
            } while(IS_UTF8CONTP(p) && *p == *q);
            if (!IS_UTF8CONTP(p)) {
                // success input character found. Spilled into next character.
                ret = pos - list;
                break;
            }
            // Failed - still in utf8 character. Advance list and search again.
            list = q;
        }
        if (ret == -1 ) {
            return 1000+utf16(unterminated_char);
        }
    } else {
        HTML_LOG(0,"null value");
    }
    return ret;
}

/*
 * Compare two strings using Abet collating sequence.
 */
int abet_strcmp(char *s1,char *s2,Abet *a)
{
    assert(a);

    if (!s1) {
        return (s2?-1:0);
    } else if (!s2) {
        return 1;
    }

    int i,j,ret=0;
    char *p =  s1;
    char *q =  s2;
    //HTML_LOG(0,"abet_strcmp[%s][%s]",s1,s2);
    while (*p && *q ) {
        i = abet_pos(p,a);
        j = abet_pos(q,a);
        ret = i -j;
        if  (ret) break;
        if (*p) {
            p++;
            while(IS_UTF8CONTP(p)) p++;
        }
        if (*q) {
            q++;
            while(IS_UTF8CONTP(q)) q++;
        }
    }
    if (ret == 0) {
        if (*p) ret = 1;
        else if (*q) ret = -1;
    }
    return ret;
}

// passed to array_sort for locale specific sorting
int array_abetcmp(const void *a,const void *b)
{
    return abet_strcmp(*(char **)a,*(char **)b,g_abet_title->abet);
}
