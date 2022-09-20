## 搞点 backtrace

sudo cgcreate -g cpu:A

## 似乎 cgcreate 不能在 v2 下使用
```txt
➜ sudo cgcreate -g cpu:A

[sudo] password for martins3:
cgcreate: libcgroup initialization failed: Cgroup is not mounted
```

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


#### 理解 task_group
> For example, it may be desirable to first provide fair CPU time to each user on the system and then to each task belonging to a user.

1. 如何确定将哪一个 thread 加入到哪一个 group ?
2. 创建 thread group 的创建的时机是什么 ?
3. thread group 让整个 reb tree 如何构建 ?
4. 一个 thread group 会不会对于另一个 thread group 含有优先级 ?
5. 是不是一旦配置了 tg 那么就所有的 thread 都必须属于某一个 group 中间 ?


## 如何切换 cgroup v2
- https://kubernetes.io/docs/concepts/architecture/cgroups/

```sh
stat -fc %T /sys/fs/cgroup/
```
