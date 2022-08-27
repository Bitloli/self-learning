## 保持当前进程运行退出
https://stackoverflow.com/questions/954302/how-to-make-a-programme-continue-to-run-after-log-out-from-ssh
ctrl+z
disown -h %1
bg 1
logout

## 密码
➜  vn git:(master) ✗ ssh-copy-id maritns3@192.168.12.34

- [ ] https://news.ycombinator.com/item?id=32486031 : ssh 技巧
