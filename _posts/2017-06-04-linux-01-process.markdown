---
layout: post
title:  "Linux下排查问题常用指令（一） - 进程相关"
date:   2017-06-04 23:36:00 +0800
---

最近真是惭愧，很久没有写博客。一是进了新公司，工作太忙了；二是工作上已经压力也大了不少，业余时间就不想给自己太大压力，放纵自己懒一点。但是最近发现，业余时间学习，还是要系统的学，并且必须要有产出。所以接下来又会写一些博客，或者说学习笔记吧。

最近的学习方向是：线上环境出了问题能有清晰的排查问题的思路和套路。总结下来，除了经验略去不谈，最基础的是这几方面的知识：

- JVM 机制、原理、常用指令和分析方法
- WEB容器
- 操作系统
   - Linux相关
- TCP/IP协议

说来真是相当惭愧，想想自己已经在linux下工作已经快三年时间，还没系统的学过Linux，很多指令到用时都得百度一下，太业余了。为了显得专业一点，最近打算系统的学习操作系统和linux，当然，一些早就理解的知识就不再记笔记了。这系列文章来说说最简单的部分...Linux下排查问题常用指令，它们是怎么用的，信息怎么看。

### 预备知识 进程属性

在学习查看进程的指令之前，先了解进程有什么属性。进程的概念不再赘述了。先看看linux的进程的几个共同属性：

- PID 进程ID。
- PPID 父进程ID。
- UID 进程创建者的用户ID
- GID 创建者的groupID，GID一般不会用到，只是如果进程需要创建文件时，这个文件的group会继承这个groupID。

关于UID的例子：

用me用户创建一个vi进程，它的uid就是me的uid：

~~~
e@iZ94rxjfu2hZ:/home/you$ id
uid=1000(me) gid=1001(me) groups=1001(me),1000(admin)

me@iZ94rxjfu2hZ:/home/you$ vi test &
[2] 22644

me@iZ94rxjfu2hZ:/home/you$ ps -l | grep 22644
0 T  1000 22644 22608  0  80   0 - 10266 signal pts/2    00:00:00 vi
~~~

换个用户创建，就是该用户的uid：

~~~
me@iZ94rxjfu2hZ:/home/you$ su you
Password:

you@iZ94rxjfu2hZ:~$ id
uid=1001(you) gid=1002(you) groups=1002(you)

you@iZ94rxjfu2hZ:~$ vi test &
[1] 22671

you@iZ94rxjfu2hZ:~$ ps -l | grep 22671
0 T  1001 22671 22653  0  80   0 - 10266 signal pts/2    00:00:00 vi
~~~

注意：用sudo创建一个进程，UID会变成root：

~~~
you@iZ94rxjfu2hZ:~$ sudo vi test &
[2] 22680

you@iZ94rxjfu2hZ:~$ ps -aux | grep 22680
root     22680  0.0  0.0  65160  2020 pts/2    T    00:40   0:00 sudo vi test
~~~

### 参考

- http://linux.vbird.org/linux_basic/0440processcontrol.php
- 《Linux从入门到精通》
