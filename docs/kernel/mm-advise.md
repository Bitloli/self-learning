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

```c
static inline bool can_madv_lru_vma(struct vm_area_struct *vma)
{
	return !(vma->vm_flags & (VM_LOCKED|VM_PFNMAP|VM_HUGETLB));
}
```

- [ ] 为什么这三种都不可以来作为?
- [ ] VM_LOCKED ?
- [ ] VM_PFNMAP ?


```diff
History:        #0
Commit:         1a4e58cce84ee88129d5d49c064bd2852b481357
Author:         Minchan Kim <minchan@kernel.org>
Committer:      Linus Torvalds <torvalds@linux-foundation.org>
Author Date:    Thu 26 Sep 2019 07:49:15 AM CST
Committer Date: Thu 26 Sep 2019 08:51:41 AM CST

mm: introduce MADV_PAGEOUT

When a process expects no accesses to a certain memory range for a long
time, it could hint kernel that the pages can be reclaimed instantly but
data should be preserved for future use.  This could reduce workingset
eviction so it ends up increasing performance.

This patch introduces the new MADV_PAGEOUT hint to madvise(2) syscall.
MADV_PAGEOUT can be used by a process to mark a memory range as not
expected to be used for a long time so that kernel reclaims *any LRU*
pages instantly.  The hint can help kernel in deciding which pages to
evict proactively.

A note: It doesn't apply SWAP_CLUSTER_MAX LRU page isolation limit
intentionally because it's automatically bounded by PMD size.  If PMD
size(e.g., 256) makes some trouble, we could fix it later by limit it to
SWAP_CLUSTER_MAX[1].

- man-page material

MADV_PAGEOUT (since Linux x.x)

Do not expect access in the near future so pages in the specified
regions could be reclaimed instantly regardless of memory pressure.
Thus, access in the range after successful operation could cause
major page fault but never lose the up-to-date contents unlike
MADV_DONTNEED. Pages belonging to a shared mapping are only processed
if a write access is allowed for the calling process.

MADV_PAGEOUT cannot be applied to locked pages, Huge TLB pages, or
VM_PFNMAP pages.

[1] https://lore.kernel.org/lkml/20190710194719.GS29695@dhcp22.suse.cz/
```
