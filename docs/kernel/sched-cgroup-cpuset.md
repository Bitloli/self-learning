# cpuset

## cpuset
```c
struct cpuset {
  struct cgroup_subsys_state css;
```

- [ ]https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v1/cpusets.html


> @question 如果缓存一个大文件，那么岂不是体验极差，一次又一次的调用，一个 GB 调用一百万次数。

The page cache is implemented on top of radix trees:
```c
static inline struct page *page_cache_alloc(struct address_space *x)
{
	return __page_cache_alloc(mapping_gfp_mask(x));
}

static inline struct page *page_cache_alloc_cold(struct address_space *x)
{
	return __page_cache_alloc(mapping_gfp_mask(x)|__GFP_COLD);
}

static inline struct page *page_cache_alloc_readahead(struct address_space *x)
{
	return __page_cache_alloc(mapping_gfp_mask(x) |
				  __GFP_COLD | __GFP_NORETRY | __GFP_NOWARN);
}


#ifdef CONFIG_NUMA
extern struct page *__page_cache_alloc(gfp_t gfp);
#else
static inline struct page *__page_cache_alloc(gfp_t gfp)
{
	return alloc_pages(gfp, 0);
}
#endif


#ifdef CONFIG_NUMA
struct page *__page_cache_alloc(gfp_t gfp)
{
	int n;
	struct page *page;

	if (cpuset_do_page_mem_spread()) {
		unsigned int cpuset_mems_cookie;
		do {
			cpuset_mems_cookie = read_mems_allowed_begin();
			n = cpuset_mem_spread_node();
			page = __alloc_pages_node(n, gfp, 0);
		} while (!page && read_mems_allowed_retry(cpuset_mems_cookie));

		return page;
	}
	return alloc_pages(gfp, 0);
}
EXPORT_SYMBOL(__page_cache_alloc);
#endif


static inline gfp_t mapping_gfp_mask(struct address_space * mapping)
{
	return mapping->gfp_mask;
}
```
> 如果不是 NUMA, 那么就很简单了，和普通的 alloc_pages 唯一的区别在于，mapping_gfp_mask
