---
layout: post
title:  "实现一致性哈希（Consistent Hashing）java版本"
date:   2016-11-19 14:26:00 +0800
---

一致性哈希算法是分布式系统中重要的路由算法，如果你对它的原理不熟悉，可以看看我之前写过的[这篇文章](/2016/07/04/consistent-hashing.html)。

这篇文章主要说说它的实现。首先，是几个关键的抽象：

- Entry，要放入cache服务器中的对象。
- Server，真正存放缓存对象的cache服务器。
- Cluster，服务器集群，维护一组Servers，相当于这一组servers的代理，接受`put`，`get`请求，通过一定算法（普通取余或一致性哈希）把请求转发到特定的server。

首先来看看不使用一致性哈希算法的情况，会出现什么问题：

#### 原始版本

Entry：

~~~ java
public class Entry {
    private String key;

    Entry(String key) {
        this.key = key;
    }

    @Override
    public String toString() {
        return key;
    }
}
~~~

Server：

~~~ java
public class Server {
    private String name;
    private Map<Entry, Entry> entries;

    Server(String name) {
        this.name = name;
        entries = new HashMap<Entry, Entry>();
    }

    public void put(Entry e) {
        entries.put(e, e);
    }

    public Entry get(Entry e) {
        return entries.get(e);
    }
}
~~~

Cluster：

~~~ java
public class Cluster {
    private static final int SERVER_SIZE_MAX = 1024;

    private Server[] servers = new Server[SERVER_SIZE_MAX];
    private int size = 0;

    public void put(Entry e) {
        int index = e.hashCode() % size;
        servers[index].put(e);
    }

    public Entry get(Entry e) {
        int index = e.hashCode() % size;
        return servers[index].get(e);
    }

    public boolean addServer(Server s) {
        if (size >= SERVER_SIZE_MAX)
            return false;

        servers[size++] = s;
        return true;
    }
}
~~~

`Entry`，`Server`，`Cluster`是对这三个抽象的实现，看代码应该是非常清晰的。

其中，`Cluster`类是实现路由算法的类，也就是根据entry的key决定entry放入哪个server中，在最简单的实现里，直接用取余的方法：`e.hashCode() % size`。

然后看看测试：

~~~ java
public class Main {

    public static void main(String[] args) {
        Cluster c = createCluster();

        Entry[] entries = {
                    new Entry("i"),
                    new Entry("have"),
                    new Entry("a"),
                    new Entry("pen"),
                    new Entry("an"),
                    new Entry("apple"),
                    new Entry("applepen"),
                    new Entry("pineapple"),
                    new Entry("pineapplepen"),
                    new Entry("PPAP")
                };

        for (Entry e : entries)
            c.put(e);

        c.addServer(new Server("192.168.0.6"));

        findEnties(c, entries);

    }

    private static Cluster createCluster() {
        Cluster c = new Cluster();
        c.addServer(new Server("192.168.0.0"));
        c.addServer(new Server("192.168.0.1"));
        c.addServer(new Server("192.168.0.2"));
        c.addServer(new Server("192.168.0.3"));
        c.addServer(new Server("192.168.0.4"));
        c.addServer(new Server("192.168.0.5"));
        return c;
    }

    private static void findEnties(Cluster c, Entry[] entries) {
        for (Entry e : entries) {
            if (e == c.get(e)) {
                System.out.println("重新找到了entry:" + e);
            } else {
                System.out.println("entry已失效:" + e);
            }
        }
    }
}
~~~

测试里，先构建一个6个服务器的集群，然后把一组entries逐个放入集群，然后向集群里添加一个新的server，看有多少个entry失效了，结果：

~~~
重新找到了entry: i
entry已失效: have
entry已失效: a
entry已失效: pen
entry已失效: an
entry已失效: apple
entry已失效: applepen
entry已失效: pineapple
entry已失效: pineapplepen
重新找到了entry: PPAP
~~~

可见，在普通取余路由算法的实现，几乎所有的entry都会被映射到新的server中，大部分缓存都失效了。
