# `vm_operations_struct` 结构体是做啥的


## vma_is_anonymous

1. 最关键的区别
```c
static inline bool vma_is_anonymous(struct vm_area_struct *vma)
{
	return !vma->vm_ops;
}
```

1. vm_operations_struct 的存在 : 一共存在哪几种 vma_area, 居然是各种驱动会给 `vm_operations_struct->open` 赋值
    1. vm_operations_struct 各种成员的总用是什么 ?
