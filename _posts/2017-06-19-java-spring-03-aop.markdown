---
layout: post
title:  "学习Spring源码（三） AOP原理之实现篇"
date:   2017-06-19 22:04:00 +0800
---

[上一篇](/2017/06/15/java-spring-02-aop.html) 已经说了Java动态代理的相关实现和原理，Spring AOP的核心技术是动态代理，但是Spring里的AOP模块比这复杂得多，包括前置通知，返回通知等一系列实现，这一篇，有了动态代理的基础，我们来看看Spring AOP模块是怎么实现的。

- proxyfactoryBean, 封装代理对象的生成过程。
