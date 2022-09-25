## 问题

1. 如何确定将哪一个 thread 加入到哪一个 group ?
2. 创建 thread group 的创建的时机是什么 ?
3. thread group 让整个 reb tree 如何构建 ?
4. 一个 thread group 会不会对于另一个 thread group 含有优先级 ?
5. 是不是一旦配置了 tg 那么就所有的 thread 都必须属于某一个 group 中间 ?

- [ ] bandwidth 和 share 如何协同工作



## 如何切换 cgroup v2 来测试
检测当前是那个版本: https://kubernetes.io/docs/concepts/architecture/cgroups/

```sh
stat -fc %T /sys/fs/cgroup/
```
- tmpfs : v1
- cgroup2fs : v2

```sh
sudo grubby --update-kernel=ALL --args=systemd.unified_cgroup_hierarchy=1
```

老版本的 libcgroup 不能支持 cgroup v2 :
```txt
➜ sudo cgcreate -g cpu:A

[sudo] password for martins3:
cgcreate: libcgroup initialization failed: Cgroup is not mounted
```

centos 8 上手动安装

```sh
sudo yum install autoconf
sudo yum install aclocal
sudo yum install automake
sudo yum install libtool
sudo yum install pam-devel
```

然后参考此处: https://askubuntu.com/questions/27677/cannot-find-install-sh-install-sh-or-shtool-in-ac-aux
```c
libtoolize --force
aclocal
autoheader
automake --force-missing --add-missing
autoconf
```

最后参考官方文档:
```c
./configure; make; make install
```

### 基本操作
- list_add_leaf_cfs_rq
- list_add_leaf_cfs_rq
- [ ] init_tg_cfs_entry

### CONFIG_CFS_BANDWIDTH

参考资料:
- https://www.kernel.org/doc/Documentation/scheduler/sched-bwc.txt

> CFS bandwidth control is a `CONFIG_FAIR_GROUP_SCHED` extension which allows the
> specification of the maximum CPU bandwidth available to a group or hierarchy.
>
> The bandwidth allowed for a group is specified using a quota and period. Within
> each given "period" (microseconds), a group is allowed to consume only up to
> "quota" microseconds of CPU time.  When the CPU bandwidth consumption of a
> group exceeds this limit (for that period), the tasks belonging to its
> hierarchy will be throttled and are not allowed to run again until the next
> period.

总结到位。

## 创建
- sudo cgcreate -g cpu:A

```txt
#0  alloc_fair_sched_group (tg=tg@entry=0xffff888142e18000, parent=parent@entry=0xffffffff834a2000 <root_task_group>) at include/linux/slab.h:640
#1  0xffffffff8113e15a in sched_create_group (parent=0xffffffff834a2000 <root_task_group>) at kernel/sched/core.c:10097
#2  0xffffffff8113e1ca in cpu_cgroup_css_alloc (parent_css=<optimized out>) at kernel/sched/core.c:10246
#3  0xffffffff811ba029 in css_create (ss=0xffffffff82a63c00 <cpu_cgrp_subsys>, cgrp=0xffff888109618800) at kernel/cgroup/cgroup.c:5384
#4  cgroup_apply_control_enable (cgrp=cgrp@entry=0xffff888109618800) at kernel/cgroup/cgroup.c:3204
#5  0xffffffff811bc1ef in cgroup_mkdir (parent_kn=0xffff888141a0c980, name=<optimized out>, mode=<optimized out>) at kernel/cgroup/cgroup.c:5602
#6  0xffffffff813e2d29 in kernfs_iop_mkdir (mnt_userns=<optimized out>, dir=<optimized out>, dentry=<optimized out>, mode=<optimized out>) at fs/kernfs/dir.c:1185
#7  0xffffffff81359dbf in vfs_mkdir (mnt_userns=0xffffffff82a61a80 <init_user_ns>, dir=0xffff8881408c2490, dentry=dentry@entry=0xffff888148895c00, mode=<optimized out>, mode@entry=509) at fs/namei.c:4013
#8  0xffffffff8135ebc1 in do_mkdirat (dfd=dfd@entry=-100, name=0xffff888004103000, mode=mode@entry=509) at fs/namei.c:4038
#9  0xffffffff8135edb3 in __do_sys_mkdir (mode=<optimized out>, pathname=<optimized out>) at fs/namei.c:4058
#10 __se_sys_mkdir (mode=<optimized out>, pathname=<optimized out>) at fs/namei.c:4056
#11 __x64_sys_mkdir (regs=<optimized out>) at fs/namei.c:4056
#12 0xffffffff81f3356b in do_syscall_x64 (nr=<optimized out>, regs=0xffffc900015d3f58) at arch/x86/entry/common.c:50
#13 do_syscall_64 (regs=0xffffc900015d3f58, nr=<optimized out>) at arch/x86/entry/common.c:80
#14 0xffffffff8200009b in entry_SYSCALL_64 () at arch/x86/entry/entry_64.S:120
```

在 sudo su 的时候，调用 setsid 的时候切换:

```txt
#0  alloc_fair_sched_group (tg=tg@entry=0xffff8880040c3c00, parent=parent@entry=0xffffffff834af000 <root_task_group>) at include/linux/slab.h:640
#1  0xffffffff811410de in sched_create_group (parent=0xffffffff834af000 <root_task_group>) at kernel/sched/core.c:10097
#2  0xffffffff811596b6 in autogroup_create () at kernel/sched/build_utility.c:10575
#3  sched_autogroup_create_attach (p=p@entry=0xffff888144d0bd00) at kernel/sched/build_utility.c:10676
#4  0xffffffff8111ee71 in ksys_setsid () at kernel/sys.c:1234
#5  0xffffffff8111eea5 in __do_sys_setsid (__unused=<optimized out>) at kernel/sys.c:1241
#6  0xffffffff81f3d6eb in do_syscall_x64 (nr=<optimized out>, regs=0xffffc90002abff58) at arch/x86/entry/common.c:50
#7  do_syscall_64 (regs=0xffffc90002abff58, nr=<optimized out>) at arch/x86/entry/common.c:80
#8  0xffffffff8200009b in entry_SYSCALL_64 () at arch/x86/entry/entry_64.S:120
```

- sched_online_group
- sched_offline_group

## 设置，以 cpu.max 为例

当 echo "10000 100000"  > cpu.max 之后，

```sh
sudo cgexec -g cpu:C dd if=/dev/zero of=/dev/null &
```

然后使用 top 去观测，发现 CPU 使用量就是 10%

- tg_set_cfs_bandwidth 进一步调用 `__cfs_schedulable`

- tg_cfs_scheduable_down　// 放到 walk_tg_tree_from 的参数吧!


```txt
#0  tg_set_cfs_bandwidth (tg=tg@entry=0xffff888104f1fc00, period=1000000, quota=18446744073709551615, burst=0, burst@entry=<error reading variable: That operation is not available on integers of more than 8 bytes.>) at kernel/sched/core.c:10558
#1  0xffffffff81138def in cpu_max_write (of=<optimized out>, buf=0xffff8881491cd180 "max 1000\n", nbytes=9, off=<optimized out>) at kernel/sched/core.c:11110
#2  0xffffffff813ee51e in kernfs_fop_write_iter (iocb=0xffffc90000fbbea0, iter=<optimized out>) at fs/kernfs/file.c:354
#3  0xffffffff813559cc in call_write_iter (iter=0xffffc90000fbbe78, kio=0xffffc90000fbbea0, file=0xffff88814b5c0c00) at include/linux/fs.h:2187
#4  new_sync_write (ppos=0xffffc90000fbbf08, len=9, buf=0x55ded7ad60c0 "max 1000\n", filp=0xffff88814b5c0c00) at fs/read_write.c:491
#5  vfs_write (file=file@entry=0xffff88814b5c0c00, buf=buf@entry=0x55ded7ad60c0 "max 1000\n", count=count@entry=9, pos=pos@entry=0xffffc90000fbbf08) at fs/read_write.c:578
#6  0xffffffff81355d9a in ksys_write (fd=<optimized out>, buf=0x55ded7ad60c0 "max 1000\n", count=9) at fs/read_write.c:631
#7  0xffffffff81f3d6eb in do_syscall_x64 (nr=<optimized out>, regs=0xffffc90000fbbf58) at arch/x86/entry/common.c:50
#8  do_syscall_64 (regs=0xffffc90000fbbf58, nr=<optimized out>) at arch/x86/entry/common.c:80
```

这里在同时分析两个数值，period 和 quota

```c
struct cfs_bandwidth {
    // ...
	ktime_t			period;
	u64			quota;
```

关于 period

- start_cfs_bandwidth : 重置 period 的时钟

```txt
#0  start_cfs_bandwidth (cfs_b=0xffff888141e9a4c8) at kernel/sched/fair.c:5510
#1  __assign_cfs_rq_runtime (target_runtime=5000000, cfs_rq=0xffff8881439c5600, cfs_b=0xffff888141e9a4c8) at kernel/sched/fair.c:4856
#2  assign_cfs_rq_runtime (cfs_rq=0xffff8881439c5600) at kernel/sched/fair.c:4877
#3  __account_cfs_rq_runtime (cfs_rq=0xffff8881439c5600, delta_exec=<optimized out>) at kernel/sched/fair.c:4897
#4  0xffffffff81145737 in entity_tick (queued=0, curr=0xffff888151b6af00, cfs_rq=0xffff8881439c5600) at kernel/sched/fair.c:4735
#5  task_tick_fair (rq=0xffff888333c2b2c0, curr=0xffff888151b6ae80, queued=0) at kernel/sched/fair.c:11416
#6  0xffffffff8113f392 in scheduler_tick () at kernel/sched/core.c:5453
#7  0xffffffff8119b2b1 in update_process_times (user_tick=0) at kernel/time/timer.c:1844
#8  0xffffffff811ad85f in tick_sched_handle (ts=ts@entry=0xffff888333c1e5c0, regs=regs@entry=0xffffc9000098be88) at kernel/time/tick-sched.c:243
#9  0xffffffff811ada3c in tick_sched_timer (timer=0xffff888333c1e5c0) at kernel/time/tick-sched.c:1480
#10 0xffffffff8119bde2 in __run_hrtimer (flags=6, now=0xffffc90000003f48, timer=0xffff888333c1e5c0, base=0xffff888333c1e0c0, cpu_base=0xffff888333c1e080) at kernel/time/hrtimer.c:1685
#11 __hrtimer_run_queues (cpu_base=cpu_base@entry=0xffff888333c1e080, now=3236401072342, flags=flags@entry=6, active_mask=active_mask@entry=15) at kernel/time/hrtimer.c:1749
#12 0xffffffff8119ca71 in hrtimer_interrupt (dev=<optimized out>) at kernel/time/hrtimer.c:1811
#13 0xffffffff810e25d7 in local_apic_timer_interrupt () at arch/x86/kernel/apic/apic.c:1095
#14 __sysvec_apic_timer_interrupt (regs=<optimized out>) at arch/x86/kernel/apic/apic.c:1112
#15 0xffffffff81f4137d in sysvec_apic_timer_interrupt (regs=0xffffc9000098be88) at arch/x86/kernel/apic/apic.c:1106
```

period 时钟注册的 hook : sched_cfs_period_timer -> do_sched_cfs_period_timer -> `__refill_cfs_bandwidth_runtime` / distribute_cfs_runtime

如何形成约束:
- `update_curr` -> `account_cfs_rq_runtime` 中需要更新统计时间。
- enqueue_entity -> check_enqueue_throttle => throttle_cfs_rq 在其中的检查是层次的性的。

### CONFIG_FAIR_GROUP_SCHED

## 设置

```txt
#0  __sched_group_set_shares (tg=0xffff888141e9a300, shares=104448) at kernel/sched/fair.c:11845
#1  0xffffffff8114be9a in sched_group_set_shares (tg=0xffff888141e9a300, shares=104448) at kernel/sched/fair.c:11880
#2  0xffffffff811bb84b in cgroup_file_write (of=<optimized out>, buf=0xffff8881547244a0 "10\n", nbytes=3, off=<optimized out>) at kernel/cgroup/cgroup.c:3983
#3  0xffffffff813ee51b in kernfs_fop_write_iter (iocb=0xffffc9000099bea0, iter=<optimized out>) at fs/kernfs/file.c:354
#4  0xffffffff813559c9 in call_write_iter (iter=0x19800 <bts_ctx+10240>, kio=0xffff888141e9a300, file=0xffff888155f80e00) at include/linux/fs.h:2187
#5  new_sync_write (ppos=0xffffc9000099bf08, len=3, buf=0x5588fa0d60c0 "10\n", filp=0xffff888155f80e00) at fs/read_write.c:491
#6  vfs_write (file=file@entry=0xffff888155f80e00, buf=buf@entry=0x5588fa0d60c0 "10\n", count=count@entry=3, pos=pos@entry=0xffffc9000099bf08) at fs/read_write.c:578
#7  0xffffffff81355d9a in ksys_write (fd=<optimized out>, buf=0x5588fa0d60c0 "10\n", count=3) at fs/read_write.c:631
#8  0xffffffff81f3d6e8 in do_syscall_x64 (nr=<optimized out>, regs=0xffffc9000099bf58) at arch/x86/entry/common.c:50
#9  do_syscall_64 (regs=0xffffc9000099bf58, nr=<optimized out>) at arch/x86/entry/common.c:80
```

应该是将 weight 更新，从而导致让 weight 小的使用量更小。

## cfs_bandwidth::period_timer 和 cfs_bandwidth::slack_timer

start_cfs_bandwidth : 似乎是开始计时的函数。

slack_timer 的作用似乎是: 用于计算没有用完的时间的。
```c
static void dequeue_entity(struct cfs_rq *cfs_rq, struct sched_entity *se, int flags)
    static __always_inline void return_cfs_rq_runtime(struct cfs_rq *cfs_rq)
        /* we know any runtime found here is valid as update_curr() precedes return */
        static void __return_cfs_rq_runtime(struct cfs_rq *cfs_rq)
            static void start_cfs_slack_bandwidth(struct cfs_bandwidth *cfs_b)
```

## unthrottle_cfs_rq 和 throttle_cfs_rq 利用上 timer 机制

```c
// 这就是两个检查是否超过 bandwidth 的时机:
check_enqueue_throttle : 被 enqueue_entity 唯一处理
check_cfs_rq_runtime
  static void throttle_cfs_rq(struct cfs_rq *cfs_rq) // todo 观察其中，就可以知道到底如何实现控制 bandwidth


void unthrottle_cfs_rq(struct cfs_rq *cfs_rq)
```

![](../../img/source/check_cfs_rq_runtime.png)

> put_prev_entity 为什么需要 check_cfs_rq_runtime ? 都已经离开队列了，为什么还是需要处理 ?

![](../../img/source/unthrottle_cfs_rq.png)


分析一下:
```c
/*
 * Responsible for refilling a task_group's bandwidth and unthrottling its
 * cfs_rqs as appropriate. If there has been no activity within the last
 * period the timer is deactivated until scheduling resumes; cfs_b->idle is
 * used to track this state.
 */
static int do_sched_cfs_period_timer(struct cfs_bandwidth *cfs_b, int overrun)


/*
 * This is done with a timer (instead of inline with bandwidth return) since
 * it's necessary to juggle rq->locks to unthrottle their respective cfs_rqs.
 */
static void do_sched_cfs_slack_timer(struct cfs_bandwidth *cfs_b)


static enum hrtimer_restart sched_cfs_period_timer(struct hrtimer *timer)
static enum hrtimer_restart sched_cfs_slack_timer(struct hrtimer *timer)

void init_cfs_bandwidth(struct cfs_bandwidth *cfs_b) // 上述函数注册的位置
```

## 需要分析的一些细节

cfs_bandwith_used() 简单的辅助函数，用于开关 bandwidth 机制。
和 `void cfs_bandwidth_usage_inc(void)` 和 `void cfs_bandwidth_usage_dec(void)` 配合使用。

## tg_set_cfs_

调用者 : 都是来自于 cgroup 机制的
- tg_set_cfs_cpu
- tg_set_cfs_period
- cpu_max_write

## rq_offline_fair 和 rq_online_fair 的作用是什么

online 和 offline 表示 cpu 的添加和去除。

```c
static void rq_online_fair(struct rq *rq)
{
	update_sysctl();

	update_runtime_enabled(rq);
}
```

利用 此处的 git blame 可以找到当时添加此函数的原因是什么东西 ?
