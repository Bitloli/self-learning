- [ ] 一个 QEMU 可以混合使用不同大小的大页吗?
- [ ] QEMU 的启动参数
  - -m 24G -mem-prealloc -mem-path /dev/hugepages/test_vm
- [ ] 一个 mmap 可以混合使用各种大页吗?
- [ ] for_each_zone_zonelist_nodemask
- highatomic 是做什么意思的
- [ ] tools/vm directory
- [ ] 检查一下 zero page 和 swap 的代码，应该是 zero page 不会被换出的。
- https://www.kernel.org/doc/Documentation/vm/pagemap.txt
  - 从这里介绍内核的 flags，是极好的
- [ ] 如果是 private 映射一个文件，其修改应该最后也是写入到 swap 中的吧
  - 应该是的，但是需要验证
- [What Every Programmer Should Know About Memory](https://people.freebsd.org/~lstewart/articles/cpumemory.pdf)
  - 总体结论，还是正确的
  - https://stackoverflow.com/questions/8126311/how-much-of-what-every-programmer-should-know-about-memory-is-still-valid
- 当使用 DMA32 同时所有内存只有 4G 的时候，那岂不是就没有 ZONE_MOVABLE 和 ZONE_NORMAL ?
- numa remote access 是如何确定的
- vmpressure.c 是做什么的
- mmu notifier

## 似乎 numastat -p 的结果是错误的

```txt
stress-ng --vm-bytes 2000M --vm-keep -m 1

➜  ~ numastat  1988

Per-node process memory usage (in MBs) for PID 1988 (stress-ng)
                           Node 0          Node 1           Total
                  --------------- --------------- ---------------
Huge                         0.00            0.00            0.00
Heap                         0.00            0.04            0.04
Stack                        0.00            0.02            0.02
Private                      2.32            3.72            6.05
----------------  --------------- --------------- ---------------
Total                        2.32            3.78            6.10
➜  ~
```
- 而且，这个同时导致了一个问题，migrate 1988 0 1 几乎是瞬间完成，无论正反过来。
- 而且，numastat -m 显示占用的内存的位置没有发生变化。

是对于 stress-ng 理解有什么问题吗?
