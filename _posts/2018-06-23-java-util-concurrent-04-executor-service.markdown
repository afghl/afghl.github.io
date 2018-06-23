---
title:  "学习juc包 - 线程池 - ExecutorService实现原理"
date:   2018-06-23 15:44:00 +0800
tags: [java,concurrency,juc,executor]
---

再来看看java的juc包下的线程池相关实现。既然面试那么那么爱考，那就把它背一背。

### 相关抽象

先来看看juc包里线程池相关的抽象和接口：

线程池相关：

- `Executor`：严格来说它不是线程池的抽象，只是“执行者”，甚至不保证异步执行。它提供`execute`方法，执行一个`Runnable`的方法。
- `ExecutorService`：继承`Executor`：线程池的抽象，提供一些生命周期管理的方法，除了能执行`Runable`之外还能执行`Callable`。
- `AbstractExecutorService`：`ExecutorService`的抽象实现，实现`invokeAll`和`invokeAny`这两个方法。
- `ThreadPoolExecutor`：继承`AbstractExecutorService`，`ExecutorService`的主要实现，下详。
- `ForkJoinPool`：继承`AbstractExecutorService`，`ExecutorService`的另一个实现，它是为那些能够被递归地拆解成子任务的工作类型量身设计的。

任务：

- `Runnable`：functionalInterface，其实就是一个方法。
- `Callable`：functionalInterface，和Runnable一样，不过有返回值。

线程生产者：

- `ThreadFactory`：提供一个方法：`newThread`，生产线程，简单易懂。线程池本身没有生产线程的能力，需要借助一个ThreadFactory实例完成。

Future：

- `Future`：在异步编程里一个有力的抽象。官方文档中说明它代表一个（将要发生的）异步运算结果。我认为可以将它看作一个将要拿到的对象的placeholder。提供阻塞的`get`方法。
- `RunnableFuture`：`Future`的扩展，含义是有能力得到运算结果的`Future`。增加1个方法`run`，成功执行后就能得到那个将要拿到的对象。
- `FutureTask`：`RunnableFuture`的实现。

Executors：

- `Executors`：`Executor`的工厂类和帮助方法。

### 怎样使用

Executors有几个静态方法创建线程池，分别是：

- `newFixedThreadPool`：返回一个固定线程数的线程池，在新增任务时，如果所有线程忙碌，那么任务会在Queue里等待直至有空闲线程。所有线程会一直存在。
- `newCachedThreadPool`：线程池内的线程数动态可变（0 - Integer.MAX_VALUE），当一个线程超过60秒没有执行任务时，该线程会被回收。对于要执行很多小任务的场景来说，是不错的选择。
- `newSingleThreadExecutor`：一个线程的线程池，同一个时间只能有一个线程，一个任务在执行。
- `newWorkStealingPool`：返回`ForkJoinPool`实现。

怎样使用`Executor`？请看代码：

~~~ java
ExecutorService pool = Executors.newCachedThreadPool();
pool.execute(() -> System.out.println("helloworld"));
~~~

### ThreadPoolExecutor内部结构

我们可以一拍脑袋将`ThreadPoolExecutor`的内部变量分为两类，一类是执行工作的变量，另一种是配置线程池的变量：

执行工作的变量是这几个：

~~~ java

/**
 * 两个功能：1. 前三位表示线程池状态，2. 余下的为表示当前所有工作线程的数量
 */
private final AtomicInteger ctl = new AtomicInteger(ctlOf(RUNNING, 0));

/**
 * 先进先出的队列，保存所有待执行的任务
 */
private final BlockingQueue<Runnable> workQueue;

/**
 * 保存所有工作线程的set（worker是内部对工作线程的封装）
 */
private final HashSet<Worker> workers = new HashSet<Worker>();

/**
 * 线程生产工厂
 */
private volatile ThreadFactory threadFactory;

/**
 * 拒绝任务时的handler
*/
private volatile RejectedExecutionHandler handler;
~~~

配置线程池的变量：

~~~ java
/**
 * 线程池内部的线程数峰值
*/
private int largestPoolSize;

/**
 * 已完成的任务数
*/
private long completedTaskCount;

/**
 * 设置线程空闲多长时间会被回收
*/
private volatile long keepAliveTime;

/**
 * 设置是否回收空闲线程
*/
private volatile boolean allowCoreThreadTimeOut;

/**
 * （当allowCoreThreadTimeOut是false时，即不回收空闲线程），线程池内会维持的最小的线程数。
*/
private volatile int corePoolSize;

/**
 * 线程池内会维持的最大的线程数。
*/
private volatile int maximumPoolSize;
~~~

### ThreadPoolExecutor工作原理

直接看`execute`方法和`runWorker`方法。

`execute`方法可看成这几步：

- 如果当前线程池线程个数小于corePoolSize则开启新线程
- 否则添加任务到任务队列
- 如果任务队列满了，则尝试新开启线程执行任务，如果线程个数>maximumPoolSize则执行拒绝策略。

当新的worker添加到workers集合后，就是执行`runWorker`方法，runWorker方法是while循环的从队列里poll一个任务出来执行。

### 在构造线程池时有哪些常见配置

看看`ThreadPoolExecutor`的构造函数：

~~~ java
public ThreadPoolExecutor(int corePoolSize,
                          int maximumPoolSize,
                          long keepAliveTime,
                          TimeUnit unit,
                          BlockingQueue<Runnable> workQueue,
                          ThreadFactory threadFactory,
                          RejectedExecutionHandler handler) {
    if (corePoolSize < 0 ||
        maximumPoolSize <= 0 ||
        maximumPoolSize < corePoolSize ||
        keepAliveTime < 0)
        throw new IllegalArgumentException();
    if (workQueue == null || threadFactory == null || handler == null)
        throw new NullPointerException();
    this.corePoolSize = corePoolSize;
    this.maximumPoolSize = maximumPoolSize;
    this.workQueue = workQueue;
    this.keepAliveTime = unit.toNanos(keepAliveTime);
    this.threadFactory = threadFactory;
    this.handler = handler;
}
~~~

主要是几个参数：

- corePoolSize：线程池核心（正在执行任务的）线程个数。默认情况下（allowCoreThreadTimeOut = false），核心线程是不会被回收的，所以只要线程池创建超过了corePoolSize的线程，线程池的最小线程数就会保持在corePoolSize数值上。当当前线程数>corePoolSize，执行的任务会添加到队列。
- maximumPoolSize：线程池最大线程数量。
- threadFactory：线程生产的工厂。
- handler：饱和策略，当队列满了并且线程个数达到maximumPoolSize后采取的策略，比如AbortPolicy(抛出异常)，CallerRunsPolicy(使用调用者所在线程来运行任务)，DiscardOldestPolicy(调用poll丢弃一个任务，执行当前任务)，DiscardPolicy(默默丢弃,不抛出异常)

### 线程池的生命周期

这些复杂的状态调度，是由整个线程池的生命周期管理的。线程池的的生命周期有5种状态：

- RUNNING：接受新任务并且处理阻塞队列里的任务

- SHUTDOWN：拒绝新任务但是处理阻塞队列里的任务

- STOP：拒绝新任务并且抛弃阻塞队列里的任务同时会中断正在处理的任务

- TIDYING：所有任务都执行完（包含阻塞队列里面任务）当前线程池活动线程为0，将要调用terminated方法

- TERMINATED：终止状态。terminated方法调用完成以后的状态

### 参考

- http://www.blogjava.net/xylz/archive/2011/02/11/344091.html
