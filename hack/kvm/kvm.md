# KVM

## 使用 `kvm_stat` 可以观测最核心的函数

```txt
Event                                         Total %Total CurAvg/s
kvm_entry                                    337793   15.4    26107
kvm_exit                                     337787   15.4    26107
kvm_ack_irq                                  457205   20.9    25548
kvm_emulate_insn                             192824    8.8    16726
kvm_fast_mmio                                192514    8.8    16709
kvm_apic_accept_irq                          168566    7.7    15209
kvm_apicv_accept_irq                         168559    7.7    15209
kvm_msi_set_irq                              151693    6.9    13865
kvm_eoi                                       91441    4.2     5110
kvm_hv_timer_state                            22948    1.0     1818
kvm_msr                                       18642    0.9     1495
kvm_wait_lapic_expire                         14466    0.7     1166
kvm_pv_tlb_flush                               5097    0.2      384
kvm_pic_set_irq                                4832    0.2      369
kvm_set_irq                                    4788    0.2      369
kvm_ioapic_set_irq                             4788    0.2      369
kvm_fpu                                        3718    0.2      268
kvm_vcpu_wakeup                                3178    0.1      243
kvm_userspace_exit                             1860    0.1      134
kvm_pio                                        1600    0.1      119
kvm_hypercall                                  1188    0.1       83
kvm_mmio                                        484    0.0       27
vcpu_match_mmio                                 274    0.0       15
kvm_apic                                       1524    0.1        8
kvm_pvclock_update                               13    0.0        4
kvm_halt_poll_ns                                 42    0.0        3
Total                                       2187824          167463
```

## 过一下官方文档
https://www.kernel.org/doc/html/latest/virt/kvm/index.html

## [ ] kvm ring
https://kvmforum2020.sched.com/event/eE4R/kvm-dirty-ring-a-new-approach-to-logging-peter-xu-red-hat

顺便理解一下:
```c
static const struct vm_operations_struct kvm_vcpu_vm_ops = {
	.fault = kvm_vcpu_fault,
};
```

## 整理关键的数据结构
- Each virtual CPU has an associated struct `kvm_run` data structure,
used to communicate information about the CPU between the kernel and user space.

## 整理一下路径
- cpu hotplug

## TODO
1. VMPTRST 和 VMPTRLD
3. rsp_rdx
4. vmcs_config vmcs 中间的具体内容是什么用于管控什么东西
5. cpuid

MSR 来 check vmx 的能力:
setup_vmcs_config 的中间，来分析其中的作用

Before system sftware can enter VMX operation, it enables VMX by setting CR4.VMXE[bit 13] = 1
`__vmx_enable`

想不到 : vmx_init_syscall 动态添加 syscall, 可以动态的修改 vcpu 的属性.

vmcs 的格式:
IA32_VMX_BASIC :

VPID 在内核中的操作方法 ?

## 记录
[^2]: 配置的代码非常详尽
TODO : 内核切换到 long mode 的方法比这里复杂多了, 看看[devos](https://wiki.osev.org/Setting_Up_Long_Moded)

The two modes are distinguished by the `dpl` (descriptor privilege level) field in segment register `cs.dpl=3`  in `cs` for user-mode, and zero for kernel-mode (not sure if this "level" equivalent to so-called ring3 and ring0).

In real mode kernelshould handle the segment registers carefully, while in x86-64, instructions syscall and sysret will properly set segment registers automatically, so we don't need to maintain segment registers manually.


This is just an example, we should *NOT* set user-accessible pages in hypervisor, user-accessible pages should be handled by our kernel.
> 这些例子 `mv->mem` 的内存是 hypervisor 的，到底什么是 hypervisor ?

Registration of syscall handler can be achieved via setting special registers named `MSR (Model Specific Registers)`. We can get/set MSR in hypervisor through `ioctl` on `vcpufd`, or in kernel using instructions `rdmsr` and `wrmsr`.

> 其实代码的所有的细节应该被仔细的理解清楚 TODO
> 1. 经典的 while(1) 循环，然后处理各种情况的结构在哪里
> 2. 似乎直接介绍了内核的运行方式而已

## 分析一下
https://www.owalle.com/2019/02/20/kvm-src-analysis

循环依赖 ?
x86.c : 存放整个 x86 通用的函数，emulate.c 和 vmx.c 中间都会使用的代码
vmx.c : 处理各种 exit 的操作, 其中可能会调用 emulate.c 的那处理
emulate.c : 各种指令的模拟


## 关键的数据结构
```c
struct kvm_x86_ops // 难道是为了将 kvm_get_msr 对于不同的 x86 架构上 ?

struct x86_emulate_ops // 定义的函数都是给 emulate.c 使用

struct vcpu_vmx {
    struct kvm_vcpu       vcpu;
  ...
}

/*
 * x86 supports 4 paging modes (5-level 64-bit, 4-level 64-bit, 3-level 32-bit,
 * and 2-level 32-bit).  The kvm_mmu structure abstracts the details of the
 * current mmu mode.
 */
struct kvm_mmu {
```


## TODO

```c
  kvm_mmu_gva_to_gpa_read:5516
  kvm_mmu_gva_to_gpa_fetch:5523
  kvm_mmu_gva_to_gpa_write:5531
  kvm_mmu_gva_to_gpa_system:5540
```
- [ ] https://www.cnblogs.com/ck1020/p/6920765.html 其他的文章

- [ ] https://www.kernel.org/doc/ols/2007/ols2007v1-pages-225-230.pdf
    - 看看 KVM 的总体上层架构怎么回事
- [ ] x86.c :  mmio / pio 的处理
- [ ] emulate.c 中间模拟的指令数量显然是远远没有达到实际上指令数量的，而且都是各种基本指令的模拟
  - [ ] 为什么要进行这些模拟, vmx 的各种 handle 函数为什么反而不能处理这些简单的指令
  - [ ] 很多操作依赖于 vcs read / write ，但是这里仅仅是利用 `ctxt->ops` 然后读 vcpu 中的内容
- [ ] vcpu 的 regs 和 vmcs 的 regs 的关系是什么 ?
- [ ] cpuid.c 为什么有 1000 行,  kvm_emulate_cpuid  和 ioctl API
- [ ] 调查一下 kvm_vcpu_gfn_to_hva
- [x] kvm 的 host va 的地址在哪里 ? 在使用 kvm 的线程的用户空间中
- [ ] mmu 和 flush 和 zap 有什么区别 ?
- [ ] ept 和 shadow page table 感觉处理方法类似了: 都是 for_each_shadow_entry，kvm_mmu_get_page, link_shadow_page 和 mmu_set_spte
    - [ ] `FNAME(fetch)`
    - [ ] `__direct_map`

- [ ] 对于 shadow page table, 不同的 process 都有一套，不同 process 的 cr3 的加载是什么时候 ?
- [ ] 在 FNAME(page_fault) 的两个步骤判断，当解决了 guest page table 的问题之后，依旧发生 page fault, 此时添加上的 shadow page table 显然可以 track 上
- [ ] dirty log



## 函数调用路径

- kvm_arch_vcpu_ioctl_run
  - vcpu_run
    - vcpu_enter_guest
        - static_call(kvm_x86_vcpu_run)(vcpu)
          - svm_vcpu_run
            - svm_exit_handlers_fastpath
              - handle_fastpath_set_msr_irqoff
        - vmx_handle_exit
          - kvm_vmx_exit_handlers
            - `__kvm_get_msr`
              - `vmx_get_msr`

## x86.c overview
- VMCS 的 IO
- timer pvclock tsc
- ioctl

- pio mmio 和 一般的 IO 的模拟
- emulate


1. debugfs
```c
static struct kmem_cache *x86_fpu_cache;
static struct kmem_cache *x86_emulator_cache;
```
2. kvm_on_user_return :
    1. user return ?
    2. share msr

3. exception_type

4. payload

提供了很多函数访问设置 vcpu，比如 kvm_get_msr 之类的
1. 谁调用 <- vmx.c 吧 !
2. 实现的方法 : 将其放在 vmcs 中，
从 vmcs 中间读取 : 当想要访问的时候，

- [ ] vmcs 是内存区域，还会放在 CPU 中间，用 指令读写的内容

kvm_steal_time_set_preempted


## details

#### vmx_vcpu_run
vmx_exit_handlers_fastpath : 通过 omit what 来 fast


#### kvm_read_guest_virt_helper
内核读取 guest 的内存，因为 guest 的使用地址空间是
用户态的，所以
1. gva_to_gpa 的地址切换
        gpa_t gpa = vcpu->arch.walk_mmu->gva_to_gpa(vcpu, addr, access,
2. kvm_vcpu_read_guest_page : copy_to_user 而已

## event injection
在 ./nested.md 中的同名 section 中间

#### kvm_vcpu_flush_tlb_all

```c
static void kvm_vcpu_flush_tlb_all(struct kvm_vcpu *vcpu)
{
    ++vcpu->stat.tlb_flush;
    kvm_x86_ops.tlb_flush_all(vcpu);
}
```

## emulat.c
init_emulate_ctxt
x86_emulate_instruction :

```c
int kvm_emulate_instruction(struct kvm_vcpu *vcpu, int emulation_type)
{
    return x86_emulate_instruction(vcpu, 0, emulation_type, NULL, 0);
}
```

1. emulate_ctxt 的使用位置 :

    struct x86_emulate_ctxt *ctxt = vcpu->arch.emulate_ctxt;

- [x] emulate_ctxt.ops 的调用位置 ? 在 emulate.c 中间

1. 为什么会出现 emulation_instruction 的需求 ?

```c
// 将 kvm_arch_vcpu_create 被 kvm_vm_ioctl_create_vcpu 唯一 call
int kvm_arch_vcpu_create(struct kvm_vcpu *vcpu)
```

#### opcode_table 的使用位置

```c
static const struct opcode opcode_table[256] = {
```

指令编码:
```c
struct opcode {
    u64 flags : 56;
    u64 intercept : 8;
    union {
        int (*execute)(struct x86_emulate_ctxt *ctxt);
        const struct opcode *group;
        const struct group_dual *gdual;
        const struct gprefix *gprefix;
        const struct escape *esc;
        const struct instr_dual *idual;
        const struct mode_dual *mdual;
        void (*fastop)(struct fastop *fake);
    } u;
    int (*check_perm)(struct x86_emulate_ctxt *ctxt);
};
```

## intel processor tracing

- patch : https://lwn.net/Articles/741093/
- https://man7.org/linux/man-pages/man1/perf-intel-pt.1.html

#### `vmx_x86_ops`

- `struct x86_kvm_ops` : `vmx_x86_ops` 也是其中一种
- `x86_kvm_ops` : 一个经常访问的变量


```c
static struct kvm_x86_init_ops vmx_init_ops __initdata = {
    .cpu_has_kvm_support = cpu_has_kvm_support,
    .disabled_by_bios = vmx_disabled_by_bios,
    .check_processor_compatibility = vmx_check_processor_compat,
    .hardware_setup = hardware_setup,

    .runtime_ops = &vmx_x86_ops,
};

// 在 KVM init 的时候，确定使用何种硬件设置，但是 emulate 还是存在的
int kvm_arch_hardware_setup(void *opaque)
{
  // ...
    memcpy(&kvm_x86_ops, ops->runtime_ops, sizeof(kvm_x86_ops));
  // ...
```

## emulate_ops 和 vmx_x86_ops 的操作对比
- vmx_x86_ops 提供了各种操作的硬件支持.
- vmx 的 kvm_vmx_exit_handlers 需要 emulate 的，但是 emulator 的工作需要从 emulator 中间得到数据



## hyperv.c
模拟 HyperV 的内容, 但是为什么需要模拟 HyperV ?

- kvm_hv_hypercall
- stimer

实在是有点看不懂:
https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/reference/hyper-v-architecture

## irq.c
似乎很短，但是 lapic 很长!


## 中断虚拟化
中断虚拟化的关键在于对中断控制器的模拟，我们知道x86上中断控制器主要有旧的中断控制器PIC(intel 8259a)和适应于SMP框架的IOAPIC/LAPIC两种。

https://luohao-brian.gitbooks.io/interrupt-virtualization/content/qemu-kvm-zhong-duan-xu-ni-hua-kuang-jia-fen-679028-4e2d29.html

查询 GSI 号上对应的所有的中断号:

从 ioctl 到下层，kvm_vm_ioctl 注入的中断，最后更改了 kvm_kipc_state:irr

kvm_kipc_state 的信息如何告知 CPU ? 通过 kvm_pic_read_irq

## trace mmu

## mmu_spte_update
TODO : 为什么会存在一个 writable spte 和 read-only spte 的区分 ?

```c
/* Rules for using mmu_spte_update:
 * Update the state bits, it means the mapped pfn is not changed.
 *
 * Whenever we overwrite a writable spte with a read-only one we
 * should flush remote TLBs. Otherwise rmap_write_protect
 * will find a read-only spte, even though the writable spte
 * might be cached on a CPU's TLB, the return value indicates this
 * case.
 *
 * Returns true if the TLB needs to be flushed
 */
static bool mmu_spte_update(u64 *sptep, u64 new_spte)
```

核心就是 WRITE_ONCE 而已，但是存在很多检查

## ept

tdp_page_fault()->
gfn_to_pfn(); GPA到HPA的转化分两步完成，分别通过gfn_to_hva、hva_to_pfn两个函数完成
`__direct_map()`; 建立EPT页表结构

为什么 ept 也是需要建立一个 shadow page table ?


kvm_tdp_page_fault 和 ept_page_fault 的关系是什么 ?

## ept page table
- [ ] ept 和 shadow page table 不应该共享结构啊

shadow page table : gva => hpa
ept : 应该是 GPA 到 HPA

- init_kvm_tdp_mmu
- kvm_mmu_alloc_page  : 申请 kvm_mmu_page 空间，该结构表示 EPT 页表项
- vmx_load_mmu_pgd : 传入的root_hpa也就直接当Guest CR3用，其实就是影子页表的基址。

- 当CPU访问EPT页表查找HPA时，发现相应的页表项不存在，则会发生EPT Violation异常，导致VM-Exit

**GPA到HPA的映射关系由EPT页表来维护**

## ept 和 shadow page table 中间的内容
- ept 和 shadow page table 的格式相同，让硬件访问可以格式相同
- 维护 ept 是使用软件的方法维护的，那么 ept 都是物理地址

pgd : page global directory

kvm_mmu_load_pgd : `vcpu->arch.mmu->root_hpa` 作为参数传递出去

## mmu_alloc_root
调用 kvm_mmu_get_page，但是其利用 hash 来查找，说好的 hash 是用于 id 的啊

## arch.mmu->root_hpa 和 arch.mmu->root_pgd
- [x] 是不是 root_hpa 被 direct 使用，root_pgd 被 shadow 使用
  - 并不是，都依赖于 hpa 进行 page walk，而 root_pgd 就是 guest cr3 的值，这是 GPA


mmu_alloc_shadow_roots : `root_pgd = vcpu->arch.mmu->get_guest_pgd(vcpu);`
mmu_alloc_direct_roots : root_pgd = 0


get_guest_pgd 的一般注册函数:
```c
static unsigned long get_cr3(struct kvm_vcpu *vcpu)
{
    return kvm_read_cr3(vcpu);
}

// 读取 cr3 似乎不是一定会从 vmcs 中间读取
static inline ulong kvm_read_cr3(struct kvm_vcpu *vcpu)
{
    if (!kvm_register_is_available(vcpu, VCPU_EXREG_CR3))
        kvm_x86_ops.cache_reg(vcpu, VCPU_EXREG_CR3);
    return vcpu->arch.cr3;
}
```




1. `arch.mmu->root_hpa` 的初始化

mmu_alloc_direct_roots
```c
static int mmu_alloc_roots(struct kvm_vcpu *vcpu)
{
    if (vcpu->arch.mmu->direct_map)
        return mmu_alloc_direct_roots(vcpu);
    else
        return mmu_alloc_shadow_roots(vcpu);
}
```

## memory in kernel or qumu process
luohao's blog:

- [ ] rmap 字段的解释，那么 memory 是 vmalloc 分配的 ?????
  - [ ] vmalloc 的分配是 page fault 的吗 ?

```c
struct kvm_memory_slot {
    gfn_t base_gfn;                    // 该块物理内存块所在guest 物理页帧号
    unsigned long npages;              //  该块物理内存块占用的page数
    unsigned long flags;
    unsigned long *rmap;               // 分配该块物理内存对应的host内核虚拟地址（vmalloc分配）
    unsigned long *dirty_bitmap;
    struct {
        unsigned long rmap_pde;
        int write_count;
    } *lpage_info[KVM_NR_PAGE_SIZES - 1];
    unsigned long userspace_addr;       // 用户空间地址（QEMU)
    int user_alloc;
};
```


## parent_ptes
```c
static void kvm_mmu_mark_parents_unsync(struct kvm_mmu_page *sp)
{
    u64 *sptep;
    struct rmap_iterator iter;

    for_each_rmap_spte(&sp->parent_ptes, &iter, sptep) {
        mark_unsync(sptep);
    }
}

static void mark_unsync(u64 *spte)
{
    struct kvm_mmu_page *sp;
    unsigned int index;

    sp = sptep_to_sp(spte);
    index = spte - sp->spt;
    if (__test_and_set_bit(index, sp->unsync_child_bitmap))
        return;
    if (sp->unsync_children++)
        return;
    kvm_mmu_mark_parents_unsync(sp);
}
```
递归向上，当发现存在有人 没有 unsync 的时候，在 unsync_child_bitmap 中间设置标志位，
并且向上传导，直到发现没人检测过

link_shadow_page : mark_unsync 的唯一调用位置
kvm_unsync_page : kvm_mmu_mark_parents_unsync 唯一调用位置

mmu_need_write_protect : 对于sp

#### mmu_need_write_protect
for_each_gfn_indirect_valid_sp : 一个 gfn 可以
同时对应多个 shadow page，原因是一个 guest page 可以对应多个 shadow page


> hash : 实现 guest page tabel 和 shadow page 的映射

> rmap_add 处理的是 :  gfn 和其对应的 pte 的对应关系


## role.quadrant
作用: 一个 guest 地址对应的 page table

get_written_sptes : 依靠 gpa 的 page_offset 计算出来，然后和 `sp->role.quadrant` 对比

#### obsolete sp

```c
static bool is_obsolete_sp(struct kvm *kvm, struct kvm_mmu_page *sp)
{
    return sp->role.invalid ||
           unlikely(sp->mmu_valid_gen != kvm->arch.mmu_valid_gen);
}
```

#### gfn_to_rmap
RMAP_RECYCLE_THRESHOLD 居然是 1000

## gfn_track

```diff
 History:        #0
 Commit:         3d0c27ad6ee465f174b09ee99fcaf189c57d567a
 Author:         Xiao Guangrong <guangrong.xiao@linux.intel.com>
 Committer:      Paolo Bonzini <pbonzini@redhat.com>
 Author Date:    Wed 24 Feb 2016 09:51:11 AM UTC
 Committer Date: Thu 03 Mar 2016 01:36:21 PM UTC

 KVM: MMU: let page fault handler be aware tracked page

 The page fault caused by write access on the write tracked page can not
 be fixed, it always need to be emulated. page_fault_handle_page_track()
 is the fast path we introduce here to skip holding mmu-lock and shadow
 page table walking

 However, if the page table is not present, it is worth making the page
 table entry present and readonly to make the read access happy

 mmu_need_write_protect() need to be cooked to avoid page becoming writable
 when making page table present or sync/prefetch shadow page table entries

 Signed-off-by: Xiao Guangrong <guangrong.xiao@linux.intel.com>
 Signed-off-by: Paolo Bonzini <pbonzini@redhat.com>
```
-  [ ] tracked 的 page 不能被 fixed, 必须被模拟，为啥 ?

gfn_track 其实没有什么特别的，告诉该 页面被 track 了，然后
kvm_mmu_page_fault 中间将会调用 x86_emulate_instruction 来处理，
似乎然后通过 mmu_notifier 使用 kvm_mmu_pte_write 来更新 guest page table

#### page_fault_handle_page_track
direct_page_fault 和 FNAME(page_fault) 调用，
似乎如果被 track，那么这两个函数会返回 RET_PF_EMULATE


## track 机制
track 和 dirty bitmap 实际上是两个事情吧!

对于加以维护的:
kvm_slot_page_track_add_page :
kvm_slot_page_track_remove_page :
==> update_gfn_track

- [ ] 两个函数，调用 update,  都是对于 gfn_track 的加减 1 而已

分别被 account_shadowed 和 unaccount_shadowed 调用

`__kvm_mmu_prepare_zap_page` : 被各种 zap page 调用，并且配合 commit_zap 使用
=> unaccount_shadowed

kvm_mmu_get_page :
=> account_shadowed




1. kvm_mmu_page_write

```c
void kvm_mmu_init_vm(struct kvm *kvm)
{
    struct kvm_page_track_notifier_node *node = &kvm->arch.mmu_sp_tracker;

    node->track_write = kvm_mmu_pte_write;
    node->track_flush_slot = kvm_mmu_invalidate_zap_pages_in_memslot;
    kvm_page_track_register_notifier(kvm, node);
}
```
kvm_mmu_get_page: 当不是 direct 模式，那么需要对于 kvm_mmu_alloc_page 的 page 进行 account_shadowed
=> account_shadowed :
=> kvm_slot_page_track_add_page

**所以，保护的是 shadow page table ?**

```c
static void account_shadowed(struct kvm *kvm, struct kvm_mmu_page *sp)
{
    struct kvm_memslots *slots;
    struct kvm_memory_slot *slot;
    gfn_t gfn;

    kvm->arch.indirect_shadow_pages++;
    gfn = sp->gfn;
    slots = kvm_memslots_for_spte_role(kvm, sp->role);
    slot = __gfn_to_memslot(slots, gfn);

    /* the non-leaf shadow pages are keeping readonly. */
    if (sp->role.level > PG_LEVEL_4K)
        return kvm_slot_page_track_add_page(kvm, slot, gfn,
                            KVM_PAGE_TRACK_WRITE);

    kvm_mmu_gfn_disallow_lpage(slot, gfn);
}
```
- [ ] 为什么不保护 leaf shadow page ?

> TOBECON

## track mode

> - dirty tracking:
>    report writes to guest memory to enable live migration
>    and framebuffer-based displays

原来 tracing 是 dirty 的



```diff
 KVM: page track: add the framework of guest page tracking

 The array, gfn_track[mode][gfn], is introduced in memory slot for every
 guest page, this is the tracking count for the gust page on different
 modes. If the page is tracked then the count is increased, the page is
 not tracked after the count reaches zero

 We use 'unsigned short' as the tracking count which should be enough as
 shadow page table only can use 2^14 (2^3 for level, 2^1 for cr4_pae, 2^2
 for quadrant, 2^3 for access, 2^1 for nxe, 2^1 for cr0_wp, 2^1 for
 smep_andnot_wp, 2^1 for smap_andnot_wp, and 2^1 for smm) at most, there
 is enough room for other trackers

 Two callbacks, kvm_page_track_create_memslot() and
 kvm_page_track_free_memslot() are implemented in this patch, they are
 internally used to initialize and reclaim the memory of the array

 Currently, only write track mode is supported
```

#### gfn_to_memslot_dirty_bitmap
`slot->dirty_bitmap` 都在 kvm_main 上面访问

pte_prefetch_gfn_to_pfn


- [ ] dirty 指的是 谁 相对于 谁 是 dirty 的

```c
/**
 * kvm_vm_ioctl_get_dirty_log - get and clear the log of dirty pages in a slot
 * @kvm: kvm instance
 * @log: slot id and address to which we copy the log
 *
 * Steps 1-4 below provide general overview of dirty page logging. See
 * kvm_get_dirty_log_protect() function description for additional details.
 *
 * We call kvm_get_dirty_log_protect() to handle steps 1-3, upon return we
 * always flush the TLB (step 4) even if previous step failed  and the dirty
 * bitmap may be corrupt. Regardless of previous outcome the KVM logging API
 * does not preclude user space subsequent dirty log read. Flushing TLB ensures
 * writes will be marked dirty for next log read.
 *
 *   1. Take a snapshot of the bit and clear it if needed.
 *   2. Write protect the corresponding page.
 *   3. Copy the snapshot to the userspace.
 *   4. Flush TLB's if needed.
 */
static int kvm_vm_ioctl_get_dirty_log(struct kvm *kvm,
                      struct kvm_dirty_log *log)
{
    int r;

    mutex_lock(&kvm->slots_lock);

    r = kvm_get_dirty_log_protect(kvm, log);

    mutex_unlock(&kvm->slots_lock);
    return r;
}
```

https://terenceli.github.io/%E6%8A%80%E6%9C%AF/2018/08/11/dirty-pages-tracking-in-migration

> So here for every gfn, we remove the write access. After return from this ioctl, the guest’s RAM has been marked no write access, every write to this will exit to KVM make the page dirty. This means ‘start the dirty log’.


- [ ] kvm_mmu_slot_apply_flags : 实际作用是 dirty log

## kvm_sync_page
kvm_sync_pages : 对于 gfn (其实是 gva 关联的 vcpu) 全部更新, 通过调用 kvm_sync_page

kvm_mmu_sync_roots : 从根节点更新更新 => (mmu_sync_children : 将整个 children 进行 sync)

最终调用 sync_page 函数指针维持生活







## mmio
- [ ] 对于 host 而言，存在 pcie 分配 mmio 的地址空间，在虚拟机中间，这一个是如何分配的 MMIO 空间的

```c
static bool is_mmio_spte(u64 spte)
{
    return (spte & SPTE_SPECIAL_MASK) == SPTE_MMIO_MASK;
}
```

- generation 只是为了 MMIO 而处理的


> - if the RSV bit of the error code is set, the page fault is caused by guest
>  accessing MMIO and cached MMIO information is available.
>
>  - walk shadow page table
>  - check for valid generation number in the spte (see "Fast invalidation of
>    MMIO sptes" below)
>  - cache the information to `vcpu->arch.mmio_gva`, `vcpu->arch.mmio_access` and
>    `vcpu->arch.mmio_gfn`, and call the emulator


## mmio generation
👇记录 mmu.rst 的内容:
虽然的确解释了 mmio 使用 generation 的原因，但是下面的问题值得理解:
- [ ] As mentioned in "Reaction to events" above, kvm will cache MMIO information in leaf sptes.
  - [ ] 如果不 cache, 这些数据放在那里

- [ ] When a new memslot is added or an existing memslot is changed, this information may become stale and needs to be invalidated.
  - [ ] 为什么 memslot 增加，导致数据失效

Unfortunately, a single memory access might access kvm_memslots(kvm) multiple
times, the last one happening when the generation number is retrieved and
stored into the MMIO spte.  Thus, the MMIO spte might be created based on
out-of-date information, but with an up-to-date generation number.

- [ ] To avoid this, the generation number is incremented again after synchronize_srcu
returns;

- [ ] 找到访问 pte 来比较 generation, 发现 out of date，然后 slow path 的代码

## TODO : shadow flood

#### kvm_vm_ioctl_set_memory_region

#### kvm_vcpu_unmap

#### kvm_read_guest
- [ ] 为什么要处理 guest page 机制

#### kvm_vcpu_fault
> 配合 vcpu ioctl
```c
static int create_vcpu_fd(struct kvm_vcpu *vcpu)
{
    char name[8 + 1 + ITOA_MAX_LEN + 1];

    snprintf(name, sizeof(name), "kvm-vcpu:%d", vcpu->vcpu_id);
    return anon_inode_getfd(name, &kvm_vcpu_fops, vcpu, O_RDWR | O_CLOEXEC);
}
```


## shadow page table 的坏处
- Simplified VMM design. 需要处理 shadow page table 和两级翻译的同步问题
- Guest page table modifications need not be trapped, hence VM exits reduced. 同步
- Reduced memory footprint compared to shadow page table algorithms. shadow table 会占用空间


## hypercall
https://stackoverflow.com/questions/33590843/implementing-a-custom-hypercall-in-kvm

x86.c: kvm_emulate_hypercall

```c
/* For KVM hypercalls, a three-byte sequence of either the vmcall or the vmmcall
 * instruction.  The hypervisor may replace it with something else but only the
 * instructions are guaranteed to be supported.
 *
 * Up to four arguments may be passed in rbx, rcx, rdx, and rsi respectively.
 * The hypercall number should be placed in rax and the return value will be
 * placed in rax.  No other registers will be clobbered unless explicitly
 * noted by the particular hypercall.
 */

static inline long kvm_hypercall0(unsigned int nr)
{
    long ret;
    asm volatile(KVM_HYPERCALL
             : "=a"(ret)
             : "a"(nr)
             : "memory");
    return ret;
}
```
host 发送 hypercall 的之后，造成从 host 中间退出，然后 最后调用到 kvm_emulate_hypercall, 实际上支持的操作很少

```c
int kvm_emulate_hypercall(struct kvm_vcpu *vcpu)
{
    unsigned long nr, a0, a1, a2, a3, ret;
    int op_64_bit;

    if (kvm_hv_hypercall_enabled(vcpu->kvm))
        return kvm_hv_hypercall(vcpu);

```

## manual notes
- Table C-1. Basic Exit Reasons
