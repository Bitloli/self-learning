# 深入理解 qmp

```txt
hack/qemu/internals/e1000-2.md:#18 qmp_x_exit_preconfig (errp=<optimized out>) at ../softmmu/vl.c:2588
hack/qemu/internals/e1000.md:#16 qmp_x_exit_preconfig (errp=<optimized out>) at ../softmmu/vl.c:2588
hack/acpi/hack-with-qemu.md:#10 qmp_x_exit_preconfig (errp=<optimized out>) at ../softmmu/vl.c:2590
docs/kernel/mm-virtio-balloon.md:- qmp 对外仅仅提供两个功能
docs/qemu/block.md:2. 后面的就是各种 qmp 操作的
docs/qemu/block.md:在 `qmp_transaction` 中的，根据命令来调用这些内容:
docs/qemu/block.md:## qmp ：没办法，不搞的话，dirty bitmap 是没有办法维持生活的
docs/qemu/block.md:- [ ] grep 一下目前对于 qmp 的所有问题，尝试将 qmp 和 qemu option 融合一下
docs/qemu/reset.md:  - `qmp_x_exit_preconfig`
docs/qemu/reset.md:#6  0x0000555555c22788 in qmp_x_exit_preconfig (errp=0x5555567aa610 <error_fatal>) at ../softmmu/vl.c:2602
docs/qemu/migration/yank.md:instances can be called by the 'yank' out-of-band qmp command.
docs/qemu/migration/yank.md:# A yank instance can be yanked with the @yank qmp command to recover from a
docs/qemu/migration/multifd.md:    - `migrate_multifd_channels` : 这个数值是从 qmp 设置的
docs/qemu/migration/migration.md:- `qmp_migrate_incoming` / `qmp_migrate_recover`
docs/qemu/migration/migration.md:- `qmp_migrate`
docs/qemu/migration/migration.md:- `qmp_query_migrate_parameters`
docs/qemu/options.md:-qmp unix:/home/maritns3/core/vn/hack/qemu/x64-e1000/test.socket,server,nowait \
docs/qemu/options.md:[qmp] : [unix:/home/maritns3/core/vn/hack/qemu/x64-e1000/test.socket,server,nowait]
docs/qemu/sh/alpine.sh:  ${arg_qmp} ${arg_vfio} ${arg_smbios} ${arg_scsi}"
docs/qemu/todo-1.md:- [ ] docs/devel/qapi-code-gen.txt 和 qmp 如何工作的，是如何生成的。
docs/qemu/todo-1.md:## qmp
docs/qemu/todo-1.md:- [ ] `qmp_block_commit` 的唯一调用者是如何被生成的。
docs/qemu/todo-1.md:qmp 让 virsh 可以和 qemu 交互
docs/qemu/qom.md:#13 0x0000555555cdaf85 in qmp_x_exit_preconfig (errp=0x5555567a94b0 <error_fatal>) at ../softmmu/vl.c:2600
docs/qemu/qom.md:#18 qmp_x_exit_preconfig (errp=<optimized out>) at ../softmmu/vl.c:2689
docs/qemu/qom.md:#19 qmp_x_exit_preconfig (errp=<optimized out>) at ../softmmu/vl.c:2682
docs/qemu/seabios.md:#13 qmp_x_exit_preconfig (errp=<optimized out>) at ../softmmu/vl.c:2588
```

## 基本使用
- https://www.qemu.org/docs/master/devel/writing-monitor-commands.html
- https://wiki.qemu.org/Documentation/QMP
- https://www.qemu.org/docs/master/devel/writing-monitor-commands.html#writing-a-debugging-aid-returning-unstructured-text

{ "execute": "qom-set",
             "arguments": { "path": "/machine/peripheral-anon/device[4]",
             "property": "guest-stats-polling-interval", "value": 2 } }

{ "execute": "qom-get",
             "arguments": { "path": "/machine/peripheral-anon/device[4]",
             "property": "guest-stats" } }
