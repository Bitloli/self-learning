# balloon

- guest 不用的内存先回收一下

- 动机，这是让 guest 自己换出的操作，这引入了多余的通路了吧。
- 让 guest 中使用 swap 真的好傻啊，直接 swap 不好吗?

- 基本的流程 : guest -> virtio device
  - 问题在于，guest 以为自己的内存是足够的，是不会换出的
  - 如果让 guest 还是以为自己持有很多内存，在 GVA -> GPA 的映射是存在的，实际上，Host 已经将内存换出，此时 GPA

- 让 guest 换出之后似乎 Host 是不知道的，如何处理?
  - 是通过 vritio 的，应该不存在这个问题。

- 是不是只是因为 host 无法准确知道 geust 中信息，所以让 guest 来释放。

- 如果 guest 将所有的内存写一遍，导致其将内存完全分配了，然后 guest 实际上没有什么工作，将自己的内存完全释放了，但是 host 不知道，从而导致内存没用了。
  - 所以，是不是，应该让 host 应该观察 guest 的使用量，保证所有的内存只是在使用的可以用。

- [ ] 到底什么样的内存会放入到 lru, 是有办法让 guest memory 的内存不放入到 lru 中吗?
  - [ ] 对于这种内存有办法直接使用

- [ ] 默认的机器是存放了 lru 的吗?

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

## [ ] qemu 的 stat 功能分析一下
- https://qemu.readthedocs.io/en/latest/interop/virtio-balloon-stats.html

## 具体代码上的分析
- free_page_hint_status

## 如何使用
- info balloon
- balloon N


想不到吧，balloon N 居然会导致这个 backtrace
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

其实是符合逻辑的，在 virtio_balloon_queue_free_page_work 是主动触发的
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
- [ ] 但是，是那些 pages 是需要和 QEMU 交流一下才对。

```txt
#0  leak_balloon (vb=vb@entry=0xffff8881010d8000, num=256000) at drivers/virtio/virtio_balloon.c:269
#1  0xffffffff81726a9a in update_balloon_size_func (work=0xffff8881010d8070) at drivers/virtio/virtio_balloon.c:483
#2  0xffffffff811225d4 in process_one_work (worker=worker@entry=0xffff888125dc0a80, work=0xffff8881010d8070) at kernel/workqueue.c:2289
#3  0xffffffff81122b68 in worker_thread (__worker=0xffff888125dc0a80) at kernel/workqueue.c:2436
#4  0xffffffff81129510 in kthread (_create=0xffff888221a3b100) at kernel/kthread.c:376
#5  0xffffffff81001a8f in ret_from_fork () at arch/x86/entry/entry_64.S:306
#6  0x0000000000000000 in ?? ()
```

- fill_balloon
  - balloon_page_alloc
  - balloon_page_push
  - set_page_pfns : 将 pages 送出去



在另一个线程中，逐个调用的:
```txt
#0  update_balloon_size_func (work=0xffff8881010d8070) at drivers/virtio/virtio_balloon.c:469
#1  0xffffffff811225d4 in process_one_work (worker=worker@entry=0xffff888125dc0a80, work=0xffff8881010d8070) at kernel/workqueue.c:2289
#2  0xffffffff81122b68 in worker_thread (__worker=0xffff888125dc0a80) at kernel/workqueue.c:2436
#3  0xffffffff81129510 in kthread (_create=0xffff888221a3b100) at kernel/kthread.c:376
#4  0xffffffff81001a8f in ret_from_fork () at arch/x86/entry/entry_64.S:306
#5  0x0000000000000000 in ?? ()
```

- [ ] get_free_page_and_send

应该是通过 shrink 是可以让 balloon 分配的 pages 全部释放给 geust 的。

- qemu 如何接受的具体的 pages
  - balloon_inflate_page -> ram_block_discard_range
  - [ ] 使用一个 backtrace 分析一下。

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

## qemu 的一些 backtrace
- [ ] virtio_balloon_handle_output
- [ ] 几个 qom 初始化的过程

### virtio_balloon_get_config

virtio_balloon_get_config 最开始的时候也是会调用一次:

设置的时候:
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

```txt
#0  virtio_balloon_handle_output (vdev=0x5555578d5c00, vq=0x7ffff428d010) at ../hw/virtio/virtio-balloon.c:391
#1  0x0000555555b207ec in virtio_queue_notify (vdev=0x5555578d5c00, n=<optimized out>) at ../hw/virtio/virtio.c:2385
#2  0x0000555555b4dc70 in memory_region_write_accessor (mr=mr@entry=0x5555578ce6d0, addr=0, value=value@entry=0x7ffde7bfe618, size=size@entry=2, shift=<optimized out>, mask=mask@entry=65535, attrs=...) at ../softmmu/memory.c:492
#3  0x0000555555b4b426 in access_with_adjusted_size (addr=addr@entry=0, value=value@entry=0x7ffde7bfe618, size=size@entry=2, access_size_min=<optimized out>, access_size_max=<optimized out>, access_fn=0x555555b4dbf0 <memory_region_write_accessor>, mr=0x5555578ce6d0, attrs=...) at ../softmmu/memory.c:554
#4  0x0000555555b4f71a in memory_region_dispatch_write (mr=mr@entry=0x5555578ce6d0, addr=0, data=<optimized out>, op=<optimized out>, attrs=attrs@entry=...) at ../softmmu/memory.c:1521
#5  0x0000555555b566f0 in flatview_write_continue (fv=fv@entry=0x7ffdd86c46e0, addr=addr@entry=4263538688, attrs=..., attrs@entry=..., ptr=ptr@entry=0x7ffff474c028, len=len@entry=2, addr1=<optimized out>, l=<optimized out>, mr=0x5555578ce6d0) at /home/martins3/core/qemu/include/qemu/host-utils.h:166
#6  0x0000555555b569b0 in flatview_write (fv=0x7ffdd86c46e0, addr=addr@entry=4263538688, attrs=attrs@entry=..., buf=buf@entry=0x7ffff474c028, len=len@entry=2) at ../softmmu/physmem.c:2867
#7  0x0000555555b5a109 in address_space_write (len=2, buf=0x7ffff474c028, attrs=..., addr=4263538688, as=0x5555565738c0 <address_space_memory>) at ../softmmu/physmem.c:2963
#8  address_space_rw (as=0x5555565738c0 <address_space_memory>, addr=4263538688, attrs=attrs@entry=..., buf=buf@entry=0x7ffff474c028, len=2, is_write=<optimized out>) at ../softmmu/physmem.c:2973
#9  0x0000555555bf140e in kvm_cpu_exec (cpu=cpu@entry=0x5555568a3340) at ../accel/kvm/kvm-all.c:2939
#10 0x0000555555bf28bd in kvm_vcpu_thread_fn (arg=arg@entry=0x5555568a3340) at ../accel/kvm/kvm-accel-ops.c:49
#11 0x0000555555d567e9 in qemu_thread_start (args=<optimized out>) at ../util/qemu-thread-posix.c:504
#12 0x00007ffff76d2ff2 in start_thread () from /nix/store/scd5n7xsn0hh0lvhhnycr9gx0h8xfzsl-glibc-2.34-210/lib/libc.so.6
#13 0x00007ffff7755bfc in clone3 () from /nix/store/scd5n7xsn0hh0lvhhnycr9gx0h8xfzsl-glibc-2.34-210/lib/libc.so.6
```

## kernel 的一些 backtrace
```txt
0  virtio_dev_probe (_d=0xffff88810105f010) at drivers/virtio/virtio.c:310
#1  0xffffffff81949641 in call_driver_probe (drv=0xffffffff82c03fc0 <virtio_balloon_driver>, dev=0xffff88810105f010) at drivers/base/dd.c:530
#2  really_probe (dev=dev@entry=0xffff88810105f010, drv=drv@entry=0xffffffff82c03fc0 <virtio_balloon_driver>) at drivers/base/dd.c:609
#3  0xffffffff8194986d in __driver_probe_device (drv=drv@entry=0xffffffff82c03fc0 <virtio_balloon_driver>, dev=dev@entry=0xffff88810105f010) at drivers/base/dd.c:748
#4  0xffffffff819498e9 in driver_probe_device (drv=drv@entry=0xffffffff82c03fc0 <virtio_balloon_driver>, dev=dev@entry=0xffff88810105f010) at drivers/base/dd.c:778
#5  0xffffffff8194a016 in __driver_attach (data=0xffffffff82c03fc0 <virtio_balloon_driver>, dev=0xffff88810105f010) at drivers/base/dd.c:1150
#6  __driver_attach (dev=0xffff88810105f010, data=0xffffffff82c03fc0 <virtio_balloon_driver>) at drivers/base/dd.c:1099
#7  0xffffffff81947630 in bus_for_each_dev (bus=<optimized out>, start=start@entry=0x0 <fixed_percpu_data>, data=data@entry=0xffffffff82c03fc0 <virtio_balloon_driver>, fn=fn@entry=0xffffffff81949f70 <__driver_attach>) at drivers/base/bus.c:301
#8  0xffffffff819491a5 in driver_attach (drv=drv@entry=0xffffffff82c03fc0 <virtio_balloon_driver>) at drivers/base/dd.c:1167
#9  0xffffffff81948bfc in bus_add_driver (drv=drv@entry=0xffffffff82c03fc0 <virtio_balloon_driver>) at drivers/base/bus.c:618
#10 0xffffffff8194ab8a in driver_register (drv=0xffffffff82c03fc0 <virtio_balloon_driver>) at drivers/base/driver.c:240
#11 0xffffffff81000e7c in do_one_initcall (fn=0xffffffff83322dee <virtio_balloon_driver_init>) at init/main.c:1296
#12 0xffffffff832e44b8 in do_initcall_level (command_line=0xffff8882000fc3c0 "root", level=6) at init/main.c:1369
#13 do_initcalls () at init/main.c:1385
#14 do_basic_setup () at init/main.c:1404
#15 kernel_init_freeable () at init/main.c:1623
#16 0xffffffff81ee0ba1 in kernel_init (unused=<optimized out>) at init/main.c:1512
#17 0xffffffff81001a8f in ret_from_fork () at arch/x86/entry/entry_64.S:306
```

- 这好吗? 一个 ballon 将 guest 收缩炸了
  - [ ] 不设置 hugepage ，还会存在问题吗?
    - 也许从内核中分配，一直都是有问题的。
```txt
[   80.347018] Tasks state (memory values in pages):
[   80.351598] [  pid  ]   uid  tgid total_vm      rss pgtables_bytes swapents oom_score_adj name
[   80.359875] [    427]     0   427    24245        1   315392      687         -1000 systemd-udevd
[   80.368756] [    507]     0   507    32708        0   159744      691         -1000 auditd
[   80.376835] [    609]     0   609    19159        0   307200      233         -1000 sshd
[   80.385405] Out of memory and no killable processes...
[   80.391092] Kernel panic - not syncing: System is deadlocked on memory
[   80.396859] CPU: 1 PID: 1 Comm: systemd Not tainted 6.0.0-rc2-00283-g10d4879f9ef0-dirty #42
[   80.406853] Hardware name: QEMU Standard PC (i440FX + PIIX, 1996), BIOS rel-1.16.0-0-gd239552ce722-prebuilt.qemu.org 04/01/2014
[   80.418924] Call Trace:
[   80.420866]  <TASK>
[   80.422977]  dump_stack_lvl+0x34/0x48
[   80.426854]  panic+0x102/0x27b
[   80.430845]  out_of_memory.cold+0x5e/0x7e
[   80.434880]  __alloc_pages_slowpath.constprop.0+0x971/0xd60
[   80.440859]  __alloc_pages+0x218/0x240
[   80.444892]  folio_alloc+0x12/0x40
[   80.448899]  __filemap_get_folio+0x1c8/0x330
[   80.454907]  filemap_fault+0x14f/0xa20
[   80.458831]  __do_fault+0x2f/0xc0
[   80.460887]  do_fault+0x1db/0x560
[   80.462903]  __handle_mm_fault+0x5c0/0xda0
[   80.466922]  ? xa_load+0x70/0xb0
[   80.470868]  handle_mm_fault+0xc0/0x2b0
[   80.473634]  do_user_addr_fault+0x1c3/0x660
[   80.480152]  ? kvm_read_and_reset_apf_flags+0x45/0x60
[   80.485073]  exc_page_fault+0x62/0x150
[   80.487131]  asm_exc_page_fault+0x22/0x30
[   80.490903] RIP: 0033:0x7f4cb52872ff
```
- 不是有 do_shrink_slab 吗？

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

## VIRTIO_BALLOON

### kernel

- virtballoon_probe
  - init_vqs ：初始化接口
  - virtio_balloon_register_shrinker ：注册 scanner 的接口
    - virtio_balloon_shrinker_scan
    -  virtio_balloon_shrinker_count

### qemu

## 为什么 vmware 的 balloon 写的这么长

➜  linux git:(master) ✗ /home/martins3/core/linux/drivers/misc/vmw_balloon.c

## hint
- 解决 migration 中，不知道将 balloon 设置为多大的问题:

- 让 balloon 尽可能的大，然后让 host 将这些页保护起来，然后如果 guest 在迁移的过程中使用了这些页，那么就重新发送。

## free pages reporting
