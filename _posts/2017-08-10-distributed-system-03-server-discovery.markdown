---
layout: post
title:  "分布式系统 - 服务治理（三） - 服务注册 & 发现"
date:   2017-08-10 22:13:00 +0800
---

顺着[上一篇文章](/2017/07/30/distributed-system-02-load-balance.html)的思路，服务路由一般是这么做的：有一个服务注册中心，它知道网络内所有节点的情况，暴露restful接口（甚至是长连接）给各个消费方消费。

路由的前置条件是服务注册中心知道所有节点的情况。那么服务注册中心怎么维护所有节点情况的？这篇文章就来讨论一下这个问题。

### 常见方案

#### 内网DNS

DNS可以理解成是一个域名和IP的hash，客户端写上服务提供方的host name，这个host name指向哪一个IP，在DNS服务器里配置。听上去很简单粗暴。

实际上，DNS的确是小规模系统的杀器。小系统里服务少，服务间的依赖关系不复杂而且节点变化较少，DNS能很好的满足要求。

但是当系统规模变大时，DNS有两个缺点：

1. DNS需要人肉配置。就算做个脚本完成自动化配置，也需要不低的开发成本。

2. 配置到生效之间，延迟较大。

在服务的动态性很强的微服务环境，DNS就不适合了。

#### 自注册

这个方案也很简单：服务注册中心开放接口给服务提交自己的信息（IP、port等）。在每个实例启动时，调用这个接口上传自己的信息，然后服务注册中心保存。

![Alt](/images/Richardson-microservices-part4-4_self-registration-pattern.png)

那实例怎么知道在何时，向谁，调用哪个API接口呢？答：SDK。没错，需要SDK，又会引入开发成本和升级成本的问题了。

#### 第三方注册

避免服务自注册的一个方法是：加入一个新服务注册进程，由它检测服务的启动和健康状况，并上报服务中心。

![Alt](/images/Richardson-microservices-part4-5_third-party-pattern.png)

### 还有一些问题

#### 心跳的保持

心跳的实现本来很简单：约定个端口和返回内容即可，但有这么一个问题：

- 有三个角色：服务调用方，服务提供方，服务注册中心，心跳应该由哪两者保持？

#### 健康的语义

还是心跳的问题。一般的心跳只是一个简单的echo。这样的话，检测的实际上是网络连接状况。但有一些情况下，明明心跳是正常的，但是请求却不能正确处理。

为什么？比如说：一个服务重度依赖redis，某一个和redis连接挂了，但是这时，因为它和其他调用方的连接没挂，任何调用方和它的心跳都返回正常。

为了应对这种特殊的情况，就需要让业务团队定义健康的语义：框架开放心跳接口，让业务团队重写，让业务团队定义每个服务的健康。

#### graceful shutdown

服务的优雅退出问题。服务在下线的时候分两步：

- 调用注册中心的unregistry接口，通知服务注册中心。
- 注册中心将这个服务踢掉，并把这个变更推给相关的调用方。

考虑一个问题，这两步之间存在一定的延迟，即使是几十毫秒，也可能有上百个请求。如何保证这些请求不丢？

一个暴力而最简单的做法是，在调用unregistry接口之后，等两秒，再退出JVM。

另一个方法是引入生命周期，并把管理一个服务的生命周期的责任交给注册中心。

### 参考

- https://www.nginx.com/blog/service-discovery-in-a-microservices-architecture/
- https://technologyconversations.com/2015/09/08/service-discovery-zookeeper-vs-etcd-vs-consul/
- http://www.infoq.com/cn/articles/background-architecture-and-solutions-of-service-discovery
- 《HighOps-on-Service-Discovery》
- https://en.wikipedia.org/wiki/Domain_Name_System
