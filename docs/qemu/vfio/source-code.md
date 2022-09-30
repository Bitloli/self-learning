# common.c

# pci.c

1. 处理 read

```c
static const MemoryRegionOps vfio_rom_ops = {
    .read = vfio_rom_read,
    .write = vfio_rom_write,
    .endianness = DEVICE_LITTLE_ENDIAN,
};
```

- `vfio_bar_register`
    - `vfio_region_mmap`
        - `mmap`


`VFIORegion` 会持有一个 `VFIODevice`，而 VFIODevice 持有一个 fd

ccw 可以使用这个进行 ioctl ，和 io

除非这个就是一个 bar 指向的空间

- `vfio_get_device`
    - 通过 VFIOGroup::fd 调用 `VFIO_GROUP_GET_DEVICE_FD`

# platform.c
