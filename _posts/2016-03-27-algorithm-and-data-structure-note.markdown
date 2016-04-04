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

### AVL

平衡二叉树，通过每次插入新结点时旋转结点调节左右树高度差，以获得更高的查找效率。

主要算法在于：

   1. 旋转不平衡节点：下以左旋为例。
   
   ~~~ C
    void leftBalance (TreePtr *tree) {
      TreePtr subRightChild;
      TreePtr leftChild = (*tree)->left;
      // 看看左子树是否需要调整
      switch (leftChild->bf) {
        case 1: // 不平衡结点位于tree的左结点的左结点。
          (*tree)->bf = leftChild->bf = 0;
          rightRotate(tree);
          break;
        case -1: // 不平衡结点位于tree的左结点的右结点。
          subRightChild = (*tree)->left->right;
          // 调整三个结点的bf
          if(subRightChild->bf == 1) {
            (*tree)->bf = 1;
            leftChild->bf = 0;
          } else if(subRightChild->bf == 0) {
            (*tree)->bf = leftChild->bf = 0;
          } else if(subRightChild->bf == -1) {
            (*tree)->bf = 0;
            leftChild->bf = 1;
          }
          subRightChild->bf = 0;
          leftRotate(&(*tree)->left);
          rightRotate(tree);
      }
    }
   ~~~

   2. 在旋转结点的同时，用一个位记录taller值，在递归的时候回溯此值，并以此调节平衡因子：
   
   ~~~ C
    // 返回值为是否插入了新节点。
    Status insertAVL(TreePtr *tree, ElementType element, Status *taller) { // taller的做法是多次传递同一个int变量时， 用指针。
      // 插入新节点
      if (! *tree) {
        *tree = (TreePtr)malloc(sizeof(struct TreeNode));
        (*tree)->element = element;
        (*tree)->left = (*tree)->right = NULL;
        (*tree)->bf = 0;
        *taller = TRUE;  //新加一个节点， 一定taller?
        printf("------插入了节点%d-------\n", element);
        return TRUE;
      }
      // 遍历tree
      if (element == (*tree)->element) {
        *taller = FALSE;
        return FALSE;
      }
    
      if (element < (*tree)->element) {
        // 递归插入
        if(!insertAVL(&(*tree)->left, element, taller)) return FALSE;
        // 插在了 tree的左节点上。
        // 现检查tree的bf，并根据bf调整旋转tree，改taller。
    
        if(*taller) {
          printf("\n---------taller----------\n");
          printf("节点：%d， 调整前bf：%d\n", (*tree)->element, (*tree)->bf);
          switch ((*tree)->bf) {
            // 原来是左子树较深， 插在了左， 所以要转。
            case 1:
              leftBalance(tree);
              // 转完后高度已经调整了。
              *taller = FALSE;
              break;
            // 原来平衡， 插在了左， 不用转， 但要调整自己的bf。
            case 0:
              (*tree)->bf = 1;
              *taller = TRUE;
              break;
            case -1:
              (*tree)->bf = 0;
              *taller = FALSE;
              break;
          }
          printf("节点：%d， 调整后bf：%d\n", (*tree)->element, (*tree)->bf);
        }
      } else {
          // 递归插入
          if(!insertAVL(&(*tree)->right, element, taller)) return FALSE;
          // 插在了右节点上。
          if(*taller) {
            switch ((*tree)->bf) {
              case 1:
                (*tree)->bf = 0;
                *taller = FALSE;
                break;
              case 0:
                (*tree)->bf = -1;
                *taller = TRUE;
                break;
              case -1:
                rightBalance(tree);
                *taller = FALSE;
                break;
            }
          }
        }
      return TRUE;
    }
   ~~~
   
### 最大堆

最大堆最重要的接口为`deleteMax`，需要将最大值作为树的根节点，常用数组实现，数据结构：

~~~ C
typedef struct HeapStruct {
  ElementType *elements;
  int size;
  int capacity; //最大容量
} HeapStruct;
~~~

`insert`的时候，先把element放在最后一个结点，然后向上回溯，比较大小，把element放到合适的位置，保持堆的特性：

~~~ C
void insert(MaxHeap h, ElementType element) {
  int i = h->size + 1;
  ElementType tmp;
  while(h->elements[i/2] < element && i > 1) {
    tmp = h->elements[i/2];
    h->elements[i/2] = h->elements[i];
    h->elements[i] = tmp;
    i = i / 2;
  }
  h->elements[i] = element;
  ++h->size;
}
~~~

`deleteMax`的时候，根节点必定是最大值，所以去掉根节点，然后把最后一个结点放在根节点，向下比较，换位使树保持最大堆的特性：

~~~ C
ElementType deleteMax(MaxHeap h) {
  ElementType maxElement, tmp, changeTmp;
  int index = 1, maxChildIndex;
  maxElement = h->elements[1];

  //保持堆的数组特性
  tmp = h->elements[h->size];
  h->size = h->size - 1;

  // 拿最后一个元素替补当前根节点， 然后与下面的左右儿子比较， 找到该元素合适的位置。
  while(1) {
    h->elements[index] = tmp;
    // 找到左右两儿子的较大者
    if(h->elements[index * 2] > h->elements[index * 2 + 1]) {
      maxChildIndex = index * 2;
    } else {
      maxChildIndex = index * 2 + 1;
    }

    if(maxChildIndex > h->size) break;

    if(h->elements[index] < h->elements[maxChildIndex]) {
      changeTmp = h->elements[index];
      h->elements[index] = h->elements[maxChildIndex];
      h->elements[maxChildIndex] = changeTmp;
      index = maxChildIndex;
    } else {
      break;
    }
  }
  return maxElement;
}
~~~

### Hash

散列表维护一个hashTable和一个Hash函数(key到下标的映射函数)。 研究方向主要有三：散列函数的构造， 处理散列冲突， hash因子。这里只给出最基本的示例，不做深究：

~~~ C
typedef struct HashTable {
  int *elements;
  int count;
} HashTable;
~~~

~~~ C
int hash(int key) { return key % m; }
~~~

处理冲突的方法使用线性探测法：

~~~ C
Status searchHash(HashTable *h, int key, int *p) {
  *p = hash(key);
  int i = 0;
  while( h->elements[*p] != key ) {
    i = i + 1;
    *p = hash(key + i);
    if (i == m || h->elements[*p] == NULLKEY) {
      return 0;
    }
  }
  return 1;
}

void insertHash(HashTable *h, int key) {
  int addr = hash(key);
  int i = 0;
  while (h->elements[addr] != NULLKEY || i == m) {
    i++;
    addr = hash(key + i);
  }
  h->elements[addr] = key;
}
~~~

未完待续。 ：）
