---
title:  "Golang并发（2） - channel用法和实现"
date:   2021-04-24 15:20:00 +0800
tags: [go,golang,concurrent,pattern,goroutine,channel]
---

除了goroutine之外，channel 是 golang 中最核心的 feature 之一，因此理解 Channel 的原理对于学习和使用 golang 非常重要。

### channel



### context

### 重构并发


#### pub sub

###多个交替打印

#### 并发度控制

一般而言不需要管理和控制goroutine的并发度。但如果每个goroutine做的事情对下游有依赖，且对下游较大，为了避免把下游瞬间打挂，还是需要控制goroutine执行的最大并行数。具体而言，可以见demo


### ref
- https://www.youtube.com/watch?v=KBZlN0izeiY&t=66s
