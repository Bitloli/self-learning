# Martins3 的 Check Sheet

启发于: https://xieby1.github.io/cheatsheet.html#debug-log

不想相同的问题 stackoverflow 两次。

## Shell

## find
- 计算所有一个目录中所有的文件的 hash: find path/to/folder -type f -print0 | sort -z | xargs -0 sha1sum | sha1sum
  - https://stackoverflow.com/questions/545387/linux-compute-a-single-hash-for-a-given-folder-contents

## rpm
- rpm -qf 可以找到一个文件对应的包
- rpm2cpio shim-15.4-2.oe2203.src.rpm | cpio -idmv  : 解压一个 rpm 包
- rpm -i --force -nodeps url 可以自动下载安装内核
- yum install whatprovides xxd

## tar
- tar czf name_of_archive_file.tar.gz name_of_directory_to_tar
  - https://unix.stackexchange.com/questions/46969/compress-a-folder-with-tar
