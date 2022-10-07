# mce 的工作原理

- https://unix.stackexchange.com/questions/451655/running-mcelog-on-an-amd-processor

 f9781bb18ed828e7b83b7bac4a4ad7cd497ee7d7


## 能不能注册 ecc 的错误给 guest

ecc 是 mce 的一种才对

## mce

- 发现只要是替换内核，那么 /dev/ 下没有 mcelog 的

- mcelog 操作需要/dev/mcelog 设备，这个设备通常自动由 udev 创建，也可以通过手工命令创建 mknod /dev/mcelog c 10 227。设备创建后剋通过 ls -lh /dev/mcelog 检查：
  - [ ] 似乎 centos 8 没有办法自动创建

> 默认没有配置/sys/devices/system/machinecheck/machinecheck0/trigger，这时这个内容是空的。当将/usr/sbin/mcelog 添加到这个 proc 文件中，就会在内核错误发生时触发运行/usr/sbin/mcelog 来处理解码错误日志，方便排查故障。

/etc/mcelog/mcelog.conf 是 mcelog 配置文件


这一步似乎是必须的:
- modprobe mce-inject
- cd /sys/devices/system/machinecheck/machinecheck0 && echo 3 > tolerant # 为了防止出现 hardware 错误的时候，不要将机器 panic

## 参考资料
- https://huataihuang.gitbooks.io/cloud-atlas/content/os/linux/log/mcelog.html
- https://www.cnblogs.com/muahao/p/6003910.html
- https://stackoverflow.com/questions/38496643/how-can-we-generate-mcemachine-check-errors : 如何使用 memory inject
- https://mcelog.org/ : 官方文档

## [ ] mce 在内核中的升级

```c
config X86_MCELOG_LEGACY
    bool "Support for deprecated /dev/mcelog character device"
    depends on X86_MCE
    help
      Enable support for /dev/mcelog which is needed by the old mcelog
      userspace logging daemon. Consider switching to the new generation
      rasdaemon solution.
```

## [ ] 确认一下，在 ARM 中也是存在这个机制的

- [ ] 是不是 ARM 上没有 mce 而已?

## [ ] 分析一下 mce 的原理

```c
/*
 * The default IDT entries which are set up in trap_init() before
 * cpu_init() is invoked. Interrupt stacks cannot be used at that point and
 * the traps which use them are reinitialized with IST after cpu_init() has
 * set up TSS.
 */
static const __initconst struct idt_data def_idts[] = {
    INTG(X86_TRAP_DE,       asm_exc_divide_error),
    INTG(X86_TRAP_NMI,      asm_exc_nmi),
    INTG(X86_TRAP_BR,       asm_exc_bounds),
    INTG(X86_TRAP_UD,       asm_exc_invalid_op),
    INTG(X86_TRAP_NM,       asm_exc_device_not_available),
    INTG(X86_TRAP_OLD_MF,       asm_exc_coproc_segment_overrun),
    INTG(X86_TRAP_TS,       asm_exc_invalid_tss),
    INTG(X86_TRAP_NP,       asm_exc_segment_not_present),
    INTG(X86_TRAP_SS,       asm_exc_stack_segment),
    INTG(X86_TRAP_GP,       asm_exc_general_protection),
    INTG(X86_TRAP_SPURIOUS,     asm_exc_spurious_interrupt_bug),
    INTG(X86_TRAP_MF,       asm_exc_coprocessor_error),
    INTG(X86_TRAP_AC,       asm_exc_alignment_check),
    INTG(X86_TRAP_XF,       asm_exc_simd_coprocessor_error),

#ifdef CONFIG_X86_32
    TSKG(X86_TRAP_DF,       GDT_ENTRY_DOUBLEFAULT_TSS),
#else
    INTG(X86_TRAP_DF,       asm_exc_double_fault),
#endif
    INTG(X86_TRAP_DB,       asm_exc_debug),

#ifdef CONFIG_X86_MCE
    INTG(X86_TRAP_MC,       asm_exc_machine_check),
#endif

    SYSG(X86_TRAP_OF,       asm_exc_overflow),
#if defined(CONFIG_IA32_EMULATION)
    SYSG(IA32_SYSCALL_VECTOR,   entry_INT80_compat),
#elif defined(CONFIG_X86_32)
    SYSG(IA32_SYSCALL_VECTOR,   entry_INT80_32),
#endif
};
```

## [ ] 了解 https://github.com/mchehab/rasdaemon 的工作原理
- 为什么感觉似乎是只能收集内存错误

> Its long term goal is to be the userspace tool that will collect all
hardware error events reported by the Linux Kernel from several sources
(EDAC, MCE, PCI, ...) into one common framework.

难道 EDAC 和 MCE 不是一个东西 ?

--enable-aer            enable PCIe AER events (currently experimental)
--enable-mce            enable MCE events (currently experimental)

靠，好家伙，居然只是 experimental 的功能 ?

## [ ] 和虚拟化有关系吗

kvm_vcpu_ioctl_x86_set_mce 向 guest 注入错误的方法

kvm_queue_exception

So, what is bank ?

同时，在 QEMU 中有 mce_init 来初始化的

  - mce_init : machine check exception, 初始化之后，那些 helper 就可以正确工作了


## 为什么 mcelog 被 deprecated 了
https://lore.kernel.org/all/20170327093304.10683-6-bp@alien8.de/T/#u

## edac
- https://docs.kernel.org/driver-api/edac.html
- https://lwn.net/Articles/480575/

## how dare you

```txt
4.105 KVM_X86_SETUP_MCE

Capability: KVM_CAP_MCE
Architectures: x86
Type: vcpu ioctl
Parameters: u64 mcg_cap (in)
Returns: 0 on success,
         -EFAULT if u64 mcg_cap cannot be read,
         -EINVAL if the requested number of banks is invalid,
         -EINVAL if requested MCE capability is not supported.

Initializes MCE support for use. The u64 mcg_cap parameter
has the same format as the MSR_IA32_MCG_CAP register and
specifies which capabilities should be enabled. The maximum
supported number of error-reporting banks can be retrieved when
checking for KVM_CAP_MCE. The supported capabilities can be
retrieved with KVM_X86_GET_MCE_CAP_SUPPORTED.

4.106 KVM_X86_SET_MCE

Capability: KVM_CAP_MCE
Architectures: x86
Type: vcpu ioctl
Parameters: struct kvm_x86_mce (in)
Returns: 0 on success,
         -EFAULT if struct kvm_x86_mce cannot be read,
         -EINVAL if the bank number is invalid,
         -EINVAL if VAL bit is not set in status field.

Inject a machine check error (MCE) into the guest. The input
parameter is:

struct kvm_x86_mce {
	__u64 status;
	__u64 addr;
	__u64 misc;
	__u64 mcg_status;
	__u8 bank;
	__u8 pad1[7];
	__u64 pad2[3];
};

If the MCE being reported is an uncorrected error, KVM will
inject it as an MCE exception into the guest. If the guest
MCG_STATUS register reports that an MCE is in progress, KVM
causes an KVM_EXIT_SHUTDOWN vmexit.

Otherwise, if the MCE is a corrected error, KVM will just
store it in the corresponding bank (provided this bank is
not holding a previously reported uncorrected error).
```
