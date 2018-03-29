---
title:  "分布式系统 - partitioning"
date:   2018-02-28 23:07:00 +0800
tags: [distribute-system]
---

上一篇文章说了分布式系统的[复制（replication）](/2018/02/06/distributed-system-replication.html)技术。这一篇来说说分区（partitioning）。

replication解决了availability。partitioning解决scalability。

复制技术的思路是：在集群内制造更多的相同状态的节点承担流量，这时每个节点都保存所有记录。但如果data set不停的增长，导致一个节点无法完全保存所有数据，就需要partitioning：将数据break down，使每个节点只需要保存特定范围的记录，对单条记录的流量最终只会落到特定的节点内，从而达到高扩展性。

分区的技术通常要考虑几个问题：

1. 该怎么对数据进行分区？比如我要将整个data set部署到10个节点，怎么决定记录A应该落在节点1还是节点2？
2. Rebalancing。
3. 请求路由（Request routing）。

### Partitioning by...

该怎么对数据进行分区？这个问题该考虑的是两点：

1. 尽可能均匀分布，避免数据热点问题。
2. 让rebalance操作尽可能方便，代价尽可能小。

下面，以常见的以int型主键id作为分区因子，看看几个对数据进行分区的策略。

#### Partitioning by Key Range

第一个方法是：每个partition存储一段（id）连续范围的数据。如：id为(0, 1000]的数据落在节点1，id为(1001, 2001]的数据落在节点2。

这一策略的一个好处是：对id进行范围查询很容易。在存储的上层可以通过分析query判断该到哪个节点寻找数据。

比如，考虑一个场景：有一个记录室内温度的应用，它每一秒会将当前温度写入数据库。id使用时间格式（year-month-day-hour-minute-second）。而大部分读取场景都是需要读取某一天内的温度变化。

这样的场景适合用上面的分区做partition。因为它使得时间相近的两条记录很有可能在同一分片。在查询的时候只需要查一个分片，就可以把一段连续时间的数据拿出来。

然而，采用这样的分区策略会同样让写入操作成为热点。在写入场景下，所有流量都会落到同一分片，sharding几乎没有起任何作用。

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
