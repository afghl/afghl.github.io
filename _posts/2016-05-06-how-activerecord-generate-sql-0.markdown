---
layout: post
title:  "ActiveRecod如何拼出一句Sql？—— （零）刚好够用的关系代数基础"
date:   2016-05-06 12:11:00 +0800
---

### 前言

介绍rails ActiveRecod的神奇， 任何方便的东西背后都包含大量的技术含量。 说说arel和关系代数的关系。
这系列的备用知识  对rails有一定了解，对sql有一定了解。

### 关系代数（Relational algebra）

介绍关系代数之前，可以从远一点扯起。

(正如计算机编译器使用自动状态机和上下文无关语法作为理论武器，关系型数据库使用关系代数，规定了我们能对数据库中的表和数据做何种操作，获得哪些结果。)