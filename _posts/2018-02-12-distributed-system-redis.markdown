---
title:  "分布式系统case by case - redis的分布式方案"
date:   2018-02-12 11:44:00 +0800
tags: [distribute-system,redis]
---

经常有一些面试题喜欢让人设计一个分布式存储系统，其目的是面试者对分布式系统的常见知识的掌握和运用。这篇文章来讨论下这个问题，从redis的实现说起，看看一个分布式系统高可用的方案有哪些。

之前已经说过对一个系统做分布式化，目的是三个：

- scalability
- availability
- performance

要达到这两点目的，一个有状态的系统要做分布式集群化，必然会做的是两点措施：1. replication，2. sharding。这两个实施之后，会引入新的问题：1. 一致性问题（一致性问题又可以分为两个问题：1.1. 分布式处理后，redis集群可以提供什么程度的一致性保证？1.2. 分布式处理后，会新增什么不一致的情况呢？），2. 集群无时无刻有节点不可用。另外分布式化是为了让集群即使在故障的时候依然可用，那么又涉及几个问题：1. 故障检测，2. 故障转移，3. 故障恢复……

我们会根据这个思路，一直提问，并从redis里找到相关的解决方案，还会看看其他的解决方案。

### master-slave replication

redis的复制机制是典型的master-slave。

### Sentinel

使用了sentinel之后是否有sharding 的功能？

### automatical failover

### master recover

### shard & reshard

### 集群化后带来的一致性问题

### request routing




### 参考

- 《分布式缓存 - 从原理到实践》
- 《redis设计与实现(第二版)》
- 《redis开发与运维》
- https://redis.io/topics/introduction
- https://stackoverflow.com/questions/31143072/redis-sentinel-vs-clustering
