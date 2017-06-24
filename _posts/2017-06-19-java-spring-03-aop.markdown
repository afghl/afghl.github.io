---
layout: post
title:  "学习Spring源码（三） AOP原理之实现篇"
date:   2017-06-19 22:04:00 +0800
---

[上一篇](/2017/06/15/java-spring-02-aop.html) 已经说了Java动态代理的相关实现和原理，Spring AOP的核心技术是动态代理，但是Spring里的AOP模块比这复杂得多，包括前置通知，返回通知等一系列实现，这一篇，有了动态代理的基础，我们来看看Spring AOP模块是怎么实现的。

### 编程式使用AOP

想要知道Spring AOP需要用到什么类，我们先来编程式的用用AOP：

定义一个Bean和Advisor:

~~~ java
public class MyBean {
    public void say() {
        System.out.println("say");
    }
}

public class MyAdvisor implements MethodBeforeAdvice {

    @Override
    public void before(Method method, Object[] args, Object target)
            throws Throwable {
        System.out.println("HijackBeforeMethod : Before method hijacked!");
    }
}
~~~

配置xml：

~~~ xml
<bean id="myBean" class="com.afghl.testaop.MyBean"></bean>
<bean id="myAdvisor" class="com.afghl.testaop.MyAdvisor"/>
<bean id="testAOP" class="org.springframework.aop.framework.ProxyFactoryBean">
    <property name="target" ref="myBean"/>
    <property name="interceptorNames">
        <list>
            <value>myAdvisor</value>
        </list>
    </property>
</bean>
~~~

测试：

~~~ java
public static void main(String[] args) {
    init();
    MyBean test = SpringContext.getBean("testAOP");
    test.say();
}
~~~

输出：

~~~ java
HijackBeforeMethod : Before method hijacked!
say
~~~

### ProxyFactoryBean

由上面的代码可以看到，Spring中`ProxyFactoryBean`这个类和它的继承体系是实现AOP的核心。我们使用它的姿势是：

- 告诉它想要代理的对象，以reference的形式传给它。
- 告诉它advisors的id，以字符串的形式传给它。

最后，他返回的是一个代理后的对象。

下面，我们来看看它的内部实现，看看到底发生了什么事。

### Spring中的FactoryBean

`ProxyFactoryBean`继承自`FactoryBean`，Spring容器对于FactoryBean及它的子类，有特殊处理：在Spring调用getBean的时候，如果Bean是`FactoryBean`的实例，不会直接返回Bean，而是会调用Bean的`getObject`方法，这个方法是`FactoryBean`定义的抽象方法：

~~~ java
public interface FactoryBean<T> {
  T getObject() throws Exception;

  Class<?> getObjectType();

  boolean isSingleton();
}
~~~

这里很显然用的是抽象工厂模式，FactoryBean允许传入任何对象，而getObject返回对这个对象加工后的成品对象，FactoryBean可以有不同实现，不同实现间通过重写`getObject`方法，可对这个对象有不同的定制。

而`ProxyFactoryBean`是它的一个实现。下面，我们来看看它是怎样重写`getObject`方法的。

### ProxyFactoryBean的内部实现

~~~ java
public Object getObject() throws BeansException {
  initializeAdvisorChain();
  if (isSingleton()) {
    return getSingletonInstance();
  }
  else {
    if (this.targetName == null) {
      logger.warn("Using non-singleton proxies with singleton targets is often undesirable. " +
          "Enable prototype proxies by setting the 'targetName' property.");
    }
    return newPrototypeInstance();
  }
}
~~~

看看`initializeAdvisorChain`：

~~~ java
  private synchronized void initializeAdvisorChain() throws AopConfigException, BeansException {
		if (this.advisorChainInitialized) {
			return;
		}

		if (!ObjectUtils.isEmpty(this.interceptorNames)) {
			if (this.beanFactory == null) {
				throw new IllegalStateException("No BeanFactory available anymore (probably due to serialization) " +
						"- cannot resolve interceptor names " + Arrays.asList(this.interceptorNames));
			}

			// Globals can't be last unless we specified a targetSource using the property...
			if (this.interceptorNames[this.interceptorNames.length - 1].endsWith(GLOBAL_SUFFIX) &&
					this.targetName == null && this.targetSource == EMPTY_TARGET_SOURCE) {
				throw new AopConfigException("Target required after globals");
			}

			// Materialize interceptor chain from bean names.
			for (String name : this.interceptorNames) {
				if (logger.isTraceEnabled()) {
					logger.trace("Configuring advisor or advice '" + name + "'");
				}

				if (name.endsWith(GLOBAL_SUFFIX)) {
					if (!(this.beanFactory instanceof ListableBeanFactory)) {
						throw new AopConfigException(
								"Can only use global advisors or interceptors with a ListableBeanFactory");
					}
					addGlobalAdvisor((ListableBeanFactory) this.beanFactory,
							name.substring(0, name.length() - GLOBAL_SUFFIX.length()));
				}

				else {
					// If we get here, we need to add a named interceptor.
					// We must check if it's a singleton or prototype.
					Object advice;
					if (this.singleton || this.beanFactory.isSingleton(name)) {
						// Add the real Advisor/Advice to the chain.
						advice = this.beanFactory.getBean(name);
					}
					else {
						// It's a prototype Advice or Advisor: replace with a prototype.
						// Avoid unnecessary creation of prototype bean just for advisor chain initialization.
						advice = new PrototypePlaceholderAdvisor(name);
					}
					addAdvisorOnChainCreation(advice, name);
				}
			}
		}

		this.advisorChainInitialized = true;
	}
~~~

### 参考

- 《SPRING技术内幕》
