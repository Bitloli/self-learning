# shmem

## KeyNote
- what's the relation with ipc/shm.c
    - shm.c rely on shmem.c to create files and mmap on it
- `shmem_fs_type` may mount multiple times
```plain
tmpfs           7.8G  103M  7.7G   2% /dev/shm
tmpfs           7.8G     0  7.8G   0% /sys/fs/cgroup
tmpfs           7.8G  4.3M  7.8G   1% /tmp
```
- /tmp 和 /dev/shm 的区别:
  - /tmp 是 FHS 定义的，实际上，很多 distribution 中，/tmp 和 /dev/shm 是同一个 mount 类型，应该是没有区别的。
  - https://superuser.com/questions/45342/when-should-i-use-dev-shm-and-when-should-i-use-tmp
- posix 的 shm_open 是通过 /dev/shm 实现的
    - it seems implemented in the glibc : https://code.woboq.org/userspace/glibc/sysdeps/posix/shm_open.c.html
- shmem_unuse 当 swapoff 的时候，将 tmpfs 中的内容放回去

## [ ] 验证一下这个说法

- tmpfs 是可以限制大小，而 ramfs 不会
  - https://askubuntu.com/questions/296038/what-is-the-difference-between-tmpfs-and-ramfs

## inode operations

shmem_inode_operations 应该是给 file 使用的，所以创建文件之类的操作都是没有的:
```txt
#0  shmem_create (mnt_userns=0xffffffff82a61920 <init_user_ns>, dir=0xffff8881212a8390, dentry=0xffff888122a2c780, mode=33206, excl=false) at mm/shmem.c:2952
#1  0xffffffff8135a878 in lookup_open (op=0xffffc900017bbedc, op=0xffffc900017bbedc, got_write=true, file=0xffff8881262d0300, nd=0xffffc900017bbdc0) at fs/namei.c:3413
#2  open_last_lookups (op=0xffffc900017bbedc, file=0xffff8881262d0300, nd=0xffffc900017bbdc0) at fs/namei.c:3481
#3  path_openat (nd=nd@entry=0xffffc900017bbdc0, op=op@entry=0xffffc900017bbedc, flags=flags@entry=65) at fs/namei.c:3688
#4  0xffffffff8135b9ed in do_filp_open (dfd=dfd@entry=-100, pathname=pathname@entry=0xffff888100f3c000, op=op@entry=0xffffc900017bbedc) at fs/namei.c:3718
#5  0xffffffff813455b5 in do_sys_openat2 (dfd=-100, filename=<optimized out>, how=how@entry=0xffffc900017bbf18) at fs/open.c:1311
#6  0xffffffff81345aae in do_sys_open (mode=<optimized out>, flags=<optimized out>, filename=<optimized out>, dfd=<optimized out>) at fs/open.c:1327
#7  __do_sys_openat (mode=<optimized out>, flags=<optimized out>, filename=<optimized out>, dfd=<optimized out>) at fs/open.c:1343
#8  __se_sys_openat (mode=<optimized out>, flags=<optimized out>, filename=<optimized out>, dfd=<optimized out>) at fs/open.c:1338
#9  __x64_sys_openat (regs=<optimized out>) at fs/open.c:1338
#10 0xffffffff81edbcf8 in do_syscall_x64 (nr=<optimized out>, regs=0xffffc900017bbf58) at arch/x86/entry/common.c:50
```

```txt
#0  shmem_mkdir (mnt_userns=0xffffffff82a61920 <init_user_ns>, dir=0xffff8881212a8390, dentry=0xffff888121a36000, mode=511) at mm/shmem.c:2942
#1  0xffffffff81356eec in vfs_mkdir (mnt_userns=0xffffffff82a61920 <init_user_ns>, dir=0xffff8881212a8390, dentry=dentry@entry=0xffff888121a36000, mode=<optimized out>, mode@entry=511) at fs/namei.c:4013
#2  0xffffffff8135bcf1 in do_mkdirat (dfd=dfd@entry=-100, name=0xffff88822120d000, mode=mode@entry=511) at fs/namei.c:4038
#3  0xffffffff8135bee3 in __do_sys_mkdir (mode=<optimized out>, pathname=<optimized out>) at fs/namei.c:4058
#4  __se_sys_mkdir (mode=<optimized out>, pathname=<optimized out>) at fs/namei.c:4056
#5  __x64_sys_mkdir (regs=<optimized out>) at fs/namei.c:4056
#6  0xffffffff81edbcf8 in do_syscall_x64 (nr=<optimized out>, regs=0xffffc900017cbf58) at arch/x86/entry/common.c:50
#7  do_syscall_64 (regs=0xffffc900017cbf58, nr=<optimized out>) at arch/x86/entry/common.c:80
```
因为 tmpfs 的 inode 信息都是不能写回的，所以必然需要额外的一个机制来处理 inode 的。

- shmem_get_inode : alloc and init inode, used by shmem_mknod and sheme_create

- [ ] shmem_special_inode_operations 是做啥的 ?
- [ ] shmem_get_unmapped_area : @todo I don't know why find unmapped area in the virtual address space is related to specific file system

```c
unsigned long shmem_get_unmapped_area(struct file *file, // todo 并不知道其作用是什么 ?
				      unsigned long uaddr, unsigned long len,
				      unsigned long pgoff, unsigned long flags)
	get_area = current->mm->get_unmapped_area; // 实际上的工作被 mm_struct 的 get_unmapped_area

static loff_t shmem_file_llseek(struct file *file, loff_t offset, int whence) // todo 取决于 whence 调用下面两个函数
    1. loff_t generic_file_llseek_size(struct file *file, loff_t offset, int whence, loff_t maxsize, loff_t eof)
    2. shmem_seek_hole_data : whence != SEEK_DATA && whence != SEEK_HOLE // todo 感觉可以 man 到 SEEK_HOLE 和 SEEK_DATA
```


## file operations
- shmem_file_operations::read_iter 是没有办法读取到具体的文件的，所以重写为 shmem_file_read_iter
- shmem_file_operations::write_iter 不一样，当写的时候反正总是经过 page cache 的。
- [ ] shmem_file_operations::llseek : 应该是因为 hole 的原因，所以需要在末尾添加上，

## 和 huge 的关系

只是和 transparent page 有关:

- shmem_getpage_gfp
  - shmem_alloc_hugefolio

## 如何利用 shmem 实现 tmpfs 的

需要额外支持:
- shmem_symlink_inode_operations
- shmem_short_symlink_operations
- shmem_file_operations  : 支持 read / write 操作，否则只是支持 mmap 的
- shmem_dir_inode_operations : 支持创建文件等操作

其实，主要需要构建文件的操作，如果不需要 tmpfs 的结构，那就是 shm 的行为，所有数据都在一起。

## struct address_space_operations shmem_aops

```c
static const struct address_space_operations shmem_aops = {
	.writepage	= shmem_writepage,
	.set_page_dirty	= __set_page_dirty_no_writeback,
#ifdef CONFIG_TMPFS
	.write_begin	= shmem_write_begin,
	.write_end	= shmem_write_end,
#endif
#ifdef CONFIG_MIGRATION
	.migratepage	= migrate_page, // 通用函数
#endif
	.error_remove_page = generic_error_remove_page, // 通用函数
};
```

1. shmem_writepage : used for wirte to swap cache ! In fact, the swap cache looks like regular file
2. shmem_write_begin, shmem_write_end : it work with generic_file_write_iter which is assigned to shmem_file_operations::write_iter
    1. shmem_write_begin : shmem_getpage
    2. shmem_write_end : do something clean up :
    3. in generic_perform_write, between shmem_write_begin and shmem_write_end, **iov_iter_copy_from_user_atomic** should be mentioned !  @todo

具体的读写并不是在此处
1. shmem_write_begin 检查 flag
2. shmem_write_end
    1. set_page_dirty
    2. put_page @todo 似乎是 swap.c 中间修改的 page 状态，和 lruvec 有关的

- 为什么 shmem_aops 中没有实现 read_folio
  - 的确是可以从 shmem_fault 和 shmem_file_read_iter 中将从 swap 中将内容读取回来，普通的文件系统中都是有的，需要按照自己的规则从来访问 disk，而 tmpfs 访问磁盘只是需要 swap 的，这些都让 swap 处理了

## swap

- 被挤压之后，被换出:
```txt
0  shmem_writepage (page=0xffffea0004a02fc0, wbc=0xffffc90001167a88) at mm/shmem.c:1318
#1  0xffffffff81292c04 in pageout (folio=folio@entry=0xffffea0004a02fc0, mapping=mapping@entry=0xffff8881274b4e08, plug=plug@entry=0xffffc90001167b50) at mm/vmscan.c:1265
#2  0xffffffff812936ea in shrink_page_list (page_list=page_list@entry=0xffffc90001167c28, pgdat=pgdat@entry=0xffff88813fffc000, sc=sc@entry=0xffffc90001167dd8, stat=stat@entry=0xffffc90001167cb0, ignore_references=ignore_references@entry=false) at mm/vmscan.c:1886
#3  0xffffffff81295c48 in shrink_inactive_list (lru=LRU_INACTIVE_ANON, sc=0xffffc90001167dd8, lruvec=0xffff888122315400, nr_to_scan=<optimized out>) at mm/vmscan.c:2447
#4  shrink_list (sc=0xffffc90001167dd8, lruvec=0xffff888122315400, nr_to_scan=<optimized out>, lru=LRU_INACTIVE_ANON) at mm/vmscan.c:2674
#5  shrink_lruvec (lruvec=lruvec@entry=0xffff888122315400, sc=sc@entry=0xffffc90001167dd8) at mm/vmscan.c:2991
#6  0xffffffff8129649b in shrink_node_memcgs (sc=0xffffc90001167dd8, pgdat=0xffff88813fffc000) at mm/vmscan.c:3180
#7  shrink_node (pgdat=pgdat@entry=0xffff88813fffc000, sc=sc@entry=0xffffc90001167dd8) at mm/vmscan.c:3304
#8  0xffffffff81296bd7 in kswapd_shrink_node (sc=0xffffc90001167dd8, pgdat=0xffff88813fffc000) at mm/vmscan.c:4086
#9  balance_pgdat (pgdat=pgdat@entry=0xffff88813fffc000, order=order@entry=0, highest_zoneidx=highest_zoneidx@entry=3) at mm/vmscan.c:4277
#10 0xffffffff8129718b in kswapd (p=0xffff88813fffc000) at mm/vmscan.c:4537
#11 0xffffffff81129510 in kthread (_create=0xffff888100fe5e40) at kernel/kthread.c:376
#12 0xffffffff81001a8f in ret_from_fork () at arch/x86/entry/entry_64.S:306
```

- 重新换入:
```txt
#0  shmem_swapin_folio (inode=inode@entry=0xffff8881274b4c90, index=index@entry=328, foliop=foliop@entry=0xffffc90001743cd0, sgp=sgp@entry=SGP_CACHE, gfp=gfp@entry=1051850, vma=vma@entry=0xffff888125652af0, fault_type=0xffffc90001743d3c) at mm/shmem.c:1729
#1  0xffffffff8129ca59 in shmem_getpage_gfp (inode=inode@entry=0xffff8881274b4c90, index=328, pagep=pagep@entry=0xffffc90001743e48, sgp=sgp@entry=SGP_CACHE, gfp=1051850, vma=0xffff888125652af0, vmf=0xffffc90001743df8, fault_type=0xffffc90001743d3c) at mm/shmem.c:1871
#2  0xffffffff8129cf73 in shmem_fault (vmf=0xffffc90001743df8) at mm/shmem.c:2127
#3  0xffffffff812bacaf in __do_fault (vmf=vmf@entry=0xffffc90001743df8) at mm/memory.c:4173
#4  0xffffffff812bf03b in do_read_fault (vmf=0xffffc90001743df8) at mm/memory.c:4518
#5  do_fault (vmf=vmf@entry=0xffffc90001743df8) at mm/memory.c:4647
#6  0xffffffff812c3ba0 in handle_pte_fault (vmf=0xffffc90001743df8) at mm/memory.c:4911
#7  __handle_mm_fault (vma=vma@entry=0xffff888125652af0, address=address@entry=140014504929552, flags=flags@entry=596) at mm/memory.c:5053
#8  0xffffffff812c4440 in handle_mm_fault (vma=0xffff888125652af0, address=address@entry=140014504929552, flags=flags@entry=596, regs=regs@entry=0xffffc90001743f58) at mm/memory.c:5151
#9  0xffffffff810f2983 in do_user_addr_fault (regs=regs@entry=0xffffc90001743f58, error_code=error_code@entry=4, address=address@entry=140014504929552) at arch/x86/mm/fault.c:1397
#10 0xffffffff81edffa2 in handle_page_fault (address=140014504929552, error_code=4, regs=0xffffc90001743f58) at arch/x86/mm/fault.c:1488
#11 exc_page_fault (regs=0xffffc90001743f58, error_code=4) at arch/x86/mm/fault.c:1544
#12 0xffffffff82000b62 in asm_exc_page_fault () at ./arch/x86/include/asm/idtentry.h:570
```

## 和 sysv share memory 的关系

- `__x64_sys_shmget`
    - newseg
    - shmem_kernel_file_setup
    - `__shmem_file_setup`
        - shmem_get_inode
        - alloc_file_pseudo

```txt
#0  shmem_get_inode (sb=0xffff888100058800, dir=dir@entry=0x0 <fixed_percpu_data>, mode=mode@entry=33279, dev=dev@entry=0, flags=flags@entry=0) at mm/shmem.c:156
#1  0xffffffff8129a59f in __shmem_file_setup (i_flags=512, flags=0, size=4096, name=0xffffc90001843e4b "SYSV00000000", mnt=0xffff8882000b4020) at mm/shmem.c:4162
#2  __shmem_file_setup (mnt=0xffff8882000b4020, name=0xffffc90001843e4b "SYSV00000000", size=4096, flags=0, i_flags=512) at mm/shmem.c:4147
#3  0xffffffff815a8b6a in newseg (ns=0xffffffff82bef240 <init_ipc_ns>, params=<optimized out>) at ipc/shm.c:751
#4  0xffffffff815a092d in ipcget_new (params=0xffffc90001843f20, ops=0xffffffff82474120 <shm_ops>, ids=0xffffffff82bef3f0 <init_ipc_ns+432>, ns=0xffffffff82bef240 <init_ipc_ns>) at ipc/util.c:345
#5  ipcget (ns=0xffffffff82bef240 <init_ipc_ns>, ids=0xffffffff82bef3f0 <init_ipc_ns+432>, ops=ops@entry=0xffffffff82474120 <shm_ops>, params=params@entry=0xffffc90001843f20) at ipc/util.c:677
#6  0xffffffff815a85f7 in ksys_shmget (shmflg=<optimized out>, size=<optimized out>, key=<optimized out>) at ipc/shm.c:831
#7  __do_sys_shmget (shmflg=<optimized out>, size=<optimized out>, key=<optimized out>) at ipc/shm.c:836
#8  __se_sys_shmget (shmflg=<optimized out>, size=<optimized out>, key=<optimized out>) at ipc/shm.c:834
#9  __x64_sys_shmget (regs=<optimized out>) at ipc/shm.c:834
#10 0xffffffff81edbcf8 in do_syscall_x64 (nr=<optimized out>, regs=0xffffc90001843f58) at arch/x86/entry/common.c:50
```

```txt
#0  shmem_kernel_file_setup (name=0xffffc90001c3be4b "SYSV00000000", size=4096, flags=0) at mm/shmem.c:4192
#1  0xffffffff815a8b6a in newseg (ns=0xffffffff82bef240 <init_ipc_ns>, params=<optimized out>) at ipc/shm.c:751
#2  0xffffffff815a092d in ipcget_new (params=0xffffc90001c3bf20, ops=0xffffffff82474120 <shm_ops>, ids=0xffffffff82bef3f0 <init_ipc_ns+432>, ns=0xffffffff82bef240 <init_ipc_ns>) at ipc/util.c:345
#3  ipcget (ns=0xffffffff82bef240 <init_ipc_ns>, ids=0xffffffff82bef3f0 <init_ipc_ns+432>, ops=ops@entry=0xffffffff82474120 <shm_ops>, params=params@entry=0xffffc90001c3bf20) at ipc/util.c:677
#4  0xffffffff815a85f7 in ksys_shmget (shmflg=<optimized out>, size=<optimized out>, key=<optimized out>) at ipc/shm.c:831
#5  __do_sys_shmget (shmflg=<optimized out>, size=<optimized out>, key=<optimized out>) at ipc/shm.c:836
#6  __se_sys_shmget (shmflg=<optimized out>, size=<optimized out>, key=<optimized out>) at ipc/shm.c:834
#7  __x64_sys_shmget (regs=<optimized out>) at ipc/shm.c:834
#8  0xffffffff81edbcf8 in do_syscall_x64 (nr=<optimized out>, regs=0xffffc90001c3bf58) at arch/x86/entry/common.c:50
#9  do_syscall_64 (regs=0xffffc90001c3bf58, nr=<optimized out>) at arch/x86/entry/common.c:80
#10 0xffffffff8200009b in entry_SYSCALL_64 () at arch/x86/entry/entry_64.S:120
```
