# aio

## 基本使用
- https://github.com/littledan/linux-aio

## aio 可以替代 epoll
https://blog.cloudflare.com/io_submit-the-epoll-alternative-youve-never-heard-about/

## 源码分析
- https://zhuanlan.zhihu.com/p/368913613


## 问题
- [ ] async 体现在什么地方?
- [ ] 为什么不能使用 page cache 啊 ?

- aio_write 直接调用 call_write_iter ，这不是就结束了吗?

## 似乎的确不会拷贝
- 那么 write 的拷贝在什么位置?

direct=1 非常重要

- https://github.com/axboe/fio/issues/512

- ext4_file_write_iter
  - ext4_dio_write_iter
    - iomap_dio_rw
      - `__iomap_dio_rw`
        - blk_finish_plug : 应该是在这个地方提交的，但是没有绝对的证据，因为 iomap 看不懂
  - ext4_buffered_write_iter
    - generic_perform_write ：提交
    - generic_write_sync ： 同步

![](./img/fio-direct.svg)

![](./img/fio-no-direct.svg)

## 通过这个补充一下 iomap 的知识吧

- https://zhuanlan.zhihu.com/p/545906763
