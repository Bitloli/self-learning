## `vm_area_struct::vm_operations_struct` 结构体的作用

mmap 映射的一个 fd 之后，在该 vma 上操作的行为取决于 fd 的来源:

1. 匿名映射不关联 fd，所以没有  `vm_operations_struct`
```c
static inline bool vma_is_anonymous(struct vm_area_struct *vma)
{
	return !vma->vm_ops;
}
```

2. socket 的 mmap 是没有含义的
```c
static const struct vm_operations_struct tcp_vm_ops = {
};
```

3. 以 hugetlb_vm_ops 为例
```c
/*
 * When a new function is introduced to vm_operations_struct and added
 * to hugetlb_vm_ops, please consider adding the function to shm_vm_ops.
 * This is because under System V memory model, mappings created via
 * shmget/shmat with "huge page" specified are backed by hugetlbfs files,
 * their original vm_ops are overwritten with shm_vm_ops.
 */
const struct vm_operations_struct hugetlb_vm_ops = {
	.fault = hugetlb_vm_op_fault,
	.open = hugetlb_vm_op_open,
	.close = hugetlb_vm_op_close,
	.may_split = hugetlb_vm_op_split,
	.pagesize = hugetlb_vm_op_pagesize,
};
```

## TODO
- [ ] VM_LOCKED|VM_PFNMAP|VM_HUGETLB 这种 flags 的整理

## mmap
- [ ] io uring, mmap 的时候需要传入 MAP_POPULATE 参数，以防止内存被 page fault。
- [ ] https://github.com/edsrzf/mmap-go : 我们应该使用类似的方法来实现一个 C 语言版本，在 mmap 区域放置汇编代码

// TODO
1. 为什么其中的 file_operations::mmap 和 mmap 的关系是什么 ?
2. 找到 pgfault 命中到错误的位置的时候，但是范围外面，并且是如何告知用户的 ? 使用信号机制吗 ?
3. 据说其中包含了各种 vma 操纵函数，整理一下

```c
static unsigned long myfs_mmu_get_unmapped_area(struct file *file,
    unsigned long addr, unsigned long len, unsigned long pgoff,
    unsigned long flags)
{
  return current->mm->get_unmapped_area(file, addr, len, pgoff, flags);
}

const struct file_operations ramfs_file_operations = {
  .get_unmapped_area  = ramfs_mmu_get_unmapped_area, // 不是非常理解啊 !
};
```

在 do_mmap 中间的各种代码都是非常简单的，但是唯独这一行理解不了:
```c
  /* Obtain the address to map to. we verify (or select) it and ensure
   * that it represents a valid section of the address space.
   */
  addr = get_unmapped_area(file, addr, len, pgoff, flags);
```

- [x] 在 dune 的分析的时候，通过 mmap 是返回一个地址的，这个地址应该是 guest physical address，
也就是 HVA，无论是系统发送过去，从内核的角度分析，其不在乎是哪个 guest 发送的,
guest 发送的时候首先会进入到 host 中间，然后调用 syscall.
- [ ] 其实可以在进行 vmcall syscall 的时候，可以首先对于 GVA 到 GVA 之间装换

- [ ] 调查一下 mmap 如何返回用户地址的


- [ ] check flag of `MAP_HUGETLB`
```c
static void * do_mapping(void *base, unsigned long len)
{
  void *mem;

  mem = mmap((void *) base, len,
       PROT_READ | PROT_WRITE,
       MAP_FIXED | MAP_HUGETLB | MAP_PRIVATE |
       MAP_ANONYMOUS, -1, 0);

  if (mem != (void *) base) {
    // try again without huge pages
    mem = mmap((void *) base, len,
         PROT_READ | PROT_WRITE,
         MAP_FIXED | MAP_PRIVATE | MAP_ANONYMOUS,
         -1, 0);
    if (mem != (void *) base)
      return NULL;
  }

  return mem;
}
```

- [ ]

#### brk

- [x] what's `[heap]` in `cat /proc/self/maps`
```plain
5587dad41000-5587dad62000 rw-p 00000000 00:00 0                          [heap]
```
answer: https://stackoverflow.com/questions/17782536/missing-heap-section-in-proc-pid-maps


- [ ] what's difference of brk and mmap ? So what's are the simplifications and extra of brk ?

#### mmap layout
- [ ] `mm_struct::mmap_base`
  - [ ] setup_new_exec()

- [ ] `mm_struct::stack_start`, discuss it ./mm/stack.md

```c
    // --------- huxueshi : just statistics of memory size -------------------
    unsigned long hiwater_rss; /* High-watermark of RSS usage */
    unsigned long hiwater_vm;  /* High-water virtual memory usage */

    unsigned long total_vm;    /* Total pages mapped */
    unsigned long locked_vm;   /* Pages that have PG_mlocked set */
    atomic64_t    pinned_vm;   /* Refcount permanently increased */
    unsigned long data_vm;     /* VM_WRITE & ~VM_SHARED & ~VM_STACK */
    unsigned long exec_vm;     /* VM_EXEC & ~VM_WRITE & ~VM_STACK */
    unsigned long stack_vm;    /* VM_STACK */

    // --------- huxueshi : vm flags for all vma, mainly used for mlock -------------------
    unsigned long def_flags;

    spinlock_t arg_lock; /* protect the below fields */
    unsigned long start_code, end_code, start_data, end_data;
    unsigned long start_brk, brk, start_stack;
    unsigned long arg_start, arg_end, env_start, env_end;
```

- [ ] so why we need these start and end ?


`arch/x86/mm/mmap.c:arch_pick_mmap_layout`
1. register get_unmapped_area `mm->get_unmapped_area = arch_get_unmapped_area;`
2. choose from `mmap_base` and `mmap_legacy_base`

[mmap_base](https://unix.stackexchange.com/questions/407204/program-stack-size) is top of mmap.

All right, heap grows up, mmap grows down, and stack grows down, like [this](https://lwn.net/Articles/91829/).
![](https://static.lwn.net/images/ns/kernel/mmap2.png)

- [ ] why I need `mmap_base` to `get_unmapped_area()`
#### page walk
![](https://static.lwn.net/images/ns/kernel/four-level-pt.png)

// 总结一下 pagewalk.c 中间的内容
// mincore.c 基本是利用 pagewalk.c 实现的

// TODO 其实存在很多位置走过一遍 page walk，只要需要修改 page table 的需要进行 page walk:
1. vmemmap 的填充
2. rmap
3. gup

check it 这几个概念 :
https://stackoverflow.com/questions/8708463/difference-between-kernel-virtual-address-and-kernel-logical-address

**还有非常重要的特点，那就是只要设计到 page walk，至少 2000 行**
#### process vm access
// 不同进程地址空间直接拷贝

## virtual memory
1. 实现地址空间的隔离是虚拟内存的目的，但是，关键位置在于如何实现在隔离的基础上共享和通信。
  1. 实现隔离的方法: page walk
  2. 实现共享 : cow + mmap(找到一下使用 mmap 的)
2. 不同虚拟内存的属性不同。vma

// ---------- 等待处理的事情 ---------------
1. 为什么 mm_struct 中间存在这个，难道这个的实现不是标准操作吗 ?
```c
    unsigned long (*get_unmapped_area) (struct file *filp,
        unsigned long addr, unsigned long len,
        unsigned long pgoff, unsigned long flags);
```
2. vma_ops : anonymous 的不需要 vm_ops，所以 vm_ops 处理都是文件相关的内容，解释一下每个函数到底如何处理 underlying 的文件的。
    1. 找到各种 file vma 的插入 vm_ops 的过程是什么 ?

```c
static inline bool vma_is_anonymous(struct vm_area_struct *vma)
{
  return !vma->vm_ops;
}
```
3. 虚拟地址空间的结构是什么 ? amd64 的架构上，内核空间如此大，内核空间的线性地址的映射是如何完成的 ?

5. 当使用四级的 page walk 的时候，为什么可以实现 48bit 的寻址过程，中间的空洞是如何体现出来的。

6. 分析一下经典的函数 : `__pa` `__va` 和 kmap 以及 kunmap 的关系是什么 ? 似乎回到 highmem 的内容

7. 还是分不清 Kernel Logical Address 和 Kernel Virtual Address 的区别是什么? 这是凭空创建出来混淆人的注意力
// ---------- 等待处理的事情 end ---------------

This hardware feature allows operating systems to map
the kernel into the address space of every process and
to have very efficient transitions from the user process
to the kernel, e.g., for interrupt handling.
1. 为什么每一个进程都需要持有内核地址空间 ?
  - 似乎 : 反正用户进程无法访问内核地址空间
  - **interrupt 的时候不用切换地址空间**，由于切换地址空间而导致的 TLB flush 都是没有必要使用的。
  - fork 会很难实现 : fork 出来的 child 需要从内核态返回，至少在返回到用户层的时候需要使用内核地址空间
  - context switch 的过程 : 进入内核态，各种切换(包括切换地址空间)，离开内核态。如果用户不包含内核态的地址空间，就需要考虑切换地址空间和进入内核空间，先后 ?，同时 ?
  > emmmmm fork 和 context switch 的内容需要重新分析

x86_64 规定了虚拟地址空间的 layout[^5]
1. 4-level 和 5-level 在 layout 的区分只是 start address 和 length 的区别
2. 处于安全问题，这些地址都是加入了随机偏移
3. page_offset_base vmalloc_base vmemmap_base 含义清晰
4. 其他暂时不管
5. *只是 ioremap 的开始位置为什么和 vmalloc_base 使用的位置相同*
6. cpu_entry_area : https://unix.stackexchange.com/questions/476768/what-is-cpu-entry-area

#### fork
1. fork 的那些 flags 如何控制
2. vma 指向的内存如何控制

到底内存中间如何控制其中的

## mm_struct
- [ ] 并不是所有的进程存在 mm_struct 的, 应该是 kernel thread ?
```c
  for_each_process (g) {
    if(g->mm)
      pr_debug("%s ---> %lx %lx\n", g->comm, g->mm->mmap_base, g->mm->start_stack);
    else
      pr_debug("%s doesn't have mm\n", g->comm);
  }
```
