#include "util.h"
#include "gaya_cgi.h"
#include "utf8.h"
#include "tree.h"

Tree *tree_new()
{
    Tree *new = CALLOC(1,sizeof(Tree));
    return new;
}

TreeNode *treenode_new()
{
    TreeNode *new = CALLOC(1,sizeof(TreeNode));
    return new;
}


TreeNode *treenode_find(
        Tree *tree,            // The tree
        void *value,               // The value
        int (*cmp)(void *,void *), // Comparison function
        int insert                 // true if new node is to be inserted.
)
{
    TreeNode *result = NULL;
    if (tree) {
        TreeNode *n = tree->node;
        if(n) {
            TreeNode **n2 = NULL;
            while (n) {
                int c = cmp(value,n->data);
                if (c < 0 ) {
                    n2 = &(n->left);
                } else if (c > 0 ) {
                    n2 = &(n->right);
                } else {
                    // Found it
                    result = n;
                    break;
                }
                if (*n2 == NULL) {
                    // Leaf node
                    if (insert) {
                        result = treenode_new(value);
                        *n2 = result;
                        result->parent = n;
                    }
                    break;
                }
                n = *n2;
            }
        } else if (insert) {
            result = treenode_new(value);
            tree->node = result;
        }
    }
    return result;
}

TreeNode *tree_find(
        Tree *tree,
        void *value,
        int (*cmp)(void *,void *)
)
{
    TreeNode *result = NULL;
    if (tree) {
        result = treenode_find(tree,value,cmp,0);
    }
    return result;
}

TreeNode *tree_find_or_insert(Tree *tree,void *value,int (*cmp)(void *,void *)) {
    return treenode_find(tree,value,cmp,1);
}
