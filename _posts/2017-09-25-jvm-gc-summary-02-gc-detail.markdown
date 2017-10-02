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

如图：

![Alt](/images/gc(1).png)

### GC算法

大部分的垃圾回收器的实现，其实就是两个阶段：

1. 找到存活的对象。
2. 清除其余的对象 - dead objects。

其中，第一阶段需要借助标记（Marking）实现的。下面详细来看看：

#### Marking Reachable Objects

上一节已经说了JVM是使用可达性分析算法判断对象是否存活的。在Marking阶段，JVM会先找到预先定义好的GC Root（也就是上文列出的对象）。然后沿着GC ROOT递归的遍历所有引用的对象，这时候，所有被访问到的对象都会被标记（marked）是存活的。

当遍历完成时，所有存活的对象都被标记了。剩下的对象就是可以被回收的。

在这一步里，有这几点值得注意的：

1. Marking阶段是stop-the-world的。否则，在标记的同时，所有对象还在不停的变换，会有很严重的bug。因为是stop-the-world的，所以JVM需要让所有线程都进入 **safe-point**，然后才能挂起线程。更具体的细节不做深入理解了，点到为止吧。
2. 这阶段的耗时取决于所有 **alive object** 的 **数量**。既不是对象数量，也不是堆的大小。所以，增加堆的容量并不能降低marking阶段的耗时。

#### Removing Unused Objects

标记好存活的对象后，接下来就是清除可以回收的对象。在不同的收集器里，这一阶段可分为这三种做法：

- sweep - 清扫：
   这种做法相对是最简单最直观的。JVM会维护一个列表（free-list），marking阶段结束后，JVM会找到可以回收的对象的内存地址，然后记录在free-list里。也就是，free-list标记了哪些内存区域是可以被重用的。下次分配内存时会直接使用free-list上的空间。

   sweep最大的问题就是会引起内存碎片的问题。

   GC-sweep.png

   ![Alt](/images/gc(1).png)

- compact - 压缩（或整理）



- copy - 复制



### GC收集器

GC收集器是GC算法的实现。

### GC参数

- -XX:+MaxTenuringThreshold。设置一个对象在新生代存活多少次minor GC后会晋升到老年代，默认值是15。

### 参考

- http://blog.csdn.net/iter_zc/article/details/41802365
- https://www.cubrid.org/blog/understanding-java-garbage-collection
- https://www.javaworld.com/article/2078645/java-se/jvm-performance-optimization-part-3-garbage-collection.html
- https://www.dynatrace.com/resources/ebooks/javabook/how-garbage-collection-works/
- https://plumbr.eu/handbook/what-is-garbage-collection
- http://stas-blogspot.blogspot.hk/2011/07/most-complete-list-of-xx-options-for.html
- http://xiao-feng.blogspot.com/2008/01/gc-safe-point-and-safe-region.html
