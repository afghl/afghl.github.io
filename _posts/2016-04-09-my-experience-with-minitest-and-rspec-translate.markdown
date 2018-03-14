---

title:  "Minitest和Rspec的比较（译）"
date:   2016-04-09 12:11:00 +0800
---

本文是译文，原文可见[tenderlove的blog](https://tenderlovemaking.com/2015/01/23/my-experience-with-minitest-and-rspec.html)（[tenderlove@github](https://github.com/tenderlove)）。我和作者的经历相反，我有较多的Rspec经验，在最近接触Minitest，读完这篇文章之后，有一些地方很有同感，作者对Minitest的观点也对我很有启发。以下是译文（有部分删改）：

<hr>

我很认真地写了6个月Rspec，现在我想是时候写一篇扯淡的文章比较一下Rspec和Minitest。我有好几年的Minitest经验，而Rspec的经验只有6个月，在阅读本文时请记住这一点！

**请记住**，只要你愿意测试你的代码，我可不管你用的是什么测试框架。这只是一篇关于我对着两个框架的体会的文章。换言之，我所说的见仁见智。

### 前言

我认为，所有测试框架本质上都是一样的。没有什么是这个框架能做，而别的框架做不了的。测试只是代码。所以是什么区别了这些测试框架呢？我认为，最主要的不同是 **用户接口(user interface)**。 所以我会比较这些框架的用户接口。

### Rspec中我喜欢的东西

目前为止，我最爱Rspec的地方在于，如果有一个fail的测试，它会在最后打印出来，告诉我怎么重新运行那个单独的测试。我可以方便的复制黏贴那行代码，再跑一次那个fail的测试。如果有人不知道，以下是一个例子：

~~~ ruby
describe "something" do
  it "works" do
    expect(10).to equal(11)
  end

  it "really works" do
    expect(11).to equal(11)
  end
end
~~~

当你跑这个测试时，输出会像这样：

~~~
[aaron@TC tlm.com (master)]$ rspec code/fail_spec.rb
F.

Failures:

  1) something works
     Failure/Error: expect(10).to eq(11)

       expected: 11
            got: 10

       (compared using ==)
     # ./code/fail_spec.rb:3:in `block (2 levels) in <top (required)>'

Finished in 0.00504 seconds (files took 0.20501 seconds to load)
2 examples, 1 failure

Failed examples:

rspec ./code/fail_spec.rb:2 # something works
[aaron@TC tlm.com (master)]$
~~~

你要做的只是赋值黏贴那一行，重新跑一次那个失败的测试，像这样：

（此处应该有图）

甚至不用思考和敲代码，我只是“复制，黏贴，回车”。

我喜欢Rspec的另一点是它有一个可设置有颜色的输出的命令参数，所以你只要`rspec --color`，就能看到有着色的输出。我用了很多年没有着色的Minitest，但我很喜欢Rspec的这个设置。它帮助我看到测试报告最重要的部分，错误的断言，和方法栈。（不过我严重怀疑Rspec开发组的人都用黑底的终端，因为一些颜色在我的白色终端上很难看）。

### Minitest中我喜欢的东西

Minitest中，我最爱的是，一个Minitest都只是一个Ruby的类。下例和之前的Rspec例子相似：

~~~ ruby
require 'minitest/autorun'

class Something < Minitest::Test
  def test_works
    assert_equal 11, 10
  end

  def test_really_works
    assert_equal 11, 11
  end
end
~~~

我喜欢这样，因为我清楚地知道`test_works`是定义在哪里的。它和其他的Ruby的类没有任何其它的区别，我不用学任何新的东西。而且我是个CTags的重度使用者，所以我可以方便的在编辑器里跳到测试的方法或测试类。另一个好处是，如果使用普通的Ruby的类，当需要重构的时候，我只需要使用最普通的重构技巧：提取方法，提取类，提取模块，改变类的继承。在实现和测试文件中，我能使用相同的重构技巧。我想这就是Minitest最好的地方。

### Rspec中我不喜欢的东西

Rspec是一种写测试的DSL。但我认为这是它的一个缺点。我是一个程序员，我看得懂代码，所以我真的不在乎我的测试代码是不是“读起来像英文一样”。我不明白这种DSL的价值，特别是当我有[4000行代码需要重构的时候](https://github.com/ManageIQ/manageiq/blob/b012b8278ac9bf70224fff61f1d356294cbcda2e/vmdb/spec/helpers/application_helper_spec.rb)。我该怎么重构？我可以提取一些方法：

~~~ ruby
describe "something" do
  def helper
    11
  end

  it "works" do
    expect(10).to eq(helper)
  end

  it "really works" do
    expect(11).to eq(helper)
  end
end
~~~

但是`helper`方法定义在哪里呢？在哪里能调用？我可以将它放在一个module里吗？它可以被继承吗？谁会调用它？我可以在提取的方法中调用`super`吗？如果可以，`super`会进入哪里？当我有3000个测试失败了并且需要阅读一个很长的测试文件时，我可不想被这些问题困惑。

据我所知，在Rspec中调用`describe`本质上是定义了一个类。但如果是那样，为什么不直接用一个Ruby的类呢？那样我就不用猜方法的可见性，模块，继承之类的东西了。而且，我要测试的代码也只是普通的Ruby的类，为什么我要用一些别的语言去测试它们呢？

嵌套的describe看起来是实现继承，但其实只有`before`代码块是这样的。如果你运行这个测试：

~~~ ruby
describe "something" do
  before do
    puts "hi!"
  end

  it "works" do
    expect(10).to eq(helper)
  end

  it "really works" do
    expect(11).to eq(helper)
  end

  context "another thing" do
    before do
      puts "hello!"
    end

    it "really really works" do
      expect(11).to eq(helper)
    end
  end

  def helper
    11
  end
end
~~~

你会看到`hi!`打印了3次，每个`it`都有一次。对于嵌套context，我希望先打印`hello!`再打印`hi!`。在普通的继承里，我只需要调用`super`。（但在这里，）如果不学点新的知识，我真不知道怎么做才是最好的。现在我的处理方法是重构一个类在这些测试之外，然后在测试中调用这个类。但这其实是使我的测试更复杂了。

另一个问题是当我重构Rspec的测试时，当我改动行号时，那个我最喜爱的“复制黏贴回车”就失效了，我必须找新的有效的行号。

总之，我目前不再用Rspec了。对于我来说，Rspec有点身份危机，它进入了一个是“一种写测试的语言”还是“只是Ruby”的怪圈，那是Rspec最大的缺点。

### 总结

两个框架都有我喜欢和不喜欢的地方。对于我来说，能使用我的调试和重构技巧，显然更重要，特别是在我需要处理残留代码的时候。这就是为什么我的个人项目都选择Minitest。不过，我认为我在Rspec中的重构和调试技巧会有所进步，当我有进步的时候，我会分享下我的成果。

所以，我关心你用哪一个吗？不，只要你测试你的代码，我就很开心了。一个专业的开发者应该能够使用任何一种测试框架，因为它们本质上都是做同一件事：测试你的代码。
