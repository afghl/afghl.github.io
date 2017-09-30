---
layout: post
title:  "JVM GC 复习（二） - GC算法、回收器、GC过程"
date:   2017-09-25 12:58:00 +0800
---

第一篇说完了JVM运行时的内存分区。这一篇说说GC的一些基本知识。GC是JVM层面的垃圾回收机制，它不由程序员控制。我们可以问：GC是什么时候对什么东西做了什么事？下文会从这个思路去行文。

### GC触发的时机

GC分为minor GC和major GC。

当新生代的Eden分区满了，会触发minor GC。

但full GC的触发时机和minor GC有所不同：full GC不会也不能等到整个堆内存都被占满才执行，想想这时候，整个JVM已经OOM了。所以，full GC的触发是判断阈值的，生产环境的full GC算法通常都用CMS，CMS回收的触发时机取决于这三个参数：

- CMSInitiatingOccupancyFraction：Percentage CMS generation occupancy to start a CMS collection cycle (A negative value means that CMSTirggerRatio is used). See good explanation about that parameter here.
- CMSTriggerRatio：Percentage of MinHeapFreeRatio in CMS generation that is allocated before a CMS collection cycle commences
- MinHeapFreeRatio：Min percentage of heap free after GC to avoid expansion

`CMSInitiatingOccupancyFraction`参数设置当堆内存使用占比为多少%时，将触发CMS回收（full GC）。我们的生产环境一般设置为60，也就是说当堆内存（CMSOldGen）占比超过60%时，将触发full GC。

在`CMSInitiatingOccupancyFraction`有值（> 0）时，JVM会取`CMSInitiatingOccupancyFraction`的值。当该值 < 0时，JVM会根据`CMSTriggerRatio`和`MinHeapFreeRatio`的值计算阈值：

~~~
GC threshold = MinHeapFreeRatio * CMSTriggerRatio
~~~

### 对象存活判断

JVM使用可达性分析算法（Reachability Analysis）判断对象是否能被回收，具体不赘。只列出GC Root：

- 虚拟机栈中引用的对象。
- 方法区中类静态属性实体引用的对象。
- 方法区中常量引用的对象。
- 本地方法栈中JNI引用的对象。

被GC root直接或间接引用的对象不能被回收。反之，就是应该回收的对象。

### GC算法



### GC收集器

GC收集器是GC算法的实现。

### GC参数

### 参考

- http://blog.csdn.net/iter_zc/article/details/41802365
- https://www.cubrid.org/blog/understanding-java-garbage-collection
- https://www.javaworld.com/article/2078645/java-se/jvm-performance-optimization-part-3-garbage-collection.html
- https://www.dynatrace.com/resources/ebooks/javabook/how-garbage-collection-works/
- https://plumbr.eu/handbook/what-is-garbage-collection
- http://stas-blogspot.blogspot.hk/2011/07/most-complete-list-of-xx-options-for.html
