# zone
因为 swap 每一个 node 的，分配的过程中

3. 每一个 node 主要管理什么信息，每一个 zone 中间放置什么内容?

4. 哪里涉及到了 nodemask 的，主要作用是什么 ?

- 为什么在我的虚拟机中，只有前三者是有管理内存的

```txt
😀  cat /tmp/x | grep Node
Node 0, zone      DMA
Node 0, zone    DMA32
Node 0, zone   Normal
Node 0, zone  Movable
Node 0, zone   Device
```

- [ ] DMA32 和 DMA 之内的 zone 的大小是如何确定的

- 如果 numa 太小，NORMAL zone 的大小可以为 0，而不是直接没有
- 为什么现在的 zone 总是没有 MOVABLE 的

## 7. movable zone 的作用是什么
如果说去掉 movable zone 和 dma，似乎 sparse 为什么

## 9.  分析函数 page_zone 实现
```c
static inline struct zone *page_zone(const struct page *page)
{
	return &NODE_DATA(page_to_nid(page))->node_zones[page_zonenum(page)];
}
```

## 2. zone 和 node 如何初始化
初始化前提首先是探测物理内存，其提供的信息为:
> TODO

```plain
void __init paging_init(void)
{
	sparse_memory_present_with_active_regions(MAX_NUMNODES);
	sparse_init();
	/*
	 * clear the default setting with node 0
	 * note: don't use nodes_clear here, that is really clearing when
	 *	 numa support is not compiled in, and later node_set_state
	 *	 will not set it back.
	 */
	node_clear_state(0, N_MEMORY);
	if (N_MEMORY != N_NORMAL_MEMORY)
		node_clear_state(0, N_NORMAL_MEMORY);

	zone_sizes_init();
}
void __init zone_sizes_init(void)
{
	unsigned long max_zone_pfns[MAX_NR_ZONES]; // 大小为4, noramle moveable dma 和 dma32

	memset(max_zone_pfns, 0, sizeof(max_zone_pfns));

#ifdef CONFIG_ZONE_DMA
	max_zone_pfns[ZONE_DMA]		= min(MAX_DMA_PFN, max_low_pfn);
#endif
#ifdef CONFIG_ZONE_DMA32
	max_zone_pfns[ZONE_DMA32]	= min(MAX_DMA32_PFN, max_low_pfn);
#endif
	max_zone_pfns[ZONE_NORMAL]	= max_low_pfn;
// 在amd64 配置中，下面的不用考虑
#ifdef CONFIG_HIGHMEM
	max_zone_pfns[ZONE_HIGHMEM]	= max_pfn;
#endif

	free_area_init_nodes(max_zone_pfns);
}
```
然后调用到 node 和 zone 的初始化位置:

free_area_init_nodes 的工作:
1. 填充 arch 初始化提供的信息:
```plain
static unsigned long arch_zone_lowest_possible_pfn[MAX_NR_ZONES] __meminitdata;
static unsigned long arch_zone_highest_possible_pfn[MAX_NR_ZONES] __meminitdata;
```
其中 movable zone 中间的内容需要单独计算。
2. 输出各种调试信息
3. 调用 free_area_init_node 逐个初始化 node

free_area_init_node 的工作:
1. 各种 pg_data_t 成员初始化
2. 调用 free_area_init_core
    1. 初始化 pg_data_t `pgdat_init_internals(pgdat)`
    2. 对于每一个 zone 为 buddy system 启用做准备，顺便初始化各个 zone `		zone_init_internals(zone, j, nid, freesize)`

1. 所以，migration 如何和 buddy system 打交道? alloc_page.c 应该就是整个 buddy system 的位置 ? 然后 pageset
## 5. 各种类型的 zone 都是用来做什么的，这些 zone 的划分到底是物理设备决定的，还是软件配置的
