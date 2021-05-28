---
title:  "Golang并发（2） - channel与context的用法和实现"
date:   2021-04-24 15:20:00 +0800
tags: [go,golang,concurrent,pattern,goroutine,channel]
---

除了goroutine之外，channel 是 golang 中最核心的 feature 之一，因此理解 Channel 的原理对于学习和使用 golang 非常重要。

golang社区有一句流行语：不要通过共享内存来通信，要通过通信来共享内存。实际上背后的理论基础就是[CSP](https://en.wikipedia.org/wiki/Communicating_sequential_processes)模型。channel就是对此的实现。


channel 提供了一种通信机制，通过它，一个 goroutine 可以向另一 goroutine 发送消息。channel 本身还需关联了一个类型，也就是 channel 可以发送数据的类型。例如: 发送 int 类型消息的 channel 写作 chan int 。

### 用法

channel有自己的语法糖，下面是最简单的一个代码段：

``` go
func sender(a chan int) {
	for i := 0; i < 10; i++ {
		a <- i
	}
}

func receiver(a chan int) {
	for {
		r := <-a
		fmt.Println("received...", r)
	}
}

func main() {
	ch := make(chan int)
	go sender(ch)
	go receiver(ch)

	var block string
	fmt.Scan(&block)
}
```

output:

```
received... 0
received... 1
received... 2
received... 3
received... 4
received... 5
received... 6
received... 7
received... 8
received... 9
```

### channel数据结构

要理解channel，需要理解其实对channel的操作的语法，只是一个语法糖。而底层支持的还是很容易理解的数据结构+算法。

我们可以看到对同一个channel的操作存在一定的同步和互斥。可以类比一下java是怎么实现线程同步的。AQS是java并发工具里的同步器，它里面的数据结构其实就三个部件组成：

1. 一个int标记位，标记当前锁是不是被持有。
2. 一个FIFO的队列，里面排队的是所有等待这个锁的线程，全部是阻塞态。
3. 保存一个指针，记录当前获得锁的线程。

channel做的事情不是同步，而是在goroutine之间传递数据，所以也会有一个数据的FIFO的队列。另外，对channel的操作也可能阻塞和唤起goroutine。所以也有类似于java里面的AQS的同步器。channel的数据结构如下：

``` go
type hchan struct {
	qcount   uint           // total data in the queue
	dataqsiz uint           // size of the circular queue
	buf      unsafe.Pointer // points to an array of dataqsiz elements
	elemsize uint16
	closed   uint32
	elemtype *_type // element type
	sendx    uint   // send index
	recvx    uint   // receive index
	recvq    waitq  // list of recv waiters
	sendq    waitq  // list of send waiters

	// lock protects all fields in hchan, as well as several
	// fields in sudogs blocked on this channel.
	//
	// Do not change another G's status while holding this lock
	// (in particular, do not ready a G), as this can deadlock
	// with stack shrinking.
	lock mutex
}
```

构成channel由几个部件组成：
- buf，保存channel的元素的一个数组。
- recvq，receiver的队列。
- sendq，sender的队列。
- lock，一个互斥器，对channel的访问需要互斥。

理解了这个数据结构之后，我们可以理解，当向一个channel执行send操作（`<-`）的时候，底层的数据结构会发生什么：

1. 当前goroutine会尝试获得锁
2. 将要传输的数据在内存中 **copy一份**，然后塞入buf数组中
3. 释放锁

执行recv操作时，就是一个相反的过程，在获得锁后，将buf数组里面的内容copy一份，然后当前goroutine的指针指向这个copy出来的对象，并在buf数组里移除掉这个数据。

所以，当一个goroutine通过channel获取到另一个goroutine的数据，其实在内存中经过最多两次的copy，在整个过程中并没有共享内存。这样是为了避免各种并发修改同一个内存的问题。

当然，channel的作用并不仅限于数据传输，它的最大的威力在于，我们在使用channel来转移一份数据的使用权，而相关的goroutine的执行和阻塞，由底层实现。当向一个已经满了的channel执行send操作时，这个操作会阻塞当前的goroutine：

``` go
ch := make(chan int, 2)
ch <- 1
ch <- 2
ch <- 3  // block...
```

底层如何实现阻塞，后面又是怎么实现唤起？答案是和AQS很类似的机制：

当hchan的数据满了后（c.qcount == c.dataqsiz），再收到send操作，会将这个goroutine连同它要发送的内存一起封装起来，保存到一个队列里（sendq），然后在执行挂起。

![Alt](/images/go-chan-1.png)

挂起是请求scheduler实现的，可以抽象的理解为：将当前的g的状态置为Waiting，然后调度的时候scheduler就会将这个g和M解开关联，然后将这个g加入到其中一个p的队列中。

所以，当一个channel满了的时候，可以理解为这样：

![Alt](/images/go-chan-2.jpg)

此时，当有另一个goroutine过来对这个已经满了的channel执行recv操作，会做几件事：

1. 从buf里出队一个ele，并copy出来给这个goroutine。
2. 从sendq里，找到第一个阻塞的sudog（hchan内部对协程的封装）并出队。
3. 唤醒这个协程，并将它的elem入队到buf队列里。

### context

context包是goroutine之间互相管理的工具。golang是面向分布式、rpc server的编程语言。一个web server的典型场景是节点接收到上游的请求request，然后处理过程中，需要创建一些额外的goroutine，并行请求下游数据（通常是阻塞操作）。这时候，如果一个request被cancel或者time out，那么它派生的goroutines也应该快速失败掉，返回err并释放资源，context就是为了处理这种场景而产生的工具。

> The sole purpose of the context package is to carry out the cancellation signal across goroutines no matter how they were spawned, context got them covered.

context的接口：

```go
type Context interface {
    // Done returns a channel that is closed when this Context is canceled
    // or times out.
    Done() <-chan struct{}

    // Err indicates why this context was canceled, after the Done channel
    // is closed.
    Err() error

    // Deadline returns the time when this Context will be canceled, if any.
    Deadline() (deadline time.Time, ok bool)

    // Value returns the value associated with key or nil if none.
    Value(key interface{}) interface{}
}
```

- `Deadline` 返回绑定当前context的任务被取消的截止时间；如果没有设定期限，将返回ok == false。
- `Done` 当绑定当前context的任务被取消时，将返回一个关闭的channel；如果当前context不会被取消，将返回nil。
- `Err` 如果Done返回的channel没有关闭，将返回nil;如果Done返回的channel已经关闭，将返回非空的值表示任务结束的原因。如果是context被取消，Err将返回Canceled；如果是context超时，Err将返回DeadlineExceeded。
- `Value` 返回context存储的键值对中当前key对应的值，如果没有对应的key,则返回nil。

我们来看一个典型的应用：

``` go
func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()

	result := make(chan int, 0)
	asyncDoStuffWithTimeout(ctx, result)
	fmt.Printf("restult get: %v", <-result)
}

func asyncDoStuffWithTimeout(ctx context.Context, result chan int) {
	go func() {
		select {
		case <-ctx.Done():
			fmt.Printf("ctx is done, %v", ctx.Err())
			result <- 0
			return
		case <-time.After(2 * time.Second):
			fmt.Println("set result")
			result <- 10
		}
	}()
}
```

实例中我们go了一个协程，执行一个，它会通过select case语句感知ctx是否已经关闭，如果是已经关闭，则会直接return。

### 重构并发

以几个例子展示怎么使用go里面的channel通道重构我们的并发编程模型。

### ping pong

这个是Advanced Go Concurrency Patterns上的一个例子，两个线程通过chan交换一个struct的使用权

``` go
type Ball struct {
	hits int
}

func main() {
	ball := Ball{}
	table := make(chan Ball)
	go play("ping", table)
	go play("pong", table)
	table <- ball
	time.Sleep(2 * time.Second)
}

func play(name string, table chan Ball)  {
	for {
		ball := <-table
		ball.hits++
		fmt.Printf("%v: hit %v\n", name, ball.hits)
		time.Sleep(300 * time.Millisecond)
		table <- ball
	}
}
```

#### 并发度控制

一般而言不需要管理和控制goroutine的并发度。但如果某些goroutine做的事情对下游有依赖，且对下游的资源消耗较大，为了避免把下游瞬间打挂，还是需要控制goroutine执行的最大并行数。

在java里最简单的方法就是使用线程池，只要设置core和max的线程数，控制了实际执行的最大线程数，再多的任务提交过来也会在队列里等待，在go里面，我们没必要直接做goroutine的线程池，而是使用channel简单实现一个concurreny limiter作为限流器。

``` go
type RateLimiter struct {
	tickets chan int
}

func GetLimiter(limit int) *rateLimiter {
	if limit <= 0 {
		limit = 10
	}

	tickets := make(chan int, limit)
	for i := 1; i <= limit; i++ {
		tickets <- i
	}

	return &RateLimiter{tickets: tickets}
}

func (r *RateLimiter) Exec(f func()) {
	ticket := <-r.tickets

	go func() {
		defer func() {
			r.tickets <- ticket
		}()
		f()
	}()
}
```

这里相当于把channel当成一个synchronizer来使用，`<-r.tickets` 有可能阻塞线程。这里需要注意的是，当限流器没容量（ticket全部占用），那么Exec方法会阻塞在原地（当前线程）。

### ref
- https://www.youtube.com/watch?v=KBZlN0izeiY&t=66s
- https://zhuanlan.zhihu.com/p/110085652
- https://blog.golang.org/io2013-talk-concurrency
- https://studygolang.com/articles/23247?fr=sidebar
- https://blog.golang.org/context
- https://medium.com/rungo/understanding-the-context-package-b2e407a9cdae
- https://www.youtube.com/watch?v=QDDwwePbDtw&t=515s
