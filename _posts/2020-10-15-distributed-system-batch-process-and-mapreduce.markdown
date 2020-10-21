---
title:  "分布式系统 - 批处理与MapReduce"
date:   2020-10-15 20:53:00 +0800
tags: [distribute-system,batch-process,mapreduce]
---

在分布式系统或单机系统中，对数据的处理分别有两种常见手段，是批处理（batch processing）和流处理（stream processing）。
区别于流处理，批处理的手段处理数据会有这几个特点和隐含的假设：
- 处理过程中，不能和终端用户交互（区别于交互式的处理）
- 数据量大，而且是冷数据，或称离线数据（就是处理过程中，数据状态不变或可忽略）
- 处理速度慢，且结果在完全处理完之后才可见

而MapReduce是google在2004年以论文方式推出的提供分布式批处理实现的框架的编程（抽象）模型。MapReduce在工业上的实现有很多，Hadoop是其中一个开源的实现版本。

### 单机MapReduce

MapReduce的编程框架将大数据处理的“石器时代”带入“青铜时代”。它提供给使用者的抽象是两个所有人再熟悉不过的fp范式的函数：map（映射）和reduce（规约）。在学习分布式MapReduce框架之前，我们先实现一个单机版的MapReduce，回忆一下这两个简单有力的抽象，能做什么事情。

以最简单的“word count”统计这个use case入手。假设需要统计文件系统里某几个文本文件中，所有出现过的单词，和它们出现的次数。你会怎么做呢？用MapReduce的模型实现，则是两步：

1. map函数，读取文件，统计这个文件出现的单词word，每次出现，记录一条记录，输出一个list<word, count>。
2. reduce函数，入参是一个key和这个key下所有的value（<word, list<count>>），对所有value求和，最终输出所有total sum（<word, sum>）。

用简单的代码实现一下，这个算法是非常简单的：

~~~ js
const fs = require('fs')

class KeyValue {
  constructor(key, value) {
    this.key = key
    this.value = value
  }
}

const mapF = (fileName, contents) =>
  contents.split(/[^A-Za-z]/).filter(a => a.length > 0).map((word) => new KeyValue(word, 1))

const reduceF = (key, values) => {return {[key]: values.reduce((sum, v) => sum + v)}}

const sort = (a, b) => {
  if (a.key < b.key) {
    return -1;
  } else if (a.key > b.key) {
    return 1;
  } else {
    return 0;
  }
}

const start = () => {
  // './contents/pg*.txt'

  ["./contents/pg-being_ernest.txt", "./contents/pg-dorian_gray.txt", "./contents/pg-frankenstein.txt"]

  // map
  let intermediate = []
  fileNames.forEach((name, _) => {
    contents = fs.readFileSync(name, 'utf8');
    const results = mapF(name, contents)
    intermediate.push.apply(intermediate, results)
  });

  // shuffle
  intermediate.sort(sort)

  // reduce
  let i = 0
  let results = []
  while (i < intermediate.length) {
    let j = i
    let values = []
    while (j < intermediate.length && intermediate[i].key == intermediate[j].key) {
      values.push(intermediate[j].value)

      j = j + 1
    }

    const reduceResult = reduceF(intermediate[i].key, values)
    results.push(reduceResult)
    i = j
  }

  console.log(results);
}

start()

~~~

[see in gist](https://gist.github.com/afghl/707448616df319ccaee4a72d0a24e148)

你可以认为上文中的整个执行流程就是单机版MapReduce的框架，调用方如果需要使用，需要实现两个函数：`mapF`，`reduceF`，去完成不同的任务。整个执行流程如图：

![Alt](/images/mapreduce.png)

在单机场景中，一切都好像很简单，然后呢？

### 设计分布式MapReduce

当从单机变成分布式环境后，情况将会变得复杂得多。整个分布式MapReduce框架的魅力在于，它屏蔽了分布式系统运算和存储中棘手的问题（fault tolerance, reliability, synchronization，availability），提供简单优雅的抽象。在上层使用者的视角，还是只需要实现简单的map函数和reduce函数，由整个mapReduce框架保证批处理流程正确执行。

我尝试根据google的mapreduce论文和MIT的6.824课程的go语言的mapreduce框架，实现一个简单的分布式mapreduce系统，看看要处理哪些问题。

#### 整体架构

![Alt](/images/mapreduce-2.jpg)

根据google原版论文的描述，整个系统架构如图，采用的是master-worker架构，有几个点：
1. 整个集群有两类节点，master node和worker node。
2. master节点保存整个mapreduce job的状态，同时负责调度所有的worker节点；
3. worker节点本身无状态，当启动一个worker节点时，它轮询地向主节点不断获取一个任务（task），有可能是map或者是reduce，获取后执行，执行成功后向报告给master，由master节点记录。
4. 用户和集群通信只通过主节点，worker节点不能直接访问。

一个核心的设计点在于单主和worker无状态化。集群状态只保存在主节点上，避免了各种一致性问题；虽然有单点问题，但主节点的work load很低（主要的负载都在worker节点），master挂掉的几率很小。同时，这样设计简化了主从间通信的复杂度（master和worker之间只要极少量语义的接口就可以完成协作）。

worker无状态化同时带来了扩展性：可以很方便的通过增加worker机器scale out，不需要担心各种复制，分片问题。

当然，single master还是会有单点问题，具体的容错保障机制在下文中会提及。

#### 状态机设计

一个mapreduce job的状态由主节点记录，主节点记录整个job的状态并记录每一个task的状态，当worker请求一个task时，主节点根据这几个状态分配一个合适的任务给worker。

状态机设计是关键一步，因为worker节点有可能由于各种各样的原因导致执行失败，甚至执行成功但没有报告给master。这时依赖master壮健的状态机推进来实现整个job的容错。根据论文的描述，我在实现时，使用的状态机如下：

一个mapreduce任务一共有5种状态：
- start：开始，待请求
- map phase：在执行map任务阶段
- map finished：map任务已执行完成，待执行reduce任务
- reduce phase：正在执行reduce任务
- finish：完成

状态机如图：

![Alt](/images/mapreduce-3.jpg)

worker节点也有状态机，是节点内部执行一个task的状态，这个状态比较简单：idle，in-progress，completed。同时，因为task是由master节点下发，所以master节点也会维护所有task的状态。

#### master和worker之间的通信协议设计

由于上文提及的整体架构的清晰（worker保持无状态），在google的论文描述中，master和worker之间的通信是可以做的很简单的。只有两个语义的接口。

一个是worker节点向master请求一个任务，这时master根据整个mapreduce job的状态，可能有三种response：1. 分配一个map task任务； 2. 分配一个reduce task任务； 3. 不分配任务，告诉worker进入idle状态。master分配后会将当前的任务状态记录下来（idle -> in-progress）。

当worker完成任务后，将中间结果写在文件系统（在google的实现是分布式文件系统，GFS）中，然后记录文件路径，并将完成情况上报给master，由master记录这个task的状态和这个intermediate文件名。同时，当worker完成任务后，会进入idle状态，此时隔一段时间向master轮询任务。

总结下来，master需要提供这两个语义的接口给worker节点：

1. `task get_task(worker)`
2. `report_task(task, execute_result)`

当然，在工业实现上，为了容错可能会做的更复杂，比如worker和master之间的心跳机制；或者允许集群重启恢复的check point机制。整体容错机制在下一节中详述。

#### fault tolerance

一个mapreduce任务可能需要成百上千个节点共同完成。所以整个集群必须有简单优雅的容错机制。

一个最常见的failure是worker节点挂掉或者和master节点的通信出现问题。mapreduce会引入master-worker之间的心跳机制，当master ping了之后收不到worker的回复，会认为worker已经挂掉，并将这个task状态更新为idle。

同时mapreduce是单主的集群，怎么对master节点的不可用做容错呢？一个做法是定期对master状态做check point，这个状态可以落盘到分布式文件系统中，下次启动时，读取check point继续任务。

#### 代码解释

了解整个系统架构和机制后，尝试做一个简单的实现。MIT的6.824提供一个的lab，可以基于这个框架一个go语言的最简版实现。关于课程的描述，可以看这里：https://pdos.csail.mit.edu/6.824/labs/lab-mr.html，只需要一个go runtime就可以做了，下面是主要代码：

Master节点：

Worker节点：

然后是上文提到的master节点提供给worker节点的第一个接口，获取一个task：`CreateTask`，master根据当前job的状态分配一个task给worker：

worker获取task之后，根据taskType（map / reduce）执行不同的func：

完成后，worker调用report接口通知master，master收到后记录状态，并同步更新整个job的状态：

### ref
- 《Designing Data-Intensive Applications》
- https://en.wikipedia.org/wiki/Batch_processing
- https://static.googleusercontent.com/media/research.google.com/en//archive/mapreduce-osdi04.pdf
- https://datawhatnow.com/batch-processing-mapreduce/#:~:text=Batch%20processing%20is%20an%20automated,the%20same%20or%20different%20database.
- https://www.cnblogs.com/fydeblog/p/12826673.html
