# shmem
- [ ] 为什么实现的这么复杂
1. what's the relation with ipc/shm.c
    1. shm.c rely on shmem.c to create files and mmap on it, 这是真的吗?
2. CONFIG_TMPFS 没有了，如果提供给 shm 使用

## shmem_inode_operations 和 shmem_dir_inode_operations 是什么关系

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
因为 tmpfs 的 inode 信息都是不能写回的，所以必然需要

## [ ] shmem_is_huge 是如何使用上的

## KeyNote

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

## [ ] swap 机制到底如何勾连起来的
## [ ] 是如何利用 shmem 实现 tmpfs 的
## [ ] shmem_unuse 机制

## doc & ref

```Makefile
config SHMEM
	bool "Use full shmem filesystem" if EXPERT
	default y
	depends on MMU
	help
	  The shmem is an internal filesystem used to manage shared memory.
	  It is backed by swap and manages resource limits. It is also exported
	  to userspace as tmpfs if TMPFS is enabled. Disabling this
	  option replaces shmem and tmpfs with the much simpler ramfs code,
	  which may be appropriate on small systems without swap.
```
1. tmpfs
2. backed by swap

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
    3. in  generic_perform_write, between shmem_write_begin and shmem_write_end, **iov_iter_copy_from_user_atomic** should be mentioned !  @todo

```c
static int
shmem_write_end(struct file *file, struct address_space *mapping,
			loff_t pos, unsigned len, unsigned copied,
			struct page *page, void *fsdata)
{
	struct inode *inode = mapping->host;

	if (pos + copied > inode->i_size)
		i_size_write(inode, pos + copied);

	if (!PageUptodate(page)) { // if page is uptodate, there is nothing to do, reasonaly !
		struct page *head = compound_head(page);
		if (PageTransCompound(page)) {
			int i;

			for (i = 0; i < HPAGE_PMD_NR; i++) {
				if (head + i == page)
					continue;
				clear_highpage(head + i);
				flush_dcache_page(head + i);
			}
		}
		if (copied < PAGE_SIZE) {
			unsigned from = pos & (PAGE_SIZE - 1);
			zero_user_segments(page, 0, from,
					from + copied, PAGE_SIZE);
		}
		SetPageUptodate(head);
	}
	set_page_dirty(page);
	unlock_page(page);
	put_page(page);

	return copied;
}
```
具体的读写并不是在此处
1. shmem_write_begin 检查 flag
2. shmem_write_end
    1. set_page_dirty
    2. put_page @todo 似乎是 swap.c 中间修改的 page 状态，和 lruvec 有关的


## struct file_operations shmem_file_operations
1. shmem_mmap : mmap_region => call_mmap => shmem_mmap, nothing special, assign shmem_vm_ops
2. shmem_get_unmapped_area : @todo I don't know why find unmapped area in the virtual address space is related to specific file system
    1. After skim the implementation of shmem_get_unmapped_area, `current->mm->get_unmapped_area` @todo

```c
static const struct file_operations shmem_file_operations = {
	.mmap		= shmem_mmap, // 万万没有想到，file_operations 而不是 vm_operations_struct 中间会有 mmap
	.get_unmapped_area = shmem_get_unmapped_area,
#ifdef CONFIG_TMPFS
	.llseek		= shmem_file_llseek,
	.read_iter	= shmem_file_read_iter,
	.write_iter	= generic_file_write_iter,
	.fsync		= noop_fsync,  // in-memory 不需要 fsync
	.splice_read	= generic_file_splice_read, // todo 请问 splice_read 和 read_iter 的关系是什么 ? 请参考 splice 似乎是可以管理
	.splice_write	= iter_file_splice_write,
	.fallocate	= shmem_fallocate,
#endif
};
```

```c
unsigned long shmem_get_unmapped_area(struct file *file, // todo 并不知道其作用是什么 ?
				      unsigned long uaddr, unsigned long len,
				      unsigned long pgoff, unsigned long flags)
	get_area = current->mm->get_unmapped_area; // 实际上的工作被 mm_struct 的 get_unmapped_area


static loff_t shmem_file_llseek(struct file *file, loff_t offset, int whence) // todo 取决于 whence 调用下面两个函数
    1. loff_t generic_file_llseek_size(struct file *file, loff_t offset, int whence, loff_t maxsize, loff_t eof)
    2. shmem_seek_hole_data : whence != SEEK_DATA && whence != SEEK_HOLE // todo 感觉可以 man 到 SEEK_HOLE 和 SEEK_DATA
```

## struct inode_operations shmem_special_inode_operations
```c
static const struct inode_operations shmem_special_inode_operations = { // todo 为什么 shmem 可以和 special node 关联起来
#ifdef CONFIG_TMPFS_XATTR
	.listxattr	= shmem_listxattr,
#endif
#ifdef CONFIG_TMPFS_POSIX_ACL
	.setattr	= shmem_setattr,
	.set_acl	= simple_set_acl,
#endif
};
```

## struct super_operations shmem_ops
```c
static const struct super_operations shmem_ops = { // todo
	.alloc_inode	= shmem_alloc_inode,
	.destroy_inode	= shmem_destroy_inode,
#ifdef CONFIG_TMPFS
	.statfs		= shmem_statfs,
	.remount_fs	= shmem_remount_fs,
	.show_options	= shmem_show_options,
#endif
	.evict_inode	= shmem_evict_inode,
	.drop_inode	= generic_delete_inode,
	.put_super	= shmem_put_super,
#ifdef CONFIG_TRANSPARENT_HUGE_PAGECACHE
	.nr_cached_objects	= shmem_unused_huge_count,
	.free_cached_objects	= shmem_unused_huge_scan,
#endif
};
```

## struct vm_operations_struct shmem_vm_ops

```c
static const struct vm_operations_struct shmem_vm_ops = {
	.fault		= shmem_fault,
	.map_pages	= filemap_map_pages,
#ifdef CONFIG_NUMA
	.set_policy     = shmem_set_policy,
	.get_policy     = shmem_get_policy,
#endif
};
```

## tmpfs
```c
static struct dentry *shmem_mount(struct file_system_type *fs_type,
	int flags, const char *dev_name, void *data)
{
	return mount_nodev(fs_type, flags, data, shmem_fill_super);
}

static struct file_system_type shmem_fs_type = { // 只有 tmpfs
	.owner		= THIS_MODULE,
	.name		= "tmpfs",
	.mount		= shmem_mount,
	.kill_sb	= kill_litter_super,
	.fs_flags	= FS_USERNS_MOUNT,
};
```

## swap
```c
/*
 * Search through swapped inodes to find and replace swap by page.
 */
int shmem_unuse(swp_entry_t swap, struct page *page) // 居然被 swapfile try_to_unuse 唯一调用
// 充满了各种蛇皮 cgroup 相关的检查

```

## shmem_getpage
1. shmem_fault is a simple warpper of shmem_getpage_gfp

```c
int shmem_getpage(struct inode *inode, pgoff_t index, // 几乎所有的函数的入口
		struct page **pagep, enum sgp_type sgp)
{
	return shmem_getpage_gfp(inode, index, pagep, sgp,
		mapping_gfp_mask(inode->i_mapping), NULL, NULL, NULL);
}

/*
 * shmem_getpage_gfp - find page in cache, or get from swap, or allocate
 *
 * If we allocate a new one we do not mark it dirty. That's up to the
 * vm. If we swap it in we mark it dirty since we also free the swap
 * entry since a page cannot live in both the swap and page cache.
 *
 * fault_mm and fault_type are only supplied by shmem_fault:
 * otherwise they are NULL.
 */
static int shmem_getpage_gfp(struct inode *inode, pgoff_t index,
	struct page **pagep, enum sgp_type sgp, gfp_t gfp,
	struct vm_area_struct *vma, struct vm_fault *vmf,
			vm_fault_t *fault_type)

```


## shmem_get_inode : alloc and init inode, used by shmem_mknod and sheme_create

```c
static struct inode *shmem_get_inode(struct super_block *sb, const struct inode *dir,
				     umode_t mode, dev_t dev, unsigned long flags)
{
	struct inode *inode;
	struct shmem_inode_info *info;
	struct shmem_sb_info *sbinfo = SHMEM_SB(sb);

	if (shmem_reserve_inode(sb))
		return NULL;

	inode = new_inode(sb);// crate and init inode, shmem_alloc_inode is used to alloc shmem_inode_info instead !
	if (inode) {
		inode->i_ino = get_next_ino();
		inode_init_owner(inode, dir, mode); // uid gid
		inode->i_blocks = 0;
		inode->i_atime = inode->i_mtime = inode->i_ctime = current_time(inode);
		inode->i_generation = prandom_u32();
		info = SHMEM_I(inode);
		memset(info, 0, (char *)inode - (char *)info);
		spin_lock_init(&info->lock);
		atomic_set(&info->stop_eviction, 0);
		info->seals = F_SEAL_SEAL; // todo
		info->flags = flags & VM_NORESERVE;
		INIT_LIST_HEAD(&info->shrinklist);
		INIT_LIST_HEAD(&info->swaplist);
		simple_xattrs_init(&info->xattrs);
		cache_no_acl(inode);

		switch (mode & S_IFMT) { // man stat(2)  S_IFMT is file type mask.
		default:
			inode->i_op = &shmem_special_inode_operations;
			init_special_inode(inode, mode, dev);
			break;
		case S_IFREG:
			inode->i_mapping->a_ops = &shmem_aops;
			inode->i_op = &shmem_inode_operations;
			inode->i_fop = &shmem_file_operations;
			mpol_shared_policy_init(&info->policy,
						 shmem_get_sbmpol(sbinfo));
			break;
		case S_IFDIR:
			inc_nlink(inode);
			/* Some things misbehave if size == 0 on a directory */
			inode->i_size = 2 * BOGO_DIRENT_SIZE;
			inode->i_op = &shmem_dir_inode_operations;
			inode->i_fop = &simple_dir_operations;
			break;
		case S_IFLNK:
			/*
			 * Must not load anything in the rbtree,
			 * mpol_free_shared_policy will not be called.
			 */
			mpol_shared_policy_init(&info->policy, NULL);
			break;
		}

		lockdep_annotate_inode_mutex_key(inode);
	} else
		shmem_free_inode(sb);
	return inode;
}
```

## shmem_rmdir : shmem_unlink drop_nlink
1. drop_nlink : @todo really wired

```c
static int shmem_rmdir(struct inode *dir, struct dentry *dentry)
{
	if (!simple_empty(dentry)) // libfs is everywhere !
		return -ENOTEMPTY;

	drop_nlink(d_inode(dentry));
	drop_nlink(dir); // todo where drop parent link
	return shmem_unlink(dir, dentry);
}

static int shmem_unlink(struct inode *dir, struct dentry *dentry)
{
	struct inode *inode = d_inode(dentry);

	if (inode->i_nlink > 1 && !S_ISDIR(inode->i_mode))
		shmem_free_inode(inode->i_sb);

	dir->i_size -= BOGO_DIRENT_SIZE;
	inode->i_ctime = dir->i_ctime = dir->i_mtime = current_time(inode);
	drop_nlink(inode);
	dput(dentry);	/* Undo the count from "create" - this does all the work */
	return 0;
}
```


## shmem_unuse : 意识到这个东西从来不简单啊
```c
/*
 * Read all the shared memory data that resides in the swap
 * device 'type' back into memory, so the swap device can be
 * unused.
 */
int shmem_unuse(unsigned int type, bool frontswap,
		unsigned long *fs_pages_to_unuse)
{
	struct shmem_inode_info *info, *next;
	int error = 0;

	if (list_empty(&shmem_swaplist))
		return 0;

	mutex_lock(&shmem_swaplist_mutex);
	list_for_each_entry_safe(info, next, &shmem_swaplist, swaplist) {
		if (!info->swapped) {
			list_del_init(&info->swaplist);
			continue;
		}
		/*
		 * Drop the swaplist mutex while searching the inode for swap;
		 * but before doing so, make sure shmem_evict_inode() will not
		 * remove placeholder inode from swaplist, nor let it be freed
		 * (igrab() would protect from unlink, but not from unmount).
		 */
		atomic_inc(&info->stop_eviction);
		mutex_unlock(&shmem_swaplist_mutex);

		error = shmem_unuse_inode(&info->vfs_inode, type, frontswap,
					  fs_pages_to_unuse);
		cond_resched();

		mutex_lock(&shmem_swaplist_mutex);
		next = list_next_entry(info, swaplist);
		if (!info->swapped)
			list_del_init(&info->swaplist);
		if (atomic_dec_and_test(&info->stop_eviction))
			wake_up_var(&info->stop_eviction);
		if (error)
			break;
	}
	mutex_unlock(&shmem_swaplist_mutex);

	return error;
}
```

## shmget: syscall
1. call graph of `shmget`
    1. newseg
    2. shmem_kernel_file_setup
    3. `__shmem_file_setup`
        1. shmem_get_inode
        2. alloc_file_pseudo

2. when the file is mapped into the virtual memory of user virtual address space ?
    1. do_shmat => do_mmap_pgoff
    2. shmget : it just setup the file

```c
/**
 * shmem_kernel_file_setup - get an unlinked file living in tmpfs which must be
 * 	kernel internal.  There will be NO LSM permission checks against the
 * 	underlying inode.  So users of this interface must do LSM checks at a
 *	higher layer.  The users are the big_key and shm implementations.  LSM
 *	checks are provided at the key or shm level rather than the inode.
 * @name: name for dentry (to be seen in /proc/<pid>/maps
 * @size: size to be set for the file
 * @flags: VM_NORESERVE suppresses pre-accounting of the entire object size
 */
struct file *shmem_kernel_file_setup(const char *name, loff_t size, unsigned long flags)
{
	return __shmem_file_setup(shm_mnt, name, size, flags, S_PRIVATE);
}
```
1. @name is interesting, here is the exmaple !
