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

CMS是为了避免长时间的GC暂停而设计的。

### 参考

- https://plumbr.eu/handbook/garbage-collection-algorithms-implementations#parallel-minor-gc
