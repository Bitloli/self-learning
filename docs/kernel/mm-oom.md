 # oom


- 为什么 oom 会因为 cpuset ？
```c
struct oom_control {
	/* Used to determine cpuset */
	struct zonelist *zonelist;
```
- `__cpuset_node_allowed` ：深入调查一下这个
