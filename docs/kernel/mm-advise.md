# madvise

madvise 告知内核该范围的内存如何访问
fadvise 告知内核该范围的文件如何访问，内核从而可以调节 readahead 的参数，或者清理掉该范围的 page cache

fadvise 很简单，阅读
1. Man fadvise(2)
2. fadvise.c 的源代码
