#!/usr/bin/env bash
docker rmi centos-kernel-build
docker build . --tag centos-kernel-build
docker run -it --rm -u $(id -u):$(id -g) -v $(pwd):/home/docker centos-kernel-build

#!/usr/bin/env bash
set -ex
make defconfig
make kvm_guest.config
sed -i "s/#.*CONFIG_XFS_FS.*$/CONFIG_XFS_FS=y/g" .config
make olddefconfig
make binrpm-pkg -j60
# mv /home/docker/rpmbuild/RPMS/ .
# rm -rf /home/docker/rpmbuild
