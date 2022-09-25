# 首先，理解了
- https://docs.kernel.org/admin-guide/pm/intel-speed-select.html

- 打印出来当前正在 CPU 上运行的:
```sh
ps -e -o pid,ppid,sgi_p,state,args | awk '$3!="*" {print}'
```

- Scheduler Domain 从 acpi 中获取吗?


- (CONFIG_ENERGY_MODEL) && (CONFIG_CPU_FREQ_GOV_SCHEDUTIL) : 做什么的 ?
- get_group 和 build_balance_mask 上有非常多暂时看不懂的注释

# topology
- [ ] build_balance_mask
  - span
  - sched_domain_topology_level
- sched_group
- root_domain
  - init_rootdomain

- cpu_attach_domain

- degenerate

- rq_attach_root

## 如何初始化

## 什么时候切换

## 大核小核的影响

## 如何实现 taskset 的效果

## 关键结构体

### root_domain

```c
/*
 * We add the notion of a root-domain which will be used to define per-domain
 * variables. Each exclusive cpuset essentially defines an island domain by
 * fully partitioning the member CPUs from any other cpuset. Whenever a new
 * exclusive cpuset is created, we also create and attach a new root-domain
 * object.
 *
 */
struct root_domain {
	atomic_t		refcount;
	atomic_t		rto_count;
	struct rcu_head		rcu;
	cpumask_var_t		span;
	cpumask_var_t		online;

	/*
	 * Indicate pullable load on at least one CPU, e.g:
	 * - More than one runnable task
	 * - Running task is misfit
	 */
	int			overload;

	/* Indicate one or more cpus over-utilized (tipping point) */
	int			overutilized;

	/*
	 * The bit corresponding to a CPU gets set here if such CPU has more
	 * than one runnable -deadline task (as it is below for RT tasks).
	 */
	cpumask_var_t		dlo_mask;
	atomic_t		dlo_count;
	struct dl_bw		dl_bw;
	struct cpudl		cpudl;

	/*
	 * Indicate whether a root_domain's dl_bw has been checked or
	 * updated. It's monotonously increasing value.
	 *
	 * Also, some corner cases, like 'wrap around' is dangerous, but given
	 * that u64 is 'big enough'. So that shouldn't be a concern.
	 */
	u64 visit_gen;

#ifdef HAVE_RT_PUSH_IPI
	/*
	 * For IPI pull requests, loop across the rto_mask.
	 */
	struct irq_work		rto_push_work;
	raw_spinlock_t		rto_lock;
	/* These are only updated and read within rto_lock */
	int			rto_loop;
	int			rto_cpu;
	/* These atomics are updated outside of a lock */
	atomic_t		rto_loop_next;
	atomic_t		rto_loop_start;
#endif
	/*
	 * The "RT overload" flag: it gets set if a CPU has more than
	 * one runnable RT task.
	 */
	cpumask_var_t		rto_mask;
	struct cpupri		cpupri;

	unsigned long		max_cpu_capacity;

	/*
	 * NULL-terminated list of performance domains intersecting with the
	 * CPUs of the rd. Protected by RCU.
	 */
	struct perf_domain __rcu *pd;
};
```


### sched_group
```c
struct sched_group {
	struct sched_group	*next;			/* Must be a circular list */
	atomic_t		ref;

	unsigned int		group_weight;
	struct sched_group_capacity *sgc;
	int			asym_prefer_cpu;	/* CPU of highest priority in group */
	int			flags;

	/*
	 * The CPUs this group covers.
	 *
	 * NOTE: this field is variable length. (Allocated dynamically
	 * by attaching extra space to the end of the structure,
	 * depending on how many CPUs the kernel has booted up with)
	 */
	unsigned long		cpumask[];
};
```

### sched_domain
```c
struct sched_domain {
	/* These fields must be setup */
	struct sched_domain __rcu *parent;	/* top domain must be null terminated */
	struct sched_domain __rcu *child;	/* bottom domain must be null terminated */
	struct sched_group *groups;	/* the balancing groups of the domain */
	unsigned long min_interval;	/* Minimum balance interval ms */
	unsigned long max_interval;	/* Maximum balance interval ms */
	unsigned int busy_factor;	/* less balancing by factor if busy */
	unsigned int imbalance_pct;	/* No balance until over watermark */
	unsigned int cache_nice_tries;	/* Leave cache hot tasks for # tries */
	unsigned int imb_numa_nr;	/* Nr running tasks that allows a NUMA imbalance */

	int nohz_idle;			/* NOHZ IDLE status */
	int flags;			/* See SD_* */
	int level;

	/* Runtime fields. */
	unsigned long last_balance;	/* init to jiffies. units in jiffies */
	unsigned int balance_interval;	/* initialise to 1. units in ms. */
	unsigned int nr_balance_failed; /* initialise to 0 */

	/* idle_balance() stats */
	u64 max_newidle_lb_cost;
	unsigned long last_decay_max_lb_cost;

	u64 avg_scan_cost;		/* select_idle_sibling */

#ifdef CONFIG_SCHEDSTATS
	/* load_balance() stats */
	unsigned int lb_count[CPU_MAX_IDLE_TYPES];
	unsigned int lb_failed[CPU_MAX_IDLE_TYPES];
	unsigned int lb_balanced[CPU_MAX_IDLE_TYPES];
	unsigned int lb_imbalance[CPU_MAX_IDLE_TYPES];
	unsigned int lb_gained[CPU_MAX_IDLE_TYPES];
	unsigned int lb_hot_gained[CPU_MAX_IDLE_TYPES];
	unsigned int lb_nobusyg[CPU_MAX_IDLE_TYPES];
	unsigned int lb_nobusyq[CPU_MAX_IDLE_TYPES];

	/* Active load balancing */
	unsigned int alb_count;
	unsigned int alb_failed;
	unsigned int alb_pushed;

	/* SD_BALANCE_EXEC stats */
	unsigned int sbe_count;
	unsigned int sbe_balanced;
	unsigned int sbe_pushed;

	/* SD_BALANCE_FORK stats */
	unsigned int sbf_count;
	unsigned int sbf_balanced;
	unsigned int sbf_pushed;

	/* try_to_wake_up() stats */
	unsigned int ttwu_wake_remote;
	unsigned int ttwu_move_affine;
	unsigned int ttwu_move_balance;
#endif
#ifdef CONFIG_SCHED_DEBUG
	char *name;
#endif
	union {
		void *private;		/* used during construction */
		struct rcu_head rcu;	/* used during destruction */
	};
	struct sched_domain_shared *shared;

	unsigned int span_weight;
	/*
	 * Span of all CPUs in this domain.
	 *
	 * NOTE: this field is variable length. (Allocated dynamically
	 * by attaching extra space to the end of the structure,
	 * depending on how many CPUs the kernel has booted up with)
	 */
	unsigned long span[];
};
```

# cpumask
- start_kernel
  - setup_arch
      - smp_init_cpus :
        - of_parse_and_init_cpus
        - acpi_parse_and_init_cpus
        - smp_cpu_setup
          - set_cpu_possible
            - **cpumask_set_cpu(cpu, &__cpu_possible_mask);**
  - arch_call_rest_init
    - rest_init
      - kernel_init
        - kernel_init_freeable
          - smp_prepare_cpus
            - set_cpu_present : 如果这只是将 possible 拷贝到 present，其意义何在 ?
              - **cpumask_set_cpu(cpu, &__cpu_present_mask);**
          - smp_init
            - bringup_nonboot_cpus
              - cpu_up : 实际上，跟丢了

SMT : L1 高速共享
MC  : 共享 LLC
SOC : DIE

```plain
config SCHED_SMT
    bool "SMT (Hyperthreading) scheduler support"
    depends on SPARC64 && SMP
    default y
    help
      SMT scheduler support improves the CPU scheduler's decision making
      when dealing with SPARC cpus at a cost of slightly increased overhead
      in some places. If unsure say N here.

config SCHED_MC
    bool "Multi-core scheduler support"
    depends on SPARC64 && SMP
    default y
    help
      Multi-core scheduler support improves the CPU scheduler's decision
      making when dealing with multi-core CPU chips at a cost of slightly
      increased overhead in some places. If unsure say N here.
```

```c
/*
 * Topology list, bottom-up.
 */
static struct sched_domain_topology_level default_topology[] = {
#ifdef CONFIG_SCHED_SMT
    { cpu_smt_mask, cpu_smt_flags, SD_INIT_NAME(SMT) },
#endif
#ifdef CONFIG_SCHED_MC
    { cpu_coregroup_mask, cpu_core_flags, SD_INIT_NAME(MC) },
#endif
    { cpu_cpu_mask, SD_INIT_NAME(DIE) },
    { NULL, },
};

typedef const struct cpumask *(*sched_domain_mask_f)(int cpu);
typedef int (*sched_domain_flags_f)(void);

struct sched_domain_topology_level {
    sched_domain_mask_f mask;      // 返回某个 cpu 在该 topology level 下的 CPU 的兄弟 cpu 的 mask
    sched_domain_flags_f sd_flags; // 用于返回 domain 的属性
    int         flags;
    int         numa_level;
    struct sd_data      data;
};

struct sd_data {
    struct sched_domain *__percpu *sd; // 优秀啊，每一个 cpu 都保存一份所有人的 sched_domain
    struct sched_domain_shared *__percpu *sds;
    struct sched_group *__percpu *sg;
    struct sched_group_capacity *__percpu *sgc;
};
```

- 在 sched_domain 被划分为 sched_group, sched_group 是调度最小单位。
  - [ ] 感觉这么定义的话，岂不是下一级的 sched_domain 就上级的 sched_group
- sched_domain_span 表示 cpu 当前的 domain 管辖的 cpu 范围


- sched_init_domains
  - build_sched_domains
  - `__visit_domain_allocation_hell`
    - `__sdt_alloc`
    - alloc_rootdomain
  - build_sched_domain
    - sd_init
  - build_sched_groups

- 构建 domain 的结果是，在每一个 topology level 中间都存在 NR_cpu 个 sched_domain
  - 这个 sched_domain 包含一定数量的 cpu
  - sched_domain 指向一个链表的 sched_group
