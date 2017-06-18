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

Proxy类提供多种方法，这里我们只看`newProxyInstance`方法：

~~~ java
/**
     * Returns an instance of a proxy class for the specified interfaces
     * that dispatches method invocations to the specified invocation
     * handler.
     *
     * <p>{@code Proxy.newProxyInstance} throws
     * {@code IllegalArgumentException} for the same reasons that
     * {@code Proxy.getProxyClass} does.
     *
     */
    @CallerSensitive
    public static Object newProxyInstance(ClassLoader loader,
                                          Class<?>[] interfaces,
                                          InvocationHandler h)
        throws IllegalArgumentException
~~~

同样，它接受3个参数：

- loader：一个ClassLoader对象，定义了由哪个ClassLoader对象来对生成的代理对象进行加载（为什么生成一个对象要用ClassLoader加载，下文你将看到，生成这个代理对象之前需要先生成它的类，而生成类当然需要类加载器。）
- interfaces：表示这个对象可以实现什么接口，一般选择编译时它的类已经实现的接口，也就是`getClass().getInterfaces()`。
- h：使用哪个哪个动态代理对象去代理原对象。

如果我们把这个方法看成一个黑箱子，这个方法就是干了这件事：

我们需要生成一个对象，这个对象没有任何现成的类可以new出来，所以我们求助于Proxy类的`newProxyInstance`方法，我们告诉它，这个对象应该由什么ClassLoader加载，它可以实现什么接口，还要告诉它，这个对象的方法由一个动态代理（最后一个参数）代理。方法返回的就是我们想要的对象。

值得注意的是，第二个参数传的是一个接口数组，返回的代理对象就自动实现了全部接口。也就是说，返回的代理对象可以被强制类型转换为这组接口中的任意一个。

### newProxyInstance内部实现

Proxy类用起来很简单，接下来，我们看看它的内部实现吧。

~~~ java
@CallerSensitive
    public static Object newProxyInstance(ClassLoader loader,
                                          Class<?>[] interfaces,
                                          InvocationHandler h)
        throws IllegalArgumentException {

        // omitted ...
        Class<?> cl = getProxyClass0(loader, intfs);

        /*
         * Invoke its constructor with the designated invocation handler.
         */
        try {
            if (sm != null) {
                checkNewProxyPermission(Reflection.getCallerClass(), cl);
            }

            final Constructor<?> cons = cl.getConstructor(constructorParams);
            final InvocationHandler ih = h;
            if (!Modifier.isPublic(cl.getModifiers())) {
                AccessController.doPrivileged(new PrivilegedAction<Void>() {
                    public Void run() {
                        cons.setAccessible(true);
                        return null;
                    }
                });
            }
            return cons.newInstance(new Object[]{h});
        } catch (IllegalAccessException|InstantiationException e) {
            // omitted ...
        }
    }
~~~

可以看到：

~~~ java
Class<?> cl = getProxyClass0(loader, intfs);
~~~

一行，是在运行时动态生成代理类。然后通过java relection api通过刚才创建的类`cl`动态new了一个对象。进入`getProxyClass0`方法内部，跟踪调用栈，发现最终动态生成代理类的方法是Proxy类里的一个内部类：ProxyClassFactory类的apply方法：

~~~ java
@Override
public Class<?> apply(ClassLoader loader, Class<?>[] interfaces) {

    Map<Class<?>, Boolean> interfaceSet = new IdentityHashMap<>(interfaces.length);
    for (Class<?> intf : interfaces) {
        /*
         * Verify that the class loader resolves the name of this
         * interface to the same Class object.
         */
        Class<?> interfaceClass = null;
        try {
            interfaceClass = Class.forName(intf.getName(), false, loader);
        } catch (ClassNotFoundException e) {
        }
        if (interfaceClass != intf) {
            throw new IllegalArgumentException(
                intf + " is not visible from class loader");
        }
        /*
         * Verify that the Class object actually represents an
         * interface.
         */
        if (!interfaceClass.isInterface()) {
            throw new IllegalArgumentException(
                interfaceClass.getName() + " is not an interface");
        }
        /*
         * Verify that this interface is not a duplicate.
         */
        if (interfaceSet.put(interfaceClass, Boolean.TRUE) != null) {
            throw new IllegalArgumentException(
                "repeated interface: " + interfaceClass.getName());
        }
    }

    String proxyPkg = null;     // package to define proxy class in
    int accessFlags = Modifier.PUBLIC | Modifier.FINAL;

    /*
     * Record the package of a non-public proxy interface so that the
     * proxy class will be defined in the same package.  Verify that
     * all non-public proxy interfaces are in the same package.
     */
    for (Class<?> intf : interfaces) {
        int flags = intf.getModifiers();
        if (!Modifier.isPublic(flags)) {
            accessFlags = Modifier.FINAL;
            String name = intf.getName();
            int n = name.lastIndexOf('.');
            String pkg = ((n == -1) ? "" : name.substring(0, n + 1));
            if (proxyPkg == null) {
                proxyPkg = pkg;
            } else if (!pkg.equals(proxyPkg)) {
                throw new IllegalArgumentException(
                    "non-public interfaces from different packages");
            }
        }
    }

    if (proxyPkg == null) {
        // if no non-public proxy interfaces, use com.sun.proxy package
        proxyPkg = ReflectUtil.PROXY_PACKAGE + ".";
    }

    /*
     * Choose a name for the proxy class to generate.
     */
    long num = nextUniqueNumber.getAndIncrement();
    String proxyName = proxyPkg + proxyClassNamePrefix + num;

    /*
     * Generate the specified proxy class.
     */
    byte[] proxyClassFile = ProxyGenerator.generateProxyClass(
        proxyName, interfaces, accessFlags);
    try {
        return defineClass0(loader, proxyName,
                            proxyClassFile, 0, proxyClassFile.length);
    } catch (ClassFormatError e) {
        /*
         * A ClassFormatError here means that (barring bugs in the
         * proxy class generation code) there was some other
         * invalid aspect of the arguments supplied to the proxy
         * class creation (such as virtual machine limitations
         * exceeded).
         */
        throw new IllegalArgumentException(e.toString());
    }
}
~~~

看代码可以看到，这个方法对参数做了一系列的校验，然后通过调用`ProxyGenerator.generateProxyClass`（native方法）生成字节码，最后调用`defineClass0`生成这个代理类（native方法）。

### 总结

Proxy.newProxyInstance的整个过程一目了然了：

1. 是用native方法动态生成一个类的字节码；
2. 然后用ClassLoader把它加载到jvm；
3. 然后用过反射new出这个类的实例。

实际上，第一步生成的类都会继承Proxy，而我们自定义的InvocationHandler会传进去作为实例变量。关于这个类，我们还可以进一步验证，反编译一下。在这里不再深挖了。

### 参考

- http://blog.csdn.net/zhangerqing/article/details/42504281/
- http://rejoy.iteye.com/blog/1627405
- http://www.cnblogs.com/flyoung2008/archive/2013/08/11/3251148.html
- http://www.2cto.com/kf/201608/533663.html
