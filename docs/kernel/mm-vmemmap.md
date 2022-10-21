# mm/sparse-vmemmap.c

## 是如何处理 NUMA 的
- for each node 的，无需额外的特殊处理

## 是如何处理 hugepage 的

```txt
#0  vmemmap_populate (start=start@entry=18446719884453740544, end=end@entry=18446719884455837696, node=node@entry=1, altmap=altmap@entry=0x0 <fixed_percpu_data>) at arch/x86/mm/init_64.c:1612
#1  0xffffffff81fb063f in __populate_section_memmap (pfn=pfn@entry=0, nr_pages=nr_pages@entry=32768, nid=nid@entry=1, altmap=altmap@entry=0x0 <fixed_percpu_data>, pgmap=pgmap@entry=0x0 <fixed_percpu_data>) at mm/sparse-vmemmap.c:392
#2  0xffffffff83366fc1 in sparse_init_nid (nid=1, pnum_begin=pnum_begin@entry=0, pnum_end=pnum_end@entry=40, map_count=32) at mm/sparse.c:527
#3  0xffffffff833673f4 in sparse_init () at mm/sparse.c:580
#4  0xffffffff833532a0 in paging_init () at arch/x86/mm/init_64.c:816
#5  0xffffffff83342b47 in setup_arch (cmdline_p=cmdline_p@entry=0xffffffff82a03f10) at arch/x86/kernel/setup.c:1253
#6  0xffffffff83338c7d in start_kernel () at init/main.c:959
#7  0xffffffff81000145 in secondary_startup_64 () at arch/x86/kernel/head_64.S:358
#8  0x0000000000000000 in ?? ()
```

- vmemmap_populate
  - vmemmap_populate_basepages : 使用 basepage 来实现映射
  - vmemmap_populate_hugepages

## [ ] 选择的虚拟地址从什么位置开始的

## 使用的物理内存是从什么位置分配的
- vmemmap_alloc_block_buf 最后调用 memblock 上

## 基本知识

1. 使用 vmemmap ，浪费大量的虚拟地址空间, 可以实现 pfn_to_page page_to_pfn 之间的快速装换。
2. 此处完成的是将那些存在物理内存的区间　对应的 page descriptor 所在的虚拟地址对应的物理内存建立一个对应关系。


```c
// fpn : section 对应的第一个 fpn
// nr_pages : 一个 section 持有 page 数量
// vmem_altmap : NULL
struct page * __meminit __populate_section_memmap(unsigned long pfn,
		unsigned long nr_pages, int nid, struct vmem_altmap *altmap)
{
	unsigned long start;
	unsigned long end;

	/*
	 * The minimum granularity of memmap extensions is
	 * PAGES_PER_SUBSECTION as allocations are tracked in the
	 * 'subsection_map' bitmap of the section.
	 */
	end = ALIGN(pfn + nr_pages, PAGES_PER_SUBSECTION);
  // 一个 subsection 可以容纳的 page 的数量，pfn + nr_pages 表示其中的结束位置的 pfn
	pfn &= PAGE_SUBSECTION_MASK; // 将起点位置进行对其，向左扩充，但是根据参数，这一个操作没有意义，因为 fpn 是 section 对应的第一个 fpn
	nr_pages = end - pfn;

	start = (unsigned long) pfn_to_page(pfn); // 这是虚拟地址
  // 没有填充就是已经可以使用 ? 所以其实 vmemmap 的存在，是不需要建立 page table 的，所以此时也是不可以访问该位置。
  // 所以此处进行的工作是 : start 到 end 之间的位置进行建立
  // todo 但是，此时还是不知道使用 mem_section 的原理 !
	end = start + nr_pages * sizeof(struct page); // 计算填充的两个虚拟地址的开始结束的分布

	if (vmemmap_populate(start, end, nid, altmap))
		return NULL;

	return pfn_to_page(pfn); // pfn 对应的 page descriptor 所在虚拟地址
}
```

arch/x86/mm/init_64.c
```c
int __meminit vmemmap_populate(unsigned long start, unsigned long end, int node,
		struct vmem_altmap *altmap)
{
	int err;

	if (end - start < PAGES_PER_SECTION * sizeof(struct page))
		err = vmemmap_populate_basepages(start, end, node);
	else if (boot_cpu_has(X86_FEATURE_PSE))
		err = vmemmap_populate_hugepages(start, end, node, altmap); // 假设 CPU 不支持
	else if (altmap) {
		pr_err_once("%s: no cpu support for altmap allocations\n",
				__func__);
		err = -ENOMEM;
	} else
		err = vmemmap_populate_basepages(start, end, node); // 那么会进入到此处
	if (!err)
		sync_global_pgds(start, end - 1);
	return err;
}
```

## vmemmap_populate_basepages : 填充函数

1. 对于 start 到 end 之间地址进行填充, 逐级向下进行 !
2. 操作方法有点类似于 pagefault 的感觉: 当需要 page frame 的时候就进行分配而已。
```c
int __meminit vmemmap_populate_basepages(unsigned long start,
					 unsigned long end, int node)
{
	unsigned long addr = start;
	pgd_t *pgd;
	p4d_t *p4d;
	pud_t *pud;
	pmd_t *pmd;
	pte_t *pte;

	for (; addr < end; addr += PAGE_SIZE) {
		pgd = vmemmap_pgd_populate(addr, node);
		if (!pgd)
			return -ENOMEM;
		p4d = vmemmap_p4d_populate(pgd, addr, node);
		if (!p4d)
			return -ENOMEM;
		pud = vmemmap_pud_populate(p4d, addr, node);
		if (!pud)
			return -ENOMEM;
		pmd = vmemmap_pmd_populate(pud, addr, node);
		if (!pmd)
			return -ENOMEM;
		pte = vmemmap_pte_populate(pmd, addr, node);
		if (!pte)
			return -ENOMEM;
		vmemmap_verify(pte, node, addr, addr + PAGE_SIZE);
	}

	return 0;
}
```
