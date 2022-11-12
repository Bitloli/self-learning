# rmap

## anon
如果想要知道一个 page 被那些地址空间映射:
1. 给 page 创建的时候在那个 vma 中间。
2. 该 vma 进一步 fork 出来了那些 vma 。


2. avc 挂载到 `vma->anon_vma_chain` 这个链表上，同时在 av 的 `anon_vma->rb_root` 上
  1. 当发生 rmap 遍历，利用 `page->mapping` 找到 anon_vma, 然找到  `anon_vma->rb_root` 来在红黑树中间查找到 avc
3. avc 是 vma 用来挂载到 av 上的钩子
2. 一个 vma 对应一个 av
4. 进程每创建一个子进程，父进程的 AV 的红黑树中会增加每一个起“桥梁”作用的 AVC，以此连接到子进程的 VMA
5. 第 n 个层次的 child 需要创建创建 n 个 avc, 分别将 avc 放到自己和自己的 n - 1 个祖先中间


![AVC AV 和 VMA 的关系](https://img2018.cnblogs.com/blog/1771657/202001/1771657-20200108072200806-1580650219.png)

![page->mapping 中指向的是 AV](https://img2018.cnblogs.com/blog/1771657/202001/1771657-20200108072227687-242824885.png)

## 构建

```c
/**
 * __page_set_anon_rmap - set up new anonymous rmap
 * @page:	Page or Hugepage to add to rmap
 * @vma:	VM area to add page to.
 * @address:	User virtual address of the mapping
 * @exclusive:	the page is exclusively owned by the current process
 */
static void __page_set_anon_rmap(struct page *page,
	struct vm_area_struct *vma, unsigned long address, int exclusive)
{
	struct anon_vma *anon_vma = vma->anon_vma;

	BUG_ON(!anon_vma);

	if (PageAnon(page))
		goto out;

	/*
	 * If the page isn't exclusively mapped into this vma,
	 * we must use the _oldest_ possible anon_vma for the
	 * page mapping!
	 */
	if (!exclusive)
		anon_vma = anon_vma->root;

	/*
	 * page_idle does a lockless/optimistic rmap scan on page->mapping.
	 * Make sure the compiler doesn't split the stores of anon_vma and
	 * the PAGE_MAPPING_ANON type identifier, otherwise the rmap code
	 * could mistake the mapping for a struct address_space and crash.
	 */
	anon_vma = (void *) anon_vma + PAGE_MAPPING_ANON;
	WRITE_ONCE(page->mapping, (struct address_space *) anon_vma);
	page->index = linear_page_index(vma, address);
out:
	if (exclusive)
		SetPageAnonExclusive(page);
}
```

```txt
#0  __page_set_anon_rmap (page=0xffffea0000997380, vma=0xffff888127fc7688, address=94283249184768, exclusive=1) at mm/rmap.c:1126
#1  0xffffffff812dd09b in do_anonymous_page (vmf=0xffffc90001967df8) at mm/memory.c:4153
#2  handle_pte_fault (vmf=0xffffc90001967df8) at mm/memory.c:4953
#3  __handle_mm_fault (vma=vma@entry=0xffff888127fc7688, address=address@entry=94283249184872, flags=flags@entry=597) at mm/memory.c:5097
#4  0xffffffff812dd620 in handle_mm_fault (vma=0xffff888127fc7688, address=address@entry=94283249184872, flags=flags@entry=597, regs=regs@entry=0xffffc90001967f58) at mm/memory.c:5218
#5  0xffffffff810f3ca3 in do_user_addr_fault (regs=regs@entry=0xffffc90001967f58, error_code=error_code@entry=6, address=address@entry=94283249184872) at arch/x86/mm/fault.c:1428
#6  0xffffffff81fa8e12 in handle_page_fault (address=94283249184872, error_code=6, regs=0xffffc90001967f58) at arch/x86/mm/fault.c:1519
#7  exc_page_fault (regs=0xffffc90001967f58, error_code=6) at arch/x86/mm/fault.c:1575
#8  0xffffffff82000b62 in asm_exc_page_fault () at ./arch/x86/include/asm/idtentry.h:570
```

- 如何理解 exclusive ?

- page_add_anon_rmap : 需要判断是不是新创建的
- page_add_new_anon_rmap : 调用 `__page_set_anon_rmap` 的时候，本 vma 一定是 root 的，参数 exclusive 是 1
- 如果是 exclusive 的，那么 `page->mapping` 中指向本 vma 的 `anon_vma`，否则指向 `anon_vma->root`
- 大多数的时候是 exclusive 的


看代码，似乎是只要是新创建的 page，目前熟悉的场景中，发生 pf 的 vma 就是 root ，但是:
- 只有 share vma 才会需要 rmap 的吧
- share 给 child，如果 pf 是 child 触发的，但是还是需要设置 parent 的 vma 为 root 吧

## anon_vma_fork 和 anon_vma_clone

- anon_vma_fork :
  - anon_vma_clone : 复制 avc ，并且将 avc 添加到红黑树和链表中
  - 创建 avc av ，并且和 vma 链接起来

```txt
@[
    anon_vma_fork+1
    dup_mm+931
    copy_process+6704
    kernel_clone+151
    __do_sys_clone+102
    do_syscall_64+59
    entry_SYSCALL_64_after_hwframe+99
]: 3953
```

```txt
@[
    anon_vma_clone+1
    copy_vma+385
    move_vma+331
    __do_sys_mremap+820
    do_syscall_64+59
    entry_SYSCALL_64_after_hwframe+99
]: 1

@[
    anon_vma_clone+1
    __split_vma+145
    __do_munmap+996
    __vm_munmap+120
    __x64_sys_munmap+23
    do_syscall_64+59
    entry_SYSCALL_64_after_hwframe+99
]: 1132
@[
    anon_vma_clone+1
    anon_vma_fork+51
    dup_mm+931
    copy_process+6704
    kernel_clone+151
    __do_sys_clone+102
    do_syscall_64+59
    entry_SYSCALL_64_after_hwframe+99
]: 4328
```

## cow
1. 当发生 cow 的时候，将新创建出来的 `page->mapping` 指向子进程的 anon_vma

## rmap_walk
- memfd 是不是创建出来了可以共享的 anonymous 映射，而再次之前，这是做不到的 ?

## rmap.c

1. 在 page 初始化的时候，只要谁来使用 page ，将 vma 挂到链表上 !
  1. 那么岂不是，当存在 1000 个 fork 同一个 1000 page 的物理页面，存在 100000 个链表节点
  2. 并不会吧

5. av 的含义是什么 ?

6. `page->mapping` 当解释 anon_vma 的时候，对其赋值的时机是什么 ?
    1. anon_vma 是 page 的实际管理者，vma 可能只会持有其中的部分区间
    2. 一个 anon_vma 是可以关联多个 vma 的，一个 vma 也可以关联多个 anon_vma，通过 `avc->same_vma`
    3. **vma 为什么需要找到与其关联的所有 anon_vma**
        1. 释放一个 vma 需要找到该 vma 关联的所有 av
    5. vma 总会关联一个独享的 vma_anon ，在哪一个 vma 上 pgfault，page.mapping 就会指向该 anon_vma
    3. 如果该 page 是在"我"这里创建的，那么就需要"我"就需要创建出来一个 anon_vma 来
而且，从我这里 fork 出来的所有 vma 都需要挂到"我"这里。

7. anon_vma_clone 的作用是什么: 因为我的 parent 持有一堆 av，那么我需要继承这些 av，所以就创建 avc 建立当前 vma 和 这些 av 的联系。

8. 我们能不能不要 anon_vma_chain ? 利用 avc， 我们想要实现的效果是什么 ?
    1. vma 可以找到 管理其 page 的所有的 anon_vma
    2. anon_vma 想知道其管理的所有 page 被映射的所有的 vma
    3. 当然，取消掉 avc, 在 av 和 vma 中间插入链表

```c
	/* Interval tree of private "related" vmas */
	struct rb_root_cached rb_root;
  // 其中持有 avc 的 interval tree，avc 中间的 av 显然是用来回指，另外的一个部分就是指向 vma 了。
  // 所以实际上相当于指向 vma 了。
```

8. 找一下 mmap.c 中间 merge 和 split 的操作过程是什么样子的 ?

9. 不仅仅可以递归的 fork ，而且可以同一个 process 可以 fork 出来大量的内容出来。
    1. 为什么 av 可以不关联 vma (是不是因为其并没有创建)
    2. reuse 不是通常看到的内容，否则根本无法解释 no alive 的含义。
        1. 在常规情况下(A fork B , B fork C, C 无法 reuse A B 的内容)，只会出现其中的

10. page_add_file_rmap 和 page_add_anon_rmap 两个函数结果加以阅读一下。


8. vma 被截断了怎么办:
    1. vm_pgoff 在 anon 中间的含义，初代的认为是 0 ，之后的所有的位置进行相对调整，例如当前端缩短了之后，那么提升 vm_pgoff 的数值
    2. vma 可以变化，但是 `page->index` 并不会发生改变
        1. 所以，新 cow 出来的 page 的 index 如何设置 ? (虽然细节不清楚，但是问题不是很大)


8. 通过 mmu notifiers 机制，可以实现检查 page 最近被 referenced 过没有 :  https://lwn.net/Articles/732952/

2. unlink_anon_vmas && anon_vma_chain_link 功能猜测和总结

## principal
1. radix tree 根本不是用来实现反向映射的，反向映射使用的内容是 : interval_tree
    1. interval_tree 的作用是 : 对于 file based 的，因为文件上挂载了所有的与之相关的 vmc
2. page cache 其实和 rmap 是没有关联的东西。
    1. ramp 的作用是当知道 page frame 的时候找到 pte，当然找到等价于知道 vma mm_struct 以及 process

3. file based 和 anon 的 rmap 的不相同的

1. 利用 `vma->anon_vma_chain` `avc->same_vma`, vma 可以挂载多个 avc, 这些 avc 再分别挂载到自己的 av 和 逐级 parent 的 av 上
2. `anon_vma->rb_root` 上挂载 avc ，利用 `avc->vma` 作为作为区间的范围。
    1. avc 中间持有指向 vma 和 av 的指针
    2. av 和 vma 都会管理一堆 avc ?
    3. 一个 av 会管理多个 vma，都是挂载其红黑树上

3. av 是构成 tree 利用 `av->degree` 来实现 reuse 机制
    1. degree 不是表示 children 的数量

4. avc 是用来勾连 av 和 mva 的

5. av 的 parent 和 degree 成员就是用于实现 reuse 的

6. The copy-on-write semantics of fork mean that an anon_vma
 can become associated with multiple processes. Furthermore,
 each child process will have its own anon_vma, where new
 pages for that process are instantiated.

7. page_vma_mapped_walk : 当一个 page A 出现了 cow 之后，得到了 page B, 实际上对于 page A 进行 rmap 查找其 reference 的时候，很有可能找到错误的。
    1. 更加窒息的位置在于，page A 所在的 vma fork 出来 N 个 vma，其中 M 个对于 page A 所在的位置进行修改，那么当进行 page A 进行 rmap 的时候，将会出现 M 此失败。
    2. 不过考虑到这种情况应该很少遇到，所以性能应该不会构成问题吧。



## references of rmap
1. rmap 具体使用位置 从 rmap.h 分析
2. rmap 和 mmap 交互 ? 在进行 vma copy 的过程中间，会调用对于 rmap.c 进行维护
3. 还有更加简单的方法 : 如果一个机制使用了 rmap，必然依赖于 rmap_walk 找到访问 page 的所有的 vma 来统计分析

rmap_walk_control::rmap_one 仅仅在 rmap_walk_ksm rmap_walk_anon rmap_walk_file 三个位置使用。

--> 分析上面哪一个图 :

1. page_mkclean
2. page_referenced
3. try_to_unmap
4. try_to_munlock : 检查映射到的 page 是被 mlock，试图 munlock

```c
/**
 * try_to_munlock - try to munlock a page
 * @page: the page to be munlocked
 *
 * Called from munlock code.  Checks all of the VMAs mapping the page
 * to make sure nobody else has this page mlocked. The page will be
 * returned with PG_mlocked cleared if no other vmas have it mlocked.
 */

void try_to_munlock(struct page *page)
{
	struct rmap_walk_control rwc = {
		.rmap_one = try_to_unmap_one,
		.arg = (void *)TTU_MUNLOCK,
		.done = page_not_mapped,
		.anon_lock = page_lock_anon_vma_read,

	};

	VM_BUG_ON_PAGE(!PageLocked(page) || PageLRU(page), page);
	VM_BUG_ON_PAGE(PageCompound(page) && PageDoubleMap(page), page);

	rmap_walk(page, &rwc);
}
```


## file-based 的流程
1. page struct 中定义了 : page 的类型

```c
		struct {	/* Page cache and anonymous pages */
			/**
			 * @lru: Pageout list, eg. active_list protected by
			 * zone_lru_lock.  Sometimes used as a generic list
			 * by the page owner.
			 */
			struct list_head lru; // 很清晰，page cache 和 anonymous page 使用同一个 lru 机制管理
			/* See page-flags.h for PAGE_MAPPING_FLAGS */
			struct address_space *mapping;
			pgoff_t index;		/* Our offset within mapping. */
      // 1. 计算得到在虚拟地址，进而得到pte
      // 2. page cache : index 表示 在文件中间的偏移
      // 3. page cache :
			/**
			 * @private: Mapping-private opaque data.
			 * Usually used for buffer_heads if PagePrivate.
			 * Used for swp_entry_t if PageSwapCache.
			 * Indicates order in the buddy system if PageBuddy.
			 */
			unsigned long private;
		};
```

2. 为什么需要使用 interval_tree : 之前一直以为是 page 上持有 interval_tree ，但是实际上一个文件才有一个 interval_tree，显然一个文件可以映射非常多的 interval_tree，可能重叠，但是用该方法都可以快速找到。
```c
static void rmap_walk_file(struct page *page, struct rmap_walk_control *rwc,
		bool locked)
	vma_interval_tree_foreach(vma, &mapping->i_mmap,// 当 page cache 管理的页面同时被 map 过，那么将内容放到此处，否则将会是一个 i_mmap 将会是一个 null
			pgoff_start, pgoff_end) { // XXX interval_tree 的遍历的，利用的是
      // todo anon_vma_interval_tree_foreach 的和这里对称的部分是什么 ?
```

3. unlink_file_vma

```c
/*
 * Unlink a file-based vm structure from its interval tree, to hide
 * vma from rmap and vmtruncate before freeing its page tables.
 */
void unlink_file_vma(struct vm_area_struct *vma)
{
	struct file *file = vma->vm_file;

	if (file) {
		struct address_space *mapping = file->f_mapping;
		i_mmap_lock_write(mapping);
		__remove_shared_vm_struct(vma, file, mapping);
		i_mmap_unlock_write(mapping);
	}
}

/*
 * Requires inode->i_mapping->i_mmap_rwsem
 */
static void __remove_shared_vm_struct(struct vm_area_struct *vma,
		struct file *file, struct address_space *mapping)
{
  // 处理辅助的引用计数的问题
	if (vma->vm_flags & VM_DENYWRITE)
		atomic_inc(&file_inode(file)->i_writecount);
	if (vma->vm_flags & VM_SHARED)
		mapping_unmap_writable(mapping);

  // 从 interval_tree 中间删除
	flush_dcache_mmap_lock(mapping);
	vma_interval_tree_remove(vma, &mapping->i_mmap);
	flush_dcache_mmap_unlock(mapping);
}
```

## rmap.c 的分析

1. unlink_anon_vmas 的作用:
    1. 将 vma 关联的所有 av 删除该 vma 的记录，然后释放用于链接的 avc
    2. 存在一些关于 lock 的小技巧

两个分析的地方:
1. swap 的 pgfault : 为什么使用 rmap 啊 ?

> 换入一个 page 其他的 pte 重做! 换出的时候，所有的 pte 写 swap_entry 还如的时候，不如使用使用 swap_entry 到 va　的映射。
> 换出之后，就没有物理内存，rmap 的 key 怎么办法 ?


filemap_map_pages => alloc_set_pte => page_add_file_rmap
> page fault 完成的过程建立，反向映射。
> rmap 的出现，让有的 pagefault 是没有必要进行 io 的。
> 好像 page_add_file_rmap 只是增加一个引用计数 `page->_mapcount`

回到第四章:

```c
// page_add_file_rmap 中间的内容 越想越奇怪啊!


// 源头之一
void page_add_anon_rmap(struct page *page,
	struct vm_area_struct *vma, unsigned long address, bool compound)

// 预感 compound  first 的作用将会很恶心 !
```

```c
struct Page{
    // page cache 和 anonymous page 才注意到类似于 kmalloc 的内容不属于任何这两者任何一个

		struct {	/* Page cache and anonymous pages */
			/**
			 * @lru: Pageout list, eg. active_list protected by
			 * zone_lru_lock.  Sometimes used as a generic list
			 * by the page owner.
			 */
			struct list_head lru;
			/* See page-flags.h for PAGE_MAPPING_FLAGS */
      // anon 和 file 的不同
			struct address_space *mapping;
      // 在vma中间的偏移量，TODO 岂不是说明 所有的vma 都是不能改变了 !
      // 有什么用 ?
			pgoff_t index;		/* Our offset within mapping. */
			/**
			 * @private: Mapping-private opaque data.
			 * Usually used for buffer_heads if PagePrivate.
			 * Used for swp_entry_t if PageSwapCache.
			 * Indicates order in the buddy system if PageBuddy.
			 */
			unsigned long private;
		};

}
```

Let’s first look at the version for anonymous pages. We first need the `page_lock_anon_vma` helper
function to find the associated list of regions by reference to a specific page instance.
> 我去，为什么，文档都没有读，然后整天 BB 个不停!

## page_get_anon_vma 和 page_lock_anon_vma_read　
1. 两者居然不是简单封装关系
2. 完全的两个外部接口

```c
//　page_lock_anon_vma_read  引用的函数
page_referenced // test if the page was referenced
try_to_unmap // try to remove all page table mappings to a page : 这不就是日思夜想的当一个 page frame 放到swap 中间
try_to_munlock


page_lock_anon_vma_read 读取page->mapping 中的 anon_vma ，with some lock !
```

## try_to_unmap
![](../../img/source/try_to_unmap.png)

1. 这个东西考虑了非常多的情况，很少见，仅仅分析下面的内容

```c
			/*
			 * No need to invalidate here it will synchronize on
			 * against the special swap migration pte.
			 */
		} else if (PageAnon(page)) {
			swp_entry_t entry = { .val = page_private(subpage) };
			pte_t swp_pte;
			/*
			 * Store the swap location in the pte.
			 * See handle_pte_fault() ...
			 */
			if (unlikely(PageSwapBacked(page) != PageSwapCache(page))) { // 下面的注释说，在 try_to_unmap 的调用路径上，不应该出现这种组合。
/* mm: fix lazyfree BUG_ON check in try_to_unmap_one() */

/* If a page is swapbacked, it means it should be in swapcache in */
/* try_to_unmap_one's path. */

/* If a page is !swapbacked, it mean it shouldn't be in swapcache in */
/* try_to_unmap_one's path. */

/* Check both two cases all at once and if it fails, warn and return */
/* SWAP_FAIL.  Such bug never mean we should shut down the kernel. */
				WARN_ON_ONCE(1);
				ret = false;
				/* We have to invalidate as we cleared the pte */
				mmu_notifier_invalidate_range(mm, address,
							address + PAGE_SIZE);
				page_vma_mapped_walk_done(&pvmw);
				break;
			}

      // todo PageAnon 为什么可以不是 PageSwapBacked 的，除非 SwapBacked 就是表示在 swap 中间存在
			/* MADV_FREE page check */
			if (!PageSwapBacked(page)) {
				if (!PageDirty(page)) {  // todo 猜测此处是那种 VM_SHARED 的那种造成的
					/* Invalidate as we cleared the pte */
					mmu_notifier_invalidate_range(mm,
						address, address + PAGE_SIZE);
					dec_mm_counter(mm, MM_ANONPAGES);
					goto discard;
				}

				/*
				 * If the page was redirtied, it cannot be
				 * discarded. Remap the page to page table.
				 */
				set_pte_at(mm, address, pvmw.pte, pteval);
				SetPageSwapBacked(page);
				ret = false;
				page_vma_mapped_walk_done(&pvmw);
				break;
			}

			if (swap_duplicate(entry) < 0) { // Verify that a swap entry is valid and increment its swap map count.
				set_pte_at(mm, address, pvmw.pte, pteval);
				ret = false;
				page_vma_mapped_walk_done(&pvmw);
				break;
			}

			if (list_empty(&mm->mmlist)) {
				spin_lock(&mmlist_lock);
				if (list_empty(&mm->mmlist))
					list_add(&mm->mmlist, &init_mm.mmlist); // todo 作用是什么 ?
				spin_unlock(&mmlist_lock);
			}
			dec_mm_counter(mm, MM_ANONPAGES);
			inc_mm_counter(mm, MM_SWAPENTS);
			swp_pte = swp_entry_to_pte(entry);
			if (pte_soft_dirty(pteval))
				swp_pte = pte_swp_mksoft_dirty(swp_pte);
			set_pte_at(mm, address, pvmw.pte, swp_pte);
			/* Invalidate as we cleared the pte */
			mmu_notifier_invalidate_range(mm, address,
						      address + PAGE_SIZE);
		} else {
			/*
			 * This is a locked file-backed page, thus it cannot
			 * be removed from the page cache and replaced by a new
			 * page before mmu_notifier_invalidate_range_end, so no
			 * concurrent thread might update its page table to
			 * point at new page while a device still is using this
			 * page.
			 *
			 * See Documentation/vm/mmu_notifier.rst
			 */
			dec_mm_counter(mm, mm_counter_file(page));
		}
discard:
		/*
		 * No need to call mmu_notifier_invalidate_range() it has be
		 * done above for all cases requiring it to happen under page
		 * table lock before mmu_notifier_invalidate_range_end()
		 *
		 * See Documentation/vm/mmu_notifier.rst
		 */
		page_remove_rmap(subpage, PageHuge(page)); // 这里会减少 _mapcount
		put_page(page); // 这里会减少 _refcount
	}
```

## vma_address : 返回 page 在被映射的虚拟地址空间的 pte
1. 两个唯一 ref 来源 : rmap_walk_anon 和 rmap_walk_file
2. 原理上 : `page->index` -  `vm_area_struct->vm_pgoff` + `vm_area_struct->vm_start`
    1. 虽然 anon vma 没有文件相对应，但是 vm_pgoff 可以自己定义一下

```c
static inline unsigned long
vma_address(struct page *page, struct vm_area_struct *vma)
{
	unsigned long start, end;

	start = __vma_address(page, vma);
	end = start + PAGE_SIZE * (hpage_nr_pages(page) - 1);

	/* page should be within @vma mapping range */
	VM_BUG_ON_VMA(end < vma->vm_start || start >= vma->vm_end, vma);

	return max(start, vma->vm_start);
}
```


## `__page_set_anon_rmap`
```c
/**
 * __page_set_anon_rmap - set up new anonymous rmap
 * @page:	Page or Hugepage to add to rmap
 * @vma:	VM area to add page to.
 * @address:	User virtual address of the mapping
 * @exclusive:	the page is exclusively owned by the current process
 */
static void __page_set_anon_rmap(struct page *page,
	struct vm_area_struct *vma, unsigned long address, int exclusive)
{
	struct anon_vma *anon_vma = vma->anon_vma;

	BUG_ON(!anon_vma);

	if (PageAnon(page))
		return;

	/*
	 * If the page isn't exclusively mapped into this vma,
	 * we must use the _oldest_ possible anon_vma for the
	 * page mapping!
	 */
	if (!exclusive) // todo 首先什么叫做 exclusive ?
		anon_vma = anon_vma->root;
    // 直接上升到 root ，会不会导致 page 中间需要搜索的范围增大
    // 增大的搜索导致错误 : 不会的，无论是page 所在偏移上是否存在其他的物理页面
    // 由于会进行 page walk，都是最终判断出来该page 是否映射到某个 vma 中间

	anon_vma = (void *) anon_vma + PAGE_MAPPING_ANON;
	page->mapping = (struct address_space *) anon_vma;
	page->index = linear_page_index(vma, address);
}
```

## page->mapping 的 flags 的含义

```c
/*
 * On an anonymous page mapped into a user virtual memory area,
 * page->mapping points to its anon_vma, not to a struct address_space;
 * with the PAGE_MAPPING_ANON bit set to distinguish it.  See rmap.h.
 *
 * On an anonymous page in a VM_MERGEABLE area, if CONFIG_KSM is enabled,
 * the PAGE_MAPPING_MOVABLE bit may be set along with the PAGE_MAPPING_ANON
 * bit; and then page->mapping points, not to an anon_vma, but to a private
 * structure which KSM associates with that merged page.  See ksm.h.
 *
 * PAGE_MAPPING_KSM without PAGE_MAPPING_ANON is used for non-lru movable
 * page and then page->mapping points a struct address_space.
 *
 * Please note that, confusingly, "page_mapping" refers to the inode
 * address_space which maps the page from disk; whereas "page_mapped"
 * refers to user virtual address space into which the page is mapped.
 */
#define PAGE_MAPPING_ANON	0x1
#define PAGE_MAPPING_MOVABLE	0x2
#define PAGE_MAPPING_KSM	(PAGE_MAPPING_ANON | PAGE_MAPPING_MOVABLE)
#define PAGE_MAPPING_FLAGS	(PAGE_MAPPING_ANON | PAGE_MAPPING_MOVABLE)
```

1. VM_MERGEABLE 的含义是什么 ?  谁使用过 ?
3. PAGE_MAPPING_MOVABLE 的含义
 * Please note that, confusingly, "page_mapping" refers to the inode
 * address_space which maps the page from disk; whereas "page_mapped"
 * refers to user virtual address space into which the page is mapped.

`page->mapping` 的复用结果，分别找到两个

```c
struct address_space *page_mapping(struct page *page)
{
	struct address_space *mapping;

	page = compound_head(page);

	/* This happens if someone calls flush_dcache_page on slab page */
	if (unlikely(PageSlab(page)))
		return NULL;

	if (unlikely(PageSwapCache(page))) {
		swp_entry_t entry;

		entry.val = page_private(page);
		return swap_address_space(entry);
	}

	mapping = page->mapping;
	if ((unsigned long)mapping & PAGE_MAPPING_ANON)// 两种表示方法水火不容
		return NULL;

	return (void *)((unsigned long)mapping & ~PAGE_MAPPING_FLAGS); // 下面两个标志位必须清理掉
}
EXPORT_SYMBOL(page_mapping);
```

## mmap 和 rmap 的交互
1. find_mergeable_anon_vma
2. anon_vma_clone 的三个调用者:
    1. copy_vma
    2. `__split_vma` : 几乎靠 `__vma_adjust` 维持生活了
    3. `__vma_adjust`

3. vma_merge : 利用 can_vma_merge_after 和 can_vma_merge_before 等简单的辅助函数判断，然后调用 `__vma_adjust` 进行处理。

```c
  // 首先试图 vma_merge，如果 merge 不成功，那么就拷贝:
	if (find_vma_links(mm, addr, addr + len, &prev, &rb_link, &rb_parent))
		return NULL;	/* should never get here */
	new_vma = vma_merge(mm, prev, addr, addr + len, vma->vm_flags,
			    vma->anon_vma, vma->vm_file, pgoff, vma_policy(vma),
			    vma->vm_userfaultfd_ctx);


		new_vma = vm_area_dup(vma); // 浅拷贝，以及初始化 anon_vma_chain
		if (!new_vma)
			goto out;
		new_vma->vm_start = addr;
		new_vma->vm_end = addr + len;
		new_vma->vm_pgoff = pgoff;
		if (vma_dup_policy(vma, new_vma))
			goto out_free_vma;
		if (anon_vma_clone(new_vma, vma)) // 调用 context 和 anon_vma_fork 类似，拷贝而已。
			goto out_free_mempol;
		if (new_vma->vm_file)
			get_file(new_vma->vm_file); // 增加一个 ref count
		if (new_vma->vm_ops && new_vma->vm_ops->open)
			new_vma->vm_ops->open(new_vma);
		vma_link(mm, new_vma, prev, rb_link, rb_parent);
		*need_rmap_locks = false;
```

## KeyNote

2. page_mapcount = `_mapcount` + 1 表示该 page 出现在 page table 的次数
3. `page->mapping === NULL` 的时候，表示该 page 在 swap cache 中间。
    1. @todo 非常怀疑，当进入 swap cache 的时候，反手就会注册 rmap ，怎么可能 mapping == NULL
5. 如果一个 page 在 swap cache 中间，如果想要释放，其过程是什么 ?
    1. 如果 swap 的 pgfault 将其读入到 swap cache 中间，那么其 mapping 如果 NULL 的话，如何处理 rmap 的关系 ?
        1. anon vma 进行 page fault 之后，对于该 anon vma 又进行了 fork ，怎么办 ? `__page_set_anon_rmap` 当不是 exclusive 的时候，直接标记到 Root 上
    2. 怎么重建 rmap ，之前的所有信息都被消除了? 非常简单:page fault 的时候是可以知道发生所在的 vma 的，rmap 对于任何 page frame 都是需要的! 依靠这个实现 unmap 进而清理所有的 page table entry !
        2. 为什么 `page->private` 需要保存 `swp_entry_t`　的内容, 难道不是 page table entry 保存吗 ? (当其需要再次被写回的时候，依靠这个确定位置，和删除在 radix tree 的关系!)

## alloc_set_pte : 为 page 建立 pte entry 以及 reverse page
1. 主要被 finish_fault 调用
2. @todo 细节满满

```c
/**
 * alloc_set_pte - setup new PTE entry for given page and add reverse page
 * mapping. If needed, the fucntion allocates page table or use pre-allocated.
 *
 * @vmf: fault environment
 * @memcg: memcg to charge page (only for private mappings)
 * @page: page to map
 *
 * Caller must take care of unlocking vmf->ptl, if vmf->pte is non-NULL on
 * return.
 *
 * Target users are page handler itself and implementations of
 * vm_ops->map_pages.
 *
 * Return: %0 on success, %VM_FAULT_ code in case of error.
 */
vm_fault_t alloc_set_pte(struct vm_fault *vmf, struct mem_cgroup *memcg,
		struct page *page)
{
	struct vm_area_struct *vma = vmf->vma;
	bool write = vmf->flags & FAULT_FLAG_WRITE;
	pte_t entry;
	vm_fault_t ret;

	if (pmd_none(*vmf->pmd) && PageTransCompound(page) &&
			IS_ENABLED(CONFIG_TRANSPARENT_HUGE_PAGECACHE)) {
		/* THP on COW? */
		VM_BUG_ON_PAGE(memcg, page);

		ret = do_set_pmd(vmf, page);
		if (ret != VM_FAULT_FALLBACK)
			return ret;
	}

	if (!vmf->pte) {
		ret = pte_alloc_one_map(vmf);
		if (ret)
			return ret;
	}

	/* Re-check under ptl */
	if (unlikely(!pte_none(*vmf->pte)))
		return VM_FAULT_NOPAGE;

	flush_icache_page(vma, page);
	entry = mk_pte(page, vma->vm_page_prot);
	if (write)
		entry = maybe_mkwrite(pte_mkdirty(entry), vma);
	/* copy-on-write page */
	if (write && !(vma->vm_flags & VM_SHARED)) {
		inc_mm_counter_fast(vma->vm_mm, MM_ANONPAGES);
		page_add_new_anon_rmap(page, vma, vmf->address, false);
		mem_cgroup_commit_charge(page, memcg, false, false);
		lru_cache_add_active_or_unevictable(page, vma);
	} else {
		inc_mm_counter_fast(vma->vm_mm, mm_counter_file(page));
		page_add_file_rmap(page, false);
	}
	set_pte_at(vma->vm_mm, vmf->address, vmf->pte, entry);

	/* no need to invalidate: a not-present page won't be cached */
	update_mmu_cache(vma, vmf->address, vmf->pte);

	return 0;
}
```

## 测试一下两者的性能差别
- filemap 和 anon

## 分析是不是让 idle pagetracking
- page_idle_clear_pte_refs

## 上锁机制 :anon_vma_clone  lock_anon_vma_root

## 关键参考
- [](https://www.cnblogs.com/LoyenWang/p/12164683.html)
- http://www.wowotech.net/memory_management/reverse_mapping.html

## TODO
- anon_vma_clone : 关注一下其调用者，应该可以可以用来理解各种操作 vma 大小的情况, split 和 merge 之类的

6. ksm 和 ksm 页反向映射
  - 相关数据结构体介绍
  - ksm 机制剖析（上）
  - ksm 机制剖析（下）
  - 反向映射查找 ksm 页 pte
  - ksm 实践
