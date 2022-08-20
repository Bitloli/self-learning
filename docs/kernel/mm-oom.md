# oom

核心结构体 `oom_control`，主要记录事发现场。

主要的入口为 `out_of_memory`，调用着有三个
- `page_alloc.c:__alloc_pages_may_oom`
- `sysrq:moom_callback` : 通过  sudo echo f > /proc/sysrq-trigger 手动触发
- `mmecontrol:mem_cgroup_out_of_memory` : 用户程序分配内存的时候，经过 cgroup 的检查 `mem_cgroup_charge` 没有通过

- 为什么 oom 会因为 cpuset ？
```c
struct oom_control {
	/* Used to determine cpuset */
	struct zonelist *zonelist;
```

- `__cpuset_node_allowed` ：深入调查一下这个

- reaper 是做啥的?

<script src="https://giscus.app/client.js"
        data-repo="martins3/martins3.github.io"
        data-repo-id="MDEwOlJlcG9zaXRvcnkyOTc4MjA0MDg="
        data-category="Show and tell"
        data-category-id="MDE4OkRpc2N1c3Npb25DYXRlZ29yeTMyMDMzNjY4"
        data-mapping="pathname"
        data-reactions-enabled="1"
        data-emit-metadata="0"
        data-theme="light"
        data-lang="zh-CN"
        crossorigin="anonymous"
        async>
</script>

本站所有文章转发 **CSDN** 将按侵权追究法律责任，其它情况随意。
