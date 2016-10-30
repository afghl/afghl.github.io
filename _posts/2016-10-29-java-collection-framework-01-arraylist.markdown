---
layout: post
title:  "Java集合框架源码解析（一） - ArrayList"
date:   2016-10-29 11:54:00 +0800
---

### List接口


### ArrayList

ArrayList是List接口最基础的实现。（比数组好的地方）它是以数组的形式实现的集合。想想看你用C语言怎么实现一个线性表呢？

~~~ C
struct LNode {
    ElementType Data[MAXSIZE];
    Position Last; // 保存线性表中最后一个元素的位置
};
~~~

而在ArrayList里，同样有ElementData和size两个实例变量，通过两个基本变量来实现可动态变容的数组的。（在构造器处看看这两个变量）下面我们看看ArrayList一些常见接口和内部实现。

#### 添加

ArrayList有两个add接口：允许把一个元素加在列表的最后，或指定位置。

分别看看它们的实现代码：

~~~ java
public boolean add(E e) {
    ensureCapacityInternal(size + 1);  // Increments modCount!!
    elementData[size++] = e;
    return true;
}

public void add(int index, E element) {
    rangeCheckForAdd(index);

    ensureCapacityInternal(size + 1);  // Increments modCount!!
    System.arraycopy(elementData, index, elementData, index + 1,
                     size - index);
    elementData[index] = element;
    size++;
}
~~~

暂时先忽略`ensureCapacityInternal`，不出所料，加在最后的add方法是一个O(1)的操作，而加在指定位置的add方法需要对index之后的所有元素移位，是一个O(n)操作。No fancy ：）。

size是维护数组长度的属性，增加元素的时候，它会+1。

#### 删除和查找

删除接口同样有两个：删除指定元素或删除指定下标上的元素。同样需要移位后继元素，是O(n)操作，代码和add方法十分相似，就不做展示了。

ArrayList提供get和indexOf接口，允许返回指定下标的元素和搜索一个特定元素的下标。时间复杂度多少，你自己猜猜。

#### 扩容

ArrayList比数组好用的最重要原因就是：数组的大小是不可变的，而ArrayList是可扩容的。而这个扩容对客户来说是透明的，它发生在add操作内，也就是刚才看到的`ensureCapacityInternal`，现在重点来说一说它：

虽说ArrayList的扩容对客户而言是透明的，但它依然提供接口：`ensureCapacity`，提供手动扩容的功能：

~~~ java
public void ensureCapacity(int minCapacity) {
    int minExpand = (elementData != DEFAULTCAPACITY_EMPTY_ELEMENTDATA)
        // any size if not default element table
        ? 0
        // larger than default for default empty table. It's already
        // supposed to be at default size.
        : DEFAULT_CAPACITY;

    if (minCapacity > minExpand) {
        ensureExplicitCapacity(minCapacity);
    }
}

~~~

在实现里，实际调用的是`grow`方法：

~~~ java
private void ensureExplicitCapacity(int minCapacity) {
    modCount++;

    // overflow-conscious code
    if (minCapacity - elementData.length > 0)
        grow(minCapacity);
}

private void grow(int minCapacity) {
    // overflow-conscious code
    int oldCapacity = elementData.length;
    int newCapacity = oldCapacity + (oldCapacity >> 1);
    if (newCapacity - minCapacity < 0)
        newCapacity = minCapacity;
    if (newCapacity - MAX_ARRAY_SIZE > 0)
        newCapacity = hugeCapacity(minCapacity);
    // minCapacity is usually close to size, so this is a win:
    elementData = Arrays.copyOf(elementData, newCapacity);
}

~~~

重点是grow方法的第二行：`>>`是向右移位操作符，得到的结果是原操作数除以二的值。整个表达式（`oldCapacity + (oldCapacity >> 1)`）的值约为oldCapacity的1.5倍。

在1.8之前的版本，这一行运算是写成`int newCapacity = (oldCapacity * 3)/2 + 1;`，旧的算法增长的更快。无论新旧算法，`capacity`的增长都是指数级的，简单做个实验：

~~~ java
public static void main(String[] args) {
    int a = 10;
    int count = 0;
    while ((a = grow(a)) < Integer.MAX_VALUE && a > 0) {
        count++;
        System.out.println(a);
    }
    System.out.println(count);
}

private static int grow(int capacity) {
    return capacity + (capacity >> 1);
}
~~~

需要grow多少次呢？

~~~
15
22
33
49
73
109
163
244
366
549
823
....
354836040
532254060
798381090
1197571635
1796357452
48
~~~

48次，你应该对这个算法有个感性的认识了。所以扩容扩多少，是JDK开发人员在时间、空间上做的一个权衡，提供出来的一个比较合理的数值。

增加了容量之后，最后是调用`Array.copyOf`复制到新数组。
