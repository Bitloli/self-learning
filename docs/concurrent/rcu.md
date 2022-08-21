# RCU

- [ ] 思考一下，RCU 在用户态和内核态中实现的差异
- [ ] 将 QEMU 中对于 RCU 的使用移动到这里
- [ ] https://liburcu.org/ : 提供了三个很好的资源
- https://mp.weixin.qq.com/s/SZqmxMGMyruYUH5n_kobYQ
- https://hackmd.io/@sysprog/linux-rcu?type=view
- `__d_lookup_rcu`
  - 实际上，rcu 的组件比想想的更加多

## What is Rcu

```c
// if debug config is closed
static __always_inline void rcu_read_lock(void)
{
  __rcu_read_lock(); // preempt_disable();
  // NO !!!!!!!!!!!!! this is impossible
}

#define rcu_assign_pointer(p, v)                          \
do {                                          \
    uintptr_t _r_a_p__v = (uintptr_t)(v);                     \
                                          \
    if (__builtin_constant_p(v) && (_r_a_p__v) == (uintptr_t)NULL)        \
        WRITE_ONCE((p), (typeof(p))(_r_a_p__v));              \
    else                                      \
        smp_store_release(&p, RCU_INITIALIZER((typeof(p))_r_a_p__v)); \
} while (0)

void synchronize_rcu(void)
{
    RCU_LOCKDEP_WARN(lock_is_held(&rcu_bh_lock_map) ||
             lock_is_held(&rcu_lock_map) ||
             lock_is_held(&rcu_sched_lock_map),
             "Illegal synchronize_rcu() in RCU read-side critical section");
    if (rcu_blocking_is_gp())
        return;
    if (rcu_gp_is_expedited())
        synchronize_rcu_expedited();
    else
        wait_rcu_gp(call_rcu);
}
```

## SRCU
e.g., `kvm_mmu_notifier_invalidate_range_start`

sleepable rcu

## 中断也是和 RCU 相关的
```c
void irq_exit(void)
{
#ifndef __ARCH_IRQ_EXIT_IRQS_DISABLED
    local_irq_disable();
#else
    lockdep_assert_irqs_disabled();
#endif
    account_irq_exit_time(current);
    preempt_count_sub(HARDIRQ_OFFSET);
    if (!in_interrupt() && local_softirq_pending())
        invoke_softirq(); ==================================》 __do_softirq

    tick_irq_exit();
    rcu_irq_exit();
    trace_hardirq_exit(); /* must be last! */
}
```
调用了 `rcu_irq_exit`

## 同时 DPDK 中间也是有 RCU 的: https://doc.dpdk.org/guides/prog_guide/rcu_lib.html

## kernel functions
- [ ] `rcu_read_lock_bh` ：使用 ./hack/iperf.svg 中可以参考，就是因为在此处

## 读读 LoyenWang 的 blog

###  https://www.cnblogs.com/LoyenWang/p/12681494.html

- [ ] 没有优先级反转的问题；
- [ ] 当使用不可抢占的 RCU 时，`rcu_read_lock`/`rcu_read_unlock`之间不能使用可以睡眠的代码
  - [ ] 什么代码会导致睡眠?

### https://www.cnblogs.com/LoyenWang/p/12770878.html

- [ ] 为什么需要组织成为 tree 的啊?

### 代码分析

softirq：
1. 时钟中断的时候
```txt
invoke_rcu_core+1
rcu_sched_clock_irq+497
update_process_times+147
tick_sched_handle+34
tick_sched_timer+109
__hrtimer_run_queues+298
hrtimer_interrupt+262
__sysvec_apic_timer_interrupt+127
sysvec_apic_timer_interrupt+157
asm_sysvec_apic_timer_interrupt+18
native_safe_halt+11
default_idle+10
default_idle_call+50
do_idle+478
cpu_startup_entry+25
start_secondary+278
secondary_startup_64_no_verify+213
```

2. 中断结束的位置开始执行 softirq 的
```txt
rcu_core_si+1
__softirqentry_text_start+238
__irq_exit_rcu+181
sysvec_apic_timer_interrupt+162
asm_sysvec_apic_timer_interrupt+18
native_safe_halt+11
default_idle+10
default_idle_call+50
do_idle+478
cpu_startup_entry+25
start_secondary+278
secondary_startup_64_no_verify+213
```
- 为什么 `__irq_exit_rcu` 会调用到 `__softirqentry_text_start`，是 backtrace 的 bug 吧！

## 使用 QEMU 调试的过程中，Guest 首先一致卡在 idel 中，然后触发这个 bug
```c
[ 4192.186591] rcu: INFO: rcu_preempt detected stalls on CPUs/tasks:
[ 4192.187264]  (detected by 7, t=42141 jiffies, g=10393, q=61 ncpus=8)
[ 4192.187264] rcu: All QSes seen, last rcu_preempt kthread activity 42025 (4298858205-4298816180), jiffies_till_next_fqs=3, root ->qsmask 0x0
[ 4192.187264] rcu: rcu_preempt kthread timer wakeup didn't happen for 42031 jiffies! g10393 f0x2 RCU_GP_WAIT_FQS(5) ->state=0x200
[ 4192.187264] rcu:     Possible timer handling issue on cpu=1 timer-softirq=2124
[ 4192.187264] rcu: rcu_preempt kthread starved for 42048 jiffies! g10393 f0x2 RCU_GP_WAIT_FQS(5) ->state=0x200 ->cpu=1
[ 4192.187264] rcu:     Unless rcu_preempt kthread gets sufficient CPU time, OOM is now expected behavior.
[ 4192.187264] rcu: RCU grace-period kthread stack dump:
[ 4192.187264] task:rcu_preempt     state:R stack:14976 pid:   14 ppid:     2 flags:0x00004000
[ 4192.187264] Call Trace:
[ 4192.187264]  <TASK>
[ 4192.187264]  __schedule+0x2a4/0x7a0
[ 4192.187264]  ? rcu_gp_cleanup+0x4f0/0x4f0
[ 4192.187264]  schedule+0x55/0xa0
[ 4192.187264]  schedule_timeout+0x83/0x150
[ 4192.187264]  ? _raw_spin_unlock_irqrestore+0x16/0x30
[ 4192.187264]  ? timer_migration_handler+0x90/0x90
[ 4192.187264]  rcu_gp_fqs_loop+0x129/0x5d0
[ 4192.187264]  rcu_gp_kthread+0x19b/0x240
[ 4192.187264]  kthread+0xe0/0x110
[ 4192.187264]  ? kthread_complete_and_exit+0x20/0x20
[ 4192.187264]  ret_from_fork+0x1f/0x30
[ 4192.187264]  </TASK>
[ 4192.187264] rcu: Stack dump where RCU GP kthread last ran:
[ 4192.187264] Sending NMI from CPU 7 to CPUs 1:
[ 4150.290203] NMI backtrace for cpu 1 skipped: idling at default_idle+0xb/0x10
[ 4213.292264] rcu: INFO: rcu_preempt detected stalls on CPUs/tasks:
[ 4213.293260]  (detected by 0, t=63241 jiffies, g=10393, q=151 ncpus=8)
[ 4213.293260] rcu: All QSes seen, last rcu_preempt kthread activity 63126 (4298879306-4298816180), jiffies_till_next_fqs=3, root ->qsmask 0x0
[ 4213.293260] rcu: rcu_preempt kthread timer wakeup didn't happen for 63133 jiffies! g10393 f0x2 RCU_GP_WAIT_FQS(5) ->state=0x200
[ 4213.293260] rcu:     Possible timer handling issue on cpu=1 timer-softirq=2124
[ 4213.293260] rcu: rcu_preempt kthread starved for 63151 jiffies! g10393 f0x2 RCU_GP_WAIT_FQS(5) ->state=0x200 ->cpu=1
[ 4213.293260] rcu:     Unless rcu_preempt kthread gets sufficient CPU time, OOM is now expected behavior.
[ 4213.293260] rcu: RCU grace-period kthread stack dump:
[ 4213.293260] task:rcu_preempt     state:R stack:14976 pid:   14 ppid:     2 flags:0x00004000
[ 4213.293260] Call Trace:
[ 4213.293260]  <TASK>
[ 4213.293260]  __schedule+0x2a4/0x7a0
[ 4213.293260]  ? rcu_gp_cleanup+0x4f0/0x4f0
[ 4213.293260]  schedule+0x55/0xa0
[ 4213.293260]  schedule_timeout+0x83/0x150
[ 4213.293260]  ? _raw_spin_unlock_irqrestore+0x16/0x30
[ 4213.293260]  ? timer_migration_handler+0x90/0x90
[ 4213.293260]  rcu_gp_fqs_loop+0x129/0x5d0
[ 4213.293260]  rcu_gp_kthread+0x19b/0x240
[ 4213.293260]  kthread+0xe0/0x110
[ 4213.293260]  ? kthread_complete_and_exit+0x20/0x20
[ 4213.293260]  ret_from_fork+0x1f/0x30
[ 4213.293260]  </TASK>
[ 4213.293260] rcu: Stack dump where RCU GP kthread last ran:
[ 4213.293260] Sending NMI from CPU 0 to CPUs 1:
[ 4192.297288] NMI backtrace for cpu 1 skipped: idling at default_idle+0xb/0x10
```


### 参考资料
- [What is RCU, Fundamentally?](https://lwn.net/Articles/262464/)
- [What is RCU? Part 2: Usage](https://lwn.net/Articles/263130/)
- [RCU part 3: the RCU API](https://lwn.net/Articles/264090/)
- [kernel doc](https://www.kernel.org/doc/Documentation/RCU/)
