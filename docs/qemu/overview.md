# QEMU 还有的挑战
- [ ] QEMU 的 blocking layer 如此复杂，是不是 zbs 将这些内容实际上 by pass 了
- [ ] 为什么 QEMU 中的 block 感觉比网络复杂很多的。
- [ ] 顶层的 job.c 的内容是什么?

阅读 QIOChannel 的时候发现:
- [ ] AioContext 是什么，和 qemu/threads.md 重新联合起来分析一下。
- [ ] coroutine 的作用?
    - 我想要核实一下，当使用 coroutine 的时候，性能相对于 poll 模式其实就是已经不行了。
- [ ] `g_autoptr` 是什么? 例如在 `fd_chr_add_watch` 中看到的。
- [ ] docs/devel/qapi-code-gen.txt 和 qmp 如何工作的，是如何生成的。

## qmp

- [ ] `qmp_block_commit` 的唯一调用者是如何被生成的。
- [ ] QEMU 这种可以接受命令行的参数吗?
```txt
-blockdev '{
"driver": "file",
"node-name": "protocol-node",
"filename": "foo.qcow2"
}'
```
- [ ] `OBJECT_DECLARE_SIMPLE_TYPE` 是什么意思，和类似的 macro 有什么区别
