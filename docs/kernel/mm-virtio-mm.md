# virtio mm

- https://virtio-mem.gitlab.io/
- ppt : https://events19.linuxfoundation.org/wp-content/uploads/2017/12/virtio-mem-Paravirtualized-Memory-David-Hildenbrand-Red-Hat-1.pdf
- https://lwn.net/Articles/813638/
- vee 文章的 pdf 没有找到哇

当时没有 virtio-mem 的时候对比 hotplug 和 balloon:
- Hotplug or Ballooning: A Comparative Study on Dynamic Memory Management Techniques for Virtual Machines

- [ ] virtio mm 似乎需要额外的考虑: CONFIG_PM_SLEEP
- [ ] virtio mm 是如何依赖本来的 hotplug 框架的 ?
  - 创建 page struct 等，直接映射等
- [ ] 直接在 QEMU 中插入一个新的 memory 设备不行吗? 为什么非要发明一个新的机制。
  - 似乎 virtio-mem 还是需要使用 memory hotplug 的
- [ ] 似乎 balloon 不会修改 watermark，但是 virito mm 会修改 watermark
  - [ ] 为什么 watermark 是按照总内存大小来设置，因为内核需要额外的内存来管理总的物理页面吗?


## 这是什么东西
- drivers/base/memory.c

## [virtio-mem: Paravirtualized Memory by David Hildenbrand](https://www.youtube.com/watch?v=H65FDUDPu9s)


## 相对于 balloon 的优缺点
- [ ] 将页面删除的时候，ballon 只是找到这些内存就可以了，而 hotplug 需要让 guest 的 migration 启动
- [ ] 会导致 host 碎片化吗?
  - 有什么方法防止碎片化?

- [ ] 对于 hotplug 的内存，内核有没有一种说法，就是尽量不要去使用这些内存。

## 问题
- [ ] 为什么需要架构支持?


## 尝试使用一下，记录一下 backtrace
- 非常坑:

```txt
(qemu) info memory-devices
Memory device [virtio-mem]: "vm0"
  memaddr: 0x140000000
  node: 0
  requested-size: 134217728
  size: 134217728
  max-size: 2147483648
  block-size: 2097152
  memdev: /objects/mem3
Memory device [virtio-mem]: "vm1"
  memaddr: 0x1c0000000
  node: 1
  requested-size: 83886080
  size: 83886080
  max-size: 2147483648
  block-size: 2097152
  memdev: /objects/mem4
```

- [ ] 这几个字段是啥意思

https://patchwork.kernel.org/project/kvm/cover/20191212171137.13872-1-david@redhat.com/


```txt
qom-set vm0 requested-size 64M
```

可以得到这个日志:

```txt
[  127.372411] virtio_mem virtio0: plugged size: 0x40000000
[  127.376059] virtio_mem virtio0: requested size: 0x4000000
```

- [ ] 为什么没有检测到 zone movable 里面的 pages 的数量，里面总是 0

## qemu

- virtio_mem_info 和 virtio_mem_pci_info 居然不是父子关系 ?

```c
struct VirtIOMEMPCI {
    VirtIOPCIProxy parent_obj; // @todo 这是个啥 ?
    VirtIOMEM vdev;
    Notifier size_change_notifier;
};
```

## 记录几个 backtrace

这个被调用了两次:
```txt
#0  virtio_mem_init_hotplug (vm=0xffff88810078fc00) at drivers/virtio/virtio_mem.c:2456
#1  virtio_mem_init (vm=0xffff88810078fc00) at drivers/virtio/virtio_mem.c:2694
#2  virtio_mem_probe (vdev=0xffff888024580000) at drivers/virtio/virtio_mem.c:2782
#3  0xffffffff81721aaa in virtio_dev_probe (_d=0xffff888024580010) at drivers/virtio/virtio.c:305
#4  0xffffffff8194ec14 in call_driver_probe (drv=0xffffffff82c04380 <virtio_mem_driver>, dev=0xffff888024580010) at drivers/base/dd.c:530
#5  really_probe (dev=dev@entry=0xffff888024580010, drv=drv@entry=0xffffffff82c04380 <virtio_mem_driver>) at drivers/base/dd.c:609
#6  0xffffffff8194ee3d in __driver_probe_device (drv=drv@entry=0xffffffff82c04380 <virtio_mem_driver>, dev=dev@entry=0xffff888024580010) at drivers/base/dd.c:748
#7  0xffffffff8194eeb9 in driver_probe_device (drv=drv@entry=0xffffffff82c04380 <virtio_mem_driver>, dev=dev@entry=0xffff888024580010) at drivers/base/dd.c:778
#8  0xffffffff8194f5e6 in __driver_attach (data=0xffffffff82c04380 <virtio_mem_driver>, dev=0xffff888024580010) at drivers/base/dd.c:1150
#9  __driver_attach (dev=0xffff888024580010, data=0xffffffff82c04380 <virtio_mem_driver>) at drivers/base/dd.c:1099
#10 0xffffffff8194cc03 in bus_for_each_dev (bus=<optimized out>, start=start@entry=0x0 <fixed_percpu_data>, data=data@entry=0xffffffff82c04380 <virtio_mem_driver>, fn=fn@entry=0xffffffff8194f540 <__driver_attach>) at drivers/base/bus.c:301
#11 0xffffffff8194e775 in driver_attach (drv=drv@entry=0xffffffff82c04380 <virtio_mem_driver>) at drivers/base/dd.c:1167
#12 0xffffffff8194e1cc in bus_add_driver (drv=drv@entry=0xffffffff82c04380 <virtio_mem_driver>) at drivers/base/bus.c:618
#13 0xffffffff8195015a in driver_register (drv=0xffffffff82c04380 <virtio_mem_driver>) at drivers/base/driver.c:240
#14 0xffffffff81000e7f in do_one_initcall (fn=0xffffffff833332c4 <virtio_mem_driver_init>) at init/main.c:1296
#15 0xffffffff832f44b8 in do_initcall_level (command_line=0xffff8881001393c0 "root", level=6) at init/main.c:1369
#16 do_initcalls () at init/main.c:1385
#17 do_basic_setup () at init/main.c:1404
#18 kernel_init_freeable () at init/main.c:1623 #19 0xffffffff81efb9f1 in kernel_init (unused=<optimized out>) at init/main.c:1512
#20 0xffffffff81001a72 in ret_from_fork () at arch/x86/entry/entry_64.S:306
```

- [ ] plug 上是一个异步的操作?
```txt
#0  virtio_mem_sbm_add_mb (mb_id=40, vm=0xffff88810078fc00) at drivers/virtio/virtio_mem.c:665
#1  virtio_mem_sbm_plug_and_add_mb (vm=vm@entry=0xffff88810078fc00, mb_id=40, nb_sb=nb_sb@entry=0xffffc900001e7e48) at drivers/virtio/virtio_mem.c:1629
#2  0xffffffff8172c8c3 in virtio_mem_sbm_plug_request (diff=<optimized out>, vm=0xffff88810078fc00) at drivers/virtio/virtio_mem.c:1743
#3  virtio_mem_plug_request (diff=<optimized out>, vm=0xffff88810078fc00) at drivers/virtio/virtio_mem.c:1857
#4  virtio_mem_run_wq (work=0xffff88810078fc10) at drivers/virtio/virtio_mem.c:2378
#5  0xffffffff81122d37 in process_one_work (worker=worker@entry=0xffff88810062e480, work=0xffff88810078fc10) at kernel/workqueue.c:2289
#6  0xffffffff811232c8 in worker_thread (__worker=0xffff88810062e480) at kernel/workqueue.c:2436
#7  0xffffffff81129c73 in kthread (_create=0xffff88810062f4c0) at kernel/kthread.c:376
#8  0xffffffff81001a72 in ret_from_fork () at arch/x86/entry/entry_64.S:306
```

```txt
#0  virtio_mem_memory_notifier_cb (nb=0xffff88810078fdd0, action=8, arg=0xffffc900001e7be0) at drivers/virtio/virtio_mem.c:952
#1  0xffffffff8112d1f8 in notifier_call_chain (nr_calls=0x0 <fixed_percpu_data>, nr_to_call=-9, v=0xffffc900001e7be0, val=8, nl=0xffffffff82c18a28 <memory_chain+40>) at kernel/notifier.c:87
#2  blocking_notifier_call_chain (v=0xffffc900001e7be0, val=8, nh=0xffffffff82c18a00 <memory_chain>) at kernel/notifier.c:382
#3  blocking_notifier_call_chain (nh=nh@entry=0xffffffff82c18a00 <memory_chain>, val=val@entry=8, v=v@entry=0xffffc900001e7be0) at kernel/notifier.c:370
#4  0xffffffff819680a2 in memory_notify (val=val@entry=8, v=v@entry=0xffffc900001e7be0) at drivers/base/memory.c:175
#5  0xffffffff81efd35e in online_pages (pfn=pfn@entry=1310720, nr_pages=nr_pages@entry=32768, zone=zone@entry=0xffff88807fffcd00, group=0xffff8881221d8040) at mm/memory_hotplug.c:1102
#6  0xffffffff81967d0c in memory_block_online (mem=0xffff88810017e800) at drivers/base/memory.c:202
#7  memory_block_action (action=1, mem=0xffff88810017e800) at drivers/base/memory.c:268
#8  memory_block_change_state (from_state_req=4, to_state=1, mem=0xffff88810017e800) at drivers/base/memory.c:293
#9  memory_subsys_online (dev=0xffff88810017e820) at drivers/base/memory.c:315
#10 0xffffffff8194c5ad in device_online (dev=0xffff88810017e820) at drivers/base/core.c:4048
#11 0xffffffff819683fd in walk_memory_blocks (start=start@entry=5368709120, size=size@entry=134217728, arg=arg@entry=0x0 <fixed_percpu_data>, func=func@entry=0xffffffff812e93b0 <online_memory_block>) at drivers/base/memory.c:969
#12 0xffffffff81efd77d in add_memory_resource (nid=nid@entry=0, res=res@entry=0xffff8881221d8100, mhp_flags=mhp_flags@entry=5) at mm/memory_hotplug.c:1421
#13 0xffffffff812ea686 in add_memory_driver_managed (nid=0, start=start@entry=5368709120, size=size@entry=134217728, resource_name=<optimized out>, mhp_flags=mhp_flags@entry=5) at mm/memory_hotplug.c:1500
#14 0xffffffff8172a071 in virtio_mem_add_memory (vm=vm@entry=0xffff88810078fc00, addr=addr@entry=5368709120, size=134217728) at drivers/virtio/virtio_mem.c:647
#15 0xffffffff8172b82e in virtio_mem_sbm_add_mb (mb_id=40, vm=0xffff88810078fc00) at drivers/virtio/virtio_mem.c:668
#16 virtio_mem_sbm_plug_and_add_mb (vm=vm@entry=0xffff88810078fc00, mb_id=40, nb_sb=nb_sb@entry=0xffffc900001e7e48) at drivers/virtio/virtio_mem.c:1629
#17 0xffffffff8172c8c3 in virtio_mem_sbm_plug_request (diff=<optimized out>, vm=0xffff88810078fc00) at drivers/virtio/virtio_mem.c:1743
#18 virtio_mem_plug_request (diff=<optimized out>, vm=0xffff88810078fc00) at drivers/virtio/virtio_mem.c:1857
#19 virtio_mem_run_wq (work=0xffff88810078fc10) at drivers/virtio/virtio_mem.c:2378
#20 0xffffffff81122d37 in process_one_work (worker=worker@entry=0xffff88810062e480, work=0xffff88810078fc10) at kernel/workqueue.c:2289
#21 0xffffffff811232c8 in worker_thread (__worker=0xffff88810062e480) at kernel/workqueue.c:2436
#22 0xffffffff81129c73 in kthread (_create=0xffff88810062f4c0) at kernel/kthread.c:376
#23 0xffffffff81001a72 in ret_from_fork () at arch/x86/entry/entry_64.S:306
```

- virtio_mem_sbm_add_mb 和 virtio_mem_memory_notifier_cb 一共会被调用几百次。


- [ ] memory_block_online 这个是需要调用的吧
