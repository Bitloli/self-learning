#!/usr/bin/env bash
mount -t hugetlbfs -o min_size=2G,nr_inodes=100 none /mnt/huge

# 如果想要制定大小，如何处理 pagesize
