# How to kept myself informed ?

- [ ] 李存的找文章的几个网站

## 订阅的邮件列表

- kernel
- kernel newbie
- QEMU

- [ ] 更好的邮件阅读器?
- [ ] 重新搭建一个 zotero，在 mac 上

## 等待分析
- https://news.ycombinator.com/item?id=22902204
- https://github.com/Wenzel/awesome-virtualization#papers

## LPC
- https://www.youtube.com/watch?v=U6HYrd85hQ8

暂时都没有搞清楚这个东西到底是做什么的?

## KVM Forum
- youtube : https://www.youtube.com/channel/UCRCSQmAOh7yzgheq-emy1xA

这是正确的资源入口吗?
- https://events.linuxfoundation.org/archive/2020/kvm-forum/

可以将这种分散的合并起来吗?
- https://people.redhat.com/~aarcange/slides/2019-KVM-monolithic.pdf

## CCF 会议
- https://ccfddl.github.io/

- [ ] Data center 相关的会议也是需要的

### 计算机体系结构/并行与分布计算/存储系统
[计算机体系结构/并行与分布计算/存储系统](https://www.ccf.org.cn/Academic_Evaluation/ARCH_DCP_SS/)

- [ASPLOS](https://dblp.uni-trier.de/db/conf/asplos/index.html)


### 软件工程/系统软件/程序设计语言
[软件工程/系统软件/程序设计语言](https://www.ccf.org.cn/Academic_Evaluation/TCSE_SS_PDL/)

### 计算机网络
- [计算机网络](https://www.ccf.org.cn/Academic_Evaluation/CN/)

## Linux Storage, Filesystem, Memory-Management, and BPF Summit
- [2022](https://lwn.net/Articles/893733/)

## gallery
- https://github.com/facundoolano/software-papers : 各个领域的经典论文

## hotchip

## 暂时无法分类
###  ACM SIGARCH Computer Architecture News
> ????

We investigate why uncooperative swapping degrades
performance in practice and find that it is largely because of:
(1) “silent swap writes” that copy unchanged blocks of data
from the guest disk image to the host swap area; (2) “stale
swap reads” triggered when guests perform explicit disk
reads whose destination buffers are pages swapped out by
the host; (3) “false swap reads” triggered when guests overwrite whole pages previously swapped out by the host while
disregarding their old content (e.g., when copying-on-write);
(4) “decayed swap sequentiality” that causes unchanged
guest file blocks to gradually lose their contiguity while being kept in the host swap area and thereby hindering swap
prefetching; and (5) “false page anonymity” that occurs
when mislabeling guest pages backed by files as anonymous
and thereby confusing the page reclamation algorithm. We
characterize and exemplify these problems in Section 3.

- [ ] 这是没有 swap 的出现问题的几种原因

- [ ] 这里介绍了两种方法来解决

- 最好的是将两种方法都来搞一下。
- 没有 ballon 的一个问题:
  - 如果 host 将 guest 中 swap 的内存，guest 重新 swap 出去，这导致 host 需要将这个数据重新读回来。
