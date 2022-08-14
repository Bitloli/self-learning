# Martins3 的 Check Sheet

启发于: https://xieby1.github.io/cheatsheet.html#debug-log

不想相同的问题 stackoverflow 两次。

## Shell

## rpm
- rpm -qf 可以找到一个文件对应的包
- rpm2cpio shim-15.4-2.oe2203.src.rpm | cpio -idmv  : 解压一个 rpm 包
- rpm -i --force -nodeps url 可以自动下载安装内核

## tar
- tar czf name_of_archive_file.tar.gz name_of_directory_to_tar
  - https://unix.stackexchange.com/questions/46969/compress-a-folder-with-tar
