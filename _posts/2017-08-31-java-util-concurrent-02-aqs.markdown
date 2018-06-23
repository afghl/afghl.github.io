---
title:  "学习juc包 - AQS"
date:   2017-08-31 00:02:00 +0800
tags: [java,concurrency,juc]
---

在分布式系统中，节点需要协作，同步。在多线程程序中，线程之间也需要协作，同步：一个线程进入某个方法之前可能需要等其他的某个线程执行完某个方法之后。我们使用锁来协调这些线程间同步。

java1.5之后提供非语法层面的同步锁，比如ReentrantLock，这些锁内部都是使用一个类：java.util.concurrent.locks.AbstractQueuedSynchronizer，来完成核心工作的。这篇文章就会从源码级别来看看aqs类的工作机制。

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

### 数据结构

下面看看AQS内部的几个字段：

- private volatile int state;
- private transient volatile Node head;
- private transient volatile Node tail;

其中state描述的有多少个线程取得了锁，对于互斥锁来说state<=1。

head/tail加上CAS操作就构成了一个CHL的FIFO队列。

#### Node内部数据结构

下面看看Node内部的数据结构：

- volatile int waitStatus; 节点的等待状态，一个节点可能位于以下几种状态：

   - 0： 正常状态，新生的非CONDITION节点都是此状态。
   - CANCELLED = 1： 节点操作因为超时或者对应的线程被interrupt。节点不应该留在此状态，一旦达到此状态将从CHL队列中踢出。
   - SIGNAL = -1： 节点的继任节点是（或者将要成为）BLOCKED状态（例如通过LockSupport.park()操作），因此一个节点一旦被释放（解锁）或者取消就需要唤醒（LockSupport.unpack()）它的继任节点。
   - CONDITION = -2：表明节点对应的线程在等待Condition。

   非负值标识节点不需要被通知（唤醒）。

- volatile Node prev;此节点的前一个节点。节点的waitStatus依赖于前一个节点的状态。

- volatile Node next;此节点的后一个节点。后一个节点是否被唤醒（uppark()）依赖于当前节点是否被释放。

- volatile Thread thread;节点绑定的线程。

- Node nextWaiter;下一个等待条件（Condition）的节点，由于Condition是独占模式，因此这里有一个简单的队列来描述Condition上的线程节点。

### 分析 acquire 方法

如上文所说，acquire动作就是获取锁，如果当前锁在被其他线程使用，会阻塞当前线程。acquire方法的实现：

~~~ java
public final void acquire(int arg) {
    if (!tryAcquire(arg) &&
        acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        selfInterrupt();
}
~~~

其中，`tryAcquire`方法需要子类实现，在这里先看`ReentrantLock`类里的公平锁`FairSync`是怎样实现这个方法的：

~~~ java
protected final boolean tryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    int c = getState();
    // c = 0 说明没有其他线程占有锁
    if (c == 0) {
        if (!hasQueuedPredecessors() &&
            compareAndSetState(0, acquires)) {
            setExclusiveOwnerThread(current);
            return true;
        }
    }
    else if (current == getExclusiveOwnerThread()) {
        int nextc = c + acquires;
        if (nextc < 0)
            throw new Error("Maximum lock count exceeded");
        setState(nextc);
        return true;
    }
    return false;
}
~~~

这个方法是比较简单的：

首先，这里的`hasQueuedPredecessors`方法是判断队列中是否有其他线程在等待锁（此方法非阻塞），然后将`state`变量（内部表示锁状态的变量）设为1，最后将`exclusiveOwnerThread`置位为当前thread，表示锁被当前线程占有。

看后一半的代码，也就是`c == 0` 且 `Thread.currentThread() == getExclusiveOwnerThread()`，意思是重入了，这时简单执行state + 1，为什么不用CAS？因为只有一个线程可重入。

在看acquire方法，当`tryAcquire`返回true时，其实下面的方法都不会执行了，也就是说，当锁是空闲状态时，获得锁操作是简单的set两个值：`state`，`exclusiveOwnerThread`。

我们看`tryAcquire`为false时继续执行的代码：

~~~ java
acquireQueued(addWaiter(Node.EXCLUSIVE), arg)
~~~

我们先看addWaiter方法，这个方法是把当前请求放到队列中：

~~~ java
private Node addWaiter(Node mode) {
    Node node = new Node(Thread.currentThread(), mode);

// Try the fast path of enq; backup to full enq on failure
// 上面这个官方注释很直白，其实下面的enq方法里也执行了这段代码，但是这里先直接试一下看能
//  否插入成功
    Node pred = tail;
    if (pred != null) {
        node.prev = pred;
// CAS把tail设置成当前节点，如果成功的话就说明插入成功，直接返回node，失败说明有其他线程也
// 在尝试插入而且其他线程成功,如果是这样就继续执行enq方法
        if (compareAndSetTail(pred, node)) {
            pred.next = node;
            return node;
        }
    }
    enq(node);
    return node;
}
~~~

（这里有一个小小巧妙的地方在这句`Node pred = tail;`，为什么要赋值一下？原因是在CAS成功之后如果执行：`tail.next = node;`，有可能tail已经被其他线程置位成其他的Node，而产生竞争问题）

继续看enq方法：

~~~ java

private Node enq(final Node node) {
    for (;;) {
        Node t = tail;
        if (t == null) { // Must initialize
// 最开始head和tail都是空的，需要通过CAS做初始化，如果CAS失败，则循环重新检查tail
            if (compareAndSetHead(new Node()))
                tail = head;
        } else {
// head和tail不是空的，说明已经完成初始化，和addWaiter方法的上半段一样，CAS修改
            node.prev = t;
            if (compareAndSetTail(t, node)) {
                t.next = node;
                return t;
            }
        }
    }
}
~~~

`addWaiter`是对锁内部的线程FIFO的队列进行操作。这个方法执行完成后，锁内部的FIFO队列会多了一个Node。

这里注意当`t == null`时，也就是第一次成功执行`addWaiter`方法，会调用：

~~~ java
compareAndSetHead(new Node())
~~~

给head创建一个空的Node。因此，AQS内部的队列，**head可以看作当前得到锁资源的线程**。

此时线程还是没进入阻塞状态的。

下面看看`acquireQueued`方法，这个方法会真正阻塞当前线程：

~~~ java
final boolean acquireQueued(final Node node, int arg) {
    boolean failed = true;
    try {
        boolean interrupted = false;
        for (;;) {
            final Node p = node.predecessor();
/*
* 如果前置节点是head，说明当前节点是队列第一个等待的节点，这时去尝试获取锁，如果成功了则
* 获取锁成功。这里有的同学可能没看懂，不是刚尝试失败并插入队列了吗，咋又尝试获取锁？ 其实这*
* 里是个循环，其他刚被唤醒的线程也会执行到这个代码
*/
            if (p == head && tryAcquire(arg)) {
// 队首且获取锁成功，把当前节点设置成head，下一个节点成了等待队列的队首
                setHead(node);
                p.next = null; // help GC
                failed = false;
                return interrupted;
            }
/* shouldParkAfterFailedAcquire方法判断如果获取锁失败是否需要阻塞，如果需要的话就执行
*  parkAndCheckInterrupt方法，如果不需要就继续循环
*/
            if (shouldParkAfterFailedAcquire(p, node) &&
                parkAndCheckInterrupt())
                interrupted = true;
        }
    } finally {
        if (failed)
            cancelAcquire(node);
    }
}
~~~

先看这一句：

~~~ java
if (shouldParkAfterFailedAcquire(p, node) &&
    parkAndCheckInterrupt())
    interrupted = true;
~~~

这里，`parkAndCheckInterrupt`方法是挂起当前线程的。意思很清楚了，如果判断当前线程不应该阻塞的话，不会挂起当前线程，而是会自旋的执行for loop，判断是否轮到当前线程获得锁了（`p == head`），然后尝试`tryAcquire`获取锁。

看看阻塞方法，它是调用unsafe，也就是JVM native方法实现的：

~~~ java
public static void park(Object blocker) {
    Thread t = Thread.currentThread();
    setBlocker(t, blocker);
    UNSAFE.park(false, 0L);
    setBlocker(t, null);
}
~~~

还有一个问题是：为什么在`acquireQueued`方法中还要执行一次`tryAcquire`方法？

其实，如果是当前线程的策略是阻塞的话，这个方法理应是在线程刚被唤醒的时候执行的，所以，`tryAcquire`这几句放在阻塞后面执行也是可以的。

#### 小结

小结一下acquire方法，一次acquire的过程是这样的：

1. 尝试调用`tryAcquire`方法，这个方法由子类实现，也就是说，怎样才算获得锁，获得锁之后要干什么，由子类自行判断。
2. 如果成功获得锁（`tryAcquire`方法返回true），那么之后的操作都跳过，线程开开心心的从`acquire`方法返回。
3. 否则为当前线程创建一个Node，加入到队列中。
4. 当前线程被挂起，直到被唤醒，再循环尝试获取锁资源，（每次只有一个节点能获取锁资源，也就是`head.next`节点）成功获取锁之后返回，否则继续阻塞。

### 分析 release 方法

再看看锁的释放操作：

~~~ java
public final boolean release(int arg) {
/*
 尝试释放锁如果失败，直接返回失败，如果成功并且head的状态不等于0就唤醒后面等待的节点
*/
    if (tryRelease(arg)) {
        Node h = head;
        if (h != null && h.waitStatus != 0)
            unparkSuccessor(h);
        return true;
    }
    return false;
}
~~~

`tryRelease`方法由子类实现，看看`ReentrantLock`里实现的版本：

~~~ java
protected final boolean tryRelease(int releases) {
// 释放后c的状态值
    int c = getState() - releases;
// 如果持有锁的线程不是当前线程，直接抛出异常
    if (Thread.currentThread() != getExclusiveOwnerThread())
        throw new IllegalMonitorStateException();
    boolean free = false;
    if (c == 0) {
// 如果c==0，说明所有持有锁都释放完了，其他线程可以请求获取锁
        free = true;
        setExclusiveOwnerThread(null);
    }
// 这里只会有一个线程执行到这，不存在竞争，因此不需要CAS
    setState(c);
    return free;
}
~~~

`tryRelease`做的事和`tryAcquire`一样，比较简单：修改`state`的值和置空`exclusiveOwnerThread`。

然后看看`unparkSuccessor`方法：

~~~ java
private void unparkSuccessor(Node node) {
    /*
     * If status is negative (i.e., possibly needing signal) try
     * to clear in anticipation of signalling.  It is OK if this
     * fails or if status is changed by waiting thread.
     */
    int ws = node.waitStatus;
    if (ws < 0)
/*
如果状态小于0，把状态改成0，0是空的状态，因为node这个节点的线程释放了锁后续不需要做任何
操作，不需要这个标志位，即便CAS修改失败了也没关系，其实这里如果只是对于锁来说根本不需要CAS，因为这个方法只会被释放锁的线程访问，只不过unparkSuccessor这个方法是AQS里的方法就必须考虑到多个线程同时访问的情况（可能共享锁或者信号量这种）
*/
        compareAndSetWaitStatus(node, ws, 0);

    /*
     * Thread to unpark is held in successor, which is normally
     * just the next node.  But if cancelled or apparently null,
     * traverse backwards from tail to find the actual
     * non-cancelled successor.
     */
    Node s = node.next;
// 这段代码的作用是如果下一个节点为空或者下一个节点的状态>0（目前大于0就是取消状态）
// 则从tail节点开始遍历找到离当前节点最近的且waitStatus<=0（即非取消状态）的节点并唤醒
    if (s == null || s.waitStatus > 0) {
        s = null;
        for (Node t = tail; t != null && t != node; t = t.prev)
            if (t.waitStatus <= 0)
                s = t;
    }
    if (s != null)
        LockSupport.unpark(s.thread);
}
~~~

`unparkSuccessor`会唤醒`head.next`的线程，这个线程被唤醒后，会执行上面的`acquireQueued`方法的代码：将这个线程set为head。

#### 小结

一次unlock的调用，总结来说流程如下：

1. 修改状态位
2. 唤醒排队的节点
3. 结合lock方法，被唤醒的节点会自动替换当前节点成为head

### 参考

- http://ifeve.com/abstractqueuedsynchronizer-use/
- http://www.blogjava.net/xylz/archive/2010/07/06/325390.html
- http://ifeve.com/java-special-troops-aqs/
- http://gee.cs.oswego.edu/dl/papers/aqs.pdf
- http://ifeve.com/juc-aqs-reentrantlock/
