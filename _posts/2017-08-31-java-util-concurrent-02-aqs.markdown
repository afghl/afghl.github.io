---
layout: post
title:  "学习juc包 - AQS"
date:   2017-08-31 00:02:00 +0800
---

在分布式系统中，节点需要协作，同步。在多线程程序中，线程之间也需要协作，同步：一个线程进入某个方法之前可能需要等其他的某个线程执行完某个方法之后。我们使用锁来协调这些线程间同步。

java1.5之后提供非语法层面的同步锁，比如ReentrantLock，这些锁内部都是使用一个类：java.util.concurrent.locks.AbstractQueuedSynchronizer，来完成核心工作的。这几篇文章就会从源码级别来看看aqs类的工作机制。

### AQS要提供的功能

AQS是一个同步器，最起码需要提供这样两个接口：

- acquire，获取锁：首先判断当前状态是否允许获取锁，如果是就获取锁，否则就阻塞操作或者获取失败，也就是说如果是独占锁就可能阻塞，如果是共享锁就可能失败。

伪代码如下：

~~~
 Acquire:
     while (!tryAcquire(arg)) {
        <em>enqueue thread if it is not already queued</em>;
        <em>possibly block current thread</em>;
     }
~~~

- release，释放锁：释放等待这个锁的一个或者更多线程。

伪代码如下：

~~~
 Release:
      if (tryRelease(arg))
         <em>unblock the first queued thread</em>;
~~~

注意当多个线程调用acquire的时候，那么如果锁已经被获取了，这些线程都会阻塞。怎样用最简单的数据结构实现这基本的功能呢？根据Doug Lea的论文，这样的操作需要3个元件：

- 原子性操作同步器的状态位
- 一些阻塞或非阻塞的线程
- 一个有序的队列

这几点也是AQS在设计API和数据结构时的思路。

### 

### 参考

- http://ifeve.com/abstractqueuedsynchronizer-use/
- http://www.blogjava.net/xylz/archive/2010/07/06/325390.html
- http://ifeve.com/java-special-troops-aqs/
- http://gee.cs.oswego.edu/dl/papers/aqs.pdf
