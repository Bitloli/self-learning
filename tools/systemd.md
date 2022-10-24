# 我所知道 systemd 的全部

## ruanyf 的教程
https://www.ruanyifeng.com/blog/2016/03/systemd-tutorial-commands.html

## 常用命令
- 查看依赖
- sudo systemctl list-dependencies

## 查看依赖链条

- https://serverfault.com/questions/617398/is-there-a-way-to-see-the-execution-tree-of-systemd

sudo systemctl list-dependencies

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

## 不要在参数上引入多余的双引号

```sh
cat /etc/systemd/system/hugepage.service

[Unit]
Description=A simple echo

[Service]
Type=oneshot
ExecStart="/bin/echo 1000" #
TimeoutStopSec=10
KillMode=process

[Install]
WantedBy=multi-user.target
```

如果使用 pipeline 等复杂的 shell 操作，应该使用上 /bin/sh -c "cmd"

## rc.local

不要使用 rc.local [^1]

如果非要使用，记得
```sh
chmod +x /etc/rc.d/rc.local
```

## 更加深入的理解
- https://stackoverflow.com/questions/31055194/how-can-i-configure-a-systemd-service-to-restart-periodically
- https://unix.stackexchange.com/questions/20399/view-stdout-stderr-of-systemd-service
  - sudo journalctl -u [unitfile]


- https://blog.k8s.li/systemd.html
    - [ ] 后面的链接

- [ ] 为什么内核参数可以管理 systemd

systemctl list-units --type=service

- [ ] TimeoutStopSec=10 似乎没用

启动这个服务实际上会等待 10s 的:
```sh
[Unit]
Description=MountSmokeScreen

[Service]
Type=oneshot
ExecStart=/bin/sleep 10
TimeoutStopSec=1

[Install]
WantedBy=multi-user.target
```

- [ ] 为什么 systemd 挂掉之后，reboot 也不能正常使用了。

## 如何让其成为最后一个


[^1]: https://unix.stackexchange.com/questions/471824/what-is-the-correct-substitute-for-rc-local-in-systemd-instead-of-re-creating-rc
[^2]: https://support.huaweicloud.com/intl/en-us/trouble-ecs/ecs_trouble_0349.html
