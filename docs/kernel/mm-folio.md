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
