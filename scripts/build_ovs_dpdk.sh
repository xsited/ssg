#!/bin/sh

feature="native"
feature="ivshmem"
dversion="1.8.0"
dversion="2.0.0"

cat << 'EOF' > config.1.8.0.patch
--- config/common_linuxapp	2014-12-19 15:38:39.000000000 -0800
+++ config/common_linuxapp.new	2015-04-13 18:52:18.411217460 -0700
@@ -81,7 +81,7 @@
 #
 # Combine to one single library
 #
-CONFIG_RTE_BUILD_COMBINE_LIBS=n
+CONFIG_RTE_BUILD_COMBINE_LIBS=y
 CONFIG_RTE_LIBNAME="intel_dpdk"
 
 #
@@ -372,7 +372,7 @@
 # fuse-devel is needed to run vhost.
 # fuse-devel enables user space char driver development
 #
-CONFIG_RTE_LIBRTE_VHOST=n
+CONFIG_RTE_LIBRTE_VHOST=y
 CONFIG_RTE_LIBRTE_VHOST_DEBUG=n
 
 #
EOF

cat << 'EOF' > config.2.0.0.patch
--- config/common_linuxapp.orig	2015-05-18 17:39:44.488021385 -0700
+++ config/common_linuxapp	2015-05-18 17:42:20.496021531 -0700
@@ -81,7 +81,7 @@
 #
 # Combine to one single library
 #
-CONFIG_RTE_BUILD_COMBINE_LIBS=n
+CONFIG_RTE_BUILD_COMBINE_LIBS=y
 CONFIG_RTE_LIBNAME="intel_dpdk"
 
 #
@@ -418,7 +418,7 @@
 # fuse-devel enables user space char driver development
 # vhost-user is turned on by default.
 #
-CONFIG_RTE_LIBRTE_VHOST=n
+CONFIG_RTE_LIBRTE_VHOST=y
 CONFIG_RTE_LIBRTE_VHOST_USER=y
 CONFIG_RTE_LIBRTE_VHOST_DEBUG=n
 
EOF

cat << 'EOF' > rc.local.include
echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
mkdir /mnt/huge
mount -t hugetlbfs nodev /mnt/huge

modprobe uio 
insmod x86_64-ivshmem-linuxapp-gcc/kmod/igb_uio.ko

# NOTE: VFIO needs to be supported in the kernel and the BIOS. 

#modprobe vfio-pci
#/usr/bin/chmod a+x /dev/vfio
#/usr/bin/chmod 0666 /dev/vfio/*

EOF


home=`pwd`

mkdir -p src
cd src
wget http://dpdk.org/browse/dpdk/snapshot/dpdk-${dversion}.tar.gz
tar xvzpf dpdk-${dversion}.tar.gz


wget -q http://openvswitch.org/releases/openvswitch-2.4.0.tar.gz
if [ $? -ne 0 ]
  then 
	echo "Open vSwitch v2.4 is not there"
	git clone https://github.com/openvswitch/ovs.git
	ovs_path="ovs"
  else 
	echo "OK"
	tar xzpf openvswitch-2.4.0.tar.gz
	ovs_path="openvswitch-2.4.0.tar.gz"
fi

cd dpdk-${dversion}/
patch -p0 <../../config.${dversion}.patch

make config T=x86_64-${feature}-linuxapp-gcc
make install T=x86_64-${feature}-linuxapp-gcc
cd lib/librte_vhost/eventfd_link/
make

cd ${home}/src/${ovs_path}

./boot.sh
./configure --prefix=/usr --localstatedir=/var --with-dpdk=../dpdk-${dversion}/x86_64-${feature}-linuxapp-gcc/

make 
# make install
#                or
# dpkg-buildpackage -b
#                or
# rpmbuild -bb rhel/openvswitch-fedora.spec

