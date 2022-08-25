# compaction

## TODO
- 错误的判断会导致 memory compaction 提前触发吗?
- CONFIG_MEMORY_ISOLATION
- Documentation/vm/unevictable-lru.rst
- Documentation/vm/page_migration.rst

- [ ] steal_suitable_fallback
- [ ] set_pfnblock_flags_mask
- [ ] set_pageblock_migratetype

- [ ] movable_zone 居然是 administer 指定的 ?

- [ ] 一个 page 被放到 movable 和 unmovable 中间的区别是什么，什么时候一个 page 是 movable 的?

## 基本流程
- compact_zone
  - isolate_migratepages
    - isolate_migratepages_block ：很长的函数，将 pageblock 中的 pages 整理出来
      - isolate_movable_page ：似乎未使用
  - lru_add_drain_cpu_zone : drain ???
  - migrate_pages
    - compaction_alloc

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
