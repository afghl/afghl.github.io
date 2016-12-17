---
layout: post
title:  "Java Nio（一） - 用NIO实现Reactor模式"
date:   2016-12-17 22:26:00 +0800
---

本文跳过了介绍NIO的各个部件，直接进入了整合、实战的阶段。如果你对NIO中三个部件：selector、channel、buffer不熟悉，可以先看看[这个系列](http://tutorials.jenkov.com/java-nio/index.html)。

### NIO与Reactor

Reactor是一种和IO相关的设计模式，Java中的NIO中天生就对Reactor模式提供很好的支持。甚至在Doug Lea大神在[《Scalable IO in Java》](http://gee.cs.oswego.edu/dl/cpjslides/nio.pdf)都演示怎么使用NIO实现Reactor模式，可以说使用Nio的最佳实践，就是实现Reactor模式。

### 什么是Reactor模式

先看Wikipedia的对Reactor模式的定义：

> The reactor design pattern is an event handling pattern for handling service requests delivered concurrently by one or more inputs. The service handler then demultiplexes the incoming requests and dispatches them synchronously to associated request handlers.

翻译并理解一下：reactor模式是事件驱动型的，它可以处理多个输入（也可以理解成事件），每个特定的事件由特定的handler处理。

![Alt](/images/reactor(1).png)

如果你写过前端/node，一定感觉这个设计模式非常熟悉。是的，它非常类似pub/sub模式：上图中的service handler可以理解成一个全局的事件对象，它负责分发不同的事件到特定的handler中处理，而handler，可理解成js世界里的callback。

### 各个部件

reactor模式的UML图如下：

![Alt](/images/reactor(2).png)

介绍一下各个部件：

- Demultiplexer

   记得上一篇文章提到Unix里多路转接IO的工作过程吗？里面提到我们需要构造fd（文件描述符）列表，调用select方法，等待select方法返回可用的fd。这里的Demultiplexer就是干这件事的：它会提供一个同步阻塞调用select，select返回时，Demultiplexer会通知Dispatcher（下文提及）这个event可用。

- Handle

   Demultiplexer通知Dispatcher是通过返回一个Handle来实现的。Handle是一个系统资源，如：socket、file。但在Reactor模式中，Handle会封装更多信息，比如：Dispatcher需要知道这个handle应该被哪一个handler处理，所以，handle必须带有这种信息。handle可以理解为：一个需要被处理的东西。

- initiation Dispatcher（又称为reactor）

   最重要的部件，负责分发不同的事件到特定的handler对象中。它提供register、remove、dispatch等API。允许客户注册感兴趣的事件并绑定handler。

- Handler

   handler，注册到Dispatcher，并由Dispatcher调用。

- Concrete event handler

   需要客户编写的handler。每个handler处理一个特定的event。

可见，Dispatcher是整个reactor模式的核心，它持有一个Demultiplexer，和一个handler的map（或list）集合。Demultiplexer为它监听输入事件并据此通知、返回事件。若事件已被注册（即有相关的处理器），就会分发到特定的处理器处理。

Demultiplexer的行为是同步阻塞的。所以，为性能考虑，它的职责应该尽可能小。在这里，它只负责通知Dispatcher处理。

### Java Nio中的Reactor模式

使用Nio实现Reactor模式，有一些接口是JDK提供的。（事实上，看到Reactor模式，我才知道原来JDK的相关的这些类是这么用的。）

所以Nio中的Reactor模式是这样的：

![Alt](/images/reactor(3).png)

注意：

- Demultiplexer被Selector替代了。Nio中的selector当然就是提供一个多路器的功能。

- 实际上，NIO中的selector做的更多：它可以注册事件。于是，Dispatcher很多方法会转发给它。

- SelectionKey替代了handler。

- handler应该实现callable，因为往往这些handlers会处在一个线程池里，使用callable保证它们可以异步调用。

### 简单的实现

简单的使用NIO实现reactor模式，会使这样的：

~~~ java
public class Reactor {
    private Map<Integer, EventHandler> registeredHandlers = new ConcurrentHashMap<>();
    private Selector demultiplexer;

    public Reactor() throws Exception {
        demultiplexer = Selector.open();
    }

    public void registerEventHandler(
        int eventType, EventHandler eventHandler) {
        registeredHandlers.put(eventType, eventHandler);
    }

    public void registerChannel(int eventType, SelectableChannel channel) throws Exception {
        channel.register(demultiplexer, eventType);
    }

    public void run() {
        try {
            while (true) { // Loop indefinitely
                demultiplexer.select();
                Set<SelectionKey> readyHandles = demultiplexer.selectedKeys();
                Iterator<SelectionKey> handleIterator = readyHandles.iterator();
                while (handleIterator.hasNext()) {
                    SelectionKey handle = handleIterator.next();
                    if (handle.isAcceptable()) {
                        EventHandler handler = registeredHandlers.get(SelectionKey.OP_ACCEPT);
                        handler.handleEvent(handle);
                    }

                    if (handle.isReadable()) {
                        EventHandler handler = registeredHandlers.get(SelectionKey.OP_READ);
                        handler.handleEvent(handle);
                        handleIterator.remove();
                    }

                    if (handle.isWritable()) {
                        EventHandler handler = registeredHandlers.get(SelectionKey.OP_WRITE);
                        handler.handleEvent(handle);
                        handleIterator.remove();
                    }
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}

~~~

调用reactor：

~~~ java
public static void main(String[] args) throws Exception {
    ServerSocketChannel server = ServerSocketChannel.open();
    server.socket().bind(new InetSocketAddress(8080));
    server.configureBlocking(false);
    Reactor reactor = new Reactor();

    reactor.registerChannel(SelectionKey.OP_ACCEPT, server);

    reactor.registerEventHandler(
            SelectionKey.OP_ACCEPT, new AcceptEventHandler());

    reactor.registerEventHandler(
            SelectionKey.OP_READ, new ReadEventHandler());

    reactor.registerEventHandler(
            SelectionKey.OP_WRITE, new WriteEventHandler());

    reactor.run();
}
~~~

实现参考[这篇文章](http://kasunpanorama.blogspot.hk/2015/04/understanding-reactor-pattern-with-java.html)。这个实现中，只使用了NIO包的selector类。是个比较粗糙的实现。下一节，我们会使用selector、channel、buffer，实现基于reactor模式的socketserver。

### 参考

- http://www.blogjava.net/DLevin/archive/2015/09/02/427045.html
- http://gee.cs.oswego.edu/dl/cpjslides/nio.pdf
- http://kasunpanorama.blogspot.hk/2015/04/understanding-reactor-pattern-with-java.html
