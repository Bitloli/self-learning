#!/usr/bin/env bash
set -e

use_nvme_as_root=false
replace_kernel=true

hacking_memory="hotplug"
hacking_memory="virtio-pmem"
hacking_memory="none"
hacking_memory="virtio-mem"
hacking_memory="numa"

use_ovmf=false

abs_loc=$(dirname "$(realpath "$0")")
configuration=${abs_loc}/config.json

# ----------------------- 配置区 -----------------------------------------------
kernel_dir=$(jq -r ".kernel_dir" <"$configuration")
qemu_dir=$(jq -r ".qemu_dir" <"$configuration")
workstation="$(jq -r ".workstation" <"$configuration")"
if [[ $(uname -r) == "5.15.0-48-generic" ]]; then
  kernel_dir=/home/maritns3/core/ubuntu-linux
  qemu_dir=/home/maritns3/core/kvmqemu
  workstation=/home/maritns3/core/hacking-vfio
fi

if [[ $(uname -r) != "5.15.0-48-generic" ]]; then
  # bios 镜像的地址，可以不配置
  seabios=/home/martins3/core/seabios/out/bios.bin
fi
# ------------------------------------------------------------------------------
qemu=${qemu_dir}/build/x86_64-softmmu/qemu-system-x86_64

abs_loc=$(dirname "$(realpath "$0")")

kernel=${kernel_dir}/arch/x86/boot/bzImage

distribution=ubuntu-server-22.04
distribution=centos7
distribution=CentOS-Stream-8-x86_64 # good
# distribution=openEuler-22.03-LTS-x86_64 # good

if [[ $(uname -r) == "5.15.0-48-generic" ]]; then
  distribution="alpine-standard-3.16.2-x86_64"
fi

iso=${workstation}/${distribution}.iso
disk_img=${workstation}/${distribution}.qcow2

debug_qemu=
debug_kernel=
LAUNCH_GDB=false

arg_hacking=""
arg_img="-drive aio=io_uring,file=${disk_img},format=qcow2,if=virtio"
root=/dev/vdb3

if [[ $(uname -r) == "5.15.0-48-generic" ]]; then
  root=/dev/vdb3
fi

if [[ $use_nvme_as_root = true ]]; then
  arg_img="-device nvme,drive=nvme3,serial=foo -drive file=${disk_img},format=qcow2,if=none,id=nvme3"
  root=/dev/nvme1n1
fi

# 在 guset 中使用 sudo dmidecode -t bios 查看
arg_smbios='-smbios type=0,vendor="martins3",version=12,date="2022-2-2", -smbios type=1,manufacturer="Martins3 Inc",product="Hacking Alpine",version=12,serial="1234-4567-abbbcbbcccccccccfasdfasdfakdjalfjdalfjadklfjakdf"'
arg_hugetlb="default_hugepagesz=2M hugepagesz=1G hugepages=4 hugepagesz=2M hugepages=512"
# 可选参数
arg_mem_cpu="-m 12G -cpu host -smp 2 -numa node"
arg_machine="-machine pc,accel=kvm,kernel-irqchip=on"
arg_mem_balloon="-device virtio-balloon"

case $hacking_memory in
"numa")
  memdev="-object memory-backend-ram,size=4G,id=m0 -object memory-backend-ram,size=4G,id=m1"
  arg_mem_cpu="$memdev -cpu host -m 8G -smp cpus=4 -numa node,memdev=m0,cpus=2-3,nodeid=0 -numa node,memdev=m1,cpus=0-1,nodeid=1"
  ;;

"virtio-mem")
  # arg_mem_cpu="-m 12G,maxmem=12G"
  # arg_mem_cpu="$arg_mem_cpu -smp sockets=2,cores=2"
  # arg_mem_cpu="$arg_mem_cpu -object memory-backend-ram,id=mem0,size=6G"
  # arg_mem_cpu="$arg_mem_cpu -device virtio-mem-pci,memdev=mem0,node=0,size=4G"
  # arg_mem_cpu="$arg_mem_cpu -object memory-backend-ram,id=mem1,size=6G"
  # arg_mem_cpu="$arg_mem_cpu -device virtio-mem-pci,memdev=mem1,node=1,size=3G"
  arg_mem_cpu="-m 4G,maxmem=20G -smp sockets=2,cores=2"
  arg_mem_cpu="$arg_mem_cpu -numa node,nodeid=0,cpus=0-1,nodeid=0,memdev=mem0 -numa node,nodeid=1,cpus=2-3,nodeid=1,memdev=mem1"
  arg_mem_cpu="$arg_mem_cpu -object memory-backend-ram,id=mem0,size=2G"
  arg_mem_cpu="$arg_mem_cpu -object memory-backend-ram,id=mem1,size=2G"
  arg_mem_cpu="$arg_mem_cpu -object memory-backend-ram,id=mem2,size=2G"
  arg_mem_cpu="$arg_mem_cpu -object memory-backend-ram,id=mem3,size=2G"
  arg_mem_cpu="$arg_mem_cpu -device virtio-mem-pci,id=vm0,memdev=mem2,node=0,requested-size=1G"
  arg_mem_cpu="$arg_mem_cpu -device virtio-mem-pci,id=vm1,memdev=mem3,node=1,requested-size=1G"

  arg_hugetlb="crashkernel=300M"
  ;;

"hotplug")
  arg_mem_cpu="-m 1G,slots=7,maxmem=8G"
  arg_hugetlb=""
  ;;
"virtio-pmem")
  # @todo 似乎这一行不能去掉
  # memory devices (e.g. for memory hotplug) are not enabled, please specify the maxmem option
  # 还有其他问题
  arg_mem_cpu="-m 1G,slots=7,maxmem=8G"
  pmem_img=${workstation}/virtio_pmem.img
  arg_hacking="${arg_hacking} -object memory-backend-file,id=nvmem1,share=on,mem-path=${pmem_img},size=4G"
  arg_hacking="${arg_hacking} -device virtio-pmem-pci,memdev=nvmem1,id=nv1"
  ;;
esac

arg_bridge="-device pci-bridge,id=mybridge,chassis_nr=1"
if [[ -z ${seabios+x} ]]; then
  arg_seabios=""
else
  arg_seabios="-chardev file,path=/tmp/seabios.log,id=seabios -device isa-debugcon,iobase=0x402,chardev=seabios -bios ${seabios}"
fi

if [[ $use_ovmf == true ]]; then
  # @todo nixos 上暂时没有搞清楚 OVMF 的安装，暂时使用这种方法了
  ovmf=$workstation/OVMF.fd
  if [[ ! -f "$ovmf" ]]; then
    wget https://github.com/clearlinux/common/blob/master/OVMF.fd -O "$ovmf"
  fi
  arg_seabios="-drive file=$ovmf,if=pflash,format=raw,unit=0,readonly=on"
  arg_seabios="$arg_seabios -drive file=/tmp/OVMF_VARS.secboot.fd,if=pflash,format=raw,unit=1"
  # arg_seabios="-bios /tmp/OVMF.fd"
fi

arg_cgroupv2="systemd.unified_cgroup_hierarchy=1"
arg_kernel_args="root=$root nokaslr console=ttyS0,9600 earlyprink=serial $arg_hugetlb $arg_cgroupv2 scsi_mod.scsi_logging_level=0xffffffff"
arg_kernel="--kernel ${kernel} -append \"${arg_kernel_args}\""

arg_nvme="-device nvme,drive=nvme1,serial=foo,bus=mybridge,addr=0x1 -drive file=${workstation}/img1,format=raw,if=none,id=nvme1"
# @todo virtio-blk-pci vs virtio-blk-device ?
arg_nvme2="-device virtio-blk-pci,drive=nvme2,iothread=io0 -drive file=${workstation}/img2,format=raw,if=none,id=nvme2"
arg_scsi="-device virtio-scsi-pci,id=scsi0,bus=pci.0,addr=0xa -device scsi-hd,bus=scsi0.0,channel=0,scsi-id=0,lun=0,drive=scsi-drive -drive file=${workstation}/img3,format=raw,id=scsi-drive,if=none"

arg_network="-netdev user,id=net1,hostfwd=tcp::5556-:22 -device e1000e,netdev=net1"
# @todo 尝试一下这个
# -netdev tap,id=nd0,ifname=tap0 -device e1000,netdev=nd0
arg_iothread="-object iothread,id=io0"
arg_qmp="-qmp unix:${abs_loc}/test.socket,server,nowait"
arg_monitor="-serial mon:stdio -display none"
if [[ $(uname -r) == "5.15.0-48-generic" ]]; then
  arg_monitor="-serial mon:stdio"
fi
arg_initrd="-initrd /home/martins3/initramfs-6.0.0-rc2-00159-g4c612826bec1-dirty.img"
arg_initrd=""
arg_trace="--trace 'memory_region_ops_\*'"

arg_vfio="-device vfio-pci,host=02:00.0" # 将音频设备直通到 Guest 中
arg_vfio=""
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
  t) arg_machine="--accel tcg,thread=single" arg_mem_cpu="" ;;
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
  echo "please download ${distribution}"
  # wget http://mirrors.ustc.edu.cn/centos/8-stream/isos/x86_64/CentOS-Stream-8-x86_64-latest-boot.iso
  exit 0
fi

# 创建额外的两个 disk 用于测试 nvme 和 scsi
# mount -o loop /path/to/data /mnt
for ((i = 0; i < 3; i++)); do
  ext4_img="${workstation}/img$((i + 1))"
  if [ ! -f "$ext4_img" ]; then
    sure "create ${ext4_img}"
    dd if=/dev/null of="${ext4_img}" bs=1M seek=100
    mkfs.ext4 -F "${ext4_img}"
    exit 0
  fi
done

if [ ! -f "${disk_img}" ]; then
  sure "use ${iso} install ${disk_img}"
  qemu-img create -f qcow2 "${disk_img}" 100G
  # 很多发行版的安装必须使用图形界面，如果在远程，那么需要 vnc
  arg_monitor="-vnc :0,password=on -monitor stdio"
  arg_monitor=""
  qemu-system-x86_64 \
    -boot d \
    -cdrom "$iso"
  -cpu host \
    -hda "${disk_img}" \
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

if [[ -z ${replace_kernel+x} ]]; then
  arg_monitor="-vnc :0,password=on -monitor stdio"
  # arg_monitor="-nographic"
  # arg_monitor=""
  # @todo 应该是无需如此复杂的
  qemu=qemu-system-x86_64
  ${qemu} \
    -cpu host $arg_img \
    -enable-kvm \
    -m 2G \
    -smp 2 $arg_monitor $debug_kernel
  exit 0
fi

cmd="${debug_qemu} ${qemu} ${arg_trace} ${debug_kernel} ${arg_img} ${arg_mem_cpu}  \
  ${arg_kernel} ${arg_seabios} ${arg_bridge} ${arg_nvme} ${arg_nvme2} ${arg_iothread} ${arg_network} \
  ${arg_machine} ${arg_monitor} ${arg_initrd} ${arg_mem_balloon} ${arg_hacking} \
  ${arg_qmp} ${arg_vfio} ${arg_smbios} ${arg_scsi}"
echo "$cmd"
eval "$cmd"
