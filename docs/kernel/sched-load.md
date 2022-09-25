
```txt
#0  update_load_avg (cfs_rq=0xffff888145898200, se=0xffff88814a10af00, flags=1) at kernel/sched/fair.c:4009
#1  0xffffffff81145747 in entity_tick (queued=0, curr=0xffff88814a10af00, cfs_rq=0xffff888145898200) at kernel/sched/fair.c:4740
#2  task_tick_fair (rq=0xffff888333d2b2c0, curr=0xffff88814a10ae80, queued=0) at kernel/sched/fair.c:11416
#3  0xffffffff8113f392 in scheduler_tick () at kernel/sched/core.c:5453
#4  0xffffffff8119b2b1 in update_process_times (user_tick=0) at kernel/time/timer.c:1844
#5  0xffffffff811ad85f in tick_sched_handle (ts=ts@entry=0xffff888333d1e5c0, regs=regs@entry=0xffffc900000c8ee8) at kernel/time/tick-sched.c:243
#6  0xffffffff811ada3c in tick_sched_timer (timer=0xffff888333d1e5c0) at kernel/time/tick-sched.c:1480
#7  0xffffffff8119bde2 in __run_hrtimer (flags=130, now=0xffffc900000c8e20, timer=0xffff888333d1e5c0, base=0xffff888333d1e0c0, cpu_base=0xffff888333d1e080) at kernel/time/hrtimer.c:1685
#8  __hrtimer_run_queues (cpu_base=cpu_base@entry=0xffff888333d1e080, now=48647511875190, flags=flags@entry=130, active_mask=active_mask@entry=15) at kernel/time/hrtimer.c:1749
#9  0xffffffff8119ca71 in hrtimer_interrupt (dev=<optimized out>) at kernel/time/hrtimer.c:1811
```
- update_load_avg
  - propagate_entity_load_avg
	- update_tg_cfs_util
	- update_tg_cfs_runnable
	- update_tg_cfs_load
