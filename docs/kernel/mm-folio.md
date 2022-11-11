# folio

## 阅读一下各种资料
- [An introduction to compound pages](https://lwn.net/Articles/619514/)
  - Compound pages can serve as anonymous memory or be used as buffers within the kernel; they cannot, however, appear in the page cache, which is only prepared to deal with singleton pages.
- [Clarifying memory management with page folios](https://lwn.net/Articles/849538/)
  - `get_folio` and `put_folio` will manage references to the folio much like `get_page` and `put_page`, but without the unneeded calls to `compound_head`

## 在 sublime 使用 Merge tag 'folio 来搜索

分析结束，根本没有进行任何实质性改变，只是将接口改动了。

顺便修改了

- mlock_pagevec
- PG_anon_exclusive 6c287605fd56466e645693eff3ae7c08fba56e0
- migrate_device 是做啥的，最近拆分出来的

- [ ] 能不能测试一下 folio 的效果，什么时候，将多个 page 聚合为一个

## 之前的笔记
```c
static inline struct page *compound_head(struct page *page)
{
	unsigned long head = READ_ONCE(page->compound_head);

	if (unlikely(head & 1))
		return (struct page *) (head - 1);
	return page;
}
```

在 page 几个并行的 struct 中间:
```c
		struct {	/* Tail pages of compound page */
			unsigned long compound_head;	/* Bit zero is set */

			/* First tail page only */
			unsigned char compound_dtor;
			unsigned char compound_order;
			atomic_t compound_mapcount;
		};
```

> https://lwn.net/Articles/619333/


 a call to PageCompound() will return a true value if the passed-in page is a compound page. Head and tail pages can be distinguished, should the need arise, with PageHead() and PageTail()

 ```c
static __always_inline int PageCompound(struct page *page)
{
	return test_bit(PG_head, &page->flags) || PageTail(page);
}
```

Every tail page has a pointer to the head page stored in the `first_page` field of struct page.
This field occupies the same storage as the private field, the spinlock used when the page holds page table entries, or the slab_cache pointer used when the page is owned by a slab allocator. The compound_head() helper function can be used to find the head page associated with any tail page.

## compound page
- [An introduction to compound pages](https://lwn.net/Articles/619514/)
> A compound page is simply a grouping of two or more physically contiguous pages into a unit that can, in many ways, be treated as a single, larger page. They are most commonly used to create huge pages, used within hugetlbfs or the transparent huge pages subsystem, *but they show up in other contexts as well*. *Compound pages can serve as anonymous memory or be used as buffers within the kernel*; *they cannot, however, appear in the page cache, which is only prepared to deal with singleton pages.*

- [x] so why page cache is only prepared to deal with singleton pages ? I think it's rather reasonable to use huge page as backend for page cache.
  - https://lwn.net/Articles/619738/ suggests page cache can use thp too.


- [ ] find the use case the compound page is buffer within the kernel
- [ ] 是不是 compound_head 出现的位置，就是和 huge memory 相关的 ?

> Allocating a compound page is a matter of calling a normal memory allocation function like alloc_pages() with the `__GFP_COMP` allocation flag set and an order of at least one
> The difference is that creating a compound page involves the creation of a fair amount of metadata; much of the time, **that metadata is unneeded so the expense of creating it can be avoided.**

> Let's start with the page flags. The first (normal) page in a compound page is called the "head page"; it has the PG_head flag set. All other pages are "tail pages"; they are marked with PG_tail. At least, that is the case on systems where page flags are not in short supply — 64-bit systems, in other words. On 32-bit systems, there are no page flags to spare, so a different scheme is used; all pages in a compound page have the PG_compound flag set, and the tail pages have PG_reclaim set as well. The PG_reclaim bit is normally used by the page cache code, but, since compound pages cannot be represented in the page cache, that flag can be reused here.
>
> Head and tail pages can be distinguished, should the need arise, with PageHead() and PageTail().

- [ ] verify the complications in 32bit in PageHead() and PageTail()

> Every tail page has a pointer to the head page stored in the `first_page` field of struct page. This field occupies the same storage as the private field, the spinlock used when the page holds page table entries, or the slab_cache pointer used when the page is owned by a slab allocator. The `compound_head()` helper function can be used to find the head page associated with any tail page.

- [ ] 了解一下函数 : PageTransHuge，以及附近的定义，似乎 hugepagefs 和 transparent hugepage 谁采用使用 compound_head 的

- [Minimizing the use of tail pages](https://lwn.net/Articles/787388/)

- [] read the article

## 更多资料
- https://lwn.net/Articles/565097/
