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



### Transaction

### 参考

- 《分布式缓存 - 从原理到实践》
- 《redis设计与实现》
- https://redis.io/commands/expire
