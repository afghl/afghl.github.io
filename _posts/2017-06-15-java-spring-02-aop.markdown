---
layout: post
title:  "学习Spring源码（二） AOP原理之动态代理"
date:   2017-06-15 22:04:00 +0800
---

想学习Spring AOP的时候，发现当中使用了动态代理的知识，所以首先先把这些前置知识学了吧。

### 怎么用

用起来的代码非常简单，一个完整的动态代理例子：

Animal接口：

~~~ java
interface Animal {
    public void eat();
}
~~~

实现Animal接口：

~~~ java
class Dog implements Animal {
    @Override
    public void eat() {
        System.out.println("小狗吃东西");
    }
}

class Cat implements Animal {
    @Override
    public void eat() {
        System.out.println("小猫吃东西");
    }
}
~~~

Animal接口的动态代理：

~~~ java
class DogProxy implements InvocationHandler {
    private Object animal;

    public DogProxy(Object animal) {
        this.animal = animal;
    }

    public Animal getProxiedAnimal() {
        return (Animal) Proxy.newProxyInstance(
                getClass().getClassLoader(),
                animal.getClass().getInterfaces(),
                this);
    }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        System.out.println("吃前吠两声");
        Object result = method.invoke(animal, args);
        System.out.println("吃后吠两声");
        return result;
    }
}
~~~

测试：

~~~ java
public static void main(String[] args) {
    Animal dog = new DogProxy(new Dog()).getProxiedAnimal();
    Animal cat = new DogProxy(new Cat()).getProxiedAnimal();
    dog.eat();
    cat.eat();
}
~~~

输出：

~~~ java
吃前吠两声
小狗吃东西
吃后吠两声
吃前吠两声
小猫吃东西
吃后吠两声
~~~

我们可以问问：为什么叫动态代理呢？很简单，因为代理对象的具体行为，在编译期不能确定，要到运行期才能确定。

### InvocationHandler & Proxy

java API为我们提供一个接口和一个类实现动态代理的相关功能：InvocationHandler和Proxy。

1. InvocationHandler

每一个动态代理类都必须要实现InvocationHandler这个接口，并且每个代理类的实例都关联到了一个handler，当我们通过代理对象调用一个方法的时候，这个方法的调用就会被转发为由InvocationHandler这个接口的 invoke 方法来进行调用。看看InvocationHandler的的java doc定义：

~~~
InvocationHandler is the interface implemented by the invocation handler of a proxy instance.

Each proxy instance has an associated invocation handler. When a method is invoked on a proxy instance, the method invocation is encoded and dispatched to the invoke method of its invocation handler.
~~~

InvocationHandler只有一个`invoke`接口，当我们通过代理对象调用一个方法的时候，这个方法的调用就会被转发为由InvocationHandler这个接口的 invoke 方法来进行调用：

~~~ java
Object invoke(Object proxy, Method method, Object[] args) throws Throwable
~~~

分别看看三个参数：

- proxy：指代我们所代理的那个真实对象
- method：指代的是我们所要调用真实对象的某个方法的Method对象
- args：指代的是调用真实对象某个方法时接受的参数

注意在方法实现时，不能：

~~~ java
method.invoke(proxy, args);
~~~

这会陷入递归死循环而导致stackoverflow。具体怎么做，可以看上面的代码。

2. Proxy

Proxy是一个工具类，它提供一系列的静态方法来创建代理对象：

~~~
Proxy provides static methods for creating dynamic proxy classes and instances, and it is also the superclass of all dynamic proxy classes created by those methods.
~~~







### 参考

- http://blog.csdn.net/zhangerqing/article/details/42504281/
- http://www.cnblogs.com/flyoung2008/archive/2013/08/11/3251148.html
