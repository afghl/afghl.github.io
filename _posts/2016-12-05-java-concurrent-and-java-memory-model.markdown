---
layout: post
title:  "从JMM层面说说Java并发（一） - 基础"
date:   2016-12-05 18:26:00 +0800
---

为什么要理解JMM（Java Memory Model）模型？在了解JMM之前，我们谈论Java并发的一些问题，如synchronized关键词、volatile关键词等问题时，总是在很高层的抽象解释它们的机制，这样难免有一些谬误。而JMM是Java从语言层面提供给程序员的心智模型，也是JVM的实现标准，在这层面解释并发问题，能保证正确性。

### 从硬件和编译器说起




### Java内存模型提供的抽象

- 主内存 / 工作内存
- happen-before机制

### 理解Happen-before机制
