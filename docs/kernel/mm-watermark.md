# TODO

## 关键参考
- https://www.cnblogs.com/LoyenWang/p/11708255.html

- `__zone_watermark_ok`

```c
/*
 * calculate_totalreserve_pages - called when sysctl_lowmem_reserve_ratio
 *  or min_free_kbytes changes.
 */
static void calculate_totalreserve_pages(void)
```

理解两个字段的含义：
- si_mem_available


```c
atomic_long_t vm_zone_stat[NR_VM_ZONE_STAT_ITEMS] __cacheline_aligned_in_smp;
atomic_long_t vm_node_stat[NR_VM_NODE_STAT_ITEMS] __cacheline_aligned_in_smp;
atomic_long_t vm_numa_event[NR_VM_NUMA_EVENT_ITEMS] __cacheline_aligned_in_smp;
```

```c
bool zone_watermark_ok(struct zone *z, unsigned int order, unsigned long mark,
              int highest_zoneidx, unsigned int alloc_flags)
{
    return __zone_watermark_ok(z, order, mark, highest_zoneidx, alloc_flags,
                    zone_page_state(z, NR_FREE_PAGES));
}
```

## 是不是 buddy 管理的 page 就是 NR_FREE_PAGES
检查 NR_FREE_PAGES 的调用位置只有 rmqueue_bulk 比较科学的，这么说，就是 buddy 的看法了。

- [ ] 那个 free 是 bug 的

- https://unix.stackexchange.com/questions/346208/system-unable-to-allocate-memory-even-though-memory-is-available
  - 只有 kernel 才可以让 memory 进入到 min 中

- min_free_kbytes

## 那么 Node number !=0 的那些普通的内存都是被谁使用的

## khugepaged
- 观察其运行过程中的结果:

- set_recommended_min_free_kbytes


## 分析一下，是如何决定触发 OOM 的
- http://linux.laoqinren.net/linux/out-of-memory/

## total_reseve_page 和 min low high 是什么关系

- `__setup_per_zone_wmarks` ：计算 min low high 的数值


## `zone_managed_pages` 到底是包含 hugepage 的吗
