---
layout: post
title:  "Java Nio（三） - 用NIO实现高性能socketserver"
date:   2016-12-18 10:26:00 +0800
---

socket server是基于TCP协议的C/S通信模式下，服务器端的实现。一个socket server最主要的工作是处理网络IO，同事，高效处理网络IO也是一个socket server最重要的性能指标。

本文会用java NIO框架实现一个同步非阻塞的socket server。

### 最基础的结构

首先从最基础的考虑。一个socket server最简单最经典的实现必然是多线程阻塞的版本：

主线程监听socket端口（阻塞），每当有新客户连接，为这个用户单独创建一个线程，并在新线程里处理业务逻辑：

~~~ java
class Server implements Runnable {
    public void run() {
        try {
            ServerSocket ss = new ServerSocket(PORT);
        while (!Thread.interrupted())
            new Thread(new Handler(ss.accept())).start();
            // or, single-threaded, or a thread pool
        } catch (IOException ex) { }
    }
}

class Handler implements Runnable {
    final Socket socket;
    Handler(Socket s) { socket = s; }
    public void run() {
        try {
            byte[] input = new byte[MAX_INPUT];
            socket.getInputStream().read(input);
            byte[] output = process(input);
            socket.getOutputStream().write(output);
        } catch (IOException ex) { }
    }
    private byte[] process(byte[] cmd) { }
}
~~~

这种I/O模型的主要缺点是：线程不是免费的。操作系统分配给每个进程的最大线程数是有限的，在高并发的情况下，服务器会因为不能创建新线程而不能响应请求。

这时，演变成线程池版本的多线程服务器：

~~~ java
public class ExecutorServiceServer implements Runnable {
    public void run() throws IOException {
        ServerSocket ss = new ServerSocket(PORT);
        ExecutorService service = Executors.newFixedThreadPool(MAX_POOL_SIZE);
        while (true) {
            Socket s = ss.accept();
            service.submit(new Handler(s));
        }
    }
}
~~~

我们解决了线程数不足的问题，但是服务器的IO模型依然是：one-thread-per-client，而且，每个线程都是阻塞的。这种I/O模型的主要缺点是：切换线程上下文的开销。我们可以看到server的`ss.accept()`和handler的`socket.getInputStream().read(input)`都是阻塞调用。最糟糕的情况是：每个client都不是经常读写data，这样，大部分线程都会阻塞在`read`或`write`方法上，但CPU可不管这个线程是否正在阻塞，它依然公平的给每个线程分配时间。 **这样，大部分CPU时间都会浪费在等待阻塞调用上。**

为了解决这种无谓的上下文切换带来的开销，我们需要非阻塞IO。

### Reactor模式下的socket server

Reactor模式是一种事件驱动的IO相关的设计模式。上一篇文章已经介绍了它是如何工作的。用Reactor实现socket server，里面的类会有一点变种，先看图：

![Alt](/images/socketserver(1).png)

我稍微搬运一下[这个slide](http://gee.cs.oswego.edu/dl/cpjslides/nio.pdf)的代码，分类结合代码说说：

#### Reactor

reactor的职责没变，还是使用JAVA NIO包中的selector监听IO事件，然后分发到指定的handler。

~~~ java
public class Reactor implements Runnable {
    final Selector selector;
    final ServerSocketChannel serverSocketChannel;

    Reactor(int port) throws IOException {
        selector = Selector.open();
        serverSocketChannel = ServerSocketChannel.open();
        serverSocketChannel.socket().bind(new InetSocketAddress(port));
        serverSocketChannel.configureBlocking(false);
        SelectionKey selectionKey0 = serverSocketChannel.register(selector, SelectionKey.OP_ACCEPT);
        selectionKey0.attach(new Acceptor());
    }

    public void run() {
        try {
            while (!Thread.interrupted()) {
                selector.select();
                Set selected = selector.selectedKeys();
                Iterator it = selected.iterator();
                while (it.hasNext()) {
                    dispatch((SelectionKey) (it.next()));
                }
                selected.clear();
            }
        } catch (IOException ex) {
            ex.printStackTrace();
        }
    }

    void dispatch(SelectionKey k) {
        Runnable r = (Runnable) (k.attachment());
        if (r != null) {
            r.run();
        }
    }
}
~~~

可以看到，selector和handler是运行在同一线程的。reactor调用`selector.select();`，然后根据`key.attachment()`找到handler，调用`run`方法。

第二点是，我们看reactor的构造方法：

~~~ java
SelectionKey selectionKey0 = serverSocketChannel.register(selector, SelectionKey.OP_ACCEPT);
selectionKey0.attach(new Acceptor());
~~~

`Acceptor`的实现是：

~~~ java
public class Reactor implements Runnable {
  class Acceptor implements Runnable {
      public void run() {
          try {
              SocketChannel socketChannel = serverSocketChannel.accept();
              if (socketChannel != null) {
                  new Handler(selector, socketChannel);
              }
              System.out.println("Connection Accepted by Reactor");
          } catch (IOException ex) {
              ex.printStackTrace();
          }
      }
   }
}
~~~

我们需要把`ServerSocketChannel`注册到`selector`中，并用`Accpeter`处理它。

`SelectionKey 0`表示这种注册关系：它告诉`selector`使用`Accpeter`处理`ServerSocketChannel`的`OP_ACCEPT`事件：当一个client请求连接时，`ServerSocketChannel`会触发一个IO事件（`OP_ACCEPT`），此时，selector的select方法会找到`selectionKey0`，从而找到`Accpeter`。

`Accpeter`的职责是：为新接收的`socketChannel`分配一个`handler`，也就是one-handler-per-client：

~~~ java
  new Handler(selector, socketChannel);
~~~

我们即将看到handler做了什么。

#### Handler

Handler的构造函数如下：

~~~ java
public class Handler implements Runnable {
    final SocketChannel socketChannel;
    final SelectionKey selectionKey;
    ByteBuffer input = ByteBuffer.allocate(1024);
    static final int READING = 0, SENDING = 1;
    int state = READING;
    String clientName = "";

    Handler(Selector selector, SocketChannel c) throws IOException {
        socketChannel = c;
        c.configureBlocking(false);
        selectionKey = socketChannel.register(selector, 0);
        selectionKey.attach(this);
        selectionKey.interestOps(SelectionKey.OP_READ);
        selector.wakeup();
    }
}
~~~

`Handler`的构造过程实际上是向`selector`注册一个`socketChannel`和一个`handler`。

注册之后，下一次当`selector.select()`返回这个`selectionKey`时，就会找到这个handler，执行它的处理逻辑：

~~~ java
public class Handler implements Runnable {
    public void run() {
        try {
            if (state == READING) {
                read();
            } else if (state == SENDING) {
                send();
            }
        } catch (IOException ex) {
            ex.printStackTrace();
        }
    }
}
~~~

整个过程就是：一个连接过来，先触发ACCEPT事件，reactor会分发给Acceptor，Acceptor调用`new Handler()`，把一个handler分配给这个socketChannel，并把两者注册到`reactor`中。保证这个handler和socketChannel的通信能被reactor分配。

以上就是一个reactor模式下的socketserver的基本实现。

为了追求更高的性能，这个模型还有一些变种：比如多线程运行handler，主从reactor，多线程运行reactor等。都比较复杂，你可以在参考一栏看到相关描述。

### 参考

- http://gee.cs.oswego.edu/dl/cpjslides/nio.pdf
- http://jeewanthad.blogspot.hk/2013/02/reactor-pattern-explained-part-1.html
