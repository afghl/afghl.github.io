---
layout: post
title:  "数据结构和算法笔记（C语言）"
date:   2016-03-19 20:11:00 +0800
---

近来学习数据结构和算法，还有一点C语言。做点笔记，持续更新。

### 二叉树

#### 存储结构

一般都会用链表实现一棵二叉树结构。

~~~ coffee
typedef struct TreeNode {
    ElementType element;
    struct TreeNode * left;
    struct TreeNode * right;
}TreeNode;
typedef TreeNode *TreePtr;
~~~

#### 遍历

前序遍历

~~~ C
void preOrderTraversal(TreePtr tree) {
    if(tree) {
        printf("%c ", tree->element);
        preOrderTraversal(tree->left);
        preOrderTraversal(tree->right);
    }
}
~~~

中序遍历

~~~ C
void inOrderTraversal(TreePtr tree) {
    if(tree) {
        inOrderTraversal(tree->left);
        printf("%c ", tree->element);
        inOrderTraversal(tree->right);
    }
}
~~~

后序遍历

~~~ C
void postOrderTraversal(TreePtr tree) {
    if(tree) {
        postOrderTraversal(tree->left);
        postOrderTraversal(tree->right);
        printf("%c ", tree->element);
    }
}
~~~

#### 树的同构判断

同构的定义：给定两棵树T1和T2。如果T1可以通过若干次左右孩子互换就变成T2，则我们称两棵树是“同构”的。算法：

~~~ C
int isomorphic(TreePtr tree1, TreePtr tree2) {
    if(tree1 == NULL && tree2 == NULL) return TRUE;
    if((tree1 == NULL && tree2 != NULL) || (tree1 != NULL && tree2 == NULL)) return FALSE;

    if(tree1->element != tree2->element) return FALSE;
    if(tree1->left != NULL && tree2->left != NULL && tree1->left->element == tree2->left->element)
        return isomorphic(tree1->right, tree2->right) && isomorphic(tree1->left, tree2->left);
    else
        return isomorphic(tree1->right, tree2->left) && isomorphic(tree1->left, tree2->right);
}
~~~

未完待续。 ：）
