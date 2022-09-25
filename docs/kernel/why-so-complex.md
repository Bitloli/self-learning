# 为什么 Linux 6.0 相比于 Linux 0.1 复杂那么多

> There are so many features in the Linux kernel it sometimes blows my mind. eventfd, signalfd, timerfd, memfd, pidfd. The whole fricking tc/qdisc featureset (OMG). netlink. io_uring. criu. SO_REUSEPORT. Teaming. Namespaces. veths. vsocks. Dpdk/netmap/af_packet. XDP ! Seccomp.
>
> [Hacker News Reader](https://news.ycombinator.com/item?id=27328285)

## 横向扩展
1. 更多的架构支持
2. 更多的驱动支持

## 纵向扩展
1. io_uring
2. iommu
3. kvm

## 参考
- https://www.zhihu.com/question/35484429/answer/62964898
