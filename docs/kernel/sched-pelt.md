# pelt

## 主要参考

https://www.cnblogs.com/LoyenWang/p/12316660.html

## 问题
- [ ] 如果 pelt 不是必须的，其替代是什么?

计算 /proc/loadavg 的方法:

1. 两个函数来统计，分别处理 hz 和 nohz 的情况，使用 calc_load_fold_active
```txt
#0  calc_load_fold_active (adjust=0, this_rq=0xffff88807dc2b2c0) at kernel/sched/build_utility.c:3245
#1  calc_load_nohz_fold (rq=0xffff88807dc2b2c0) at kernel/sched/build_utility.c:3399
#2  calc_load_nohz_start () at kernel/sched/build_utility.c:3413
#3  0xffffffff811a7389 in tick_nohz_stop_tick (cpu=0, ts=0xffff88807dc1e5c0) at kernel/time/tick-sched.c:913
#4  __tick_nohz_idle_stop_tick (ts=0xffff88807dc1e5c0) at kernel/time/tick-sched.c:1108
#5  tick_nohz_idle_stop_tick () at kernel/time/tick-sched.c:1129
#6  0xffffffff8114b0e8 in cpuidle_idle_call () at kernel/sched/build_policy.c:231
#7  do_idle () at kernel/sched/build_policy.c:345
#8  0xffffffff8114b324 in cpu_startup_entry (state=state@entry=CPUHP_ONLINE) at kernel/sched/build_policy.c:442
#9  0xffffffff81f383ab in rest_init () at init/main.c:727
#10 0xffffffff8330dc05 in arch_call_rest_init () at init/main.c:883
#11 0xffffffff8330e27d in start_kernel () at init/main.c:1138
#12 0xffffffff81000145 in secondary_startup_64 () at arch/x86/kernel/head_64.S:358
#13 0x0000000000000000 in ?? ()
```

```txt
#0  calc_load_nohz_start () at kernel/sched/build_utility.c:3413
#1  0xffffffff811a7389 in tick_nohz_stop_tick (cpu=3, ts=0xffff88813dd1e5c0) at kernel/time/tick-sched.c:913
#2  __tick_nohz_idle_stop_tick (ts=0xffff88813dd1e5c0) at kernel/time/tick-sched.c:1108
#3  tick_nohz_idle_stop_tick () at kernel/time/tick-sched.c:1129
#4  0xffffffff8114b0e8 in cpuidle_idle_call () at kernel/sched/build_policy.c:231
#5  do_idle () at kernel/sched/build_policy.c:345
#6  0xffffffff8114b324 in cpu_startup_entry (state=state@entry=CPUHP_AP_ONLINE_IDLE) at kernel/sched/build_policy.c:442
#7  0xffffffff810e0518 in start_secondary (unused=<optimized out>) at arch/x86/kernel/smpboot.c:262
#8  0xffffffff81000145 in secondary_startup_64 () at arch/x86/kernel/head_64.S:358
#9  0x0000000000000000 in ?? ()
```

2. 进行统计
```txt
#0  calc_global_load () at kernel/sched/build_utility.c:3516
#1  0xffffffff811a6d0a in tick_do_update_jiffies64 (now=<optimized out>) at kernel/time/tick-sched.c:148
#2  tick_do_update_jiffies64 (now=<optimized out>) at kernel/time/tick-sched.c:57
#3  0xffffffff811a7897 in tick_nohz_restart_sched_tick (now=389458267506, ts=0xffff88813dd1e5c0) at kernel/time/tick-sched.c:962
#4  tick_nohz_idle_update_tick (now=389458267506, ts=0xffff88813dd1e5c0) at kernel/time/tick-sched.c:1315
#5  tick_nohz_idle_exit () at kernel/time/tick-sched.c:1349
#6  0xffffffff8114b044 in do_idle () at kernel/sched/build_policy.c:358
#7  0xffffffff8114b324 in cpu_startup_entry (state=state@entry=CPUHP_AP_ONLINE_IDLE) at kernel/sched/build_policy.c:442
#8  0xffffffff810e0518 in start_secondary (unused=<optimized out>) at arch/x86/kernel/smpboot.c:262
#9  0xffffffff81000145 in secondary_startup_64 () at arch/x86/kernel/head_64.S:358
#10 0x0000000000000000 in ?? ()
```

- calc_global_load 调用 calc_global_nohz，同时处理两种情况的数据。


```txt
0  0xffffffff8114d371 in accumulate_sum (running=<optimized out>, runnable=<optimized out>, load=<optimized out>, sa=<optimized out>, delta=<optimized out>) at kernel/sched/build_policy.c:4029
#1  ___update_load_sum (running=1, runnable=<optimized out>, load=1, sa=0xffff8881485f5b40, now=390223811783) at kernel/sched/build_policy.c:4150
#2  __update_load_avg_se (now=now@entry=390223811783, cfs_rq=cfs_rq@entry=0xffff88813dc2b340, se=se@entry=0xffff8881485f5a80) at kernel/sched/build_policy.c:4232
#3  0xffffffff811404d4 in update_load_avg (cfs_rq=0xffff88813dc2b340, se=0xffff8881485f5a80, flags=1) at kernel/sched/fair.c:4018
#4  0xffffffff81142322 in entity_tick (queued=0, curr=0xffff8881485f5a80, cfs_rq=0xffff88813dc2b340) at kernel/sched/fair.c:4740
#5  task_tick_fair (rq=0xffff88813dc2b2c0, curr=0xffff8881485f5a00, queued=0) at kernel/sched/fair.c:11416
#6  0xffffffff8113c7c9 in scheduler_tick () at kernel/sched/core.c:5453
#7  0xffffffff811946d1 in update_process_times (user_tick=0) at kernel/time/timer.c:1844
#8  0xffffffff811a6c7f in tick_sched_handle (ts=ts@entry=0xffff88813dc1e5c0, regs=regs@entry=0xffffc900014e3b28) at kernel/time/tick-sched.c:243
#9  0xffffffff811a6e5c in tick_sched_timer (timer=0xffff88813dc1e5c0) at kernel/time/tick-sched.c:1480
#10 0xffffffff81195205 in __run_hrtimer (flags=2, now=0xffffc9000012cf48, timer=0xffff88813dc1e5c0, base=0xffff88813dc1e0c0, cpu_base=0xffff88813dc1e080) at kernel/time/hrtimer.c:1685
#11 __hrtimer_run_queues (cpu_base=cpu_base@entry=0xffff88813dc1e080, now=389462153629, flags=flags@entry=2, active_mask=active_mask@entry=15) at kernel/time/hrtimer.c:1749
#12 0xffffffff81195e91 in hrtimer_interrupt (dev=<optimized out>) at kernel/time/hrtimer.c:1811
#13 0xffffffff810e256a in local_apic_timer_interrupt () at arch/x86/kernel/apic/apic.c:1095
#14 __sysvec_apic_timer_interrupt (regs=<optimized out>) at arch/x86/kernel/apic/apic.c:1112
#15 0xffffffff81f371fd in sysvec_apic_timer_interrupt (regs=0xffffc900014e3b28) at arch/x86/kernel/apic/apic.c:1106
```

- [Per-entity load tracking](https://lwn.net/Articles/531853/)

[Load tracking in the scheduler](https://lwn.net/Articles/639543/)
- The CFS algorithm defines a time duration called the "scheduling period," during which every runnable task on the CPU should run at least once.
- A group of tasks is called a "scheduling entity" in the kernel.

*If a CPU is associated with a number C that represents its ability to process tasks (let's call it "capacity"), then the load of a process is a metric that is expressed in units of C, indicating the number of such CPUs required to make satisfactory progress on its job. This number could also be a fraction of C, in which case it indicates that a single such CPU is good enough. The load of a process is important in scheduling because, besides influencing the time that a task spends running on the CPU, it helps to estimate overall CPU load, which is required during load balancing.

The question is how to estimate the load of a process. Should it be set statically or should it be set dynamically at run time based on the behavior of the process? Either way, how should it be calculated? There have been significant efforts at answering these questions in the recent past. As a consequence, the number of load-tracking metrics has grown significantly and load estimation itself has gotten quite complex.*

- [ ] what's relation with `load`, `priority` , `weight` and `share` ?

how and when groups of tasks are created:
1. Users may use the control group ("cgroup") infrastructure to partition system resources between tasks. Tasks belonging to a cgroup are associated with a group in the scheduler (if the scheduler controller is attached to the group).
2. When a new session is created through the `set_sid()` system call. All tasks belonging to a specific session also belong to the same scheduling group. This feature is enabled when CONFIG_SCHED_AUTOGROUP is set in the kernel configuration.
3. a single task becomes a scheduling entity on its own.

**Each scheduling entity contains a run queue**, the parent run queue on which a scheduling entity is queued is represented by `cfs_rq`, while the run queue that it owns is represented by `my_rq` in the `sched_entity` data structure.
```c
struct sched_entity {
	/* rq on which this entity is (to be) queued: */
	struct cfs_rq			*cfs_rq;
	/* rq "owned" by this entity/group: */
	struct cfs_rq			*my_q;
```
For every CPU c, a given `task_group` tg has a `sched_entity` called se and a run queue `cfs_rq` associated with it.

Any given task's time slice is dependent on its priority and the number of tasks on the run queue. The priority of a task is a number that represents its importance; **it is represented in the kernel by a number between zero and 139.**

But the priority value by itself is not helpful to the scheduler, *which also needs to know the load of the task to estimate its time slice.*
As mentioned above, the load must be the multiple of the capacity of a standard CPU that is required to make satisfactory progress on the task. Hence this priority number must be mapped to such a value; this is done in the array `prio_to_weight[]`.

A priority number of 120, which is the priority of a normal task, is mapped to a load of 1024, which is the value that the kernel uses to represent the capacity of a single standard CPU.
```c
/*
 * Nice levels are multiplicative, with a gentle 10% change for every
 * nice level changed. I.e. when a CPU-bound task goes from nice 0 to
 * nice 1, it will get ~10% less CPU time than another CPU-bound task
 * that remained on nice 0.
 *
 * The "10% effect" is relative and cumulative: from _any_ nice level,
 * if you go up 1 level, it's -10% CPU usage, if you go down 1 level
 * it's +10% CPU usage. (to achieve that we use a multiplier of 1.25.
 * If a task goes up by ~10% and another task goes down by ~10% then
 * the relative distance between them is ~25%.)
 */
const int sched_prio_to_weight[40] = {
 /* -20 */     88761,     71755,     56483,     46273,     36291,
 /* -15 */     29154,     23254,     18705,     14949,     11916,
 /* -10 */      9548,      7620,      6100,      4904,      3906,
 /*  -5 */      3121,      2501,      1991,      1586,      1277,
 /*   0 */      1024,       820,       655,       526,       423,
 /*   5 */       335,       272,       215,       172,       137,
 /*  10 */       110,        87,        70,        56,        45,
 /*  15 */        36,        29,        23,        18,        15,
};
```

```c
/*
 * Task weight (visible to users) and its load (invisible to users) have
 * independent resolution, but they should be well calibrated. We use
 * scale_load() and scale_load_down(w) to convert between them. The
 * following must be true:
 *
 *  scale_load(sched_prio_to_weight[USER_PRIO(NICE_TO_PRIO(0))]) == NICE_0_LOAD
 *
 */
#define NICE_0_LOAD		(1L << NICE_0_LOAD_SHIFT)

/*
 * 'User priority' is the nice value converted to something we
 * can work with better when scaling various scheduler parameters,
 * it's a [ 0 ... 39 ] range.
 */
#define USER_PRIO(p)		((p)-MAX_RT_PRIO)

/*
 * Convert user-nice values [ -20 ... 0 ... 19 ]
 * to static priority [ MAX_RT_PRIO..MAX_PRIO-1 ],
 * and back.
 */
#define NICE_TO_PRIO(nice)	((nice) + DEFAULT_PRIO)
```
- [x] It's reasonable, nice value is friendly to user, but it doesn't provide proper granularity.

> man nice(2)
> with -20 being the highest priority and 19 being the lowest priority.

- [ ] what's nice of rt thread ?

A run queue (struct cfs_rq) is also characterized by a "weight" value that is the accumulation of weights of all tasks on its run queue.

The lowest vruntime found in the queue is stored in `cfs_rq.min_vruntime`. When a new task is picked to run, the leftmost node of the red-black tree is chosen since that task has had the least running time on the CPU. *Each time a new task forks or a task wakes up, its vruntime is assigned to a value that is the maximum of its last updated value and cfs_rq.min_vruntime.* If not for this, its vruntime would be very small as an effect of not having run for a long time (or at all) and would take an unacceptably long time to catch up to the vruntime of its sibling tasks and hence starve them of CPU time.

Every periodic tick, the vruntime of the currently-running task is updated as follows:
```c
    vruntime += delta_exec * (NICE_0_LOAD/curr->load.weight);
```


The load of a CPU could have simply been the sum of the load of all the scheduling entities running on its run queue.
In fact, that was once all there was to it.
This approach has a disadvantage, though, in that tasks are associated with load values based only on their priorities.
This approach does not take into account the nature of a task, such as whether it is a bursty or a steady task, or whether it is a CPU-intensive or an I/O-bound task.
*While this does not matter for scheduling within a CPU, it does matter when load balancing across CPUs because it helps estimate the CPU load more accurately.*


Therefore the per-entity load tracking metric was introduced to estimate the nature of a task numerically.
**This metric calculates task load as the amount of time that the task was runnable during the time that it was alive.**
This is kept track of in the `sched_avg` data structure (stored in the `sched_entity` structure):

Given a task p, if the `sched_entity` associated with it is se and the `sched_avg` of se is sa, then:
```plain
sa.load_avg_contrib = (sa.runnable_sum * se.load.weight) / sa.runnable_period;
```
where `runnable_sum` is the amount of time that the task was runnable, `runnable_period` is the period during which the task could have been runnable.

The load on a CPU is the sum of the `load_avg_contrib` of all the scheduling entities on its run queue;
it is accumulated in a field called `runnable_load_avg` in the `cfs_rq` data structure.
This is roughly a measure of how heavily contended the CPU is. The kernel also tracks the load associated with blocked tasks. When a task gets blocked, its load is accumulated in the blocked_load_avg metric of the cfs_rq structure.

- [ ] [Per-entity load tracking in presence of task groups](https://lwn.net/Articles/639543/) : Continue the reading if other parts finished.
