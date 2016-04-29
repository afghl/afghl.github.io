---
layout: post
title:  "利用Graphviz看ActiveRecod源码"
date:   2016-04-09 12:11:00 +0800
---

我们都知道ActiveRecod借助Arel管理Sql的生成，而Arel使用ast和visitor pattern生成Sql。但是当你想看这颗语法树时，可能会很郁闷：

~~~ Ruby
2.1.5 :047 > pp Post.all.ast
#<Arel::Nodes::SelectStatement:0x007fe6e1406c10
 @cores=
  [#<Arel::Nodes::SelectCore:0x007fe6e1406be8
    @groups=[],
    @having=nil,
    @projections=
     [#<struct Arel::Attributes::Attribute
       relation=
        #<Arel::Table:0x007fe6e2977608
         @aliases=[],
         @columns=nil,
         @engine=
          Post(id: integer, title: string, context: text, created_at: datetime, updated_at: datetime),
  ...
~~~

最近我找到一个方法能让你直观的看到这颗语法树的结构。

#### 准备

安装 Graphviz

graphviz和它提供的dot语言是一套绘图DSL，但对这个一无所知并不妨碍阅读这篇文章。

~~~
  brew install graphviz
~~~

#### to_dot

对ActiveRecod::Relation调用`to_dot`，获得生成的dot脚本

~~~ Ruby
2.1.5 :048 > Post.all.to_dot
=> "digraph \"Arel\" {\nnode [width=0.375,height=0.25,shape=record];
70314799067660 [label=\"<f0>Arel::Nodes::SelectStatement\"];\n70314799067500
[label=\"<f0>Array\"];\n70314799067640 [label=\"<f0>Arel::Nodes::SelectCore\"];\n70314799067620
[label=\"<f0>Arel::Nodes::JoinSource\"];\n70314810391300 [label=\"<f0>Arel::Table\"];\n70314810391580
...
~~~

#### 生产dot文件

~~~ Ruby
  File.write("post.dot", Post.all.to_dot)
~~~

#### 使用graphviz绘图

~~~
  dot post.dot -T png -o post.png
~~~

最后得到的，就是`Post.all`在arel中所生成的AST。

<img src="/images/post.png"/>
