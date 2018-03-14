---
title:  "JVM GC 复习（一） - 运行时内存分区与JVM参数"
date:   2017-09-18 21:15:00 +0800
tags: [jvm,jvm-gc]
---

前几天线上出了个JVM方面的问题，看来有必要对JVM的知识再梳理和复习一下。（本系列会以JVM 8为例分析）

会整理这几方面的知识：

- JVM运行时的内存分区，各个区都放什么。（结合一些JVM设置参数）
- GC的方方面面（触发条件，算法，parNew和CMS收集器，GC的整个过程）
- 结合分析GC log分析一次GC过程
- tuning

这一篇来说说第一点，内存分区。

### Run-Time Data Areas

oracle的官方文档将jvm运行时的内存分为这几个区域：

- The pc Register
- Java Virtual Machine Stacks
- Heap
- Method Area
- Run-Time Constant Pool
- Native Method Stacks

先看看内存布局：

![Alt](/images/JVM-runtime-data-area.jpg)

概括的说，整个运行时的内存可分为这三大部分：

- Heap - 程序运行期间，需要动态分配对象 / 内存时，都会分配在这里。
- Stack - 程序运行期间，存放方法调用栈，存放的数据是方法的local variable、partial results等。顾名思义，数据结构也是栈。栈内每一个元素称为frame，每次调用一个方法时，JVM生成一个Frame压入栈；调用方法结束时，顶部的一个frame会被push出来delete掉。
- Static - 这个区域里的内存一般在进程启动时就已经初始化好，在运行时不会频繁操作这一区域，如：Constant pool。

更详细的信息，在oracle的[官方文档](https://docs.oracle.com/javase/specs/jvms/se7/html/jvms-2.html#jvms-2.5)里已经描述的很清楚了。具体不缀。

### 值得关注的区域

再分析下heap和static的划分。堆可以分为三个部分：

- Par Eden Space。新生代 Eden区
- Par Survivor Space。新生代 Survivor区
- CMS Old Gen。老年代

static区域可分为这几个部分：

- Metaspace。
- Compressed Class Space。
- Code Cache。

#### ParEdenSpace & ParSurvivorSpace & CMSOldGen

为了优化内存分配和GC效率，JVM将整个堆区域分为两部分：新生代、老年代。新生代又分为：eden、survivor from、survivor to三个区域。

具体的划分思想和对象分配/晋升机制，这里不再赘述了。

![Alt](/images/jvm-gc-01.png)

（图为1.7之前的内存布局，在java8之后，移除了方法区permanent generation）。

这里只说说相关的一些设置参数：

- -Xss。栈大小分配。（虽然不是堆的设置参数但经常放在一起设置）
- –Xms。堆的初始尺寸。也是最小尺寸。
- -Xmx。表示JVM Heap(堆内存)最大允许的尺寸。（注意：Java会尽量的维持在最小堆运行，即使设置的最大值很大，只有当GC之后也无法满足最小堆，才会去扩容。）
- -Xmn。设置新生代大小（绝对值）。
- -XX:NewRatio。设置新生代大小（比例）。比如-XX:NewRatio4 表示 新生代:老年代=1:4。
- -XX:SurvivorRatio。设置两个Survivor区（s0，s1或者from和to）和eden的比例。比如-XX:SurvivorRatio8表示两个Survivor : eden=2:8，即一个Survivor占年轻代的1/10。

#### Metaspace

metaspace是JAVA 8新划出的内存空间，它存储class的原信息，替代了原来的perm。

为什么要替代原来的perm空间？因为原来的perm空间是一块连续的内存块，而这空间是在jvm启动时就已经分配，所以如果设置太小，有可能在运行时报perm的oom，如果设置太大，又会浪费一块连续的内存空间。

于是metaspace出现了，它可以支持在运行时分配内存。

metaspace其实由两大部分组成：

- Klass Metaspace
- NoKlass Metaspace

Klass Metaspace就是用来存klass的，klass是我们熟知的class文件在jvm里的运行时数据结构。

NoKlass Metaspace专门来存klass相关的其他的内容，比如method，constantPool等，这块内存是由多块内存组合起来的，所以可以认为是不连续的内存块组成的。

#### Compressed Class Space

Compressed Class Space是Metaspace的一部分。这部分的内存保存的是一堆class的指针。当开启UseCompressedClassesPointers（默认开启）参数时，这块内存空间会划分出来。划分的考虑应该和JVM优化有关。目前还没深入看这块内容。

#### Code Cache 

> The HotSpot Java VM also includes a code cache, containing memory that is used for compilation and storage of native code.

这部分的内存存放native方法的代码。一般不会出问题，不深入研究了

### 参考

- https://www.programcreek.com/2013/04/jvm-run-time-data-areas/
- https://docs.oracle.com/javase/specs/jvms/se7/html/jvms-2.html
- https://docs.oracle.com/javase/8/docs/technotes/guides/vm/gctuning/toc.html
- http://www.jianshu.com/p/92a5fbb33764
- http://blog.csdn.net/iter_zc/article/details/41802365
- https://stackoverflow.com/questions/25867989/what-is-the-difference-between-java-non-heap-memory-and-stack-memory-are-they-s
- https://stackoverflow.com/questions/1262328/how-is-the-java-memory-pool-divided
- https://www.journaldev.com/2856/java-jvm-memory-model-memory-management-in-java
- http://java.dzone.com/articles/java-8-permgen-metaspace
