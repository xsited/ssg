DPDK_DIR=/home/stack/src/dpdk-1.8.0
sudo modprobe uio 
sudo modprobe cfuse 
sudo insmod $DPDK_DIR/lib/librte_vhost/eventfd_link/eventfd_link.ko
sudo insmod $DPDK_DIR/x86_64-ivshmem-linuxapp-gcc/kmod/igb_uio.ko

ps ax | grep open
lsmod | grep open
lsmod | grep uio
lsmod | grep eventfd
lsmod | grep virt
