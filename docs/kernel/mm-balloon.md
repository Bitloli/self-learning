# balloon

- 动机，这是让 guest 自己换出的操作，这引入了多余的通路了吧。
- 让 guest 中使用 swap 真的好傻啊，直接 swap 不好吗?

- 基本的流程 : guest -> virtio device
  - 问题在于，guest 以为自己的内存是足够的，是不会换出的
  - 如果让 guest 还是以为自己持有很多内存，在 GVA -> GPA 的映射是存在的，实际上，Host 已经将内存换出，此时 GPA

- 让 guest 换出之后似乎 Host 是不知道的，如何处理?

- 是不是只是因为 host 无法准确知道 geust 中信息，没有必要给 guest 和

- [ ] 到底什么样的内存会放入到 lru, 是有办法让 guest memory 的内存不放入到 lru 中吗?
  - [ ] 对于这种内存有办法直接使用

- [ ] 默认的机器是存放了 lru 的吗?

## BALLOON_COMPACTION

## HYPERV_BALLOON

## MEMORY_BALLOON

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
