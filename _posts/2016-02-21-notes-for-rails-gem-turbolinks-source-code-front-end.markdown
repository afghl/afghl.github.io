---
layout: post
title:  "Turbolinks 源码分析 - 前端篇"
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

1. **将`<a>`标签中的正常跳转替换成Ajax请求。**

    Turbolinks通过监听document对象的click事件拦截所有的点击操作。

    这里需要解决一个问题：**和用户脚本冲突**。比如，我有这样的一个`<a>`标签：

       <a id='foo' href='/admin'></a>

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


    Click的实现：

       class Click
         # 每次执行Click.installHandlerLast方法时，都重新将真正的callback(Click.handle)绑定。
         # 保证真正的callback总在最后执行。
         @installHandlerLast: (event) ->
           unless event.defaultPrevented
             document.removeEventListener 'click', Click.handle, false
             document.addEventListener 'click', Click.handle, false

         @handle: (event) ->
           new Click event

         # omitted

    所以，每次点击都会重新绑定`Click.handle`，使这个方法总在最后执行。

2. **fetch**

    fetch是发出Ajax的过程。在发出异步请求之前，Turbolinks首先会做的是：

      - 判断crossDomain，如果是则无需处理直接修改document.location.href。
      - cache当前页面的整个DOM对象。
      - 将当前的document.location.href保存（以便作为请求的header中的referer）。
      - 尝试使用Transition Cache，即如果链接中的页面在cache里，会立即替换已经缓存的版本。（等到真正的response回来了，再替换一次最新的版本。）

    在Ajax拿到服务器的响应，需要解析response：

    分析status，contentType，和assets：

       extractTrackAssets = (doc) ->
          # 只取<head>中的有个data-turbolinks-track的<script>
          for node in doc.querySelector('head').childNodes when node.getAttribute?('data-turbolinks-track')?
            node.getAttribute('src') or node.getAttribute('href')

       intersection = (a, b) ->
          [a, b] = [b, a] if a.length > b.length
          value for value in a when value in b

        assetsChanged = (doc) ->
          loadedAssets ||= extractTrackAssets document
          fetchedAssets  = extractTrackAssets doc

          # 简单的比较[fetchedAssets, loadedAssets]的交集是否和loadedAssets一样
          fetchedAssets.length isnt loadedAssets.length or intersection(fetchedAssets, loadedAssets).length isnt loadedAssets.length

    如果response不满足条件，如Assets有任何改动，或响应的是一个redirect，则会替换document.location.href，发出传统的请求：

       document.location.href = crossOriginRedirect() or url.absolute

    换言之，两个页面上<head>里的有data-turbolinks-track的`<script>` tag 差异， 会引发：double load。

3. **replace**

    来到最坑的最后一步，替换body。替换DOM本身很简单，麻烦的是javascript执行。Turbolinks本身使用Pjax技术，导致document对象的事件和普通跳转时不同了，依赖这些事件的js方法都会影响。另外，直接写在`<script>`里面的js代码，也会有意想不到的情况发生。

    关于Evaluating script tags，看看官方document：

    > Turbolinks will evaluate any script tags in pages it visits, if those tags do not have a type or if the type is text/javascript. All other script tags will be ignored.

    > As a rule of thumb when switching to Turbolinks, move all of your javascript tags inside the head and then work backwards, only moving javascript code back to the body if absolutely necessary.

    看看如何实现：

       getScriptsToRun = (changedNodes, runScripts) ->
          selector = if runScripts is false then 'script[data-turbolinks-eval="always"]' else 'script:not([data-turbolinks-eval="false"])'
          # 在body里，找出'script[data-turbolinks-eval="always"]' 的script tag
          script for script in document.body.querySelectorAll(selector) when isEvalAlways(script) or (nestedWithinNodeList(changedNodes, script) and not withinPermanent(script))


    然后再一次append每个script tag到原来的位置：

       executeScriptTags = (scripts) ->
         for script in scripts when script.type in ['', 'text/javascript']
           copy = document.createElement 'script'
           copy.setAttribute attr.name, attr.value for attr in script.attributes
           copy.async = false unless script.hasAttribute 'async'
           copy.appendChild document.createTextNode script.innerHTML
           { parentNode, nextSibling } = script
           parentNode.removeChild script
           parentNode.insertBefore copy, nextSibling
         return

    由代码中可以看到，这里的`getScriptsToRun`是针对body中的`<script>` tag，而没有理会<head>中的标签。 换言之，你在A页面的<head>中有一段js代码：

       <script type="text/javascript">
          console.log('hello')
        </script>

    当由B页面进入A页面时，这段代码不会执行（甚至不会加载）。而这不是bug...

前端的部分就说这些，下一篇看看后端的实现吧。
