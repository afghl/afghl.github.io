---
title:  "（业务系统的）性能优化总结（1）"
date:   2020-10-15 20:53:00 +0800
tags: [performance,performance-optimize]
---

性能优化是个很大的话题。但如果将问题范围缩小到“业务系统”的性能问题，其实问题的范围会收窄很多，从而很多问题的解决方案都是有套路可循的，无外乎是几板斧：接口优化、缓存、异步、批量、系统解耦。其实大部分是系统架构优化的话题，而在其中，有很多patterns是可以沉淀和复用的。

曾经有不少机会负责系统的性能优化相关的工作。这系列文章，会将我的一些经验、知识和曾经用过的套路总结一下。希望对你有帮助。

首先我们想想，一个业务开发的同学，他关于性能优化的一个最基础的知识图谱应该是怎样的？这是我目前认为需要了解的几个面向：

![Alt](/images/performance-1.png)

也就是说，要做性能优化，你首先要能知道性能出现问题了。而要发现问题，你首先要知道节点正常状态下的表现，然后观察哪一些指标和常态下不一样，推断背后的原因。用性能测试的手段验证，进一步定位问题，然后提出解决方法。

这篇文章会首先来看看性能调优所需要的前置知识 ---- 生产环境里，节点的线程模型，和各种类型的应用的线上的典型表现。

### 了解线上节点的特性，我们应该把重点放在哪里

大部分互联网应用都在处理业务对象，比如：订单、商品、消息、用户数据，做一些符合业务场景的状态流转。这些业务实体都是存储在数据库DB层，所以大部分系统都在做这样的事情：把一个或多个业务实体从DB或其他系统读取出来，做状态流转，校验业务约束，然后需要保存的话，再持久化到数据库层。这就是我们常说的CRUD。

再看看这样一组数据：

> L1 cache reference 0.5 ns
Branch mispredict 5 ns
L2 cache reference 7 ns
Mutex lock/unlock 25 ns
Main memory reference 100 ns
Compress 1K bytes with Zippy 3,000 ns
Send 2K bytes over 1 Gbps network 20,000 ns
Read 1 MB sequentially from memory 250,000 ns
Round trip within same datacenter 500,000 ns
Disk seek 10,000,000 ns
Read 1 MB sequentially from disk 20,000,000 ns
Send packet CA->Netherlands->CA 150,000,000 ns

（摘录自Jeff Dean的"Designs, Lessons and Advice from Building Large Distributed Systems"）

CPU访问内存的速度是访问硬盘和网络的速度的100000倍左右。

**应该说，一般的业务系统，在处理一个请求时，线程有超过90%的时间都在等待网络IO或磁盘IO，而线程资源就是服务器中最宝贵的资源之一。（下文会继续探讨这一点）**

这部分的耗时我们无法通过简单的优化代码而降低，这就是为什么了解数据库原理如此重要的原因，因为很多接口延迟高，或者系统负载过高，都是因为数据库使用姿势错误（字段过大、索引建立不对等）。

### dubbo & netty线程模型



线程模型 & IO模型
线程几种状态
了解dubbo & netty
有哪些线程，分别是什么状态？
生产环境里，这三组线程池应该如何设置？
• nettyBoss
• nettyWorker
• dubboServerHandler
IO密集型进程 / 计算密集型进程 在高负载的典型表现


### 参考
- https://coolshell.cn/articles/7490.html/comment-page-1#comments
- http://highscalability.com/blog/2012/5/16/big-list-of-20-common-bottlenecks.html
- https://www.oreilly.com/library/view/system-performance-tuning/059600284X/ch01.html
- https://medium.com/dm03514-tech-blog/software-performance-tuning-methodology-discover-design-measure-refine-e0866c0898b8
- 《Java性能权威指南》
