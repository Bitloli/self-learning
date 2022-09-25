## try_to_wake_up 的辅助函数 `ttwu_
1. remote 的概念 ?

```c
static void ttwu_queue(struct task_struct *p, int cpu, int wake_flags)
{
	struct rq *rq = cpu_rq(cpu);
	struct rq_flags rf;

#if defined(CONFIG_SMP)
	if (sched_feat(TTWU_QUEUE) && !cpus_share_cache(smp_processor_id(), cpu)) {
		sched_clock_cpu(cpu); /* Sync clocks across CPUs */
		ttwu_queue_remote(p, cpu, wake_flags);
		return;
	}
#endif

	rq_lock(rq, &rf);
	update_rq_clock(rq);
	ttwu_do_activate(rq, p, wake_flags, &rf);
	rq_unlock(rq, &rf);
}
```

```c
/*
 * Called in case the task @p isn't fully descheduled from its runqueue,
 * in this case we must do a remote wakeup. Its a 'light' wakeup though,
 * since all we need to do is flip p->state to TASK_RUNNING, since
 * the task is still ->on_rq.
 */
static int ttwu_remote(struct task_struct *p, int wake_flags)
{
	struct rq_flags rf;
	struct rq *rq;
	int ret = 0;

	rq = __task_rq_lock(p, &rf);
	if (task_on_rq_queued(p)) {
		/* check_preempt_curr() may use rq clock */
		update_rq_clock(rq);
		ttwu_do_wakeup(rq, p, wake_flags, &rf);
		ret = 1;
	}
	__task_rq_unlock(rq, &rf);

	return ret;
}
```

activate_task : 既然就是一个加入到队列中间 ?
```c
void activate_task(struct rq *rq, struct task_struct *p, int flags)
{
	if (task_contributes_to_load(p))
		rq->nr_uninterruptible--;

	enqueue_task(rq, p, flags);
}
```

> 下面两个顶层函数

![](../../img/source/ttwu_queue.png)
![](../../img/source/ttwu_remote.png)

![](../../img/source/ttwu_do_activate.png)
> 我们的核心函数 ?

![](../../img/source/ttwu_do_wakeup.png)
![](../../img/source/ttwu_activate.png)
![](../../img/source/ttwu_queue_remote.png)

![](../../img/source/try_to_wake_up_local.png)

1. try_to_wake_up 和 try_to_wake_up_local 的关系是什么 ?
2. remote wakeup 的含义是什么 ?

## sched_ttwu_pending

该函数似乎是将所有 rq 中的所有的，wake_list

```c
void sched_ttwu_pending(void)
{
	struct rq *rq = this_rq();
	struct llist_node *llist = llist_del_all(&rq->wake_list);
	struct task_struct *p, *t;
	struct rq_flags rf;

	if (!llist)
		return;

	rq_lock_irqsave(rq, &rf);
	update_rq_clock(rq);

	llist_for_each_entry_safe(p, t, llist, wake_entry)
		ttwu_do_activate(rq, p, p->sched_remote_wakeup ? WF_MIGRATED : 0, &rf);

	rq_unlock_irqrestore(rq, &rf);
}
```

![](../../img/source/sched_ttwu_pending.png)

> @todo 分析其中的调用位置是什么 ?
