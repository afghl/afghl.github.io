---
layout: post
title:  "深入Java Classloader（二） - Classloader工作机制"
date:   2016-10-26 18:54:00 +0800
---

在上一节中，已经说明了Java的类加载机制和Classloader的职责。实际上，类加载器虽然只用于实现类的加载动作，但它在Java程序里起到的作用远远不限于类加载阶段。每个Classloader，都有独立的类名称空间。所以，一个class文件被不同的classloader加载，这两个类是不相等的。JVM在判定两个class是否相同时，不仅要判断两个类名是否相同，而且要判断是否由同一个类加载器实例加载的。只有两者同时满足的情况下，JVM才认为这两个class是相同的。这样的做法是为了保障Java程序运行的安全性。

下面，来说说为了这个特性，类加载器是怎样实现的。

### Java默认提供的三个ClassLoader

Java 中的类加载器大致可以分成两类，一类是系统提供的，另外一类则是由 Java 应用开发人员编写的。程序的绝大部分的类都是由系统提供的类加载器加载的。系统提供的类加载器主要有下面三个：

- 引导类加载器（bootstrap class loader）：是Java类加载层次中最顶层的类加载器，这个类加载器会加载Java中的核心类库。它负责将存放在<JAVA_HOME>/lib目录中的，或者被 -Xbootclasspath指定的路径中的类加载到虚拟机内存中。

   bootstrap classloader是由C++写成的，所以在Java中无法获得它的引用（会返回Null）。

- 扩展类加载器（extensions class loader）：负责加载Java的扩展类库，默认加载<JAVA_HOME>/lib/ext/目下的所有jar。

- 系统类加载器（system class loader）：它根据 Java 应用的类路径（CLASSPATH）来加载 Java 类。一般来说，Java 应用的类都是由它来完成加载的。可以通过 ClassLoader.getSystemClassLoader()来获取它。

这三个类加载器的职责和等级示意图：

![Alt](/images/classloader(6).gif)

### 双亲委派模型

一个Java程序中最少会有以上的的三个类加载器。当然，用户（开发者）可以编写自定义的类加载器。在JVM中，所有的类加载器是有严格的等级制度的。也就是双亲委派模型，这个模型是用一个树状结构实现的：

![Alt](/images/classloader(7).jpg)

双亲委派模型是保证类加载机制安全的重要基础。它要求除了顶层的启动类加载器外，其他的类加载器都有自己的父类加载器。（这种父子关系使用组合实现的。）每个ClassLoader实例都有一个父类加载器的引用（不是继承的关系，是一个包含的关系），可以通过`getParent`方法获得父类实例的引用：

~~~ java
public class ClassLoaderTest {
    public static void main(String[] args) {
        ClassLoader loader = ClassLoaderTest.class.getClassLoader();
        while (loader != null) {
            System.out.println(loader.toString());
            loader = loader.getParent();
        }

        System.out.println("---");
        // 尝试访问核心库类的类加载器
        System.out.println(Integer.class.getClassLoader());
    }
}
~~~

得到的结果：

~~~ java
sun.misc.Launcher$AppClassLoader@4b1210ee
sun.misc.Launcher$ExtClassLoader@78308db1
---
null
~~~

如上文所说，我们不能访问bootstrap class loader，extensions class loader是我们的访问的最高层的classloader。

#### 工作过程

双亲委派模型的工作过程是：如果一个类加载器收到了类加载的请求，它首先不会自己去加载这个类，而是把这个请求委派给父类加载器去完成。每一个层次的类加载器都是如此，因此所有的类加载请求都会传递到最顶层的启动类加载器，只有当父类反馈自己无法完成这个请求（它搜索范围内没有找到所需的类）时，子类加载器才会尝试自己去加载。

使用双亲委派模型来组织类加载器之间的关系，有一个显而易见的好处：能够保证由这个模型加载的Java类具备带有优先级的层次关系。如rt.jar中的java.lang.Object，无论哪一个类加载器要加载这个类，最终都会委派给处于模型最顶端的启动类加载器进行加载，这样能保证Object类在各种类加载器环境中都是同一个类。如果不是使用双亲委派模型，而是由类加载器自行加载，而用户自己编写了一个java.lang.Object类，那系统中就会出现多个不同的Object类，Java类型体系中最基础的行为也就无法保证，应用程序也将会变成一片混乱。

#### 验证双亲委派模型

我们通过一段简单的代码，尝试伪造String类，并通过系统类加载器尝试加载，验证双亲委派模型。

首先构建一个伪造的String类：

~~~ java
package java.lang;

public class String {

    static {
        System.out.println("our fake String class is loaded!!");
    }

    @Override
    public String toString() {
        return "Foobar";
    }
}
~~~

在另一个类里，重新加载String里，看看是否能加载。

~~~ java
package com.utils;

public class ClassLoaderTest {
    public static void main(String[] args) throws ClassNotFoundException, IllegalAccessException, InstantiationException {
        ClassLoader loader = ClassLoaderTest.class.getClassLoader();

        Class<?> klass = loader.loadClass("java.lang.String");
        System.out.println(klass.getClassLoader());
        Object instance = klass.newInstance();
        System.out.println(String.class == klass);
    }
}
~~~

输出：

~~~ java
null
true
~~~

通过一个自定义类的`getClassLoader`方法获得系统类加载器，然后通过它来载入String类。

第一行说明：`klass.getClassLoader()`返回`NULL`，只有一种情况，就是`klass`的classloader是最顶层的引导类加载器，说明String类的类加载器没有改变。

第二行说明：比较`String.class`和`klass`，它们指向同一个对象，说明没有加载新的String类，而是返回了已经加载的核心库中的String类。

就这样，使用双亲委派模式，用户伪造的类永远无法被加载运行。保证了Java程序运行时的安全。

### 参考资源

- 《深入理解Java虚拟机》
- http://www.ibm.com/developerworks/cn/java/j-lo-classloader/
- http://blog.csdn.net/coslay/article/details/40709921
