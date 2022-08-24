# buddy


```txt
__alloc_pages+1
folio_alloc+23
__filemap_get_folio+441
pagecache_get_page+21
ext4_da_write_begin+238
generic_perform_write+193
ext4_buffered_write_iter+123
io_write+280
io_issue_sqe+1182
io_wq_submit_work+129
io_worker_handle_work+615
io_wqe_worker+766
ret_from_fork+34
```

```txt
__alloc_pages+1
alloc_pages_vma+143
__handle_mm_fault+2562
handle_mm_fault+178
do_user_addr_fault+460
exc_page_fault+103
asm_exc_page_fault+30
```

```txt
__alloc_pages+1
__get_free_pages+13
__pollwait+137
n_tty_poll+105
tty_poll+102
do_sys_poll+652
__x64_sys_poll+162
do_syscall_64+59
entry_SYSCALL_64_after_hwframe+68
```

```c
/*
 * This is the 'heart' of the zoned buddy allocator.
 */
struct page *__alloc_pages(gfp_t gfp, unsigned int order, int preferred_nid,
							nodemask_t *nodemask)
```
