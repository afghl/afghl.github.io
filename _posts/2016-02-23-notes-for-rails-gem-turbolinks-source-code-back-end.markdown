---

title:  "Turbolinks 源码分析 - 后端篇"
date:   2016-02-23 11:27:00 +0800
---

本文介绍Turbolinks的后端部分的源码，前端部分请见另一篇文章。

不同于前端，Turbolinks的后端部分不需要做太多的处理，只需让Tubolinks尽量“透明化” -- 让开发者能将Tubolinks的pjax请求当成普通的HTTP请求处理。为此，需要解决这几个问题：

- XHR的referer
- cache
- 重定向

下面看看Turbolinks是怎么处理这三个问题的：

1. **XHR的referer**

   Turbolinks用Ajax代替普通HTTP请求，所以在HTTP头的`referer`字段有可能不正确，使用了`X-XHR-Referer`字段代替普通HTTP请求中的`referer`：

   前端：

   ~~~ coffee
   xhr?.abort()
   xhr = new XMLHttpRequest
   # 使用X-XHR-Referer
   xhr.setRequestHeader 'X-XHR-Referer', referer
   ~~~

   后端则重写`Request#referer`方法：

   ~~~ ruby
   ActionDispatch::Request.class_eval do
     def referer
       # 优先用headers['X-XHR-Referer']
       self.headers['X-XHR-Referer'] || super
     end
     alias referrer referer
   end
   ~~~

2. **cache**

   在Turbolinks cache页面部分，有一个问题： 浏览器可以用`pushState`改变URL，但部分浏览器的`pushState`不会改变request method。如：

   - `POST: /page_a` 进入A页面
   - 通过pjax（ajax + pushState） `GET: /page_b` 进入B页面
   - 此时浏览器上href被改为`/page_b`

   此时刷新页面，部分浏览器会发出`POST: /page_b`请求，因为pushState不能改写request method。

   为此，Turbolinks的解决方法是：在进入一个新页面时，只有当服务器渲染的是一个`GET`请求时，前端的Turbolinks对象才会被初始化。

   使用cookies传递并检测request method：

   ~~~ ruby
   def set_request_method_cookie
     if request.get?
       cookies.delete(:request_method)
     else
       cookies[:request_method] = request.request_method # POST, DELETE
     end
   end
   ~~~

   前端部分在initialize阶段，会通过`cookies[:request_method]`判断。

3. **重定向的问题**

   3.1 同源重定向

      Turbolinks通过XHR发起页面的请求，而如果server返回redirect（302）的响应时，XHR会这样处理：

      马上向302 response上的Location发出第二个请求，将第二次请求拿到的结果返回。而整个过程由XHR内部处理，从外部能看到的只是第二次请求的响应和200报头。

      这会导致最终请求的URL不能被Turbolinks的pushState记录。如：

      通过Turbolinks向`/page_a`发出请求，返回的是`redirect_to: '/page_b'`的响应，则Turbolinks最终能拿到的`/page_b`的页面，而只记录了`/page_a`的URL。

      为了修复这个问题，Turbolinks的做法是：使用`session`记录一次重定向：

   **第一次请求时**，在服务器渲染一个redirect响应时，会把`target url`存放在`session`中：

   ~~~ruby
   # 拦截 _compute_redirect_to_location(redirect_to时会调用该方法)
   def _compute_redirect_to_location(*args)
     # 此处使用伪代码
     store_for_turbolinks begin
         super(*args)
       end
     end
   end

   def store_for_turbolinks(url)
     session[:_turbolinks_redirect_to] = url if session && request.headers["X-XHR-Referer"]
     url
   end
   ~~~

   **第二次请求时**，在`before_action`中检测`session[:_turbolinks_redirect_to]`，并放入header：

   ~~~ ruby
   def set_xhr_redirected_to
     if session && session[:_turbolinks_redirect_to]
       response.headers['X-XHR-Redirected-To'] = session.delete :_turbolinks_redirect_to
     end
   end
   ~~~

   用回上面的例子：

   - 在第一次请求时，服务器渲染``redirect_to: '/page_b'``，赋值：`session[:_turbolinks_redirect_to] = '/page_b'`
   - 第二次请求时，从`session[:_turbolinks_redirect_to]`获取`/page_b`，并设为`response.headers['X-XHR-Redirected-To']`

   这样，前端就能从`headers['X-XHR-Redirected-To']`拿到最终的URL。

   3.2 非同源重定向

   Ajax不能处理CrossDomain。Turbolinks的处理方法是：改变Http status，通知前端通过浏览器发出普通HTTP请求：

   ~~~ ruby
   def abort_xdomain_redirect
     to_uri = response.headers['Location']
     # 通过current判断这个request是否由Turbolinks发出。
     current = request.headers['X-XHR-Referer']
     unless to_uri.blank? || current.blank? || same_origin?(current, to_uri)
       # 如果：1. request由Turbolinks发出，2. 非同源，则改变status
       self.status = 403
     end
   rescue URI::InvalidURIError
   end
   ~~~

   这样，当前端获得一个403的请求时，会中断处理，通过改变`document.location.href`向非同源URL发出普通请求。

### 总结
   Turbolinks作为Server-side rendering到Client-side rendering的过渡产物。它和其他前端框架（AngularJS, Backbone）在功能上是有重叠的。

   但它对开发人员的要求更高：不仅要熟悉DOM对象生命周期的事件，和JS的内存管理（Turbolinks处理跳转时，不会释放Javascript内存）有更深的理解。

   我们在好好了解这个gem之后就决定放弃使用了。:) 但是Turbolinks 5 还是值得期待的。

---

### 参考资源

   - http://www.rubydoc.info/github/rails/turbolinks
   - https://www.nateberkopec.com/2015/05/27/100-ms-to-glass-with-rails-and-turbolinks.html
   - http://geekmonkey.org/2012/09/introducing-turbolinks-for-rails-4-0/
   - http://guides.ruby-china.org/working_with_javascript_in_rails.html#turbolinks
   - http://lingceng.github.io/blog/2014/10/16/turbolink-best-practice/
