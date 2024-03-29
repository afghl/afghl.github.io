---
title: "电商业务架构背后的Know-Why：订单、交易、TCC"
date: 2022-02-04 15:20:00 +0800
tags: [pattern, ecommerce, architecture]
---

业务的后台开发，过去的工作出彩点很多时候是：在完成业务需求的同时，弥补基础设施的不足。在近几年，随着底层 PaaS 的日益完善，这类的短板在变少：比如好几年前的数据库分库分表，可能需要一个中间件团队的几个 DBA 专门开发和维护。但现在很多云厂商的数据库，天然就是分片和主备容灾的。这是技术的复利效应，也是所有业务开发不得不思考的问题。

上有数字化浪潮峰值已过，下有基础设施完善导致大部分的业务架构知识和经验都在贬值，业务开发路在何方？我认为对于业务开发/架构师，（数字化过程里）做的事情是正确的将现实世界映射到计算机世界。所以很多时候，关于架构设计背后的思考，答案往往都来自：1) 业务领域；或者 2) 计算机，网络，分布式本身的原理。但真正重要的是其中的思考力。

通过从系统的设计（Know-How），思考和反推背后依据的原则和原理（Know-Why），锻炼思考力（也有人说第一性原理），可能是比较重要的。因为越本质的结论往往是越容易迁移的。

下面分享一些关于(电商)业务架构的思考和记录。

## 订单和交易

电商业务的核心是订单和交易。订单系统作为电商系统的“纽带”贯穿了整个电商系统的关键流程，也是大部分的业务复杂度的体现。

如果给订单这个实体下一个定义，它是 **买卖双方一次钱-物(或服务)交换的凭证和合同** ，至少承载两个功能：

1. 合同：包含钱物交换所需要的所有信息。包括物品，价格，金额，时间地点。
2. 状态流转：需要将线下的交换环节通过订单状态机建模到订单里。让这个交换环节可以数字化。

根据订单的这个定义，我们可以解释很多在交易，下单，订单系统的设计，比如：

### 1. 订单模型设计

订单的设计通常分为主子订单，其实更适合的说法应该是 “订单(Order) - 订单项(OrderLine)”，订单记录交易的合同信息和状态，可以说就是合同本身；订单项记录的是：这笔订单里所购买的具体商品（SKU）、数量和价格。

### 2. 拆单

既然订单的粒度是买卖双方一次交换，那么一笔订单的覆盖范围，应该是**一笔订单对应相同买卖双方的物流和资金流**。这解释了为什么需要拆单和怎样拆单：

1. 不同卖家的商品需要拆分到多笔订单，因为它们构成不同的资金流。
2. 库存在不同货仓的商品应拆分到多笔订单，因为它们的物流也不相同。
3. ...

### 3. 保持订单（状态）简单

在电商领域里，订单和物流、支付、售后等域是一个星型设计。除了部分需要用户/卖家主动确认的步骤外，很多的订单状态的流转来自于其他域（资金流、物流）的驱动。

正因为订单流转的权责来自其他领域，订单的状态的一个设计原则是**保持简单**。比如订单里有“支付中”的状态，可以理解为“当前订单流转的权责给到支付域，正在等待支付结果通知”。而“支付中”这个状态其实对应支付域里的一系列状态。

订单、交易、支付等涉及金额的关键系统；稳定性和防范资损风险的优先级，应在业务创新之上，应该保持订单的职责单一。

同时，订单的定义也可以指导一些业务和场景应如何落地：

### 1. 不同的订单类型：拼团、O2O、货到付款

不同的业务场景下，可能需要调整订单状态机：

比如拼团玩法，可能需要在“支付中”的状态前加入“拼团中”的状态。
再如 O2O 业务中，因为配送/服务过程对客户体验至关重要，所以可能需要将配送的状态建模到订单状态里。（例如饿了么的订单，就有“骑手待接单”，“配送中”这些状态）。
COD（货到付款）则支付环节相应转移到订单配送之后，而过程中所有与款项相关的逻辑变为只操作金额数字，不对结算和账户进行打退款操作。

常见的实现思路有两种：

1. 中台+业务前台的做法：中台保留基本的业务状态机，开放业务定制拦截状态往下流转，相当于将订单流转权责移交至业务前台。双方通过异步+补偿方式保证一致性。
2. 无法通过 1 的方法定制的业务流程，则需要扩展订单类型，新增不同的状态机，完成业务流程。考量点是实现成本和业务价值的权衡。

### 2. 为什么所有金额计算要放在下单

不同的业务玩法，可能会导致资金流的改动。比如分佣带货（这是常见的 CPS 模式：达人通过推广链接引流到特定商品，达成交易后，通过佣金的方法获得收益）：

![Alt](/images/cps_1.jpg)

可以看到，资金流会以分佣的形式给到带货达人。这样的业务模式下，有两种选择：1) 在订单结算分账时，通过快照信息计算佣金；2) 在订单生成的时候，就将佣金金额计算好，在分账的时候再获取。

在这两种方法中，第二种方法是更好的方法和选型；第一种通过快照的方式是存在资损风险的。它违背了“订单”的基本定义：所有后续履约所需要用到的信息（包括分佣佣金），都应该在创建订单的时候就确认并记录。而在技术上，我们使用分布式事务的方式，保证下单过程的事务一致性。

关于一致性，下面会说说下单和其他场景的一致性。

## 下单与订单系统、一致性选型

上文中说到在电商下单时，我们会使用分布式事务保证一致性。常见的架构设计是将整个订单页和下单接口独立为一个微服务(buy)，运行一个 TCC 协议的分布式事务，分布式一致性的选型很多，TCC 是其中一种：

![Alt](/images/dis_tran.jpg)

在下单这个场景中选择一致性模型，我们的思考点至少有这几个：

1. 原子性和隔离性：下单的业务，所有资源的操作需要一起成功，一起失败，也就是需要分布式原子性。则我们不能使用最终一致性的模型，只能使用 TCC 或 2PC，3PC 这样的事务。
2. 同步 / 异步：同步的本质就是加锁，锁住分布式事务里所需的资源，同时阻塞等待整个事务处理完成。这样的开销太大，吞吐量很低。而 TCC 是异步执行，在过程中并不需要长时间锁定资源。

关于事务的选型，实现和容错，是一个值得单独讨论的话题，目前我们先关注 TCC 的实现。

![Alt](/images/tcc.jpg)

在这里，Buy 应用担任的是分布式 transition manager 的角色，负责将事务的执行和推进。在实现时，有几个值得注意的点：

- 空回滚：当某些参与者在第一阶段未收到尝试请求时，系统将取消整个事务。如果一个失败或未执行尝试操作的参与者接收到取消请求，则需要进行空回滚操作。
- 幂等：当出现网络超时等异常情况时，在第二阶段会重复调用确认和取消方法。因此，这两种方法的实现必须是幂等的。
- 避免资源悬挂：网络异常扰乱了两个阶段的执行顺序，使得参与方端较晚地收到尝试请求而早于取消请求。为确保事务正确性，取消操作将执行空回滚，并且不会执行尝试操作。
- 锁定资源：Try 过程中锁定的资源，在整个事务过程中对外不可见。（**这里不同于阻塞访问**）

有一些分布式事务框架（Seata）提供 TCC 的抽象。但其实实现的大部分复杂度是在各个原子事务的方法实现。

# REF

- https://mp.weixin.qq.com/s?__biz=MzU0OTE4MzYzMw==&mid=2247488518&idx=1&sn=336409f91801c1c6617ccc9d7f67fa24&chksm=fbb29df8ccc514ee3c637ed39b0afe6222e5bf8531d5d78de3ab6d3b68f0c3dab8470be20a03&scene=27
