---
layout: post
title:  "分布式系统case by case - google file system（GFS）"
date:   2018-01-23 23:07:00 +0800
---

google file system是15年前（2003）google发布的一个分布式文件系统论文，这篇论文可以说是分布式系统的入门经典。google应该是全球最早遇到如此复杂的分布式技术难题的公司。gfs是其中一个难题的解决方案：超大规模的，可靠的文件存储。看gfs的这篇论文，可以看到google的牛逼的大神们是怎样思考和工作的：遇到一个问题，做假设，设计系统，完成工程，最后将整个过程和经验输出为论文。

### workload

GFS是Google为其内部应用设计的分布式存储系统。google内部对文件系统的访问特点如下：

1. 数据集庞大，数据总量和单个文件都比较大，如应用常常产生数GB大小的单个文件；
2. 数据访问特点多为顺序访问，比较常见的场景是数据分析，应用程序会顺序遍历数据文件，产生顺序读行为；
3. 多客户端 **并发追加** 场景很常见，极少有 **随机写** 行为；
4. 一次写入，多次读取，例如互联网上的网页存储。

其中，第三点是最重要的，一些架构上，feature上的取舍都是对它的权衡。我们接下来就会看到。

### architecture

整个gfs的架构图如下：

![Alt](/images/gfs-1.jpg)

整个gfs的集群可分为：一个master，多个chunkservers。master和chunkserver都有可能和client直接联系。

- master：存储系统元数据信息，主要包括namespace、文件chunk信息以及chunk多副本位置信息。Master是系统的中心节点，所有客户端的元数据访问，如列举目录下文件，获取文件属性等操作都是直接访问Master。

在介绍chunkserver之前，先说说chunk的概念：在gfs里，一个大的文件会分为多个chunks。一个chunk的大小是64mb，一个chunk是数据复制的基本单位。当client要读一个文件的时候，在send request的时候其实会把file name和chunk index发给master。master会将每个chunk index所在的chunkserver返回给client。

- chunkserver：是文件chunk的存储位置。每个数据节点挂载多个磁盘设备并将其格式化为本地文件系统（如XFS）。将客户端写入数据以Chunk为单位存储，存储形式为本地文件。

### master fault tolerant

如上所述，gfs的架构是single master的，那么会引起两个问题：1. 单点故障，2. master读写瓶颈。看看gfs是怎么解决这两个问题。

### consistency model

gfs对外提供的一致性保证中，提供了4中语义：分别是：

consistent：所有client都能读到相同的data
defined：是consistent的而且都能完整的读到最新的写入
inconsistent and also undefined：different clients may see different data at different times。
什么时候会发生？failure
undefined but consistent：所有client都能读到相同的data，但有可能看不到任何新的写入，
也就是说有可能写入了一些并发数据

### data flow

### record append


### data detection

### 参考

- http://nil.csail.mit.edu/6.824/2017/papers/gfs.pdf
- http://nil.csail.mit.edu/6.824/2017/notes/l-gfs-short.txt
- http://www.cs.cornell.edu/courses/cs6464/2009sp/lectures/15-gfs.pdf
- https://zhuanlan.zhihu.com/p/28155582
