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

~~~ shell
e@iZ94rxjfu2hZ:/home/you$ id
uid=1000(me) gid=1001(me) groups=1001(me),1000(admin)

me@iZ94rxjfu2hZ:/home/you$ vi test &
[2] 22644

me@iZ94rxjfu2hZ:/home/you$ ps -l | grep 22644
0 T  1000 22644 22608  0  80   0 - 10266 signal pts/2    00:00:00 vi
~~~

换个用户创建，就是该用户的uid：

~~~ shell
me@iZ94rxjfu2hZ:/home/you$ su you
Password:

you@iZ94rxjfu2hZ:~$ id
uid=1001(you) gid=1002(you) groups=1002(you)

you@iZ94rxjfu2hZ:~$ vi test &
[1] 22671

you@iZ94rxjfu2hZ:~$ ps -l | grep 22671
0 T  1001 22671 22653  0  80   0 - 10266 signal pts/2    00:00:00 vi
~~~

注意：用sudo创建一个进程，UID会变成root的UID：

~~~ shell
you@iZ94rxjfu2hZ:~$ sudo vi test &
[2] 22680

you@iZ94rxjfu2hZ:~$ ps -aux | grep 22680
root     22680  0.0  0.0  65160  2020 pts/2    T    00:40   0:00 sudo vi test
~~~

### 查看进程属性的指令

有了以上的基础知识，来看看查看进程属性的指令。

#### ps

ps是最基础的查看进程的命令。它可以列出正在运行的进程，看看它的参数：

- -A 列出所有的进程。
- -a 列出不与terminal相关的进程。
- -u 有效使用者相关的进程。
- x 列出较齐全的信息。
- l 列出更多信息。

普通的ps指令只提供很少的信息，一般会用这两个命令：

1. `ps -l`：列出当前shell上下文的进程，并且用详细格式打印。
2. `ps aux`：观察系统所有进程。
3. `ps -ef`：观察系统的所有进程。列出PPID，C这些字段。

`ps -l`的示例：

~~~ shell
me@iZ94rxjfu2hZ:~$ ps -l | head -n2
F S   UID   PID  PPID  C PRI  NI ADDR SZ WCHAN  TTY          TIME CMD
0 S  1000 29946 29945  1  80   0 -  5691 wait   pts/2    00:00:00 bash
~~~

看看它的列：

- F：代表這個程序旗標 (process flags)，說明這個程序的總結權限，常見號碼有：
   - 若為 4 表示此程序的權限為 root；
   - 若為 1 則表示此子程序僅進行複製(fork)而沒有實際執行(exec)。
- S：代表這個程序的狀態 (STAT)，主要的狀態有：
   - R (Running)：該程式正在運作中；
   - S (Sleep)：該程式目前正在睡眠狀態(idle)，但可以被喚醒(signal)。
   - D ：不可被喚醒的睡眠狀態，通常這支程式可能在等待 I/O 的情況(ex>列印)
   - T ：停止狀態(stop)，可能是在工作控制(背景暫停)或除錯 (traced) 狀態；
   - Z (Zombie)：僵屍狀態，程序已經終止但卻無法被移除至記憶體外。
- UID/PID/PPID：代表『此程序被該 UID 所擁有/程序的 PID 號碼/此程序的父程序 PID 號碼』
- C：代表 CPU 使用率，單位為百分比；
- PRI/NI：Priority/Nice 的縮寫，代表此程序被 CPU 所執行的優先順序，數值越小代表該程序越快被 CPU 執行。
- ADDR：ADDR 是 kernel function，指出該程序在記憶體的哪個部分，如果是個 running 的程序，一般就會顯示『 - 』。
- SZ：进程用了多少内存。
- WCHAN：表示目前程序是否運作中，同樣的， 若為 - 表示正在運作中。
- TTY：登入者的終端機位置，若為遠端登入則使用動態終端介面 (pts/n)；
- TIME：使用掉的 CPU 時間，注意，是此程序實際花費 CPU 運作的時間，而不是系統時間；
- CMD：就是 command 的縮寫，造成此程序的觸發程式之指令為何。

`ps aux`的示例：

~~~ shell
me@iZ94rxjfu2hZ:~$ ps aux | head -n2
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.1  33372  2620 ?        Ss   Feb14   0:01 /sbin/init
~~~

只说明几个不明显的列：

- VSZ：该进程占用的虚拟内存数（Kb）。
- RSS：该进程占用的实际内存数（Kb）。
- STAT：同`ps -l`的S列。
- TTY：該 process 是在那個終端機上面運作，若與終端機無關則顯示 ?，另外， tty1-tty6 是本機上面的登入者程序，若為 pts/0 等等的，則表示為由網路連接進主機的程序。

#### top



### 参考

- http://linux.vbird.org/linux_basic/0440processcontrol.php
- 《Linux从入门到精通》
