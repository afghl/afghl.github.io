---
layout: post
title:  "有什么不能TDD？"
date:   2016-03-19 20:11:00 +0800
---

### 前言

TDD，Test-Driven Development，测试驱动开发。其定义和理念不在此赘述。据我所知，Rails社区应该是最推崇这一开发模式的社区了。我也是TDD的拥护者之一。的确，在WEB开发的大部分场景里，它能让我写出更好的代码，正如敏捷社区所说的：clean code that works。但是，当然也有TDD不适用的场景。

在几个星期前，我尝试用TDD开发一个小小的前端物理引擎。（其实就是几个小球撞来撞去...）github：[地址](https://github.com/afghl/collision-game)。 测试框架是jasmine。以下我就这个项目和之前几个项目里，我遇到的问题和我的感觉，谈谈有什么不能TDD。

### 构建的前期

在项目设计和开发的初期，当项目代码的架构还没确定时，不应让测试去接管你的代码。因为项目初期，系统有可能需要重新设计，架构，甚至推倒重来。如果在这时先写测试再写代码，往往是两个极端：要么测试代码太过High level了，这样的测试并不能“驱动开发”。因为在TDD中，当一个测试过大时，你不能快速的实现代码获得反馈，那就失去了“驱动”的意义了。再者，测试代码如果太过High level，出问题时还需花时间去debug实现代码。另一个极端则是测试代码太Low level，这意味着你得花一倍的时间维护测试代码，而在项目初期，需求，设计都是易变的，维护成本大大增高。

### 前端不适合TDD

应该说，和DOM耦合度很高的前端代码不适合TDD。但目前而已，前端大部分代码还是和html高度耦合的。在这些代码中如果先写测试，反而会变得束手束脚。

一个难题是测试环境的搭建，不在浏览器里模拟一个DOM对象的难度很大。我没有找到什么好的解决方案，最终只能用最笨的方法：把jasmine框架的代码、测试代码和项目代码全放入一个页面中，在本地访问页面来跑测试代码：

~~~ html
<html>
  <head>
    <link rel="shortcut icon" type="image/png" href="../../lib/jasmine/jasmine_favicon.png">
    <link rel="stylesheet" type="text/css" href="../../lib/jasmine/jasmine.css">

    <script src="../../lib/jquery/jquery.min.js"></script>
    <script src="../../lib/jasmine/jasmine.js"></script>
    <script src="../../lib/jasmine/jasmine-html.js"></script>
    <script src="../../lib/jasmine/boot.js"></script>
    <script src="../../dist/js/collision-game.js"></script>
    <script src="ball_spec.js"></script>
    <script src="vector_rotate_spec.js"></script>
  </head>
</html>
~~~

另一个问题是前端开发大多数情况不需要通过测试来获得反馈，刷新页面就能看到效果了。

### 无法用一两个测试描述清楚情况

TDD通过把一个需求点变成一句话，然后再用一些代码描述这句话，通过这个测试，就可以说是完成这个需求点。比如：

~~~ js
it("has expected attributes", function() {
  expect(ball.r).toEqual(5);
  expect(ball.position).toEqual([5, 7]);
  expect(ball.m).toEqual(10);
  expect(ball.v).toEqual([4, 6]);
});
~~~

但有时无法用一两个测试概括情况，比如：两个小球的碰撞。我当然可以写出一个测试去看看小球碰撞前后，速度V的变化来实现一个测试：

~~~ js
beforeEach(function() {
  Ball.allBalls = [];
  ball1 = new Ball({ domId: 'ball-1', radius: 5, position: [905, 500], mass: 10, velocity: [10, 0] });
  ball2 = new Ball({ domId: 'ball-2', radius: 30, position: [940, 500], mass: 40, velocity: [-11, 0] });
});

it("will cause a collision when touch another ball", function() {
  ball1.render().kickOff();
  ball2.render().kickOff();
  jasmine.clock().tick(31);
  expect(ball1.v).toEqual([-24, 0]);
  expect(ball2.v).toEqual([-3, 0]);
})
~~~

但在实现这部分的时候，发现这几个问题：

1. 测试太难写了。两个小球的初始位置，初速度，碰撞后的速度，都要非常特殊，才能写出一个test case。

2. 这个测试本身的跨度像“把大象装进冰箱”一样大。

3. 即使这个测试通过了，不能信任碰撞情况的效果。

很显然，关于碰撞效果，如果想用测试代码把情况都描述清楚，根本不可能。

其实，因为两小球的碰撞算法，涉及的都是物理公式，人脑里的常识早就构建了无数的测试用例，最好的测试方法显然就是干脆渲染出来，观察效果，而不是写一些自作聪明的测试。
