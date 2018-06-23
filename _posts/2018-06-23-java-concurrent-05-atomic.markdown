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

看看atomic类是怎么实现的。

### 还有什么问题


### 参考

- http://ifeve.com/atomic-operation/
