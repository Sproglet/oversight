#ifndef __OVS_LIST_H__
#define __OVS_LIST_H__


typedef struct ListNodeStruct {
    struct ListNodeStruct *prev;
    void *data;
    struct ListNodeStruct *next;
} ListNode;

typedef struct ListStruct {
    ListNode *head;
    ListNode *tail;
    int length;
} List;

List *list_new();
ListNode *list_node_new(void *d);
void *list_append(List *l,void *d);
void *list_insert(List *l,void *d);
void list_free(List *l, void (*free_fn)(void *));
#endif

