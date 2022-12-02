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

[^26]: [lwn: ioremap and memremap](https://lwn.net/Articles/653585/)

# 参考资料
- Understand Linux Kernel : I/O Architecture and Device Drivers : 4.4 Accessing the I/O Shared Memory

Depending on the device and on the bus type, I/O shared memory in the PC’s architecture may be mapped within different physical address ranges. Typically:
- For most devices connected to the ISA bus

  The I/O shared memory is usually mapped into the 16-bit physical addresses
  ranging from 0xa0000 to 0xfffff; this gives rise to the “hole” between 640 KB
  and 1 MB mentioned in the section “Physical Memory Layout” in Chapter 2.

- For devices connected to the PCI bus.

  The I/O shared memory is mapped into 32-bit physical addresses near the 4 GB
  boundary. This kind of device is much simpler to handle.


How does a device driver access an I/O shared memory location? *Let’s start with the
PC’s architecture*, which is relatively simple to handle, and then extend the discussion to other architectures.

Remember that kernel programs act on linear addresses, so the I/O shared memory
locations must be expressed as addresses greater than PAGE_OFFSET. In the following
discussion, we assume that `PAGE_OFFSET` is equal to 0xc0000000—that is, that the kernel linear addresses are in the fourth gigabyte.

1. 内核的确映射了 0xc0000000 之后的虚拟地址空间到低地址的物理空间上。

There is a problem, however, for the second statement, because the I/O physical
address is greater than the *last physical address of the system RAM*. Therefore, the
`0xfc000000` linear address does not correspond to the 0xfc000000 physical address.
> @todo 什么叫做 : last physical address of the system RAM
>

In
such cases, the kernel Page Tables must be modified to include a linear address that
maps the I/O physical address. This can be done by invoking the ioremap( ) or
ioremap_nocache() functions. The first function, which is similar to vmalloc( ),
invokes get_vm_area( ) to create a new vm_struct descriptor (see the section “Descriptors of Noncontiguous Memory Areas” in Chapter 8) for a linear address interval that
has the size of the required I/O shared memory area. The functions then update the
corresponding Page Table entries of the canonical kernel Page Tables appropriately.
The `ioremap_nocache()` function differs from ioremap() in that it also disables the
*hardware cache* when referencing the remapped linear addresses properly.
> @todo 什么叫做 hardware cache 啊 ?
> @todo 也就是 访问相当于访问 设备是一个早就存在的操作，使用 ioremap 只是因为部分 page table entry 无法走到正确的位置而已。 如果这样说，resource 的含义到底是什么 ?
> @todo 我感觉只要分析了 resource 以及 System Ram 是如何放到其中的就可以了 !

On some architectures other than the PC, I/O shared memory cannot be accessed by
simply dereferencing the linear address pointing to the physical memory location.
should be used when accessing I/O shared memory:
```c
readb(), readw(), readl()
/* Reads 1, 2, or 4 bytes, respectively, from an I/O shared memory location */
writeb(), writew(), writel()
/* Writes 1, 2, or 4 bytes, respectively, into an I/O shared memory location */
memcpy_fromio(), memcpy_toio()
/* Copies a block of data from an I/O shared memory location to dynamic memory and vice versa */
memset_io()
/* Fills an I/O shared memory area with a fixed value */
```

调查一下 VM_IOREMAP 以及相关的内容:

```c
#define VM_IOREMAP		0x00000001	/* ioremap() and friends */
```

## Linux Device Driver : Communicating with Hardware : 9.5 Using I/O Memory

Despite the popularity of I/O ports in the **x86** world, the main mechanism used to
communicate with devices is through *memory-mapped registers and device memory*.
**Both** are called I/O memory because the difference between registers and memory is transparent to software.


Depending on the computer platform and bus being used, I/O memory may or may
not be accessed through **page tables**. When access passes though page tables, the
kernel must first arrange for the physical address to be visible from your driver, and
this usually means that you must call **ioremap** before doing any I/O. If no page tables
are needed, I/O memory locations lookpretty much like I/O ports, and you can just
read and write to them using proper wrapper functions.

Whether or not ioremap is required to access I/O memory, direct use of pointers to I/O
memory is discouraged.

#### 9.5.1 I/O Memory Allocation and Mapping
All I/O memory allocations are listed in `/proc/iomem`.

在 64 位系统上，我不知道为什么只有其中映射范围只有 32b 的长度

```txt
#define __request_mem_region(start,n,name, excl) __request_region(&iomem_resource, (start), (n), (name), excl)
```


Allocation of I/O memory is not the only required step before that memory may be
accessed. You must also ensure that this I/O memory has been made accessible to the
kernel. Getting at I/O memory is not just a matter of dereferencing a pointer; on many
systems, I/O memory is not directly accessible in this way at all. So a mapping must
be set up first. This is the role of the `ioremap` function.
> 首先 分配，然后映射

```c
// 这些函数架构相关
void *ioremap(unsigned long phys_addr, unsigned long size);
void *ioremap_nocache(unsigned long phys_addr, unsigned long size);
void iounmap(void * addr);


/*
 * The default ioremap() behavior is non-cached:
 */
static inline void __iomem *ioremap(resource_size_t offset, unsigned long size)
{
	return ioremap_nocache(offset, size);
}
```
> cache 到底是指什么东西 ?



#### 9.5.2 Accessing I/O Memory
On some platforms, you may get away with using the return value from ioremap as a
pointer. Such use is not portable, and, increasingly, the kernel developers have been
working to eliminate any such use

```txt
void *ioport_map(unsigned long port, unsigned int count);
```

These functions make I/O ports look like memory. Do note, however, that the I/O
ports must still be allocated with `request_region` before they can be remapped in this
way.


#### 9.5.3 Reusing short for I/O Memory
> 利用之前的 short 重新操作

#### 9.5.4 ISA Memory Below 1 MB
One of the most well-known I/O memory regions is the ISA range found on personal computers. This is the memory range between 640 KB (0xA0000) and 1 MB
(0x100000).

## ioremap 的初始化
- kernel-inside 中的整理一下

# Kernel entry point
> 从本 section 开始分析 start_kernel 函数

Before the first process will be started, the start_kernel must do many things such as: to enable lock validator, to initialize processor id, to enable early cgroups subsystem, to setup per-cpu areas, to initialize different caches in vfs, to initialize memory manager, rcu, vmalloc, scheduler, IRQs, ACPI and many many more.

The next function after the `set_task_stack_end_magic` is `smp_setup_processor_id`


> @todo cpumask 在此处被分析过!

The next step is architecture-specific initialization. The Linux kernel does it with the call of the setup_arch function.


```c
/*
 * Determine if we were loaded by an EFI loader.  If so, then we have also been
 * passed the efi memmap, systab, etc., so we should use these data structures
 * for initialization.  Note, the efi init code path is determined by the
 * global efi_enabled. This allows the same kernel image to be used on existing
 * systems (with a traditional BIOS) as well as on EFI systems.
 */
/*
 * setup_arch - architecture-specific boot-time initializations
 *
 * Note: On x86_64, fixmaps are ready for use even before this is called.
 */

void __init setup_arch(char **cmdline_p)
```

This function starts from the reserving memory block for the kernel `_text` and `_data` which starts from the `_text` symbol and ends before `__bss_stop`

In the next step after we reserved place for the kernel text and data is reserving place for the initrd. We will not see details about initrd in this post, you just may know that it is temporary root file system
> initrd 的作用没有看
> @todo 为什么需要为这些东西 resever memory

Here are two similar functions `set_intr_gate_ist` and `set_system_intr_gate_ist`. Both of these two functions take three parameters:
1. number of the interrupt;
2. base address of the interrupt/exception handler;
3. third parameter is - Interrupt Stack Table. IST is a`new mechanism in the x86_`64 and part of the TSS. Every active thread in kernel mode has own kernel stack which is 16 kilobytes. While a thread in user space, this kernel stack is empty.

```c
	idt_setup_early_traps(); // 相对于原来的 idt 添加了两条新的handler `#DB and #BP 并且分析了#DB's han`dler
```
> @todo 只是添加了两条指令，为什么还需要重新 load idt

The next step is initialization of early ioremap. In general there are two ways to communicate with devices:
1. I/O Ports;
2. Device memory.

> 当前还是在 setup_arch 中间的:
> @todo 现在唯一需要知道的就是此处处理的过 ioremap



```c
	ROOT_DEV = old_decode_dev(boot_params.hdr.root_dev); // @todo 神奇的启动参数，所以谁来获取这一个数值的，grub 吗 ? 如何保证grub 和 内核使用相同的数值描述数值
```

All information about registered resources are available through:
1. /proc/ioports - provides a list of currently registered port regions used for input or output communication with a device;
2. /proc/iomem - provides current map of the system's memory for each physical device.

```c
	e820__memory_setup(); // 在此处完成 ioremap 初始化的工作
```

The next two steps is parsing of the setup_data with `parse_setup_data` function and copying BIOS EDD to the safe place. setup_data is a field from the kernel boot header and as we can read from the x86 boot protocol:


> Memory descriptor initialization

```c
	if (!boot_params.hdr.root_flags)
		root_mountflags &= ~MS_RDONLY;
	init_mm.start_code = (unsigned long) _text;
	init_mm.end_code = (unsigned long) _etext;
	init_mm.end_data = (unsigned long) _edata;
	init_mm.brk = _brk_end;

	mpx_mm_init(&init_mm);

	code_resource.start = __pa_symbol(_text);
	code_resource.end = __pa_symbol(_etext)-1;
	data_resource.start = __pa_symbol(_etext);
	data_resource.end = __pa_symbol(_edata)-1;
	bss_resource.start = __pa_symbol(__bss_start);
	bss_resource.end = __pa_symbol(__bss_stop)-1;
```

> @todo track the bss_resource, 似乎和 ioremap 有关联

## 其他资料
4. https://lwn.net/Articles/653585/ 实际上，使用不是 mmap 而是 ioremap 完成的工作

[^25]: [kernelnewbies : ioremap vs mmap](https://lists.kernelnewbies.org/pipermail/kernelnewbies/2016-September/016814.html)

## cat /proc/iomap 的实现

## 这里有好多内容是看不懂的

```txt
sudo cat /proc/iomem
[sudo] password for martins3:
00000000-00000fff : Reserved
00001000-0009dfff : System RAM
0009e000-0009efff : Reserved
0009f000-0009ffff : System RAM
000a0000-000fffff : Reserved
  000a0000-000bffff : PCI Bus 0000:00
  00000000-00000000 : PCI Bus 0000:00
  00000000-00000000 : PCI Bus 0000:00
  00000000-00000000 : PCI Bus 0000:00
  000e0000-000effff : PCI Bus 0000:00
  000f0000-000fffff : System ROM
00100000-5ed4b017 : System RAM
  4e000000-55ffffff : Crash kernel
5ed4b018-5ed5a057 : System RAM
5ed5a058-63e5dfff : System RAM
63e5e000-63e5efff : Reserved
63e5f000-63e9bfff : System RAM
63e9c000-63e9cfff : Reserved
63e9d000-6b60bfff : System RAM
6b60c000-6b9d8fff : Reserved
6b9d9000-6dc60fff : System RAM
6dc61000-6dc61fff : Reserved
6dc62000-70560fff : System RAM
70561000-74260fff : Reserved
74261000-744b0fff : ACPI Tables
744b1000-7471efff : ACPI Non-volatile Storage
7471f000-75ffefff : Reserved
75fff000-75ffffff : System RAM
76000000-79ffffff : Reserved
7a400000-7a7fffff : Reserved
7b000000-807fffff : Reserved
  7c800000-807fffff : Graphics Stolen Memory
80800000-bfffffff : PCI Bus 0000:00
  80800000-80800fff : 0000:00:1f.5
    80800000-80800fff : 0000:00:1f.5 0000:00:1f.5
  82000000-83ffffff : 0000:00:0e.0
    82000000-83ffffff : VMD MEMBAR1
  84000000-849fffff : PCI Bus 0000:03
  84a00000-84bfffff : PCI Bus 0000:04
    84a00000-84afffff : 0000:04:00.0
      84a00000-84afffff : igc
    84b00000-84b03fff : 0000:04:00.0
      84b00000-84b03fff : igc
  84c00000-84cfffff : PCI Bus 0000:02
    84c00000-84c03fff : 0000:02:00.0
      84c00000-84c03fff : nvme
    84c04000-84c0ffff : 0000:02:00.0
  84d00000-84dfffff : PCI Bus 0000:01
    84d00000-84d1ffff : 0000:01:00.0
    84d20000-84d2ffff : 0000:01:00.0
      84d20000-84d2ffff : nvme
    84d30000-84d33fff : 0000:01:00.0
      84d30000-84d33fff : nvme
    84d34000-84db3fff : 0000:01:00.0
  84e00000-84e01fff : 0000:00:17.0
    84e00000-84e01fff : ahci
  84e02000-84e027ff : 0000:00:17.0
    84e02000-84e027ff : ahci
  84e03000-84e030ff : 0000:00:17.0
    84e03000-84e030ff : ahci
c0000000-cfffffff : PCI MMCONFIG 0000 [bus 00-ff]
  c0000000-cfffffff : Reserved
e0690000-e069ffff : INTC1056:00
  e0690000-e069ffff : INTC1056:00 INTC1056:00
e06a0000-e06affff : INTC1056:00
  e06a0000-e06affff : INTC1056:00 INTC1056:00
e06b0000-e06bffff : INTC1056:00
  e06b0000-e06bffff : INTC1056:00 INTC1056:00
e06d0000-e06dffff : INTC1056:00
  e06d0000-e06dffff : INTC1056:00 INTC1056:00
e06e0000-e06effff : INTC1056:00
  e06e0000-e06effff : INTC1056:00 INTC1056:00
fe000000-fe010fff : Reserved
fec00000-fec00fff : Reserved
  fec00000-fec003ff : IOAPIC 0
fed00000-fed00fff : Reserved
  fed00000-fed003ff : HPET 0
    fed00000-fed003ff : PNP0103:00
fed20000-fed7ffff : Reserved
  fed40000-fed44fff : MSFT0101:00
    fed40000-fed44fff : MSFT0101:00
fed90000-fed90fff : dmar0
fed91000-fed91fff : dmar1
feda0000-feda0fff : pnp 00:04
feda1000-feda1fff : pnp 00:04
fedc0000-fedc7fff : pnp 00:04
fee00000-fee00fff : Local APIC
  fee00000-fee00fff : Reserved
ff000000-ffffffff : Reserved
100000000-107f7fffff : System RAM
  d3f000000-d3fc01a87 : Kernel code
  d3fe00000-d40587fff : Kernel rodata
  d40600000-d4083607f : Kernel data
  d40da4000-d40ffffff : Kernel bss
107f800000-107fffffff : RAM buffer
4000000000-7fffffffff : PCI Bus 0000:00
  4000000000-400fffffff : 0000:00:02.0
  4010000000-4016ffffff : 0000:00:02.0
  4017000000-40171fffff : PCI Bus 0000:03
  4017200000-4017200fff : 0000:00:15.0
    4017200000-40172001ff : lpss_dev
      4017200000-40172001ff : i2c_designware.0 lpss_dev
    4017200200-40172002ff : lpss_priv
    4017200800-4017200fff : idma64.0
      4017200800-4017200fff : idma64.0 idma64.0
  4017201000-4017201fff : 0000:00:15.1
    4017201000-40172011ff : lpss_dev
      4017201000-40172011ff : i2c_designware.1 lpss_dev
    4017201200-40172012ff : lpss_priv
    4017201800-4017201fff : idma64.1
      4017201800-4017201fff : idma64.1 idma64.1
  4017202000-4017202fff : 0000:00:15.2
    4017202000-40172021ff : lpss_dev
      4017202000-40172021ff : i2c_designware.2 lpss_dev
    4017202200-40172022ff : lpss_priv
    4017202800-4017202fff : idma64.2
      4017202800-4017202fff : idma64.2 idma64.2
  4020000000-40ffffffff : 0000:00:02.0
  6000000000-6001ffffff : 0000:00:0e.0
  6002000000-6002ffffff : 0000:00:02.0
  6003000000-60030fffff : 0000:00:1f.3
  6003100000-60031fffff : 0000:00:0e.0
    6003102000-60031fffff : VMD MEMBAR2
  6003200000-600320ffff : 0000:00:14.0
    6003200000-600320ffff : xhci-hcd
  6003210000-6003217fff : 0000:00:0a.0
    6003214000-6003214d9f : telem0
    6003214da0-6003214edf : telem1
    60032164d8-60032164e7 : intel_vsec.telemetry.0
    60032164e8-60032164f7 : intel_vsec.telemetry.0
    60032164f8-6003216507 : intel_vsec.telemetry.0
    6003216508-6003216517 : intel_vsec.telemetry.0
  6003218000-600321bfff : 0000:00:1f.3
    6003218000-600321bfff : ICH HD audio
  600321c000-600321ffff : 0000:00:14.3
    600321c000-600321ffff : iwlwifi
  6003220000-6003223fff : 0000:00:14.2
  6003224000-60032240ff : 0000:00:1f.4
  6003225000-6003225fff : 0000:00:16.0
    6003225000-6003225fff : mei_me
  6003229000-6003229fff : 0000:00:14.2
mem-oc/wss on  master [+?] via C v11.3.0-gcc via 🐍 v3.9.15 took 2s
```
