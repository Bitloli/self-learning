## 文档
- https://docs.oasis-open.org/virtio/virtio/v1.1/virtio-v1.1.html

## 核心的结构体
- virtio_config_ops

## TODO
- [ ] /home/maritns3/core/firecracker/src/devices/src/virtio/vsock/csm/connection.rs has a small typo
- [ ] virtio and msi:
- [ ] 有的设备不支持 PCI 总线，需要使用 MMIO 的方式，但是 kvmtool 怎么知道这个设备需要使用 MMIO
- [ ] 约定是第一个 bar 指向的 IO 空间在内核那一侧是怎么分配的 ?
- [ ] virtio_bus 是挂载到哪里的?
- [ ] virtio_console 的具体实现是怎么样子的 ?
- [ ] 现在对于 eventfd 都是从 virt-blk 角度理解的，其实如何利用 eventfd 实现 guest 到 kernel 的通知，比如 irqfd 来实现 Qemu 直接将 irq 注入到 guest 中

- [ ] 观察，如何从 blk 的数值是如何发送的，如果一会构成 block size ，一会合并，是不是很烦 ?
  - 网络中，是不是总是需要等到一整个 page 才可以发送，还是说没有这个问题 ?
  - 对于 virtio ballon 岂不是难受，所以这个想法是有问题的

- [ ] QEMU 是如何初始化 virtio 设备的
- 热插拔

## 关键代码

```c
/* Virtio ring descriptors: 16 bytes.  These can chain together via "next". */
struct vring_desc {
  /* Address (guest-physical). */
  __virtio64 addr;
  /* Length. */
  __virtio32 len;
  /* The flags as indicated above. */
  __virtio16 flags;
  /* We chain unused descriptors via this, too */
  __virtio16 next;
};

struct vring_avail {
  __virtio16 flags;
  __virtio16 idx;
  __virtio16 ring[];
};

/* u32 is used here for ids for padding reasons. */
struct vring_used_elem {
  /* Index of start of used descriptor chain. */
  __virtio32 id;
  /* Total length of the descriptor chain which was used (written to) */
  __virtio32 len;
};

struct vring_used {
  __virtio16 flags;
  __virtio16 idx;
  struct vring_used_elem ring[];
};
```

## 深入理解 virtio ，以 virtio-blk 为例

1. 架构层次
2. 数据传输
  - [ ] 有拷贝吗?
3. 中断
4. 睡眠

## 代码上的问题

- [ ] vp_find_vqs_intx : 为什么 ballon 总是调用 int 而不是 msi
  - [ ] msi 相对于 int 的性能优势是什么?

- 几个结构体直接的关系:
  - vring_virtqueue 持有一个 vq，在创建 vring_create_virtqueue_packed 和 vring_create_virtqueue_split 的时候创建两者
  - 测试显示，从来没有人调用过 vring_create_virtqueue_packed

- [ ] vring_map_one_sg

```c
struct vring {
	unsigned int num;

	vring_desc_t *desc;

	vring_avail_t *avail;

	vring_used_t *used;
};
```

## virtio bus
- [ ] struct bus_type 的 match 和 probe 是什么关系?
```c
static inline int driver_match_device(struct device_driver *drv,
              struct device *dev)
{
  return drv->bus->match ? drv->bus->match(dev, drv) : 1;
}
```

`device_attach` 是提供给外部的一个常用的函数，会调用 `bus->probe`，在当前的上下文就是 pci_device_probe 了。

- [ ] `pci_device_probe` 的内容是很简单, 根据设备找驱动的地方在哪里？
  - 根据参数 struct device 获取 pc_driver 和 pci_device
  - 分配 irq number
  - 回调 `pci_driver->probe`, 使用 virtio_pci_probe 为例子
      - 初始化 pci 设备
      - 回调 `virtio_driver->probe`, 使用 virtnet_probe 作为例子


#### virtio_pci_probe

```plain
#0  virtio_pci_probe (pci_dev=0xffff888100c0c800, id=0xffffffff824aa4a0 <virtio_pci_id_table>) at include/linux/slab.h:600
#1  0xffffffff816b2a4d in local_pci_probe (_ddi=_ddi@entry=0xffffc9000003bd68) at drivers/pci/pci-driver.c:324
#2  0xffffffff816b4229 in pci_call_probe (id=<optimized out>, dev=0xffff888100c0c800, drv=<optimized out>) at drivers/pci/pci-driver.c:392
#3  __pci_device_probe (pci_dev=0xffff888100c0c800, drv=<optimized out>) at drivers/pci/pci-driver.c:417
#4  pci_device_probe (dev=0xffff888100c0c8c8) at drivers/pci/pci-driver.c:460
#5  0xffffffff8194f094 in call_driver_probe (drv=0xffffffff82c04038 <virtio_pci_driver+120>, dev=0xffff888100c0c8c8) at drivers/base/dd.c:560
#6  really_probe (dev=dev@entry=0xffff888100c0c8c8, drv=drv@entry=0xffffffff82c04038 <virtio_pci_driver+120>) at drivers/base/dd.c:639
#7  0xffffffff8194f2bd in __driver_probe_device (drv=drv@entry=0xffffffff82c04038 <virtio_pci_driver+120>, dev=dev@entry=0xffff888100c0c8c8) at drivers/base/dd.c:778
#8  0xffffffff8194f339 in driver_probe_device (drv=drv@entry=0xffffffff82c04038 <virtio_pci_driver+120>, dev=dev@entry=0xffff888100c0c8c8) at drivers/base/dd.c:808
#9  0xffffffff8194fa49 in __driver_attach (data=0xffffffff82c04038 <virtio_pci_driver+120>, dev=0xffff888100c0c8c8) at drivers/base/dd.c:1190
#10 __driver_attach (dev=0xffff888100c0c8c8, data=0xffffffff82c04038 <virtio_pci_driver+120>) at drivers/base/dd.c:1134
#11 0xffffffff8194d043 in bus_for_each_dev (bus=<optimized out>, start=start@entry=0x0 <fixed_percpu_data>, data=data@entry=0xffffffff82c04038 <virtio_pci_driver+120>, fn=fn@entry=0xffffffff8194f9e0 <__driver_attach>) at drivers/base/bus.c:301
#12 0xffffffff8194ebb5 in driver_attach (drv=drv@entry=0xffffffff82c04038 <virtio_pci_driver+120>) at drivers/base/dd.c:1207
#13 0xffffffff8194e60c in bus_add_driver (drv=drv@entry=0xffffffff82c04038 <virtio_pci_driver+120>) at drivers/base/bus.c:618
#14 0xffffffff819505fa in driver_register (drv=0xffffffff82c04038 <virtio_pci_driver+120>) at drivers/base/driver.c:240
#15 0xffffffff81000e7f in do_one_initcall (fn=0xffffffff833342da <virtio_pci_driver_init>) at init/main.c:1296
#16 0xffffffff832f54b8 in do_initcall_level (command_line=0xffff888003922b40 "root", level=6) at init/main.c:1369
#17 do_initcalls () at init/main.c:1385
#18 do_basic_setup () at init/main.c:1404
#19 kernel_init_freeable () at init/main.c:1623
#20 0xffffffff81efca11 in kernel_init (unused=<optimized out>) at init/main.c:1512
#21 0xffffffff81001a72 in ret_from_fork () at arch/x86/entry/entry_64.S:306
#22 0x0000000000000000 in ?? ()
```

#### virtblk_probe && virtio_dev_probe

```txt
#0  virtblk_probe (vdev=0xffff8881001b5000) at drivers/block/virtio_blk.c:886
#1  0xffffffff81721c9a in virtio_dev_probe (_d=0xffff8881001b5010) at drivers/virtio/virtio.c:305
#2  0xffffffff8194f094 in call_driver_probe (drv=0xffffffff82c1a0e0 <virtio_blk>, dev=0xffff8881001b5010) at drivers/base/dd.c:560
#3  really_probe (dev=dev@entry=0xffff8881001b5010, drv=drv@entry=0xffffffff82c1a0e0 <virtio_blk>) at drivers/base/dd.c:639
#4  0xffffffff8194f2bd in __driver_probe_device (drv=drv@entry=0xffffffff82c1a0e0 <virtio_blk>, dev=dev@entry=0xffff8881001b5010) at drivers/base/dd.c:778
#5  0xffffffff8194f339 in driver_probe_device (drv=drv@entry=0xffffffff82c1a0e0 <virtio_blk>, dev=dev@entry=0xffff8881001b5010) at drivers/base/dd.c:808
#6  0xffffffff8194fa49 in __driver_attach (data=0xffffffff82c1a0e0 <virtio_blk>, dev=0xffff8881001b5010) at drivers/base/dd.c:1190
#7  __driver_attach (dev=0xffff8881001b5010, data=0xffffffff82c1a0e0 <virtio_blk>) at drivers/base/dd.c:1134
#8  0xffffffff8194d043 in bus_for_each_dev (bus=<optimized out>, start=start@entry=0x0 <fixed_percpu_data>, data=data@entry=0xffffffff82c1a0e0 <virtio_blk>, fn=fn@entry=0xffffffff8194f9e0 <__driver_attach>) at drivers/base/bus.c:301
#9  0xffffffff8194ebb5 in driver_attach (drv=drv@entry=0xffffffff82c1a0e0 <virtio_blk>) at drivers/base/dd.c:1207
#10 0xffffffff8194e60c in bus_add_driver (drv=drv@entry=0xffffffff82c1a0e0 <virtio_blk>) at drivers/base/bus.c:618
#11 0xffffffff819505fa in driver_register (drv=drv@entry=0xffffffff82c1a0e0 <virtio_blk>) at drivers/base/driver.c:240
#12 0xffffffff817214d7 in register_virtio_driver (driver=driver@entry=0xffffffff82c1a0e0 <virtio_blk>) at drivers/virtio/virtio.c:357
#13 0xffffffff8333b1f3 in virtio_blk_init () at drivers/block/virtio_blk.c:1213
#14 0xffffffff81000e7f in do_one_initcall (fn=0xffffffff8333b1a6 <virtio_blk_init>) at init/main.c:1296
#15 0xffffffff832f54b8 in do_initcall_level (command_line=0xffff888003922b40 "root", level=6) at init/main.c:1369
#16 do_initcalls () at init/main.c:1385
#17 do_basic_setup () at init/main.c:1404
#18 kernel_init_freeable () at init/main.c:1623
#19 0xffffffff81efca11 in kernel_init (unused=<optimized out>) at init/main.c:1512
#20 0xffffffff81001a72 in ret_from_fork () at arch/x86/entry/entry_64.S:306
#21 0x0000000000000000 in ?? ()
```

## virtio_pci_driver virtio_bus virtio_blk 三者是什么关系
```c
static struct pci_driver virtio_pci_driver = {
  .name   = "virtio-pci",
  .id_table = virtio_pci_id_table,
  .probe    = virtio_pci_probe,
  .remove   = virtio_pci_remove,
#ifdef CONFIG_PM_SLEEP
  .driver.pm  = &virtio_pci_pm_ops,
#endif
  .sriov_configure = virtio_pci_sriov_configure,
};
```

```c
static struct bus_type virtio_bus = {
  .name  = "virtio",
  .match = virtio_dev_match,
  .dev_groups = virtio_dev_groups,
  .uevent = virtio_uevent,
  .probe = virtio_dev_probe,
  .remove = virtio_dev_remove,
};
```

```c
static struct virtio_driver virtio_blk = {
  .feature_table      = features,
  .feature_table_size   = ARRAY_SIZE(features),
  .feature_table_legacy   = features_legacy,
  .feature_table_size_legacy  = ARRAY_SIZE(features_legacy),
  .driver.name      = KBUILD_MODNAME,
  .driver.owner     = THIS_MODULE,
  .id_table     = id_table,
  .probe        = virtblk_probe,
  .remove       = virtblk_remove,
  .config_changed     = virtblk_config_changed,
#ifdef CONFIG_PM_SLEEP
  .freeze       = virtblk_freeze,
  .restore      = virtblk_restore,
#endif
};
```


- [ ] 为什么会存在 virtio-pci 设备的存在，既然已经构建了一个 virtio_bus 的总线类型

- [ ] virtio_pci_probe
  - [ ] virtio_pci_modern_probe : 给 virtio_pci_device::vdev 注册


virtio_find_vqs

```c
/* Our device structure */
struct virtio_pci_device {
  struct virtio_device vdev;
  struct pci_dev *pci_dev;
```

```c
static const struct virtio_config_ops virtio_pci_config_ops = {
  .get    = vp_get,
  .set    = vp_set,
  .generation = vp_generation,
  .get_status = vp_get_status,
  .set_status = vp_set_status,
  .reset    = vp_reset,
  .find_vqs = vp_modern_find_vqs,
  .del_vqs  = vp_del_vqs,
  .get_features = vp_get_features,
  .finalize_features = vp_finalize_features,
  .bus_name = vp_bus_name,
  .set_vq_affinity = vp_set_vq_affinity,
  .get_vq_affinity = vp_get_vq_affinity,
  .get_shm_region  = vp_get_shm_region,
};
```

```c
static int vp_modern_find_vqs(struct virtio_device *vdev, unsigned nvqs,
            struct virtqueue *vqs[],
            vq_callback_t *callbacks[],
            const char * const names[], const bool *ctx,
            struct irq_affinity *desc)
{
  struct virtio_pci_device *vp_dev = to_vp_device(vdev);
  struct virtqueue *vq;
  int rc = vp_find_vqs(vdev, nvqs, vqs, callbacks, names, ctx, desc);

  if (rc)
    return rc;

  /* Select and activate all queues. Has to be done last: once we do
   * this, there's no way to go back except reset.
   */
  list_for_each_entry(vq, &vdev->vqs, list) {
    vp_iowrite16(vq->index, &vp_dev->common->queue_select);
    vp_iowrite16(1, &vp_dev->common->queue_enable);
  }

  return 0;
}
```



```c
/**
 * virtio_device - representation of a device using virtio
 * @index: unique position on the virtio bus
 * @failed: saved value for VIRTIO_CONFIG_S_FAILED bit (for restore)
 * @config_enabled: configuration change reporting enabled
 * @config_change_pending: configuration change reported while disabled
 * @config_lock: protects configuration change reporting
 * @dev: underlying device.
 * @id: the device type identification (used to match it with a driver).
 * @config: the configuration ops for this device.
 * @vringh_config: configuration ops for host vrings.
 * @vqs: the list of virtqueues for this device.
 * @features: the features supported by both driver and device.
 * @priv: private pointer for the driver's use.
 */
struct virtio_device {
  int index;
  bool failed;
  bool config_enabled;
  bool config_change_pending;
  spinlock_t config_lock;
  struct device dev;
  struct virtio_device_id id;
  const struct virtio_config_ops *config;
  const struct vringh_config_ops *vringh_config;
  struct list_head vqs;
  u64 features;
  void *priv;
};
```

```c

/**
 * virtqueue - a queue to register buffers for sending or receiving.
 * @list: the chain of virtqueues for this device
 * @callback: the function to call when buffers are consumed (can be NULL).
 * @name: the name of this virtqueue (mainly for debugging)
 * @vdev: the virtio device this queue was created for.
 * @priv: a pointer for the virtqueue implementation to use.
 * @index: the zero-based ordinal number for this queue.
 * @num_free: number of elements we expect to be able to fit.
 *
 * A note on @num_free: with indirect buffers, each buffer needs one
 * element in the queue, otherwise a buffer will need one element per
 * sg element.
 */
struct virtqueue {
  struct list_head list;
  void (*callback)(struct virtqueue *vq);
  const char *name;
  struct virtio_device *vdev;
  unsigned int index;
  unsigned int num_free;
  void *priv;
};

static const struct blk_mq_ops virtio_mq_ops = {
  .queue_rq = virtio_queue_rq,
  .commit_rqs = virtio_commit_rqs,
  .complete = virtblk_request_done,
  .init_request = virtblk_init_request,
  .map_queues = virtblk_map_queues,
};
```

### virtio_pci_driver
- drivers/virtio/virtio_pci_common.c

主要提供 virtio_pci_config_ops ，virtio 驱动最后会调用到此处:

```txt
#0  vp_find_vqs (vdev=vdev@entry=0xffff888004150000, nvqs=5, vqs=0xffffc9000003bca8, callbacks=0xffffc9000003bcd0, names=0xffffc9000003bcf8, ctx=0x0 <fixed_percpu_data>, desc=0x0 <fixed_percpu_data>) at drivers/virtio/virtio_pci_common.c:405
#1  0xffffffff81726212 in vp_modern_find_vqs (vdev=0xffff888004150000, nvqs=<optimized out>, vqs=<optimized out>, callbacks=<optimized out>, names=<optimized out>, ctx=<optimized out>, desc=0x0 <fixed_percpu_data>) at drivers/virtio/virtio_pci_modern.c:355
#2  0xffffffff81727d9d in virtio_find_vqs (desc=0x0 <fixed_percpu_data>, names=0xffffc9000003bcf8, callbacks=0xffffc9000003bcd0, vqs=0xffffc9000003bca8, nvqs=5, vdev=<optimized out>) at include/linux/virtio_config.h:227
#3  init_vqs (vb=vb@entry=0xffff888004152800) at drivers/virtio/virtio_balloon.c:527
#4  0xffffffff81728385 in virtballoon_probe (vdev=0xffff888004150000) at drivers/virtio/virtio_balloon.c:888
```

- vp_find_vqs : 初始化 vq
  - vp_find_vqs_msix ：这是推荐的配置
    - vp_request_msix_vectors : 注册 vp_config_changed 的中断
    - vp_setup_vq : 给每一个 queue 注册 vring_interrupt
  - vp_find_vqs_intx
    - request_irq
    - vp_setup_vq
      - `vp_dev->setup_vq` : virtio_pci_device::setup_vq, 这个在 virtio_pci_legacy_probe 中间初始化
      - 使用 virtio_pci_legacy.c::setup_vq 作为例子
          - iowrite16(index, vp_dev->ioaddr + VIRTIO_PCI_QUEUE_SEL); // 告诉选择的数值是哪一个 queue
          - ioread16(vp_dev->ioaddr + VIRTIO_PCI_QUEUE_NUM); // 读 bar 0 约定的配置空间，得到 queue 的大小
          - vring_create_virtqueue
             - 在这里，有一个参数 vp_nofify 作为 callback 函数
             - vring_alloc_queue : 分配的页面是连续物理内存
          - iowrite32(q_pfn, vp_dev->ioaddr + VIRTIO_PCI_QUEUE_PFN); // 告诉 kvmtool，virtqueue 准备好了

## interrupt
- vring_interrupt : qeueu 接受到信息
- vp_config_changed : 当出现配置的时候，例如修改 virtio-mem 的大小的时候

```txt
#0  vring_interrupt (irq=irq@entry=11, _vq=0xffff888100d9c400) at drivers/virtio/virtio_ring.c:2441
#1  0xffffffff8172648f in vp_vring_interrupt (irq=11, opaque=0xffff88800413d800) at drivers/virtio/virtio_pci_common.c:68
#2  0xffffffff811658d1 in __handle_irq_event_percpu (desc=desc@entry=0xffff888003920e00) at kernel/irq/handle.c:158
#3  0xffffffff81165a7f in handle_irq_event_percpu (desc=0xffff888003920e00) at kernel/irq/handle.c:193
#4  handle_irq_event (desc=desc@entry=0xffff888003920e00) at kernel/irq/handle.c:210
#5  0xffffffff81169c1b in handle_fasteoi_irq (desc=0xffff888003920e00) at kernel/irq/chip.c:714
#6  0xffffffff810b9a14 in generic_handle_irq_desc (desc=0xffff888003920e00) at include/linux/irqdesc.h:158
#7  handle_irq (regs=<optimized out>, desc=0xffff888003920e00) at arch/x86/kernel/irq.c:231
#8  __common_interrupt (regs=<optimized out>, vector=34) at arch/x86/kernel/irq.c:250
#9  0xffffffff81ef93d3 in common_interrupt (regs=0xffffc90000197bf8, error_code=<optimized out>) at arch/x86/kernel/irq.c:240
```

```txt
#0  vp_config_changed (opaque=0xffff88800413d800, irq=11) at drivers/virtio/virtio_pci_common.c:54
#1  vp_interrupt (irq=11, opaque=0xffff88800413d800) at drivers/virtio/virtio_pci_common.c:97
#2  0xffffffff811658d1 in __handle_irq_event_percpu (desc=desc@entry=0xffff888003920e00) at kernel/irq/handle.c:158
#3  0xffffffff81165a7f in handle_irq_event_percpu (desc=0xffff888003920e00) at kernel/irq/handle.c:193
#4  handle_irq_event (desc=desc@entry=0xffff888003920e00) at kernel/irq/handle.c:210
#5  0xffffffff81169c1b in handle_fasteoi_irq (desc=0xffff888003920e00) at kernel/irq/chip.c:714
#6  0xffffffff810b9a14 in generic_handle_irq_desc (desc=0xffff888003920e00) at include/linux/irqdesc.h:158
#7  handle_irq (regs=<optimized out>, desc=0xffff888003920e00) at arch/x86/kernel/irq.c:231
#8  __common_interrupt (regs=<optimized out>, vector=34) at arch/x86/kernel/irq.c:250
#9  0xffffffff81ef93d3 in common_interrupt (regs=0xffffc900000bbe38, error_code=<optimized out>) at arch/x86/kernel/irq.c:240
Backtrace stopped: Cannot access memory at address 0xffffc90000101018
```

- [ ] 为什么两个 irq 都是 11 的哇

- 通过 vp_notify 通知给 Host 内核的:
```txt
#0  vp_notify (vq=0xffff888140418e00) at drivers/virtio/virtio_pci_common.c:45
#1  0xffffffff81722296 in virtqueue_notify (_vq=0xffff888140418e00) at drivers/virtio/virtio_ring.c:2231
#2  0xffffffff8197812d in virtio_queue_rqs (rqlist=0xffffc90001027b68) at drivers/block/virtio_blk.c:441
#3  0xffffffff81612ffd in __blk_mq_flush_plug_list (plug=0xffffc90001027b68, q=0xffff888101d59fc8) at block/blk-mq.c:2577
#4  __blk_mq_flush_plug_list (plug=0xffffc90001027b68, q=0xffff888101d59fc8) at block/blk-mq.c:2572
#5  blk_mq_flush_plug_list (plug=plug@entry=0xffffc90001027b68, from_schedule=from_schedule@entry=false) at block/blk-mq.c:2633
#6  0xffffffff816070e1 in __blk_flush_plug (plug=0xffffc90001027b68, plug@entry=0xffffc90001027b18, from_schedule=from_schedule@entry=false) at block/blk-core.c:1153
#7  0xffffffff81607370 in blk_finish_plug (plug=0xffffc90001027b18) at block/blk-core.c:1177
#8  blk_finish_plug (plug=plug@entry=0xffffc90001027b68) at block/blk-core.c:1174
#9  0xffffffff8128a9e7 in read_pages (rac=rac@entry=0xffffc90001027c58) at mm/readahead.c:181
#10 0xffffffff8128b10d in page_cache_ra_order (ractl=0xffffc90001027c58, ractl@entry=0x0 <fixed_percpu_data>, ra=0xffff8881475a6598, new_order=2) at mm/readahead.c:539
#11 0xffffffff8128b3bb in ondemand_readahead (ractl=ractl@entry=0x0 <fixed_percpu_data>, folio=folio@entry=0x0 <fixed_percpu_data>, req_size=req_size@entry=1) at mm/readahead.c:672
#12 0xffffffff8128b605 in page_cache_sync_ra (ractl=0x0 <fixed_percpu_data>, ractl@entry=0xffffc90001027c58, req_count=req_count@entry=1) at mm/readahead.c:699
#13 0xffffffff8127ece6 in page_cache_sync_readahead (req_count=1, index=0, file=0xffff8881475a6500, ra=0xffff8881475a6598, mapping=0xffff8881068e6eb0) at include/linux/pagemap.h:1215
#14 filemap_get_pages (iocb=iocb@entry=0xffffc90001027e28, iter=iter@entry=0xffffc90001027e00, fbatch=fbatch@entry=0xffffc90001027d00) at mm/filemap.c:2566
#15 0xffffffff8127f304 in filemap_read (iocb=iocb@entry=0xffffc90001027e28, iter=iter@entry=0xffffc90001027e00, already_read=0) at mm/filemap.c:2660
#16 0xffffffff81280f20 in generic_file_read_iter (iocb=iocb@entry=0xffffc90001027e28, iter=iter@entry=0xffffc90001027e00) at mm/filemap.c:2806
#17 0xffffffff81560d0b in xfs_file_buffered_read (iocb=0xffffc90001027e28, to=0xffffc90001027e00) at fs/xfs/xfs_file.c:277
#18 0xffffffff81560df5 in xfs_file_read_iter (iocb=<optimized out>, to=<optimized out>) at fs/xfs/xfs_file.c:302
#19 0xffffffff8134a5e3 in __kernel_read (file=0xffff8881475a6500, buf=buf@entry=0xffff8881427266a0, count=count@entry=256, pos=pos@entry=0xffffc90001027e90) at fs/read_write.c:428
#20 0xffffffff8134a796 in kernel_read (file=<optimized out>, buf=buf@entry=0xffff8881427266a0, count=count@entry=256, pos=pos@entry=0xffffc90001027e90) at fs/read_write.c:446
#21 0xffffffff81352809 in prepare_binprm (bprm=0xffff888142726600) at fs/exec.c:1664
#22 search_binary_handler (bprm=0xffff888142726600) at fs/exec.c:1718
#23 exec_binprm (bprm=0xffff888142726600) at fs/exec.c:1775
#24 bprm_execve (flags=<optimized out>, filename=<optimized out>, fd=<optimized out>, bprm=0xffff888142726600) at fs/exec.c:1844
#25 bprm_execve (bprm=0xffff888142726600, fd=<optimized out>, filename=<optimized out>, flags=<optimized out>) at fs/exec.c:1806
#26 0xffffffff81352dfd in do_execveat_common (fd=fd@entry=-100, filename=0xffff888004379000, flags=0, envp=..., argv=..., envp=..., argv=...) at fs/exec.c:1949
#27 0xffffffff8135301e in do_execve (__envp=0x7fffbacdd978, __argv=0x7fffbacdafe0, filename=<optimized out>) at fs/exec.c:2023
#28 __do_sys_execve (envp=0x7fffbacdd978, argv=0x7fffbacdafe0, filename=<optimized out>) at fs/exec.c:2099
#29 __se_sys_execve (envp=<optimized out>, argv=<optimized out>, filename=<optimized out>) at fs/exec.c:2094
#30 __x64_sys_execve (regs=<optimized out>) at fs/exec.c:2094
#31 0xffffffff81ef8c2b in do_syscall_x64 (nr=<optimized out>, regs=0xffffc90001027f58) at arch/x86/entry/common.c:50
#32 do_syscall_64 (regs=0xffffc90001027f58, nr=<optimized out>) at arch/x86/entry/common.c:80
```


## vring

```txt
#0  virtqueue_add (gfp=2592, ctx=0x0 <fixed_percpu_data>, data=0xffff88814003d508, in_sgs=1, out_sgs=1, total_sg=2, sgs=0xffffc9000007bc78, _vq=0xffff888100efd900) at drivers/virtio/virtio_ring.c:2086
#1  virtqueue_add_sgs (_vq=_vq@entry=0xffff888100efd900, sgs=sgs@entry=0xffffc9000007bc78, out_sgs=out_sgs@entry=1, in_sgs=in_sgs@entry=1, data=data@entry=0xffff88814003d508, gfp=gfp@entry=2592) at drivers/virtio/virtio_ring.c:2122
#2  0xffffffff81976586 in virtblk_add_req (vq=0xffff888100efd900, vbr=vbr@entry=0xffff88814003d508) at drivers/block/virtio_blk.c:130
#3  0xffffffff81977742 in virtio_queue_rq (hctx=0xffff88814003d200, bd=0xffffc9000007bd70) at drivers/block/virtio_blk.c:353
#4  0xffffffff816121cf in blk_mq_dispatch_rq_list (hctx=hctx@entry=0xffff88814003d200, list=list@entry=0xffffc9000007bdc0, nr_budgets=nr_budgets@entry=0) at block/blk-mq.c:1902
#5  0xffffffff816184c3 in __blk_mq_sched_dispatch_requests (hctx=hctx@entry=0xffff88814003d200) at block/blk-mq-sched.c:306
#6  0xffffffff816185a0 in blk_mq_sched_dispatch_requests (hctx=hctx@entry=0xffff88814003d200) at block/blk-mq-sched.c:339
#7  0xffffffff8160eff0 in __blk_mq_run_hw_queue (hctx=0xffff88814003d200) at block/blk-mq.c:2020
#8  0xffffffff8160f2a0 in __blk_mq_delay_run_hw_queue (hctx=<optimized out>, async=<optimized out>, msecs=msecs@entry=0) at block/blk-mq.c:2096
#9  0xffffffff8160f509 in blk_mq_run_hw_queue (hctx=<optimized out>, async=async@entry=false) at block/blk-mq.c:2144
#10 0xffffffff8160f8a0 in blk_mq_run_hw_queues (q=q@entry=0xffff888100c75fc8, async=async@entry=false) at block/blk-mq.c:2192
#11 0xffffffff816103db in blk_mq_requeue_work (work=0xffff888100c761f8) at block/blk-mq.c:1361
#12 0xffffffff81122d37 in process_one_work (worker=worker@entry=0xffff888003850a80, work=0xffff888100c761f8) at kernel/workqueue.c:2289
#13 0xffffffff811232c8 in worker_thread (__worker=0xffff888003850a80) at kernel/workqueue.c:2436
#14 0xffffffff81129c73 in kthread (_create=0xffff88800425b180) at kernel/kthread.c:376
#15 0xffffffff81001a72 in ret_from_fork () at arch/x86/entry/entry_64.S:306
```

- vring_virtqueue 持有 virtqueue 和 vring_virtqueue_split
- vring_virtqueue_split 持有 vring
- vring 持有 vring_desc，vring_avail 和 vring_used 的指针

- [ ] virtqueue 的定位是什么?


- virtqueue_add_split => virtqueue_add_desc_split 向 vring::desc 数组中添加

- 一个 vring_desc 不是对应一个 page 的，而是对应一个 scatterlist
- vring_desc 也是形成一个链表的
- vring_map_one_sg 获取一个 scatterlist 的物理地址

- [ ] 有趣，分析 scatterlist 和 blk 的联系，但是没有太看懂:
  - 从 virtblk_add_req 开始分析吧

### vring_size
参数 align 为 :
```c
/* The alignment to use between consumer and producer parts of vring.
 * x86 pagesize again. */
#define VIRTIO_PCI_VRING_ALIGN    4096
```
参数 num 是 VIRTIO_PCI_QUEUE_NUM, kvmtool 配置的是 16

```c
static inline unsigned vring_size(unsigned int num, unsigned long align)
{
  return ((sizeof(struct vring_desc) * num + sizeof(__virtio16) * (3 + num)
     + align - 1) & ~(align - 1))
    + sizeof(__virtio16) * 3 + sizeof(struct vring_used_elem) * num;
}
```
- [x] vring_size 含义在百度书上解释过，但是页面对齐，为什么不包含 vring_used 的
  - 从 vring_init 中间可以找到对称的数值

- [ ] vring_avail 和 vring_used 的成员都是只有两个(flags 和 idx), 为什么需要三个

```txt
#0  vring_alloc_queue_split (vring_split=vring_split@entry=0xffffc9000003bab0, vdev=vdev@entry=0xffff888004998000, num=128, num@entry=4294967295, vring_align=vring_align@entry=64, may_reduce_num=may_reduce_num@entry=true) at drivers/virtio/virtio_ring.c:1042
#1  0xffffffff81724d40 in vring_create_virtqueue_split (name=0xffffffff82835c3d "inflate", callback=0xffffffff81727ab0 <balloon_ack>, notify=0xffffffff81726d30 <vp_notify>, context=false, may_reduce_num=true, weak_barriers=true, vdev=0xffff888004998000, vring_align=64, num=4294967295, index=0) at drivers/virtio/virtio_ring.c:1101
#2  vring_create_virtqueue (index=index@entry=0, num=num@entry=128, vring_align=vring_align@entry=64, vdev=vdev@entry=0xffff888004998000, weak_barriers=weak_barriers@entry=true, may_reduce_num=may_reduce_num@entry=true, context=false, notify=0xffffffff81726d30 <vp_notify>, callback=0xffffffff81727ab0 <balloon_ack>, name=0xffffffff82835c3d "inflate") at drivers/virtio/virtio_ring.c:2546
#3  0xffffffff817260a7 in setup_vq (vp_dev=0xffff888004998000, info=0xffff8880042c7c80, index=0, callback=0xffffffff81727ab0 <balloon_ack>, name=0xffffffff82835c3d "inflate", ctx=<optimized out>, msix_vec=65535) at drivers/virtio/virtio_pci_modern.c:321
#4  0xffffffff8172697a in vp_setup_vq (vdev=vdev@entry=0xffff888004998000, index=index@entry=0, callback=0xffffffff81727ab0 <balloon_ack>, name=0xffffffff82835c3d "inflate", ctx=<optimized out>, msix_vec=msix_vec@entry=65535) at drivers/virtio/virtio_pci_common.c:189
#5  0xffffffff81727535 in vp_find_vqs_intx (ctx=0x0 <fixed_percpu_data>, names=0xffffc9000003bcf8, callbacks=0xffffc9000003bcd0, vqs=0xffffc9000003bca8, nvqs=5, vdev=0xffff888004998000) at drivers/virtio/virtio_pci_common.c:381
#6  vp_find_vqs (vdev=vdev@entry=0xffff888004998000, nvqs=5, vqs=0xffffc9000003bca8, callbacks=0xffffc9000003bcd0, names=0xffffc9000003bcf8, ctx=0x0 <fixed_percpu_data>, desc=0x0 <fixed_percpu_data>) at drivers/virtio/virtio_pci_common.c:413
#7  0xffffffff81726652 in vp_modern_find_vqs (vdev=0xffff888004998000, nvqs=<optimized out>, vqs=<optimized out>, callbacks=<optimized out>, names=<optimized out>, ctx=<optimized out>, desc=0x0 <fixed_percpu_data>) at drivers/virtio/virtio_pci_modern.c:355
#8  0xffffffff817281dd in virtio_find_vqs (desc=0x0 <fixed_percpu_data>, names=0xffffc9000003bcf8, callbacks=0xffffc9000003bcd0, vqs=0xffffc9000003bca8, nvqs=5, vdev=<optimized out>) at include/linux/virtio_config.h:227
#9  init_vqs (vb=vb@entry=0xffff88800499a800) at drivers/virtio/virtio_balloon.c:527
#10 0xffffffff817287c5 in virtballoon_probe (vdev=0xffff888004998000) at drivers/virtio/virtio_balloon.c:888
```

- [ ] vp_setup_vq 是需要和 vp_find_vqs_intx 下调用的，和中断是关系的吗?

- 通过 vp_active_vq 将 vring_desc , vring_avail 和 vring_used 的地址发送给 QEMU 的。

### desc
如果从 multiqueue 到达了一个消息下来，那么 vring_avail 增加一个。
如果在 host 中间将任务完成了，那么 vring_used 增加一个, 在 host 通过中断的方式通知 guest 之后，guest 处理 vring_used ，并且释放

从 5.2 的描述看，vring_desc 会构成链表，描述一次 IO 的所有数据。

vring_avail 表示当前设备可以使用的 vring_desc, 这些数据从上层到达之后，vring_avail::idx++,
vring_avail::ring 描述的项目增加，如果被设备消费了，那么 last_avail_idx ++

设备每处理一个可用描述符数组 ring 的描述符链，都需要将其追加到 vring_used 数组中。

设备通过 vring_used 将告诉驱动那些数据被使用了。感觉这就是一个返回值列表罢了。

- [ ] idx 是谁维护的，两个 last_avail_idx 和 last_used_idx 是谁维护的

- [ ] 这些队列都是 guest 维护的吗? 显然不是

- 在设备侧定义 last_avail_idx ，在驱动侧定义 last_used_idx
  - vring_virtqueue::last_used_idx 例如， virtblk_done -> virtqueue_get_buf 的时候会更新的，因为设备处理数据完成。

- [ ] last_avail_idx 和 last_used_idx 都是队列的一部分，总是需要和另一个共享吧，不然队列直接被毁掉了，如何处理?

## vring_used_elem::len 是什么作用的

```txt
#0  virtqueue_get_buf_ctx_split (ctx=0x0 <fixed_percpu_data>, len=0xffffc90000003f1c, _vq=0xffff888140418e00) at drivers/virtio/virtio_ring.c:790
#1  virtqueue_get_buf_ctx (_vq=0xffff888140418e00, len=len@entry=0xffffc90000003f1c, ctx=ctx@entry=0x0 <fixed_percpu_data>) at drivers/virtio/virtio_ring.c:2282
#2  0xffffffff81722f27 in virtqueue_get_buf (_vq=<optimized out>, len=len@entry=0xffffc90000003f1c) at drivers/virtio/virtio_ring.c:2288
#3  0xffffffff819766ba in virtblk_done (vq=0xffff888140418e00) at drivers/block/virtio_blk.c:283
#4  0xffffffff81722f85 in vring_interrupt (irq=<optimized out>, _vq=<optimized out>) at drivers/virtio/virtio_ring.c:2462
#5  vring_interrupt (irq=<optimized out>, _vq=<optimized out>) at drivers/virtio/virtio_ring.c:2437
#6  0xffffffff811658d1 in __handle_irq_event_percpu (desc=desc@entry=0xffff888140458400) at kernel/irq/handle.c:158
#7  0xffffffff81165a7f in handle_irq_event_percpu (desc=0xffff888140458400) at kernel/irq/handle.c:193
#8  handle_irq_event (desc=desc@entry=0xffff888140458400) at kernel/irq/handle.c:210
#9  0xffffffff81169e0a in handle_edge_irq (desc=0xffff888140458400) at kernel/irq/chip.c:819
#10 0xffffffff810b9a14 in generic_handle_irq_desc (desc=0xffff888140458400) at include/linux/irqdesc.h:158
#11 handle_irq (regs=<optimized out>, desc=0xffff888140458400) at arch/x86/kernel/irq.c:231
#12 __common_interrupt (regs=<optimized out>, vector=36) at arch/x86/kernel/irq.c:250
#13 0xffffffff81efa443 in common_interrupt (regs=0xffffc90001027998, error_code=<optimized out>) at arch/x86/kernel/irq.c:240
```
- 修改 vring_used_elem::len 的位置只有在 `vhost_net` 和 `virtqueue_get_buf_ctx_split` 中，`virtqueue_get_buf_ctx_split` 的调用是非常频繁的，看来 vring_used_elem::len 总是在被 host 更新
  - 而且 vhost_net 本来就是 host 的代码，所以更加说明这是 host 告诉 guest 的。
  - 的确是设备写回到 guest 驱动的数据。


- [ ] 为什么 vring_avail 没有这个 length
- [ ] 难道不能从 vring_desc 中获取吗?


## Guest 的 virtio-blk 如何将数据发送到 vring 中的

和 scsi 以及 nvme 相同的，驱动注册 multiqueue 的 hook:
```c
static const struct blk_mq_ops virtio_mq_ops = {
  .queue_rq = virtio_queue_rq,
  .complete = virtblk_request_done,
  .init_request = virtblk_init_request,
  .map_queues = virtblk_map_queues,
};
```

```c
/*
 * This comes first in the read scatter-gather list.
 * For legacy virtio, if VIRTIO_F_ANY_LAYOUT is not negotiated,
 * this is the first element of the read scatter-gather list.
 */
struct virtio_blk_outhdr {
  /* VIRTIO_BLK_T* */
  __virtio32 type;
  /* io priority. */
  __virtio32 ioprio;
  /* Sector (ie. 512 byte offset) */
  __virtio64 sector;
};
```

- virtblk_add_req 中，将 virtblk_req::out_hdr 放到 scatterlist 中，之后 scatterlist 的元素会被逐个转换为 vring_desc

分析一下 virtio_blk_outhdr 是如何生成的，在 virtblk_setup_cmd 中是 virtio_blk_outhdr::sector 中唯一的访问位置:

```txt
#0  virtblk_setup_cmd (vdev=0xffff888100705000, req=req@entry=0xffff8881411d0000, vbr=vbr@entry=0xffff8881411d0108) at drivers/block/virtio_blk.c:220
#1  0xffffffff81977e31 in virtblk_prep_rq (vblk=0xffff888101910000, vblk=0xffff888101910000, vbr=0xffff8881411d0108, req=0xffff8881411d0000, hctx=0xffff888141087600) at drivers/block/virtio_blk.c:321
#2  virtio_queue_rq (hctx=0xffff888141087600, bd=0xffffc9000003b868) at drivers/block/virtio_blk.c:348
#3  0xffffffff81611edc in __blk_mq_issue_directly (last=true, rq=0xffff8881411d0000, hctx=0xffff888141087600) at block/blk-mq.c:2440
#4  __blk_mq_try_issue_directly (hctx=0xffff888141087600, rq=rq@entry=0xffff8881411d0000, bypass_insert=bypass_insert@entry=false, last=last@entry=true) at block/blk-mq.c:2493
#5  0xffffffff816120d2 in blk_mq_try_issue_directly (hctx=<optimized out>, rq=0xffff8881411d0000) at block/blk-mq.c:2517
#6  0xffffffff8161370c in blk_mq_submit_bio (bio=<optimized out>) at block/blk-mq.c:2843
#7  0xffffffff81606212 in __submit_bio (bio=<optimized out>) at block/blk-core.c:595
#8  0xffffffff81606806 in __submit_bio_noacct_mq (bio=<optimized out>) at block/blk-core.c:672
#9  submit_bio_noacct_nocheck (bio=<optimized out>) at block/blk-core.c:689
#10 submit_bio_noacct_nocheck (bio=<optimized out>) at block/blk-core.c:678
#11 0xffffffff81390395 in submit_bh_wbc (opf=<optimized out>, opf@entry=0, bh=0xffff8881017ab000, wbc=wbc@entry=0x0 <fixed_percpu_data>) at fs/buffer.c:2719
#12 0xffffffff81391e88 in submit_bh (bh=<optimized out>, opf=0) at fs/buffer.c:2725
#13 block_read_full_folio (folio=0xffffea0004066980, folio@entry=<error reading variable: value has been optimized out>, get_block=0xffffffff815fedb0 <blkdev_get_block>, get_block@entry=<error reading variable: value has been optimized out>) at fs/buffer.c:2340
#14 0xffffffff8127d0da in filemap_read_folio (file=0x0 <fixed_percpu_data>, filler=<optimized out>, folio=0xffffea0004066980) at mm/filemap.c:2394
#15 0xffffffff8127f9de in do_read_cache_folio (mapping=0xffff88810176b500, index=index@entry=0, filler=0xffffffff815fee00 <blkdev_read_folio>, filler@entry=0x0 <fixed_percpu_data>, file=file@entry=0x0 <fixed_percpu_data>, gfp=1051840) at mm/filemap.c:3519
#16 0xffffffff8127faa9 in read_cache_folio (mapping=<optimized out>, index=index@entry=0, filler=filler@entry=0x0 <fixed_percpu_data>, file=file@entry=0x0 <fixed_percpu_data>) at include/linux/pagemap.h:274
#17 0xffffffff8161deed in read_mapping_folio (file=0x0 <fixed_percpu_data>, index=0, mapping=<optimized out>) at include/linux/pagemap.h:762
```

但是追查 `request::__sector` 就和 block layer 放到一起了。

## QEMU 侧如何接受数据

virtio 标准在 virtio 设备的配置空间中，增加了一个 Queue Notify 寄存器，驱动准备好了 virtqueue 之后, 向 Queue Notify 寄存器发起写操作，
切换到 Host 状态中间。

- virtio_queue_rq
  - virtblk_add_req : 消息加入到队列中间
  - virtqueue_kick
    - virtqueue_kick_prepare
    - virtqueue_notify
      - `vq->notify`
        - vring_virtqueue::notify : 在 vring_alloc_queue 中间注册的 vp_notify

- [ ] 如果存在 eventfd 机制，因为通知方式是 MMIO，所以，其实内核可以在另一侧就通知出来这个事情，不需要在下上通知退出原因是什么位置的 MMIO


```txt
#0  virtio_blk_handle_output (vdev=0x555557cae140, vq=0x7ffff40d8010) at ../hw/block/virtio-blk.c:810
#1  0x0000555555b2307f in virtio_queue_notify_vq (vq=0x7ffff40d8010) at ../hw/virtio/virtio.c:2365
#2  0x0000555555d5b628 in aio_dispatch_handler (ctx=ctx@entry=0x55555661d7c0, node=0x7ffcd0006340) at ../util/aio-posix.c:369
#3  0x0000555555d5bee2 in aio_dispatch_handlers (ctx=0x55555661d7c0) at ../util/aio-posix.c:412
#4  aio_dispatch (ctx=0x55555661d7c0) at ../util/aio-posix.c:422
#5  0x0000555555d6ed7e in aio_ctx_dispatch (source=<optimized out>, callback=<optimized out>, user_data=<optimized out>) at ../util/async.c:320
#6  0x00007ffff79e7dfb in g_main_context_dispatch () from /nix/store/s7yq6ngnxf4gsp4263q7xywfjihh5mpn-glib-2.72.2/lib/libglib-2.0.so.0
#7  0x0000555555d7b058 in glib_pollfds_poll () at ../util/main-loop.c:297
#8  os_host_main_loop_wait (timeout=91100000) at ../util/main-loop.c:320
#9  main_loop_wait (nonblocking=nonblocking@entry=0) at ../util/main-loop.c:596
#10 0x00005555559d28f7 in qemu_main_loop () at ../softmmu/runstate.c:734
#11 0x000055555582712c in qemu_main (argc=<optimized out>, argv=<optimized out>, envp=<optimized out>) at ../softmmu/main.c:38
```

virtio_blk_handle_output 中，调用 virtio_blk_handle_request 来解析 virtio_blk_outhdr


当 IO 任务结束之后，virtio_blk_rw_complete 调用 virtio_notify 来通知 Guest

```txt
0  virtio_blk_rw_complete (opaque=0x555557bc4400, ret=0) at ../hw/block/virtio-blk.c:119
#1  0x0000555555c5bd38 in blk_aio_complete (acb=0x5555570c0060) at ../block/block-backend.c:1503
#2  blk_aio_complete (acb=0x5555570c0060) at ../block/block-backend.c:1500
#3  blk_aio_read_entry (opaque=0x5555570c0060) at ../block/block-backend.c:1558
#4  0x0000555555d70d8b in coroutine_trampoline (i0=<optimized out>, i1=<optimized out>) at ../util/coroutine-ucontext.c:177
#5  0x00007ffff769ef60 in __correctly_grouped_prefixwc () from /nix/store/scd5n7xsn0hh0lvhhnycr9gx0h8xfzsl-glibc-2.34-210/lib/libc.so.6
#6  0x0000000000000000 in ?? ()
$ qemu coroutine
usage: qemu coroutine <coroutine-pointer>
$ qemu bt
#0  virtio_blk_rw_complete (opaque=0x555557bc4400, ret=0) at ../hw/block/virtio-blk.c:119
#1  0x0000555555c5bd38 in blk_aio_complete (acb=0x5555570c0060) at ../block/block-backend.c:1503
#2  blk_aio_complete (acb=0x5555570c0060) at ../block/block-backend.c:1500
#3  blk_aio_read_entry (opaque=0x5555570c0060) at ../block/block-backend.c:1558
#4  0x0000555555d70d8b in coroutine_trampoline (i0=<optimized out>, i1=<optimized out>) at ../util/coroutine-ucontext.c:177
#5  0x00007ffff769ef60 in __correctly_grouped_prefixwc () from /nix/store/scd5n7xsn0hh0lvhhnycr9gx0h8xfzsl-glibc-2.34-210/lib/libc.so.6
#6  0x0000000000000000 in ?? ()
Coroutine at 0x7ffff7212320:
#0  qemu_coroutine_switch (from_=from_@entry=0x7ffff7212320, to_=to_@entry=0x555556a55d40, action=action@entry=COROUTINE_ENTER) at ../util/coroutine-ucontext.c:307
#1  0x0000555555d7b4b8 in qemu_aio_coroutine_enter (ctx=ctx@entry=0x55555661d7c0, co=co@entry=0x555556a55d40) at ../util/qemu-coroutine.c:162
#2  0x0000555555d6fbf3 in aio_co_enter (ctx=0x55555661d7c0, co=0x555556a55d40) at ../util/async.c:665
#3  0x0000555555cc2e17 in luring_process_completions (s=s@entry=0x55555686ae90) at ../block/io_uring.c:215
#4  0x0000555555cc31f8 in ioq_submit (s=0x55555686ae90) at ../block/io_uring.c:260
#5  0x0000555555c6c84c in bdrv_io_unplug (bs=0x555556863900) at ../block/io.c:3286
#6  0x0000555555c6c81d in bdrv_io_unplug (bs=<optimized out>) at ../block/io.c:3291
#7  0x0000555555c5ca16 in blk_io_unplug (blk=<optimized out>) at ../block/block-backend.c:2284
#8  0x0000555555ada9dd in virtio_blk_handle_vq (s=0x555557cae140, vq=0x7ffff40d8010) at ../hw/block/virtio-blk.c:802
#9  0x0000555555b2307f in virtio_queue_notify_vq (vq=0x7ffff40d8010) at ../hw/virtio/virtio.c:2365
#10 0x0000555555d5b628 in aio_dispatch_handler (ctx=ctx@entry=0x55555661d7c0, node=0x7ffcd0006340) at ../util/aio-posix.c:369
#11 0x0000555555d5bee2 in aio_dispatch_handlers (ctx=0x55555661d7c0) at ../util/aio-posix.c:412
#12 aio_dispatch (ctx=0x55555661d7c0) at ../util/aio-posix.c:422
#13 0x0000555555d6ed7e in aio_ctx_dispatch (source=<optimized out>, callback=<optimized out>, user_data=<optimized out>) at ../util/async.c:320
#14 0x00007ffff79e7dfb in g_main_context_dispatch () from /nix/store/s7yq6ngnxf4gsp4263q7xywfjihh5mpn-glib-2.72.2/lib/libglib-2.0.so.0
#15 0x0000555555d7b058 in glib_pollfds_poll () at ../util/main-loop.c:297
#16 os_host_main_loop_wait (timeout=91100000) at ../util/main-loop.c:320
#17 main_loop_wait (nonblocking=nonblocking@entry=0) at ../util/main-loop.c:596
#18 0x00005555559d28f7 in qemu_main_loop () at ../softmmu/runstate.c:734
#19 0x000055555582712c in qemu_main (argc=<optimized out>, argv=<optimized out>, envp=<optimized out>) at ../softmmu/main.c:38
#20 0x00007ffff7676237 in __libc_start_call_main () from /nix/store/scd5n7xsn0hh0lvhhnycr9gx0h8xfzsl-glibc-2.34-210/lib/libc.so.6
#21 0x00007ffff76762f5 in __libc_start_main_impl () from /nix/store/scd5n7xsn0hh0lvhhnycr9gx0h8xfzsl-glibc-2.34-210/lib/libc.so.6
#22 0x0000555555827051 in _start () at ../sysdeps/x86_64/start.S:116
```
