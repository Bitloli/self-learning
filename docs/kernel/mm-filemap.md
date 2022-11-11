## page cache
1. 对于数据库，为什么需要绕过 page cache
https://www.scylladb.com/2018/07/26/how-scylla-data-cache-works/
2. 当一个文件被关闭之后，其 page cache 会被删除吗 ?
3. 当一个设备被 umount 的时候，其关联的所有的数据需要全部落盘，找到对应实现的代码！


| aspect | page cache             | cache                    |
|--------|------------------------|--------------------------|
| why    | cache disk             | cache memroy             |
| evict  | lru by software        | lru by hardware          |
| locate | radix tree             | physical address and tag |
| dirty  | page writeback control | cache coherency          |

page cache 处理:
1. page cache 位于 vfs 和 fs 之间
    1. file_operations : 处理 vfs 到 page cache 之间的:
        1. @todo 有什么需要做的: 维护读写文件的各种动态信息
    2. address_space_operations :
        1. @todo 将工作交给 buffer.c

2. page cache 内部处理: **可不可以说，其实 page cache 是内存的提供给文件系统的一个工具箱和接口，而文件系统需要利用这个工具箱完成其任务**
    1. radix tree : 基本功能直接使用就可以了 filemap.c
    3. dirty : page-writeback.c fs-writeback.c
    4. page reclaim : vmscan.c
或者说，可以使用 page cache，但是需要处理好。
上面说过的，处理的位置 :
file_operations::write :: write 的 将 page 标记为 dirty，告诉 page reclaim 机制写过的 page 如何
address_space_operations::write 的 将 page 标记为 dirty



解释几个问题:
1. 从 file_operations::write_iter 如何进入到 address_space_operations::wreitepage: 其实这个问题就是向知道，文件系统如何穿过 page cache

generic_file_write_iter => `__generic_file_write_iter` => generic_perform_write

generic_perform_write 的流程:
```c
a_ops->write_begin
iov_iter_copy_from_user_atomic
a_ops->write_end
```
使用 ext2 作为例子:
ext2_write_begin => block_write_begin // 进入到 buffer.c 中间
  1. grab_cache_page_write_begin : Find or create a page at the given pagecache position. Return the locked page. This function is specifically for buffered writes.
      1. pagecache_get_page : 可以找到就返回 page cache 中间的 page，找不到就创建 page cache
  2. `__block_write_begin` : `__block_write_begin_int` 将需要读取的 block 读入到 page cache 中间
ext2_write_end => block_write_end => `__block_commit_write` : set_buffer_uptodate 和 mark_buffer_dirty 更新一下状态

而 file_operations::wreitepage 的实现:
ext2_writepage => block_write_full_page => `__block_write_full_page` : 将 dirty buffer 写回
其调用位置在 page-writeback.c 和 fs-writeback.c 中间。

所以，file_operations::write_iter 首先将 page 写入到 page cache 中间，
在 buffer.c 中间，ll_rw_block 会读取由于没有 block 需要加载的 disk 页面，并且初始化或者更新 buffer cache 的各种。
而写回工作，需要等到 page-writeback.c 和 fs-writeback.c 中间当 flusher 启动的时候，会调用 address_space_operations::writepage 进行
由此得出的结论 : **为了使用 page cache, fs 需要提供的两套接口，file_operations::write_begin file_operations::write_iter 加入到 page cache 中间
通过 address_space_operations::writepage 将 page 从 page cache 发送出去。**


2. 从 file_operations::read_iter => generic_file_read_iter => generic_file_buffered_read => address_space_operations::readpage


3. How `__x64_sys_write` ==> file_operations::write_iter ?

(hint: read_write.c)


- [ ] trace it : pagecache_write_begin

## address_space


## address_space_operations
address_space 和 address_space_operations
// TODO 整理解释其中每一个内容
1. 能够区分 writepage 和 write_begin/write_end 之间的关系是什么 ?
2. freepage 和 releasepage 的关系

```c
struct address_space_operations {
  int (*writepage)(struct page *page, struct writeback_control *wbc);
  int (*readpage)(struct file *, struct page *);

  /* Write back some dirty pages from this mapping. */
  int (*writepages)(struct address_space *, struct writeback_control *);

  /* Set a page dirty.  Return true if this dirtied it */
  int (*set_page_dirty)(struct page *page);

  /*
   * Reads in the requested pages. Unlike ->readpage(), this is
   * PURELY used for read-ahead!.
   */
  int (*readpages)(struct file *filp, struct address_space *mapping,
      struct list_head *pages, unsigned nr_pages);

  int (*write_begin)(struct file *, struct address_space *mapping,
        loff_t pos, unsigned len, unsigned flags,
        struct page **pagep, void **fsdata);
  int (*write_end)(struct file *, struct address_space *mapping,
        loff_t pos, unsigned len, unsigned copied,
        struct page *page, void *fsdata);

  /* Unfortunately this kludge is needed for FIBMAP. Don't use it */
  sector_t (*bmap)(struct address_space *, sector_t);
  void (*invalidatepage) (struct page *, unsigned int, unsigned int);
  int (*releasepage) (struct page *, gfp_t);
  void (*freepage)(struct page *);
  ssize_t (*direct_IO)(struct kiocb *, struct iov_iter *iter);
  /*
   * migrate the contents of a page to the specified target. If
   * migrate_mode is MIGRATE_ASYNC, it must not block.
   */
  int (*migratepage) (struct address_space *,
      struct page *, struct page *, enum migrate_mode);
  bool (*isolate_page)(struct page *, isolate_mode_t);
  void (*putback_page)(struct page *);
  int (*launder_page) (struct page *);
  int (*is_partially_uptodate) (struct page *, unsigned long,
          unsigned long);
  void (*is_dirty_writeback) (struct page *, bool *, bool *);
  int (*error_remove_page)(struct address_space *, struct page *);

  /* swapfile support */
  int (*swap_activate)(struct swap_info_struct *sis, struct file *file,
        sector_t *span);
  void (*swap_deactivate)(struct file *file);
};
```

- [ ] fgp_flags : just flags, it seems find a page in pagecache and swap cache is more tricky than expected
  - [ ] find_get_page
  - [ ] pagecache_get_page

#### page writeback
1. fs-writeback.c 和 page-writeback 的关系是上下级的，但是实际上，不是，fs-writeback.c 只是为了实现整个 inode 写回，以及 metadata 的写回。
2. page writeback 没有 flusher 机制，而是靠 flusher 机制维持生活


// TOOD http://www.wowotech.net/memory_management/327.html
里面的配图，让人感到不安:
虽然，后面 workqueue 相关的内容基本都是错误的，但是到达的路线基本都是正确的
1. laptop_mode 无法解释
2. 居然将 page reclaim 的


// TODO 的内容
9. 搞清楚 fs-writeback 和 page-writeback 各自的作用
    1. laptop_mode 的含义
    2. radix tag 的作用
    3. ratio 的触发
    4. diff 的整理
        1. wb_wakeup_delayed : 看上去是 wakeup 实际上是 queue
        2. 线程都是怎么 spawn 的 以及 杀死的

// TODO
dirty page 的 flag　的操控总结一下
1. inode_operations::dirty_inode
2. vm_operations_struct::page_mkwrite
3. address_space_operations::set_page_dirty
还有让人感到绝对恶心的，page dirty flags
以及辅助函数 set_page_dirty，请问和 address_space_operations::set_page_dirty 的关系是什么

我想知道，page 如何被 dirty，以及如何被 clean ?

dirty 和 update 的关系是什么 ? 各自的管理策略是什么 ?

1. 核心写回函数
```c
int do_writepages(struct address_space *mapping, struct writeback_control *wbc)
{
  int ret;

  if (wbc->nr_to_write <= 0)
    return 0;
  while (1) {
    if (mapping->a_ops->writepages)
      ret = mapping->a_ops->writepages(mapping, wbc); // 有点窒息的地方在于，ext4 的 writepages 注册就是 generic_writepages
    else
      ret = generic_writepages(mapping, wbc); // 调用 address_space::writepage 一个个的写入
    if ((ret != -ENOMEM) || (wbc->sync_mode != WB_SYNC_ALL))
      break;
    cond_resched();
    congestion_wait(BLK_RW_ASYNC, HZ/50);
  }
  return ret;
}
```

2. 各种计算 dirty rate 以及 提供给 proc 的 handler
// 能不能搞清楚，几个 proc 的作用

3. balance_dirty_pages_ratelimited : 任何产生 dirty page 都需要调用此函数，调用位置为:
    1. fault_dirty_shared_page
    2. generic_perform_write :  被调用，`__generic_file_write_iter`，便是唯一的入口。

```c
/**
 * balance_dirty_pages_ratelimited - balance dirty memory state
 * @mapping: address_space which was dirtied
 *
 * Processes which are dirtying memory should call in here once for each page
 * which was newly dirtied.  The function will periodically check the system's
 * dirty state and will initiate writeback if needed.
 *
 * On really big machines, get_writeback_state is expensive, so try to avoid
 * calling it too often (ratelimiting).  But once we're over the dirty memory
 * limit we decrease the ratelimiting by a lot, to prevent individual processes
 * from overshooting the limit by (ratelimit_pages) each.
 */
void balance_dirty_pages_ratelimited(struct address_space *mapping)
  if (unlikely(current->nr_dirtied >= ratelimit)) // 只有超过 ratelimit 的时候才会进行真正的 balance_dirty_pages 的工作
    balance_dirty_pages(wb, current->nr_dirtied); // 很长的函数，在其中触发 fs-writeback.c 的 flusher 维持生活
```


4. `__set_page_dirty_nobuffers` : 被注册为 address_space_operations::set_page_dirty
既然 balance_dirty_pages_ratelimited 被所有的可能的 dirty 的位置注册，那么为什么需要 set_page_dirty
在 balance_dirty_pages_ratelimited 中间调用 `__set_page_dirty_nobuffers` 不就结束了 ?
其实 set_page_dirty 的真实作用是 : 让某些 page 被 writeback skip
```c
/*
 * For address_spaces which do not use buffers.  Just tag the page as dirty in
 * the xarray.
 *
 * This is also used when a single buffer is being dirtied: we want to set the
 * page dirty in that case, but not all the buffers.  This is a "bottom-up"
 * dirtying, whereas __set_page_dirty_buffers() is a "top-down" dirtying.
 *
 * The caller must ensure this doesn't race with truncation.  Most will simply
 * hold the page lock, but e.g. zap_pte_range() calls with the page mapped and
 * the pte lock held, which also locks out truncation.
 */
int __set_page_dirty_nobuffers(struct page *page)

/*
 * For address_spaces which do not use buffers nor write back.
 */
int __set_page_dirty_no_writeback(struct page *page)
{
  if (!PageDirty(page))
    return !TestSetPageDirty(page);
  return 0;
}
```

#### truncate
- [ ] 阅读一下源代码

#### readahead
// 阅读一下源代码 readahead.c 的
// 居然还存在一个 readahead syscall

请问一般的文件的 readahead 和 swap 的 readahead 存在什么区别 ?

## buffer cache
如果 fs/buffer.c 中间是完成写入工作，那么 fs/read_write.c 中间是做什么的 ?
fs/read_write.c 提供的接口是用户层的接口封装。

Buffer cache is a kernel subsystem that handles caching (both read and write) blocks from block devices. The base entity used by cache buffer is the struct buffer_head structure. The most important fields in this structure are:

- `b_data`, pointer to a memory area where the data was read from or where the data must be written to
- `b_size`, buffer size
- `b_bdev`, the block device
- `b_blocknr`, the number of block on the device that has been loaded or needs to be saved on the disk
- `b_state`, the status of the buffer

// 这些函数可以详细调查一下:
There are some important functions that work with these structures:
- `__bread()` : reads a block with the given number and given size in a buffer_head structure; in case of success returns a pointer to the buffer_head structure, otherwise it returns NULL;
- `sb_bread()` : does the same thing as the previous function, but the size of the read block is taken from the superblock, as well as the device from which the read is done;
- `mark_buffer_dirty()` : marks the buffer as dirty (sets the BH_Dirty bit); the buffer will be written to the disk at a later time (from time to time the bdflush kernel thread wakes up and writes the buffers to disk);
- `brelse()` :  frees up the memory used by the buffer, after it has previously written the buffer on disk if needed;
- `map_bh()` :  associates the buffer-head with the corresponding sector.


这两个函数有什么区别吗 ?

```c
set_buffer_dirty();
mark_buffer_dirty();
```

`ext2->writepage` 最终会调用到此处


// TODO
// nobh 的含义是什么 ?
// ext2_direct_IO 和 dax 似乎完全不是一个东西 ?
```c
const struct address_space_operations ext2_aops = {
  .readpage   = ext2_readpage,
  .readpages    = ext2_readpages,
  .writepage    = ext2_writepage,
  .write_begin    = ext2_write_begin,
  .write_end    = ext2_write_end,
  .bmap     = ext2_bmap,
  .direct_IO    = ext2_direct_IO,
  .writepages   = ext2_writepages,
  .migratepage    = buffer_migrate_page,
  .is_partially_uptodate  = block_is_partially_uptodate,
  .error_remove_page  = generic_error_remove_page,
};

const struct address_space_operations ext2_nobh_aops = {
  .readpage   = ext2_readpage,
  .readpages    = ext2_readpages,
  .writepage    = ext2_nobh_writepage,
  .write_begin    = ext2_nobh_write_begin,
  .write_end    = nobh_write_end,
  .bmap     = ext2_bmap,
  .direct_IO    = ext2_direct_IO,
  .writepages   = ext2_writepages,
  .migratepage    = buffer_migrate_page,
  .error_remove_page  = generic_error_remove_page,
};
```


## vma
[TO BE CONTINUE](https://www.cnblogs.com/LoyenWang/p/12037658.html)

1. 内核地址空间存在 vma 吗 ? TODO
  - 应该是不存在的，不然，该 vma 放到哪里呀 ? 挂到各种用户的 mm_struct 上吗 ?

了解一下 vmacache.c 中间的内容

virtual memory area : 内核管理进程的最小单位。

和其他版块的联系:
1. rmap

细节问题的解释:
- [ ] vma 的 vm_flags 是做什么的
2. mprotect

#### vm_ops
- [ ] `vm_ops->page_mkwrite`

#### vm_flags
in fact, we have already understand most of them

- VM_WIPEONFORK : used by madvise, wipe content when fork, check the function in `dup_mmap`, child process will copy_page_range without it

#### page_flags
- I believe, but have find the evidence yet
  - [ ] pte_mkold / pte_mkyoung is used for access page
  - [ ] arm / mips has to use pgfault to set page access mask

page_flags 除了 PG_slab, PG_slab 等 flags 可以使用，还可以用于标记 node zone LAST_CPUID(numa 平衡算法使用)
```c
static inline void set_page_zone(struct page *page, enum zone_type zone)
{
  page->flags &= ~(ZONES_MASK << ZONES_PGSHIFT);
  page->flags |= (zone & ZONES_MASK) << ZONES_PGSHIFT;
}

static inline void set_page_node(struct page *page, unsigned long node)
{
  page->flags &= ~(NODES_MASK << NODES_PGSHIFT);
  page->flags |= (node & NODES_MASK) << NODES_PGSHIFT;
}
```
