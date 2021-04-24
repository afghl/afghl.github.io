---
title:  "Golang并发（2） - channel用法和实现"
date:   2021-04-24 15:20:00 +0800
tags: [go,golang,concurrent,pattern,goroutine,channel]
---

除了goroutine之外，channel 是 golang 中最核心的 feature 之一，因此理解 Channel 的原理对于学习和使用 golang 非常重要。

golang社区有一句流行语：不要通过共享内存来通信，要通过通信来共享内存。实际上背后的理论基础就是[CSP](https://en.wikipedia.org/wiki/Communicating_sequential_processes)模型。channel就是对此的实现。


channel 提供了一种通信机制，通过它，一个 goroutine 可以想另一 goroutine 发送消息。channel 本身还需关联了一个类型，也就是 channel 可以发送数据的类型。例如: 发送 int 类型消息的 channel 写作 chan int 。

### 用法

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



### context

### 重构并发


#### pub sub

###多个交替打印

#### 并发度控制

一般而言不需要管理和控制goroutine的并发度。但如果每个goroutine做的事情对下游有依赖，且对下游较大，为了避免把下游瞬间打挂，还是需要控制goroutine执行的最大并行数。具体而言，可以见demo


### ref
- https://www.youtube.com/watch?v=KBZlN0izeiY&t=66s
