---
layout: post
title:  "ActiveRecord如何拼出一句Sql？—— （一）ActiveRecord、Relation与Arel"
date:   2016-07-01 14:15:00 +0800
---

在[上一篇](2016/05/06/how-activerecord-generate-sql-0.html)中我们学习了基本的关系代数知识，以及Arel和关系代数的关系。上集讲到，ActiveRecord在幕后使用Arel拼出SQL语句。现在，我们先跳过Arel，说说幕前：从ActiveRecord讲起，说说AR的query接口（如：where，select，order）的设计思路和实现，这部分会主要涉及`ActiveRecord::Relation`模块。

本文以ActiveRecord4.1.8版本为例。

### ActiveRecord的结构

Rails是一个MVC结构的web框架，而ActiveRecord是Rails MVC中的M（model）层，也是三层中最重的一层：

~~~ ruby
module ActiveRecord #:nodoc:
  class Base
    extend ActiveModel::Naming

    extend ActiveSupport::Benchmarkable
    extend ActiveSupport::DescendantsTracker

    extend ConnectionHandling
    extend QueryCache::ClassMethods
    extend Querying
    extend Translation
    extend DynamicMatchers
    extend Explain
    extend Enum
    extend Delegation::DelegateCache

    include Core
    include Persistence
    ...
    include AutosaveAssociation
    include NestedAttributes
    include Aggregations
    include Transactions
    include NoTouching
    include Reflection
    include Serialization
    include Store
  end
end
~~~

简单的一行：`class Post < ActiveRecord::Base`，其实是继承了超过40个模块，数百个实例方法，超过40层的方法查找路径：

~~~ ruby
2.3.0 :001 > Post = Class.new(ActiveRecord::Base)
 => Foo (call 'Foo.connection' to establish a connection)
2.3.0 :002 > Post.ancestors
 => [Post (call 'Post.connection' to establish a connection), Post::GeneratedAssociationMethods,
     #<#<Class:0x007ffb85d82448>:0x007ffb85d824c0>, ActiveRecord::Base, ActiveRecord::Store,
     ActiveRecord::Serialization,ActiveModel::Serializers::Xml, ActiveModel::Serializers::JSON,
     ActiveModel::Serialization, ActiveRecord::Reflection, ActiveRecord::NoTouching,
     ...
     Kernel, BasicObject]
~~~

而`ActiveRecord::Relation`则是AR内部的一个模块，`Relation`模块以类的形式内置在`ActiveRecord`中。
Relation，即关系，顾名思义，其主要工作就是负责关系代数的映射：对外提供query API的接口，对内使用合适的数据结构，表示并维护客户提供的关系代数的信息。

### ActiveRecord::Relation

我们从一次普通的方法调用：

~~~ ruby
Post.where(id: 1)
~~~

的深度探险说起。

#### 委托（delegate）

我们知道，Rails中的ActiveRecord其中一个优雅之处在于query API是chainable的。而chainable的原因是每次调用query接口，不会直接生成SQL，而是返回一个`Relation`的实例：

~~~ ruby
2.3.0 :001 > Post.where(id: 1).class
 => Post::ActiveRecord_Relation
~~~

那么调用`where`方法时发生了什么呢？为什么`Post.where(...)`会变成`Relation`的实例呢？

其实，所有的query接口都是在`ActiveRecord::Relation`这个类里实现的。`ActiveRecord::Base`本身没有实现`where`方法，而是使用`delegate`，在`Base`里，有这样一行：

~~~ ruby
module ActiveRecord
  module Querying
    delegate :find_by, :find_by!, to: :all
    delegate :select, :group, :order, :except, :reorder, :limit, :offset, :joins,
             :where, :rewhere, :preload, :eager_load, :includes, :from, :lock, :readonly,
             :having, :create_with, :uniq, :distinct, :references, :none, :unscope, to: :all

    # ...
  end
end
~~~

`ActiveRecord::Base`将所有查询接口都一次性委托给`all`方法！也就是说：

~~~ ruby
Post.where(id: 1)
~~~

等价于：

~~~ ruby
Post.all.where(id: 1)
~~~

当然，`all`方法是定义在`Base`里的。而且不难估计，`all`返回的就是`Relation`实例（因为只有`Relation`里定义了`where`，`select`等方法）。再看看`all`方法的定义：

~~~ ruby
# lib/active_record/scoping/named.rb

def all
  if current_scope
    current_scope.clone
  else
    default_scoped
  end
end

# 默认情况下没有current_scope，所以all返回default_scoped

def default_scoped # :nodoc:
  relation.merge(build_default_scope)
end
~~~

所以`all`方法返回`relation`变量，而`relation`显然是`Relation`的实例：

~~~ ruby
# lib/active_record/core.rb

def relation #:nodoc:
  relation = Relation.create(self, arel_table)

  if finder_needs_type_condition?
    relation.where(type_condition).create_with(inheritance_column.to_sym => sti_name)
  else
    relation
  end
end
~~~

所以，`ActiveRecord`通过把`.where(...)`委托给`all`方法变成：`.all.where(...)`，将所有查询交给`Relation`类处理。

### 链式调用

然后再来看看`where`本身做了什么吧！

~~~ ruby
# lib/active_record/relation/query_methods.rb

def where(opts = :chain, *rest)
  if opts == :chain
    WhereChain.new(spawn)
  elsif opts.blank?
    self
  else
    spawn.where!(opts, *rest)
  end
end
~~~

在本例中，代码会进入if语句的最后一个分支，而此处`spawn`方法定义为调用clone方法：

~~~ ruby
# lib/active_record/relation/spawn_methods.rb

def spawn #:nodoc:
  clone
end
~~~

所以调用`where`最终会调用`where!`方法：

~~~ ruby
def where!(opts = :chain, *rest) # :nodoc:
  # omitted ...
  self.where_values += build_where(opts, rest)
  self
end
~~~

（为了方便理解我省略了一些对参数的特殊处理。）可见`where!`方法中做了两件事：

- 向`self.where_values`添加新的value。
- 返回`self`。

实际上，其他大部分的query方法所做的事都是一样的：

~~~ ruby
def _select!(*fields) # :nodoc:
  # omitted ...
  self.select_values += fields
  self
end

def order!(*args) # :nodoc:
  preprocess_order_args(args)

  self.order_values += args
  self
end


def includes!(*args) # :nodoc:
  # omitted ...
  self.includes_values |= args
  self
end

...
~~~

没错，说起来，这里确实没什么高大上的设计：每次调用方法时，把客户传入的参数处理并绑定在self中，然后返回self。

回顾一下，比如一句比较复杂的查询：

~~~ ruby
Post.where(title: 'hehe').order('id desc').limit(5)
~~~

调用链将会是：

![Alt text](/images/method-chain.png)

上图只是一个简单的示意图。接下来，详细看看所谓的`build_where`和`where_values`，到底是如何设计的。
