---

title:  "用pub / sub实现DDD中的领域事件"
date:   2017-09-23 12:16:00 +0800
---

领域事件是DDD里的一个概念。牛逼的领域专家觉得：

在所有领域中，总是有相同的情况重复出现：领域中发生了某件事，需要对这件事做一些后续的操作，或者广播通知。例如，用户在完成注册后，系统会发出一封带有确认信息的邮件到用户的邮箱；用户关注的好友发送动态后他会收到相应的通知等等。

把这种经常出现的情况抽象为了领域事件。适当的抽象和建模领域事件，可以降低代码耦合，使代码更能反映领域模型的本质，原因是：

- 这些后续操作基本都是：发送消息，处理数据同步，它们无关领域逻辑。把这些后续操作从主流程的逻辑中分离出来，让service / domain model只反映领域逻辑。
- 隐藏技术细节：mq，redis等的处理细节
- 易于维护：要新增，减小对领域事件的响应，只需要订阅 / 取消订阅一个register。

### 实现

接下来提供一个简单的实现：

实现起来一共有几个概念：

- domainEvent，事件本身，比如UserLoginedEvent，就是一个特定的事件。
- DomainEventPublisher，单例。提供发布/订阅功能。
- Subscriber，订阅事件的handler。

代码非常简单：

DomainEvent：

~~~ java
/**
 * 领域事件
 */
public interface DomainEvent {
    /**
     * 领域事件发生的时间
     * @return
     */
    public LocalDateTime occurredOn();

}
~~~

Subscriber：

~~~ java
/**
 * 处理领域事件的subscriber
 * @param <T>
 */
public interface Subscriber<T extends DomainEvent> {
    /**
     * 处理领域事件
     * @param event
     * @return 处理结果，为false时不往下执行
     */
    public boolean handle(T event);
}
~~~

DomainEventPublisher：

~~~ java
@NotThreadSafe
public class DomainEventPublisher {

    private final static DomainEventPublisher INSTANCE = new DomainEventPublisher();

    private Map<Class<? extends DomainEvent>, List<Subscriber>> subscriberMap;

    private DomainEventPublisher() {
        subscriberMap = new ConcurrentHashMap<>();
    }

    public static DomainEventPublisher instance() {
        return INSTANCE;
    }

    public <T extends DomainEvent> void publish(T event) {
        Validator.checkNotNull(event);

        Class<?> klass = event.getClass();

        final List<Subscriber> subscribers = subscriberMap.get(klass);

        if (subscribers == null || subscribers.isEmpty()) {
            return;
        }

        for (Subscriber s : subscribers) {
            if (!s.handle(event)) {
                break;
            }
        }
    }

    public void register(Class<? extends DomainEvent> eventKlass, Subscriber subscriber) {
        if (eventKlass == DomainEvent.class) {
            throw new IllegalArgumentException("cannot register abstract DomainEvent");
        }

        List<Subscriber> subscribers = subscriberMap.get(eventKlass);

        if (subscribers == null) {
            synchronized (this) {
                if (subscribers == null) {
                    subscribers = new CopyOnWriteArrayList<>();
                    subscriberMap.put(eventKlass, subscribers);
                }
            }

            subscribers = subscriberMap.get(eventKlass);
        }

        subscribers.add(subscriber);
    }
}
~~~

### 参考

- 《领域驱动设计》
- 《实现领域驱动设计》
- https://docs.microsoft.com/en-us/dotnet/standard/microservices-architecture/microservice-ddd-cqrs-patterns/domain-events-design-implementation
- http://michael-j.net/2016/01/19/%E5%AE%9E%E7%8E%B0%E9%A2%86%E5%9F%9F%E4%BA%8B%E4%BB%B6/
