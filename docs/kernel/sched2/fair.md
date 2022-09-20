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

```c
// dequeue_task 整个指针仅仅使用在一个位置:
// 但是 : dequeue_task 被众多内容使用 !
// TODO 检查一下到底那些蛇皮在调用这一个东西 ?

static inline void dequeue_task(struct rq *rq, struct task_struct *p, int flags)
{
	if (!(flags & DEQUEUE_NOCLOCK))
		update_rq_clock(rq);

	if (!(flags & DEQUEUE_SAVE))
		sched_info_dequeued(rq, p);

	p->sched_class->dequeue_task(rq, p, flags);
}

// dequeue_task 的实现有点麻烦啊!

		cfs_rq->h_nr_running--; // 两次计数 ?
		if (cfs_rq_throttled(cfs_rq)) // 什么机制 ?
		update_load_avg(cfs_rq, se, UPDATE_TG); // 为什么支持load avg 但是load avg 自己是什么 ?
		update_cfs_group(se); // group 机制
    util_est_dequeue(&rq->cfs, p, task_sleep); // 什么神仙东西 ?
    hrtick_update(rq); // 高精度时钟 ?
```



## 更新时钟机制

```c
/*
 * Update the current task's runtime statistics.
 */
static void update_curr(struct cfs_rq *cfs_rq)
{
	struct sched_entity *curr = cfs_rq->curr;
	u64 now = rq_clock_task(rq_of(cfs_rq));
	u64 delta_exec;

  // 如果curr的cfs的sched_class 根本不是fair_sched_class呢?
  // 那么就会给cfs 注册上 !
	if (unlikely(!curr))
		return;

	delta_exec = now - curr->exec_start;
	if (unlikely((s64)delta_exec <= 0))
		return;

	curr->exec_start = now;

	schedstat_set(curr->statistics.exec_max,
		      max(delta_exec, curr->statistics.exec_max));

	curr->sum_exec_runtime += delta_exec;
	schedstat_add(cfs_rq->exec_clock, delta_exec);

	curr->vruntime += calc_delta_fair(delta_exec, curr); // 核心
	update_min_vruntime(cfs_rq); // 调整rbtree

  // TODO 不知道own 是什么含义 ?
  // 又是和cgroup 相关的内容 ?
	if (entity_is_task(curr)) {
		struct task_struct *curtask = task_of(curr);

		trace_sched_stat_runtime(curtask, delta_exec, curr->vruntime);
		cgroup_account_cputime(curtask, delta_exec);
		account_group_exec_runtime(curtask, delta_exec);
	}

	account_cfs_rq_runtime(cfs_rq, delta_exec);
}

static void update_curr_fair(struct rq *rq)
{
	update_curr(cfs_rq_of(&rq->curr->se));
}

// 应该处理了一些数值溢出之类的问题
/*
 * delta /= w
 */
static inline u64 calc_delta_fair(u64 delta, struct sched_entity *se)
{
  // NICE_0_LOAD TODO 获取nice的含义 !
	if (unlikely(se->load.weight != NICE_0_LOAD))
		delta = __calc_delta(delta, NICE_0_LOAD, &se->load);

	return delta;
}
```


* ***Latency Tracking***

> 似乎 latency 描述 : 在特定的时间之类的所有 active 的 process 必须处理一下。
> 的确是 preempt 机制的目的相同


## group 机制
1. 所有的好像就是这些吧!
CONFIG_FAIR_GROUP_SCHED
CONFIG_RT_GROUP_SCHED

2. 采用的原因: cpu bandwidth control ?

> The bandwidth allowed for a group is specified using a quota and period. Within
> each given "period" (microseconds), a group is allowed to consume only up to
> "quota" microseconds of CPU time.  When the CPU bandwidth consumption of a
> group exceeds this limit (for that period), the tasks belonging to its
> hierarchy will be throttled and are not allowed to run again until the next
> period.

```c
// 为什么感觉进程是共同管理的原因 : 整个 tg 的，
static int cpu_cfs_quota_write_s64(struct cgroup_subsys_state *css, struct cftype *cftype, s64 cfs_quota_us) { return tg_set_cfs_quota(css_tg(css), cfs_quota_us); }
static u64 cpu_cfs_period_read_u64(struct cgroup_subsys_state *css, struct cftype *cft) { return tg_get_cfs_period(css_tg(css)); }


int tg_set_cfs_quota(struct task_group *tg, long cfs_quota_us)
{
	u64 quota, period;

	period = ktime_to_ns(tg->cfs_bandwidth.period);
	if (cfs_quota_us < 0)
		quota = RUNTIME_INF;
	else
		quota = (u64)cfs_quota_us * NSEC_PER_USEC;

	return tg_set_cfs_bandwidth(tg, period, quota);
}

// TODO 所以，哪里分析过 task_group ?
// TODO us ? 我们 ?
long tg_get_cfs_period(struct task_group *tg)
{
	u64 cfs_period_us;

	cfs_period_us = ktime_to_ns(tg->cfs_bandwidth.period);
	do_div(cfs_period_us, NSEC_PER_USEC);

	return cfs_period_us;
}
```

#### 理解 task_group
> For example, it may be desirable to first provide fair CPU time to each user on the system and then to each task belonging to a user.

1. 如何确定将哪一个 thread 加入到哪一个 group ?
2. 创建 thread group 的创建的时机是什么 ?
3. thread group 让整个 reb tree 如何构建 ?
4. 一个 thread group 会不会对于另一个 thread group 含有优先级 ?
5. 是不是一旦配置了 tg 那么就所有的 thread 都必须属于某一个 group 中间 ?

```c
/* Task group related information */
struct task_group {
	struct cgroup_subsys_state css;
  // cgroup 如影随形，cgroup 和 rlimit 是相同的机制吗 ?
  // 使用在什么位置了 : mem cpu io and ?

#ifdef CONFIG_FAIR_GROUP_SCHED
  // 居然thread group 中间的thread 可以出现在不同的CPU上
	/* schedulable entities of this group on each CPU */
	struct sched_entity	**se;
  // TODO cpu 不是和rq 一一对应吗? rq 不是和 cfs_rq 意义对应吗 ?
	/* runqueue "owned" by this group on each CPU */
	struct cfs_rq		**cfs_rq;
	unsigned long		shares;

#ifdef	CONFIG_SMP
	/*
	 * load_avg can be heavily contended at clock tick time, so put
	 * it in its own cacheline separated from the fields above which
	 * will also be accessed at each tick.
	 */
	atomic_long_t		load_avg ____cacheline_aligned;
#endif
#endif

#ifdef CONFIG_RT_GROUP_SCHED
	struct sched_rt_entity	**rt_se;
	struct rt_rq		**rt_rq;

	struct rt_bandwidth	rt_bandwidth;
#endif

	struct rcu_head		rcu;
	struct list_head	list;

	struct task_group	*parent;
	struct list_head	siblings;
	struct list_head	children;

#ifdef CONFIG_SCHED_AUTOGROUP
	struct autogroup	*autogroup;
#endif

	struct cfs_bandwidth	cfs_bandwidth;
};

struct cfs_bandwidth {
#ifdef CONFIG_CFS_BANDWIDTH
	raw_spinlock_t		lock;
	ktime_t			period;
	u64			quota;
	u64			runtime;
	s64			hierarchical_quota;
	u64			runtime_expires;
	int			expires_seq;

	short			idle;
	short			period_active;
	struct hrtimer		period_timer;
	struct hrtimer		slack_timer;
	struct list_head	throttled_cfs_rq;

	/* Statistics: */
	int			nr_periods;
	int			nr_throttled;
	u64			throttled_time;

	bool                    distribute_running;
#endif
};
```
> Documentation/admin-guide/cgroup-v1/cgroups.rst
