---
title:  "学习juc包 - atomic包"
date:   2018-06-23 15:44:00 +0800
tags: [java,concurrency,juc,atomic]
---

atomic包是juc下的其中一个包，主要是封装常用变量，方便使用者可以原子操作。

### Atomic可以解决什么问题？

一个场景的并发不安全的场景：

~~~ java
public class AtomicTest {
    public static void main(String[] args) throws InterruptedException {
        ExecutorService pool = Executors.newFixedThreadPool(30);
        Counter c = getCounter();

        // increase it 100000 times;
        int times = 100000;
        while (times-- > 0) {
            pool.execute(c::incr);
        }

        pool.shutdown();
        pool.awaitTermination(20, TimeUnit.SECONDS);

        System.out.println(c.get() == times); // false
    }

    private static Counter getCounter() {
        return new Counter() {
            int c = 0;
            @Override
            public void incr() {
                c = c + 1;
            }

            @Override
            public int get() {
                return c;
            }
        };
    }
}

interface Counter {
    void incr(); int get();
}
~~~

最终`c.get()`的值有可能有各种值，原因不用多说，因为`c = c + 1;`不是原子操作，这里面有三个独立的操作：或者变量当前值，为该值+1/-1，然后写回新的值。所以`incr`方法并不是线性安全的。

解决方法之一是使用`AtomicInteger`：

~~~ java
private static Counter getCounter() {
    return new Counter() {
        AtomicInteger i = new AtomicInteger(0);
        @Override
        public void incr() {
            i.incrementAndGet();
        }

        @Override
        public int get() {
            return i.get();
        }
    };
}
~~~

这样`incr`是线程安全的方法。

### Atomic类的实现原理

看看atomic类是怎么实现的。以`AtomicInteger`为例，最主要的两个变量是：`unsafe`、`value`。而所有原子方法都是代理到`unsafe`实现的：

~~~ java
public final int incrementAndGet() {
    return unsafe.getAndAddInt(this, valueOffset, 1) + 1;
}
~~~

而`unsafe`的内部实现全是native方法，它是通过cpu的提供原语实现的。unsafe的cas操作在硬件（CPU）层级就是原子的。

OK，那CPU是怎么实现原子操作的？

CPU是：**基于对缓存加锁** 或 **总线加锁** 的方式来实现多处理器之间的原子操作。

- 对缓存加锁：意思是当一个处理器读取一个字节时，其他处理器不能访问这个字节的内存地址。
- 总线加锁：所谓总线锁就是使用处理器提供的一个LOCK＃信号，当一个处理器在总线上输出此信号时，其他处理器的请求将被阻塞住,那么该处理器可以独占使用共享内存。

### 还有什么问题

Atomic类还有什么问题没有解决？

- **ABA问题**。因为CAS需要在操作值的时候检查下值有没有发生变化，如果没有发生变化则更新，但是如果一个值原来是A，变成了B，又变成了A，那么使用CAS进行检查时会发现它的值没有发生变化，但是实际上却变化了。怎样解决？思路就是使用版本号。在变量前面追加上版本号，每次变量更新的时候把版本号加一，那么A－B－A 就会变成1A-2B－3A。

- **循环时间长开销大**。自旋CAS如果长时间不成功，会给CPU带来非常大的执行开销。

- **只能保证一个共享变量的原子操作**。对多个共享变量操作时，循环CAS就无法保证操作的原子性，这个时候就必须加锁了。

### 参考

- http://ifeve.com/atomic-operation/
- http://www.docjar.com/html/api/sun/misc/Unsafe.java.html
