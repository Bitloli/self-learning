# compaction

## 关键参考
- https://www.cnblogs.com/LoyenWang/p/11746357.html : 应该是很清楚了
- http://linux.laoqinren.net/kernel/memory-compaction/

## 导出的接口
1. 观测
```txt
cat /proc/vmstat  | grep compact

/sys/kernel/debug/extfrag/extfrag_index
/sys/kernel/debug/extfrag/unusable_index

cat /proc/pagetypeinfo
```

2. 主动触发

```txt
/proc/sys/vm/compact_memory
/sys/devices/system/node/node0/compact
```

## 如果尝试分配大页，会因为 compaction 而 hang 住吗
不会


## TODO
- Documentation/vm/unevictable-lru.rst

- [ ] set_pfnblock_flags_mask

- [ ] 一个 page 被放到 movable 和 unmovable 中间的区别是什么，什么时候一个 page 是 movable 的?
- [ ] 完全不能理解，khugepaged 和 kcompactd 难道不是的功能难道不是都是将内存压缩到一起吗？

- [ ] RECLAIMABLE : 是什么类型的内存
  - page cache 是可以移动的吧，只是将关联的结构体修改一下
  - 但是 inode / dcache 之类的就很难了

- 检查一些过程
  - fallback 的过程
    - 如果在一个 pageblock 中分配了一个 page，那么是不是需要将这个 pageblock 的属性为什么，是不是需要进行修改

- page block 的大小和 max_order 是什么关系?
```c
/*
 * Huge pages are a constant size, but don't exceed the maximum allocation
 * granularity.
 */
#define pageblock_order     min_t(unsigned int, HUGETLB_PAGE_ORDER, MAX_ORDER - 1)
```
-  如果是 UNMOVABLE 的页面释放了，其会放到那种属性的 buddy 中，如果放到 MOVABLE 中，那么岂不是会导致 buddy 再去分配 UNMOVABLE 的时候， 总是需要 fallback 的吗
  - 释放的页进入的 freelist 的移动属性取决于 pageblock

- [ ] compaction 只能是 zone 内部的吗?

## steal 操作
find_suitable_fallback 的两个调用位置:
```txt
# 第一种
find_suitable_fallback+1
rmqueue_bulk+1892
get_page_from_freelist+4177
__alloc_pages_direct_compact+493
__alloc_pages_slowpath.constprop.0+1385
__alloc_pages+506

# 第二种
find_suitable_fallback+1
compact_zone+2618
```

- `__rmqueue_fallback`
  - find_suitable_fallback : 找到 fallback
  - get_page_from_free_area
  - steal_suitable_fallback ：是不分配了之后一个 page 之后立刻让这个 pageblock 修改属性的。

- 没有这个属性的 page，那么进行 steal ，此时将该 pageblock 剩余的 page 全部处理掉，如果 steal 的 page 比较少，那么并不会去将反转 pageblock 的属性。
- 从什么 pageblock 上释放，那么该 page 的属性就是啥。

- [ ] 为什么 compact 的过程中，需要调用 find_suitable_fallback 来实现 fallback 的

## 基本流程
- compact_zone
  - isolate_migratepages ：这个是核心了
    - isolate_migratepages_block : 对于一个范围中的 page 从 lru 中取出来，其中对于 page 存在很多过滤的操作，例如是 free 的 page，例如不再 LRU 中的 page
      - fast_find_migrateblock ：首先扫描一下 freelist，从数据比较多的位置开始
      - isolate_movable_page ：似乎未使用
      - del_page_from_lru_list : 最终的行动
  - lru_add_drain_cpu_zone : drain ???
  - migrate_pages
    - compaction_alloc : 这是传递给 migrate pages 的 hook，这里来获取
      - isolate_freepages
       - `__isolate_free_page` : 可能会修改 pageblock 的属性
  - release_freepages : 释放用不完的 free_pages 的时候吗?

```txt
@[
    compact_zone+895
    kcompactd_do_work+372
    kcompactd+832
    kthread+232
    ret_from_fork+34
]: 209
@[
    compact_zone+1525
    compact_zone_order+187
    try_to_compact_pages+238
    __alloc_pages_direct_compact+140
    __alloc_pages_slowpath.constprop.0+514
    __alloc_pages+506
    alloc_buddy_huge_page.isra.0+67
    alloc_fresh_huge_page+399
    alloc_pool_huge_page+109
    set_max_huge_pages+371
    hugetlb_sysctl_handler_common+252
    proc_sys_call_handler+408
    new_sync_write+265
    vfs_write+521
    ksys_write+95
    do_syscall_64+59
    entry_SYSCALL_64_after_hwframe+68
]: 485210
```

- `__rmqueue_fallback` ：是进行类型 fallback 的时候

## find_suitable_fallback

- compact_zone
  - find_suitable_fallback

## [The hard work behind large physical memory allocations in the kernel](https://lpc.events/event/2/contributions/65/attachments/15/171/slides-expanded.pdf)

- Migration scanner looks for migration source pages
  ‒ Starts at beginning (first page) of a zone, moves towards end
  ‒ **Isolates movable pages from their LRU lists**
- Free scanner looks for migration target pages
  ‒ Starts at the end of zone, moves towards beginning
  ‒ Isolates free pages from buddy allocator (splits as needed)

- Free page goes to UNMOVABLE free listas the pageblock is UNMOVABLE.
> free list 中间显然挂的是 page 而不是 page block

- UNMOVABLE allocation steals all free pages from the pageblock
(too few to also “repaint” the pageblock) and grabs the smallest

> 对应的代码:
> - steal_suitable_fallback
>   - move_freepages_block ：将这个 page 所在的所有的 page 全部 steal
>   - set_pageblock_migratetype ：如果可以全部 steal，那么也会修改 pageblock 的迁移属性

如果 free list 中间含有 migrate type，同时 page block 持有 migrate type ，没有冲突吗？
1. free list 的选择被 GFP 的确定
2. pageblock 应该是在扫描 isolate 的时候使用，当一个 page 处于被 use 的状态，其 mobility 被所处的 page block 确定

> TODO
反向 fallback 除非表示为 steal 整个 page block 的，page block 让扫描变的简单，但是 reclaimable 中间放置一个 movable，
感觉也确定当前的 page in use or not 也不是很好判断 !

# [Short topics in memory management](https://lwn.net/Articles/224829/)
So, this time around, Mel has posted two sets of patches: a list-based grouping mechanism and a new ZONE_MOVABLE zone which is restricted to movable allocations.
> 将类似的放到 list 上或者 zone 上，但是其中的工作 ?

# [Avoiding - and fixing - memory fragmentation](https://lwn.net/Articles/211505/)
But there are a few situations where physically-contiguous memory is absolutely required.
1. These include large kernel data structures (except those created with vmalloc())
2. and any memory which must appear contiguous to peripheral devices.
  - DMA buffers for low-end devices (those which cannot do scatter/gather I/O) are a classic example.
  - If a large ("high order") block of memory is not available when needed, something will fail and yet another user will start to consider switching to BSD.

So, in this patch, movable pages (those marked with `__GFP_MOVABLE`) are generally those belonging to user-space processes.
Moving a user-space page is just a matter of copying the data and changing the page table entry, so it is a relatively easy thing to do.
Reclaimable pages (`__GFP_RECLAIMABLE`), instead, usually belong to the kernel.
They are either allocations which are expected to be short-lived (some kinds of DMA buffers, for example, which only exist for the duration of an I/O operation)
or can be discarded if needed (various types of caches). Everything else is expected to be hard to reclaim.

> 1. 用户数据可以随便移动，copy 数据然后修改 pte 即可。
> 2. 但是内核态的采用的是线性映射，如果将页面进行移动，那么指向其的指针全部需要进行修改，但是很难找到指向其的指针。
> 3. 内核 backing store 的方法 : 将该 page 写回。

## migratetype

sudo cat /proc/pagetypeinfo

```c
enum migratetype {
  MIGRATE_UNMOVABLE,
  MIGRATE_MOVABLE,
  MIGRATE_RECLAIMABLE,
  MIGRATE_PCPTYPES, /* the number of types on the pcp lists */
  MIGRATE_HIGHATOMIC = MIGRATE_PCPTYPES,
#ifdef CONFIG_CMA
  /*
   * MIGRATE_CMA migration type is designed to mimic the way
   * ZONE_MOVABLE works.  Only movable pages can be allocated
   * from MIGRATE_CMA pageblocks and page allocator never
   * implicitly change migration type of MIGRATE_CMA pageblock.
   *
   * The way to use it is to change migratetype of a range of
   * pageblocks to MIGRATE_CMA which can be done by
   * __free_pageblock_cma() function.  What is important though
   * is that a range of pageblocks must be aligned to
   * MAX_ORDER_NR_PAGES should biggest page be bigger then
   * a single pageblock.
   */
  MIGRATE_CMA,
#endif
#ifdef CONFIG_MEMORY_ISOLATION
  MIGRATE_ISOLATE,  /* can't allocate from here */
#endif
  MIGRATE_TYPES
};
```

```c
/*
 * This array describes the order lists are fallen back to when
 * the free lists for the desirable migrate type are depleted
 *
 * The other migratetypes do not have fallbacks.
 */
static int fallbacks[MIGRATE_TYPES][3] = {
    [MIGRATE_UNMOVABLE]   = { MIGRATE_RECLAIMABLE, MIGRATE_MOVABLE,   MIGRATE_TYPES },
    [MIGRATE_MOVABLE]     = { MIGRATE_RECLAIMABLE, MIGRATE_UNMOVABLE, MIGRATE_TYPES },
    [MIGRATE_RECLAIMABLE] = { MIGRATE_UNMOVABLE,   MIGRATE_MOVABLE,   MIGRATE_TYPES },
};
```

可以观测的内容:
