# swap 模块基本分析

- mm/page-io.c : `swap_readpage` / `swap_writepage` 等，将 swap page 写入到 disk 中
- mm/swap_state.c : 维护 swap cache ，构建出来 `swap_aops`
- mm/swap_slots.c
