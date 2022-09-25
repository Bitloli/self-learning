# kernel/sched/core.c

- [ ] 没有找到层级式的计算每一个 CPU shared 的地方

## 关键函数
- scheduler_tick : scheduler 面对始终的 hook
- resched_curr : 当前 thread 决定释放 CPU

## 基本的分析一下选择过程

```txt
#0  select_task_rq_fair (p=0xffff88814a11ae80, prev_cpu=0, wake_flags=8) at kernel/sched/fair.c:7015
#1  0xffffffff8113cff4 in select_task_rq (wake_flags=8, cpu=0, p=0xffff88814a11ae80) at kernel/sched/core.c:3489
#2  try_to_wake_up (p=0xffff88814a11ae80, state=state@entry=3, wake_flags=wake_flags@entry=0) at kernel/sched/core.c:4183
#3  0xffffffff8113d3cc in wake_up_process (p=<optimized out>) at kernel/sched/core.c:4314
#4  0xffffffff8119b859 in hrtimer_wakeup (timer=<optimized out>) at kernel/time/hrtimer.c:1939
#5  0xffffffff8119bde2 in __run_hrtimer (flags=2, now=0xffffc90000003f48, timer=0xffffc900005bb910, base=0xffff888333c1e0c0, cpu_base=0xffff888333c1e080) at kernel/time/hrtimer.c:1685
#6  __hrtimer_run_queues (cpu_base=cpu_base@entry=0xffff888333c1e080, now=48626544325410, flags=flags@entry=2, active_mask=active_mask@entry=15) at kernel/time/hrtimer.c:1749
#7  0xffffffff8119ca71 in hrtimer_interrupt (dev=<optimized out>) at kernel/time/hrtimer.c:1811
```

- [ ] 在这里， select_task_rq 中，根据当时参数的就直接找到

```txt
#0  resched_curr (rq=0xffff888333c2b2c0) at kernel/sched/core.c:1027
#1  0xffffffff8114599b in check_preempt_tick (curr=0xffff888145898a00, cfs_rq=0xffff888333c2b3c0) at kernel/sched/sched.h:1169
#2  entity_tick (queued=0, curr=0xffff888145898a00, cfs_rq=0xffff888333c2b3c0) at kernel/sched/fair.c:4761
#3  task_tick_fair (rq=0xffff888333c2b2c0, curr=0xffff888100a22e80, queued=0) at kernel/sched/fair.c:11416
#4  0xffffffff8113f392 in scheduler_tick () at kernel/sched/core.c:5453
#5  0xffffffff8119b2b1 in update_process_times (user_tick=0) at kernel/time/timer.c:1844
#6  0xffffffff811ad85f in tick_sched_handle (ts=ts@entry=0xffff888333c1e5c0, regs=regs@entry=0xffffc9000086be88) at kernel/time/tick-sched.c:243
#7  0xffffffff811ada3c in tick_sched_timer (timer=0xffff888333c1e5c0) at kernel/time/tick-sched.c:1480
#8  0xffffffff8119bde2 in __run_hrtimer (flags=130, now=0xffffc90000003f48, timer=0xffff888333c1e5c0, base=0xffff888333c1e0c0, cpu_base=0xffff888333c1e080) at kernel/time/hrtimer.c:1685
#9  __hrtimer_run_queues (cpu_base=cpu_base@entry=0xffff888333c1e080, now=48647509299866, flags=flags@entry=130, active_mask=active_mask@entry=15) at kernel/time/hrtimer.c:1749
#10 0xffffffff8119ca71 in hrtimer_interrupt (dev=<optimized out>) at kernel/time/hrtimer.c:1811
#11 0xffffffff810e25d7 in local_apic_timer_interrupt () at arch/x86/kernel/apic/apic.c:1095
#12 __sysvec_apic_timer_interrupt (regs=<optimized out>) at arch/x86/kernel/apic/apic.c:1112
#13 0xffffffff81f4137d in sysvec_apic_timer_interrupt (regs=0xffffc9000086be88) at arch/x86/kernel/apic/apic.c:1106
```
- [ ] scheduler_tick : 还是根据 curr 进行确定的

## TODO
cgroup 在 7000 line 注册的函数无人使用呀!

rq 内嵌的 cfs_rq 的作用到底是什么 ? 为什么 pick_next_task_fair 总是从其中 pick 但是依旧可以到 root_task_group 上，
`__sched_init` 中间说明了其结果!

task_group 的 share 的计算方法是什么 ?


## analyze

## rq 中间的 cfs_rq 的地位
rq 中间的似乎是根基，然后利用这个实现 group 找到其他的之类的 ?

cfs_rq entity 以及 task_group 初始化的时候，都是一套的，猜测此时创建的
entity 就是一个 group 的代表

所以通过这种方法就用 rq owned by entity/group 的效果。

现在的问题 : 其他的 entitiy 如何添加上来的 ?

> attach_entity_cfs_rq

> set_task_rq
> task_set_group_fair

> 好像也不是


> 1. malloc 出来的如何关联上去 ?
> 2. 和 rq 中间的关系是什么 ?

task_group  CONFIG_FAIR_GROUP_SCHED 以及 CONFIG_CFS_BANDWIDTH 三者逐渐递进的


## group 之间如何均衡

```c
int alloc_fair_sched_group(struct task_group *tg, struct task_group *parent)

	tg->shares = NICE_0_LOAD;
```

1. tg->shares 相关的计算
    1. 赋值永远都是 NICE_0_LOAD

```c

/*
 * Increase resolution of nice-level calculations for 64-bit architectures.
 * The extra resolution improves shares distribution and load balancing of
 * low-weight task groups (eg. nice +19 on an autogroup), deeper taskgroup
 * hierarchies, especially on larger systems. This is not a user-visible change
 * and does not change the user-interface for setting shares/weights.
 *
 * We increase resolution only if we have enough bits to allow this increased
 * resolution (i.e. 64-bit). The costs for increasing resolution when 32-bit
 * are pretty high and the returns do not justify the increased costs.
 *
 * Really only required when CONFIG_FAIR_GROUP_SCHED=y is also set, but to
 * increase coverage and consistency always enable it on 64-bit platforms.
 */
#ifdef CONFIG_64BIT
# define NICE_0_LOAD_SHIFT	(SCHED_FIXEDPOINT_SHIFT + SCHED_FIXEDPOINT_SHIFT)
# define scale_load(w)		((w) << SCHED_FIXEDPOINT_SHIFT)
# define scale_load_down(w)	((w) >> SCHED_FIXEDPOINT_SHIFT)
#else
# define NICE_0_LOAD_SHIFT	(SCHED_FIXEDPOINT_SHIFT)
# define scale_load(w)		(w)
# define scale_load_down(w)	(w)
#endif

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
 * Integer metrics need fixed point arithmetic, e.g., sched/fair
 * has a few: load, load_avg, util_avg, freq, and capacity.
 *
 * We define a basic fixed point arithmetic range, and then formalize
 * all these metrics based on that basic range.
 */
# define SCHED_FIXEDPOINT_SHIFT		10
# define SCHED_FIXEDPOINT_SCALE		(1L << SCHED_FIXEDPOINT_SHIFT)
```
> @todo 还有 freq capacity load_avg 等

A priority number of 120, which is the priority of a normal task, is mapped to a load of 1024, which is the value that the kernel uses to represent the capacity of a single standard CPU.
> @todo 为什么会映射到 1024 上，利用 prio_to_weight 吗 ?

A run queue (`struct cfs_rq`) is also characterized by a "weight" value that is the accumulation of weights of all tasks on its run queue.

```c
struct sched_entity {
	/* For load-balancing: */
	struct load_weight		load;
	unsigned long			runnable_weight; // 难道 bandwidth 使用的 ?
	struct rb_node			run_node;
	struct list_head		group_node; // task group ?
	unsigned int			on_rq; // why not boolean ?

  // @todo how runtime works ?
	u64				exec_start;
	u64				sum_exec_runtime;
	u64				vruntime;
	u64				prev_sum_exec_runtime;

	u64				nr_migrations;
```
> 1. load 和 runnable_weight 之间的关系是什么 ?

The time slice can now be calculated as:
    time_slice = (sched_period() * se.load.weight) / cfs_rq.load.weight;
where `sched_period()` returns the scheduling period as a factor of the number of running tasks on the CPU.
We see that the higher the load, the higher the fraction of the scheduling period that the task gets to run on the CPU.
> 下面的两个函数似乎说明了 : time_slice 的效果，但是由于 group 的存在，其计算过程变成了递归的过程。
> 所以 time_slice 相当于一个 taks 允许运行的时间吗 ?

```c
/*
 * We calculate the wall-time slice from the period by taking a part
 * proportional to the weight.
 *
 * s = p*P[w/rw]
 */
static u64 sched_slice(struct cfs_rq *cfs_rq, struct sched_entity *se)
{
	u64 slice = __sched_period(cfs_rq->nr_running + !se->on_rq);

	for_each_sched_entity(se) {
		struct load_weight *load;
		struct load_weight lw;

		cfs_rq = cfs_rq_of(se);
		load = &cfs_rq->load;

		if (unlikely(!se->on_rq)) {
			lw = cfs_rq->load;

			update_load_add(&lw, se->load.weight);
			load = &lw;
		}
		slice = __calc_delta(slice, se->load.weight, load);
	}
	return slice;
}

/*
 * The idea is to set a period in which each task runs once.
 *
 * When there are too many tasks (sched_nr_latency) we have to stretch
 * this period because otherwise the slices get too small.
 *
 * p = (nr <= nl) ? l : l*nr/nl
 */
static u64 __sched_period(unsigned long nr_running)
{
	if (unlikely(nr_running > sched_nr_latency))
		return nr_running * sysctl_sched_min_granularity;
	else
		return sysctl_sched_latency;
}
```

Each time a new task forks or a task wakes up, its vruntime is assigned to a value that is the maximum of its last updated value and `cfs_rq.min_vruntime`.
If not for this, its vruntime would be very small as an effect of not having run for a long time (or at all)
and would take an unacceptably long time to catch up to the vruntime of its sibling tasks and hence starve them of CPU time.
> 不是很懂，对于 `cfs_rq.min_vruntime` 的更新其实也是不清楚的

Every periodic tick, the vruntime of the currently-running task is updated as follows:
    vruntime += delta_exec * (NICE_0_LOAD/curr->load.weight);
where delta_exec is the time spent by the task since the last time vruntime was updated, NICE_0_LOAD is the load of a task with normal priority, and curr is the currently-running task. We see that vruntime progresses slowly for tasks of higher priority. It has to, because the time slice for these tasks is large and they cannot be preempted until the time slice is exhausted.


> 找到了 vruntime 中间的 delta_exec 位置在于何处 ?

```c
// update_curr 中间的内容:
	curr->vruntime += calc_delta_fair(delta_exec, curr);

/*
 * delta /= w
 */
static inline u64 calc_delta_fair(u64 delta, struct sched_entity *se)
{
	if (unlikely(se->load.weight != NICE_0_LOAD))
		delta = __calc_delta(delta, NICE_0_LOAD, &se->load);

	return delta;
}

/*
 * delta_exec * weight / lw.weight
 *   OR
 * (delta_exec * (weight * lw->inv_weight)) >> WMULT_SHIFT
 *
 * Either weight := NICE_0_LOAD and lw \e sched_prio_to_wmult[], in which case
 * we're guaranteed shift stays positive because inv_weight is guaranteed to
 * fit 32 bits, and NICE_0_LOAD gives another 10 bits; therefore shift >= 22.
 *
 * Or, weight =< lw.weight (because lw.weight is the runqueue weight), thus
 * weight/lw.weight <= 1, and therefore our shift will also be positive.
 */
static u64 __calc_delta(u64 delta_exec, unsigned long weight, struct load_weight *lw)
// 这个函数虽然恶心，但是内容就是根据实际的运行时间片段，然后得到 vruntime 得到的片段，并且和 vruntime 无关。
```

**Per-entity load-tracking metrics**

```c
// sched entity 中间保证的变量。
#ifdef CONFIG_SMP
	/*
	 * Per entity load average tracking.
	 *
	 * Put into separate cache line so it does not
	 * collide with read-mostly values above.
	 */
	struct sched_avg		avg;
#endif
```
> pelt 还是和其含有关系的 ?

https://lwn.net/Articles/531853/

放到 SMP 中间，就是为了处理其中的 pelt ?

pelt.c 中间是什么个情况 ?

> 问一下蜗壳科技 ?

## sched_entity.avg 是什么情况

> 说了这么多，到底和 SMP 有什么蛇皮关系呀 ?

```c
/*
 * sched_entity:
 *
 *   task:
 *     se_runnable() == se_weight()
 *
 *   group: [ see update_cfs_group() ]
 *     se_weight()   = tg->weight * grq->load_avg / tg->load_avg
 *     se_runnable() = se_weight(se) * grq->runnable_load_avg / grq->load_avg
 *
 *   load_sum := runnable_sum
 *   load_avg = se_weight(se) * runnable_avg
 *
 *   runnable_load_sum := runnable_sum
 *   runnable_load_avg = se_runnable(se) * runnable_avg
 *
 * XXX collapse load_sum and runnable_load_sum
 *
 * cfq_rq:
 *
 *   load_sum = \Sum se_weight(se) * se->avg.load_sum
 *   load_avg = \Sum se->avg.load_avg
 *
 *   runnable_load_sum = \Sum se_runnable(se) * se->avg.runnable_load_sum
 *   runnable_load_avg = \Sum se->avg.runable_load_avg
 */

int __update_load_avg_blocked_se(u64 now, int cpu, struct sched_entity *se)
{
	if (entity_is_task(se))
		se->runnable_weight = se->load.weight;

	if (___update_load_sum(now, cpu, &se->avg, 0, 0, 0)) {
		___update_load_avg(&se->avg, se_weight(se), se_runnable(se));
		return 1;
	}

	return 0;
}

int __update_load_avg_se(u64 now, int cpu, struct cfs_rq *cfs_rq, struct sched_entity *se)
{
	if (entity_is_task(se))
		se->runnable_weight = se->load.weight;

	if (___update_load_sum(now, cpu, &se->avg, !!se->on_rq, !!se->on_rq,
				cfs_rq->curr == se)) {

		___update_load_avg(&se->avg, se_weight(se), se_runnable(se));
		cfs_se_util_change(&se->avg);
		return 1;
	}

	return 0;
}
```
> 1. se_runnable 和 se_weight 的关系是什么 ?
> 2. update_cfs_group 的作用是什么 ?


> update_cfs_group 中间的内容和注释中间描述的一致吗 ?

```c
/*
 * Recomputes the group entity based on the current state of its group
 * runqueue.
 */
static void update_cfs_group(struct sched_entity *se)
{
	struct cfs_rq *gcfs_rq = group_cfs_rq(se);
	long shares, runnable;

  // 似乎仅仅分析 group 的 owner 的
	if (!gcfs_rq)
		return;

  // 如果 bandwidth 没有通过 ?
	if (throttled_hierarchy(gcfs_rq))
		return;

    // 似乎分别计算出来 group 的 weight 和 runnable 的内容
    // TODO 所以啥几把是 grq 呀!
  /**
   *   group: [ see update_cfs_group() ]
   *     se_weight()   = tg->weight * grq->load_avg / tg->load_avg
   *     se_runnable() = se_weight(se) * grq->runnable_load_avg / grq->load_avg
   */
	shares   = calc_group_shares(gcfs_rq);
	runnable = calc_group_runnable(gcfs_rq, shares);

	reweight_entity(cfs_rq_of(se), se, shares, runnable);
}

// 调用位置 : enqueue_entity enqueue_task_fair entity_tick 以及 sched_group_set_shares
// 其中 : int sched_group_set_shares(struct task_group *tg, unsigned long shares) 设置位置在 core.c 中间
// update_curr 算是 group 发生变化然后更新的方法了
```

0. 但是我怀疑，其中只有在 涉及到什么的时候
1. grq 到底是什么 ? group runqueue ? sched:776 并不是 rq 中的，就是 task_group 中间的
2. 不如直接搜索 pelt 的内容 ?
3. 如果知道其中的

## 分析一下 : `static long calc_group_shares(struct cfs_rq *cfs_rq)` 上的注释

```c
/*
 * All this does is approximate the hierarchical proportion which includes that
 * global sum we all love to hate.
 *
 * That is, the weight of a group entity, is the proportional share of the
 * group weight based on the group runqueue weights. That is:
 *
 *                     tg->weight * grq->load.weight
 *   ge->load.weight = -----------------------------               (1)
 *			  \Sum grq->load.weight
 *
 * Now, because computing that sum is prohibitively expensive to compute (been
 * there, done that) we approximate it with this average stuff. The average
 * moves slower and therefore the approximation is cheaper and more stable.
 *
 * So instead of the above, we substitute:
 *
 *   grq->load.weight -> grq->avg.load_avg                         (2)
 *
 * which yields the following:
 *
 *                     tg->weight * grq->avg.load_avg
 *   ge->load.weight = ------------------------------              (3)
 *				tg->load_avg
 *
 * // 也就是说 : tg->load_avg 其实就是 share ?
 * Where: tg->load_avg ~= \Sum grq->avg.load_avg
 *
 * That is shares_avg, and it is right (given the approximation (2)).
 *
 * The problem with it is that because the average is slow -- it was designed
 * to be exactly that of course -- this leads to transients in boundary
 * conditions. In specific, the case where the group was idle and we start the
 * one task. It takes time for our CPU's grq->avg.load_avg to build up,
 * yielding bad latency etc..
 *
 * Now, in that special case (1) reduces to:
 *
 *                     tg->weight * grq->load.weight
 *   ge->load.weight = ----------------------------- = tg->weight   (4)
 *			    grp->load.weight
 *
 * That is, the sum collapses because all other CPUs are idle; the UP scenario.
 *
 * So what we do is modify our approximation (3) to approach (4) in the (near)
 * UP case, like:
 *
 *   ge->load.weight =
 *
 *              tg->weight * grq->load.weight
 *     ---------------------------------------------------         (5)
 *     tg->load_avg - grq->avg.load_avg + grq->load.weight
 *
 * But because grq->load.weight can drop to 0, resulting in a divide by zero,
 * we need to use grq->avg.load_avg as its lower bound, which then gives:
 *
 *
 *                     tg->weight * grq->load.weight
 *   ge->load.weight = -----------------------------		   (6)
 *				tg_load_avg'
 *
 * Where:
 *
 *   tg_load_avg' = tg->load_avg - grq->avg.load_avg +
 *                  max(grq->load.weight, grq->avg.load_avg)
 *
 * And that is shares_weight and is icky. In the (near) UP case it approaches
 * (4) while in the normal case it approaches (3). It consistently
 * overestimates the ge->load.weight and therefore:
 *
 *   \Sum ge->load.weight >= tg->weight
 *
 * hence icky!
 */
```
1. task_group 和 cfs_rq 都有 weight 吗 ? 并不是，所以 weight 在什么地方 ?
2. 观察一下　calc_group_shares 中间的内容吧!



```c
/* Task group related information */
struct task_group {
	unsigned long		shares;

#ifdef	CONFIG_SMP
	/*
	 * load_avg can be heavily contended at clock tick time, so put
	 * it in its own cacheline separated from the fields above which
	 * will also be accessed at each tick.
	 */
	atomic_long_t		load_avg ____cacheline_aligned;
#endif



/* CFS-related fields in a runqueue */
struct cfs_rq {
	struct load_weight	load;
	unsigned long		runnable_weight;
	unsigned int		nr_running;
	unsigned int		h_nr_running;


#ifdef CONFIG_SMP
	/*
	 * CFS load tracking
	 */
	struct sched_avg	avg;



struct sched_entity {
	/* For load-balancing: */
	struct load_weight		load;
	unsigned long			runnable_weight;
#ifdef CONFIG_SMP
	/*
	 * Per entity load average tracking.
	 *
	 * Put into separate cache line so it does not
	 * collide with read-mostly values above.
	 */
	struct sched_avg		avg;
#endif
};
```
> 所以，所有的疑惑都在 tg 中间 : share 和 load_avg　　



```c
/**
 * update_tg_load_avg - update the tg's load avg
 * @cfs_rq: the cfs_rq whose avg changed
 * @force: update regardless of how small the difference
 *
 * this function 'ensures': tg->load_avg := \sum tg->cfs_rq[]->avg.load.
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
{
	long delta = cfs_rq->avg.load_avg - cfs_rq->tg_load_avg_contrib;
  // 其实，所以这些 tg_load_avg_contrib 的使用真的是过于简单呀!

	/*
	 * No need to update load_avg for root_task_group as it is not used.
	 */
	if (cfs_rq->tg == &root_task_group)
		return;

	if (force || abs(delta) > cfs_rq->tg_load_avg_contrib / 64) {
		atomic_long_add(delta, &cfs_rq->tg->load_avg);
		cfs_rq->tg_load_avg_contrib = cfs_rq->avg.load_avg;
	}
}
```

> 忽然，意识到，其实，tg 其实所有的 cpu 的 rq 的总和
> this function 'ensures': `tg->load_avg := \sum tg->cfs_rq[]->avg.load`.

This metric calculates task load as the amount of time that the task was runnable during the time that it was alive.
This is kept track of in the sched_avg data structure (stored in the sched_entity structure):

## reweight_entity 内容分析
1. runnable_avg 和 avg 的关系是什么 ?
2. reweight_entity 其实就是直接对于 se 的 runnable_weight 和 load.weight 进行赋值。

```c
static void reweight_entity(struct cfs_rq *cfs_rq, struct sched_entity *se,
			    unsigned long weight, unsigned long runnable)
{
	if (se->on_rq) {
		/* commit outstanding execution time */
		if (cfs_rq->curr == se)
			update_curr(cfs_rq);
		account_entity_dequeue(cfs_rq, se);
		dequeue_runnable_load_avg(cfs_rq, se);
	}
	dequeue_load_avg(cfs_rq, se);

	se->runnable_weight = runnable;
	update_load_set(&se->load, weight);

#ifdef CONFIG_SMP
	do {
		u32 divider = LOAD_AVG_MAX - 1024 + se->avg.period_contrib;

		se->avg.load_avg = div_u64(se_weight(se) * se->avg.load_sum, divider);
		se->avg.runnable_load_avg =
			div_u64(se_runnable(se) * se->avg.runnable_load_sum, divider);
	} while (0);
#endif

	enqueue_load_avg(cfs_rq, se);
	if (se->on_rq) {
		account_entity_enqueue(cfs_rq, se);
		enqueue_runnable_load_avg(cfs_rq, se);
	}
}
```



```c
static inline void
enqueue_runnable_load_avg(struct cfs_rq *cfs_rq, struct sched_entity *se)
{
	cfs_rq->runnable_weight += se->runnable_weight;

	cfs_rq->avg.runnable_load_avg += se->avg.runnable_load_avg;
	cfs_rq->avg.runnable_load_sum += se_runnable(se) * se->avg.runnable_load_sum;
}

static inline void
dequeue_runnable_load_avg(struct cfs_rq *cfs_rq, struct sched_entity *se)
{
	cfs_rq->runnable_weight -= se->runnable_weight;

	sub_positive(&cfs_rq->avg.runnable_load_avg, se->avg.runnable_load_avg);
	sub_positive(&cfs_rq->avg.runnable_load_sum,
		     se_runnable(se) * se->avg.runnable_load_sum);
}

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

## Nohz 的影响是什么

## attach 和 detach 三个函数

```c
static void attach_entity_cfs_rq(struct sched_entity *se)

/*
 * attach_tasks() -- attaches all tasks detached by detach_tasks() to their
 * new rq.
 */
static void attach_tasks(struct lb_env *env)

/**
 * attach_entity_load_avg - attach this entity to its cfs_rq load avg
 * @cfs_rq: cfs_rq to attach to
 * @se: sched_entity to attach
 * @flags: migration hints
 *
 * Must call update_cfs_rq_load_avg() before this, since we rely on
 * cfs_rq->avg.last_update_time being current.
 */
static void attach_entity_load_avg(struct cfs_rq *cfs_rq, struct sched_entity *se, int flags)
```


1. `static void attach_tasks(struct lb_env *env)`

利用 lb_env (load_balance environment ?) 将 task 一个一个的从 链表中间迁移。

```c
void activate_task(struct rq *rq, struct task_struct *p, int flags)
{
	if (task_contributes_to_load(p)) // 这两行看不懂啊!
		rq->nr_uninterruptible--;

	enqueue_task(rq, p, flags);
}
```

detach_tasks 和 attach_tasks 对称，但是其中存在部分检查 `env->loop` 和 `can_migrate_task`

2. `attach_entity_cfs_rq` 和 `attach_task_cfs_rq`

```c
static void attach_entity_cfs_rq(struct sched_entity *se)
{
	struct cfs_rq *cfs_rq = cfs_rq_of(se);

#ifdef CONFIG_FAIR_GROUP_SCHED
	/*
	 * Since the real-depth could have been changed (only FAIR
	 * class maintain depth value), reset depth properly.
	 */
	se->depth = se->parent ? se->parent->depth + 1 : 0;
#endif

	/* Synchronize entity with its cfs_rq */
	update_load_avg(cfs_rq, se, sched_feat(ATTACH_AGE_LOAD) ? 0 : SKIP_AGE_LOAD);
	attach_entity_load_avg(cfs_rq, se, 0);
	update_tg_load_avg(cfs_rq, false);
	propagate_entity_cfs_rq(se);
}

static void attach_task_cfs_rq(struct task_struct *p)
{
	struct sched_entity *se = &p->se;
	struct cfs_rq *cfs_rq = cfs_rq_of(se);

	attach_entity_cfs_rq(se);

	if (!vruntime_normalized(p))
		se->vruntime += cfs_rq->min_vruntime;
}
```
3. `attach_entity_load_avg` 因为切换 rq 之类需要更新 load_avg

attach_task_cfs_rq 最后 switch_to_fair 以及 task_move_group_fair (task_change_group_fair)调用。
都是 sched_class 中间的标准的函数。

其实 attach_tasks 和 其他的各种蛇皮是两个体系

## affine
都是 select_task_rq_fair 的辅助函数，task 开始执行需要选择最佳的 rq

wake_affine
    - wake_affine_idle
    - wake_affine_weight

wake_wide :
