#!/usr/bin/env bash

set -ex
make defconfig
commit_id=$(git log --pretty=format:'%h' -n 1)
make kvm_guest.config
sed -i "s/#.*CONFIG_XFS_FS.*$/CONFIG_XFS_FS=y/g" .config
sed -i "s/CONFIG_LOCALVERSION=.*$/CONFIG_LOCALVERSION=\"-$commit_id\"/g" .config
make olddefconfig
make binrpm-pkg -j60
mv rpmbuild/RPMS/x86_64/*.rpm rpms
rm -rf /home/docker/rpmbuild
