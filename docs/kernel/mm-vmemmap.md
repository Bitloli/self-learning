# sparse vmemmap

## 原理
物理内存不是连续的，为空洞分配 page struct 非常划不来。

- 物理内存分配: for each node 的构建的，通过 memblock 的分配器来保证 page frame 和对应的 page struct 在同一个 node 中
- 虚拟内存分配: 从 `pfn_to_page` 可以看到是从 vmemmap 开始的

## 基本执行流程
```txt
#0  vmemmap_populate (start=start@entry=18446719884453740544, end=end@entry=18446719884455837696, node=node@entry=1, altmap=altmap@entry=0x0 <fixed_percpu_data>) at arch/x86/mm/init_64.c:1612
#1  0xffffffff81fb063f in __populate_section_memmap (pfn=pfn@entry=0, nr_pages=nr_pages@entry=32768, nid=nid@entry=1, altmap=altmap@entry=0x0 <fixed_percpu_data>, pgmap=pgmap@entry=0x0 <fixed_percpu_data>) at mm/sparse-vmemmap.c:392
#2  0xffffffff83366fc1 in sparse_init_nid (nid=1, pnum_begin=pnum_begin@entry=0, pnum_end=pnum_end@entry=40, map_count=32) at mm/sparse.c:527
#3  0xffffffff833673f4 in sparse_init () at mm/sparse.c:580
#4  0xffffffff833532a0 in paging_init () at arch/x86/mm/init_64.c:816
#5  0xffffffff83342b47 in setup_arch (cmdline_p=cmdline_p@entry=0xffffffff82a03f10) at arch/x86/kernel/setup.c:1253
#6  0xffffffff83338c7d in start_kernel () at init/main.c:959
#7  0xffffffff81000145 in secondary_startup_64 () at arch/x86/kernel/head_64.S:358
#8  0x0000000000000000 in ?? ()
```

- vmemmap_populate : 处理自动选择 hugepages 的，在 arch/x86/mm/init_64.c
  - vmemmap_populate_basepages : 使用 basepage 来实现映射
  - vmemmap_populate_hugepages

hugepages 的初始化是在此之后的:
```txt
#0  hugepages_setup (s=0xffff88823fff51ea "4") at mm/hugetlb.c:4165
#1  0xffffffff833388f0 in obsolete_checksetup (line=0xffff88823fff51e0 "hugepages=4") at init/main.c:221
#2  unknown_bootoption (param=0xffff88823fff51e0 "hugepages=4", val=val@entry=0xffff88823fff51ea "4", unused=unused@entry=0xffffffff827b3bc4 "Booting kernel", arg=arg@entry=0x0 <fixed_percpu_data>) at init/main.c:541
#3  0xffffffff81131dc3 in parse_one (handle_unknown=0xffffffff83338856 <unknown_bootoption>, arg=0x0 <fixed_percpu_data>, max_level=-1, min_level=-1, num_params=748, params=0xffffffff82992e20 <__param_initcall_debug>, doing=0xffffffff827b3bc4 "Booting kernel", val=0xffff88823fff51ea "4", param=0xffff88823fff51e0 "hugepages=4") at kernel/params.c:153
#4  parse_args (doing=doing@entry=0xffffffff827b3bc4 "Booting kernel", args=0xffff88823fff51ec "hugepagesz=2M hugepages=512 systemd.unified_cgroup_hierarchy=1 ", params=0xffffffff82992e20 <__param_initcall_debug>, num=748, min_level=min_level@entry=-1, max_level=max_level@entry=-1, arg=0x0 <fixed_percpu_data>, unknown=0xffffffff83338856 <unknown_bootoption>) at kernel/params.c:188
#5  0xffffffff83338e27 in start_kernel () at init/main.c:974
#6  0xffffffff81000145 in secondary_startup_64 () at arch/x86/kernel/head_64.S:358
#7  0x0000000000000000 in ?? ()
```

## 其他问题
- vmemmap_alloc_block 中为什么会出现 slab_is_available 的判断，是因为内存的热插拔
在内核启动的时候 vmemmap_alloc_block_buf 最后调用 memblock 上

<script src="https://giscus.app/client.js"
        data-repo="martins3/martins3.github.io"
        data-repo-id="MDEwOlJlcG9zaXRvcnkyOTc4MjA0MDg="
        data-category="Show and tell"
        data-category-id="MDE4OkRpc2N1c3Npb25DYXRlZ29yeTMyMDMzNjY4"
        data-mapping="pathname"
        data-reactions-enabled="1"
        data-emit-metadata="0"
        data-theme="light"
        data-lang="zh-CN"
        crossorigin="anonymous"
        async>
</script>

本站所有文章转发 **CSDN** 将按侵权追究法律责任，其它情况随意。
