---
layout: post
title:  "Java集合框架源码解析（二） - LinkedList"
date:   2016-10-30 11:54:00 +0800
---

LinkedList是非线程安全的List实现，只在单线程下适合使用。LinkedList是一个用双向链表实现的一个List（通过源码很容易看出），它除了可以当做链表来操作外，它还可以当做栈、队列和双端队列来使用。    

如果你熟悉链表这个数据结构，LinkedList里的代码是非常易懂的，首先，链表中的每一个Node是它的一个内部类实现的：

~~~ java
private static class Node<E> {
    E item;
    Node<E> next;
    Node<E> prev;

    Node(Node<E> prev, E element, Node<E> next) {
        this.item = element;
        this.next = next;
        this.prev = prev;
    }
}
~~~

这里我们已经看到LinkedList是双向链表的证据了：每个Node维护一个前向指针和后向指针。LinkedList内部就是通过多个相连的Node实现。而它本身会通过first指针和last指针维护链表的头尾：

~~~ java
public class LinkedList<E>
    extends AbstractSequentialList<E>
    implements List<E>, Deque<E>, Cloneable, java.io.Serializable
{
    transient int size = 0;

    /**
     * Pointer to first node.
     * Invariant: (first == null && last == null) ||
     *            (first.prev == null && first.item != null)
     */
    transient Node<E> first;

    /**
     * Pointer to last node.
     * Invariant: (first == null && last == null) ||
     *            (last.next == null && last.item != null)
     */
    transient Node<E> last;
}
~~~

#### 增删改查

我们已经知道LinkedList内部实现是通过链表的，这种数据结构有它固有的特性，这些特性是不会随语言实现而改变的，先简单回顾下链表的特点：

1. 插入和删除某一元素，不需要移动其他元素，只需维护相邻两个结点的指针，效率很高，时间复杂度是O(1)。
2. 结点间只通过指针相连，不要求连续的空间，空间利用率高。
3. 通过index来访问元素的效率低，因为要逐个访问前序结点才能访问目标结点，效率是O(n)。

知道链表的这几点，再看Java里LinkedList的代码并不难读，这里没必要一一罗列了。

#### 千万不要用for迭代LinkedList

首先先上测试代码和结果：

~~~ java
public class LoopList {
    private final static int SIZE = 100 * 1024;

    public static void main(String[] args) {
        List<Integer> l = new LinkedList<Integer>();

        for (int i = 0; i < SIZE; i++)
            l.add(i);

        forLoop(l);
        foreachLoop(l);
    }

    private static void forLoop(List<Integer> l) {
        long start = System.currentTimeMillis();

        for (int i = 0; i < l.size(); i++)
            l.get(i);

        System.out.println("for loop, time spent: " + (System.currentTimeMillis() - start) + "ms");
    }

    private static void foreachLoop(List<Integer> l) {
        long start = System.currentTimeMillis();

        for (Integer i : l);

        System.out.println("foreach loop, time spent: " + (System.currentTimeMillis() - start) + "ms");
    }
}
~~~

结果：

~~~
for loop, time spent: 5550ms
foreach loop, time spent: 9ms
~~~

普通for循环速度之慢令人咋舌。其实思考一下很容易得到原因，就是上文提到的链表的特性：通过index来访问链表的元素，需要把之前的元素都访问一遍。LinkedList里`get`方法的实现：

~~~ java
public E get(int index) {
    checkElementIndex(index);
    return node(index).item;
}

Node<E> node(int index) {
    // assert isElementIndex(index);

    if (index < (size >> 1)) {
        Node<E> x = first;
        for (int i = 0; i < index; i++)
            x = x.next;
        return x;
    } else {
        Node<E> x = last;
        for (int i = size - 1; i > index; i--)
            x = x.prev;
        return x;
    }
}
~~~

这里有个小小的优化：LinkedList的`get(index)`并不一定从链表头开始查找，会先将index与长度size的一半比较，如果index<size/2，就只从位置0往后遍历到位置index处，而如果index>size/2，就只从位置size往前遍历到位置index处。这样可以减少一部分不必要的遍历，从而提高一定的效率，但实际上每次get还是一个O(n)的操作。

所以对于LinkedList，用访问下标的方法遍历它实在是非常痛苦。
