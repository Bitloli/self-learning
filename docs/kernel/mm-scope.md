- 整理这个: https://richardweiyang-2.gitbook.io/kernel-exploring/00-memory_a_bottom_up_view/13-physical-layer-partition

- 同时整理 compound page, folio, hugetlb 之类的东西

通过这个函数 memory section 在 vmemmap 模式下是做啥的:

```c
static __always_inline int get_pfnblock_migratetype(const struct page *page,
					unsigned long pfn)
{
	return __get_pfnblock_flags_mask(page, pfn, MIGRATETYPE_MASK);
}
```

- 一个 page 可以知道自己所在的 pageblock，一个 pageblock 是 migrate 的基本单元。
  - 一个 memsection 中存储该 memsection 所有 pageblock 的属性
