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

redis的复制机制是master-slave模型 - 对同一份数据，会有多份拷贝分布在多个节点，其中，只有一个master节点可以更新，master节点更新后，会通过一定机制使其它节点同步状态。在redis官方文档中，复制系统是通过三个机制实现：

1. 在正常状态下，master会将接收到的指令传播到slave节点，使slave节点的状态同步。
2. 当从节点发生故障，将有一段时间不可用。当从节点恢复时，会发起partial resynchronization请求，请求这段时间内，master节点执行了的所有指令，重新执行一遍，这时这个slave节点的状态又会再次同步。
3. 当partial resynchronization不可用时，从节点会发起full resynchronization，请求完整的同步。完成之后，进入正常状态，主从之间通过指令流同步。

整个机制里，值得注意的是两点：

1. 在指令传播的同步场景里，是异步复制（asynchronous replication）的。
2. partial resynchronization和full resynchronization的同步场景中，master节点是非阻塞的。

#### 指令传播的实现

指令传播是通过在主从节点共同维护偏移量实现的。从节点会通过每秒向主节点发送命令的方式保持心跳，命令包括：

1. Replication ID - 主节点的id（集群内唯一）。
2. offset - 从节点已经处理了指令字节偏移量。

主节点会将最近执行的指令放入一个buffer中，同时维护自己已经执行的指令偏移量。从节点通过心跳的方式告诉主节点，已经执行的指令偏移量。主节点通过比较两者的差距，在buffer里偏移量差值的指令字节发送给从节点。

![Alt](/images/redis-0.png)

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
