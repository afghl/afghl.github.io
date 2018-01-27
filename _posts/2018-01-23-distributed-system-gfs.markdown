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

gfs的架构图如下：

![Alt](/images/gfs-1.jpg)

整个gfs的集群可分为：一个master，多个chunkservers。master和chunkserver都有可能和client直接联系。

- master：存储系统元数据信息，主要包括namespace、文件chunk信息以及chunk多副本位置信息。Master是系统的中心节点，所有客户端的元数据访问，如列举目录下文件，获取文件属性等操作都是直接访问Master。

在介绍chunkserver之前，先说说chunk的概念：在gfs里，一个大的文件会分为多个chunks。一个chunk的大小是固定的，是64mb，一个chunk是数据复制的基本单位。当client要读一个文件的时候，在send request的时候其实会把file name和chunk index发给master。master会将每个chunk index所在的chunkserver返回给client。

- chunkserver：是文件chunk的存储位置。每个数据节点挂载多个磁盘设备并将其格式化为本地文件系统（如XFS）。将客户端写入数据以Chunk为单位存储，存储形式为本地文件。

### master fault tolerant

如上所述，gfs的架构是single master的，那么会引起两个问题：1. 单点故障，2. master读写瓶颈。看看gfs是怎么解决这两个问题。

#### 客户端直接访问chunkserver，最小化client和master的交互

用一次简单的read操作中，client、master、chunkserver三者间的交互说明这个问题。

1. client知道他要读取的文件名和文件大小。
2. client将文件名+文件大小转换成文件名+chunk index请求master。（由于chunk size是确定的，client可以根据文件大小确定chunk index。比如：一个640mb的文件，要读取后一半的数据，那么chunk index就是 6 - 10。）
3. master接收到文件名和chunk index后，在内存中的metadata中找到对应的chunk所在的chunkserver的hostname，返回给client。
4. 这时master的工作已经完成，client可以直接和chunkserver交互并读取文件。

这样，在一次read操作中，client和master只有一次交互。为进一步减少对master的请求，client还会将master返回的信息cache起来。client再次请求相同文件的时候，不需要和master交互。

#### master高可用



### consistency model

![Alt](/images/gfs-2.jpg)

如上图，gfs对外提供的一致性保证中，提供了4中语义。分别是：

1. **consistent**：所有client都能读到相同的data
2. **defined**：是consistent的而且都能完整的读到最新的写入
3. **inconsistent and also undefined**：不同的client在不同的时间看到不同的内容。（我的理解是：这个状态下的data已经损坏）
4. **undefined but consistent**：所有client都能读到相同的data，但data可能是错误的（就是发生了并发写的问题导致data错误）

在上图中，可以看到两个column：write和record append。其中，write的情况很容易理解，无非是串行写还是并发写，如果是并发写，则gfs不保证数据是defined的。

record append是gfs的核心feature，它保证多client并发的以record append方式写入的数据是defined的。我们下面会看到，这点保证是如何实现的。

### data flow

### record append

### data detection

### 参考

- http://nil.csail.mit.edu/6.824/2017/papers/gfs.pdf
- http://nil.csail.mit.edu/6.824/2017/notes/l-gfs-short.txt
- http://www.cs.cornell.edu/courses/cs6464/2009sp/lectures/15-gfs.pdf
- https://zhuanlan.zhihu.com/p/28155582
- http://pages.cs.wisc.edu/~remzi/Classes/537/Fall2008/Notes/gfs.pdf
