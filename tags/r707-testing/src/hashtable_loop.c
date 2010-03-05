/* Copyright (C) 2002, 2004 Christopher Clark  <firstname.lastname@cl.cam.ac.uk> */

/* Andy Lord Andy AT lordy dot org dot uk
 * This is based on the hashtable_itr.c but I wanted something to reduce 
 * amount of code required to use in basic loops.
 * 
 * --------------------------------------------
 * hashtable_iterator
 * --------------------------------------------
 *
 *
 * if (hashtable_count(h) {
 *    struct hashtable_itr *itr = hashtable_iterator(h);
 *    do {
 *        k = hashtable_iterator_key(itr);
 *        v = hashtable_iterator_value(itr);
 *        ..
 *        ..
 *    } while (hashtable_iterator_advance(itr);
 *    FREE(itr);
 * } 
 * 
 * --------------------------------------------
 * hashtable_loop_init/more
 * --------------------------------------------
 *
 * struct hashtable_itr2=hashtable_loop_init(h);
 * while (hashtable_loop_more(itr,&k,&v)) {
 *
 * }
 * #iterator is auto freed at the end.
 *
 * 
 * --------------------------------------------
 * The .index member is initialised slightly differently,  (to indicate
 * no member has been selected yet - but after the first call it should 
 * be set as normal)
 *
 * Andy Lord Andy AT lordy dot org dot uk
 */

#include "hashtable.h"
#include "hashtable_private.h"
#include "hashtable_loop.h"
#include <stdlib.h> /* defines NULL */
#include <assert.h>
#include "util.h" //for MALLOC

/*****************************************************************************/

struct hashtable_itr * hashtable_loop_init(struct hashtable *h) {

    struct hashtable_itr *itr =  MALLOC(sizeof(struct hashtable_itr));

    if (itr) {

        itr->h = h;
        itr->e = NULL;
        itr->parent = NULL;
        itr->index = -1;
    }

    return itr;
}

/*****************************************************************************/
/*  - advance the iterator to the next element
 *           returns zero and frees iterator if advanced to end of table */

int hashtable_loop_more(struct hashtable_itr *itr,void *k,void *v) {

    unsigned int i,tablelength;
    struct entry **table;
    struct entry *next;


    if (NULL == itr->e) {
       /* first time */
        if ( -1 != itr->index ) {
            assert("hashtable_itr not initialised  with hashtable_loop_init" == NULL);
            /* We should never get here. It means itr->e is null after initialisation */
            return 0;
        }

        itr->index = 0;
        /* Fall through to look for first non-null table entry */

    } else {
            /* subsequent times */

        next = itr->e->next;
        if (next) {

            /* Get the next entry in this linked list */
            itr->parent = itr->e;
            itr->e = next;

        } else {
            /* List exhausted - move on to the next linked list */

            itr->parent = NULL;
            itr->e = NULL; 
            ++(itr->index);
        }
    }

    if ( itr->h->entrycount > 0 && itr->e == NULL ) {
        /* Search forward from ->index for the next populated linked list in the table */

        table = itr->h->table;
        tablelength = itr->h->tablelength;

        for( i = itr->index ; i < tablelength ; i++ ) {

            if (table[i]) {

                itr->index = i;
                itr->e = table[i];
                break;

            }
        }

    }

    if (itr->e) {

        if (k) { *((void **)k) = itr->e->k; }
        if (v) { *((void **)v) = itr->e->v; }
        return -1;

    } else {
        FREE(itr);
        return 0;
    }
}

/*
 * Copyright (c) 2002, 2004, Christopher Clark
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
