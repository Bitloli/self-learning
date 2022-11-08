# migration

- Documentation/vm/page_migration.rst

- https://man7.org/linux/man-pages/man2/migrate_pages.2.html

- [ ] 搜索一下 migration ，还是存在很多类似的积累的

## 测试工具
> migratepages pid from-nodes to-nodes
>
> https://man7.org/linux/man-pages/man8/migratepages.8.html

## 两个 syscall 对比 migrate_pages move_pages
- migrate_pages : 在 mempolicy.c 中
- move_pages : 在 migrate.c 中 ，只是粒度更加细

使用 migrate pages 来计算得到的:
```txt
#0  migrate_pages (from=from@entry=0xffffc90001a8be08, get_new_page=0xffffffff813315c0 <alloc_migration_target>, put_new_page=put_new_page@entry=0x0 <fixed_percpu_data>, private=private@entry=18446683600597859864, mode=mode@entry=MIGRATE_SYNC, reason=reason@entry=3, ret_succeeded=0x0 <fixed_percpu_data>) at mm/migrate.c:1417
#1  0xffffffff8131e445 in migrate_to_node (mm=mm@entry=0xffff8881620a1100, source=source@entry=0, dest=dest@entry=1, flags=flags@entry=4) at mm/mempolicy.c:1087
#2  0xffffffff8131f554 in do_migrate_pages (mm=mm@entry=0xffff8881620a1100, from=from@entry=0xffffc90001a8bf00, to=to@entry=0xffffc90001a8bf08, flags=4) at mm/mempolicy.c:1186
#3  0xffffffff8131f894 in kernel_migrate_pages (pid=<optimized out>, maxnode=<optimized out>, old_nodes=<optimized out>, new_nodes=<optimized out>) at mm/mempolicy.c:1663
#4  0xffffffff8131f934 in __do_sys_migrate_pages (new_nodes=<optimized out>, old_nodes=<optimized out>, maxnode=<optimized out>, pid=<optimized out>) at mm/mempolicy.c:1682
#5  __se_sys_migrate_pages (new_nodes=<optimized out>, old_nodes=<optimized out>, maxnode=<optimized out>, pid=<optimized out>) at mm/mempolicy.c:1678
#6  __x64_sys_migrate_pages (regs=<optimized out>) at mm/mempolicy.c:1678
#7  0xffffffff81fa4bcb in do_syscall_x64 (nr=<optimized out>, regs=0xffffc90001a8bf58) at arch/x86/entry/common.c:50
#8  do_syscall_64 (regs=0xffffc90001a8bf58, nr=<optimized out>) at arch/x86/entry/common.c:80
#9  0xffffffff8200009b in entry_SYSCALL_64 () at arch/x86/entry/entry_64.S:12
```

## 记录一下 syscall 相关的内容

```txt
#0  migrate_pages (from=from@entry=0xffffc9000179fd88, get_new_page=get_new_page@entry=0xffffffff81331550 <alloc_misplaced_dst_page>, put_new_page=put_new_page@entry=0x0 <fixed_percpu_data>, private=private@entry=1, mode=mode@entry=MIGRATE_ASYNC, reason=reason@entry=5, ret_succeeded=0xffffc9000179fd84) at mm/migrate.c:1417
#1  0xffffffff81334631 in migrate_misplaced_page (page=page@entry=0xffffea0005a3f440, vma=vma@entry=0xffff88816549fbe0, node=node@entry=1) at mm/migrate.c:2193
#2  0xffffffff812dcf5a in do_numa_page (vmf=0xffffc9000179fdf8) at mm/memory.c:4783
#3  handle_pte_fault (vmf=0xffffc9000179fdf8) at mm/memory.c:4962
#4  __handle_mm_fault (vma=vma@entry=0xffff88816549fbe0, address=address@entry=140728201447760, flags=flags@entry=596) at mm/memory.c:5097
#5  0xffffffff812dd620 in handle_mm_fault (vma=0xffff88816549fbe0, address=address@entry=140728201447760, flags=flags@entry=596, regs=regs@entry=0xffffc9000179ff58) at mm/memory.c:5218
#6  0xffffffff810f3ca3 in do_user_addr_fault (regs=regs@entry=0xffffc9000179ff58, error_code=error_code@entry=4, address=address@entry=140728201447760) at arch/x86/mm/fault.c:1428
#7  0xffffffff81fa8e02 in handle_page_fault (address=140728201447760, error_code=4, regs=0xffffc9000179ff58) at arch/x86/mm/fault.c:1519
#8  exc_page_fault (regs=0xffffc9000179ff58, error_code=4) at arch/x86/mm/fault.c:1575
#9  0xffffffff82000b62 in asm_exc_page_fault () at ./arch/x86/include/asm/idtentry.h:570
```
