---
layout: post
title:  "从JMM层面说说Java并发（二） - volatile"
date:   2016-12-06 18:26:00 +0800
---

volatile关键字是用于线程间通讯的特殊字段。它保证一个线程对一个volatile变量的读，总是能看到（任意线程）对这个volatile变量最后的写入。也就是保证变量的可见性。另一点更重要的是，volatile读和volatile写之间有 **happens-before关系**。

### JMM层面上volatile的语义

volatile关键字在JMM层面的内存语义是两点：

- 保证可见性（改变对变量的读 / 写的内存语义）
- 禁止重排序优化

其中，后者是前者的实现、原因。下面简单说说它们实现：

#### 保证可见性

在JMM内存模型里，一个声明为volatile的变量，它会直接读写主内存，而不经过工作内存：

- 当写一个volatile变量时，JMM会把该线程对应的本地内存中的共享变量刷新到主内存。
- 当读一个volatile变量时，JMM会把该线程对应的本地内存置为无效。线程接下来将从主内存中读取共享变量。

这两点便保证了volatile变量在线程间的可见性：在读线程B读一个volatile变量后，写线程A在写这个volatile变量之前所有可见的共享变量的值都将立即变得对读线程B可见。

#### 禁止重排序

为了实现volatile内存语义，JMM会分别限制编译器重排序和处理器重排序。JMM是通过插入JMM内存屏障限制重排序的：

- 在每个volatile写操作的前面插入一个StoreStore屏障。
- 在每个volatile写操作的后面插入一个StoreLoad屏障。
- 在每个volatile读操作的后面插入一个LoadLoad屏障。
- 在每个volatile读操作的后面插入一个LoadStore屏障。

volatile写插入内存屏障后生成的指令序列示意图：

![Alt](/images/4.png)

这些规则确保了两件事：

- 确保volatile写之前的操作不会被编译器重排序到volatile写之后。
- 确保volatile读之后的操作不会被编译器重排序到volatile读之前。

JMM做的这些限制确保了volatile读和volatile写之间是有happens-before关系的。

### 利用volatile变量的happens-before规则

请看下面的代码：

~~~ java
class VolatileExample {
    int a = 0;
    volatile boolean flag = false;

    public void writer() {
        a = 1;                   //1
        flag = true;               //2
    }

    public void reader() {
        if (flag) {                //3
            int i =  a;           //4
            ……
        }
    }
}
~~~

看程序的意思，很显然，我们希望保证在跨线程执行`reader`方法时，`i`能读取到`a`为1的值。也就是1操作happens-before 4操作。

这里，如果没有足够的同步机制，是不可能做到的。而我们volatile关键字带来的同步来轻松实现，可以想想这四个操作直接的happens-before关系：

1. 根据程序次序规则，1 happens before 2; 3 happens before 4。
2. 根据volatile规则，2 happens before 3。
3. 根据happens before 的传递性规则，1 happens before 4。

这样，我们保证了 1 happens before 4。

### 参考

- 《Java并发编程实战》
- http://ifeve.com/java-memory-model-4/
- http://ifeve.com/syn-jmm-volatile/
