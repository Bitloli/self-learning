# buddy

从这个角度介绍是很好的:
https://richardweiyang-2.gitbook.io/kernel-exploring/00-memory_a_bottom_up_view/13-physical-layer-partition

- 整理这个: https://richardweiyang-2.gitbook.io/kernel-exploring/00-memory_a_bottom_up_view/13-physical-layer-partition

- 同时整理 compound page, folio, hugetlb 之类的东西

## 问题
```c
/**
 * __free_pages - Free pages allocated with alloc_pages().
 * @page: The page pointer returned from alloc_pages().
 * @order: The order of the allocation.
 *
 * This function can free multi-page allocations that are not compound
 * pages.  It does not check that the @order passed in matches that of
 * the allocation, so it is easy to leak memory.  Freeing more memory
 * than was allocated will probably emit a warning.
 *
 * If the last reference to this page is speculative, it will be released
 * by put_page() which only frees the first page of a non-compound
 * allocation.  To prevent the remaining pages from being leaked, we free
 * the subsequent pages here.  If you want to use the page's reference
 * count to decide when to free the allocation, you should allocate a
 * compound page, and use put_page() instead of __free_pages().
 *
 * Context: May be called in interrupt context or while holding a normal
 * spinlock, but not in NMI context or while holding a raw spinlock.
 */
void __free_pages(struct page *page, unsigned int order)
{
	if (put_page_testzero(page))
		free_the_page(page, order);
	else if (!PageHead(page))
		while (order-- > 0)
			free_the_page(page + (1 << order), order);
}
```
这个 free 真的让人疑惑:
- free 不应该就是释放 page 吗?
- 为什么不是 PageHead 就可以释放？

- 是不是 Movable 的有 zone 和 page 吧
```txt
Node 0, zone  Movable
  pages free     0
        boost    0
        min      0
        low      0
        high     0
        spanned  0
        present  0
        managed  0
        cma      0
        protection: (0, 0, 0, 0, 0)
```

- 跟踪一下 migrate_pages 这个系统调用

## 问题
0. per_cpu_pageset 到底是用于管理缓存的还是管理 migration 的?
1. 为什么定义如此之多的 gfp_t 类型，都是用来做什么的 ? 都是如何被一一化解的 ?
1. imgration 的内容似乎就是简单的通过创建多个 list 解决的
2. buddy system 如何确定那些 page 的 imagration 的类型 ?
3. watermark 不同数值会导致分配的策略变化是什么 ?
4. 找到 cache hot-cold page 的内容位置 ?

1. alloc_pages 调用链条是什么？
2. fallback list ?
3. pageset watermark 如何融合的 ?
4. 如何通过 zone movable 机制实现 anti-fragmentation


> 对于每一个 node 的初始化，同时会初始化 page 的 flags 相关的内容
```c
/*
 * Allocate the accumulated non-linear sections, allocate a mem_map
 * for each and record the physical to section mapping.
 */
void __init sparse_init(void)

// 很好，又回来了
void __init paging_init(void)
```plain

> 似乎就是简单的分析gfp_t来分析migration，因为gfp其实在 alloc_pages 参数加以指定。
```c
static inline int gfpflags_to_migratetype(const gfp_t gfp_flags)
{
	VM_WARN_ON((gfp_flags & GFP_MOVABLE_MASK) == GFP_MOVABLE_MASK);
	BUILD_BUG_ON((1UL << GFP_MOVABLE_SHIFT) != ___GFP_MOVABLE);
	BUILD_BUG_ON((___GFP_MOVABLE >> GFP_MOVABLE_SHIFT) != MIGRATE_MOVABLE);

	if (unlikely(page_group_by_mobility_disabled))
		return MIGRATE_UNMOVABLE;

	/* Group based on mobility */
	return (gfp_flags & GFP_MOVABLE_MASK) >> GFP_MOVABLE_SHIFT;
}


// 当前环境信息以及gfp_t的信息在此处完成
static inline bool prepare_alloc_pages(gfp_t gfp_mask, unsigned int order,
		int preferred_nid, nodemask_t *nodemask,
		struct alloc_context *ac, gfp_t *alloc_mask,
		unsigned int *alloc_flags)
{
```

## todo
> 回答一下问题可以推进代码的分析

https://linuxplumbersconf.org/event/2/contributions/65/attachments/15/171/slides-expanded.pdf
> 似乎解释了 compaction 的含义

- Isolates movable pages from their LRU lists
- Fallback to other type when matching pageblocks full (实际上就是划分为一个有一个区域，一个区域使用完成，然后向下一个区域，而不是说都是真的)
- Each marked as MOVABLE, UNMOVABLE or RECLAIMABLE migratetype (there are few more for other purposes
- Zones divided to pageblocks (order-9 = 2MB on x86) 我怀疑是 page block 中间含有两个内容
- Isolates free pages from buddy allocator (splits as needed)

> 1. migrate 从哪里迁移到哪里? 确定谁需要被迁移 !
> 2. 怀疑 pageblock 的大小就是最大分配的连续的物理内存的大小 !
> 3. pcplist 是做什么的 ?
> 4. watermark 的作用 ?


> 解释一下 isolate movable 以及 lru list

```c
int PageMovable(struct page *page)
{
	struct address_space *mapping;

	VM_BUG_ON_PAGE(!PageLocked(page), page);
  // 似乎movabel 不能给ano page 标记
	if (!__PageMovable(page))
		return 0;

	mapping = page_mapping(page);
  // ??? 只要isolate_page 就是movable，何时注册的?
	if (mapping && mapping->a_ops && mapping->a_ops->isolate_page)
		return 1;

	return 0;
}
EXPORT_SYMBOL(PageMovable);

static __always_inline int __PageMovable(struct page *page)
{
	return ((unsigned long)page->mapping & PAGE_MAPPING_FLAGS) ==
				PAGE_MAPPING_MOVABLE;
}
```

## 基本流程

```txt
__alloc_pages+1
folio_alloc+23
__filemap_get_folio+441
pagecache_get_page+21
ext4_da_write_begin+238
generic_perform_write+193
ext4_buffered_write_iter+123
io_write+280
io_issue_sqe+1182
io_wq_submit_work+129
io_worker_handle_work+615
io_wqe_worker+766
ret_from_fork+34
```

```txt
__alloc_pages+1
alloc_pages_vma+143
__handle_mm_fault+2562
handle_mm_fault+178
do_user_addr_fault+460
exc_page_fault+103
asm_exc_page_fault+30
```

```txt
__alloc_pages+1
__get_free_pages+13
__pollwait+137
n_tty_poll+105
tty_poll+102
do_sys_poll+652
__x64_sys_poll+162
do_syscall_64+59
entry_SYSCALL_64_after_hwframe+68
```

# TODO

- 构建一个 memory 启动的基本流程:
```txt
#0  sparse_init_one_section (flags=8, usage=0xffff88813fffab00, mem_map=0xffffea0000000000, pnum=0, ms=0xffff88813fffb000) at mm/sparse.c:306
#1  sparse_init_nid (nid=nid@entry=0, pnum_begin=pnum_begin@entry=0, pnum_end=pnum_end@entry=40, map_count=<optimized out>) at mm/sparse.c:537
#2  0xffffffff8330ae45 in sparse_init () at mm/sparse.c:580
#3  0xffffffff832f7eba in paging_init () at arch/x86/mm/init_64.c:815
#4  0xffffffff832e78e3 in setup_arch (cmdline_p=cmdline_p@entry=0xffffffff82a03f10) at arch/x86/kernel/setup.c:1253
#5  0xffffffff832ddc56 in start_kernel () at init/main.c:952
#6  0xffffffff81000145 in secondary_startup_64 () at arch/x86/kernel/head_64.S:358
```


## 基本流程
```c
/*
 * This is the 'heart' of the zoned buddy allocator.
 */
struct page *__alloc_pages(gfp_t gfp, unsigned int order, int preferred_nid,
							nodemask_t *nodemask)
```

- `__alloc_pages`: 分配 `struct alloc_context`
  - prepare_alloc_pages : 组装出来 `alloc_context`
    - gfp_migratetype : 将 gfp_t 中的两个 bit 提取出来
  - get_page_from_freelist : 选择 zone 和 migrate type
    - rmqueue
      - rmqueue_pcplist : size=1 有特殊通道
        - `__rmqueue_pcplist`
          - `rmqueue_bulk` ：一次多取出几个放到
      - rmqueue_buddy
        - `__rmqueue_smallest`
        - `__rmqueue`
          - `__rmqueue_smallest` ：常规的伙伴系统
          - `__rmqueue_cma_fallback`
          - `__rmqueue_fallback`

- free_pages
  - `__free_pages`
     - free_the_page
      - free_unref_page ：释放为 pcp pages
      - `__free_pages_ok` ：释放普通的
        - `__free_one_page` ：常规的伙伴系统


## [ ] 深入理解 gfp.h

- current_gfp_context : 会根据 current 来修改分配的规则


- [ ] 这些 flags 都是做啥的哇
```c
#define FGP_ACCESSED		0x00000001
#define FGP_LOCK		0x00000002
#define FGP_CREAT		0x00000004
#define FGP_WRITE		0x00000008
#define FGP_NOFS		0x00000010
#define FGP_NOWAIT		0x00000020
#define FGP_FOR_MMAP		0x00000040
#define FGP_HEAD		0x00000080
#define FGP_ENTRY		0x00000100
#define FGP_STABLE		0x00000200
```

- [ ] 按照道理来说，find_get_page 是去获取一个 page cache 的，page cache 总是 MOVABLE 的，但是传递给 pagecache_get_page 的参数是 0
```c
/**
 * find_get_page - find and get a page reference
 * @mapping: the address_space to search
 * @offset: the page index
 *
 * Looks up the page cache slot at @mapping & @offset.  If there is a
 * page cache page, it is returned with an increased refcount.
 *
 * Otherwise, %NULL is returned.
 */
static inline struct page *find_get_page(struct address_space *mapping,
					pgoff_t offset)
{
	return pagecache_get_page(mapping, offset, 0, 0);
}
```
