---
layout: post
title:  "分布式系统 - partitioning"
date:   2018-02-28 23:07:00 +0800
---

上一篇文章说了分布式系统的[复制（replication）](/2018/02/06/distributed-system-replication.html)技术。这一篇来说说分区（partitioning）。

partitioning和replication想要解决的问题是一样的：scalability。

复制技术的思路是：在集群内制造更多的相同状态的节点承担流量，这时每个节点都保存所有记录。但如果data set不停的增长，导致一个节点无法完全保存所有数据，就需要partitioning：将数据break down，使每个节点只需要保存特定范围的记录，对单条记录的流量最终只会落到特定的节点内，从而达到高扩展性。

分区的技术通常要考虑几个问题：

1. 该怎么对数据进行分区？比如我要将整个data set部署到10个节点，怎么决定记录A应该落在节点1还是节点2？
2. Rebalancing。
3. 请求路由（Request routing）。

### Partitioning by...

#### Partitioning by Key Range

#### Partitioning by Hash of Key

#### 避免热点

### Rebalance

#### 不要使用 hash mod N

#### Fixed number of partitions

#### Dynamic partitioning

#### 自动还是手动

### Request Routing

### 参考

- 《Designing Data-Intensive Applications》
