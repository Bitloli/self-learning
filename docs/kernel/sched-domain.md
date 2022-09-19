# 首先，理解了
- https://docs.kernel.org/admin-guide/pm/intel-speed-select.html

- 打印出来当前正在 CPU 上运行的:
```sh
ps -e -o pid,ppid,sgi_p,state,args | awk '$3!="*" {print}'
```

- [ ] 有没有现成的工具分析一个 CPU 上的运行程序，例如百分比，1s 一次更新。ebpf ?

- Scheduler Domain 从 acpi 中获取吗?
