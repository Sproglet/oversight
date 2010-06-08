#include <stdlib.h>
#include <string.h>
#include "list.h"
#include "util.h"

List *list_new()
{
    List *l = MALLOC(sizeof(List));
    memset(l,0,sizeof(List));
    return l;
}

ListNode *list_node_new(void *d)
{
    ListNode *n = MALLOC(sizeof(ListNode));
    memset(n,0,sizeof(ListNode));
    n->data = d;
    return n;
}

void *list_append(List *l,void *d)
{
    ListNode *n = list_node_new(d);
    if (l->length == 0) {
        l->head=n;
        l->tail=n;
    } else {
        l->tail->next = n;
        n->prev = l->tail;
        l->tail = n;
    }
    return d;
}

void *list_insert(List *l,void *d)
{
    ListNode *n = list_node_new(d);
    if (l->length == 0) {
        l->head=n;
        l->tail=n;
    } else {
        l->head->prev = n;
        n->next = l->head;
        l->head = n;
    }
    return d;
}

void list_free(List *l, void (*free_fn)(void *))
{
    if (l) {
        ListNode *n,*m;
        n = l->head;
        while(n) {
            m = n;
            n = n->next;
            if (free_fn) {
                (*free_fn)(m->data);
            }
            FREE(m);
        }
        FREE(l);
    }
}



