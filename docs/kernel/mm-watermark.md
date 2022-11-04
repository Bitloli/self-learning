# watermark

## watermark 接口
https://www.kernel.org/doc/Documentation/sysctl/vm.txt

> watermark_boost_factor:
>
> This factor controls the level of reclaim when memory is being fragmented.
> It defines the percentage of the high watermark of a zone that will be
> reclaimed if pages of different mobility are being mixed within pageblocks.
> The intent is that compaction has less work to do in the future and to
> increase the success rate of future high-order allocations such as SLUB
> allocations, THP and hugetlbfs pages.
>
> To make it sensible with respect to the watermark_scale_factor
> parameter, the unit is in fractions of 10,000. The default value of
> 15,000 on !DISCONTIGMEM configurations means that up to 150% of the high
> watermark will be reclaimed in the event of a pageblock being mixed due
> to fragmentation. The level of reclaim is determined by the number of
> fragmentation events that occurred in the recent past. If this value is
> smaller than a pageblock then a pageblocks worth of pages will be reclaimed
> (e.g.  2MB on 64-bit x86). A boost factor of 0 will disable the feature.
>
> =============================================================
>
> watermark_scale_factor:
>
> This factor controls the aggressiveness of kswapd. It defines the
> amount of memory left in a node/system before kswapd is woken up and
> how much memory needs to be free before kswapd goes back to sleep.
>
> The unit is in fractions of 10,000. The default value of 10 means the
> distances between watermarks are 0.1% of the available memory in the
> node/system. The maximum value is 1000, or 10% of memory.
>
> A high rate of threads entering direct reclaim (allocstall) or kswapd
> going to sleep prematurely (kswapd_low_wmark_hit_quickly) can indicate
> that the number of free pages kswapd maintains for latency reasons is
> too small for the allocation bursts occurring in the system. This knob
> can then be used to tune kswapd aggressiveness accordingly.

## 问题
- [ ] 是一个 zone 出现了低于 high 的时候，就开始，还是先让所有的都低于 high 再说?
- [ ] watermark 是每一个 zone 构建一个的吗?
- 分析 calculate_totalreserve_pages 的计算原理
- 根据 per_cpu_pages 中间的内容 : watermark 是用于处理 pcp 的，但是我找到了一堆 `zone_watermark_*` 的函数
2. watermark 和 pcp 的初始化
      1. 似乎 watermark 的作用就是 : page reclaim 的标记
      2. pcp : 处理那些 cpu local cache 访问过的 page ?

## 总是检查这个
- `__zone_watermark_ok`

```txt
#0  __zone_watermark_ok (z=0xffff88823fff9d00, order=1, mark=0, highest_zoneidx=2, alloc_flags=257, free_pages=1281590) at mm/page_alloc.c:3977
#1  0xffffffff812fe8fb in zone_watermark_fast (gfp_mask=335872, alloc_flags=257, highest_zoneidx=2, mark=0, order=1, z=0xffff88823fff9d00) at mm/page_alloc.c:4069
#2  get_page_from_freelist (gfp_mask=335872, order=order@entry=1, alloc_flags=257, ac=ac@entry=0xffffffff82a03c70) at mm/page_alloc.c:4242
#3  0xffffffff8130032d in __alloc_pages (gfp=335872, order=order@entry=1, preferred_nid=preferred_nid@entry=0, nodemask=nodemask@entry=0x0 <fixed_percpu_data>) at mm/page_alloc.c:5555
#4  0xffffffff8132a90a in __alloc_pages_node (order=<optimized out>, gfp_mask=<optimized out>, nid=0) at include/linux/gfp.h:223
```

## min_free_kbytes
- [ ] 为什么 transparent hugepage 需要通过 set_recommended_min_free_kbytes 来影响 min_free_kbytes

- calculate_totalreserve_pages

- [ ] `__setup_per_zone_wmarks` ：计算 min low high 的数值

每一个 zone 都有:
```c
enum zone_watermarks {
  WMARK_MIN,
  WMARK_LOW,
  WMARK_HIGH,
  NR_WMARK
};
```



* 预存一些内存
```c
  /*
   * We don't know if the memory that we're going to allocate will be
   * freeable or/and it will be released eventually, so to avoid totally
   * wasting several GB of ram we must reserve some of the lower zone
   * memory (otherwise we risk to run OOM on the lower zones despite
   * there being tons of freeable ram on the higher zones).  This array is
   * recalculated at runtime if the sysctl_lowmem_reserve_ratio sysctl
   * changes.
   */
  long lowmem_reserve[MAX_NR_ZONES];
```
> 1. 为毛 zone 被划分　low 和 high 的部分, 此处的 higher zones 和 high memory 有什么关系 ? (第四条说: 应该没有什么关系吧
> 2. 为什么是 lowmeme_reserve　而不是 highmem_reserve
> 3. 设置 reserve　难道不就是内存的浪费吗?
> 4. 这是 zone 的描述，high memory , DMA , NORMAL 本身就是 zone，也就是说 low 指的是 zone 内部也划分 low 和 high

* pageset 用于管理那些被 cache　视为 hot page 和 cold page 的

```c
struct per_cpu_pageset __percpu *pageset;

struct per_cpu_pages {
  int count;    /* number of pages in the list */
  int high;   /* high watermark, emptying needed */
  int batch;    /* chunk size for buddy add/remove */

  /* Lists of pages, one per migrate type stored on the pcp-lists */
  struct list_head lists[MIGRATE_PCPTYPES];
};

struct per_cpu_pageset {
  struct per_cpu_pages pcp;
#ifdef CONFIG_NUMA
  s8 expire;
  u16 vm_numa_stat_diff[NR_VM_NUMA_STAT_ITEMS];
#endif
#ifdef CONFIG_SMP
  s8 stat_threshold;
  s8 vm_stat_diff[NR_VM_ZONE_STAT_ITEMS];
#endif
};
```

Filling the watermarks in the data structure is handled by `init_per_zone_pages_min`, which is invoked during kernel boot and need not be started explicitly.


## 分配的过程中，会检查一下 watermark 是否 ok
`mm/internal.h`
```c
/*
 * Return true if free base pages are above 'mark'. For high-order checks it
 * will return true of the order-0 watermark is reached and there is at least
 * one free page of a suitable size. Checking now avoids taking the zone lock
 * to check in the allocation paths if no pages are free.
 */
bool __zone_watermark_ok(struct zone *z, unsigned int order, unsigned long mark,
       int classzone_idx, unsigned int alloc_flags,
       long free_pages)
{


bool zone_watermark_ok(struct zone *z, unsigned int order, unsigned long mark,
          int classzone_idx, unsigned int alloc_flags)
{
  return __zone_watermark_ok(z, order, mark, classzone_idx, alloc_flags,
          zone_page_state(z, NR_FREE_PAGES));
}

## watermark
min_wmark_pages
zone_watermark_ok

> 1. 难道存在多个watermark 吗 ?
> 2. 但是似乎其实是访问zone 的 watermark

```c
enum zone_watermarks {
    WMARK_MIN,
    WMARK_LOW,
    WMARK_HIGH,
    NR_WMARK
};

#define min_wmark_pages(z) (z->watermark[WMARK_MIN])
#define low_wmark_pages(z) (z->watermark[WMARK_LOW])
#define high_wmark_pages(z) (z->watermark[WMARK_HIGH])
```

```c
/**
 * setup_per_zone_wmarks - called when min_free_kbytes changes
 * or when memory is hot-{added|removed}
 *
 * Ensures that the watermark[min,low,high] values for each zone are set
 * correctly with respect to min_free_kbytes.
 */
void setup_per_zone_wmarks(void)
{
    static DEFINE_SPINLOCK(lock);

    spin_lock(&lock);
    __setup_per_zone_wmarks();
    spin_unlock(&lock);
}

init_per_zone_wmark_min : 非常值的关注的东西
```

## init_per_zone_wmark_min

```c
/*
 * Initialise min_free_kbytes.
 *
 * For small machines we want it small (128k min).  For large machines
 * we want it large (64MB max).  But it is not linear, because network
 * bandwidth does not increase linearly with machine size.  We use
 *
 *  min_free_kbytes = 4 * sqrt(lowmem_kbytes), for better accuracy:
 *  min_free_kbytes = sqrt(lowmem_kbytes * 16)
 *
 * which yields
 *
 * 16MB:    512k
 * 32MB:    724k
 * 64MB:    1024k
 * 128MB:   1448k
 * 256MB:   2048k
 * 512MB:   2896k
 * 1024MB:  4096k
 * 2048MB:  5792k
 * 4096MB:  8192k
 * 8192MB:  11584k
 * 16384MB: 16384k
 */
int __meminit init_per_zone_wmark_min(void)
{
    unsigned long lowmem_kbytes;
    int new_min_free_kbytes;

    lowmem_kbytes = nr_free_buffer_pages() * (PAGE_SIZE >> 10);
    new_min_free_kbytes = int_sqrt(lowmem_kbytes * 16);

    if (new_min_free_kbytes > user_min_free_kbytes) {
        min_free_kbytes = new_min_free_kbytes;
        if (min_free_kbytes < 128)
            min_free_kbytes = 128;
        if (min_free_kbytes > 65536)
            min_free_kbytes = 65536;
    } else {
        pr_warn("min_free_kbytes is not updated to %d because user defined value %d is preferred\n",
                new_min_free_kbytes, user_min_free_kbytes);
    }
    setup_per_zone_wmarks();
    refresh_zone_stat_thresholds(); // todo 统计信息初始化
    setup_per_zone_lowmem_reserve(); // todo pgdata_t 各种信息的初始化，下面两个函数也是如此，但是，关键问题没有被处理! watermark 和 pcp 被如何使用 ?

#ifdef CONFIG_NUMA
    setup_min_unmapped_ratio(); // todo
    setup_min_slab_ratio(); // todo
#endif

    return 0;
}
```

1. lowmem_kbytes 计算
```c
/**
 * nr_free_buffer_pages - count number of pages beyond high watermark
 *
 * nr_free_buffer_pages() counts the number of pages which are beyond the high
 * watermark within ZONE_DMA and ZONE_NORMAL.
 *
 * Return: number of pages beyond high watermark within ZONE_DMA and
 * ZONE_NORMAL.
 */
unsigned long nr_free_buffer_pages(void)
{
    return nr_free_zone_pages(gfp_zone(GFP_USER));
}
EXPORT_SYMBOL_GPL(nr_free_buffer_pages);

/**
 * nr_free_zone_pages - count number of pages beyond high watermark
 * @offset: The zone index of the highest zone
 *
 * nr_free_zone_pages() counts the number of pages which are beyond the
 * high watermark within all zones at or below a given zone index.  For each
 * zone, the number of pages is calculated as:
 *
 *     nr_free_zone_pages = managed_pages - high_pages
 *
 * Return: number of pages beyond high watermark.
 */
static unsigned long nr_free_zone_pages(int offset) // todo 神奇的函数，不过首先理解 node_zonelist 的含义是什么 ?
{
    struct zoneref *z;
    struct zone *zone;

    /* Just pick one node, since fallback list is circular */
    unsigned long sum = 0;

    struct zonelist *zonelist = node_zonelist(numa_node_id(), GFP_KERNEL); // 获取current node 的 zonelist

    for_each_zone_zonelist(zone, z, zonelist, offset) { // todo 这个宏是什么意思 ?
        unsigned long size = zone_managed_pages(zone); // zone->managed_pages
        unsigned long high = high_wmark_pages(zone); //
        if (size > high)
            sum += size - high;
    }

    return sum;
}
```

2. setup_per_zone_wmarks
```c
/**
 * setup_per_zone_wmarks - called when min_free_kbytes changes
 * or when memory is hot-{added|removed}
 *
 * Ensures that the watermark[min,low,high] values for each zone are set
 * correctly with respect to min_free_kbytes.
 */
void setup_per_zone_wmarks(void)
{
    static DEFINE_SPINLOCK(lock);

    spin_lock(&lock);
    __setup_per_zone_wmarks();
    spin_unlock(&lock);
}
```

#### watermark
- [x] page writeback 如何利用 watermark 机制来触发写回的
    1. watermark 的初始化 : 根据探测的物理内存，然后确定 watermark
    2. 提供给用户调节 watermark 的机制
    3. page allocator 中间检测和触发

- [ ] file:///home/shen/Core/linux/Documentation/output/admin-guide/mm/concepts.html?highlight=watermark
内核介绍的核心概念，务必逐个分析

[LoyenWang](https://www.cnblogs.com/LoyenWang/p/11708255.html)

- `WMARK_MIN` : 内存不足的最低点，如果计算出的可用页面低于该值，则无法进行页面计数；
- `WMARK_LOW` : 默认情况下，该值为 WMARK_MIN 的 125%，此时 kswapd 将被唤醒，可以通过修改 watermark_scale_factor 来改变比例值；
- `WMARK_HIGH` : 默认情况下，该值为 WMARK_MAX 的 150%，此时 kswapd 将睡眠，可以通过修改 watermark_scale_factor 来改变比例值；
![](https://img2018.cnblogs.com/blog/1771657/201910/1771657-20191020172801277-1235981981.png)

## 关键参考
- https://www.cnblogs.com/LoyenWang/p/11708255.html
