# kernel 中没有看懂的 commit

- 415d832497098030241605c52ea83d4e2cfa7879 : 因为 out-of-order 修复 test_and_set_bit
- spi 是啥？
- kmap_atomic 转换为 kmap_local_page
- 4ba4f41942745f1906c06868a4acc6c926463f53: kvm_create_vm_debugfs 是做啥的
- d3b38596875dbc709b4e721a5873f4663d8a9ea : blk mq 的一个 bug 修复
- abfcf55d8b07a990589301bc64d82a5d26680956 : acl 相关的
- 95607ad99b5a4e3e69e025621165753718a6ea98 : 一系列 memory 模块的修复patch
- 41a55567b9e31cb852670684404654ec4fd0d8d6 : CONFIG enable 是什么意思
- c40e8341e3b3bb27e3a65b06b5b454626234c4f0 : 一系列的 schduler 的修复