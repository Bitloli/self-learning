# balloon

调查下，这些函数的 backtrace:
- [ ] balloon_ack

## 统计信息的来源
- update_balloon_stats

## 使用方法
- info balloon
- balloon N

- 基本的流程 : guest -> virtio device
  - 问题在于，guest 以为自己的内存是足够的，是不会换出的
  - 如果让 guest 还是以为自己持有很多内存，在 GVA -> GPA 的映射是存在的，实际上，Host 已经将内存换出，此时 GPA

lspci 可以得到:
```txt
00:06.0 Unclassified device [00ff]: Red Hat, Inc. Virtio memory balloon
```
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/virtualization_deployment_and_administration_guide/sect-manipulating_the_domain_xml-devices#sect-Devices-Memory_balloon_device

- [ ] virtio 驱动必然又一个设置中断的吧

```c
static void virtio_balloon_class_init(ObjectClass *klass, void *data)
{
    DeviceClass *dc = DEVICE_CLASS(klass);
    VirtioDeviceClass *vdc = VIRTIO_DEVICE_CLASS(klass);

    device_class_set_props(dc, virtio_balloon_properties);
    dc->vmsd = &vmstate_virtio_balloon;
    set_bit(DEVICE_CATEGORY_MISC, dc->categories);
    vdc->realize = virtio_balloon_device_realize;
    vdc->unrealize = virtio_balloon_device_unrealize;
    vdc->reset = virtio_balloon_device_reset;
    vdc->get_config = virtio_balloon_get_config;
    vdc->set_config = virtio_balloon_set_config;
    vdc->get_features = virtio_balloon_get_features;
    vdc->set_status = virtio_balloon_set_status;
    vdc->vmsd = &vmstate_virtio_balloon_device;
}
```

- virtio 是无需映射 mmap 的吧，既然数据都是通过 vqs 传输的

- 这几个从来不会被调用:
```txt
Num     Type           Disp Enb Address            What
3       breakpoint     keep y   0x0000555555b350d0 in virtio_balloon_receive_stats at ../hw/virtio/virtio-balloon.c:450
        breakpoint already hit 1 time
4       breakpoint     keep y   0x0000555555b34d30 in virtio_ballloon_get_free_page_hints at ../hw/virtio/virtio-balloon.c:555
5       breakpoint     keep y   0x0000555555b34890 in virtio_balloon_handle_report at ../hw/virtio/virtio-balloon.c:330
```

- 使用 memory hotplug 来实现，我这是万万没有想到的。

## stat: 如何实现周期性的发送统计信息
- https://qemu.readthedocs.io/en/latest/interop/virtio-balloon-stats.html


- qemu::balloon_stats_poll_cb : QEMU 定时触发，通知 guest 需要统计信息
- kernel::stats_request : guest 接受到中断
- kernel::stats_handle_request : 统计所有信息，并且将
- qemu::virtio_balloon_receive_stats : 从 virtuequeue 中接受消息
- qemu::balloon_stats_get_all : qom 的 hook，virsh 从 VirtIOBalloon::stat 中阅读信息

```txt
#0  virtio_balloon_receive_stats (vdev=0x55555790d780, vq=0x7fffe7e2a140) at ../hw/virtio/virtio-balloon.c:450
#1  0x0000555555b3b17c in virtio_queue_notify (vdev=0x55555790d780, n=<optimized out>) at ../hw/virtio/virtio.c:2860
#2  0x0000555555b70c20 in memory_region_write_accessor (mr=mr@entry=0x555557906250, addr=8, value=value@entry=0x7ffff4ac95d8, size=size@entry=2, shift=<optimized out>, mask=mask@entry=65535, attrs=...) at ../softmmu/memory.c:493
#3  0x0000555555b6e406 in access_with_adjusted_size (addr=addr@entry=8, value=value@entry=0x7ffff4ac95d8, size=size@entry=2, access_size_min=<optimized out>, access_size_max=<optimized out>, access_fn=0x555555b70ba0 <memory_region_write_accessor>, mr=0x555557906250, attrs=...) at ../softmmu/memory.c:555
#4  0x0000555555b726ca in memory_region_dispatch_write (mr=mr@entry=0x555557906250, addr=8, data=<optimized out>, op=<optimized out>, attrs=attrs@entry=...) at ../softmmu/memory.c:1522
#5  0x0000555555b79880 in flatview_write_continue (fv=fv@entry=0x7ffddc007b10, addr=addr@entry=4263538696, attrs=..., attrs@entry=..., ptr=ptr@entry=0x7ffff42c6028, len=len@entry=2, addr1=<optimized out>, l=<optimized out>, mr=0x555557906250) at /home/martins3/core/qemu/include/qemu/host-utils.h:166
#6  0x0000555555b79b40 in flatview_write (fv=0x7ffddc007b10, addr=addr@entry=4263538696, attrs=attrs@entry=..., buf=buf@entry=0x7ffff42c6028, len=len@entry=2) at ../softmmu/physmem.c:2867
#7  0x0000555555b7d2a9 in address_space_write (len=2, buf=0x7ffff42c6028, attrs=..., addr=4263538696, as=0x555556590ba0 <address_space_memory>) at ../softmmu/physmem.c:2963
#8  address_space_rw (as=0x555556590ba0 <address_space_memory>, addr=4263538696, attrs=attrs@entry=..., buf=buf@entry=0x7ffff42c6028, len=2, is_write=<optimized out>) at ../softmmu/physmem.c:2973
#9  0x0000555555bff98e in kvm_cpu_exec (cpu=cpu@entry=0x5555568da320) at ../accel/kvm/kvm-all.c:2900
#10 0x0000555555c00e7d in kvm_vcpu_thread_fn (arg=arg@entry=0x5555568da320) at ../accel/kvm/kvm-accel-ops.c:51
#11 0x0000555555d6fb29 in qemu_thread_start (args=<optimized out>) at ../util/qemu-thread-posix.c:505
#12 0x00007ffff7870ff2 in start_thread () from /nix/store/v6szn6fczjbn54h7y40aj7qjijq7j6dc-glibc-2.34-210/lib/libc.so.6
#13 0x00007ffff78f3bfc in clone3 () from /nix/store/v6szn6fczjbn54h7y40aj7qjijq7j6dc-glibc-2.34-210/lib/libc.so.6
```


kernel code:
```c
/*
 * While most virtqueues communicate guest-initiated requests to the hypervisor,
 * the stats queue operates in reverse.  The driver initializes the virtqueue
 * with a single buffer.  From that point forward, all conversations consist of
 * a hypervisor request (a call to this function) which directs us to refill
 * the virtqueue with a fresh stats buffer.  Since stats collection can sleep,
 * we delegate the job to a freezable workqueue that will do the actual work via
 * stats_handle_request().
 */
static void stats_request(struct virtqueue *vq)
{
	struct virtio_balloon *vb = vq->vdev->priv;

	spin_lock(&vb->stop_update_lock);
	if (!vb->stop_update)
		queue_work(system_freezable_wq, &vb->update_balloon_stats_work);
	spin_unlock(&vb->stop_update_lock);
}
```
- 每次当 host 发过来请求，将任务放到 workqueu 中。
  - [ ] 什么统计会导致 sleep
  - [x] 为什么不可以 sleep : 因为在中断的上下文中。

```txt
#0  stats_request (vq=0xffff888122297200) at drivers/virtio/virtio_balloon.c:365
#1  0xffffffff81746ec5 in vring_interrupt (irq=10, _vq=<optimized out>) at drivers/virtio/virtio_ring.c:2470
#2  vring_interrupt (irq=irq@entry=10, _vq=<optimized out>) at drivers/virtio/virtio_ring.c:2445
#3  0xffffffff8174a82f in vp_vring_interrupt (irq=10, opaque=0xffff88810005f800) at drivers/virtio/virtio_pci_common.c:68
#4  0xffffffff81179ef1 in __handle_irq_event_percpu (desc=desc@entry=0xffff888100124c00) at kernel/irq/handle.c:158
#5  0xffffffff8117a09f in handle_irq_event_percpu (desc=0xffff888100124c00) at kernel/irq/handle.c:193
#6  handle_irq_event (desc=desc@entry=0xffff888100124c00) at kernel/irq/handle.c:210
#7  0xffffffff8117e39b in handle_fasteoi_irq (desc=0xffff888100124c00) at kernel/irq/chip.c:714
#8  0xffffffff810bba44 in generic_handle_irq_desc (desc=0xffff888100124c00) at include/linux/irqdesc.h:158
#9  handle_irq (regs=<optimized out>, desc=0xffff888100124c00) at arch/x86/kernel/irq.c:231
#10 __common_interrupt (regs=<optimized out>, vector=33) at arch/x86/kernel/irq.c:250
#11 0xffffffff81fa6553 in common_interrupt (regs=0xffffffff82a03de8, error_code=<optimized out>) at arch/x86/kernel/irq.c:240
Backtrace stopped: Cannot access memory at address 0xffffc90000004018
```

## size

### balloon N 的实现
qemu 中，经过 QMP 到达 virtio_balloon_to_target
- virtio_balloon_to_target
  - dev->num_pages = (vm_ram_size - target) >> VIRTIO_BALLOON_PFN_SHIFT;
  - virtio_notify_config


- 这个到底什么时候获取?
  - virtio_balloon_get_config

```txt
#0  virtio_balloon_get_config (vdev=0x5555578d5c00, config_data=0x5555578de1a0 "") at ../hw/virtio/virtio-balloon.c:711
#1  0x0000555555b204f5 in virtio_config_modern_readl () at ../hw/virtio/virtio.c:2163
#2  0x00005555559b0d15 in virtio_pci_device_read (opaque=<optimized out>, addr=<optimized out>, size=<optimized out>) at ../hw/virtio/virtio-pci.c:1443
#3  0x0000555555b4e1df in memory_region_read_accessor (mr=mr@entry=0x5555578ce5b0, addr=0, value=value@entry=0x7ffde73fd6d0, size=size@entry=4, shift=0, mask=mask@entry=4294967295, attrs=...) at ../softmmu/memory.c:440
#4  0x0000555555b4b426 in access_with_adjusted_size (addr=addr@entry=0, value=value@entry=0x7ffde73fd6d0, size=size@entry=4, access_size_min=<optimized out>, access_size_max=<optimized out>, access_fn=0x555555b4e1a0 <memory_region_read_accessor>, mr=0x5555578ce5b0, attrs=...) at ../softmmu/memory.c:554
#5  0x0000555555b4f5d1 in memory_region_dispatch_read1 (attrs=..., size=4, pval=0x7ffde73fd6d0, addr=0, mr=0x5555578ce5b0) at ../softmmu/memory.c:1430
#6  memory_region_dispatch_read (mr=<optimized out>, addr=<optimized out>, pval=pval@entry=0x7ffde73fd6d0, op=MO_32, attrs=attrs@entry=...) at ../softmmu/memory.c:1457
#7  0x0000555555b59ae6 in flatview_read_continue (fv=fv@entry=0x7ffdd82827f0, addr=addr@entry=4263534592, attrs=attrs@entry=..., ptr=ptr@entry=0x7ffff4749028, len=len@entry=4, addr1=<optimized out>, l=<optimized out>, mr=<optimized out>) at /home/martins3/core/qemu/include/qemu/host-utils.h:166
#8  0x0000555555b59d40 in flatview_read (fv=0x7ffdd82827f0, addr=addr@entry=4263534592, attrs=attrs@entry=..., buf=buf@entry=0x7ffff4749028, len=len@entry=4) at ../softmmu/physmem.c:2934
#9  0x0000555555b5a08e in address_space_read_full (len=4, buf=0x7ffff4749028, attrs=..., addr=4263534592, as=0x5555565738c0 <address_space_memory>) at ../softmmu/physmem.c:2947
#10 address_space_rw (as=0x5555565738c0 <address_space_memory>, addr=4263534592, attrs=attrs@entry=..., buf=buf@entry=0x7ffff4749028, len=4, is_write=<optimized out>) at ../softmmu/physmem.c:2975
#11 0x0000555555bf140e in kvm_cpu_exec (cpu=cpu@entry=0x5555568de410) at ../accel/kvm/kvm-all.c:2939
#12 0x0000555555bf28bd in kvm_vcpu_thread_fn (arg=arg@entry=0x5555568de410) at ../accel/kvm/kvm-accel-ops.c:49
#13 0x0000555555d567e9 in qemu_thread_start (args=<optimized out>) at ../util/qemu-thread-posix.c:504
#14 0x00007ffff76d2ff2 in start_thread () from /nix/store/scd5n7xsn0hh0lvhhnycr9gx0h8xfzsl-glibc-2.34-210/lib/libc.so.6
#15 0x00007ffff7755bfc in clone3 () from /nix/store/scd5n7xsn0hh0lvhhnycr9gx0h8xfzsl-glibc-2.34-210/lib/libc.so.6
```

当 guest 接受到消息之后，在 `virtio_balloon_queue_free_page_work` 中发起 workqueue
```txt
#0  virtio_balloon_queue_free_page_work (vb=<optimized out>) at drivers/virtio/virtio_balloon.c:425
#1  virtballoon_changed (vdev=<optimized out>) at drivers/virtio/virtio_balloon.c:445
#2  0xffffffff8171f590 in __virtio_config_changed (dev=0xffff888200a8f000) at drivers/virtio/virtio.c:133
#3  virtio_config_changed (dev=dev@entry=0xffff888200a8f000) at drivers/virtio/virtio.c:141
#4  0xffffffff817244d3 in vp_config_changed (opaque=0xffff888200a8f000, irq=10) at drivers/virtio/virtio_pci_common.c:54
#5  vp_interrupt (irq=10, opaque=0xffff888200a8f000) at drivers/virtio/virtio_pci_common.c:97
#6  0xffffffff8116516e in __handle_irq_event_percpu (desc=desc@entry=0xffff888100120c00) at kernel/irq/handle.c:158
#7  0xffffffff8116531f in handle_irq_event_percpu (desc=0xffff888100120c00) at kernel/irq/handle.c:193
#8  handle_irq_event (desc=desc@entry=0xffff888100120c00) at kernel/irq/handle.c:210
#9  0xffffffff811694bb in handle_fasteoi_irq (desc=0xffff888100120c00) at kernel/irq/chip.c:714
#10 0xffffffff810b9ab1 in generic_handle_irq_desc (desc=0xffff888100120c00) at include/linux/irqdesc.h:158
#11 handle_irq (regs=<optimized out>, desc=0xffff888100120c00) at arch/x86/kernel/irq.c:231
#12 __common_interrupt (regs=<optimized out>, vector=33) at arch/x86/kernel/irq.c:250
#13 0xffffffff81edd563 in common_interrupt (regs=0xffffffff82a03de8, error_code=<optimized out>) at arch/x86/kernel/irq.c:240
Backtrace stopped: Cannot access memory at address 0xffffc90000004018
```

然后在 workqueue 中间:
```txt
#1  0xffffffff81726a9a in update_balloon_size_func (work=0xffff8881010d8070) at drivers/virtio/virtio_balloon.c:483
#2  0xffffffff811225d4 in process_one_work (worker=worker@entry=0xffff888125dc0a80, work=0xffff8881010d8070) at kernel/workqueue.c:2289
#3  0xffffffff81122b68 in worker_thread (__worker=0xffff888125dc0a80) at kernel/workqueue.c:2436
#4  0xffffffff81129510 in kthread (_create=0xffff888221a3b100) at kernel/kthread.c:376
#5  0xffffffff81001a8f in ret_from_fork () at arch/x86/entry/entry_64.S:306
#6  0x0000000000000000 in ?? ()
```

- update_balloon_size_func
  - leak_balloon
  - fill_balloon : 增大 balloon
    - balloon_page_alloc
    - balloon_page_enqueue
      - balloon_page_insert : 设置 page 的 `PAGE_MAPPING_MOVABLE`
    - tell_host : 将页面发送给 host，然后等待
  - update_balloon_size : 修改 config，host 侧不会接受到通知
    - 将 balloon_dev_info::pages 链表中的页释放出去

最后在 QEMU 中间:
- virtio_balloon_handle_output
  - balloon_inflate_page
    - ram_block_discard_range
  - balloon_deflate_page
    - qemu_madvise(host_addr, rb_page_size, QEMU_MADV_WILLNEED)

### info balloon 的实现

## 为什么 shrink 从来用不上
- shrink 的工作是什么，当 guest 实在不行的时候，来释放，但是

- 实际上，guest 宁可 oom 也是不会调用这个的: virtio_balloon_shrinker_count
```txt
#0  do_shrink_slab (shrinkctl=shrinkctl@entry=0xffffc9000115fcc0, shrinker=shrinker@entry=0xffffffff82b4cc40 <kfree_rcu_shrinker>, priority=priority@entry=12) at mm/vmscan.c:774
#1  0xffffffff81294954 in shrink_slab (gfp_mask=3264, nid=0, memcg=memcg@entry=0xffff888100180000, priority=12) at mm/vmscan.c:991
#2  0xffffffff812964b3 in shrink_node_memcgs (sc=0xffffc9000115fdd8, pgdat=0xffff88813fffc000) at mm/vmscan.c:3182
#3  shrink_node (pgdat=pgdat@entry=0xffff88813fffc000, sc=sc@entry=0xffffc9000115fdd8) at mm/vmscan.c:3304
#4  0xffffffff81296bd7 in kswapd_shrink_node (sc=0xffffc9000115fdd8, pgdat=0xffff88813fffc000) at mm/vmscan.c:4086
#5  balance_pgdat (pgdat=pgdat@entry=0xffff88813fffc000, order=order@entry=4, highest_zoneidx=highest_zoneidx@entry=3) at mm/vmscan.c:4277
#6  0xffffffff8129718b in kswapd (p=0xffff88813fffc000) at mm/vmscan.c:4537
#7  0xffffffff81129510 in kthread (_create=0xffff888200b6ed40) at kernel/kthread.c:376
#8  0xffffffff81001a8f in ret_from_fork () at arch/x86/entry/entry_64.S:306
```

## [ ] 这些 feature 需要逐个检查一下
```c
/* The feature bitmap for virtio balloon */
#define VIRTIO_BALLOON_F_MUST_TELL_HOST 0 /* Tell before reclaiming pages */
#define VIRTIO_BALLOON_F_STATS_VQ   1 /* Memory Stats virtqueue */
#define VIRTIO_BALLOON_F_DEFLATE_ON_OOM 2 /* Deflate balloon on OOM */
#define VIRTIO_BALLOON_F_FREE_PAGE_HINT 3 /* VQ to report free pages */
#define VIRTIO_BALLOON_F_PAGE_POISON    4 /* Guest is using page poisoning */
#define VIRTIO_BALLOON_F_REPORTING  5 /* Page reporting virtqueue */
```

Linux 都是支持的。
- VIRTIO_BALLOON_F_FREE_PAGE_HINT : (kernel 86a559787e6f5cf662c081363f64a20cad654195)
- VIRTIO_BALLOON_F_REPORTING : (kernel 2e991629bcf55a43681aec1ee096eeb03cf81709) 这个不是写的很详细，也不懂 poison 的原理

## qemu 代码分析

- qmp 对外仅仅提供两个功能
  - virtio_balloon_stat
    - [ ] get_current_ram_size
  - virtio_balloon_to_target
    - dev->num_pages = (vm_ram_size - target) >> VIRTIO_BALLOON_PFN_SHIFT;
    - virtio_notify_config
- [ ]  但是存在 5 个 qeueu 啊

```c
struct VirtIOBalloon {
    VirtIODevice parent_obj;
    VirtQueue *ivq, *dvq, *svq, *free_page_vq, *reporting_vq;
    uint32_t free_page_hint_status;
    uint32_t num_pages; // 希望归还的页面
    uint32_t actual; // 实际捕获的页面 ?
    uint32_t free_page_hint_cmd_id;
    uint64_t stats[VIRTIO_BALLOON_S_NR];
    VirtQueueElement *stats_vq_elem;
    size_t stats_vq_offset;
    // 定时查询 ?
    QEMUTimer *stats_timer;
    IOThread *iothread;
    QEMUBH *free_page_bh;
    /*
     * Lock to synchronize threads to access the free page reporting related
     * fields (e.g. free_page_hint_status).
     */
    QemuMutex free_page_lock;
    QemuCond  free_page_cond;
    /*
     * Set to block iothread to continue reading free page hints as the VM is
     * stopped.
     */
    bool block_iothread;
    NotifierWithReturn free_page_hint_notify;
    int64_t stats_last_update;
    int64_t stats_poll_interval;
    uint32_t host_features;

    bool qemu_4_0_config_size;
    uint32_t poison_val;
};
```

## BALLOON_COMPACTION

```txt
config BALLOON_COMPACTION
    bool "Allow for balloon memory compaction/migration"
    def_bool y
    depends on COMPACTION && MEMORY_BALLOON
    help
      Memory fragmentation introduced by ballooning might reduce
      significantly the number of 2MB contiguous memory blocks that can be
      used within a guest, thus imposing performance penalties associated
      with the reduced number of transparent huge pages that could be used
      by the guest workload. Allowing the compaction & migration for memory
      pages enlisted as being part of memory balloon devices avoids the
      scenario aforementioned and helps improving memory defragmentation.
```

## HYPERV_BALLOON

### kernel

- virtballoon_probe
  - init_vqs ：初始化接口
  - virtio_balloon_register_shrinker ：注册 scanner 的接口
    - virtio_balloon_shrinker_scan
    -  virtio_balloon_shrinker_count

### qemu

## 为什么 vmware 的 balloon 写的这么长

- linux git:(master) ✗ /home/martins3/core/linux/drivers/misc/vmw_balloon.c
- 内核中页存在 HyperV 的 balloon :
  - https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/hh831766(v=ws.11)?redirectedfrom=MSDN

## hint
- 解决 migration 中，不知道将 balloon 设置为多大的问题:

- 让 balloon 尽可能的大，然后让 host 将这些页保护起来，然后如果 guest 在迁移的过程中使用了这些页，那么就重新发送。

## free pages reporting

## virtio

```diff
History:        #0
Commit:         997e120843e82609c8d99a9d5714e6cf91e14cbe
Author:         Denis V. Lunev <den@openvz.org>
Committer:      Michael S. Tsirkin <mst@redhat.com>
Author Date:    Thu 20 Aug 2015 05:49:49 AM CST
Committer Date: Tue 08 Sep 2015 06:32:11 PM CST

virtio_balloon: do not change memory amount visible via /proc/meminfo

Balloon device is frequently used as a mean of cooperative memory control
in between guest and host to manage memory overcommitment. This is the
typical case for any hosting workload when KVM guest is provided for
end-user.

Though there is a problem in this setup. The end-user and hosting provider
have signed SLA agreement in which some amount of memory is guaranted for
the guest. The good thing is that this memory will be given to the guest
when the guest will really need it (f.e. with OOM in guest and with
VIRTIO_BALLOON_F_DEFLATE_ON_OOM configuration flag set). The bad thing
is that end-user does not know this.

Balloon by default reduce the amount of memory exposed to the end-user
each time when the page is stolen from guest or returned back by using
adjust_managed_page_count and thus /proc/meminfo shows reduced amount
of memory.

Fortunately the solution is simple, we should just avoid to call
adjust_managed_page_count with VIRTIO_BALLOON_F_DEFLATE_ON_OOM set.

Signed-off-by: Denis V. Lunev <den@openvz.org>
CC: Michael S. Tsirkin <mst@redhat.com>
Signed-off-by: Michael S. Tsirkin <mst@redhat.com>

diff --git a/drivers/virtio/virtio_balloon.c b/drivers/virtio/virtio_balloon.c
index 8543c9a97307..7efc32945810 100644
--- a/drivers/virtio/virtio_balloon.c
+++ b/drivers/virtio/virtio_balloon.c
@@ -157,7 +157,9 @@ static void fill_balloon(struct virtio_balloon *vb, size_t num)
 		}
 		set_page_pfns(vb->pfns + vb->num_pfns, page);
 		vb->num_pages += VIRTIO_BALLOON_PAGES_PER_PAGE;
-		adjust_managed_page_count(page, -1);
+		if (!virtio_has_feature(vb->vdev,
+					VIRTIO_BALLOON_F_DEFLATE_ON_OOM))
+			adjust_managed_page_count(page, -1);
 	}

 	/* Did we get any? */
@@ -173,7 +175,9 @@ static void release_pages_balloon(struct virtio_balloon *vb)
 	/* Find pfns pointing at start of each page, get pages and free them. */
 	for (i = 0; i < vb->num_pfns; i += VIRTIO_BALLOON_PAGES_PER_PAGE) {
 		struct page *page = balloon_pfn_to_page(vb->pfns[i]);
-		adjust_managed_page_count(page, 1);
+		if (!virtio_has_feature(vb->vdev,
+					VIRTIO_BALLOON_F_DEFLATE_ON_OOM))
+			adjust_managed_page_count(page, 1);
 		put_page(page); /* balloon reference */
 	}
 }
```

## [ ] Out of puff! Can't get 1 pages
直接访问

似乎有时候会触发连续的这个报错

- 不科学，除非一直有

## [ ] 似乎有时候，设置 balloon 不会立刻得到响应

## 基本理解
QEMU 中:
- virtio_balloon_device_realize 中创建两个 virt queue 的

从 QEMU 这端会接受 page ，最后分别调用到:
```c
    if (vq == s->ivq) {
        balloon_inflate_page(s, section.mr,
                             section.offset_within_region, &pbp);
    } else if (vq == s->dvq) {
        balloon_deflate_page(s, section.mr, section.offset_within_region);
```

- QEMU_MADV_REMOVE
- QEMU_MADV_DONTNEED
```c
madvise(host_startaddr, length, QEMU_MADV_REMOVE); // share anonymous 采用此方法
madvise(host_startaddr, length, QEMU_MADV_DONTNEED);
```

```c
qemu_madvise(host_addr, rb_page_size, QEMU_MADV_WILLNEED);
```

- [ ] 关于 share anonymous 需要使用 QEMU_MADV_REMOVE 而不是 QEMU_MADV_DONTNEED
  - 大致原因，应该是使用 QEMU_MADV_DONTNEED, 如果是 shared anonymous 的，其实只能将 page table 删除，而不可以页面删除。
  - QEMU_MADV_REMOVE 和 QEMU_MADV_DONTNEED 的实现原理，暂时没有时间分析。
    - QEMU_MADV_REMOVE 在调用的时候，明显

- 我看了下内核的实现，感觉明显不科学啊?
```diff
History:        #0
Commit:         cdfa56c551bb48f286cfe1f2daa1083d333ee45d
Author:         David Hildenbrand <david@redhat.com>
Committer:      Paolo Bonzini <pbonzini@redhat.com>
Author Date:    Tue 06 Apr 2021 04:01:25 PM CST
Committer Date: Wed 16 Jun 2021 02:27:37 AM CST

softmmu/physmem: Fix ram_block_discard_range() to handle shared anonymous memory

We can create shared anonymous memory via
    "-object memory-backend-ram,share=on,..."
which is, for example, required by PVRDMA for mremap() to work.

Shared anonymous memory is weird, though. Instead of MADV_DONTNEED, we
have to use MADV_REMOVE: MADV_DONTNEED will only remove / zap all
relevant page table entries of the current process, the backend storage
will not get removed, resulting in no reduced memory consumption and
a repopulation of previous content on next access.

Shared anonymous memory is internally really just shmem, but without a
fd exposed. As we cannot use fallocate() without the fd to discard the
backing storage, MADV_REMOVE gets the same job done without a fd as
documented in "man 2 madvise". Removing backing storage implicitly
invalidates all page table entries with relevant mappings - an additional
MADV_DONTNEED is not required.

Fixes: 06329ccecfa0 ("mem: add share parameter to memory-backend-ram")
Reviewed-by: Peter Xu <peterx@redhat.com>
Reviewed-by: Dr. David Alan Gilbert <dgilbert@redhat.com>
Signed-off-by: David Hildenbrand <david@redhat.com>
Message-Id: <20210406080126.24010-3-david@redhat.com>
Signed-off-by: Paolo Bonzini <pbonzini@redhat.com>

diff --git a/softmmu/physmem.c b/softmmu/physmem.c
index b78b30e7ba..c0a3c47167 100644
--- a/softmmu/physmem.c
+++ b/softmmu/physmem.c
@@ -3527,6 +3527,7 @@ int ram_block_discard_range(RAMBlock *rb, uint64_t start, size_t length)
         /* The logic here is messy;
          *    madvise DONTNEED fails for hugepages
          *    fallocate works on hugepages and shmem
+         *    shared anonymous memory requires madvise REMOVE
          */
         need_madvise = (rb->page_size == qemu_host_page_size);
         need_fallocate = rb->fd != -1;
@@ -3560,7 +3561,11 @@ int ram_block_discard_range(RAMBlock *rb, uint64_t start, size_t length)
              * fallocate'd away).
              */
 #if defined(CONFIG_MADVISE)
-            ret =  madvise(host_startaddr, length, MADV_DONTNEED);
+            if (qemu_ram_is_shared(rb) && rb->fd < 0) {
+                ret = madvise(host_startaddr, length, QEMU_MADV_REMOVE);
+            } else {
+                ret = madvise(host_startaddr, length, QEMU_MADV_DONTNEED);
+            }
             if (ret) {
                 ret = -errno;
                 error_report("ram_block_discard_range: Failed to discard range "
```

## 统计信息是如何导出的

## 如何理解 qapi_event_send_balloon_change
```c
    if (dev->actual != oldactual) {
        qapi_event_send_balloon_change(vm_ram_size -
                        ((ram_addr_t) dev->actual << VIRTIO_BALLOON_PFN_SHIFT));
    }
```

## TODO
```c
struct VirtIOBalloon {
    VirtIODevice parent_obj;
    VirtQueue *ivq, *dvq, *svq, *free_page_vq, *reporting_vq;
```
- 这几个 vqs 都是做什么的?
  - svq : 统计信息

- balloon 并不会将 Linux kernel 彻底压缩掉，但是其停手的规则是什么?

- qemu/softmmu/balloon.c 似乎没有任何作用了，似乎是因为以前 QEMU 中存在多个 balloon dirver，现在只是剩下 virtio balloon 了
  - 是因为考虑 HyperV 吗?

## 似乎两侧通信的格式是按照约定的

### QEMU 的解析
```c
static void balloon_stats_poll_cb(void *opaque)
{
    VirtIOBalloon *s = opaque;
    VirtIODevice *vdev = VIRTIO_DEVICE(s);

    if (s->stats_vq_elem == NULL || !balloon_stats_supported(s)) {
        /* re-schedule */
        balloon_stats_change_timer(s, s->stats_poll_interval);
        return;
    }

    virtqueue_push(s->svq, s->stats_vq_elem, 0);
    virtio_notify(vdev, s->svq);
    g_free(s->stats_vq_elem);
    s->stats_vq_elem = NULL;
}
```

- balloon_stats_poll_cb
  - virtqueue_push
    - virtqueue_fill

- virtio_balloon_receive_stats
  - elem = virtqueue_pop(vq, sizeof(VirtQueueElement));
  - iov_to_buf : 从中解析出来 virtio_balloon_stat

- VirtQueueElement : 是 QEMU 自己创建出来的

```c
static void virtio_balloon_receive_stats(VirtIODevice *vdev, VirtQueue *vq)
{
    VirtIOBalloon *s = VIRTIO_BALLOON(vdev);
    VirtQueueElement *elem;
    VirtIOBalloonStat stat;
    size_t offset = 0;

    elem = virtqueue_pop(vq, sizeof(VirtQueueElement));
    if (!elem) {
        goto out;
    }

    if (s->stats_vq_elem != NULL) {
        /* This should never happen if the driver follows the spec. */
        virtqueue_push(vq, s->stats_vq_elem, 0);
        virtio_notify(vdev, vq);
        g_free(s->stats_vq_elem);
    }

    s->stats_vq_elem = elem;

    /* Initialize the stats to get rid of any stale values.  This is only
     * needed to handle the case where a guest supports fewer stats than it
     * used to (ie. it has booted into an old kernel).
     */
    reset_stats(s);

    while (iov_to_buf(elem->out_sg, elem->out_num, offset, &stat, sizeof(stat))
           == sizeof(stat)) {
        uint16_t tag = virtio_tswap16(vdev, stat.tag);
        uint64_t val = virtio_tswap64(vdev, stat.val);

        offset += sizeof(stat);
        if (tag < VIRTIO_BALLOON_S_NR)
            s->stats[tag] = val;
    }
    s->stats_vq_offset = offset;
    s->stats_last_update = g_get_real_time() / G_USEC_PER_SEC;

out:
    if (balloon_stats_enabled(s)) {
        balloon_stats_change_timer(s, s->stats_poll_interval);
    }
}
```

### 内核如何传输这两个数值

```c
static void stats_handle_request(struct virtio_balloon *vb)
{
	struct virtqueue *vq;
	struct scatterlist sg;
	unsigned int len, num_stats;

	num_stats = update_balloon_stats(vb);

	vq = vb->stats_vq;
	if (!virtqueue_get_buf(vq, &len))
		return;
	sg_init_one(&sg, vb->stats, sizeof(vb->stats[0]) * num_stats);
	virtqueue_add_outbuf(vq, &sg, 1, vb, GFP_KERNEL);
	virtqueue_kick(vq);
}
```

- sg_init_one : 将 struct virtio_balloon_stat stats[VIRTIO_BALLOON_S_NR]; 生成为一个 sg
- virtqueue_add_outbuf

## 具体代码上的分析
- free_page_hint_status

## 理解一下这个 feature
- VIRTIO_BALLOON_F_FREE_PAGE_HINT
- [ ] get_free_page_and_send

- 如何理解 virtballoon_freeze 和 virtballoon_restore 的功能:
```c
static struct virtio_driver virtio_balloon_driver = {
	.feature_table = features,
	.feature_table_size = ARRAY_SIZE(features),
	.driver.name =	KBUILD_MODNAME,
	.driver.owner =	THIS_MODULE,
	.id_table =	id_table,
	.validate =	virtballoon_validate,
	.probe =	virtballoon_probe,
	.remove =	virtballoon_remove,
	.config_changed = virtballoon_changed,
#ifdef CONFIG_PM_SLEEP
	.freeze	=	virtballoon_freeze,
	.restore =	virtballoon_restore,
#endif
};
```

## [ ] 如何 Host 或者 Guest 中有的 page 大小不是 4k 如何

```c
/* Size of a PFN in the balloon interface. */
#define VIRTIO_BALLOON_PFN_SHIFT 12
```

## 快速回答
- 为什么将 update_balloon_size_func 和 update_balloon_stats_func 设置为 workqueue 的?
  - 因为他们都会导致睡眠？
