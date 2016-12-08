---
layout: post
title:  "从JMM层面说说Java并发（二） - ConcurrentHashmap（JDK1.6）"
date:   2016-12-08 18:26:00 +0800
---

ConcurrentHashMap是JDK提供的一个线程安全的Map实现。在JDK1.6中，它使用锁分离和Segment的方法实现更小粒度的锁。而在JDK1.8版本中，ConcurrentHashMap基本放弃了这一做法，而是使用CAS算法实现。本文分析的是JDK1.6版本中的实现。

### HashTable的问题

除ConcurrentHashMap之外，HashTable也是一个线程安全的Map实现。但是在多线程环境，不会使用HashTable，原因是：它的性能太低下。HashTable容器使用synchronized来保证线程安全，也就是一个HashTable对象是共享一个锁的：如线程1使用put进行添加元素，线程2不但不能使用put方法添加元素，并且也不能使用get方法来获取元素，所以竞争越激烈效率越低。

### 锁分段技术

HashTable容器在竞争激烈的并发环境下表现出效率低下的原因，是因为所有访问HashTable的线程都必须竞争同一把锁。所以，一个优化思路是：**调整内部数据结构，从而允许容器里有多个锁**，每一把锁用于锁容器其中一部分数据，那么当多线程访问容器里不同数据段的数据时，线程间就不会存在锁竞争，从而可以有效的提高并发访问效率。这就是ConcurrentHashmap使用的锁分段技术。

### 数据结构的调整

先复习一下HashTable的数据结构，是一个典型的哈希表实现：

- 使用数组存储Entry
- 使用拉链法解决哈希冲突

一个HashMap的数据结构看起来类似下图：

![Alt](/images/hashtable(4).gif)

也是因为这样的数据结构，HashTable只能有一个锁。

ConcurrentHashmap使用一个种粒度更细的加锁机制来实现高性能，看看ConcurrentHashmap的解决方法：



### 参考

- http://ifeve.com/java-concurrent-hashmap-2/
- http://ifeve.com/concurrenthashmap/
