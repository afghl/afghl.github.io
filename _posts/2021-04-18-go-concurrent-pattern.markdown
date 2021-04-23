---
title:  "Golang学习（1） - Go并发模式"
date:   2021-04-18 15:13:00 +0800
tags: [go,golang,concurrent,pattern,goroutine,channel]
---

最近工作用到Golang会比较多。因此计划花2 - 3星期学学Go语言。在这里记录学习过程的一些记录和想法。希望对你也有帮助。

要快速一个新的语言，我认为有几个重点需要关注：1. 知道它的关键部分的设计思想和原理，避免踩坑，而且能快速定位和解决问题；2. 知道它的设计哲学，写出比较好的代码。

基于此，对于golang而言，有几个比较重要的部分值得学习整理：

- 并发的设计和使用
- 运行时
- 语言设计哲学
- 工程化

这一篇先来说说go concurrent pattern，它是go语言的最大亮点和最值得学习的地方。

浏览了一些书和网上的一些课程，基本都没有知识结构。所以只能类比之前的经验（java）先理一下我的疑问，再来逐个解答，以问题的方式串起来这一块知识，我们大概可以这样提问：

- 协程是啥？和它的一些特点：用户态调度，非抢占式，轻量级线程等。
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

golang使用协程而非线程进行并发。操作系统层面有三个“执行体”的概念：进程，线程，协程。这些概念的诞生都是为了解决一个问题：CPU计算速度远远高于CPU访问内存、磁盘、网络的速度。进程和线程的设计就是为了让CPU可以同一时间做多件事情。而对每个执行体而言，它认为CPU只为自己服务。

进程和线程的区别大家都知道：两个进程之间，内存隔离，通信一般只能靠socket；而多线程在同一个进程里，使用同一个内存空间。

协程也是一个执行体，它可以理解为用户态的线程，在使用上和线程基本无异，主要有几个不同：

1. 协程轻量级：所占用的空间更小，协程切换的开销更小
2. 线程的调度发生在操作系统，由操作系统实现；而协程的调度发生在用户内存空间，由用户实现。

既然协程的用法和线程很像，那么为什么需要用协程取代线程呢？其中一个原因，不难想到，就是高负载的网络请求模型这个典型场景。对网络服务器来说，大量的来自客户端的请求包和服务器的返回包，都是网络 IO；在响应请求的过程中，往往需要访问存储来保存和读取自身的状态，这也涉及本地或网络 IO，也就是说要保持足够的吞吐量，必须创建足够多的线程，而实际上线程也经常是瓶颈。

一个线程所需的内存空间大概是数MB（linux），也就是1000个线程已经是GB级别。在java里，我们的解法是使用线程池去管理这种资源：在服务器节点有一个worker pool，它去处理请求，如果这批线程全都忙碌（其实都在等IO或者等锁），就拒绝请求。这也就是为什么，一个典型的IO密集型应用即使在大流量冲击时，CPU使用率一般也远远不会打满，而这时有大量的线程阻塞等待，线程就成为了资源瓶颈。我们可以看到很多线上事故，最初暴露的现象往往是服务器节点报错“无可用线程”。

协程通过降低空间成本（内存空间）和时间成本（降低调度的时间）来解决这个问题。在golang里，能同时创建上百万个协程来调度，这背后是如何实现的呢？

### goroutine与调度

如上所说，既然协程是用户态的线程，那它与OS无关。在Kernel里面，它只知道自己运行的是线程，调度单位也是线程。所以要实现协程，就是要负责协程的抽象和调度，说白了在这一块里和操作系统干的活差不多。我们可以建立一个这样的心智模型：

![Alt](/images/go-1-runtime.png)

实际上go runtime由c代码实现，在编译时会和用户代码编译在一起，所以并不会有这样的分层。但这有助我们去理解调度器scheduler：我们向runtime创建goroutine和运行代码，runtime在内部管理所有的goroutine（想象一个大的线程池），它向下和OS交互，申请线程和管理系统调用。

协程和线程的比例肯定是多对一，也就是多个goroutine的代码有可能由同一个线程执行，而操作系统对此并不知情，所以协程的context需要在用户态实现保存和切换调度。

#### 调度原理

建立大的模型之后，还需要关心几个细节问题，比如：

- 多个协程共享使用一个线程，当一个协程发起系统调用导致挂起，那么正常来说肯定会影响其他协程，这个问题怎么解决呢？
- 协程的生命周期，创建后何时销毁
- ......

需要再细看一下goroutine调度的实现。

先说说上一个版本的设计和实现，也就是GM模型。原来的调度器由三个部件构成：

- G。协程的抽象。

``` go
struct G {
  byte∗ stackguard; // stack guard information
  byte∗ stackbase; // base of stack
  byte∗ stack0; // current stack pointer
  byte∗ entry; // initial function
  void∗ param; // passed parameter on wakeup
  int16 status; // status
  int32 goid; // unique id
  M∗ lockedm; // used for locking M’s and G’s
  ...
};
```

- M。指向一个OS线程的抽象。

```go
struct M {
  G∗ curg; // current running goroutine
  int32 id; // unique id
  int32 locks ; // locks held by this M
  MCache ∗mcache; // cache for this thread
  G∗ lockedg; // used for locking M’s and G’s
  uintptr createstack [32]; // Stack that created this thread
  M∗ nextwaitm; // next M waiting for lock
  ...
};
```

- SCHED。一个全局对象。它持有一个全局锁。并维护G和M的队列。如果需要修改队列，必须获得这个全局锁。

``` go
struct Sched {
  Lock; // global sched lock .
  // must be held to edit G or M queues
  G ∗gfree; // available g’ s ( status == Gdead)
  G ∗ghead; // g’ s waiting to run queue
  G ∗gtail; // tail of g’ s waiting to run queue
  int32 gwait; // number of g’s waiting to run
  int32 gcount; // number of g’s that are alive
  int32 grunning; // number of g’s running on cpu
  // or in syscall
  M ∗mhead; // m’s waiting for work
  int32 mwait; // number of m’s waiting for work
  int32 mcount; // number of m’s that have been created
  ...
};
```

这个模型就像这样：

![Alt](/images/go-1-gm.jpeg)

也就是说调度是在Sched里进行。此时的调度原理是所有的available G都放在一个global的队列，然后当一个M是runnable状态时，去队列里获取一个G来执行它的代码。此时麻烦的是当G发起一个阻塞的系统调用时，其实会把M阻塞（os层面阻塞线程）。所以这个模型最大的问题就是阻塞的系统调用带来的overhead太大。而且需要一个全局锁执行调度。

go调度器在2012年重新设计后解决了这个问题。简而言之是在G和M之间加了一层抽象，称为P，指代一个可以执行G code的资源。从而实现一个work-stealing scheduler。

看P的数据结构，可以看到中心化的Sched里面的字段有很多转移到P struct里，每个P会维护一个G队列，也分别有runnable和freelist：

``` go
struct P {
  Lock;
  G *gfree; // freelist, moved from sched
  G *ghead; // runnable, moved from sched
  G *gtail;
  MCache *mcache; // moved from M
  FixAlloc *stackalloc; // moved from M
  uint64 ncgocall;
  GCStats gcstats;
  // etc
  ...
};
```

进程内有多个P，所有的P在一个队列里保存：

``` go
P *allp; // [GOMAXPROCS]
```

引入了P之后，整个调度过程变成：goroutine创建之后不会放入一个中心化队列，而是放入其中一个P的本地队列，等待调度。而P最终调用M来执行G的代码。且P上面会实现work stealing算法：当P的队列为空时，它会从其他的P里随机抽一个，偷走一半的runnable goroutines，而不是销毁线程。

另一项优化是它避免了一个G在系统调用时会产生过多开销，具体的做法是：引入了P之后，G不直接和M关联，而是加入到P的队列里面，当线程M需要阻塞时，整个P就和这个被阻塞的M摘除，然后整个P挂到其他的线程上，就像这样：

![Alt](/images/go-1-sc.png)

> 图中的M1可能是被创建，或者从线程缓存中取出。
当MO返回时，它必须尝试取得一个context P来运行goroutine，一般情况下，它会从其他的OS线程那里steal偷一个context过来，
如果没有偷到的话，它就把goroutine放在一个global runqueue里，然后自己就去睡大觉了（放入线程缓存里）。Contexts们也会周期性的检查global runqueue，否则global runqueue上的goroutine永远无法执行。

#### 协程生命周期



#### 可观测

golang里有类似jstack的命令观察整个进程的协程运行情况。

### channel

### context

### 重构并发


#### pub sub

###多个交替打印

#### 并发度控制

一般而言不需要管理和控制goroutine的并发度。但如果每个goroutine做的事情对下游有依赖，且对下游较大，为了避免把下游瞬间打挂，还是需要控制goroutine执行的最大并行数。具体而言，可以见demo

### ref
- 《Concurrency in Go》
- https://time.geekbang.org/column/article/304188
- https://time.geekbang.org/dailylesson/detail/100056885
- https://www.youtube.com/watch?v=f6kdp27TYZs
- https://www.youtube.com/watch?v=QDDwwePbDtw
- https://blog.cloudflare.com/how-stacks-are-handled-in-go/
- https://morsmachine.dk/go-scheduler
- https://morsmachine.dk/go-scheduler
- https://docs.google.com/document/d/1TTj4T2JO42uD5ID9e89oa0sLKhJYD0Y_kqxDv3I3XMw/edit#
- http://www.cs.columbia.edu/~aho/cs6998/reports/12-12-11_DeshpandeSponslerWeiss_GO.pdf
