---
title:  "使用redis实现低粒度的分布式锁"
date:   2018-06-17 21:43:00 +0800
tags: [distribute-system,redis,distibuted-lock]
---

分布式锁的原始用法是：使集群内所有线程互斥地执行某一个方法：

~~~ java
public void executeInRedisLock(String lockKey) {
    try (redisLock.lock(lockKey)) {
        executeTask();
    }
}

private void executeTask() {
    // do something...
}
~~~

如果想要提高性能，那么我们应该找到`executeTask`中可以并行执行的代码块，尽量让它们并行，假设`executeTask`的代码是这样：

~~~ java
private void executeTask(int i) {
    if (i < 10000) {
        doMethodA(i);
    } else if (i >= 10000 && i < 20000) {
        doMethodB(i);
    } else {
        doMethodC(i);
    }
}
~~~

`executeTask`里面，会根据入参`i`的取值执行不同的方法，而假设这些方法彼此间是可以并行执行的。那么可以根据`i`的取值，生成不同的key，达到让不同的代码块，竞争各自的锁：

~~~ java
public void executeInRedisLock(int i) {
    try (redisLock.lock(getLockKey(i))) {
        executeTask(i);
    }
}

private void executeTask(int i) {
    if (i < 10000) {
        doMethodA(i);
    } else if (i >= 10000 && i < 20000) {
        doMethodB(i);
    } else {
        doMethodC(i);
    }
}

private String getLockKey(int i) {
    if (i < 10000) {
        return "key*of*a";
    } else if (i >= 10000 && i < 20000) {
        return "key*of*b";
    } else {
        return "key*of*c";
    }
}
~~~

这样，我们保证了`doMethodA`、`doMethodB`、`doMethodC`三个方法是互斥进行的。而`executeTask`的并发度理论上提高了3倍。

最近有一个更变态的需求，抽象来说是这样的：一个方法入参是一批id的数组，对于不同的id，可以并发执行，对于每个id，要求互斥的执行，而且要求同一批id的数组尽量要求原子性：要么一起成功，要么全部拒绝。

最终采用的方案是这样的：在redis里使用两个key：

- 一个存储所有正在执行这个方法的线程
- 另一个存储每个线程的id数组

代码如下，代码实现的细节可见注释：

~~~ java
public void executeInRedisLock(List<Long> ids) {
    String requestId = UUID.randomUUID().toString(); // 在每次进入方法的时候随机生成的唯一标识

    try {
        lock(requestId, ids);
        executeTask(ids);
    } catch (Exception e) {

    } finally {
        unlock(requestId);
    }
}

private void lock(String requestId, List<Long> ids) {
    // all_request_ids这个key下是所有正在执行当前方法的requestIds
    Set<String> requestIds = redis.smembers("all_request_ids");
    // 将当前请求的requestId加入数组
    redis.sadd("all_request_ids", requestId);

    if (CollectionUtils.isEmpty(requestIds)) {
        // 说明当前无并发执行的请求，成功获得锁
        return;
    }

    // 如果当前的requestIds不为空，说明有并发执行的请求，这时要对比所有数组，比较入参id数组和正在执行方法的id数组
    Set<Long> unionIds = Sets.newHashSet();
    try (Pipelined pipelined = redis.pipelined()) {
        requestIds.forEach(pipelined::smembers);
        pipelined.syncAndReturnAll().forEach(ids -> {
            if (ids != null) {
                unionIds.addAll((Set<Long>) ids);
            }
        });
    }

    // 此时，unionIds是所有正在执行方法的id数组，求unionIds和ids的交集
    Set<Long> intersection = Sets.intersection(unionIds, ids);

    // 如果有交集，说明交集内的ids存在并发执行，这时判断为没有获得锁。
    if (!intersection.isEmpty()) {
        throw new LockFailedException();
    }

}

private void unlock(String requestId) {
    redis.del(requestId);
    // 删除
    redis.srem("all_request_ids", requestId);
}
~~~
