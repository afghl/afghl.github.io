---
layout: post
title:  "学习Spring源码（一） - IoC原理"
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

Spring中对于ApplicationContext的一部分实现是，它会持有一个BeanFactory作为私有变量来帮它实现这些接口。如：

~~~ Java
public abstract class AbstractRefreshableApplicationContext extends AbstractApplicationContext {

	private Boolean allowBeanDefinitionOverriding;

	private Boolean allowCircularReferences;

	/** Bean factory for this context */
	private DefaultListableBeanFactory beanFactory;
}
~~~

那么实际上ApplicationContext的一部分操作是内部的beanFactory实现的。

#### Bean在容器中的抽象

SpringIOC容器管理了我们定义的各种Bean对象及其相互的关系，Bean对象在Spring实现中是以BeanDefinition来描述的，其继承体系如下，BeanDefinition是什么意思？就是要创建Bean时的一种药方，该创建成什么样，都由BeanDefinition记录：

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

上面我们用编程的方式说明了Spring加载IoC容器的步骤和这些重要的接口是怎样相互协作的。下面我们来看看在生产环境中，是怎么初始化IoC容器的，我们用常用的ApplicationContext实现：FileSystemXmlApplicationContext说明：

~~~ Java
public class FileSystemXmlApplicationContext extends AbstractXmlApplicationContext {
    public FileSystemXmlApplicationContext(String[] configLocations, boolean refresh, ApplicationContext parent) throws BeansException {

        super(parent);
        setConfigLocations(configLocations);
        if (refresh) {
            refresh();
        }
    }
}
~~~

当我们new一个FileSystemXmlApplicationContext的时候，主要调用的是`refresh`方法来进行容器的初始化，看看里面的实现：

~~~ java
public void refresh() throws BeansException, IllegalStateException {  
       synchronized (this.startupShutdownMonitor) {  
           //调用容器准备刷新的方法，获取容器的当时时间，同时给容器设置同步标识  
           prepareRefresh();  
           //告诉子类启动refreshBeanFactory()方法，Bean定义资源文件的载入从  
          //子类的refreshBeanFactory()方法启动  
           ConfigurableListableBeanFactory beanFactory = obtainFreshBeanFactory();  
           //为BeanFactory配置容器特性，例如类加载器、事件处理器等  
           prepareBeanFactory(beanFactory);  
           try {  
               //为容器的某些子类指定特殊的BeanPost事件处理器  
               postProcessBeanFactory(beanFactory);  
               //调用所有注册的BeanFactoryPostProcessor的Bean  
               invokeBeanFactoryPostProcessors(beanFactory);  
               //为BeanFactory注册BeanPost事件处理器.  
               //BeanPostProcessor是Bean后置处理器，用于监听容器触发的事件  
               registerBeanPostProcessors(beanFactory);  
               //初始化信息源，和国际化相关.  
               initMessageSource();  
               //初始化容器事件传播器.  
               initApplicationEventMulticaster();  
               //调用子类的某些特殊Bean初始化方法  
               onRefresh();  
               //为事件传播器注册事件监听器.  
               registerListeners();  
               //初始化所有剩余的单态Bean.  
               finishBeanFactoryInitialization(beanFactory);  
               //初始化容器的生命周期事件处理器，并发布容器的生命周期事件  
               finishRefresh();  
           }  
           catch (BeansException ex) {  
               //销毁以创建的单态Bean  
               destroyBeans();  
               //取消refresh操作，重置容器的同步标识.  
               cancelRefresh(ex);  
               throw ex;  
           }  
       }  
   }
}
~~~

注释来自[这边文章](http://www.cnblogs.com/ITtangtang/p/3978349.html)。

- `obtainFreshBeanFactory`方法，是最重要的一步，上文说过，`ApplicationContext`实际会持有一个`beanFactory`，把容器的很多基本操作代理到这个field完成。这个方法做的事就是把`beanFactory`初始化好，拿出来，然后放到下面的方法里进行初始化。注册容器的信息源和生命周期事件。以FileSystemXmlApplicationContext为例，这里的初始化包括：
   - 创建个Reader，将Class Path里的xml配置读进内存。
   - 从配置里读取BeanDefinition。
   - 将BeanDefinition注册到`beanFactory`中的`beanDefinitionMap`中。
- `prepareBeanFactory`方法，添加一些 Spring 本身需要的一些工具类。该方法主要分成四步，如下：
   1. 第一步，设置类加载器；
   2. 第二步，设置属性编辑器注册类，用来注册相关的属性编辑器。
   3. 第三步：设置内置的BeanPostProcessor：ApplicationContextAwareProcessor。该BeanPostProcessor的作用是，为实现特殊接口的bean，注入容器类（例如为实现ApplicationContextAware接口的类，注入ApplicationContext对象实例）。
   4. 第四步：调用ignoreDependencyInterface，设置忽略自动注入的接口（因为这些接口已经通过ApplicationContextAwareProcessor注入了）。
- `postProcessBeanFactory`：hook method。
- `invokeBeanFactoryPostProcessors`：获取所有实现 BeanFactoryPostProcessor 接口的bean，然后按不同的优先级顺序，依次执行BeanFactoryPostProcessor的 postProcessBeanFactory 方法。Spring会暴露一个`BeanFactoryPostProcessor`接口，使用户可以对初始化过程中的`beanFactory`进行定制，这个定制是在这个方法中执行的。
- `registerBeanPostProcessors`：顾名思义：注册`BeanFactoryPostProcessor`。通过beanFactory.getBeanNamesForType(BeanPostProcessor.class, true, false)，获取spring配置文件中所有实现BeanPostProcessor接口的bean。将bean放入AbstractBeanFactory类的beanPostProcessors列表中，根据bean实现的不同排序接口，进行分组、排序，然后逐一注册。
- `initApplicationEventMulticaster`方法：这个方法的主要功能是为spring容器初始化ApplicationEventMulticaster，功能也相对简单，如果spring配置文件没有定义applicationEventMulticaster，则使用默认的。默认的ApplicationEventMulticaster实现类是SimpleApplicationEventMulticaster。
- `onRefresh`：hook。
- `finishBeanFactoryInitialization`：也是非常重要的一步。在这一步中会调用`beanFactory.preInstantiateSingletons()`，Spring容器是在这步初始化Bean的。下详。

### IoC容器的依赖注入

上文的refresh方法主要是在IoC容器中建立BeanDefinition映射。这个过程是在getBean接口实现的。详细的技术可以在《SPRING技术内幕》里看到，这里不再展开说了。

### 参考

- 《SPRING技术内幕》
- http://www.cnblogs.com/ITtangtang/p/3978349.html#a1
