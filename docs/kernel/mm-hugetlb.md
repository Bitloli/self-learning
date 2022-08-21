## 如何使用内核参数预留 hugetlb

- 无需考虑碎片化的问题。
- 内核不用使用这些页面。
- 不用 swap 的。
- 其 cgroup 是单独分析的。

alloc_fresh_huge_page

- 分配过程中，如何逐个地被 memory policy ，cpuset 和 cgroup 管理

## [ ] 一个 mmap 的时候，其中是否可以同时包含两种 page

## 理解一下核心结构体

```c
struct hstate {
	struct mutex resize_lock;
	int next_nid_to_alloc;
	int next_nid_to_free;
	unsigned int order;
	unsigned int demote_order;
	unsigned long mask;
	unsigned long max_huge_pages;
	unsigned long nr_huge_pages;
	unsigned long free_huge_pages;
	unsigned long resv_huge_pages;
	unsigned long surplus_huge_pages;
	unsigned long nr_overcommit_huge_pages;
	struct list_head hugepage_activelist;
	struct list_head hugepage_freelists[MAX_NUMNODES];
	unsigned int max_huge_pages_node[MAX_NUMNODES];
	unsigned int nr_huge_pages_node[MAX_NUMNODES];
	unsigned int free_huge_pages_node[MAX_NUMNODES];
	unsigned int surplus_huge_pages_node[MAX_NUMNODES];
#ifdef CONFIG_CGROUP_HUGETLB
	/* cgroup control files */
	struct cftype cgroup_files_dfl[8];
	struct cftype cgroup_files_legacy[10];
#endif
	char name[HSTATE_NAME_LEN];
};
```
总共的统计数据和所有的统计数据:

- [ ] hugepage_activelist ：没有搞懂这个和 memory policy , migrate 和 cgroup 的关系

- nr_overcommit_huge_pages ：当前可以超过使用的 page
- surplus_huge_pages : 当前实际上使用的 page
  - 两者的关系可以从 alloc_surplus_huge_page 轻松的看到

## [ ] hstate_is_gigantic
- 为什么到处都是这个东西的判断?

- alloc_surplus_huge_page : 如果是 gigantic ，那么直接失败，因为 surplus 的需要从 buddy 中申请


## [ ] transpaent huge page 的代码量为什么少，到底是为了处理什么问题，让 hugetlb 如此复杂

## [ ] overcommit 工作的

## [ ] demote 如何工作的

## [ ] alloc_buddy_huge_page_with_mpol 为什么正好在  dequeue_huge_page_vma 分配不出来的时候进行

dequeue_huge_page_vma 中还是有 memory policy 的代码的啊

之后还有
```c
	hugetlb_cgroup_commit_charge(idx, pages_per_huge_page(h), h_cg, page);
```


## TODO
- https://zhuanlan.zhihu.com/p/392703566
- [ ] transparent huge tlb 的论文找过来一下，实际上，没有人使用这个。
- [ ] https://stackoverflow.com/questions/67991417/how-to-use-hugepages-with-tmpfs
- [ ] mem_cgroup_charge 是用户态分配内存检查的位置，但是为什么 hugetlb 的分配是完全没有使用
  - 或者说 hugetlb 的 memcg 在什么位置
- [ ] echo 20 > /proc/sys/vm/nr_hugepages 是做什么的?
- [ ] ➜  linux git:(master) ✗ /home/martins3/core/linux/Documentation/translations/zh_CN/mm/hugetlbfs_reserv.rst
- [ ] https://www.kernel.org/doc/html/latest/admin-guide/mm/hugetlbpage.html

## CONFIG_CONTIG_ALLOC 是做什么

```txt
config CONTIG_ALLOC
	def_bool (MEMORY_ISOLATION && COMPACTION) || CMA
```
是否可以分配连续的内存

- alloc_fresh_huge_page，从 buddy 中获取，如果没有被这个打开，无法获取连续的 page，直接失败。

## [ ] dissolve_free_huge_page 被 memory_failure 和 memory hotplug 有关的

## [ ] 是在什么时间点预留的

## [ ] 预留的时候如何考虑 numa 的

## [ ] 为什么需要借助 fs 的存在

## [ ] 预留的时候需要制定每一种大小的 page 的数量吗

## [x] 如果 hugetlb_file_setup 是入口，那个文件系统还需要使用吗

ksys_mmap_pgoff 中处理过，

## [ ] init_hugetlbfs_fs 是什么时候调用的

## [ ] init_hugetlbfs_fs 中，似乎每一个 size 都是单独的一个 mount 点

## [ ] 测试一下 hugetlbfs_symlink / hugetlbfs_tmpfile

默认的 mount 点:
```txt
hugetlbfs /dev/hugepages hugetlbfs rw,seclabel,relatime,pagesize=1024M 0 0
```
libhugetlbfs 中有个函数 : `hugetlbfs_find_path_for_size`

- hugetlb_file_setup
  - hugetlb_reserve_pages
  - alloc_file_pseudo ：如果成功，该文件关联的的 hugetlbfs_file_operations

- [ ] hugetlbfs_read_iter : 这个是做啥的

```c
struct hugetlbfs_inode_info {
	struct shared_policy policy;
	struct inode vfs_inode;
	unsigned int seals;
};
```
- [ ] `hugetlbfs_setattr` 中为什么需要修改 inode 的大小

- [ ] 我是没有想到，居然 2021 才支持的: https://lwn.net/Articles/872070/
  - https://stackoverflow.com/questions/27997934/mremap2-with-hugetlb-to-change-virtual-address : 直接可以通过 hugetlbfs 来实现


## [ ] vm_operations_struct

```txt
#0  hugetlb_vm_op_close (vma=0xffff8883086d03c0) at include/linux/hugetlb.h:720
#1  0xffffffff812c58c9 in remove_vma (vma=vma@entry=0xffff8883086d03c0) at mm/mmap.c:143
#2  0xffffffff812c8363 in exit_mmap (mm=mm@entry=0xffff888300244800) at mm/mmap.c:3121
#3  0xffffffff810ff6ed in __mmput (mm=0xffff888300244800) at kernel/fork.c:1187
#4  mmput (mm=mm@entry=0xffff888300244800) at kernel/fork.c:1208
#5  0xffffffff811085db in exit_mm () at kernel/exit.c:510
#6  do_exit (code=code@entry=0) at kernel/exit.c:782
#7  0xffffffff81108e58 in do_group_exit (exit_code=0) at kernel/exit.c:925
#8  0xffffffff81108ecf in __do_sys_exit_group (error_code=<optimized out>) at kernel/exit.c:936
#9  __se_sys_exit_group (error_code=<optimized out>) at kernel/exit.c:934
#10 __x64_sys_exit_group (regs=<optimized out>) at kernel/exit.c:934
#11 0xffffffff81ea93c8 in do_syscall_x64 (nr=<optimized out>, regs=0xffffc900005a7f58) at arch/x86/entry/common.c:50
#12 do_syscall_64 (regs=0xffffc900005a7f58, nr=<optimized out>) at arch/x86/entry/common.c:80
#13 0xffffffff8200009b in entry_SYSCALL_64 () at arch/x86/entry/entry_64.S:120
#14 0x0000000000000000 in ?? ()
```

```txt
const struct vm_operations_struct hugetlb_vm_ops = {
	.fault = hugetlb_vm_op_fault,
	.open = hugetlb_vm_op_open,
	.close = hugetlb_vm_op_close,
	.may_split = hugetlb_vm_op_split,
	.pagesize = hugetlb_vm_op_pagesize,
};
```
- hugetlb_vm_op_open 不会被调用，是因为其只是在被 copy 的时候才有用的。

## 和 gup 还有关系，靠
- follow_huge_pud 和类似的一堆函数 follow 函数

## 和 memory policy 有关系的

## 分配和回收是如何进行的

- enqueue_huge_page
```txt
#0  enqueue_huge_page (h=h@entry=0xffffffff834abe20 <hstates>, page=page@entry=0xffffea000b000000) at mm/hugetlb.c:1114
#1  0xffffffff812f0d4f in free_huge_page (page=0xffffea000b000000) at mm/hugetlb.c:1734
#2  0xffffffff8128c8bb in __folio_put_large (folio=<optimized out>) at mm/swap.c:118
#3  release_pages (pages=pages@entry=0xffffc9000054fe38, nr=nr@entry=8) at mm/swap.c:978
#4  0xffffffff812e62e5 in free_pages_and_swap_cache (pages=pages@entry=0xffffc9000054fe38, nr=nr@entry=8) at mm/swap_state.c:311
#5  0xffffffff812ca608 in tlb_batch_pages_flush (tlb=tlb@entry=0xffffc9000054fdf8) at mm/mmu_gather.c:58
#6  0xffffffff812cabb0 in tlb_flush_mmu_free (tlb=0xffffc9000054fdf8) at mm/mmu_gather.c:255
#7  tlb_flush_mmu (tlb=0xffffc9000054fdf8) at mm/mmu_gather.c:262
#8  tlb_finish_mmu (tlb=tlb@entry=0xffffc9000054fdf8) at mm/mmu_gather.c:353
#9  0xffffffff812c8346 in exit_mmap (mm=mm@entry=0xffff88830211fc00) at mm/mmap.c:3115
#10 0xffffffff810ff6ed in __mmput (mm=0xffff88830211fc00) at kernel/fork.c:1187
#11 mmput (mm=mm@entry=0xffff88830211fc00) at kernel/fork.c:1208
#12 0xffffffff811085db in exit_mm () at kernel/exit.c:510
#13 do_exit (code=code@entry=0) at kernel/exit.c:782
#14 0xffffffff81108e58 in do_group_exit (exit_code=0) at kernel/exit.c:925
#15 0xffffffff81108ecf in __do_sys_exit_group (error_code=<optimized out>) at kernel/exit.c:936
#16 __se_sys_exit_group (error_code=<optimized out>) at kernel/exit.c:934
#17 __x64_sys_exit_group (regs=<optimized out>) at kernel/exit.c:934
#18 0xffffffff81ea93c8 in do_syscall_x64 (nr=<optimized out>, regs=0xffffc9000054ff58) at arch/x86/entry/common.c:50
#19 do_syscall_64 (regs=0xffffc9000054ff58, nr=<optimized out>) at arch/x86/entry/common.c:80
#20 0xffffffff8200009b in entry_SYSCALL_64 () at arch/x86/entry/entry_64.S:120
#21 0x0000000000000000 in ?? ()
```

```txt
#0  dequeue_huge_page_nodemask (h=h@entry=0xffffffff834abe20 <hstates>, gfp_mask=1051842, nid=0, nmask=nmask@entry=0x0 <fixed_percpu_data>) at include/linux/gfp.h
:170
#1  0xffffffff812f1f74 in dequeue_huge_page_vma (chg=<optimized out>, avoid_reserve=<optimized out>, address=140629040431104, vma=0xffff88830ed12000, h=0xffffffff
834abe20 <hstates>) at mm/hugetlb.c:1220
#2  alloc_huge_page (vma=vma@entry=0xffff88830ed12000, addr=addr@entry=140629040431104, avoid_reserve=avoid_reserve@entry=0) at mm/hugetlb.c:2925
#3  0xffffffff812f5a25 in hugetlb_no_page (flags=597, old_pte=..., ptep=0xffff888300351cd8, address=140629040431104, idx=0, mapping=0xffff8883003f4188, vma=0xffff
88830ed12000, mm=0xffff888301a8bc00) at mm/hugetlb.c:5545
#4  hugetlb_fault (mm=0xffff888301a8bc00, vma=vma@entry=0xffff88830ed12000, address=address@entry=140629040431104, flags=flags@entry=597) at mm/hugetlb.c:5763
#5  0xffffffff812bdf9b in handle_mm_fault (vma=0xffff88830ed12000, address=address@entry=140629040431104, flags=flags@entry=597, regs=regs@entry=0xffffc9000057ff5
8) at mm/memory.c:5149
#6  0xffffffff810f29a3 in do_user_addr_fault (regs=regs@entry=0xffffc9000057ff58, error_code=error_code@entry=6, address=address@entry=140629040431104) at arch/x8
6/mm/fault.c:1397
#7  0xffffffff81ead672 in handle_page_fault (address=140629040431104, error_code=6, regs=0xffffc9000057ff58) at arch/x86/mm/fault.c:1488
#8  exc_page_fault (regs=0xffffc9000057ff58, error_code=6) at arch/x86/mm/fault.c:1544
#9  0xffffffff82000b62 in asm_exc_page_fault () at ./arch/x86/include/asm/idtentry.h:570
#10 0x0000000000000000 in ?? ()
```

hugetlb_vm_op_fault 是一定不会触发的，因为很早的时候就已经被 handle_mm_fault 中被劫持了。

- [ ] 但是为什么不使用常规路径哇，而是非要改动主线代码?



## reservation
- [ ] hugetlb_vm_op_open 处理 reservation 的

```txt
#0  region_add (resv=resv@entry=0xffff8883063e73c0, f=0, t=1, in_regions_needed=in_regions_needed@entry=1, h=h@entry=0x0 <fixed_percpu_data>, h_cg=h_cg@entry=0x0
<fixed_percpu_data>) at mm/hugetlb.c:531
#1  0xffffffff812ef70c in __vma_reservation_common (h=<optimized out>, vma=0xffff88830631de40, addr=<optimized out>, mode=VMA_COMMIT_RESV) at mm/hugetlb.c:2532
#2  0xffffffff812f210e in vma_commit_reservation (addr=140508781346816, vma=0xffff88830631de40, h=0xffffffff834abe20 <hstates>) at mm/hugetlb.c:2597
#3  alloc_huge_page (vma=vma@entry=0xffff88830631de40, addr=addr@entry=140508781346816, avoid_reserve=avoid_reserve@entry=0) at mm/hugetlb.c:2952
#4  0xffffffff812f5a25 in hugetlb_no_page (flags=597, old_pte=..., ptep=0xffff88830085a958, address=140508781346816, idx=0, mapping=0xffff888302fbc410, vma=0xffff
88830631de40, mm=0xffff888300246c00) at mm/hugetlb.c:5545
#5  hugetlb_fault (mm=0xffff888300246c00, vma=vma@entry=0xffff88830631de40, address=address@entry=140508781346816, flags=flags@entry=597) at mm/hugetlb.c:5763
#6  0xffffffff812bdf9b in handle_mm_fault (vma=0xffff88830631de40, address=address@entry=140508781346816, flags=flags@entry=597, regs=regs@entry=0xffffc900005c7f5
8) at mm/memory.c:5149
#7  0xffffffff810f29a3 in do_user_addr_fault (regs=regs@entry=0xffffc900005c7f58, error_code=error_code@entry=6, address=address@entry=140508781346816) at arch/x8
6/mm/fault.c:1397
#8  0xffffffff81ead672 in handle_page_fault (address=140508781346816, error_code=6, regs=0xffffc900005c7f58) at arch/x86/mm/fault.c:1488
```

## vma_resv_map 到底是做啥用的
```txt
#0  0xffffffff812ef611 in vma_resv_map (vma=<optimized out>) at mm/hugetlb.c:974
#1  __vma_reservation_common (h=0xffffffff834abe20 <hstates>, vma=0xffff88830631de40, addr=140508781346816, mode=VMA_NEEDS_RESV) at mm/hugetlb.c:2517
#2  0xffffffff812f623a in vma_needs_reservation (addr=140508781346816, vma=0xffff88830631de40, h=0xffffffff834abe20 <hstates>) at mm/hugetlb.c:2591
#3  hugetlb_no_page (flags=597, old_pte=..., ptep=0xffff88830085a958, address=140508781346816, idx=<optimized out>, mapping=0xffff888302fbc410, vma=0xffff88830631
de40, mm=0xffff888300246c00) at mm/hugetlb.c:5617
#4  hugetlb_fault (mm=0xffff888300246c00, vma=vma@entry=0xffff88830631de40, address=address@entry=140508781346816, flags=flags@entry=597) at mm/hugetlb.c:5763
#5  0xffffffff812bdf9b in handle_mm_fault (vma=0xffff88830631de40, address=address@entry=140508781346816, flags=flags@entry=597, regs=regs@entry=0xffffc900005c7f5
8) at mm/memory.c:5149
#6  0xffffffff810f29a3 in do_user_addr_fault (regs=regs@entry=0xffffc900005c7f58, error_code=error_code@entry=6, address=address@entry=140508781346816) at arch/x8
6/mm/fault.c:1397
#7  0xffffffff81ead672 in handle_page_fault (address=140508781346816, error_code=6, regs=0xffffc900005c7f58) at arch/x86/mm/fault.c:1488
#8  exc_page_fault (regs=0xffffc900005c7f58, error_code=6) at arch/x86/mm/fault.c:1544
#9  0xffffffff82000b62 in asm_exc_page_fault () at ./arch/x86/include/asm/idtentry.h:570
#10 0x0000000000000000 in ?? ()
```
- 在 page fault 的时候 reserve 有点说不过吧

```txt
#0  0xffffffff812ef611 in vma_resv_map (vma=<optimized out>) at mm/hugetlb.c:974
#1  __vma_reservation_common (h=0xffffffff834abe20 <hstates>, vma=0xffff88830631de40, addr=140508781346816, mode=VMA_END_RESV) at mm/hugetlb.c:2517
#2  0xffffffff812f6252 in vma_end_reservation (addr=140508781346816, vma=0xffff88830631de40, h=0xffffffff834abe20 <hstates>) at mm/hugetlb.c:2603
#3  hugetlb_no_page (flags=597, old_pte=..., ptep=0xffff88830085a958, address=140508781346816, idx=<optimized out>, mapping=0xffff888302fbc410, vma=0xffff88830631
de40, mm=0xffff888300246c00) at mm/hugetlb.c:5622
#4  hugetlb_fault (mm=0xffff888300246c00, vma=vma@entry=0xffff88830631de40, address=address@entry=140508781346816, flags=flags@entry=597) at mm/hugetlb.c:5763
#5  0xffffffff812bdf9b in handle_mm_fault (vma=0xffff88830631de40, address=address@entry=140508781346816, flags=flags@entry=597, regs=regs@entry=0xffffc900005c7f5
8) at mm/memory.c:5149
#6  0xffffffff810f29a3 in do_user_addr_fault (regs=regs@entry=0xffffc900005c7f58, error_code=error_code@entry=6, address=address@entry=140508781346816) at arch/x8
6/mm/fault.c:1397
#7  0xffffffff81ead672 in handle_page_fault (address=140508781346816, error_code=6, regs=0xffffc900005c7f58) at arch/x86/mm/fault.c:1488
#8  exc_page_fault (regs=0xffffc900005c7f58, error_code=6) at arch/x86/mm/fault.c:1544
#9  0xffffffff82000b62 in asm_exc_page_fault () at ./arch/x86/include/asm/idtentry.h:570
#10 0x0000000000000000 in ?? ()
```

```txt
#0  vma_resv_map (vma=0xffff88830631de40) at mm/hugetlb.c:974
#1  hugetlb_vm_op_close (vma=0xffff88830631de40) at mm/hugetlb.c:4589
#2  0xffffffff812c58c9 in remove_vma (vma=vma@entry=0xffff88830631de40) at mm/mmap.c:143
#3  0xffffffff812c8363 in exit_mmap (mm=mm@entry=0xffff888300246c00) at mm/mmap.c:3121
#4  0xffffffff810ff6ed in __mmput (mm=0xffff888300246c00) at kernel/fork.c:1187
#5  mmput (mm=mm@entry=0xffff888300246c00) at kernel/fork.c:1208
#6  0xffffffff811085db in exit_mm () at kernel/exit.c:510
#7  do_exit (code=code@entry=0) at kernel/exit.c:782
#8  0xffffffff81108e58 in do_group_exit (exit_code=0) at kernel/exit.c:925
#9  0xffffffff81108ecf in __do_sys_exit_group (error_code=<optimized out>) at kernel/exit.c:936
#10 __se_sys_exit_group (error_code=<optimized out>) at kernel/exit.c:934
#11 __x64_sys_exit_group (regs=<optimized out>) at kernel/exit.c:934
#12 0xffffffff81ea93c8 in do_syscall_x64 (nr=<optimized out>, regs=0xffffc900005c7f58) at arch/x86/entry/common.c:50
#13 do_syscall_64 (regs=0xffffc900005c7f58, nr=<optimized out>) at arch/x86/entry/common.c:80
#14 0xffffffff8200009b in entry_SYSCALL_64 () at arch/x86/entry/entry_64.S:120
#15 0x0000000000000000 in ?? ()
```

reservation 应该是创建的时候就存在的，但是为什么要设计出来 commit 之类的操作

- [ ] huge page 可以从

## pool

- [ ] subpool 是个什么概念

通过触发 /proc/sys/vm/nr_hugepages 来控制 pool 中的 pages 的数量
```txt
#0  remove_pool_huge_page (h=h@entry=0xffffffff834abe20 <hstates>, nodes_allowed=nodes_allowed@entry=0xffffffff82cf8218 <node_states+24>, acct_surplus=acct_surplu
s@entry=false) at mm/hugetlb.c:2041
#1  0xffffffff812f0321 in set_max_huge_pages (h=h@entry=0xffffffff834abe20 <hstates>, count=count@entry=4, nid=nid@entry=-1, nodes_allowed=0xffffffff82cf8218 <nod
e_states+24>) at mm/hugetlb.c:3393
#2  0xffffffff812f05c8 in __nr_hugepages_store_common (len=2, count=4, nid=-1, h=0xffffffff834abe20 <hstates>, obey_mempolicy=false) at mm/hugetlb.c:3582
#3  hugetlb_sysctl_handler_common (obey_mempolicy=<optimized out>, table=<optimized out>, write=<optimized out>, buffer=<optimized out>, length=<optimized out>, p
pos=<optimized out>) at mm/hugetlb.c:4385
#4  0xffffffff813a9c2e in proc_sys_call_handler (iocb=0xffffc90000a63ea0, iter=0xffffc90000a63e78, write=<optimized out>) at fs/proc/proc_sysctl.c:611
#5  0xffffffff8131d309 in call_write_iter (iter=0xffffffff82cf8218 <node_states+24>, kio=0xffffffff834abe20 <hstates>, file=0xffff88830ec92200) at include/linux/f
s.h:2187
#6  new_sync_write (ppos=0xffffc90000a63f08, len=2, buf=0x7f90eb632000 "4\n", filp=0xffff88830ec92200) at fs/read_write.c:491
#7  vfs_write (file=file@entry=0xffff88830ec92200, buf=buf@entry=0x7f90eb632000 "4\n", count=count@entry=2, pos=pos@entry=0xffffc90000a63f08) at fs/read_write.c:5
78
#8  0xffffffff8131d6da in ksys_write (fd=<optimized out>, buf=0x7f90eb632000 "4\n", count=2) at fs/read_write.c:631
#9  0xffffffff81ea93c8 in do_syscall_x64 (nr=<optimized out>, regs=0xffffc90000a63f58) at arch/x86/entry/common.c:50
#10 do_syscall_64 (regs=0xffffc90000a63f58, nr=<optimized out>) at arch/x86/entry/common.c:80
#11 0xffffffff8200009b in entry_SYSCALL_64 () at arch/x86/entry/entry_64.S:120
#12 0x0000000000000000 in ?? ()
```

## hugepage_subpool_get_pages

居然是在 mmap 的时候创建分配的
```txt
#0  hugepage_subpool_get_pages (delta=1, spool=0x0 <fixed_percpu_data>) at mm/hugetlb.c:169
#1  hugetlb_reserve_pages (inode=inode@entry=0xffff888302fbc298, from=0, to=1, vma=vma@entry=0xffff888309e5b240, vm_flags=<optimized out>) at mm/hugetlb.c:6510
#2  0xffffffff81432f48 in hugetlbfs_file_mmap (file=0xffff888301e4cc00, vma=0xffff888309e5b240) at fs/hugetlbfs/inode.c:167
#3  0xffffffff812c9800 in call_mmap (vma=0xffff888309e5b240, file=0xffff888301e4cc00) at include/linux/fs.h:2192
#4  mmap_region (file=file@entry=0xffff888301e4cc00, addr=addr@entry=139922518310912, len=len@entry=1073741824, vm_flags=vm_flags@entry=115, pgoff=<optimized out>
, uf=uf@entry=0xffffc90000c43eb0) at mm/mmap.c:1749
#5  0xffffffff812c9dbe in do_mmap (file=file@entry=0xffff888301e4cc00, addr=139922518310912, addr@entry=0, len=len@entry=1073741824, prot=<optimized out>, prot@en
try=3, flags=flags@entry=262178, pgoff=<optimized out>, pgoff@entry=0, populate=0xffffc90000c43ea8, uf=0xffffc90000c43eb0) at mm/mmap.c:1540
#6  0xffffffff8129ec35 in vm_mmap_pgoff (file=file@entry=0xffff888301e4cc00, addr=addr@entry=0, len=len@entry=1073741824, prot=prot@entry=3, flag=flag@entry=26217
8, pgoff=pgoff@entry=0) at mm/util.c:552
#7  0xffffffff812c7133 in ksys_mmap_pgoff (addr=0, len=1073741824, prot=3, flags=262178, fd=<optimized out>, pgoff=0) at mm/mmap.c:1586
#8  0xffffffff81ea93c8 in do_syscall_x64 (nr=<optimized out>, regs=0xffffc90000c43f58) at arch/x86/entry/common.c:50
#9  do_syscall_64 (regs=0xffffc90000c43f58, nr=<optimized out>) at arch/x86/entry/common.c:80
#10 0xffffffff8200009b in entry_SYSCALL_64 () at arch/x86/entry/entry_64.S:120
#11 0x0000000000000003 in fixed_percpu_data ()
#12 0xffffffffffffffff in ?? ()
#13 0x0000000000000000 in ?? ()
```

- alloc_huge_page 中间干了什么 ?
  - 调用 dequeue_huge_page_vma

## 到底是如何分配的
- hugetlb_hstate_alloc_pages ：这个是初始化的注册的函数

- alloc_fresh_huge_page

## 启动过程中，如何预留的

这是参数解析的时候
```txt
#0  hugetlb_hstate_alloc_pages (h=0xffffffff834abe20 <hstates>) at mm/hugetlb.c:3088
#1  0xffffffff832fbd53 in hugepages_setup (s=0xffff88833fff186a "8") at mm/hugetlb.c:4221
#2  0xffffffff832cf89b in obsolete_checksetup (line=0xffff88833fff1860 "hugepages=8") at init/main.c:219
#3  unknown_bootoption (param=0xffff88833fff1860 "hugepages=8", val=val@entry=0xffff88833fff186a "8", unused=unused@entry=0xffffffff827eb41c "Booting kernel", arg
=arg@entry=0x0 <fixed_percpu_data>) at init/main.c:539
#4  0xffffffff81127893 in parse_one (handle_unknown=0xffffffff832cf801 <unknown_bootoption>, arg=0x0 <fixed_percpu_data>, max_level=-1, min_level=-1, num_params=5
84, params=0xffffffff829aecb8 <__param_initcall_debug>, doing=0xffffffff827eb41c "Booting kernel", val=0xffff88833fff186a "8", param=0xffff88833fff1860 "hugepages
=8") at kernel/params.c:153
#5  parse_args (doing=doing@entry=0xffffffff827eb41c "Booting kernel", args=0xffff88833fff186b "", params=0xffffffff829aecb8 <__param_initcall_debug>, num=584, mi
n_level=min_level@entry=-1, max_level=max_level@entry=-1, arg=0x0 <fixed_percpu_data>, unknown=0xffffffff832cf801 <unknown_bootoption>) at kernel/params.c:188
#6  0xffffffff832cfe00 in start_kernel () at init/main.c:967
#7  0xffffffff81000145 in secondary_startup_64 () at arch/x86/kernel/head_64.S:358
#8  0x0000000000000000 in ?? ()
```

这是 initcalls 得到的
```txt
#0  hugetlb_hstate_alloc_pages (h=h@entry=0xffffffff834ad5e8 <hstates+6088>) at mm/hugetlb.c:3088
#1  0xffffffff832fc0d1 in hugetlb_init_hstates () at mm/hugetlb.c:3157
#2  hugetlb_init () at mm/hugetlb.c:4069
#3  0xffffffff81000e7c in do_one_initcall (fn=0xffffffff832fbf41 <hugetlb_init>) at init/main.c:1296
#4  0xffffffff832d0491 in do_initcall_level (command_line=0xffff888300804180 "root", level=4) at init/main.c:1369
#5  do_initcalls () at init/main.c:1385
#6  do_basic_setup () at init/main.c:1404
#7  kernel_init_freeable () at init/main.c:1611
#8  0xffffffff81eae271 in kernel_init (unused=<optimized out>) at init/main.c:1500
#9  0xffffffff81001a8f in ret_from_fork () at arch/x86/entry/entry_64.S:306
#10 0x0000000000000000 in ?? ()
```

- 为什么要调用两次哇

## 需要分析的

首先，注意区分一下
```txt
obj-$(CONFIG_HUGETLBFS)	+= hugetlb.o
obj-$(CONFIG_CGROUP_HUGETLB) += hugetlb_cgroup.o
obj-$(CONFIG_TRANSPARENT_HUGEPAGE) += huge_memory.o khugepaged.o
```
- [ ] https://lwn.net/Articles/839737/
  - https://lwn.net/ml/linux-kernel/20201210035526.38938-1-songmuchun@bytedance.com/

## 首先使用起来
- https://github.com/lagopus/lagopus/blob/master/docs/how-to-allocate-1gb-hugepages.md

## hugetlb

1. 为了实现简单，那么 hugetlb 减少处理什么东西 ?

https://www.ibm.com/developerworks/cn/linux/l-cn-hugetlb/
https://www.ibm.com/developerworks/cn/linux/1305_zhangli_hugepage/index.html

总结一下 :
1. subpool, resv_map , enqueue 机制
2. hugetlb_file_setup hugetlb_fault 和对外提供的关键接口
3. 利用 sys 提供了很多接口

Huge pages can improve performance through reduced page faults (a single fault brings in a large chunk of memory at once) and by reducing the cost of virtual to physical address translation (fewer levels of page tables must be traversed to get to the physical address).

用户层 : https://lwn.net/Articles/375096/ 中间的使用首先理解清楚吧 !

https://github.com/libhugetlbfs/libhugetlbfs
> 其中包含有大量的测试
The library provides support for automatically backing text, data, heap and shared memory segments with huge pages.
In addition, this package also provides a programming API and manual pages. The behaviour of the library is controlled by environment variables (as described in the libhugetlbfs.7 manual page) with a launcher utility hugectl that knows how to configure almost all of the variables. hugeadm, hugeedit and pagesize provide information about the system and provide support to system administration. tlbmiss_cost.sh automatically calculates the average cost of a TLB miss. cpupcstat and oprofile_start.sh provide help with monitoring the current behaviour of the system. Manual pages are available describing in further detail each utility.

1. shmget() : SHM_HUGETLB
2. hugetlbfs : 似乎用户共享的，同时可以用于实现

```c
       #include <hugetlbfs.h>
       int hugetlbfs_unlinked_fd(void);
       int hugetlbfs_unlinked_fd_for_size(long page_size);
       // hugetlbfs_unlinked_fd, hugetlbfs_unlinked_fd_for_size - Obtain a file descriptor for a new unlinked file in hugetlbfs
```


One important common point between them all is how huge pages are faulted and when the huge pages are allocated.
Further, there are important differences between shared and private mappings depending on the exact kernel version used. [^1]
> 重点处理的方面

1. fault
2. shared/private
3. hugetlb 不处理 swap

和正常大小的 page 的比较
1. hugetlb_fault

2. include/asm-generic/hugetlb.h : 如果架构含有关于 page table 的不同处理，
那么就可以使用

- [ ] 了解一下，从 mmap 的进入到 hugetlb
  - [ ] 似乎还可以在 hugetlb 的文件系统中间创建文件，然后 open ?

[HugeTLB Pages](https://www.kernel.org/doc/html/latest/admin-guide/mm/hugetlbpage.html) 的阅读结果 ：

> /proc/sys/vm/nr_hugepages indicates the current number of “persistent” huge pages in the kernel’s huge page pool. “Persistent” huge pages will be returned to the huge page pool when freed by a task. A user with root privileges can dynamically allocate more or free some persistent huge pages by increasing or decreasing the value of nr_hugepages.
>
> Pages that are used as huge pages are reserved inside the kernel and **cannot** be used for other purposes. Huge pages cannot be swapped out under memory pressure.
>
> Once a number of huge pages have been pre-allocated to the kernel huge page pool, a user with appropriate privilege can use either the mmap system call or shared memory system calls to use the huge pages.

- [ ] 是不是没有 preallocated 的 page 会导致分配失败 ？

**TO BE CONTINUE**
- [ ] 这个文档还是没有看完的，感觉 hugetlb 设计有点问题

# hugetlbfs
如何分配 1G 的 page

1. 每一个 pagesize 都是添加一个大小
2. `gather_bootmem_prealloc` : 似乎的确对于 bootmem 存在特殊处理
3. 阅读 linhugetlbfs ，其大致的功能是 : 在该文件系统中间的 mmap 出来的都是 hugepage，但是现在不知道如何测试！
4. subpool 和 reserved map 都是为了 alloc huge page 处理的。
5. `alloc_huge_page` 还会处理 numa 之类的各种业务
6. `enqueue_huge_page` : huge page 的关系需要单独的分析。
7. page cache 相关的

```c
/*
 * node_hstate/s - associate per node hstate attributes, via their kobjects,
 * with node devices in node_devices[] using a parallel array.  The array
 * index of a node device or _hstate == node id.
 * This is here to avoid any static dependency of the node device driver, in
 * the base kernel, on the hugetlb module.
 */
struct node_hstate {
	struct kobject		*hugepages_kobj;
	struct kobject		*hstate_kobjs[HUGE_MAX_HSTATE];
};
static struct node_hstate node_hstates[MAX_NUMNODES];

struct hugepage_subpool {
	spinlock_t lock;
	long count;
	long max_hpages;	/* Maximum huge pages or -1 if no maximum. */
	long used_hpages;	/* Used count against maximum, includes */
				/* both alloced and reserved pages. */
	struct hstate *hstate;
	long min_hpages;	/* Minimum huge pages or -1 if no minimum. */
	long rsv_hpages;	/* Pages reserved against global pool to */
				/* sasitfy minimum size. */
};

struct resv_map {
	struct kref refs;
	spinlock_t lock;
	struct list_head regions;
	long adds_in_progress;
	struct list_head region_cache;
	long region_cache_count;
};
```

```c
#define HSTATE_NAME_LEN 32
/* Defines one hugetlb page size */
struct hstate {
	int next_nid_to_alloc;
	int next_nid_to_free;
	unsigned int order;
	unsigned long mask;
	unsigned long max_huge_pages;
	unsigned long nr_huge_pages;
	unsigned long free_huge_pages;
	unsigned long resv_huge_pages;
	unsigned long surplus_huge_pages;
	unsigned long nr_overcommit_huge_pages;
	struct list_head hugepage_activelist;
	struct list_head hugepage_freelists[MAX_NUMNODES];
	unsigned int nr_huge_pages_node[MAX_NUMNODES];
	unsigned int free_huge_pages_node[MAX_NUMNODES];
	unsigned int surplus_huge_pages_node[MAX_NUMNODES];
#ifdef CONFIG_CGROUP_HUGETLB
	/* cgroup control files */
	struct cftype cgroup_files_dfl[5];
	struct cftype cgroup_files_legacy[5];
#endif
	char name[HSTATE_NAME_LEN];
};
```

## hugepage_subpool
```c
struct hugepage_subpool *hugepage_new_subpool(struct hstate *h, long max_hpages,
						long min_hpages);
void hugepage_put_subpool(struct hugepage_subpool *spool);
```

被 hugetlbfs_fill_super 调用，也就是一个 mount point 对应一个.

pool 就会用于预留 hugepage


1. get pages
```c
/*
 * Subpool accounting for allocating and reserving pages.
 * Return -ENOMEM if there are not enough resources to satisfy the
 * the request.  Otherwise, return the number of pages by which the
 * global pools must be adjusted (upward).  The returned value may
 * only be different than the passed value (delta) in the case where
 * a subpool minimum size must be manitained.
 */
static long hugepage_subpool_get_pages(struct hugepage_subpool *spool,
				      long delta)
{
	long ret = delta;

	if (!spool)
		return ret;

	spin_lock(&spool->lock);

	if (spool->max_hpages != -1) {		/* maximum size accounting */
		if ((spool->used_hpages + delta) <= spool->max_hpages)
			spool->used_hpages += delta;
		else {
			ret = -ENOMEM;
			goto unlock_ret;
		}
	}

	/* minimum size accounting */
	if (spool->min_hpages != -1 && spool->rsv_hpages) {
		if (delta > spool->rsv_hpages) {
			/*
			 * Asking for more reserves than those already taken on
			 * behalf of subpool.  Return difference.
			 */
			ret = delta - spool->rsv_hpages;
			spool->rsv_hpages = 0;
		} else {
			ret = 0;	/* reserves already accounted for */
			spool->rsv_hpages -= delta;
		}
	}

unlock_ret:
	spin_unlock(&spool->lock);
	return ret;
}
```

2. put pages

```c
/*
 * Subpool accounting for freeing and unreserving pages.
 * Return the number of global page reservations that must be dropped.
 * The return value may only be different than the passed value (delta)
 * in the case where a subpool minimum size must be maintained.
 */
static long hugepage_subpool_put_pages(struct hugepage_subpool *spool,
				       long delta)
{
	long ret = delta;

	if (!spool)
		return delta;

	spin_lock(&spool->lock);

	if (spool->max_hpages != -1)		/* maximum size accounting */
		spool->used_hpages -= delta;

	 /* minimum size accounting */
	if (spool->min_hpages != -1 && spool->used_hpages < spool->min_hpages) {
		if (spool->rsv_hpages + delta <= spool->min_hpages)
			ret = 0;
		else
			ret = spool->rsv_hpages + delta - spool->min_hpages;

		spool->rsv_hpages += delta;
		if (spool->rsv_hpages > spool->min_hpages)
			spool->rsv_hpages = spool->min_hpages;
	}

	/*
	 * If hugetlbfs_put_super couldn't free spool due to an outstanding
	 * quota reference, free it now.
	 */
	unlock_or_release_subpool(spool);

	return ret;
}
```

## alloc_huge_page && hugetlb_reserve_pages
都是 hugepage_subpool_get_pages 打交道，只是一个在 page fault 的时候处理，一个是在 mmap 的时候

alloc_huge_page 调用位置 : hugetlb_cow(被 hugetlb_no_page 调用) hugetlb_no_page(被 hugetlb_fault 调用)

hugetlb_reserve_pages :  hugetlb_file_setup 和 hugetlbfs_file_mmap


## resv_map

```c
/*
 * Add the huge page range represented by [f, t) to the reserve
 * map.  Existing regions will be expanded to accommodate the specified
 * range, or a region will be taken from the cache.  Sufficient regions
 * must exist in the cache due to the previous call to region_chg with
 * the same range.
 *
 * Return the number of new huge pages added to the map.  This
 * number is greater than or equal to zero.
 */
static long region_add(struct resv_map *resv, long f, long t)

/*
 * vma_needs_reservation, vma_commit_reservation and vma_end_reservation
 * are used by the huge page allocation routines to manage reservations.
 *
 * vma_needs_reservation is called to determine if the huge page at addr
 * within the vma has an associated reservation.  If a reservation is
 * needed, the value 1 is returned.  The caller is then responsible for
 * managing the global reservation and subpool usage counts.  After
 * the huge page has been allocated, vma_commit_reservation is called
 * to add the page to the reservation map.  If the page allocation fails,
 * the reservation must be ended instead of committed.  vma_end_reservation
 * is called in such cases.
 *
 * In the normal case, vma_commit_reservation returns the same value
 * as the preceding vma_needs_reservation call.  The only time this
 * is not the case is if a reserve map was changed between calls.  It
 * is the responsibility of the caller to notice the difference and
 * take appropriate action.
 *
 * vma_add_reservation is used in error paths where a reservation must
 * be restored when a newly allocated huge page must be freed.  It is
 * to be called after calling vma_needs_reservation to determine if a
 * reservation exists.
 */
enum vma_resv_mode {
	VMA_NEEDS_RESV,
	VMA_COMMIT_RESV,
	VMA_END_RESV,
	VMA_ADD_RESV,
};
```

```c
/*
 * Region tracking -- allows tracking of reservations and instantiated pages
 *                    across the pages in a mapping.
 *
 * The region data structures are embedded into a resv_map and protected
 * by a resv_map's lock.  The set of regions within the resv_map represent
 * reservations for huge pages, or huge pages that have already been
 * instantiated within the map.  The from and to elements are huge page
 * indicies into the associated mapping.  from indicates the starting index
 * of the region.  to represents the first index past the end of  the region.
 *
 * For example, a file region structure with from == 0 and to == 4 represents
 * four huge pages in a mapping.  It is important to note that the to element
 * represents the first element past the end of the region. This is used in
 * arithmetic as 4(to) - 0(from) = 4 huge pages in the region.
 *
 * Interval notation of the form [from, to) will be used to indicate that
 * the endpoint from is inclusive and to is exclusive.
 */
struct file_region {
	struct list_head link;
	long from;
	long to;
};
```

> resv_map 就是给一个具体的 vma 处理的: @todo 但是为什么 vma 需要持有这个东西

```c
static struct resv_map *vma_resv_map(struct vm_area_struct *vma)
{
	VM_BUG_ON_VMA(!is_vm_hugetlb_page(vma), vma); // 首先这个 vma 必须持有这个东西
	if (vma->vm_flags & VM_MAYSHARE) {
		struct address_space *mapping = vma->vm_file->f_mapping;
		struct inode *inode = mapping->host;

		return inode_resv_map(inode);

	} else {
		return (struct resv_map *)(get_vma_private_data(vma) &
							~HPAGE_RESV_MASK);
	}
}
```

```c
/*
 * These helpers are used to track how many pages are reserved for
 * faults in a MAP_PRIVATE mapping. Only the process that called mmap()
 * is guaranteed to have their future faults succeed.
 *
 * With the exception of reset_vma_resv_huge_pages() which is called at fork(),
 * the reserve counters are updated with the hugetlb_lock held. It is safe
 * to reset the VMA at fork() time as it is not in use yet and there is no
 * chance of the global counters getting corrupted as a result of the values.
 *
 * The private mapping reservation is represented in a subtly different
 * manner to a shared mapping.  A shared mapping has a region map associated
 * with the underlying file, this region map represents the backing file
 * pages which have ever had a reservation assigned which this persists even
 * after the page is instantiated.  A private mapping has a region map
 * associated with the original mmap which is attached to all VMAs which
 * reference it, this region map represents those offsets which have consumed
 * reservation ie. where pages have been instantiated.
 */
static unsigned long get_vma_private_data(struct vm_area_struct *vma)
{
	return (unsigned long)vma->vm_private_data;
}
```






## syscontrol
```c
int hugetlb_sysctl_handler(struct ctl_table *, int, void __user *, size_t *, loff_t *);
int hugetlb_overcommit_handler(struct ctl_table *, int, void __user *, size_t *, loff_t *);
int hugetlb_treat_movable_handler(struct ctl_table *, int, void __user *, size_t *, loff_t *);

#ifdef CONFIG_NUMA
int hugetlb_mempolicy_sysctl_handler(struct ctl_table *, int,
					void __user *, size_t *, loff_t *);
#endif

unsigned long hugetlb_total_pages(void);
```

## misc
```c
int hugetlb_reserve_pages(struct inode *inode, long from, long to,
						struct vm_area_struct *vma,
						vm_flags_t vm_flags);
long hugetlb_unreserve_pages(struct inode *inode, long start, long end,
						long freed);
bool isolate_huge_page(struct page *page, struct list_head *list);
void putback_active_hugepage(struct page *page);
void move_hugetlb_state(struct page *oldpage, struct page *newpage, int reason);
void free_huge_page(struct page *page);
void hugetlb_fix_reserve_counts(struct inode *inode);
```





## 从用户层角度分析

```c
static inline bool is_file_hugepages(struct file *file)
{
	if (file->f_op == &hugetlbfs_file_operations) // 首先阅读一下 hugetlbfs 的作用吧
		return true;

	return is_file_shm_hugepages(file);
}
```

## core one : hugetlb_file_setup
1. 三个神奇的调用位置 : memfd.c mmap.c(mmap 系统调用必然经过) shmem.c(shmem 获取内存)
得出来的结论，这就是 hugetlb 提供的功能，也就是使用 hugetlb 都是需要创建对应的文件的


// 主要处理文件系统
```c
/*
* Note that size should be aligned to proper hugepage size in caller side,
 * otherwise hugetlb_reserve_pages reserves one less hugepages than intended.
 */
struct file *hugetlb_file_setup(const char *name, size_t size,
				vm_flags_t acctflag, struct user_struct **user,
				int creat_flags, int page_size_log)
```

2. hugetlb 并不一定总是需要 reserve_pages 的
```c
int hugetlb_reserve_pages(struct inode *inode,
					long from, long to,
					struct vm_area_struct *vma,
					vm_flags_t vm_flags)
```

## core two : hugetlb_fault


```c
/*
 * Hugetlb_cow() should be called with page lock of the original hugepage held.
 * Called with hugetlb_instantiation_mutex held and pte_page locked so we
 * cannot race with other handlers or page migration.
 * Keep the pte_same checks anyway to make transition from the mutex easier.
 */
static vm_fault_t hugetlb_cow(struct mm_struct *mm, struct vm_area_struct *vma,
		       unsigned long address, pte_t *ptep,
		       struct page *pagecache_page, spinlock_t *ptl)
```
