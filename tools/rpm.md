# RPM

## 如何不依赖 tar ball 来实现
- https://stackoverflow.com/questions/17655265/is-it-possible-to-build-an-rpm-package-without-making-a-tar-gz-archive

```txt
Source1: php.conf
Source2: php.ini
Source3: macros.php

install -m 644 $RPM_SOURCE_DIR/php.conf $RPM_BUILD_ROOT/etc/httpd/conf.d
```
