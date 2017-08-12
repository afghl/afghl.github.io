---
layout: post
title:  "学习juc包 - 线程池"
date:   2017-08-03 15:25:00 +0800
---

java.util.concurrent包提供了多线程编程相关的工具接口，主要有：`Executor`、`ExecutorService`、`Future`等。

使用这些（线程池）接口的好处有几点：

- 性能。节省了创建和销毁线程的开销。
- 壮健。线程是稀缺资源，使用JDK本身提供的线程池能有效预防各种意外情况。

下面，会以`ThreadPoolExecutor`这个实现类为例，说说线程池的实现。

### 数据结构

如果要你实现一个`ExecutorService`接口，你会需要什么数据结构呢？

线程池需要支持多个线程并发执行，因此有一个线程集合Collection<Thread>来执行线程任务；

涉及任务的异步执行，因此需要有一个集合来缓存任务队列Collection<Runnable>；

很显然在多个线程之间协调多个任务，那么就需要一个线程安全的任务集合，同时还需要支持阻塞、超时操作，那么BlockingQueue是必不可少的；

如果是有限的线程池大小，那么长时间不使用的线程资源就应该销毁掉，这样就需要一个线程空闲时间的计数来描述线程何时被销毁；

前面描述过线程池也是有生命周期的，因此需要有一个状态来描述线程池当前的运行状态；

线程池的任务队列如果有边界，那么就需要有一个任务拒绝策略来处理过多的任务，同时在线程池的销毁阶段也需要有一个任务拒绝策略来处理新加入的任务；

上面种的线程池大小、线程空闲实际那、线程池运行状态等等状态改变都不是线程安全的，因此需要有一个全局的锁（mainLock）来协调这些竞争资源；

大概就是这些，然后看看`ThreadPoolExecutor`内部的实例变量是怎么写的吧：

~~~ java

public class ThreadPoolExecutor extends AbstractExecutorService {

    private final AtomicInteger ctl = new AtomicInteger(ctlOf(RUNNING, 0));

    private final BlockingQueue<Runnable> workQueue;

    private final ReentrantLock mainLock = new ReentrantLock();

    private final HashSet<Worker> workers = new HashSet<Worker>();

    private final Condition termination = mainLock.newCondition();

    private int largestPoolSize;

    private long completedTaskCount;

    private volatile ThreadFactory threadFactory;

    private volatile RejectedExecutionHandler handler;

    private volatile long keepAliveTime;

    private volatile boolean allowCoreThreadTimeOut;

    private volatile int corePoolSize;

    private volatile int maximumPoolSize;

    private static final RejectedExecutionHandler defaultHandler =
        new AbortPolicy();

    private static final RuntimePermission shutdownPerm =
        new RuntimePermission("modifyThread");
}

~~~

这些字段在JDK源码里对每个字段都有注释了，这里就不再一一解释。

值得一提的是：在这里，`workQueue`和`workers`是任务队列和工作线程，workers是一个`Worker`类的集合。

`Worker`是`ThreadPoolExecutor`内部对一个线程的抽象：

~~~ java

private final class Worker
        extends AbstractQueuedSynchronizer
        implements Runnable
    {
        final Thread thread;
        Runnable firstTask;
        volatile long completedTasks;
    }
~~~

很奇怪吧，它持有一个Thread，同时持有一个Runnable。它的run方法实现是这样的：

~~~ java
public void run() { runWorker(this); }

final void runWorker(Worker w) {
    Thread wt = Thread.currentThread();
    Runnable task = w.firstTask;
    w.firstTask = null;
    w.unlock(); // allow interrupts
    boolean completedAbruptly = true;
    try {
        while (task != null || (task = getTask()) != null) {
            w.lock();
            // If pool is stopping, ensure thread is interrupted;
            // if not, ensure thread is not interrupted.  This
            // requires a recheck in second case to deal with
            // shutdownNow race while clearing interrupt
            if ((runStateAtLeast(ctl.get(), STOP) ||
                 (Thread.interrupted() &&
                  runStateAtLeast(ctl.get(), STOP))) &&
                !wt.isInterrupted())
                wt.interrupt();
            try {
                beforeExecute(wt, task);
                Throwable thrown = null;
                try {
                    task.run();
                } catch (RuntimeException x) {
                    thrown = x; throw x;
                } catch (Error x) {
                    thrown = x; throw x;
                } catch (Throwable x) {
                    thrown = x; throw new Error(x);
                } finally {
                    afterExecute(task, thrown);
                }
            } finally {
                task = null;
                w.completedTasks++;
                w.unlock();
            }
        }
        completedAbruptly = false;
    } finally {
        processWorkerExit(w, completedAbruptly);
    }
}

~~~

从源码可以看到：Worker的run方法实现就是从`workQueue`里拿任务出来执行。

一旦线程池启动线程后（调用线程run()）方法，那么线程工作队列Worker就从第1个任务开始执行（这时候发现构造Worker时传递一个任务的好处了），一旦第1个任务执行完毕，就从线程池的任务队列中取出下一个任务进行执行。循环如此，直到线程池被关闭或者任务抛出了一个RuntimeException。

由此可见，线程池的基本原理其实也很简单，无非预先启动一些线程，线程进入死循环状态，每次从任务队列中获取一个任务进行执行，直到线程池被关闭。如果某个线程因为执行某个任务发生异常而终止，那么重新创建一个新的线程而已。如此反复。

### 生命周期

线程池原理看起来简单，但是复杂的是各种策略，例如何时该启动一个线程，何时该终止、挂起、唤醒一个线程，任务队列的阻塞与超时，线程池的生命周期以及任务拒绝策略等等。

这些复杂的状态调度，是由整个线程池的生命周期管理的。线程池的的生命周期有5种状态：

- RUNNING：接受新任务并且处理阻塞队列里的任务

- SHUTDOWN：拒绝新任务但是处理阻塞队列里的任务

- STOP：拒绝新任务并且抛弃阻塞队列里的任务同时会中断正在处理的任务

- TIDYING：所有任务都执行完（包含阻塞队列里面任务）当前线程池活动线程为0，将要调用terminated方法

- TERMINATED：终止状态。terminated方法调用完成以后的状态

状态的流转：

- RUNNING -> SHUTDOWN：显式调用shutdown()方法，或者隐式调用了finalize(),它里面调用了shutdown（）方法。

- RUNNING or SHUTDOWN)-> STOP：显式 shutdownNow()方法

- SHUTDOWN -> TIDYING：当线程池和任务队列都为空的时候

- STOP -> TIDYING：当线程池为空的时候

- TIDYING -> TERMINATED：当 terminated() hook 方法执行完成时候

有限状态机：

![Alt](/images/Executor-Lifecycle_4.png)

### 关键方法

下面，看看`ThreadPoolExecutor`的一些关键接口的实现和机制。

#### execute

看看`execute`方法的源码：

~~~ java
public void execute(Runnable command) {
    if (command == null)
        throw new NullPointerException();

    //获取当前线程池的状态+线程个数变量
    int c = ctl.get();

    // 如果当前线程池的线程数是否小于 corePoolSize，如果是就新增一个线程执行任务
    if (workerCountOf(c) < corePoolSize) {
        if (addWorker(command, true))
            return;
        c = ctl.get();
    }

    // 如果线程池的线程池已经大于等于corePoolSize了，那就将任务添加到队列中，
    if (isRunning(c) && workQueue.offer(command)) {
        // recheck当前线程池的状态，如果不是RUNNING了，那就拒绝这个任务
        int recheck = ctl.get();
        if (! isRunning(recheck) && remove(command))
            reject(command);
        // 如果线程池为空，添加一个空的线程。
        else if (workerCountOf(recheck) == 0)
            addWorker(null, false);
    }

    // 代码能执行到这里，说明队列满了或线程池不是RUNNING状态，这时，再次尝试添加到线程池，如果失败就执行拒绝策略
    else if (!addWorker(command, false))
        reject(command);
}
~~~

jdk8的线程池实现需要处理太多了并发问题了，无法在文中一一说清。先写到这里吧，有兴趣的可以再参见[这篇文章](http://ifeve.com/java%E4%B8%AD%E7%BA%BF%E7%A8%8B%E6%B1%A0threadpoolexecutor%E5%8E%9F%E7%90%86%E6%8E%A2%E7%A9%B6/
)

### 参考

- http://www.blogjava.net/xylz/archive/2010/07/08/325587.html
- https://docs.oracle.com/javase/7/docs/api/java/util/concurrent/ThreadPoolExecutor.html
- http://ifeve.com/java-threadpool/
- http://www.blogjava.net/xylz/archive/2011/01/18/343183.html
- http://ifeve.com/java%E4%B8%AD%E7%BA%BF%E7%A8%8B%E6%B1%A0threadpoolexecutor%E5%8E%9F%E7%90%86%E6%8E%A2%E7%A9%B6/
