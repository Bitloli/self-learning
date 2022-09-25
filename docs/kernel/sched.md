## 基本结构体
- sched_entity
- sched_rt_entity
- sched_dl_entity

- struct rq
```c
struct rq {
    // ...
    struct cfs_rq       cfs;
    struct rt_rq        rt;
    struct dl_rq        dl;
    // ...
```

- struct cfs_rq     cfs;
- struct rt_rq      rt;
- struct dl_rq      dl;

- 似乎 stop 和 idle 过于蛇皮，没有对应 rq 结构体
- 所以其实 rq 和 sched_class 是对应的!


- sched_class

## 问题和记录
- [ ] 似乎存在一个机制，让 thread 一个时间段必须运行一段时间。
- [ ] 将奇怪的 thread process / process group / session 总结一下

## v2
- https://facebookmicrosites.github.io/cgroup2/docs/cpu-controller.html
