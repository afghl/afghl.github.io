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



#### 健康的语义

#### graceful shutdown


### 参考

- https://www.nginx.com/blog/service-discovery-in-a-microservices-architecture/
- https://technologyconversations.com/2015/09/08/service-discovery-zookeeper-vs-etcd-vs-consul/
- http://www.infoq.com/cn/articles/background-architecture-and-solutions-of-service-discovery
- 《HighOps-on-Service-Discovery》
- https://en.wikipedia.org/wiki/Domain_Name_System
