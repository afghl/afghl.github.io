---
layout: post
title:  "学习java.util.concurrent包"
date:   2017-07-30 15:25:00 +0800
---

学习一下java并发编程常用到的包：java.util.concurrent。先来看下overview。

### concurrent包结构

整个包下的类，按功能可分为这几部分：

- Task scheduling framework
- Fork/join framework
- Concurrent collections
- Atomic variables
- Synchronizers
- Locks
- Nanosecond-granularity timing.

再看看官方的简介：

**Task scheduling framework**. The Executor interface standardizes invocation, scheduling, execution, and control of asynchronous tasks according to a set of execution policies. Implementations are provided that enable tasks to be executed within the submitting thread, in a single background thread (as with events in Swing), in a newly created thread, or in a thread pool, and developers can create customized implementations of Executor that support arbitrary execution policies. The built-in implementations offer configurable policies such as queue length limits and saturation policy that can improve the stability of applications by preventing runaway resource use.

**Fork/join framework**. Based on the ForkJoinPool class, this framework is an implementation of Executor. It is designed to efficiently run a large number of tasks using a pool of worker threads. A work-stealing technique is used to keep all the worker threads busy, to take full advantage of multiple processors.

**Concurrent collections**. Several new collections classes were added, including the new Queue, BlockingQueue and BlockingDeque interfaces, and high-performance, concurrent implementations of Map, List, and Queue. See the Collections Framework Guide for more information.

**Atomic variables**. Utility classes are provided that atomically manipulate single variables (primitive types or references), providing high-performance atomic arithmetic and compare-and-set methods. The atomic variable implementations in the java.util.concurrent.atomic package offer higher performance than would be available by using synchronization (on most platforms), making them useful for implementing high-performance concurrent algorithms and conveniently implementing counters and sequence number generators.

**Synchronizers**. General purpose synchronization classes, including semaphores, barriers, latches, phasers, and exchangers, facilitate coordination between threads.

**Locks**. While locking is built into the Java language through the synchronized keyword, there are a number of limitations to built-in monitor locks. The java.util.concurrent.locks package provides a high-performance lock implementation with the same memory semantics as synchronization, and it also supports specifying a timeout when attempting to acquire a lock, multiple condition variables per lock, nonnested ("hand-over-hand") holding of multiple locks, and support for interrupting threads that are waiting to acquire a lock.

**Nanosecond-granularity timing**. The System.nanoTime method enables access to a nanosecond-granularity time source for making relative time measurements and methods that accept timeouts (such as the BlockingQueue.offer, BlockingQueue.poll, Lock.tryLock, Condition.await, and Thread.sleep) can take timeout values in nanoseconds. The actual precision of the System.nanoTime method is platform-dependent.

懒得翻译了。

接下来看看这个包的源码，提出、分析并解答一些比较关键的问题。

### 参考

- http://docs.oracle.com/javase/7/docs/technotes/guides/concurrency/overview.html
- https://docs.oracle.com/javase/7/docs/api/java/util/concurrent/package-summary.html
- http://www.cnblogs.com/wanly3643/category/437878.html
- http://www.blogjava.net/xylz/archive/2010/07/08/325587.html
