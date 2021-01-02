# Port dune to mips
- [x] 如何交叉编译从而可以让我在 x86 的电脑上看内核 ?


<!-- vim-markdown-toc GFM -->

  - [question before write](#question-before-write)
  - [clean and old](#clean-and-old)
  - [到底要不要写测试](#到底要不要写测试)
  - [user mode](#user-mode)
    - [entry.c](#entryc)
    - [percpu](#percpu)
    - [vm.c](#vmc)
    - [signal](#signal)
  - [*process*](#process)
  - [horrible](#horrible)
  - [Not Now](#not-now)
- [ref](#ref)

<!-- vim-markdown-toc -->

## question before write
- hypercall 
  - [ ] cause BD : something instruction emulation

- [x] syscall
  - We have to recompile glibc
  - [x] enter the guest mode in the usermode, maybe we have to adjust some register value to indicate the usermode.
    - x86 : 如果没有配置 MSR_LSTAR 的话，而是使用 int 80, 那么会执行 idt 中间的地址
    - [x] mips : syscall 的手册 : 
  - [x] MIPS virtualization manual :  4.7.4 Exception Priority
    - [x] A guest enabled interrupt occurred. / A root enabled interrupt occurred. : how to confict ? junru wang's paper says it's dangerous

- tdp
  - [x] pte_mkclean / pte_mkold
    - pte_mkold : used by notifier
    - pte_mkclean : used by map page fast 
  - [x] mmu notifier
    - [x] invalidate_range_start
    - [x] invalidate_range_end
    - [x] clear_flush_young  
    - [x] clear_young
    - [x] test_young
    - [x] change_pte : **I think dune will never call this function**
    - [x] release
  - [x] invalid TLB
  - [ ] asid

-  kvm_mips_handle_exit
  - kvm_trap_vz_handle_tlb_ld_miss + kvm_trap_vz_handle_tlb_st_miss
    - *kvm_mips_handle_vz_root_tlb_fault*
      - kvm_mips_map_page
        - [ ] kvm_mips_set_pmd_huge
      - kvm_vz_host_tlb_inv

- relation between kvm_mips_flush_gpa_pt && kvm_vz_host_tlb_inv && kvm_mips_flush_gva_pt
  - kvm_mips_flush_gva_pt : used by emulate.c at which we're not interested
  - kvm_mips_flush_gpa_pt : mmu notifier, used for invalid page table translation from `gpa -> gpa`
  - kvm_vz_host_tlb_inv : load miss / store miss exception

- entry
  - [x] why need assembly code to return to host ? because we have something more to restore, such as host register
    - [x] RESUME_HOST to userspace.
  - [ ] **TLB exception handler is managed by software, so we have to setup the TLB entry before enter to guest software.**
    - Now that we have already setup entry for the guset software, of course, change the syscall entry is possible too.
      - [x] is supporting kernel mode syscall and user mode syscall possible ?
        - YES, x86 remap the page,  MIPS rewrite the code


- memslot : substituted by our wired **dune_vm_map_pages**

## clean and old
- [x] how mips handle clean and old page in the host ?

## 到底要不要写测试

## user mode
进入的流程分析:
1. 地址空间的准备: page table 格式
2. 切换 : dune_conf / mips 汇编 / 很短的代码(用于调整参数)
3. 切换之后，利用 eip 进入到 dune_boot 的位置
4. dune_boot : 设置 ebase 的中间，syscall, page fault 的入口，其他入口的封锁掉
    - [ ] TSS 的机制, 实际上，并不需要才对, 应该检测一下
    - 对于 gebase 的赋值

退出，从内核到用户态的退出，在 dune_conf 上，还是从该位置返回啊!

- [ ] SAVE_REGS 和 SAVE_REST 在内核中间是否存在对应的东西
  - 参数 / gpr / exception frame
  - [ ] 那个 MIPS 操作系统作为参考

### entry.c
- [x] setup_safe_stack
  - [ ] mips switch to kernel stack
  - [ ] **do some test**

### percpu
- [ ] fs / gs register
  - [ ] keep fs consistent with kernel space.
  - [x] 在 guest mode 中间, gs is reserved for percpu access, 在 dune_boot 中间将其替换掉.
  - [ ] cs / ss / ds / es / fs / gs 中间，为什么 fs 和 gs 需要特殊处理
    - 因为 pthread local storage 利用的是内核相同的数值 ?

本来访问 fs / gs 寄存器是需要导致 vmexit 的:
```c
	memset(msr_bitmap, 0xff, PAGE_SIZE);
	__vmx_disable_intercept_for_msr(msr_bitmap, MSR_FS_BASE);
	__vmx_disable_intercept_for_msr(msr_bitmap, MSR_GS_BASE);
	__vmx_disable_intercept_for_msr(msr_bitmap, MSR_PKG_ENERGY_STATUS);
	__vmx_disable_intercept_for_msr(msr_bitmap, MSR_RAPL_POWER_UNIT);
```
- [x] 这是在访问 host 的 FS / GS 吗 ?
  - 是的，但是在 vmexit 的时候，fs / gs 将会被自动保存
- [ ] 实现 percpu 的功能必须需要 gs 寄存器吗 ?
  - [x] gs 寄存器如何保证没有其他的程序使用 (似乎修改是需要利用 msr)
  - [ ] kfs_base / ufs_base / in_usermode
  - [ ] tss 和 gdt 所有的 cpu 共享的

- [ ] percpu 的生命周期是什么 ?

- dune_init_and_enter
  - dune_init : 地址空间，syscall, signal 的设置，一个 dune 进程应该仅仅创建一次 ?
  - dune_enter : 

- [x] percpu
  - bind to vcpu (yes)
  - thread / percpu / vcpu / physical cpu 的关系
    - percpu is thread local area
    - vcpu is create under current process
    - so, thread / percpu / vcpu can migrate different physical cpu
    - [x] gdt / idt / tss 是全局的还是局部的(必然是局部的，否则 lidt 的指令无法解释)
      - 好吧，gdt / idt / tss 都是保存在 vmcs 中间的
      - 没有 preempt 的时候，即使是在内核任何位置都是可以出现代码被 preempt 的情况
      - 在 vcpu 正在运行的时候，不会直接切换到另一个 cpu 上，但是一旦进入到 host 中间，随时都是可能切换到不同的 cpu 上，切换之后，保证再次进入的时候，vcpu 内容 和 cpu 加载的保持一致。
      - [x] 加载到 CPU 中间的内容是 :
        - vmcs 的地址 ： vmcs_load
        - [x]  `__vmx_setup_cpu`: 让当前所在的 CPU 和 vmcs 中间的 Host 相关的数值保持一致
          - TR / FS / GS / GDT / HOST_IA32_SYSENTER_ESP
          - [ ] segment_base

- vmx_vcpu 保存了 vcpu 的 general purpose register 的数值，除此之外还有什么 ?
  - [x] host_rsp
    - [ ] why need a special instruction to handle this : ASM_VMX_VMWRITE_RSP_RDX
    - [ ] why only reload if changed ?
    - [ ] In vmx, there is a function for it ? why so special ?
  - [x] cr2
    - it's guest cr2
    - cr0, cr3, cr4 is preserved by vcpu
  - [x] msr_autoload
    - 利用 msr_bitmap 控制 msr 那些可以直接访问，那些不可以
    - perf need msr
  - [x] guest_kernel_gs_base
  - [x] idt_base : related with posted interrupt
- cpu 通过持有 `__this_cpu_read` 来确定自己执行的 vcpu 结构体
- dune_percpu 是用户态的，被 vmcs 的字段 gs 所指向。lpercpu, vcpu 都是当前 thread 分配的, 只是当前 thread 会被迁移到个个 CPU 上。


vcpu::guest_kernel_gs_base
```c
#define MSR_FS_BASE		0xc0000100
#define MSR_GS_BASE		0xc0000101
#define MSR_KERNEL_GS_BASE	0xc0000102
```

- [x] do_dune_enter / on_dune_exit
  - save regs in the host mode, but restore it in the guest mode
  - dune_conf

```c
	conf->vcpu = 0; // used for specify which conf is bind to vcpu
  conf->rip = (__u64) &__dune_ret;
	conf->rsp = 0; // 在 __dune_enter 的代码中间，movq	%rsp, DUNE_CFG_RSP(%rsi) 实现的赋值
	conf->cr3 = (physaddr_t) pgroot;
	conf->rflags = 0x2; // although written into the vmcs, but why 0x2 is save TODO
```
- dune_enter
  - vmx_launch
    - vmx_create_vcpu
      - vmx_setup_registers
    - vmx_copy_registers_to_conf


- [x] TSS
  - 如果 syscall 全部都是被截断的，为什么一个内核态的 Stack ? 实际上，部分内容还是需要切换到内核中间, 首先，syscall 的代码的部分被覆盖，被覆盖的代码实际上在内核中间执行。
  - 其次，由于掌控内核态 和 用户态程序，在切换到内核态的时候，需要 stack 的支持
  - [ ] 有些问题没有调查清楚
    - [ ] 默认情况下，进入内核，使用的 sp 还是用户态配置的，所以并不是很清楚，在自由切换用户态和内核的时候， stack 到底是哪一个
      - [ ] 似乎只要保持始终在内核态，那么就可以了，首先测试一下简单的程序吧 !

### vm.c
- [ ] ept and host page table has different form, but it seems we handle ept violation and paging setup in the same way ?

- [x] I should fix the bug in the wedge
  - [ ] 其中使用了 pthread 啊
  - dune_vm_clone 利用 `__dune_vm_clone_helper` 进行地址拷贝的时候，没有考虑 Hugetlb 的影响。
    - 出现错误的原因 : dune_vm_clone 的原理是，遍历地址空间，通过 source 的 pte 找到物理地址，targete 的建立一个 page table 映射到相同的物理地址上。
    - [ ] fix
    - [x] 默认的情况下，系统中间没有申请 hugepage 才对啊。是的，但是在 guest 中间，dune 掌控了系统初始化的过程，构建的 guest 映射是 transparent hugepage

- [ ] `ptent_t *pgroot;` 是 libdune/entry.c 提供全局变量, 以 wedge/test.c 为例子，最开始创建的线程都是 guest kernel thread, 其之后创建出来的都是 user mode thread

- page 
  - page table format
    - [ ] how can I verify it ?
  - page 是如何处理 fork 的

- [ ] `__dune_vm_clone_helper` 中间的:
  - [ ] dune_page_isfrompool : 影响在于什么地方
  - [ ] dune_page_get

- 一般来说，通过在 PMD 和 PUD 的 page table 上插入 flag 表示该 pte 映射一个 transparent page
  - [ ] Loongson 的实现是怎么样子的

### signal
- [x] how signal handled ?
- [x] `__dune_go_dune` : mainly used for signal
- 在 dune_init 中间关闭 signal, 并没有，但是各种 kill 信号还是可以收到的

## *process*
- fork + dune_init_and_enter 的效果 : 两个虚拟机，但是可以通过 host kernel 实现通信
- fork + dune_enter 的效果 : 在同一个虚拟机中间, 在同一个 pgroot 下。

- [ ] 找一下论文的说明

- [ ] dune_clone 的实现, 现在 sandbox 执行需要 fork 的代码有问题。

- [x] 在 guest user space 增加一个代码，让所有的 pthread / fork 自动进入到 dune 中间.
  - 调用内核 sys_fork，children 的之后会指向 fork_ret 的路径，然后返回到用户空间, 如果想要不修改 qemu 的代码，那么就让 qemu 的 syscall 被截断
  - qemu 本身可以运行在用户态, 但是设置 page table 的 flag 让其可以任意访问


## horrible
- [x] check code in entry line by line
  - [x] how to register idt in the code
  - 大部分是 macro, 很多是 debug 和 interrupt 的代码，实际上，我们只需要执行两个代码

- [ ] thread local variable : fs register

- [ ] vmx_run_vcpu 
  - [ ] `Lkvm_vmx_return` : we are relying on some wired symbol ?

- [ ] 为什么说修改 glibc 最后会导致性能可以稍微提升一点点。

- [ ] 每次 debug 的时候，都要恐惧一次地址空间的各个成分，起止位置的含义。

- 不知道为什么，有时候系统直接卡死了，现在不知道处理的办法.

- wedge 遇到的 bug : 如果是 trap.c 的 handler 中间调用 printf, 因为 SIMD(SSE) 指令和 stack 对齐的问题，造成 double fault
  - [ ] 但是 printf 在进入 dune 之后似乎变成了线程不安全的，例如下面的效果，实际上，和线程安全性没有关系，因为每次都是下面的效果。
  - [ ] dune_printf 和 printf 的区别
```
Creating a new sthread 3
stack addresss 0x7f163a9b4000
writable addresss 0x7f163a984000
before jump to user
we can printf in kernel mode
we caGet cr3 : 21b10d003
SYSCALL 257 current 0x7f163aa46560
POS 32 sys 257
SYSCALL 0 current 0x7f163aa46560
Blocked syscall 0
sorry for the page fault
7ffef9073020
5
```
- [ ] sthread.c : schedule : how it works 

- [ ] mmu notifier 的 log 显然是不对的，利用 dump_stack 显示，刚刚创建的 page 几乎总是立刻就会被清理掉。

- [ ] msa lasx
- [ ] fpu


## Not Now
- [ ] `__dune_go_linux` : related with debug, but currently, debug is not used by far.

# ref
https://wiki.osdev.org/Paging

```
Bit 0 (P) is the Present flag.
Bit 1 (R/W) is the Read/Write flag.
Bit 2 (U/S) is the User/Supervisor flag.
```

The combination of these flags specify the details of the page fault and indicate what action to take:

```
US RW  P - Description
0  0  0 - Supervisory process tried to read a non-present page entry
0  0  1 - Supervisory process tried to read a page and caused a protection fault
0  1  0 - Supervisory process tried to write to a non-present page entry
0  1  1 - Supervisory process tried to write a page and caused a protection fault
1  0  0 - User process tried to read a non-present page entry
1  0  1 - User process tried to read a page and caused a protection fault
1  1  0 - User process tried to write to a non-present page entry
1  1  1 - User process tried to write a page and caused a protection fault
```