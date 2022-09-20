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
