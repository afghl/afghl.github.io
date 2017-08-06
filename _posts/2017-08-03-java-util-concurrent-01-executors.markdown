---
layout: post
title:  "学习juc包 - 线程池"
date:   2017-07-30 15:25:00 +0800
---

java.util.concurrent包提供了多线程编程相关的工具接口，主要有：`Executor`、`ExecutorService`、`Future`等。

使用这些（线程池）接口的好处有几点：

- 性能。节省了创建和销毁线程的开销。
- 壮健。线程是稀缺资源，使用JDK本身提供的线程池能有效预防各种意外情况。



### 参考

- http://www.blogjava.net/xylz/archive/2010/07/08/325587.html
- https://docs.oracle.com/javase/7/docs/api/java/util/concurrent/ThreadPoolExecutor.html
- http://ifeve.com/java-threadpool/
