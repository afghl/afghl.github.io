---
title:  "分布式系统 - 单机transactions"
date:   2018-04-09 23:07:00 +0800
tags: [distribute-system transaction]
---

单机事务（本文会简称为事务），区分于分布式事务，可以大致这样定义：单机事务的场景里，客户端可以有多个，但提供写入操作的节点只有一个，单机就是提供写入的服务器的单机。事务是数据库提供的最强大的保证：单机事务中，最复杂的是并发问题，随时有可能出现多个client同时修改同一个记录的情况，而正是利用不同的事务的隔离级别的保证，使业务开发人员可以规避掉一部分的并发问题，大大简化application层的编程模型。

单机事务中能出现什么并发问题？为什么要有不同的隔离级别？每个隔离级别解决什么问题，又是怎么实现的呢？接下来是在《Designing Data-Intensive Applications》一书中关于这些问题的一点笔记。

### 理清ACID

ACID是数据库事务的四个保证： Atomicity（原子性）, Consistency（一致性）, Isolation（隔离性）, Durability（持久性）。但这四点到底说了什么？我们可以从中知道，哪些我们希望不要发生的情况绝不会发生？其实什么都看不出来。这几个名字像所有口号一样被过分滥用而失去原意了。

我们可以重新看看这四点，理清事务的特点（或者说起码的保证）到底是什么。

#### Atomicity（原子性）

原子意为不能拆分的最小单位。事务有原子性，也就是事务的所有操作要么一起成功，要么一起失败。如果事务中有一步失败，整个事务会回滚到事务开始之前，就像整个事务没有执行过一样。

且在事务执行过程中，事务外部的请求不能看到这个事务做的改动。

#### Consistency（一致性）

ACID里的C是一个含糊不清的词，要知道在单机事务中，数据只有一个copy，那么到底是什么和什么一致？

ACID里的一致性和分布式系统里的一致性是两个概念，它说的是：只要你正确使用事务，那么无论在任何时候查看数据，总是 **满足不变的一致性条件**。比如信用卡里的可用余额和已用金额之和总是一个固定值。

显然，数据库本身不能定义什么数据是满足所谓的一致性的，这应该是application层的责任。而且一致性也不是数据库提供的根本的保证，它是application层在利用数据库的Atomicity，Isolation，Durability能获得的一个保证。

#### Isolation（隔离性）

数据库有可能被不同的客户端同时操作同一条数据，隔离性的意思是多个事务之间不会互相影响，就算它们操作同一条数据。也可以说：**保证当多个客户端并发执行时，其结果和它们串行执行的结果一致**。

但事实是，在实践中，并不能完全保证隔离性（隔离程度最高级别的serializable通常不会被使用）。而是让用户权衡性能和安全问题，选择不同的隔离级别。

#### Durability（持久性）

持久性意为：只要事务成功commit，那么提交的数据就会永久写到DB中，不会丢失。

### 事务与隔离级别

最理想的情况下，使用事务就能防止所有并发问题。但是数据库的设计者又将事务划分了多个隔离级别，让用户选择。我们可以认为，隔离级别越弱，提供的ACID保证也越弱，也就是有越多的并发BUG没有解决。

可惜的是，在实践中，由于性能问题，我们一般不会选择最强的serializable隔离级别。所以不同的隔离级别有可能有什么并发问题，值得好好讨论一下。

#### Read Committed（提交读）

Read Committed，提供两点保证：

- 当一个client要读取数据时，只能读取到已经提交（committed）的数据。
- 当一个client要写入数据时，只能重写（overwrite）已经提交的数据。

这两点保证可以防止脏读（dirty read）和脏写（dirty write）。

![Alt](/images/transaction-1.png)

如图，User 1使用了事务写入x=3，y=3。在事务提交之前，即使set x = 3的写入已经执行，User 2读取到的还是x = 2的值。这样的case就是避免了脏读。（不就是事务的隔离性么？）

脏写比脏读要复杂一些，假设这是一个事务还没提交的写入被其他事务重写了：

![Alt](/images/transaction-2.png)

如图可见，两个用户Alice和Bob都执行相同的事务，当Alice对Listings表的写入在提交前就被Bob的写入覆盖了，Bob对Invoices的写入同理，最后，两个事务的写入都错误，显然不满足Consistency的。

Read Committed的第二点保证杜绝了脏写的问题，其实现是对写入的行加锁，直到commit只有才释放锁，其他事务如果要写入相同的行，就需要阻塞等待这个锁。

#### Repeatable Read（可重复读）

Read Committed看上去很美好，但其实还有一些并发问题没有解决，比如：read skew：

![Alt](/images/transaction-3.png)

如图所示，假设Alice总余额有1000，在Account 1和Account 2中各有500，而她读取两个账号，中间刚好执行了一次事务，那么看起来，就有100的余额不翼而飞。这样的case可以称为read skew，这在Read Committed隔离级别里是允许的，因为这个场景没有违反它提供的两点保证。但在一些场景里，这样的问题可能会导致严重后果：

- 比如有一个长达几分钟的query，在它执行期间，有无数个事务修改了它的数据，所以它读取到的是哪个时刻的数据呢？
- 当需要备份数据库时，可能需要对整个库做一个快照，这样的快照也会长达起码数分钟甚至更久。在它执行期间，会有同样的问题，那么无论你以哪个时间点为准，都会造成数据不准确。

当需要思考这些问题时，显然，Read Committed是不符合隔离性的。所以需要比它更强的隔离级别，解决这个问题：Repeatable Read（可重复读）。

它比Read Committed新增一点保证：当开启Repeatable Read事务时，它读到的数据是事务开始的时刻，已经commit到数据库的数据，即使在执行过程中，其它事务修改了记录，当前的事务都不会读到。

它的实现是：多版本控制（MVCC）。以pg的实现为例说明：

对于数据库中的一行，其实数据库内部存了多份数据，且在数据库实现内部，一次update其实会被转换为一次create + delete，**且每个事务会被分配到一个单调递增的事务id，事务不会读取到比它事务id更高的数据版本**：

![Alt](/images/transaction-4.png)

Repeatable Read（可重复读）是mqsql默认的隔离级别。

### 还有哪些并发Bug

上面讨论了两种隔离级别，也讨论了它们哪些并发bug，还有几个问题没有解决。

#### lost updates

通常是，从数据库里读取一行数据，然后根据这行数据修改某个值（比如a = a + 1，是在a的基础上+1，a = 2则不算这种case），然后更新这一行，这样的操作可以称为read-modify-write操作。

以 执行a = a + 1这样的操作为例子，如果有两个事务并发进行，那么就有可能丢失其中一个事务的更新：

![Alt](/images/transaction-5.png)

lost updates问题当然可以通过最高隔离级别的serializable避免。但还有一些比较tricky的方法的可以做：

- Atomic write operations

   把sql写成这样：`UPDATE counters SET value = value + 1 WHERE key = 'foo';`，在数据库里完成计算。这样的sql是原子的，但问题是，使用这样的sql，接口很难写成幂等。

- Explicit locking（悲观锁）

   在select语句里加入`for update`，告诉数据库你这句select语句需要等一个写锁。

   一般来说，lost updates的场景总是在做这三件事：1. 读出来（select），2. 更改（change），3. 更新（update）。不难看出，对于同一条记录，这个过程是分布式互斥的，也就是同时只有一个线程能执行。所以，如果1和3之间，也就是第二步会耗时非常长的时间，使用悲观锁会有严重的性能问题。

- Compare-and-set（乐观锁）

   把sql写成这样：`UPDATE wiki_pages SET content = 'new content' WHERE id = 1234 AND content = 'old content';`。注意在where子句里，加入了对原来的值`content`的判断，这样如果执行这条语句时已经被修改成其他的值，这句sql会执行失败。

#### write skew

write skew和lost updates的场景类似，直接看例子：

![Alt](/images/transaction-6.png)

两个事务做了同样的事，可分为三步：

1. 对doctors表进行`select count(*)`操作。
2. 根据第一步返回的结果，对doctors表进行一些修改。
3. 执行update语句进行更新。

然而，上图中的两个更新当然是race condition，因为如果两个事务顺序执行，**那么后执行的事务对`current_on_call >= 2`的判断将会是false**。

write skew和lost updates场景的三步类似，只有第二步不同，它是根据query出来的结果执行特定的逻辑，再更新数据库（而lost updates场景是直接更新query出来的结果）。

所以，write skew的解决方法也更加受限。乐观锁和悲观锁都不能用在这样的场景，只能使用对整个事务加锁（在第一步的select语句加上`for update`）。

#### phantom

phantom是write skew更诡异的变种。想想在上图的例子里，第一次`select count(*)`语句找出来的是0，那么即使加了`for update`，也锁不了任何行。那么锁就会失效。

### Serializability

即使在Repeatable Read的隔离级别里，还是有很多并发bug需要谨慎处理。最后再来看一个真正完全满足ACID的隔离级别：Serializability。它能真正避免所有并发问题。常见的实现有两种：

#### 真正的单线程执行

最简单的方法就是，真正让一个线程执行所有query。这是redis的做法。

#### 2PL

2PL是做这样的事：

- 如果事务A读取到一行，而事务B需要写入，那么事务B必须阻塞等待事务A完成。
- 如果事务A写入一行，而事务B需要读取，那么事务B必须阻塞等待事务A完成。

它的实现是数据库的每一行都有一个锁，且这个锁有两种模式：shared mode，exclusive mode。

### 参考

- 《Designing Data-Intensive Applications》
