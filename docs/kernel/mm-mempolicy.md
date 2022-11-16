## 官方文档已经非常清楚了

- https://docs.kernel.org/admin-guide/mm/numa_memory_policy.html
- https://man7.org/linux/man-pages/man2/set_mempolicy.2.html : 这个也是需要自习分析

- alloc_pages_vma

-  默认算法是从 Local Node 上找，如果没有就去 remote 的 Node 上尝试
  - get_page_from_freelist 中调用 for_next_zone_zonelist_nodemask 将所有的 Node 都遍历一次

## 内核分配内存真的是 interleaved 吗
- 还是说，只是启动的时候是 interleaved


- 如果用户进程访问文件:
  - 形成的 page cache 是 interleaved 吗? 但是如果该文件是 shared ?
  - 因为该文件形成了很多 inode 之类的，因此分配的空间在什么地方?

## set_mempolicy() or mbind() 两个系统调用的区别是什么

## memory
```c
/*
 * Both the MPOL_* mempolicy mode and the MPOL_F_* optional mode flags are
 * passed by the user to either set_mempolicy() or mbind() in an 'int' actual.
 * The MPOL_MODE_FLAGS macro determines the legal set of optional mode flags.
 */

/* Policies */
enum {
	MPOL_DEFAULT,
	MPOL_PREFERRED,
	MPOL_BIND,
	MPOL_INTERLEAVE,
	MPOL_LOCAL,
	MPOL_PREFERRED_MANY,
	MPOL_MAX,	/* always last member of enum */
};
```

## vma_dup_policy : 当 frok 的时候，默认集成上一个的 policy
```txt
#0  vma_dup_policy (src=src@entry=0xffff8881212902f8, dst=dst@entry=0xffff888121290390) at mm/mempolicy.c:2387
#1  0xffffffff812e4710 in __split_vma (mm=mm@entry=0xffff888121518000, vma=vma@entry=0xffff8881212902f8, addr=addr@entry=140295976648704, new_below=new_below@entry=0) at mm/mmap.c:2222
#2  0xffffffff812e4914 in do_mas_align_munmap (mas=mas@entry=0xffffc9000005fd28, vma=0xffff8881212902f8, mm=mm@entry=0xffff888121518000, start=start@entry=140295976648704, end=end@entry=140295976849408, uf=uf@entry=0xffffc9000005fd18, downgrade=false) at mm/mmap.c:2341
#3  0xffffffff812e4dc2 in do_mas_munmap (mas=mas@entry=0xffffc9000005fd28, mm=mm@entry=0xffff888121518000, start=start@entry=140295976648704, len=len@entry=200704, uf=uf@entry=0xffffc9000005fd18, downgrade=downgrade@entry=false) at mm/mmap.c:2502
#4  0xffffffff812e4ec3 in __vm_munmap (start=start@entry=140295976648704, len=len@entry=200704, downgrade=downgrade@entry=false) at mm/mmap.c:2775
#5  0xffffffff812e4f87 in vm_munmap (start=start@entry=140295976648704, len=len@entry=200704) at mm/mmap.c:2793
#6  0xffffffff813cb166 in elf_map (filep=filep@entry=0xffff888121740200, addr=addr@entry=0, eppnt=eppnt@entry=0xffff888121332000, prot=prot@entry=1, type=2, total_size=<optimized out>) at fs/binfmt_elf.c:392
#7  0xffffffff813cc8e8 in load_elf_interp (arch_state=<synthetic pointer>, interp_elf_phdata=0xffff888121332000, no_base=94798853218304, interpreter=<optimized out>, interp_elf_ex=0xffff8881617b1580) at fs/binfmt_elf.c:638
#8  load_elf_binary (bprm=0xffff888161c2b400) at fs/binfmt_elf.c:1250
#9  0xffffffff8136e43e in search_binary_handler (bprm=0xffff888161c2b400) at fs/exec.c:1727
#10 exec_binprm (bprm=0xffff888161c2b400) at fs/exec.c:1768
#11 bprm_execve (flags=<optimized out>, filename=<optimized out>, fd=<optimized out>, bprm=0xffff888161c2b400) at fs/exec.c:1837
#12 bprm_execve (bprm=0xffff888161c2b400, fd=<optimized out>, filename=<optimized out>, flags=<optimized out>) at fs/exec.c:1799
#13 0xffffffff8136ee1b in kernel_execve (kernel_filename=kernel_filename@entry=0xffffffff827b40bb "/sbin/init", argv=argv@entry=0xffffffff82a14220 <argv_init>, envp=envp@entry=0xffffffff82a14100 <envp_init>) at fs/exec.c:2002
#14 0xffffffff81f34748 in run_init_process (init_filename=init_filename@entry=0xffffffff827b40bb "/sbin/init") at init/main.c:1435
#15 0xffffffff81f34753 in try_to_run_init_process (init_filename=init_filename@entry=0xffffffff827b40bb "/sbin/init") at init/main.c:1442
#16 0xffffffff81fa8ae0 in kernel_init (unused=<optimized out>) at init/main.c:1575
#17 0xffffffff81001a72 in ret_from_fork () at arch/x86/entry/entry_64.S:306
#18 0x0000000000000000 in ?? ()
```
## vm_operations_struct 的两个 hook : set_policy get_policy

使用位置:
- vma_replace_policy

- syscall mbind
  - kernel_mbind
    - do_mbind
- syscall set_mempolicy_home_node

上面两者调用:
- mbind_range
  - vma_replace_policy

是为了处理 shared policy 的

## mempolicy

1. Memory policies are a programming interface that a NUMA-aware application can take advantage of.
2. cpusets which is an administrative mechanism for restricting the nodes from which memory may be allocated by a set of processes.  cpuset 和 numa mempolicy 同时出现的时候，cpuset 优先
3. 一共四个粒度 和 两个 flags MPOL_F_STATIC_NODES 和 MPOL_F_RELATIVE_NODES (**flag 的作用有点迷**)
4. 还分析了一下 mol_put 和 mol_get 的问题

```c
// 获取 vma 对应的 policy ，解析出来 preferred_nid 和 nodemask 然后
struct page * alloc_pages_vma(gfp_t gfp, int order, struct vm_area_struct *vma, unsigned long addr, int node, bool hugepage)
```
> 感觉 mempolicy 并没有什么特殊的地方，只是提供一个 syscall 给用户。

- vma_merge

- vm_area_struct : 持有 vm_policy

## 分析一个问题，各个 NUMA 不是对称的，hugepage 的分配的时候，如何处理大页
interleave 分配的

## 用户进程分配内存的时候，如何被 mempolicy 影响的

```c
static struct mempolicy default_policy = {
    .refcnt = ATOMIC_INIT(1), /* never free it */
    .mode = MPOL_PREFERRED,
    .flags = MPOL_F_LOCAL,
};
```

## 验证一下，是首先检查 cpuset，然后检查 memory policy 的

## 这个回答很肤浅，而且并不是正确的
https://stackoverflow.com/questions/59607742/what-is-default-memory-policy-flag-for-malloc

- default_policy

```diff
History:        #0
Commit:         7858d7bca7fbbbbd5b940d2ec371b2d060b21b84
Author:         Feng Tang <feng.tang@intel.com>
Committer:      Linus Torvalds <torvalds@linux-foundation.org>
Author Date:    Thu 01 Jul 2021 09:51:00 AM CST
Committer Date: Thu 01 Jul 2021 11:47:29 AM CST

mm/mempolicy: don't handle MPOL_LOCAL like a fake MPOL_PREFERRED policy

MPOL_LOCAL policy has been setup as a real policy, but it is still handled
like a faked POL_PREFERRED policy with one internal MPOL_F_LOCAL flag bit
set, and there are many places having to judge the real 'prefer' or the
'local' policy, which are quite confusing.

In current code, there are 4 cases that MPOL_LOCAL are used:

1. user specifies 'local' policy

2. user specifies 'prefer' policy, but with empty nodemask

3. system 'default' policy is used

4. 'prefer' policy + valid 'preferred' node with MPOL_F_STATIC_NODES
   flag set, and when it is 'rebind' to a nodemask which doesn't contains
   the 'preferred' node, it will perform as 'local' policy

So make 'local' a real policy instead of a fake 'prefer' one, and kill
MPOL_F_LOCAL bit, which can greatly reduce the confusion for code reading.

For case 4, the logic of mpol_rebind_preferred() is confusing, as Michal
Hocko pointed out:

: I do believe that rebinding preferred policy is just bogus and it should
: be dropped altogether on the ground that a preference is a mere hint from
: userspace where to start the allocation.  Unless I am missing something
: cpusets will be always authoritative for the final placement.  The
: preferred node just acts as a starting point and it should be really
: preserved when cpusets changes.  Otherwise we have a very subtle behavior
: corner cases.

So dump all the tricky transformation between 'prefer' and 'local', and
just record the new nodemask of rebinding.

[feng.tang@intel.com: fix a problem in mpol_set_nodemask(), per Michal Hocko]
  Link: https://lkml.kernel.org/r/1622560492-1294-3-git-send-email-feng.tang@intel.com
[feng.tang@intel.com: refine code and comments of mpol_set_nodemask(), per Michal]
  Link: https://lkml.kernel.org/r/20210603081807.GE56979@shbuild999.sh.intel.com

Link: https://lkml.kernel.org/r/1622469956-82897-3-git-send-email-feng.tang@intel.com
Signed-off-by: Feng Tang <feng.tang@intel.com>
Suggested-by: Michal Hocko <mhocko@suse.com>
Acked-by: Michal Hocko <mhocko@suse.com>
Cc: Andi Kleen <ak@linux.intel.com>
Cc: Andrea Arcangeli <aarcange@redhat.com>
Cc: Ben Widawsky <ben.widawsky@intel.com>
Cc: Dan Williams <dan.j.williams@intel.com>
Cc: Dave Hansen <dave.hansen@intel.com>
Cc: David Rientjes <rientjes@google.com>
Cc: Huang Ying <ying.huang@intel.com>
Cc: Mel Gorman <mgorman@techsingularity.net>
Cc: Michal Hocko <mhocko@kernel.org>
Cc: Mike Kravetz <mike.kravetz@oracle.com>
Cc: Randy Dunlap <rdunlap@infradead.org>
Cc: Vlastimil Babka <vbabka@suse.cz>
Signed-off-by: Andrew Morton <akpm@linux-foundation.org>
Signed-off-by: Linus Torvalds <torvalds@linux-foundation.org>
```

```diff
commit b27abaccf8e8b012f126da0c2a1ab32723ec8b9f
Author: Dave Hansen <dave.hansen@linux.intel.com>
Date:   Thu Sep 2 15:00:06 2021 -0700

    mm/mempolicy: add MPOL_PREFERRED_MANY for multiple preferred nodes

    Patch series "Introduce multi-preference mempolicy", v7.

    This patch series introduces the concept of the MPOL_PREFERRED_MANY
    mempolicy.  This mempolicy mode can be used with either the
    set_mempolicy(2) or mbind(2) interfaces.  Like the MPOL_PREFERRED
    interface, it allows an application to set a preference for nodes which
    will fulfil memory allocation requests.  Unlike the MPOL_PREFERRED mode,
    it takes a set of nodes.  Like the MPOL_BIND interface, it works over a
    set of nodes.  Unlike MPOL_BIND, it will not cause a SIGSEGV or invoke the
    OOM killer if those preferred nodes are not available.

    Along with these patches are patches for libnuma, numactl, numademo, and
    memhog.  They still need some polish, but can be found here:
    https://gitlab.com/bwidawsk/numactl/-/tree/prefer-many It allows new
    usage: `numactl -P 0,3,4`

    The goal of the new mode is to enable some use-cases when using tiered memory
    usage models which I've lovingly named.

    1a. The Hare - The interconnect is fast enough to meet bandwidth and
        latency requirements allowing preference to be given to all nodes with
        "fast" memory.
    1b. The Indiscriminate Hare - An application knows it wants fast
        memory (or perhaps slow memory), but doesn't care which node it runs
        on.  The application can prefer a set of nodes and then xpu bind to
        the local node (cpu, accelerator, etc).  This reverses the nodes are
        chosen today where the kernel attempts to use local memory to the CPU
        whenever possible.  This will attempt to use the local accelerator to
        the memory.
    2.  The Tortoise - The administrator (or the application itself) is
        aware it only needs slow memory, and so can prefer that.

    Much of this is almost achievable with the bind interface, but the bind
    interface suffers from an inability to fallback to another set of nodes if
    binding fails to all nodes in the nodemask.

    Like MPOL_BIND a nodemask is given. Inherently this removes ordering from the
    preference.

    > /* Set first two nodes as preferred in an 8 node system. */
    > const unsigned long nodes = 0x3
    > set_mempolicy(MPOL_PREFER_MANY, &nodes, 8);

    > /* Mimic interleave policy, but have fallback *.
    > const unsigned long nodes = 0xaa
    > set_mempolicy(MPOL_PREFER_MANY, &nodes, 8);

    Some internal discussion took place around the interface. There are two
    alternatives which we have discussed, plus one I stuck in:

    1. Ordered list of nodes.  Currently it's believed that the added
       complexity is nod needed for expected usecases.
    2. A flag for bind to allow falling back to other nodes.  This
       confuses the notion of binding and is less flexible than the current
       solution.
    3. Create flags or new modes that helps with some ordering.  This
       offers both a friendlier API as well as a solution for more customized
       usage.  It's unknown if it's worth the complexity to support this.
       Here is sample code for how this might work:

    > // Prefer specific nodes for some something wacky
    > set_mempolicy(MPOL_PREFER_MANY, 0x17c, 1024);
    >
    > // Default
    > set_mempolicy(MPOL_PREFER_MANY | MPOL_F_PREFER_ORDER_SOCKET, NULL, 0);
    > // which is the same as
    > set_mempolicy(MPOL_DEFAULT, NULL, 0);
    >
    > // The Hare
    > set_mempolicy(MPOL_PREFER_MANY | MPOL_F_PREFER_ORDER_TYPE, NULL, 0);
    >
    > // The Tortoise
    > set_mempolicy(MPOL_PREFER_MANY | MPOL_F_PREFER_ORDER_TYPE_REV, NULL, 0);
    >
    > // Prefer the fast memory of the first two sockets
    > set_mempolicy(MPOL_PREFER_MANY | MPOL_F_PREFER_ORDER_TYPE, -1, 2);
    >

    This patch (of 5):

    The NUMA APIs currently allow passing in a "preferred node" as a single
    bit set in a nodemask.  If more than one bit it set, bits after the first
    are ignored.

    This single node is generally OK for location-based NUMA where memory
    being allocated will eventually be operated on by a single CPU.  However,
    in systems with multiple memory types, folks want to target a *type* of
    memory instead of a location.  For instance, someone might want some
    high-bandwidth memory but do not care about the CPU next to which it is
    allocated.  Or, they want a cheap, high capacity allocation and want to
    target all NUMA nodes which have persistent memory in volatile mode.  In
    both of these cases, the application wants to target a *set* of nodes, but
    does not want strict MPOL_BIND behavior as that could lead to OOM killer
    or SIGSEGV.

    So add MPOL_PREFERRED_MANY policy to support the multiple preferred nodes
    requirement.  This is not a pie-in-the-sky dream for an API.  This was a
    response to a specific ask of more than one group at Intel.  Specifically:

    1. There are existing libraries that target memory types such as
       https://github.com/memkind/memkind.  These are known to suffer from
       SIGSEGV's when memory is low on targeted memory "kinds" that span more
       than one node.  The MCDRAM on a Xeon Phi in "Cluster on Die" mode is an
       example of this.

    2. Volatile-use persistent memory users want to have a memory policy
       which is targeted at either "cheap and slow" (PMEM) or "expensive and
       fast" (DRAM).  However, they do not want to experience allocation
       failures when the targeted type is unavailable.

    3. Allocate-then-run.  Generally, we let the process scheduler decide
       on which physical CPU to run a task.  That location provides a default
       allocation policy, and memory availability is not generally considered
       when placing tasks.  For situations where memory is valuable and
       constrained, some users want to allocate memory first, *then* allocate
       close compute resources to the allocation.  This is the reverse of the
       normal (CPU) model.  Accelerators such as GPUs that operate on
       core-mm-managed memory are interested in this model.

    A check is added in sanitize_mpol_flags() to not permit 'prefer_many'
    policy to be used for now, and will be removed in later patch after all
    implementations for 'prefer_many' are ready, as suggested by Michal Hocko.

    [mhocko@kernel.org: suggest to refine policy_node/policy_nodemask handling]

    Link: https://lkml.kernel.org/r/1627970362-61305-1-git-send-email-feng.tang@intel.com
    Link: https://lore.kernel.org/r/20200630212517.308045-4-ben.widawsky@intel.com
    Link: https://lkml.kernel.org/r/1627970362-61305-2-git-send-email-feng.tang@intel.com
    Co-developed-by: Ben Widawsky <ben.widawsky@intel.com>
    Signed-off-by: Ben Widawsky <ben.widawsky@intel.com>
    Signed-off-by: Dave Hansen <dave.hansen@linux.intel.com>
    Signed-off-by: Feng Tang <feng.tang@intel.com>
    Cc: Michal Hocko <mhocko@kernel.org>
    Acked-by: Michal Hocko <mhocko@suse.com>
    Cc: Andrea Arcangeli <aarcange@redhat.com>
    Cc: Mel Gorman <mgorman@techsingularity.net>
    Cc: Mike Kravetz <mike.kravetz@oracle.com>
    Cc: Randy Dunlap <rdunlap@infradead.org>
    Cc: Vlastimil Babka <vbabka@suse.cz>
    Cc: Andi Kleen <ak@linux.intel.com>
    Cc: Dan Williams <dan.j.williams@intel.com>
    Cc: Huang Ying <ying.huang@intel.com>b
    Cc: Michal Hocko <mhocko@suse.com>
    Signed-off-by: Andrew Morton <akpm@linux-foundation.org>
    Signed-off-by: Linus Torvalds <torvalds@linux-foundation.org>
```
