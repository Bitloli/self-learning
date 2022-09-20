## pelt
[Per-entity load tracking](https://lwn.net/Articles/531853/)

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
