# 装机

本科的电脑，是联想 Thinkpad，刚开始购买的时候只有 4G 内存，128G 固态，续航大约两小时，分辨率非常垃圾，等到 2018 年的时候，重新购买了电池和内存，从此联想一生黑。

研究生夏令营之后，重新购买了一个小米笔记本，虽然风扇有点问题，然后去修过一次，此外体验还是不错的。

最近决定组装一个机器在公司，原因有三:
- 闲钱: 与其省吃俭用买房被政府收割，还不如对自己好点；
- 习惯: 我之前一直是使用 Linux 和 Windows 的，但是公司给我发了一个 M2 Mac，非常不习惯；例如 control option command 键。
- 工作: 使用 Mac 之后，需要连远程服务工作，感觉不是很得劲儿。一是，存在延迟。二是，我现在在任何时候都必须打开两个 tmux，一个在本地的 Mac 的，
一个在远程的虚拟机中的。内核的代码在 Mac 上无法编译，所以必须使用远程。但是在远程上，输入法在 vim 中**很难**[^1]无法自动切换了。

当然这里有一个非常重要的前提，是我的公司允许使用自己的电脑。

我的日常负载:
- vim 编辑；
  - clangd 内核代码；
- 浏览器；
- 编译内核。

除此之外，因为我自己的执念，我尽量采购国产的配件。

所以，我的配置的有如下特点:
- 没有显卡。
- 大内存。
- CPU 核心多。

最终结果如下，除了 CPU 很贵，其他的都是将就着用的状态:
![](./m.jpeg)

前期是我老板帮忙的搞定了散热和风扇，搞了一晚上，还是没有搞定，到了第二天，白天上班，晚上继续，我老板有事先走了，
只能硬着头皮上，才发现，其实安装也没有难，只是到了最后，才发现 CPU 风扇电源插错位置了，没办法，只好把好不容易安装好的
散热和风扇拆掉，才将 CPU 风扇暴露出来。

组后组装大约用了 5 个小时，是的，非常离谱。但是组装完成之后，还是很有成就感的，如果你也喜欢 DIY，我认为没有必要花钱让别人来装。

然后，我装上 Windows，安装过程中，发现 Windows 没有预装无线网卡的驱动，让我以为我的 wifi 接收器有问题。
随后，装上 Ubuntu，还是曾经的味道，当时天色已晚，我决定第二天过来把环境切换过来，晚上的时候还在到底要不要安装
Nixos ，如何实现各个平台数据同步，在机器里面如何管理虚拟机，如何在虚拟机中构建 k8s 集群，如何在虚拟机中调试虚拟机，
观察 Linux 调度器如何应对现在大小核架构，如何管理现在的存储，如何使用使用额外的固态测试 spdk，好吧，可以做的事情太多了。

结果，第二天，我的小区被封了。

## 参考
- https://cerr.cc/post/zkv%E7%9A%84%E6%94%92%E6%9C%BA%E7%AE%80%E5%8F%B2/
- https://nanoreview.net/en/cpu-list/cinebench-scores

[^1]: https://github.com/ZSaberLv0/ZFVimIM

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
