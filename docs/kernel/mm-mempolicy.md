## 官方文档已经非常清楚了

https://docs.kernel.org/admin-guide/mm/numa_memory_policy.html
- alloc_pages_vma

-  默认算法是从 Local Node 上找，如果没有就去 remote 的 Node 上尝试
  - get_page_from_freelist 中调用 for_next_zone_zonelist_nodemask 将所有的 Node 都遍历一次

## vma_dup_policy : 当 frok 的时候，默认集成上一个的 policy
```txt
#0  vma_dup_policy (src=src@entry=0xffff8881212902f8, dst=dst@entry=0xffff888121290390) at mm/mempolicy.c:2387
#1  0xffffffff812e4710 in __split_vma (mm=mm@entry=0xffff888121518000, vma=vma@entry=0xffff8881212902f8, addr=addr@entry=140295976648704, new_below=new_below@entry=0) at mm/mmap.c:2222
#2  0xffffffff812e4914 in do_mas_align_munmap (mas=mas@entry=0xffffc9000005fd28, vma=0xffff8881212902f8, mm=mm@entry=0xffff888121518000, start=start@entry=140295976648704, end=end@entry=140295976849408, uf=uf@entry=0xffffc9000005fd18, downgrade=false) at mm/mmap.c:2341
#3  0xffffffff812e4dc2 in do_mas_munmap (mas=mas@entry=0xffffc9000005fd28, mm=mm@entry=0xffff888121518000, start=start@entry=140295976648704, len=len@entry=200704, uf=uf@entry=0xffffc9000005fd18, downgrade=downgrade@entry=false) at mm/mmap.c:2502
#4  0xffffffff812e4ec3 in __vm_munmap (start=start@entry=140295976648704, len=len@entry=200704, downgrade=downgrade@entry=false) at mm/mmap.c:2775
#5  0xffffffff812e4f87 in vm_munmap (start=start@entry=140295976648704, len=len@entry=200704) at mm/mmap.c:2793
#6  0xffffffff813cb166 in elf_map (filep=filep@entry=0xffff888121740200, addr=addr@entry=0, eppnt=eppnt@entry=0xffff888121332000, prot=prot@entry=1, type=2, total_size=<optimized out>) at fs/binfmt_elf.c:392
#7  0xffffffff813cc8e8 in load_elf_interp (arch_state=<synthetic pointer>, interp_elf_phdata=0xffff888121332000, no_base=94798853218304, interpreter=<optimized out>, interp_elf_ex=0xffff8881617b1580) at fs/binfmt_elf.c:638
#8  load_elf_binary (bprm=0xffff888161c2b400) at fs/binfmt_elf.c:1250
#9  0xffffffff8136e43e in search_binary_handler (bprm=0xffff888161c2b400) at fs/exec.c:1727
#10 exec_binprm (bprm=0xffff888161c2b400) at fs/exec.c:1768
#11 bprm_execve (flags=<optimized out>, filename=<optimized out>, fd=<optimized out>, bprm=0xffff888161c2b400) at fs/exec.c:1837
#12 bprm_execve (bprm=0xffff888161c2b400, fd=<optimized out>, filename=<optimized out>, flags=<optimized out>) at fs/exec.c:1799
#13 0xffffffff8136ee1b in kernel_execve (kernel_filename=kernel_filename@entry=0xffffffff827b40bb "/sbin/init", argv=argv@entry=0xffffffff82a14220 <argv_init>, envp=envp@entry=0xffffffff82a14100 <envp_init>) at fs/exec.c:2002
#14 0xffffffff81f34748 in run_init_process (init_filename=init_filename@entry=0xffffffff827b40bb "/sbin/init") at init/main.c:1435
#15 0xffffffff81f34753 in try_to_run_init_process (init_filename=init_filename@entry=0xffffffff827b40bb "/sbin/init") at init/main.c:1442
#16 0xffffffff81fa8ae0 in kernel_init (unused=<optimized out>) at init/main.c:1575
#17 0xffffffff81001a72 in ret_from_fork () at arch/x86/entry/entry_64.S:306
#18 0x0000000000000000 in ?? ()
```
## vm_operations_struct 的两个 hook : set_policy get_policy

使用位置:
- vma_replace_policy

- syscall mbind
  - kernel_mbind
    - do_mbind
- syscall set_mempolicy_home_node

上面两者调用:
- mbind_range
  - vma_replace_policy

是为了处理 shared policy 的

## mempolicy

1. Memory policies are a programming interface that a NUMA-aware application can take advantage of.
2. cpusets which is an administrative mechanism for restricting the nodes from which memory may be allocated by a set of processes.  cpuset 和 numa mempolicy 同时出现的时候，cpuset 优先
3. 一共四个粒度 和 两个 flags MPOL_F_STATIC_NODES 和 MPOL_F_RELATIVE_NODES (**flag 的作用有点迷**)

4. 还分析了一下 mol_put 和 mol_get 的问题

```c
// 获取 vma 对应的 policy ，解析出来 preferred_nid 和 nodemask 然后
struct page * alloc_pages_vma(gfp_t gfp, int order, struct vm_area_struct *vma, unsigned long addr, int node, bool hugepage)
```
> 感觉 mempolicy 并没有什么特殊的地方，只是提供一个 syscall 给用户。


- vma_merge

- vm_area_struct : 持有 vm_policy
