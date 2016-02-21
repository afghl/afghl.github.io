---
layout: post
title:  "Turbolinks 源码分析"
date:   2016-02-20 16:07:00 +0800
---

在半年前的一个项目中，遇到Rails 4的大坑之一：Turbolinks，所以花一点时间好好的研究了这个gem。近来有时间整理一下写下来。本文成文时，[Turbolinks 5 preview](https://github.com/turbolinks/turbolinks) 已经出了，并支持iOS 和 Andrid hybrid apps。本文的源码指的是[Turbolinks Classic](https://github.com/turbolinks/turbolinks-classic)，权当复习。

### Turbolinks介绍
Turbolinks 可说是[pjax](https://github.com/defunkt/jquery-pjax)的一种实现：基于pushState，用替换DOM节点的方式替代传统的页面跳转。但它比pjax更“粗暴”：

> This is similar to pjax, but instead of worrying about what element on the page to replace and tailoring the server-side response to fit, we replace the entire body by default, and let you specify which elements to replace on an opt-in basis.

所以，从server的角度看，依然是返回一份**完整的**html response（包括`<head>`和`<body>`）。但是在前端会替换整个body DOM(默认情况)和更新head中的部分信息。

### 工作原理

> Turbolinks 为页面中所有的 `<a>` 元素添加了一个点击事件处理程序。如果浏览器支持 PushState，Turbolinks 会发起 Ajax 请求，处理响应，然后使用响应主体替换原始页面的整个 <body> 元素。最后，使用 PushState 技术更改页面的 URL，让新页面可刷新，并且有个精美的 URL。

下面来看看Turbolinks的具体实现：

#### 前端部分

1. 将`<a>`标签中的正常跳转替换成Ajax请求。

    Turbolinks通过监听document对象的click事件拦截所有的点击操作。

    这里需要解决一个问题：**和用户脚本冲突**。比如，我有这样的一个`<a>`标签：

~~~html
<a id='foo' href='/admin'></a>
~~~

    然后有这样一段js：

          document.addEventListener('click', function(e){
            if e.target.id == 'foo' document.location.href = 'http://www.baidu.com'
          }, false);

    这样，这个ID为foo的a标签就不再链向/admin，而应该是baidu了（虽然这例子很奇怪）。但是如果Turbolinks的callback在这段js之前执行，那么还是会向a上的href属性（/admin）发出一个Ajax请求。这当然不是我们预期的效果。

    所以Turbolinks需要保证它本身的Handler总在最后执行，是这样实现的：

          initializeTurbolinks = ->
            # omitted

            # 在initialize的时候绑定的callback，useCapture设为true，总在事件捕获阶段执行。
            document.addEventListener 'click', Click.installHandlerLast, true


          class Click
            # 每次执行Click.installHandlerLast方法时，都重新将真正的callback(Click.handle)绑定。保证真正的callback总在最后执行。
            @installHandlerLast: (event) ->
              unless event.defaultPrevented
                document.removeEventListener 'click', Click.handle, false
                document.addEventListener 'click', Click.handle, false

            @handle: (event) ->
              new Click event

            # omitted

    所以，每次点击都会重新绑定`Click.handle`。

2. fetch

3. 替换body
