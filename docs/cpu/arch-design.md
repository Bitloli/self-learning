## 如何设计一个成功的指令集架构

显然我的功力不足以真正的指导一个指令集架构的设计，感觉 10 年前是 X86 一家独大，但是如今指令集又有一种百家争鸣的感觉，工作学习中是不是和不同的指令集打交道，用这篇 blog 来整理一下自己在学习不同架构中的内容。

实现一个简单的 CPU 是不难的，如果仅仅包含运算指令，跳转指令，访存指令，其强度大约是本科生的大作业，但是能够跑起来 Linux 操作系统，就开始有点麻烦了，不过还好。
但是如果你的 CPU 可以:
- 在嵌入式平台中运行，这要求超低功耗。
- 可以在数据中心中运行，这要求虚拟化，高性能，多核。
- 可以在桌面电脑中运行，这要求视频编解码，软件生态。

这些要求让躺在 linux/arch 和 QEMU/target 下架构，除了 X86，ARM 和 RISC，大多死得悄无声息。


## 需要实现的内容

### SOC
- 主要要求实现 chipset

### 基础的库
- QEMU
- LibC

### 硬件虚拟化加速
能够支持 hyerpv, kvm, zen 等

### 编译器
需要以下的编译器的支持:
- LLVM / GCC
- JVM , LuaJit 和 .NET
- Rust / Golang

需要有:
- abi 定义
- elf 支持

### 高性能计算

### Linux 内核
让 MacOS 或者 Windows 这种大公司持有的闭源操作系统支持你的新架构，可能性实在是太小了。

- 内存: page walk, cache，TLB
- ebpf
- 中断，异常
- KVM
- idle driver
- init
- perf
- vdso
- memory model
- memory management
  - page table
  - ioremap
  - hugetlb
- ACPI
- 锁
- trace
  - krpoeb / uprobe
  - pmc : 要求 CPU 有硬件计数器
- kdump
- mmio
- kgdb
- context switch
  - `__switch_to`
- fork
  - `arch_dup_task_struct`
  - `copy_thread`
  - `ret_from_fork`
- boot
  - `setup_arch`
- signal
- 各种使用汇编写的库

### Firmware
- edk2
- acpica

## 架构设计需要考虑的点
- 指令是否定长，不定长会让译码很难做，但是对齐之后，加载一个 8 字节的指令需要多条指令。
- 如何避免指令的相关性。
- 那些是当前负载中经常出现的指令。
- 指令的复杂程度不是功耗的决定因素[^2]。
- 最精简的指令集只是需要一条[^3] [^4]。

- 在用户态执行的指令集和系统态执行的指令集不同。
- 不同的核执行的指令集不同[^5]。

### memory model

### cache coherence
- [ ] 如果 dma 修改了 memory ，如何同步到 cache 中去

### 外设
- 使用 memory mapped io 还是单独的 io 指令

### 物理版图

### 编译器
- 各种 built-in

### 加速
- SIMD 指令
- 加解密指令

### 二进制翻译

### 操作系统
- swap: 如何确定一个页面是否访问，到底是在 page table entry 上放一个 flags，还是使用 page fault 来实现。

### 兼容性

### 功耗

### 可靠性

### 成本

## TODO
- 测试 RISC-V 的用户态中断，硬件线程

## 参考资料
[^1] [riscv non isa](https://github.com/riscv-non-isa)
[^2] [Power Struggles: Revisiting the RISC vs. CISC Debate on Contemporary ARM and x86 Architectures](https://research.cs.wisc.edu/vertical/papers/2013/hpca13-isa-power-struggles.pdf)
[^3]: [One-instruction set computer](https://en.wikipedia.org/wiki/One-instruction_set_computer)
[^4]: https://en.wikipedia.org/wiki/No_instruction_set_computing
[^5]: A reconfigurable heterogeneous multicore with a homogeneous ISA
