# swap.c 分析

1. lurvec 和 pagevec 各自的作用: lrulist 封装和 batch 操作封装
2. 本文件处理的内容和 swap 没有什么蛇皮关系，虽然主要的内容是 pagevec 的各种操作，但是实际上是向各种 lrulist 中间添加。

```txt
#0  lru_add_drain_cpu (cpu=3) at mm/swap.c:665
#1  0xffffffff812a7d2b in lru_add_drain () at mm/swap.c:773
#2  0xffffffff812a7d84 in __pagevec_release (pvec=pvec@entry=0xffffc9000005fb88) at mm/swap.c:1072
#3  0xffffffff812a8ab1 in pagevec_release (pvec=0xffffc9000005fb88) at include/linux/pagevec.h:71
#4  folio_batch_release (fbatch=0xffffc9000005fb88) at include/linux/pagevec.h:135
```

- [ ] 现在 lruvec 到底是什么作用，怎么感觉是一个 memcg 持有一个?

## 调用环节 : 莫名奇妙的
> vmscan.c 整个维持 swap 页面的替换回去，但是 page cache 的刷新回去的操作谁来控制 ?
> page cache 和 swap cache 是不是采用相同的模型进行的 ? 如果说，其中，将 anon memory 当做 swap 形成的 file based 那么岂不是很好。

```txt
#0  add_to_swap (folio=folio@entry=0xffffea0002ef9e00) at mm/swap_state.c:182
#1  0xffffffff812ade01 in shrink_folio_list (folio_list=folio_list@entry=0xffffc900012bbc30, pgdat=pgdat@entry=0xffff88823fff9000, sc=sc@entry=0xffffc900012bbdd8, stat=stat@entry=0xffffc900012bbcb8, ignore_references=ignore_references@entry=false) at mm/vmscan.c:1834
#2  0xffffffff812af5d8 in shrink_inactive_list (lru=LRU_INACTIVE_ANON, sc=0xffffc900012bbdd8, lruvec=0xffff888164d5c000, nr_to_scan=<optimized out>) at mm/vmscan.c:2489
#3  shrink_list (sc=0xffffc900012bbdd8, lruvec=0xffff888164d5c000, nr_to_scan=<optimized out>, lru=LRU_INACTIVE_ANON) at mm/vmscan.c:2716
#4  shrink_lruvec (lruvec=lruvec@entry=0xffff888164d5c000, sc=sc@entry=0xffffc900012bbdd8) at mm/vmscan.c:5885
#5  0xffffffff812afe3f in shrink_node_memcgs (sc=0xffffc900012bbdd8, pgdat=0xffff88823fff9000) at mm/vmscan.c:6074
#6  shrink_node (pgdat=pgdat@entry=0xffff88823fff9000, sc=sc@entry=0xffffc900012bbdd8) at mm/vmscan.c:6105
#7  0xffffffff812b0577 in kswapd_shrink_node (sc=0xffffc900012bbdd8, pgdat=0xffff88823fff9000) at mm/vmscan.c:6894
#8  balance_pgdat (pgdat=pgdat@entry=0xffff88823fff9000, order=order@entry=9, highest_zoneidx=highest_zoneidx@entry=3) at mm/vmscan.c:7084
#9  0xffffffff812b0b2b in kswapd (p=0xffff88823fff9000) at mm/vmscan.c:7344
#10 0xffffffff81133853 in kthread (_create=0xffff888004058240) at kernel/kthread.c:376
```

## folio_add_lru

- folio_add_lru : 将 page 添加到 folio_batch 中
- lru_add_drain_cpu : 将 folio_batch 中的 page 移动到 lru 中

```txt
#0  lru_add_drain_cpu (cpu=1) at mm/swap.c:665
#1  0xffffffff812a7f4b in lru_add_drain () at mm/swap.c:773
#2  0xffffffff812af51d in shrink_inactive_list (lru=LRU_INACTIVE_ANON, sc=0xffffc90000127ba8, lruvec=0xffff888164d5c000, nr_to_scan=32) at mm/vmscan.c:2470
#3  shrink_list (sc=0xffffc90000127ba8, lruvec=0xffff888164d5c000, nr_to_scan=32, lru=LRU_INACTIVE_ANON) at mm/vmscan.c:2716
#4  shrink_lruvec (lruvec=lruvec@entry=0xffff888164d5c000, sc=sc@entry=0xffffc90000127ba8) at mm/vmscan.c:5885
#5  0xffffffff812afe3f in shrink_node_memcgs (sc=0xffffc90000127ba8, pgdat=0xffff88823fff9000) at mm/vmscan.c:6074
#6  shrink_node (pgdat=pgdat@entry=0xffff88823fff9000, sc=sc@entry=0xffffc90000127ba8) at mm/vmscan.c:6105
#7  0xffffffff812b1030 in shrink_zones (sc=0xffffc90000127ba8, zonelist=<optimized out>) at mm/vmscan.c:6343
#8  do_try_to_free_pages (zonelist=zonelist@entry=0xffff88823fffab00, sc=sc@entry=0xffffc90000127ba8) at mm/vmscan.c:6405
#9  0xffffffff812b1aaa in try_to_free_pages (zonelist=0xffff88823fffab00, order=order@entry=0, gfp_mask=gfp_mask@entry=1314250, nodemask=<optimized out>) at mm/vmscan.c:6640
#10 0xffffffff812ffb89 in __perform_reclaim (ac=0xffffc90000127d28, order=0, gfp_mask=1314250) at mm/page_alloc.c:4755
#11 __alloc_pages_direct_reclaim (did_some_progress=<synthetic pointer>, ac=0xffffc90000127d28, alloc_flags=2240, order=0, gfp_mask=1314250) at mm/page_alloc.c:4777
#12 __alloc_pages_slowpath (gfp_mask=<optimized out>, gfp_mask@entry=1314250, order=order@entry=0, ac=ac@entry=0xffffc90000127d28) at mm/page_alloc.c:5183
#13 0xffffffff81300718 in __alloc_pages (gfp=gfp@entry=1314250, order=order@entry=0, preferred_nid=<optimized out>, nodemask=0x0 <fixed_percpu_data>) at mm/page_alloc.c:5568
#14 0xffffffff81301022 in __folio_alloc (gfp=gfp@entry=1052106, order=order@entry=0, preferred_nid=<optimized out>, nodemask=<optimized out>) at mm/page_alloc.c:5587
```

一个经典的调用:
```txt
#0  filemap_add_folio (mapping=mapping@entry=0xffff8880369cb9c0, folio=folio@entry=0xffffea0008731dc0, index=index@entry=0, gfp=gfp@entry=1125578) at mm/filemap.c:929
#1  0xffffffff812a47af in page_cache_ra_unbounded (ractl=ractl@entry=0xffffc9000189fd18, nr_to_read=71, lookahead_size=<optimized out>) at mm/readahead.c:251
#2  0xffffffff812a4e27 in do_page_cache_ra (lookahead_size=<optimized out>, nr_to_read=<optimized out>, ractl=0xffffc9000189fd18) at mm/readahead.c:300
#3  0xffffffff8129a2ba in do_sync_mmap_readahead (vmf=0xffffc9000189fdf8) at mm/filemap.c:3043
#4  filemap_fault (vmf=0xffffc9000189fdf8) at mm/filemap.c:3135
#5  0xffffffff812d39ef in __do_fault (vmf=vmf@entry=0xffffc9000189fdf8) at mm/memory.c:4203
#6  0xffffffff812d7ef1 in do_read_fault (vmf=0xffffc9000189fdf8) at mm/memory.c:4554
#7  do_fault (vmf=vmf@entry=0xffffc9000189fdf8) at mm/memory.c:4683
#8  0xffffffff812dcad4 in handle_pte_fault (vmf=0xffffc9000189fdf8) at mm/memory.c:4955
#9  __handle_mm_fault (vma=vma@entry=0xffff8880626a5260, address=address@entry=94203785161552, flags=flags@entry=596) at mm/memory.c:5097
#10 0xffffffff812dd7b0 in handle_mm_fault (vma=0xffff8880626a5260, address=address@entry=94203785161552, flags=flags@entry=596, regs=regs@entry=0xffffc9000189ff58) at mm/memory.c:5218
#11 0xffffffff810f3ca3 in do_user_addr_fault (regs=regs@entry=0xffffc9000189ff58, error_code=error_code@entry=4, address=address@entry=94203785161552) at arch/x86/mm/fault.c:1428
#12 0xffffffff81faf042 in handle_page_fault (address=94203785161552, error_code=4, regs=0xffffc9000189ff58) at arch/x86/mm/fault.c:1519
#13 exc_page_fault (regs=0xffffc9000189ff58, error_code=4) at arch/x86/mm/fault.c:1575
#14 0xffffffff82000b62 in asm_exc_page_fault () at ./arch/x86/include/asm/idtentry.h:570
#15 0x000055ad88e4d310 in ?? ()
```



## wired

```c
// TODO 完成相同的函数为什么写两次，
// 而且不知道和 lru_cache_add 的区别啊 !
// TODO 它被谁调用 ?

/**
 * lru_cache_add_anon - add a page to the page lists
 * @page: the page to add
 */
void lru_cache_add_anon(struct page *page)
{
    if (PageActive(page))
        ClearPageActive(page);
    __lru_cache_add(page);
}

void lru_cache_add_file(struct page *page)
{
    if (PageActive(page))
        ClearPageActive(page);
    __lru_cache_add(page);
}
EXPORT_SYMBOL(lru_cache_add_file);
```


## pagevec_lru_move_fn
1. 对于 pagevec 中间的所有 page 调用 move_fn
2. 然后 release_pages

```c
static void pagevec_lru_move_fn(struct pagevec *pvec,
    void (*move_fn)(struct page *page, struct lruvec *lruvec, void *arg),
    void *arg)
{
    int i;
    struct pglist_data *pgdat = NULL;
    struct lruvec *lruvec;
    unsigned long flags = 0;

    for (i = 0; i < pagevec_count(pvec); i++) { // 对于 pagevec 中间所有的数值处理掉
        struct page *page = pvec->pages[i];
        struct pglist_data *pagepgdat = page_pgdat(page);

        if (pagepgdat != pgdat) {
            if (pgdat)
                spin_unlock_irqrestore(&pgdat->lru_lock, flags); // 当切换到不同的 pgdat 的时候，需要将 pgdat 对于 lru lock 去掉锁
            pgdat = pagepgdat;
            spin_lock_irqsave(&pgdat->lru_lock, flags);
        }

        lruvec = mem_cgroup_page_lruvec(page, pgdat);
        (*move_fn)(page, lruvec, arg);
    }
    if (pgdat)
        spin_unlock_irqrestore(&pgdat->lru_lock, flags);
    release_pages(pvec->pages, pvec->nr); // todo 为什么要 release
    pagevec_reinit(pvec);
}
```

## pagevec_lru_move_fn 的调用者 : 其实是外部的接口

> 依赖于某一个模式，move_fn 定义的 paradiam : 将当前的 page 移除所在的 lru list 然后添加到制定的 lru list 中间。

```c
/*
 * pagevec_move_tail() must be called with IRQ disabled.
 * Otherwise this may cause nasty races.
 */
static void pagevec_move_tail(struct pagevec *pvec)
{
    int pgmoved = 0;

    pagevec_lru_move_fn(pvec, pagevec_move_tail_fn, &pgmoved);
    __count_vm_events(PGROTATED, pgmoved);
}

static void activate_page_drain(int cpu)
{
    struct pagevec *pvec = &per_cpu(activate_page_pvecs, cpu);

    if (pagevec_count(pvec))
        pagevec_lru_move_fn(pvec, __activate_page, NULL);
}


/*
 * Drain pages out of the cpu's pagevecs.
 * Either "cpu" is the current CPU, and preemption has already been
 * disabled; or "cpu" is being hot-unplugged, and is already dead.
 */
void lru_add_drain_cpu(int cpu)
    if (pagevec_count(pvec))
        pagevec_lru_move_fn(pvec, lru_deactivate_file_fn, NULL);

    pvec = &per_cpu(lru_lazyfree_pvecs, cpu);
    if (pagevec_count(pvec))
        pagevec_lru_move_fn(pvec, lru_lazyfree_fn, NULL);


/**
 * deactivate_file_page - forcefully deactivate a file page
 * @page: page to deactivate
 * This function hints the VM that @page is a good reclaim candidate,
 * for example if its invalidation fails due to the page being dirty
 * or under writeback.
 */
void deactivate_file_page(struct page *page)
{
    /*
     * In a workload with many unevictable page such as mprotect,
     * unevictable page deactivation for accelerating reclaim is pointless.
     */
    if (PageUnevictable(page))
        return;

    if (likely(get_page_unless_zero(page))) {
        struct pagevec *pvec = &get_cpu_var(lru_deactivate_file_pvecs);

        if (!pagevec_add(pvec, page) || PageCompound(page))
            pagevec_lru_move_fn(pvec, lru_deactivate_file_fn, NULL);
        put_cpu_var(lru_deactivate_file_pvecs);
    }
}

/**
 * mark_page_lazyfree - make an anon page lazyfree
 * @page: page to deactivate
 * mark_page_lazyfree() moves @page to the inactive file list.
 * This is done to accelerate the reclaim of @page.
 */
void mark_page_lazyfree(struct page *page)
{
    if (PageLRU(page) && PageAnon(page) && PageSwapBacked(page) &&
        !PageSwapCache(page) && !PageUnevictable(page)) {
        struct pagevec *pvec = &get_cpu_var(lru_lazyfree_pvecs);

        get_page(page);
        if (!pagevec_add(pvec, page) || PageCompound(page))
            pagevec_lru_move_fn(pvec, lru_lazyfree_fn, NULL);
        put_cpu_var(lru_lazyfree_pvecs);
    }
}

/*
 * Add the passed pages to the LRU, then drop the caller's refcount
 * on them.  Reinitialises the caller's pagevec.
 */
void __pagevec_lru_add(struct pagevec *pvec)
{
    pagevec_lru_move_fn(pvec, __pagevec_lru_add_fn, NULL);
}
EXPORT_SYMBOL(__pagevec_lru_add);
```

## pagevec_lru_move_fn 的参数
似乎是除了第一个，其余的都是用于实现在 lrulsit 上进行移动的，其实也不是移动，只是从一个 list 上删除，然后加入到另一个 list 上，删除也只是为了保持不要同时出现在多个 list 上的防护，
所以，下面的各种移动函数，只是特殊版本的添加函数。只要这些函数是作为 pagevec_lru_move_fn 的参数，那么，其作用就是添加，而不是移动。

#### (1) `__pagevec_lru_add_fn`

1. 确定正确的 lrulist 然后添加到其中
```c
static void __pagevec_lru_add_fn(struct page *page, struct lruvec *lruvec,
                 void *arg)
{
    enum lru_list lru;
    int was_unevictable = TestClearPageUnevictable(page);

    VM_BUG_ON_PAGE(PageLRU(page), page);

    SetPageLRU(page);
    /*
     * Page becomes evictable in two ways:
     * 1) Within LRU lock [munlock_vma_page() and __munlock_pagevec()].
     * 2) Before acquiring LRU lock to put the page to correct LRU and then
     *   a) do PageLRU check with lock [check_move_unevictable_pages]
     *   b) do PageLRU check before lock [clear_page_mlock]
     *
     * (1) & (2a) are ok as LRU lock will serialize them. For (2b), we need
     * following strict ordering:
     *
     * #0: __pagevec_lru_add_fn     #1: clear_page_mlock
     *
     * SetPageLRU()             TestClearPageMlocked()
     * smp_mb() // explicit ordering    // above provides strict
     *                  // ordering
     * PageMlocked()            PageLRU()
     *
     *
     * if '#1' does not observe setting of PG_lru by '#0' and fails
     * isolation, the explicit barrier will make sure that page_evictable
     * check will put the page in correct LRU. Without smp_mb(), SetPageLRU
     * can be reordered after PageMlocked check and can make '#1' to fail
     * the isolation of the page whose Mlocked bit is cleared (#0 is also
     * looking at the same page) and the evictable page will be stranded
     * in an unevictable LRU.
     */
    smp_mb(); // todo 777777 这应该是理解 smp_mb() 最简单的位置了

    if (page_evictable(page)) {
        lru = page_lru(page);
        update_page_reclaim_stat(lruvec, page_is_file_cache(page),
                     PageActive(page));
        if (was_unevictable)
            count_vm_event(UNEVICTABLE_PGRESCUED);
    } else {
        lru = LRU_UNEVICTABLE;
        ClearPageActive(page); // clearPageActive ，因为都设置为 unevictable 了
        SetPageUnevictable(page);
        if (!was_unevictable)
            count_vm_event(UNEVICTABLE_PGCULLED);
    }

    add_page_to_lru_list(page, lruvec, lru);
    trace_mm_lru_insertion(page, lru);
}
```

#### (2) lru_lazyfree_fn 搬运

```c
static void lru_lazyfree_fn(struct page *page, struct lruvec *lruvec,
                void *arg)
{
    if (PageLRU(page) && PageAnon(page) && PageSwapBacked(page) &&
        !PageSwapCache(page) && !PageUnevictable(page)) { // 各种限制条件
        bool active = PageActive(page);

        del_page_from_lru_list(page, lruvec,
                       LRU_INACTIVE_ANON + active); // todo 取出来的位置是 ANON
        ClearPageActive(page);
        ClearPageReferenced(page);
        /*
         * lazyfree pages are clean anonymous pages. They have
         * SwapBacked flag cleared to distinguish normal anonymous
         * pages
         */
        ClearPageSwapBacked(page);
        add_page_to_lru_list(page, lruvec, LRU_INACTIVE_FILE); // todo 放入的位置却是 FILE

        __count_vm_events(PGLAZYFREE, hpage_nr_pages(page));
        count_memcg_page_event(page, PGLAZYFREE);
        update_page_reclaim_stat(lruvec, 1, 0);
    }
}
```


#### (3) lru_deactivate_file_fn 搬运
> @todo 这注释看不懂啊 !

```c
/*
 * If the page can not be invalidated, it is moved to the
 * inactive list to speed up its reclaim.  It is moved to the
 * head of the list, rather than the tail, to give the flusher
 * threads some time to write it out, as this is much more
 * effective than the single-page writeout from reclaim.
 *
 * If the page isn't page_mapped and dirty/writeback, the page
 * could reclaim asap using PG_reclaim.
 *
 * 1. active, mapped page -> none
 * 2. active, dirty/writeback page -> inactive, head, PG_reclaim
 * 3. inactive, mapped page -> none
 * 4. inactive, dirty/writeback page -> inactive, head, PG_reclaim
 * 5. inactive, clean -> inactive, tail
 * 6. Others -> none
 *
 * In 4, why it moves inactive's head, the VM expects the page would
 * be write it out by flusher threads as this is much more effective
 * than the single-page writeout from reclaim.
 */
static void lru_deactivate_file_fn(struct page *page, struct lruvec *lruvec,
                  void *arg)
{
    int lru, file;
    bool active;

    if (!PageLRU(page))
        return;

    if (PageUnevictable(page))
        return;

    /* Some processes are using the page */
    if (page_mapped(page))
        return;

    active = PageActive(page);
    file = page_is_file_cache(page);
    lru = page_lru_base_type(page);

    del_page_from_lru_list(page, lruvec, lru + active);
    ClearPageActive(page);
    ClearPageReferenced(page);

    if (PageWriteback(page) || PageDirty(page)) {
        /*
         * PG_reclaim could be raced with end_page_writeback
         * It can make readahead confusing.  But race window
         * is _really_ small and  it's non-critical problem.
         */
        add_page_to_lru_list(page, lruvec, lru);
        SetPageReclaim(page);
    } else {
        /*
         * The page's writeback ends up during pagevec
         * We moves tha page into tail of inactive.
         */
        add_page_to_lru_list_tail(page, lruvec, lru);
        __count_vm_event(PGROTATED);
    }

    if (active)
        __count_vm_event(PGDEACTIVATE);
    update_page_reclaim_stat(lruvec, file, 0);
}
```

#### (4) lru_deactivate_fn 搬运
```c
static void lru_deactivate_fn(struct page *page, struct lruvec *lruvec,
                void *arg)
{
    if (PageLRU(page) && PageActive(page) && !PageUnevictable(page)) {
        int file = page_is_file_cache(page);
        int lru = page_lru_base_type(page);

        del_page_from_lru_list(page, lruvec, lru + LRU_ACTIVE);
        ClearPageActive(page);
        ClearPageReferenced(page);
        add_page_to_lru_list(page, lruvec, lru);

        __count_vm_events(PGDEACTIVATE, hpage_nr_pages(page));
        update_page_reclaim_stat(lruvec, file, 0);
    }
}
```

#### (5) `__activate_page` 搬运

```c
static void __activate_page(struct page *page, struct lruvec *lruvec,
                void *arg)
{
    if (PageLRU(page) && !PageActive(page) && !PageUnevictable(page)) {
        int file = page_is_file_cache(page);
        int lru = page_lru_base_type(page);

        del_page_from_lru_list(page, lruvec, lru);
        SetPageActive(page);
        lru += LRU_ACTIVE;
        add_page_to_lru_list(page, lruvec, lru);
        trace_mm_lru_activate(page);

        __count_vm_event(PGACTIVATE);
        update_page_reclaim_stat(lruvec, file, 1);
    }
}
```



## lru_add_drain_cpu
1. 想不到还有一堆 percpu 的 pagevec
    1. 这不是废话吗 ? 不然将 page 积累在什么地方上 ?
```c
/*
 * Drain pages out of the cpu's pagevecs.
 * Either "cpu" is the current CPU, and preemption has already been
 * disabled; or "cpu" is being hot-unplugged, and is already dead.
 */
void lru_add_drain_cpu(int cpu)
{
    struct pagevec *pvec = &per_cpu(lru_add_pvec, cpu);

    if (pagevec_count(pvec))
        __pagevec_lru_add(pvec);                                 // 1

    pvec = &per_cpu(lru_rotate_pvecs, cpu);
    if (pagevec_count(pvec)) {
        unsigned long flags;

        /* No harm done if a racing interrupt already did this */
        local_irq_save(flags);
        pagevec_move_tail(pvec);
        local_irq_restore(flags);
    }

    pvec = &per_cpu(lru_deactivate_file_pvecs, cpu);
    if (pagevec_count(pvec))
        pagevec_lru_move_fn(pvec, lru_deactivate_file_fn, NULL); // 2

    pvec = &per_cpu(lru_deactivate_pvecs, cpu);
    if (pagevec_count(pvec))
        pagevec_lru_move_fn(pvec, lru_deactivate_fn, NULL);      // 3

    pvec = &per_cpu(lru_lazyfree_pvecs, cpu);
    if (pagevec_count(pvec))
        pagevec_lru_move_fn(pvec, lru_lazyfree_fn, NULL);        // 4

    activate_page_drain(cpu);
}
```

## mark_page_accessed
> @todo 也许参考一下其他的位置

```c
/*
 * Mark a page as having seen activity.
 *
 * inactive,unreferenced    ->  inactive,referenced
 * inactive,referenced      ->  active,unreferenced
 * active,unreferenced      ->  active,referenced
 *
 * When a newly allocated page is not yet visible, so safe for non-atomic ops,
 * __SetPageReferenced(page) may be substituted for mark_page_accessed(page).
 */
void mark_page_accessed(struct page *page)
{
    page = compound_head(page);

    if (!PageReferenced(page)) {
        SetPageReferenced(page);
    } else if (PageUnevictable(page)) {
        /*
         * Unevictable pages are on the "LRU_UNEVICTABLE" list. But,
         * this list is never rotated or maintained, so marking an
         * evictable page accessed has no effect.
         */
    } else if (!PageActive(page)) {
        /*
         * If the page is on the LRU, queue it for activation via
         * activate_page_pvecs. Otherwise, assume the page is on a
         * pagevec, mark it active and it'll be moved to the active
         * LRU on the next drain.
         */
        if (PageLRU(page))
            activate_page(page);
        else
            __lru_cache_activate_page(page);
        ClearPageReferenced(page);
        if (page_is_file_cache(page))
            workingset_activation(page);
    }
}
EXPORT_SYMBOL(mark_page_accessed);
```
1. filemap.c : do_read_cache_page  pagecache_get_page generic_file_buffered_read
2. buffered-io.c : 看不懂
3. fs/buffer.c : `__find_get_block`
4. shmem.c : 没有分析

> @todo 此处仅仅处理了文件 io 使用的 mark_page_accessed 的情况
> @todo 当一个 page 用于实现加速 读写文件的时候，还有 rmap 的需求吗 ?
    1. rmap 用于实现 page frame 和 vma 之间的关系
        1. 三个入口了解一下

> @todo 同样的，此处分析的内容缺少 anon 的分析，除非 shmem.c 中间的是用于 /tmp 的，所以似乎没有用于 anon 的
> 除非，mark_page_accessed 表示这次，这个东西是和 fs 打过交道的
> 所以，对于 anon 处理的地方在于 swap cache 中间吗 ?


> @todo 非常的怀疑，page_referenced 的调用，只有当发现其实在上一次调用 page_referenced 到此次，根本没有任何
> 对于该 page frame 的映射发生过访问，所以，决定下调。
> 而 mark_page_accessed 出现的位置表示 : 该 page 刚刚读入进来，如果此时换出，非常的不应该。


mark_page_accessed : 慢速访问，重量级访问
    1. anon page 加入和 mark_page_accessed 的操作都是不知道在哪里的!
    2. 如果 mark_page_accessed 真的是 慢速访问，重量级访问，那么，应该 swap cache 就需要含有对应的调用
        1. swap cache 也是需要加入到 lrulist 中间吧 !

page_referenced : 硬件记录，轻量级访问
    1. 但是 page cache
    2. 当一个 page 被映射到 vma，为什么还需要 page cache ?
        1. page cache 是用于读写文件的加速的
        2. 证据容易验证 : file mapped 的发生 pgfault 发生的时候，会利用 page cache 吗 ? 会拷贝，还是直接修改 page table 就可以了 ?

lruvec 中间的类型只有 : anon 以及 file 和 unevictable，都是映射而已。
    1. 如果是靠这个怀疑 io page cache 不在 reclaim 的机制之下，那么 generic_file_buffered_read 中间也是调用过 mark_page_accessed 的
    2. page-writeback 的功能只是表示 dirty 数量不要超过某一个阈值，和到底存在多少个 page 在内存中间没有关系

**filemap_fault 调用过 find_get_page，所以 mapped 的区间不可能不被 page cache 管理过**



## `put_page` : 基于 `_refcount` 的释放 page

```c
static inline void put_page(struct page *page)
{
    page = compound_head(page);

    /*
     * For devmap managed pages we need to catch refcount transition from
     * 2 to 1, when refcount reach one it means the page is free and we
     * need to inform the device driver through callback. See
     * include/linux/memremap.h and HMM for details.
     */
    if (page_is_devmap_managed(page)) { // 依赖于 CONFIG_DEV_PAGEMAP_OPS
        put_devmap_managed_page(page);
        return;
    }

    if (put_page_testzero(page)) // 减少其 _refcount，当 _refcount 为 0 的时候，删除 page
        __put_page(page);
}

void __put_page(struct page *page)
{
    if (is_zone_device_page(page)) {
        put_dev_pagemap(page->pgmap);

        /*
         * The page belongs to the device that created pgmap. Do
         * not return it to page allocator.
         */
        return;
    }

    if (unlikely(PageCompound(page)))
        __put_compound_page(page);
    else
        __put_single_page(page);
}


static void __put_single_page(struct page *page)
{
    __page_cache_release(page);
    mem_cgroup_uncharge(page);
    free_unref_page(page); // 释放工作
}

/*
 * This path almost never happens for VM activity - pages are normally
 * freed via pagevecs.  But it gets used by networking.
 */
static void __page_cache_release(struct page *page)
{
    if (PageLRU(page)) { // todo 不知道为什么此处突然出现了 LRU list 的删除工作的含义是什么 ?
        pg_data_t *pgdat = page_pgdat(page);
        struct lruvec *lruvec;
        unsigned long flags;

        spin_lock_irqsave(&pgdat->lru_lock, flags);
        lruvec = mem_cgroup_page_lruvec(page, pgdat);
        VM_BUG_ON_PAGE(!PageLRU(page), page);
        __ClearPageLRU(page);
        del_page_from_lru_list(page, lruvec, page_off_lru(page));
        spin_unlock_irqrestore(&pgdat->lru_lock, flags);
    }
    __ClearPageWaiters(page); // todo 什么意思 ?
}
```

## swap

// 从 swapOn 的部分开始分析就可以了，所以为什么 shmem 中间存在一堆内容
// 经典函数收集，尤其是 page swap 中间的
// 4. swap_slots 的工作原理是什么 ?


swap 应该算是是历史遗留产物，之所以阅读之，是因为不看的话，其他的部分看不懂。
1. shmem 以及基于 shmem 实现的 /tmp 中间的内容可以被 swap 到磁盘
2. 匿名映射的内存，比如用户使用 syscall brk 分配的，可以被 swap 到磁盘
3. 当进行 swap 机制开始回收的时候，一个物理页面需要被清楚掉，但是映射到该物理页面的 pte_t 的需要被重写为 swp_entry_t 的内容，由于可能共享，所以需要 rmap 实现找到这些 pte，
4. page reclaim 机制可能需要清理 swap cache 的内容
5. hugetlb 和 transparent hugetlb 的页面能否换出，如何换出 ?

swap 机制主要组成部分是什么 :
    0. swap cache 来实现其中
    1. page 和 设备上的 io : page-io.c
    2. swp_entry_t 空间的分配 : swapfile.c
    3. policy :
        1. 确定那些页面需要被放到 swap 中间
        2. swap cache 的页面如何处理
    4. 特殊的 swap

在 mm/ 文件夹下涉及到 swap 的文件，和对于 swap 的作用:
| Name        | description                 |
|-------------|-----------------------------|
| swapfile    |                             |
| swap_state  | 维护 swap cache，swap 的 readahead                           |
| swap        | pagevec 和 lrulist 的操作，其实和 swap 的关系不大 |
| swap_slot   |                             |
| page_io     | 进行通往底层的 io                             |
| mlock       |                             |
| workingset  |                             |
| frontswap   |                             |
| zswap       |                             |
| swap_cgroup |                             |

struct page 的支持
1. `page->private` 用于存储 swp_entry_t.val，表示其中的
2. TODO 还有其他的内容吗

#### swap cache

swap_state.c 主要内容:
| Function name               | desc                                                                                 |
|-----------------------------|--------------------------------------------------------------------------------------|
| `read_swap_cache_async`     |                                                                                      |
| `swap_cluster_readahead`    | @todo 为什么 readahead 不是利用 page cache 中间的公共框架，最终调用在 do_swap_page 中间 |
| `swap_vma_readahead`        | 另一个 readahead 策略，swapin_readahead 中间被决定                                    |
| `total_swapcache_pages`     | 返回所有的 swap 持有的 page frame                                                    |
| `show_swap_cache_info`      | 打印 swap_cache_info 以及 swapfile 中间的                                            |
| `add_to_swap_cache`       | 将 page 插入到 radix_tree 中间                                                        |
| `add_to_swap`               | 利用 `swap_slots.c` 获取 get_swap_page 获取空闲 swp_entry                             |
| `__delete_from_swap_cache`  | 对称操作                                                                             |
| `delete_from_swap_cache`    |                                                                                      |
| `free_swap_cache`           | 调用 swapfile.c try_to_free_swap @todo swapfile.c 的内容比想象的多得多啊 !            |
| `free_page_and_swap_cache`  |                                                                                      |
| `free_pages_and_swap_cache` |                                                                                      |
| `lookup_swap_cache`         | find_get_page 如果不考虑处理 readahead 机制的话                                      |
| `__read_swap_cache_async`   |                                                                                      |
| `swapin_nr_pages`           | readahead 函数的读取策略 @todo                                                       |
| `init_swap_address_space`   | swapon syscall 调用，初始化 swap                                                      |
1. /sys/kernel/mm/swap/vma_ra_enabled 来控制是否 readahead
2. 建立 radix_tree 的过程，多个文件，多个分区，各自大小而且不同 ? init_swap_address_space 中说明的，对于一个文件，每 64M 创建一个 radix_tree，至于其来自于那个文件还是分区，之后寻址的时候不重要了。init_swap_address_space 被 swapon 唯一调用
```c
struct address_space *swapper_spaces[MAX_SWAPFILES] __read_mostly;
static unsigned int nr_swapper_spaces[MAX_SWAPFILES] __read_mostly;
```
3. 谁会调用 add_to_swap 这一个东西 ?
    1. 认为 : 当 anon page 发生 page fault 在 swap cache 中间没有找到的时候，创建了一个 page，于是乎将该 page 通过 add_to_swap 加入到 swap cache
    2. 实际上 : 只有 shrink_page_list 调用，这个想法 `__read_swap_cache_async` 实现的非常不错。
    3. 猜测 : 当一个 page 需要被写会的时候，首先将其添加到 swap cache 中间
```c
/**
 * add_to_swap - allocate swap space for a page
 * @page: page we want to move to swap
 *
 * Allocate swap space for the page and add the page to the
 * swap cache.  Caller needs to hold the page lock.
 */
int add_to_swap(struct page *page)
    get_swap_page     // 分配 swp_entry_t // todo 实现比想象的要复杂的多，首先进入到 swap_slot.c 但是 swap_slot.c 中间似乎根本不处理什么具体分配，而是靠 swapfile.c 的 get_swap_pages // todo 获取到 entry.val != 0 说明 page 已经被加入到 swap 中间 ?
    add_to_swap_cache // 将 page 和 swp_entry_t 链接起来，形成
    set_page_dirty // todo 和 page-writeback.c 有关，line 240 的注释看不懂
    put_swap_page // Called after dropping swapcache to decrease refcnt to swap entries ，和 get_swap_page 对称的函数，核心是调用 free_swap_slot

// 从 get_swap_page 和 put_swap_page 中间，感觉 swp_entry_t 存在引用计数 ? 应该不可能呀 !
```
4. 利用 swap_cache_info 来给管理员提供信息
```c
static struct {
  unsigned long add_total;
  unsigned long del_total;
  unsigned long find_success;
  unsigned long find_total;
} swap_cache_info;
```


问题:
1. 两种的 readahead 机制 swap_cluster_readahead 和 swap_vma_readahead 的区别 ?
```c
/**
 * swapin_readahead - swap in pages in hope we need them soon
 * @entry: swap entry of this memory
 * @gfp_mask: memory allocation flags
 * @vmf: fault information
 *
 * Returns the struct page for entry and addr, after queueing swapin.
 *
 * It's a main entry function for swap readahead. By the configuration,
 * it will read ahead blocks by cluster-based(ie, physical disk based)
 * or vma-based(ie, virtual address based on faulty address) readahead.
 */
struct page *swapin_readahead(swp_entry_t entry, gfp_t gfp_mask,
        struct vm_fault *vmf)
{
  return swap_use_vma_readahead() ?
      swap_vma_readahead(entry, gfp_mask, vmf) :
      swap_cluster_readahead(entry, gfp_mask, vmf);
}
```
2. 什么时候使用 readahead，什么时候使用 page-io.c:swap_readpage ?<br/> memory.c::do_swap_page 中间说明
3. add_to_swap 和 add_to_swap_cache 的关系是什么 ?<br/> add_to_swap 首先调用 swap_slot.c::get_swap_page 分配 swap slot，然后调用 add_to_swap_cache 将 page 和 swap slot 关联起来。
4. swap cache 的 page 和 page cache 的 page 在 page reclaim 机制中间有没有被区分对待 ? TODO
5. swap cache 不复用 page cache ? <br/>两者只是使用的机制有点类似，通过索引查询到 page frame，但是 swap cache 的 index 是 swp_entry_t，而 page cache 的 index 是文件的偏移量。对于每一个文件，都是存在一个 radix_tree 来提供索引功能，对于 swap，

page-io.c 主要内容:
| Function                    | description                                                                                                                       |
|-----------------------------|-----------------------------------------------------------------------------------------------------------------------------------|
| `swap_writepage`            | 封装 `__swap_writepage`
| `__swap_writepage`          |
| `swap_readpage`             | 如果 swap 建立在文件系统上的，那么调用该文件系统的 `aops->readpage`，如果 swap 直接建立在 blockdev 上的，使用 bdev_read_page 进行 |
| `swap_set_page_dirty`       |
| `get_swap_bio`              |
| `end_swap_bio_write`        |
| `end_swap_bio_read`         |
| `swap_slot_free_notify`     |
| `generic_swapfile_activate` |
| `swap_page_sector`          |
| `count_swpout_vm_event`     |
问题:
1. 请问 page-io.c 实现的内容，在 ext2 是对应的哪里实现的 ?<br/>page-io.c 中间实现的就是 readpage 和 writepage 的功能，其对应的 ext2 部分无非是 ext2 的 readpage 和 writepage。page-io.c 的主要作用正确的将 IO 工作委托给下层的 fs 或者 blkdev.
2. 为什么 swap_readpage 和 swap_writepage 使用不是对称的 ?
    1. swap_aops 到底如何最后调用其中的 writepage 的 ? TODO 既然利用了 address_space ，那么 swap cache 放到 swap cache 中间统一管理。
    2. 为什么 ext2 不是直接使用 readpage ，这这里是直接使用的 ?<br/> 因为 swap 其实可以当做一个文件系统，所以没有必要经过一个通用的 address_space_operations::readpage，对于 swap 的 IO 是没有 file operation 的，而是直接进行在 page 的层次的，所以 swap_state 提供的操作是在 generic_file_buffered_read 后面部分的工作。
> TODO 等等，什么 file operation 的 direct IO 是什么情况 ?


swap_slot.c 主要内容:
```c
static DEFINE_PER_CPU(struct swap_slots_cache, swp_slots);
struct swap_slots_cache {
  bool    lock_initialized;
  struct mutex  alloc_lock; /* protects slots, nr, cur */
  swp_entry_t *slots;
  int   nr;
  int   cur;
  spinlock_t  free_lock;  /* protects slots_ret, n_ret */
  swp_entry_t *slots_ret;
  int   n_ret;
};

// 两个对外提供的接口
int free_swap_slot(swp_entry_t entry);
swp_entry_t get_swap_page(struct page *page)
```
当 get_swap_page 将 cache 耗尽之后，会调用 swapfile::get_swap_pages 来维持生活
也就是 swap_slots.c 其实是 slots cache 机制。

2. 为什么 `page->private` 需要保存 `swp_entry_t`　的内容, 难道不是 page table entry 保存吗 ? (当其需要再次被写回的时候，依靠这个确定位置，和删除在 radix tree 的关系!)
