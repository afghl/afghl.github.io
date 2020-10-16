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

### 分布式MapReduce

当从单机变成分布式环境后，情况将会变得难以想象的复杂。整个分布式MapReduce框架的魅力在于，它屏蔽了分布式系统运算和存储中棘手的问题（fault tolerance, reliability, synchronization  availability），提供简单优雅的抽象。在上层使用者的视角，还是只需要实现简单的map函数和reduce函数，由整个mapReduce框架保证批处理流程正确执行。

最起码，会有这样的问题：

当数据量大时，还会有这样的问题：



### ref
- https://en.wikipedia.org/wiki/Batch_processing
- https://static.googleusercontent.com/media/research.google.com/en//archive/mapreduce-osdi04.pdf
- https://datawhatnow.com/batch-processing-mapreduce/#:~:text=Batch%20processing%20is%20an%20automated,the%20same%20or%20different%20database.
