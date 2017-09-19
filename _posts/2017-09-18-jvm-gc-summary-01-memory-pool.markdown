---
layout: post
title:  "JVM GC 复习（一） - 运行时内存分区与JVM参数"
date:   2017-09-18 21:15:00 +0800
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

非堆区域可分为这几个部分：

- Metaspace。
- Compressed Class Space。
- Code Cache。

#### ParEdenSpace



#### ParSurvivorSpace

#### CMSOldGen

#### Metaspace

#### CompressedClassSpace

#### CodeCache 

### 参考

- https://www.programcreek.com/2013/04/jvm-run-time-data-areas/
- https://docs.oracle.com/javase/specs/jvms/se7/html/jvms-2.html
- https://docs.oracle.com/javase/8/docs/technotes/guides/vm/gctuning/toc.html
- http://www.jianshu.com/p/92a5fbb33764
- http://blog.csdn.net/iter_zc/article/details/41802365
- https://stackoverflow.com/questions/25867989/what-is-the-difference-between-java-non-heap-memory-and-stack-memory-are-they-s
