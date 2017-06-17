---
layout: post
title:  "学习Spring源码（二） - AOP原理之动态代理"
date:   2017-06-15 22:04:00 +0800
---

~~~ java
package me.ele.pcd.dom.core.helper;


import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;

class Student {
    public void eat() {
        System.out.println("eat");
    }
}

class StudentProxy implements InvocationHandler {
    private Object student;

    public StudentProxy(Object student) {
        super();
        this.student = student;
    }

    public Student getProxy() {
        Object o = Proxy.newProxyInstance(Thread.currentThread()
                        .getContextClassLoader(), student.getClass().getInterfaces(),
                this);
        System.out.println(o.getClass().getName());
        return  (Student) o;
    }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        System.out.println("before");
        Object result = method.invoke(student, args);
        System.out.println("after");
        return result;
    }
}

public class Test {
    public static void main(String[] args) {
        Student s = new Student();
        StudentProxy invocationHandler = new StudentProxy(s);

        Student proxy = invocationHandler.getProxy();
        proxy.eat();
    }
}
~~~

### 参考

- http://blog.csdn.net/zhangerqing/article/details/42504281/
- http://www.cnblogs.com/flyoung2008/archive/2013/08/11/3251148.html
