- https://stackoverflow.com/questions/31055194/how-can-i-configure-a-systemd-service-to-restart-periodically
- https://unix.stackexchange.com/questions/20399/view-stdout-stderr-of-systemd-service
  - sudo journalctl -u [unitfile]


- https://blog.k8s.li/systemd.html
    - [ ] 后面的链接

- [ ] 为什么内核参数可以管理 systemd

systemctl list-units --type=service

## [systemd](https://medium.com/@benmorel/creating-a-linux-service-with-systemd-611b5c8b91d6)
将长时间运行的程序转化为systemd

- https://systemd.io/ 了解一下其中的内容

## 各种 init
- https://github.com/troglobit/finit : Finit is a simple alternative to SysV init and systemd.
- https://github.com/krallin/tini : A tiny but valid init for containers

- [ ] 然后更新一下一个 nixos systemd 的内容吧
    - systemd 有 timer 的 service，也许可以用起来实现喝水的

## 原理上的疑惑
- [ ] 如何将程序转换为 deamon
- [ ] D-bus 的工作原理
- [ ] 如何和 cgroup 交互
- [ ] /var 下的 journal 到底是谁生成的，是 systemd 管理的吗?

## ruanyf 的最基本的教程基本是够的
https://www.ruanyifeng.com/blog/2016/03/systemd-tutorial-commands.html
