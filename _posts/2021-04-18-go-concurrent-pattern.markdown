---
title:  "Golang学习（1） - Go并发模式"
date:   2021-04-18 15:13:00 +0800
tags: [go,golang,concurrent,pattern,goroutine,channel]
---

最近工作用到Golang会比较多。因此计划花2 - 3星期学学Go语言。在这里记录学习过程的一些记录和想法。希望对你也有帮助。

要快速一个新的语言，我认为有几个重点需要关注：1. 知道它的关键部分的设计思想和原理，避免踩坑，而且能快速定位和解决问题；2. 知道它的设计哲学，写出比较好的代码。

基于此，我认为有几个比较重要的部分值得学习整理：

- 并发的设计和使用
- 运行时
- 设计哲学
- 工程化

这一篇先来说说go concurrent pattern，它是go语言的最大亮点和最值得学习的地方。

浏览了一些书和网上的一些课程，基本都没有知识结构。所以只能类比之前的经验（java）先理一下我的疑问，再来逐个解答，以问题的方式串起来这一块知识，我们大概可以这样提问：

- 协程是啥？和它的一些特点。
- 为什么叫用户态的线程？为什么调度起来比线程快，为什么比线程轻量级？那线程是什么态？
- 为什么说协程是非抢占式的，什么叫抢占式。
- go是怎么实现协程的：调度器的实现原理，goroutine。
- 用户态的调度器怎么实现这些功能，例如协程的yield，等等。
- goroutine的状态，生命周期以及观测的方法。
- go的并发pattern：channel。
- channel是什么和它的理论？（计算机并发一般来说早已有各种理论支撑，语言工具包甚至关键字都是对理论的实现）
- go对channel的实现，具体的数据结构。
- 为什么有很多并发场景可以转换成用channel这个思想去解决。
- 用channel的优势是啥，原有的程序怎么改造（abc线程交替打印）

可见goroutine和channel是比较重要的两块，我们先从协程说起。

### 协程coroutine

golang使用协程而非线程进行并发。

### goroutine与调度

### channel

### ref
- 《Concurrency in Go》
- https://time.geekbang.org/column/article/304188
- https://time.geekbang.org/dailylesson/detail/100056885
- https://www.youtube.com/watch?v=f6kdp27TYZs
- https://www.youtube.com/watch?v=QDDwwePbDtw
- https://blog.cloudflare.com/how-stacks-are-handled-in-go/