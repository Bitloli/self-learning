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

以 folio 为例子:
