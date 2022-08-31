# madvise

- madvise 告知内核该范围的内存如何访问
- fadvise 告知内核该范围的文件如何访问，内核从而可以调节 readahead 的参数，或者清理掉该范围的 page cache

fadvise 很简单，阅读
2. mm/fadvise.c 的源代码只有 200 行，具体可以看看 Man fadvise(2)

## MAP_COLD

- 核心: madvise_cold_or_pageout_pte_range

- [ ] 似乎很多位置都是这个类似的这种结构

```c
static long madvise_cold(struct vm_area_struct *vma,
			struct vm_area_struct **prev,
			unsigned long start_addr, unsigned long end_addr)
{
	struct mm_struct *mm = vma->vm_mm;
	struct mmu_gather tlb;

	*prev = vma;
	if (!can_madv_lru_vma(vma))
		return -EINVAL;

	lru_add_drain();
	tlb_gather_mmu(&tlb, mm);
	madvise_cold_page_range(&tlb, vma, start_addr, end_addr);
	tlb_finish_mmu(&tlb);

	return 0;
}
```
