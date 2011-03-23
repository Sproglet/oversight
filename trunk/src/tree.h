#ifndef _OVS_TREE_H_
#define _OVS_TREE_H_

typedef struct TreeNodeStr {
    struct TreeNodeStr *parent;
    struct TreeNodeStr *left;
    void *data;
    struct TreeNodeStr *right;
} TreeNode;

typedef struct TreeStr {
    TreeNode *node;
    int count;
} Tree;

#endif
