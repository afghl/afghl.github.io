---
title:  "说说“表现与数据分离”"
date:   2015-06-21 22:24:00 +0800
---

先看一道面试题：

> 有一个国家列表，现在要将国家列表放到A中，然后B可以由A选择，也可以有总列表选择
  但是B中添加后，若是A中没有要动态为A增加这项。

原文见： http://www.cnblogs.com/yexiaochai/p/3523219.html

尝试做一下， 代码：

~~~coffeescript
# initialize app
app              = {}

app.controllers  = {}
app.views        = {}
app.models       = {}
app.countries    = []
app.events       = $.extend({}, Backbone.Events)

class app.models.Country
  constructor: (name, isCountryA = false, isCountryB = false) ->
    @name = name
    @isCountryA = isCountryA
    @isCountryB = isCountryB

class BaseView
  constructor: ->
    app.events.on('calculate', @onCalculate)

  render: ->
    $('#main-container').append @template

class app.views.MainListView extends BaseView
  template: "<div class='country-container' id='main'><div class='title'>main</div></div>"

  onCalculate: ->
    _appendCountryItems(app.countries, '#main')

class app.views.ACountriesListView extends BaseView
  template: "<div class='country-container' id='a'><div class='title'>A</div></div>"

  onCalculate: ->
    countries = (country for country in app.countries when country.isCountryA)
    _appendCountryItems(countries, '#a')

class app.views.BCountriesListView extends BaseView
  template: "<div class='country-container' id='b'><div class='title'>B</div></div>"

  onCalculate: ->
    countries = (country for country in app.countries when country.isCountryB)
    _appendCountryItems(countries, '#b')

_appendCountryItems = (countries, containerSelector) ->
  $container = $(containerSelector)
  $container.find('span').remove()

  countryTemplate = "<span class='country'></span>"

  for country in countries
    do (country) ->
      $item = $(countryTemplate).text(country.name)
                .click ->
                  country.isCountryB = !country.isCountryB
                  app.events.trigger('calculate')

      $container.append $item

class app.controllers.CountryController
  createCountries: ->
    for name in ['China', 'American', 'UK', 'France', 'Brazil', 'Spain', 'Japan']
      app.countries.push new app.models.Country(name)
    @

  showViews: ->
    for view of app.views
      new app.views[view]().render()

    app.events.trigger('calculate')

window.app = app

$ ->
  c = new app.controllers.CountryController
  c.createCountries().showViews()
~~~

为了保持简洁，使用coffeescript，功能只实现了添加到B的部分，事件对象就只extend了一个backbone.event。

然后说说这样设计的思路：

1.  图中有三个区域：分别是所有国家， 国家A， 国家B，三个div。可以把这三个div， 看成对同一份coutries（数据）的映射：
   -  在所有国家的div中，展示所有countries。
   -  国家A的div中，展示`isCountryA == true`的coutries。
   -  国家B的div中，展示`isCountryB == true`的coutries。

    这样，在表现上有三个列表，但实际上都是同一份countries的展示。

2. 通过第一点的设计，实现了三个列表间的解耦。因为三个列表都是只和countries关联，彼此之间甚至不知道对方存在。当coutries发生变化时，发出事件`‘calculate‘`，三个列表通过监听同一个事件，获得的countries的最新状态。然后重新渲染即可。

3. dom和逻辑模型的解耦：用户通过操作，看似更改dom的内容，实际只是通过dom事件的callback操作数据模型countries，而不直接操作任何的view。

这样设计如何应对需求的变化？

1. **最简单的，增加C国家列表，D国家列表。**

    只需要增加相应的 CountriesListView。


2. **改点击为拖动。**

    因为业务逻辑已经封装成一个方法， 只需要把该方法放入不同的dom事件即可。（当然，需要判断一下拖动的位置和div的位置等。）

3. **对A B列表增加判断。**比如说， 变A为亚洲国家， B为欧洲国家。 在切换的时候，需要判断是否属于亚洲或欧洲，否则不能添加到该列表。

    这时，依然和dom节点， `CountriesListView`无关。 我会按照mvc思想，将`isCountryA`和`isCountryB` 变为私有变量，并在models.Country里增加get set方法， 这样，讲判断的逻辑放在model里， 只需要额外维护两个国家列表（亚洲国家和欧洲国家）。而view则不需要关心业务逻辑。
