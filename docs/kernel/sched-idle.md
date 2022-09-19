# Linux scheduelr

- https://mp.weixin.qq.com/s/0LM25OrpFCCcokSCMv--Mg
  - 大致分析 idle driver 的作用已经整个 idle 代码的流程

- cpuidle.off = 1

## 默认 idle
```txt
0  default_idle () at arch/x86/kernel/process.c:730
#1  0xffffffff81f46f0c in default_idle_call () at kernel/sched/idle.c:109
#2  0xffffffff8114b0ed in cpuidle_idle_call () at kernel/sched/idle.c:191
#3  do_idle () at kernel/sched/idle.c:303
#4  0xffffffff8114b324 in cpu_startup_entry (state=state@entry=CPUHP_AP_ONLINE_IDLE) at kernel/sched/idle.c:400
#5  0xffffffff810e0518 in start_secondary (unused=<optimized out>) at arch/x86/kernel/smpboot.c:262
#6  0xffffffff81000145 in secondary_startup_64 () at arch/x86/kernel/head_64.S:358
#7  0x0000000000000000 in ?? ()
```

- do_idle
  - cpu_idle_poll
    - cpu_relax : 使用 nop 指令
  - cpuidle_idle_call


- acpi_processor_setup_cstates
