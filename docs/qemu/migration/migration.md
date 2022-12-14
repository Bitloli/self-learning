# migration
> not only live upgrade

- 基本流程
- 优化
- 相关问题
- 对于现在问题的启发是什么。

TODO:
每一个问题都需要看看:
- postcopy
- xbzrle
- colo
- multifd
- yank
- rdma
- [ ] qemu file
- vfio
- [ ] vhost
- [ ] 到底什么是 failover 啊? `PCIDevice::net_failover`

## TODO
- [ ] `qemu_event_wait` 中存在 `smp_mb_acquire`
- [ ] 正在注入的中断怎么如何迁移
- [ ] 那么 snapshot 是如何和这个耦合的哇
- [ ] 有一说一，如果迁移之后，这个网络是怎么保证的啊
- [ ] disk 的修改怎么搞的，动不动就是 1T 之类的
    - [ ] 还是说分布式存储之下，这些都是小问题
- [ ] rdma
- [ ] 已经有无数的函数存在说需要持有，或者不用持有 iothread lock 了。
- [ ] 将最新的 QEMU 的 dirty memory 的东西也 kevein Xu 的那个一并找过来看看。
- [ ] 这里反复出现了  `WITH_RCU_READ_LOCK_GUARD` ，所以到底在保护什么内容，例如在 `ram_load` 中。
- [ ] ram 的迁移需要考虑 hugetlbfs 的
    - `ram_load_postcopy`
- [ ] 根据局部性原理，可能修改的代码总是那几个，所以发送内存应该存在顺序才对，即使是没有 xbzrle 的出现，也应该
使用 cache 记录一下，谁总是在被修改，然后最后发送这些程序。
- [ ] QEMUFile 在 QIOChannel 上再次搞过什么封装吗?
```c
    qemu_set_fd_handler(rdma->channel->fd, rdma_accept_incoming_migration,
                        NULL, (void *)(intptr_t)rdma);
```
- [ ] `qio_channel_rdma_readv` 是如何被调用的，或者类似的 io 函数。

## 核心流程
- `qmp_migrate_incoming` / `qmp_migrate_recover`

输入:
- `fd_start_incoming_migration`
    - `fd_accept_incoming_migration` <------ 使用 fd 作为例子
        - `migration_channel_process_incoming`
            - `migration_ioc_process_incoming`
                - `qemu_file_new_input` : single connection
                - `multifd_recv_new_channel` : multiple connection
                - `migration_incoming_process` : 如果准备好了，那么开始
                    - `qemu_coroutine_create(process_incoming_migration_co, NULL);`
                        - `qemu_loadvm_state` : 就是从这里开始的
                        - 如果是 colo 模式，那么还会继续操作

- `qmp_migrate`
    - `fd_start_outgoing_migration`
        - `migration_channel_connect`
            - `migrate_fd_connect`
                - `migration_thread`
                    - `qemu_savevm_state_header`
                    - `qemu_savevm_state_setup`
                    - `qemu_savevm_wait_unplug` : 不知道这个在表达什么啊
                    - `migration_iteration_run`
                        - `qemu_savevm_state_pending`
                            - `::save_live_pending` : 将所有的 SaveStateEntry 的都执行
                        - `qemu_savevm_state_iterate` ：在这里对于 `savevm_state` 进行这个调用其 hook
                            - [ ] 为什么是 iterated 的，每一个 interaction 的划分标准是什么
                            - `::is_active`  居然只有 block
                            - `::is_active_iterate` 还是只有 block 的
                            - `::has_postcopy` ram 和 block
                            - `save_section_header`
                            - `::save_live_iterate` : vfio block ram
                            - `save_section_footer`
                        - `start_postcopy`

彻底完成 precopy
- `qemu_savevm_state_complete_precopy`
    - `qemu_savevm_state_complete_precopy_iterable`

## 核心的数据结构关系
```c
static SaveState savevm_state = {
    .handlers = QTAILQ_HEAD_INITIALIZER(savevm_state.handlers),
    .handler_pri_head = { [MIG_PRI_DEFAULT ... MIG_PRI_MAX] = NULL },
    .global_section_id = 0,
};
```

的这个上面挂
```c
SaveStateEntry
```

然后将 `savevm_ram_handlers` 和 `ram_state` 关联为其成员:
```c
register_savevm_live("ram", 0, 4, &savevm_ram_handlers, &ram_state);
```


```c
static RAMState *ram_state;
```


## caller of `migration_channel_connect`

- The `migration_channel_process_incoming` have same caller.

- [ ] why it's socket and tls is much loonger
- [ ] what does fd / exec mean?
    - [ ] this is the live upgrade?

- tcp migration: do the migration using tcp sockets
- unix migration: do the migration using unix sockets
- exec migration: do the migration using the stdin/stdout through a process.
- fd migration: do the migration using a file descriptor that is passed to QEMU. QEMU doesn’t care how this file descriptor is opened.

- [ ] 无法理解 exec 是通过
- [ ] 实际上，是通过 tls 的，而没有 unix domain 的。
    - [ ] 感觉在一个机器上的两个 QEMU 进行迁移似乎是一个很寻常的事情，但是为什么没有直接访问。

- [ ] 有趣的操作
    - migrate 命令 ?
    - 可以直接运行脚本? 还有 500 多行的代码。
```plain
```sh
$ qemu-system-x86_64 -display none -monitor stdio
(qemu) migrate "exec:cat > mig"
(qemu) q
$ ./scripts/analyze-migration.py -f mig
{
  "ram (3)": {
      "section sizes": {
          "pc.ram": "0x0000000008000000",
...
```


### fd
- `fd_start_outgoing_migration`
- `fd_start_incoming_migration`

### exec
- `exec_start_outgoing_migration`
- `exec_start_incoming_migration`

### tls
- `migration_tls_outgoing_handshake`
- `migration_tls_incoming_handshake`


### socket
- `socket_start_incoming_migration`
- `socket_start_outgoing_migration`

## [ ] what's channel

## [ ] multifd
- [ ] zlib ?
- [ ] zstd ?

```c
typedef struct {
    /* Setup for sending side */
    int (*send_setup)(MultiFDSendParams *p, Error **errp);
    /* Cleanup for sending side */
    void (*send_cleanup)(MultiFDSendParams *p, Error **errp);
    /* Prepare the send packet */
    int (*send_prepare)(MultiFDSendParams *p, Error **errp);
    /* Setup for receiving side */
    int (*recv_setup)(MultiFDRecvParams *p, Error **errp);
    /* Cleanup for receiving side */
    void (*recv_cleanup)(MultiFDRecvParams *p);
    /* Read all pages */
    int (*recv_pages)(MultiFDRecvParams *p, Error **errp);
} MultiFDMethods;
```
- [ ] 只有 multifd 才会又压缩吗？
- [ ] 为什么又和 tls 有关系?

## KeyStructure
- [ ] MigrationIncomingState
    - [ ] `from_src_file` : why it's so important ?
    - [ ] 为什么会存在这么多的 QemuSemaphore 和 QemuMutex

## Question
- [ ] why QEMU need QEMUFile to handle it?
- [ ] 在哪里处理的基本 disk 的迁移的，难道那不是一个痛苦面具吗？
- [ ] 传输的是否存在压缩的吗？

## nbd

## colo
- `migration_incoming_process`
    - `process_incoming_migration_co`
        - `colo_process_incoming_thread`

- `migrate_start_colo_process`
    - `colo_process_checkpoint`
        - `vm_start`
        - `A while loop`
            - `qemu_event_wait` : `MigrationState::colo_checkpoint_event` -> `colo_checkpoint_notify`
            - `colo_do_checkpoint_transaction`

- [ ] 需要理解的概念
    - failover
    - checkpoint

## 关联的模块

### ./io

- 对于这些东西的封装是不是因此获取了相同的 coroutine 的实力。
    - io/channel.c 中，主要是在 `qio_channel_writev_full_all` 中的。
- 还可以屏蔽操作系统的接口，让 QEMU 可以在 Windows 上使用。

channel-file.c 的 `qio_channel_file_new_fd` 存在多个调用者

- `qio_task` 主要被 socket websocket tls 使用的
    - `qio_task_run_in_thread` 使用线程来封装，简单的使用两个。

### notify
- `notifier_list_add` ：将 Notifier 加入到 list 中
- `notifier_list_notify` ：让这些 Notifier 都开始执行自己的 hook

## 文件的分析

### migration.c
- `migrate_params_apply`
- `migrate_params_test_apply`
- `qmp_query_migrate_parameters`
- `migrate_params_check`

- [ ] 通过 params 分析一共支持的功能

- [ ] `migration_state_notifiers` 是如何工作的?
    - 只有唯一的 `virtio_net_device_realize` 才会使用。

- [ ] `MIGRATION_CAPABILITY_XBZRLE`
- [ ] `MIGRATION_CAPABILITY_RDMA_PIN_ALL`
- [ ] `MIGRATION_CAPABILITY_AUTO_CONVERGE`
- [ ] `MIGRATION_CAPABILITY_ZERO_BLOCKS`
- [ ] `MIGRATION_CAPABILITY_COMPRESS`
- [ ] `MIGRATION_CAPABILITY_EVENTS`
- [ ] `MIGRATION_CAPABILITY_X_COLO`
- [ ] `MIGRATION_CAPABILITY_RELEASE_RAM`
- [ ] `MIGRATION_CAPABILITY_BLOCK`
- [ ] `MIGRATION_CAPABILITY_RETURN_PATH`
- [ ] `MIGRATION_CAPABILITY_PAUSE_BEFORE_SWITCHOVER`
- [ ] `MIGRATION_CAPABILITY_MULTIFD`
- [ ] `MIGRATION_CAPABILITY_DIRTY_BITMAPS`
- [ ] `MIGRATION_CAPABILITY_POSTCOPY_BLOCKTIME`
- [ ] `MIGRATION_CAPABILITY_POSTCOPY_RAM`
- [ ] `MIGRATION_CAPABILITY_LATE_BLOCK_ACTIVATE`
- [ ] `MIGRATION_CAPABILITY_X_IGNORE_SHARED`
- [ ] `MIGRATION_CAPABILITY_VALIDATE_UUID`
- [ ] `MIGRATION_CAPABILITY_BACKGROUND_SNAPSHOT`
- [ ] `MIGRATION_CAPABILITY_ZERO_COPY_SEND`
- [ ] `MIGRATION_CAPABILITY__MAX`

- [ ] 每一个都分析一下吧。

## qemu-file.c
> 是不是对于 file 存在什么误解

- 和 qio 是如何配合起来的?

- [ ] 这里的 file 可以指的是的远程的文件吗？

- [ ] 为什么需要考虑到字节序？
- [ ] `rate_limit`
- [ ] 和 channel 的关系是什么?


## dirtyrate.c

## snapshot

## manual: https://www.qemu.org/docs/master/devel/migration.html

## message 机制
- `migrate_send_rp_message`

难道 `to_src_file` 是通信的 channel 吗?
```c
    qemu_put_be16(mis->to_src_file, (unsigned int)message_type);
    qemu_put_be16(mis->to_src_file, len);
    qemu_put_buffer(mis->to_src_file, data, len);
    qemu_fflush(mis->to_src_file);
```

- `migrate_send_rp_req_pages`
    - [ ] `migrate_send_rp_message_req_pages` : 这个应该就是实现 postcopy 的方法了

RP: Return Pass

```c
/* Messages sent on the return path from destination to source */
enum mig_rp_message_type {
    MIG_RP_MSG_INVALID = 0,  /* Must be 0 */
    MIG_RP_MSG_SHUT,         /* sibling will not send any more RP messages */
    MIG_RP_MSG_PONG,         /* Response to a PING; data (seq: be32 ) */

    MIG_RP_MSG_REQ_PAGES_ID, /* data (start: be64, len: be32, id: string) */
    MIG_RP_MSG_REQ_PAGES,    /* data (start: be64, len: be32) */
    MIG_RP_MSG_RECV_BITMAP,  /* send recved_bitmap back to source */
    MIG_RP_MSG_RESUME_ACK,   /* tell source that we are ready to resume */

    MIG_RP_MSG_MAX
};
```
- [ ] 每个消息都分析一下吧!

- `MIG_RP_MSG_RECV_BITMAP`
    - 仅仅使用在 `migrate_send_rp_recv_bitmap` 中


## kvm
获取一次 memory 的内容：
- `ram_save_pending` ：每次进行一次 iteration 的时候处理一次，调用一次
    -  `migration_bitmap_sync_precopy`
        - `migration_bitmap_sync`
            - `ramblock_sync_dirty_bitmap`
                - `memory_global_dirty_log_sync` ：调用到 memory listener 中。
                - `cpu_physical_memory_sync_dirty_bitmap`
