---
layout: post
title:  "Java集合框架源码解析（三） - HashTable"
date:   2016-10-30 11:54:00 +0800
---

说完List的几个实现，下面来说说Map系列的类。

首先看看Map接口定义的方法：

![Alt](/images/hashmap(1).png)

可看出，Map定义的就是一个“key-value键值对”的字典，它的用法不必赘言。HashTable实现了Map接口，它是使用一个哈希表实现的。

首先简单的介绍哈希表这个数据结构，它的物理实现是一个数组，对于任何一对键值对，哈希表的操作方法是：

- 将键值对中的key作为hash function的输入，得到一个数字（这个数必须是稳定的，也就是相同的key，两次经过hash function的到的值必须是相等的）
- 然后将这个数取余数组哈希表中数组的长度，得出该键值对合适的位置。

![Alt](/images/hashtable(3).jpg)

在使用上，HashTable有几个要点：

1. 它是线程安全的。
2. 影响HashTable性能的两个因素：初始容量（initial capacity）和装载因子（load factor）。（下文详）
3. 任何对象都可以作为HashTable的Key，只要这个对象实现了hashCode和equals方法。如果一个自定义类要作为HashTable的Key，最好小心的重写这两个方法。

对于哈希表的实现代码，我认为重点有这几个：

- 内部数据结构的实现
- hash值的计算
- Hash Collision的处理策略
- rehash的策略

下面，我们深入到实现代码，看看HashTable类的设计与实现。

#### 内部数据结构

看看里面的实例变量：

~~~ java
public class Hashtable<K,V>
    extends Dictionary<K,V>
    implements Map<K,V>, Cloneable, java.io.Serializable {

    /**
     * The hash table data.
     */
    private transient Entry<?,?>[] table;

    /**
     * The total number of entries in the hash table.
     */
    private transient int count;

    /**
     * The table is rehashed when its size exceeds this threshold.  (The
     * value of this field is (int)(capacity * loadFactor).)
     *
     * @serial
     */
    private int threshold;

    /**
     * The load factor for the hashtable.
     *
     * @serial
     */
    private float loadFactor;

}
~~~

HashTable包括几个重要的成员变量：table, count, threshold, loadFactor, modCount。

- table是一个Entry[]数组类型，存放每一对key-value的数组。
- count是Hashtable的大小，它是Hashtable保存的键值对的数量。
- threshold是Hashtable的阈值，用于判断是否需要调整Hashtable的容量。threshold的值="容量*加载因子"。
- loadFactor就是加载因子。

table数组的每一个元素都是一个Entry，Entry是一个内部类：

~~~ java
private static class Entry<K,V> implements Map.Entry<K,V> {
    final int hash;
    final K key;
    V value;
    Entry<K,V> next;
}
~~~

Entry实际上就是一个单向链表，它维护一个next指针。

#### 处理Hash冲突的策略

看到Entry的next指针，你应该已经想到了，没错，HashTable内部用“拉链法”处理冲突。先花一分钟，用一个图直观的讲解下拉链法的原理：

hashTable使用数组作为存储键值对的数据结构。那么每一对K-V值应该都有一个唯一、不变的在数组中的index，而且这个index应该是和KEY对应的。这样理想状态下的get方法的伪代码是：

~~~ java
public V get(Object k) {
    return table[k.hashCode() % table.length].value;
}
~~~

这个hashCode方法是客户负责实现的，它应该尽量随机。但是始终会出现一个问题：两个不同的key的hashCode不一致，但取余`table.length`后，对应数组的index一致，这就是hash冲突。

拉链法解决冲突的方法是：

![Alt](/images/hashtable(4).gif)

这两个冲突的KEY用链表相连，链表头放在table数组中。查找时，找到index之后，还要比较key是否相等，如果不相等，会沿着next指针向下查找：

~~~ java
public synchronized V get(Object key) {
    Entry<?,?> tab[] = table;
    int hash = key.hashCode();
    int index = (hash & 0x7FFFFFFF) % tab.length;
    for (Entry<?,?> e = tab[index] ; e != null ; e = e.next) {
        if ((e.hash == hash) && e.key.equals(key)) {
            return (V)e.value;
        }
    }
    return null;
}
~~~

具体看一看HashTable相关代码，首先是`put`方法：

~~~ java
public synchronized V put(K key, V value) {
    // Make sure the value is not null
    if (value == null) {
        throw new NullPointerException();
    }

    // Makes sure the key is not already in the hashtable.
    Entry<?,?> tab[] = table;
    int hash = key.hashCode();
    int index = (hash & 0x7FFFFFFF) % tab.length;
    @SuppressWarnings("unchecked")
    Entry<K,V> entry = (Entry<K,V>)tab[index];
    for(; entry != null ; entry = entry.next) {
        if ((entry.hash == hash) && entry.key.equals(key)) {
            V old = entry.value;
            entry.value = value;
            return old;
        }
    }

    addEntry(hash, key, value, index);
    return null;
}

private void addEntry(int hash, K key, V value, int index) {
    modCount++;

    Entry<?,?> tab[] = table;
    if (count >= threshold) {
        // Rehash the table if the threshold is exceeded
        rehash();

        tab = table;
        hash = key.hashCode();
        index = (hash & 0x7FFFFFFF) % tab.length;
    }

    // Creates the new entry.
    @SuppressWarnings("unchecked")
    Entry<K,V> e = (Entry<K,V>) tab[index];
    tab[index] = new Entry<>(hash, key, value, e);
    count++;
}

~~~

讲解一下（rehash的代码下详）：

1. 根据hashcode找到在table数组的位置。若找到Key相等的entry，说明这次put操作是更新。
2. 如果找不到Key对应的entry，说明是插入新的K-V对，这时创建新entry，插入到链表头，并维护后继指针。

`remove`方法可以看到相似的操作：

~~~ java
public synchronized V remove(Object key) {
    Entry<?,?> tab[] = table;
    int hash = key.hashCode();
    int index = (hash & 0x7FFFFFFF) % tab.length;
    @SuppressWarnings("unchecked")
    Entry<K,V> e = (Entry<K,V>)tab[index];
    for(Entry<K,V> prev = null ; e != null ; prev = e, e = e.next) {
        if ((e.hash == hash) && e.key.equals(key)) {
            modCount++;
            if (prev != null) {
                prev.next = e.next;
            } else {
                tab[index] = e.next;
            }
            count--;
            V oldValue = e.value;
            e.value = null;
            return oldValue;
        }
    }
    return null;
}
~~~

remove方法同样是根据key的hashCode方法，找到在table的index，利用Entry的next指针找到目标entry，将其删除。最后维护前后entry的指针。

#### rehash

为什么要rehash？如果知道哈希表实现原理，相信大家都可以回答：

举个栗子：有一个hashTable，它的table数组长度为5（5个格子）。当存放5个键值对的时候，平均每个格子都有一个entry。这很好。

但如果要存放的键值对增加到500个，那会出现什么情况？格子还是5个，但平均每个格子存放了100个entry，这些entry以链表的形式相连，想想看此时整个hashtable的形态，竟变成了5个链表！查找删除都成了O(n)操作。

为了解决这个问题，一个策略就是讲table数组扩容：将table数组的容量增加，然后将旧的entry重新（平均）分布到新table数组里，这就是rehash。

看看hashTable中rehash方法的实现：

~~~ java
protected void rehash() {
    int oldCapacity = table.length;
    Entry<?,?>[] oldMap = table;

    // overflow-conscious code
    int newCapacity = (oldCapacity << 1) + 1;
    if (newCapacity - MAX_ARRAY_SIZE > 0) {
        if (oldCapacity == MAX_ARRAY_SIZE)
            // Keep running with MAX_ARRAY_SIZE buckets
            return;
        newCapacity = MAX_ARRAY_SIZE;
    }
    Entry<?,?>[] newMap = new Entry<?,?>[newCapacity];

    modCount++;
    threshold = (int)Math.min(newCapacity * loadFactor, MAX_ARRAY_SIZE + 1);
    table = newMap;

    for (int i = oldCapacity ; i-- > 0 ;) {
        for (Entry<K,V> old = (Entry<K,V>)oldMap[i] ; old != null ; ) {
            Entry<K,V> e = old;
            old = old.next;

            int index = (e.hash & 0x7FFFFFFF) % newCapacity;
            e.next = (Entry<K,V>)newMap[index];
            newMap[index] = e;
        }
    }
}
~~~

首先，rehash方法是protected的，说明客户不能手动rehash一个HashTable。

在jdk的hashTable实现中，rehash方法会把table扩容一倍。然后根据`loadFactor`计算新的`threshold`。然后遍历旧table，将所有entry迁移，是个O(table.length)的操作。
