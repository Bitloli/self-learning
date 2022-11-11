# linux Memory Management

布局: introduction 写一个综述，然后 reference 各个 section 和 subsection 中间的内容。

// TODO 经过讲解 PPT 的内容之后，可以整体框架重做为 物理内存，虚拟内存，page cache 和 swap cache 四个部分来分析

## introduction
大致分析一下和内存相关的 syscall
https://thevivekpandey.github.io/posts/2017-09-25-linux-system-calls.html
1. mmap munmap mremap mprotec brk
2. shmget shmat shmctl
3. membarrier
4. madvise msync mlock munlock mincore
5. mbind set_mempoliyc get_mempolicy


1. 一个干净的地址空间 : virtual memory。
    1. 历史上存在使用段式，现代操作系统使用页式虚实映射，x86 对于段式保持兼容，为了节省物理内存，所以虚实翻译是一个多级的。
    2. 访存需要进行一个 page walk ，原先一次访存，现在需要进行多次，所以存在 TLB 加快速度。为了减少 TLB miss rate，使用 superpage 是一种补救方法。
2. 加载磁盘的内容到内存的时机，linux 使用 page fault 机制，当访问到该页面在加载内存(demand paging)。
2. 哪一个物理页面是空闲，哪一个物理页面正在被使用: buddy allocator
    1. 伙伴系统的分配粒度是 : 2^n * page size 的，但是内核需要更小粒度的分配器，linux 使用 slub slob slab 分配器
    2. 物理内存碎片化会导致即使内存充足，但是 buddy allocator 依据无法分配足够的内存，因此需要 [compaction](#compaction) 机制和 [page reclaim](#page-reclaim) 机制
    3. 当缺乏连续的物理页面，可以通过修改内核 page table 的方法获取虚拟的连续地址，这是通过 vmalloc 实现的。
2. 不同的程序片段的属性不同，代码，数据等不同，linux 使用 vma 来描述。
3. 程序需要访问文件，内存比磁盘快很多，所以需要使用内存作为磁盘的缓存: [page cache](#page-cache)
    1. dirty 缓存什么时候写回磁盘，到底让谁写回到内存。
    4. 如果不加控制，缓存将会占据大量的物理内存，所以需要 page reclaim 机制释放一些内存出来。
4. 当内存不够的时候，利用磁盘进行缓存。
    1. 物理页面可能被多个进程共享，当物理页面被写回磁盘的时候，linux 使用反向映射的机制来告知所有的内存。
    2. 不仅仅可以使用 disk 进行缓存，也可以使用一些异构硬件或者压缩内存的方法
5. 不同进程之间需要进行信息共享，利用内存进行共享是一个高效的方法，linux 支持 Posix 和 sysv 的 shmem。
    1. 父子进程之间由于 fork 也会进行内存共享，使用 cow 机制实现更加高效的拷贝(没有拷贝就是最高效的拷贝)
6. 虚拟机中如何实现内存虚拟化
7. 内存是关键的资源，类似于 docker 之类的容器技术需要利用内核提供的 cgroup 技术来限制一个容器内内存使用。

硬件对于内存的管理提出的挑战：
1. 由于 IO 映射以及 NUMA，内存不是连续的。linux 提供了多个内存模型来解决由于空洞导致的无效 struct page
2. NUMA 系统中间，访问非本地的内存延迟比访问本地的延迟要高，如何让 CPU 尽可能访问本地的内存。
    1. 内存分配器应该确立分配的优先级。
    2. 将经常访问的内存迁移过来。
3. 现在操作系统中间，每一个 core 都存在自己的 local cache，为了让 CPU 尽可能访问自己 local cache 的内容，linux 使用 percpu 机制。
4. 内存是操作系统的运行基础，包括内存的分配，为了解决这个鸡生蛋的问题，linux 使用架构相关的代码探测内存，并且使用 memblock 来实现早期的内存管理。
5. 现代处理器处于性能的考虑，对于访存提出 memory consistency 和 cache coherence 协议，其中 memory consistency 让内核的代码需要特殊注意来避免错误。

克服内核开发人员的疏忽产生的错误:
1. kmemleak @todo
2. kasan @todo
3. vmstat 获取必要的统计数据 https://www.linuxjournal.com/article/8178

克服恶意攻击:
1. stack 随机 ?
2. cow 机制的漏洞是什么 ?
3. 内核的虚拟地址空间 和 用户的虚拟地址空间 互相分离。copy_to_user 和 copy_from_user 如何实现 ?
    1. 内核的物理地址是否也是局限于特定的范围中 ? 否则似乎难以建立 linear 映射。
    2. 猜测，对于 amd64, 内核虚拟地址映射了所有的物理地址，这导致其可以访问任何物理地址，而不会出现 page fault 的情况。
        1. 但是用户的看到的地址空间不仅仅包括内核(线性映射)，也包含自己
        2. 用户进程 syscall 之后，需要切换使用内核的 mm_struct 吗 ?
    3. 对于 x86 32bit 利用 highmem 到底实现了什么内容 ?

那么这些东西具有怎样的联系:(将上面的内容整理成为一个表格)
1. page fault 需要的页面可能是是被 swap 出去的
2. shmem 的内存可能被 swap
3. superpage 需要被纳入到 dirty 和 page claim 中间
4. 进行 page reclaim 可以辅助完成 compaction
5. page reclaim 和 swap 都需要使用反向映射。

现在从一个物理页面的角度将上述的内容串联起来。

> 确立那些是基本要素，然后之间的交互是什么:

| virtual memory | swap | allocator | numa | multicore | hugetlb | page cache | page fault | cgroup | shmem | page reclaim | migrate |
|----------------|------|-----------|------|-----------|---------|------------|------------|--------|-------|--------------|---------|
| virtual memory |
| swap           |
| allocator      |
| numa           |

总结内容主要来自于 lwn [^3], (几本书)，wowotech ，几个试验

## page fault
- [ ] vmf_insert_pfn : 给驱动使用的直接，在 vma 连接 va 和 pa

[TO BE CONTINUE](https://www.cnblogs.com/LoyenWang/p/12116570.html), this is a awesome post.

handle_pte_fault 的调用路径图:
1. do_anonymous_page : anon page
2. do_fault : 和 file 相关的
5. do_numa_page
3. do_swap_page
    4. do_wp_page : 如果是 cow 一个在 disk 的 page ，其实不能理解，如果 cow ，那么为什么不是直接复制 swp_entry_t ，为什么还会有别的蛇皮东西 !
    2. @todo 由于 cow 机制的存在, 岂不是需要将所有的 pte 全部标记一遍，找到证据!
4. do_wp_page


- [ ] `enum vm_fault_reason` : check it's entry one by one

- [ ] I guess the only user of `struct vm_operations_struct` is page fault

```c
static const struct vm_operations_struct xfs_file_vm_ops = {
  .fault    = xfs_filemap_fault,
  .huge_fault = xfs_filemap_huge_fault,
  .map_pages  = xfs_filemap_map_pages,
  .page_mkwrite = xfs_filemap_page_mkwrite,
  .pfn_mkwrite  = xfs_filemap_pfn_mkwrite,
};
```

#### page table
- [ ] https://stackoverflow.com/questions/32943129/how-does-arm-linux-emulate-the-dirty-accessed-and-file-bits-of-a-pte


#### paging
> 准备知识
- [todo 首先深入理解 x86 paging 机制](https://cirosantilli.com/x86-paging)
- [todo](https://0xax.gitbooks.io/linux-insides/content/Theory/linux-theory-1.html)
- [todo](https://stackoverflow.com/questions/12557267/linux-kernel-memory-management-paging-levels)

A. 到底存在多少级 ?
arch/x86/include/asm/pgtable_types.h
一共 5 级，每一级的作用都是相同的
1. 如果处理模拟的各种数量的 level : CONFIG_PGTABLE_LEVELS
2. 似乎 获取 address 的，似乎各种 flag 占用的 bit 数量太多了，应该问题不大，反正这些 table 的高位都是在内核的虚拟地址空间，所有都是


B. 通过分析 `__handle_mm_fault` 说明其中的机制：
由于 page walk 需要硬件在 TLB 和 tlb miss 的情况下提供额外的支持。

// 有待处理的
1. vm_fault 所有成员解释 todo
3. devmap : pud_devmap 的作用是什么 ?


```c
/*
 * By the time we get here, we already hold the mm semaphore
 *
 * The mmap_sem may have been released depending on flags and our
 * return value.  See filemap_fault() and __lock_page_or_retry().
 */
static vm_fault_t __handle_mm_fault(struct vm_area_struct *vma,
    unsigned long address, unsigned int flags)
{
  struct vm_fault vmf = {
    .vma = vma,
    .address = address & PAGE_MASK,
    .flags = flags,
    .pgoff = linear_page_index(vma, address),
    .gfp_mask = __get_fault_gfp_mask(vma),
  };
  unsigned int dirty = flags & FAULT_FLAG_WRITE;
  struct mm_struct *mm = vma->vm_mm;
  pgd_t *pgd;
  p4d_t *p4d;
  vm_fault_t ret;

  pgd = pgd_offset(mm, address); // 访问 mm_struct::pgd 以及 address 的偏移，但是可以从此处获取到
  p4d = p4d_alloc(mm, pgd, address); // 如果 pgd 指向 p4d entry 是无效的，首先分配。如果有效，只是简单的计算地址。
  if (!p4d)
    return VM_FAULT_OOM;

  vmf.pud = pud_alloc(mm, p4d, address); // vmf.pud 指向 pmd。vmf.pud 对应的映射范围 : pmd 的 entry *  page table 的 entry * PAGE_SIZE
  if (!vmf.pud)
    return VM_FAULT_OOM;
retry_pud:
  if (pud_none(*vmf.pud) && __transparent_hugepage_enabled(vma)) {
    ret = create_huge_pud(&vmf);
    if (!(ret & VM_FAULT_FALLBACK))
      return ret;
  } else {
    pud_t orig_pud = *vmf.pud;

    barrier(); // TODO 现在不清楚为什么需要添加 barrier
    if (pud_trans_huge(orig_pud) || pud_devmap(orig_pud)) {

      /* NUMA case for anonymous PUDs would go here */

      if (dirty && !pud_write(orig_pud)) {
        ret = wp_huge_pud(&vmf, orig_pud); //
        if (!(ret & VM_FAULT_FALLBACK))
          return ret;
      } else {
        huge_pud_set_accessed(&vmf, orig_pud);
        return 0;
      }
    }
  }

  vmf.pmd = pmd_alloc(mm, vmf.pud, address); // 如果处理的不是 vmf.pud 指向的不是 pgfault
  if (!vmf.pmd)
    return VM_FAULT_OOM;

  /* Huge pud page fault raced with pmd_alloc? */
  if (pud_trans_unstable(vmf.pud)) // 当线程同时在进行 page fault
    goto retry_pud;

  if (pmd_none(*vmf.pmd) && __transparent_hugepage_enabled(vma)) {
    ret = create_huge_pmd(&vmf);
    if (!(ret & VM_FAULT_FALLBACK))
      return ret;
  } else {
    pmd_t orig_pmd = *vmf.pmd;

    barrier();
    if (unlikely(is_swap_pmd(orig_pmd))) { // TODO swap 的关系是什么
      VM_BUG_ON(thp_migration_supported() &&
            !is_pmd_migration_entry(orig_pmd));
      if (is_pmd_migration_entry(orig_pmd))
        pmd_migration_entry_wait(mm, vmf.pmd);
      return 0;
    }
    if (pmd_trans_huge(orig_pmd) || pmd_devmap(orig_pmd)) {
      if (pmd_protnone(orig_pmd) && vma_is_accessible(vma))
        return do_huge_pmd_numa_page(&vmf, orig_pmd); // TODO 处理内容

      if (dirty && !pmd_write(orig_pmd)) {
        ret = wp_huge_pmd(&vmf, orig_pmd);
        if (!(ret & VM_FAULT_FALLBACK))
          return ret;
      } else {
        huge_pmd_set_accessed(&vmf, orig_pmd);
        return 0;
      }
    }
  }

  return handle_pte_fault(&vmf);
}
```

#### copy_from_user
从这里看，copy_from_user 和 copy_to_user 并不是检查 vma 的方法，而是和架构实现息息相关, TODO
https://stackoverflow.com/questions/8265657/how-does-copy-from-user-from-the-linux-kernel-work-internally


```c
ssize_t cdev_fops_write(struct file *flip, const char __user *ubuf,
                        size_t count, loff_t *f_pos)
{
    unsigned int *kbuf;
    copy_from_user(kbuf, ubuf, count);
    printk(KERN_INFO "Data: %d",*kbuf);
}
```
ubuf 用户提供的指针，在执行该函数的时候，当前的进程地址空间就是该用户的，所以使用 ubuf 并不需要什么奇怪的装换。


1. copy_from_user 和 copy_to_user


```c
size_t iov_iter_copy_from_user_atomic(struct page *page,
    struct iov_iter *i, unsigned long offset, size_t bytes)
{
  char *kaddr = kmap_atomic(page), *p = kaddr + offset;
  if (unlikely(!page_copy_sane(page, offset, bytes))) {
    kunmap_atomic(kaddr);
    return 0;
  }
  if (unlikely(iov_iter_is_pipe(i) || iov_iter_is_discard(i))) {
    kunmap_atomic(kaddr);
    WARN_ON(1);
    return 0;
  }
  iterate_all_kinds(i, bytes, v,
    copyin((p += v.iov_len) - v.iov_len, v.iov_base, v.iov_len),
    memcpy_from_page((p += v.bv_len) - v.bv_len, v.bv_page,
         v.bv_offset, v.bv_len),
    memcpy((p += v.iov_len) - v.iov_len, v.iov_base, v.iov_len)
  )
  kunmap_atomic(kaddr);
  return bytes;
}
EXPORT_SYMBOL(iov_iter_copy_from_user_atomic);
```

## pmem
DAX 设置 : 到时候在分析吧!
1. https://www.intel.co.uk/content/www/uk/en/it-management/cloud-analytic-hub/pmem-next-generation-storage.html
2. https://nvdimm.wiki.kernel.org/
3. https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/storage_administration_guide/ch-persistent-memory-nvdimms

目前观察到的 generic_file_read_iter 和 file_operations::mmap 的内容对于 DAX 区分对待的，但是内容远远不该如此，不仅仅可以越过 page cache 机制，而且 page reclaim 全部可以跳过。

## mmio
https://gist.github.com/Measter/2108508ba25ebe3978a6c10a1e01b9ad

- [] mmio 的建立和 pcie 的关系
- [] mmio 和 kvm
## vmstate
// 搞清楚如何使用这个代码吧 !

`vmstat.h/vmstat.c`
```c
static inline void count_vm_event(enum vm_event_item item)
{
  this_cpu_inc(vm_event_states.event[item]);
}
// @todo 以此为机会找到内核实现暴露接口的位置
```

```c
    __mod_zone_page_state(page_zone(page), NR_MLOCK,
            hpage_nr_pages(page));
    count_vm_event(UNEVICTABLE_PGMLOCKED);
    // 两个统计的机制，但是并不清楚各自统计的内容是什么包含什么区别
```

## lock
- [ ] mm_take_all_locks

## ioremap
1. maps device physical address(device memory or device registers) to kernel virtual address [^25]
2. Like user space, the kernel accesses memory through page tables; as a result, when kernel code needs to access memory-mapped I/O devices, it must first set up an appropriate kernel page-table mapping. [^26]
  - [ ] memremap 是 ioremap 的更好的接口.

因为内核也是运行在虚拟地址空间上的，而访问设备是需要物理地址，为了将访问设备的物理地址映射到虚拟地址空间中，所以需要 ioremap，当然 pci 访问带来的各种 cache coherency 问题也是需要尽量考虑的:
```txt
#0  ioremap (phys_addr=1107312640, size=56) at arch/loongarch/mm/ioremap.c:95
#1  0x90000000008555c0 in pci_iomap_range (dev=<optimized out>, bar=<optimized out>, offset=<optimized out>, maxlen=<optimized out>) at lib/pci_iomap.c:46
#2  0x9000000000962150 in map_capability (dev=0x900000027d75b000, off=<optimized out>, minlen=56, align=4, start=0, size=56, len=0x0) at drivers/virtio/virtio_pci_modern.c:134
#3  0x9000000000962950 in virtio_pci_modern_probe (vp_dev=0x900000027da3e800) at drivers/virtio/virtio_pci_modern.c:652
#4  0x900000000096311c in virtio_pci_probe (pci_dev=0x900000027d75b000, id=<optimized out>) at drivers/virtio/virtio_pci_common.c:546
#5  0x90000000008c28c0 in local_pci_probe (_ddi=0x900000027cd33c58) at drivers/pci/pci-driver.c:306
#6  0x9000000000235030 in work_for_cpu_fn (work=0x900000027cd33c08) at kernel/workqueue.c:4908
#7  0x9000000000238ce0 in process_one_work (worker=0x900000027c08fc00, work=0x900000027cd33c08) at kernel/workqueue.c:2152
#8  0x9000000000239220 in process_scheduled_works (worker=<optimized out>) at kernel/workqueue.c:2211
```
## mremap

## debug
> 从内核的选项来看，对于 debug 一无所知啊 !
- Extend memmap on extra space for more information on page
- Debug page memory allocations
- Track page owner
- Poison pages after freeing
- Enable tracepoint to track down page reference manipulation
- Testcase for the marking rodata read-only
- Export kernel pagetable layout to userspace via debugfs
- Debug object operations
- SLUB debugging on by default
- Enable SLUB performance statistics
- Kernel memory leak detector
- Stack utilization instrumentation
- Detect stack corruption on calls to schedule()
- Debug VM
- Debug VM translations
- Debug access to per_cpu maps
- KASAN: runtime memory debugger

#### page owner

page owner is for the tracking about who allocated each page.

#### KASAN
Finding places where the kernel accesses memory that it shouldn't is the goal for the kernel address sanitizer (KASan).

#### kmemleak
Kmemleak provides a way of detecting possible kernel memory leaks in a way similar to a tracing garbage collector, with the difference that the orphan objects are not freed but only reported via /sys/kernel/debug/kmemleak. [^18]


## dmapool
https://lwn.net/Articles/69402/

Some very obscure driver bugs have been traced down to cache coherency problems with structure fields adjacent to small DMA areas. [^17]
> DMA 为什么会导致附近的内存的 cache coherency 的问题 ?

- [ ] dma_pool_create() - Creates a pool of consistent memory blocks, for dma.

- [ ] https://www.kernel.org/doc/html/latest/driver-api/dmaengine/index.html#dmaengine-documentation
- [ ] https://www.kernel.org/doc/html/latest/core-api/index.html#memory-management
- [ ] https://www.kernel.org/doc/Documentation/DMA-API-HOWTO.txt

## mempool
使用 mempool 的目的:
The purpose of mempools is to help out in situations where a memory allocation must succeed, but sleeping is not an option. To that end, mempools pre-allocate a pool of memory and reserve it until it is needed. [^16]

## hmm
Provide infrastructure and helpers to integrate non-conventional memory (device memory like GPU on board memory) into regular kernel path, with the cornerstone of this being specialized struct page for such memory.
HMM also provides optional helpers for SVM (Share Virtual Memory) [^19]

## zsmalloc
slub 分配器处理 size > page_size / 2 会浪费非常多的内容，zsmalloc 就是为了解决这个问题 [^20]

## z3fold
z3fold is a special purpose allocator for storing compressed pages. [^23]

## zud
和 z3fold 类似的东西

## msync
存在系统调用 msync，实现应该很简单吧!

## mpage
fs/mpage.c : 为毛是需要使用这个机制 ? 猜测其中的机制是为了实现

```c
static int ext2_readpage(struct file *file, struct page *page)
{
  return mpage_readpage(page, ext2_get_block);
}

static int
ext2_readpages(struct file *file, struct address_space *mapping,
    struct list_head *pages, unsigned nr_pages)
{
  return mpage_readpages(mapping, pages, nr_pages, ext2_get_block);
}

/*
 * This is the worker routine which does all the work of mapping the disk
 * blocks and constructs largest possible bios, submits them for IO if the
 * blocks are not contiguous on the disk.
 *
 * We pass a buffer_head back and forth and use its buffer_mapped() flag to
 * represent the validity of its disk mapping and to decide when to do the next
 * get_block() call.
 */
static struct bio *do_mpage_readpage(struct mpage_readpage_args *args)
```
> 无论是 ext2_readpage 还是 ext2_readpages 最后都是走到 do_mpage_readpage

## memblock


## profiler
用户层的:
1. https://github.com/KDE/heaptrack
2. https://github.com/koute/memory-profiler

## mprotect
[changing memory protection](https://perception-point.io/changing-memory-protection-in-an-arbitrary-process/)

> - The `vm_area_struct` contains the field `vm_flags` which represents the protection flags of the memory region in an architecture-independent manner, and `vm_page_prot` which represents it in an architecture-dependent manner.

> After some reading and digging into the kernel code, we detected the most essential work needed to really change the protection of a memory region:
> - Change the field `vm_flags` to the desired protection.
> - Call the function `vma_set_page_prot` to update the field vm_page_prot according to the vm_flags field.
> - Call the function `change_protection` to actually update the protection bits in the page table.

check the code in `mprotect.c:mprotect_fixup`, above claim can be verified

- except what three steps meantions above, mprotect also splitting and joining memory regions by their protection flags
## vmalloc
[TO BE CONTINUE](https://www.cnblogs.com/LoyenWang/p/11965787.html)

## mincore

## pageblock
https://richardweiyang-2.gitbook.io/kernel-exploring/00-memory_a_bottom_up_view/13-physical-layer-partition

## user address space
/home/maritns3/core/vn/hack/lab/proc-self-maps/main.c
```plain
00400000-00401000 r--p 00000000 103:02 13252000                          /home/maritns3/core/vn/hack/lab/proc-self-maps/main.out
00401000-00402000 r-xp 00001000 103:02 13252000                          /home/maritns3/core/vn/hack/lab/proc-self-maps/main.out
00402000-00403000 r--p 00002000 103:02 13252000                          /home/maritns3/core/vn/hack/lab/proc-self-maps/main.out
00403000-00404000 r--p 00002000 103:02 13252000                          /home/maritns3/core/vn/hack/lab/proc-self-maps/main.out
00404000-00405000 rw-p 00003000 103:02 13252000                          /home/maritns3/core/vn/hack/lab/proc-self-maps/main.out
007fa000-0081b000 rw-p 00000000 00:00 0                                  [heap]
7fd3e0f16000-7fd3e0f19000 rw-p 00000000 00:00 0
7fd3e0f19000-7fd3e0f3e000 r--p 00000000 103:02 4982896                   /usr/lib/x86_64-linux-gnu/libc-2.31.so
7fd3e0f3e000-7fd3e10b6000 r-xp 00025000 103:02 4982896                   /usr/lib/x86_64-linux-gnu/libc-2.31.so
7fd3e10b6000-7fd3e1100000 r--p 0019d000 103:02 4982896                   /usr/lib/x86_64-linux-gnu/libc-2.31.so
7fd3e1100000-7fd3e1101000 ---p 001e7000 103:02 4982896                   /usr/lib/x86_64-linux-gnu/libc-2.31.so
7fd3e1101000-7fd3e1104000 r--p 001e7000 103:02 4982896                   /usr/lib/x86_64-linux-gnu/libc-2.31.so
7fd3e1104000-7fd3e1107000 rw-p 001ea000 103:02 4982896                   /usr/lib/x86_64-linux-gnu/libc-2.31.so
7fd3e1107000-7fd3e110b000 rw-p 00000000 00:00 0
7fd3e110b000-7fd3e111a000 r--p 00000000 103:02 4982898                   /usr/lib/x86_64-linux-gnu/libm-2.31.so
7fd3e111a000-7fd3e11c1000 r-xp 0000f000 103:02 4982898                   /usr/lib/x86_64-linux-gnu/libm-2.31.so
7fd3e11c1000-7fd3e1258000 r--p 000b6000 103:02 4982898                   /usr/lib/x86_64-linux-gnu/libm-2.31.so
7fd3e1258000-7fd3e1259000 r--p 0014c000 103:02 4982898                   /usr/lib/x86_64-linux-gnu/libm-2.31.so
7fd3e1259000-7fd3e125a000 rw-p 0014d000 103:02 4982898                   /usr/lib/x86_64-linux-gnu/libm-2.31.so
7fd3e125a000-7fd3e125c000 rw-p 00000000 00:00 0
7fd3e1273000-7fd3e1274000 r--p 00000000 103:02 4982891                   /usr/lib/x86_64-linux-gnu/ld-2.31.so
7fd3e1274000-7fd3e1297000 r-xp 00001000 103:02 4982891                   /usr/lib/x86_64-linux-gnu/ld-2.31.so
7fd3e1297000-7fd3e129f000 r--p 00024000 103:02 4982891                   /usr/lib/x86_64-linux-gnu/ld-2.31.so
7fd3e12a0000-7fd3e12a1000 r--p 0002c000 103:02 4982891                   /usr/lib/x86_64-linux-gnu/ld-2.31.so
7fd3e12a1000-7fd3e12a2000 rw-p 0002d000 103:02 4982891                   /usr/lib/x86_64-linux-gnu/ld-2.31.so
7fd3e12a2000-7fd3e12a3000 rw-p 00000000 00:00 0
7ffcb622f000-7ffcb6250000 rw-p 00000000 00:00 0                          [stack]
7ffcb6374000-7ffcb6377000 r--p 00000000 00:00 0                          [vvar]
7ffcb6377000-7ffcb6378000 r-xp 00000000 00:00 0                          [vdso]
ffffffffff600000-ffffffffff601000 --xp 00000000 00:00 0                  [vsyscall]
```

- [ ] why there are more section for `main.out` than expected ? There are five entry whose path is `proc-self-maps/main.out`.
  - [ ] check the main.out with section header
  - [ ] why two entry has same offset ? third and forth

- [x] why text segment start at 0x40000 ?
  - [ ] read this : https://stackoverflow.com/questions/39689516/why-is-address-0x400000-chosen-as-a-start-of-text-segment-in-x86-64-abi

- [ ] why some area with no names ?

- [x] check inode
  - [ ] https://unix.stackexchange.com/questions/35292/quickly-find-which-files-belongs-to-a-specific-inode-number
    - In fact, we can find file name with inode by checking file one by one, but **debufs** impressed my

## kaslr
- [ ] https://unix.stackexchange.com/questions/469016/do-the-virtual-address-spaces-of-all-the-processes-have-the-same-content-in-thei
  - [ ] https://en.wikipedia.org/wiki/Kernel_page-table_isolation
  - [ ] https://lwn.net/Articles/738975/

- [ ] https://bneuburg.github.io/
  - [ ] he has writen three post about it

- [ ] https://lwn.net/Articles/569635/


- [ ] Sometimes /proc/$pid/maps show text address start at 0x400000, sometimes 0x055555555xxx,
maybe because of user space address randomization
    - [  ] https://www.theurbanpenguin.com/aslr-address-space-layout-randomization/

## CXL
- CXL 2.0 的基本概念: https://www.zhihu.com/question/531720207/answer/2521601976
- 显存为什么不能当内存使？内存、Cache 和 Cache 一致性: https://zhuanlan.zhihu.com/p/63494668

[^1]: [lwn : Huge pages part 1 (Introduction)](https://lwn.net/Articles/374424/)
[^2]: [lwn : An end to high memory?](https://lwn.net/Articles/813201/)
[^3]: [lwn#memory management](https://lwn.net/Kernel/Index/#Memory_management)
[^5]: [Complete virtual memory map of x86_64](https://www.kernel.org/doc/html/latest/x86/x86_64/mm.html)
[^8]: [kernel doc : pin_user_pages() and related calls](https://www.kernel.org/doc/html/latest/core-api/pin_user_pages.html)
[^9]: [lwn : Explicit pinning of user-space pages](https://lwn.net/Articles/807108/)
[^13]: [lwn : Smarter shrinkers](https://lwn.net/Articles/550463/)
[^14]: [kernel doc : page owner: Tracking about who allocated each page](https://www.kernel.org/doc/html/latest/vm/page_owner.html)
[^16]: [kernel doc : Driver porting: low-level memory allocation](https://lwn.net/Articles/22909/)
[^17]: [stackoverflow : Why do we need DMA pool ?](https://stackoverflow.com/questions/60574054/why-do-we-need-dma-pool)
[^18]: [kernel doc : Kernel Memory Leak Detector](https://www.kernel.org/doc/html/latest/dev-tools/kmemleak.html)
[^19]: [kernel doc : Heterogeneous Memory Management (HMM)](https://www.kernel.org/doc/html/latest/vm/hmm.html)
[^20]: [lwn : The zsmalloc allocator](https://lwn.net/Articles/477067/)
[^21]: [lwn : A reworked contiguous memory allocator](https://lwn.net/Articles/447405/)
[^22]: [lwn : A deep dive into dma](https://lwn.net/Articles/486301/)
[^23]: [kernel doc : z3fold](https://www.kernel.org/doc/html/latest/vm/z3fold.html)
[^25]: [kernelnewbies : ioremap vs mmap](https://lists.kernelnewbies.org/pipermail/kernelnewbies/2016-September/016814.html)
[^26]: [lwn: ioremap and memremap](https://lwn.net/Articles/653585/)
[^27]: https://lwn.net/Articles/619738/
[^29]: https://my.oschina.net/u/3857782/blog/1854548
