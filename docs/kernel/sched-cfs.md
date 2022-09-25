- loyenwang
- wowo
- 奔跑
- man sched(7) 也是很不错的

- [ ] https://github.com/hamadmarri/cacule-cpu-scheduler : 新的一个 scheduler patch

# kernel/sched/fair.md
有点怀疑，cgroup 会将一组的 thread 的所有的资源统一管理的 ? 而不是存在一个 cgroup for mem , cgroup for cpu 之类的 ?

## 构建一些 backtrace 吧

#### pick_next_task_fair

```txt
#0  pick_next_task_fair (rq=rq@entry=0xffff88807dc2b2c0, prev=prev@entry=0xffffffff82a149c0 <init_task>, rf=rf@entry=0xffffffff82a03e90) at kernel/sched/fair.c:7363
#1  0xffffffff81f3fea6 in __pick_next_task (rf=0xffffffff82a03e90, prev=0xffffffff82a149c0 <init_task>, rq=0xffff88807dc2b2c0) at kernel/sched/core.c:5804
#2  pick_next_task (rf=0xffffffff82a03e90, prev=0xffffffff82a149c0 <init_task>, rq=0xffff88807dc2b2c0) at kernel/sched/core.c:6313
#3  __schedule (sched_mode=sched_mode@entry=0) at kernel/sched/core.c:6458
#4  0xffffffff81f40595 in schedule () at kernel/sched/core.c:6570
```

#### dequeue_task_fair
```txt
#0  dequeue_task_fair (rq=0xffff88807dc2b2c0, p=0xffff8881001b8f00, flags=9) at kernel/sched/fair.c:5824
#1  0xffffffff81f40186 in dequeue_task (flags=9, p=0xffff8881001b8f00, rq=0xffff88807dc2b2c0) at kernel/sched/core.c:2086
#2  deactivate_task (flags=9, p=0xffff8881001b8f00, rq=0xffff88807dc2b2c0) at kernel/sched/core.c:2100
#3  __schedule (sched_mode=sched_mode@entry=0) at kernel/sched/core.c:6448
#4  0xffffffff81f40595 in schedule () at kernel/sched/core.c:6570
#5  0xffffffff8112aee1 in kthreadd (unused=<optimized out>) at kernel/kthread.c:733
#6  0xffffffff81001a72 in ret_from_fork () at arch/x86/entry/entry_64.S:306
#7  0x0000000000000000 in ?? ()
```

#### update_curr

- calc_delta_fair : 计算什么 ?

```txt
#0  update_curr (cfs_rq=cfs_rq@entry=0xffff88807dc2b340) at kernel/sched/fair.c:887
#1  0xffffffff81142b50 in dequeue_entity (flags=9, se=0xffff8881001b8f80, cfs_rq=0xffff88807dc2b340) at kernel/sched/fair.c:4517
#2  dequeue_task_fair (rq=0xffff88807dc2b2c0, p=0xffff8881001b8f00, flags=9) at kernel/sched/fair.c:5835
#3  0xffffffff81f40186 in dequeue_task (flags=9, p=0xffff8881001b8f00, rq=0xffff88807dc2b2c0) at kernel/sched/core.c:2086
#4  deactivate_task (flags=9, p=0xffff8881001b8f00, rq=0xffff88807dc2b2c0) at kernel/sched/core.c:2100
#5  __schedule (sched_mode=sched_mode@entry=0) at kernel/sched/core.c:6448
#6  0xffffffff81f40595 in schedule () at kernel/sched/core.c:6570
#7  0xffffffff8112aee1 in kthreadd (unused=<optimized out>) at kernel/kthread.c:733
#8  0xffffffff81001a72 in ret_from_fork () at arch/x86/entry/entry_64.S:306
#9  0x0000000000000000 in ?? ()
```

## 整理一下 kernel 的 doc
> A group’s unassigned quota is globally tracked, being refreshed back to cfs_quota units at each period boundary. As threads consume this bandwidth it is transferred to cpu-local “silos” on a demand basis. The amount transferred within each of these updates is tunable and described as the “slice”.

> For efficiency run-time is transferred between the global pool and CPU local “silos” in a batch fashion.

## pick_next_task 分析
1. CONFIG_FAIR_GROUP_SCHED 如果不考虑 !

## sched_entity 是否对应的
看上去，sched_entity 和 rq 对应:
1. se 特指给 cfs_rq 使用 ?
2. 如果真的是仅仅作为 rb tree 中间的一个 node 显然没有必要高处三个来！

## 浏览一下所有的函数的作用
1. 为什么这些函数中间都需要持有的参数 rq ? 难道不能通过 task_struct 找到 rq 吗 ?
2. 会不会一个 rq 中间持有多个 cfs_rq

## 更新时钟机制

* ***Latency Tracking***

> 似乎 latency 描述 : 在特定的时间之类的所有 active 的 process 必须处理一下。
> 的确是 preempt 机制的目的相同

# linux kernel scheduler
1. cpu domain
2. nohz

cpu_attach_domain

- [ ] so many update load avg:
  - update_tg_load_avg
  - update_load_avg
  - rebalance_domains : 处理 idle , balance 的时机
    - load_balance

- [ ] sched_group_span
- [ ] load_balance_mask
```c
    struct cpumask *cpus = this_cpu_cpumask_var_ptr(load_balance_mask);
```

- [ ] 计算 sched_group 的时候的 busy 程度的时候，是使用什么来分析的。

- [ ] 存在多个调度类还是可以理解的，优先级高的队列首先清空，但是各种调度策略的影响如何在代码中间具体体现。
```c
/*
 * Scheduling policies
 */
#define SCHED_NORMAL        0
#define SCHED_FIFO      1
#define SCHED_RR        2
#define SCHED_BATCH     3
```


## smp balance

```c
__init void init_sched_fair_class(void)
{
#ifdef CONFIG_SMP
    open_softirq(SCHED_SOFTIRQ, run_rebalance_domains);

#ifdef CONFIG_NO_HZ_COMMON
    nohz.next_balance = jiffies;
    nohz.next_blocked = jiffies;
    zalloc_cpumask_var(&nohz.idle_cpus_mask, GFP_NOWAIT);
#endif
#endif /* SMP */

}
```
- [ ] 不知道 softirq 的实现，为什么不是直接调用，而是通过一次 softirq 的封装

```c
enum migration_type {
    migrate_load = 0,
    migrate_util,
    migrate_task,
    migrate_misfit
};

/*
 * 'group_type' describes the group of CPUs at the moment of load balancing.
 *
 * The enum is ordered by pulling priority, with the group with lowest priority
 * first so the group_type can simply be compared when selecting the busiest
 * group. See update_sd_pick_busiest().
 */
enum group_type {
    /* The group has spare capacity that can be used to run more tasks.  */
    group_has_spare = 0,
    /*
     * The group is fully used and the tasks don't compete for more CPU
     * cycles. Nevertheless, some tasks might wait before running.
     */
    group_fully_busy,
    /*
     * SD_ASYM_CPUCAPACITY only: One task doesn't fit with CPU's capacity
     * and must be migrated to a more powerful CPU.
     */
    group_misfit_task,
    /*
     * SD_ASYM_PACKING only: One local CPU with higher capacity is available,
     * and the task should be migrated to it instead of running on the
     * current CPU.
     */
    group_asym_packing,
    /*
     * The tasks' affinity constraints previously prevented the scheduler
     * from balancing the load across the system.
     */
    group_imbalanced,
    /*
     * The CPU is overloaded and can't provide expected CPU cycles to all
     * tasks.
     */
    group_overloaded
};
```

- [ ] migration 和 group_type 的关系是什么 ?


- run_rebalance_domains
  - * trigger_load_balance
  - * nohz_csd_func
  - nohz_csd_func
  - update_blocked_averages
  - rebalance_domains
    - should_we_balance
    - find_busiest_group
      - update_sd_lb_stats
        - update_group_capacity
        - update_sg_lb_stats
        - update_sd_pick_busiest
      - calculate_imbalance : 计算需要迁移多少负载量才能达到均衡
    - find_busiest_queue
    - stop_one_cpu_nowait
    - detach_tasks : 注意，我们只是迁移没有运行的 cpu
      - detach_task
        - deactivate_task
        - set_task_cpu


- [ ] there are **two** cpumask
  - 应该是一个描述这个 sched_group 包含那些 cpu，一个描述那些做 load balance 的 cpu
  - struct sched_group_capacity::cpumask
  - struct sched_group::cpumask

- select_task_rq
  - * sched_exec
  - * select_task_rq
    - * wake_up_new_task
    - * try_to_wake_up
  - select_task_rq_fair
    - wake_affine
      - wake_affine_idle
      - wake_affine_weight
    - select_idle_sibling : 快速路径，首先在附近进行查找
      - available_idle_cpu
      - sched_idle_cpu
      - select_idle_core
      - select_idle_cpu
      - select_idle_smt
    - find_idlest_cpu : 慢速路径，是在不行就在全局查找
      - find_idlest_group
      - find_idlest_group_cpu

- [ ] SD_WAKE_AFFINE 标志位 : 表示运行唤醒进程的 CPU 可以运行这个被唤醒的进程。

## load
```c
static unsigned long cpu_load(struct rq *rq)
{
    return cfs_rq_load_avg(&rq->cfs);
}
```

```c
/*
 * The load/runnable/util_avg accumulates an infinite geometric series
 * (see __update_load_avg_cfs_rq() in kernel/sched/pelt.c).
 *
 * [load_avg definition]
 *
 *   load_avg = runnable% * scale_load_down(load)
 *
 * [runnable_avg definition]
 *
 *   runnable_avg = runnable% * SCHED_CAPACITY_SCALE
 *
 * [util_avg definition]
 *
 *   util_avg = running% * SCHED_CAPACITY_SCALE
 *
 * where runnable% is the time ratio that a sched_entity is runnable and
 * running% the time ratio that a sched_entity is running.
 *
 * For cfs_rq, they are the aggregated values of all runnable and blocked
 * sched_entities.
 *
 * The load/runnable/util_avg doesn't directly factor frequency scaling and CPU
 * capacity scaling. The scaling is done through the rq_clock_pelt that is used
 * for computing those signals (see update_rq_clock_pelt())
 *
 * N.B., the above ratios (runnable% and running%) themselves are in the
 * range of [0, 1]. To do fixed point arithmetics, we therefore scale them
 * to as large a range as necessary. This is for example reflected by
 * util_avg's SCHED_CAPACITY_SCALE.
 *
 * [Overflow issue]
 *
 * The 64-bit load_sum can have 4353082796 (=2^64/47742/88761) entities
 * with the highest load (=88761), always runnable on a single cfs_rq,
 * and should not overflow as the number already hits PID_MAX_LIMIT.
 *
 * For all other cases (including 32-bit kernels), struct load_weight's
 * weight will overflow first before we do, because:
 *
 *    Max(load_avg) <= Max(load.weight)
 *
 * Then it is the load_weight's responsibility to consider overflow
 * issues.
 */
struct sched_avg {
    u64             last_update_time;
    u64             load_sum;
    u64             runnable_sum;
    u32             util_sum;
    u32             period_contrib;
    unsigned long           load_avg;
    unsigned long           runnable_avg;
    unsigned long           util_avg;
    struct util_est         util_est;
} ____cacheline_aligned;
```

首先，一共三个数值，load, runnable, util, 这三个都是无穷级数
- 表示可运行状态，在就绪队列可运行状态，和正在执行
- [x] 所以 可运行状态 和 在就绪队列 真的区分了吗 ?
  - 确实如此表述的

其次，两个对象，sched_entities 和 rq

- [x] load_sum 对于 entity 只是衰减时间，而对于 rq 是 时间 乘以 权重
   - 分析 `__update_load_avg_se` 和 `__update_load_avg_cfs_rq`，就 load，前者是 1 ，而后者是 `scale_load_down(cfs_rq->load.weight)`

- 分析 `___update_load_avg`, 其实 avg 的作用对于 cfs_rq 就是除以 `get_pelt_divider`
  - 但是对于 se 来说，load 参数为其 weight

```c
static __always_inline void
___update_load_avg(struct sched_avg *sa, unsigned long load)
{
    u32 divider = get_pelt_divider(sa);

    /*
     * Step 2: update *_avg.
     */
    sa->load_avg = div_u64(load * sa->load_sum, divider);
    sa->runnable_avg = div_u64(sa->runnable_sum, divider);
    WRITE_ONCE(sa->util_avg, sa->util_sum / divider);
}
```


```c
/*
 * sched_entity:
 *
 *   task:
 *     se_weight()   = se->load.weight
 *     se_runnable() = !!on_rq
 *
 *   group: [ see update_cfs_group() ]
 *     se_weight()   = tg->weight * grq->load_avg / tg->load_avg
 *     se_runnable() = grq->h_nr_running
 *
 *   runnable_sum = se_runnable() * runnable = grq->runnable_sum
 *   runnable_avg = runnable_sum
 *
 *   load_sum := runnable
 *   load_avg = se_weight(se) * load_sum
 *
 * cfq_rq:
 *
 *   runnable_sum = \Sum se->avg.runnable_sum
 *   runnable_avg = \Sum se->avg.runnable_avg
 *
 *   load_sum = \Sum se_weight(se) * se->avg.load_sum
 *   load_avg = \Sum se->avg.load_avg
 */
int __update_load_avg_se(u64 now, struct cfs_rq *cfs_rq, struct sched_entity *se)
{
    if (___update_load_sum(now, &se->avg, !!se->on_rq, se_runnable(se),
                cfs_rq->curr == se)) {

        ___update_load_avg(&se->avg, se_weight(se));
        cfs_se_util_change(&se->avg);
        trace_pelt_se_tp(se);
        return 1;
    }

    return 0;
}

int __update_load_avg_cfs_rq(u64 now, struct cfs_rq *cfs_rq)
{
    if (___update_load_sum(now, &cfs_rq->avg,
                scale_load_down(cfs_rq->load.weight),
                cfs_rq->h_nr_running,
                cfs_rq->curr != NULL)) {

        ___update_load_avg(&cfs_rq->avg, 1);
        trace_pelt_cfs_tp(cfs_rq);
        return 1;
    }

    return 0;
}
```


关于 load_avg 和 load_sum 在 rq 和 se 上的区别：
```c
static inline void
enqueue_load_avg(struct cfs_rq *cfs_rq, struct sched_entity *se)
{
    cfs_rq->avg.load_avg += se->avg.load_avg;
    cfs_rq->avg.load_sum += se_weight(se) * se->avg.load_sum;
}

static inline void
dequeue_load_avg(struct cfs_rq *cfs_rq, struct sched_entity *se)
{
    sub_positive(&cfs_rq->avg.load_avg, se->avg.load_avg);
    sub_positive(&cfs_rq->avg.load_sum, se_weight(se) * se->avg.load_sum);
}
```
- [x] 如果 load_avg 和 load_sum 靠这个来维持，那么为什么还存在 `__update_load_avg_cfs_rq`
  - 因为这两个函数是 task 加入到 cfs_rq 中的时候调用
- [x] 上面两个函数还印证的想法 : se 的 sum 都是没有加入权重的，而 load_avg 是增加了权重的

![](https://img2018.cnblogs.com/blog/1771657/202002/1771657-20200216135939689-531768656.png)

- [x] why has split time into period(1024ms)
  - kernel can't handle float
- [x] why decay, how to decay ?
  - maybe the reason is same with /proc/loadavg

- [x] how to count the time is blocked , or runable ?
  - 状态更新的时候，这些统计函数都会被使用

### cpu load
I think cpu load is used for [load balancing](#load-balancing)

#### global load
- [ ] 忽然发现 /proc/loadavg 的计算不是利用上面的体系的

exported by `/proc/loadavg`

[^9]: The load number is calculated by counting the number of running (currently running or waiting to run) and uninterruptible processes (waiting for disk or network activity). So it's simply a number of processes.

![](https://img2018.cnblogs.com/blog/1771657/202002/1771657-20200216135559205-958783412.png)


1. scheduler_tick :
    - `curr->sched_class->task_tick(rq, curr, 0);`
    - calc_global_load_tick : update `calc_load_tasks`
    - perf_event_task_tick
2. do_timer : do the calculation

- [ ] `curr->sched_class->task_tick` : what are we doing in it ?
- [ ] what's relation `do_timer` and `scheduler_tick` ?

loadavg decay at rate `1/e` at 1min, 5min, 15min.

## task_group
- [x] struct task_group::load_avg
- [x] struct cfs_rq::tg_load_avg_contrib;
```c
/**
 * update_tg_load_avg - update the tg's load avg
 * @cfs_rq: the cfs_rq whose avg changed
 * @force: update regardless of how small the difference
 *
 * This function 'ensures': tg->load_avg := \Sum tg->cfs_rq[]->avg.load.
 * However, because tg->load_avg is a global value there are performance
 * considerations.
 *
 * In order to avoid having to look at the other cfs_rq's, we use a
 * differential update where we store the last value we propagated. This in
 * turn allows skipping updates if the differential is 'small'.
 *
 * Updating tg's load_avg is necessary before update_cfs_share().
 */
static inline void update_tg_load_avg(struct cfs_rq *cfs_rq, int force)


/* Task group related information */
struct task_group {
    /*
     * load_avg can be heavily contended at clock tick time, so put
     * it in its own cacheline separated from the fields above which
     * will also be accessed at each tick.
     */
    atomic_long_t       load_avg ____cacheline_aligned;
```
As two comments suggests, `tg->load_avg := \Sum tg->cfs_rq[]->avg.load_avg.`, tg_load_avg_contrib is used for lock efficiency.

- cfs_rq 上挂在的 node 可能是 se, 可能是 tg
  - task_group 会为每个 CPU 再维护一个 cfs_rq，这个 cfs_rq 用于组织挂在这个任务组上的任务以及子任务组

- 一个 task_group 并不会限制其 task 都是运行在哪一个 cpu 上
  - 一个 task_group 的 load_avg 就是其所在 cpu 的 load_avg 的总和
  - 需要 per_cpu 的 cfs_rq 是因为 cfs_rq 是用于管理的
  - 需要 per_cpu 的 se 是因为 se 作为挂载使用的


- [x] struct task_group::shares
  - `share` is exclusive concept used for task_group, describing share of a task_group in all task_groups


- [ ] calc_group_shares()
  - `reweight_entity` : 作用就是将 重新计算一下 load_avg, 因为该 tg 的 weight 发生了变化
第一件事情，当我们试图调整 share 的时候，是不是最终会影响到每一个所有人 task 的 weight ?
  - 这样是不是太慢了，甚至那些没有处于就绪队列的 task 的 weight 都需要重新计算
  - 但是 vruntime 的计算是靠 除以 weight 来的
  - 实际上的策略是，将整个 group 当做一 asdfa 个 se, 当 share 调整之后，只是需要重新调整这个 group 的 weight 的
  - 其实所有的 process 都是放到 group 中间的
    - weight 不是直接算到每一个 se 上的
    - 感觉 share 就是 weight 啊
  - group 可能分布于所有的 cpu 上，但是，calc_group_shares 的参数只是一个 se
  - 而 cfs_rq 中间选择其最佳的 se 的时候，显然是从当前的 se 中间选择的
    - 如果 cpu A, B 中间都有进程，并且 A 中间有 tg 的 weight 为 1000, B 中间为 10, 那么 tg 在 A, B 对应的 se 的 weight 调整显然不同

```plain
                 tg->weight * grq->load.weight
e->load.weight = -----------------------------               (1)
      \Sum grq->load.weight
```
- 恐怖注释中间的，`tg->weight` 实际上是 `tg->shares`, 而 `tg->shares` 的数值就是普通的 weight

## bandwidth
利用接口
- /sys/fs/cgroup/cpu/cpu.cfs_quota_us
- /sys/fs/cgroup/cpu/cpu.cfs_period_us

`period`表示周期，`quota`表示限额，也就是在 period 期间内，用户组的 CPU 限额为 quota 值，当超过这个值的时候，用户组将会被限制运行（throttle），等到下一个周期开始被解除限制（unthrottle）；
- [ ] 还是一个 task_group 作为对象来限制吗 ?
  - [ ] 是一个 cpu 还是总的 cpu ?

- [ ] 那么我之前一致说，保证至少运行一点时间的机制在哪里啊 ?

```c
struct cfs_bandwidth {
#ifdef CONFIG_CFS_BANDWIDTH
    raw_spinlock_t      lock;
    ktime_t         period;
    u64         quota;
    u64         runtime; // 记录限额剩余时间，会使用quota值来周期性赋值；
    s64         hierarchical_quota;

    u8          idle;
    u8          period_active; // 周期性计时已经启动；
    u8          slack_started;
    struct hrtimer      period_timer;
    struct hrtimer      slack_timer; // 延迟定时器，在任务出列时，将剩余的运行时间返回到全局池里；
    struct list_head    throttled_cfs_rq;

    /* Statistics: */
    int         nr_periods;
    int         nr_throttled;
    u64         throttled_time;
#endif
};


/* CFS-related fields in a runqueue */
struct cfs_rq {
// ...
#ifdef CONFIG_CFS_BANDWIDTH
    int         runtime_enabled;
    s64         runtime_remaining; // 剩余的运行时间；

    u64         throttled_clock;
    u64         throttled_clock_task;
    u64         throttled_clock_task_time;
    int         throttled;
    int         throttle_count;
    struct list_head    throttled_list;
#endif /* CONFIG_CFS_BANDWIDTH */
```
- [ ] cfs_rq::runtime_remaining 和 cfs_bandwidth::runtime 描述感觉是同一个东西啊
- [x] cfs_bandwidth 会被多个 cfs_rq，是的，注意 bandwidth 的概念一致都是作用于 task_group 的，而不是 se 的
  - [x] 所以，cfs_bandwidth 就是一个全局概念

- `tg_set_cfs_bandwidth` 会从 `root_task_group` 根节点开始，遍历组调度树，并逐个设置限额比率 ；
- 由于 task_group 是层级的，如果顶层的被限制，下面的所有节点都是需要被限制，所以 quota 需要需要累计所有的子节点

注入时间, 或者称之为 runtime_remaining++ :
1. update_curr
2. check_enqueue_throttle :
3. set_next_task_fair : This routine is mostly called to set `cfs_rq->curr` field when a task migrates between groups/classes.

- slack_timer 定时器，slack_period 周期默认为 5ms，在该定时器函数中也会调用 distribute_cfs_runtime 从全局运行时间中分配 runtime；
- slack_timer : 一个用于将未用完的时间再返回到时间池中


A group’s unassigned quota is globally tracked, being refreshed back to cfs_quota units at each period boundary.

```c
/*
 * Amount of runtime to allocate from global (tg) to local (per-cfs_rq) pool
 * each time a cfs_rq requests quota.
 *
 * Note: in the case that the slice exceeds the runtime remaining (either due
 * to consumption or the quota being specified to be smaller than the slice)
 * we will always only issue the remaining available time.
 *
 * (default: 5 msec, units: microseconds)
 */
unsigned int sysctl_sched_cfs_bandwidth_slice       = 5000UL;
```

- bandwidth_slice : 时间是 cpu 时间，而不是 wall clock

- throttle 的两条路径:
  - check_enqueue_throttle : 如果从 runtime pool 中间都借不到资源，那么就只能 throttle
    - account_cfs_rq_runtime
      - `__account_cfs_rq_runtime` : 如果 `cfs_rq->runtime_remaining > 0`，那么就不需要继续了，有钱还借钱，贱不贱啊!
        - assign_cfs_rq_runtime : 借钱开始
          - `__assign_cfs_rq_runtime` : 从 runtime pool 中间尽量取出来给其
            - start_cfs_bandwidth : 如果 period 过期了，那么顺便将 period timer 移动一下
  - check_cfs_rq_runtime
    - throttle_cfs_rq

![](https://img2020.cnblogs.com/blog/1771657/202003/1771657-20200310214423221-158953219.png)


- [x] 可是，我还是无法理解 slack_timer
  - slack_timer：延迟定时器，在任务出列时，将**剩余的运行时间**返回到全局池里；
  - slack_timer 定时器，slack_period 周期默认为 5ms，在该定时器函数中也会调用 distribute_cfs_runtime 从全局运行时间中分配 runtime；
  - 好吧，还是理解的，当存在 task 将自己的时间返回给 runtime pool 的时候，不要立刻进行 distribute, 因为还有可能其他的 task 也在返回，所以等

- dequeue_entity
  - return_cfs_rq_runtime : return excess runtime on last dequeue
    - `__return_cfs_rq_runtime` :  we know any runtime found here is valid as update_curr() precedes return
      - 将自己持有的时间 `cfs_rq->runtime_remaining` 返回给 runtime pool `cfs_b->runtime`，如果此时有人被 unthrottle, 那么 `start_cfs_slack_bandwidth`
      - runtime_refresh_within : Are we near the end of the current quota period?

```c
/* a cfs_rq won't donate quota below this amount */
static const u64 min_cfs_rq_runtime = 1 * NSEC_PER_MSEC;
/* minimum remaining period time to redistribute slack quota */
static const u64 min_bandwidth_expiration = 2 * NSEC_PER_MSEC;
/* how long we wait to gather additional slack before distributing */
static const u64 cfs_bandwidth_slack_period = 5 * NSEC_PER_MSEC;
```
- unthrottle_cfs_rq 的时候，似乎操作就是 enqueue_task 就可以了，再次之前，runtime pool 的数值必然得到补充了

- [ ] update_curr

# numa balancing
- https://www.linux-kvm.org/images/7/75/01x07b-NumaAutobalancing.pdf : 算是说的很清楚了吧！

- task_numa_work

- [ ] 忽然想到，奔跑上说的内容，是不是只对于 die 级别的，根本没有考虑 numa 层次
  - [ ] 如果 load balancing 只是能处理同一个 die 级别的，这不是会导致有的线程永远无法迁移其他的可用的 core 上去 ?

- update_numa_stats : Gather all necessary information to make NUMA balancing placement decisions that are compatible with standard load balancer. This borrows code and logic from `update_sg_lb_stats` but sharing a common implementation is impractical.

```c
struct task_numa_env {
    struct task_struct *p;

    int src_cpu, src_nid;
    int dst_cpu, dst_nid;

    struct numa_stats src_stats, dst_stats;

    int imbalance_pct;
    int dist;

    struct task_struct *best_task;
    long best_imp;
    int best_cpu;
};
```

- task_numa_fault : 调用者来自于 remote process 的位置，其中
  - numa_migrate_preferred
    - task_numa_migrate :
      - task_numa_find_cpu
        - task_numa_compare : 如果 task 迁移到新的 CPU 上去会更加好 ?

## auto group
man sched(7)
和 setsid 的关系

因为 task_group 是 cgroup 机制下，所以将 task_group 加入到机制中间:
- sched_online_group
- sched_offline_group

# uclamp(TODO)
clamped utilization

## wait_queue
wait_queue 的机制 : 将自己加入到队列，然后睡眠，之后其他的 thread 利用 wake up 将队列出队, 并且执行事先注册好的函数，这个函数一般就是 try_to_wake_up, 从而达到 wait 事件的过程自己在睡眠

- [x] wait_event : sleep until a condition gets true
- [x] add_wait_queue  : 加入队列， 当 wake_up 的时候会调用被 init_waitqueue_func_entry 初始化的函数
- [x] wake_up : 将队列中间的 entry delte 并且执行事先注册的函数

- [ ] exclusive task

- wake_up
  - `__wake_up_common_lock`
    - `__wake_up_common`

- wait_event
  - `__wait_event`

```c
#define ___wait_event(wq_head, condition, state, exclusive, ret, cmd)       \
({                                      \
    __label__ __out;                            \
    struct wait_queue_entry __wq_entry;                 \
    long __ret = ret;   /* explicit shadow */               \
                                        \
    init_wait_entry(&__wq_entry, exclusive ? WQ_FLAG_EXCLUSIVE : 0);    \
    for (;;) {                              \
        long __int = prepare_to_wait_event(&wq_head, &__wq_entry, state);\
                                        \
        if (condition)                          \
            break;                          \
                                        \
        if (___wait_is_interruptible(state) && __int) {         \
            __ret = __int;                      \
            goto __out;                     \
        }                               \
                                        \
        cmd;                                \
    }                                   \
    finish_wait(&wq_head, &__wq_entry);                 \
__out:  __ret;                                  \
})
// 其中的，init_wait_entry 将会设置被移动出来队列的时候，设置的 function 导致其被自动运行
```


# fair.c 源码分析


> 1. 从 1000 ~ 2700 config_numa_balancing
> 2. 3700 计算 load avg 以及处理 tg 等东西
> 3. 4000 dequeue_entity 各种 entity_tick 之类的
> 4. 5000 作用的位置，处理 bandwidth
> 5. 后面也许都是在处理 cpu attach 的吧

update_cfs_group : shares runable 然后利用 reweight_entity 分析


- pick_next_task_fair
  - check_cfs_rq_runtime
    - cfs_rq_throttled

- pick_next_entity_fair
  - put_prev_entity
  - set_next_entity

- set_curr_task_fair
  - set_next_entity

```txt
#0  migrate_task_rq_fair (p=0xffff888100225d00, new_cpu=0) at kernel/sched/fair.c:7088
#1  0xffffffff8113c6fe in set_task_cpu (p=p@entry=0xffff888100225d00, new_cpu=new_cpu@entry=0) at kernel/sched/core.c:3128
#2  0xffffffff8113d090 in try_to_wake_up (p=0xffff888100225d00, state=state@entry=3, wake_flags=32, wake_flags@entry=0) at kernel/sched/core.c:4192
#3  0xffffffff8113d3cc in wake_up_process (p=<optimized out>) at kernel/sched/core.c:4314
#4  0xffffffff81158289 in swake_up_locked (q=<optimized out>, q=<optimized out>) at kernel/sched/build_utility.c:3928
#5  swake_up_locked (q=0xffffffff82b4e918 <rcu_state+3288>) at kernel/sched/build_utility.c:3920
#6  swake_up_one (q=0xffffffff82b4e918 <rcu_state+3288>) at kernel/sched/build_utility.c:3951
#7  0xffffffff81189d03 in rcu_report_qs_rdp (rdp=0xffff888333c2c0c0) at kernel/rcu/tree.c:2047
#8  rcu_check_quiescent_state (rdp=0xffff888333c2c0c0) at kernel/rcu/tree.c:2090
#9  rcu_core () at kernel/rcu/tree.c:2489
#10 0xffffffff822000e1 in __do_softirq () at kernel/softirq.c:571
#11 0xffffffff8110b3aa in invoke_softirq () at kernel/softirq.c:445
#12 __irq_exit_rcu () at kernel/softirq.c:650
#13 0xffffffff81f41382 in sysvec_apic_timer_interrupt (regs=0xffffc9000086be88) at arch/x86/kernel/apic/apic.c:1106
```

- select_task_rq_fair

## taks group
> 1. root_task_group 在 sched_init 中间被初始化 ?

```c
// init_tg_cfs_entry 的两个调用者
int alloc_fair_sched_group(struct task_group *tg, struct task_group *parent)
void __init sched_init(void)

    void init_tg_cfs_entry(struct task_group *tg, struct cfs_rq *cfs_rq,
          struct sched_entity *se, int cpu,
          struct sched_entity *parent)

// @todo 找到，缺少加入 task_group 离开 task_group 之类的操作
// 调用的地方太少了
```

```c
int alloc_fair_sched_group(struct task_group *tg, struct task_group *parent)

struct task_group {
// 部分字段被省略

#ifdef CONFIG_FAIR_GROUP_SCHED
	/* schedulable entities of this group on each CPU */
	struct sched_entity	**se;
	/* runqueue "owned" by this group on each CPU */
	struct cfs_rq		**cfs_rq;
	unsigned long		shares;
#endif

	struct rcu_head		rcu;
	struct list_head	list;

	struct task_group	*parent;
	struct list_head	siblings;
	struct list_head	children;

	struct cfs_bandwidth	cfs_bandwidth;
};
```

1. task_group 也是划分为含有 parent 机制的
2. tg 是参数，外部 malloc 将其各个部分初始化
3. task_group 通过 parent siblings 以及 chilren 将其中的各个部分形成网状结构
4. CONFIG_CFS_BANDWIDTH 中间的部分:
  1. task_group 不依赖于 fair_group_sched ，而是总是存在的，用于形成
  2. cfs_bandwidth 为什么和 fair_group_sched 的关系到底是什么 ?　本以为其子集呀，现在 bandwidth 似乎用于保证 task_group 中间保证最多使用，fair_group_sched 保证内部的公平
  3. 居然还有 percpu 机制
  4. alloc_fair_sched_group 就是对于 se cfs_rq  cfs_bandwidth 的初始化而已


> 还是 init_tg_cfs_entry 含有一些有意思的东西。

## 详细内容

```c
static inline void update_load_add(struct load_weight *lw, unsigned long inc)
static inline void update_load_sub(struct load_weight *lw, unsigned long dec)
static inline void update_load_set(struct load_weight *lw, unsigned long w)
// 辅助函数，@todo load_weight 中间 inv_weight 到底如何使用 ?


// 利用load weight 计算 @todo 计算什么来着 ?
static void __update_inv_weight(struct load_weight *lw)
static u64 __calc_delta(u64 delta_exec, unsigned long weight, struct load_weight *lw)

// 为 CONFIG_FAIR_GROUP_SCHED 而配置的各种辅助函数
static inline struct rq *rq_of(struct cfs_rq *cfs_rq)
static inline struct task_struct *task_of(struct sched_entity *se)
static inline struct rq *rq_of(struct cfs_rq *cfs_rq)
static inline struct cfs_rq *task_cfs_rq(struct task_struct *p)
static inline struct cfs_rq *cfs_rq_of(struct sched_entity *se)
static inline struct cfs_rq *group_cfs_rq(struct sched_entity *grp)
static inline void list_add_leaf_cfs_rq(struct cfs_rq *cfs_rq)
static inline void list_del_leaf_cfs_rq(struct cfs_rq *cfs_rq)
static inline struct sched_entity *parent_entity(struct sched_entity *se)
static inline void find_matching_se(struct sched_entity **se, struct sched_entity **pse)



// Scheduling class tree data structure manipulation methods:
// @todo 但是 min_vruntime 的含义还是不动呀!
static inline u64 max_vruntime(u64 max_vruntime, u64 vruntime)
static inline u64 min_vruntime(u64 min_vruntime, u64 vruntime)
static void update_min_vruntime(struct cfs_rq *cfs_rq)
// 还有一堆 __fun 的函数

// Scheduling class statistics methods:
// 700 line

// 6000 - 10000 用于迁移
```

```c
// 6296
/*
 * select_task_rq_fair: Select target runqueue for the waking task in domains
 * that have the 'sd_flag' flag set. In practice, this is SD_BALANCE_WAKE,
 * SD_BALANCE_FORK, or SD_BALANCE_EXEC.
 *
 * Balances load by selecting the idlest CPU in the idlest group, or under
 * certain conditions an idle sibling CPU if the domain has SD_WAKE_AFFINE set.
 *
 * Returns the target CPU number.
 *
 * preempt must be disabled.
 */
static int select_task_rq_fair(struct task_struct *p, int prev_cpu, int sd_flag, int wake_flags)
// selecting the idlest CPU in the idlest group
  // 文章中间提到的 group 以及 domain 的概念来处理

// 6365
/*
 * Called immediately before a task is migrated to a new CPU; task_cpu(p) and
 * cfs_rq_of(p) references at time of call are still valid and identify the
 * previous CPU. The caller guarantees p->pi_lock or task_rq(p)->lock is held.
 */
static void migrate_task_rq_fair(struct task_struct *p, int new_cpu)



// 不知道是做什么的，四个辅助的小函数
static void rq_online_fair(struct rq *rq)
{
	update_sysctl();

	update_runtime_enabled(rq);
}

static void rq_offline_fair(struct rq *rq)
{
	update_sysctl();

	/* Ensure any throttled groups are reachable by pick_next_task */
	unthrottle_offline_cfs_rqs(rq);
}

static void task_dead_fair(struct task_struct *p)
{
	remove_entity_load_avg(&p->se);
}

/*
 * sched_class::set_cpus_allowed must do the below, but is not required to
 * actually call this function.
 */
void set_cpus_allowed_common(struct task_struct *p, const struct cpumask *new_mask)
{
	cpumask_copy(&p->cpus_allowed, new_mask);
	p->nr_cpus_allowed = cpumask_weight(new_mask);
}
```

## dequeue_task_fair
> 总体来说， dequeue_task_fair 在于和 bandwidth group 相关的更新
> enqueue_task_fair 和其效果非常的相似

![](../../img/source/update_load_avg.png)
![](../../img/source/update_cfs_group.png)
![](../../img/source/dequeue_task_fair.png)
![](../../img/source/cfs_rq_throttled.png)


```c
//  各种update

// check_buddies 就是为了处理 cfs_rq 中间的四个变量，将其设置为NULL

/* CFS-related fields in a runqueue */
struct cfs_rq {
	/*
	 * 'curr' points to currently running entity on this cfs_rq.
	 * It is set to NULL otherwise (i.e when none are currently running).
	 */
	struct sched_entity	*curr;
	struct sched_entity	*next;
	struct sched_entity	*last;
	struct sched_entity	*skip;


// account_entity_dequeue : 另一个调用位置 reweight_entity

static void
account_entity_dequeue(struct cfs_rq *cfs_rq, struct sched_entity *se)
{
  // 本函数，处理 nr_running 和 load.weight 机制
	update_load_sub(&cfs_rq->load, se->load.weight);
	if (!parent_entity(se))
		update_load_sub(&rq_of(cfs_rq)->load, se->load.weight);
#ifdef CONFIG_SMP
	if (entity_is_task(se)) {
		account_numa_dequeue(rq_of(cfs_rq), task_of(se));
		list_del_init(&se->group_node);
	}
#endif
	cfs_rq->nr_running--;
}

// dequeue_runable_load_avg
```

## yield_task_fair
> @todo update_rq_clock 相关的内容有点复杂了
> yield_to_task_fair 简单的利用了 yield_task_fair ，首先设置接下来运行的 task
> 其实按道理来说，yield_task_fair 这种的，应该就是当前进程直接 schedule 就可以了

```c
static bool yield_to_task_fair(struct rq *rq, struct task_struct *p, bool preempt)
{
	struct sched_entity *se = &p->se;

	/* throttled hierarchies are not runnable */
	if (!se->on_rq || throttled_hierarchy(cfs_rq_of(se)))
		return false;

	/* Tell the scheduler that we'd really like pse to run next. */
	set_next_buddy(se);　// 现在才感觉到，buddy 的作用是什么，rq 的特殊关注对象

	yield_task_fair(rq);

	return true;
}
```
```c
// 唯一调用地点
/**
 * sys_sched_yield - yield the current processor to other threads.
 *
 * This function yields the current CPU to other tasks. If there are no
 * other threads running on this CPU then this function will return.
 *
 * Return: 0.
 */
static void do_sched_yield(void)
{
	struct rq_flags rf;
	struct rq *rq;

	local_irq_disable();
	rq = this_rq();
	rq_lock(rq, &rf);

	schedstat_inc(rq->yld_count);
	current->sched_class->yield_task(rq); // 所以其中的工作到底是什么 ?

	/*
	 * Since we are going to call schedule() anyway, there's
	 * no need to preempt or enable interrupts:
	 */
	preempt_disable();
	rq_unlock(rq, &rf);
	sched_preempt_enable_no_resched();

	schedule();　// 切换上下文吗 ?
}
```

```c
/*
 * sched_yield() is very simple
 *
 * The magic of dealing with the ->skip buddy is in pick_next_entity.
 */
// todo 分析一下 pick_next_entity 中间如何处理 skip 的 ?
static void yield_task_fair(struct rq *rq)
{
	struct task_struct *curr = rq->curr;
	struct cfs_rq *cfs_rq = task_cfs_rq(curr);
	struct sched_entity *se = &curr->se;

	/*
	 * Are we the only task in the tree?
	 */
	if (unlikely(rq->nr_running == 1))
		return;

	clear_buddies(cfs_rq, se);

  // TODO SCHED_BATCH 的作用到底是什么 ?
	if (curr->policy != SCHED_BATCH) {
		update_rq_clock(rq);
		/*
		 * Update run-time statistics of the 'current'.
		 */
		update_curr(cfs_rq);
		/*
		 * Tell update_rq_clock() that we've just updated,
		 * so we don't do microscopic update in schedule()
		 * and double the fastpath cost.
		 */
		rq_clock_skip_update(rq);
	}

	set_skip_buddy(se); // 实际上，这就是全部的工作
}
```


> pick_next_task_fair 当去掉各种　CONFIG_FAIR_GROUP_SCHED 的时候的逻辑很简单

```c
again:
	if (!cfs_rq->nr_running) // 没有事情做，那么切换一下
		goto idle;


	put_prev_task(rq, prev); // 释放当前的

  // 我猜测其实并不是 rq owned by this group
	do {
		se = pick_next_entity(cfs_rq, NULL);
		set_next_entity(cfs_rq, se);
		cfs_rq = group_cfs_rq(se);
	} while (cfs_rq);

	p = task_of(se);

done: __maybe_unused;
#ifdef CONFIG_SMP
	/*
	 * Move the next running task to the front of
	 * the list, so our cfs_tasks list becomes MRU
	 * one.
	 */
	list_move(&p->se.group_node, &rq->cfs_tasks);
#endif

	if (hrtick_enabled(rq))
		hrtick_start_fair(rq, p);

	return p;
```
