---
title:  "（业务系统的）性能优化总结（1）"
date:   2020-10-15 20:53:00 +0800
tags: [performance,performance-optimize]
---

性能优化是个很大的话题。但如果将问题范围缩小到“业务系统”的性能问题，其实问题的范围会收窄很多，从而很多问题的解决方案都是有套路可循的，无外乎是几板斧：接口优化、缓存、异步、批量、系统解耦。其实大部分是系统架构优化的话题，而在其中，有很多patterns是可以沉淀和复用的。

曾经有不少机会负责系统的性能优化相关的工作。这系列文章，会将我的一些经验、知识和曾经用过的套路总结一下。希望对你有帮助。

首先我们想想，一个业务开发的同学，他关于性能优化的一个最基础的知识图谱应该是怎样的？这是我目前认为需要了解的几个面向：

![Alt](/images/performance-1.png)

也就是说，要做性能优化，你首先要能知道性能出现问题了。而要发现问题，你首先要知道节点正常状态下的表现，然后观察哪一些指标和常态下不一样，推断背后的原因。用性能测试的手段验证，进一步定位问题，然后提出解决方案。

这篇文章会首先来看看性能调优所需要的前置知识 ---- 生产环境里，节点的线程模型，和各种类型的应用的在各个状态下的典型表现。

### 了解线上节点的特性，我们应该把重点放在哪里

大部分互联网应用都在处理业务对象（比如：订单、商品、消息、用户数据）做一些符合业务场景的状态流转。这些业务实体都是存储在数据库DB层，所以大部分系统都在做这样的事情：把一个或多个业务实体从DB或其他系统读取出来，做状态流转，校验业务约束，然后需要保存的话，再持久化到数据库层。这就是我们常说的CRUD。

再看看这样一组数据：

![Alt](/images/performance-2.jpg)

（https://formulusblack.com/blog/compute-performance-distance-of-data-as-a-measure-of-latency/）

这个图很有意思，意思是用人类的观感来说，假设一次CPU时钟为1秒，那么CPU访问一次一级缓存或者二级缓存需要的时间是3-9秒，而CPU访问内存的时间需要3.5 - 5.5分钟，而访问固态硬盘是2小时-2天。CPU访问内存的速度是访问硬盘和网络的速度的100000倍左右。

**应该说，一般的业务系统，在处理一个请求时，线程有超过90%的时间都在等待网络IO或磁盘IO，而线程资源就是服务器中最宝贵的资源之一。（下文会继续探讨这一点）**

这就是为什么了解数据库原理如此重要的原因，因为很多接口延迟高，或者系统负载过高，都是因为数据库使用姿势错误（字段过大、索引建立不对、SQL语句本身的问题等），这部分的耗时我们无法通过简单的优化代码而降低，往往需要使用其他套路。

### dubbo & netty线程模型

既然线程资源如此宝贵，那么就需要好好搞清楚这几个问题：

- 业务代码最终是在什么线程下执行，由谁提供，有多少个？
- 在高并发的场景下的典型表现。
- 一个节点的Throughput和接口的耗时达到多少，会将整个节点的线程资源消耗完。

我们写的业务代码是运行在jvm里，和RPC框架（比如dubbo），spring cloud运行在一个进程中。我们的业务代码，是由服务框架分配线程执行的，熔断限流降级等对节点的保护措施也是由服务框架提供的。先来看看dubbo 和 netty的线程模型。

dubbo将一个节点的角色分为provider和consumer，但一般来说一个节点既是provider也是consumer，我们可以合起来一起讨论。而因为dubbo使用netty框架作为io框架，所以一个使用dubbo框架的节点会有起码四组线程：

- (netty的)nettyBoss线程
- (netty的)nettyWorker线程
- 作为provider的业务线程 - DubboServerHandler
- 作为consumer的业务线程 - DubboClientHandler

如下图：

![Alt](/images/performance-3.jpg)

我使用矩形的长度来代表一个请求在每个线程里面的执行耗时。

nettyBoss和nettyWorker是netty用来处理网络IO的线程，在一个节点一般只有一个boss线程，它的作用是accept客户端的连接，然后将接收到的连接注册到一个worker线程上。而worker线程是处理一个connection的IO事件，比如将流转换成其他格式的数据。worker线程的数量也比较少，一般cpu核数 + 1。而DubboServerHandler和DubboClientHandler是处理业务逻辑的线程，如图：

![Alt](/images/performance-4.jpg)

以一个请求为例，这四组线程的调用如下：

- worker线程处理完io事件后，会将请求交给dubboServerHandler线程执行业务逻辑，然后马上继续等待处理网络IO。
- 业务线程（DubboServerHandler）拿到请求后，状态从WAITING转换为RUNNABLE，执行业务逻辑：根据参数定位到具体的API方法，然后执行业务代码。
- 当需要远程调用时，当前的业务线程（DubboServerHandler）会发出一个请求后获得future，在执行get时进行阻塞等待；（进入WAITING状态）。
- 当业务进程处理完请求后，返回结果。线程状态进入WAITING状态等待任务。

我们可以看一个节点的threadDump，看看这几组线程的状态：

![Alt](/images/performance-5.jpg)

可见在正常状态下，业务线程DubboServerHandler处于WAITING态。而netty线程会等待网络IO，（实际上的java线程状态是RUNNABLE，见[连接](https://stackoverflow.com/questions/1516434/should-thread-blocked-by-java-nio-selector-select-be-considered-waiting-or-run)）


### IO密集型进程 / 计算密集型进程 在高负载的典型表现

几个问题：
为什么boss一个就够了？worker核数+1就够了？


线程模型 & IO模型
了解dubbo & netty
有哪些线程，分别是什么状态？
IO密集型进程 / 计算密集型进程 在高负载的典型表现


### 参考
- https://coolshell.cn/articles/7490.html/comment-page-1#comments
- http://highscalability.com/blog/2012/5/16/big-list-of-20-common-bottlenecks.html
- https://www.oreilly.com/library/view/system-performance-tuning/059600284X/ch01.html
- https://medium.com/dm03514-tech-blog/software-performance-tuning-methodology-discover-design-measure-refine-e0866c0898b8
- 《Java性能权威指南》
- https://formulusblack.com/blog/compute-performance-distance-of-data-as-a-measure-of-latency/
- https://www.cnblogs.com/java-zhao/p/7822766.html
