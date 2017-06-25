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

#### `initializeAdvisorChain`

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

注意`advice = this.beanFactory.getBean(name);`这一句，我们之前传入了一个String数组，代表Advisors的id。ProxyFactoryBean会根据这些id询问容器拿到具体的Advisor的Bean。然后调用`addAdvisorOnChainCreation`把Advisor加入到ProxyFactoryBean内部维护的一个Advisor链表里。

`initializeAdvisorChain`方法执行完之后，这个Advisor链表也就被初始化完成。

#### `getSingletonInstance`

初始化完成之后，就会调用`getSingletonInstance`方法，获得代理过后的Bean。看看这个方法的实现：

~~~ java
private synchronized Object getSingletonInstance() {
	if (this.singletonInstance == null) {
		this.targetSource = freshTargetSource();
		if (this.autodetectInterfaces && getProxiedInterfaces().length == 0 && !isProxyTargetClass()) {
			// Rely on AOP infrastructure to tell us what interfaces to proxy.
			Class<?> targetClass = getTargetClass();
			if (targetClass == null) {
				throw new FactoryBeanNotInitializedException("Cannot determine target class for proxy");
			}
			setInterfaces(ClassUtils.getAllInterfacesForClass(targetClass, this.proxyClassLoader));
		}
		// Initialize the shared singleton instance.
		super.setFrozen(this.freezeProxy);
		this.singletonInstance = getProxy(createAopProxy());
	}
	return this.singletonInstance;
}
~~~

关键在`this.singletonInstance = getProxy(createAopProxy());`一句。这里将创建一个`JdkDynamicAopProxy`的实例，然后调用它的的`getProxy`方法：

~~~ java
protected Object getProxy(AopProxy aopProxy) {
  return aopProxy.getProxy(this.proxyClassLoader);
}
~~~

整个Aop模块生成代理对象的玄机就在这个`getProxy`方法，下面，我们先说说`JdkDynamicAopProxy`的类继承层次，然后看看这个`getProxy`方法做了什么。

#### `AopProxy`

事实上，`getProxy`方法是来自`AopProxy`接口，是AopProxy接口是提供最终生成代理对象的方法：

~~~ java
public interface AopProxy {

	Object getProxy();

	Object getProxy(ClassLoader classLoader);
}
~~~

AopProxy有两个实现，一个是`JdkDynamicAopProxy`，它使用java里的Proxy系列接口创建代理对象；另一个是`CglibAopProxy`，它使用Cglib库创建。后者在这里不详述。

来看看在`JdkDynamicAopProxy`接口里的`getProxy`方法。就是在这里，真正调用`Proxy.newProxyInstance`，创建代理对象的：

~~~ java
public Object getProxy(ClassLoader classLoader) {
	if (logger.isDebugEnabled()) {
		logger.debug("Creating JDK dynamic proxy: target source is " + this.advised.getTargetSource());
	}
	Class<?>[] proxiedInterfaces = AopProxyUtils.completeProxiedInterfaces(this.advised);
	findDefinedEqualsAndHashCodeMethods(proxiedInterfaces);
	return Proxy.newProxyInstance(classLoader, proxiedInterfaces, this);
}
~~~

注意到这里调用`Proxy.newProxyInstance(classLoader, proxiedInterfaces, this);`第三个参数传入的是this，上一篇文章已经说过，`newProxyInstance`方法的最后一个参数，传入的是一个`InvocationHandler`对象，没错，JdkDynamicAopProxy除了实现`AopProxy`接口之外，也实现了`InvocationHandler`接口：

~~~ java
final class JdkDynamicAopProxy implements AopProxy, InvocationHandler, Serializable {

}
~~~

上一篇文章已经说过，实现`InvocationHandler`接口，需要实现`invoke`方法。当我们通过代理对象调用一个方法的时候，这个方法的调用就会被转发为由InvocationHandler这个接口的 invoke 方法来进行调用。

所以，最后，来看看`JdkDynamicAopProxy`怎样实现`invoke`方法的：

~~~ java
public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
	MethodInvocation invocation;
	Object oldProxy = null;
	boolean setProxyContext = false;

	TargetSource targetSource = this.advised.targetSource;
	Class<?> targetClass = null;
	Object target = null;

	try {
		if (!this.equalsDefined && AopUtils.isEqualsMethod(method)) {
			// The target does not implement the equals(Object) method itself.
			return equals(args[0]);
		}
		if (!this.hashCodeDefined && AopUtils.isHashCodeMethod(method)) {
			// The target does not implement the hashCode() method itself.
			return hashCode();
		}
		if (!this.advised.opaque && method.getDeclaringClass().isInterface() &&
				method.getDeclaringClass().isAssignableFrom(Advised.class)) {
			// Service invocations on ProxyConfig with the proxy config...
			return AopUtils.invokeJoinpointUsingReflection(this.advised, method, args);
		}

		Object retVal;

		if (this.advised.exposeProxy) {
			// Make invocation available if necessary.
			oldProxy = AopContext.setCurrentProxy(proxy);
			setProxyContext = true;
		}

		// May be null. Get as late as possible to minimize the time we "own" the target,
		// in case it comes from a pool.
		target = targetSource.getTarget();
		if (target != null) {
			targetClass = target.getClass();
		}

		// Get the interception chain for this method.
		List<Object> chain = this.advised.getInterceptorsAndDynamicInterceptionAdvice(method, targetClass);

		// Check whether we have any advice. If we don't, we can fallback on direct
		// reflective invocation of the target, and avoid creating a MethodInvocation.
		if (chain.isEmpty()) {
			// We can skip creating a MethodInvocation: just invoke the target directly
			// Note that the final invoker must be an InvokerInterceptor so we know it does
			// nothing but a reflective operation on the target, and no hot swapping or fancy proxying.
			retVal = AopUtils.invokeJoinpointUsingReflection(target, method, args);
		}
		else {
			// We need to create a method invocation...
			invocation = new ReflectiveMethodInvocation(proxy, target, method, args, targetClass, chain);
			// Proceed to the joinpoint through the interceptor chain.
			retVal = invocation.proceed();
		}

		// Massage return value if necessary.
		Class<?> returnType = method.getReturnType();
		if (retVal != null && retVal == target && returnType.isInstance(proxy) &&
				!RawTargetAccess.class.isAssignableFrom(method.getDeclaringClass())) {
			// Special case: it returned "this" and the return type of the method
			// is type-compatible. Note that we can't help if the target sets
			// a reference to itself in another returned object.
			retVal = proxy;
		}
		else if (retVal == null && returnType != Void.TYPE && returnType.isPrimitive()) {
			throw new AopInvocationException(
					"Null return value from advice does not match primitive return type for: " + method);
		}
		return retVal;
	}
	finally {
		if (target != null && !targetSource.isStatic()) {
			// Must have come from TargetSource.
			targetSource.releaseTarget(target);
		}
		if (setProxyContext) {
			// Restore old proxy.
			AopContext.setCurrentProxy(oldProxy);
		}
	}
}
~~~

### 参考

- 《SPRING技术内幕》
