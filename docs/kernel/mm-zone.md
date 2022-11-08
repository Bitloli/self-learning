# zone

## node / zone 初始化
- paging_init
  - zone_sizes_init
    - free_area_init
      - free_area_init_node : 初始化 pg_data_t
        - calculate_node_totalpages : 在这里给每一个 zone 的大小进行划定，顺着分配，先分配的占据架构允许的所有的内存
          - zone_spanned_pages_in_node
        - free_area_init_core
          - zone_init_internals : 初始化一个 zone

如果自习观察 zone_spanned_pages_in_node，发现 zone 的范围是受 `arch_zone_highest_possible_pfn` 控制的，如果是 NUMA 机器，可以发现只有 Node 0 上是有 DMA 和 DMA32，其他的 Node 上是没有该节点的。

## 问题
- 因为 swap 每一个 node 的，分配的过程中，会导致 node 中较少的开始触发水位线吗？
  - 应该存在机制来，让这边的至少是处于良好运行的状态吧
- gfp_zone 是做啥的
