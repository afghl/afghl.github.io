---
layout: post
title:  "JVM GC 复习（三） - GC收集器"
date:   2017-10-03 00:02:00 +0800
---

(上一篇)[/2017/09/25/jvm-gc-summary-02-gc-detail.html]讲了一系列的GC算法。这一篇来看看这些算法的具体实现，也就是GC收集器。

JVM提供这几种GC收集器：

- Serial
- Parallel
- Concurrent Mark and Sweep (CMS)
- Garbage First (G1)

注意，因为JVM分为新生代和老年代，在使用前三个GC收集器时，需要分别设置新生代和老年代的算法。而第四个（G1）是采用分而治之的思想，将整个堆内存划分为各个小的regions，所以无所谓新生代和老年代。只需要设置一个算法。

一些workable的GC收集器设置选项是这样的：

| 新生代         | 老年代         | JVM options      |
||||
| Serial      | Serial |-XX:+UseSerialGC |
| Parallel Scavenge      | Parallel Old |-XX:+UseParallelGC -XX:+UseParallelOldGC |
| Parallel New      | CMS |-XX:+UseConcMarkSweepGC |
| G1      |   |-XX:+UseG1GC |


下面，分别介绍这四种GC组合。

### Serial GC

也就是Serial for young GC & Serial for Old GC。

这个GC组合，实际的GC算法是：

- 新生代：标记 - 复制
- 老年代：标记 - 压缩

这个不是重点，重点是：这种GC收集器在young GC和full GC阶段都是单线程的，也就是都会stop-the-world，并且只能利用一个CPU核。

这种算法对CPU利用率不高，stop-the-world时间很长，在server-side不会选择，不展开说了。

### Parallel GC

也就是Parallel Scavenge for young GC & Parallel Old for Old GC。

这种GC组合使用的GC算法和Serial是一样的。它是Serial的一个多线程版本。

多线程意味着它比Serial的stop-the-world时间更短，但是仍然是young GC和full GC都需要stop-the-world。

在高负载，高并发的后端集群里，低延迟、高吞吐量是最重要的指标，所以这个Parallel GC也可以不作考虑了。

### Concurrent Mark and Sweep

CMS是为了避免长时间的GC暂停而设计的。也就生产环境常用的收集器选择。下面来详细说说CMS收集器。

它在新生代使用标记 - 复制算法（也就是常说的将新生代分为eden survivor区域），在老年代使用的是标记 - 清扫算法（也就是使用free-list记录可使用的内存区域）。

它和前两种收集器最大的区别是：它是最高程度的并发的。整个GC阶段的大部分时间，GC线程和其他线程是并发执行的，只会有很少的时间出现stop-the-world。

下面结合一段GC log，说说CMS是如何达到“最高程度的并发”的：

~~~
[GC (Allocation Failure) 64.322: [ParNew: 613404K->68068K(613440K), 0.1020465 secs] 10885349K->10880154K(12514816K), 0.1021309 secs] [Times: user=0.78 sys=0.01, real=0.11 secs]
[GC (CMS Initial Mark) [1 CMS-initial-mark: 10812086K(11901376K)] 10887844K(12514816K), 0.0001997 secs] [Times: user=0.00 sys=0.00, real=0.00 secs]
[CMS-concurrent-mark-start]
[CMS-concurrent-mark: 0.035/0.035 secs] [Times: user=0.07 sys=0.00, real=0.03 secs]
[CMS-concurrent-preclean-start]
[CMS-concurrent-preclean: 0.016/0.016 secs] [Times: user=0.02 sys=0.00, real=0.02 secs]
[CMS-concurrent-abortable-preclean-start]
[CMS-concurrent-abortable-preclean: 0.167/1.074 secs] [Times: user=0.20 sys=0.00, real=1.07 secs]
[GC (CMS Final Remark) [YG occupancy: 387920 K (613440 K)]65.550: [Rescan (parallel) , 0.0085125 secs]65.559: [weak refs processing, 0.0000243 secs]65.559: [class unloading, 0.0013120 secs]65.560: [scrub symbol table, 0.0008345 secs]65.561: [scrub string table, 0.0001759 secs][1 CMS-remark: 10812086K(11901376K)] 11200006K(12514816K), 0.0110730 secs] [Times: user=0.06 sys=0.00, real=0.01 secs]
[CMS-concurrent-sweep-start]
[CMS-concurrent-sweep: 0.027/0.027 secs] [Times: user=0.03 sys=0.00, real=0.03 secs]
[CMS-concurrent-reset-start]
[CMS-concurrent-reset: 0.012/0.012 secs] [Times: user=0.01 sys=0.00, real=0.01 secs]
~~~

以上是一次完整的CMS full GC的GC log。其中，第一行是minor GC，其余的log是由minor GC所触发的full GC。我们会在下一篇详细分析GC Log。在这里，只看看整个CMS过程所有的阶段：

首先是minor GC阶段（第一行）：CMS使用ParNew收集器，minor GC的过程是stop-the-world的。



### 参考

- https://plumbr.eu/handbook/garbage-collection-algorithms-implementations#parallel-minor-gc
- http://www.oracle.com/webfolder/technetwork/tutorials/obe/java/G1GettingStarted/index.html
- https://blogs.oracle.com/jonthecollector/the-unspoken-phases-of-cms
- https://blogs.oracle.com/jonthecollector/our-collectors
