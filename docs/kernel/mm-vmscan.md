# vmscan

## 问题
- lruvec 是基于 Node 的，会出现一个 Node 开始 swap 而另一个 Node 上还是内存很多的情况吗?
- 对于 dirty memory 和 clean mmeory 的 scan 应该是不同的吧
- lruvec 一共有多少个，处理的时候的规则是怎样的
- 如果整个分配都是在 zone 上进行，那么为什么 reclaim 机制又是在 node 上完成的
- [ ] 按道理来说，所有的 page 分配之后，需要立刻加入的 lru list 中

## lruvec
- [ ] 全局搜索一下
- [ ] 我记得 lrulist 是 per zone 的，例如每次都是 shrink zone 的
- lruvec 在 pg_data_t 中间的作用是什么?


通过 lru_add_drain_cpu 将 cpu_fbatches 的内容加入到 lruvec 中。
## kswapd
- 描述主动和被动触发的流程
- [ ] 每一个 numa 一个 kswapd，确认下

## [ ] mem_cgroup_lruvec

## [ ]

## pagevec

似乎已经被取消了:
```c
struct pagevec {
	unsigned long nr;
	unsigned long cold;
	struct page *pages[PAGEVEC_SIZE];
};
```

似乎使用这个作为替代的:
```c
/*
 * The following folio batches are grouped together because they are protected
 * by disabling preemption (and interrupts remain enabled).
 */
struct cpu_fbatches {
	local_lock_t lock;
	struct folio_batch lru_add;
	struct folio_batch lru_deactivate_file;
	struct folio_batch lru_deactivate;
	struct folio_batch lru_lazyfree;
#ifdef CONFIG_SMP
	struct folio_batch activate;
#endif
};
```

`pagevec_release` decrements the usage counter of all pages in the vector batchwise. Pages
whose usage counter value reaches 0 — these are therefore no longer in use — are automatically returned to the buddy system.
If the page was on an *LRU list* of the system, it is removed
from the list, regardless of the value of its usage counter.

- lru_cache_add
  - folio_batch_add_and_move 参数为 lru_add_fn
    - folio_batch_move_lru
      - 调用 hook : lru_add_fn
        - lruvec_add_folio
          - 将 lurvec 加入到

- [ ] 通过 folio 找到 lruvec 的方法

- lru_cache_add_inactive_or_unevictable
- add_to_page_cache_lru


Usually a page is first regarded as inactive and has to earn its merits to be considered active. However, a
selected number of procedures have a high opinion of their pages and invoke `lru_cache_add_active` to
place pages directly on the zone’s active list:
1. `read_swap_cache_async` from mm/swap_state.c; this reads pages from the swap cache.
2. The page fault handlers `__do_fault`, `do_anonymous_page`, `do_wp_page`, and `do_no_page`; these
are implemented in mm/memory.c.

## 转换的方法 : mark_page_accessed 和 page_check_references
两个 bit : PG_active 和 PG_referenced

- mark_page_accessed
  - [ ] 为什么 kvm 要调用这个?
  - [ ] 感觉申请的匿名页从来不会调用这个
- folio_check_references
  - 在扫描 inactive list 的时候调用，返回决定该 page 的四个状态

这个逻辑好奇怪啊，为什么在 exit 的时候还需要来 mark_page_accessed 一下
```txt
#0  mark_page_accessed (page=page@entry=0xffffea0005a014c0) at mm/folio-compat.c:50
#1  0xffffffff812d59a3 in zap_pte_range (details=0xffffc90001a93d00, end=<optimized out>, addr=94723981115392, pmd=<optimized out>, vma=<optimized out>, tlb=0xffffc90001a93df0) at mm/memory.c:1453
#2  zap_pmd_range (pud=<optimized out>, pud=<optimized out>, details=<optimized out>, end=<optimized out>, addr=94723981115392, vma=<optimized out>, tlb=<optimized out>) at mm/memory.c:1577
#3  zap_pud_range (p4d=<optimized out>, p4d=<optimized out>, details=0xffffc90001a93d00, end=<optimized out>, addr=94723981115392, vma=<optimized out>, tlb=0xffffc90001a93df0) at mm/memory.c:1606
#4  zap_p4d_range (details=0xffffc90001a93d00, end=<optimized out>, addr=94723981115392, pgd=<optimized out>, vma=<optimized out>, tlb=0xffffc90001a93df0) at mm/memory.c:1627
#5  unmap_page_range (tlb=tlb@entry=0xffffc90001a93df0, vma=<optimized out>, addr=94723981115392, end=<optimized out>, details=details@entry=0xffffc90001a93d00) at mm/memory.c:1648
#6  0xffffffff812d6478 in unmap_single_vma (tlb=tlb@entry=0xffffc90001a93df0, vma=<optimized out>, start_addr=start_addr@entry=0, end_addr=end_addr@entry=18446744073709551615, details=details@entry=0xffffc90001a93d00) at mm/memory.c:1694
#7  0xffffffff812d698c in unmap_vmas (tlb=tlb@entry=0xffffc90001a93df0, mt=mt@entry=0xffff888162ce5d80, vma=<optimized out>, vma@entry=0xffff888166099130, start_addr=start_addr@entry=0, end_addr=end_addr@entry=18446744073709551615) at mm/memory.c:1733
#8  0xffffffff812e5125 in exit_mmap (mm=mm@entry=0xffff888162ce5d80) at mm/mmap.c:3087
#9  0xffffffff81109891 in __mmput (mm=0xffff888162ce5d80) at kernel/fork.c:1185
#10 0xffffffff8110997e in mmput (mm=<optimized out>) at kernel/fork.c:1207
#11 0xffffffff811126a9 in exit_mm () at kernel/exit.c:516
#12 do_exit (code=code@entry=32512) at kernel/exit.c:807
#13 0xffffffff81112f28 in do_group_exit (exit_code=32512) at kernel/exit.c:950
#14 0xffffffff81112f8f in __do_sys_exit_group (error_code=<optimized out>) at kernel/exit.c:961
#15 __se_sys_exit_group (error_code=<optimized out>) at kernel/exit.c:959
#16 __x64_sys_exit_group (regs=<optimized out>) at kernel/exit.c:959
#17 0xffffffff81fa3bdb in do_syscall_x64 (nr=<optimized out>, regs=0xffffc90001a93f58) at arch/x86/entry/common.c:50
#18 do_syscall_64 (regs=0xffffc90001a93f58, nr=<optimized out>) at arch/x86/entry/common.c:80
#19 0xffffffff8200009b in entry_SYSCALL_64 () at arch/x86/entry/entry_64.S:120
#20 0x0000000000000000 in ?? ()
```
