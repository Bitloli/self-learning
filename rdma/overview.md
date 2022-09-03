# RDMA

## 文摘
- https://gwzlchn.github.io/202207/rdma-stack-01/

## https://zhuanlan.zhihu.com/p/138874738

> RDMA本身指的是一种技术，具体协议层面，包含Infiniband（IB），RDMA over Converged Ethernet（RoCE）和internet Wide Area RDMA Protocol（iWARP）。三种协议都符合RDMA标准，使用相同的上层接口，在不同层次上有一些差别。

- https://github.com/linux-rdma/
    - 一个用户态的库
    - 一个测试工具

内核主要的代码: drivers/infiniband/

这是一个其所在的专栏: https://www.zhihu.com/column/c_1231181516811390976

## 资源
- https://github.com/zrlio/softiwarp

## rdma

- `rdma_start_outgoing_migration` : 也是 socket fd 等方法中的一种

- 用于传递什么?
    - 物理内存

- 参考 qemu/docs/rdma.txt 来理解 rdma.c 中的内容。

## 为什么需要在其中需要重新增加一个 QIOChannel
- [ ] QIOChannel 是在给 QEMU 使用的吗?

- `rdma_start_incoming_migration`
    - `qemu_set_fd_handler` 设置 handler 为 `rdma_accept_incoming_migration`
        - `rdma_accept_incoming_migration`
            - `qemu_rdma_accept` ：TODO 全部都是 RDMA 的相关领域的内容
            - `qemu_fopen_rdma` ：返回的 QEMUFile 将会持有这个 QIOChannelRDMA
                - 创建 `QIOChannelRDMA`
                - `qemu_file_new_output`
                - 设置 `QEMUFileHooks`
            - `migration_fd_process_incoming` : 这是常规流程

## SMC-R
- https://help.aliyun.com/document_detail/327118.html
- 内核中 net/smc 的位置
