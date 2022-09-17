# numa
1. 创建的内存最好是就是在附近 ：buddy 和 slub 分配器的策略，这些策略被整理成为 mempolicy.c
2. 运行过程中间发生变化 : migrate.c

首先分析一波 numa 的基础知识 [^6]

用户层次:
Available policies are
1. **page interleaving** (i.e., allocate in a round-robin fashion from all, or a subset, of the nodes on the system), inorder to overload the initial boot node with boot-time allocations.
2. **preferred node allocation** (i.e., preferably allocate on a particular node),
3. **local allocation** (i.e., allocate on the node on which the task is currently executing), or
4. **allocation only on specific nodes** (i.e., allocate on some subset of the available nodes).  It is also possible to bind tasks to specific nodes.

分析 syscall :
1. get_mempolicy
2. mbind
3. migrate_page

## mempolicy

1. Memory policies are a programming interface that a NUMA-aware application can take advantage of.
2. cpusets which is an administrative mechanism for restricting the nodes from which memory may be allocated by a set of processes.  cpuset 和 numa mempolicy 同时出现的时候，cpuset 优先
3. 一共四个模式 和 两个 flags MPOL_F_STATIC_NODES 和 MPOL_F_RELATIVE_NODES (**flag 的作用有点迷**)
4. 还分析了一下 mol_put 和 mol_get 的问题

```c
// 获取 vma 对应的 policy ，解析出来 preferred_nid 和 nodemask 然后
struct page * alloc_pages_vma(gfp_t gfp, int order, struct vm_area_struct *vma, unsigned long addr, int node, bool hugepage)
```
> 感觉 mempolicy 并没有什么特殊的地方，只是提供一个 syscall 给用户。


## 问题

- [ ] 如何理解这个？
```c
/*
 * Array of node states.
 */
nodemask_t node_states[NR_NODE_STATES] __read_mostly = {
	[N_POSSIBLE] = NODE_MASK_ALL,
	[N_ONLINE] = { { [0] = 1UL } },
#ifndef CONFIG_NUMA
	[N_NORMAL_MEMORY] = { { [0] = 1UL } },
#ifdef CONFIG_HIGHMEM
	[N_HIGH_MEMORY] = { { [0] = 1UL } },
#endif
	[N_MEMORY] = { { [0] = 1UL } },
	[N_CPU] = { { [0] = 1UL } },
#endif	/* NUMA */
};
EXPORT_SYMBOL(node_states);
```
- [ ] 到底 memory policy 是一个进程的行为还是直接影响所有的程序的

## 设备和 numa 的关系是什么


[^6]: [NUMA (Non-Uniform Memory Access): An Overview](https://queue.acm.org/detail.cfm?id=2513149)
[^7]: [kernel doc : numa memory policy](https://www.kernel.org/doc/html/latest/admin-guide/mm/numa_memory_policy.html)
