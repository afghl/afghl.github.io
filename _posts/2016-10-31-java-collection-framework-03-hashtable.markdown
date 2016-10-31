---
layout: post
title:  "Java集合框架源码解析（三） - HashTable"
date:   2016-10-30 11:54:00 +0800
---

说完List的几个实现，下面来说说Map系列的类。

首先看看Map接口定义的方法：

~~~ java

~~~

可看出，Map定义的就是一个“key-value键值对”的字典，它的用法不必赘言。HashTable实现了Map接口，它是使用一个哈希表实现的。
