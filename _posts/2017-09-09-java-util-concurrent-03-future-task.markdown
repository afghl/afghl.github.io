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

###

### 参考

- http://ifeve.com/futuretask-source/
