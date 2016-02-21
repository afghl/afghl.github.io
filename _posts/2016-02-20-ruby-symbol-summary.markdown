---
layout: post
title:  "Ruby Symbol 知识整理"
date:   2016-02-20 16:07:00 +0800
---

入门的时候被Ruby里的Symbol有点弄晕。现在整理一下关于 Ruby Symbol 的知识，写篇文章。

### Symbol是什么
symbol就是一个字符序列，可用来表示“名字”。Symbol的语法为一个冒号后面接一个标识符。

### Symbol的特性

1. **相同名字的symbol总是同一个对象**

        2.1.6 :001 > :foobar.object_id
          => 546728
        2.1.6 :002 > :foobar.object_id
          => 546728
        2.1.6 :003 > :'foobar'.object_id
          => 546728
        2.1.6 :004 > 'foobar'.object_id
          => 14580160
        2.1.6 :005 > 'foobar'.object_id
          => 14567740


      即：

      - 对于Symbol，相同名字的symbol总是同一个对象（symbol的字符串内容唯一确定一个symbol对象）。
      - 对于String，每个String对象都是不同的，即使它们包含相同的字符串内容。

2. **Symbol本质上（C语言层次）是无符号整数**

    这是Symbol和String的本质区别。也是用Symbol替代String可以提高执行速度的原因。String在Ruby源码中是一个重量级的结构体对象：

        struct RBasic {
          unsigned long flags;
          VALUE klass;
        };
        struct RString {
          struct RBasic basic;
          long len;
          char *ptr;
          union {
            	long capa;
            	VALUE shared;
          } aux;
        };
        #define RSTRING_PTR(s) (RSTRING(s)->ptr)
        #define RSTRING_LEN(s) (RSTRING(s)->len)

    而Symbol对象在C语言的定义是无符号整数：

        typedef unsigned long ID;

    这个数字和创建 Symbol 的名字，通过系统创建的符号表（Symbol Table）形成一对一的映射。

3. **Symbol一旦创建，不能被GC回收。**

    正是因为其在底层的实现，所以Symbol对象一旦定义将一直存在，直到程序执行退出。
    Symbol不会被 GC 回收，所以如果频繁调用`#to_sym`方法将String转换成Symbol的话，会耗费大量内存。
    可调用Symbol.all_symbols查看所以Symbol对象：

        2.1.6 :001 > Symbol.all_symbols.size
         => 3215

     **Ruby2.2之后，GC可回收部分Symbol对象。**（由`String#to_sym`, `String#intern` 生成的动态Symbol） （https://bugs.ruby-lang.org/issues/9634）


### 什么时候使用Symbol

由于Symbol处理名字可以降低Ruby内存消耗，并能提高速度。所以尽量使用Symbol。对于使用Symbol还是String的选择，一个简单的判断方法为：

- 如果字符串的内容不会在运行时发生变化，即优选Symbol。

典型场景为：

1. Hash的Key：

        options = {}
        options[:auto_save]     = true
        options[:show_comments] = false

   Hash的Key应尽量使用Symbol。因为如果使用String作为Key，则每次引用哈希表中的value时都会创建一个String对象。

2. hash参数：

        def method(keyword, opts)
          p keyword
          p opts
        end

        method :word, option1: 'foo', option2: 'bar'

    结果为：

        :word
        {:option1=>"foo", :option2=>"bar"}

---

### 参考资源
  - 理解 Ruby Symbol. (https://www.ibm.com/developerworks/cn/opensource/os-cn-rubysbl/)
  - 13 Ways of Looking at a Ruby Symbol. (http://www.randomhacks.net/2007/01/20/13-ways-of-looking-at-a-ruby-symbol/)
  - Understanding Differences Between Symbols & Strings in Ruby(http://www.gaurishsharma.com/2013/04/understanding-differences-between-symbols-strings-in-ruby.html)
