# Kernel 调试

- [disassemble with code and line](https://stackoverflow.com/questions/9970636/view-both-assembly-and-c-code)
- [如何增大 dmesg buffer 的大小](https://unix.stackexchange.com/questions/412182/how-to-increase-dmesg-buffer-size-in-centos-7-2)

# 通过插入预防错误的方法实现
```c
dump_page(page, "VM_BUG_ON_PAGE(" __stringify(cond)")");\

void dump_page(struct page *page, const char *reason)
{
	__dump_page(page, reason);
	dump_page_owner(page);
}
EXPORT_SYMBOL(dump_page);
```

> 以后再去慢慢跟踪吧!

## kernel hacking

- `pr_info`
  - 注意 `%px` 来输出指针
- `dump_stack`


- [ ] 这个没有测试过啊
调试内核模块
```sh
cat /proc/modules
objdump -dS --adjust-vma=0xffffffff85037434 vmlinux
```

- 如何 hacking 内核的官方文档:
  - https://www.kernel.org/doc/html/latest/kernel-hacking/index.html
  - https://www.kernel.org/doc/html/latest/trace/index.html#
  - https://www.kernel.org/doc/html/latest/dev-tools/index.html

## mce

```txt
CONFIG_X86_MCE=y
# CONFIG_X86_MCELOG_LEGACY is not set
CONFIG_X86_MCE_INTEL=y
CONFIG_X86_MCE_AMD=y
CONFIG_X86_MCE_THRESHOLD=y
# CONFIG_X86_MCE_INJECT is not set
```

- mcelog 操作需要/dev/mcelog 设备，这个设备通常自动由 udev 创建，也可以通过手工命令创建 mknod /dev/mcelog c 10 227。设备创建后剋通过 ls -lh /dev/mcelog 检查：
  - [ ] 似乎 centos 8 没有办法自动创建

> 默认没有配置/sys/devices/system/machinecheck/machinecheck0/trigger，这时这个内容是空的。当将/usr/sbin/mcelog 添加到这个 proc 文件中，就会在内核错误发生时触发运行/usr/sbin/mcelog 来处理解码错误日志，方便排查故障。

/etc/mcelog/mcelog.conf 是 mcelog 配置文件

## memtest
- https://github.com/memtest86plus/memtest86plus


## 参考资料
- https://huataihuang.gitbooks.io/cloud-atlas/content/os/linux/log/mcelog.html
- https://www.cnblogs.com/muahao/p/6003910.html
