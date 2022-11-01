# mmu notifier

配合 mmu notifier 理解:
```c
static const struct mmu_notifier_ops kvm_mmu_notifier_ops = {
	.invalidate_range	= kvm_mmu_notifier_invalidate_range,
	.invalidate_range_start	= kvm_mmu_notifier_invalidate_range_start,
	.invalidate_range_end	= kvm_mmu_notifier_invalidate_range_end,
	.clear_flush_young	= kvm_mmu_notifier_clear_flush_young,
	.clear_young		= kvm_mmu_notifier_clear_young,
	.test_young		= kvm_mmu_notifier_test_young,
	.change_pte		= kvm_mmu_notifier_change_pte,
	.release		= kvm_mmu_notifier_release,
};
```

- dune 中观察到，需要让 ept 的二级映射指向新创建出来的 page 上:
```txt
[25556.799013] Hardware name: Timi TM1701/TM1701, BIOS XMAKB5R0P0603 02/02/2018
[25556.799013] Call Trace:
[25556.799019]  dump_stack+0x6d/0x9a
[25556.799037]  ept_mmu_notifier_invalidate_range_start.cold+0x5/0xfe [dune]
[25556.799039]  __mmu_notifier_invalidate_range_start+0x5e/0xa0
[25556.799041]  wp_page_copy+0x6be/0x790
[25556.799042]  ? vsnprintf+0x39e/0x4e0
[25556.799043]  do_wp_page+0x94/0x6a0
[25556.799045]  ? sched_clock+0x9/0x10
[25556.799046]  __handle_mm_fault+0x771/0x7a0
[25556.799047]  handle_mm_fault+0xca/0x200
[25556.799048]  __get_user_pages+0x251/0x7d0
[25556.799049]  get_user_pages_unlocked+0x145/0x1f0
[25556.799050]  get_user_pages_fast+0x180/0x1a0
[25556.799051]  ? ept_lookup_gpa.isra.0+0xb2/0x1a0 [dune]
[25556.799053]  vmx_do_ept_fault+0xe3/0x450 [dune]
```

- https://www.linux-kvm.org/images/3/33/KvmForum2008%24kdf2008_15.pdf

#### mmu notifier
[^24] is worth reading !

- some notifier triggers:
  - try_to_unmap_one
  - ptep_clear_flush_notify

- [ ] how kvm work with mmu notifier ?

- [ ] mmu_notifier.rst

- [x] so why kvm need mmu notifier ?
[Integrating KVM with the Linux Memory Management](https://www.linux-kvm.org/images/3/33/KvmForum2008%24kdf2008_15.pdf)

Guest ram is mostly allocated by user process with `memalign()` and
kvm get physical memory with `get_user_pages`.

> The 'MMU Notifier' functionality can be also used
by other subsystems like GRU and XPMEM to
export the user virtual address space of
computational tasks to other nodes

> This will also allow KVM guest physical ram itself
to be exported to other nodes through GRU and
XPMEM or any other RDMA engine

- TODO really interesting RDMA and XPMEM

> - The KVM page fault is the one that instantiates the shadow pagetables
> - Shadow pagetables works similarly to a TLB
> - They translate a virtual (or physical with EPT/NPT) guest address to a physical host address
> - They can be discarded at any time and they will be recreated later as new KVM page fault triggers, just like the primary CPU TLB can be flushed at any time and the CPU will refill it from the ptes
> - The sptes are recreated by the KVM page fault by calling get_user_pages (i.e. looking at the Linux ptes) to translate a guest physical address (the malloced region) to a host physical address

------------  function calling chain -------------------------- begin ---

- [ ] *unless we can understand hugetlb and thp, we can't understand mmu_notifier*

```plain
mmu_notifier_invalidate_range_start
  --> __mmu_notifier_invalidate_range_start
    --> mn_itree_invalidate
    --> mn_hlist_invalidate_range_start : call list one by one
```

```plain
mmu_notifier_invalidate_range_end
  --> __mmu_notifier_invalidate_range_end
    --> mn_itree_inv_end
    --> mn_hlist_invalidate_end
```

```plain
__mmu_notifier_register :
1. if mm->notifier_subscriptions is NULL, alloc and init one for it
2. is parameter subscription is not NULL, add it to mm->notifier_subscriptions list, mm->notifier_subscriptions->has_itree = true; otherwise
  mm_drop_all_locks(mm);
```
------------  function calling chain -------------------------- begin ---



------------ critical struct -------------------------- begin ---
```c
/*
 * The notifier chains are protected by mmap_lock and/or the reverse map
 * semaphores. Notifier chains are only changed when all reverse maps and
 * the mmap_lock locks are taken.
 *
 * Therefore notifier chains can only be traversed when either
 *
 * 1. mmap_lock is held.
 * 2. One of the reverse map locks is held (i_mmap_rwsem or anon_vma->rwsem).
 * 3. No other concurrent thread can access the list (release)
 */
struct mmu_notifier {
  struct hlist_node hlist;
  const struct mmu_notifier_ops *ops;
  struct mm_struct *mm;
  struct rcu_head rcu;
  unsigned int users;
};

/**
 * struct mmu_interval_notifier_ops
 * @invalidate: Upon return the caller must stop using any SPTEs within this
 *              range. This function can sleep. Return false only if sleeping
 *              was required but mmu_notifier_range_blockable(range) is false.
 */
struct mmu_interval_notifier_ops {
  bool (*invalidate)(struct mmu_interval_notifier *interval_sub,
         const struct mmu_notifier_range *range,
         unsigned long cur_seq);
};

struct mmu_interval_notifier {
  struct interval_tree_node interval_tree;
  const struct mmu_interval_notifier_ops *ops;
  struct mm_struct *mm;
  struct hlist_node deferred_item;
  unsigned long invalidate_seq;
};


struct mmu_notifier_range {
  struct vm_area_struct *vma;
  struct mm_struct *mm;
  unsigned long start;
  unsigned long end;
  unsigned flags;
  enum mmu_notifier_event event;
  void *migrate_pgmap_owner;
};

/*
 * The mmu_notifier_subscriptions structure is allocated and installed in
 * mm->notifier_subscriptions inside the mm_take_all_locks() protected
 * critical section and it's released only when mm_count reaches zero
 * in mmdrop().
 */
struct mmu_notifier_subscriptions {
  /* all mmu notifiers registered in this mm are queued in this list */
  struct hlist_head list;
  bool has_itree;
  /* to serialize the list modifications and hlist_unhashed */
  spinlock_t lock;
  unsigned long invalidate_seq;
  unsigned long active_invalidate_ranges;
  struct rb_root_cached itree;
  wait_queue_head_t wq;
  struct hlist_head deferred_list;
};
```

- `mmu_notifier` and `mmu_interval_notifier` are chained into `mmu_notifier_subscriptions`
- `mmu_notifier_range` is interface for memory management part
------------ critical struct -------------------------- end ---


[^24]: [lwn : Memory management notifiers](https://lwn.net/Articles/266320/)
