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

#### [Flushing out pdflush](https://lwn.net/Articles/326552/)
The amount of dirty memory is listed in `/proc/meminfo`.

Jens Axboe in [his patch](http://lwn.net/Articles/324833/) set proposes a new idea of using flusher threads per **backing device info (BDI)**, as a replacement for pdflush threads. Unlike pdflush threads, per-BDI flusher threads focus on a single disk spindle. With per-BDI flushing, when the request_queue is congested, blocking happens on request allocation, avoiding request starvation and providing better fairness.
> BDI 相比 pdflush 到底有什么好处

As with pdflush, per-BDI writeback is controlled through the `writeback_control` data structure, which instructs the writeback code what to do, and how to perform the writeback. The important fields of this structure are:
1. `sync_mode`: defines the way synchronization should be performed with respect to inode locking. If set to `WB_SYNC_NONE`, the writeback will skip locked inodes, where as if set to WB_SYNC_ALL will wait for locked inodes to be unlocked to perform the writeback.

2. `nr_to_write`: the number of pages to write. This value is decremented as the pages are written.

3. `older_than_this`: If not NULL, all inodes older than the jiffies recorded in this field are flushed. This field takes precedence over `nr_to_write`.

```c
/*
 * A control structure which tells the writeback code what to do.  These are
 * always on the stack, and hence need no locking.  They are always initialised
 * in a manner such that unspecified fields are set to zero.
 */
struct writeback_control {
    long nr_to_write;       /* Write this many pages, and decrement
                       this for each page written */
    long pages_skipped;     /* Pages which were not written */

    /*
     * For a_ops->writepages(): if start or end are non-zero then this is
     * a hint that the filesystem need only write out the pages inside that
     * byterange.  The byte at `end' is included in the writeout request.
     */
    loff_t range_start;
    loff_t range_end;

    enum writeback_sync_modes sync_mode;

    unsigned for_kupdate:1;     /* A kupdate writeback */
    unsigned for_background:1;  /* A background writeback */
    unsigned tagged_writepages:1;   /* tag-and-write to avoid livelock */
    unsigned for_reclaim:1;     /* Invoked from the page allocator */
    unsigned range_cyclic:1;    /* range_start is cyclic */
    unsigned for_sync:1;        /* sync(2) WB_SYNC_ALL writeback */
#ifdef CONFIG_CGROUP_WRITEBACK
    struct bdi_writeback *wb;   /* wb this writeback is issued under */
    struct inode *inode;        /* inode being written out */

    /* foreign inode detection, see wbc_detach_inode() */
    int wb_id;          /* current wb id */
    int wb_lcand_id;        /* last foreign candidate wb id */
    int wb_tcand_id;        /* this foreign candidate wb id */
    size_t wb_bytes;        /* bytes written by current wb */
    size_t wb_lcand_bytes;      /* bytes written by last candidate */
    size_t wb_tcand_bytes;      /* bytes written by this candidate */
#endif
};
```

The struct `bdi_writeback` keeps all information required for flushing the dirty pages:

```c
struct bdi_writeback {
    struct backing_dev_info *bdi;
    unsigned int nr;
    struct task_struct  *task;
    wait_queue_head_t   wait;
    struct list_head    b_dirty;
    struct list_head    b_io;
    struct list_head    b_more_io;

    unsigned long       nr_pages;
    struct super_block  *sb;
};
```
The `bdi_writeback` structure is initialized when the device is registered through `bdi_register()`. The fields of the `bdi_writeback` are:


1. `bdi`: the `backing_device_info` associated with this `bdi_writeback`,
2. `task`: contains the pointer to the default flusher thread which is responsible for spawning threads for performing the flushing work,
3. `wait`: a wait queue for synchronizing with the flusher threads,
4. `b_dirty`: list of all the dirty inodes on this BDI to be flushed,
5. `b_io`: inodes parked for I/O,
6. `b_more_io`: more inodes parked for I/O; all inodes queued for flushing are inserted in this list, before being moved to b_io,
7. `nr_pages`: total number of pages to be flushed, and
8. `sb`: the pointer to the superblock of the filesystem which resides on this BDI.

The `bdi_writeback_task()` function waits for the `dirty_writeback_interval`, which by default is 5 seconds, and initiates `wb_do_writeback(wb)` periodically. If there are no pages written for five minutes, the flusher thread exits (with a grace period of `dirty_writeback_interval`). If a writeback work is later required (after exit), new flusher threads are spawned by the default writeback thread.



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
- 分析 page

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
