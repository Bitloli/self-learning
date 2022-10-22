- https://unix.stackexchange.com/questions/297591/swap-cache-of-vmstat-vs-swapcached-of-proc-meminfo
  - 这里面介绍了好几个工具，都仔细看看

- http://linux.laoqinren.net/archives/ : 存在几篇 blog 分析这个
- https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=34e431b0ae398fc54ea69ff85ec700722c9da773
  - MemAvailable  和 MemFree 是什么关系
- https://lwn.net/Articles/178850/


- [ ] 将 /proc/sys/vm 中的内容分析一下

- [ ] /proc/meminfo /proc/sys/vm/nr_hugepages /proc/sys/vm/nr_overcommit_hugepages /sys/kernel/mm/hugepages /sys/devices/system/node/node0/hugepages/hugepages-1048576kB/ /sys/kernel/
/sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages 都是一些什么东西 :
检查以下这些参数的作用
  - [ ] /proc/meminfo 的 HugePages_Rsvd 的含义是什么 ? 下面的代码，为什么不会导致 HugePages_Free 减少，而是 HugePages_Rsvd 增加
```c
#include <stdio.h>
#include <stdlib.h> // malloc
#include <sys/mman.h>
#include <asm/mman.h>
#include <sys/types.h>
#include <unistd.h> // sleep

int main(int argc, char *argv[]) {
  size_t SIZE_2M = 1 << 21;
  char *addr = (char *)mmap(0, SIZE_2M, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE | MAP_HUGETLB, -1, 0);
  if (addr == MAP_FAILED) {
    perror("mmap");
    exit(1);
  }
  for (int i = 0; i < SIZE_2M; ++i) {
    addr[i] = 'a';
  }
  sleep(100);
  return 0;
}
```



## 可以调查的函数
- int hugetlb_report_node_meminfo(int, char *);
- void hugetlb_report_meminfo(struct seq_file *);
- void hugetlb_show_meminfo(void);

## 这几个接口也是可以调查一下的
- slabtop
- /proc/meminfo
  - [ ] 从这里看，存在一个 zone 居然是 device
- /proc/buddyinfo
- /proc/pagetypeinfo
- /sys/kernel/mm/hugepages
- /proc

## /proc/zoneinfo

## 忽然发现这是一个大主题
- MIGRATE_PCPTYPES


这两个是做啥用的:
- zone_batchsize
- zone_highsize

## /proc/meminfo 中这些是啥
```txt
DirectMap4k:       36680 kB
DirectMap2M:     3108864 kB
DirectMap1G:    11534336 kB
```


- sudo cat /proc/pagetypeinfo
```txt
Page block order: 9
Pages per block:  512

Free pages count per migrate type at order       0      1      2      3      4      5      6      7      8      9     10
Node    0, zone      DMA, type    Unmovable      0      0      0      0      0      0      0      0      1      0      0
Node    0, zone      DMA, type      Movable      0      0      0      0      0      0      0      0      0      1      3
Node    0, zone      DMA, type  Reclaimable      0      0      0      0      0      0      0      0      0      0      0
Node    0, zone      DMA, type   HighAtomic      0      0      0      0      0      0      0      0      0      0      0
Node    0, zone      DMA, type          CMA      0      0      0      0      0      0      0      0      0      0      0
Node    0, zone      DMA, type      Isolate      0      0      0      0      0      0      0      0      0      0      0
Node    0, zone    DMA32, type    Unmovable     62    106    153    134    119     72     44     15      5      0      0
Node    0, zone    DMA32, type      Movable    417    197     98     86     84     90     64     65     71     90    137
Node    0, zone    DMA32, type  Reclaimable     41     57     62     61     64     59     48     35     27      0      0
Node    0, zone    DMA32, type   HighAtomic      0      0      0      0      0      0      0      0      0      0      0
Node    0, zone    DMA32, type          CMA      0      0      0      0      0      0      0      0      0      0      0
Node    0, zone    DMA32, type      Isolate      0      0      0      0      0      0      0      0      0      0      0
Node    0, zone   Normal, type    Unmovable     53    105    830    360     80     48     52     30     18     14     16
Node    0, zone   Normal, type      Movable >100000  93493  41359  17188   5937   3527   2269   1339    842   1269   1170
Node    0, zone   Normal, type  Reclaimable     88     86    457      3    198    466    360    245    106      1      0
Node    0, zone   Normal, type   HighAtomic      0      0     16     15      6      3      1      0      0      0      0
Node    0, zone   Normal, type          CMA      0      0      0      0      0      0      0      0      0      0      0
Node    0, zone   Normal, type      Isolate      0      0      0      0      0      0      0      0      0      0      0

Number of blocks type     Unmovable      Movable  Reclaimable   HighAtomic          CMA      Isolate
Node 0, zone      DMA            1            7            0            0            0            0
Node 0, zone    DMA32           25         1466           37            0            0            0
Node 0, zone   Normal          298        10165          288            1            0            0
```
- [ ] 为什么 Movable 中有那么多 order=10 的页

## /proc/meminfo 中关于 hugepage 的统计真奇怪啊

## 3. zone 和 node 中间都含有统计信息，分别统计什么
1. 这些统计信息是通过什么接口提供给用户程序的，或者内核如何使用它们?
2. zone 和 node 统计内容有什么侧重?

node 统计信息定义
```txt
	/* Per-node vmstats */
	struct per_cpu_nodestat __percpu *per_cpu_nodestats;
	atomic_long_t		vm_stat[NR_VM_NODE_STAT_ITEMS];
} pg_data_t;

struct zone {
...
	/* Zone statistics */
	atomic_long_t		vm_stat[NR_VM_ZONE_STAT_ITEMS];
	atomic_long_t		vm_numa_stat[NR_VM_NUMA_STAT_ITEMS];
} ____cacheline_internodealigned_in_smp;

struct per_cpu_nodestat {
	s8 stat_threshold;
	s8 vm_node_stat_diff[NR_VM_NODE_STAT_ITEMS];
};
```



```txt
AnonHugePages:    798720 kB
ShmemHugePages:        0 kB
ShmemPmdMapped:        0 kB
FileHugePages:         0 kB
FilePmdMapped:         0 kB
CmaTotal:              0 kB
CmaFree:               0 kB
HugePages_Total:    1024
HugePages_Free:     1024
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:       2048 kB
```

```txt

enum zone_stat_item {
	/* First 128 byte cacheline (assuming 64 bit words) */
	NR_FREE_PAGES,
	NR_ZONE_LRU_BASE, /* Used only for compaction and reclaim retry */
	NR_ZONE_INACTIVE_ANON = NR_ZONE_LRU_BASE,
	NR_ZONE_ACTIVE_ANON,
	NR_ZONE_INACTIVE_FILE,
	NR_ZONE_ACTIVE_FILE,
	NR_ZONE_UNEVICTABLE,
	NR_ZONE_WRITE_PENDING,	/* Count of dirty, writeback and unstable pages */
	NR_MLOCK,		/* mlock()ed pages found and moved off LRU */
	NR_PAGETABLE,		/* used for pagetables */
	NR_KERNEL_STACK_KB,	/* measured in KiB */
	/* Second 128 byte cacheline */
	NR_BOUNCE,
#if IS_ENABLED(CONFIG_ZSMALLOC)
	NR_ZSPAGES,		/* allocated in zsmalloc */
#endif
	NR_FREE_CMA_PAGES,
	NR_VM_ZONE_STAT_ITEMS };

enum node_stat_item {
	NR_LRU_BASE,
	NR_INACTIVE_ANON = NR_LRU_BASE, /* must match order of LRU_[IN]ACTIVE */
	NR_ACTIVE_ANON,		/*  "     "     "   "       "         */
	NR_INACTIVE_FILE,	/*  "     "     "   "       "         */
	NR_ACTIVE_FILE,		/*  "     "     "   "       "         */
	NR_UNEVICTABLE,		/*  "     "     "   "       "         */
	NR_SLAB_RECLAIMABLE,
	NR_SLAB_UNRECLAIMABLE,
	NR_ISOLATED_ANON,	/* Temporary isolated pages from anon lru */
	NR_ISOLATED_FILE,	/* Temporary isolated pages from file lru */
	WORKINGSET_REFAULT,
	WORKINGSET_ACTIVATE,
	WORKINGSET_NODERECLAIM,
	NR_ANON_MAPPED,	/* Mapped anonymous pages */
	NR_FILE_MAPPED,	/* pagecache pages mapped into pagetables.
			   only modified from process context */
	NR_FILE_PAGES,
	NR_FILE_DIRTY,
	NR_WRITEBACK,
	NR_WRITEBACK_TEMP,	/* Writeback using temporary buffers */
	NR_SHMEM,		/* shmem pages (included tmpfs/GEM pages) */
	NR_SHMEM_THPS,
	NR_SHMEM_PMDMAPPED,
	NR_ANON_THPS,
	NR_UNSTABLE_NFS,	/* NFS unstable pages */
	NR_VMSCAN_WRITE,
	NR_VMSCAN_IMMEDIATE,	/* Prioritise for reclaim when writeback ends */
	NR_DIRTIED,		/* page dirtyings since bootup */
	NR_WRITTEN,		/* page writings since bootup */
	NR_INDIRECTLY_RECLAIMABLE_BYTES, /* measured in bytes */
	NR_VM_NODE_STAT_ITEMS
};
```
