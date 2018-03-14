---

title:  "Linux下排查问题常用指令（二） - 机器状态相关"
date:   2017-06-08 08:51:00 +0800
---

接上篇。第一篇说了查看进程状态相关的指令，这一篇来看看查看机器状态相关的指令（相当于windows下的资源管理器）。

### 相关指令

#### free

从最简单的开始，查看内存使用的指令：free。示例：

~~~ sh
me@iZ94rxjfu2hZ:~$ free -g
             total       used       free     shared    buffers     cached
Mem:             1          1          0          0          0          0
-/+ buffers/cache:          0          0
Swap:            0          0          0
~~~

输入-g代表以Gbytes作为单位显示。可以看到这台机的内存已经快用完了。以我了解，这里的Swap字段如果超过0，说明内存已经用完了，操作系统在用Swap技术以磁盘作为虚拟内存使用，这时机器会变得非常慢，一般來說， swap 最好不要被使用。

#### uname

uname也很简单，可看一些kernel的信息：

~~~ sh
me@iZ94rxjfu2hZ:~$ uname -a
Linux iZ94rxjfu2hZ 3.13.0-32-generic #57-Ubuntu SMP Tue Jul 15 03:51:08 UTC 2014 x86_64 x86_64 x86_64 GNU/Linux
~~~

#### uptime

uptime：觀察系統啟動時間與工作負載。就是顯示出目前系統已經開機多久的時間，以及 1, 5, 15 分鐘的平均負載。

~~~ sh
me@iZ94rxjfu2hZ:~$ uptime
 09:15:45 up 113 days, 23:34,  1 user,  load average: 0.03, 0.03, 0.05
~~~

#### lsof

lsof，list open files的意思。列出被程序所開啟的檔案檔名。它的参数是：

- -a  ：多項資料需要『同時成立』才顯示出結果時，相当于and。
- -U  ：僅列出 Unix like 系統的 socket 檔案類型；
- -u  ：後面接 username，列出該使用者相關程序所開啟的檔案；
- +d  ：後面接目錄，亦即找出某個目錄底下已經被開啟的檔案！

示例：

列出me用户下的进程使用的文件：

~~~ shell
me@iZ94rxjfu2hZ:~$ lsof -u me| head -n 2
COMMAND   PID USER   FD      TYPE             DEVICE SIZE/OFF     NODE NAME
java     1390   me  cwd       DIR              202,1     4096   527145 /home/me/repos/moments
~~~

FD、TYPE、DEVICE、NODE这几栏的意义不详，待补充。

#### netstat

netstat：监控和追踪网络和其他资源的变化。它的一些参数：

- -a  ：將目前系統上所有的連線、監聽、Socket 資料都列出來
- -t  ：列出 tcp 網路封包的資料
- -u  ：列出 udp 網路封包的資料
- -n  ：不以程序的服務名稱，以埠號 (port number) 來顯示；
- -l  ：列出目前正在網路監聽 (listen) 的服務；
- -p  ：列出該網路服務的程序 PID

一个非常好用的指令，可以列出本地正在监听哪些端口，哪些进程在收到请求，示例：

列出正在监听各种端口的所有进程，并列出PID号：

~~~ sh
me@iZ94rxjfu2hZ:~$ netstat -tupl
(Not all processes could be identified, non-owned process info
 will not be shown, you would have to be root to see it all.)
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 *:9090                  *:*                     LISTEN      1458/java
tcp        0      0 *:http                  *:*                     LISTEN      -
tcp        0      0 *:56789                 *:*                     LISTEN      -
tcp6       0      0 [::]:3000               [::]:*                  LISTEN      1570/node
tcp6       0      0 [::]:3001               [::]:*                  LISTEN      1513/node
udp        0      0 112.74.28.115:ntp       *:*                                 -
udp        0      0 iZ94rxjfu2hZ:ntp        *:*                                 -
udp        0      0 localhost:ntp           *:*                                 -
udp        0      0 *:ntp                   *:*                                 -
udp6       0      0 [::]:ntp                [::]:*                              -
~~~

这样就可以看到3001端口被一个PID为1513的node进程监听，9090端口被一个PID为1458的java进程监听。

在网络篇再详细介绍下这个指令吧。

#### vmstat

vmstat：查看机器的输入输出变化，这些输入输出主要有几部分：

1. CPU
2. 内存
3. 硬盘

看看各项都是怎么呈现的：

~~~
me@iZ94rxjfu2hZ:~$ vmstat
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 3  0      0 542860 136728 381760    0    0     0     6    4    4  1  1 98  0  0
~~~

- procs：进程数。r ：等待運作中的程序數量；b：不可被喚醒的程序數量。這兩個項目越多，代表系統越忙碌。
- memory：顾名思义，内存情况。swpd：虛擬記憶體被使用的容量； free：未被使用的記憶體容量； buff：用於緩衝記憶體； cache：用於快取記憶體。
- swap：内存使用swap的IO。si：由磁碟中將程序取出的量； so：由於記憶體不足而將沒用到的程序寫入到磁碟的 swap 的容量。 如果 si/so 的數值太大，表示記憶體內的資料常常得在磁碟與主記憶體之間傳來傳去，系統效能會很差！如果si、so不是一直为0，那说明性能已经出现问题！
- io：磁盘io。
- system：in：每秒被中斷的程序次數； cs：每秒鐘進行的事件切換次數；這兩個數值越大，代表系統與周邊設備的溝通非常頻繁！ 這些周邊設備當然包括磁碟、網路卡、時間鐘等。
- cpu：CPU 的項目分別為：
us：非核心層的 CPU 使用狀態； sy：核心層所使用的 CPU 狀態； id：閒置的狀態； wa：等待 I/O 所耗費的 CPU 狀態； st：被虛擬機器 (virtual machine) 所盜用的 CPU 使用狀態 (2.6.11 以後才支援)。

#### iostat

iostat：主要用于监控系统设备的IO负载情况（主要是磁盘），iostat首次运行时显示自系统启动开始的各项统计信息，之后运行iostat将显示自上次运行该命令以后的统计信息。

~~~
me@iZ94rxjfu2hZ:~$ iostat
Linux 3.13.0-32-generic (iZ94rxjfu2hZ) 	06/11/2017 	_x86_64_	(1 CPU)

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.80    0.00    0.63    0.08    0.13   98.36

Device:            tps    kB_read/s    kB_wrtn/s    kB_read    kB_wrtn
xvda              0.57         0.11         5.68    1082365   57503280
~~~

- tps：该设备每秒的传输次数（Indicate the number of transfers per second that were issued to the device.）。"一次传输"意思是"一次I/O请求"。多个逻辑请求可能会被合并为"一次I/O请求"。"一次传输"请求的大小是未知的。
- kB_read/s：每秒从设备（drive expressed）读取的数据量；
- kB_wrtn/s：每秒向设备（drive expressed）写入的数据量；
- kB_read：读取的总数据量；
- kB_wrtn：写入的总数量数据量；这些单位都为Kilobytes。

iostat还有一个-x选项，能显示磁盘性能相关的更详尽的信息，但一般情况下应该用不到，先不列出了。

#### pidstat



#### 其他

包括：ss, sar, mpstat。 linux下相关的命令太多，不需要一一记住，掌握几个就可以了。

### 参考

- http://linux.vbird.org/linux_basic/0440processcontrol.php
- 《Linux从入门到精通》
