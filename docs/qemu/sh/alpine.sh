#!/usr/bin/env bash
set -ex

use_nvme_as_root=false
use_default_kernel=false

abs_loc=$(dirname "$(realpath "$0")")
configuration=${abs_loc}/config.json

# ----------------------- 配置区 -----------------------------------------------
kernel_dir=$(jq -r ".kernel_dir" <"$configuration")
qemu_dir=$(jq -r ".qemu_dir" <"$configuration")
workstation="$(jq -r ".workstation" <"$configuration")"
# bios 镜像的地址，可以不配置，将下面的 arg_seabios 定位为 "" 就是使用默认的
# seabios=/home/maritns3/core/seabios/out/bios.bin
# ------------------------------------------------------------------------------
qemu=${qemu_dir}/build/x86_64-softmmu/qemu-system-x86_64

abs_loc=$(dirname "$(realpath "$0")")

kernel=${kernel_dir}/arch/x86/boot/bzImage

distribution=centos
iso=${workstation}/${distribution}.iso
disk_img=${workstation}/${distribution}.qcow2
ext4_img1=${workstation}/img1.ext4
ext4_img2=${workstation}/img2.ext4

debug_qemu=
debug_kernel=
LAUNCH_GDB=false

# 必选参数
arg_img="-drive aio=io_uring,file=${disk_img},format=qcow2,if=virtio"
root=/dev/vdb3

if [[ $use_nvme_as_root = true ]]; then
  arg_img="-device nvme,drive=nvme3,serial=foo -drive file=${disk_img},format=qcow2,if=none,id=nvme3"
  root=/dev/nvme1n1
fi

arg_kernel_args="root=$root nokaslr console=ttyS0,9600 earlyprink=serial default_hugepagesz=1G hugepagesz=1G hugepages=8"
arg_kernel="--kernel ${kernel} -append \"${arg_kernel_args}\""

# 可选参数
arg_mem="-m 12G -smp 8"
arg_bridge="-device pci-bridge,id=mybridge,chassis_nr=1"
arg_machine="-machine pc,accel=kvm,kernel-irqchip=on" # q35
arg_cpu="-cpu host"
if [[ -n ${seabios+x} ]]; then
  arg_seabios="-chardev file,path=/tmp/seabios.log,id=seabios -device isa-debugcon,iobase=0x402,chardev=seabios -bios ${seabios}"
else
  arg_seabios=""
fi
arg_nvme="-device nvme,drive=nvme1,serial=foo,bus=mybridge,addr=0x1 -drive file=${ext4_img1},format=raw,if=none,id=nvme1"
arg_nvme2="-device virtio-blk-pci,drive=nvme2,iothread=io0 -drive file=${ext4_img2},format=raw,if=none,id=nvme2"
arg_network="-netdev user,id=n1,ipv6=off -device e1000e,netdev=n1"
arg_iothread="-object iothread,id=io0"
arg_qmp="-qmp unix:${abs_loc}/test.socket,server,nowait"
arg_monitor="-serial mon:stdio -display none"
arg_initrd=""
arg_qmp=""
arg_tmp=""
arg_trace="--trace 'memory_region_ops_\*'"
# -soundhw pcspk

show_help() {
  echo "------ 配置参数 ---------"
  echo "kernel=${kernel}"
  echo "qemu=${qemu}"
  echo "seabios=${seabios}"
  echo "-------------------------"
  echo ""
  echo "-h 展示本消息"
  echo "-s 调试内核，启动 QEMU 部分"
  echo "-k 调试内核，启动 gdb 部分"
  echo "-t 使用 tcg 作为执行引擎而不是 kvm"
  echo "-d 调试 QEMU"
  exit 0
}
mon_socket_path=/tmp/qemu-monitor-socket
serial_socket_path=/tmp/qemu-serial-socket

while getopts "dskthpcm" opt; do
  case $opt in
  d)
    debug_qemu="gdb -ex \"handle SIGUSR1 nostop noprint\" --args"
    # gdb 的时候，让 serial 输出从 unix domain socket 输出
    # https://unix.stackexchange.com/questions/426652/connect-to-running-qemu-instance-with-qemu-monitor
    arg_monitor="-serial unix:$serial_socket_path,server,nowait -monitor unix:$mon_socket_path,server,nowait -display none"
    cd "${qemu_dir}" || exit 1
    ;;
  p) debug_qemu="perf record -F 1000" ;;
  s) debug_kernel="-S -s" ;;
  k) LAUNCH_GDB=true ;;
  t) arg_machine="--accel tcg,thread=single" arg_cpu="" ;;
  h) show_help ;;
  c) socat -,echo=0,icanon=0 unix-connect:$serial_socket_path ;;
  m) socat -,echo=0,icanon=0 unix-connect:$mon_socket_path ;;
  *) exit 0 ;;
  esac
done

sure() {
  read -r -p "$1? (y/n)" yn
  case $yn in
  [Yy]*) return ;;
  [Nn]*) exit ;;
  *) echo "Please answer yes or no." ;;
  esac
}

if [ ! -f "$iso" ]; then
  # wget https://mirrors.tuna.tsinghua.edu.cn/centos/7.9.2009/isos/x86_64/CentOS-7-x86_64-DVD-2009.iso -O "$iso"
  # wget https://releases.ubuntu.com/22.04/ubuntu-22.04-live-server-amd64.iso -O "$iso"
  # wget https://dl-cdn.alpinelinux.org/alpine/v3.15/releases/x86_64/alpine-standard-3.15.0-x86_64.iso -O "$iso"
  exit 0
fi

# 创建额外的两个 disk 用于测试 nvme
# mount -o loop /path/to/data /mnt
if [ ! -f "$ext4_img1" ]; then
  sure "create ${ext4_img1}"
  dd if=/dev/null of="${ext4_img1}" bs=1M seek=100
  mkfs.ext4 -F "${ext4_img1}"
  exit 0
fi

if [ ! -f "$ext4_img2" ]; then
  sure "create ${ext4_img1}"
  dd if=/dev/null of="${ext4_img2}" bs=1M seek=100
  mkfs.ext4 -F "${ext4_img2}"
  exit 0
fi

if [ ! -f "${disk_img}" ]; then
  sure "install alpine image"
  qemu-img create -f qcow2 "${disk_img}" 100G
  # 很多发行版的安装必须使用图形界面，如果在远程，那么需要 vnc
  arg_monitor="-vnc :0,password=on -monitor stdio"
  qemu-system-x86_64 \
    -boot d \
    -cdrom "$iso" \
    -cpu host \
    -hda "${disk_img}" \
    -enable-kvm \
    -m 2G \
    -smp 2 $arg_monitor
  exit 0
fi

if [[ $use_default_kernel = true ]]; then
  arg_monitor="-vnc :0,password -monitor stdio"
  arg_monitor="-nographic"
  qemu-system-x86_64 \
    -cpu host $arg_img \
    -enable-kvm \
    -m 2G \
    -smp 2 $arg_monitor
  exit 0
fi

if [ $LAUNCH_GDB = true ]; then
  echo "debug kernel"
  cd "${kernel_dir}" || exit 1
  gdb vmlinux -ex "target remote :1234" -ex "hbreak start_kernel" -ex "continue"
  exit 0
fi

cmd="${debug_qemu} ${qemu} ${arg_trace} ${debug_kernel} ${arg_img} ${arg_mem} ${arg_cpu} \
  ${arg_kernel} ${arg_seabios} ${arg_bridge} ${arg_nvme} ${arg_nvme2} ${arg_iothread} ${arg_network} \
  ${arg_machine} ${arg_monitor} ${arg_qmp} ${arg_initrd} \
  ${arg_tmp}"
echo "$cmd"
eval "$cmd"

# mount -t 9p -o trans=virtio,version=9p2000.L host0 /mnt/9p
# 内核参数 : pci=nomsi
