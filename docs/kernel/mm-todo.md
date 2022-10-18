- 一个 QEMU 可以混合使用不同大小的大页吗?

- [ ] for_each_zone_zonelist_nodemask

- highatomic 是做什么意思的

- [ ] tools/vm directory
- [ ] 检查一下 zero page 和 swap 的代码，应该是 zero page 不会被换出的。

- https://www.kernel.org/doc/Documentation/vm/pagemap.txt
  - 从这里介绍内核的 flags，是极好的

- 如果是 private 映射一个文件，其修改应该最后也是写入到 swap 中的吧

- [What Every Programmer Should Know About Memory](https://people.freebsd.org/~lstewart/articles/cpumemory.pdf)
  - 总体结论，还是正确的
  - https://stackoverflow.com/questions/8126311/how-much-of-what-every-programmer-should-know-about-memory-is-still-valid
