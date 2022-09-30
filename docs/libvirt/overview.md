# libvirt

- https://wiki.libvirt.org/page/Main_Page
- https://libvirt.org/drvqemu.html

## 环境搭建: https://wiki.libvirt.org/page/UbuntuKVMWalkthrough

- [ ] python-virtinst : 是做什么的?

## 正式操作: https://wiki.libvirt.org/page/QEMUSwitchToLibvirt

## what's the domiain in the libvirt


## patch
- https://libvirt.org/intro.html : not found


## TODO

> 将 source code 的 reading 放到之后

- 使用 Python 开发的吗?

## 使用 libvirt
两个配合使用:
- https://wiki.libvirt.org/page/UbuntuKVMWalkthrough
- https://www.technicalsourcery.net/posts/nixos-in-libvirt/

nixos 专属内容:
- Check if `/dev/kvm` exists, and check the contents of the file opened with `virsh edit <your vm name>`.
This should list /run/libvirt/nix-emulators/qemu-kvm in the <emulator> tag. If both are the case, the VM should be KVM accelerated.

## 重新创建虚拟机的
```sh
kvm : no hardware support
```
