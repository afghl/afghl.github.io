---
layout: post
title:  "学习Spring（一） - IoC原理"
date:   2017-06-11 21:01:00 +0800
---

系统的学习一下Spring原理，这篇首先说的是IoC，IoC是Spring框架最基本最核心的功能，其他任何功能都是基于IoC而存在的。

Spring里一直有一些故弄玄虚的术语，什么IoC、DI、AOP、AOP里又有各种Pointcut、Weave...我建议你不要纠结这些字眼，直接从这个角度思考：这项技术带给我们什么好处？

在这个角度说说IoC是什么：面向对象的思想里，项目代码是一堆对象的合作完成的，有时候这种合作会非常复杂，导致代码难以维护。IoC的作用是：使这些对象之间游离出来：它们只知道这些事：1. 自己要做什么；2. 它要和哪些其他对象合作。绝大部分的对象不知道自己是怎么产生的，如何产生的，也不知道和它合作的对象是怎么产生的，何时产生的。这些信息都交给Spring容器管理，这就是IoC。

### IoC该怎样实现？

先不说Spring，如果要我们自己写个这样的框架，该怎么写？可以这样想想：

- Bean和Bean之间的合作关系既然不写在代码中，那这些信息保存在哪里？
- 容器是什么？

回答第一个问题：IoC是将Bean之间的依赖关系告诉容器，让容器统一管理。而这个告诉的方式一定不是以代码的形式（如果是这样，就不需要这个框架了）。所以可能的方式是：一个文件，一个外部资源，一个URI。 **反正它一定存在于Java 运行时之外的**。

既然在内存之外，我们就需要将它以流的方式读入内存，然后对它做一定的封装，使我们可以读取这些内容的信息，然后处理。

第二个问题：容器当然是一个全局对象。而我们能通过`getBean`方法从它手中获得一个Bean，它应该有个map保存这些beans。第一步从外部读取的信息，最终处理的结果就是存放到这个map里。

### Spring中IoC容器的体系结构

Spring内部有非常复杂的接口和类层次设计。如果是学习的目的，没必要也很难完全理清楚里面的接口关系甚至是设计目的。这里我们只关注几个最重要的接口和它们的继承关系。

#### 容器

图

图中有两个设计主线：

- BeanFactory。只定义最简单的IoC容器的基本功能。如`getBean`。
- ApplicationContext。ApplicationContext继承BeanFactory，也就是它也是IoC容器，只是它的功能更丰富：它同时继承ResourcePatternResolver，MessageSource等接口，是高级容器。

#### Bean在容器中的抽象

SpringIOC容器管理了我们定义的各种Bean对象及其相互的关系，Bean对象在Spring实现中是以BeanDefinition来描述的，其继承体系如下：

#### Reader

上文说了，Bean加载的过程会有这一步：将Bean的信息以流的方式读入内存，然后对它做一定的封装，使我们可以读取这些内容的信息，然后处理。这个过程由Reader接口类实现：

#### Resource

Resource是Spring中对资源的抽象的一系列接口，最主要的实现类是：ClassPathResource。

#### 编程的方式使用这些接口

下面，我们用编程的方式使用上面的接口，看看IoC初始化的过程中，这些类需要怎么合作：

~~~ Java
ClassPathResource res = new ClassPathResource("bean.xml");
DefaultListableBeanFactory factory = new DefaultListableBeanFactory();
XmlBeanDefinitionReader reader = new XmlBeanDefinitionReader(factory);
reader.loadBeanDefinitions(res);
~~~

这样，就初始化好了容器变量`factory`，看看这四行代码，分别做了什么：

1. 创建IoC配置文件的抽象资源，这个抽象资源就包含了BeanDefinition的信息。
2. 创建一个BeanFactory。
3. 使用XmlBeanDefinitionReader这个读取器，来载入XML文件形式的`res`，通过一个回调配置给BeanFactory。
4. `reader`从`res`里读取配置信息。



### IoC容器加载过程

下面，我们看看XmlBeanFactory的实现代码，来看看IoC容器加载的全过程：

~~~ java
public class XmlBeanFactory extends DefaultListableBeanFactory {
	private final XmlBeanDefinitionReader reader = new XmlBeanDefinitionReader(this);

	public XmlBeanFactory(Resource resource) throws BeansException {
		this(resource, null);
	}

	public XmlBeanFactory(Resource resource, BeanFactory parentBeanFactory) throws BeansException {
		super(parentBeanFactory);
		this.reader.loadBeanDefinitions(resource);
	}
}
~~~





### 参考

- 《SPRING技术内幕》
- http://www.cnblogs.com/ITtangtang/p/3978349.html#a1
