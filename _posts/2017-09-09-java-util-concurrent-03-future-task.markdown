---
layout: post
title:  "学习juc包 - FutureTask是如何实现的"
date:   2017-09-09 23:39:00 +0800
---

future接口是的作用是跨线程拿到其他线程的处理结果。future接口是对一个即将拿到的结果的抽象，runnable接口是一个可以被执行的任务的抽象。今天看一下future接口的重要实现：futureTask，发现还是比较简单的。

### 一种workaround

问：如果没有future接口，你要实现跨进程获得处理结果，要怎么做呢？应该大部分人都会想到，利用闭包在线程间共享对象即可：

~~~ java
class Container {
    private Object result;
    // omitted getter setter...
}

public static void main(String[] args) {
    ExecutorService pool = Executors.newFixedThreadPool(10);
    Container c = new Container();
    Runnable r = () -> {
        c.setResult(2);
    };

    try {
        pool.execute(r);
    } finally {
        pool.shutdown();
    }

    System.out.println(c.getResult());
}
~~~

这是比较原始的方式。futureTask的实现思路和上面代码块中的实现思路是一样的。

### 数据结构

FutureTask的数据结构很简单：

~~~ java
public class FutureTask<V> implements RunnableFuture<V> {
    /** The underlying callable; nulled out after running */
    private Callable<V> callable;
    /** The result to return or exception to throw from get() */
    private Object outcome; // non-volatile, protected by state reads/writes
    /** The thread running the callable; CASed during run() */
    private volatile Thread runner;
    /** Treiber stack of waiting threads */
    private volatile WaitNode waiters;
}
~~~

解释一下：

- callable：要执行的任务。
- runner：执行这个任务的线程。
- outcome：执行结果。

看到这个结构，怎么实现的就比较清晰了：

future接口实际上可看成callable的代理：通过将call方法的返回值放在一个叫做outcome的变量中，在线程间共享这个outcome对象。

### run

futureTask同时实现future和runnable接口，我们调用`executorService.submit`方法的时候，实际上是拿出线程池里一个线程，执行futureTask的run方法：

~~~ java
public void run() {
    if (state != NEW ||
        !UNSAFE.compareAndSwapObject(this, runnerOffset,
                                     null, Thread.currentThread()))
        return;
    try {
        Callable<V> c = callable;
        if (c != null && state == NEW) {
            V result;
            boolean ran;
            try {
                result = c.call();
                ran = true;
            } catch (Throwable ex) {
                result = null;
                ran = false;
                setException(ex);
            }
            if (ran)
                set(result);
        }
    } finally {
        // runner must be non-null until state is settled to
        // prevent concurrent calls to run()
        runner = null;
        // state must be re-read after nulling runner to prevent
        // leaked interrupts
        int s = state;
        if (s >= INTERRUPTING)
            handlePossibleCancellationInterrupt(s);
    }
}
~~~

run方法做了三件事：

1. 先记录一下执行run方法的当前线程，放到runner这个field里。
2. 执行callable，将返回结果放在outcome里。
3. 执行完成后，将runner赋值为空。

想想为什么需要第三步，将runner赋值为空？

### get

future的get是获取计算结果的接口，它会阻塞当前线程：

~~~ java
public V get() throws InterruptedException, ExecutionException {
    int s = state;
    if (s <= COMPLETING)
        s = awaitDone(false, 0L);
    return report(s);
}
~~~

~~~ java
private int awaitDone(boolean timed, long nanos)
    throws InterruptedException {
    final long deadline = timed ? System.nanoTime() + nanos : 0L;
    WaitNode q = null;
    boolean queued = false;
    for (;;) {
        if (Thread.interrupted()) {
            removeWaiter(q);
            throw new InterruptedException();
        }

        int s = state;
        if (s > COMPLETING) {
            if (q != null)
                q.thread = null;
            return s;
        }
        else if (s == COMPLETING) // cannot time out yet
            Thread.yield();
        else if (q == null)
            q = new WaitNode();
        else if (!queued)
            queued = UNSAFE.compareAndSwapObject(this, waitersOffset,
                                                 q.next = waiters, q);
        else if (timed) {
            nanos = deadline - System.nanoTime();
            if (nanos <= 0L) {
                removeWaiter(q);
                return state;
            }
            LockSupport.parkNanos(this, nanos);
        }
        else
            LockSupport.park(this);
    }
}
~~~

`awaitDone`方法会比较futureTask的state，如果已完成（state > COMPLETING）直接返回，否则调用LockSupport.park（内部调用unsafe阻塞当前线程）。

### 参考

- http://ifeve.com/futuretask-source/
