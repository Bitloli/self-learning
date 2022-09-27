# 装机
## 需求
- AMD CPU
- NVIDIA GPU : GPCPU ，调查一下
  - NV 的显卡驱动真的可以插入到内核中吗?

- 编译内核要足够快
  - phoronix 1.9.1 的编译速度 : 292s

https://openbenchmarking.org/test/pts/build-linux-kernel&eval=5f0c5d1d2c9fac0ff90c8a1af1dbfb35a146b7d6#metrics

```sh
curl -LO https://phoronix-test-suite.com/releases/phoronix-test-suite-10.4.0.tar.gz
tar -xvf phoronix-test-suite-10.4.0.tar.gz
cd phoronix-test-suite
sudo ./install-sh
phoronix-test-suite run pts/build-linux-kernel-1.9.1
```


## 参考
- https://cerr.cc/post/zkv%E7%9A%84%E6%94%92%E6%9C%BA%E7%AE%80%E5%8F%B2/
- https://nanoreview.net/en/cpu-list/cinebench-scores
