---
layout: post
title:  "在markdown使用mathjax"
date:   2016-05-15 11:27:00 +0800
---

mathjax 是一个允许用结构化语言写数据公式的插件。几个简单的步骤就可以在markdown里使用它了。

1. include CDN
  
   ~~~ html
   <script type="text/javascript" src="http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML"></script>
   ~~~
   
2. 用 `$$` 插入mathjax代码

   ~~~
   $$ \begin{align} & \phi(x,y) = \phi \left(\sum_{i=1}^n x_ie_i, \sum_{j=1}^n y_je_j \right) = \sum_{i=1}^n \sum_{j=1}^n x_i y_j \phi(e_i, e_j) = \ & (x_1, \ldots, x_n) \left( \begin{array}{ccc} \phi(e_1, e_1) & \cdots & \phi(e_1, e_n) \ \vdots & \ddots & \vdots \ \phi(e_n, e_1) & \cdots & \phi(e_n, e_n) \end{array} \right) \left( \begin{array}{c} y_1 \ \vdots \ y_n \end{array} \right) \end{align} $$
   ~~~

   得到：
   
   $$ \begin{align} & \phi(x,y) = \phi \left(\sum_{i=1}^n x_ie_i, \sum_{j=1}^n y_je_j \right) = \sum_{i=1}^n \sum_{j=1}^n x_i y_j \phi(e_i, e_j) = \ & (x_1, \ldots, x_n) \left( \begin{array}{ccc} \phi(e_1, e_1) & \cdots & \phi(e_1, e_n) \ \vdots & \ddots & \vdots \ \phi(e_n, e_1) & \cdots & \phi(e_n, e_n) \end{array} \right) \left( \begin{array}{c} y_1 \ \vdots \ y_n \end{array} \right) \end{align} $$
   
   :) 你猜我写了什么？
   
3. mathjax语法
   
   学习mathjax的一些资源：
   - http://docs.mathjax.org/en/latest/start.html
   - http://meta.math.stackexchange.com/questions/5020/mathjax-basic-tutorial-and-quick-reference
   - https://github.com/mathjax/MathJax-examples
