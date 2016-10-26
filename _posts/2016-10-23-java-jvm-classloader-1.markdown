---
layout: post
title:  "深入Java Classloader（一） - JVM模型和类加载机制"
date:   2016-10-23 11:54:00 +0800
---

Classloader是JVM模型的一部分，JVM通过Classloader动态加载class文件到内存中使用的。

所以要给出Classloader的定义十分简单，它就是Java中的一系列类，这些类的职责就是动态加载其他类。

但是，了解这样的定义意义不大，我们希望明白的是这一套机制是解决什么问题的。要了解这个问题，先从C说起。

### 从C说起（C语言的编译和连接过程）

假设我有三个.c文件，整个编译过程是这样的：

![Alt](/images/classloader(1).png)

整个过程会有这样4个步骤：

- 预处理(Preprocessing)：静态替换，处理预编译指令。
- 编译(Compilation)：预处理完的文件进行一系列的词法分析，语法分析，语义分析及优化后生成相应的汇编代码。
- 汇编(Assembly)：汇编代码转变成机器可以执行的命令，每一个汇编语句几乎都对应一条机器指令。
- 链接(Linking)：通过调用链接器ld来链接程序运行需要的一大堆目标文件，以及所依赖的其它库文件，最后生成可执行文件。

最终得到的是一个.exe(windows)或.out(linux)文件。

在运行的时候，是将整个输出文件（a.exe）读到内存里运行的：

![Alt](/images/classloader(2).png)

可见，经过编译和汇编步骤，会生成直接给CPU执行的机器指令。机器码顾名思义就是0101的二进制代码。所以，执行C语言的时候，实际上是运行最底层的语言，这样的代码高效，却和芯片，操作系统紧密耦合在一起了。

### Write Once, Run~~Error~~ Anywhere

Java在刚刚诞生的时候提出一个非常著名的宣传口号“Write Once, Run Anywhere”。它希望程序员写的代码能在不同的平台/硬件上执行，“与平台无关”。

平台无关性的两个基石是：

1. 字节码存储格式。Java编译器会将.java文件编译为.class文件，.class文件就是能被JVM执行的代码，它包含Java虚拟机的指令集，符号表和其他辅助信息。
2. Java虚拟机（JVM）。顾名思义它是加在应用层的一层抽象。从上层看，它就是CPU：加载并运行字节码代码，屏蔽了操作系统和硬件细节，对下，它将字节码翻译为CPU能执行的机器指令。

了解bytecode和JVM后，再来看看JAVA的编译，执行过程。

首先，是将.java文件编译成.class文件：

![Alt](/images/classloader(3).png)

当JVM运行时，再按需加载这些.class到内存中：

![Alt](/images/classloader(4).png)

可以看到，Java和C在编译过程中的一个差异是：在Java语言里面，类型的加载，连接，和初始化是在运行期间完成的。

结合整个JVM的结构模型，能更清楚的看到classloader的位置和机制：

![Alt](/images/classloader(5).png)

有了这些背景知识，现在我们能清楚地给出相关定义：

- JVM在运行期间把.class文件加载到内存，并对数据进行校验，转换，和初始化的过程就是类加载机制。
- classloader就是实现这套机制的一系列类。

下一篇，说说类加载的工作机制。

### 参考资源
  - JVM (Java Virtual Machine) Introduction (https://www.youtube.com/watch?v=G1ubVOl9IBw)
