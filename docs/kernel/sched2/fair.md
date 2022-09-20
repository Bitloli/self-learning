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
