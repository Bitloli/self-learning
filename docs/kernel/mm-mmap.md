## `vm_area_struct::vm_operations_struct` 结构体的作用

mmap 映射的一个 fd 之后，在该 vma 上操作的行为取决于 fd 的来源:

1. 匿名映射不关联 fd，所以没有  `vm_operations_struct`
```c
static inline bool vma_is_anonymous(struct vm_area_struct *vma)
{
	return !vma->vm_ops;
}
```

2. socket 的 mmap 是没有含义的
```c
static const struct vm_operations_struct tcp_vm_ops = {
};
```

3. 以 hugetlb_vm_ops 为例
```c
/*
 * When a new function is introduced to vm_operations_struct and added
 * to hugetlb_vm_ops, please consider adding the function to shm_vm_ops.
 * This is because under System V memory model, mappings created via
 * shmget/shmat with "huge page" specified are backed by hugetlbfs files,
 * their original vm_ops are overwritten with shm_vm_ops.
 */
const struct vm_operations_struct hugetlb_vm_ops = {
	.fault = hugetlb_vm_op_fault,
	.open = hugetlb_vm_op_open,
	.close = hugetlb_vm_op_close,
	.may_split = hugetlb_vm_op_split,
	.pagesize = hugetlb_vm_op_pagesize,
};
```

- gcc
