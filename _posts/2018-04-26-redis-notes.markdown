---
title:  "redis单机特性"
date:   2018-04-26 17:58:00 +0800
tags: [redis,data-structure]
---

最近的项目深度使用redis，需要好好调研一下。这篇文章会做些笔记

### 数据结构



### Expire

redis可以设置每个key的过期时间，超过过期时间的key-value对会自动delete。一些命令会clear这个key的过期时间，具体可查：https://redis.io/commands/expire。

redis的expire实现有两种方法：a passive way, and an active way.

主动过期：每个redis对象都有一个field，可以设置过期时间，每次拿key返回之前，比较当前时间和过期时间，如果判断过期，返回null并删除key。

主动过期有一个问题：如果这个key已经到了过期时间，但一直没有给访问，那么它会一直占用空间。所以需要被动过期：redis有一个很聪明的算法干这件事：

server端每0.1s会执行一次这几步：

- Test 20 random keys from the set of keys with an associated expire.
- Delete all the keys found expired.
- If more than 25% of keys were expired, start again from step 1.

这是基于一个假设：抽样的20个key能代表整个键空间，如果抽样的20个key里过期率小于25%，那么推断整个空间的过期率也小于25%。

### Evict

redis是使用内存的缓存数据库，当内存到达上限时，会有部分的key被驱逐出键空间，即使这些key有可能没设置过期时间，驱逐的策略有这些：

1. noeviction:返回错误当内存限制达到并且客户端尝试执行会让更多内存被使用的命令（大部分的写入指令，但DEL和几个例外）
2. allkeys-lru: 尝试回收最少使用的键（LRU），使得新添加的数据有空间存放。
3. volatile-lru: 尝试回收最少使用的键（LRU），但仅限于在过期集合的键,使得新添加的数据有空间存放。
4. allkeys-random: 回收随机的键使得新添加的数据有空间存放。
5. volatile-random: 回收随机的键使得新添加的数据有空间存放，但仅限于在过期集合的键。
6. volatile-ttl: 回收在过期集合的键，并且优先回收存活时间（TTL）较短的键，使得新添加的数据有空间存放。

LRU算法会淘汰那些最近最少使用（被访问时间最早的）的keys，想象有一个链表，每次一个key被访问，就将这个key置于列表的头部，那么LRU算法淘汰的就是列表尾部的keys。

redis使用的算法是近似LRU算法，通过对少量keys进行取样，然后回收其中一个最好的key（被访问时间较早的）。

redis4.0之后的版本新增了LFU算法：

1. volatile-lfu： 尝试回收最少使用的键（LFU），但仅限于在过期集合的键。
2. allkeys-lfu： 尝试回收最少使用的键（LFU），使得新添加的数据有空间存放。

LFU算法详解可看：https://www.youtube.com/watch?v=MCTN3MM8vHA

### Transaction

redis是单线程的内存数据库，它支持非常弱的事务。以下是一个事务例子，它原子地增加了 foo 和 bar 两个键的值：

~~~
> MULTI
OK
> INCR foo
QUEUED
> INCR bar
QUEUED
> EXEC
1) (integer) 1
2) (integer) 1
~~~

redis是单线程的，事务的隔离级别天然的就是Serializable，不用担心并发问题。它的事务的实现要比传统数据库简单不少，它非常简单粗暴的实现：用执行`MULTI`命令开启一个Queue，然后将后续的命令（如：`INCR foo`、`INCR bar`）放入队列中，当执行`EXEC`命令时，将队列里的命令一起（原子性的）执行，因为是单线程的，所以所谓的原子性只是将命令批量的执行即可。

正因为如此，所以redis的事务是不支持回滚的，如果出现任何一个命令错误，redis会忽略这个错误，继续执行下面的指令。

### 参考

- 《分布式缓存 - 从原理到实践》
- 《redis设计与实现》
- https://redis.io/commands/expire
- https://redis.io/topics/lru-cache
- https://www.youtube.com/watch?v=MCTN3MM8vHA
