---
layout: post
title:  "ActiveRecord如何拼出一句Sql？—— （一）ActiveRecord、Relation与Arel"
date:   2016-07-01 14:15:00 +0800
---

在[上一篇](2016/05/06/how-activerecord-generate-sql-0.html)中我们学习了基本的关系代数知识，以及Arel和关系代数的关系。上集讲到，ActiveRecord在幕后使用Arel拼出SQL语句。现在，我们跳过Arel，从ActiveRecord讲起，说说AR的query接口（如：where，select，order）的设计思路和实现，这部分会主要设计ActiveRecord::Relation模块。

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

当你有一个类继承了`ActiveRecord::Base`时，其实是继承了一大堆ActiveRecord内部的module。

~~~ ruby
2.3.0 :001 > Foo = Class.new(ActiveRecord::Base)
 => Foo (call 'Foo.connection' to establish a connection)
2.3.0 :002 > Foo.ancestors
 => [Foo (call 'Foo.connection' to establish a connection), Foo::GeneratedAssociationMethods,
     #<#<Class:0x007ffb85d82448>:0x007ffb85d824c0>, ActiveRecord::Base, ActiveRecord::Store,
     ActiveRecord::Serialization,ActiveModel::Serializers::Xml, ActiveModel::Serializers::JSON,
     ActiveModel::Serialization, ActiveRecord::Reflection, ActiveRecord::NoTouching,
     ...
     Kernel, BasicObject]
~~~

而`ActiveRecord::Relation`则是AR内部的一个模块，`Relation`模块以class的形式内置在ActiveRecord。
顾名思义（Relation即是：关系），Relation模块主要工作就是负责关系代数的映射：对外提供query API的接口，对内使用合适的数据结构，表示并维护客户提供的关系代数的信息。





















ss
