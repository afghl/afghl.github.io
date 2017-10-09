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
| :-------------: |:-------------:|
| Serial      | Serial |-XX:+UseSerialGC |
| Parallel Scavenge      | Parallel Old |-XX:+UseParallelGC -XX:+UseParallelOldGC |
| Parallel New      | CMS |-XX:+UseConcMarkSweepGC |
| G1      |   |-XX:+UseG1GC |


### 参考

- https://plumbr.eu/handbook/garbage-collection-algorithms-implementations#parallel-minor-gc
