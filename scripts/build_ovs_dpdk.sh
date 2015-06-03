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

cat << 'EOF' > dpdk-vhost-user-2.patch
diff --git a/INSTALL.DPDK.md b/INSTALL.DPDK.md
index 462ba0e..8d6fd6a 100644
--- a/INSTALL.DPDK.md
+++ b/INSTALL.DPDK.md
@@ -16,7 +16,9 @@ OVS needs a system with 1GB hugepages support.
 Building and Installing:
 ------------------------
 
-Required DPDK 2.0, `fuse`, `fuse-devel` (`libfuse-dev` on Debian/Ubuntu)
+Required: DPDK 2.0
+Optional (if building with vhost-cuse): `fuse`, `fuse-devel` (`libfuse-dev`
+on Debian/Ubuntu)
 
 1. Configure build & install DPDK:
   1. Set `$DPDK_DIR`
@@ -31,13 +33,10 @@ Required DPDK 2.0, `fuse`, `fuse-devel` (`libfuse-dev` on Debian/Ubuntu)
 
      `CONFIG_RTE_BUILD_COMBINE_LIBS=y`
 
-     Update `config/common_linuxapp` so that DPDK is built with vhost
-     libraries; currently, OVS only supports vhost-cuse, so DPDK vhost-user
-     libraries should be explicitly turned off (they are enabled by default
-     in DPDK 2.0).
+     Update `config/common_linuxapp` so that DPDK is built with vhost-user
+     libraries.
 
      `CONFIG_RTE_LIBRTE_VHOST=y`
-     `CONFIG_RTE_LIBRTE_VHOST_USER=n`
 
      Then run `make install` to build and install the library.
      For default install without IVSHMEM:
@@ -316,40 +315,144 @@ the vswitchd.
 DPDK vhost:
 -----------
 
-vhost-cuse is only supported at present i.e. not using the standard QEMU
-vhost-user interface. It is intended that vhost-user support will be added
-in future releases when supported in DPDK and that vhost-cuse will eventually
-be deprecated. See [DPDK Docs] for more info on vhost.
+DPDK 2.0 supports two types of vhost:
 
-Prerequisites:
-1.  Insert the Cuse module:
+1. vhost-user
+2. vhost-cuse
 
-      `modprobe cuse`
+This document assumes the use of vhost-user, unless otherwise specified.
+At the moment, vhost-cuse support is enabled in OVS only if it is detected
+in the DPDK build specified during OVS compilation.
+Please note that support for vhost-cuse is intended to be deprecated in OVS
+in a future release.
 
-2.  Build and insert the `eventfd_link` module:
+(Optional) Building with vhost-cuse ports:
+------------------------------------------
 
-     `cd $DPDK_DIR/lib/librte_vhost/eventfd_link/`
-     `make`
-     `insmod $DPDK_DIR/lib/librte_vhost/eventfd_link.ko`
+Should you wish to use vhost-cuse instead of vhost-user, you must
+enable vhost-cuse in DPDK by setting the following additional flag in
+`config/common_linuxapp`:
+
+ `CONFIG_RTE_LIBRTE_VHOST_USER=n`
+
+Following this, rebuild DPDK as per the instructions in the "Building and
+Installing" section. Finally, rebuild OVS as per step 3 in the "Building
+and Installing" section - OVS will detect that DPDK has vhost-cuse libraries
+compiled and in turn will enable support for it in the switch and disable
+vhost-user support.
+
+DPDK vhost Prerequisites:
+-------------------------
+
+1. DPDK 2.0 with vhost support enabled as documented in the "Building and
+   Installing section":
+
+2. (Optional) If using vhost-cuse:
+
+  1. Insert the Cuse module:
+
+     `modprobe cuse`
+
+  2. Build and insert the `eventfd_link` module:
+
+     ```
+     cd $DPDK_DIR/lib/librte_vhost/eventfd_link/
+     make
+     insmod $DPDK_DIR/lib/librte_vhost/eventfd_link.ko
+     ```
+
+3. QEMU version v2.1.0+
+
+   Both vhost-user and vhost-cuse will work with QEMU v2.1.0 and above,
+   however it is recommended to use v2.2.0 if providing your VM with memory
+   greater than 1GB due to potential issues with memory mapping larger areas.
+   Note: For vhost-cuse, QEMU v1.6.2 will also work, with slightly different
+   command line parameters, which are specified later in this document.
+
+Adding DPDK vhost ports to the Switch:
+--------------------------------------
 
 Following the steps above to create a bridge, you can now add DPDK vhost
-as a port to the vswitch.
+as a port to the vswitch. Unlike DPDK ring ports, DPDK vhost ports can have
+arbitrary names.
+
+When adding vhost ports to the switch, take care depending on which type of
+vhost you are using.
 
-`ovs-vsctl add-port br0 dpdkvhost0 -- set Interface dpdkvhost0 type=dpdkvhost`
+  -  For vhost-user (default), the name of the port type is `dpdkvhostuser`
+
+     ```
+     ovs-ofctl add-port br0 vhost-user-1 -- set Interface vhost-user-1
+     type=dpdkvhostuser
+     ```
 
-Unlike DPDK ring ports, DPDK vhost ports can have arbitrary names:
+     This action creates a socket located at
+     `/usr/local/var/run/openvswitch/vhost-user-1`, which you must provide
+     to your VM on the QEMU command line. More instructions on this can be
+     found in the next section "DPDK vhost-user VM configuration"
+     Note: If you wish for the vhost-user sockets to be created in a
+     directory other than `/usr/local/var/run/openvswitch`, you may specify
+     another location on the ovs-vswitchd command line like so:
 
-`ovs-vsctl add-port br0 port123ABC -- set Interface port123ABC type=dpdkvhost`
+      `./vswitchd/ovs-vswitchd --dpdk --vhost_sock_dir /my-dir -c 0x1 ...`
 
-However, please note that when attaching userspace devices to QEMU, the
-name provided during the add-port operation must match the ifname parameter
-on the QEMU command line.
+  -  For vhost-cuse, the name of the port type is `dpdkvhost`
 
+     ```
+     ovs-ofctl add-port br0 vhost-cuse-1 -- set Interface vhost-cuse-1
+     type=dpdkvhost
+     ```
+
+     When attaching vhost-cuse ports to QEMU, the name provided during the
+     add-port operation must match the ifname parameter on the QEMU command
+     line. More instructions on this can be found in the section "DPDK
+     vhost-cuse VM configuration"
+
+DPDK vhost-user VM configuration:
+---------------------------------
+Follow the steps below to attach vhost-user port(s) to a VM.
 
-DPDK vhost VM configuration:
-----------------------------
+1. Configure sockets.
+   Pass the following parameters to QEMU to attach a vhost-user device:
 
-   vhost ports use a Linux* character device to communicate with QEMU.
+   ```
+   -chardev socket,id=char1,path=/usr/local/var/run/openvswitch/vhost-user-1
+   -netdev type=vhost-user,id=mynet1,chardev=char1,vhostforce
+   -device virtio-net-pci,mac=00:00:00:00:00:01,netdev=mynet1
+   ```
+
+   ...where vhost-user-1 is the name of the vhost-user port added
+   to the switch.
+   Repeat the above parameters for multiple devices, changing the
+   chardev path and id as necessary. Note that a separate and different
+   chardev path needs to be specified for each vhost-user device. For
+   example you have a second vhost-user port named 'vhost-user-2', you
+   append your QEMU command line with an additional set of parameters:
+
+
+   ```
+   -chardev socket,id=char2,path=/usr/local/var/run/openvswitch/vhost-user-2
+   -netdev type=vhost-user,id=mynet2,chardev=char2,vhostforce
+   -device virtio-net-pci,mac=00:00:00:00:00:02,netdev=mynet2
+   ```
+
+2. Configure huge pages.
+   QEMU must allocate the VM's memory on hugetlbfs. Vhost ports access a
+   virtio-net device's virtual rings and packet buffers mapping the VM's
+   physical memory on hugetlbfs. To enable vhost-ports to map the VM's
+   memory into their process address space, pass the following paramters
+   to QEMU:
+
+   ```
+   -object memory-backend-file,id=mem,size=4096M,mem-path=/dev/hugepages,
+   share=on
+   -numa node,memdev=mem -mem-prealloc
+   ```
+
+DPDK vhost-cuse VM configuration:
+---------------------------------
+
+   vhost-cuse ports use a Linux* character device to communicate with QEMU.
    By default it is set to `/dev/vhost-net`. It is possible to reuse this
    standard device for DPDK vhost, which makes setup a little simpler but it
    is better practice to specify an alternative character device in order to
@@ -415,16 +518,19 @@ DPDK vhost VM configuration:
    QEMU must allocate the VM's memory on hugetlbfs. Vhost ports access a
    virtio-net device's virtual rings and packet buffers mapping the VM's
    physical memory on hugetlbfs. To enable vhost-ports to map the VM's
-   memory into their process address space, pass the following paramters
+   memory into their process address space, pass the following parameters
    to QEMU:
 
      `-object memory-backend-file,id=mem,size=4096M,mem-path=/dev/hugepages,
       share=on -numa node,memdev=mem -mem-prealloc`
 
+   Note: For use with an earlier QEMU version such as v1.6.2, use the
+   following to configure hugepages instead:
 
-DPDK vhost VM configuration with QEMU wrapper:
-----------------------------------------------
+     `-mem-path /dev/hugepages -mem-prealloc`
 
+DPDK vhost-cuse VM configuration with QEMU wrapper:
+---------------------------------------------------
 The QEMU wrapper script automatically detects and calls QEMU with the
 necessary parameters. It performs the following actions:
 
@@ -450,8 +556,8 @@ qemu-wrap.py -cpu host -boot c -hda <disk image> -m 4096 -smp 4
   netdev=net1,mac=00:00:00:00:00:01
 ```
 
-DPDK vhost VM configuration with libvirt:
------------------------------------------
+DPDK vhost-cuse VM configuration with libvirt:
+----------------------------------------------
 
 If you are using libvirt, you must enable libvirt to access the character
 device by adding it to controllers cgroup for libvirtd using the following
@@ -525,7 +631,7 @@ Now you may launch your VM using virt-manager, or like so:
 
     `virsh create my_vhost_vm.xml`
 
-DPDK vhost VM configuration with libvirt and QEMU wrapper:
+DPDK vhost-cuse VM configuration with libvirt and QEMU wrapper:
 ----------------------------------------------------------
 
 To use the qemu-wrapper script in conjuntion with libvirt, follow the
@@ -553,7 +659,7 @@ steps in the previous section before proceeding with the following steps:
   the correct emulator location and set any additional options. If you are
   using a alternative character device name, please set "us_vhost_path" to the
   location of that device. The script will automatically detect and insert
-  the correct "vhostfd" value in the QEMU command line arguements.
+  the correct "vhostfd" value in the QEMU command line arguments.
 
   5. Use virt-manager to launch the VM
 
diff --git a/acinclude.m4 b/acinclude.m4
index d09a73f..20391ec 100644
--- a/acinclude.m4
+++ b/acinclude.m4
@@ -220,6 +220,9 @@ AC_DEFUN([OVS_CHECK_DPDK], [
     DPDK_vswitchd_LDFLAGS=-Wl,--whole-archive,$DPDK_LIB,--no-whole-archive
     AC_SUBST([DPDK_vswitchd_LDFLAGS])
     AC_DEFINE([DPDK_NETDEV], [1], [System uses the DPDK module.])
+
+    OVS_GREP_IFELSE([$RTE_SDK/include/rte_config.h], [define RTE_LIBRTE_VHOST_USER 1],
+                    [], [AC_DEFINE([VHOST_CUSE], [1], [DPDK vhost-cuse support enabled, vhost-user disabled.])])
   else
     RTE_SDK=
   fi
diff --git a/lib/netdev-dpdk.c b/lib/netdev-dpdk.c
index 63243d8..62da812 100644
--- a/lib/netdev-dpdk.c
+++ b/lib/netdev-dpdk.c
@@ -28,6 +28,7 @@
 #include <unistd.h>
 #include <stdio.h>
 
+#include "dirs.h"
 #include "dp-packet.h"
 #include "dpif-netdev.h"
 #include "list.h"
@@ -90,8 +91,8 @@ BUILD_ASSERT_DECL((MAX_NB_MBUF / ROUND_DOWN_POW2(MAX_NB_MBUF/MIN_NB_MBUF))
 #define NIC_PORT_RX_Q_SIZE 2048  /* Size of Physical NIC RX Queue, Max (n+32<=4096)*/
 #define NIC_PORT_TX_Q_SIZE 2048  /* Size of Physical NIC TX Queue, Max (n+32<=4096)*/
 
-/* Character device cuse_dev_name. */
-static char *cuse_dev_name = NULL;
+char *cuse_dev_name = NULL;    /* Character device cuse_dev_name. */
+char *vhost_sock_dir = NULL;   /* Location of vhost-user sockets */
 
 /*
  * Maximum amount of time in micro seconds to try and enqueue to vhost.
@@ -126,7 +127,8 @@ enum { DRAIN_TSC = 200000ULL };
 
 enum dpdk_dev_type {
     DPDK_DEV_ETH = 0,
-    DPDK_DEV_VHOST = 1
+    DPDK_DEV_VHOST = 1,
+    DPDK_DEV_VHOST_USER = 2
 };
 
 static int rte_eal_init_ret = ENODEV;
@@ -221,6 +223,9 @@ struct netdev_dpdk {
     /* virtio-net structure for vhost device */
     OVSRCU_TYPE(struct virtio_net *) virtio_dev;
 
+    /* socket location for vhost-user device */
+    char socket_path[IF_NAME_SZ];
+
     /* In dpdk_list. */
     struct ovs_list list_node OVS_GUARDED_BY(dpdk_mutex);
 };
@@ -560,6 +565,24 @@ netdev_dpdk_init(struct netdev *netdev_, unsigned int port_no,
     netdev_->n_rxq = NR_QUEUE;
     netdev->real_n_txq = NR_QUEUE;
 
+    /* Take the name of the vhost-user port and append it to the location where
+     * the socket is to be created, then register the socket.
+     */
+    if (type == DPDK_DEV_VHOST_USER) {
+        snprintf(netdev->socket_path, sizeof(netdev->socket_path), "%s/%s",
+                vhost_sock_dir, netdev_->name);
+        err = rte_vhost_driver_register(netdev->socket_path);
+        if (err) {
+            VLOG_ERR("vhost-user socket device setup failure for socket %s\n",
+                     netdev->socket_path);
+            goto unlock;
+        }
+
+        VLOG_INFO("Socket %s created for vhost-user port %s\n", netdev->socket_path, netdev_->name);
+    } else {
+        strncpy(netdev->socket_path, "", sizeof(netdev->socket_path));
+    }
+
     if (type == DPDK_DEV_ETH) {
         netdev_dpdk_alloc_txq(netdev, NR_QUEUE);
         err = dpdk_eth_dev_init(netdev);
@@ -594,7 +617,7 @@ dpdk_dev_parse_name(const char dev_name[], const char prefix[],
 }
 
 static int
-netdev_dpdk_vhost_construct(struct netdev *netdev_)
+vhost_construct_helper(struct netdev *netdev_, int type)
 {
     struct netdev_dpdk *netdev = netdev_dpdk_cast(netdev_);
     int err;
@@ -604,7 +627,7 @@ netdev_dpdk_vhost_construct(struct netdev *netdev_)
     }
 
     ovs_mutex_lock(&dpdk_mutex);
-    err = netdev_dpdk_init(netdev_, -1, DPDK_DEV_VHOST);
+    err = netdev_dpdk_init(netdev_, -1, type);
     ovs_mutex_unlock(&dpdk_mutex);
 
     rte_spinlock_init(&netdev->vhost_tx_lock);
@@ -613,6 +636,18 @@ netdev_dpdk_vhost_construct(struct netdev *netdev_)
 }
 
 static int
+netdev_dpdk_vhost_construct(struct netdev *netdev_)
+{
+     return vhost_construct_helper(netdev_, DPDK_DEV_VHOST);
+}
+
+static int
+netdev_dpdk_vhost_user_construct(struct netdev *netdev_)
+{
+     return vhost_construct_helper(netdev_, DPDK_DEV_VHOST_USER);
+}
+
+static int
 netdev_dpdk_construct(struct netdev *netdev)
 {
     unsigned int port_no;
@@ -1067,7 +1102,7 @@ dpdk_do_tx_copy(struct netdev *netdev, int qid, struct dp_packet **pkts,
         rte_spinlock_unlock(&dev->stats_lock);
     }
 
-    if (dev->type == DPDK_DEV_VHOST) {
+    if (dev->type == DPDK_DEV_VHOST || dev->type == DPDK_DEV_VHOST_USER) {
         __netdev_dpdk_vhost_send(netdev, (struct dp_packet **) mbufs, newcnt, true);
     } else {
         dpdk_queue_pkts(dev, qid, mbufs, newcnt);
@@ -1599,15 +1634,17 @@ set_irq_status(struct virtio_net *dev)
  * A new virtio-net device is added to a vhost port.
  */
 static int
-new_device(struct virtio_net *dev)
+new_device_helper(struct virtio_net *dev, bool sock, int size)
 {
     struct netdev_dpdk *netdev;
     bool exists = false;
+    char* netdev_name;
 
     ovs_mutex_lock(&dpdk_mutex);
     /* Add device to the vhost port with the same name as that passed down. */
     LIST_FOR_EACH(netdev, list_node, &dpdk_list) {
-        if (strncmp(dev->ifname, netdev->up.name, IFNAMSIZ) == 0) {
+        netdev_name = sock ? netdev->socket_path : netdev->up.name;
+        if (strncmp(dev->ifname, netdev_name, size) == 0) {
             ovs_mutex_lock(&netdev->mutex);
             ovsrcu_set(&netdev->virtio_dev, dev);
             ovs_mutex_unlock(&netdev->mutex);
@@ -1632,6 +1669,18 @@ new_device(struct virtio_net *dev)
     return 0;
 }
 
+static int
+new_device(struct virtio_net *dev)
+{
+    return new_device_helper(dev, false, IFNAMSIZ);
+}
+
+static int
+new_device_vhost_user(struct virtio_net *dev)
+{
+    return new_device_helper(dev, true, IF_NAME_SZ);
+}
+
 /*
  * Remove a virtio-net device from the specific vhost port.  Use dev->remove
  * flag to stop any more packets from being sent or received to/from a VM and
@@ -1686,8 +1735,14 @@ static const struct virtio_net_device_ops virtio_net_device_ops =
     .destroy_device = destroy_device,
 };
 
+const struct virtio_net_device_ops virtio_net_device_ops_vhost_user =
+{
+    .new_device =  new_device_vhost_user,
+    .destroy_device = destroy_device,
+};
+
 static void *
-start_cuse_session_loop(void *dummy OVS_UNUSED)
+start_vhost_loop(void *dummy OVS_UNUSED)
 {
      pthread_detach(pthread_self());
      /* Put the cuse thread into quiescent state. */
@@ -1714,7 +1769,16 @@ dpdk_vhost_class_init(void)
         return -1;
     }
 
-    ovs_thread_create("cuse_thread", start_cuse_session_loop, NULL);
+    ovs_thread_create("vhost_thread", start_vhost_loop, NULL);
+    return 0;
+}
+
+static int
+dpdk_vhost_user_class_init(void)
+{
+    rte_vhost_driver_callback_register(&virtio_net_device_ops_vhost_user);
+
+    ovs_thread_create("vhost_thread", start_vhost_loop, NULL);
     return 0;
 }
 
@@ -1923,6 +1987,32 @@ unlock_dpdk:
     NULL,                       /* rxq_drain */               \
 }
 
+static int
+process_vhost_flags(char* flag, char* default_val, int size, char** argv, char** new_val)
+{
+    int changed = 0;
+
+    /* Depending on which version of vhost is in use, process the vhost-specific
+     * flag if it is provided on the vswitchd command line, otherwise resort to
+     * a default value.
+     *
+     * For vhost-user: Process "--cuse_dev_name" to set the custom location of
+     * the vhost-user socket(s).
+     * For vhost-cuse: Process "--vhost_sock_dir" to set the custom name of the
+     * vhost-cuse character device.
+     */
+    if (!strcmp(argv[1], flag) && (strlen(argv[2]) <= size)) {
+        *new_val = strdup(argv[2]);
+        VLOG_INFO("User-provided %s in use: %s", flag, *new_val);
+        changed = 1;
+    } else {
+        *new_val = default_val;
+        VLOG_INFO("No %s provided - defaulting to %s", flag, default_val);
+    }
+
+    return changed;
+}
+
 int
 dpdk_init(int argc, char **argv)
 {
@@ -1937,27 +2027,20 @@ dpdk_init(int argc, char **argv)
     argc--;
     argv++;
 
-    /* If the cuse_dev_name parameter has been provided, set 'cuse_dev_name' to
-     * this string if it meets the correct criteria. Otherwise, set it to the
-     * default (vhost-net).
-     */
-    if (!strcmp(argv[1], "--cuse_dev_name") &&
-        (strlen(argv[2]) <= NAME_MAX)) {
-
-        cuse_dev_name = strdup(argv[2]);
-
-        /* Remove the cuse_dev_name configuration parameters from the argument
+#ifdef VHOST_CUSE
+    if (process_vhost_flags("--cuse_dev_name", strdup("vhost-net"),
+            PATH_MAX, argv, &cuse_dev_name)) {
+#else
+    if (process_vhost_flags("--vhost_sock_dir", strdup(ovs_rundir()),
+            NAME_MAX, argv, &vhost_sock_dir)) {
+#endif
+        /* Remove the vhost flag configuration parameters from the argument
          * list, so that the correct elements are passed to the DPDK
          * initialization function
          */
         argc -= 2;
-        argv += 2;    /* Increment by two to bypass the cuse_dev_name arguments */
+        argv += 2;    /* Increment by two to bypass the vhost flag arguments */
         base = 2;
-
-        VLOG_ERR("User-provided cuse_dev_name in use: /dev/%s", cuse_dev_name);
-    } else {
-        cuse_dev_name = "vhost-net";
-        VLOG_INFO("No cuse_dev_name provided - defaulting to /dev/vhost-net");
     }
 
     /* Keep the program name argument as this is needed for call to
@@ -2026,6 +2109,20 @@ static const struct netdev_class dpdk_vhost_class =
         NULL,
         netdev_dpdk_vhost_rxq_recv);
 
+const struct netdev_class dpdk_vhost_user_class =
+    NETDEV_DPDK_CLASS(
+        "dpdkvhostuser",
+        dpdk_vhost_user_class_init,
+        netdev_dpdk_vhost_user_construct,
+        netdev_dpdk_vhost_destruct,
+        netdev_dpdk_vhost_set_multiq,
+        netdev_dpdk_vhost_send,
+        netdev_dpdk_vhost_get_carrier,
+        netdev_dpdk_vhost_get_stats,
+        NULL,
+        NULL,
+        netdev_dpdk_vhost_rxq_recv);
+
 void
 netdev_dpdk_register(void)
 {
@@ -2039,7 +2136,11 @@ netdev_dpdk_register(void)
         dpdk_common_init();
         netdev_register_provider(&dpdk_class);
         netdev_register_provider(&dpdk_ring_class);
+#ifdef VHOST_CUSE
         netdev_register_provider(&dpdk_vhost_class);
+#else
+        netdev_register_provider(&dpdk_vhost_user_class);
+#endif
         ovsthread_once_done(&once);
     }
 }
diff --git a/lib/netdev.c b/lib/netdev.c
index 03a7549..ee8e56d 100644
--- a/lib/netdev.c
+++ b/lib/netdev.c
@@ -111,7 +111,8 @@ netdev_is_pmd(const struct netdev *netdev)
 {
     return (!strcmp(netdev->netdev_class->type, "dpdk") ||
             !strcmp(netdev->netdev_class->type, "dpdkr") ||
-            !strcmp(netdev->netdev_class->type, "dpdkvhost"));
+            !strcmp(netdev->netdev_class->type, "dpdkvhost") ||
+            !strcmp(netdev->netdev_class->type, "dpdkvhostuser"));
 }
 
 static void
diff --git a/vswitchd/ovs-vswitchd.c b/vswitchd/ovs-vswitchd.c
index a1b33da..48651df 100644
--- a/vswitchd/ovs-vswitchd.c
+++ b/vswitchd/ovs-vswitchd.c
@@ -253,8 +253,13 @@ usage(void)
     vlog_usage();
     printf("\nDPDK options:\n"
            "  --dpdk options            Initialize DPDK datapath.\n"
+#ifdef VHOST_CUSE
            "  --cuse_dev_name BASENAME  override default character device name\n"
            "                            for use with userspace vHost.\n");
+#else
+           "  --vhost_sock_dir DIR      override default directory where\n"
+           "                            vhost-user sockets are created.\n");
+#endif
     printf("\nOther options:\n"
            "  --unixctl=SOCKET          override default control socket name\n"
            "  -h, --help                display this help message\n"
EOF

home=`pwd`

mkdir -p src
cd src
wget http://dpdk.org/browse/dpdk/snapshot/dpdk-${dversion}.tar.gz
tar xvzpf dpdk-${dversion}.tar.gz
git clone https://github.com/openvswitch/ovs.git
cd dpdk-${dversion}/
patch -p0 <../../config.${dversion}.patch

make config T=x86_64-${feature}-linuxapp-gcc
make install T=x86_64-${feature}-linuxapp-gcc
cd lib/librte_vhost/eventfd_link/
make
cd ${home}/src/ovs
git checkout 7762f7c39a8f5f115427b598d9e768f9336af466

pwd
patch -p1 <../../dpdk-vhost-user-2.patch
./boot.sh
./configure --prefix=/usr --localstatedir=/var --with-dpdk=../dpdk-${dversion}/x86_64-${feature}-linuxapp-gcc/

# make install
#                or
dpkg-buildpackage -b
# mv ../../*.deb ../../ovs-debian

