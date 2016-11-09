---
layout: post
title:  "Java集合框架源码解析（四） - HashMap(jdk 1.8)"
date:   2016-11-07 22:13:00 +0800
---

HashMap是Java程序员使用频率最高的用于映射(键值对)处理的数据类型。和HashTable一样，HashMap也实现了Map接口，这意味着两个类的接口、用法是几乎一样的。以至于一些面试题很喜欢提问HashMap和HashTable的区别。对于这类问题，与其死记硬背一些答案，不如深入到两者的实现层面里，看看两者在设计上有何区别。

上一篇文章分析了HashTable的源码，介绍了散列表这个抽象数据结构的原理和工作方法。在详细深入探讨HashMap的结构实现和功能原理前，先说说两个类之间的相同点：

- 都是用table数组作为存储键值对的底层数据结构。
- 都用拉链法处理哈希冲突。（1. 关于哈希冲突，上一篇文章已有详细描述）（2. jdk 1.8中的HashMap的手法更复杂，下详）
- 其他的哈希表特性，初始容量（initial capacity）和装载因子（load factor），在HashMap中同样适用。

JDK1.8对HashMap底层的实现进行了优化，也就是HashMap和HashTable实现上最大的不同：

- 例如引入红黑树的数据结构，在冲突严重时依然确保性能。
- 扩容的优化。

在分析HashMap源码时，我会把重点放在这些JDK1.8新增的特性和优化上，分为几部分：

1. 内部实现，几个关键的内部数据结构（主要是红黑树）
2. 扩容机制
3. 常用操作：put和get方法的设计
4. 处理hash冲突

下面，逐点展开说说。

### 内部数据结构

看看里面的实例变量：

~~~ java
public class HashMap<K,V> extends AbstractMap<K,V>
    implements Map<K,V>, Cloneable, Serializable {

  transient Node<K,V>[] table;

  transient Set<Map.Entry<K,V>> entrySet;

  transient int size;

  int threshold;

  final float loadFactor;

}
~~~

HashMap包括几个重要的成员变量：table, size, threshold, loadFactor，这个HashTable几乎是一样的：
- table是一个Node[]数组类型，存放每一对key-value的数组。
- size是HashMap的大小，它是HashMap保存的键值对的数量。
- threshold是Hashtable的阈值，用于判断是否需要调整Hashtable的容量。threshold的值="容量*加载因子"。
- loadFactor就是加载因子。

其中最大的不同是Node类型的实现，有两种：

一个是单向链表的Node：

~~~ java
static class Node<K,V> implements Map.Entry<K,V> {
   final int hash;
   final K key;
   V value;
   Node<K,V> next;
}
~~~

另一个是JDK1.8中新引入的红黑树的Node实现：

~~~ java
static final class TreeNode<K,V> extends LinkedHashMap.Entry<K,V> {
   TreeNode<K,V> parent;  // red-black tree links
   TreeNode<K,V> left;
   TreeNode<K,V> right;
   TreeNode<K,V> prev;    // needed to unlink next upon deletion
   boolean red;
}
~~~

这里`TreeNode`继承自`LinkedHashMap.Entry`，而`LinkedHashMap.Entry`继承自`Node`，所谓Node依然可以放在table数组中。

说完这三个关键的数据结构（table数组，单向链表，红黑树），你可能已经想到HashMap的数据结构实现了。可以简单地阐述为三个层次：

1. table数组是存储核心，普通情况下，每个K-V对都通过hash方法计算下标，存在数组中的一个格子里。
2. 当发生hash冲突，也就是两个K-V对通过hash方法计算出相同的下标，此时两个K-V对组成一个链表，头节点放在数组中，后继结点仍然可通过next指针访问。
3. 当第二中情况出现过多，也就是冲突严重时，链表长度过长（默认超过8），这时链表转换为红黑树，这样大大提高了查找的效率。

可见，1，2点都是HashTable的做法，第三点是HashMap引入的优化。利用红黑树快速增删改查的特点提高HashMap的性能，其中会用到红黑树的插入、删除、查找等算法。本文不再对红黑树展开讨论，想了解更多红黑树数据结构的工作原理可以参考http://blog.csdn.net/v_july_v/article/details/6105630。

### put方法的实现

put方法的内部实现是putVal方法：

~~~ java
final V putVal(int hash, K key, V value, boolean onlyIfAbsent,
               boolean evict) {
    Node<K,V>[] tab; Node<K,V> p; int n, i;
    // 如果table为空，创建table
    if ((tab = table) == null || (n = tab.length) == 0)
        n = (tab = resize()).length;
    // 计算index，如果还没有插入，直接插入。
    if ((p = tab[i = (n - 1) & hash]) == null)
        tab[i] = newNode(hash, key, value, null);
    // 处理哈希冲突
    else {
        Node<K,V> e; K k;
        // key存在，说明是更新，直接覆盖value
        if (p.hash == hash &&
            ((k = p.key) == key || (key != null && key.equals(k))))
            e = p;
        // 说明该链是红黑树，插入新的TreeNode节点。
        else if (p instanceof TreeNode)
            e = ((TreeNode<K,V>)p).putTreeVal(this, tab, hash, key, value);
        else {
            // 该链是链表，插入链表结点。
            for (int binCount = 0; ; ++binCount) {
                if ((e = p.next) == null) {
                    p.next = newNode(hash, key, value, null);
                    // binCount为统计链表里节点数，当链表长度大于8时，转换为红黑树并处理
                    if (binCount >= TREEIFY_THRESHOLD - 1) // -1 for 1st
                        treeifyBin(tab, hash);
                    break;
                }
                if (e.hash == hash &&
                    ((k = e.key) == key || (key != null && key.equals(k))))
                    break;
                p = e;
            }
        }
        if (e != null) { // existing mapping for key
            V oldValue = e.value;
            if (!onlyIfAbsent || oldValue == null)
                e.value = value;
            afterNodeAccess(e);
            return oldValue;
        }
    }
    ++modCount;

    // 最后，判断是否需要扩容。
    if (++size > threshold)
        resize();
    afterNodeInsertion(evict);
    return null;
}

~~~

### 参考资源

- http://tech.meituan.com/java-hashmap.html
- http://www.2cto.com/kf/201505/401433.html
- http://blog.csdn.net/v_july_v/article/details/6105630
- http://www.nurkiewicz.com/2014/04/hashmap-performance-improvements-in.html
