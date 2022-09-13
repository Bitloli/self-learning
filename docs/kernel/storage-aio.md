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
