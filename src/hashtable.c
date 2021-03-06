/* Copyright (C) 2004 Christopher Clark <firstname.lastname@cl.cam.ac.uk> */
// $Id:$

#include "hashtable.h"
#include "hashtable_private.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "util.h" //for MALLOC
#include "gaya_cgi.h" //for HTML_LOG

/*
Credit for primes table: Aaron Krowne
 http://br.endernet.org/~akrowne/
 http://planetmath.org/encyclopedia/GoodHashTablePrimes.html
*/
static const unsigned int primes[] = {
17, 53, 97, 193, 389,
769, 1543, 3079, 6151,
12289, 24593, 49157, 98317,
196613, 393241, 786433, 1572869,
3145739, 6291469, 12582917, 25165843,
50331653, 100663319, 201326611, 402653189,
805306457, 1610612741
};
const unsigned int prime_table_length = sizeof(primes)/sizeof(primes[0]);
//const float max_load_factor = 0.65;
const float max_load_factor = 0.8;

/*****************************************************************************/
struct hashtable *
create_hashtable(char *name,
        unsigned int minsize,
                 unsigned int (*hashf) (void*),
                 int (*eqf) (void*,void*))
{
    struct hashtable *h;
    unsigned int pindex, size = primes[0];
    /* Check requested hashtable isn't too large */
    if (minsize > (1u << 30)) return NULL;
    /* Enforce size as prime */
    for (pindex=0; pindex < prime_table_length; pindex++) {
        if (primes[pindex] > minsize) {
            size = primes[pindex];
            break;
        }
    }
    h = (struct hashtable *)MALLOC(sizeof(struct hashtable));
    if (!h) return NULL; /*oom*/

    h->table = (struct entry **)CALLOC(size,sizeof(struct entry*));
    if (!h->table) {
        FREE(h);
        return NULL;
    } /*oom*/

    h->tablelength  = size;
    h->primeindex   = pindex;
    h->entrycount   = 0;
    h->hashfn       = hashf;
    h->eqfn         = eqf;
    h->loadlimit    = (unsigned int) ceil(size * max_load_factor);
    h->searches     = 0;
    h->misses       = 0;
    h->name         = STRDUP(name);
    return h;
}

/*****************************************************************************/
// ALL #defined away this function. I spend too much time looking at hash functions
// and then see this.
//  see hashtable_private.h for macro replacement
//
#if 0
unsigned int
hash(struct hashtable *h, void *k)
{
    /* Aim to protect against poor hash functions by adding logic here
     * - logic taken from java 1.4 hashtable source */
    unsigned int i = h->hashfn(k);
    i += ~(i << 9);
    i ^=  ((i >> 14) | (i << 18)); /* >>> */
    i +=  (i << 4);
    i ^=  ((i >> 10) | (i << 22)); /* >>> */
    return i;
}


#endif

/*****************************************************************************/
static int
hashtable_expand(struct hashtable *h)
{
    /* Double the size of the table to accomodate more entries */
    struct entry **newtable;
    struct entry *e;
    struct entry **pE;
    unsigned int newsize, i, index;
    /* Check we're not hitting max capacity */
    if (h->primeindex == (prime_table_length - 1)) return 0;
    newsize = primes[++(h->primeindex)];

    newtable = (struct entry **)CALLOC(newsize,sizeof(struct entry*));
    if (newtable)
    {
        /* This algorithm is not 'stable'. ie. it reverses the list
         * when it transfers entries between the tables */
        for (i = 0; i < h->tablelength; i++) {
            while (NULL != (e = h->table[i])) {
                h->table[i] = e->next;
                index = indexFor(newsize,e->h);
                e->next = newtable[index];
                newtable[index] = e;
            }
        }
        FREE(h->table);
        h->table = newtable;
    }
    /* Plan B: realloc instead */
    else 
    {
        newtable = (struct entry **)
                   realloc(h->table, newsize * sizeof(struct entry *));
        if (!newtable) { (h->primeindex)--; return 0; }
        h->table = newtable;
        memset(newtable[h->tablelength], 0, newsize - h->tablelength);
        for (i = 0; i < h->tablelength; i++) {
            for (pE = &(newtable[i]), e = *pE; e != NULL; e = *pE) {
                index = indexFor(newsize,e->h);
                if (index == i)
                {
                    pE = &(e->next);
                }
                else
                {
                    *pE = e->next;
                    e->next = newtable[index];
                    newtable[index] = e;
                }
            }
        }
    }
    h->tablelength = newsize;
    h->loadlimit   = (unsigned int) ceil(newsize * max_load_factor);
    return -1;
}

/*****************************************************************************/
unsigned int
hashtable_count(struct hashtable *h)
{
    return h->entrycount;
}

/*****************************************************************************/
int hashtable_insert(struct hashtable *h, void *k, void *v) {
    /* This method allows duplicate keys - but they shouldn't be used */
    unsigned int index;
    struct entry *e;
    if (++(h->entrycount) > h->loadlimit)
    {
        /* Ignore the return value. If expand fails, we should
         * still try cramming just this value into the existing table
         * -- we may not have memory for a larger table, but one more
         * element may be ok. Next time we insert, we'll try expanding again.*/
        hashtable_expand(h);
    }
    e = (struct entry *)MALLOC(sizeof(struct entry));
    if (!e) {
        --(h->entrycount);
        return 0;
    } /*oom*/

    e->h = hash(h,k);
    index = indexFor(h->tablelength,e->h);
    e->k = k;
    e->v = v;
    e->next = h->table[index];
    h->table[index] = e;
    return -1;
}

/*****************************************************************************/
void * /* returns value associated with key */
hashtable_search(struct hashtable *h, void *k)
{
    struct entry *e;
    unsigned int hashvalue, index;

    if (h->entrycount) {
        hashvalue = hash(h,k);
        index = indexFor(h->tablelength,hashvalue);
        e = h->table[index];
        h->searches++;
        while (e)
        {
            /* Check hash value to short circuit heavier comparison */
            if ((hashvalue == e->h) && (h->eqfn(k, e->k))) return e->v;
            e = e->next;
            h->misses++;
        }
    }
    return NULL;
}

/*****************************************************************************/
void * /* returns value associated with key */
hashtable_remove(struct hashtable *h, void *k,int free_key)
{
    /* TODO: consider compacting the table when the load factor drops enough,
     *       or provide a 'compact' method. */

    struct entry *e;
    struct entry **pE;
    void *v;
    unsigned int hashvalue, index;

    if (h->entrycount) {
        hashvalue = hash(h,k);
        index = indexFor(h->tablelength,hashvalue);
        pE = &(h->table[index]);
        e = *pE;
        while (e)
        {
            /* Check hash value to short circuit heavier comparison */
            if ((hashvalue == e->h) && (h->eqfn(k, e->k)))
            {
                *pE = e->next;
                h->entrycount--;
                v = e->v;
                if (free_key) freekey(e->k);
                FREE(e);
                return v;
            }
            pE = &(e->next);
            e = e->next;
        }
    }
    return NULL;
}

/*****************************************************************************/
/* destroy */
void
hashtable_destroy(struct hashtable *h, int free_keys , void (*free_fn)(void *))
{
    if (h) {
        unsigned int i;
        struct entry *e, *f;
        struct entry **table = h->table;

        // stats
        int used=0;
        int hit2=0;
        int hmax=0;


        for (i = 0; i < h->tablelength; i++)
        {
            e = table[i];
            if (e) used++;

            int hthis=0;
            while (e) {

                f = e;

                hthis++;

                e = e->next;
                if (free_keys && f->k) freekey(f->k);
                if (free_fn && f->v) free_fn(f->v);
                FREE(f);
            }
            hit2 += hthis;
            if (hthis > hmax) hmax = hthis;
        }
        HTML_LOG(1,"hashtable[%s]: size=%u,used =%d, max=%d searches=%d misses=%d",
            h->name,
            h->tablelength,used,hmax,
            h->searches,h->misses);

        FREE(h->table);
        FREE(h->name);
        FREE(h);
    }
}

/*
 * Copyright (c) 2002, Christopher Clark
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 
 * * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 * 
 * * Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 * 
 * * Neither the name of the original author; nor the names of any contributors
 * may be used to endorse or promote products derived from this software
 * without specific prior written permission.
 * 
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER
 * OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
// vi:sw=4:et:ts=4
