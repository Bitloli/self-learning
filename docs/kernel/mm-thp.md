## THP


- 原来的那个文章找过来看看

- [ ] PageDoubleMap
- [ ] THP only support PMD ? so can it support more than 2M space (21bit) ?
- [ ] https://gist.github.com/shino/5d9aac68e7ebf03d4962a4c07c503f7d, check references in it
- [ ] 提供的硬件支持是什么 ?
    - [ ] 除了在 pml4 pud pmd 的 page table 上的 flags
        - [ ] /sys/kernel/mm/transparent_hugepage/hpage_pmd_size 的含义看，实际上，内核只是支持一共大小的 hugepage
    - [ ] 需要提供 TLB 知道自己正在访问虚拟地址是否被 hugetlb 映射

transparent hugepage 和 swap 是相关的
使用 transparent hugepage 的原因:
1. TLB 的覆盖更大，可以降低 TLB miss rate
2. page fault 的次数更少，可以忽略不计
3. hugepage 的出现让原先的 page walk 的路径变短了

几个 THP 需要考虑的核心问题:
1. swap
2. reference 的问题
3. split 和 merge

## [The transparent huge page shrinker](https://lwn.net/Articles/906511/)

lwn 作者认为如果加上这个，那么 thp 就可以成为默认参数。

## how to disable thp
- https://www.thegeekdiary.com/centos-rhel-7-how-to-disable-transparent-huge-pages-thp/
  - 实际上，不仅仅需要在 grub 中 disable 的，而且需要考虑 tune


#### THP admin manual
[用户手册](https://www.kernel.org/doc/html/latest/admin-guide/mm/transhuge.html)

The THP behaviour is controlled via `sysfs` interface and using `madvise(2)` and `prctl(2)` system calls.

- [ ] how madvise and prctl control the THP

Currently THP **only works for** anonymous memory mappings and tmpfs/shmem. But in the future it can expand to other filesystems.

- [ ] so page cache can't work with THP ?

THP 相对于 hugetlbfs 的优势:
- Transparent Hugepage Support maximizes the usefulness of free memory if compared to the reservation approach of hugetlbfs by allowing all unused memory to be used as cache or other movable (or even unmovable entities).
- It doesn’t require reservation to prevent hugepage allocation failures to be noticeable from userland. *It allows paging and all other advanced VM features to be available on the hugepages.*
- It requires no modifications for applications to take advantage of it.

- [x] 在 hugepage 上可以使用 paging 等 advanced VM feaures. ( Paging is a mechanism that translates a linear memory address to a physical address.)
    - [x] paging sometimes meaning page fault

interface in sysfs :
1. /sys/kernel/mm/transparent_hugepage : always madvise never
2. /sys/kernel/mm/transparent_hugepage/defrag : always defer defer + madvise madvise never
3. You can control hugepage allocation policy in tmpfs with mount option huge=. It can have following values: always never advise deny force

- [ ] 应该按照手册，将手册中间的说明在内核中间一个个的找到
  - [ ] /sys/kernel/mm/transparent_hugepage
    - [ ] always 指的是任何位置都需要 hugepage 处理吗?
  - [ ] /sys/kernel/mm/transparent_hugepage/defrag 的 always 无法理解，或者说，什么时候应该触发 defrag, 不是分配的时候就是决定了吗 ?
- [ ] THP has to defrag pages, so check the compaction.c and find out how thp deal with it !
  - [ ] how defrag wake kcompactd ?

- [x] mmap 添加上 hugepage 的参数，是不是几乎等价于普通 mmap，然后 madvice
  - 不是，一个是 madvise， 一个是 thp

#### THP kernel
- mmap 和配合 hugetlb 使用的

- [ ] huge_memory.c 用于处理 split 和 各种参数
- [ ] khugepaged.c 用于 scan page 将 base page 转化为 hugepage
- [ ] 内核态分析: 透明的性质在于 `__handle_mm_fault` 中间就开始检查是否可以 由于 hugepage 会修改 page walk ，所以 pud_none 和 `__transparent_hugepage_enabled`
  - [ ] 检查更多的细节


- [ ] 从 madvise 到启动 THP
    - [ ] hugepage_vma_check : 到底那些 memory 不适合 thp
    - [x] `__khugepaged_enter` : 将所在的 mm_struct 放到 list 上，等待之后 khugepaged 会将该区域清理赶紧

- [ ] collapse_file : 处理 page cache / shmem / tmpfs
  - [ ] *caller*
      - [ ] khugepaged_scan_file
          - [ ] khugepaged_scan_mm_slot

- [ ] /sys/kernel/mm/transparent_hugepage 的真正含义 ?
    - [x] khugepaged_enter : 这是判断是否将该区域用于 transparent 的开始位置，[Transparent huge pages for filesystems](https://lwn.net/Articles/789159/) 中来看，现在支持 THP 只有 transparent hugepage 和 tmp memory 了
        - [x] do_huge_pmd_anonymous_page : 在 page fault 的时候，会首先进行 hugepage 检查，如果是 always, 那么**所有的 vma 都会被转换为 transparent hugepage**
            - [x] create_huge_pmd <= `__handle_mm_fault`

- [ ] 好吧，transparent hugepage 只是支持 pmd(从 /proc/meminfo 的 HugePagesize 和 /sys/kernel/mm/transparent_hugepage/hpage_pmd_size)，但是实际上 pud 也是支持的.

关键问题 A : do_huge_pmd_anonymous_page
1. 检查是否 vma 中间是否可以容纳 hugepage
2. 假如可以使用 zero page 机制
3. 利用 alloc_hugepage_direct_gfpmask 计算出来 buddy allocator 处理分配 hugepage 的找不到之后的策略，到底是等待，还是立刻失败，还是
4. prep_transhuge_page @todo 不知道干嘛的
5. `__do_huge_pmd_anonymous_page` : 将分配的 page 和 page table 组装
> 1. 进行分配的核心在于 : mempolicy.c 中间

关键问题 B : split_huge_page_to_list

不关键问题 A : vm_operations_struct::huge_fault 和 DAX 的关系不一般
不关键问题 A2 : vm_operations_struct 几乎没有一个可以理解的

khugepaged.c 中间的 hugepage 守护进程的工作是什么 ?

[Transparent huge page reference counting](https://lwn.net/Articles/619738/)

> In particular, he has eliminated the hard separation between normal and huge pages in the system. In current kernels, a specific 4KB page can be treated as an individual page, or it can be part of a huge page, but not both. If a huge page must be split into individual pages, it is split completely for all users, the compound page structure is torn down, and the huge page no longer exists. The fundamental change in Kirill's patch set is to allow a huge page to be split in one process's address space, while remaining a huge page in any other address space where it is found.

- [ ] what's the flag in PMD page table entry used to suggest the page is huge page ? verify it in intel manual.

- [ ] page_trans_huge_mapcount
- [ ] total_mapcount

[Transparent huge pages for filesystems](https://lwn.net/Articles/789159/)

> It is using the [Binary Optimization and Layout Tool (BOLT)](https://github.com/facebookincubator/BOLT) to profile its code in order to identify the hot functions. Those functions are collected up into an 8MB region in the generated executable.


#### THP khugepaged
- [ ] if `kcompactd` compact pages used by hugepage, and defrag pages by `split_huge_page_to_list`, so what's the purpose of khugepaged ?

1. /sys/kernel/mm/transparent_hugepage/enabled => start_stop_khugepaged => khugepaged => khugepaged_do_scan => khugepaged_scan_mm_slot => khugepaged_scan_pmd
2. in `khugepaged_scan_pmd`, we will check pages one by one, if enough base pages are found,  call `collapse_huge_page` to merge base page to huge page
3. `collapse_huge_page` = `khugepaged_alloc_page` + `__collapse_huge_page_copy` + many initialization for huge page + `__collapse_huge_page_isolate` (free base page)

- [x] it seems khugepaged scan pages and collapse it into huge pages, so what's difference between kcompactd
  - khugepaged is consumer of hugepage, it's scan base pages and collapse them
  - [ ] khugepaged 是用于扫描 base page 的 ? It’s the responsibility of khugepaged to then install the THP pages.

#### THP split
这几个文章都是讲解两种方案，很烦!
[Transparent huge pages in the page cache](https://lwn.net/Articles/686690/)
> Finally, a file may be used without being mapped into process memory at all, while anonymous memory is always mapped. So any changes to a filesystem to support transparent huge page mapping must not negatively impact normal read/write performance on an unmapped file.

- [x] 无论是在内核态和用户态中间，一个 huge page 都是可以随意拆分的，在用户态每个人都是不同的映射。在内核态，总是线性映射，pmd page table entry 的修改其实没有任何意义。
- [x] swap cache 的实现根本挑战在于区间的可以随意变化

[Improving huge page handling](https://lwn.net/Articles/636162/)

[Transparent huge page reference counting](https://lwn.net/Articles/619738/)
> In many other situations, Andrea placed a call to split_huge_page(), a function which breaks a huge page down into its component small pages.

> In other words, if split_huge_page() could be replaced by a new function, call it split_huge_pmd(), that would only split up a single process's mapping of a huge page, code needing to deal with individual pages could often be accommodated while preserving the benefits of the huge page for other processes. But, as noted above, the kernel currently does not support different mappings of huge pages; all processes must map the memory in the same way. This restriction comes down to how various parameters — reference counts in particular — are represented in huge pages.

> it must be replaced by a scheme that can track both the mappings to the huge page as a whole and the individual pages that make up that huge page.


```c
#define split_huge_pmd(__vma, __pmd, __address)       \
  do {                \
    pmd_t *____pmd = (__pmd);       \
    if (is_swap_pmd(*____pmd) || pmd_trans_huge(*____pmd) \
          || pmd_devmap(*____pmd))  \
      __split_huge_pmd(__vma, __pmd, __address, \
            false, NULL);   \
  }  while (0)
```

- [ ] split_huge_page_to_list
  - [ ] `__split_huge_page` : 不对劲，似乎 hugepage 只是体现在 struct page 上，而没有体现在 pmd 上
      - [x] 在 huge page 中间拆分出来几个当做其他的 page 正常使用, 虽然从中间抠出来的页面不可以继续当做内核，但是可以给用户使用
          - [ ] 是否存在 flag 说明那些页面可以分配给用户，那些是内核 ?



- [ ] `__split_huge_pmd` : 处理各种 lock 包括 pmd_lock
  - [ ] `__split_huge_pmd_locked`
    - 取回 pmd_huge_pte，向其中填充 pte, 然后将 pmd entry 填充该位置
  - `pgtable_t page::(anonymous union)::(anonymous struct)::pmd_huge_pte`
      - [ ]  从 `__split_huge_pmd_locked` 的代码: `pgtable_trans_huge_withdraw` 看，这一个 page table 从来没有被删除过
