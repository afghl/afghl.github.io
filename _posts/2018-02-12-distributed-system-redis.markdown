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

对于有状态的分布式系统来说，要提高系统的可用性，冗余是必须考虑的最基本的方法，而最简单最常用的冗余方法，就是复制。

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

上一节中已经介绍了redis的复制方案。实现了复制之后，集群不是马上就能获得高可用的好处，我们还需要一套对集群状态的维护，检测，failover的机制。redis里使用哨兵（sentiel）解决这一问题。

sentinel的实现方法是在集群中有一组特殊功能的节点，它们负责维护集群的健康度。官方文档中，Sentinel提供这几点功能：

> Monitoring. Sentinel constantly checks if your master and slave instances are working as expected.

> Notification. Sentinel can notify the system administrator, another computer programs, via an API, that something is wrong with one of the monitored Redis instances.

> Automatic failover. If a master is not working as expected, Sentinel can start a failover process where a slave is promoted to master, the other additional slaves are reconfigured to use the new master, and the applications using the Redis server informed about the new address to use when connecting.

> Configuration provider. Sentinel acts as a source of authority for clients service discovery: clients connect to Sentinels in order to ask for the address of the current Redis master responsible for a given service. If a failover occurs, Sentinels will report the new address.

简而言之，sentinel最大作用是自动故障转移。

Redis Sentinel 本身也是一个分布式系统（否则将成为单点），它要求至少三个节点。它的架构图是这样：

![Alt](/images/redis-1.png)

下面来看看它是怎么工作的：

1. **和master节点创建连接**。sentinel集群上线后，会与集群内的master节点创建命令连接和订阅连接。
2. **定期轮询master节点和slave节点信息**。sentinel默认会以10s一次的频率，通过命令连接向master节点和slave节点发送INFO命令。master和slave会将彼此的一些信息汇报给sentinel，通过这样的轮询，sentinel可以知道集群内master和slave的拓扑结构、具体物理地址（IP），连接情况，从服务器的复制偏移量、等等。
3. **sentinel主动向master节点和slave节点推送信息**。sentinel会以2s一次的频率，通过命令连接向master节点和slave节点发送PUBLISH指令，主要是为了心跳检测，另外汇报sentinel节点本身的物理地址，和master节点的物理地址。
4. **保持心跳**。其他节点会用类似3的方式与sentinel集群保持心跳。
5. **sentinel集群内部自治**。sentinel集群内部不需要复杂的心跳方式，它们彼此之间的发现是通过上面2完成的（sentinel轮询master时，master会报告与它相连的所有sentinel节点），然后在彼此间建立连接可以通信。

通过这样的方式，sentinel可以监视集群内的master节点健康状况。为failure detection和failover做基础。下详。

### automatical failover



### master recover（可能没有）

### shard & reshard

### 集群化后带来的一致性问题

### request routing




### 参考

- 《分布式缓存 - 从原理到实践》
- 《redis设计与实现(第二版)》
- 《redis开发与运维》
- https://redis.io/topics/introduction
- https://stackoverflow.com/questions/31143072/redis-sentinel-vs-clustering
