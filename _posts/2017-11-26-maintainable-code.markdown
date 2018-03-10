---
layout: post
title:  "写可维护的项目（代码）"
date:   2017-11-26 16:18:00 +0800
---

最近有机会一个人负责、主导一个项目。其中一项工作，就是需要从零开始写代码做一个code project。在整个过程中，我一直在学习和思考怎么写可维护的代码，写一个可以 **一直维护，一直迭代，却把复杂度控制在一定的范围之内** 的项目。

为什么我对这事感兴趣？因为看过太多悲剧的产生：在我参与的所有代码项目里（我参与工作以来一直写的是业务系统），几乎全部都会陷入这样的境地：对复杂度完全没有把控，对新增的需求，新增的领域知识，只能通过新增模型，新增接口，新增面条式的代码完成。直到复杂度增加到后人无法理解的地步 -- 重写项目。

我们是可以做的更好的。下面说说我的想法和经验。

### 起码，分个层（建立多层次的抽象）

现在的项目一般会使用第三方框架，业务开发人员的代码相当于在一个框架里填入自己的业务逻辑。也就是说，这种项目天然的有来自框架的抽象，天然的有分层。

但是除此之外，业务开发人员的代码基本上是“事务脚本”，也就是将这件接口要做什么，从头到脚写出来，通常是这样：在数据库里拉出什么对象，改里面的某些值，然后在调用持久层的方法放回去。这样的问题是什么？是 **缺乏抽象层次的代码不能表现领域逻辑**。这样的代码如果人员调动频繁，而且缺乏文档和注释，这些代码的意图就会难以理解。

更麻烦的情况是，将技术细节（比如访问mq中间件，redis的访问细节）耦合在这种事务脚本里，导致代码更难维护。

正确的代码分层和好的OO设计可以很大程度的解决这个问题。它的思想也和其他领域的分层类似：每一层专注在解决自己的问题，下层对上层提供抽象。

很多ddd的书里喜欢把代码分层这样设计：

![Alt](/images/maintainable-code-0.gif)

在学了一些DDD的方法和理念之后，在我最近的这个项目中，项目采用这样的架构：

![Alt](/images/maintainable-code-1.png)

- 外部依赖层：封装对外部领域的依赖。包括：接口，外部DTO，transformer。（为什么要封装？该怎样封装？可以看 #怎样访问外部 一节）
- 提供给外部的接口层：提供给外部调用的层次。这层的角色像是项目里的协调者，一般会做这些事：
   - 向下调用领域层的服务，完成对领域对象的操作。
   - 调用redis，Mq组件的方法，完成除了业务逻辑之外支路逻辑。
   - 发布领域事件
- 领域层：封装重要的领域逻辑。在理想的情况下，这一层可以完全用model来表示，但在实现上，除了model之外，还有很多的service对象。具体代码下详。
- 基础设施层：封装项目对其他基础设施的依赖，如：redis，mq，dao。另外一些util的类也会在这一层。

### 用模型模型表现领域逻辑

先来说说领域层。业务逻辑可以看成是领域模型的相互协作和影响。正确建模，然后在代码里把模型之间的关系显式的表达出来，是提高整个项目可维护性的第一步。

#### 让模型有表达的能力

先看几个bad taste。以我最近写的项目，店铺配送举例：一个店铺有配送费A、配送费B字段，且店铺的配送状态有可能改变，如果配送状态为A，则给外部返回配送费A，如果配送状态为B，则给外部返回B。

我看过很多bad taste的代码，看起来会是这样：

~~~ java

class Delivery {
    private int deliveryFeeA;
    private int deliveryFeeB;
    private DeliveryStatus status;
}

class DeliveryTransformer {
    public static DeliveryDTO transform(Delivery input) {
        DeliveryDTO output = new DeliveryDTO();
        // ...

        if (input.getStatus() == DeliveryStatus.StatusA) {
            output.setDeliveryFee(input.getDeliveryFeeA());
        } else if (input.getStatus() == DeliveryStatus.StatusB) {
            output.setDeliveryFee(input.getDeliveryFeeB());
        }

        return output;
    }
}

~~~

这段代码的问题是：取配送费A还是配送费B的逻辑，实际上是 **非常重要的领域逻辑**。而这代码却将这段逻辑放在一个猥琐的角落，甚至跑出了领域层，到了外部接口层的transformer上去了。产生的问题不仅仅是代码复用差，更重要的是领域逻辑被淹没了。

修改方法就是把这段逻辑放在model层，也就是领域层：

~~~ java

class Delivery {
    private int deliveryFeeA;
    private int deliveryFeeB;
    private DeliveryStatus status;

    public int getDeliveryFee() {
        return status == DeliveryStatus.StatusA ? deliveryFeeA : deliveryFeeB;
    }
}

class DeliveryTransformer {
    public static DeliveryDTO transform(Delivery input) {
        DeliveryDTO output = new DeliveryDTO();
        // ...
        output.setDeliveryFee(input.getDeliveryFee());
        return output;
    }
}

~~~

上面的例子非常简单，思路就是将属于领域层的逻辑收归到model，这样的小重构使代码变得可复用，可维护。当领域层能表达足够多的领域逻辑时，实现新的需求变成了：调整 / 修改领域模型，使它更能描述当前领域。（至于怎么挖掘和发现模型，怎样对领域建模，不在本文的讨论范围，可以移步《领域驱动设计》）。

接下来我们讨论，有什么逻辑应该移动到领域模型内：

1. 状态类表述。模型得起码知道自己的类型 / 状态 / 属性。如上述例子。重构的方法也比较简单。
2. 关键动作。领域模型能自己完成的关键动作。
3. tell。有时，别的模型，或service对象，需要借助当前模型的领域知识。这样的领域知识，也应该封装在model里。举个例子：

   对审核流任务建模，一个重要的领域逻辑是：当这个任务在生命周期的什么阶段，谁可以对这个任务有怎样的操作？直接上代码：

   ~~~ java

   class AuditJob {
       private AuditStatus status;
   }

   class AuditService {
       public void submitAction(Long jobId, User user, Action action, String remark) {
           AuditJob job = AuditJobRepository.find(jobId);

           if (job == null) {
               throw new NotFoundException();
           }

           if (job.getStatus() == AuditStatus.Success || job.getStatus() == AuditStatus.Fail) {
               throw new ServiceException();
           }

           if (job.getStatus() != AuditStatus.Initiailize && user.getRole() == UserRole.User) {
               throw new ServiceException();
           }

           // ...
       }
   }

   ~~~

   上面代码中，AuditJob这个领域模型有足够的知识告诉上层，什么角色，什么操作，是允许的。这样的判断应该封装在model里：

   ~~~ java

   class AuditJob {
       private AuditStatus status;

       public boolean actionIsValid(UserRole role, Action action) {
           if (this.isFinished()) {
               return false;
           }

           if (role == UserRole.User && status == AuditStatus.Initiailize) {
               return false;
           }

           // ...
       }

       public boolean isFinished() {
           return status == AuditStatus.Success || status == AuditStatus.Fail;
       }
   }

   class AuditService {
       public void submitAction(Long jobId, User user, Action action, String remark) {
           AuditJob job = AuditJobRepository.find(jobId);

           if (job == null) {
               throw new NotFoundException();
           }

           if (!job.actionIsValid(user.getRole(), action)) {
               throw new ServiceException();
           }

           // ...
       }
   }

   ~~~



#### 领域模型能完成什么动作？

### 使用ddd构建聚合的概念

聚合的概念，无论是在建模上，还是在代码上，都是一个对控制复杂度，提高代码表达能力的非常有效的抽象。

#### 用代码表现聚合

#### 封装聚合内模型的互动

#### 校验整个聚合

#### 保存聚合

#### 使用版本号 保证聚合的一致性

### 用facade模式控制外部访问
### 怎样访问外部
### 考虑拓展性（问问：如果xx怎么办？）
### 不再写面条式的代码

### 使用领域事件分离支路逻辑

一般来说，支路逻辑是可以异步化的，这样分离之后更容易实现异步化


### 参考

- 《企业应用架构模式》
- 《领域驱动设计》
- 《实现领域驱动设计》
